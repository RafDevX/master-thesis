use std::{fmt, time};

pub struct AnalysisReport {
    results: Option<AnalysisResultsSummary>,
    sloc: usize,
    run_time: time::Duration,
}

impl AnalysisReport {
    pub fn new_succeeded(sloc: usize, run_time: time::Duration) -> Self {
        let results = AnalysisResultsSummary {
            success: true,
            n_errors: 0,
            n_warnings: 0,
            n_confidentiality_flows: 0,
            n_integrity_flows: 0,
        };

        Self {
            results: Some(results),
            sloc,
            run_time,
        }
    }

    pub fn new_failed(
        sloc: usize,
        run_time: time::Duration,
        n_errors: usize,
        n_warnings: usize,
        n_confidentiality_flows: usize,
        n_integrity_flows: usize,
    ) -> Self {
        let results = AnalysisResultsSummary {
            success: false,
            n_errors,
            n_warnings,
            n_confidentiality_flows,
            n_integrity_flows,
        };

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

    pub fn status(&self) -> AnalysisStatus {
        match self.results.as_ref().map(|results| results.success) {
            Some(true) => AnalysisStatus::Succeeded,
            Some(false) => AnalysisStatus::Failed,
            None => AnalysisStatus::Crashed,
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
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum AnalysisStatus {
    Succeeded,
    Failed,
    Crashed,
}

impl AnalysisStatus {
    pub fn key(self) -> &'static str {
        match self {
            Self::Succeeded => "S",
            Self::Failed => "F",
            Self::Crashed => "C",
        }
    }
}

impl fmt::Display for AnalysisStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Succeeded => write!(f, "SUCCEEDED"),
            Self::Failed => write!(f, "FAILED"),
            Self::Crashed => write!(f, "CRASHED"),
        }
    }
}
