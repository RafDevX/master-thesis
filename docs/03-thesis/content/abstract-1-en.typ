As today's society develops an increasing reliance on digital systems,
information provenance itself grows in significance even beyond what is
attributed to the concrete data it is associated with. In particular, such
provenance metadata plays a meaningful role in Cybersecurity, as it often
determines where and how different kinds of information can be used: secret
inputs should usually not be publicly observable, whereas untrusted ones
commonly require sanitization before safely reaching critical parts.

This work uses information flow control techniques to model flexible static
taint analysis, focusing on detecting several patterns of confidentiality and
integrity faults. The analysis is highly specialized and tailored to the Go
programming language, centering on the sound and precise handling of a multitude
of Go constructs and functionality, within a certain subset of the language
delineating some notable exceptions and blackbox approximations.

/*
Reflection, unsafe Go, and precise happens-before reasoning for concurrency are
notably excluded, as is complicated pointer aliasing and heap location tracking,
due to time and complexity constraints. Similarly, external dependencies and
call targets without known implementations are approximated as black boxes,
under an unsound yet frequently correct assumption that outputs represent a
contextualized sum of inputs.
*/

In general, a significant share of Go programs are supported. Analysis focuses
on source code, incurs no runtime costs, and is characterized as
interprocedural, call-site sensitive, and partially flow sensitive. It considers
Go modules as its fundamental unit of operation, independently scrutinizing all
possible combinations of build-tag constraints.

// cannot use zero.num because it uses context; not for-diva-serializable
// (sym.spacing.thin, == h, is also not serializable, so we use a normal space)
Major contributions arising from this degree project include Glowy, encompassing
both the theoretical Go static taint analysis model itself and a corresponding
$35" "000$-line Rust implementation, as well as a $230$-module corpus of
correctness benchmarks illustrating possible flows in Go, and an extensive
evaluation comprising the audit of $371$ Go modules extracted from $300$ popular
open-source projects that identified true security vulnerabilities affecting
both confidentiality and integrity, such as credential leakage and Server-Side
Request Forgery issues.

Focus is put on balancing the soundness-precision duality while prioritizing
usability, efficiency, and flexibility, including through a novel opt-in axes
system that supports complex use cases without compromising simplicity.

Overall, Go static taint analysis based on expressive security controls shows
promising results and brings real security value.
