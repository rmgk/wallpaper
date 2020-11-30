use std::env;
use std::fs;
use std::process::Command;

use rusqlite::{Connection, NO_PARAMS, Result, ToSql, Transaction};
use serde_derive::{Deserialize, Serialize};

use crate::structs::{Collection, Purity, WallpaperPath, WallpaperInfo};

mod import;
mod structs;

#[derive(Deserialize, Serialize)]
pub struct Config {
    db_path: String,
    position: Option<i32>,
    current: Option<String>,
    wp_path: String,
    simulate: Option<bool>,
    collections: Vec<Collection>,
    random: Vec<Collection>,
}


fn main() -> Result<()> {
    let config_path = "config.toml";
    let mut config: Config = toml::from_str(fs::read_to_string(config_path).expect("read config").as_str()).expect("parse config");


    let mut conn = Connection::open(&config.db_path)?;
    let tx = conn.transaction()?;
    let args = env::args().skip(1);
    for arg in args {
        match arg.as_str() {
            "import" => import::import(&tx)?,
            "rand" => set_wallpaper(select_random(&tx, &config)?, &mut config),
            "reorder" => {
                reorder(&tx, &config)?;
                config.position = Some(1);
            }
            "+trash" => set_collection(Collection::Trash, &config, &tx)?,
            "+fav" => set_collection(Collection::Favorite, &config, &tx)?,
            "+shelve" => set_collection(Collection::Shelf, &config, &tx)?,
            "+display" => set_collection(Collection::Display, &config, &tx)?,
            "+normal" => set_collection(Collection::Favorite, &config, &tx)?,
            "+sketchy" => set_purity(Purity::Sketchy, &config, &tx)?,
            "+nsfw" => set_purity(Purity::NSFW, &config, &tx)?,
            "+pure" => set_purity(Purity::Pure, &config, &tx)?,
            "info" => {
                config.current.as_ref().map(|c| select_sha(&c, &tx).map(|w| {
                    println!("{:?}", w.1)
                }));
            }
            "path" => {
                config.current.as_ref().map(|c| select_sha(&c, &tx).map(|w| {
                    println!("{}{}", config.wp_path, w.0.path)
                }));
            }
            other => {
                match other.parse::<i32>() {
                    Ok(mov) => {
                        config.position = Some(config.position.unwrap_or(1) + mov);
                        set_wallpaper(select_position(config.position.unwrap_or(1), &tx)?, &mut config);
                    }
                    Err(_) => println!("unknown argument: {}", other),
                }
            }
        }
    }
    tx.commit()?;
    fs::write(config_path, toml::to_string(&config).expect("serialize config")).expect("write config");
    Ok(())
}

fn set_collection(collection: Collection, config: &Config, tx: &Transaction) -> Result<()> {
    tx.execute::<&[&dyn ToSql]>("update info set collection = ? where sha1 = ?", &[&collection, &config.current]).map(|_| ())
}

fn set_purity(purity: Purity, config: &Config, tx: &Transaction) -> Result<()> {
    tx.execute::<&[&dyn ToSql]>("update info set purity = ? where sha1 = ?", &[&purity, &config.current]).map(|_| ())
}


fn select_random(tx: &Transaction, config: &Config) -> Result<WallpaperPath> {
    let rand = &config.random;
    let holes: Vec<&str> = rand.iter().map(|_| "?").collect();
    let sql = format!("select path, sha1 from info natural join files where collection in ({}) order by RANDOM() LIMIT 1", holes.join(", "));
    tx.query_row(&sql, rand, |row| { Ok(WallpaperPath { path: row.get(0)?, sha1: row.get(1)? }) })
}

fn select_position(pos: i32, tx: &Transaction) -> Result<WallpaperPath> {
    tx.query_row("select path, sha1 from ordering natural join files where position = ?", &[pos], |row| Ok(WallpaperPath { path: row.get(0)?, sha1: row.get(1)? }))
}

fn select_sha(sha1: &str, tx: &Transaction) -> Result<(WallpaperPath, WallpaperInfo)> {
    let wpp = tx.query_row("select path, sha1 from files where sha1 = ?", &[sha1], |row| Ok(WallpaperPath { path: row.get(0)?, sha1: row.get(1)? }))?;
    let wpi = tx.query_row("select sha1, collection, purity from info where sha1 = ?", &[sha1], |row| Ok(WallpaperInfo { sha1: row.get(0)?, collection: row.get(1)?, purity: row.get(2)? }))?;
    Ok((wpp, wpi))
}

fn reorder(tx: &Transaction, config: &Config) -> Result<()> {
    tx.execute("drop table if exists ordering;", NO_PARAMS)?;
    tx.execute("create table ordering (position INTEGER PRIMARY KEY AUTOINCREMENT, sha1 UNIQUE NOT NULL);", NO_PARAMS)?;
    let collections = &config.collections;
    let holes: Vec<&str> = collections.iter().map(|_| "?").collect();
    let sql = format!("insert into ordering (sha1) select sha1 from info where collection in ({}) order by random(); ", holes.join(", "));
    tx.execute(&sql, collections)?;
    Ok(())
}

fn set_wallpaper(wpi: WallpaperPath, config: &mut Config) {
    let full = format!("{}{}", config.wp_path, wpi.path);
    config.current = Some(wpi.sha1);

    if !config.simulate.unwrap_or(false) {
        Command::new("set-wallpaper")
            .args(&[full])
            .status()
            .expect("failed to execute process");
    } else {
        println!("set »{}«", full);
    }
}

// fn set_image(path: &String) {
//     let size = imagesize::size(path).expect("parse image size");
//
//     let x = size.width;
//     let y = size.height;
//
//     let ratio = (x as f32) / (y as f32);
//
//     let mut escaped_path = path.clone();
//
//     for symbol in "()&;'".chars() {
//         escaped_path = escaped_path.replace(symbol, format!("\\{}", symbol).as_str());
//     }
//
//
//     let method = if ratio < 1.35 || ratio > 2.25 { "fit" } else { "fill" };
//
//     println!("{}, {} {}", ratio, method, escaped_path);
//
//
//     Command::new("swaymsg")
//         .args(&["output", "*", "bg", escaped_path.as_str(), method])
//         .status()
//         .expect("failed to execute process");
// }
