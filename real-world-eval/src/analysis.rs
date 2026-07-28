use std::{
    borrow::Cow,
    fs::{self, File},
    io::{self, BufRead, BufReader},
    path::Path,
    process, time,
};

use chrono::Utc;
use regex::regex;
use walkdir::WalkDir;

use crate::{
    db::DbConn,
    errors::{AppError, AppResult},
    modules::Module,
    reports::{AnalysisAbortReason, AnalysisReport},
};

const GLOWY_SUCCESS_MESSAGE: &str = "Analysis succeeded with no errors found!";

// by convention, these are the exit codes that Rust uses when a panic happens
const RUST_PANIC_CODES: &[i32] = &[
    101, // normal unwinding panic
    134, // aborting panic
];

// file names are usually limited to 255 characters, so we cannot exceed that
const MAX_FAILURE_OUTPUT_NAME_BYTES: usize = 255 - ".stderr".len();

pub fn process_module(module: &Module, binary: &str, conn: &mut DbConn) -> AppResult<()> {
    println!(
        "[now: {}] \t> Processing module `{}`",
        Utc::now(),
        module.path().display()
    );

    let root = module.files_root()?;

    let (report, output) = analyze_module(&root, binary)?;

    if report.status().should_store_output()
        && let Some(output) = output
    {
        // if we failed or crashed, store the output for later inspection
        fs::create_dir_all(crate::FAILURE_OUTPUTS_DIR.as_path())?;

        // slashes are not allowed in file names, so we use % instead
        let mut name = module.path().to_str().unwrap().replace('/', "%");
        truncate_left(&mut name, MAX_FAILURE_OUTPUT_NAME_BYTES);

        fs::write(
            crate::FAILURE_OUTPUTS_DIR.join(format!("{name}.stdout")),
            output.stdout,
        )?;

        fs::write(
            crate::FAILURE_OUTPUTS_DIR.join(format!("{name}.stderr")),
            output.stderr,
        )?;
    }

    let paren = if let Some(n_errors) = report.n_errors()
        && let Some(n_warnings) = report.n_warnings()
    {
        Cow::Owned(format!(" ({n_errors}/{n_warnings})"))
    } else {
        Cow::Borrowed("")
    };

    println!(
        "[now: {}] \t< Module `{}` {}{} in {:?}",
        Utc::now(),
        module.path().display(),
        report.status(),
        paren,
        report.run_time()
    );

    conn.insert_report(module, &report)?;

    Ok(())
}

fn analyze_module(
    root: &Path,
    binary: &str,
) -> AppResult<(AnalysisReport, Option<process::Output>)> {
    let sloc = calculate_sloc(root)?;

    if sloc == 0 {
        // don't waste time running analysis

        let report = AnalysisReport::new_empty();

        return Ok((report, None));
    }

    let start = time::Instant::now();

    let output = process::Command::new(binary)
        .arg(root)
        .env_clear()
        .env("GLOWY_VERBOSE", "true")
        .output()
        .map_err(AppError::AnalyzerExecutionFailure)?;

    let run_time = start.elapsed();

    let status = output.status;

    let stdout = str::from_utf8(&output.stdout)?;
    let stderr = str::from_utf8(&output.stderr)?;

    // check success message since warnings are still considered a failure even
    // if the execution returns a success exit code
    let report = if status.success()
        && stdout.lines().last().map(str::trim) == Some(GLOWY_SUCCESS_MESSAGE)
    {
        AnalysisReport::new_succeeded(sloc, run_time, stdout)
    } else if status
        .code()
        .is_some_and(|code| !RUST_PANIC_CODES.contains(&code))
    {
        // if the status is not considered a success but there is still an
        // associated exit code, then analysis necessarily failed (or aborted)

        if regex!(r"(?mR)^error[C002]: too many enumerable build worlds:").is_match(stderr) {
            // more than ~20 independent build tag dimensions, so enumeration
            // would take virtually forever, meaning analysis is aborted
            AnalysisReport::new_aborted(sloc, run_time, AnalysisAbortReason::WorldLimitExceeded)
        } else if regex!(r"(?mR)^error[C003]: too many distinct build permutations:")
            .is_match(stderr)
        {
            // way too many permutations for analysis to ever finish (could take
            // centuries), so analysis is aborted
            AnalysisReport::new_aborted(
                sloc,
                run_time,
                AnalysisAbortReason::BuildPermutationLimitExceeded,
            )
        } else if regex!(r"(?mR)^warning[S001]: no registered Go source code files$")
            .is_match(stderr)
        {
            // this can happen even if our calculated sloc was 0, since build
            // tag constraints can lead the analyzer to ignore all files
            AnalysisReport::new_empty()
        } else if regex!(r"(?mR)^Finished parsing \d+ file\(s\)$").is_match(stdout) {
            // parsing finished, so there are real errors
            AnalysisReport::new_failed(sloc, run_time, stdout, stderr)
        } else {
            // no analysis took place because parsing failed
            AnalysisReport::new_aborted(sloc, run_time, AnalysisAbortReason::ParsingFailed)
        }
    } else {
        // if there is no associated exit code, then the process crashed
        // (this is also true even if there is a code, but representing a panic)

        AnalysisReport::new_crashed(sloc, run_time)
    };

    Ok((report, Some(output)))
}

fn calculate_sloc(root: &Path) -> AppResult<usize> {
    let mut total = 0;

    'walker: for entry in WalkDir::new(root).follow_links(true) {
        let entry = entry.map_err(io::Error::from)?;

        if entry.file_type().is_dir() {
            continue;
        }

        let file_name = entry.file_name().to_string_lossy();

        if !file_name.ends_with(".go") || file_name.ends_with("_test.go") {
            continue;
        }

        let file = File::open(entry.path())?;
        let mut reader = BufReader::new(file);

        // re-use the same buffer instead of allocating a new String every time
        let mut line = String::new();
        let mut in_block_comment = false;
        let mut in_raw_string = false;

        while reader.read_line(&mut line)? > 0 {
            let trimmed = line.trim();

            if let Some(constraint) = trimmed
                .strip_prefix("//go:build")
                .or_else(|| trimmed.strip_prefix("// +build"))
                && constraint.trim() == "ignore"
            {
                // the `ignore` tag is conventionally unsatisfiable, typically
                // corresponding to generated code or irrelevant fixtures, so we
                // ignore files requiring it

                // we do not go through all the trouble of evaluating complex
                // constraints (e.g. `!ignore || tools`) since it is very rare
                // in real-world projects for `ignore` to be used in any other
                // position than by itself, and we really just want to quickly
                // exclude files that should be ignored

                // note that in theory there should be no code before build
                // constraints, so `total` has not been changed for this file
                // yet, and so we do not need a per-file tally
                continue 'walker;
            }

            if line_has_code(trimmed, &mut in_block_comment, &mut in_raw_string) {
                total += 1;
            }

            line.clear();
        }
    }

    Ok(total)
}

fn line_has_code(line: &str, in_block_comment: &mut bool, in_raw_string: &mut bool) -> bool {
    let mut has_code = *in_raw_string;

    // since we're working with bytes and not &str, we don't need to worry about
    // valid unicode character mappings and indexing in the middle of a char
    let bytes = line.as_bytes();
    let mut i = 0;
    let mut in_line_string = false;
    let mut in_rune_lit = false;

    while i < bytes.len() {
        if *in_block_comment {
            if (i + 1) < bytes.len() && bytes[i] == b'*' && bytes[i + 1] == b'/' {
                *in_block_comment = false;
                i += 2; // skip */
            } else {
                i += 1; // advance so we can check the next pair for */
            }

            continue;
        }

        match bytes[i] {
            b'\\' if (in_line_string || in_rune_lit) && (i + 1) < bytes.len() => {
                has_code = true;
                i += 2; // skip \x
            }
            b'`' if !in_line_string && !in_rune_lit => {
                *in_raw_string = !*in_raw_string;
                has_code = true;
                i += 1; // skip `
            }
            _ if *in_raw_string => {
                i += 1; // advance so we can check the next byte for `
            }
            b'"' if !*in_raw_string && !in_rune_lit => {
                in_line_string = !in_line_string;
                has_code = true;
                i += 1; // skip "
            }
            _ if in_line_string => {
                i += 1; // advance so we can check the next byte for "
            }
            b'\'' if !*in_raw_string && !in_line_string => {
                in_rune_lit = !in_rune_lit;
                has_code = true;
                i += 1; // skip '
            }
            _ if in_rune_lit => {
                i += 1; // advance so we can check the next byte for "
            }
            b'/' if (i + 1) < bytes.len() && bytes[i + 1] == b'/' => break,
            b'/' if (i + 1) < bytes.len() && bytes[i + 1] == b'*' => {
                *in_block_comment = true;
                i += 2; // skip /*
            }
            other if !other.is_ascii_whitespace() => {
                has_code = true;
                i += 1; // advance to next byte
            }
            _ => i += 1, // nothing special, just advance
        }
    }

    has_code
}

fn truncate_left(s: &mut String, mut max_bytes: usize) {
    if s.len() <= max_bytes {
        return;
    }

    max_bytes -= "…".len();

    let mut start = s.len() - max_bytes;

    while !s.is_char_boundary(start) {
        start += 1;
    }

    s.drain(..start);
    s.insert(0, '…');
}
