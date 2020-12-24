use std::collections::HashMap;
use std::env;
use std::fs;
use std::iter::repeat;
use std::path::Path;
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
    database_path: String,
    wallpaper_path: String,
    order_collections: Vec<Collection>,
    random_collections: Vec<Collection>,
    order_purity: Vec<Purity>,
    random_purity: Vec<Purity>,
}

fn main() -> Result<()> {
    let xdg_dirs = xdg::BaseDirectories::with_prefix("wpc").unwrap();
    let config_path = xdg_dirs.place_config_file("wpc.toml").expect("could not create config directory");

    let config: Config = toml::from_str(
        fs::read_to_string("wpc.toml").or_else(
            |_error| fs::read_to_string(&config_path))
            .expect(&format!("no config file in »{:?}«", config_path))
            .as_str(),
    )
        .expect("parse config");

    let mut conn = Connection::open(&config.database_path)?;

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
                "recompute-hashes" => rescan_for_changed_files(&config, &tx)?,
                "rand" => set_wallpaper(select_random(&tx, &config)?, &config, &tx)?,
                "mark-seen" => {
                    let count = mark_seen(&tx)?;
                    println!("marked {} wallpapers as seen", count);
                }
                "reorder" => {
                    reorder(&tx, &config)?;
                    set_position(1, &tx)?;
                }
                "+trash" => set_collection(Collection::Trash, &tx)?,
                "+fav" => set_collection(Collection::Favorite, &tx)?,
                "+shelve" => set_collection(Collection::Shelf, &tx)?,
                "+display" => set_collection(Collection::Display, &tx)?,
                "+normal" => set_collection(Collection::Normal, &tx)?,
                "+sketchy" => set_purity(Purity::Sketchy, &tx)?,
                "+nsfw" => set_purity(Purity::NSFW, &tx)?,
                "+pure" => set_purity(Purity::Pure, &tx)?,
                "info" => {
                    let current = get_current(&tx)?;
                    let position = get_position(&tx).unwrap_or(0);
                    let ordered = is_ordered(&tx)?;
                    select_sha(&current, &tx).map(|(wpp, wpi)| {
                        println!("sha1 {}", wpi.sha1);
                        println!("coll {}", wpi.collection);
                        println!("puri {}", wpi.purity);
                        if ordered {
                            println!("posi {}/{}", position, max_pos);
                        } else {
                            println!("pos* {}/{}", position, max_pos);
                        }
                        println!("path {}{}", config.wallpaper_path, wpp.path);
                    })?;
                }
                "path" => {
                    let current = get_current(&tx)?;
                    select_sha(&current, &tx).map(|w| println!("{}{}", config.wallpaper_path, w.0.path))?;
                }
                other => match other.parse::<i32>() {
                    Ok(mov) => {
                        let next_pos = get_position(&tx).unwrap_or(1) + mov;
                        if next_pos <= max_pos && next_pos >= 1 {
                            set_position(next_pos, &tx)?;
                            set_wallpaper(
                                select_current_position(&tx)?,
                                &config,
                                &tx,
                            )?;
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
    tx.commit()
}

fn is_ordered(tx: &Transaction) -> Result<bool> {
    tx.query_row("select res.sha1 = value from settings, (select sha1 from ordering, settings where ordering.position = settings.value and settings.key = 'position') as res where settings.key = 'current'", NO_PARAMS, |row| row.get(0))
}

fn set_position(pos: i32, tx: &Transaction) -> Result<usize> {
    tx.execute("replace into settings (key, value) values ('position', ?)", &[pos])
}

fn set_current(sha1: &str, tx: &Transaction) -> Result<usize> {
    tx.execute("replace into settings (key, value) values ('current', ?)", &[sha1])
}

fn get_position(tx: &Transaction) -> Result<i32> {
    tx.query_row("select CAST(value as INTEGER) from settings where key = 'position'", NO_PARAMS, |row| row.get(0))
}

fn get_current(tx: &Transaction) -> Result<String> {
    tx.query_row("select CAST(value as TEXT) from settings where key ='current'", NO_PARAMS, |row| row.get(0))
}

fn help() {
    println!(indoc! {"
        # Management

        initialize-database – create the correct tables (only call once with a new db)
        import-database     – import from old wallpaper database format (call initialize first)
        scan                – scan wallpaper directory for new elements
        mark-seen           – change collection of WP from before current position from New to Normal
        recompute-hashes    – recompute hashes of all files in the database

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
    tx.execute(
        "create table settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);",
        NO_PARAMS,
    )?;

    Ok(())
}

struct WpPathRelative {
    path: DirEntry,
    relative: String,
}

fn rescan_for_changed_files(config: &Config, tx: &Transaction) -> Result<()> {
    let mut select_paths_stmt = tx.prepare("select path, sha1 from files;")?;
    let existing_paths: Vec<(String, String)> = select_paths_stmt
        .query_map(NO_PARAMS, |row| Ok((row.get::<usize, String>(0)?, row.get(1)?)))?
        .into_iter()
        .filter_map(|e| e.ok())
        .collect();

    let mut hasher = Sha1::new();

    let mut update_files = tx.prepare("update files set sha1 = ? where sha1 = ?")?;
    let mut update_info =
        tx.prepare("update info set sha1 = ? where sha1 = ?")?;

    let wp_path = Path::new(&config.wallpaper_path);

    for (path, old_sha1) in existing_paths {
        let fullpath = wp_path.join(Path::new(&path));

        let new_sha1 = {
            let bytes = fs::read(&fullpath).expect(&format!("could not read »{:?}«", &fullpath));
            hasher.update(bytes);
            let result = hasher.finalize_reset();
            hex::encode(result)
        };
        if new_sha1 != old_sha1 {
            println!("updating sha1 of {:?}", fullpath);
            update_files.exists(&[&new_sha1, &old_sha1])?;
            update_info.exists(&[&new_sha1, &old_sha1])?;
        }
    }

    Ok(())
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

    WalkDir::new(&config.wallpaper_path)
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
                    .strip_prefix(&config.wallpaper_path)
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
            insert_file_stmt.execute(&[&wp.sha1, &wp.path])?;
            insert_info_stmt.execute::<&[&dyn ToSql]>(&[
                &wp.sha1,
                &Collection::New,
                &Purity::Pure,
            ])?;
            Ok(())
        })
        .find(|r: &Result<()>| r.is_err())
        .unwrap_or(Ok(()))?;


    let mut delete_missing = tx.prepare(
        "delete from files where sha1 = ? and path = ?")?;
    println!("delete missing files …");
    for (path, seen) in known_seen_paths {
        if let Some(sha) = seen {
            let res = delete_missing.execute::<&[&dyn ToSql]>(&[&sha, &path])?;
            if res > 0 {
                println!("{},\"{}\"", sha, path);
            }
        }
    }

    Ok(())
}

fn set_collection(collection: Collection, tx: &Transaction) -> Result<()> {
    let current_sha = get_current(&tx)?;
    tx.execute::<&[&dyn ToSql]>(
        "update info set collection = ? where sha1 = ?",
        &[&collection, &current_sha],
    )
        .map(|_| ())
}

fn set_purity(purity: Purity, tx: &Transaction) -> Result<()> {
    let current_sha = get_current(&tx)?;
    tx.execute::<&[&dyn ToSql]>(
        "update info set purity = ? where sha1 = ?",
        &[&purity, &current_sha],
    )
        .map(|_| ())
}

fn select_random(tx: &Transaction, config: &Config) -> Result<WallpaperPath> {
    let rand = &config.random_collections;
    let filter = &config.random_purity;
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

fn select_current_position(tx: &Transaction) -> Result<WallpaperPath> {
    tx.query_row(
        "select path, sha1 from ordering natural join files, settings where position = settings.value and settings.key = 'position'",
        NO_PARAMS,
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

fn mark_seen(tx: &Transaction) -> Result<usize> {
    tx.execute::<&[&dyn ToSql]>("update or ignore info set collection = ? from (select sha1 from ordering, settings where position <= settings.value and settings.key = 'position') as seen where collection = ? and info.sha1 = seen.sha1", &[&Collection::Normal, &Collection::New])
}

fn reorder(tx: &Transaction, config: &Config) -> Result<()> {
    tx.execute("drop table if exists ordering;", NO_PARAMS)?;
    tx.execute(
        "create table ordering (position INTEGER PRIMARY KEY AUTOINCREMENT, sha1 TEXT UNIQUE NOT NULL);",
        NO_PARAMS,
    )?;

    let collections = &config.order_collections;
    let filter = &config.order_purity;

    let sql = format!("insert into ordering (sha1) select sha1 from info where collection in ({}) and purity in ({}) order by random(); ",
                      qstr(collections.len()),
                      qstr(filter.len()));

    tx.execute(&sql, sconcat(collections, filter))?;
    Ok(())
}

fn set_wallpaper(wpi: WallpaperPath, config: &Config, tx: &Transaction) -> Result<()> {
    let full = format!("{}{}", config.wallpaper_path, wpi.path);
    let size = imagesize::size(&full).expect("parse image size");

    set_current(&wpi.sha1, tx)?;

    let status = Command::new("set-wallpaper")
        .args(&[full, size.width.to_string(), size.height.to_string()])
        .status()
        .expect("failed to execute process");
    assert!(status.success(), "setting wallpaper command failed");
    Ok(())
}

