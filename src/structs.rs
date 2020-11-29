use std::collections::HashMap;
use std::process::Command;

use rusqlite::{Connection, Error, NO_PARAMS, Result, Row, Statement, ToSql, Transaction};
use rusqlite::types::{FromSqlResult, ToSqlOutput, ValueRef};
use strum_macros::Display;
use strum_macros::EnumString;

#[derive(Debug, PartialEq, EnumString, Display, FromPrimitive, Copy, Clone)]
pub enum Purity {
    Normal = 0,
    Sketchy = 1,
    NSFW = 2,
}

impl ToSql for Purity {
    fn to_sql(&self) -> Result<ToSqlOutput> { Ok(ToSqlOutput::from(*self as i8)) }
}

#[derive(Debug, PartialEq, EnumString, Display, FromPrimitive, Copy, Clone)]
pub enum Collection {
    Display = 2,
    Favorite = 1,
    Normal = 0,
    Shelf = -1,
    Trash = -2,
}

impl ToSql for Collection {
    fn to_sql(&self) -> Result<ToSqlOutput> { Ok(ToSqlOutput::from(*self as i8)) }
}

#[derive(Debug)]
pub struct WallpaperInfo {
    pub sha1: String,
    pub collection: Collection,
    pub purity: Purity,
}

#[derive(Debug)]
pub struct WallpaperPath {
    pub sha1: String,
    pub path: String,
}
