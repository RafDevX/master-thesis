#import "../utils/dependencies.typ": fletcher, zero

= Methods <methods>

Given this degree project's ambitious research questions, it is imperative that
the best available methods are used at each stage of the project in order to
maximize its research and engineering value, as well as to promote its overall
success.

This chapter describes in detail the research process employed throughout the
project's implementation and evaluation, motivating each concrete elected method
and justifying why it was chosen for each applicable task.

== Research Process <methods:process>

Various research subprocesses are necessary in order to answer the research
questions presented in @intro:rq and fulfill the project goals established in
@intro:goals. These compose to form an overall workflow, as shown in
@methods:process:workflow below.

#figure(
  fletcher.diagram(node-stroke: 1pt, spacing: 2em, {
    import fletcher: edge, node
    import fletcher.shapes: diamond, pill, rect

    node((0, 0), smallcaps[#strong[A.] Start], shape: pill)
    edge("-|>")
    node(
      (1, 0),
      [#strong[B.] Implement Analyzer \ & Benchmarks \ (Initial Prototype)],
      shape: rect,
    )
    edge("-|>")
    node(
      (2, 0),
      [#strong[C.] Draft Initial \ Base Security Policy],
      shape: rect,
    )
    edge("-|>")
    node(
      (2, 1),
      [#strong[D.] Generate & Sample \ Go Project Datasets],
      shape: rect,
    )
    edge("-|>")
    node(
      (1, 1),
      [#strong[E.] Run Analyzer \ on Real-World \ Go Projects],
      shape: rect,
    )
    edge("-|>")
    node((0, 1), [#strong[F.] Inspect Results \ (Overview)], shape: rect)
    edge("-|>")
    node(
      (0, 2),
      box(inset: (y: 5pt))[#strong[G.] Major Faults?],
      shape: diamond,
    )
    edge("-|>", [Yes], label-side: right)
    node(
      (1.5, 2),
      [#strong[H.] Iteratively Implement Fixes \
        (Analyzer + Base Security Policy)],
    )
    edge((2, 2), (1, 1), "-|>")
    edge((0, 2), auto, "-|>", [No])
    node((0, 3.5), [#strong[I.] Inspect Results \ (In-Depth)], shape: rect)
    edge("-|>")
    node((1.25, 3.5), [#strong[J.] Summarize & Reflect \ on Findings])
    edge("-|>")
    node((2.25, 3.5), smallcaps[#strong[K.] End], shape: pill)
  }),
  caption: [Overview of research process workflow],
  placement: auto,
) <methods:process:workflow>

At a high level, the first major subprocess of note is the initial development
of the core Glowy analyzer, first as a theoretical model based on the careful
and thorough representation of the semantics described by the Go specification,
and then as the concrete, software-based implementation of the model into a
usable and extensible library as well as a user-facing application.

In tandem with both the theoretical modeling and the software implementation, it
is necessary to also develop several epitomic Go modules to form a corpus of
correctness benchmarks and guide development of the analyzer, testing its
functionalities as it grows, and preventing regressions.

This is, by far, the most complex and longest-running macro-scale subprocess,
spanning many months of intensive work due to its intricate and involved
requirements. It is denoted by node B in @methods:process:workflow and
correlates with @rq-ifc[] and @pg-tool[]. This subprocess is further detailed
in @methods:process:tool.

After an initial prototype is complete, the next logical step is to write an
initial draft for the analyzer's base security policy, per @rq-base-policy[] and
@pg-base-policy[]. This subprocess, represented by node C in the diagram above,
is further described in @methods:process:base-policy.

Following that, determining which real-world projects to evaluate the analyzer
against is a key subject, with real concern on the degree project's results and
their overall validity, depending on the representativeness of the universe
under sampling and the attributes exhibited by the selected Go projects. This
subprocess, indicated by node D, is crucial for supporting @rq-find-vulns[] and
@pg-evaluation[]. It is further developed in @methods:process:real-world and
@methods:collection:discovery.

After real-world Go projects have been selected for evaluating the analyzer (and
the ecosystem as a whole), the subsequent step is to execute the implemented
prototype with each of those projects as input, as the core component of
@rq-find-vulns[] and @pg-evaluation[], per node E of @methods:process:workflow.
This is also described in @methods:process:real-world below.

Next, when the analysis is complete, a cursory review of the reported results
(node F in the flowchart) is conducted in order to obtain sufficient context to
determine whether major analyzer faults are present (e.g., critical missing
features, obvious bugs, false positives based on in-scope constructs) and make
an informed decision (node G) on whether they need to be fixed and if any
applicable regression tests should be added to the benchmarks corpus.

This broad-strokes review and the subsequent adjustments made to both the
analyzer and its base security policy (node H) represent an essential iterative
process in order to improve the contributions to their best possible state or
otherwise intentionally determine certain patterns as out of scope, in either
case directly contributing to @rq-ifc[] and @pg-tool[].

This cycle of subprocesses E, F, G, and H repeats until the verdict in node G
changes and, also bearing time and complexity constraints, it is decided that
all remaining faults are considered out of the scope of the research work. In
that case, a more in-depth examination of the reported analysis results takes
place (node I of the diagram) in order to find patterns and correlations
between the different variables being tracked, so as to serve as the final piece
for @rq-find-vulns[] and @pg-evaluation[]. This subprocess is discussed in
@methods:process:real-world..

Finally, the last step in this research process is embodied by the subprocess
denoted by node J in the @methods:process:workflow flowchart, consisting of a
targeted interpretation of all the results obtained in the previous steps,
including any derived or inferred correlations between variables. This drawing
of conclusions and high-level reflections directly correlates to
@rq-prevalence[] and @pg-interpret[], and it is further developed in
@methods:process:prevalence.

=== Tool Design <methods:process:tool>

In order to answer @rq-ifc[] and fulfill @pg-tool[], it is necessarily to design
a static analysis tool capable of consuming virtually any Go program and
tracking its information flows throughout all possible code paths, as to be able
to identify any potentially insecure gadgets. In particular,
@rq-ifc-confidentiality[] and @rq-ifc-integrity[] require that both
confidentiality and integrity faults can be detected, respectively, with both of
those relying on the tracing of information provenance.

==== Core Desired Values

In addition to the substantial efficacy evidently necessary to achieve this
goal, it is also essential for the tool in question to strive towards maximum
usability, as to allow the greatest possible number of stakeholders to easily
make use of it where appropriate. This implies a need for simplicity and smooth
onboarding by means of a gentle learning curve, but also a significant degree of
flexibility in order to support more advanced use cases.

Tied to usability is also the matter of performance, since shorter run times
mean that the tool can be invoked more frequently, up to the point of entering
a project's development lifecycle. For instance, a convenient enough analyzer
can be added to automatic nightly build validation, to the Pull Request checks
required for new features to be merged, or even to a pre-commit hook on each
developer's individual workstation, yielding relevant security diagnostics as
part of an immediate feedback loop. This kind of integration and routine usage
can bring immense security benefits by catching vulnerabilities in new code
before it is even shipped.

Furthermore, one of the most crucial factors for the tool's success is its
soundness guarantees, especially in terms of how narrow the circumstances are
under which it does not detect and report manifestly insecure behavior. A high
false negative rate significantly harms a security mechanism's usefulness, so
soundness must always be a priority.

On the other hand, a useful tool cannot be too conservative either, requiring
sufficient precision to ensure a low rate of false positives, at the risk of
inducing alert fatigue that compromises the output diagnostics' credibility and
can lead to real vulnerabilities being inadvertently dismissed by stakeholders
under the impression that most or all reported security issues are
inconsequential. As such, it is important for the tool to not make too broad
assumptions about information flows, instead focusing on real propagation.

==== Comprehensiveness

The aforementioned duality between soundness and precision demands intricate and
specialized handling, which is only possible if the tool has satisfactory
individualized support for a wide range of language constructs and idiomatic
patterns.

A valuable supporting resource is therefore a broad collection of Go programs,
specially crafted to exercise a large number of features and designed to serve
as ground truth for the analyzer, promoting representativeness and ensuring
sufficient scope. Quality is of more relevance than quantity, but there should
still be an elevated degree of exhaustiveness to safeguard adequate
comprehensiveness of supported language constructs.

While it is not realistic due to the time and simplicity constraints inescapably
associated with a project of this nature to offer full language support spanning
all possibilities compliant with the Go specification with maximal soundness and
precision, it is still vital for the tool to be developed under the guiding
principle of ambition for breadth and broadness, aiming to handle as many
constructs as feasible as gracefully as possible.

In particular, precedence should, in most cases, be awarded to more commonly
used functionality, especially as use case patterns emerge from empirical
observations across real-world Go projects, in connection with
@methods:process:real-world. It is thus imperative for there to be an iterative
process under which the analyzer is developed and improved based on feedback
from it being run on real projects, as described above and represented visually
by the cycle between nodes E, F, G, and H in the diagram from
@methods:process:workflow.

The final Go subset considered for analysis is further detailed in
@methods:subset.

==== Rust <methods:process:tool:rust>

While many valid tooling alternatives exist, this degree project uses the Rust
programming language to implement the static analyzer and all other supporting
programs, given the strong reliability and robustness guarantees it offers, its
notable performance, as well as prior author familiarity.

Known for its ownership model, Rust is designed around safety, enforcing correct
(mostly implicit) memory management at compile-time, promoting explicit error
handling, as well as encouraging and simplifying resilient control-flow
structuring practices. This often includes mandatory handling of the entire
possibility space, reducing logic bugs and edge-case problems.

The language is very expressive, and idiomatic Rust code is easy to read,
conventionally prioritizing descriptive identifiers. Several clean, high-level
constructs support an intuitive codebase, while low-level utilities are still
available when necessary.

In addition, its first-class support for powerful algebraic data types (via
`enum`) makes it easier to represent many concepts important to this work, such
as @ast nodes, and allows more expressive pattern matching.

#v(1fr)
#highlight[more stuff]

#pagebreak()

==== First-Party Parser

An important point regarding the tool architecture is whether to use an existent
third-party Go parser to obtain @ast:longplural from raw textual source code,
given the task's complexity and maintainability requirements.

The Rust ecosystem does not presently have a strong native candidate: the only
relevant published crate is `go-parser`
#footnote(link("https://crates.io/crates/go-parser")), a part of the Goscript
project#footnote(link("https://github.com/oxfeeefeee/goscript")), which has
since been discontinued#footnote[A successor exists, Vo
  (#link("https://volang.dev")), but it defines its own nonstandard flavor of
  Go, therefore making its parser unsuitable for use in this work.]\;
`go-parser` has not been updated since 2023 and only has support up to Go 1.12,
which is not compatible with this degree project's goal of targeting the latest
stable release, Go 1.26.

A viable option would be to depend on Tree-sitter
#footnote(link("https://github.com/tree-sitter/tree-sitter")), a widely-used
multi-language parsing framework with a C runtime. Rust bindings
#footnote(link("https://crates.io/crates/tree-sitter")) and a Go grammar
#footnote(link("https://crates.io/crates/tree-sitter-go")) are available and
actively maintained, allowing consumers to parse Go code into queryable Rust
structures. Since is it very beneficial for analysis to be able to
pattern-match across @ast nodes, a possible solution could be to define new
@ast types for use in this work, as well as a translation mechanism to move from
string-based fields to expressive strong typing. This would result in a
controlled interface operating as a thin wrapper around Tree-sitter's existing
third-party implementation, via @ffi bindings.

However, such an approach would ultimately prove less effective than
implementing a custom project-specific first-party parser. Besides it being
simpler to build a single @ast once rather than converting a C structure into
more manageable types, most of Tree-sitter's competitive advantages are not
relevant for this use case, or even form drawbacks. For instance, Tree-sitter is
designed for performant incremental re-parsing, but that is not appropriate for
this work, which means the overhead penalty brings no additional value.
Moreover, Tree-sitter supports error recovery and partially-correct trees, but
silently analyzing an incorrectly-formed @ast is unsound and much less clear
than aborting parsing and returning an error.

#pagebreak()

In contrast, a fully-custom implementation can be much better tailored for taint
analysis, as the parser can be developed with knowledge of how its output will
be used. This also allows the parser and the analyzer to be developed in tandem,
with new semantic distinctions being added to the parser whenever they are
required by the analyzer, as part of a generalized iterative process exploiting
the tight coupling between the two components.

An owned, custom parsing procedure keeps semantic control close to the analyzer,
besides being simpler to version and distribute with the consumer, forming a
safe and native abstraction, rather than relying on @ffi with limited safety
guarantees, as is required with Tree-sitter. Customized behavior specific to the
Go language is much more convenient than generic and language-agnostic
data structuring, even if in some cases the latter could be converted into the
former for simpler and safer manipulation.

Given the points considered above, the present degree project provides a
full-fledged first-party custom parser implementation, depending on its own
parsing rules in accordance with the Go language specification @go126spec.

==== Implementation Process

Taking into account the subsections above, the analyzer's implementation is an
iterative process composed of careful development strides always conducted in
tandem with extensive testing, especially through the parallel establishment and
repeated extension of a significant number of focused correctness benchmarks in
the form of short, independent Go programs exercising different features.

The core analyzer rules for modeling information flow and enforcement are
derived from the thorough interpretation of the Go language specification,
which is this work's primary reference material and offers authoritative
guidelines for all development work.

#v(1fr)
#highlight[more stuff]

#pagebreak()

=== Base Security Policy Definition <methods:process:base-policy>

A critical complement to the analyzer itself is the security policy it is
configured to enforce during its execution. Concretely, this corresponds to the
sources, sinks, and revocation points (sanitizers) applicable to each project
under scrutiny.

While a given project's security policy is necessarily domain-specific, it is
vital for simple and swift onboarding that new projects can benefit from some
form of sensible defaults until human intervention is possible and stakeholders
with specific knowledge can adjust the defaults or define their own policy from
scratch, after they have deemed doing so worth the effort (e.g., succeeding a
trial-run of the tool where the results prove helpful).

This could be accomplished by, upon first execution, conducting an automatic
surveying of the different functionalities and @api:pl employed by the project,
and then suggesting an initial security policy appropriate for the inventoried
@api:pl. For instance, different controls are applicable if a codebase uses the
`net/http` Go package#footnote(link("https://pkg.go.dev/net/http")) for external
telemetry or if it composes raw database @sql commands via `database/sql`
#footnote(link("https://pkg.go.dev./database/sql")). Such a survey-based
customization can be granular (per @api) or based on pre-configured program
archetypes (e.g., "Web Backend Server", "@cli Application", etc.), each with
associated controls.

However, a survey-based approach as described above generates a policy that is
applicable only for that particular moment, as it can quickly become out of
date: codebases evolve over time, usually becoming more complex, and whichever
controls were suitable at the time of the @api\-aware inventory are not
necessarily still appropriate for the current state, meaning that the initial
survey would actually have to be repeated often, adding more overhead and
workload, as well as potentially giving stakeholders a false sense of security
if it is ever not up-to-date.

In alternative, this work uses a static, globally-applicable base security
policy, bypassing the need for regular project surveying by always enabling all
controls by default, since they will only ever actually manifest themselves in
codebases that use the @api:pl to which they are associated, and there is
negligible overhead for the analyzer to track all controls as always enabled,
compared to if they were only considered under detected usage. For example, even
if Go operations for fetching the value of an @http `Authorization` header
#footnote(link("https://httpwg.org/specs/rfc9110.html#field.authorization"))
are marked as information sources, this will never affect, neither semantically
nor performance-wise, any programs which have no external communication, since
they will necessarily never access such a header.

Thus, in order to answer @rq-base-policy[] and fulfill @pg-base-policy[], it is
necessary to draft specifications of information sources, enforcement sinks, and
revocation points reasonably appropriate for any average Go project which makes
use of them, so that they can be composed into a unified base security policy
and ship with the analyzer, seamlessly embedded into the tooling.

Just as with the tool itself, this process also has an iterative component where
adjustments are made based on observations from Go projects, but here the most
significant work is the initial enumeration of plausible @api:pl and common
utilities core to the Go ecosystem. Only through thorough research and
consideration can this essential piece of configuration serve its stated
purpose well before it can be manually overridden or extended for each project's
specific security requirements and risk appetite.

=== Real-World Problem Detection <methods:process:real-world>

For the purposes of answering @rq-find-vulns[] and @pg-evaluation[], it is
necessary to select a reasonable number of real-world Go projects and then
deploy the analyzer tool to inspect each of them. This is useful both as
real-world evaluation for the analyzer and as data collection regarding detected
potential vulnerabilities present in projects across and throughout the
ecosystem.

In terms of the selection process, it comprises first and foremost the
establishment of multiple independent datasets from significant sources, where
each datapoint is an individual Go project, ranked within its dataset, as
described in @methods:collection:discovery. Following that, each dataset is
stratified, with partitioning based on rank, as explained in
@methods:collection:stratification, and then each stratum is sampled in order to
obtain several separate sets of real-world projects to be targeted, per
@methods:collection:sampling.

Regarding the actual invocations of the analysis tool for each selected project,
it is useful to implement an auxiliary orchestrator to deterministically take
one of the sampled projects, download it from its dataset's associated source
repository, set up an appropriate environment, deploy the analyzer, collect and
report results and metadata (such as execution run time), store everything in a
database for later retrieval, and then repeat the same flow for the next
sampled project.

This kind of orchestration guarantees consistency and reproducibility for the
evaluation process, as well as allowing the mechanism to execute unsupervised,
as any sufficiently large sample size means long aggregate run times and makes
manual handling much less manageable, besides increasing the chances of human
error, which can skew the collected results.

For each execution, no project-specific adjustments are conducted and no
configuration is provided beyond the analyzer's own base security policy, which
is enabled by default. Relevant verbose tool output is saved for potential later
in-depth review and the analyzer is set to process no more than two build-tag
constraint permutations at once (i.e., use at most two processor cores if
applying parallelism), in an attempt to balance speed with manageable memory
usage, as well as to promote reproducibility in machines with fewer available
computational resources.

After the static analyzer has inspected each sampled project's codebase in
search for insecure information flows, all necessary results and outputs are
available and easily accessible in a structured format, such as through a
database engine. This makes it simple to perform a broad high-level review of
the collected findings, so as to trace patterns and potentially identify any
true positives, corresponding to real vulnerabilities.

=== Vulnerability Prevalence <methods:process:prevalence>

The final research method, associated with @rq-prevalence[] and @pg-interpret[],
consists of the aggregate interpretation of the results obtained from the
process described in @methods:process:real-world above, in order to
quantitatively describe the sampled corpus of real-world Go projects, in an
attempt to uncover insights and draw conclusions regarding the entire Go
ecosystem at large.

This is at its core a pattern-matching exercise, employing various statistical
tools to find interesting correlations and metrics, the foremost of which
especially related to perceived vulnerability prevalence across popular
production-grade applications and libraries in Go.

Given this information, the last piece is the informed hypothesizing of the
general applicability of @ifc techniques to Go as a useful security device,
particularly within the context of static source-code analysis.

== Research Paradigm

The research process described above comprises three complementing facets.
Firstly, deductive processes are used to implement initial versions of the
analyzer and the benchmarks corpus, based on reference material, such as the
Go specification and the state-of-the-art literature review supporting this
document's @bg. Secondly, empirical observations from real Go projects guide
the subsequent development, as the work's different components are iteratively
adjusted and extended. Thirdly, inductive inferences allow drawing conclusions
for the entire project population under consideration based on the analyzer's
findings for each sampled project.

== Supported Go Subset <methods:subset>

This work is centered on the static analysis of Go programs compliant with Go
1.26, currently the latest stable version of the language. All input is expected
to be compliant with the Go specification (i.e., all code must compile); the
tools' behavior is undefined for faulty programs, though a best-effort attempt
is made to report clear problems and to isolate their impact so as not to fully
compromise the results for other unrelated sections.

However, even correct Go 1.26 programs are not necessarily supported, as
simplicity and time constraints mean that certain language features are not
considered to be in scope for this degree project. These are constructs and
patterns too complex to handle in an initial prototype, but future work could
extend this project's contributions to support some or all of what is here
considered out of scope, with varying degrees of difficulty.

Most Go features are supported and considered to be in scope, including but not
limited to the general usage of control-flow constructs (`if` branching,
expression and type `switch` statements, `for` loops, labeled and unlabeled
`break` and `continue` statements, forwards and backwards `goto`, etc.),
functions, methods, closures and captures, deferred calls, variable and constant
operations, type assertions, receiving from and sending to channels, and
component-based operations (slicing, indexing, `struct` field selection, etc.).

Nevertheless, several other features or patterns are not considered, as they
are deemed too complex to be supported in an initial prototype. This section
outlines the chief areas determined to be out of scope.

Firstly, heap locations and general pointer aliasing is not modeled. Very simple
pointer usage may be correctly handled, as in most cases pointers are here
considered equivalent to their targets, but more complex patterns can lead to
unsound results. Alias relationships in general may not be preserved, and calls
do not perform mutation write-backs through reference-holding arguments (e.g.,
pointers, maps, slices, channels) nor through pointer-typed receivers, in the
case of methods.

Secondly, interface-typed dynamic dispatch is not supported, nor is method
promotion through embedded interfaces. Simple generic constructs are handled
correctly, but behavior dependent on dynamic type restrictions, constraints, and
shapes is not supported.

Thirdly, `panic` to `recover` chains are not modeled, and contextual
`panic`-based propagation is excluded as a termination covert channel, as
described in @bg:ifc:covert. Run-time panics in general (even if not explicit)
are not considered and can lead to undefined results, with the same being true
for blocking, timing, resource use, allocation failure, and other such covert
channels listed in the aforementioned @bg:ifc:covert.

Moreover, while simple concurrency cases are in scope as one of Go's most
distinctive features, complex channel and goroutine chains are not, and
advanced happens-before/synchronization precision is not a project goal,
including some forms of data races. In particular, goroutine effects that
require argument/receiver write-backs are not supported, as stated above.

Additionally, no usages of the `unsafe` package
#footnote(link("https://pkg.go.dev/unsafe")) are supported, as it allows
consumers to bypass the type system and break critical language assumptions,
including through arbitrary reads and writes that cannot be tracked by taint
analysis.

In general, only pure, base Go is considered for this degree project. Assembly
implementations, plugins#footnote(link("https://pkg.go.dev/plugin")), reflection
#footnote(link("https://pkg.go/dev/reflect")), finalizers and pointer cleanup
functions, signal handling, and `//go:linkname` directives for arbitrary linking
are not modeled, since they would require extremely complex handling, as well as
much more contextual information, leading to greatly reduced performance.

All functions and methods without known implementations, such as those from
external packages not under analysis or from `cgo`-powered @ffi mechanisms, are
not supported soundly, instead being approximated as black boxes. This means
that all their outputs are modeled at call-time as being tainted by the
aggregate union of all provided inputs, in addition to the contextual branch
taint surrounding the invocation. This is correct in most cases, but it is not
sound in general because it does not take into account any potential
side-effects. In addition, external dependency resolution (including through
`replace` directives) is also not supported.

#v(1fr)
#highlight[more]
#v(1fr)

Overall, these limitations are considerable, but many of the excluded language
features are relatively niche and used only in hyper-specialized contexts. This
means that a very significant share of all Go programs is considered to be in
scope for this work and are modeled correctly, which is appropriate for a degree
project of this nature.

#pagebreak()

== Data Collection <methods:collection>

As stated above, it is necessary to select real-world Go projects as part of the
defined research process, especially for the evaluation of this work's
contributions relative to the Go ecosystem, as referenced in
@methods:process:real-world.

The population considered is not taken to be the literal, complete universe of
all possible or existent Go programs, as this would include extremely
specialized and out of the ordinary projects, very unconventional code (e.g.,
as written by beginners, or automatically transpiled from another language), and
other undesirable outliers. Such a universe would also be impossible to
representatively characterize, as most Go programs are not easily accessible
(e.g., they are part of proprietary closed-source implementations, contain trade
secrets, or exist locally in ad-hoc files in one particular machine).

Instead, for the purposes of this degree project, the most suitable population
is limited to popular, production-grade, open-source Go projects, which
represent projects likely to be truly relevant and in use, either as libraries
depended on across the entire ecosystem, or applications used directly by
end-users for a particular purpose (or both, in some cases).

=== Project Discovery <methods:collection:discovery>

Objective metrics are necessary to select concrete real-world projects to be
analyzed, in an attempt to be faithful to the general guidelines above regarding
a desired population based on some form of actual widespread usage or
recognition.

This degree project opts to do so according to three different principles, so
that they can complement each other's limitations and thus collectively form a
better birds-eye representation of the pertinent population.

Each set of criteria results in an ordered dataset of Go projects, ranked from
best-scoring (according to the dataset's own metric) and down to the
lowest-scoring project that still meets the dataset's specific admission
criteria.

#v(1fr)
#highlight[more]

#pagebreak()

==== Dataset A: Published Modules by Dependents <methods:collection:discovery:a>

The first dataset focuses primarily on libraries and makes use of Go's official
module mirror to derive commonly used dependencies. While external module
distribution is possible through many sources, the `go` tool defaults to using
#link("https://proxy.golang.org"), which is managed by the Go team and hosted by
Google. This means that public modules are, in practice, centralized in that
repository, while other servers implementing the `GOPROXY` protocol
#footnote(link("https://go.dev/ref/mod#goproxy-protocol")) are typically only
used for private modules, such as in a proprietary context.

In addition, the widely-used official documentation and discovery website at
#link("https://pkg.go.dev") is actually a frontend for the `proxy.golang.org`
mirror, further cementing the latter's role as an authoritative source for
open-source Go modules throughout the ecosystem.

In parallel, another service provided by the Go team and hosted by Google is the
index at #link("https://index.golang.org"), which serves a feed of module
versions published to `proxy.golang.org` since April 10, 2019 at 19:08:52.997264
@utc:short, corresponding to when the service entered operation. Each entry
contains the module path, version, and publication timestamp.

Since `pkg.go.dev`'s @api does not support listing
modules#footnote[As part of this degree project, a request was made at
  #link("https://github.com/golang/go/issues/76718#issuecomment-4747014777") to
  add a `List` endpoint capable of ordering results by importers count, but at
  the time of writing the request has not yet been actioned.] (and neither does
its user-facing website, nor the `GOPROXY` protocol itself), an acceptable
alternative is to traverse the entire `index.golang.org` feed and collect all
unique module paths mentioned, thereby obtaining the set of modules known to
`proxy.golang.org` (or rather, those that were at one point known to it) with at
least one version published since the aforementioned April 2019 date, up to and
including some other particular date.

#let index-modules-truncation = zero.num(100000)

Then, taking the collected set of all known public modules, this work
truncates it to the first #index-modules-truncation entries, ordered by the
absolute number of versions listed in `index.golang.org` (which corresponds to
the number of feed entries for each module). This is necessary because it would
be unmanageable and excessively time consuming to process the entirety of the
calculated set, corresponding to millions of records.

For each listed module in the truncated list, `proxy.golang.org` is then queried
to obtain the `go.mod` file for the module's latest published version. All of
the module's stated dependencies, both direct and transitive, then have their
tally incremented by one, so as to end up with a mapping of Go modules to the
number of dependents they have within the #index-modules-truncation\-entry
truncated set obtained from the `index.golang.org` feed.

The final Dataset A is then the list of public modules depended on (directly or
indirectly, at any version) by at least one of the top #index-modules-truncation
modules by published version count since April 10, 2019 at 19:08:52.997264 @utc,
as reported by the official module mirror at `proxy.golang.org`.

==== Dataset B: GitHub Repositories by Stars

The second dataset considered by this degree project focuses on GitHub
#footnote(link("https://github.com")), a
project hosting platform widely used across the entire open-source community,
which has Go as its 10#super[th] most common programming language across all
630 million Git#footnote(link("https://git-scm.com")) repositories, as of
Octoverse 2025 @github2025octoverse. This complements the real-world projects
population under consideration since not all relevant Go modules are dependency
libraries, especially in the case of end-user-oriented applications, which are
executed directly and not depended on.

Since popularity is a desired trait for projects in the target population,
the best possible metric on GitHub is star count (stars are awarded by users to
repositories as they see fit, but usually based on merit or interest).

GitHub detects the programming languages present in a repository using the
open-source tool Linguist
#footnote(link("https://github.com/github-linguist/linguist")),
which applies file-based heuristics to determine language shares, proportional
to file size. The most significant share in a repository is denoted its primary
language.

The GitHub @api's Search Repositories endpoint
#footnote(
  link("https://docs.github.com/en/rest/search/search#search-repositories"),
)
allows searching for repositories with a given primary language by providing the
query `language:<name>` (e.g., `language:go` yields all public Go repositories
available on GitHub). It also allows sorting results by number of stars, ordered
from most to least, as well as filtering for a specific number or range of
stars.

As such, the final Dataset B is the list of public repositories on GitHub with
at least #zero.num(1000) stars and Go as their primary language, at a particular
date, ordered from most to least stars.

==== Dataset C: GitLab Repositories by Stars <methods:collection:discovery:c>

The third dataset is very similar to Dataset B, but focuses instead on GitLab
#footnote(link("https://gitlab.com")), the second primary hub for open-source
development. It complements the other two datasets by including even more
noteworthy projects that would likely not otherwise be found in the research
population.

GitLab also uses Linguist to determine languages used by a repository, but an
important nuance is that the GitLab @api List Projects endpoint
#footnote(link("https://docs.gitlab.com/api/projects/#list-projects")) accepts
a `with_language` parameter, meaning that repositories are filtered by _any_
share of the language rather than whether it matches the primary language.

Since GitLab operates at a much smaller scale than GitHub (especially since only
the main `gitlab.com` instance is considered, and GitLab is often self-hosted
for proprietary contexts), the minimum star threshold is reduced two orders of
magnitude compared to Dataset B, which results in a minimum requirement of at
least 10 stars for admission. Despite being very low in absolute terms, this
threshold strikes a balance appropriate for GitLab.

As such, the final Dataset C is the list of public repositories on GitLab with
at least #zero.num(10) stars and any detected Go usage, at a particular date,
ordered from most to least stars, excluding those marked as archived.

==== Rejected Alternatives

It should be noted that other selection processes are worthy of consideration,
especially in alternative to Dataset A as described above. The present
subsection describes some of the possibilities explored.

Firstly, `pkg.go.dev` has an experimental publicly-available
@api#footnote(link("https://pkg.go.dev/v1beta/api")) released at the end of May
2026 @lee2026gopkgsiteapi which, while still not supporting module listing,
provides an `/imported-by` endpoint to list a module's dependents, which could
replace the manual tallying used by the present work. However, this considers
direct dependencies only, which is not a representative metric of overall
reliance on the module, so the returned results would have to be recursively
queried in order to also count transitive dependencies.

In addition, the `pkg.go.dev` website and @api use Go packages as their
fundamental unit of operation, rather than modules, meaning that it would be
necessary to sum up all "imported by" counts for all of the module's packages in
order to get an accurate figure; for example, at the time of writing,
`pkg.go.dev` reports that package `k8s.io/client-go/kubernetes` is imported by
#zero.num(61635) other packages, but its parent module's root package
`k8s.io/client-go` is only imported by 4 other packages. This incompatibility
is especially damaging given that the listing obtainable from the
`index.golang.org` feed contains only modules, not packages (i.e., the list
would contain `k8s.io/client-go`). In any case, though, there is no simple way
to map a module to its sub-packages except by downloading its entire source code
and manually inspecting its directory structure, thus making this solution
unequivocally infeasible at large scale.

Secondly, Google maintains #link("https://deps.dev"), a public service tracking
various insights for open-source dependencies across different ecosystems,
including Go's. As part of this initiative, a public BigQuery dataset is made
available#footnote(link("https://docs.deps.dev/bigquery/v1")), which includes
pre-calculated direct and indirect dependents information for all public Go
modules as part of its `Dependents` table, which also uses modules (rather than
packages) as its unit of operation, as desired. A very appropriate alternative
to this work's Dataset A could thus be obtained through an @sql query such as
the one in @methods:collection:discovery:rejected:bigquery below.

#figure(
  ```sql
  SELECT
    Name AS module,
    ANY_VALUE(Version) AS latest_version,
    COUNT(DISTINCT Dependent.Name) AS dependent_count
  FROM `bigquery-public-data.deps_dev_v1.DependentsLatest`
  WHERE System = 'GO'
    AND DependentIsHighestReleaseWithResolution
  GROUP BY module
  HAVING dependent_count >= 10
  ORDER BY dependent_count DESC;
  ```,
  caption: [Example dependents query to `deps.dev`'s BigQuery dataset],
) <methods:collection:discovery:rejected:bigquery>

Nevertheless, while Google allows queries to this BigQuery dataset up to 1 TiB
of processing per month, Google Cloud Console estimates the query in
@methods:collection:discovery:rejected:bigquery as processing 54.32 TiB of data,
which would reportedly cost an equivalent to approximately \$340 U.S. dollars to
run and is thus not suitable for this work, even if the resulting dataset would
likely be of higher quality.

#pagebreak()

Instead of using the BigQuery dataset directly, it would also be reasonable to
query `deps.dev`'s @api for each module in the set derived from the
`index.golang.org` feed, as it exposes a `GetDependents` endpoint
#footnote(link("https://docs.deps.dev/api/v3alpha/#getdependents")) with
equivalent semantics. However, this is not actually a valid solution because
this particular endpoint is only available for npm (JavaScript), Cargo (Rust),
Maven (Java), and PyPI (Python), but not the Go ecosystem.

In summary, taking into account the reasoning above, the pipeline described in
@methods:collection:discovery:a is deemed the most appropriate for this degree
project's purposes, even if convoluted, as it is the only real solution
available.

=== Stratification <methods:collection:stratification>

After the three datasets are formed, each of them is stratified into four
quartile rank bands, according to their native ordering:

- Band I: top $25%$ projects (inclusive) with best dataset-specific score;
- Band II: projects within $(25%, 50%]$, from the top;
- Band III: projects within $(50%, 75%]$, from the top;
- Band IV: projects within $(75%, 100%]$, from the top.

This means, for example, that stratum B.I corresponds to the quarter of Dataset
B with the most stars, while stratum A.III refers to the second-worst quarter of
Dataset A by number of dependents in the truncated set derived from the
`index.golang.org` feed.

Stratification ensures different levels of merit within each dataset are fairly
and evenly represented, which is essential to promote a good understanding of
how this work's contributions behave when confronted with different kinds of
real-world projects. While no stratification would lead to a more faithful
representation of the overall environment, it is more important for analyzer
evaluation to safeguard the separation by band, as explained above.

In total, for $3$ datasets and $4$ bands, $12$ strata are produced.

=== Sampling <methods:collection:sampling>

Due to limited time and resources, it is not possible for the purposes of this
degree project to use the entirety of the three datasets directly, as they
collectively include tens of thousands of projects.

As such, this work uses stratified sampling to randomly select $25$ projects
from each of the $12$ strata defined in @methods:collection:stratification, thus
resulting in a final list of $300$ selected projects. All the $12$ samples (with
$25$ projects each) are kept separate, so that dataset and band information is
preserved. The sampling seed (for pseudo-randomness) is likewise stored to
ensure reproducibility.

It ought to be noted that, throughout this degree project, the definition of "Go
project" is intentionally kept vague, since the term can mean different levels
of granularity in different contexts, depending on what is most appropriate,
which is necessarily dataset-specific. For Dataset A, each project corresponds
to a single Go module, but for Datasets B and C, a project denotes a hosted Git
repository, which may contain multiple related modules.

=== Inter-Dataset Duplicates <methods:collection:duplicates>

It is possible for the same module to be selected from separate datasets, since
sampling is conducted independently for each strata. While entries are
guaranteed unique within each dataset, duplication is possible across datasets,
making this a real concern.

Concretely, for the three datasets defined in @methods:collection:discovery,
the only possible configuration for a duplicate to occur is by a clash between
Dataset A and one of Datasets B or C; Datasets B and C can never clash with each
other because they only contain modules with base paths starting with
`github.com/` and `gitlab.com/`, respectively, but Dataset A entries may use
either (or neither) of those prefixes.

If a Go module is found in multiple datasets, analysis is performed only once,
but its results are reported as part of both datasets. In that case, the project
from Dataset A containing the module is considered its primary project, and the
other project containing it (in another dataset) its secondary one. The
primary/secondary distinction is based purely on the arbitrary dataset ordering
and safeguards determinism.

The project version used for the single analysis run is that of the primary
project, as it represents a published, stable version, rather than the
arbitrary most recent commit associated with the secondary project. In any case,
the differences between the two versions (if any) are assumed to be negligible.

== Data Evaluation <methods:data-eval>

This section presents a final and brief evaluation on the methods selected for
fulfillment of the degree project's research questions (@intro:rq) and stated
goals (@intro:goals), particularly in regard to the evaluation subprocesses, in
terms of project selection, systematic results collection, and interpretation of
findings, as described in @methods:process:real-world,
@methods:process:prevalence, and @methods:collection.

=== Validity

Validity concerns itself with measurement accuracy, which relates to whether
the chosen methods yield results consistent with the abstract truth for the
population in question.

In this case, validity is primarily tied to the representativeness of the $300$
selected projects as compared to the Go ecosystem, more specifically the stated
population constraints of popular, production-grade, open-source Go projects.
This is because internal validity is already guaranteed by the very nature of
the results, which correspond to their own objective truth, thus making external
validity the evaluation's chief concern.

To that end, the use of random sampling from three different datasets, each of
which focused on covering one major facet of the population, is a strong
argument for satisfactory external validity, while broad stratification into
quartile rank bands ensures the representation of desired attributes in the
final project selection.

The datasets are considered representative and acceptable for this degree
project's purposes, given that, based on empirical observation, the vast
majority of significant open-source Go projects are present in one or more of
the official Go module mirror (`proxy.golang.org` / `pkg.go.dev`), the GitHub
platform, or the public GitLab instance. The strongest threats to validity are,
possibly, the chosen minimum thresholds of 1000 and 10 stars for Datasets B and
C respectively, but the stated figures proved appropriate and reasonable at
separating relevant projects from others less suitable for the target group.

The selected sample size is also sufficiently large to allow drawing
conclusions, at $100$ projects per dataset and $300$ projects overall,
especially given the time and resource constraints associated with the present
work.

=== Reliability

Reliability complements validity by focusing on measurement consistency, which
corresponds to whether the chosen methods yield repeatable and reproducible
results.

This is a key factor to the evaluation methodology and is, by design, heavily
taken into account by the project selection and results collection subprocesses.
Given that the analyzer output is deterministic for a given input project, that
the pseudo-randomness sampling seed is published as part of this work, and that
each project analyzed has its version pinned and recorded, the results are
highly reliable.

The most significant threat to reproducibility concerns itself with the
generation of Datasets B and C, since the GitHub and GitLab @api:pl make
available data only for their current state, so it is not possible to specify a
specific timestamp to bind results to, and thus the same query performed at
different points in time may yield different results. Nevertheless, this is not
a major problem for reliability because star counts in principle do not
fluctuate so significantly, especially at the captured order of magnitude.

It is thus considered that the chosen methods are reliable for the purposes of
this degree project, especially since repeatability is guaranteed by the
publishing of all scripts, seeds, and intermediate materials used and produced
during the project discovery step and all other evaluation subprocesses.

#pagebreak()

== Summary

In conclusion, this degree project uses clear and appropriate methods to further
its stated purpose. It comprises the development of a static analyzer for
tracking and enforcing @ifc, as well as a base security policy for it to employ,
and a corpus of correctness benchmarks, all using a combination of deductive and
iterative empirical-led processes. In addition, it evaluates such contributions
by scrutinizing the findings reported for $300$ popular real-world Go projects,
randomly selected using stratified sampling from datasets based on public
dependent count, GitHub stars, and GitLab stars.
