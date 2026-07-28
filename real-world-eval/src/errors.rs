use std::{io, str};

pub type AppResult<T> = Result<T, AppError>;

#[justerror::Error]
pub enum AppError {
    DbConnectionFailed(#[source] rusqlite::Error),
    Database(#[from] rusqlite::Error),
    FileSystem(#[from] io::Error),
    Network(#[from] reqwest::Error),
    Git(#[from] git2::Error),
    InvalidBand(String),
    MalformedProjectPath(#[from] url::ParseError),
    NonUtf8Path(String),
    TriplicateModule {
        module: String,
        new_project: String,
    },
    ProjectNotInDatasetSource {
        project: String,
        dataset_key: &'static str,
    },
    ProjectDownloadTargetAlreadyExists {
        project: String,
    },
    GoProxyNoValidLatestVersion {
        project: String,
        response: String,
    },
    GoProxyCorruptedZip(#[from] zip::result::ZipError),
    ProjectFilesRootNotFound(String),
    AnalyzerExecutionFailure(#[source] io::Error),
    AnalysisOutputNotUtf8(#[from] str::Utf8Error),
}
