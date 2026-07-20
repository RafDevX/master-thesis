#!/usr/bin/env rust-script
//! ```cargo
//! [package]
//! edition = "2024"
//!
//! [dependencies]
//! chacha20 = "0.10.1"
//! hex = "0.4.3"
//! rand = "0.10.2"
//! ```

use std::{
    fs,
    path::{Path, PathBuf},
};

use chacha20::ChaCha20Rng;
use rand::{SeedableRng, seq::IndexedRandom};

// from https://www.random.org/cgi-bin/randbyte?nbytes=32&format=h
const SEED: [u8; 32] = [
    0x8a, 0x1c, 0x56, 0x07, 0x9c, 0x3f, 0x88, 0x1e, 0x09, 0xe4, 0xfc, 0x9a, 0x83, 0x9c, 0xb4, 0xe1,
    0x48, 0xc5, 0x69, 0x83, 0xea, 0x2d, 0x1f, 0xd5, 0xee, 0xdd, 0x13, 0xc8, 0xbb, 0x8f, 0x08, 0x9c,
];

const SAMPLE_SIZE: usize = 25;

const INPUT_DIR: &str = "./strata";
const OUTPUT_DIR: &str = "./sampled";

fn main() {
    let input_dir = Path::new(INPUT_DIR);
    let output_dir = Path::new(OUTPUT_DIR);

    fs::create_dir_all(output_dir)
        .unwrap_or_else(|error| panic!("failed to create {OUTPUT_DIR}: {error}"));

    let files = sorted_text_files(input_dir);
    let mut rng = ChaCha20Rng::from_seed(SEED);

    println!(
        "Using ChaCha20 sampling with 256-bit seed: {}",
        hex::encode_upper(SEED)
    );

    for source_path in files {
        sample_file(&source_path, output_dir, &mut rng);
    }
}

fn sorted_text_files(directory: &Path) -> Vec<PathBuf> {
    let mut files: Vec<_> = fs::read_dir(directory)
        .unwrap_or_else(|error| panic!("failed to read {}: {error}", directory.display()))
        .map(|entry| {
            entry.unwrap_or_else(|error| {
                panic!(
                    "failed to read an entry in {}: {error}",
                    directory.display()
                )
            })
        })
        .filter(|entry| entry.file_type().as_ref().is_ok_and(fs::FileType::is_file))
        .map(|entry| entry.path())
        .filter(|path| {
            path.extension()
                .is_some_and(|ext| ext.eq_ignore_ascii_case("txt"))
        })
        .collect();

    files.sort();

    files
}

fn sample_file(source_path: &Path, output_dir: &Path, rng: &mut ChaCha20Rng) {
    let contents = fs::read_to_string(source_path)
        .unwrap_or_else(|error| panic!("failed to read {}: {error}", source_path.display()));

    let lines: Vec<&str> = contents
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .collect();

    let sample_count = SAMPLE_SIZE.min(lines.len());

    let sampled = lines
        .sample(rng, sample_count)
        .copied()
        .collect::<Vec<_>>()
        .join("\n");

    let file_name = source_path
        .file_name()
        .unwrap_or_else(|| panic!("source path has no filename: {}", source_path.display()));

    let output_path = output_dir.join(file_name);

    // preserve the conventional final newline for non-empty output
    let output = if sampled.is_empty() {
        sampled
    } else {
        sampled + "\n"
    };

    fs::write(&output_path, output)
        .unwrap_or_else(|error| panic!("failed to write {}: {error}", output_path.display()));

    println!(
        "{}: sampled {} of {} lines",
        source_path.display(),
        sample_count,
        lines.len()
    );
}
