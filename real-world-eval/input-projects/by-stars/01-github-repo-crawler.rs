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
//! urlencoding = "2.1.3"
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
    header::{ACCEPT, AUTHORIZATION, HeaderMap, HeaderValue, LINK, RETRY_AFTER},
};
use rusqlite::{Connection, OptionalExtension, params};
use serde::Deserialize;

const SEARCH_URL: &str = "https://api.github.com/search/repositories";
const USER_AGENT: &str = "github-repo-crawler/1.0";
const DB_FILE: &str = "data.sqlite";
const OUTPUT_FILE: &str = "01-github-repos-by-stars.txt";

const MIN_STARS: i64 = 1000;
const PER_PAGE: u32 = 100;

const MAX_SERVER_RETRIES: u64 = 8;
const REQUEST_DELAY: Duration = Duration::from_secs(1);

#[derive(Debug, Deserialize)]
struct SearchResponse {
    total_count: i64,
    #[serde(default)]
    items: Vec<Repo>,
}

#[derive(Debug, Deserialize)]
struct Repo {
    #[serde(rename = "full_name")]
    path: String,
    #[serde(rename = "stargazers_count")]
    stars: i64,
}

struct Fetched {
    body: String,
    had_link_header: bool,
    next_link: Option<String>,
    rate_remaining: Option<u64>,
    rate_reset: Option<u64>,
}

fn main() -> anyhow::Result<()> {
    let token = std::env::var("GITHUB_TOKEN").ok().filter(|t| !t.is_empty());
    if token.is_none() {
        eprintln!(
            "warning: no GITHUB_TOKEN set; anonymous search is limited to ~10 requests/min - this \
             will be slow and may rate-limit often."
        );
    }

    let client = build_client(token.as_deref())?;

    let conn = Connection::open(DB_FILE)?;
    ensure_schema(&conn)?;

    let (mut next_url, mut max_bound) = match load_next(&conn)? {
        None => (Some(build_base_url(None)), None), // fresh start
        Some((url, mb)) if url.is_empty() => (None, mb), // already done
        Some((url, mb)) => (Some(url), mb),         // resume mid-crawl
    };

    println!("Resuming: max_bound={max_bound:?}");

    while let Some(url) = next_url.clone() {
        let fetched = fetch_with_backoff(&client, &url)?;

        let resp: SearchResponse = serde_json::from_str(&fetched.body)?;

        let lowest = resp.items.last().map(|r| r.stars);
        let highest = resp.items.first().map(|r| r.stars);

        println!(
            "[now: {}] items={} total_count={} stars=[{}..{}] bound={:?}",
            Utc::now(),
            resp.items.len(),
            resp.total_count,
            lowest.map(|s| s.to_string()).unwrap_or_else(|| "-".into()),
            highest.map(|s| s.to_string()).unwrap_or_else(|| "-".into()),
            max_bound,
        );

        // decide the next request *before* writing so it can be committed
        // atomically with the rows from this page
        let (new_next_url, new_max_bound, done) = compute_next(&resp, &fetched, max_bound);

        let tx = conn.unchecked_transaction()?;

        for repo in &resp.items {
            tx.execute(
                r#"
                INSERT INTO github_repos(path, stars)
                VALUES (?1, ?2)
                ON CONFLICT(path) DO UPDATE SET stars = excluded.stars
                "#,
                params![repo.path, repo.stars],
            )?;
        }

        tx.execute(
            "INSERT OR REPLACE INTO github_crawler_state(key, value) VALUES ('next_url', ?1)",
            params![new_next_url],
        )?;
        tx.execute(
            "INSERT OR REPLACE INTO github_crawler_state(key, value) VALUES ('max_bound', ?1)",
            params![new_max_bound.map(|v| v.to_string()).unwrap_or_default()],
        )?;

        tx.commit()?;

        max_bound = new_max_bound;

        if done {
            println!("Done - reached end of results");
            break;
        }

        if fetched.rate_remaining == Some(0) {
            if let Some(reset) = fetched.rate_reset {
                let now = Utc::now().timestamp().max(0) as u64;
                let wait = reset.saturating_sub(now).saturating_add(1);
                if wait > 0 {
                    println!("Rate limit budget exhausted, sleeping {wait}s until reset...");
                    thread::sleep(Duration::from_secs(wait));
                }
            }
        }

        next_url = Some(new_next_url);
        thread::sleep(REQUEST_DELAY);
    }

    write_output(&conn)?;

    Ok(())
}

fn build_client(token: Option<&str>) -> anyhow::Result<Client> {
    let mut headers = HeaderMap::new();

    headers.insert(
        ACCEPT,
        HeaderValue::from_static("application/vnd.github+json"),
    );
    headers.insert(
        "X-GitHub-Api-Version",
        HeaderValue::from_static("2026-03-10"),
    );

    if let Some(t) = token {
        let mut val = HeaderValue::from_str(&format!("Bearer {t}"))?;
        val.set_sensitive(true);
        headers.insert(AUTHORIZATION, val);
    }

    let client = Client::builder()
        .user_agent(USER_AGENT)
        .default_headers(headers)
        .gzip(true)
        .brotli(true)
        .build()?;

    Ok(client)
}

fn ensure_schema(conn: &Connection) -> anyhow::Result<()> {
    conn.execute_batch(
        r#"
        CREATE TABLE IF NOT EXISTS github_repos (
            path TEXT PRIMARY KEY,
            stars INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS github_crawler_state (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        "#,
    )?;

    Ok(())
}

fn build_base_url(max_stars: Option<i64>) -> String {
    let q = match max_stars {
        Some(max) => format!("stars:{MIN_STARS}..{max} language:go"),
        None => format!("stars:>{MIN_STARS} language:go"),
    };

    format!(
        "{SEARCH_URL}?q={}&sort=stars&order=desc&per_page={PER_PAGE}",
        urlencoding::encode(&q)
    )
}

fn compute_next(
    resp: &SearchResponse,
    fetched: &Fetched,
    max_bound: Option<i64>,
) -> (String, Option<i64>, bool) {
    if resp.total_count == 0 {
        // nothing left
        return (String::new(), max_bound, true);
    }

    if let Some(link) = &fetched.next_link {
        return (link.clone(), max_bound, false);
    }

    if !fetched.had_link_header {
        // everything fit in one page
        return (String::new(), max_bound, true);
    }

    // if we got this far, this is the last page of a multi-page query

    let min_stars = resp.items.last().map(|r| r.stars).unwrap_or(MIN_STARS);
    let prev_upper = max_bound.unwrap_or(i64::MAX);

    let mut upper = min_stars;
    if upper >= prev_upper {
        // guard against a plateau (>1000 repos sharing a star count) that would
        // otherwise re-issue an identical query forever
        upper = prev_upper - 1;
    }

    if upper < MIN_STARS {
        (String::new(), Some(upper), true)
    } else {
        (build_base_url(Some(upper)), Some(upper), false)
    }
}

fn load_next(conn: &Connection) -> anyhow::Result<Option<(String, Option<i64>)>> {
    let url: Option<String> = conn
        .query_row(
            "SELECT value FROM github_crawler_state WHERE key='next_url'",
            [],
            |r| r.get(0),
        )
        .optional()?;

    match url {
        None => Ok(None),
        Some(u) => {
            let mb: Option<String> = conn
                .query_row(
                    "SELECT value FROM github_crawler_state WHERE key='max_bound'",
                    [],
                    |r| r.get(0),
                )
                .optional()?;

            let mb = mb.filter(|s| !s.is_empty()).and_then(|s| s.parse().ok());
            Ok(Some((u, mb)))
        }
    }
}

fn fetch_with_backoff(client: &Client, url: &str) -> anyhow::Result<Fetched> {
    let mut attempt = 0u64;

    loop {
        attempt += 1;
        let resp = client.get(url).send()?;

        match resp.status().as_u16() {
            200 => return Ok(extract(resp)?),
            403 | 429 => {
                let status = resp.status().as_u16();

                if let Some(wait) = retry_after(&resp) {
                    eprintln!("rate limited (HTTP {status}), retry-after {wait:?}");
                    thread::sleep(wait);
                } else if header_u64(resp.headers(), "x-ratelimit-remaining") == Some(0) {
                    let reset = header_u64(resp.headers(), "x-ratelimit-reset").unwrap_or(0);
                    let now = Utc::now().timestamp().max(0) as u64;
                    let wait = reset.saturating_sub(now).saturating_add(1).max(1);
                    eprintln!(
                        "primary rate limit hit (HTTP {status}), sleeping {wait}s until reset"
                    );
                    thread::sleep(Duration::from_secs(wait));
                } else {
                    let body = resp.text().unwrap_or_default();
                    anyhow::bail!(
                        "HTTP {status} (not a recognized rate limit): {}",
                        body.trim()
                    );
                }
            }
            code @ (500 | 502 | 503 | 504) => {
                if attempt > MAX_SERVER_RETRIES {
                    anyhow::bail!("giving up after {attempt} attempts (last HTTP {code})");
                }
                let wait = Duration::from_secs(attempt.min(10) * 5);
                eprintln!("server error {code}, retrying in {wait:?}");
                thread::sleep(wait);
            }
            code => {
                let body = resp.text().unwrap_or_default();
                anyhow::bail!("HTTP error {code}: {}", body.trim());
            }
        }
    }
}

fn header_u64(headers: &HeaderMap, name: &str) -> Option<u64> {
    headers.get(name)?.to_str().ok()?.trim().parse().ok()
}

fn retry_after(resp: &Response) -> Option<Duration> {
    let header = resp.headers().get(RETRY_AFTER)?.to_str().ok()?;
    header.parse::<u64>().ok().map(Duration::from_secs)
}

fn extract(resp: Response) -> anyhow::Result<Fetched> {
    let headers = resp.headers();

    let had_link_header = headers.contains_key(LINK);
    let next_link = headers
        .get(LINK)
        .and_then(|v| v.to_str().ok())
        .and_then(parse_next_link);

    let rate_remaining = header_u64(headers, "x-ratelimit-remaining");
    let rate_reset = header_u64(headers, "x-ratelimit-reset");

    let body = resp.text()?;

    Ok(Fetched {
        body,
        had_link_header,
        next_link,
        rate_remaining,
        rate_reset,
    })
}

/// format: `<url1>; rel="next", <url2>; rel="last"`
fn parse_next_link(header: &str) -> Option<String> {
    for part in header.split(',') {
        let mut segs = part.split(';');
        let url_seg = segs.next()?.trim();
        let rel_seg = segs.next()?.trim();

        if rel_seg == "rel=\"next\"" {
            let url = url_seg
                .trim_start_matches('<')
                .trim_end_matches('>')
                .to_string();
            return Some(url);
        }
    }
    None
}

fn write_output(conn: &Connection) -> anyhow::Result<()> {
    println!("Writing output ordered by stars...");

    let mut stmt = conn.prepare(
        r#"
        SELECT path, stars
        FROM github_repos
        ORDER BY stars DESC, path ASC
        "#,
    )?;

    let rows = stmt.query_map([], |row| {
        Ok((row.get::<_, String>(0)?, row.get::<_, i64>(1)?))
    })?;

    let file = File::create(OUTPUT_FILE)?;
    let mut writer = BufWriter::new(file);

    let mut n = 0usize;
    for row in rows {
        let (path, stars) = row?;
        writeln!(writer, "{path} {stars}")?;
        n += 1;
    }

    writer.flush()?;

    println!("Done. Wrote {n} repos to {OUTPUT_FILE}");
    Ok(())
}
