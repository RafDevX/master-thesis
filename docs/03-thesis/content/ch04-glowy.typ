= Glowy

tool overview

chapter overview

#box(fill: orange)[is this too much for just 1 chapter? how to split?]

== Software Design

...

=== Architecture <glowy:design:architecture>

Glowy is made up of the following primary components:
- the Glowy library
- the Glowy CLI application
- the Glowy parser
- ...

in this report, the terms "tool" and "Glowy" are sometimes used interchangeably
to refer to both the main library and the CLI application that makes use of it,
as well as the entirety of this work in general,
since in many cases they are 'equivalent' for the point being made. when
relevant and necessary, these components are explicitly disambiguated as library
and CLI application respectively

=== Usage Workflow

...

[diagram showing the steps for using cli into library into parser]

== Implementation

this section describes how different parts of the Glowy ecosystem have been
implemented. in addition to each of the components listed in
@glowy:design:architecture, other stuff (like script to generate go project
dataset) ...

=== Glowy Parser

...

=== Glowy Library

...

specific steps of the analysis algorithm described in more detail in @glowy:algo

=== Glowy CLI Application

...

=== Dataset Generator

...

== Analysis Algorithm <glowy:algo>

implementation

step-by-step, in detail

// maybe use `lovelace` package, but probably not

== Fundamental Concepts

...

=== Label Backtraces

...

=== Value Shapes

...

== Directives

...

=== Sources

...

=== Sinks

...

=== Assertions

...

== Dependency Analysis & Blackbox

...

btw special handling for github.com et al @ infer_qualifier_from_import_path

== Label Stabilization

snapshotting

...

== Construct Handling & Quirks

as part of point X in the algorithm above, it is necessary to have specific
handling of each Go construct (within FancyName). here we discuss how some
relevant ones were implemented, including design choices that had to be made

=== Qualified Operand Names

initially had separate nodes, now just treated as selections of a
PackageRefValue

=== Branching

no split branch then union

=== Loops

...

=== Methods

treated as special functions (they just have a receiver), despite being separate
things in the Go spec

=== Built-In Function Calls

...

=== Composite Values

semi-fine-grained analysis for known-constant indexes

SimpleConstValue

applies to slices, arrays, maps, ??

=== Deferred Enforcement Checks

...

== Summary

...
