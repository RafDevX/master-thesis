use std::{fmt, fs, path::PathBuf};

use crate::{
    datasets::Dataset,
    db::DbConn,
    errors::{AppError, AppResult},
    projects::Project,
};

pub struct Sample {
    dataset: &'static dyn Dataset,
    band: Band,
}

impl Sample {
    pub fn new(dataset: &'static dyn Dataset, band: Band) -> Self {
        Self { dataset, band }
    }

    pub fn dataset(&self) -> &'static dyn Dataset {
        self.dataset
    }

    pub fn band(&self) -> Band {
        self.band
    }

    pub fn key(&self) -> (&'static str, Band) {
        (self.dataset.key(), self.band)
    }

    pub fn file_name(&self) -> String {
        format!(
            "set-{}-{}-band-{}.txt",
            self.dataset.key().to_lowercase(),
            self.dataset.name().to_lowercase(),
            self.band.as_str().to_lowercase()
        )
    }

    pub fn file_path(&self) -> PathBuf {
        crate::SAMPLES_DIR.join(self.file_name())
    }

    pub fn read_projects_from_file(&self) -> AppResult<Vec<Project>> {
        let projects = fs::read_to_string(self.file_path())?
            .lines()
            .map(|entry| self.dataset.project_from_entry(entry))
            .collect::<AppResult<_>>()?;

        Ok(projects)
    }

    pub fn next_project(&self, conn: &DbConn) -> AppResult<Option<Project>> {
        let next = self
            .read_projects_from_file()?
            .into_iter()
            .find_map(|project| {
                project
                    .already_exists(conn)
                    .map(|exists| (!exists).then_some(project))
                    .transpose()
            })
            .transpose()?;

        Ok(next)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
#[expect(
    clippy::upper_case_acronyms,
    reason = "Roman numerals are not acronyms"
)]
pub enum Band {
    I,
    II,
    III,
    IV,
}

impl Band {
    pub const ALL: &[Self] = &[Self::I, Self::II, Self::III, Self::IV];

    pub fn as_str(self) -> &'static str {
        match self {
            Self::I => "I",
            Self::II => "II",
            Self::III => "III",
            Self::IV => "IV",
        }
    }
}

impl fmt::Display for Band {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}

impl TryFrom<&str> for Band {
    type Error = AppError;

    fn try_from(s: &str) -> Result<Self, Self::Error> {
        let band = match s {
            "I" | "i" => Self::I,
            "II" | "ii" => Self::II,
            "III" | "iii" => Self::III,
            "IV" | "iv" => Self::IV,
            _ => return Err(AppError::InvalidBand(s.to_owned())),
        };

        Ok(band)
    }
}
