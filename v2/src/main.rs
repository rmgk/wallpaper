use std::collections::HashMap;
use std::env;
use std::fs;
use std::iter::repeat;
use std::process::Command;

use indoc::indoc;
use itertools::Itertools;
use rusqlite::{Connection, NO_PARAMS, Result, ToSql, Transaction};
use serde_derive::{Deserialize, Serialize};
use sha1::{Digest, Sha1};
use walkdir::{DirEntry, WalkDir};

use crate::structs::{Collection, Purity, WallpaperInfo, WallpaperPath};

mod import;
mod structs;

#[derive(Deserialize, Serialize)]
pub struct Config {
    db_path: String,
    position: Option<i32>,
    current: Option<String>,
    wp_path: String,
    simulate: Option<bool>,
    ordered: Vec<Collection>,
    random: Vec<Collection>,
    order_filter: Vec<Purity>,
    random_filter: Vec<Purity>,
}

fn main() -> Result<()> {
    let config_path = "config.toml";
    let mut config: Config = toml::from_str(
        fs::read_to_string(config_path)
            .expect("read config")
            .as_str(),
    )
        .expect("parse config");

    let mut conn = Connection::open(&config.db_path)?;

    let max_pos = conn
        .query_row("select max(position) from ordering", NO_PARAMS, |row| {
            row.get(0)
        })
        .unwrap_or(0);

    let tx = conn.transaction()?;

    let args = env::args().skip(1);
    if args.len() == 0 {
        help()
    } else {
        for arg in args {
            match arg.as_str() {
                "initialize-database" => create_tables(&tx)?,
                "import-database" => import::import(&tx)?,
                "scan" => scan_new_files(&config, &tx)?,
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
                    config
                        .current
                        .as_ref()
                        .map(|c| select_sha(&c, &tx).map(|w| println!("{:?}", w.1)));
                }
                "path" => {
                    config.current.as_ref().map(|c| {
                        select_sha(&c, &tx).map(|w| println!("{}{}", config.wp_path, w.0.path))
                    });
                }
                other => match other.parse::<i32>() {
                    Ok(mov) => {
                        let next_pos = config.position.unwrap_or(1) + mov;
                        if next_pos <= max_pos && next_pos >= 1 {
                            config.position = Some(next_pos);
                            set_wallpaper(
                                select_position(config.position.unwrap_or(1), &tx)?,
                                &mut config,
                            );
                        }
                    }
                    Err(_) => {
                        help();
                        println!("unknown argument: {}", other)
                    }
                },
            }
        }
    }
    tx.commit()?;
    fs::write(
        config_path,
        toml::to_string(&config).expect("serialize config"),
    )
        .expect("write config");
    Ok(())
}

fn help() {
    println!(indoc! {"
        # Initializing

        initialize-database – create the correct tables (only call once with a new db)
        import-database     – import from old wallpaper database format (call initialize first)
        scan                – scan wallpaper directory for new elements

        # Selecting

        rand     – select random wallpaper
        reorder  – create a new order of wallpaper
        [number] – move wallpaper in order

        # Meta

        info      – print info about the wallpaper
        path      – print the path of the wallpaper
        +<purity> – set purity to one of <pure, sketchy, nsfw>
        +<collct> – change collection <display, fav, normal, shelve, trash>
        "})
}

fn create_tables(tx: &Transaction) -> Result<()> {
    tx.execute(
        "create table info (sha1 TEXT PRIMARY KEY, collection TEXT NOT NULL, purity TEXT NOT NULL);",
        NO_PARAMS,
    )?;
    tx.execute(
        "create table files (sha1 TEXT PRIMARY KEY, path TEXT NOT NULL);",
        NO_PARAMS,
    )?;
    tx.execute(
        "create index idx_info_collection on info (collection);",
        NO_PARAMS,
    )?;
    Ok(())
}

struct WpPathRelative {
    path: DirEntry,
    relative: String,
}

fn scan_new_files(config: &Config, tx: &Transaction) -> Result<()> {
    let endings = [".jpg", ".jpeg", ".png", ".gif", ".bmp"];
    let mut select_paths_stmt = tx.prepare("select path, sha1 from files;")?;
    let mut known_seen_paths: HashMap<String, Option<String>> = select_paths_stmt
        .query_map(NO_PARAMS, |row| Ok((row.get::<usize, String>(0)?, row.get(1)?)))?
        .into_iter()
        .filter_map(|e| e.ok())
        .collect();

    let mut hasher = Sha1::new();

    let mut insert_file_stmt = tx.prepare("replace into files (sha1, path) values (?, ?)")?;
    let mut insert_info_stmt =
        tx.prepare("insert or ignore into info (sha1, collection, purity) values (?, ?, ?)")?;

    WalkDir::new(&config.wp_path)
        .follow_links(true)
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_type().is_file())
        .filter(|e| {
            endings
                .iter()
                .any(|ft| e.path().to_str().map_or(false, |p| p.ends_with(ft)))
        })
        .map(|e| WpPathRelative {
            path: e.clone(),
            relative: String::from(
                e.path()
                    .strip_prefix(&config.wp_path)
                    .expect("strip prefix")
                    .to_str()
                    .expect("to str"),
            ),
        })
        .filter(|wp| {
            if known_seen_paths.contains_key(&wp.relative) {
                known_seen_paths.insert(wp.relative.clone(), None);
                false
            } else { true }
        })
        .map(|wp| {
            println!("found new »{}«", wp.path.path().to_str().unwrap_or(""));
            let bytes = fs::read(wp.path.path()).expect(&format!(
                "reading failed »{}«",
                wp.path.path().to_str().unwrap_or("")
            ));
            hasher.update(bytes);
            let result = hasher.finalize_reset();
            let sha1 = hex::encode(result);
            WallpaperPath {
                sha1,
                path: wp.relative,
            }
        })
        .map(|wp| {
            insert_file_stmt.insert(&[&wp.sha1, &wp.path])?;
            insert_info_stmt.insert::<&[&dyn ToSql]>(&[
                &wp.sha1,
                &Collection::New,
                &Purity::Pure,
            ])?;
            Ok(())
        })
        .find(|r: &Result<()>| r.is_err())
        .unwrap_or(Ok(()))?;


    let mut delete_missing = tx.prepare(
        "delete from files where sha1 = ?")?;
    for (_path, seen) in known_seen_paths {
        if let Some(sha) = seen {
            delete_missing.execute::<&[&dyn ToSql]>(&[&sha])?;
        }
    }

    Ok(())
}

fn set_collection(collection: Collection, config: &Config, tx: &Transaction) -> Result<()> {
    tx.execute::<&[&dyn ToSql]>(
        "update info set collection = ? where sha1 = ?",
        &[&collection, &config.current],
    )
        .map(|_| ())
}

fn set_purity(purity: Purity, config: &Config, tx: &Transaction) -> Result<()> {
    tx.execute::<&[&dyn ToSql]>(
        "update info set purity = ? where sha1 = ?",
        &[&purity, &config.current],
    )
        .map(|_| ())
}

fn select_random(tx: &Transaction, config: &Config) -> Result<WallpaperPath> {
    let rand = &config.random;
    let filter = &config.random_filter;
    let sql =
        format!("select path, sha1 from info natural join files where collection in ({}) and purity in ({}) order by RANDOM() LIMIT 1",
                qstr(rand.len()),
                qstr(filter.len()));
    tx.query_row(&sql, sconcat(rand, filter), |row| {
        Ok(WallpaperPath {
            path: row.get(0)?,
            sha1: row.get(1)?,
        })
    })
}

fn select_position(pos: i32, tx: &Transaction) -> Result<WallpaperPath> {
    tx.query_row(
        "select path, sha1 from ordering natural join files where position = ?",
        &[pos],
        |row| {
            Ok(WallpaperPath {
                path: row.get(0)?,
                sha1: row.get(1)?,
            })
        },
    )
}

fn select_sha(sha1: &str, tx: &Transaction) -> Result<(WallpaperPath, WallpaperInfo)> {
    let wpp = tx.query_row(
        "select path, sha1 from files where sha1 = ?",
        &[sha1],
        |row| {
            Ok(WallpaperPath {
                path: row.get(0)?,
                sha1: row.get(1)?,
            })
        },
    )?;
    let wpi = tx.query_row(
        "select sha1, collection, purity from info where sha1 = ?",
        &[sha1],
        |row| {
            Ok(WallpaperInfo {
                sha1: row.get(0)?,
                collection: row.get(1)?,
                purity: row.get(2)?,
            })
        },
    )?;
    Ok((wpp, wpi))
}

fn qstr(len: usize) -> String {
    repeat("?").take(len).join(", ")
}

fn sconcat<'a>(col: &'a Vec<Collection>, pur: &'a Vec<Purity>) -> Vec<&'a dyn ToSql> {
    let mut params: Vec<&dyn ToSql> = Vec::new();
    col.iter().for_each(|c| params.push(c));
    pur.iter().for_each(|c| params.push(c));
    params
}

fn reorder(tx: &Transaction, config: &Config) -> Result<()> {
    config.position.map(|p| {
        tx.execute::<&[&dyn ToSql]>("update or ignore info set collection = ? from (select sha1 from ordering where position < ?) as seen where collection = ? and info.sha1 = seen.sha1", &[&Collection::Normal, &p, &Collection::New]).unwrap();
    });
    tx.execute("drop table if exists ordering;", NO_PARAMS)?;
    tx.execute(
        "create table ordering (position INTEGER PRIMARY KEY AUTOINCREMENT, sha1 UNIQUE NOT NULL);",
        NO_PARAMS,
    )?;

    let collections = &config.ordered;
    let filter = &config.order_filter;

    let sql = format!("insert into ordering (sha1) select sha1 from info where collection in ({}) and purity in ({}) order by random(); ",
                      qstr(collections.len()),
                      qstr(filter.len()));

    tx.execute(&sql, sconcat(collections, filter))?;
    Ok(())
}

fn set_wallpaper(wpi: WallpaperPath, config: &mut Config) {
    let full = format!("{}{}", config.wp_path, wpi.path);
    let size = imagesize::size(&full).expect("parse image size");
    config.current = Some(wpi.sha1);

    if !config.simulate.unwrap_or(false) {
        Command::new("set-wallpaper")
            .args(&[full, size.width.to_string(), size.height.to_string()])
            .status()
            .expect("failed to execute process");
    } else {
        println!("set »{}«", full);
    }
}

