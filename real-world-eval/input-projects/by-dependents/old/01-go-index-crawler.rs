#!/usr/bin/env rust-script
//! ```cargo
//! [dependencies]
//! anyhow = "1.0.102"
//! chrono = { version = "0.4.45", features = ["serde"] }
//! reqwest = { version = "0.13.4", features = ["blocking", "brotli", "gzip"] }
//! rusqlite = { version = "0.40.1", features = ["bundled"] }
//! serde = { version = "1.0.228", features = ["derive"] }
//! serde_json = "1.0.150"
//! urlencoding = "2.1.3"
//! ```

use std::{
    fs::File,
    io::{BufWriter, Write},
    thread,
    time::Duration,
};

use chrono::{DateTime, Utc};
use reqwest::{blocking::Client, header::RETRY_AFTER};
use rusqlite::{Connection, OptionalExtension, params};
use serde::Deserialize;

const BASE_URL: &str = "https://index.golang.org/index?include=all";
const USER_AGENT: &str = "go-index-crawler/1.0";
const DB_FILE: &str = "data.sqlite";
const OUTPUT_FILE: &str = "01-all-modules.txt";
const STOP_BEFORE: &str = "2026-06-01T00:00:00Z";

#[derive(Debug, Deserialize)]
struct Entry {
    #[serde(rename = "Path")]
    path: String,
    #[serde(rename = "Timestamp")]
    timestamp: DateTime<Utc>,
}

fn main() -> anyhow::Result<()> {
    let stop_before = DateTime::parse_from_rfc3339(STOP_BEFORE)?.with_timezone(&Utc);

    let client = Client::builder()
        .user_agent(USER_AGENT)
        .gzip(true)
        .brotli(true)
        .build()?;

    let conn = Connection::open(DB_FILE).context("open db")?;
    ensure_schema(&conn)?;

    let mut since = load_since(&conn)?;
    let mut pages: usize = load_pages(&conn)?;

    println!("Resuming from since={since:?}, pages={pages}");

    loop {
        let url = match since {
            Some(ts) => format!("{BASE_URL}&since={}", urlencoding::encode(&ts.to_rfc3339())),
            None => BASE_URL.to_owned(),
        };

        let body = fetch_with_backoff(&client, &url)?;

        if body.trim().is_empty() {
            println!("Done - end of data");
            break;
        }

        let entries: Vec<Entry> = body
            .lines()
            .filter_map(|line| {
                let line = line.trim();

                if line.is_empty() {
                    return None;
                }

                serde_json::from_str(line).ok()
            })
            .collect();

        if entries.is_empty() {
            println!("empty page");
            break;
        }

        let last = entries.iter().map(|e| e.timestamp).max().unwrap();
        let first = entries.iter().map(|e| e.timestamp).min().unwrap();

        println!(
            "[now: {}] page={} entries={} first={} last={}",
            Utc::now(),
            pages,
            entries.len(),
            first,
            last
        );

        let tx = conn.unchecked_transaction()?;

        for entry in &entries {
            tx.execute(
                "INSERT OR IGNORE INTO modules(path) VALUES (?1)",
                params![entry.path],
            )?;
        }

        tx.execute(
            "INSERT OR REPLACE INTO state(key, value) VALUES ('since', ?1)",
            params![last.to_rfc3339()],
        )?;

        tx.execute(
            "INSERT OR REPLACE INTO state(key, value) VALUES ('pages', ?1)",
            params![(pages + 1).to_string()],
        )?;

        tx.commit()?;

        since = Some(last);
        pages += 1;

        if last >= stop_before {
            println!("Reached stop date: {STOP_BEFORE}");
            break;
        }

        thread::sleep(Duration::from_millis(250));
    }

    println!("Writing final deduplicated output...");

    let mut stmt = conn.prepare("SELECT path FROM modules ORDER BY path")?;
    let rows = stmt.query_map([], |row| row.get::<_, String>(0))?;

    let file = File::create(OUTPUT_FILE)?;
    let mut writer = BufWriter::new(file);

    for path in rows {
        writeln!(writer, "{}", path?)?;
    }

    writer.flush()?;

    println!("Done. See {OUTPUT_FILE}");

    Ok(())
}

fn ensure_schema(conn: &Connection) -> anyhow::Result<()> {
    conn.execute_batch(
        r#"
        CREATE TABLE IF NOT EXISTS modules (
            path TEXT PRIMARY KEY
        );

        CREATE TABLE IF NOT EXISTS state (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        "#,
    )?;

    Ok(())
}

fn load_since(conn: &Connection) -> anyhow::Result<Option<DateTime<Utc>>> {
    let val: Option<String> = conn
        .query_row("SELECT value FROM state WHERE key='since'", [], |r| {
            r.get(0)
        })
        .optional()?;

    let val = val.filter(|v| !v.is_empty());

    match val {
        Some(v) => Ok(Some(DateTime::parse_from_rfc3339(&v)?.with_timezone(&Utc))),
        None => Ok(None),
    }
}

fn load_pages(conn: &Connection) -> anyhow::Result<usize> {
    let val: Option<String> = conn
        .query_row("SELECT value FROM state WHERE key='pages'", [], |r| {
            r.get(0)
        })
        .optional()?;

    Ok(val.unwrap_or_else(|| "0".to_string()).parse().unwrap_or(0))
}

fn fetch_with_backoff(client: &Client, url: &str) -> anyhow::Result<String> {
    let mut attempt = 0;

    loop {
        attempt += 1;
        let resp = client.get(url).send()?;

        match resp.status().as_u16() {
            200 => return Ok(resp.text()?),
            429 => {
                let wait = retry_after(&resp).unwrap_or(Duration::from_secs(30));
                eprintln!("429 rate limit, sleeping {:?}", wait);
                thread::sleep(wait);
            }
            500 | 502 | 503 | 504 => {
                let wait = Duration::from_secs(attempt.min(10) * 5);
                eprintln!("server error, retrying in {:?}", wait);
                thread::sleep(wait);
            }
            code => anyhow::bail!("HTTP error: {code}"),
        }
    }
}

fn retry_after(resp: &reqwest::blocking::Response) -> Option<Duration> {
    let header = resp.headers().get(RETRY_AFTER)?.to_str().ok()?;

    header.parse::<u64>().ok().map(Duration::from_secs)
}
