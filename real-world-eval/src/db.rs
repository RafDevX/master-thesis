use std::path::{Path, PathBuf};

use rusqlite::{OptionalExtension, params};

use crate::{
    datasets,
    errors::{AppError, AppResult},
    modules::Module,
    projects::Project,
    reports::AnalysisReport,
    samples::{Band, Sample},
};

pub struct DbConn(rusqlite::Connection);

impl DbConn {
    pub fn init<P: AsRef<Path>>(file: P) -> AppResult<Self> {
        let inner = rusqlite::Connection::open(file).map_err(AppError::DbConnectionFailed)?;

        let mut conn = Self(inner);

        conn.pragma()?;
        conn.ensure_schema()?;

        Ok(conn)
    }

    // connection-specific settings
    fn pragma(&mut self) -> AppResult<()> {
        self.0
            .pragma_update(None, "foreign_keys", true)
            .map_err(Into::into)
    }

    fn ensure_schema(&mut self) -> AppResult<()> {
        self.0.execute_batch(
            r#"
            CREATE TABLE IF NOT EXISTS projects (
                url TEXT PRIMARY KEY,
                dataset TEXT NOT NULL,
                band TEXT NOT NULL,
                relative_rank INTEGER NOT NULL
                    CHECK (relative_rank BETWEEN 0 and 100)
            ) STRICT;

            CREATE TABLE IF NOT EXISTS modules (
                path TEXT PRIMARY KEY,
                project TEXT NOT NULL
                    REFERENCES projects(url),
                pending INTEGER NOT NULL DEFAULT 1
                    CHECK (pending IN (0, 1))
            ) STRICT;

            CREATE TABLE IF NOT EXISTS reports (
                module TEXT PRIMARY KEY
                    REFERENCES modules(path),
                status TEXT NOT NULL
                    CHECK (status IN ('S', 'F', 'C')),
                n_errors INTEGER,
                n_warnings INTEGER,
                n_confidentiality_flows INTEGER,
                n_integrity_flows INTEGER,
                sloc INTEGER NOT NULL,
                run_time INTEGER NOT NULL
            ) STRICT;
            "#,
        )?;

        Ok(())
    }

    pub fn first_pending_module(&self) -> AppResult<Option<Module>> {
        let result: Option<(String, String, String)> = self
            .0
            .query_one(
                r#"
                SELECT m.path, m.project, p.dataset
                FROM modules m
                JOIN projects p
                    ON m.project = p.url
                WHERE m.pending
                ORDER BY m.path
                LIMIT 1
                "#,
                [],
                |row| row.try_into(),
            )
            .optional()?;

        let Some((path, project, dataset_key)) = result else {
            return Ok(None);
        };

        let dataset = datasets::dataset_by_key(&dataset_key).unwrap();
        let project = dataset.project_from_entry(&project)?;
        let path = PathBuf::from(path);

        Ok(Some(Module::new(path, project)))
    }

    pub fn project_count_per_sample(&self) -> AppResult<Vec<(String, Band, i64)>> {
        let mut stmt = self.0.prepare(
            r#"
            SELECT dataset, band, COUNT(*) AS project_count
            FROM projects
            GROUP BY dataset, band
            ORDER BY dataset, band
            "#,
        )?;

        stmt.query_map([], |row| row.try_into())?
            .map(|result| {
                let (dataset, band, count): (_, String, _) = result?;

                Ok((dataset, Band::try_from(band.as_str())?, count))
            })
            .collect()
    }

    pub fn project_already_exists(&self, project: &Project) -> AppResult<bool> {
        let mut stmt = self.0.prepare(
            r#"
            SELECT 1
            FROM projects
            WHERE url = ?1
            "#,
        )?;

        Ok(stmt.exists([project.url().as_str()])?)
    }

    pub fn insert_project(
        &mut self,
        project: &Project,
        sample: &Sample,
        relative_rank: u8,
        modules: &[String],
    ) -> AppResult<()> {
        let txn = self.0.transaction()?;

        txn.execute(
            r#"
            INSERT INTO projects (url, dataset, band, relative_rank)
            VALUES (?1, ?2, ?3, ?4)
            "#,
            params![
                project.url().as_str(),
                sample.dataset().key(),
                sample.band().as_str(),
                relative_rank
            ],
        )?;

        for module in modules {
            txn.execute(
                r#"
                INSERT INTO modules (path, project)
                VALUES (?1, ?2)
                "#,
                [module, project.url().as_str()],
            )?;
        }

        txn.commit()?;

        Ok(())
    }

    pub fn insert_report(&mut self, module: &Module, report: &AnalysisReport) -> AppResult<()> {
        let txn = self.0.transaction()?;

        let module_path = module.path().to_string_lossy();

        txn.execute(
            r#"
            INSERT INTO reports (
                module, status, n_errors, n_warnings,
                n_confidentiality_flows, n_integrity_flows, sloc, run_time
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
            "#,
            params![
                &module_path,
                report.status().key(),
                report.n_errors().map(into_i64_saturating),
                report.n_warnings().map(into_i64_saturating),
                report.n_confidentiality_flows().map(into_i64_saturating),
                report.n_integrity_flows().map(into_i64_saturating),
                into_i64_saturating(report.sloc()),
                into_i64_saturating(report.run_time().as_nanos())
            ],
        )?;

        txn.execute(
            r#"
            UPDATE modules
            SET pending = 0
            WHERE path = ?1
            "#,
            [module_path],
        )?;

        txn.commit()?;

        Ok(())
    }
}

fn into_i64_saturating<T>(value: T) -> i64
where
    i64: TryFrom<T>,
{
    i64::try_from(value).unwrap_or(i64::MAX)
}
