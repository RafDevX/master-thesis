#import "@preview/timeliney:0.2.0"

#import "../common/simple.typ": setup_simple, kthblue

#let title = "Efficiently Tracking Information Flow in Go"
#let today = datetime(year: 2025, month: 3, day: 3)
#let keywords = ("information flow", "non-interference", "static analysis")

#show: setup_simple.with(
  title: title,
  doc_name: "Degree Project Individual Plan",
  keywords: keywords,
  written_date: today,
  scoped_header: false, // sadly doesn't fit otherwise; title grew
)

// [The individual plan needs to be prepared within a few weeks after project
// start, and has to be approved by the examiner. The document should be 3-4
// pages long.]

= Project Information

- *Preliminary Title:* #title
- *Student:* Rafael Serra e Oliveira (#link("mailto:rmfseo@kth.se"))
- *Examiner:* Prof. Philipp Haller (#link("mailto:phaller@kth.se"))
- *Supervisor:* Prof. Musard Balliu (#link("mailto:musard@kth.se"))
- *Date:* #today.display("[weekday], [month repr:long] [day padding:none], [year]")
- *Keywords:* #keywords.join(", ")

= Background & Objective
// [Description of the area within which the degree project is being carried out
// with connection to scientific and/or societal interest.
//
// Description of the interest of the organization or company who provided the
// assignment.
//
// The high level objective of the project, the desired outcome from the
// perspective of the assignment provider.
//
// The background knowledge required to carry out the project.]

An important problem within Cybersecurity is how to systematically isolate what
is trusted or secret from untrusted or public data, especially in terms of what
information should be accessible or used where. This aligns primarily with the
high-level aspects of *Confidentiality* and *Integrity* of the CIA triad and has
widespread implications for how security vulnerabilities might manifest within
software products.

Theoretical models already exist and have been shown to be mathematically
robust, such as initially proposed by Bell and LaPadula in 1973 @bell-lapadula
and further developed by Denning in 1976 @dorothy. However, it would be
desirable to enforce these assurances on arbitrary programs without relying on
them to implement one of these mechanisms correctly. Such a zero-trust approach
would allow principals to independently verify whether programs are secure (from
this perspective) and equip developers with the necessary tooling to find
vulnerabilities in their own projects.

*Information Flow Control* is a technique that allows tracing how information is
used throughout a program's lifetime, keeping track of both explicit and
implicit dependencies to identify flows between sources and sinks @sabelfeld. In
particular, it is often implemented as higher-order software that operates on
other programs either by analyzing their source code before they run or by
injecting dynamic monitoring logic into the final executable.

*The Go programming language* was created by Google in 2007 and has recently
seen extensive adoption across a wide array of applications. An increasing
number of critical, production-grade Go projects are becoming more and more
prevalent throughout the world, such as
#link("https://github.com/docker", [Docker]),
#link("https://github.com/kubernetes/kubernetes/", [Kubernetes]), and
#link("https://github.com/rclone/rclone", [rclone]), which showcases the
language's growing relevance.

Go is compiled, statically typed, and has a number of interesting constructs
that, while on the one hand extend its usefulness for programmers, on the other
hand also present new challenges for information flow control such as
concurrency (via _goroutines_) and message-passing (via _channels_).

The student has previously co-authored a Rust tool called
#link("https://github.com/ist199211-ist199311/glowy-langsec", "Glowy") as part
of a project within the course
#link("https://www.kth.se/student/kurser/kurs/DD2525?l=en",
 "DD2525 Language-Based Security") which implements taint tracking to perform
static analysis of simple Go programs and detect some insecure flows. However,
this was merely a basic prototype with minimal language support and it is now
desired to extend it further so that it can be used in real-life settings.

#pagebreak() // ideally after the next paragraph, but doesn't fit...

This proposed extension and especially the necessary theoretical developments
that precede it is what forms the basis for the student's degree project work.

*In essence, the primary objective of this degree project is to study the
feasibility of using static information flow analysis techniques to detect
certain kinds of security vulnerabilities in modern Go programs.* More
concretely, the project's goal is to develop techniques and tooling for
revealing confidentiality and integrity faults in Go programs, followed by an
evaluation step wherein these tools are tested against real-world projects.

Emphasis is put chiefly on _efficacy,_ with the tools striving first and
foremost to minimize false negatives within their area of application.
Nevertheless, they should still take into account reasonable considerations to
avoid false positives, such as in cases where suspicious situations can actually
prove to be innocuous in light of a deeper analysis.

In tandem, care is also taken to perform this analysis _efficiently,_ aiming for
actionable results to be presented within a reasonably short timeframe. Though
the output's accuracy is fundamental, yielding it quickly allows developers to
receive near-real-time feedback on their code and so reduces disruptive
task-switching, thus maintaining productivity. In this sense, it is an explicit
project goal for the developed tools to promote and allow for their regular
execution, as to come across as a helpful linting aid, rather than
unpredictable, slow, and blocking.

At a high level, this means that background knowledge must be acquired with
regard to several broad aspects, such as existing data flow characterization
theory, Go-specific functionality and runtime behavior, as well as efficient
techniques for source code parsing and interprocedural analysis.

= Research Questions & Method
// [QUESTION: State the question that will be examined. Formulate it as an
// explicit and evaluatable question. State your hypothesis.
//
// Objectives: Break down the research questions to measurable objectives.
//
// Tasks: Describe the tasks that are necessary to reach the objectives. For
// each task, describe the challenges it involves.
//
// Method: Describe the method/s that will be followed. Explain why they are
// appropriate for the project or for the specific tasks.
//
// Ethics and Sustainability: Does the project address questions of ethics or
// sustainability? Does the project raise ethical or sustainability questions?
// If yes, how could those be handled?
//
// Limitations: Define the limitations on what is to be done (so that it is
// clear what is not included in the degree project).
//
// Risks: Explain what can go wrong and delay or make the project impossible to
// conclude. Explain how you will deal with these problems.]

This degree project will aim to investigate the following research questions:

#[
  #set enum(
    full: true,
    numbering: (..nums) => strong[RQ#numbering("1.1.", ..nums)],
  )

  + How to efficiently track information flow in arbitrary Go programs through
    static analysis?
    + How to systematically detect flows of secret data to public outputs?
      #smallcaps[(Confidentiality)]
    + How to systematically detect flows of untrusted inputs to critical parts?
      #smallcaps[(Integrity)]
  + Can information flow analysis effectively identify true security
    vulnerabilities in Go projects with minimal domain-specific knowledge and
    configuration?
  + How prevalent are detectable security issues in popular
    production-grade tools and frameworks written in Go?
]

Each of these is expanded on in more detail over the following subsections.

== RQ1: Efficient Information Flow Tracking in Arbitrary Go Programs

This base research question serves as a fundamental stepping-stone for all the
others, comprising the foundational development of the data flow tracking tool
itself, both in theory and in code.

The tool ought to target a significant, if not complete, coverage of the Go
programming language, prioritizing the most commonly used constructs in order to
support the majority of mainstream projects written in compatibility with
contemporary Go versions (i.e., approximately Go 1.24.x).

It will likely make use of taint tracking to propagate labels from sources to
sinks, with both of those presumably relying on annotations to characterize what
label constraints they define. When an illegal flow is detected, for example
from a source with label ${"Admiral"}$ to a sink that only accepts
${"Sergeant"}$, the issue is conveyed to the user (e.g., the application
developer) as intuitively as possible.

In terms of specific tasks, this includes an initial in-depth literature review
to understand the field's state-of-the-art (see @pre-study), followed by a first
modelling of the tool's design. Finally, based on that, the tool itself is
developed according to its stated goals, such as efficacy, efficiency, and
usability.

#pagebreak()

This process implicitly addresses *RQ1*'s sub-questions, but specific
considerations are laid out below.

=== RQ1.1: Detection of Confidentiality Faults

An explicit effort must be made to apply the tool's information flow tracking
capabilities to detecting unintentional leakage of domain secrets into public
outputs. In practice, this means ensuring that the tool supports varied
constellations of source/sink configurations which can be important for
detecting common confidentiality problems.

As a result, a suite of test cases should be developed in an attempt to
representatively ensure that key examples of vulnerabilities, or innocuous edge
cases, are correctly handled by the tooling. This should be done primarily prior
to the development of the tool itself, so as to double as concrete guidance to
what it needs to support.

=== RQ1.2: Detection of Integrity Faults

Similarly, the aforementioned test suite must also be written to verify that the
tool is capable of being configured to find common patterns of integrity faults,
wherein untrusted information (e.g., from user input) is passed unsanitized to
critical components vulnerable to manipulation (e.g., raw file path).

This will highlight specific nuances of features that should be supported to
allow sufficient flexibility for general use, e.g., marking the query part of
a database driver invocation to be vulnerable to SQL injection, while still
allowing for user input to be sent as part of explicit prepared statement
parameters.

== RQ2: Effective Domain-Specific Vulnerability Flagging <sensible>

In addition to the tool's inherent development as required by *RQ1*, it is
critical to focus on its ease of configuration, while still allowing for
flexibility. This means that, besides allowing for granular customization, it
should be relatively simple to obtain significant results from a first-time
analysis of a new project with little to no domain-specific configuration.

Concretely, this can likely be achieved in some fashion through the inference
of sensible defaults according to the capabilities associated with specific APIs
as used by the code. For example, the file path parameter of `os.WriteFile` is a
likely integrity sink, while many fields of `http.Request` would in most cases
be considered untrusted, so a flow from the latter to the former would result in
a violation.

Evidently, such sensible defaults would almost never be sufficient to model the
domain's complexity, including what (in context) is secret/public or
trusted/exploitable, so it would necessarily never be as secure as a careful,
reasoned configuration of sources and sinks. Nevertheless, in some cases it
might be sufficient to indicate major security problems and, in any case, it
serves the purpose of interactively demonstrating to a new user how the tool can
be used.

Furthermore, given such a generic starting point, it should be simple to easily
get more and more significant and accurate reports with every small incremental
change to the configuration, allowing the tool to gain a wide insight of the
domain with only a limited number of tweaks.

== RQ3: Measurement of Vulnerability Prevalence within Go Ecosystem

Armed with an initial version of the tool (per *RQ1*) and some coarse
quick-configuration strategy (per *RQ2*), a number of third-party Go projects
will be selected to undergo analysis in order to determine if any real security
problems can be discovered by means of this technique. The tool will be executed
both with only its most basic configuration ("sensible defaults", likely based
on capability-linked API usage, per @sensible) and again after a more in-depth
manual tuning (though likely still cursory due to limited domain-specific
knowledge and time, see @limitations).

This will provide a general basis for evaluation of the tool's performance and
may even lead to adjustments in its behavior or extensibility.

#pagebreak()

== Ethics and Sustainability

All external projects chosen to be analyzed, particularly in connection to
*RQ3*, will be exclusively source-available software. In addition, any potential
security vulnerabilities discovered will be reported via stated responsible
disclosure procedures for immediate patching by the project maintainers.

If the tool is later used by third-parties to secure their projects, even in
proprietary and/or confidential codebases, this would not pose an additional
(direct) risk for those projects, since all analysis is performed locally and
the tool could be easily audited to verify that it does not contact any other
hosts. Sandboxing would also be possible without loss of functionality.

In addition, although this degree project does not directly relate to
sustainability, it contributes towards cybersecurity at large and so can
feasibly indirectly aid with the protection and overall resilience of, e.g.,
critical software for disaster relief or control of green smart devices, among
others.

== Limitations <limitations>

The project will attempt to maximize support of common Go constructs as used in
modern projects, but time constraints might mean that full language support
cannot be achieved.// and so is sacrificed in lieu of other developments.

Additionally, unsafe Go code (i.e., any usage of the `unsafe` package) will not
be supported due to breaking critical assumptions (e.g., type safety) and
explicitly being non-portable (which could lead to inconsistent tool output in
different platforms).

Moreover, despite an effort being made to come up with sensible defaults for a
new project (see @sensible), these are only intended to be better than no
configuration whatsoever, and should not be construed to represent the full
benefit of using the tool extensively configured for a particular project.

In turn, this can affect the evaluation step of *RQ3*, since the student will
never have full domain knowledge of all the third-party projects analyzed; in
other words, there is insufficient domain expertise to guarantee correctness of
the configuration for any one project except by its maintainers. There is also a
trade-off between time spent reading up on and adjusting settings to a specific
project, versus time spent analyzing more projects.

== Risks

The primary danger that can compromise the project's feasibility is the short
time period under which it must take place, with such limited time constraints
potentially exacerbating any difficulties encountered, cascading into even
stricter time boundaries for the tasks that follow. An effort will be
continuously made to prioritize and re-evaluate priorities according to the
circumstances and the project's fundamental goals, as well as the Supervisor's
advice and guidance.

= Evaluation & News Value
// [Evaluation: How is it determined if the objectives of the degree project
// have been fulfilled and if the research question has been adequately
// answered? What kind of qualitative or quantitative measures can be defined
// and evaluated?
//
// Expected scientific results: How is the work scientifically relevant?
//
// The work's innovation/news value: Why does someone want to read the finished
// work? And who are these people?]

The degree project's objectives are, in general, determined to be fulfilled if
it yields a tool capable of detecting security vulnerabilities in arbitrary Go
programs, which can easily be adopted by new projects, and that has been tested
against multiple third-party, source-available projects with significant impact
or notoriety. It is not necessary that any new vulnerabilities are found in
these projects, since they might not be detectable or exist altogether, but an
attempt to find any must still be conducted.

Quantitatively, the tool should be reasonably efficient, completing within a few
seconds for smaller codebases and within a few minutes for very large projects.
It should support all the constructs used in
#link("https://gobyexample.com/", "Go by Example"), unless otherwise justified.
Qualitatively, it should document its usability benefits.

The final product would be scientifically relevant because it furthers existing
research and applies it to specific constructs in Go, which presents an
innovation that would presumably interest the Go community, as well as the
field of cybersecurity in general, thus affirming the work's value.

#pagebreak()

= Pre-Study <pre-study>
// [Description of the literature studies. What areas will the literature study
// focus on? How shall the necessary knowledge on background and
// state-of-the-art be obtained? What preliminary important references have been
// identified?]

The degree project's work will be preceded by a comprehensive literature survey
aiming to gain a satisfactory understanding of the current state-of-the-art in
static information flow analysis as understood by research and the industry.
Some focus will also be put into studying high-level strategies for efficient
source-code parsing and tree-walking, but extreme optimization is not a goal of
this project.

Important references might be, for example, "Information Flow Analysis for Go"
(2016) @bodden, "Challenges for Information-Flow Security" (2004) @challenges,
and "Parallelizing Top-Down Interprocedural Analyses" (2012) @interprocedural.

Prior work of interest is also
#link("https://github.com/google/go-flow-levee", "Go Flow Levee"), a Go taint
propagation analysis tool seemingly abandoned in 2021
#footnote[Go introduced generics in 2022 @go-1.18, which Levee does not support,
including within the Go standard library.],
#link("https://github.com/atwick/gotcha", "Gotcha"), another Go taint checker
developed for a 2016 Master's thesis, and
#link("https://github.com/google/capslock", "Capslock"), a capability analysis
tool for Go packages.

= Conditions & Schedule
// [List of the resources that are needed to solve the problem. This can be
// technical equipment, software, or data, but also experiment and interview
// subjects.
//
// Describe the way the external supervisor will be involved in the project.
//
// Provide a project timeline, specifying the main tasks and the time allocated
// for them, and milestones (time of achievement of intermediate goals).]

The tool will be developed in #link("https://rust-lang.org", "Rust") and be
based on the existing
#link("https://github.com/ist199211-ist199311/glowy-langsec", "Glowy") prototype
previously co-developed by the student, either by forking it directly or by
adapting parts of it into a new codebase created from scratch. In parallel, a
Degree Project Report will be written in #link("https://typst.app", "Typst") and
worked on continuously throughout the project duration.

Regular meetings will be held between the student and the Supervisor, both
one-on-one and as part of the KTH LangSec group within EECS's
Division of Theoretical Computer Science (TCS).

In terms of scheduling, @timeline below shows a proposed preliminary timeline
for the project.

#figure(
  caption: "Gantt chart of preliminary degree project timeline",
  text(
    size: 0.7em, // fit on last page
    {
      timeliney.timeline(
        show-grid: true,
        milestone-line-style: (stroke: (dash: "dashed", paint: kthblue)),
        //milestone-layout: "aligned",
        {
          import timeliney: *

          let subtask(..args) = task(..args, style: (stroke: 3pt + gray))

          let months = ("March", "April", "May", "June", "July")
          headerline(..months.map(m => group(strong(m))))

          taskgroup(
            title: [*Preparation (3.5w)*],
            {
              subtask("Literature Review (3w)", (0, 0.75))
              subtask("Pre-Study Drafting (2.5w)", (0.25, 0.875))
              subtask(text(fractions: true, "Preliminary Project Selection (1/2w)"), (0.75, 0.875))
            },
          )

          taskgroup(
            title: [*Conceptualization (2.5w)*],
            {
              subtask("Test Suite Development (1.5w)", (0.875, 1.25))
              subtask("High-Level Design (2w)", (1, 1.5))
            },
          )

          task([*Tool Development (1mo)*], (1.5, 2.5))

          taskgroup(
            title: [*Evaluation (3w)*],
            {
              subtask("Final Project Selection (1w)", (2.25, 2.5))
              subtask("Analysis (2w)", (2.5, 3))
              subtask("Tool Adjustments (1w)", (2.75, 3))
            },
          )

          taskgroup(
            title: [*Reporting (>4.5w)*],
            {
              subtask(
                "Final Report Drafting (>2w)",
                (from: 0, to: 3, style: (stroke: (dash: "densely-dotted", thickness: 2pt, paint: gray))),
                (3, 3.5),
              )
              subtask("Presentation Preparation (2w)", (3.25, 3.75))
              subtask("Final Revision (2.5w)", (3.5, 4.125))
            },
          )

          let milestone-text(name, date) = align(
            center,
            text(
              fill: kthblue,
              [
                *#name* \
                #date
              ],
            ),
          )

          milestone(
            at: 0.875,
            milestone-text("Pre-Study Submission", "Mar/Apr 2025"),
          )

          milestone(
            at: 3.5,
            anchor: "north-east",
            milestone-text("Report Submission", "Jun 2025"),
          )

          milestone(
            at: 3.75,
            milestone-text("Oral Presentation", "Jun 2025"),
          )

          milestone(
            at: 4.125,
            anchor: "north-west",
            milestone-text("Final Submission", "Jun/Jul 2025"),
          )
        },
      )
    },
  ),
) <timeline>

#pagebreak()

#bibliography("references.yaml", title: "References")
