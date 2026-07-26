use std::fs;

use crate::{
    datasets::ProjectDownloadMetadata,
    errors::{AppError, AppResult},
    projects::Project,
};

#[expect(clippy::panic_in_result_fn, reason = "Triple-check before delete")]
pub fn download_project_from_git_remote(project: &Project) -> AppResult<ProjectDownloadMetadata> {
    let target = crate::PROJECT_FILES_DIR.join(project.as_base());

    if fs::exists(&target)? {
        return Err(AppError::ProjectDownloadTargetAlreadyExists {
            project: project.to_string(),
        });
    }

    // parent directories need to exist for clone to work, and it's OK if the
    // actual leaf directory also exists (as long as it's empty)
    fs::create_dir_all(&target)?;

    // avoid cloning rich git history when we won't ever use it
    let mut fetch_opts = git2::FetchOptions::new();
    fetch_opts.depth(1);

    // we don't specify any other options so that git automatically clones using
    // the remote's default branch, which will become our local default branch
    let repo = git2::build::RepoBuilder::new()
        .fetch_options(fetch_opts)
        .clone(project.url().as_str(), &target)?;

    let head = repo.head()?;
    let default_branch = head.resolve()?;
    let default_branch_name = default_branch.name()?.to_owned();
    let rev_hash = default_branch.target().as_ref().map(git2::Oid::to_string);

    // we don't need this anymore
    let git_dir = target.join("./.git");
    // triple check
    assert!(
        git_dir.starts_with(crate::PROJECT_FILES_DIR.as_path()),
        "Arbitrary deletion"
    );
    fs::remove_dir_all(git_dir)?;

    let metadata = ProjectDownloadMetadata {
        root: target,
        rev_name: default_branch_name,
        rev_hash,
    };

    Ok(metadata)
}
