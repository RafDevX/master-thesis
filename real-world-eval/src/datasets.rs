use std::{
    fs::File,
    io::{BufRead, BufReader},
    path::{Path, PathBuf},
};

use crate::{
    errors::{AppError, AppResult},
    network::NetworkClient,
    projects::Project,
};

mod dependents;

pub const ALL: &[&dyn Dataset] = &[&dependents::Dependents];

pub trait Dataset {
    fn key(&self) -> &'static str;

    fn name(&self) -> &'static str;

    fn source_file_path(&self) -> &Path;

    fn project_from_entry(&self, entry: &str) -> AppResult<Project>;

    fn download_project(
        &self,
        project: &Project,
        client: &NetworkClient,
    ) -> AppResult<ProjectDownloadMetadata>;

    fn calculate_relative_rank_of(&self, project: &Project) -> AppResult<u8> {
        // we avoid `fs::read_to_string` because dataset source can have
        // millions of lines, so we would rather not commit all that to memory
        let file = File::open(self.source_file_path())?;
        let mut reader = BufReader::new(file);
        let mut line = String::new();

        let mut total = 0_usize;
        let mut position = None; // 1-indexed

        // we don't use `for line in reader.lines()` so we can re-use the same
        // `line` buffer, instead of allocating a new `String` every single time
        while reader.read_line(&mut line)? > 0 {
            let Some(entry) = line.split_whitespace().next() else {
                line.clear();

                continue;
            };

            let Ok(current) = self.project_from_entry(entry) else {
                line.clear();

                continue;
            };

            total += 1;

            if position.is_none() && current == *project {
                position = Some(total);
            }

            line.clear();
        }

        let Some(position) = position else {
            return Err(AppError::ProjectNotInDatasetSource {
                project: project.to_string(),
                dataset_key: self.key(),
            });
        };

        // 100 * (position / total), but we want rounding and no overflow
        // (we know total is not 0, or position would have been None above)
        let rank = (100 * (position as u128) + ((total as u128) / 2)) / (total as u128);

        #[expect(
            clippy::cast_possible_truncation,
            reason = "Safe because rank is always <=100 (u8::MAX = 255)"
        )]
        Ok(rank as u8)
    }
}

pub fn dataset_by_key(key: &str) -> Option<&'static dyn Dataset> {
    for dataset in ALL {
        if dataset.key() == key {
            return Some(*dataset);
        }
    }

    None
}

pub struct ProjectDownloadMetadata {
    pub root: PathBuf,
    pub rev_name: String,
    pub rev_hash: Option<String>,
}
