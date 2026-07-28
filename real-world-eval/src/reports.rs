use std::{fmt, sync::LazyLock, time};

use regex::Regex;

static BUILD_PERMUTATIONS_REGEX: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?mR)^Detected (\d+) distinct build-constraint permutations:$"#).unwrap()
});
static CONVERGENCE_ITERATIONS_REGEX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"(?mR)Finished Stage 2 in (\d+) iterations"#).unwrap());

pub struct AnalysisReport {
    status: AnalysisStatus,
    abort_reason: Option<AnalysisAbortReason>,
    n_errors: Option<usize>,
    n_warnings: Option<usize>,
    n_confidentiality_flows: Option<usize>,
    n_integrity_flows: Option<usize>,
    n_build_constraint_permutations: Option<usize>,
    min_convergence_iterations: Option<usize>,
    max_convergence_iterations: Option<usize>,
    total_convergence_iterations: Option<usize>,
    sloc: usize,
    run_time: time::Duration,
}

impl AnalysisReport {
    pub fn new_succeeded(sloc: usize, run_time: time::Duration, stdout: &str) -> Self {
        let (
            n_build_constraint_permutations,
            min_convergence_iterations,
            max_convergence_iterations,
            total_convergence_iterations,
        ) = Self::summarize_stdout(stdout);

        Self {
            status: AnalysisStatus::Succeeded,
            abort_reason: None,
            n_errors: Some(0),
            n_warnings: Some(0),
            n_confidentiality_flows: None,
            n_integrity_flows: None,
            n_build_constraint_permutations: Some(n_build_constraint_permutations),
            min_convergence_iterations: Some(min_convergence_iterations),
            max_convergence_iterations: Some(max_convergence_iterations),
            total_convergence_iterations: Some(total_convergence_iterations),
            sloc,
            run_time,
        }
    }

    pub fn new_failed(sloc: usize, run_time: time::Duration, stdout: &str, stderr: &str) -> Self {
        let (n_errors, n_warnings, n_confidentiality_flows, n_integrity_flows) =
            Self::summarize_stderr(stderr);

        let (
            n_build_constraint_permutations,
            min_convergence_iterations,
            max_convergence_iterations,
            total_convergence_iterations,
        ) = Self::summarize_stdout(stdout);

        Self {
            status: AnalysisStatus::Failed,
            abort_reason: None,
            n_errors: Some(n_errors),
            n_warnings: Some(n_warnings),
            n_confidentiality_flows: Some(n_confidentiality_flows),
            n_integrity_flows: Some(n_integrity_flows),
            n_build_constraint_permutations: Some(n_build_constraint_permutations),
            min_convergence_iterations: Some(min_convergence_iterations),
            max_convergence_iterations: Some(max_convergence_iterations),
            total_convergence_iterations: Some(total_convergence_iterations),
            sloc,
            run_time,
        }
    }

    pub fn new_aborted(sloc: usize, run_time: time::Duration, reason: AnalysisAbortReason) -> Self {
        Self {
            status: AnalysisStatus::Aborted,
            abort_reason: Some(reason),
            n_errors: None,
            n_warnings: None,
            n_confidentiality_flows: None,
            n_integrity_flows: None,
            n_build_constraint_permutations: None,
            min_convergence_iterations: None,
            max_convergence_iterations: None,
            total_convergence_iterations: None,
            sloc,
            run_time,
        }
    }

    pub fn new_crashed(sloc: usize, run_time: time::Duration) -> Self {
        Self {
            status: AnalysisStatus::Crashed,
            abort_reason: None,
            n_errors: None,
            n_warnings: None,
            n_confidentiality_flows: None,
            n_integrity_flows: None,
            n_build_constraint_permutations: None,
            min_convergence_iterations: None,
            max_convergence_iterations: None,
            total_convergence_iterations: None,
            sloc,
            run_time,
        }
    }

    pub fn new_empty() -> Self {
        Self {
            status: AnalysisStatus::Empty,
            abort_reason: None,
            n_errors: None,
            n_warnings: None,
            n_confidentiality_flows: None,
            n_integrity_flows: None,
            n_build_constraint_permutations: None,
            min_convergence_iterations: None,
            max_convergence_iterations: None,
            total_convergence_iterations: None,
            sloc: 0,
            run_time: time::Duration::ZERO,
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

    pub fn status(&self) -> AnalysisStatus {
        self.status
    }

    pub fn abort_reason(&self) -> Option<AnalysisAbortReason> {
        self.abort_reason
    }

    pub fn n_errors(&self) -> Option<usize> {
        self.n_errors
    }

    pub fn n_warnings(&self) -> Option<usize> {
        self.n_warnings
    }

    pub fn n_confidentiality_flows(&self) -> Option<usize> {
        self.n_confidentiality_flows
    }

    pub fn n_integrity_flows(&self) -> Option<usize> {
        self.n_integrity_flows
    }

    pub fn n_build_constraint_permutations(&self) -> Option<usize> {
        self.n_build_constraint_permutations
    }

    pub fn min_convergence_iterations(&self) -> Option<usize> {
        self.min_convergence_iterations
    }

    pub fn max_convergence_iterations(&self) -> Option<usize> {
        self.max_convergence_iterations
    }

    pub fn total_convergence_iterations(&self) -> Option<usize> {
        self.total_convergence_iterations
    }

    pub fn sloc(&self) -> usize {
        self.sloc
    }

    pub fn run_time(&self) -> time::Duration {
        self.run_time
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum AnalysisStatus {
    Succeeded,
    Failed,
    Aborted,
    Crashed,
    Empty,
}

impl AnalysisStatus {
    pub fn key(self) -> &'static str {
        match self {
            Self::Succeeded => "S",
            Self::Failed => "F",
            Self::Aborted => "A",
            Self::Crashed => "C",
            Self::Empty => "E",
        }
    }

    pub fn should_store_output(self) -> bool {
        matches!(self, Self::Failed | Self::Aborted | Self::Crashed)
    }
}

impl fmt::Display for AnalysisStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Succeeded => write!(f, "SUCCEEDED"),
            Self::Failed => write!(f, "FAILED"),
            Self::Aborted => write!(f, "ABORTED"),
            Self::Crashed => write!(f, "CRASHED"),
            Self::Empty => write!(f, "EMPTY"),
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum AnalysisAbortReason {
    ParsingFailed,
    WorldLimitExceeded,
    BuildPermutationLimitExceeded,
}

impl AnalysisAbortReason {
    pub fn key(self) -> &'static str {
        match self {
            Self::ParsingFailed => "P",
            Self::WorldLimitExceeded => "W",
            Self::BuildPermutationLimitExceeded => "B",
        }
    }
}

impl fmt::Display for AnalysisAbortReason {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::ParsingFailed => write!(f, "PARSING"),
            Self::WorldLimitExceeded => write!(f, "WORLDS"),
            Self::BuildPermutationLimitExceeded => write!(f, "BUILD"),
        }
    }
}
