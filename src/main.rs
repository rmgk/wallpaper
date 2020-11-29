use std::collections::HashMap;
use std::process::Command;

use rusqlite::{Connection, Error, NO_PARAMS, Result, Row, Statement, ToSql, Transaction};
use rusqlite::types::{FromSqlResult, ToSqlOutput, ValueRef};
use strum_macros::Display;
use strum_macros::EnumString;

#[derive(Debug, PartialEq, EnumString, Display)]
enum Purity {
    Normal,
    Sketchy,
    NSFW,
}

impl ToSql for Purity {
    fn to_sql(&self) -> Result<ToSqlOutput> { Ok(ToSqlOutput::from(self.to_string())) }
}

#[derive(Debug, PartialEq, EnumString, Display)]
enum Collection {
    Display,
    Favorite,
    Normal,
    Shelf,
    Trash,
}

impl ToSql for Collection {
    fn to_sql(&self) -> Result<ToSqlOutput> { Ok(ToSqlOutput::from(self.to_string())) }
}

#[derive(Debug)]
struct WallpaperInfo {
    sha1: String,
    collection: Collection,
    purity: Purity,
}

#[derive(Debug)]
struct WallpaperPath {
    sha1: String,
    path: String,
}

fn query_helper(stmt: &Statement) -> Result<HashMap<String, usize>> {
    let names = stmt.column_names();
    let mut map = HashMap::new();
    for name in names {
        map.insert(String::from(name), stmt.column_index(name)?);
    }
    Ok(map)
}

fn get_wpp(row: &Row, names: &HashMap<String, usize>) -> Result<WallpaperPath> {
    let path = row.get(names["path"])?;
    let sha1 = row.get(names["sha1"])?;
    Ok(WallpaperPath { sha1, path })
}


fn get_wpi(row: &Row, names: &HashMap<String, usize>) -> Result<WallpaperInfo> {
    let nsfw: Option<i32> = row.get(names["nsfw"])?;
    let purity = match nsfw {
        Some(0) => Purity::Sketchy,
        Some(1) => Purity::NSFW,
        _ => Purity::Normal
    };
    let vote: Option<i32> = row.get(names["vote"])?;
    let fav: Option<i32> = row.get(names["fav"])?;
    let deleted_option: Option<i32> = row.get(names["fav"])?;
    let deleted = deleted_option.map(|_| true).unwrap_or(false);

    let collect =
        if deleted { Collection::Trash }
        else if vote.unwrap_or(0) > 0 { Collection::Display }
        else if vote.unwrap_or(0) < 0 { Collection::Shelf }
        else if fav.map(|_|true).unwrap_or(false) {Collection::Favorite}
        else {Collection::Normal};

    Ok(WallpaperInfo {
        sha1: row.get(names["sha1"])?,
        purity: purity,
        collection:collect,
    })
}

fn main() -> Result<()> {
    let mut conn = Connection::open("wp.db")?;
    let tx = conn.transaction()?;

    tx.execute("create table if not exists info (sha1 TEXT UNIQUE, collection TEXT, purity TEXT);", NO_PARAMS);
    tx.execute("create table if not exists files (sha1 TEXT NOT NULL, path TEXT NOT NULL);", NO_PARAMS);


    let x = {
        let mut query_stmt = tx.prepare(
            "select path, sha1, vote, fav, deleted, nsfw from wallpaper"
        )?;

        let names = query_helper(&query_stmt)?;

        for key in names.keys() {
            println!("{}: {}", key, names[key]);
        }

        let rows = query_stmt.query_map(NO_PARAMS, |row| {
            let wpp = get_wpp(row, &names);
            let wpi = get_wpi(row, &names);
            Ok((wpp, wpi))
        })?;

        let mut file_stmt = tx.prepare(
            "insert into files (sha1, path) values (?, ?)"
        )?;

        let mut info_stmt = tx.prepare(
            "insert or fail into info (sha1, collection, purity) values (?, ?, ?)"
        )?;

        for row in rows {
            let (wpp, wpir) = row?;
            let wpi = wpir?;
            let sha = wpi.sha1;
            let col = wpi.collection;
            let pur = wpi.purity;

            info_stmt.execute::<&[&dyn ToSql]>(&[&sha, &col, &pur])?;

            match wpp {
                Err(e) => {println!("err wpp {}", sha)}
                Ok(wppo) => {
                    file_stmt.execute::<&[&dyn ToSql]>(&[&wppo.sha1, &wppo.path])?;
                }
            }
        }
        // Command::new("set-wallpaper")
        //     .arg(full)
        //     .spawn()
        //     .expect("failed to execute process");
    };

    tx.commit()?;

    Ok(())
}
