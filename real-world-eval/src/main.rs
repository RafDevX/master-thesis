// Clippy lint configuration
#![warn(
    // Lint Groups
    clippy::all,
    clippy::pedantic,
    clippy::cargo,
    // From clippy::restriction (should not be enabled as a group)
    clippy::allow_attributes,
    clippy::allow_attributes_without_reason,
    clippy::as_underscore,
    clippy::assertions_on_result_states,
    clippy::cfg_not_test,
    clippy::clone_on_ref_ptr,
    clippy::create_dir,
    clippy::dbg_macro,
    clippy::decimal_literal_representation,
    clippy::default_numeric_fallback,
    clippy::deref_by_slicing,
    clippy::doc_include_without_cfg,
    clippy::doc_paragraphs_missing_punctuation,
    clippy::empty_enum_variants_with_brackets,
    clippy::empty_structs_with_brackets,
    clippy::error_impl_error,
    clippy::exit,
    clippy::field_scoped_visibility_modifiers,
    clippy::filetype_is_file,
    clippy::float_cmp_const,
    clippy::fn_to_numeric_cast_any,
    clippy::get_unwrap,
    clippy::infinite_loop,
    clippy::iter_over_hash_type,
    clippy::lossy_float_literal,
    clippy::map_err_ignore,
    clippy::map_with_unused_argument_over_ranges,
    clippy::missing_assert_message,
    clippy::missing_inline_in_public_items,
    clippy::mixed_read_write_in_expression,
    clippy::mod_module_files,
    clippy::module_name_repetitions,
    clippy::multiple_inherent_impl,
    clippy::multiple_unsafe_ops_per_block,
    clippy::panic_in_result_fn,
    clippy::partial_pub_fields,
    clippy::pathbuf_init_then_push,
    clippy::precedence_bits,
    clippy::pub_without_shorthand,
    clippy::rc_buffer,
    clippy::rc_mutex,
    clippy::redundant_test_prefix,
    clippy::redundant_type_annotations,
    clippy::ref_patterns,
    clippy::renamed_function_params,
    clippy::rest_pat_in_fully_bound_structs,
    clippy::return_and_then,
    clippy::same_name_method,
    clippy::semicolon_inside_block,
    clippy::shadow_same,
    clippy::shadow_unrelated,
    clippy::str_to_string,
    clippy::string_lit_chars_any,
    clippy::string_slice,
    clippy::suspicious_xor_used_as_pow,
    clippy::tests_outside_test_module,
    clippy::todo,
    clippy::try_err,
    clippy::undocumented_unsafe_blocks,
    clippy::unnecessary_safety_comment,
    clippy::unnecessary_safety_doc,
    clippy::unnecessary_self_imports,
    clippy::unneeded_field_pattern,
    clippy::unseparated_literal_suffix,
    clippy::unused_result_ok,
    clippy::verbose_file_reads,
    clippy::wildcard_enum_match_arm,
    // From clippy::nursery (check for open issues before enabling each lint)
    clippy::branches_sharing_code,
    clippy::clear_with_drain,
    clippy::collection_is_never_read,
    clippy::debug_assert_with_mut_call,
    clippy::derive_partial_eq_without_eq,
    clippy::doc_link_code,
    clippy::equatable_if_let,
    clippy::fallible_impl_from,
    clippy::iter_on_empty_collections,
    clippy::iter_on_single_items,
    clippy::iter_with_drain,
    clippy::large_stack_frames,
    clippy::literal_string_with_formatting_args,
    clippy::needless_collect,
    clippy::nonstandard_macro_braces,
    clippy::or_fun_call,
    clippy::path_buf_push_overwrite,
    clippy::redundant_clone,
    clippy::redundant_pub_crate,
    clippy::search_is_some,
    clippy::set_contains_or_insert,
    clippy::significant_drop_in_scrutinee,
    clippy::significant_drop_tightening,
    clippy::single_option_map,
    clippy::string_lit_as_bytes,
    clippy::suboptimal_flops,
    clippy::suspicious_operation_groupings,
    clippy::too_long_first_doc_paragraph,
    clippy::trait_duplication_in_bounds,
    clippy::trivial_regex,
    clippy::tuple_array_conversions,
    clippy::type_repetition_in_bounds,
    clippy::unnecessary_struct_initialization,
    clippy::unused_peekable,
    clippy::unused_rounding,
    clippy::use_self,
    clippy::useless_let_if_seq,
    clippy::while_float,
)]
#![expect(clippy::cargo_common_metadata, reason = "Not for publication")]
#![expect(
    clippy::multiple_crate_versions,
    reason = "Pending new release of rsqlite-vfs (see its PR #178)"
)]
#![expect(
    clippy::needless_raw_string_hashes,
    reason = "More distinguishable and consistent SQL queries"
)]

use std::{
    collections::HashSet,
    env, fs,
    io::{self, Write},
    path::{self, PathBuf},
    process::Command,
    sync::LazyLock,
};

use crate::{
    db::DbConn,
    errors::AppResult,
    network::NetworkClient,
    samples::{Band, Sample},
};

mod datasets;
mod db;
mod errors;
mod network;
mod projects;
mod samples;

macro_rules! absolute_path {
    ($name:ident = $path:expr) => {
        static $name: LazyLock<PathBuf> = LazyLock::new(
            || path::absolute(PathBuf::from($path)).unwrap(), // might not exist
        );
    };
}

absolute_path!(DB_FILE = "./data.sqlite");
absolute_path!(SAMPLES_DIR = "./input-projects/sampled");
absolute_path!(PROJECT_FILES_DIR = "./project-files");

#[expect(clippy::panic_in_result_fn, reason = "More user-friendly error")]
fn main() -> AppResult<()> {
    let Some(binary) = env::args().nth(1) else {
        panic!("[FATAL] Missing path to Glowy's executable binary as first argument");
    };

    fs::create_dir_all(PROJECT_FILES_DIR.as_path())?;

    let mut conn = db::DbConn::init(DB_FILE.as_path())?;

    let client = NetworkClient::new()?;

    let output = Command::new(binary)
        .env_clear()
        .output()
        .expect("Failed to execute Glowy");

    io::stdout().write_all(&output.stdout).unwrap();
    io::stdout().write_all(&output.stderr).unwrap();

    println!("Hello, world!");

    println!("{:?}", next_module(&mut conn, &client));

    Ok(())
}

fn next_module(conn: &mut DbConn, client: &NetworkClient) -> AppResult<Option<PathBuf>> {
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

            return Ok(Some(first_module));
        }

        // nothing left in this sample; use the next one available
        excluding.insert(sample.key());
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
