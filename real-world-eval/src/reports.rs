use std::{fmt, sync::LazyLock, time};

use regex::Regex;

static BUILD_PERMUTATIONS_REGEX: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?mR)^Detected (\d+) distinct build-constraint permutations:$"#).unwrap()
});
static CONVERGENCE_ITERATIONS_REGEX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"(?mR)Finished Stage 2 in (\d+) iterations"#).unwrap());

pub struct AnalysisReport {
    results: Option<AnalysisResultsSummary>,
    sloc: usize,
    run_time: time::Duration,
}

impl AnalysisReport {
    pub fn new_succeeded(sloc: usize, run_time: time::Duration, stdout: &str) -> Self {
        let results = AnalysisResultsSummary::new_succeeded(stdout);

        Self {
            results: Some(results),
            sloc,
            run_time,
        }
    }

    pub fn new_failed(sloc: usize, run_time: time::Duration, stdout: &str, stderr: &str) -> Self {
        let results = AnalysisResultsSummary::new_failed(stdout, stderr);

        Self {
            results: Some(results),
            sloc,
            run_time,
        }
    }

    pub fn new_crashed(sloc: usize, run_time: time::Duration) -> Self {
        Self {
            results: None,
            sloc,
            run_time,
        }
    }

    pub fn new_empty() -> Self {
        Self {
            results: None,
            sloc: 0,
            run_time: time::Duration::ZERO,
        }
    }

    pub fn status(&self) -> AnalysisStatus {
        match self.results.as_ref().map(|results| results.success) {
            Some(true) => AnalysisStatus::Succeeded,
            Some(false) => AnalysisStatus::Failed,
            None => {
                if self.sloc > 0 {
                    AnalysisStatus::Crashed
                } else {
                    AnalysisStatus::Empty
                }
            }
        }
    }

    pub fn n_errors(&self) -> Option<usize> {
        self.results.as_ref().map(|results| results.n_errors)
    }

    pub fn n_warnings(&self) -> Option<usize> {
        self.results.as_ref().map(|results| results.n_warnings)
    }

    pub fn n_confidentiality_flows(&self) -> Option<usize> {
        self.results
            .as_ref()
            .map(|results| results.n_confidentiality_flows)
    }

    pub fn n_integrity_flows(&self) -> Option<usize> {
        self.results
            .as_ref()
            .map(|results| results.n_integrity_flows)
    }

    pub fn n_build_constraint_permutations(&self) -> Option<usize> {
        self.results
            .as_ref()
            .map(|results| results.n_build_constraint_permutations)
    }

    pub fn min_convergence_iterations(&self) -> Option<usize> {
        self.results
            .as_ref()
            .map(|results| results.min_convergence_iterations)
    }

    pub fn max_convergence_iterations(&self) -> Option<usize> {
        self.results
            .as_ref()
            .map(|results| results.max_convergence_iterations)
    }

    pub fn total_convergence_iterations(&self) -> Option<usize> {
        self.results
            .as_ref()
            .map(|results| results.total_convergence_iterations)
    }

    pub fn sloc(&self) -> usize {
        self.sloc
    }

    pub fn run_time(&self) -> time::Duration {
        self.run_time
    }
}

struct AnalysisResultsSummary {
    success: bool,
    n_errors: usize,
    n_warnings: usize,
    n_confidentiality_flows: usize,
    n_integrity_flows: usize,
    n_build_constraint_permutations: usize,
    min_convergence_iterations: usize,
    max_convergence_iterations: usize,
    total_convergence_iterations: usize,
}

impl AnalysisResultsSummary {
    pub fn new_succeeded(stdout: &str) -> Self {
        let (
            n_build_constraint_permutations,
            min_convergence_iterations,
            max_convergence_iterations,
            total_convergence_iterations,
        ) = Self::summarize_stdout(stdout);

        Self {
            success: true,
            n_errors: 0,
            n_warnings: 0,
            n_confidentiality_flows: 0,
            n_integrity_flows: 0,
            n_build_constraint_permutations,
            min_convergence_iterations,
            max_convergence_iterations,
            total_convergence_iterations,
        }
    }

    pub fn new_failed(stdout: &str, stderr: &str) -> Self {
        let (
            n_build_constraint_permutations,
            min_convergence_iterations,
            max_convergence_iterations,
            total_convergence_iterations,
        ) = Self::summarize_stdout(stdout);

        let (n_errors, n_warnings, n_confidentiality_flows, n_integrity_flows) =
            Self::summarize_stderr(stderr);

        Self {
            success: false,
            n_errors,
            n_warnings,
            n_confidentiality_flows,
            n_integrity_flows,
            n_build_constraint_permutations,
            min_convergence_iterations,
            max_convergence_iterations,
            total_convergence_iterations,
        }
    }

    fn summarize_stdout(stdout: &str) -> (usize, usize, usize, usize) {
        let n_build_constraint_permutations = BUILD_PERMUTATIONS_REGEX
            .captures(stdout)
            .and_then(|captures| captures.get(1))
            .as_ref()
            .map(regex::Match::as_str)
            .map(str::parse)
            .and_then(Result::ok)
            .unwrap_or(1);
        // ^ permutation count is only printed if 2+, so we default to 1

        let n_convergence_iterations_per_permutation: Vec<usize> = CONVERGENCE_ITERATIONS_REGEX
            .captures_iter(stdout)
            .filter_map(|captures| captures.get(1))
            .map(|capture| capture.as_str().parse())
            .filter_map(Result::ok)
            .collect();

        let min_convergence_iterations = n_convergence_iterations_per_permutation
            .iter()
            .min()
            .copied()
            .unwrap(); // surely the Vec is not empty
        let max_convergence_iterations = n_convergence_iterations_per_permutation
            .iter()
            .max()
            .copied()
            .unwrap(); // surely the Vec is not empty
        let total_convergence_iterations = n_convergence_iterations_per_permutation.iter().sum();

        (
            n_build_constraint_permutations,
            min_convergence_iterations,
            max_convergence_iterations,
            total_convergence_iterations,
        )
    }

    fn summarize_stderr(stderr: &str) -> (usize, usize, usize, usize) {
        let mut n_errors = 0;
        let mut n_warnings = 0;
        let mut n_confidentiality_flows = 0;
        let mut n_integrity_flows = 0;

        for line in stderr.lines() {
            if line.starts_with("error[") {
                n_errors += 1;
            } else if line.starts_with("warning[") {
                n_warnings += 1;
            } else if !line.starts_with("   | ") {
                // if a line number is provided, then it's actually source code
            } else if line.contains("has label {secret:*}, but") {
                n_confidentiality_flows += 1;
            } else if line.contains("has label {untrusted:*}, but") {
                n_integrity_flows += 1;
            }
        }

        (
            n_errors,
            n_warnings,
            n_confidentiality_flows,
            n_integrity_flows,
        )
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum AnalysisStatus {
    Succeeded,
    Failed,
    Crashed,
    Empty,
}

impl AnalysisStatus {
    pub fn key(self) -> &'static str {
        match self {
            Self::Succeeded => "S",
            Self::Failed => "F",
            Self::Crashed => "C",
            Self::Empty => "E",
        }
    }

    pub fn should_store_output(self) -> bool {
        matches!(self, Self::Failed | Self::Crashed)
    }
}

impl fmt::Display for AnalysisStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Succeeded => write!(f, "SUCCEEDED"),
            Self::Failed => write!(f, "FAILED"),
            Self::Crashed => write!(f, "CRASHED"),
            Self::Empty => write!(f, "EMPTY"),
        }
    }
}
