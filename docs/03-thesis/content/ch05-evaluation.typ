#import "../charts/all.typ" as charts
#import "../utils/cmd-outputs.typ": cmd-output
#import "../utils/dependencies.typ": codly, lq, zero
#import "../utils/subfigures.typ": subfigures
#import "./zz-b-results.typ": results

#import codly: codly

#let share(count, total) = zero.num(
  calc.round(100 * count / total, digits: 2),
  suffix: [%],
)

#let median(data) = {
  let data = data.sorted()

  if calc.odd(data.len()) {
    data.at(data.len() / 2)
  } else {
    let half = int(data.len() / 2)

    calc.round(
      (data.at(half - 1) + data.at(half)) / 2,
      digits: 2,
    )
  }
}

= Evaluation <eval>

The present degree project aims to conceptualize and develop a static taint
analyzer of sufficient robustness, efficiency, and efficacy to bring significant
security value to a project's stakeholders. The established theoretical model
and prototype implementation must therefore be subjected to a rigorous
evaluation process so as to determine the extent to which the stated goals have
been achieved, as objectively as possible.

Moreover, as part of the project's overall ambitions for usability, flexibility,
and simplicity, it is desired that the analyzer offers a satisfactory route for
accessible and straightforward onboarding of new projects and users, namely
through the definition of a Base Security Policy broadly applicable to most
real-world Go projects, as an initial stepping stone before real,
project-specific configuration.

This chapter describes how Glowy and its integrated Base Security Policy were
evaluated and reports the various results obtained for each part of said
evaluation process. Context is also provided for all surrounding aspects,
including details necessary for repeatability and reproducibility.

== Benchmarks Corpus

#let benchmarks-data = csv("../assets/ifc-benchmarks.csv", row-type: dictionary)
#let total-benchmarks = benchmarks-data.len()

#let benchmark-suites = (
  benchmarks-data
    .fold((:), (counts, item) => {
      counts + (item.Suite: counts.at(item.Suite, default: 0) + 1)
    })
    .pairs()
    .map(pair => {
      let (suite, count) = pair
      let parts = suite.split("-")

      (
        letter: upper(parts.at(1)),
        name: parts
          .slice(2)
          .map(word => upper(word.at(0)) + word.slice(1))
          .join(" "),
        count: count,
      )
    })
)

In an attempt to representatively assess Glowy's capabilities with regards to Go
language constructs and the different means and opportunities that each of them
offers for covert or overt propagation of information, a structured corpus of
$#total-benchmarks$ Go modules was developed to both enumerate potential flows
of interest and test the analyzer's handling of them, in connection with
@rq-ifc[].

These correctness benchmarks were produced in tandem with the analyzer itself,
thus benefiting both contributions from a mutual feedback loop, in an iterative
process striving for soundness and precision across the Go program space, as
described in @methods:process of earlier @methods.

As to better support this symbiosis, the corpus integrates directly with Glowy's
test environment, enabling unified reporting with the remainder of the testing
apparatus, including doctests and unit tests.

Although quality is more important than quantity for the careful enumeration of
the primary possible means of propagation, some degree of exhaustiveness and
thoroughness is advantage in identifying and documenting the various points of
observability within the Go language.

#let benchmarks-lines = benchmarks-data.map(item => int(item.Lines))
#let benchmark-lines-avg = calc.round(
  benchmarks-lines.sum() / total-benchmarks,
  digits: 2,
)
#let benchmark-lines-median = median(benchmarks-lines)

The corpus is a collection of independent Go modules, each focusing on
demonstrating one particular aspect or functionality, as concisely and clearly
as possible. Prioritizing test case simplicity means that each module is easy to
understand, making the corpus as a whole more accessible. Modules have an
average of $#benchmark-lines-avg$ lines across all Go files and a median of
$#benchmark-lines-median$, which indicate relatively short programs.

All modules consist of an independent directory containing a `go.mod` file, a
`main.go` file with declared native package name `main`, and in some cases one
or more additional Go files, potentially nested into subdirectories.

The overwhelming majority of modules use source-code annotations to define
security directives as required to illustrate and adequately reproduce the
pattern that is the focus of the test.

However, unlike what is recommended for real use, the benchmarks use exclusively
assertions as a policy enforcement check, given their precision advantages and
subsequent suitability for a test environment. Whereas sinks accept a range of
labels, assertions require exact equality, giving much higher confidence that
a passing test demonstrates correct handling.

Each of the #total-benchmarks modules adds genuine and independent security
value, no matter how simple or complex. They are additionally relatively
target-agnostic (except the annotations themselves, which are simple to replace
if needed), not testing very specific implementation details, but rather
attempting to represent what should be expected from any generic Go static taint
analyzer. This means that the the corpus may be used to test others tools'
correctness with minimal changes, therefore constituting a significant research
contribution on its own.

All tests are manually created to showcase important aspects, constructs, and
edge-cases that should be handled correctly by an analyzer of this kind.

#pagebreak()

Modules are organized into suites, which group related functionality or kinds of
flows. The corpus has #benchmark-suites.len() suites, as shown in
@eval:benchmarks:suites below.

#figure(
  table(
    columns: (auto, auto, auto, auto),

    table.header(
      strong[Suite], strong[Name], strong[\# Modules], strong[Handled?]
    ),

    ..benchmark-suites
      .map(suite => (
        suite.letter,
        suite.name,
        [#suite.count],
        if suite.letter == "X" { sym.ballot.cross } else {
          sym.checkmark.heavy
        },
      ))
      .flatten(),
    table.hline(stroke: 1pt),
    [], strong[TOTAL], strong[#total-benchmarks], [/],
  ),
  caption: [Benchmarks corpus suites],
) <eval:benchmarks:suites>

Suites have an associated letter that identifies them, and each module is
numbered within its respective suite. This means that modules may be succinctly
referred to by the combination of its suite letter and inherent number, such as
$"L"03$ for module `suite-l-loops/03-condition-mutation`.

The last suite, Failures ($"X"$), corresponds to major cases that should
ordinarily be handled by a taint analyzer, but are considered out of scope for
this work, in accordance with the Go subset defined in @methods:subset.

As an example, @eval:benchmarks:multi-tainted-gotos below reproduces benchmark
case $\#5$ from the corpus's Suite J, which focuses on Jumps. It comprises just
19 lines of code and focuses on showcasing one very particular Go aspect in
terms of value exfiltration and flow security: if multiple ```go goto```
statements alter control flow such that their branch dependency becomes
indirectly observable, the contextual taints must be conservatively aggregated
and applied at the corresponding ```go goto``` target.

#codly(
  header: pad(
    y: 0.5em,
    [`ifc-benchmarks/suite-j-jumps/05-multi-tainted-gotos/main.go`],
  ),
  highlighted-lines: (10, 13, 16),
)
#figure(
  ```go
  package main
  import "fmt"
  // glowy::label::{alice}
  const alice = 1
  // glowy::label::{bob}
  const bob = 2
  func main() {
    x := 0
    if alice > 0 {
      goto End
    }
    if bob > 0 {
      goto End
    }
    x = 3
  End:
    // glowy::assert::{alice, bob}
    fmt.Println(x)
  }
  ```,
  caption: [Example correctness benchmark],
) <eval:benchmarks:multi-tainted-gotos>

The assertion on line 17 of @eval:benchmarks:multi-tainted-gotos emits an error
whenever `x`'s associated security label does not match ${"alice", "bob"}$
exactly, identifying a gap in the analyzer implementation or underlying model.

Overall, the benchmarks corpus forms an important research contribution and
doubles as a guarantee corroborating Glowy's robustness and sound handling of
a wide variety of potential data flows. The tests focus mostly on
confidentiality, but integrity-related flows have a considerable overlap.

#pagebreak()

== Real-World Project Analysis <eval:real-world>

In order to evaluate @rq-find-vulns[], but also @rq-ifc[] and @rq-base-policy[],
this work selects a number of popular, open-source, real-world Go projects and
subjects them to analysis by Glowy, recording the reported findings, directly
addressing @pg-evaluation[].

No project-specific configuration is provided, since evaluating the Base
Security Policy is a significant goal for this process, in addition to the lack
of scalability associated with manual preparation of target projects.

Furthermore, risk assessment is a competence of each project's authors and
maintainers, who are the only ones with the required domain knowledge to
determine the most appropriate security policy tailored to the project's
requirements and assumptions. This work therefore makes no attempt at defining
a ground truth for third-party project analysis findings, as it would be
misleading even if not impractical.

=== Project Selection

Selection was performed in accordance with @methods:collection:discovery.

==== Dataset A: Published Modules by Dependents

#let dataset-a-feed-total = 2717350
#let with-single-version = 1196524

The `index.golang.org` feed was enumerated for versions published between the
service's start date of April 10, 2019, at 19:08:52.997264 @utc (inclusive) and
the selected cut-off date of June 1, 2026, at 00:00:00.000000 @utc (exclusive),
thereby encompassing approximately 7 years and 2 months, resulting in a set of
#zero.num(dataset-a-feed-total) modules after deduplication.

Modules extracted from the `index.golang.org` feed had an average of
#zero.num(19.81) published versions within the queried time period, and a median
of #zero.num(2). Additionally, #zero.num(with-single-version), corresponding to
#share(with-single-version, dataset-a-feed-total), had one single version
listed.

#let dataset-a-trunc = 100000

The top #zero.num(dataset-a-trunc) by version count, as considered for
dependency counting, presented an average of #zero.num(376.07) listed
versions and a median of #zero.num(136). The last admitted module (i.e., the
#zero.num(dataset-a-trunc)#super[th]) had #zero.num(68) published versions.

#let dataset-a-total = 44648

After dependency counting, the final dataset comprised
#zero.num(dataset-a-total) Go modules depended on (directly or indirectly) by at
least one of the top #zero.num(dataset-a-trunc) modules by number of published
versions to `index.golang.org` within the time period under consideration.

The dataset entries have an average of #zero.num(108.76) and a median of
#zero.num(3) total dependents, which indicates a large mass concentration at
low counts.

==== Dataset B: GitHub Repositories by Stars

#let dataset-b-total = 3880

The GitHub @api was queried for all public repositories with Go as their
primary detected language and at least #zero.num(1000) stars, as of July 23,
2026\. This yielded a total of #zero.num(dataset-b-total) repositories with
an average of #zero.num(5077.49) and a median of #zero.num(2325.5) stars,
indicating the presence of outliers with a very high star count, as only
#zero.num(911) repositories (#share(911, dataset-b-total)) held more stars than
the average.

==== Dataset C: GitLab Repositories by Stars

#let dataset-c-total = 236

The GitLab @api was queried for all public repositories with Go as one of their
detected languages, not archived, and at least #zero.num(10) stars, as of July
26, 2026.

This resulted in a dataset of #zero.num(dataset-c-total) repositories, much less
than in comparison to GitHub, with an average of #zero.num(74.63) and a median
of #zero.num(24) stars, again showing some degree of skewness. Only
#zero.num(49) repositories (#share(49, dataset-c-total)) held more stars than
the average.

==== Sampling

#let total-selected = dataset-a-total + dataset-b-total + dataset-c-total

The total #zero.num(total-selected) projects were stratified according to the
quartile rank bands defined in @methods:collection:stratification, resulting in
$12$ strata for $4$ bands and $3$ datasets.

Each of those strata was then uniformly sampled in order for $25$ projects,
using pseudo-random algorithm ChaCha20 @bernstein2008chacha20 seeded with the
256 bits \
`8A1C56079C3F881E09E4FC9A839CB4E148C56983EA2D1FD5EEDD13C8BB8F089C`.

#let total-sampled = 12 * 25

This resulted in $12$ samples of $25$ projects each, constituting a grand total
of #zero.num(total-sampled) real-world Go projects selected for analysis.

The only duplicate across samples is the module
`gitlab.com/gitlab-org/api/client-go`, present in both samples A.I and C.I, with
the procedure described in @methods:collection:duplicates applying.

=== Manual Exclusion

#let excluded-projects = 9
#let total-projects = total-sampled - excluded-projects

Out of the #total-sampled sampled projects, #excluded-projects had to be
manually excluded:
- 4 because they caused resource exhaustion;
- 3 because they used unsupported constructs (analysis never converged);
- 2 because their source code is no longer publicly available.

This means that #total-projects projects were submitted for analysis.

=== Analysis Execution

The analysis of the remaining #zero.num(total-projects) projects was
orchestrated by the `glowy-eval` application, described in @glowy:impl:eval,
with the entire run completing in approximately 2 hours and 20 minutes,
including approximately 1 hour of network-dependent time for downloading each
project's source code.

#let empty-projects = 23

A total of #zero.num(empty-projects) projects did not contain any Go modules,
corresponding to $10$ from Dataset B and $13$ from Dataset C
#footnote[This figure is not applicable to Dataset A because all its projects
  are, by definition, necessarily Go modules, given that the dataset source is
  the official Go module mirror.]. This is primarily due to some projects having
been entirely developed (and often discontinued) before the Go Modules System
was introduced at the end of 2018 @go2018modules, as well as the GitLab @api
limitation already addressed in @methods:collection:discovery:c wherein the
search results include repositories with any share of detected Go usage, even if
minimal (e.g., isolated utility scripts).

#let unfolded-projects = total-projects - empty-projects

The remaining #zero.num(unfolded-projects) projects were unfolded
into a total of #zero.num(results.len()) Go modules, with each project
containing an average of #zero.num(1.65) detected modules, as shown in
@eval:real-world:execution:modules-per-project below.

/*
SELECT MAX(module_count)
FROM (
    SELECT
        p.url,
        COUNT(m.path) AS module_count
    FROM projects AS p
    JOIN modules AS m
        ON m.primary_project = p.url
        OR m.secondary_project = p.url
    WHERE p.dataset in ('B', 'C')
    GROUP BY p.url
);
*/

#figure(
  table(
    columns: (auto, 5em, 5em, 5em),

    table.header(strong[Dataset], strong[Average], strong[Median], strong[Max]),
    table.vline(x: 1, stroke: 1pt),

    [B: GitHub], zero.num(1.52), zero.num(1), zero.num(12),
    [C: GitLab], zero.num(1.78), zero.num(1), zero.num(18),

    table.hline(stroke: 1pt),
    [Both], zero.num(1.65), zero.num(1), zero.num(18),
  ),
  caption: [Modules per project not empty nor manually excluded],
) <eval:real-world:execution:modules-per-project>

Each of the aforementioned #zero.num(results.len()) Go modules was subject to
independent static taint analysis using the `glowy-cli` application, executing
on a Linux machine with approximately 12 GB of available memory, shared with
other processes. The `GLOWY_MAX_THREADS` environment variable was set to `2` to
reduce memory usage and increase results reproducibility, per
@methods:process:real-world, as well as to obtain more accurate performance
reads without overly compromising evaluation speed.

Results were saved in an SQLite database for easy querying and summarized to a
`results.csv` file, with verbose output captures (`stdout` and `stderr`) also
being stored for modules whose analysis did not succeed. All artifacts are
available in a public GitHub repository
#footnote(link("https://github.com/RafDevX/master-thesis")).

#pagebreak()

== Results <eval:results>

This section presents the results obtained from auditing the
#zero.num(results.len()) Go modules extracted from popular, open-source,
real-world projects as sampled in accordance with @methods:collection:discovery
and individually evaluated as described in the preceding @eval:real-world. This
directly relates to @rq-find-vulns[] and @rq-prevalence[], concluding
@pg-evaluation[] and supporting @pg-interpret[].

@results includes a short summary of the collected results for each of the
aforementioned #zero.num(results.len()) analyzed modules, organized as a sorted
table.

=== Overview

Each individual module audit was classified according to one of the following
broad outcome classes:
- *Succeeded (222):* Analysis completed with no problems reported.
- *Diagnostics (126):* Analysis completed with at least one problem.
- *Crashed (4):* Analysis could not be completed due to analyzer fault.
- *Aborted (8):* Glowy rejected performing taint analysis.
- *Empty (11):* No Go files admitted.

The numbers indicated next to each outcome's name correspond to the number of
modules classified within that class. It is thus evident that approximately
two thirds of modules that completed analysis did so without reporting any
problems.

/*
SELECT
  p.url,
  COUNT(m.path) AS module_count
FROM projects AS p
JOIN modules AS m
  ON m.primary_project = p.url
  OR m.secondary_project = p.url
JOIN reports AS r
  ON r.module = m.path
WHERE r.status = 'E'
*/

Modules classified as empty are generally composed entirely of test fixtures, or
otherwise declare exclusion from normal builds (such as with a conventional
```go //go:build ignore``` constraint). All but one are associated with
multi-module projects, with the latter comprising a Hugo
#footnote(link("https://gohugo.io")) statically-generated website; Hugo uses
Go's module utilities to manage in-framework plugins.

Crashed runs, in turn, correspond to implementation defects or bugs. A notable
example is tied to the implementation's design decision to panic if a synthetic
label tag escapes its respective function, as already previously mentioned in
@glowy:constructs:functions:synthetics.

Overall, the general outcome classification helps sift through the sizeable
set of results, especially considering how dense they are, as `glowy-eval`
collects numerous datapoints for each audit.

#pagebreak()

Outcome distribution is represented in @eval:results:overview:outcomes below,
with bar size corresponding to the percentage of modules within the stated
sample whose analysis was categorized according to each possible outcome. The
first bar, notably, shows an aggregate global summary across all modules. Values
above each bar specify the absolute number of modules considered.

#figure(
  charts.outcomes,
  caption: [Analysis outcomes by dataset and popularity band],
) <eval:results:overview:outcomes>

The stacked bar chart demonstrates no clear relationship between samples and
module analysis outcomes, though Band I of each dataset tends to have a lower
share of runs without reported diagnostics, in comparison with the remaining
bands within the same dataset. This may be due to more popular or more
widely-used projects being more developed and presenting greater complexity,
thus comprising a larger surface area for diagnostics to surface from,
especially if deep abstraction chains obscure analysis.

The global distribution is thus the one summarized in
@eval:results:overview:outcome-distribution below.

#let outcome-counts = (
  ([Succeeded], 222),
  ([Diagnostics], 126),
  ([Empty], 11),
  ([Aborted], 8),
  ([Crashed], 4),
)

#figure(
  table(
    columns: (auto, auto, auto),

    table.header(
      strong[Outcome], strong[\# Modules], strong[Share (%)],

      ..outcome-counts
        .map(((label, count)) => (
          label,
          zero.num(count),
          share(count, results.len()),
        ))
        .flatten(),
    ),
  ),
  caption: [Total modules by analysis outcome],
) <eval:results:overview:outcome-distribution>

#pagebreak()

Shown in purple in the previous page's @eval:results:overview:outcomes is the
Aborted outcome, which encompasses the following three cases:
- *Parsing Failure (2):* At least one source file could not be translated from
  raw text to an @ast:long.
- *World Limit (3):* The specified build-tag constraint dimensions correspond to
  more enumerable build worlds than the set $2^20$ limit.
- *Permutation Limit (3):* The total build permutations that would be
  independently analyzed exceeds the configured limit of $256$ permutations
  after deduplication by set of admitted files.

// somewhat-comically useless given the very low numbers and the existing
// textual description above
// #figure(
//   charts.aborts,
//   caption: [
//     ...
//   ],
// ) <xx2>

The two parse errors correspond to extremely particular cases, the first one
caused by an extremely large float literal in a fuzzing tool's payloads list
(`glowy-go-parser` only supports up to 64 bits of precision) and the other one
an unresolvable escape sequence in an enormous string literal with close to a
million pre-escape bytes, encoding cryptographic data.

On the other hand, the world limit was reached by well-known production-grade
modules, namely Prometheus
#footnote(link("https://github.com/prometheus/prometheus")) (in sample B.I),
Tailscale#footnote(link("https://github.com/tailscale/tailscale")) (B.I), and
TinyGo's drivers#footnote(link("https://github.com/tinygo-org/drivers")) (B.II).
Glowy calculated approximately $2^38$, $2^109$, and $2^66$ potential
combinations for them, respectively, which are undoubtedly too many worlds to
consider. The underlying problem, however, is that the majority of these
combinations is impossible for the project's build model, so they should not be
counted at all, as many tags are never or are always satisfied together. It is
nevertheless impossible for Glowy to systematically determine these
domain-specific assumptions, so this behavior is still appropriate for the
general case.

Finally, the permutation limit follows the same logic as discussed in the
previous paragraph, but with the attenuating factor that it only applies after
deduplication by admitted files, meaning that a violation genuinely corresponds
to distinct file configurations, even if they are still impossible in practice.
The three modules whose analysis was aborted would require, under Glowy's
heuristics, the independent analysis of $352$, $768$, and $896$ build
permutations all above the default limit of $256$.

In light of the explanations above, this work therefore considers the 8 abort
cases to be acceptable, given the degree project's limitations.

#pagebreak()

Modules with diagnostics may be assigned to that outcome class because of either
reported warnings or errors (or both), with errors being further divisible
into confidentiality-related and integrity-related.
@eval:results:overview:avg-median-problems shows per-sample distribution for
modules with at least one warning or error.

#subfigures(
  figure(
    charts.avg-problems,
    caption: [Average reported problems per dataset and band],
  ),
  <eval:results:overview:avg-median-problems:avg>,
  figure(
    charts.median-problems,
    caption: [Median reported problems per dataset and band],
  ),
  <eval:results:overview:avg-median-problems:median>,
  caption: [Reported warnings and errors for modules with diagnostics],
  label: <eval:results:overview:avg-median-problems>,
)

It should be noted that the division into confidentiality or integrity errors is
only possible in light of the distinction made by the Base Security Policy,
used for these evaluation runs, which uses different deny-sink labels for each
kind, namely $cal(L)_"Conf" = {"secret" thin : thin *}$ and
$cal(L)_"Int" = {"untrusted" thin : thin *}$.

=== Outliers

Most samples present a very significant disparity in reported problems per
module between the average case and the median case; it should be stressed that
@eval:results:overview:avg-median-problems:avg and
@eval:results:overview:avg-median-problems:median use significantly
different Y-axes, hence being shown on different sides of their respective
charts.

This variation can also be visualized by means of box plots, as shown in
@eval:results:outliers:problem-boxes, which considers for each problem kind only
the modules with at least one matching report for that kind. Outliers are not
plotted because they would significantly distort the chart, as some modules have
even $300$ reported problems of one kind.

#figure(
  charts.problem-boxes,
  caption: [Problem-specific reports for modules with at least one],
) <eval:results:outliers:problem-boxes>

Both @eval:results:overview:avg-median-problems:median and
@eval:results:outliers:problem-boxes clearly identify that the median module
within the Diagnostics outcome class has very few associated diagnostics,
demonstrating a significant skew attributable to some few modules with very high
diagnostic counts.

This is especially true for insecure flow errors, which disappear entirely
between @eval:results:overview:avg-median-problems grand total columns's when
switching from average to median, and is clear from the unusually-large upper
whiskers of @eval:results:outliers:problem-boxes. Notably, the upper whisker
corresponding to confidentiality flows is shorter simply because the next
datapoint exceeds the conventional $1.5 thin times thin "IQR"$ limit.

As such, there is a clear indication that outliers are of particular relevance
to these results, requiring finer-grained examination.

#pagebreak()

@eval:results:outliers:pareto shows a Pareto chart with the $15$ projects whose
modules most accumulated insecure flow reports, tracking their individual and
cumulative contributions to the global error count.

#figure(
  charts.outliers,
  caption: [Top 15 projects by errors reported],
) <eval:results:outliers:pareto>

The chart makes it clear that these outliers are responsible for the observed
disparity between median and average numbers of diagnostics. After the
15#super[th] project, the cumulative share is already at three-quarters of the
total error pool across all modules, thus indicating that the others report
relatively few.

In particular, the top contributor's only module,
`github.com/multica-ai/multica/server`, causes $301$ errors to be reported by
the taint analysis. Upon inspection, this appears to be related to multiple
instances of conservative taint propagation causing essentially the entire
codebase to be tainted, as returning from `main` on secret validation failure
will implicitly taint the remainder of the function with a
${underline("secret") thin : thin "env"}$ branch label (early abort).
Moreover, some cases trigger Blanket Security Policy directives even if they
are not applicable, such as reading the environment variable `AUTH_TOKEN_TTL`,
which is a blanket source for containing `_TOKEN`.

It is thus clear that these policy violations, as reported by Glowy, are
primarily instances of Blanket Security Policy not offering sufficient
precision, as it cannot distinguish between safe and unsafe patterns around
potentially dangerous constructs. Glowy prioritizes soundness at all times
unless it is otherwise aware of specific guidance in a certain direction.

=== Warnings

Considering the results from a different angle, there is a significant
number of modules reporting analysis warnings, as had been shown in
@eval:results:overview:avg-median-problems and
@eval:results:outliers:problem-boxes. Specifically, out of the the $126$ modules
with diagnostics, $78$ of them reported at least one warning, corresponding that
figure to #share(78, 126).

This is concerning because warnings typically compromise the reported findings,
as they represent situations wherein the analyzer detected a broken invariant
and had to remediate by making unsound assumptions so that the analysis could
proceed. In some cases this does not disqualify entirely the reported results,
but in others it is a legitimate clue that the emitted diagnostics ought to be
doubted.

Based on broad empirical observations of the reported results, warnings are
typically reported upon contact with unsupported Go (i.e., not in the subset
laid out in @methods:subset), including complex patterns that are not handled
by the analyzer.

Another major significant factor is the blackboxing mechanism used to model
external dependencies, as it sometimes may prove insufficient for a deep
analysis of the program's flows. In many cases, black boxes cause a very
significant lack of precision, or even influence incorrect assumptions,
especially in terms of value shape derivation. This can easily cascade to other
operations; e.g., a map wrongly presumed to be an array will cause a warning to
be reported every time ```go v, ok := m[k]``` syntax is used.

However, this is not always connected to lack of coverage.
@eval:results:warnings:top-warnings shows that a significant share of warnings
are due to accesses to an unknown symbol or due to duplicate symbol
declarations, corresponding to a combined share of $71.83%$. These two
categories, more than the others, occur predominantly in cases where exhaustive
build constraint permutations analysis causes incompatible files to clash (or
the opposite, with inter-file dependencies sometimes not being met) in worlds
that are assumed by the developers to be impossible based on project-specific
build constraints.

/*
$ rg 'warning\[' failure-outputs | cut -d'[' -f2 | cut -d']' -f1 \
  | sort | uniq -c | sort -nr

    453 G005 --- UnknownSymbol
    134 G016 --- InvalidLeftValue
     85 G004 --- IllegalRedeclaration
     42 G018 --- InvalidSelectionBase
     10 G013 --- UnevenBindingDeclSpec
      7 G020 --- InvalidSlicingBase
      6 G001 --- DistinctPackageName
      4 G017 --- ImmutableLeftValue
      2 U001
      2 G028
      2 G012
      2 G003
      1 P001 )
      1 L009 )
*/

#let top-warnings = (
  (453, `G005`, [Unknown Symbol]),
  (134, `G016`, [Invalid Left Value]),
  (85, `G004`, [Illegal Redeclaration]),
  (42, `G018`, [Invalid Selection Base]),
  (10, `G013`, [Uneven Binding Decl.]),
  (25, [---], emph[Others]),
)
#let total-warnings = top-warnings.map(((count, _, _)) => count).sum()

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (right, right, auto, auto),

    table.header(strong[Amount], strong[Share], strong[Code], strong[Name]),

    table.hline(y: top-warnings.len(), stroke: 1pt),
    ..top-warnings
      .map(((count, code, label)) => (
        zero.num(count),
        share(count, total-warnings),
        code,
        label,
      ))
      .flatten(),
  ),
  caption: [Top warnings reported across all modules],
) <eval:results:warnings:top-warnings>

Given the potential unsoundness indicated by warnings, it thus makes sense to
consider the findings for modules that did not report any. In addition to the
aforementioned #zero.num(222) which completed analysis without any diagnostic,
#zero.num(48) modules had exclusively error diagnostics (i.e., without any
warnings). This corresponds to a total of #zero.num(270) modules whose audit
successfully completed and did not report any warnings, representing
#share(270, results.len()) of the total #zero.num(results.len()).

Taking the median to mitigate outlier-derived bias and ignoring all modules with
any reported warnings, @eval:results:warnings:median-errors highlights how
audits reporting insecure flows tend to have more confidentiality-related
problems detected than integrity-based.

#figure(
  charts.median-errors,
  caption: [Median insecure flows in modules with errors without warnings],
) <eval:results:warnings:median-errors>

#pagebreak()

This potentially has to do with confidentiality-focused blanket directives in
Glowy's Base Security Policy being more generally applicable, while
integrity-adjacent directives are more sparse, even though there are more source
and sink directives targeting integrity (#zero.num(56 + 128)) compared to
confidentiality (#zero.num(52 + 109)), in absolute numbers.

For instance, blanket source directives focusing on environment variables are
very likely to trigger for almost any program that has secret-named inputs (or
reads variables dynamically through chains not modeled by simple constant
values), while web-framework-centric source directives only apply if the program
employs that specific framework. Additionally, as a compromise in the interest
of balancing security value with usability, the Base Security Policy only
defines integrity sources for @http\-focused targets, meaning that it will
always be less likely for integrity flows to be detected in programs
that do not implement some flavor of a web server.

Nevertheless, it is important to note that this imbalance between
confidentiality and integrity reports is not an undesired property: the two
kinds operate on orthogonal axes and complement each other; any parity would be
artificial and coincidental.

=== Effectiveness <eval:results:effectiveness>

It is difficult to measure if and to what extent Glowy was effective at
identifying security vulnerabilities across the #zero.num(results.len())
examined modules since there exists no objective set of vulnerabilities for the
sampled projects.

As already noted at the beginning of the present @eval:real-world, it is not
feasible nor desired to attempt to determine a ground truth for every evaluated
module against which the obtained results could be compared, since security
validation and risk acceptance is necessarily a domain-specific endeavor
reserved to each project's stakeholders, such as developers and maintainers.

However, while a set of true positives, is not accessible to this work in the
general case, some are distinguishable based on an individual basis, stemming
from manual perusal of the reported findings and the corresponding codebase
sections for each respective module.

Through the thorough examination of selected cases and a high-level surveying of
the results, it is clear that the majority of the reported findings constitute
false positives, especially when considering sanitization, but there are
nonetheless some other cases that stand out as real vulnerabilities.

#pagebreak()

For instance, Glowy detected an integrity-based insecure flow where a web server
used an @http query parameter verbatim as the target to a GET request without
performing any validation. This is an @ssrf vulnerability because remote,
unauthenticated clients can mislead the server into performing a request to any
address, including within the server's internal network and to services bound to
loopback addresses. @ssrf is a serious attack because it exploits the server's
authority and abuses the access it has.

Glowy's reported error finding is reproduced below in
@eval:results:effectiveness:vk-golang (trimmed).

#cmd-output(
  read("../assets/vk-golang.ansi"),
  text-size: 0.7em,
  caption: [Example @ssrf:short true positive finding],
  label: <eval:results:effectiveness:vk-golang>,
)

The example diagnostic displayed above, standing as a representative of the
several comparable findings across the results set, corresponds to the sample
C.II project hosted on GitLab under `vk-golang/lectures`
#footnote(link("https://gitlab.com/vk-golang/lecture")), which is a
Russian-language educational repository presumably supporting a
university-style course about Go. VK is the largest Russian social media
service, with its VK Education program interfacing with schools and universities
to collaborate so that its engineers teach students about particular topics.

The file path within the repository where the vulnerability was found is
explicitly `/07_sec/06_ssrf/ssrf.go`, which confirms that the finding is a real
@ssrf:long flow, as intentionally designed by the course faculty to illustrate
the said kind of attack within the context of the Go programming language to
students taking part in VK Education's Go course.

#v(1fr)
#highlight[more]

#pagebreak()

This is therefore a definite true positive, in the technical sense, even if
intentionally and artificially crafted for explanatory purposes. Importantly,
the reasoning behind the vulnerability and the educational character of the
overarching repository does not in any way reduce or demerit the analyzer's
capabilities. On the contrary, the very explicitness of the security issue
substantiates the conclusion that Glowy can identify true security issues and
brings real security value.

Another case is that of Commento
#footnote(link("https://gitlab.com/commento/commento")), sampled from stratum
C.I, an open-source commenting platform aiming to be an alternative to Disqus
#footnote(link("https://disqus.com")), a widely-used service. The underlying
premise is that publishers and blog owners can embed Commento (or Disqus) on
their website, and the conversation service provides and manages comments and
discussions for a particular article, so that such complex handling (including
user sessions) does not have to be implemented by the host website.

Glowy detected two independent @ssrf vulnerabilities in Commento. The first one
relates to two individual but analogous flows in the project's data importing
pipeline, wherein any authenticated user (of a special type consigned for
self-designated owners of other Commento-hosting sites, with no validation
being performed) can trigger an import (GET request) from any address. Owner
user-type registration is enabled by default, so even self-hosted instances are
likely vulnerable.

The second identified security problem is a stored @ssrf vulnerability related
to user profiles. It stems from the fact that users may edit their own profile
picture by specifying an arbitrary @url, for which no validation whatsoever is
performed before it is stored in the database. Any subsequent (unauthenticated)
requests to Commento's @api endpoint for that user's profile picture trigger a
GET request to the configured @url, since the server attempts to download the
image to rescale it as required.

Neither of these external-request mechanisms have protection against iterative
redirects, @dns rebinding, or reject internal or loopback network addresses.
Both vulnerabilities present high exploitability and can be used to cause
denial of service to either the server itself, or to other targets; e.g.,
an attacker might mask their identity by having Commento proxy requests to a
victim of a distributed denial of service attack.

The vulnerabilities described in the preceding paragraphs were responsibly
disclosed to Commento via GitLab Confidential Issues, since the project does not
have a security policy or define any other preferred form of intake.

However, it appears that the project has been fully abandoned since early 2021
(more than 5 years ago, at the time of writing), with the maintainer not
showing any activity nor answering users' queries about the status of the
project. Commento's commercial hosted solution also reportedly stopped
responding to users' contact requests @moses2025commento, and while its domain
`commento.io` is still registered, the website itself just shows an error page.

As such, these issues are not expected to have a significant impact on
production usage#footnote[This is also the fundamental reason for why they are
  described here so openly, despite not having been patched.], since the project
is effectively discontinued and does not seem to have active users.
Nevertheless, they still comprise true positives in a (once) popular, real-world
Go project, again serving as a testament to Glowy's capabilities in detecting
true vulnerabilities in real codebases.

Other true positives correspond mostly to dangerous flows in the literal sense,
but that are presumed to be accepted as part of their respective project's
attacker model and risk profile.

Examples include writing an administrator password to logs upon first startup
(acceptable because this is the only way to obtain it if automatically
generated, and those with access to first logs would usually be able to modify
it directly anyway), outputting incoming @http Bearer credentials (only in debug
mode, and as an explicit instruction that outputs only the token, making the
operation clearly intended), or an @ssrf request-to-arbitrary-URL vulnerability
(in a network router utility that implicitly trusts its @api users for all
endpoints, since they are physically connected to the router's local network
and possibly authenticated, when authentication is enabled).

In general, the collected results support that Glowy is effective at identifying
security vulnerabilities in real Go projects, though without any additional
project-specific configuration it also reports a significant number of false
positives.

#pagebreak()

=== Performance <eval:results:performance>

Another significant aspect to Glowy's usability and overall goal accomplishment
is the analyzer's efficiency and speed, since a faster tool is more suitable for
inclusion in a project's development lifecycle, such as in @ci pipelines
as a required check that must pass before features can be shipped, or even as a
pre-commit hook on developers' local machines, offering a virtually-immediate
feedback loop so that potential problems can be caught early even before the
first push.

// nanoseconds
#let all-global-run-times = (
  results
    .filter(row => row.global_run_time not in ("", "0"))
    .map(row => int(row.global_run_time))
)

#let avg-global-run-time = (
  all-global-run-times.sum() / all-global-run-times.len()
)
#let avg-global-run-time = calc.round(avg-global-run-time / 1e9, digits: 2)

#let median-global-run-time = median(all-global-run-times)
#let median-global-run-time = calc.round(
  median-global-run-time / 1e6,
  digits: 2,
)

For the #zero.num(results.len()) analyzed Go modules, the measured (wall-clock)
global run time (between `glowy-cli` process spawning and captured output
buffers becoming available) comprised an average of
#zero.num(avg-global-run-time) seconds and a median of
#zero.num(median-global-run-time) milliseconds. This excludes Empty modules,
whose run time is not reported.

The two orders of magnitude difference between the average and the median is
once again attributable to outliers, since the data is demonstrably skewed, as
shown by the box plots in @eval:results:performance:run-time-by-outcome.

#subfigures(
  figure(
    charts.run-time-by-outcome(zoom: false),
    caption: [All outcomes],
  ),
  figure(
    charts.run-time-by-outcome(zoom: true),
    caption: [Zoomed version on lower values],
  ),
  caption: [Per-module global recorded run time per outcome],
  label: <eval:results:performance:run-time-by-outcome>,
)

#pagebreak()

For the purpose of identifying the most significant outliers, a Pareto chart is
again used, as shown in @eval:results:performance:pareto, this time showing the
top 15 projects whose modules contribute the most towards the total sum of all
of the #zero.num(all-global-run-times.len()) non-empty modules' global run time.

In addition, besides individual and cumulative contributions, the chart also
plots each project's total aggregate @sloc#footnote[@sloc corresponds to the
  total lines of source-code across all of a module's Go files, excluding blank
  lines, comments, and (in this work) also inner multi-line string literals.] on
a separate axis, scaled for each module by multiplying the recorded @sloc by the
module's build permutation count. This operates under the assumption that, in
most cases, the majority of a module's code is re-used across most or all
permutations (i.e., not subject to constraints), which means that it must be
re-processed for each permutation.

#figure(
  charts.run-time-outliers,
  caption: [Top 15 projects by global run time with scaled @sloc:short context],
) <eval:results:performance:pareto>

#pagebreak()

The chart in @eval:results:performance:pareto highlights some degree of broad
correlation between the
permutations-scaled @sloc and the aggregate global run time, especially for the
first and most significant case (`cznic/ccgo`, sample C.I).

#let remaining-run-time-share = 100 - 81.76104550216284

Nevertheless, the relation is not so clear, as @sloc and build constraint
permutations are not authoritative, self-standing indicators representative of a
codebase's complexity, especially specifically for the purposes of static taint
analysis. In any case, though, the referenced 15 projects already comprise a
very significant share of the total global run time aggregate, leaving only a
remainder share of
#zero.num(calc.round(remaining-run-time-share, digits: 2), suffix: [$%$])
unaccounted for, which corresponds to all the other
#zero.num(unfolded-projects - 15) projects admitted to analysis.

In order to better understand the relationships between the different variables,
@eval:results:performance:scatter shows a scatter plot of each module's global
run time as a function of its @sloc (unscaled).

Only completed runs are included (with and without diagnostics), since aborts
and crashes do not represent natural run times. Both axes are logarithmic, and
the marker shape and color indicate a discrete range of build constraint
permutations.

#figure(
  charts.run-time-scaling,
  caption: [Analysis run time as a function of @sloc:short for completed runs],
) <eval:results:performance:scatter>

#pagebreak()

The log-log fit shown as a dashed line follows the approximate equation

$ y(x) = e^(-9.28) times x^(1.06) $

which empirically shows slightly superlinear relationship between a project's
global run time and its calculated @sloc. The fit is decent in log-log space but
not perfect ($R^2 = 0.78$), supporting a general relationship between the two
variables.

Morever, in an effort to better understand the composition of this global run
time, @eval:results:performance:stages showcases per-stage run time distribution
according to a reconstructed time for each module that completed analysis, which
corresponds to the sum of each stage's recorded elapsed time as reported by
`glowy-cli` itself. Each stage time is an average for all build permutations,
and all averages are additionally multiplied by that number of build constraint
permutations. Parsing is not multiplied because it only takes place once.

#figure(
  charts.stages,
  caption: [Reconstructed analysis-stage costs by @sloc:short quartile],
) <eval:results:performance:stages>

The figure above demonstrates how Stage \#2 stabilization becomes more and more
the dominant stage, in terms of run time, as larger modules are analyzed, with
@sloc representing total module size. This is expected, as Stage \#2 comprises
the grand majority of the taint flow logic and must process each part of the
program multiple times until label convergence.

#pagebreak()

Regarding convergence iterations, when summarizing outputs, `glowy-eval`
recorded for each successful run the minimum, maximum, and total Stage \#2
passes required for security labels to stabilize, acros all of the module's
build permutations. For example, if a module required 4 independent build
permutation analyses and each of their respective convergence loops terminated
after $2$, $6$, $4$, and $2$ iterations, then the minimum observed iterations is
$2$, the maximum is $6$, and the total is $14$. The average iterations per
build permutation can additionally be derived by dividing the total number by
the number of permutations, such as $frac(14, 4, style: "skewed") = 3$ here.

@eval:results:performance:iters summarizes the aforementioned datapoints
according to their lowest observed value, median, average, and highest value
within the results set, for modules which completed analysis.

#figure(
  table(
    columns: (auto, auto, auto, auto, auto),

    table.header(
      strong[Measurement],
      strong[Lowest],
      strong[Median],
      strong[Average],
      strong[Highest],
    ),

    table.vline(x: 1, stroke: 1pt),
    [Min. Iterations], zero.num(2), zero.num(4), zero.num(4.39), zero.num(32),
    [(Avg. Iterations)], zero.num(2), zero.num(4), zero.num(4.39), zero.num(32),
    [Max. Iterations], zero.num(2), zero.num(4), zero.num(4.44), zero.num(32),
    [Total Iterations],
    zero.num(2),
    zero.num(4),
    zero.num(12.41),
    zero.num(836),
  ),
  caption: [Summary of convergence iterations by build permutations],
) <eval:results:performance:iters>

The notable similarity between indicates how different build permutations for
the same module tend to converge under the same amount of iterations. In
particular, there are only $8$ cases in the results set where the minimum
required iterations differed from the maximum required iterations, whereas $80$
modules with multiple build permutations still had the same minimum and maximum
required iterations values.

The disparity on the bottom-right of the table is simply because the number of
total iterations is multiplied by the number of build permutations.

#v(1fr)
#highlight[more]

#pagebreak()

The maximum number of convergence iterations is plotted graphically in
@eval:results:performance:cumulative, which presents the value's empirical
cumulative distribution for modules which completed analysis. The chart is read
as a cumulative share, since modules that have converged at lower iteration
counts have necessarily also already converged at higher counts.

It is worth mentioning that the minimum number of iterations, for instance, is
not plotted because it has a very high correlation with the maximum value (as
had been noted in @eval:results:performance:iters) and thus would almost
completely overlap the maximum measurement.

Moreover, the most interesting metric is undoubtedly the maximum number of
iterations required for convergence, as all permutations must complete for
analysis to finish, and the number of total iterations is not comparable as it
depends on permutation count. The former value is thus the one most appropriate
for graphical presentation.

#figure(
  charts.iterations,
  caption: [Distribution of the maximum convergence iterations],
) <eval:results:performance:cumulative>


Together, @eval:results:performance:iters and
@eval:results:performance:cumulative definitively show that the vast majority of
modules converge within a reasonable number of iterations.

When combined with the #zero.num(median-global-run-time) milliseconds figure
presented at the beginning of this subsection, which denoted the median global
run time for non-empty modules, it is clear that Glowy achieves respectable
performance despite its robust taint model. Moreover, this number can be reduced
even further to a median of #zero.num(152.11, suffix: [$thin "ms"$]), if only
considering completed runs.

#pagebreak()

== Summary

In conclusion, this degree project evaluates the Glowy static taint analyzer and
its Base Security Policy by using the developed tool to audit
#zero.num(results.len()) Go modules extracted from $291$ popular, open-source,
real-world projects, selected using stratified sampling from complementing
datasets.

The analysis produced a significative number of false positives due to the
necessary soundness-preserving over-conservativeness, as it lacked any
project-specific configuration and relied only on the Base Security Policy's
generic assumptions, but it also identified a considerable number of true
positives corresponding to real security vulnerabilities, proving Glowy's
worth and capabilities as a security tool.

In general, performance was adequate to the project goals, with a median module
audit time of $152.11$ milliseconds for modules which completed analysis (the
vast majority) and #zero.num(median-global-run-time) milliseconds when
considering all non-empty modules.

Moreover, a corpus of #zero.num(total-benchmarks) correctness benchmarks were
developed to represent the ground truth in terms of what is expected of a Go
security analyzer with respect to @ifc:long. This corpus is a significant
research contribution as it can be used for future work, but it also directly
evaluates Glowy's capabilities and guarantees its sound and precise support of a
very wide range of Go constructs and functionalities.
