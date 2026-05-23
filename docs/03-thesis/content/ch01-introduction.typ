= Introduction

cybersecurity is important

information security

cia triad

etc etc, very general

== Problem Statement

golang widespread and growing

hard for programmers to always keep track of what's secret/etc, especially in
large and complex codebases with many layers of abstraction (e.g., adding some
secret key to an app state object for convenience might make another part of the
code insecure if the whole object is being sent to a third party)

ideally mention high profile incidents / cves that could have been prevented by
something like this, especially in go

better to automate this kind of checks so they can run often and robustly

== Research Questions

rq1: How to effectively track information flow in arbitrary Go programs through
static analysis?

rq1.a: How to systematically detect flows of secret data to public outputs?
#smallcaps[(Confidentiality)]

rq1.b: How to systematically detect flows of untrusted inputs to critical parts?
#smallcaps[(Integrity)]

rq2: How to reliably scaffold reasonable security policies for
arbitrary Go projects without domain-specific knowledge, as a starting point
before human intervention?

rq3: Can information flow analysis effectively identify true security
vulnerabilities in Go projects with minimal configuration or domain-specific
knowledge?

rq4: How prevalent are detectable security issues in popular production-grade
tools and frameworks written in Go?

#box(fill: orange)[have a subsection per research question here, or in another
  chapter like methodology? explaining them in detail]

== Purpose & Goals

// merged because a separate Goals section would overlap significantly with the
// Contributions section, just one in the future and another in the past tense

["the purpose is to change something for the better"]

["the goals are what concretely must be done in order to achieve the purpose"]

establish a robust

good for "research" / the engineering community because ...

good for industry because ...

#box(
  fill: purple,
)[give it a shot separate goals section saying things "in the future" and then use contributions to back with data]

== Contributions

go parser in rust, oriented towards this analysis but still generic enough that
it could be used for other applications

the tool (glowy)

test suites

== Methodology

[or "Research Methodology"]

["present philosophical assumptions, research methods and approaches"]

#box(fill: orange)[not sure what concretely to say here]

#box(
  fill: purple,
)["study the state of the art to identify missing points and space to contribute to, deductive/inductive (prolly deductive or a mix of the 2), ak2030. deductive initially for first version but then empirically add support for more lang constructs etc; iterative approach small scale to big scale"]

== Scope & Limitations <intro:limitations>

target is programs compliant with go 1.26 spec, incorrect programs provided as
input lead to undefined behavior (though a best-effort attempt is made to warn
the user of obvious errors and spec violations)

even not all spec-compliant programs will be accepted, this work assumes only a
subset FancyName of the go programming language

#box(fill: orange)[where should we describe FancyName? Background? Method?]

#box(fill: purple)[Implementation chapter if needed, but Method would be good]

// not saying "subset as defined in @some-section" because introduction has to
// be self-contained and should never link to other parts of the document

this work is focused on finding potential problems and highlighting them to
users (such as security auditors or developers), which means that while reported
errors can be very useful, an absence of errors cannot be construed as an
endorsement that the program is fully secure

== Ethics & Sustainability

all data used and projects analyzed are open source

any potential security vulnerabilities discovered immediately reported
to the respective project maintainers // weird to write this in the past/future
// if it ends up being the case that we know nothing was found

analysis performed locally; tool can be sandboxed without loss of functionality

tool released as open source and licensed mit

contributes indirectly to sustainability

#box(
  fill: purple,
)[our society depends on digital infra, by making it more secure it's cool; ref of a study that companies and people don't have much trust in critical digital infra, this increases trust]

== Structure of the Thesis

X is done in Chapter Y, etc. etc.
