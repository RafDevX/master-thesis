#!/usr/bin/env rust-script
//! ```cargo
//! [package]
//! edition = "2024"
//!
//! [dependencies]
//! anyhow = "1.0.102"
//! chrono = "0.4.45"
//! reqwest = { version = "0.13.4", features = ["blocking", "brotli", "gzip"] }
//! rusqlite = { version = "0.40.1", features = ["bundled"] }
//! serde = { version = "1.0.228", features = ["derive"] }
//! serde_json = "1.0.150"
//! ```

use std::{
    fs::File,
    io::{BufWriter, Write},
    thread,
    time::Duration,
};

use chrono::Utc;
use reqwest::{
    blocking::{Client, Response},
    header::{HeaderMap, HeaderValue, RETRY_AFTER},
};
use rusqlite::{Connection, OptionalExtension, params};
use serde::Deserialize;

const PROJECTS_URL: &str = "https://gitlab.com/api/v4/projects";
const DB_FILE: &str = "data.sqlite";
const OUTPUT_FILE: &str = "02-gitlab-repos-by-stars.txt";

const MIN_STARS: i64 = 10;
const PER_PAGE: u32 = 100;

const MAX_SERVER_RETRIES: u64 = 8;
const REQUEST_DELAY: Duration = Duration::from_secs(1);

#[derive(Debug, Deserialize)]
struct Project {
    #[serde(rename = "path_with_namespace")]
    path: String,
    #[serde(rename = "star_count")]
    stars: i64,
    #[serde(default)]
    archived: bool,
    #[serde(default)]
    mirror: bool,
    #[serde(default)]
    forked_from_project: Option<serde_json::Value>,
}

struct Fetched {
    body: String,
    next_page: Option<u32>,
    rate_remaining: Option<u64>,
}

fn main() -> anyhow::Result<()> {
    let token = std::env::var("GITLAB_TOKEN").ok().filter(|t| !t.is_empty());

    let client = build_client(token.as_deref())?;

    let conn = Connection::open(DB_FILE)?;
    ensure_schema(&conn)?;

    let mut page = load_page(&conn)?.unwrap_or(1);

    println!("Resuming from page {page}");

    loop {
        let url = build_url(page);

        let fetched = fetch_with_backoff(&client, &url)?;

        let projects: Vec<Project> = serde_json::from_str(&fetched.body)?;

        if projects.is_empty() {
            println!("No more projects");
            break;
        }

        let highest = projects.first().map(|p| p.stars).unwrap_or(0);
        let lowest = projects.last().map(|p| p.stars).unwrap_or(0);

        println!(
            "[{}] page={} projects={} stars=[{}..{}]",
            Utc::now(),
            page,
            projects.len(),
            lowest,
            highest,
        );

        let tx = conn.unchecked_transaction()?;

        for project in &projects {
            if project.stars < MIN_STARS {
                continue;
            }

            if project.archived {
                continue;
            }

            if project.mirror {
                continue;
            }

            if project.forked_from_project.is_some() {
                continue;
            }

            tx.execute(
                r#"
                INSERT INTO gitlab_repos(path, stars)
                VALUES (?1, ?2)
                ON CONFLICT(path) DO UPDATE SET stars = excluded.stars
                "#,
                params![project.path, project.stars],
            )?;
        }

        let next_page = fetched.next_page.unwrap_or(page + 1);

        tx.execute(
            r#"
            INSERT OR REPLACE INTO gitlab_crawler_state(key, value)
            VALUES ('page', ?1)
            "#,
            params![next_page.to_string()],
        )?;

        tx.commit()?;

        if lowest < MIN_STARS {
            println!("Reached projects below {MIN_STARS} stars");
            break;
        }

        page = next_page;

        if fetched.rate_remaining == Some(0) {
            println!("Rate limit exhausted, sleeping 60s...");
            thread::sleep(Duration::from_secs(60));
        }

        thread::sleep(REQUEST_DELAY);
    }

    write_output(&conn)?;

    Ok(())
}

fn build_client(token: Option<&str>) -> anyhow::Result<Client> {
    let mut headers = HeaderMap::new();

    if let Some(token) = token {
        headers.insert("PRIVATE-TOKEN", HeaderValue::from_str(token)?);
    }

    Ok(Client::builder()
        .default_headers(headers)
        .gzip(true)
        .brotli(true)
        .build()?)
}

fn ensure_schema(conn: &Connection) -> anyhow::Result<()> {
    conn.execute_batch(
        r#"
        CREATE TABLE IF NOT EXISTS gitlab_repos (
            path TEXT PRIMARY KEY,
            stars INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS gitlab_crawler_state (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        "#,
    )?;

    Ok(())
}

fn build_url(page: u32) -> String {
    format!(
        concat!(
            "{}",
            "?order_by=star_count",
            "&sort=desc",
            "&with_programming_language=go",
            "&archived=false",
            "&per_page={}",
            "&page={}",
        ),
        PROJECTS_URL, PER_PAGE, page,
    )
}

fn load_page(conn: &Connection) -> anyhow::Result<Option<u32>> {
    let page: Option<String> = conn
        .query_row(
            "SELECT value FROM gitlab_crawler_state WHERE key='page'",
            [],
            |r| r.get(0),
        )
        .optional()?;

    Ok(page.and_then(|p| p.parse().ok()))
}

fn fetch_with_backoff(client: &Client, url: &str) -> anyhow::Result<Fetched> {
    let mut attempt = 0u64;

    loop {
        attempt += 1;

        let resp = client.get(url).send()?;

        match resp.status().as_u16() {
            200 => return Ok(extract(resp)?),
            429 => {
                if let Some(wait) = retry_after(&resp) {
                    eprintln!("rate limited, sleeping {wait:?}");
                    thread::sleep(wait);
                } else {
                    thread::sleep(Duration::from_secs(60));
                }
            }
            500 | 502 | 503 | 504 => {
                if attempt > MAX_SERVER_RETRIES {
                    anyhow::bail!("giving up after {} attempts", attempt);
                }

                let wait = Duration::from_secs(attempt.min(10) * 5);

                eprintln!("server error, retrying in {:?}", wait);

                thread::sleep(wait);
            }
            code => {
                let body = resp.text().unwrap_or_default();

                anyhow::bail!("HTTP {}: {}", code, body.trim());
            }
        }
    }
}

fn extract(resp: Response) -> anyhow::Result<Fetched> {
    let headers = resp.headers();

    let next_page = headers
        .get("x-next-page")
        .and_then(|v| v.to_str().ok())
        .filter(|s| !s.is_empty())
        .and_then(|s| s.parse::<u32>().ok());

    let rate_remaining = headers
        .get("ratelimit-remaining")
        .and_then(|v| v.to_str().ok())
        .and_then(|s| s.parse::<u64>().ok());

    let body = resp.text()?;

    Ok(Fetched {
        body,
        next_page,
        rate_remaining,
    })
}

fn retry_after(resp: &Response) -> Option<Duration> {
    resp.headers()
        .get(RETRY_AFTER)?
        .to_str()
        .ok()?
        .parse::<u64>()
        .ok()
        .map(Duration::from_secs)
}

fn write_output(conn: &Connection) -> anyhow::Result<()> {
    println!("Writing output...");

    let mut stmt = conn.prepare(
        r#"
        SELECT path, stars
        FROM gitlab_repos
        ORDER BY stars DESC, path ASC
        "#,
    )?;

    let rows = stmt.query_map([], |row| {
        Ok((row.get::<_, String>(0)?, row.get::<_, i64>(1)?))
    })?;

    let file = File::create(OUTPUT_FILE)?;
    let mut writer = BufWriter::new(file);

    let mut count = 0usize;

    for row in rows {
        let (path, stars) = row?;

        writeln!(writer, "{path} {stars}")?;

        count += 1;
    }

    writer.flush()?;

    println!("Done. Wrote {} repositories to {}", count, OUTPUT_FILE);

    Ok(())
}
