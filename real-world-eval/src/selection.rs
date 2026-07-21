use std::{collections::HashSet, fs};

use crate::{
    datasets,
    db::DbConn,
    errors::AppResult,
    modules::Module,
    network::NetworkClient,
    samples::{Band, Sample},
};

pub fn next_module(conn: &mut DbConn, client: &NetworkClient) -> AppResult<Option<Module>> {
    if let Some(pending) = conn.first_pending_module()? {
        // there might be modules pending analysis (e.g., if a project had
        // multiple modules, or if we crashed in the middle of analysis), so
        // start with those first until we run out of pending modules
        return Ok(Some(pending));
    }

    // we try to alternate between datasets by choosing the first one with least
    // analyzed projects so far, but cannot choose a dataset with no remaining
    // outstanding projects to analyze, so we need to exclude those
    let mut excluding = HashSet::new(); // cheap until first insert

    while let Some(sample) = next_sample(conn, &excluding)? {
        while let Some(project) = sample.next_project(conn)? {
            let Some(first_module) = project.init(&sample, conn, client)? else {
                // no modules found in this project; move on to the next one
                continue;
            };

            return Ok(Some(Module::new(first_module, project)));
        }

        // nothing left in this sample; use the next one available
        excluding.insert(sample.key());

        // before switching to a new  sample, we delete all project files so we
        // don't accumulate too many (and this is a safe point to do it)
        fs::remove_dir_all(crate::PROJECT_FILES_DIR.as_path())?;
        fs::create_dir_all(crate::PROJECT_FILES_DIR.as_path())?;
        // ^ deleting and recreating is easier than looping through its children
        // to delete each of them, even if it does not really support symlinks
    }

    // no datasets have outstanding projects, so we're done
    Ok(None)
}

fn next_sample(conn: &DbConn, excluding: &HashSet<(&str, Band)>) -> AppResult<Option<Sample>> {
    let counts = conn.project_count_per_sample()?;

    let min = counts
        .iter()
        .filter(|(dataset_key, band, _)| !excluding.contains(&(dataset_key, *band)))
        .min_by_key(|(_, _, count)| *count)
        .map(|(dataset_key, band, _)| (dataset_key, band));

    for dataset in datasets::ALL {
        let key = dataset.key();

        let is_fully_excluded = excluding
            .iter()
            .filter(|(excluded_key, _)| *excluded_key == key)
            .count()
            == Band::N_BANDS;

        if !is_fully_excluded && min.is_none_or(|(min_key, _)| dataset.key() == min_key) {
            let band = min.map_or(Band::I, |(_, min_band)| *min_band);

            return Ok(Some(Sample::new(*dataset, band)));
        }
    }

    Ok(None)
}
