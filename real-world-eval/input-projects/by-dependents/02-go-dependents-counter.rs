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
//! ```

use std::{
    collections::HashSet,
    fs::File,
    io::{BufWriter, Write},
    thread,
    time::Duration,
};

use chrono::Utc;
use reqwest::blocking::Client;
use rusqlite::{Connection, params};

const BASE_URL: &str = "https://proxy.golang.org/";
const USER_AGENT: &str = "go-dependents-counter/1.0";
const DB_FILE: &str = "data.sqlite";
const OUTPUT_FILE: &str = "02-modules-by-dependents.txt";
const BATCH_SIZE: i64 = 50;
const STOP_AT: i64 = 100_000;
const BASE_SLEEP_MS: u64 = 10;
const MAX_TRANSPORT_RETRIES: u32 = 10;

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

        println!(
            "[now: {}] Processing batch of {} starting at {}",
            Utc::now(),
            batch.len(),
            batch[0]
        );

        let tx = conn.transaction()?;

        for path in &batch {
            let result = process_module(&client, path);
            let success = result.as_ref().is_ok_and(Option::is_some);

            match result {
                Ok(Some(deps)) => apply_increments(&tx, &deps)?,
                Ok(None) => {}
                Err(err) => eprintln!("Error processing module {path}: {err}"),
            }

            mark_queried(&tx, path, success)?;

            // be respectful
            thread::sleep(Duration::from_millis(BASE_SLEEP_MS));
        }

        tx.commit()?;
    }

    println!("Writing final output...");

    let mut stmt = conn.prepare(
        r#"
        SELECT path,
               as_direct + as_indirect AS total,
               as_direct,
               as_indirect
        FROM dependent_counts
        WHERE as_direct + as_indirect > 0
        ORDER BY total DESC
        "#,
    )?;

    let rows = stmt.query_map([], |row| {
        Ok((
            row.get::<_, String>(0)?,
            row.get::<_, i64>(1)?,
            row.get::<_, i64>(2)?,
            row.get::<_, i64>(3)?,
        ))
    })?;

    let file = File::create(OUTPUT_FILE)?;
    let mut writer = BufWriter::new(file);

    for row in rows {
        let (path, total, direct, indirect) = row?;
        writeln!(writer, "{path} {total} {direct} {indirect}")?;
    }

    writer.flush()?;

    println!("Done. See {OUTPUT_FILE}");

    Ok(())
}

fn ensure_schema(conn: &Connection) -> anyhow::Result<()> {
    // note that dependent_counts.path has no foreign key constraint pointing to
    // modules.path because sometimes there might be module dependencies not
    // included in our original modules table, and there is no reason to exclude
    // those entirely (if needed later, a JOIN solves that problem)

    conn.execute_batch(
        r#"
        CREATE TABLE IF NOT EXISTS modules (
            path TEXT PRIMARY KEY,
            n_versions INTEGER
        );

        CREATE TABLE IF NOT EXISTS dependent_counts (
            path TEXT PRIMARY KEY,
            as_direct INTEGER NOT NULL DEFAULT 0,
            as_indirect INTEGER NOT NULL DEFAULT 0
        );

        -- just for easy resumption on crash
        CREATE TABLE IF NOT EXISTS dependent_queried_modules (
            path TEXT PRIMARY KEY,
            success INTEGER NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_modules_n_versions
            ON modules(n_versions);
        "#,
    )?;

    Ok(())
}

fn get_batch(conn: &Connection) -> anyhow::Result<Vec<String>> {
    let mut stmt = conn.prepare(
        r#"
        SELECT m.path
        FROM modules m
        WHERE NOT EXISTS (
            SELECT 1
            FROM dependent_queried_modules q
            WHERE q.path = m.path
        )
        ORDER BY m.n_versions DESC
        LIMIT MIN(
            ?1,
            MAX(
                0,
                ?2 - (SELECT COUNT(*) FROM dependent_queried_modules)
            )
        )
        "#,
    )?;

    let rows = stmt.query_map(params![BATCH_SIZE, STOP_AT], |row| row.get(0))?;

    rows.map(|r| r.map_err(anyhow::Error::from)).collect()
}

fn process_module(client: &Client, path: &str) -> anyhow::Result<Option<Vec<(String, bool)>>> {
    let escaped = escape_module_path(path);

    let latest_url = format!("{BASE_URL}{escaped}/@latest");
    let json = match fetch_with_backoff(client, &latest_url)? {
        Some(json) => json,
        None => return Ok(None),
    };

    let version = match extract_version(&json) {
        Some(v) => v,
        None => {
            eprintln!("no Version field for {path}");
            return Ok(None);
        }
    };

    let mod_url = format!("{BASE_URL}{escaped}/@v/{}.mod", escape_module_path(version));
    let r#mod = match fetch_with_backoff(client, &mod_url)? {
        Some(r#mod) => r#mod,
        None => return Ok(None),
    };

    Ok(Some(parse_requires(&r#mod)))
}

/// Go module protocol case encoding: every uppercase ASCII letter in a path or
/// version is escaped as `!` followed by its lowercase form
fn escape_module_path(s: &str) -> String {
    let mut out = String::with_capacity(s.len());

    for c in s.chars() {
        if c.is_ascii_uppercase() {
            out.push('!');
            out.push(c.to_ascii_lowercase());
        } else {
            out.push(c);
        }
    }

    out
}

fn fetch_with_backoff(client: &Client, url: &str) -> anyhow::Result<Option<String>> {
    let mut server_attempt: u64 = 0;
    let mut transport_attempt: u32 = 0;

    loop {
        let resp = match client.get(url).send() {
            Ok(resp) => resp,
            Err(err) => {
                transport_attempt += 1;
                if transport_attempt > MAX_TRANSPORT_RETRIES {
                    return Err(err.into());
                }

                let wait = Duration::from_secs(3 * transport_attempt as u64);
                eprintln!("transport error ({err}), retry {transport_attempt} in {wait:?}");

                thread::sleep(wait);

                continue;
            }
        };

        match resp.status().as_u16() {
            200 => return Ok(Some(resp.text()?)),
            404 => {
                if let Ok(body) = resp.text()
                    && body.contains("module source tree too large")
                {
                    eprintln!("module source tree too large on {url}");
                }

                return Ok(None);
            }
            429 => {
                let wait = retry_after(&resp).unwrap_or(Duration::from_secs(45));
                eprintln!("429 rate limit on {url}, sleeping {wait:?}");
                thread::sleep(wait);
            }
            500 | 502 | 503 | 504 => {
                server_attempt += 1;

                let wait = Duration::from_secs(server_attempt.min(10) * 5);
                eprintln!("server error on {url}, retrying in {wait:?}");

                thread::sleep(wait);
            }
            code => {
                eprintln!("unexpected status {code} on {url}, skipping");
                return Ok(None);
            }
        }
    }
}

fn retry_after(resp: &reqwest::blocking::Response) -> Option<Duration> {
    use reqwest::header::RETRY_AFTER;

    let header = resp.headers().get(RETRY_AFTER)?.to_str().ok()?;
    header.parse::<u64>().ok().map(Duration::from_secs)
}

fn extract_version(json: &str) -> Option<&str> {
    let key = "\"Version\"";
    let after_key = &json[json.find(key)? + key.len()..];

    let after_colon = &after_key[after_key.find(':')? + 1..];
    let after_open = &after_colon[after_colon.find('"')? + 1..];
    let end = after_open.find('"')?;

    let version = &after_open[..end];

    if version.is_empty() {
        None
    } else {
        Some(version)
    }
}

fn parse_requires(r#mod: &str) -> Vec<(String, bool)> {
    let mut direct: HashSet<String> = HashSet::new();
    let mut indirect: HashSet<String> = HashSet::new();
    let mut in_block = false;

    for raw in r#mod.lines() {
        let line = raw.trim();

        if in_block {
            if line.starts_with(')') {
                in_block = false;
            } else if !line.is_empty() && !line.starts_with("//") {
                add_dep(line, &mut direct, &mut indirect);
            }

            continue;
        }

        if let Some(rest) = line.strip_prefix("require") {
            if rest.is_empty() || rest.starts_with(char::is_whitespace) || rest.starts_with('(') {
                let rest = rest.trim_start();
                if let Some(stripped) = rest.strip_prefix('(') {
                    in_block = true;
                    let stripped = stripped.trim();
                    if !stripped.is_empty() && !stripped.starts_with(')') {
                        add_dep(stripped, &mut direct, &mut indirect);
                    }
                } else if !rest.is_empty() {
                    add_dep(rest, &mut direct, &mut indirect);
                }
            }
        }
    }

    let mut out = Vec::with_capacity(direct.len() + indirect.len());

    for p in &direct {
        out.push((p.clone(), true));
    }

    for p in indirect {
        if !direct.contains(&p) {
            out.push((p, false));
        }
    }

    out
}

fn add_dep(line: &str, direct: &mut HashSet<String>, indirect: &mut HashSet<String>) {
    let path = match line.split_whitespace().next() {
        Some(path) => path,
        None => return,
    };

    if line.contains("// indirect") {
        indirect.insert(path.to_string());
    } else {
        direct.insert(path.to_string());
    }
}

fn apply_increments(conn: &Connection, deps: &[(String, bool)]) -> anyhow::Result<()> {
    for (path, is_direct) in deps {
        let (d, i) = if *is_direct { (1, 0) } else { (0, 1) };

        conn.execute(
            r#"
            INSERT INTO dependent_counts(path, as_direct, as_indirect)
            VALUES (?1, ?2, ?3)
            ON CONFLICT(path) DO UPDATE SET
                as_direct = as_direct + excluded.as_direct,
                as_indirect = as_indirect + excluded.as_indirect
            "#,
            params![path, d, i],
        )?;
    }

    Ok(())
}

fn mark_queried(conn: &Connection, path: &str, success: bool) -> anyhow::Result<()> {
    conn.execute(
        r#"
        INSERT OR IGNORE INTO dependent_queried_modules(path, success)
        VALUES (?1, ?2)
        "#,
        params![path, success],
    )?;

    Ok(())
}
