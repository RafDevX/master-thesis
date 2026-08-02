use std::{
    ffi::OsStr,
    fmt, fs, io,
    path::{Path, PathBuf},
};

use chrono::Utc;
use url::Url;
use walkdir::WalkDir;

use crate::{
    datasets::ProjectDownloadMetadata,
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

    pub fn files_root(&self) -> AppResult<PathBuf> {
        // this is not very pretty and there is probably a better way to
        // refactor the code so this is not needed, but it works for now.
        // we assume the files root is just PROJECT_FILES_DIR + host + path,
        // which it should be for most cases, but if the original dataset source
        // is a Go Proxy then the root actually has `@{version}` on its last
        // component -- and, helpfully, this is only the case if our URL scheme
        // is "proxy". it would be cleaner to just strip the `@{version}` suffix
        // from the project root on directory creation, but that would also be
        // less sound since in theory it could clash with the same project in a
        // different dataset (not necessarily the same version)
        let naive = crate::PROJECT_FILES_DIR.join(self.as_base());

        if self.0.scheme() == "proxy"
            && let Some(parent) = naive.parent()
            && let Some(last) = naive.file_name().and_then(OsStr::to_str)
        {
            for entry in fs::read_dir(parent)? {
                let entry = entry?;
                let file_name = entry.file_name();

                let Some(file_name) = file_name.to_str() else {
                    continue;
                };

                let mut split = file_name.split('@');

                if let Some(name) = split.next()
                    && split.next().is_some()
                    && split.next().is_none()
                    && name == last
                {
                    return Ok(entry.path());
                }
            }

            Err(AppError::ProjectFilesRootNotFound(self.to_string()))
        } else {
            Ok(naive)
        }
    }

    pub fn already_exists(&self, conn: &DbConn) -> AppResult<bool> {
        conn.project_already_exists(self)
    }

    #[expect(clippy::panic_in_result_fn, reason = "Triple-check before delete")]
    pub fn init(
        &self,
        sample: &Sample,
        exclude_list: &Path,
        conn: &mut DbConn,
        client: &NetworkClient,
    ) -> AppResult<Option<PathBuf>> {
        let dataset = sample.dataset();

        let relative_rank = dataset.calculate_relative_rank_of(self)?;

        if self.is_excluded(exclude_list)? {
            println!(
                "[now: {}] Skip init project `{}` from sample {}.{} (EXCLUDED)",
                Utc::now(),
                self.0.as_str(),
                dataset.key(),
                sample.band().as_str(),
            );

            conn.skip_excluded_project(self, sample, relative_rank)?;

            return Ok(None);
        }

        println!(
            "[now: {}] Init project `{}` from sample {}.{} (rank {}/100)",
            Utc::now(),
            self.0.as_str(),
            dataset.key(),
            sample.band().as_str(),
            relative_rank
        );

        let ProjectDownloadMetadata { root, version } = dataset.download_project(self, client)?;

        let mut modules = Vec::new();

        for entry in WalkDir::new(&root) {
            let entry = entry.map_err(io::Error::from)?;

            #[expect(
                clippy::filetype_is_file,
                reason = "We want to exclude symlinks (could point to outside project)"
            )]
            if !entry.file_type().is_file() {
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

                if relative.starts_with("vendor/") || relative.contains("/vendor/") {
                    continue;
                }

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
                    entry.path().starts_with(crate::PROJECT_FILES_DIR.as_path()),
                    "Arbitrary deletion"
                );

                fs::remove_file(entry.path())?;
            }
        }

        // do a second pass just to remove empty directories, now that we've
        // already deleted all irrelevant files (we enable contents-first mode
        // since otherwise higher-level empty directories would not be deleted)
        for entry in WalkDir::new(&root).contents_first(true) {
            let entry = entry.map_err(io::Error::from)?;

            if entry.file_type().is_dir()
                && entry.path().parent().is_some()
                && entry.path() != root
                && fs::read_dir(entry.path())?.next().is_none()
            {
                // empty directory; deleting it won't affect this iteration
                // because, by definition, it has no children to iterate on

                // triple check
                assert!(
                    entry.path().starts_with(crate::PROJECT_FILES_DIR.as_path()),
                    "Arbitrary deletion"
                );

                fs::remove_dir(entry.path())?;
            }
        }

        let first_new_module = conn.insert_project(
            self,
            sample,
            relative_rank,
            &version, // rev info
            &modules,
        )?;

        Ok(first_new_module.map(PathBuf::from))
    }

    fn is_excluded(&self, exclude_list_path: &Path) -> AppResult<bool> {
        let list = match fs::read_to_string(exclude_list_path) {
            Ok(list) => list,
            Err(err) if err.kind() == io::ErrorKind::NotFound => return Ok(false),
            Err(err) => return Err(err.into()),
        };

        for line in list.lines() {
            let line = line
                .split_once('#')
                .map_or(line, |(before, _)| before)
                .trim();

            if !line.is_empty() && line == self.url().as_str() {
                return Ok(true);
            }
        }

        Ok(false)
    }
}

impl fmt::Display for Project {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.0.fmt(f)
    }
}

pub struct ProjectVersion {
    pub rev_name: String,
    pub rev_hash: Option<String>,
}
