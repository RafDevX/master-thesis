#!/usr/bin/env rust-script
//! ```cargo
//! [dependencies]
//! anyhow = "1.0.102"
//! reqwest = { version = "0.13.4", features = ["blocking", "brotli", "gzip"] }
//! rusqlite = { version = "0.40.1", features = ["bundled"] }
//! ```

use std::{
    fs::File,
    io::{BufWriter, Write},
    thread,
    time::Duration,
};

use reqwest::blocking::Client;
use rusqlite::{Connection, params};

const BASE_URL: &str = "https://pkg.go.dev/";
const USER_AGENT: &str = "go-pkg-importers-crawler/1.0";
const DB_FILE: &str = "data.sqlite";
const OUTPUT_FILE: &str = "02-ranked-modules-by-importers.txt";
const BATCH_SIZE: i64 = 50;
const BASE_SLEEP_MS: u64 = 50;

fn main() -> anyhow::Result<()> {
    let client = Client::builder()
        .user_agent(USER_AGENT)
        .gzip(true)
        .brotli(true)
        .build()?;

    let mut conn = Connection::open(DB_FILE)?;
    ensure_schema(&conn)?;

    loop {
        let batch = get_batch(&conn)?;

        if batch.is_empty() {
            println!("Done.");
            break;
        }

        println!("Processing batch starting at {}", batch[0]);

        let tx = conn.transaction()?;

        for path in batch {
            let url = BASE_URL.to_owned() + &path;

            let html = match fetch_with_backoff(&client, &url) {
                Ok(html) => html,
                Err(err) => {
                    eprintln!("fetch failed for {path}: {err}");
                    continue;
                }
            };

            let count = html
                .as_ref()
                .map(String::as_str)
                .and_then(extract_imported_by);

            insert_importer(&tx, &path, count)?;

            // be respectful
            thread::sleep(Duration::from_millis(BASE_SLEEP_MS));
        }

        tx.commit()?;
    }

    println!("Writing final output...");

    let mut stmt = conn.prepare(
        r#"
    SELECT path, count
    FROM importers
    ORDER BY count DESC
    WHERE count > 0
    "#,
    )?;

    let rows = stmt.query_map([], |row| {
        Ok((row.get::<_, String>(0)?, row.get::<_, i64>(1)?))
    })?;

    let file = File::create(OUTPUT_FILE)?;
    let mut writer = BufWriter::new(file);

    for row in rows {
        let (path, count) = row?;
        writeln!(writer, "{path} {count}")?;
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

        CREATE TABLE IF NOT EXISTS importers (
            path TEXT PRIMARY KEY,
            count INTEGER, -- nullable for unknown count or 404
            FOREIGN KEY(path) REFERENCES modules(path)
        );

        CREATE INDEX IF NOT EXISTS idx_modules_path ON modules(path);
        "#,
    )?;

    Ok(())
}

fn get_batch(conn: &Connection) -> anyhow::Result<Vec<String>> {
    // we randomly select N entries to try to increase the probability of
    // including more packages that actually exist; otherwise, the ones at
    // the beginning (starting with numbers) tend to be 404 which might lead to
    // more aggressive rate limiting
    let mut stmt = conn.prepare(
        r#"
        SELECT m.path
        FROM modules m
        WHERE NOT EXISTS (
            SELECT 1
            FROM importers i
            WHERE i.path = m.path
        )
        ORDER BY RANDOM()
        LIMIT ?1
        "#,
    )?;

    let rows = stmt.query_map(params![BATCH_SIZE], |row| row.get(0))?;

    rows.map(|r| r.map_err(anyhow::Error::from)).collect()
}

fn fetch_with_backoff(client: &Client, url: &str) -> anyhow::Result<Option<String>> {
    let mut attempt = 0;

    loop {
        attempt += 1;
        let resp = client.get(url).send()?;

        match resp.status().as_u16() {
            200 => return Ok(Some(resp.text()?)),
            404 => return Ok(None),
            429 => {
                let wait = retry_after(&resp).unwrap_or(Duration::from_secs(45));
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
    use reqwest::header::RETRY_AFTER;

    let header = resp.headers().get(RETRY_AFTER)?.to_str().ok()?;
    header.parse::<u64>().ok().map(Duration::from_secs)
}

fn extract_imported_by(html: &str) -> Option<i64> {
    // pattern: Imported by: </span>1,776,917
    let marker = "Imported by: </span>";

    let pos = html.find(marker)?;
    let slice = &html[pos + marker.len()..];

    let until = slice.find('\n')?;
    let num = &slice[..until];

    num.replace(',', "").parse::<i64>().ok()
}

fn insert_importer(conn: &Connection, path: &str, count: Option<i64>) -> anyhow::Result<()> {
    conn.execute(
        r#"
        INSERT INTO importers(path, count)
        VALUES (?1, ?2)
        ON CONFLICT(path) DO UPDATE SET count = excluded.count
        "#,
        params![path, count],
    )?;

    Ok(())
}
