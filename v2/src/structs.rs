use std::str::FromStr;

use rusqlite::types::{FromSql, FromSqlError, FromSqlResult, ToSqlOutput, ValueRef};
use rusqlite::{Result, ToSql};
use serde_derive::{Deserialize, Serialize};
use strum_macros::Display;
use strum_macros::EnumString;

#[derive(Debug, PartialEq, EnumString, Display, Copy, Clone, Deserialize, Serialize)]
pub enum Purity {
    Pure,
    Sketchy,
    NSFW,
}

impl ToSql for Purity {
    fn to_sql(&self) -> Result<ToSqlOutput> {
        Ok(ToSqlOutput::from(self.to_string()))
    }
}

impl FromSql for Purity {
    fn column_result(value: ValueRef) -> FromSqlResult<Self> {
        value
            .as_str()
            .and_then(|s| Purity::from_str(s).map_err(|e| FromSqlError::Other(Box::from(e))))
    }
}

#[derive(Debug, PartialEq, EnumString, Display, Copy, Clone, Deserialize, Serialize)]
pub enum Collection {
    Display,
    Favorite,
    Normal,
    Shelf,
    Trash,
    New,
    Missing,
}

impl FromSql for Collection {
    fn column_result(value: ValueRef) -> FromSqlResult<Self> {
        value
            .as_str()
            .and_then(|s| Collection::from_str(s).map_err(|e| FromSqlError::Other(Box::from(e))))
    }
}

impl ToSql for Collection {
    fn to_sql(&self) -> Result<ToSqlOutput> {
        Ok(ToSqlOutput::from(self.to_string()))
    }
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
