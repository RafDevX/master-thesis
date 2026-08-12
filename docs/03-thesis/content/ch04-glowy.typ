#import "../utils/algorithms.typ": algorithm
#import "../utils/cmd-outputs.typ": cmd-output
#import "../utils/dependencies.typ": codly, fletcher, lovelace, zero

#import codly: codly

= Glowy <glowy>

The present degree project's primary and most central contribution is *Glowy,*
which comprises the theoretical model developed to employ static analysis @ifc
and taint tracking techniques to examine Go programs, as well as that model's
practical implementation and realization as a tool prototype.

This chapter describes the algorithms used for the entire analysis process,
including relevant special handling for select relevant language constructs
and functionalities. It generally progresses from broader to more specific
descriptions of how Glowy models Go and implements tracing its data flows.

== Software Design

This section describes the primary Glowy pipeline at a high level, which
operates on (usually) one input Go module and applies several layers of
processing until a final output is produced. Such output generally comprises
either a list of identified problems, or a lack thereof.

Nevertheless, as mentioned in @intro:limitations, a successful output of no
detected issues cannot be misconstrued as an absolute endorsement of the input
program's security, since Glowy is not completely sound (e.g., there are Go
constructs it does not support, per @methods:subset) nor does it operate on all
possible classes of vulnerabilities (e.g., a logic bug can constitute a security
issue without being detectable as a data propagation fault). In addition,
reported results are evidently also dependent on the quality and soundness of
the provided security policy to enforce.

As already described in @methods:process:tool:rust, all of this degree
project's software contributions are implemented in Rust
#footnote(link("https://rust-lang.org")), an ownership-based programming
language with focus on safety, performance, and ergonomics @jung2021rust
@klabnik2026rust. Their design can therefore be influenced by idiomatic Rust
patterns.

#pagebreak()

=== Architecture <glowy:design:architecture>

Glowy is made up of the following principal components, each its own independent
Rust crate#footnote[Crates are Rust's fundamental unit for compilation,
  versioning, and dependency management, existing at a similar level of
  abstraction to Go modules.]:
- the Glowy library, including the core taint analysis engine;
- the Glowy @cli application, optimized for end-user usability; and
- the Glowy parser, for translating Go files into @ast:pl.

In addition, several other satellite Rust programs are also part of Glowy's
larger ecosystem, particularly in connection with its evaluation:
- the Glowy evaluation orchestration utility, also a @cli application;
- multiple evaluation dataset generation scripts;
- a dataset stratification script for supporting evaluation; and
- a deterministic stratified sampler for generating the final evaluation target.

In this report, the terms "tool" and "Glowy" are sometimes used interchangeably
to refer to not only the entirety of this work in general, but also either of
the main library (`glowy`) and the @cli application that makes use of it
(`glowy-cli`), since they work in tandem and in many cases the distinction is
negligible for the point under discussion. When necessary, the two components
are disambiguated as library and @cli application, respectively.

#v(1fr)
#highlight[more paragraphs]
#v(1fr)

#pagebreak()

=== Usage Workflow <glowy:design:workflow>

The primary macro-level steps for the most standard use of Glowy are identified
in @glowy:design:workflow:overview below. The @cli application is taken as the
main entrypoint, but it should be noted that the Glowy library can be depended
on and used directly by consumers wishing to programmatically perform (more
heavily customizable) taint analysis. Nevertheless, it is intended that most
users rely on `glowy-cli`, since it is more intuitive and transparently
abstracts boilerplate configuration and output formatting.

#algorithm([Overview of the main pipeline workflow], [
  + *`glowy-cli`:* Initialize Analyzer instance from input directory $cal(D)$:
    + *`glowy:`* Locate `go.mod` file in $cal(D)$ and extract module path
      $cal(M)$
    + *`glowy:`* Load configuration from `glowy.toml` in $cal(D)$, if if exists
    + *`glowy:`* Load Base Security Policy (unless `inherit_base` is `false`)
    + *`glowy:`* Recursively read to memory all Go files nested in $cal(D)$
    + *`glowy:`* Register all source files to an ordered set $FF$
    + *`glowy:`* Return constructed Analyzer $cal(A)$ with configuration and
      $FF$
  + *`glowy-cli:`* Execute analysis on $cal(A)$:
    + #lovelace.line-label(<glowy:design:workflow:overview:parsing>) *`glowy:`*
      Parse each file $cal(F)$ in $FF$ into @ast:pl stored in ordered set $TT$:
      + *`glowy-go-parser:`* Recursively traverse $cal(F)$'s source code
      + *`glowy-go-parser:`* Return a constructed `SourceFileNode`
        $cal(T)_cal(F)$
    + *`glowy:`* Enumerate build permutations $PP$ from constraints in $TT$
    + *`glowy:`* Process each build permutation $cal(P)$:
      + #lovelace.line-label(<glowy:design:workflow:overview:admitted>)
        *`glowy:`* Filter $TT$ by $cal(P)$'s build constraints into admitted set
        $TT_cal(P)$
      + #lovelace.line-label(<glowy:design:workflow:overview:analysis>)
        *`glowy:`* Analyze $TT_cal(P)$, yielding a detected problem set
        $EE_cal(P)$
    + *`glowy:`* Merge all problem sets $EE_cal(P)$ into one unified set
      $EE$
    + *`glowy:`* Deduplicate problems in $EE$ using shallow comparison into
      $EE'$
    + *`glowy:`* Return final set of identified problems, $EE'$
  + *`glowy-cli`:* Map each problem $cal(E)$ in $EE'$ to a severity level
    (warning/error)
  + *`glowy-cli`:* Convert each problem $cal(E)$ from raw data to a
    user-friendly diagnostic structure $cal(E)'$, with explanatory messages,
    annotated source code snippets, and the previously-calculated severity level
  + *`glowy-cli`:* Output each final diagnostic $cal(E)'$ to `stderr`, colorized
    if the terminal supports ANSI escape sequences
]) <glowy:design:workflow:overview>

The pipeline, as described in @glowy:design:workflow:overview, clearly
emphasizes the close dependency relationships between the @cli application, the
main analysis library, and the internal Go parser.

In particular, it shows how a module is analyzed independently for each of its
build constraint permutations, corresponding to the deduplicated sets of files
admitted by each possible combination of build-tags (such as `linux` or
`amd64`), as introduced in @bg:go:overview:build-constraints. This process is
described in more detail in @glowy:construct:build-constraints.

However, while still useful to understand the general orchestration at a
birds-eye view, @glowy:design:workflow:overview is very high-level,
encapsulating most of the workload and complexity under a single step on
@glowy:design:workflow:overview:analysis. The remainder of the present chapter
elaborates on each applicable point, especially that step.

== Analysis Procedure <glowy:procedure>

This section presents a high-level view of the process developed as part of this
work for applying static taint analysis techniques to Go projects, in an attempt
to achieve a balance between simplicity, soundness, and precision. It represents
one of this degree project's most central contributions, and corresponds to the
step referred to by @glowy:design:workflow:overview:analysis of
@glowy:design:workflow:overview. The corresponding Rust implementation is
provided by the `glowy` library, with the `Analyzer::analyze` method as its
public entrypoint.

The analysis operates on a build permutation's admitted file set, which means
that it takes as its primary output the $TT_cal(P)$ set of parsed
@ast:longplural (@ast:pl) for all registered files with a build-tag constraint
satisfied by the current permutation. This implies that some degree of
preparation and pre-processing is required prior to the analysis, as already
outlined in lines @glowy:design:workflow:overview:parsing[] through
@glowy:design:workflow:overview:admitted[] of @glowy:design:workflow:overview.

The procedure now described by @glowy:design:procedure:overview therefore
assumes that such preparation work has already been conducted prior to the
analysis process itself. After its completion, it yields a set $EE_cal(P)$,
corresponding to all identified problems, both direct security violations (e.g.,
insecure flow) and more subtle invariant breaches (e.g., attempted mutation of
an immutable symbol). While the former kind is the most interesting, the latter
is also significant as it can be a clue for a program being unsupported (see
@methods:subset), thereby potentially invalidating all analysis results, which
should preferably be reported rather than happen silently.

#pagebreak()

#algorithm([Overview of the main analysis procedure], [
  + Set the active Branch Label $beta := bot$
  + Construct an empty Symbol Table $Sigma$
  + Construct an empty Type Registry $Theta$
  + Construct an empty Problem Set $Pi$
  + Construct an empty Function Stack $Phi$
  + Construct a new Global Context $Gamma = chevron.l Sigma, Theta, Pi, Phi,
    beta, dots.h.c chevron.r$
  + Compute the full $cal(M)$-prefixed package path for each file in $TT_cal(P)$
  + #lovelace.line-label(<glowy:design:procedure:overview:sort>) Sort
    $TT_cal(P)$ by dependency order _(@glowy:design:procedure:ordering:graph
    and @glowy:design:procedure:ordering:kahn)_
  + *Stage \#1 --- Record Declarations:*
    + *for each* $cal(T)_cal(F) in TT_cal(P):$
      + Record each of $cal(T)_cal(F)$'s imports in $Sigma$ for later qualifier
        resolution
      + Record each of $cal(T)_cal(F)$'s top-level declarations in $Sigma$ with
        label $bot$
      + Record each of $cal(T)_cal(F)$'s top-level type declarations in $Theta$
    + Execute deferred type resolution for $Theta$
    + #lovelace.line-label(<glowy:design:procedure:overview:errors-off>)
      $Pi' := Pi$
  + *Stage \#2 --- Stabilize Labels:*
    + $"Prev" := "nil"$
    // SnapshotAwareEq is an implementation detail for snapshot's Eq
    + *while* $"snapshot"(Sigma) != "Prev":$
      + $"Prev" := "snapshot"(Sigma)$
      + Perform a taint analysis pass on $TT_cal(P)$
        _(@glowy:design:procedure:stage2:taint-pass)_
  + *Stage \#3 --- Enforce Security Policy:*
    + #lovelace.line-label(<glowy:design:procedure:overview:errors-on>)
      $Pi := Pi'$
    + Perform a taint analysis pass on $TT_cal(P)$
      _(@glowy:design:procedure:stage2:taint-pass)_
  + *return* $Pi$ as $EE_cal(P)$
]) <glowy:design:procedure:overview>

Some of the steps from @glowy:design:procedure:overview are described in more
detail in the subsequent subsections, especially the three major analysis
stages.

#v(1fr)
#highlight[add more]

#pagebreak()

=== Global Analysis Context <glowy:procedure:context>

Over the course of the entire analysis procedure, a single Global Context
instance supports and guides all handling. Denoted $Gamma$, this Context
includes a Symbol Table $Sigma$, a Type Registry $Theta$, a Problem Set $Pi$,
the current Function Stack $Phi$, the currently active branch label $beta$, but
also many other more specific datapoints, all of which are essential to inform
local-level implementations and give them visibility over the current analysis
state.

==== Symbol Table <glowy:procedure:context:symtab>

The Symbol Table $Sigma$ records and manipulates scopes and symbols, exposing a
unified @api for the rest of the analyzer to rely upon. It
primarily stores:
- the universe Scope, which holds all predeclared identifiers;
- a mapping of package paths to their respective Package Scope Envelopes;
- the current file's imports, i.e., mappings from qualifiers to package paths;
- a cursor pointing to the currently active scope; and
- the currently active package path.

Package Scope Envelopes contain a package's declared native name (since it does
not necessarily correlate with package path), its top-level Scope, and all the
methods declared within the package.

Scopes are essentially collections of Symbols, but they form tree-shaped
structures since they also store children Scopes and a reference to their parent
Scope; the only root Scopes (i.e., without a parent) represent either a package
scope or the universe scope.

Methods are not stored directly in the package's Scope tree because multiple
methods with the same name may be defined in the same package for different
receiver types, so their associated Symbols must be keyed both by receiver type
and method name. Since Go requires all methods to be declared in the same
package as their receiver type, a simple type name is a sufficient type
identifier, as there is no need for qualified name resolution.

Symbols represent individual variable, constant, or function declarations, as
well as function parameters and adjacent synthetics. They store their own
inherent declared name (including exact location in the source code), whether
the symbol is mutable, as well as its associated security label.

Overall, this Symbol Table structure is essential for taint analysis, as it
encapsulates Symbols containing the security labels that form the chief
subject of the entire analysis procedure.

#pagebreak()

==== Type Registry <glowy:procedure:context:types>

Glowy does not model full type information, but in many cases precision is
greatly improved by the simple propagation and storage of lightweight type
information. As such, the global Type Registry $Theta$ primarily stores basic
details for all known declared types, keyed by package path and type name.

Each type stores only its underlying kind and its method set (methods point to
the same Symbols as present in Package Scope Envelopes, but duplicating an
index supports different lookup strategies for convenience and efficiency).

Recognized type kinds are:
- _Opaque,_ representing built-in types (such as `int` or `string`) or otherwise
  any type whose shape could not be resolved and is thus opaque to analysis;
- _Named,_ associated with the newtype pattern (e.g.,
  ```go type Wrapper Other```), but storing a reference to the inner type so
  that its underlying shape is still accessible wherever useful;
- _Pointer,_ similarly holding a reference to its inner type;
- _Struct,_ nesting per-field type information; and
- _Map, Slice, Array, Channel, Interface, and Function,_ with no additional
  information stored besides the type kind's inherent identity.

This information is derived from type declarations at the package level.

==== Problem Set

At any point during the analysis, if a problem of any kind is identified, it can
be reported to the global Problem Set $Pi$ to later be included in the analysis'
output. This behavior is preferable to a pipeline-interrupting abort (such as
the more idiomatic cascading ```rust Result``` pattern in Rust, or exceptions in
Java/Python) because this allows analysis to proceed so that problems can be
surfaced to consumers as an aggregate, rather than one at a time.

==== Function Stack <glowy:procedure:context:functions>

Much specific behavior depends on a function-specific contextual information, so
the global Function Stack $Phi$ stores context frames for each function
currently being defined. Often this will contain a single element, but Go allows
nested function definitions, making the stack a vital generalization.

Some operations target only the innermost function frame, while others query the
entire stack. For example, a `return` statement must update its respective
function's context, and capture lookups (e.g., for mutation) can depend on any
enclosing function's context, since captures are inherited.

==== Branch Label <glowy:procedure:context:branch>

Sometimes referred to as a _pc label_ in other work, standing for Program
Counter, a branch label represents the taint associated with the current
execution path itself. This is later used during propagation operations, such as
mutations. For example, any assignment taking place inside a secret-dependent
branch should always be tainted.

The Branch Label $beta$ is a core mechanism crucial to the correct
detection of implicit information flows, as described in @bg:ifc:flows:implicit.
Its management throughout the analysis lifecycle is implemented by the Global
Context $Gamma$, which supports two symmetric operations: pushing and popping.

This is possible because $Gamma$ internally stores a stack of branch labels,
rather than a single one, even if this is always exposed as one label $beta$,
corresponding to the last (most recent) stack element. The stack is used to
maintain history, but all entries are always active, so $beta$ is sufficient to
represent the entire stack, as long as the following invariant is always held:

$ forall i, j, quad i <= j ==> beta_i <= beta_j $

The branch label push operation must then union the latest stack entry (if any)
with the incoming new branch label, forming a new label that representative of
the new branch but also the existing history information.

The pop operation, in turn, only needs to pop the stack to restore the history
to what it was before the push, with the newly-uncovered label already
representing all other stack entries.

Mutation operations then combine the current Branch Label $beta$ with their
target's new label, so that observable control-flow dependencies are propagated
by the target's taint. The same applies for other committal operations, such as
return statements or policy enforcement checks (e.g., sinks).

==== Other Contextual Information

The Global Context $Gamma$ also contains a multitude of additional information
necessary to permit local handlers to make informed decisions based on global
state and surrounding context.

This includes, among other datapoints, the relative path of the file currently
undergoing processing, as well as various internal state for the
necessarily-decentralized handling of ```go goto``` statements, range functions,
and per-iteration loop bindings.

#pagebreak()

=== Topological Ordering by Dependency <glowy:design:procedure:ordering>

The ordering referred to by @glowy:design:procedure:overview:sort of
@glowy:design:procedure:overview is crucial for the sound and efficient
performance of the analysis process. Its main goal is to order files (or rather,
files' corresponding @ast:pl) according to a topological order, so that if
any file in package $A$ imports package $B$, then $B$ is ordered before $A$.

This is essential since any changes in $B$'s taint state can have repercussions
on $A$'s taint state, so the latter must always be recalculated when the former
is updated, in order to guarantee sound propagation across packages.

For the purposes of safeguarding determinism, this sorting is stable, meaning
that multiple files associated with the same package path are kept in the same
order as they were already listed in $TT_cal(P)$, i.e., they are kept in the
same order that they were registered to the analyzer.

The ordering operation requires a graph with packages as nodes and dependency
relationships (from ```go import``` directives) as edges. However, rather than
calculating the entire graph, it is sufficient to make accessible some specific
information about the graph; in particular, it is necessary to know how many
other packages each package imports (DependencyCounts) and what other packages
each package is imported by (Dependents). For these specific purposes, these
two properties are equivalent to exhaustive graph construction.

This restructuring of already-available information is showcased in
@glowy:design:procedure:ordering:graph below.

#algorithm([Graph construction for topological sorting], [
  + $"DependencyCounts" := { thin chevron.l thick forall cal(T)_cal(F) in
      TT_cal(P), quad "pkg" (cal(T)_cal(F)) thick chevron.r : 0 thin}$
  + $"Dependents" := { thin chevron.l thick forall cal(T)_cal(F) in TT_cal(P),
      quad "pkg"(cal(T)_cal(F)) thick chevron.r : emptyset thin }$
  + *for each* $cal(T)_cal(F) in TT_cal(P):$
    + *for each* $cal(D) in "imports"(cal(T)_cal(F)):$
      + #lovelace.line-label(<glowy:design:procedure:ordering:graph:guard>) *if*
        $cal(D) in "keys"("Dependents"):$
        + *if* $cal(T)_cal(F) in.not "Dependents"[cal(D)]:$
          + $"Dependents"[cal(D)] := "Dependents"[cal(D)] union {"pkg"(
                cal(T)_cal(F))}$
          + $"DependencyCounts"["pkg"(cal(T)_cal(F))] "+=" 1$
  + *return* $chevron.l "DependencyCounts", "Dependents" chevron.r$
]) <glowy:design:procedure:ordering:graph>

For simplicity and conciseness, in this work the notation $A "+=" B$ is used in
pseudocode to mean $A := A + B$. The same applies for $A "-=" B$ and
$A := A - B$. Set insertion, in contrast, is kept explicit as $A := A union {B}$
to highlight its behavior and because there is no equivalent well-understood
intuitive operator that could be used in its stead.

It is worth highlighting that the guard at
@glowy:design:procedure:ordering:graph:guard of
@glowy:design:procedure:ordering:graph is necessary because imported packages
might be external to the module under analysis and thus not subject to the
present process of sorting by dependencies.

The sorting itself is accomplished through the well-known algorithm first
introduced by #cite(<kahn1962topological>, form: "prose").
@glowy:design:procedure:ordering:kahn illustrates how it is applied to this
concrete case, following from @glowy:design:procedure:ordering:graph's graph
construction.

#algorithm([Kahn's topological sorting by dependencies], [
  + $"Ready" := emptyset$
  + *for each* $(p, c) in "DependencyCounts":$
    + *if* $c = 0:$
      + $"Ready" := "Ready" union {p}$
  + #hide[---]
  + $"Ordered" := emptyset$
  + *while* $"Ready" != emptyset:$
    + $p := "pop"("Ready")$
    + *for each* $cal(R) in "Dependents"[p]:$
      + $"DependencyCounts"[cal(R)] "-=" 1$
      + *if* $"DependencyCounts"[cal(R)] = 0:$
        + $"Ready" := "Ready" union {cal(R)}$
    + $"Ordered" := "Ordered" union {p}$
  + *return* $"Ordered"$
]) <glowy:design:procedure:ordering:kahn>

It should be noted that this is guaranteed to succeed because Go explicitly
forbids import cycles. An error is nonetheless reported by Glowy's
implementation if $"Ready"$ is not empty at the end of the sorting procedure, in
the case of the registered input files being invalid.

#pagebreak()

=== Top-Level Declaration Processing

The bulk of the analysis work is implemented by visitors operating on @ast nodes
to perform the appropriate handling and defer to other visitors where suitable,
recursively until leaf nodes are reached. As outlined in
@glowy:design:procedure:overview, analysis is mostly organized into three major
stages, each of which employing these visitor trees in a different way.

The first such stage is denoted *Record Declarations* and focuses on top-level
declarations. It constitutes an initial pass through all files to find and
record all top-level declarations, so that the Symbol Table $Sigma$ is fully
initialized before the subsequent stage.

In particular, this includes populating $Sigma$ with all the necessary Package
Scope Envelopes, as well as registering all top-level declarations, since they
can be referenced from anywhere in any order, even textually before their
definition, and even from other packages in the case of exported names
#footnote[Go does not have `public`/`private`-like keywords to define
  visibility; instead, a name is exported if it starts with an uppercase letter,
  otherwise it is considered private and thus only accessible from within its
  own package.].

During this Stage \#1, scaffolding package-level symbols is the only goal,
explicitly without visiting initialization expressions (since they might
reference names not yet processed, precisely the reason why the present Stage
exists), so all symbols are declared with an initial label of Bottom.

Top-level type declarations are also processed so that full (lightweight) type
information is already available before Stage \#2. When a type declaration is
visited, it is recorded in the Type Registry $Theta$, but if it cannot be fully
resolved at that point in time (e.g., if it depends on another type whose
declaration has not yet been visited) then the registration is deferred.

At the end of Stage \#1, deferred type resolution takes place, repeatedly
re-attempting resolution for all deferred types until the latter does not
decrease in size between iterations, at which point all remaining types are
deemed permanently unresolvable and discarded or registered as Opaque.

Top-level declarations processing is an essential process for ensuring that the
taint analysis itself has a stable foundation on which to operate. Problems
detected during this stage are real and significant, so the global Problem Set
$Pi$ is snapshotted to $Pi'$ and later re-applied at the beginning of Stage \#3.

#pagebreak()

=== Label Stabilization <glowy:design:procedure:stage2>

Stage \#2 entails the most significant taint analysis work. In essence, it
repeatedly performs taint analysis passes until a fixed point is reached, when
all labels have converged. This is a critical process to guarantee that Stage
\#3 operates on a stable final model of the project under analysis.

Concretely, this means that a snapshot of the Symbol Table $Sigma$ is computed
at the end of each iteration, with Stage \#2 continuing for as long as the
current iteration's snapshot differs from the previous iteration's snapshot.
When they match, Symbol Table state has converged and cannot ever oscillate any
further, so the present stage terminates and analysis proceeds.

Since both the label lattice and the Symbols in $Sigma$ are finite, and since
Symbol labeling is monotonic for the supported subset of Go (described in
@methods:subset), it must necessarily converge if the project under
consideration is well-formed and in scope for this work.

As labels are unreliable during stabilization iterations up until they converge,
problem reporting is suppressed during Stage \#2. This is represented by lines
@glowy:design:procedure:overview:errors-off[] and
@glowy:design:procedure:overview:errors-on[] of
@glowy:design:procedure:overview, which limit effective problem tracking to
the surrounding Stages \#1 and \#3.

It should be stressed that a worklist-style mechanism filtering $TT_cal(P)$ at
each iteration to only include trees for unstable packages would not be correct;
for example, if package $A$ contains an assignment to a binding in package $B$,
then only $B$ would be considered unstable (that is, changed since the previous
iteration), but re-visiting just $B$ during the subsequent iteration would
simply undo this assignment, as only the binding's initial declaration in $B$
would be processed, not $A$'s assignment overwriting it. This can happen even
across longer chains, and other packages $C_i$ can depend on $B$'s exported
binding but have been processed before the mutation in $A$, in which case they
must be re-visited to observe the new taint. However, despite it not being
possible to reduce each iteration's scope in this way, the overall number of
iterations is already greatly reduced by the topological sorting by
inter-package dependencies described in @glowy:design:procedure:ordering.

Snapshotting is similarly not replaceable by a (presumably cheaper) mutation
stamping wherein Symbols store a "last revision" generation identifier
corresponding to the last iteration during which they were changed, since the
same Symbol might be mutated multiple times during the same iteration and end
up holding the same label as at the beginning of the iteration (therefore being
stable, overall), which would still affect "last revision" and thus be
incorrectly considered unstable by the convergence loop. In consequence, this
behavior could lead to a fixed point never being detected (even if label
convergence itself is technically reached), causing analysis to never terminate
and continue performing iterations without bound.

This kind of convergence is required because symbols often have complex
dependencies that cannot be calculated from a single pass, such as in the case
of mutually recursive functions or complex call chains, wherein taint is slowly
propagated from function to function between iterations. When analyzing source
code one element at a time, it is not feasible to propagate taint immediately
to all reliant sites, so this is the most practical and scalable solution
that still preserves soundness and precision.

The actual work performed within each iteration is here denoted a taint analysis
pass and relies heavily on the taint-oriented tree of visitors that implement
specialized handling for each @ast node type. These are rooted at the visitor
for `SourceFileNode`, which defers to the respective visitors for top-level
declarations, and so on until the @ast tree's leaf nodes are reached.

#algorithm([Taint analysis pass], [
  + Partition $TT_cal(P)$ by package into an ordered set of blocks $BB_cal(P)$
  + *for each* $b in BB_cal(P):$
    + #lovelace.line-label(<glowy:design:procedure:stage2:taint-pass:phase>)
      *for each* $omega in Omega:$
      #h(1fr) $italic(underline((Omega "is defined below")))$
      + *for each* $cal(T)_cal(F) in b:$
        + $"visit_source_file"_omega (cal(T)_cal(F))$
]) <glowy:design:procedure:stage2:taint-pass>

The primary goal of the behavior expressed in
@glowy:design:procedure:stage2:taint-pass is to adhere to the general evaluation
ordering semantics set forth by the Go language specification @go126spec. In
particular, each package is initialized separately, and within each package
there is a set cross-file ordering that must be respected.

Denoted by $Omega$ on @glowy:design:procedure:stage2:taint-pass:phase of
@glowy:design:procedure:stage2:taint-pass is the ordered set of _package
initialization phases_ for each of which Glowy visits the entire package before
continuing to the next stage and, afterwards, the next package.

#pagebreak()

These phases affect only the root visitor for `SourceFileNode`, conditionally
selecting which top-level declarations it processes, but all lower-level
implementations throughout the visitor tree are fully independent of phase
$omega$.

Concretely, the ordered package initialization phases comprising $Omega$ are:
+ #underline[Package Bindings]: top-level variables and constants are visited,
  but all function declarations are skipped.
+ #underline[Function Declarations]: top-level function declarations are
  visited, except for `main` and `init` functions.
+ #underline[Init Functions]: only `init` function declarations are visited.
+ #underline[Main]: only the `main` function's declaration is visited, if any.

This ordering is necessary to ensure that all top-level function bodies are only
analyzed after taint information is available for all top-level bindings, while
`init` functions may additionally require top-level functions' taint
information, and `main` must be processed taking into account fully-initialized
taint information. Top-level type declarations have already been fully processed
in Stage \#1 and are thus not visited again as they are already stable.

Ordered per-package initialization is not just a necessity for efficiency
reasons (i.e., reduce the number of iterations until convergence), but rather an
incorrect processing order (e.g., exclusively following textual source-code
order) can cause labels to oscillate and compromise convergence entirely.

Finally, it should be noted that partitioning file @ast:pl into blocks of files
within the same package is trivial because $TT_cal(P)$ is at this point already
sorted by package, per the topological sorting process described in
@glowy:design:procedure:ordering.

=== Policy Enforcement

The third and final stage is the simplest, merely performing another taint
analysis pass, but now without problem suppression so that security policy
enforcement checks can report any potential identified problems based on the
stable security labels for the entire taint analysis state.

The taint analysis pass itself is exactly the same as in Stage \#2, following
the outline in @glowy:design:procedure:stage2:taint-pass and the same
package initialization phases $Omega$.

While operationally equivalent to the work performed during a standard Stage \#2
iteration, the present Stage \#3 is the most relevant for observed analyzer
output, as it is only here that the security policy's defined enforcement checks
are definitively evaluated, following the semantics from @glowy:controls.
// This makes its correctness of the utmost importance, emphasizing also the
// prior stages' role in providing a sound baseline for enforcement.

#pagebreak()

== Security Controls <glowy:controls>

As already introduced in @bg:taint:controls, this work considers five different
types of security controls to support its taint analysis endeavor. These each
represent different aspects of the customization necessary for information flow
control to be applied correctly to a given project and yield useful results.

Each control is associated with an inherent security label which determines how
that particular instance behaves and what semantic meaning it represents,
adapted to each specific situation where security controls are employed
throughout the Go module under analysis.

Different kinds of controls may be applied to different Go constructs, depending
on where they have defined semantics and provide a legitimate security value. It
should be noted, however, that all controls that accept function declarations or
function calls likewise accept method declarations or method calls, since this
work generally treats methods as a specialized kind of function, as explained in
@.

Some controls' security labels support a special wildcard notation for more
convenient handling of tag axes; concretely, the tag
$underline(italic("name")) thin : thin *$ is interpreted as meaning all possible
tags within the $underline(italic("name"))$ axis. This shorthand is useful to
promote simplicity, a clear policy intent, and maintainability, since wildcards
unburden stakeholders both from knowing all possible tags when configuring a
localized control and from continuously having to update exhaustive lists of all
possible tags. Wildcards therefore offer an analogous benefit to what is already
the advantage provided by axes themselves as a convenient mechanism increasing
policy expressiveness and mitigating human error.

Wildcards are nevertheless only accepted in some specific positions, and have no
meaning when used anywhere else. In particular, values themselves may never be
labeled with a wildcard tag, since it is a convenience for controls only, and
would bring no useful security meaning if applied outside of the specific cases
outlined in this section. This means that, for instance, a value tainted with
label $L = {underline("unit") thin : thin \*}$ is taken as conveying a single,
ordinary tag identified by the literal character $\*$ and bound to the
$underline("unit")$ axis, rather than a wildcard $*$ for that same axis, as $\*$
is not recognized any special meaning in this particular context.

Later @glowy:directives specifies in more detail how security controls can be
configured for this work's implementation.

#pagebreak()

=== Sources

Sources are fundamental controls, marking points from tainted information flows.
These are the only logical units initiating actual taint tracking throughout the
program's execution paths, as all values are otherwise labeled $bot$ unless
operated on by a source, or representing the propagation of taint originating
from other values initially subject to a source.

This control may target any constant, variable, or function declaration, as well
as any assignment (including complex assignments, such as ```go a += b```), and
send statements (such as ```go ch <- x```). Some of these are associated with a
right-value, in which case its label $L$ is preserved and not overwritten; for
bindings (constants and variables), this corresponds to the specified
initialization expression (or $bot$ if the declaration is not initialized, since
a type's zero-value has no taint), for assignments it is the right-value being
assigned to the mutation left-value, and for send statements it is the value
being sent. Is is always considered $bot$ for function declarations, as the
source's effect is in that case applied upon function access, including for each
returned value's taint at invocation sites, since calls necessarily constitute
access.

Sources are therefore construct-specific controls instructing the analyzer to
increase an existing label $L$ by the source's configured label,
$cal(L)_"Source"$, instead considering the new combined security label

$ L' = L union.sq cal(L)_"Source" $

for the purposes of the underlying operation.

For example, if an assignment ```go a = b``` is marked as an information source
with inherent label $cal(L)_"Source"$, then `a`'s taint is updated to hold label

$ L_a = L_b union.sq cal(L)_"Source" union.sq beta $

where $L_b$ is `b`'s own security label and $beta$ is the contextual Branch
Label, as defined in @glowy:procedure:context:branch, since assignments are
committal operations and must thus reflect a dependency on the current execution
path.

Sources' inherent labels do not allow wildcard tags, as that would not bring any
precise security value and be functionality equivalent to an axis-scoped Top
($top$), intentionally excluded from this work due to its associated pitfalls.

As a special case, sources may also target struct fields when the struct type's
declaration is known.

=== Revocations

Revocations counteract sources' effects by partially or wholly revoking a
target's accumulated taint, as explicit manual overrides to the overall taint
propagation model designed as an intuitive escape hatch for managing risk
according to the project's tolerance for necessary breaches of security.

They may target the same constructs as sources (except for struct fields) and
operate in the same way as sources, but symmetrically: the analyzer considers
revocation-targeted operations as manipulating

$ L' = L \\ cal(L)_"Revocation" $

where $L$ is the existing right-value's label (or $bot$) and
$cal(L)_"Revocation"$ is the control's inherent security label.

Unlike sources, however, revocations do support wildcard tags in
$cal(L)_"Revocation"$, allowing for greater flexibility in sanitizers and
related patterns.

=== Sinks

Sinks are the primary class of policy enforcement checks, representing a
security boundary where a given invariant must hold true, according to its
inherent $cal(L)_"Sink"$. They validate the accumulated taint of each value that
reaches them against what is permitted by the configured security policy,
surfacing an illegal flow error if the value's label is rejected.

This control may target any construct supported by sources and revocations
(constant, variable, or function declarations, as well as assignments), but also
function invocations. It operates independently for each of the construct's
underlying values, meaning that the associated invariant will be checked
individually for each binding initialization expression, assignment right-value,
and passed call arguments (this latter case applying both for calls directly
targeted by a sink and for all calls to a function targeted by a sink).

Each underlying value's label $L$, as accumulated through taint propagation over
the course of the program's relevant execution paths, is thus subject to the
specific enforcement criteria associated with the kind of the sink in question,
i.e., depending on whether the sink is an allow-sink or a deny-sink.

It is critical to note, however, that sinks always examine a value's label $L$
_after_ the current branch label $beta$ has been merged into it, so as to take
into account the overall environment affecting the operation.

All sinks' inherent labels support wildcard tags, enabling stakeholders to
define security policies with broad coverage and clear intent, as is expected
by supporting the axes system in its entirety for complex use cases.

==== Allow-Sinks (Whitelisting)

Allow-sinks verify whether the relevant subset of the incoming value's label $L$
is consistent with a given whitelist, first restricting $L$ to the axes
referenced in the sink's inherent label (the whitelist) and then checking
whether that restriction is a subset of that permitted label.

Given an allow-sink $S$ of label $cal(L)_"Sink"$ and a value $v$ of label $L$,

$
  S "accepts" v <==> L|_A <= cal(L)_"Sink", quad
  "where" A = underline(cal(L)_"Sink")
$

with $L|_A$ representing the axis restriction of $L$ to $A$ and $underline(L)$
the axis set of $L$, according to each operations' definition in
@intro:ifc:axes.

This means that, for instance, an allow-sink with label
$cal(L)_A_1 = {"blue", "red"}$ accepts a value with label $L_"A1A" = {"red"}$,
but rejects another value with label $L_"A1R" = {"blue", "red", "green"}$, since
the tag $"green"$ is not whitelisted.

Furthermore, an allow-sink with label
$cal(L)_A_2 = {"yellow", thick underline("dir") thin : thin *}$ accepts a value
with label $L_"A2A" = {underline("dir") thin : thin "north", thick
  underline("month") thin : thin "july"}$ but not a value labeled
$L_"A2R" = {"brown", thick underline("dir") thin : thin "east"}$, as $"brown"$
is not contained in $cal(L)_A_2$.

==== Deny-Sinks (Blacklisting)

Deny-sinks denote a reversed kind of criterion, instead being satisfied only by
incoming values with a label $L$ that respects a configured blacklist, i.e., the
sink's inherent label.

Given a deny-sink $S$ of label $cal(L)_"Sink"$ and a value $v$ of label $L$,

$ S "accepts" v <==> L inter.sq cal(L)_"Sink" = bot $

meaning that $v$ is accepted if and only if its label $L$ contains none of the
tags present in $cal(L)_"Sink"$. If the latter contains any wildcard tags, then
$L$ analogously cannot contain any tag bound to such an axis.

For example, a given deny-sink with label
$cal(L)_D = {"pink", thick underline("month") thin : thin *}$ accepts a value
tainted with label $L_"DA" = {"green"}$ but rejects another value with
associated security label
$L_"DR1" = {"pink", thick underline("dir") thin : thin "north"}$.
Moreover, a value with label
$L_"DR2" = {"blue", thick underline("month") thin : thin "january"}$
would similarly be rejected, since the entire $underline("month")$ axis is
blacklisted.

#pagebreak()

=== Assertions

Assertions are the other kind of policy enforcement checks, operating in the
same way as sinks, but applying a simple equality criterion to determine
consistency with the specified security policy. These are not intended for
normal use, but are provided to support testing and debugging facilities.

Given an assertion $A$ of label $cal(L)_"Assertion"$ and a value $v$ of label
$L$,

$ A "accepts" v <==> L = cal(L)_"Assertion" $

requiring exact matching for $v$ to be accepted.

Assertions may be used anywhere where sinks are supported (constant, variable,
or function declarations, as well as assignments and function invocations), but
may alternatively also target arbitrary expressions that evaluate to one or more
values, in which case the assertion enforces exact label equality for each of
those values. This latter case is however only considered when the expression is
isolated in an expression statement.

It is important to note that assertions, like sinks, take into account a value's
label $L$ _after_ the current branch label $beta$ has been merged into it.

Unlike sinks, this control does not support wildcards, since they would
compromise the very precision that assertions exist to provide.

=== Blanket Controls <glowy:controls:blanket>

Each of the aforementioned security controls is often applied at source-code
level to specific instances of their respectively supported language constructs,
but they may alternatively target all instances of a specific construct that
satisfy a set of conditions. The only exception is assertions, which do not
support blanket targeting, due to their precision-oriented nature.

This mechanism is especially useful when dealing with third-party code,
necessarily without a corresponding definition in the codebase under analysis,
so that the appropriate controls apply every time the constructs in question are
accessed or employed within first-party implementations.

For instance, it often makes sense to define a blanket sink targeting all calls
to `fmt.Println` and similar output functions, or a blanket revocation
instructing the analyzer to recognize filesystem path sanitization performed by
invocations to the `path.Clean` function, depending on the project's specific
attacker model and elected risk acceptance.

#pagebreak()

Different blanket controls support different kinds of conditions under which
they apply, but they must always target a specific item, such as a function or
a struct field. This means that all blanket controls are necessarily associated
with a Go package path, pinning the remainder of their conditions to a
particular scope, and a member name, relative to that package. If the target is
a type-associated member (i.e., a method or a struct field), then the blanket
target also has an associated type name, thus being conditional to a given
member of a given type from a given package; otherwise, no type name is relevant
as the target exists at the package level, in which case it refers simply to the
top-level function or binding identified by the given member name within the
package with the given path.

The pseudo-path `builtin` is interpreted as referring to predeclared identifiers
(such as `len` or `max`), in accordance with the convention adopted by the
official Go documentation#footnote(link("https://pkg.go.dev/builtin")). This is
a design choice motivated by the absence of a package path potentially being
subject to confusion by stakeholders as referring to the root package path of
the module under analysis, leading to a silent lack of application that would be
difficult to notice.

Analogously, the pseudo-path `operator` scopes references to some of Go's
language-level operators, so that blanket controls may be defined for them. This
special mechanism is supported for all binary operators, including those related
to equality (`=`, `!=`), comparison (`<`, `<=`, `>`, `>=`), calculations (`+`,
`-`, `*`, `/`, `%`), bit manipulation (`<<`, `>>`, `|`, `&`, `^`, `&^`), and
logic (`&&`, `||`).

Furthermore, blanket sinks targeting functions or methods may be conditional to
specific argument positions. For example, a sink defined to apply only to the
argument at the first position of calls to the `Query` method of the `DB` struct
of the `database/sql` will trigger for the raw @sql query string, but not for
the query arguments passed separately.

In turn, blanket sources and revocations targeting functions or methods may
additionally be applied selectively to only one or more of its return values.
Moreover, for maximum precision, an argument predicate may be specified to limit
control application to when a specific call argument position may match a given
constant, case-insensitively. In that case, the control is conservatively
triggered whenever the analyzer cannot prove that the argument in question does
not match the provided value. This matching may also be set as fuzzy, wherein
instead of requiring equality, substring presence suffices.

#pagebreak()


== Fundamental Primitives

This section describes basic primitives used by this work's implementation of
taint analysis in order to support greater flexibility and precision, even if
not strictly necessary for the literal realization of the analysis procedure
outlined in @glowy:procedure.

They represent fundamental building blocks used extensively across all
mechanisms, directly contributing for and greatly improving the present work's
overall quality and accomplishing of the stated project goals.

=== Label Backtraces

While the main concern of taint analysis is, naturally, the taint itself, is it
crucial to also track adjacent metadata, namely the taint's provenance trace,
i.e., the historical steps by which a value has acquired each logical part of
its taint. For that purpose, Glowy defines _label backtraces,_ which
encapsulate labels and enrich them with additional contextual information.

The implementation thus propagates backtraces, not labels, across all relevant
paths. This increases overall complexity and consumes significantly more
resources (particularly increasing memory usage), but enables enforcement checks
to report problems with much more detailed information.

Backtraces are defined recursively, as they comprise trees where each instance
is the composition of its children complemented by additional context, as
relevant especially for problem reporting and in-depth understanding of taint
encountered at policy enforcement checks. Each label backtrace tracks the
following properties:
- *Kind:* the type of operation causing the present label attribution, such as
  Assignment, Function Parameter, or Branch;
- *Label:* the security label associated with a piece of information;
- *Symbol:* known name of the binding, function, method, or field
  that is reported to hold the present label backtrace, if any;
- *Location:* where the present attribution operation took place, as indicated
  by an unambiguous file path and byte range; and
- *Children:* other label backtraces representing earlier steps in the taint
  provenance tree, each holding these same properties.

Label backtraces corresponding to attributions caused by information sources to
values that would otherwise have a Bottom label have no children, since they
represent a root from which the provenance tree grows.

Since the explicit goal with this primitive is to track taint propagation,
backtraces never have a Bottom label, with the absence of taint instead being
aptly represented by the absence of a backtrace. This condition allows
operations to be defined more expressively for label backtraces without having
to worry about the special case where their label could be Bottom.

Moreover, for the purpose of keeping backtraces as lightweight and focused as
possible, they enforce the following two invariants over their children:
+ _Children's labels are always a subset of their parent's label._ For example,
  a backtrace representing the label ${"blue", "violet"}$ can have a child
  with label ${"blue"}$ and another holding label ${"violet"}$, but never a
  child with label ${"yellow"}$. Formally, for a backtrace $B$,
  $ forall c in B, quad L_c <= L_B $
+ _Children's labels are always disjoint._ For example, if a first child has
  label ${"blue", "violet"}$, a second child can never have label
  ${"blue", "yellow"}$; instead, it is trimmed to just ${"yellow"}$ at
  construction. Formally,
  $
    forall i, j, quad i != j and max(i, j) < \#B space.third ==> space.third
    L_B_i inter.sq L_B_j = bot
  $
  where $B$ is a backtrace and $B_i$ its $i$#super[th] child (zero-indexed).

In addition, specialized pruning is performed upon construction in an attempt to
keep backtraces more shallow, manageable, and efficient, since otherwise their
growth could explode, especially during convergence loops. With the goal of
eliminating unnecessary and repeated backtraces that add no new information to
what is already explicit from their children, a single-child backtrace that
would hold exactly the same label as its child is not created (with the child
being used instead) if either the child, or one of its descendents following a
single-child spine, has exactly the same contextual properties as
the parent backtrace that would be created (kind, symbol, and location). This
prevents semantic cycles and ensures backtraces are strictly limited to the
depth necessary to contextualize the associated taint.

=== Value Shapes <glowy:primitives:shapes>

Furthermore, whereas label backtraces provide context essential to post-analysis
reporting, more detailed information regarding each value is necessary during
the analysis process in order to ensure adequate precision.

In order to support more specialized handling and propagation, this work employs
broad value _shapes_ to hint more precise details about pieces of information
whenever they are known. The implementation thus, in reality, propagates shaped
value representations across all relevant paths, rather than label backtraces
directly, forming an even higher level of abstraction.

All such materialized value representations are purely intermediate artifacts
supporting increased precision and can be collapsed into label backtraces
wherever required, including at implementation boundaries where any output
leaves the analyzer (such as when reporting illegal flows, with a backtrace
being reported found rather than an internal value representation).

Concretely, these value representations comprise an associated source-code
location (necessary for constructing a label backtrace upon collapsing), any
associated declared type's lightweight information (per
@glowy:procedure:context:types) if statically known, and the value's shape,
providing more specific context.

The following broad value shapes are supported:
- *Simple:* represents a scalar, or any kind of value when no more specific
  shape is presently known;
  - Simple values are associated with a single label backtrace (or lack
    thereof), with no additional contextual information being tracked.
- *Expandable:* encapsulates one primary and one or more secondary values, for
  use with special language constructs that present differing cardinality
  depending on where they are used;
  - For example, indexing from a map can yield either one or two values
    (e.g., ```go v = m[k]``` or ```go v, ok = m[k]```), represented here as an
    expandable value with primary corresponding to `v` and `ok` as the single
    secondary.
- *Möbius:* represents an infinite strip expandable to any cardinality based on
  a single encapsulated value, commonly used to support blackboxing;
  - Optional overrides allow per-index precision when more is known.
- *Channel:* tracks precise information regarding the label backtraces affecting
  different channel properties;
- *Array, Struct, Map, and Unknown Composite:* tracks precise context such as
  known values at constant keys, for some degree of field sensitivity;
- *Slice:* tracks even more precise, slice-specific information, relying on an
  underlying Array-shaped value for backing storage.
- *Function:* tracks various contextual datapoints essential to analysis.

In most cases, information enters the analysis scope as a Simple value, but it
might be automatically upgraded (coerced) into one of the more complex shapes
when it is used in a context unambiguously tied to that shape.

=== Simple Constant Values <glowy:primitives:consts>

In parallel, as a complement to value shape and taint information, it is
sometimes crucial for increased precision to support the simple constant
evaluation of statically-known values and expressions.

This mechanism is provided as a best-effort improvement to precision, only
supporting very simple constant expressions, especially for literal composition
with an obvious result. For example, the expression ```go 2 + 3``` is recognized
as evaluating to the constant integer ```go 5```.

Besides the ```go nil``` identifier and isolated boolean, integer, and string
literals, some degree of manipulation is modeled, including:
- the identity operator (e.g., ```go +3``` is ```go 3```);
- string concatenation (e.g., ```go "a" + "b"``` is ```go "ab"```);
- constant equality and inequality (e.g., ```go (2 + 3) == (3 + 2)``` is
  ```go true```);
- logical operations (e.g., ```go true && false``` is ```go false```); and
- calculations between integer constants (e.g., ```go 5 * 5``` is ```go 25```).

When a computation result would surpass numeric bounds, no constant value is
recognized, rather than a different (e.g., overflowing) number being used, to
preserve soundness.

Moreover, Symbols in the Symbol Table ($Sigma$, described in
@glowy:procedure:context:symtab) store an optional associated known constant
value, populated only if one is known. This allows simple constant value
derivation to additionally perform name resolution and re-use computed simple
constant values throughout the program, greatly improving constant value
tracking. @glowy:primitives:consts:resolution showcases name resolution of
`x` to the constant value $7$ in the highlighted line 2.

#codly(highlighted-lines: (2,))
#figure(
  ```go
  x := 5 + 2 // known constant value = 7
  y := x % 3 // known constant value = 1
  z := fn(y) // no known constant value
  ```,
  caption: [Example simple constant value propagation across bindings],
) <glowy:primitives:consts:resolution>

Simple constant values are used to, for instance, to sustain more precise
handling of composite values so that an entire container is not tainted just
based on an assignment to a known constant key.

In addition, blanket controls supporting argument predicates use this primitive
to avoid being applied for function or method calls which can be statically
proven to not match the specified predicate value.

#pagebreak()

== Implementation

This section explores in more detail how each of the architectural components
listed in @glowy:design:architecture are implemented, allowing for a better
understanding on how concretely they operate and work together.

More detailed usage instructions are provided in @usage.

=== Glowy Library

The principal software contribution provided by this degree project is `glowy`,
the central taint analysis and policy enforcement library. It comprises
approximately #zero.num(24000) lines of Rust code (excluding blanks) across a
rich module structure. It exposes a polished and intuitive public @api, which is
fully and extensively documented#footnote[The documentation is mirrored at
  #link("https://glowy.rso.pt") for more convenient access.], including several
per-item usage examples, which automatically double as tests through Cargo's
doctests facility#footnote[Cargo (#link("https://doc.rust-lang.org/cargo")) is
  Rust's package manager.].

In order to make full use of the language's safety guarantees, unsafe Rust is
not used anywhere in the library (or any of the other contributions), as
enforced at the compiler level by a `#![deny(unsafe_code)]` lint.

The main exported interface is the `Analyzer` type, supporting different kinds
of initialization and configuration, so as to suit a variety of use cases. It is
also through `Analyzer` that the topmost-level analysis mechanisms are
implemented, deferring specific steps to other private modules.

Analysis in `glowy` is implemented according to the theoretical procedure
described in @glowy:procedure, though some parts have been restructured to
optimize performance; for instance, the Stage \#2 convergence loop snapshots
only once per iteration, and Stage \#3 does not clear `AnalysisContext`'s
problem set because global error suppression is already enabled throughout Stage
\#2. This means that the software implementation is more complex and convoluted
than the theoretical model, as the presented algorithms are bound to explanatory
simplicity, but the effective observable behavior is the same.

The bulk of the implementation code corresponds to the taint analysis visitor
tree that provides specialized handling for all @ast node types, with local
processing being complemented by the global `AnalysisContext` instance offering
the properties described in @glowy:procedure:context. Starting from
`visit_source_file` for `SourceFileNode`, each visitor delegate to others
whenever their corresponding nodes are found, until the @ast leaf nodes are
reached. In order to ensure correctness, each node is only visited once
#footnote[Expect when global error reporting is disabled during convergence
  loops.].

These visitors' behavior is necessarily specific to each functionality and
represent very extensive specialized logic, so they cannot be exhaustively
described in the present report, but more interesting or otherwise noteworthy
cases are explored in @glowy:constructs.

Furthermore, fixed point determination, particularly during Stage \#2 of
analysis as described in @glowy:design:procedure:stage2, relies on snapshotting
of the current `SymbolTable` state so that later checks for convergence can
compare the current snapshot with the previous one, per
@glowy:design:procedure:overview. As a design decision, this snapshot comprises
an actual (condensed) copy of the relevant state, rather than relying on a hash
digest, even if at a cost of increased memory usage. This is because
materialized snapshots provide observability and debuggability, as well as
cheaper comparison between instances, as equality checks are short-circuiting,
which is much more useful if performing a deep recursive comparison than a
digest comparison (where the hashing, prior to the comparison itself, is the
most expensive operation). In addition, using digests would require assuming
that no collisions could ever happen, which (while not entirely unreasonable) is
not a necessary model constraint. Such an assumption would also necessitate the
use of an expensive hash function to minimize the risk of collisions, affecting
performance.

Additionally, the referenced snapshot equality checks must use special logic to
omit `LabelBacktrace` children, comparing backtraces shallowly rather than
requiring exact tree equality to determine convergence. This is necessary
because backtraces track all taint history, even across convergence iterations,
meaning that provenance trees may experience unbounded growth; if they were to
be included in the comparison, it would be possible for two consecutive
snapshots to never match, meaning that a fixed point would never be determined,
even after the underlying labels converging.

Project-specific configuration, including security controls forming a security
policy, are in most cases derived from a `glowy.toml` file in the project root,
if one exists. In particular, if the `verbose` configuration option is enabled,
or if the `GLOWY_VERBOSE` environment variable is set, the analyzer emits
high-level progress reports to standard output (`stdout`), including partial
elapsed times for the different analysis stages.

#pagebreak()

The library also notably ships with a Base Security Policy, per
@glowy:base-policy, exposed via the `BASE_SECURITY_POLICY` constant of the
`policy` module. Although it is enabled by default, it can be disabled as a
whole by setting the `inherit_base` configuration option to `false`, and each of
its directives can be individually disabled through
`excluded_base_blanket_directives`.

Moreover, as a point of customizability, `glowy` defines 3 Cargo features gating
non-essential functionality so as to allow for smaller binary sizes if used
programmatically by consumers who do not need all convenience features. They are
nevertheless enabled by default, so all features are opt-out rather than opt-in.
The features are:
- `base-security-policy`: Embeds the Base Security Policy @toml source in the
  binary and applies it when the `inherit_base` configuration option is not
  `false`. If this Cargo feature is disabled at compilation, the Base Security
  Policy is not included, nor any code specific to its application.
- `parallelism`: Uses `rayon`
  #footnote(link("https://github.com/rayon-rs/rayon")) to parallelize build
  constraint permutation analysis, as described in
  @glowy:construct:build-constraints. Parsing is also parallelized but only from
  1 GiB total file size, to avoid unnecessary overhead penalty. If this Cargo
  feature is disabled at compilation, analysis is strictly sequential and
  `rayon` is not a dependency.
- `toml-config`: Supports parsing `glowy.toml` files rather than relying on
  programmatic configuration. If this Cargo feature is disabled at compilation,
  @toml deserialization is not provided and neither of the `toml` or `serde`
  crates are a dependency.

When analyzing Go modules, $40$ different kinds of problems can be identified
and surfaced. These are organized into categories, simplifying classification
work for consumers. Problem kinds are mapped to the following categories:
- Analyzer Misconfiguration (e.g., duplicate registered source file)
- Unrecognized Feature (e.g., unknown Glowy directive)
- Suspicious (e.g., explicit revocation with Bottom as its inherent label)
- Invalid Go (e.g., unknown symbol in operand name expression)
- Unsupported Go (e.g., incompatible function merging)
- Security Policy Violation (e.g., insecure information flow)

Extensive and well-documented problem reporting helps consumers know when to
draw conclusions from library's findings, ensuring transparency and avoiding
a false sense of security when a construct is not supported.

#pagebreak()

=== Glowy @cli Application

The most user-facing component of the Glowy ecosystem is `glowy-cli`, the
@cli application wrapping around the `glowy` library and complementing it with
easy orchestration and user-friendly, intuitive problem diagnostics. The crate
has approximately #zero.num(1300) lines of Rust code (excluding blanks).

It supports two commands. The main and default one performs information flow
analysis using `glowy`, while the second one (`base-security-policy`) just
outputs the analyzer's Base Security Policy to standard output (`stdout`). The
latter command supports a `--eject` flag designed to support a smooth onboarding
of stakeholders to the project; the flag causes the Base Security Policy to be
written to a `glowy.toml` file at the repository root to allow easy and
progressive modifications according to the project's own requirements.

When using the primary command, `glowy-cli` triages problems detected during
analysis into an appropriate severity level, based on its category. For the
six categories mentioned in the previous section, `glowy-cli` maps
Misconfiguration and Security Policy Violation into an Error, while the rest are
considered Warnings. If the `--strict` flag is passed, however, all reported
problems are surfaced as Errors.

Furthermore, the most significant contribution provided by the @cli application
is its construction of rich error and warning diagnostics, including annotated
source code snippets and clear but concise tailored explanatory messages. For
policy violations, the complete propagation chain from source to sink is shown,
allowing stakeholders to easily identify the issue. For example,
@glowy:impl:cli:diagnostic (below) shows a real diagnostic output from analysis
of a real-world project, taken from a longer output report.

#cmd-output(
  read("../assets/openlist.ansi"),
  text-size: 0.7em,
  caption: [Example insecure flow diagnostic],
  label: <glowy:impl:cli:diagnostic>,
)

The example diagnostic in @glowy:impl:cli:diagnostic is polished and intuitive,
ensuring easy grasp of all relevant information, especially for stakeholders
already familiar with the layout. A short error summary is included at the top,
next to the error kind's unique code, while the affected file is listed
promptly thereafter, succinctly identified by its registered path within the Go
module directory under analysis. The detailed error message (in red) immediately
stands out as the most important element in the diagnostic, while additional
problem-specific context is provided in blue (in this case, taint provenance).
Source code in snippets is included in white, with line numbering on the left.
The error's main location is expressed as line and column next to the file path,
and a grounded, non-obtrusive help message is included at the end. If more
information is needed, the error code (e.g. `F003`) is a clickable hyperlink to
that problem type's online documentation, which describes it in more detail.

After all diagnostics, a summary line is shown, as illustrated in
@glowy:impl:cli:summary. This allows stakeholders to easily tell at a glance if
any problems were reported. The error and warning count segments are only
colorized if more than 0, making them stand out. If there are no errors nor
warnings whatsoever, a success message is shown instead.

#cmd-output(
  read("../assets/summary.ansi"),
  text-size: 0.7em,
  caption: [Example summary line for a failing analysis run],
  label: <glowy:impl:cli:summary>,
)

When source code snippets are included, by default 1 additional line of context
is given in each direction, but this is customizable by supplying the flag
`--context-lines N`. Moreover, the `--time-analysis` flag reports the elapsed
time for the entire analysis process, including parsing.

In addition, the tool strives to make the conveyed problems as clear as possible
for users to understand, which includes not overloading output and keeping it
concise. A significant effort undertaken in that direction is `glowy-cli`'s
mechanism for noise reduction, wherein enforcement check violations have their
provenance trace pruned to include only what is relevant for the violation in
question, if possible; while `glowy`'s output aims for completeness and provides
the full history, `glowy-cli` prefers human-friendly simplicity.

For example, in the case of the insecure flow in @glowy:impl:cli:diagnostic, the
`bt` variable has label $L = { underline("secret") thin : thin "http", thick
  underline("untrusted") thin : thin "http"}$, thus being rejected by the
`log.Debug` deny-sink that blacklists each of the tags in
$cal(L)_"Sink" = {underline("secret") thin : thin *}$. The critical fault with
`bt` is its $underline("secret") thin : thin "http"$ tag since all tags bound to
the $underline("secret")$ axis are explicitly prohibited by the sink, while
$underline("untrusted") thin : thin "http"$ is not in any way relevant to the
violation. As such, the trace information explaining why `bt` has the latter
tag is not necessary for the user to understand and investigate the underlying
problem, and is thus omitted by `glowy-cli`'s noise reduction mechanism. This is
visible in @glowy:impl:cli:diagnostic, which states the value's full label but
then only shows the relevant taint's provenance.

Finally, while the `glowy` library only supports analyzing a single Go module at
a time, `glowy-cli` has a `--suite` flag to orchestrate the sequential analysis
of multiple modules in the same directory. The `--multi-suites` flag applies the
same effect at a higher level, accepting a directory of directories of modules.
This is particularly useful for testing, including `ifc-benchmarks`, but could
also be used by security auditors examining several third-party projects as
part of the same workflow.

If analyzing multiple modules, a convenient summary report is generated at the
end of output, allowing users to understand aggregate status at a glance. If the
`--summary-only` flag is passed, per-module output is omitted.

=== Glowy Parser

Any high-level analysis is only possible because of `glowy-go-parser`, a
lower-level utility that takes Go raw text as input and parses it into an
@ast:long for convenient manipulation.

The parser crate is made up of approximately #zero.num(8000) lines of Rust code
(excluding blanks), and supports almost all Go constructs, with the notable
exception of arbitrary-precision extremely-large numeric literal constants, even
if this is extremely rare in real Go code (for example,
integers are only supported up to $2^64 - 1 = 18 thin 446 thin 744 thin 073 thin
709 thin 551 thin 615$ in this work).

This library has extensive unit tests and, while it is somewhat specialized
towards Glowy's particular use case, it is sufficiently generic to possibly be
used by others, for other applications.

In addition, despite `glowy-go-parser` being primarily intended to be used as a
modular library to be depended on by other Rust crates, it can also be used
directly as an executable, outputting a textual representation of the @ast if
successful, or user-friendly diagnostics in case of error (in the same style as
for `glowy-cli`). In fact, `glowy-cli` defers parsing error summarization to
`glowy-go-parser`'s existing intuitive messages, which is exported by the parser
library in a structured form.

=== Glowy Evaluation Utility <glowy:impl:eval>

In order to support the systematic evaluation of the Glowy pipeline against
real-world Go projects, `glowy-eval` is implemented as a separate and
independent higher-order orchestrator used to facilitate the download of each
input project, to deploy and monitor Glowy's analysis of each of the project's
Go modules, and to record statistics from the run for later manual analysis,
as well as the analyzer output if any problems were reported.

The `glowy-eval` component comprises approximately #zero.num(2200) lines of Rust
code (excluding blanks) and handles both Git-based and @http\-based downloads,
both of which with resilient retry mechanisms using exponential backoff. Results
are stored in an SQLite#footnote(link("https://sqlite.org")) database during
operation, so that runs are resumable and the procedure does not have to be
restarted after a crash, and a text-based (comma-separated format) results
summary is generated after all input projects have been processed.

This utility spawns a `glowy-cli` process to conduct the analysis instead of
programmatically depending on the `glowy` library directly, since the goal is to
be as realistic as possible and mimic the exact results that would be obtained
by manually executing `glowy-cli` and taking notes of the reported findings and
associated metadata. As such, the indirectness is appropriate for full-stack
evaluation, even if in normal use cases Rust programs should depend on the
`glowy` Rust library for in-Rust taint analysis of Go modules.

=== Other Auxiliary Scripts

Finally, several other one-off scripts were written to support the evaluation
process, especially each dataset generation step described in
@methods:collection:discovery, but also the pseudo-random stratified sampling
prescribed by @methods:collection:sampling.

These are implemented as individual and independent Rust files, comprising a
total of approximately #zero.num(1700) lines of code (excluding blanks). For
simplicity, multi-file Cargo directories are not used (as would be standard for
normal Rust projects), with each `.rs` file instead making use of the
rust-script third-party utility#footnote(link("https://rust-script.org")) to
make compilation and dependency management transparent to the invoker; a
`#!/usr/bin/env rust-script` shebang allows the script to be executed directly
as `./path/to/script.rs`.
// (no space) Dataset generation scripts use an SQLite database to store
// intermediate state so that they are interruption-resistent, meaning that
// execution can be safely resumed after a crash.
All network communication uses retry mechanisms when /* appropriate */ suitable,
respecting rate limits. // set by providers.

== Analyzer Directives <glowy:directives>

Security controls are registered to the analyzer through explicit directives,
which may be accomplished in multiple ways, so as to flexibly support various
possible use cases as required by the different kinds of stakeholders.

Firstly, directives may be present directly in the source code under scrutiny by
their embedding in well-formed source-code annotations. These are included in Go
comments, meaning that they do not interfere with other tooling, including the
Go compiler itself. @glowy:directives:annotations illustrates how an annotation
can be used to declare a source for a binding declaration.

#figure(
  ```go
  // glowy::label::{secret, origin:deep-thought}
  const answer = 42
  // glowy::label::{origin:earth}
  var question = questionFor(answer)
  ```,
  caption: [Example source directives applied via annotations],
) <glowy:directives:annotations>

Line 1 of @glowy:directives:annotations causes the constant `answer` to be
tainted with security label
$L_A = {"secret", thick underline("origin") thin : thin "deep-thought"}$,
whereas line 3 combines the right-value's existing label ($L_A$, assuming
`questionFor` returns a single value with taint matching the passed argument)
with $cal(L)_Q = {underline("origin") thin : thin "earth"}$ which leads to the
variable `question` being tainted with an effective label $L_B = {"secret",
  thick underline("origin") thin : thin "deep-thought", thick
  underline("origin") thin : thin "earth"}$.

Source-code annotations are excellent for locality and clearer behavior
immediately evident to one reading their target's code, tying implementation to
security policy, which is also better for maintainability. They are therefore
the recommended primary method for defining a security policy for project-local
targets. @glowy:directives:annotation-mapping below shows the mapping between
supported annotation directives names and their corresponding security controls.

#figure(
  table(
    columns: (auto, auto),

    table.header(strong[Directive Name], strong[Security Control]),

    [`label`], [Source],
    [`revoke`], [Revocation],
    [`allow`], [Allow-Sink],
    [`deny`], [Deny-Sink],
    [`assert`], [Assertion],
  ),
  caption: [Supported source-code annotation directives names],
) <glowy:directives:annotation-mapping>

It should be noted, however, that these annotations are only accepted where
their respective controls are defined, as specified in @glowy:controls, with the
analyzer surfacing a problem for user review when an annotation is found with an
unrecognized or unsupported directive name, for visibility and to facilitate
to stakeholders the detection of potential mistakes.

In addition, annotation comments must always immediately precede the construct
they are intended to target, which in some cases might require the (otherwise
unnecessary) parenthesization of sub-expressions, such as if targeting a
function call that is syntactically nested in a larger expression.

Secondly, when using the `glowy` library directly (i.e., not through the
provided @cli application), blanket controls as defined in
@glowy:controls:blanket may be registered programmatically through the exposed
`Analyzer` methods `add_blanket_source`, `add_blanket_revocation`, and
`add_blanket_sink`, relying on the structured Rust-side definition of blanket
directive targets. This is convenient particularly for third-party and
standard library targets, namely `fmt.Println`, since they do not have one
singular particular definition site in the examined codebase where can
annotation could be placed.

Thirdly, blanket directives may also be present in a `glowy.toml` configuration
file in the module's root directory, alongside other options. The @toml tables
at keys `sources`, `revocations`, `allow_sinks` and `deny_sinks` are
deserialized into typed Rust representations following documented procedures,
with blanket directive targets in particular being parsed from a well-formed
string conformant to what is essentially a minimal and well-documented
#footnote(link("https://glowy.rso.pt/glowy/" + //
"policy/struct.BlanketDirectiveTarget.html#parsing-and-deserializing")) @dsl.

#codly(highlights: ((line: 2, start: 2, end: 27),))
#figure(
  ```toml
  [sources]
  "os.LookupEnv->0#0~=API_KEY" = ["secret"]

  [deny_sinks]
  "fmt.Println" = ["secret"]
  ```,
  caption: [Example `glowy.toml` blanket directives configuration],
) <glowy:directives:toml>

#v(1fr)
#highlight[a little more]

#pagebreak()

For instance, the highlighted source key in line 2 of @glowy:directives:toml
is unmarshaled into a blanket directive target applying to the first returned
value by calls to the `LookupEnv` function of the standard library's `os`
package, but only when the value passed as first argument cannot be proved to
not contain the (case-insensitive) substring `API_KEY`. Any value matching such
a target is thus tainted with label $cal(L)_"Source" = {"secret"}$. In contrast,
line 5 shows a simpler example that does not rely on so many conditions.

Thirdly, for convenience and as a special case, struct fields may define struct
directives directly from their tags, according to conventional Go formatting.
The highlighted fields in @glowy:directives:struct-field-tag illustrates how
this is possible. For the snippet in question, a source directive labels field
`token` with security label $cal(L)_"token" = {"secret"}$, whereas another
source directive applies to the `nextId` field the label
$cal(L)_"nextId" = {"enumeration", thick underline("id") thin : thin "state"}$.

#codly(highlighted-lines: (3, 4))
#figure(
  ```go
  type state struct {
    active bool
    token string `glowy:"secret"`
    nextId int `json:"next_id" glowy:"enumeration, id:state"`
  }
  ```,
  caption: [Example `glowy.toml` blanket directives configuration],
) <glowy:directives:struct-field-tag>

If literal quote characters (`"`) are required, they may be escaped using `\"`.

Finally, it should be noted that the well-known axis prefixes `$` and `?` are
recognized as shorthands for axes `secret` and `untrusted`, respectively, when
used in a security label's tag. This means that when a tag is constructed, if it
is ostensibly not bound to an axis but has a name starting with such a prefix,
it is instead mapped to the respective axis and the prefix is stripped; for
example, during construction, the label $L = {\$"env"}$ is mapped to and
normalized as $L' = {underline("secret") thin : thin "env"}$. From then on and
throughout the analysis lifetime, including for problem reporting, only the $L'$
label is used.

This is a convenience aimed at simplifying security policies by keeping them
more concise, given that confidentiality and integrity are two very common
concerns when applying taint analysis, but the referenced axes are otherwise not
given any special treatment besides the stated shorthand construction. Such
behavior is supported for all directives, including in source-code annotations
and in `glowy.toml` files.

#v(1fr)
#highlight[a little more]

#pagebreak()

== Dependency Analysis & Blackboxing

Analysis is considerably limited by its restriction to first-party code. Only
the Go source code files registered to the analyzer (in most cases, those
present in the module's directory) are considered, even if they reference
dependencies external to the codebase under scrutiny.

For simplicity and resource restraining, this work does not attempt to resolve,
download, and analyze external dependencies. Instead, they are modeled as
black boxes, as already previously mentioned in @methods:subset. The same
applies in general to all accesses or uses of names without a known declaration
or implementation, as well as to situations wherein invalid or unsupported
constructs mean that an expected value cannot be determined and analysis must
proceed past the problem reporting.

Simple black boxes are approximated as if holding a Bottom label, while
function-shaped black boxes are modeled at call-time as returning a
Möbius-shaped value corresponding to the aggregate taint of all its inputs.

While this modeling is correct in the majority of cases, it is not sound (or
grossly imprecise) in general for three reasons:
+ A function or method's returned values do not depend on all of its inputs
  (arguments and receiver), making its aggregation an imprecise
  overapproximation, especially in cases where there are multiple returned
  values and each depends on different provided inputs.
+ A function or method's returned values, or any blackboxed value in general,
  depends on other input than expected by the blackbox modeling, such as in the
  case of ```go const Exported = secret``` in an external dependency, thus
  comprising an unsound underapproximation.
+ A function or method's unknown implementation, or a declared binding's
  unknown initialization expression, have side effects that would ordinarily
  result in the application of policy enforcement checks but do not since their
  targets are invisible to analysis.

Nevertheless, black boxes often still support targeting by blanket directives,
which is applied if applicable. This means that, for instance, even if the
`Body` field of the `Request` struct from the `net/http` Go standard library
package is approximated to hold label Bottom (since the `net/http` package is
not included in the analysis scope), if there is a blanket source directive
defined apply to it the security label ${"untrusted"}$, then the control will
still be effective, since
$L' = cal(L)_"Source" union.sq L = {"untrusted"} union.sq bot = {"untrusted"}$.

#pagebreak()

== Construct Handling <glowy:constructs>

As stated in @glowy:design:procedure:stage2, it is necessary to have specific
handling of each Go construct and language feature included in the supported Go
subset described in @methods:subset. The present section discusses how Glowy
implements specialized handling for some particularly relevant or interesting
constructs, including design choices that had to be made in the interest of
balancing soundness, precision, efficiency, flexibility, usability, and
overall simplicity.

Each subsection presents only a general overview of the specific implementation,
since it would be too extensive to explore each construct in more detail than
what is here included.

=== Import Declarations

Import declarations are processed and registered to the Symbol Table $Sigma$,
which tracks a mapping of qualifier names to their respective package paths for
the file currently being visited.

For named imports that do not specify a qualifier, which is the vast majority of
cases, it is necessary for a qualifier to be inferred. The correct default
qualifier corresponds to the package's native package name, which as explained
in @bg:go:overview:org is not necessarily related to the package path.

If the package exists in the codebase under analysis, its native name is
already available in its respective Package Scope Envelope stored in the Symbol
Table, as originally extracted from its files' ```go package``` clauses. In that
case, the inferred qualifier is always set correctly.

Otherwise, for external dependencies, the package path is the only available
piece of information, so inference must assume the package name can be derived
from the last component of the package path. This is not always true, but in
many cases it is a sufficient heuristic.

As mandated by the Go Modules Reference @gomod, a module path must have a suffix
in the form `vX` for major versions above 1 (except for paths with domain
`gopkg.in`, which should also have it for `/v0` and `/v1`), so this suffix is
stripped when found.

Common repository name tags are also stripped from the inferred qualifier, such
as a `go-`/`-go` or `lib-`/`-lib` prefix/suffix, as those generally do not
correspond to the declared root package name, representing only a naming
artifact for the project's publication repository.

In addition, the Symbol Table stores a set of package paths corresponding to the
current file's wildcard imports (dot-imports). These have no associated
qualifier and cannot be referenced by qualified operand names, instead having
all its exported members directly accessible by name.

When a symbol is accessed, if it fails resolution because it cannot be found in
the surrounding Scope tree, and if its name begins with an uppercase letter
(i.e., is an exported name), the file's registered wildcard imports are checked.
Priority is given to wildcard imports of packages part of the codebase under
analysis, since they can be checked for the corresponding name, but otherwise
if the accessed name if not present and there is at least one wildcard import of
an external package, a black box is created to represent the possibility that
the name is exported by an external wildcard import.

=== Qualified Operand Names

Qualified Operand Names (e.g., `pkg.ExportedBinding`) are considered by the Go
spec @go126spec part of operand name expressions, the latter of which simply
permitting both a qualified and an unqualified form (e.g., `name`). An initial
version of Glowy thus relied on parser-side heuristics to detect qualified
operand names, but this is an unreliable, unsound, and often incorrect solution,
since the parser often does not have enough information to distinguish a
qualified name from a normal struct-like field selection (e.g., `obj.Field`), as
they are syntactically indistinguishable.

For this reason, Glowy currently gives no special handling for qualified operand
names at the parser level, with operand name expressions representing
exclusively unqualified accesses, and all semantic qualified names being
reported by the parser as selections, greatly simplifying parsing throughout the
tree structure. This means that the analyzer is thus responsible for
disambiguating qualified operand name expressions from real selection
expressions based on contextual information, namely depending on whether the
selection base corresponds to a known package qualifier.

In particular, the implementation relies on a special shape denoted Package Ref,
additional to the ones listed in @glowy:primitives:shapes, for the pseudo-values
obtained from accessing a qualifier as if an operand name. Such a shape does not
support any other operations besides selections, which in fact correspond to an
access to a qualified operand name. Package Ref values are thus treated
specially by the selection handling visitor, which redirects evaluation to the
operand name visitor.

=== Unary and Binary Operations

// starting qualification required to exclude receive
In general, unary operations simply relay their inner value's existing label, as
they do not perform any operation capable of modifying taint. For example, the
value associated with expression ```go !x``` has the same label as for `x`.

Binary operations similarly combine their operands' labels, as expected. For
example, the label of ```go x + y``` is equivalent to $L_X inter.sq L_Y$, where
$L_X$ and $L_Y$ are the labels derived for expressions `x` and `y`,
respectively.

For short-circuiting binary operations (i.e., where the operator is either
logical AND, `&&`, or logical OR, `||`), the left operand's evaluated label is
pushed onto the branch label $beta$ during evaluation of the right operand,
since the latter may have side-effects, which would execute conditionally
depending on the left operand's boolean value at run-time. The branch label is
again popped after the right operand's evaluation.

It should be noted that bitwise logic operators, `&` and `|`, do not
short-circuit, per the language specification @go126spec, so no special behavior
is applicable.

=== Branching <glowy:constructs:branching>

For simplicity and to prevent an explosion of memory usage, Glowy does not
handle split control flow regions (such as the different arms of an ```go if```
statement) independently and then union the two results.

Instead, upon mutation, it heuristically determines when to perform strong
updates (overriding) and when to perform weak updates (adding to but not
replacing taint). Concretely, a weak update is always performed unless both:
- the target symbol was declared within the current control-flow split; and
- the assignment type is simple (e.g., ```go x = 2```, rather than
  ```go x += 2``` or ```go x++```, with the latter being considered syntactic
  sugar for ```go x = x + 1```).

Such a policy is sound, but it may also be overconservative in some rare cases,
as illustrated by @bg:taint:flow-sensitivity:weak in @bg:taint:flow-sensitivity,
since it does not detect situations where a tainted variable is set to the same
untainted value in all branches (wherein the targeted outer variable should have
its taint downgraded, but Glowy cannot prove this and so conservatively leaves
it tainted).

When branching on a condition, its calculated label is always pushed to the
branch label $beta$ until the end of the construct. For instance, the body of an
```go else if``` is subject to the branch label of all the conditions above it,
not just its own, since that condition is only evaluated when the others fail.

=== Loops <glowy:constructs:loops>

The different kinds of loops rely on the branch label $beta$ to enclose
expressions and statements that would only be executed depending on another
value, per the general branching procedure laid out in
@glowy:procedure:context:branch and the prior @glowy:constructs:branching. For
instance, a for-clause's "post" statement is only executed if the condition
expression evaluates to ```go true``` at least once, so a dependency
relationship is formed. Another notable case is, evidently, that the loop body
is always tainted by the condition or loop expression that causes a number of
iterations directly observable from the body.

Go does not specify map iteration order and explicitly allows entries created
during iteration to be observed by subsequent iterations. For analysis
soundness, the loop variables' taint must therefore reflect any mutations that
the body performs on the ranged collection.

The implementation models this by visiting the body more than once within a
single analysis pass, as part of an internal convergence loop, analogously to
the broader Stage \2 stabilization procedure; the first visits are speculative
and execute with global error suppression enabled, using loop variables that
already account for everything the previous visits revealed.

Loop termination relies on the lattice of possible labels being finite-height
and growing monotonically across visits, since assignments only ever union new
tags into existing values. Once a visit produces no new taint on the range
expression, the next visit's bindings match the previous one and convergence has
been reached.

Special handling is given for the case where for-range-declaration loop bodies
contain closures that capture the range variable, as in
@glowy:constructs:loops:per-iter, wherein the escaped value must reflect only
the current iteration (not a merge).

#figure(
  ```go
  for _, x := range xs {
    fs = append(fs, func() int { return x })
  }
  ```,
  caption: [Example capturing of loop per-iteration declaration],
) <glowy:constructs:loops:per-iter>

Moreover, if the range expression corresponds to an iterable function, taint is
propagated both from the function to the loop (via `yield`) as well as from the
loop to the function, through `yield`'s return value, which can be used by
conditional ```go break``` statements to convey information to the function.

#pagebreak()

@glowy:constructs:loops:yield illustrates how this is possible, with primary
flow of $"blue"$ (from the underlying array) and $"red"$ (from the function's
logic, via branch label), as well as feedback via `stopped` from the loop body
back to the function.

#codly(highlighted-lines: (3, 5, 6, 18))
#figure(
  ```go
  func main() {
    x := 0
    for value := range selectedValues {
      x += value
      if private { break }
      if high { break }
    }
    // glowy::assert::{blue, red}
    fmt.Println(x)
    // glowy::assert::{blue, red, private, high}
    fmt.Println(stopped)
  }

  var arr = [...]int{1, blue, 5, 4}
  var stopped = false
  func selectedValues(yield func(int) bool) {
    for _, value := range arr {
      if should(value) && !yield(value) {
        stopped = true
        // glowy::assert::{blue, red, private, high}
        fmt.Println(0)
        return
      }
    }
  }

  func should(n int) bool {
    return n%red == 0
  }
  ```,
  caption: [Example snippet with two-way range function tainting],
) <glowy:constructs:loops:yield>

The highlighted lines show the propagation points between the two parts of the
program, with `yield` being synthetized by the language as glue.

#pagebreak()

=== Value Matching <glowy:constructs:switch-expr>

Go supports ```go switch``` statements matching on an expression's value. Since
clause ordering matters and each clause is implicitly affected not only by its
own condition, but also all the ones prior, all pushed branch labels are kept
until the end of the construct.

This means that ```go fallthrough``` statements can be largely ignored, as their
semantics are effectively always applied, for the purposes of this work.

The ```go default``` clause, if it exists, is only processed after all others
(even if textually it appears first in source-order) and is subject to all other
branch labels, reflecting the prescribed execution behavior in Go.

=== Type Matching

A similar logic to the one described in @glowy:constructs:switch-expr is applied
to switch-type statements, but this case affords greater simplicity, as each
clause is guarded by a type (which is not a value and thus cannot be tainted),
so the only relevant branch label is the one derived from the expression being
matched.

=== Type Assertions

Type assertions produce either one or two values, depending on where they are
used; for example, `y := x.(T)` panics if `x` is `nil` or not of type `T`,
while `y, ok := x.(T)` instead identifies whether the assertion succeeded.

Such expressions are thus considered to yield an Expandable value, with primary
corresponding to the inner operand (with the same taint, but a different
declared type as tracked by the internal materialized value representation), and
a single secondary set to that same inner value but downgraded to a Simple
shape (i.e., losing type-specific precision but keeping the same taint).

=== Type Conversions

Since conversions cannot modify their underlying inner operand's taint, that
same value is considered as the conversion result, in the same way as in type
assertions, described in the previous subsection.

It should be noted, in particular, that the branch label $beta$ is not
applied even if this is an observable value change, since it is instead applied
if or when the result is ever committed, per @glowy:procedure:context:branch.

#pagebreak()

=== Type Instantiations

While Go does not define type instantiations as a separate kind of expression,
the present work takes it as such, since it functionally behaves as one for the
purposes of the analysis being performed, and it requires some form of
syntactic representation in the @ast. This is illustrated by the example in
@glowy:constructs:type-inst:as-expr, which assigns an instantiated function to
a variable before invoking it from that new name.

#figure(
  ```go
  func sum[T ~int | ~float64](x, y T) T {
   return x + y
  }

  inst := sum[int]
  fmt.Println(inst(2, 3)) // 5
  // fmt.Println(inst(3.4, 2.1)) // would not compile
  fmt.Println(sum(3.4, 2.1)) // 4.4
  ```,
  caption: [Example expression-like usage of a type instantiation],
) <glowy:constructs:type-inst:as-expr>

For the purposes of taint analysis, Glowy considers the operation's result to be
equivalent to its operand.

=== Channels

Channels are one of the most important constructs in idiomatic Go programming,
so they are afforded particular support for optimal precision, even if actual
concurrency happens-before and synchronization ordering is not modeled by this
work, as stated in @methods:subset.

Channels are modeled by their specialized value shape of the same name, which is
essentially characterized by a set of aggregate label backtraces. In particular,
each Channel value stores one or more allocations, each representing a channel
identity and being possibly shared with other Channel values, as well as one
additional unbound aggregate structure used to model identity-free information
or effects awaiting binding to concrete allocations.

Multiple allocations are stored because control-flow merges of Channel values
may produce multiple potential channel identities; while only one of them
actually chosen at run-time, static analysis must conservatively assume any of
them is applicable, so all allocations must be kept.

Each allocation corresponds to an aggregate structure and a known allocation
site (i.e., a source-code location). Aggregate structures, in turn, comprise
core backtraces (or their absence) required to model channel operations
precisely. These correspond to:
- *Payload:* aggregate backtrace of values sent into the channel;
- *Delivery:* taint dependency of whether the channel was `close`'d;
- *Occupancy:* taint dependency of the number of queued elements; and
- *Capacity:* taint dependency of the channel's immutable buffer capacity.

This means that different channel operations are only tainted by their
applicable backtraces; for instance ```go cap(ch)``` depends on the declared
buffer size, not on the aggregate taint of the values sent to the channel.

In cases where multiple aggregate structures are possible, especially when
a Channel value contains references to multiple allocations as a result of
control-flow merges and weak updates, each of them is queried independently and
their individual precise backtraces are then conservatively merged.

Receiving from a channel, sending to a channel, or closing a channel are all
externally observable, so they are considered commit operations and thus apply
the currently active branch label $beta$.

=== Communication Selections

Select statements take multiple channel-targeting communication operations and
select one of them to proceed, choosing randomly according to a uniform
distribution if multiple cases happen to be ready.

All communication case operands are evaluated once at the beginning of
processing, and then all targeted channels' calculated delivery backtrace is
combined so that it can be pushed onto the branch label $beta$. It is worth
highlighting that channel contents (payload) do not contribute to this taint, as
such elements do not determine whether a communication may proceed.

This means that each case's body is considered to depend on every communication,
since information may be inferred from a case always being selected instead of
others, even if the choice is randomized if multiple cases are ready.

No special handling takes place for a ```go default``` case, since it requires
the same joint-dependency already implemented for all other arms.

#pagebreak()

=== Functions and Methods

Functions constitute perhaps the most extensive part of the implementation, as
they interact with a great deal of mechanisms and must consider many different
edge cases and functionality. They are represented by a value shape of the same
name, which tracks a significant amount of associated state.

Methods are treated by this work as a special flavor of functions, despite being
entirely different concepts in formal Go. Concretely, all functions are
considered to have an optional receiver, the presence of which means that they
are a method. This allows significant code reuse and more logically-segregated
processing pipelines, even if at times complemented by specialized handling for
method-only functionality, such as described in @glowy:constructs:selection.

For simplicity, in this work the term "parameter" is taken to mean each of a
function's input slots for concrete arguments, unlike the standard Go
terminology which is based on parameter declarations. For instance, a function
with signature ```go func(a, b int, c string)``` is here considered to have 3
distinct parameters (even if the first two coincidentally have the same type),
rather than just 2 parameters (with the first one defining two names).

Additionally, whenever type declarations are found during analysis, a Function
value with the same name is registered to the Symbol Table $Sigma$ to emulate a
type constructor for that type, as functions' native blackboxing means that
the returned value's taint will be approximated to the input taint, matching the
desired semantics for type constructors.

==== Synthetics and Realization <glowy:constructs:functions:synthetics>

Function analysis is supported primarily by _synthetic label tags,_ which
correspond to internal artifacts designed to aid with separating function
definition from invocations, so that call-site sensitivity can be supported
(@bg:taint:call-site-sensitivity).

These tags are never visible outside the implementation, representing a special
placeholder for when a label is not fully known, which the analyzer synthetizes
to proceed with the necessary taint propagation until a concrete label is known
to match that placeholder.

Synthetics can later be _realized_ into concrete labels, a process consisting of
the translation of applicable synthetic tags into concrete ones. This is a
powerful mechanism enabling the deferring of source information while still
proceeding with the underlying taint analysis, generalizing workload so that
analysis does not repeat equivalent steps.

It is important to highlight that synthetic label tags are always associated
with a particular function, since they represent a placeholder specific to that
function. This may be a named, declared function (identified by its name,
pinned to a specific source code file), or an anonymous function literal
(identified solely by its source code location).

Moreover, each synthetic tag is associated with a particular placeholder slot:
- Parameter $\#i$: represents the taint of the function argument passed at
  (zero-indexed) position $\#i$ during a particular invocation;
- Receiver: represents the taint of a method's receiver;
- Capture $\#i$: represents the taint of the $i$#super[th] captured outer symbol
  (which may change between capturing and function invocation, as mutations may
  occur between those two points and are observable from the capture);
- Call Site Branch: represents the taint of the implicit branch label $beta$ at
  a particular invocation; and
- Yield Feedback: represents the taint of loop exit operations that cause a
  `yield` function to return `false`, as described in @glowy:constructs:loops.

Synthetic tags are used extensively across function logic. Notably, during
function definition, synthetic Symbols are injected for each of the function's
inputs (e.g., parameters and receiver), so that at return statements taint
already expresses precise dependencies on particular inputs. Often known as
function summaries, return statements update the Function value at the top of
the function stack $Phi$ (@glowy:procedure:context:functions) to track
_outcomes_, i.e., calculated taint for each return value, usually expressed
partially or fully with synthetic tags.

Upon function call, its registered outcome is retrieved and realized according
to that invocation's specific call-site context. For example, a synthetic tag
serving as a placeholder for the first argument is translated in all outcome
labels into the actual label held by the concrete argument being passed.

A great deal of care and special handling is essential to ensure that synthetic
tags never escape their respective function, otherwise they will never be
subject to realization and may reach the analyzer's public interface. Glowy's
implementation prefers to panic and abort execution if such a bug is detected
at the relevant abstraction boundary, since it necessarily means a correctness
fault and thus compromises any analysis results.

#v(1fr)
#highlight[more]

#pagebreak()

==== Captures

Go anonymous function literals are _closures,_ meaning that they may capture
outer Symbols and share them with the enclosing scope, as already explained in
more detail in @bg:go:overview:closures.

Glowy models such a relationship by injecting a synthetic local Symbol in the
closure's scope, holding a synthetic tag that serves as a placeholder to the
outer Symbol's taint. Such placeholder is then realized upon function call,
depending on the captured variable's current, up-to-date taint.

In order to support capture mutations from within closures, each capture binding
state internal to the function also tracks a mutation backtrace (potentially
with synthetics dependent on function inputs), which is realized and applied
during a write-backs stage of function application during calls.

Furthermore, captures are a general mechanism that is not just restricted to
closures. Since there is no difference in handling between function literals and
named functions, this enables the implementations to re-use the captures
pipeline to also apply to any access to global variables, even from declared
top-level functions (as technically globals are, functionally, captured by the
declared function).

=== Built-In Function Calls

Predeclared functions are special language constructs and have a specific
meaning prescribed by the language itself. They may only be used in call
expressions, and sometimes present behavior not available to normal functions.
For this reason, this work treats them separately when required.

In particular, Glowy defines the following kinds of built-in functions:
- *Type I:* Take a type instead of a value as a parameter, meaning that they are
  fundamentally incompatible with normal function calls at the syntactic level.
  Parsed and handled as special kinds of expressions.
  - Includes `make` and `new`.
- *Type II:* Syntactically equivalent to normal function calls, so no special
  treatment is necessary at the parser level, but once they reach analysis they
  are processed separately rather than through the normal call pipeline.
  - Includes `append`, `copy`, `clear`, `close`, `delete`, `len`, and `cap`.
- *Type III:* The existing blackbox mechanism is sufficient to model their
  functionality, so no special handling whatsoever is performed.
  - Includes `min`, `max`, `print`, `println`, `complex`, `real`, and `imag`.

Type I built-in functions have their own associated @ast node, since their shape
can vary significantly. For instance, `make` supports invocation as
```go make(T)```, ```go make(T, n)```, and ```go make(T, n, m)```.

The built-in `new` takes only one argument, but it may be either a type or an
expression (```go new(T)``` or ```go new(S)```). This cannot always be
distinguished at parse-time, especially for plain names, such as in the case of
```go new(x)```, so when the argument is syntactically ambiguous, the parser
reports the ambiguity (as a variant of @ast `NewArgNode`) and defers to the
analyzer to resolve into either case using contextual information, such as if
`x` is a known type. Cases where the variant is syntactically evident are
nonetheless resolved immediately at the parser level, such as for
```go new(x + 2)``` or ```go new(map[string]int)```.

Type II special handling makes use of the existing precision information when
possible, modeling each return value with the correct associated taint.

=== Composite Values

Composite values such as arrays or structs are modeled with some degree of
precision, providing semi-fine-grained analysis for known-constant keys. This is
supported by a unified apparatus that implements sound, on-demand precision, as
part of the types' respective value shapes.

Composites an overall backtrace affecting the entire structure (denoted `dyn`),
optionally complemented by backtraces known to be present at specific keys
(denoted `const`). When a read or write is performed with a key that can be
resolved to a simple constant value (per @glowy:primitives:consts), the `const`
mapping is used to avoid tainting or being tainted by all of the container's
elements. Otherwise, if a key cannot be resolved to a constant, dynamic reads
conservatively take the aggregate of all elements in `const`, in addition to
`dyn`.

Additional state is also kept, such as aggregate key backtraces and an exact
length when statically known (so that ```go len(x)``` may sometimes be resolved
as a simple constant value).

Struct field selection and indexing both use this unified composite interface to
provide the best possible precision while retaining soundness. Slicing uses it
indirectly, as mentioned in @glowy:constructs:slices.

In some cases, it is not clear at the syntactic level whether an expression
is an indexing or a type instantiation, as both use the form `a[b]`. In such
situations, the ambiguity is marked by the parser with pseudo-expression
@ast `AmbiguousBracketAccessNode` and resolved in the analyzer based on
contextual information, such as whether `b` is a known type. The parser only
commits to indexing or type instantiation when syntactically evident, such as
with ```go arr[i + 2]``` (indexing) or ```go f[chan-> int]``` (type
instantiation).

Similarly, syntactically ambiguous composite literals, such as `T{}`, are
reported by the parser as an unknown composite literal, which is later resolved
by the analyzer into an array, slice, map, or struct literal based on contextual
information for type `T`. If resolution is not possible, they are kept under an
Unknown Composite value shape until usage patterns identify a concrete container
type and the value can be upgraded to a specific shape, retaining all
accumulated precision information.

When visiting unknown composite literals, if they cannot be immediately resolved
to a concrete composite shape based solely on the context available (such as for
types declared in external dependencies), keys are evaluated into simple
constant values with that mechanism's name resolution disabled, because they
might be struct fields and thus unrelated to any Symbol which happens to have
the same name.

=== Slices <glowy:constructs:slices>

Slices are treated differently from the remaining composite types because of
their nature and widespread usage in idiomatic Go, thus warranting more precise
handling, even if still built around the same unified composite structure,
since it uses an underlying Array-shaped value as backing storage.

Multiple such backings are kept, in a similar pattern to allocations in
channels, as control-flow merges can make several backing identities possible.
In addition, slice shapes store an associated access taint, and three slice
bounds corresponding to the slice's start index, end index, and maximum
capacity, as relative to the underlying array. Each such bound is associated
with an individual taint backtrace, as well as a simple constant value when the
corresponding bound is statically known.

This allows for greater precision when manipulating slices, including when
constructing subslices and when iterating over the contained values, but also
for meta-querying operations such as `len`, the resulting taint of which does
not necessarily depend on the contained elements' taint.

Since array backings are shared between slices, revocations are stored at the
Slice shape level to prevent the controls from applying to other slices.

=== Selection Strategies <glowy:constructs:selection>

Selection expressions demand special attention because they are often not
trivial to resolve, especially when the base has no known implementation (i.e.,
is from a foreign package, such as a third-party dependency). In particular, it
is sometimes difficult to distinguish between struct field selections and
method selections, especially since Glowy only tracks lightweight type
information and does not implement a full-fledged type checker.

It is thus necessary to use heuristics, applying different strategies in order,
from most to least sound, until a decision is reached. These strategies are
briefly summarized in the present subsection.

The first such strategy is Typed Dispatch, which is the best case scenario and
(if applicable) is guaranteed to be correct, even cross-package. Essentially,
when the selection base has a known declared type (tracked via the internal
materialized value representation, per @glowy:primitives:shapes), it is used to
look up a method or a struct field by name. It is important to note, however,
that this needs to take into account method and field promotion, as introduced
in @bg:go:overview:structs, so it is still a complicated process.

Otherwise, if Typed Dispatch did not succeed, the subsequent strategy is
Attempted Upgrade, which checks whether it is possible to upgrade the base into
a Struct shape from either a Simple or Unknown Composite shape. This is only
attempted when it is plausible (based on any available precision information)
for the base to be a struct, in addition to there not being any registered
blanket directives which require call resolution (e.g., targets referencing
return values or arguments), with the latter case implying that the selection
result corresponds to a method.

#v(1fr)
#highlight[more]

#pagebreak()

The final possible strategy is Blackbox Softening, which takes a failure of
Attempted Upgrade as an indication that the selection refers to a method. It
thus tests four different criteria and models the selection as a function
black box if any of them hold. These four criteria are:
+ The value is a plausible method if there is any registered blanket directive
  for it in the base's known type (if any).
+ The value is a plausible method if there is any known method implementation
  with the same name anywhere, on any type, across the entire module codebase
  under analysis.
+ The value is a plausible method if the base's known type (if any) is an
  interface, as valid Go cannot select fields from interfaces.
+ The value is a plausible method if the base's known type (if any) has an
  external underlying type, whose method set cannot be known as analysis does
  not include external dependencies.

This last strategy is the least sound, being very broad in accepting what could
be a plausible method, but it is important to note that it is conditional on the
previous two strategies failing, and that the only alternative is guaranteed
unsoundness with a problem report.

If none of the strategies above succeed, a problem is reported for an invalid or
unsupported selection base, as analysis cannot proceed soundly.

=== Generic Type Parameters

Since the analyzer only performs lightweight type tracking, as described in
@glowy:procedure:context:types, type parameters are largely erased and not used
for analysis.

However, they are still tracked in the global Analysis Context $Gamma$ for the
current function whose definition is being processed, so that they are treated
as known type names during processing.

It is also relevant to mention that Go does not allow type parameters in
method declarations, only in real functions.

#v(1fr)
#highlight[more]

#pagebreak()

=== Execution Jumps

Jumps are supported via ```go goto``` statements, bound to the restrictions set
forth by the language. This is implemented in this work at the function level:
if a function body is detected to contain a ```go goto``` statement, special
handling kicks in, relying on an internal convergence loop.

The body is visited repeatedly (speculatively, with problem reporting
suppressed) until the per-label taint state converges, after which a final
authoritative visit is conducted.

At each ```go goto``` statement, the current branch label $beta$ is merged into
the target label's pending state, whereas at each labeled statement the label's
pending security labels are pushed onto $beta$ so that taint may be propagated
from the ```go goto``` to all statements at and after its target.

This supports both forwards and backwards jumps.

=== Deferred Execution

In order to support ```go defer f()``` statements, function call processing is
split into two phases: resolution, where callee and arguments are evaluated, and
application, where actual effects take place, including outcome-based
realization and capture write-backs.

A ```go defer``` statement, when found, therefore immediately executes the first
stage (call resolution) and stores its result in the global Analysis Context
$Gamma$ alongside additional necessary contextual information. At the end of
function definitions, any registered deferred calls are taken from $Gamma$ in
reverse order and applied.

#v(1fr)
#highlight[more]

#pagebreak()

=== Early Abort

An important kind of implicit flow is one that uses early abort operations to
divert control flow in some particular situations. The program in
@glowy:constructs:early-abort:break below showcases how information might be
propagated using this pattern.

#codly(highlighted-lines: (9,))
#figure(
  ```go
  package main
  import "fmt"
  // glowy::label::{private}
  const private = true
  func main() {
    result := 0
    for {
      if private {
        break
      }
      result = 1
      break
    }
    // glowy::assert::{private}
    fmt.Println(result)
  }
  ```,
  caption: [Example implicit flow from conditional ```go break```],
) <glowy:constructs:early-abort:break>

The highlighted line affects control flow while under the influence of branch
label $beta = {"private"}$, but in ordinary circumstances $beta$ would be popped
after line 10 when the respective ```go if``` statement terminates, meaning that
the assignment to `result` on line 11 would not be tainted.

In order to counteract this, Glowy implements _deferred branch labels,_ which
cause a branch label to remain active during longer than it otherwise would.
This mechanism is used by ```go return```, ```go continue```, and ```go break```
statements, since all three abort the current execution flow.

Return statements always defer the current branch label $beta$ until the end of
the current function, while ```go continue``` and ```go break``` defer until the
end of the enclosing context identified by the provided label, or the innermost
one if no label is specified. Whereas ```go continue``` only affects loops,
```go break``` may also target ```go switch``` and ```go select``` statements,
so the closest innermost construct may differ between the two.

=== Deferred Enforcement Checks

When a policy enforcement check is found (i.e., a sink or an assertion), an
attempt is immediately made to apply its associated enforcement procedure,
reporting a problem if so warranted.

However, since functions use synthetic tags throughout their bodies, as
explained in @glowy:constructs:functions:synthetics, it is common for synthetics
to be present in the label under appraisal, which might make it impossible to
soundly perform the enforcement check. For example, it is not clear whether a
deny-sink with inherent label $cal(L)_"Sink" = {"yellow"}$ ought to accept or
reject a value tainted with security label $L = {"red", "<sum:$RECEIVER>"}$,
since at this point it is not known whether or not the synthetic tag will be
realized into a label containing $"yellow"$. It is thus necessary, in those
cases, to defer enforcing the check's invariant until more information is known.

Deferred checks are included in their enclosing function's summary so that they
may be re-attempted at each invocation, after realization. If even then there is
not enough information (e.g., in the case of nested function literals), the
check is again deferred, but into the invoker's function summary. This process
repeats until a higher level is reached whereupon all relevant synthetic tags
have been realized, allowing the check to proceed.

Even if deferred, policy enforcement checks always report any potential insecure
flows or other problems at the original file location; the function triggering
the check is merely a logistical facilitator, and its details are not recorded,
since a snapshot of the original site is already kept.

Nevertheless, it is not always necessary to defer enforcement, even in the
presence of synthetics. For sinks alone, a violation demonstrated by a
partially-synthetic label's concrete part can never be removed, so it is
reported immediately. Concretely, after a value has its label restricted to only
concrete tags, if it is rejected by an allow-sink, then its label already has a
concrete tag not permitted by the whitelist, whereas if it is rejected by a
deny-sink, then its label analogously already has a concrete tag present in the
blacklist.

This means that sinks can often be eargly evaluated, even with synthetics.
Assertions, however, test exact equality and must thus only be triggered when
the final label is known.

=== Build Constraints <glowy:construct:build-constraints>

Build-tag constraints are parsed from ```go //go:build``` directives at the top
of source-code files, representing conditions for file inclusion, as introduced
in @bg:go:overview:build-constraints. If no such directive is present, Glowy
additionally supports parsing legacy ```go // +build``` constraints, as it is
still prevalent among real-world projects. Moreover, well-formed filename
suffixes may also set restrictions at the @os (`GOOS`) or architectural
(`GOARCH`) level.

One of the first tasks performed during analysis preparation is the enumeration
of build constraint permutations. This consists of collecting all mentioned
build tags across all registered files' constraint expressions and calculating
all possible permutations that need to be analyzer.

The first step involves separating all mentioned tags into four groups: ordinary
tags (i.e., user-defined, with no special meaning), `GOOS`-selection,
`GOARCH`-selection, and compiler selection. A preliminary calculation is then
performed based on these dimensions in order to ensure that the enumeration
itself would not exceed a reasonable limit; without this, enumeration could
plausibly take significantly longer than analysis, even to the point of taking
years, given that growth is exponential with dimensions. This preliminary
calculation corresponds to the number of different worlds that must be
considered, as given by

$
  W = 2^(\#"Ordinary") & times (\#"GOOS" + 1) \
                       & times (\#"GOARCH" + 1) \
                       & times (\#"Compiler" + 1)
$

If this number exceeds the set limit of $2^20$, analysis is not performed and an
error is returned due to too many enumerable build worlds. The special handling
for the three latter groups in the expression stems from the fact that each of
them is mutually exclusive; for example, a world satisfying both `linux` and
`windows` does not make sense. The $+1$ factor represents the case where none of
the specified tags in that category is satisfied, which is necessary, for
instance, for projects which only have special `windows` files and all others
are applicable for all @os:pl.

Assuming that the number of enumerable worlds does not exceed the stated limit,
enumeration proceeds by considering each possible world under the set of
mentioned build tags and calculating the set of files that would be admitted
under the constraints that that particular world satisfies.

Admitted file sets are deduplicated, since in some cases different worlds
satisfy the same expressions, especially those using OR operators `||`. This
means that the enumeration result is a set of sets of admitted files, each of
them corresponding to a specific build permutation that must be considered
independently under analysis. Each set thus becomes $TT_cal(P)$ as defined in
@glowy:design:workflow, which is also the input for the analysis procedure in
@glowy:procedure.

If the final number of permutations exceeds the configured limit of maximum
build permutations, however, analysis is not performed and an error is reportd.
This limit defaults to $256$ permutations but is configured programmatically
and through the project's `glowy.toml` configuration file.

Otherwise, if there is more than one permutation to analyze and Cargo feature
`parallelism` is not manually disabled, the implementation attempts to analyze
multiple permutations at once, as they are fully independent.

Glowy defaults to processing, at most, $\#"Cores" - 2$ permutations at once,
leaving two processing cores to not overwhelm the system, but always at minimum
$2$, since otherwise it does not make sense to pay the parallelism overhead
penalty for a single parallel thread. This number can nevertheless be reduced
further through the `GLOWY_MAX_THREADS` environment variable.

This work therefore conducts taint analysis on all possible execution paths,
even across build configurations, so as to not promote a false sense of security
for stakeholders less familiar with the implementation's assumptions.

#v(1fr)
#highlight[more]
#v(1fr)

#pagebreak()

== Base Security Policy <glowy:base-policy>

Glowy's Base Security Policy is intended as a generic security control
configuration providing sensible defaults applicable to most arbitrary Go
programs. It is primarily destined for facilitating simple project onboarding
before manual human-led adjustment to the project's specific requirements.

It is implemented as an internal drop-in @toml file that may be ejected as-is
into a `glowy.toml` configuration file at the module's root directory via the
`glowy-cli base-security-policy --eject` command. As such, it (somewhat
counterintuitively) specifies the configuration option
`inherit_base_policy = false`, since if its contents are used as a user-editable
template, the real Base Security Policy should not inferfere.

Besides `inherit_base_policy`, the only configuration it provides is respective
to blanket security controls. Blanket directives for sources, revocations, and
deny-sinks are included.

No allow-sink blanket directives are present in the Base Security Policy because
whitelists are most useful for domain-specific trust boundaries. For example,
it might make sense for some project to define that the value returned from a
`/profile` @http @api endpoint ought to be targeted by an allow-sink of label
$cal(L)_"Profile" = {underline("user") thin : thin "bio", thick
  underline("user") thin : thin "full-name", thick underline("user") thin : thin
  "phone-number"}$, deriving significant security value from such control, but
it is not possible for a generic base policy to make such judgements about any
particular cases since, as stated, they are inherently domain-specific.

The Base Security Policy uses only label tags bound to the two conventional axes
with well-known prefix shorthands, $underline("secret")$ (shorthand `$`) and
$underline("untrusted")$ (shorthand `?`). Sources specify labels with a single
tag bound to one of those axes, named succintly to convey the general category
of information provenance, whereas (deny-)sinks use the wildcard notation
introduced in @glowy:controls to blacklist either of the aforementioned axes
entirely.

This allows for appropriate generic behavior while still showing useful context
in potential reported problems and empowering stakeholders to complement the
base policy with project-specific decisions. For example, a project still
relying on the Base Security Policy may define new source directives using
custom tags in one of the two canonical axes and benefit from the existing
sink directives for free, or it might define other unrelated tags in different
(or no) axes, without affecting the existing controls' behavior.

@glowy:base-policy:summary below shows a summary of the different groups of
blanket sources and sinks defined in Glowy's Base Security Policy, as well as
subtotal counts per target property and directive kind, followed by a grand
total.

#let directives = (
  (
    name: "Source",
    description: "Roots for taint propagation",
    properties: (
      (
        name: "Conf.",
        groups: (
          (
            label: [${\$"env"}$],
            description: "Environment-derived credentials",
            amount: 47,
          ),
          (
            label: [${\$"http"}$],
            description: "Inbound request credentials",
            amount: 5,
          ),
        ),
      ),
      (
        name: "Int.",
        groups: (
          (
            label: [${?"http"}$],
            description: [Inbound `net/http` request data],
            amount: 20,
          ),
          (
            label: [${?"http"}$],
            description: "Popular web-framework request accessors",
            amount: 36,
          ),
        ),
      ),
    ),
  ),
  (
    name: "Deny-Sink",
    description: "Blacklist-based enforcement checks",
    properties: (
      (
        name: "Conf.",
        groups: (
          (
            label: [${\$*}$],
            description: [`stdout` and standard loggers],
            amount: 26,
          ),
          (
            label: [${\$*}$],
            description: "Popular structured logging",
            amount: 66,
          ),
          (
            label: [${\$*}$],
            description: [@http responses],
            amount: 17,
          ),
        ),
      ),
      (
        name: "Int.",
        groups: (
          (
            label: [${?*}$],
            description: [@sql injection (raw query strings)],
            amount: 66,
          ),
          (
            label: [${?*}$],
            description: [Command injection \ (process execution)],
            amount: 5,
          ),
          (
            label: [${?*}$],
            description: "Path traversal (filesystem paths)",
            amount: 27,
          ),
          (
            label: [${?*}$],
            description: [@ssrf (outbound request targets)],
            amount: 16,
          ),
          (
            label: [${?*}$],
            description: [Open redirect \ (@http redirection)],
            amount: 5,
          ),
          (
            label: [${?*}$],
            description: [Template injetion \ (escaping bypass)],
            amount: 9,
          ),
        ),
      ),
    ),
  ),
)

#let cells = (
  directives
    .map(directive => (
      directive
        .properties
        .map(property => (
          property
            .groups
            .map(group => (
              directive.name,
              property.name,
              group.label,
              group.description,
              group.amount,
            ))
            .flatten()
            + (
              strong(directive.name),
              strong(property.name),
              table.cell(colspan: 2, repeat(sym.dot)),
              strong[#{ property.groups.fold(0, (sum, g) => sum + g.amount) }],
            )
            + (table.hline(stroke: gray + 0.5pt),),
        ))
        .flatten()
        + (
          strong(directive.name),
          table.cell(colspan: 3, repeat(sym.dot)),
          strong[#{
            directive
              .properties
              .map(p => p.groups.fold(0, (sum, g) => sum + g.amount))
              .fold(0, (sum, amount) => sum + amount)
          }],
        )
        + (table.hline(stroke: gray + 0.5pt),),
    ))
    .flatten()
    + (table.hline(stroke: 1pt + black),)
    + (
      table.cell(colspan: 4, strong[TOTAL]),
      strong[#{
        directives
          .map(d => d
            .properties
            .map(p => p.groups.fold(0, (sum, g) => sum + g.amount))
            .fold(0, (sum, amount) => sum + amount))
          .fold(0, (sum, amount) => sum + amount)
      }],
    )
).map(cell => [#cell])

#figure(
  table(
    columns: (auto, auto, auto, 1fr, auto),
    align: horizon,

    table.header(
      strong[Directive],
      strong[Prop.],
      strong[Label],
      strong[Description],
      strong[Amt.],
    ),

    ..cells,
  ),
  caption: [Summary of Base Security Policy source/sink directives],
) <glowy:base-policy:summary>

The extreme shorthands ${\$*$} and ${?*}$ are used above merely for table layout
convenience, but the policy itself uses sink labels
${underline("secret") thin : thin *}$ and
${underline("untrusted") thin : thin *}$ for greater clarity.

#pagebreak()

Excluded from the summary provided by @glowy:base-policy:summary are only the
blanket revocation directives reproduced in @glowy:base-policy:revocations.

#figure(
  ```toml
  "builtin.len" = ["$env"]
  "operator.eq#*=" = ["$env"]
  "operator.neq#*=" = ["$env"]
  ```,
  caption: [Base Security Policy blanket revocation directives],
) <glowy:base-policy:revocations>

The first directive revokes label ${underline("secret") thin : thin "env"}$
from the result of the `len` predeclared function. This is included in the
Base Security Policy to counteract the rigidness set forth by the policy's
source directives focused on environment variables, since it is a common pattern
in Go to write code such as the one in @glowy:base-policy:revoke-len.

#figure(
  ```go
  val := os.Getenv("API_TOKEN")
  if len(val) == 0 { return; }
  ```,
  caption: [Example abort based on environment variable length],
) <glowy:base-policy:revoke-len>

Without the `len` revocation, the entire program would be tainted by the
```go return``` statement, based on the propagated branch label.

For analogous reasons, the second and third revocations in
@glowy:base-policy:revocations register an exception for when a tainted
environment variable is compared to the empty string (```go ""```), respectively
for equality and inequality.

The three referenced blanket revocation directives handle only hyper-focused
cases in order to offset other policy directives that would otherwise be too
strict.

No broader revocations are defined since their scope is not appropriate for a
widely-applicable base policy. It does not make sense, for example, to revoke
${?"http"}$ for common @http escaping utilities, since all sanitizers are
necessarily context-specific and thus a simple `<` to `&gt;` transformation does
not make untrusted input any safer to use, e.g., in a literal @sql query.
Revocations are thus domain-specific controls and depend on each project's
particular usage, as well as more specialized labeling per use-case.

Overall, Glowy's Base Security Policy attempts to strike a delicate balance
between completeness and applicability. It is based on heuristics and designed
to be replaced, but it still defines useful blanket controls applicable for
most Go real-world projects that make use of each directive target.

#pagebreak()

== Summary

In short, Glowy is primarily composed of a core analysis Rust library, a
separate Rust utility for parsing Go files into @ast:pl, and a user-facing @cli
application that reports problems detected during analysis using intuitive and
clear diagnostics.

The analysis procedure itself is divided into three stages. Stage \#1 processes
and registers all top-level declarations, since they may be referenced from
anywhere, while Stage \#2 repeatedly performs taint analysis passes
(without error reporting) until all security labels stabilize, and Stage \#3
runs a final taint analysis pass to collect errors based on the calculated
stable labels.

Within each taint analysis pass, a tree of visitor implementations provides
specialized handling for all supported constructs and language functionalities.
References to bindings without known declarations and invocations of functions
and methods without known implementations are approximated as black boxes.

Security controls, namely sources, revocations, allow-sinks, deny-sinks, and
assertions, may be configured through directives in source-code annotations,
programmatically, or through a `glowy.toml` file in the root directory of the
module under analysis.

An ejectable Base Security Policy ships with the analyzer, providing blanket
directives intended to act as sensible defaults for onboarding new projects. It
is nevertheless extremely generic and based on heuristics, so it should be
replaced by stakeholder-defined project-specific configuration in order to
maximize the value extracted from analyzing a codebase with Glowy.
