use std::{fs, path::Path, time};

use backon::BlockingRetryable;

use crate::{
    datasets::ProjectDownloadMetadata,
    errors::{AppError, AppResult},
    projects::Project,
};

const EXPONENTIAL_RETRY: backon::ExponentialBuilder = backon::ExponentialBuilder::new()
    .with_jitter()
    .with_max_times(5)
    .with_min_delay(time::Duration::from_secs(20))
    .without_max_delay();

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

    let mut builder = git2::build::RepoBuilder::new();
    builder.fetch_options(fetch_opts);

    // we don't specify any other options so that git automatically clones
    // using the remote's default branch, which will also become our local
    // default branch
    let repo = clone_repository_with_retry(&mut builder, project.url().as_str(), &target)?;

    let head = repo.head()?;
    let default_branch = head.resolve()?;
    let default_branch_name = default_branch.shorthand()?.to_owned();
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

fn clone_repository_with_retry(
    builder: &mut git2::build::RepoBuilder,
    url: &str,
    destination: &Path,
) -> AppResult<git2::Repository> {
    (|| builder.clone(url, destination))
        .retry(EXPONENTIAL_RETRY)
        .when(|err| {
            err.class() == git2::ErrorClass::Http
                && matches!(
                    err.message()
                        .strip_prefix("unexpected http status code:")
                        .map(str::trim),
                    Some("429" | "503")
                )
        })
        .notify(|_err, duration| {
            println!("Retrying git clone of `{url}` in {duration:?}");
        })
        .call()
        .map_err(Into::into)
}
