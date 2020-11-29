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
    let sha1 = tx.query_row("select sha1 from info where collection = ? order by RANDOM() LIMIT 1", &[Collection::Display], |row| row.get::<usize, String>(0))?;
    let path: String = tx.query_row("select path from files where sha1 = ?", &[sha1], |row| row.get(0))?;
    let full = ["/home/ragnar/Sync/Wallpaper/", path.as_str()].concat();
    Command::new("set-wallpaper")
        .args(&[full])
        .status()
        .expect("failed to execute process");
    Ok(())
}
