use std::path::{Path, PathBuf};

use crate::{errors::AppResult, projects::Project};

pub struct Module {
    path: PathBuf,
    project: Project,
}

impl Module {
    pub fn new(path: PathBuf, project: Project) -> Self {
        Self { path, project }
    }

    pub fn path(&self) -> &Path {
        self.path.as_path()
    }

    pub fn files_root(&self) -> AppResult<PathBuf> {
        let project_base = PathBuf::from(self.project.as_base());
        let suffix = self.path.strip_prefix(project_base).unwrap();

        let project_root = self.project.files_root()?;

        Ok(project_root.join(suffix))
    }
}
