extern crate num;
#[macro_use]
extern crate num_derive;

use std::collections::HashMap;
use std::env;
use std::env::VarError::NotPresent;
use std::process::Command;

use rusqlite::{Connection, Error, NO_PARAMS, Result, Row, Statement, ToSql, Transaction};
use rusqlite::types::{FromSqlResult, ToSqlOutput, ValueRef};
use strum_macros::Display;
use strum_macros::EnumString;

use crate::structs::Collection;

mod import;
mod structs;

fn query_helper(stmt: &Statement) -> Result<HashMap<String, usize>> {
    let names = stmt.column_names();
    let mut map = HashMap::new();
    for name in names {
        map.insert(String::from(name), stmt.column_index(name)?);
    }
    Ok(map)
}


fn main() -> Result<()> {
    let mut conn = Connection::open("wp.db")?;
    let tx = conn.transaction()?;
    let args = env::args().skip(1);
    for arg in args {
        match arg.as_str() {
            "import" => import::import(&tx)?,
            "rand" => random(&tx)?,
            other => println!("unknown argument: {}", other),
        }
    }
    tx.commit()?;
    Ok(())
}

fn random(tx: &Transaction) -> Result<()> {
    let path: String = tx.query_row("select path from info natural join files where collection = ? order by RANDOM() LIMIT 1", &[Collection::Display], |row| row.get(0))?;
    let full = ["/home/ragnar/Sync/Wallpaper/", path.as_str()].concat();
    
    Command::new("set-wallpaper")
        .args(&[full])
        .status()
        .expect("failed to execute process");
    Ok(())
}


fn set_image(path: &String) {
    let size = imagesize::size(path).expect("parse image size");

    let x = size.width;
    let y = size.height;

    let ratio = (x as f32) / (y as f32);

    let mut escaped_path = path.clone();

    for symbol in "()&;'".chars() {
        escaped_path = escaped_path.replace(symbol, format!("\\{}", symbol).as_str());
    }


    let method = if ratio < 1.35 || ratio > 2.25 { "fit" } else { "fill" };

    println!("{}, {} {}", ratio, method, escaped_path);


    Command::new("swaymsg")
        .args(&["output", "*", "bg", escaped_path.as_str(), method])
        .status()
        .expect("failed to execute process");
}
