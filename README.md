# Rafael Oliveira's Master's Thesis

- Title: _**Glowy: Flexibly Tracking Information Flow in Go Programs**_
- Subtitle: _**Striving for Soundness, Efficiency, and Usability**_
- Supervisor: Prof. Musard Balliu (KTH)
- Examiner: Prof. Philipp Haller (KTH)
- Abstract:
  > As today's society develops an increasing reliance on digital systems,
  > information provenance itself grows in significance even beyond what is
  > attributed to the concrete data it is associated with. In particular, such
  > provenance metadata plays a meaningful role in Cybersecurity, as it often
  > determines where and how different kinds of information can be used: secret
  > inputs should usually not be publicly observable, whereas untrusted ones
  > commonly require sanitization before safely reaching critical parts.
  >
  > This work uses information flow control techniques to model flexible static
  > taint analysis, focusing on detecting several patterns of confidentiality
  > and integrity faults. The analysis is highly specialized and tailored to the
  > Go programming language, centering on the sound and precise handling of a
  > multitude of Go constructs and functionality, within a certain subset of the
  > language delineating some notable exceptions and blackbox approximations.
  >
  > In general, a significant share of Go programs are supported. Analysis
  > focuses on source code, incurs no runtime costs, and is characterized as
  > interprocedural, call-site sensitive, and partially flow sensitive. It
  > considers Go modules as its fundamental unit of operation, independently
  > scrutinizing all possible combinations of build-tag constraints.
  >
  > Major contributions arising from this degree project include Glowy,
  > encompassing both the theoretical Go static taint analysis model itself and
  > a corresponding 35 000-line Rust implementation, as well as a 230-module
  > corpus of correctness benchmarks illustrating possible flows in Go, and an
  > extensive evaluation comprising the audit of 371 Go modules extracted from
  > 300 popular open-source projects that identified true security
  > vulnerabilities affecting both confidentiality and integrity, such as
  > credential leakage and Server-Side Request Forgery issues.
  >
  > Focus is put on balancing the soundness-precision duality while prioritizing
  > usability, efficiency, and flexibility, including through a novel opt-in
  > axes system that supports complex use cases without compromising simplicity.
  >
  > Overall, Go static taint analysis based on expressive security controls
  > shows promising results and brings real security value.

---

# Overview

This work constitutes **[Rafael Serra e Oliveira](https://rso.pt)'s Degree
Project**, the capstone course of a study program leading to a **Master's Degree
in Cybersecurity** from the [KTH Royal Institute of Technology](https://kth.se)
in Stockholm, Sweden.

The project was conducted as part of the **Language-Based Security Research
Group,** which is led by [Prof. Musard Balliu](https://people.kth.se/~musard/)
within the _Theoretical Computer Science_ division of the _School of Electrical
Engineering and Computer Science_ at KTH.

# Glowy

The project's most significant contribution is **Glowy,** a static taint
analyzer for identifying potentially-insecure information flows in Go programs.
Glowy's implementation (in Rust) can be found at either of

- [KTH-LangSec/glowy repository](https://github.com/KTH-LangSec/glowy): official
  project home after Degree Project conclusion; or
- [RafDevX/glowy repository](https://github.com/RafDevX/glowy): previous
  development site and now archive of final Degree Project version.

Glowy is also published as three Rust crates:
[`glowy-cli`](https://crates.io/crates/glowy-cli),
[`glowy`](https://crates.io/crates/glowy), and
[`glowy-go-parser`](https://crates.io/crates/glowy-go-parser). The `glowy`
library crate has its documentation hosted at
[docs.rs/glowy](https://docs.rs/glowy) and at
[glowy.rso.pt](https://glowy.rso.pt) (mirror).

# Repository Structure

This repository contains all artifacts, datasets, seeds, and utility scripts
used throughout the course of the Degree Project in order to support its
research process, except for Glowy itself (linked above).

Directory [`real-world-eval/`](./real-world-eval/) contains the `glowy-eval`
evaluation orchestration utility, as well as everything relating to input
Go project selection.

Directory [`docs/`](./docs/), on the other hand, contains the
[Typst](https://typst.app) source code (and assets) for the thesis report
itself, the oral presentation slides, and other planning documents.

All deliverables, including compiled PDFs, can be found under this repository's
[Releases](https://github.com/RafDevX/master-thesis/releases).
