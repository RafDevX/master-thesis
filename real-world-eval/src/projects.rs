use std::{fmt, fs, path::PathBuf};

use chrono::Utc;
use url::Url;
use walkdir::WalkDir;

use crate::{
    db::DbConn,
    errors::{AppError, AppResult},
    network::NetworkClient,
    samples::Sample,
};

#[derive(PartialEq, Eq)]
pub struct Project(Url);

impl Project {
    pub fn new(url: Url) -> Self {
        assert_eq!(url.query(), None, "Invalid query (should not be set)");
        assert_eq!(url.fragment(), None, "Invalid fragment (should not be set)");

        Self(url)
    }

    pub fn url(&self) -> &Url {
        &self.0
    }

    pub fn as_base(&self) -> &str {
        // we don't use url.domain() + url.path() because that would require
        // allocating a new String, so we just slice the inner str repr
        #[expect(clippy::string_slice, reason = "Guaranteed safe index")]
        &self.0.as_str()[(self.0.scheme().len() + "://".len())..]
    }

    pub fn already_exists(&self, conn: &DbConn) -> AppResult<bool> {
        conn.project_already_exists(self)
    }

    #[expect(clippy::panic_in_result_fn, reason = "Triple-check before delete")]
    pub fn init(
        &self,
        sample: &Sample,
        conn: &mut DbConn,
        client: &NetworkClient,
    ) -> AppResult<Option<PathBuf>> {
        let dataset = sample.dataset();

        let relative_rank = dataset.calculate_relative_rank_of(self)?;

        println!(
            "[now: {}] Init project `{}` from sample {}.{} (rank {}/100)",
            Utc::now(),
            self.0.as_str(),
            dataset.key(),
            sample.band().as_str(),
            relative_rank
        );

        let root = dataset.download_project(self, client)?;

        let mut modules = Vec::new();

        for entry in WalkDir::new(&root) {
            let entry = match entry.map_err(walkdir::Error::into_io_error) {
                Ok(entry) => entry,
                Err(None) => continue,
                Err(Some(err)) => return Err(err.into()),
            };

            if entry.file_type().is_dir() {
                continue;
            }

            if entry.file_name() == "go.mod" {
                let go_mod_path = entry.into_path();
                let dir_path = go_mod_path.parent().unwrap();

                let relative = dir_path
                    .strip_prefix(&root)
                    .unwrap() // safe (entry is a subdirectory of root)
                    .to_str()
                    .ok_or_else(|| {
                        AppError::NonUtf8Path(dir_path.to_string_lossy().into_owned())
                    })?;

                let with_base = if relative.is_empty() {
                    // project root itself
                    self.as_base().to_owned()
                } else {
                    // sub-directory
                    format!("{}/{relative}", self.as_base())
                };

                modules.push(with_base);
            } else if entry.path().extension().is_none_or(|ext| ext != "go") {
                // this file is irrelevant, just delete it

                // triple check
                assert!(
                    entry.path().starts_with(&*crate::PROJECT_FILES_DIR),
                    "Arbitrary deletion"
                );

                fs::remove_file(entry.path())?;
            }
        }

        // do a second pass just to remove empty directories, now that we've
        // already deleted all irrelevant files
        for entry in WalkDir::new(&root) {
            let entry = match entry.map_err(walkdir::Error::into_io_error) {
                Ok(entry) => entry,
                Err(None) => continue,
                Err(Some(err)) => return Err(err.into()),
            };

            if entry.file_type().is_dir()
                && entry.path().parent().is_some()
                && entry.path() != root
                && fs::read_dir(entry.path())?.next().is_none()
            {
                // empty directory; deleting it won't affect this iteration
                // because, by definition, it has no children to iterate on

                // triple check
                assert!(
                    entry.path().starts_with(&*crate::PROJECT_FILES_DIR),
                    "Arbitrary deletion"
                );

                fs::remove_dir(entry.path())?;
            }
        }

        conn.insert_project(self, sample, relative_rank, &modules)?;

        let first_module = modules.into_iter().map(PathBuf::from).next();

        Ok(first_module)
    }
}

impl fmt::Display for Project {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.0.fmt(f)
    }
}
