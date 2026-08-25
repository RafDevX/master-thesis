#import "./template.typ": *
#import "./utils.typ": *
#import "../03-thesis/acronyms.typ": acronyms
#import "../03-thesis/charts/all.typ" as charts
#import "../03-thesis/utils/code-blocks.typ": setup-codly
#import "../03-thesis/utils/cmd-outputs.typ": cmd-output
#import "../03-thesis/utils/dependencies.typ": codly, glossarium, zero
#import "../03-thesis/utils/tables.typ": setup-tables

#import codly: codly, codly-init
#import glossarium: make-glossary, print-glossary, register-glossary

#let HANDOUT = false
// note that ITEM-BY-ITEM is enabled/disabled in utils.typ
// (i.e., soft handout mode when disabled)

#let dark-blue = rgb("#000061")
#let light-blue = rgb("#def0ff")

#show: setup-tables
#show: codly-init
#show: make-glossary
#set cite(style: "../03-thesis/assets/ieee-et-al-3.csl")

// typst eval --root .. 'query(<pdfpc-file>).first().value' \
//   --in ./presentation.typ > ./presentation.pdfpc
#let pdfpc-config = pdfpc.config(
  duration-minutes: 25,
  last-minutes: 5,
  note-font-size: 18,
)

#show: university-theme.with(
  aspect-ratio: "16-9",
  config-common(
    handout: HANDOUT,
    preamble: {
      pdfpc-config

      setup-codly()

      register-glossary(acronyms)
      // needs to exist so that acronyms work
      print-glossary(
        acronyms,
        disable-back-references: true,
        invisible: true,
      )
    },
    show-bibliography-as-footnote: bibliography(
      title: none,
      "../03-thesis/references.yaml",
    ),
    enable-frozen-states-and-counters: false, // causes non-convergence
  ),
  config-info(
    title: [Glowy: Flexibly Tracking Information Flow in Go Programs],
    subtitle: [Striving for Soundness, Efficiency, and Usability],
    author: [Rafael Serra e Oliveira | rmfseo\@kth.se],
    date: datetime(year: 2026, month: 8, day: 25),
    institution: [KTH Royal Institute of Technology],
    logo: image("../common/KTH_logo_RGB_bla.svg"),
    logo-white: image("../common/KTH_logo_RGB_vit.svg"),
  ),
)

#set footnote.entry(gap: 0.3em, separator: none)
#show footnote.entry: set text(size: 0.5em, fill: black.lighten(20%))

#set table(inset: 0.5em)

#set enum(number-align: start + top)

#let num = zero.num.with(math: false)

// truly a sign of decaying times
#let fig-num-raw = 0
#let fig-num-img = 0
#let fig-num-tbl = 0

#title-slide()

#speaker-note[
  Hello

  Welcome to my presentation about Glowy, flexibly ...
]

---

#{
  show outline.entry: it => if HANDOUT {
    // Name .... page
    it
  } else [
    // - Name
    - #link(
        it.element.location(),
        it.indented(it.prefix(), it.body()),
      )
  ]

  components.adaptive-columns(outline(
    depth: 1,
    title: [Presentation Structure],
  ))
}

= Motivation & Background

== Motivation

#items-with-notes(
  start-empty: false,
  (
    item: [Digital systems are increasingly important@haberzarsky2017reliance],
    note: [
      Society is increasingly reliant on digital systems for critical
      infrastructure,

      which allows for incredible advancements, of course,

      but also makes these digital capabilities significant targets for attacks
    ],
  ),
  (
    item: [Cybersecurity protects society's digital resources],
    note: [
      It's crucial to defend digital assets

      to prevent *unauthorized access* and *ensure they continue to operate* as
      intended,

      so Cybersecurity studies the preservation of Confidentiality, Integrity,
      and Availability
    ],
  ),
  (
    item: [
      Categorization of information
      - Secret vs. Public
      - Trusted vs. Untrusted
    ],
    note: [
      These properties, especially Confidentiality and Integrity, imply
      the distinction of secret from public information, ...
    ],
  ),
  (
    item: [Distinction is not trivial and is purely artificial],
    note: [
      For instance, the very same bits of information can be trusted or not
      depending on where they came from,

      but origin is not a physical property derivable from information
    ],
  ),
  (
    item: [_Metadata_ based on provenance],
    note: [
      This means that, in this case,

      it is often more of interest metadata describing a piece of information

      than the information itself
    ],
  ),
)

---

#items-with-notes(
  start-empty: false,
  (
    item: [
      For example, 2 programs:
      - Program A: ```go print(randNum(0, 10_000))```
      - Program B: ```go print(user.pinCode)```
      - Both can output the same number, e.g. #num(4200)
    ],
  ),
  (
    item: [#num(4200) #sym.eq.not #num(4200), even if indistinguishable],
    note: [
      One 4200 is not the same as the other 4200, even if they are represented
      by the same literal bits

      since it's about what each 4200 implies
    ],
  ),
  (
    item: [Known link between the output and a secret],
    note: [
      Knowing that there is a link between the output and a secret

      is key for security relevance and exploitability
    ],
  ),
  (
    item: [Not simple to determine if such a link exists],
    note: [
      Requires taking into account all possible factors that can influence a
      program's output

      For large codebases, indirection may be extremely complex and cross
      multiple levels of abstraction

      For instance, a developer might not realize that storing an API token in
      an internal global state object is not OK because the entire state object
      is sent to another system within an unrelated component
    ],
  ),
  (
    item: [Tracking provenance should be computer-assisted],
    note: [
      It follows that tracking this kind of metadata is too taxing and exacting
      to be reliably done manually,

      so the process should be automated wherever possible

      THE SAME APPLIES ANALOGOUSLY FOR INTEGRITY, E.G. USER INPUT VS STATIC
      HARD-CODED STRING
    ],
  ),
  (
    item: strong[Identify faults by tracking information flows in Go],
    note: [
      This work applies Information Flow Control techniques

      to identify certain confidentiality and integrity faults

      in arbitrary programs written in a subset of Go
    ],
  ),
)

== The Go Programming Language

#speaker-note(subslide: 1)[Why Go?]

#items-with-notes(
  (
    item: [
      Prevalence makes it an attractive target
      - Widespread in modern development@stackoverflow2025
      - Used for various applications
      - Several high-profile projects
    ],
    note: [
      Stack Overflow 2025 survey: Go is 13th most used language

      Web backend components, developer tools, cloud infrastructure, databases
      and storage, distributed systems, and so on

      Docker, Kubernetes, Hugo, Syncthing, Terraform
    ],
  ),
  (
    item: [Relatively recent@pike2012go, with novel concepts],
    note: [
      Created by Google in 2007, bringing new paradigms and ideas

      interesting to explore, from a research perspective
    ],
  ),
  (
    item: [Compiled, with static and strong typing],
    note: [Reducing possibility space helps keeping flow tracking lighter],
  ),
  (
    item: [No pointer arithmetic],
    note: [
      C-like behavior where it is legal to dereference something like
      `some_ptr+7`

      makes it virtually impossible to track information flows,

      and Go does not allow it in safe code
    ],
  ),
)

== Possible Information Flows

#speaker-note[
  This work follows standard research terminology and classifies Go information
  flows into three major categories
]

#pause

=== Explicit Flows

#speaker-note[
  Simplest and most obvious sources of security vulnerabilities within this
  class
]

Direct propagation of information

#v(1em)
#pause

#hardcode-figure-number(raw, fig-num-raw)
#(fig-num-raw += 1)
#codly(highlighted-lines: (2,))
#figure(
  ```go
  secret := 7
  output = secret + 4
  ```,
  caption: [Example explicit flow via variable assignment],
)

#speaker-note[
  Shows a clear breach that would allow an attacker to fully derive the exact
  value of `secret` just from the value of `output`
]

#v(1em)
#pause

#speaker-note[In this case, it follows trivially that]

Attackers can simply reverse the transformation applied:

$ "secret" = "output" - 4 $

---

=== Implicit Flows

#speaker-note[
  Especially based on conditional operations that only execute for certain code
  paths
]

Indirect propagation from contextual or control-flow logic

#hardcode-figure-number(raw, fig-num-raw)
#(fig-num-raw += 1)
#codly(highlighted-lines: (4,))
#figure(
  ```go
  isEven := false

  if secret % 2 == 0 {
    isEven = true
  }
  ```,
  caption: [Example implicit flow via conditional assignment],
)

---

=== Other Covert Channels

#speaker-note[
  Each poses a real security threat, exploitable with some degree of difficulty,
  especially by dedicated attackers

  but out of scope due to simplicity and time constraints

  This means not considered part of attacker model in question

  In the future, this work could be extended to support some of them, but
  difficult without compromising usability

  Halting problem well-known undecidable in the general case, so attempts at
  detection would have to restrict supported constructs and patterns
]

Additional forms of propagation@sabelfeldmyers2003lang
- Termination
- Timing
- Probabilistic
- Resource exhaustion
- Power

All considered out of scope #pause (except implicit flows)

#speaker-note[
  The referenced work of Sabelfeld and Myers considers even implicit flows to be
  covert channels

  and thus part of this category

  but this work explicitly opts to distinguish ...

  importance / first-class focus in this degree project
]

#focus-slide[
  How to enforce this?

  #speaker-note[
    We now know we want to restrict so e.g. secret data does not flow into
    public outputs, but there are different ways to do this in practice
  ]
]

== Static Analysis

#speaker-note(subslide: 1)[
  This work uses static analysis OF SOURCE CODE as its enforcement paradigm
]

#items-with-notes(
  (
    item: [Program's flows are assessed ahead of time],
    note: [Checked against security policies],
  ),
  (
    item: [Zero-cost impact on runtime performance (vs. dynamic)],
    note: [
      ...which checks flows during execution, usually intercepting each access
      through a DYNAMIC MONITOR
    ],
  ),
  (
    item: [Increased confidence and robustness],
    note: [
      Static analysis checks all possible code paths, no matter how unlikely,
      whereas dynamic only identifies problems for situations that actually
      occur.

      This means that if... (but still accessible through specially crafted)
    ],
  ),
  (
    item: [Violations reported when relevant and convenient],
    note: [Better usability, alerts at development time, not in production],
  ),
  (
    item: [Early detection],
    note: [
      Finding potential vulnerabilities at development time means they can
      be fixed before the code is even shipped, MORE SECURE SYSTEMS
    ],
  ),
  (
    item: [Often less precise],
    note: [
      HOWEVER, some information is really only known at runtime (such as with
      dynamic dispatch)
    ],
  ),
  (
    item: [Broader guarantees],
    note: [
      To account for this, analyzer must be more conservative, prioritizing
      soundness in the aggregate for all possible code paths, no matter how
      obscure
    ],
  ),
)

== Information Classification

#speaker-note(subslide: 1)[
  Final key background concept

  Classify information into archetypes to help reason about attributes of
  information systematically
]

#items-with-notes(
  (
    item: [Data organized into _labels_ forming a security lattice],
    note: [
      Each piece of information is associated with a security label
    ],
  ),
  (item: [Labels describe information sensitivity or scope]),
  (
    item: [
      A label is a set of _tags_ (security namespaces)
      $ L = {"Secret", "Nuclear"} $
    ],
    note: [Tags can represent any relevant domain-specific attribute],
  ),
  (
    item: [
      Lattice defines a partial ordering for compatible labels

      $ {"X"} < {"X", "Y"} wide {"X"} >= {"X"} wide {"X"} gt.lt.not {"Y"} $
    ],
    note: [
      Ordering is defined based on set operations such as union and intersection
    ],
  ),
  (
    item: [By convention, Bottom is $bot = emptyset = {}$],
    note: [Empty label (with no tags) is traditionally denoted Bottom],
  ),
)

= /*Research Questions,*/ Goals & Contributions

#speaker-note[
  In order to tackle this broad purpose, we need explicit goals and guidelines
]

/*== Research Questions

#speaker-note[\[GO VERY FAST HERE\]]

#pause

#{
  set enum(
    full: true,
    numbering: (..nums) => strong[RQ#numbering("1.A.", ..nums)],
  )

  item-by-item[
    + How to effectively *track information flow* in arbitrary Go programs
      through static analysis?
      + How to systematically detect flows of secret data to public outputs?
        _*(Confidentiality)*_
      + How to systematically detect flows of untrusted inputs to critical
        parts? _*(Integrity)*_
    + How to reliably *define a reasonable security policy* applicable to
      arbitrary Go projects, without domain-specific knowledge, as a starting
      point *before human intervention?*
  ]
}

#speaker-note[
  We focus on 4 distinct but mutually complementing research questions
]

// separate enums because they don't all fit in one page
---

#{
  set enum(
    full: true,
    numbering: (..nums) => strong[RQ#numbering("1.A.", ..nums)],
  )

  item-by-item[
    3. Can information flow analysis effectively *identify true security
      vulnerabilities* in Go projects with minimal configuration, generic and
      absent of domain-specific knowledge?
    + *How prevalent are detectable security issues* in popular production-grade
      applications and libraries written in Go?
  ]
}*/

== Project Goals

#{
  set enum(
    full: true,
    numbering: (..nums) => strong[PG#numbering("1.A.", ..nums)],
  )

  item-by-item[
    + Develop a static analysis model and tool

    + Define a base security policy

    + Evaluate both by auditing real-world Go projects

    + Interpret results and draw conclusions
  ]
}

#speaker-note[
  Concretely, this project defines 4 high-level goals

  Here presented in simplified language
]

== Primary Contributions

#items-with-notes(
  (
    item: [
      _Glowy,_ comprising:
      - Analyzer model itself; and
      - Rust implementation (approx. #num(35000) lines of code)
    ],
    note: [
      Glowy means both the developed theoretical model and the corresponding
      implementation, written in Rust
    ],
  ),
  (
    item: [Corpus of #num(230) correctness benchmarks],
    note: [
      Each benchmark is an independent Go module, focused on showcasing one
      particular possible information flow in Go. High-quality and comprehensive
    ],
  ),
  (
    item: [Glowy's Base Security Policy (with #num(348) security controls)],
    note: [
      Sensible default security controls, generic for normal Go projects

      Just for onboarding, before human intervention, before project-specific
      configuration

      For example, a raw Sequel query should not accept unsanitized untrusted
      input
    ],
  ),
  (
    item: [Audit of #num(371) Go modules from popular real-world projects],
    note: [
      Evaluation of the Glowy + BSP combination through analysis of 371 Go
      modules from popular, real-world, production-grade, open-source projects
    ],
  ),
  (
    item: [Evaluation orchestration utility for systematic analysis],
    note: [
      Finally, what makes this mass-auditing possible,

      Evaluation orchestrator for systematic project download, module
      extraction, as well as structured collection of findings and run metadata
      (approx 2200 lines of Rust, excluding blanks). Helps reproducibility and
      avoids human error
    ],
  ),
)

#pause

... among others

#speaker-note[
  Other contributions are less relevant for the stated goals so they are not
  listed here, but are still significant byproducts of the research process,
  including:
  - the underlying Go parser implementation in Rust,
  - the datasets of Go projects themselves
]

= Model, Analysis, & Design

== Taint Analysis

#speaker-note[
  This work uses *taint analysis,* a common technique that

  taints values at sources

  propagates that taint across the program flow

  checks for taint at invariant enforcement points, usually sinks
]

#hardcode-figure-number(raw, fig-num-raw)
#(fig-num-raw += 1)
#codly(highlighted-lines: (2, 7))
#figure(
  ```go
  output = false
  x := source()
  y := x + 4
  if x % 5 == 0 {
    output = true
  }
  sink(output)
  ```,
  caption: [Example taint propagation],
)

Branch label $beta$ propagates contextual taint (= _pc_ label)

== Label Tag Axes

#speaker-note(subslide: 1)[
  This work focuses on flexibility, and one of its flagship concepts is its
  novel label axes system
]

#items-with-notes(
  (
    item: [
      A security label's tags may optionally be bound to an axis

      $ L_alpha = {"secret", "nuclear"} $
      $
        L_beta = {"pii", thick underline("unit") thin : thin "accounting", thick
          underline("unit") thin : thin "ops", thick underline("untrusted") thin
          : thin "http"}
      $
    ],
    note: [Only PLAIN tags; BOUND tags; can COEXIST in the same label],
  ),
  (
    item: [Axes are strictly opt-in, promoting simplicity & flexibility],
    note: [
      Stakeholders can choose whether their use case

      only needs simple plain tags

      or calls for one or more domain-specific orthogonal axes

      PROMOTES SEPARATION OF CONCERNS AND MAINTAINABILITY, unburdens
      stakeholders from always having to know all possible tags when defining
      policies
    ],
  ),
  (
    item: [
      Wildcard notation ${underline("customer") thin : thin *}$
      simplifies policies
    ],
    note: [
      Represents all possible tags in the `customer` axis

      NEVER in values, only when defining some security controls
    ],
  ),
  // (
  //   item: [
  //     Axis-set operator: $underline(L_alpha) = {} wide underline(L_beta) =
  //     {underline("unit"), underline("untrusted")}$
  //   ],
  //   note: [
  //     This work defines / corresponding to the set of axes mentioned in label
  //   ],
  // ),
  // (
  //   item: [
  //     Axis-restriction operator: if $A = {underline("dir"),
  //       underline("untrusted")}$, then $L_alpha|_A = L_A$ itself, whereas
  //     $L_beta|_A = {"pii", thick underline("untrusted") thin : thin "http"}$
  //   ],
  //   note: [
  //     Defined as removing all of a label's tags that are bound to any axis
  //     not contained in set A

  //     These operators will be useful shortly
  //   ],
  // ),
)

// == Security Controls

// #speaker-note[
//   This work considers 5 different types of security controls that can be used
//   by stakeholders to express their security concerns
// ]

// Security Policy $=$ set of security controls

// #pause

// === Sources

// Assign labels to values: $L' = L inter.sq cal(L)_"Source"$

// #pause

// === Revocations

// #speaker-note[
//   Symmetric to sources

//   Does not overwrite, just subtracts what is explicitly stated

//   Explicit risk acceptance, e.g. hash function technically leaks info but OK
// ]

// Subtract labels from values: $L' = L \\ cal(L)_"Revocation"$

// Manual overrides to the taint model (escape hatches)

// ---

// === Allow-Sinks

// Enforce a label tag whitelist (after axis restriction)

// Given an allow-sink $S$ of label $cal(L)_"Sink"$ and a value $v$ of label
// $L$,

// $
//   S "accepts" v <==> L|_A <= cal(L)_"Sink", quad
//   "where" A = underline(cal(L)_"Sink")
// $

// For example, an allow-sink with label
// $cal(L)_"Sink" = {"yellow", thick underline("dir") thin : thin *}$:
// - accepts a value with label $L_1 = {"yellow"}$
// - accepts a value with label $L_2 = {underline("dir") thin : thin "north",
//     thick underline("month") thin : thin "july"}$
// - rejects a value with label $L_2 = {"brown",
//     underline("dir") thin : thin "east"}$

// ---

// === Deny-Sinks

// Enforce a label tag blacklist

// $ S "accepts" v <==> L inter.sq cal(L)_"Sink" = bot $

// For example, a deny-sink with label $cal(L)_"Sink" = {"pink", thick
//   underline("month") thin : thin *}$:
// - accepts a value with label $L_1 = {"green"}$
// - rejects a value with label $L_2 = {"pink", thick underline("dir") thin :
//     thin "north"}$
// - rejects a value with label $L_3 = {"blue", thick underline("month") thin :
//     thin "january"}$

// #speaker-note[L3 rejected because the entire `month` axis is blacklisted]

// #pause

// === Assertions

// Require an exact label match: $A "accepts" v <==> L = cal(L)_"Assertion"$

// #speaker-note[
//   Not intended for normal use, but provided to support testing and debugging
//   facilities
// ]

== Analyzer Directives

#speaker-note[
  IN THE PROVIDED IMPLEMENTATION

  Directives are chiefly of two kinds
]

Security controls are registered through explicit directives

#pause

=== Source Code Annotations

Apply to specific textual instances (great precision)

#hardcode-figure-number(raw, fig-num-raw)
#(fig-num-raw += 1)
#figure(
  ```go
  // glowy::label::{secret, origin:deep-thought}
  const answer = 42
  // glowy::deny::{secret}
  socket <- answer
  ```,
  caption: [Example directives applied via annotations],
)

---

=== Blanket Directives

#speaker-note[
  Even external dependencies, builtins, or some language operators

  Can be simpler or more complex (EXPLAIN SINK, THEN SOURCE)

  Very flexible
]

Apply broadly to all targeted instances

#hardcode-figure-number(raw, fig-num-raw)
#(fig-num-raw += 1)
#figure(
  ```toml
  [sources]
  "os.LookupEnv->0#0~=API_KEY" = ["secret"]

  [deny_sinks]
  "fmt.Println" = ["secret"]
  ```,
  caption: [Example `glowy.toml` blanket directives],
)

#focus-slide[How does Glowy actually work?]

== Analysis Procedure Overview

#speaker-note[
  Convergence loop is safe, guaranteed to converge because:
  - security label lattice is finite
  - symbols are finite
  - labeling is monotonic
]

#item-by-item[
  + Parse Go files into @ast:pl

  + Sort @ast:pl by inter-package dependency order
    - e.g., if A depends on B, B must be analyzed before A

  + *Stage \#1:* Record Declarations

  + *Stage \#2:* Stabilize Labels _(convergence loop; safe)_

  + *Stage \#3:* Enforce Security Policy

  + Output each identified problem as a user-friendly diagnostic, with
    explanatory messages, annotated source code snippets, and a severity level
]

// ---

// During each Stage \#2 iteration and Stage \#3:

// #item-by-item[
//   - Sorted set of @ast:pl is partitioned by package into blocks

//   - Each block is processed sequentially

//   - Within each block, each _package initialization phase:_
//     + Package Bindings
//     + Function Declarations
//     + Init Functions
//     + Main Function

//   - Within each phase, all the files' appropriate declarations
// ]

#speaker-note[
  IMPORTANT AT THE END:

  This does make this process conceptually a dataflow analysis, but did not
  use a well-known framework because
  - optimized for implementation simplicity
  - global fixed-point iteration allows representing the abstract program state
    directly, rather than having to DECOMPOSE that state into DATAFLOW FACTS
    and TRANSFER FUNCTIONS as well as explicitly representing RELEVANT
    CONTEXT, which would significantly increase complexity
]

== Specialized Handling

#speaker-note[
  In the interest of time, it is not possible to go into detail for each
  supported construct and functionality

  MENTION:
  - "Basic constructs such as branches and loops"
  - Functions, QUICK EXPLANATION OF SYNTHETICS
  - Capturing of variables from outside the function body
  - Early abort
  - Goto
  - Defer
]

#cols[
  - Branching (```go if```)
  - Loops (```go for```)
  - Channels
  - Communication Selections (```go select```)
  - Functions and Methods
  - Closures and Captures
  - Built-In Function Calls
  - Composite Values
  - Slices
  - Early Abort (e.g., ```go break```)
][
  - Execution Jumps (```go goto```)
  - Deferred Execution (```go defer```)
  - Build Constraints
  - Qualified Operand Names
  - Unary/Binary Operations
  - Value Matching (```go switch```)
  - Type Matching (```go switch```)
  - Type Assertions
  - Type Conversions
  - Type Instantiations
  - ... among many more
]

== Intuitive Diagnostics

#speaker-note[
  START RED AND THEN GO UP
]

Secret token leakage found in a real-world project

#hardcode-figure-number(raw, fig-num-raw)
#(fig-num-raw += 1)
#cmd-output(
  read("../03-thesis/assets/openlist.ansi"),
  text-size: 0.55em,
  caption: [Example reported error diagnostic],
)

== Example

#speaker-note[
  To help understand better the whole process,

  Let's see how Glowy detects the insecure information flow

  between this source and this sink through this function chain.

  THESE 2 CONTROLS COMPRISE THE PROGRAM'S SECURITY POLICY, registered here to
  the analyzer via source code annotations
]

#let example-code = {
  hardcode-figure-number(raw, fig-num-raw)
  fig-num-raw += 1
  figure(
    ```go
    // glowy::label::{secret}
    const secret = 3.9
    func main() {
      result := outer()
      // glowy::deny::{secret}
      fmt.Println(result)
    }
    func outer() float64 { return inner() }
    func inner() float64 { return secret }
    ```,
    caption: [Example snippet with illegal flow],
  )
}

#codly(highlighted-lines: (2, 6))
#example-code

#let post-states = (
  (
    stage: 1,
    name: "Record Declarations",
    state: [
      - `secret` is $bot$

      - `outer` returns $bot...$

      - `inner` returns $bot...$
    ],
  ),
  // (
  //   stage: 2,
  //   name: "Stabilize Labels",
  //   iteration: 1,
  //   highlighted-lines: (2, 4, 8, 9),
  //   state: [
  //     - `secret` is ${"secret"}$

  //     - `result` is $bot$

  //     - `outer` returns $bot$

  //     - `inner` returns ${"secret"}$

  //     - Sink is ignored

  //     - No convergence (first iteration)
  //   ],
  // ),
  (
    stage: 2,
    name: "Stabilize Labels",
    iteration: 1,
    pip: "Package Bindings",
    highlighted-lines: (8, 9),
    state: [
      - `secret` is ${"secret"}$

      - All function declarations are skipped
    ],
  ),
  (
    stage: 2,
    name: "Stabilize Labels",
    iteration: 1,
    pip: "Function Decls.",
    highlighted-lines: (6, 7),
    state: [
      - `outer` returns $bot$

      - `inner` returns ${"secret"}$

      - `main` is skipped
    ],
  ),
  (
    stage: 2,
    name: "Stabilize Labels",
    iteration: 1,
    pip: "Main Function",
    highlighted-lines: range(1, 5, inclusive: true),
    state: [
      - `result` is $bot$

      - Sink is ignored

      - No convergence (first iteration)
    ],
  ),
  // (
  //   stage: 2,
  //   name: "Stabilize Labels",
  //   iteration: 2,
  //   highlighted-lines: (4, 8),
  //   state: [
  //     - `outer` returns ${"secret"}$

  //     - `result` is ${"secret"}$

  //     - Sink is ignored

  //     - No convergence (first iteration)
  //   ],
  // ),
  (
    stage: 2,
    name: "Stabilize Labels",
    iteration: 2,
    pip: "Function Decls.",
    highlighted-lines: (6, 7),
    state: [
      - `outer` returns ${"secret"}$
    ],
  ),
  (
    stage: 2,
    name: "Stabilize Labels",
    iteration: 2,
    pip: "Main Function",
    highlighted-lines: range(1, 5, inclusive: true),
    state: [
      - `result` is ${"secret"}$

      - Sink is ignored

      - No convergence (state has changed)
    ],
  ),
  (
    stage: 2,
    name: "Stabilize Labels",
    iteration: 3,
    state: [
      - No changes

      - Sink is ignored

      - Convergence reached
    ],
  ),
  (
    stage: 3,
    name: "Enforce Security Policy",
    highlighted-lines: (3, 4),
    state: [
      - (No changes)

      - Sink is evaluated
        - $L_mono("outer") = {"secret"}$
        - $cal(L)_"Sink" = {"secret"}$
        - $L inter.sq cal(L)_"Sink" != bot$
        - Insecure flow!
    ],
  ),
)

#for entry in post-states [
  ---

  #if "iteration" in entry {
    let iter = if "pip" in entry {
      str(entry.iteration) + entry.pip.first()
    } else {
      entry.iteration
    }

    [=== After Iteration \##iter of Stage \##entry.stage (#entry.name)]
  } else {
    [=== After Stage \##entry.stage (#entry.name)]
  }

  #if "highlighted-lines" in entry {
    codly(highlighted-lines: entry.highlighted-lines)
  }

  #cols(columns: (1.5fr, 1fr), text(size: 0.75em, example-code), {
    if "pip" in entry {
      [*PIP:* #entry.pip]
      text(fill: dark-blue, align(center, grid(
        columns: (1fr, 1fr, 1fr, 1fr),
        stroke: 1pt + dark-blue,
        fill: light-blue,
        inset: 5pt,
        ..array("PFIM".clusters()).map(phase => if phase == entry.pip.first() {
          grid.cell(fill: dark-blue, stroke: 2pt + dark-blue, text(
            fill: light-blue,
            phase,
          ))
        } else {
          phase
        })
      )))
    }

    entry.state
  })
]

== Implementation

#speaker-note[
  In addition to this work introducing a generic theoretical model,

  it also provides an implementation
]

#pause

=== Rust

#speaker-note[
  Often includes Mandatory handling of the entire possibility space,

  reducing logic bugs and edge-case problems
]

- Strong reliability and robustness guarantees
- Safety-centric design
- Encourages and simplifies resilient practices
- Very expressive, intuitive, and easy to read
// - Prior author familiarity

#pause

=== Components

- *`glowy`:* central taint analysis & policy enforcement library
- *`glowy-cli`:* user-facing @cli:short (orchestration + diagnostics)
- *`glowy-go-parser`:* lower-level utility (raw text to @ast)

#speaker-note[
  A first-party parser is used because a fully-custom implementation can be
  much better tailored for taint analysis,

  as the parser can be developed with knowledge of how its output will be used.

  This allows the parser and the analyzer to be developed in tandem, exploiting
  the tight coupling between the two components
]

= Methodology & Results

#speaker-note[
  Regarding the auditing of 300 real Go projects (EVALUATION)
]

== Project Selection // Discovery

#items-with-notes(
  (
    item: [Popular, production-grade, open-source Go projects],
    notes: [Population; both applications and libraries],
  ),
  // (item: [3 complementing metrics], notes: [3 separate, ordered datasets]),
  (
    item: [
      *Dataset A:* Published modules by dependents ($n = 44 thin 648$)
      - From the Go official module mirror (`proxy.golang.org`)
    ],
    notes: [
      DON'T SAY: The final Dataset A is then the list of public modules
      depended on (directly or indirectly, at any version) by at least one of
      the top 100 000 modules by published version count since April 10, 2019
      at 19:08:52.997264 UTC, as reported by the official module mirror at
      proxy.golang.org.
    ],
  ),
  (
    item: [
      *Dataset B:* GitHub repositories by stars ($n = 3880$)
      - with $>=$ #num(1000) stars
    ],
  ),
  (
    item: [
      *Dataset C:* GitLab repositories by stars ($n = 236$)
      - with $>=$ #num(10) stars
    ],
  ),
  (item: [Total *#num(44648 + 3880 + 236)* real-world projects]),
  (item: [Total *300* projects selected for analysis (371 modules)]),
)

// == Project Selection

// #items-with-notes(
//   (
//     item: [
//       Each dataset was stratified into quartile rank bands
//       - e.g., stratum B.II corresponds to the top $(25%, 50%]$ Go GitHub
//         repositories by stars
//       - For 3 datasets and 4 bands, 12 strata were produced
//     ],
//   ),
//   (
//     item: [Each strata was uniformly sampled for 25 projects],
//     notes: [Pseudo-random algorithm ChaCha20; means reproducibility],
//   ),
//   (item: [Total *300* selected real-world projects]),
//   (item: [Projects unfolded into *371 Go modules*]),
// )

== Analysis Process

#items-with-notes(
  (
    item: [
      `glowy-eval` utility orchestrated entire process
      - Project download, module enumeration, analyzer spawning, summarizing
        of findings, results collection
    ],
    notes: [
      No manual intervention, being generic and systematic helps reproducibility

      and prevents human error during result collection
    ],
  ),
  (
    item: [Analysis with no project-specific configuration],
    notes: [Just Glowy's generic Base Security Policy, enabled by default],
  ),
  (
    item: [
      Each of the 371 Go modules was classified into:
      - *Succeeded (222):* Analysis completed with no findings
      - *Diagnostics (126):* Analysis completed with $>=$ 1 finding
      - *Crashed (4):* Analysis could not be completed
      - *Aborted (8):* Glowy rejected performing taint analysis
      - *Empty (11):* No Go files admitted
    ],
    notes: [
      Outcome

      Crashed = analyzer fault (defects or bugs)

      Aborted = usually related to too many build permutations

      Empty = text fixtures or Hugo
    ],
  ),
)

== Distribution by Outcome

// #hardcode-figure-number(raw, fig-num-img)
// #(fig-num-img += 1)
// #pad(x: -5%, figure(
//   charts.outcomes(big: true),
//   caption: [Analysis outcomes by dataset and popularity band],
// ))

// ---

#let outcome-counts = (
  ([Succeeded], 222),
  ([Diagnostics], 126),
  ([Empty], 11),
  ([Aborted], 8),
  ([Crashed], 4),
)

#let share(count, total) = num(
  calc.round(100 * count / total, digits: 2),
  suffix: [%],
)

#hardcode-figure-number(raw, fig-num-tbl)
#(fig-num-tbl += 1)
#figure(
  table(
    columns: (auto, auto, auto),

    table.header(
      strong[Outcome], strong[\# Modules], strong[Share (%)],

      ..outcome-counts
        .map(((label, count)) => (
          label,
          num(count),
          share(count, 371),
        ))
        .flatten(),
    ),
  ),
  caption: [Total modules by analysis outcome],
)

== Findings

#items-with-notes(
  (
    item: [
      Avg. 18 reported problems per module with diagnostics:
      - 6 warnings and 12 errors (detected insecure flows)
    ],
  ),
  (
    item: [
      Median 1 reported problem per module with diagnostics:
      - 1 warning, 0 errors
    ],
  ),
  (
    item: [
      Disparity attributable to outliers
      - Just 15 projects (#share(15, 291)) responsible for 75% of errors
    ],
    notes: [
      Resulting from overly conservative propagation, would be easily fixed by
      project-specific configuration
    ],
  ),
  (
    item: [Warnings typically represent unsupported Go],
    notes: [
      Including complex patterns not handled by the analyzer, especially
      pointer-related

      But around 70% of all warnings because of illegal build constraint
      permutations
    ],
  ),
  (
    item: [Majority of the reported findings are false positives],
    notes: [
      Clear from thorough examination of selected cases and a high-level
      surveying of all the collected results

      CONSTITUTE
    ],
  ),
  (
    item: [Average global run time 13.15 sec, median 152.11 ms],
    notes: [
      Median: considering only completed runs

      Difference again attributable to outliers, mostly enormous projects by
      SLOC
    ],
  ),
)

// == Error Makeup

// #speaker-note[
//   Projects with warnings are not considered here because they compromise
//   the reported results

//   Median is used to avoid skew by outliers
// ]

// #v(1fr)

// #hardcode-figure-number(raw, fig-num-img)
// #(fig-num-img += 1)
// #pad(x: -5%, figure(
//   charts.median-errors(big: true),
//   caption: [
//     Median insecure flows in modules with reported errors but without any
//     reported warnings
//   ],
// ))

== True Positives

#speaker-note[
  Even though many false positives, there are still real findings

  For instance, this SSRF is a real vulnerability detected in an audited module

  Several such cases were found, and responsibly disclosed where appropriate

  CVE assignment has been requested and is waiting review by the MITRE Corp,
  which is the CVE Numbering Authority of Last Resort, for cases where the
  maintainer did not respond (had to escalate)
]

#hardcode-figure-number(raw, fig-num-raw)
#(fig-num-raw += 1)
#cmd-output(
  read("../03-thesis/assets/vk-golang.ansi"),
  text-size: 0.55em,
  caption: [Example true @ssrf finding],
)

= Discussion

== Research Questions

#pause

=== RQ1. Information Flow Analyzer

#sym.ballot.check.heavy Glowy model and implementation

#pause

=== RQ2. Generic Security Policy

#sym.ballot.check.heavy Glowy's Base Security Policy

#pause

=== RQ3. Vulnerability Detection

#sym.ballot.check.heavy True security vulnerabilities identified

#pause

=== RQ4. Prevalence of Security Issues

◩ No concrete figures, but some degree of prevalence

#speaker-note[Provably]

== Limitations

#speaker-note[
  While this work aims for comprehensiveness, soundness, and precision,

  it is still bound to the inevitable time and complexity constraints associated
  with a degree project

  Glowy is a research prototype and not feature-complete

  Some parts were deemed too costly to support up to their full extent

  The MOST SIGNIFICANT are listed here

  END: OVERALL, these limitations are significant, but they do not compromise
  the general integrity of the contributions, per the presented results
]

- Cross-module dependency resolution and handling

- Precise synchronization and happens-before reasoning

- Project-conventional build-tag combinations awareness

- Pointer aliasing and heap location modeling

- Interface-typed dynamic dispatch

- All usages of the `unsafe` and `reflection` packages

- In general, input is expected to be Go spec compliant

== Future Work

- Full language support

- More output formats, such as @sarif

- Allow specifying sets of mutually exclusive build tags

- Pre-analyze the entire Go standard library

- (Partially) support more covert information flow channels

... among other possible improvements

== Comparison to Existing Work

#items-with-notes(
  start-empty: false,
  (
    item: [Several projects already exist with the same premise],
    notes: [
      Go ecosystem

      Some form of static analysis for identifying potential security issues
    ],
  ),
  (
    item: [Most are discontinued, but some are actively maintained],
    notes: [Abandoned],
  ),
  (
    item: [
      In general, Glowy presents three major advantages:

      - *Flexibility:* multi-tag labels, partial revocation, and axes mechanic
        allow expressive and extensible policies
      - *Implicit Flows:* tracking across multiple Go constructs, including
        early-abort (e.g., ```go if secret { return }; f()```)
      - *Rich Problem Reporting:* concise and intuitive error messages and
        taint trace visualizations
    ],
    notes: [
      Over all of them

      Most of them are binary, taint is a single boolean, rather than labels
    ],
  ),
)

= Conclusion

== Conclusion

#speaker-note[
  LEAVE CONCLUSION UP, DO NOT CHANGE SLIDE
]

#item-by-item[
  - Substantial contributions to the research space

  - Glowy, a robust framework for systematically and effectively tracking
    information flow in Go programs

  - Strong balance of soundness, precision, and simplicity

  - Prioritizes flexibility, usability, and specialized handling

  - True security vulnerabilities found in real-world Go

  - Overall, security tooling helps foster a more secure society
]

#title-slide()
