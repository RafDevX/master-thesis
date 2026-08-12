= Conclusion <conclusion>

This work focuses on tracking information provenance and controlling where and
how data can be used in order to identify potential breaches to both integrity
and confidentiality. It introduces Glowy, a robust framework for systematically
and effectively tracking information flow in Go programs.

Taint analysis is employed to statically scrutinize Go source code in search of
insecure information flows between configured sources and sinks, propagating
security labels throughout the program's various execution paths, all according
to the theoretical model developed by this work to adapt @ifc:long techniques
to the Go programming language.

Contributions of relevance include a Rust implementation of the developed
analyzer, including other supporting software, a benchmarks corpus comprising
$230$ simple Go modules that showcase a particular flow or aspect relevant for
the language, a Base Security Policy of generic blanket security controls
applicable as a reasonable default before project-specific configuration, and an
evaluation step where Glowy audited $371$ popular, production-grade, open-source
Go modules.

Besides balancing the known soundness-precision duality, this work prioritizes
flexibility, usability, and specialized handling of Go language features. It
offers a novel alternative for simple and reliable auditing of Go programs,
covering use cases from the most basic to the most complex.

In an increasingly digitized society, the present degree project contributes to
stronger security practices and thus more resilient systems, supporting critical
services that power crucial capabilities for a modern way of life.
