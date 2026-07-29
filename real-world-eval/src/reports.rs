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
    stdout: Option<AnalysisStdoutSummary>,
    stderr: Option<AnalysisStderrSummary>,
    sloc: usize,
    run_time: time::Duration,
}

impl AnalysisReport {
    pub fn new_succeeded(sloc: usize, run_time: time::Duration, stdout: &str) -> Self {
        Self {
            status: AnalysisStatus::Succeeded,
            abort_reason: None,
            stdout: Some(AnalysisStdoutSummary::new(stdout)),
            stderr: None,
            sloc,
            run_time,
        }
    }

    pub fn new_failed(sloc: usize, run_time: time::Duration, stdout: &str, stderr: &str) -> Self {
        Self {
            status: AnalysisStatus::Failed,
            abort_reason: None,
            stdout: Some(AnalysisStdoutSummary::new(stdout)),
            stderr: Some(AnalysisStderrSummary::new(stderr)),
            sloc,
            run_time,
        }
    }

    pub fn new_aborted(sloc: usize, run_time: time::Duration, reason: AnalysisAbortReason) -> Self {
        Self {
            status: AnalysisStatus::Aborted,
            abort_reason: Some(reason),
            stdout: None,
            stderr: None,
            sloc,
            run_time,
        }
    }

    pub fn new_crashed(sloc: usize, run_time: time::Duration) -> Self {
        Self {
            status: AnalysisStatus::Crashed,
            abort_reason: None,
            stdout: None,
            stderr: None,
            sloc,
            run_time,
        }
    }

    pub fn new_empty() -> Self {
        Self {
            status: AnalysisStatus::Empty,
            abort_reason: None,
            stdout: None,
            stderr: None,
            sloc: 0,
            run_time: time::Duration::ZERO,
        }
    }

    pub fn status(&self) -> AnalysisStatus {
        self.status
    }

    pub fn abort_reason(&self) -> Option<AnalysisAbortReason> {
        self.abort_reason
    }

    pub fn n_errors(&self) -> Option<usize> {
        self.stderr.as_ref().map(|summary| summary.n_errors)
    }

    pub fn n_warnings(&self) -> Option<usize> {
        self.stderr.as_ref().map(|summary| summary.n_warnings)
    }

    pub fn n_confidentiality_flows(&self) -> Option<usize> {
        self.stderr
            .as_ref()
            .map(|summary| summary.n_confidentiality_flows)
    }

    pub fn n_integrity_flows(&self) -> Option<usize> {
        self.stderr
            .as_ref()
            .map(|summary| summary.n_integrity_flows)
    }

    pub fn n_build_constraint_permutations(&self) -> Option<usize> {
        self.stdout
            .as_ref()
            .map(|summary| summary.n_build_constraint_permutations)
    }

    pub fn min_convergence_iterations(&self) -> Option<usize> {
        self.stdout
            .as_ref()
            .map(|summary| summary.min_convergence_iterations)
    }

    pub fn max_convergence_iterations(&self) -> Option<usize> {
        self.stdout
            .as_ref()
            .map(|summary| summary.max_convergence_iterations)
    }

    pub fn total_convergence_iterations(&self) -> Option<usize> {
        self.stdout
            .as_ref()
            .map(|summary| summary.total_convergence_iterations)
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

#[derive(Clone, Copy)]
struct AnalysisStdoutSummary {
    n_build_constraint_permutations: usize,
    min_convergence_iterations: usize,
    max_convergence_iterations: usize,
    total_convergence_iterations: usize,
}

impl AnalysisStdoutSummary {
    fn new(stdout: &str) -> Self {
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

        Self {
            n_build_constraint_permutations,
            min_convergence_iterations,
            max_convergence_iterations,
            total_convergence_iterations,
        }
    }
}

#[derive(Clone, Copy)]
#[expect(clippy::struct_field_names, reason = "Consistency with upstream")]
struct AnalysisStderrSummary {
    n_errors: usize,
    n_warnings: usize,
    n_confidentiality_flows: usize,
    n_integrity_flows: usize,
}

impl AnalysisStderrSummary {
    fn new(stderr: &str) -> Self {
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

        Self {
            n_errors,
            n_warnings,
            n_confidentiality_flows,
            n_integrity_flows,
        }
    }
}
