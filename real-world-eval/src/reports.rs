use std::{collections::HashSet, fmt, time};

use regex::regex;

pub struct AnalysisReport {
    status: AnalysisStatus,
    abort_reason: Option<AnalysisAbortReason>,
    stdout: Option<AnalysisStdoutSummary>,
    stderr: Option<AnalysisStderrSummary>,
    global_run_time: time::Duration,
    sloc: usize,
}

impl AnalysisReport {
    pub fn new_succeeded(sloc: usize, global_run_time: time::Duration, stdout: &str) -> Self {
        Self {
            status: AnalysisStatus::Succeeded,
            abort_reason: None,
            stdout: Some(AnalysisStdoutSummary::new(stdout)),
            stderr: None,
            global_run_time,
            sloc,
        }
    }

    pub fn new_failed(
        sloc: usize,
        global_run_time: time::Duration,
        stdout: &str,
        stderr: &str,
    ) -> Self {
        Self {
            status: AnalysisStatus::Failed,
            abort_reason: None,
            stdout: Some(AnalysisStdoutSummary::new(stdout)),
            stderr: Some(AnalysisStderrSummary::new(stderr)),
            global_run_time,
            sloc,
        }
    }

    pub fn new_aborted(
        sloc: usize,
        global_run_time: time::Duration,
        reason: AnalysisAbortReason,
    ) -> Self {
        Self {
            status: AnalysisStatus::Aborted,
            abort_reason: Some(reason),
            stdout: None,
            stderr: None,
            global_run_time,
            sloc,
        }
    }

    pub fn new_crashed(sloc: usize, global_run_time: time::Duration) -> Self {
        Self {
            status: AnalysisStatus::Crashed,
            abort_reason: None,
            stdout: None,
            stderr: None,
            global_run_time,
            sloc,
        }
    }

    pub fn new_empty() -> Self {
        Self {
            status: AnalysisStatus::Empty,
            abort_reason: None,
            stdout: None,
            stderr: None,
            global_run_time: time::Duration::ZERO,
            sloc: 0,
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

    pub fn n_parsed_files(&self) -> Option<usize> {
        self.stdout.as_ref().map(|summary| summary.n_parsed_files)
    }

    pub fn n_parsed_bytes(&self) -> Option<usize> {
        self.stdout.as_ref().map(|summary| summary.n_parsed_bytes)
    }

    pub fn n_distinct_build_tags(&self) -> Option<usize> {
        self.stdout
            .as_ref()
            .map(|summary| summary.n_distinct_build_tags)
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

    pub fn parsing_time(&self) -> Option<time::Duration> {
        self.stdout.as_ref().map(|summary| summary.parsing_time)
    }

    pub fn avg_stage1_time(&self) -> Option<time::Duration> {
        self.stdout.as_ref().map(|summary| summary.avg_stage1_time)
    }

    pub fn avg_stage2_time(&self) -> Option<time::Duration> {
        self.stdout.as_ref().map(|summary| summary.avg_stage2_time)
    }

    pub fn avg_stage3_time(&self) -> Option<time::Duration> {
        self.stdout.as_ref().map(|summary| summary.avg_stage3_time)
    }

    pub fn sloc(&self) -> usize {
        self.sloc
    }

    pub fn global_run_time(&self) -> time::Duration {
        self.global_run_time
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
    n_parsed_files: usize,
    n_parsed_bytes: usize,
    n_distinct_build_tags: usize,
    n_build_constraint_permutations: usize,
    min_convergence_iterations: usize,
    max_convergence_iterations: usize,
    total_convergence_iterations: usize,
    parsing_time: time::Duration,
    avg_stage1_time: time::Duration,
    avg_stage2_time: time::Duration,
    avg_stage3_time: time::Duration,
}

impl AnalysisStdoutSummary {
    #[expect(
        clippy::too_many_lines,
        reason = "Splitting would not make the code clearer"
    )]
    fn new(stdout: &str) -> Self {
        let (n_parsed_files, n_parsed_bytes) =
            regex!(r#"(?mR)^Parsing (\d+) Go file\(s\) corresponding to a total of (\d+) bytes$"#)
                .captures(stdout)
                .map(|captures| captures.extract().1)
                .map(|[files, bytes]| (files.parse().unwrap(), bytes.parse().unwrap()))
                .unwrap();

        let n_build_constraint_permutations =
            regex!(r#"(?mR)^Detected (\d+) distinct build-constraint permutations:$"#)
                .captures(stdout)
                .and_then(|captures| captures.get(1))
                .as_ref()
                .map(regex::Match::as_str)
                .map(str::parse)
                .and_then(Result::ok)
                .unwrap_or(1);
        // ^ permutation count is only printed if 2+, so we default to 1

        let distinct_build_tags: HashSet<_> =
            regex!(r#"(?mR)^\tPermutation #\d+: \d+ file\(s\) with tags = (.+)$"#)
                .captures_iter(stdout)
                .filter_map(|captures| captures.get(1))
                .map(|r#match| r#match.as_str())
                .flat_map(|full| full.split('/'))
                .map(str::trim)
                .filter_map(|constraint| constraint.strip_prefix('['))
                .filter_map(|constraint| constraint.strip_suffix(']'))
                .flat_map(|constraint| constraint.split(','))
                .map(str::trim)
                .filter(|tag| !tag.is_empty())
                .collect();

        let n_distinct_build_tags = distinct_build_tags.len();

        let n_convergence_iterations_per_permutation: Vec<_> =
            regex!(r#"(?mR)Finished Stage 2 in (\d+) iterations \((.+)\)$"#)
                .captures_iter(stdout)
                .map(|captures| captures.extract().1)
                .map(|[n, elapsed]| (n.parse::<usize>(), parse_duration(elapsed)))
                .filter_map(|(n, elapsed)| n.ok().zip(elapsed))
                .collect();

        let min_convergence_iterations = n_convergence_iterations_per_permutation
            .iter()
            .map(|(n, _)| n)
            .min()
            .copied()
            .unwrap(); // surely the Vec is not empty
        let max_convergence_iterations = n_convergence_iterations_per_permutation
            .iter()
            .map(|(n, _)| n)
            .max()
            .copied()
            .unwrap(); // surely the Vec is not empty
        let total_convergence_iterations = n_convergence_iterations_per_permutation
            .iter()
            .map(|(n, _)| n)
            .sum();

        let n_permutations = n_convergence_iterations_per_permutation
            .len()
            .try_into()
            .unwrap();

        let total_stage2_time: time::Duration = n_convergence_iterations_per_permutation
            .iter()
            .map(|(_, elapsed)| elapsed)
            .sum();
        let avg_stage2_time = total_stage2_time / n_permutations;

        let parsing_time = regex!(r#"(?mR)^Finished parsing \d+ file\(s\) in (.+)$"#)
            .captures(stdout)
            .and_then(|captures| captures.get(1))
            .and_then(|r#match| parse_duration(r#match.as_str()))
            .unwrap();

        let all_stage1_times: Vec<_> =
            regex!(r#"(?mR)Finished Stage 1 in (.+) \(deferred type resolution: .+\)$"#)
                .captures_iter(stdout)
                .filter_map(|captures| captures.get(1))
                .filter_map(|r#match| parse_duration(r#match.as_str()))
                .collect();
        let total_stage1_time: time::Duration = all_stage1_times.iter().sum();
        assert_eq!(
            all_stage1_times.len(),
            n_permutations as usize,
            "Missing datapoints"
        );
        let avg_stage1_time = total_stage1_time / n_permutations;

        let all_stage3_times: Vec<_> = regex!(r#"(?mR)Finished Stage 3 in (.+)$"#)
            .captures_iter(stdout)
            .filter_map(|captures| captures.get(1))
            .filter_map(|r#match| parse_duration(r#match.as_str()))
            .collect();
        let total_stage3_time: time::Duration = all_stage3_times.iter().sum();
        assert_eq!(
            all_stage3_times.len(),
            n_permutations as usize,
            "Missing datapoints"
        );
        let avg_stage3_time = total_stage3_time / n_permutations;

        Self {
            n_parsed_files,
            n_parsed_bytes,
            n_distinct_build_tags,
            n_build_constraint_permutations,
            min_convergence_iterations,
            max_convergence_iterations,
            total_convergence_iterations,
            parsing_time,
            avg_stage1_time,
            avg_stage2_time,
            avg_stage3_time,
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
            } else if !line.trim_start().starts_with("| ") {
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

fn parse_duration(s: &str) -> Option<time::Duration> {
    let (s, multiplier) = if let Some(s) = s.strip_suffix("ns") {
        (s, 1)
    } else if let Some(s) = s.strip_suffix("µs") {
        (s, 1000)
    } else if let Some(s) = s.strip_suffix("ms") {
        (s, 1_000_000)
    } else if let Some(s) = s.strip_suffix('s') {
        (s, 1_000_000_000)
    } else {
        return None;
    };

    let (whole, frac) = s.split_once('.').unzip();

    let whole: u128 = whole.unwrap_or(s).parse().ok()?;

    let frac_nanos = if let Some(frac) = frac {
        let digits = u32::try_from(frac.len()).ok()?;
        let divisor = 10_u128.checked_pow(digits)?;

        let frac: u128 = frac.parse().ok()?;

        frac.checked_mul(multiplier)?.checked_div(divisor)?
    } else {
        0
    };

    let nanos = whole.checked_mul(multiplier)?.checked_add(frac_nanos)?;

    Some(time::Duration::from_nanos_u128(nanos))
}
