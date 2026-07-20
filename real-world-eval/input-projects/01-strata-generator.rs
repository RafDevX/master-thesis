#!/usr/bin/env rust-script
//! ```cargo
//! [package]
//! edition = "2024"
//! ```

use std::{
    fs::{self, File},
    io::{BufRead, BufReader, BufWriter, Write},
    path::{Path, PathBuf},
};

const OUTPUT_DIR: &str = "./strata";

const DATASETS: &[Dataset] = &[
    Dataset {
        set: "a",
        name: "dependents",
        path: "./by-dependents/02-modules-by-dependents.txt",
    },
    Dataset {
        set: "b",
        name: "github",
        path: "./by-stars/01-github-repos-by-stars.txt",
    },
    Dataset {
        set: "c",
        name: "gitlab",
        path: "./by-stars/02-gitlab-repos-by-stars.txt",
    },
];

struct Dataset {
    set: &'static str,
    name: &'static str,
    path: &'static str,
}

fn main() {
    fs::create_dir_all(OUTPUT_DIR)
        .unwrap_or_else(|error| panic!("failed to create {OUTPUT_DIR}: {error}"));

    for dataset in DATASETS {
        generate_strata(dataset);
    }
}

fn generate_strata(dataset: &Dataset) {
    let entries = read_first_column(dataset.path);
    let entry_count = entries.len();

    assert!(
        entry_count > 4, // enough to split into quartile bands
        "dataset {} at {} has insufficient entries ({} < 4)",
        dataset.name,
        dataset.path,
        entry_count,
    );

    let mut start = 0;

    for quartile in 1..=4 {
        let end = (entry_count * quartile) / 4;

        let band = roman_numeral(quartile);
        let output_path = stratum_path(dataset, band);

        write_entries(&output_path, &entries[start..end]);

        println!(
            "{}: ranks {}-{} -> {}",
            dataset.name,
            start + 1,
            end,
            output_path.display()
        );

        start = end;
    }

    assert_eq!(start, entry_count);
}

fn read_first_column(path: impl AsRef<Path>) -> Vec<String> {
    let path = path.as_ref();
    let file = File::open(path)
        .unwrap_or_else(|error| panic!("failed to open {}: {error}", path.display()));

    BufReader::new(file)
        .lines()
        .enumerate()
        .filter_map(|(index, line)| {
            let line = line.unwrap_or_else(|error| {
                panic!(
                    "failed to read line {} from {}: {error}",
                    index + 1,
                    path.display()
                )
            });

            line.split_whitespace().next().map(str::to_owned)
        })
        .collect()
}

fn write_entries(path: &Path, entries: &[String]) {
    let file = File::create(path)
        .unwrap_or_else(|error| panic!("failed to create {}: {error}", path.display()));

    let mut writer = BufWriter::new(file);

    for entry in entries {
        writeln!(writer, "{entry}")
            .unwrap_or_else(|error| panic!("failed to write {}: {error}", path.display()));
    }
}

fn stratum_path(dataset: &Dataset, band: &str) -> PathBuf {
    Path::new(OUTPUT_DIR).join(format!(
        "set-{}-{}-band-{}.txt",
        dataset.set, dataset.name, band
    ))
}

fn roman_numeral(value: usize) -> &'static str {
    match value {
        1 => "i",
        2 => "ii",
        3 => "iii",
        4 => "iv",
        _ => unreachable!("only four quartiles exist"),
    }
}
