#import "../utils/dependencies.typ": fletcher, zero
#import "../utils/enum-refs.typ": enum-label, wrapped-enum-numbering

#let source = what => box(fill: fuchsia, text(fill: black)[#what \[?\]])

= Introduction <intro>

Cybersecurity has become increasingly important over the last decades as society
becomes more and more reliant on digital resources. All around the world,
technology adoption has led to increased dependence on critical systems that now
control infrastructure, communication networks, and other essential services,
such as governmental and institutional resources @haberzarsky2017reliance.

Digital capabilities bring extensive benefits and allow for incredible feats
when governed well, but they inevitably also become relevant targets that
can be susceptible to attacks, precisely due to their rising value in society
@liliu2021attacks.

It is thus necessary to strive towards securing and defending society's digital
resources, preventing unauthorized access and ensuring they continue to operate
as they should. In this light, *Cybersecurity* emerges as the study of how to
protect information assets, cyberspace itself, their users, and the information
communication technologies that support them @vonsolms2013cybersec.

From the definition above, it is clear that Cybersecurity has a significant
overlap with the field of *Information Security,* which concerns itself
primarily with the preservation of the *confidentiality,* the *integrity,* and
the *availability* of information @iso27000.

Confidentiality means that no unauthorized users, computers, and processes
(generically, "principals") may access the information in question, while
integrity safeguards that the information remains accurate and complete, and
availability refers to the information being accessible and usable on demand
by authorized principals.

These three properties, collectively known as the _CIA triad,_ represent the
chief qualities desired from most information systems, thus justifying their
central roles in Information Security and qualifying them as prime targets for
Cybersecurity developments across the field. It is crucial to continuously work
towards a balanced improvement of each of these three properties without
sacrificing any of the others.

In particular, the properties of confidentiality and integrity are similar in
that they both imply the categorization of information, with the former
requiring the distinction of _secret_ information from what is _public_, while
the latter separates _trusted_ (and accurate) information from _untrusted_
information (which is not necessarily accurate and should, for example, be
rejected or treated differently during an update operation).

Importantly, this requires differentiating between different "colors" of
information, which is not trivial: for example, the very same bits can be
trusted or not depending on their provenance, but origin is not measurable or
derivable from the information itself, so it must be tracked indirectly. This is
because "color" is not a property inherent to information, but rather metadata
that is independent to its nature.

The present "color" analogy, adapted from Skala's "What Colour are your bits?"
essay about copyright law @skala2004colour, illustrates how at times it is
desirable to reason about a property even if it does not physically exist, since
metadata can sometimes be more relevant than the actual data it describes.

For instance, a program outputting the number $4200$ because it was chosen by
its internal random number generation pipeline is very different from another
program outputting $4200$ because it is a user's passcode. Even though their
outputs are indistinguishable, one $4200$ is not the same as the other $4200$
because of what they imply: knowing that there is a link between the output and
a secret is key for security relevance and exploitability.

Determining whether such a link exists, however, is not simple: it requires
taking into account all possible factors that can influence a program's output,
which is hard and complex for a human to do, especially given a sufficiently
large codebase. It follows, then, that tracking "color" should be automated as a
computer-assisted process, artificially making derivable a property that does
not truly exist, but can still have real impact on a program's security.

This work applies @ifc techniques to identify certain confidentiality and
integrity faults in arbitrary programs written in Go (or rather, a subset
thereof). This is useful for both developers and security
auditors, helping promote Information Security and Cybersecurity in an
increasingly digital society.

#pagebreak()

== Problem Statement

The Go programming language, often referred to as Golang, was
created by Google in 2007 @pike2012go and has recently seen extensive adoption
across a wide array of applications. Go is widespread in modern
development @stackoverflow2025 @ufliand2025jetbrains and has been consistently
trending upwards in popularity since its release @beuke2023githut.

Given the extensive (and growing) prevalence of Go, it becomes necessary to
ensure there are sufficient security tools to support the community and
ecosystem in detecting potential vulnerabilities, as the latter's numbers and
impact will inevitably rise proportionally to the flourishing adoption of Go,
especially in core services, libraries, and applications.

Furthermore, as stated above, in order to safeguard confidentiality, integrity,
and (to a somewhat lesser extent) availability, it is necessary to always assess
a program's outputs (as well as what they depend on) and inputs (as well as what
they affect), distinguishing throughout the course of each execution path what
is secret from what is public, and what is trusted from what is not.

However, it is difficult for programmers and reviewers to always keep track of
these subtle distinctions (differences in "color", per the analogy above),
especially in large and complex codebases with many layers of abstraction: for
instance, adding some secret key to an application state object for access
convenience might make another part of the code insecure if the whole state
object is being sent to a third party, making this change insecure and
unacceptable even if at a glance it may seem innocuous (e.g., from the diff).

Thus, it is better to automate this kind of checks so that they can run often,
systematically, and robustly. This reduces human error and significantly
lightens the necessary mental load to acquiring a satisfactory level of
confidence in a program's security, helping find problems that could otherwise
have been missed by a cursory human consideration.

As such, there is a clear need for security tooling that can assist developers,
reviewers, and security auditors at detecting potential problems and vulnerabilities in applications and libraries written in Go, tracking
information flow to identify possible lapses in confidentiality or integrity.

Information flow checks are important because they can detect and minimize an
entire class of vulnerabilities in Go. Tooling as described above could have
prevented a number of past security issues, such as five Kubernetes
vulnerabilities regarding secret leakage @cve20208563kubernetes
@cve20208564kubernetes @cve20208565kubernetes @cve20208566kubernetes
@cve20257445kubernetes.

#pagebreak()

== Research Questions

This degree project aims to answer the following research questions:

#[
  #set enum(
    full: true,
    numbering: wrapped-enum-numbering(
      // we need a custom ref numbering so refs don't have a trailing `.`
      ref-numbering: (..nums) => strong[RQ#numbering("1.A", ..nums)],
      // this is the actual numbering displayed on the enum items (with `.`)
      (..nums) => strong[RQ#numbering("1.A.", ..nums)],
    ),
  )

  + #enum-label("rq-ifc") How to effectively track information flow in arbitrary
    Go programs through static analysis?
    + #enum-label("rq-ifc-confidentiality") How to systematically detect flows
      of secret data to public outputs? #smallcaps[(Confidentiality)]
    + #enum-label("rq-ifc-integrity") How to systematically detect flows of
      untrusted inputs to critical parts? #smallcaps[(Integrity)]
  + #enum-label("rq-scaffold") How to reliably scaffold reasonable security
    policies for arbitrary Go projects without domain-specific knowledge, as a
    starting point before human intervention?
  + #enum-label("rq-min-config") Can information flow analysis effectively
    identify true security vulnerabilities in Go projects with minimal
    configuration or domain-specific knowledge?
  + #enum-label("rq-prevalence") How prevalent are detectable security issues in
    popular production-grade applications and libraries written in Go?
]

These research questions reflect the implementation and validation of the
proposed solution to the problem previously stated.

#place(dy: -5%, box(
  fill: orange,
)[have a subsection per research question here, or in another
  chapter like methodology? explaining them in detail])

== Purpose

This project's central objective is to establish a robust framework to
systematically and effectively track information flow in Go programs, detecting
potential faults in confidentiality and integrity at sufficient speed that the
analysis can be integrated into a feedback loop for developers and reviewers.

Ideally, this analysis framework should be reasonably useful even with minimal
configuration, and improve in accuracy even further proportionally to how much
domain-specific information the user makes available. This allows for a scalable
mass analysis of high-profile Go programs, in search for data on vulnerability
prevalence and validation of the technique employed.

This purpose benefits the research field and the engineering community because
it promotes the development of sound analysis algorithms for a variety of
constructs, in addition to the collection of data that may be relevant for
similar research in Go. Moreover, this is beneficial for the Software
Engineering industry since it puts forward substantial work towards more secure
Go software, requiring less human effort in security consciousness.

#pagebreak()

== Goals

Given the research questions and the purpose laid out above, the following
primary project goals are established:

#[
  #set enum(
    full: true,
    numbering: wrapped-enum-numbering(
      // we need a custom ref numbering so refs don't have a trailing `.`
      ref-numbering: (..nums) => strong[PG#numbering("1.A", ..nums)],
      // this is the actual numbering displayed on the enum items (with `.`)
      (..nums) => strong[PG#numbering("1.A.", ..nums)],
    ),
  )

  + #enum-label("pg-tool") Develop a tool applying @ifc techniques to perform
    static analysis of Go programs, reporting potential vulnerabilities as
    output if any are detected, with support for focus on both confidentiality
    and integrity.
  + #enum-label("pg-scaffold") Determine an appropriate way to easily scaffold
    reasonable (even if imperfect) security policies for arbitrary Go programs,
    specifically to use as input for the aforementioned tool.
  + #enum-label("pg-evaluation") Evaluate the developed materials by trying to
    make use of them to audit popular production-grade Go applications and
    libraries.
  + #enum-label("pg-interpret") Interpret the results obtained from the
    evaluation step and attempt to draw conclusions regarding the applicability
    of @ifc in Go.
]

These goals, bound to the project scope, represent the general approach taken in
order to answer the relevant research questions.

== Contributions

This degree project brings forth a number of noteworthy contributions, all
developed in connection to the aforementioned research questions and project
goals. This section presents an overview of each of them, including how they
relate to each other.

Firstly, *`glowy`,* a Rust library for static analysis of information flows
within Go modules and enforcement of custom security policies. It supports a
significant number of major Go constructs, allowing invokers to identify
potential security issues relating to breaches of both confidentiality and
integrity. If a problem is reported, it is always accompanied by a structured
representation of all relevant contextual information. Additionally, the
library's public interface is carefully and exhaustively documented#footnote[The
  most recent version has its documentation mirrored at
  #link("https://glowy.rso.pt/").]
to maximize ease of use and reduce friction for both onboarding and debugging.

Secondly, *`glowy-parser`,* a Rust library capable of parsing source code
written in (a subset of) Go, processing raw text into structured @ast nodes
representing the underlying Go constructs, for easier manipulation. The parser
is oriented towards this project's specific needs (i.e., information flow
analysis), but it is still generic enough that it could be used for other
applications requiring a structured understanding of Go programs. This library
has extensive unit tests and is used by the `glowy` library to parse each Go
file in the input module(s).

Thirdly, *`ifc-tests`,* a collection of several test suites (written in Go)
designed to showcase all the relevant behaviors, edge cases, and quirks that
need to be minded when applying @ifc techniques to Go static analysis. Each
suite is a set of test cases related to a certain topic (e.g., loops), and each
individual test case is an independent Go module clearly testing a specific
facet of what is expected from an analysis tool of this kind. These tests can be
used via `glowy-cli` (described below), but they also plug directly into the
`glowy` library's main testing pipeline (managed by `cargo`). Since all test
cases are written in plain Go source code text, any usage also indirectly tests
that the `glowy-parser` library works correctly, but this is not a main focus.

Then, *`glowy-init`,* ... #text(fill: red, lorem(140))

Finally, *`glowy-cli`,* a Rust user-facing @cli application, puts it all
together by allowing stakeholders to orchestrate the analysis of one or more Go
modules. This tool uses the `glowy` library to analyze the provided input files,
collecting the reported results and digesting them into user-friendly
diagnostics explaining each potential security problem that has been identified.
#text(fill: orange)[
  If no security policy is defined, the application proposes scaffolding one
  // with fits above
  with `glowy-init`, allowing for a simple onboarding with minimal human
  intervention.
]
Developers, reviewers, and security auditors alike can use `glowy-cli` to
execute the analyzer and easily understand its output within the context of the
codebase in question.

#pagebreak()

These five primary contributions are different components of the same machine:
even though they are each independent and can be useful on their own (especially
for other applications, such as Go-focused research in related fields), they are
designed to operate together to form the Glowy ecosystem.
@intro:contributions:relationship (below) visualizes the intended relationship
between them, with blue nodes denoting libraries (i.e., dependencies designed to
be used by other code), purple nodes representing user-facing applications, and
orange nodes referring to tests.

#figure(
  fletcher.diagram({
    import fletcher: edge, node
    import fletcher.shapes: hexagon, pill, rect

    node((0, 0), [`glowy`], shape: pill, stroke: 2pt + blue)
    edge("=>", label-side: right, [depends on])
    node((2, 0), [`glowy-parser`], shape: pill, stroke: blue)
    edge((0, 0), auto, "<=", [depends on])
    node((0, -1), [`glowy-cli`], shape: rect, stroke: purple)
    node((-1, 0), [`ifc-tests`], shape: hexagon, stroke: orange)
    edge(auto, (0, -1), "--|>", stroke: orange, [tests])
    edge(auto, (0, 0), "--|>", stroke: orange, [tests])
    node((2, -1), [`glowy-init`], shape: pill, stroke: blue)
    edge(auto, (0, -1), "<=", [depends on])
  }),
  caption: [Relationship between contributions],
) <intro:contributions:relationship>

Put together, these five major pieces form a substantial research contribution to
the areas of Cybersecurity and Information Security, consolidating this work's
overall relevance and value to both academia and the engineering community. In
total, these components comprise approximately
#box(fill: red, zero.num(20000)) lines of Rust and Go source code.

== Scope & Limitations <intro:limitations>

The present work attempts to address as many use cases as possible, but it is
limited to its scope, inherent to a degree project. Glowy targets programs
compliant with the Go 1.26 specification @go126spec but is not focused on
validating this assumption, so incorrect programs that are provided as input
will lead to undefined behavior. However, a best-effort attempt is made to warn
the user of obvious Go errors and specification violations, despite the no
guarantees.

Furthermore, not even all specification-compliant Go programs will be accepted,
as in reality this works assumes only a subset of the Go programming language,
chosen as to represent as many core constructs as possible within the time and
complexity limitations imposed on the project. Despite an attempt to be
extensive to the greatest feasible degree, this still means that certain Go
features are unsupported, such as `goto` statements and pointers.
// not saying "subset as defined in @some-section" because introduction has to
// be self-contained and should never link to other parts of the document

This particularly applies with regard to unsafe Go code (i.e., any usage of the
`unsafe` package), which is entirely unsupported due to breaking critical
assumptions (such as type safety) and being explicitly non-portable, which could
lead to inconsistent tool outputs across different invocation platforms.

In addition, this work is focused on finding potential security vulnerabilities
and highlighting them to users (such as security auditors or developers), which
means that while reported errors can be very useful, an absence of errors cannot
be construed as an absolute endorsement that the program is fully secure. Glowy
makes no assurances of finding all possible issues.

Finally, regarding the automatic scaffolding of an initial security policy for
easy onboarding of projects without one defined, this process is extremely
coarse and does not use any domain-specific knowledge, so it is not perfect.
While an effort is made to identify sensible defaults, these are only intended
to be better (on average) than no configuration whatsoever, and should not be
construed to represent the full benefit of using Glowy when extensively
and carefully (manually) configured for a given Go project.

Nevertheless, despite the above limitations (essential due to the necessarily
reduced scope), this work still produces considerable strides within its field,
both from a scientific and an ecosystem point of view.

== Methodology

[or "Research Methodology"]

["present philosophical assumptions, research methods and approaches"]

#box(fill: orange)[not sure what concretely to say here]

#box(
  fill: purple,
)["study the state of the art to identify missing points and space to contribute to, deductive/inductive (prolly deductive or a mix of the 2), ak2030. deductive initially for first version but then empirically add support for more lang constructs etc; iterative approach small scale to big scale"]

== Ethics & Sustainability

This degree project strives to adhere to high ethical standards and promote
sustainable practices, with this section outlining relevant factors and
decisions that support the work's agreement with these two areas.

Firstly, all data from external sources used throughout this project is openly
available, and all Go projects analyzed are open-source. This bolsters result
reproducibility and avoids licensing complications.

Secondly, from the very beginning of the project, a commitment has been made and
upheld to report (via responsible disclosure channels) any and all potential
security vulnerabilities to the respective project maintainers, if they are
discovered to be true security issues, especially if exploitable or particularly
impactful.
#text(fill: red)[
  It should be noted, however, that this was never deemed necessary due to no
  relevant, true vulnerability being found.
]
// ^ if the above paragraph becomes smaller, add "... for immediate patching"
// after "project maintainers" - but it's fine to keep it cut if doesn't fit

Thirdly, the Glowy library and all other contributions (such as the @cli
application) are all released as open-source software and artifacts, with the
tool and related components being made available under the MIT License
#footnote(link("https://opensource.org/license/mit")). This license is
appropriate as, in addition to currently being one of the most popular
open-source licenses @santiagocalderon2022oss, it is considered permissive and
suitable for commercial usage, making it simple for companies and other
industry players to benefit from this degree project's contributions.

Furthermore, all analysis is performed locally, the tool can easily be audited
to verify no network telemetry, and sandboxing is possible without loss of
functionality, since Glowy does not communicate with any external services. This
can give stakeholders higher confidence that no data leakage is possible,
thereby making Glowy more trusted to be used in proprietary and/or confidential
contexts, just as the MIT License does. Using Glowy does not pose an additional
(direct) risk to such sensitive projects, making it more appealing.

All in all, these conveniences and reduced barriers mean that more people and
organizations can use the tool, which is helpful to society as a whole, since
more reliance on security mechanisms is presumed to lead to more secure
software, in general. When combined with society's present day dependence on
critical software and digital systems (as described at the beginning of this
Chapter), this means that the present work comprises a development promoting
both economic and social sustainability.

By the same token, this degree project can also indirectly benefit ecological
sustainability, as it contributes towards Cybersecurity at large and so can
plausibly indirectly aid with the protection and overall resilience of
critical software, such as that for disaster relief or control of smart green
devices.

In addition, if institutional and commercial systems are made more secure
(especially with respect to confidentiality guarantees), individual users are
less likely to be affected by data leaks that compromise their private data.
All persons have a fundamental right to privacy @udhr @iccpr, including online
@ahrcres4215, and this degree project is unquestionably a step towards its
preservation.

Moreover, there is empirical evidence of low trust in digital services
@duenascid2023distrust @thales2025trust, despite their prevalence and
undeniable impact to today's society. While this is undoubtedly a consequence of
a plethora of different factors, promoting software security should presumably
have a positive effect on this matter, increasing trust in digital
infrastructure.

Finally, while there is a possibility that this project's results could be used
by malicious actors in an attempt to find exploitable vulnerabilities in
(primarily) source-available software, the defensive benefits are expected to
far outweigh the associated risks. Security tool usage supports earlier and more
scalable vulnerability detection, enabling developers and security practitioners
to remediate issues before they can be exploited, and the target class of
vulnerabilities is not novel, in any case, so it is already accessible through
manual analysis or more coarse chaining of existing tools.

== Structure of the Thesis

This document is divided into Chapters for easier readability and reference,
with the present @intro purely giving an overview of the topics under this
discussion, which are further developed throughout the rest of this report.

@bg presents relevant technical background information and related work in this
area, while @methods describes and justifies the research process applied over
the course of the project. Implementation details and design choices are
outlined in @glowy, and evaluation results are presented in @eval. Finally,
@discussion interprets and reflects on the project's results, while @conclusion
briefly summarizes and concludes this degree project report.
