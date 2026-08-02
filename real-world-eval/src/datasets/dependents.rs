use std::{fs, path::Path, sync::LazyLock};

use regex::Regex;
use url::Url;

use crate::{
    datasets::{Dataset, ProjectDownloadMetadata},
    errors::{AppError, AppResult},
    network::NetworkClient,
    projects::{Project, ProjectVersion},
};

const SOURCE_FILE_PATH: &str = "./input-projects/by-dependents/02-modules-by-dependents.txt";
const BASE_URL: &str = "https://proxy.golang.org";

static VERSION_REGEX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#""Version":"([^"]+)""#).unwrap());
static REV_HASH_REGEX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#""Hash":"([^"]+)""#).unwrap());

pub struct Dependents;

impl Dataset for Dependents {
    fn key(&self) -> &'static str {
        "A"
    }

    fn name(&self) -> &'static str {
        "Dependents"
    }

    fn source_file_path(&self) -> &Path {
        Path::new(SOURCE_FILE_PATH)
    }

    fn project_from_entry(&self, entry: &str) -> AppResult<Project> {
        let url = Url::parse(&format!("proxy://{entry}"))?;

        Ok(Project::new(url))
    }

    fn owns_project(&self, project: &Project) -> bool {
        project.url().scheme() == "proxy"
    }

    fn download_project(
        &self,
        project: &Project,
        at_version: Option<ProjectVersion>,
        client: &NetworkClient,
    ) -> AppResult<ProjectDownloadMetadata> {
        let module = project.as_base();

        let (version, rev_hash) = if let Some(at_version) = at_version {
            // we have no choice but to use the required version
            (at_version.rev_name, at_version.rev_hash)
        } else {
            // we use the latest available version
            let latest = client.get(&escape_case(format!("{BASE_URL}/{module}/@latest")))?;

            // not worth it deserializing JSON (which requires more dependencies)
            // when we can just extract what we need using regex; API won't change
            let version = VERSION_REGEX
                .captures(&latest)
                .and_then(|captures| captures.get(1))
                .as_ref()
                .map(regex::Match::as_str)
                .ok_or_else(|| AppError::GoProxyNoValidLatestVersion {
                    project: project.to_string(),
                    response: latest.clone(),
                })?;

            let rev_hash = REV_HASH_REGEX
                .captures(&latest)
                .and_then(|captures| captures.get(1))
                .as_ref()
                .map(regex::Match::as_str)
                .map(str::to_owned);

            (version.to_owned(), rev_hash)
        };

        let target = crate::PROJECT_FILES_DIR.join(format!("./{module}@{version}"));

        if fs::exists(&target)? {
            return Err(AppError::ProjectDownloadTargetAlreadyExists {
                project: project.to_string(),
            });
        }

        let zip = client.download(&escape_case(format!(
            "{BASE_URL}/{module}/@v/{version}.zip"
        )))?;

        let mut zip = zip::ZipArchive::new(zip)?;

        zip.extract(crate::PROJECT_FILES_DIR.as_path())?;

        let version = ProjectVersion {
            rev_name: version,
            rev_hash,
        };

        let metadata = ProjectDownloadMetadata {
            root: target,
            version,
        };

        Ok(metadata)
    }
}

// server rejects any non-escaped uppercase letters
fn escape_case(s: impl AsRef<str>) -> String {
    let s = s.as_ref();

    let mut escaped = String::with_capacity(s.len());

    for ch in s.chars() {
        if ch.is_uppercase() {
            escaped.push('!');
            escaped.extend(ch.to_lowercase());
        } else {
            escaped.push(ch);
        }
    }

    escaped
}
