use std::path::Path;

use url::Url;

use crate::{
    datasets::{Dataset, ProjectDownloadMetadata},
    errors::AppResult,
    network::NetworkClient,
    projects::Project,
};

const SOURCE_FILE_PATH: &str = "./input-projects/by-stars/02-gitlab-repos-by-stars.txt";

pub struct GitLab;

impl Dataset for GitLab {
    fn key(&self) -> &'static str {
        "C"
    }

    fn name(&self) -> &'static str {
        "GitLab"
    }

    fn source_file_path(&self) -> &Path {
        Path::new(SOURCE_FILE_PATH)
    }

    fn project_from_entry(&self, entry: &str) -> AppResult<Project> {
        let url = Url::parse(&format!("https://gitlab.com/{entry}"))?;

        Ok(Project::new(url))
    }

    fn download_project(
        &self,
        project: &Project,
        _client: &NetworkClient,
    ) -> AppResult<ProjectDownloadMetadata> {
        super::git_generic::download_project_from_git_remote(project)
    }
}
