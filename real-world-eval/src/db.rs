use std::path::{Path, PathBuf};

use rusqlite::{OptionalExtension, params};

use crate::{
    errors::{AppError, AppResult},
    projects::Project,
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

            CREATE TABLE IF NOT EXISTS "modules" (
                path TEXT PRIMARY KEY,
                project TEXT NOT NULL
                    REFERENCES projects(url),
                sloc INTEGER,
                pending INTEGER NOT NULL DEFAULT 1
                    CHECK (pending IN (0, 1))
            ) STRICT;
            "#,
        )?;

        Ok(())
    }

    pub fn first_pending_module(&self) -> AppResult<Option<PathBuf>> {
        let pending: Option<String> = self
            .0
            .query_one(
                r#"
                SELECT path
                FROM modules
                WHERE pending
                ORDER BY path
                LIMIT 1
                "#,
                [],
                extract_single,
            )
            .optional()?;

        Ok(pending.map(PathBuf::from))
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
}

fn extract_single<T: rusqlite::types::FromSql>(row: &rusqlite::Row<'_>) -> rusqlite::Result<T> {
    row.get(0)
}
