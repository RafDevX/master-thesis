= Background

chapter overview

== Information Flow Control

what is ifc

=== Observable Flows

things to keep in mind for ifc to ensure soundness

==== Explicit Flows

secret := 7
output = secret + 4

==== Implicit Flows

isEven := false
if secret % 2 == 0: isEven = true

the case where secret is odd is trickier to detect but is still insecure because
the absence of change can still reveal information. need to check all possible
execution paths of the program, which is not practical at runtime, hence static
analysis

==== Other Covert Channels <bg:ifc:covert>

see sabelfeld ii.c

besides implicit flows, \@sabelfeld defines:
- termination channels: explain
- timing channels: explain
- probabilistic channels: explain
- resource exhaustion channels: explain
- power channels: explain

how to mention these without outright copying / plagiarizing?

are all of them really out of scope?

--

as stated in @intro:limitations, for simplicity these are not supported by this
work (hard e.g. halting problem), but could be extended to support some or all
of them

=== Non-Interference

explain property

nice in theory, but in practice often not desirable, too strict, e.g. incorrect
password alert when logging in. there should be flexibility to opt-out at
specific points (escape catch) -- declassification

this means that through explicit declassification we force creating a roster of
several "important"-yet-small areas of code that need to be reviewed more
carefully and can easily be found if the need arises, simplifying auditing even
for large codebases

== Enforcement Mechanisms for IFC

TODO: use acronym above ^^ (or Enforcement Mechanisms & Paradigms)

many different ways

=== Security Type System

security-oriented typing would be cool, like having a Token type that can only
reveal its inner string through explicit operations that make declassification
or sanitization very clear; see sabelfeld refs 2-14

can be achieved through either a separate orthogonal security type system, or
just by making deliberate use of the language's standard typing and visibility
rules (e.g., secret data is marked private and made mechanically inaccessible
via language-level features, and then controlled explicit access points are made
public/accessible to other parts of the program)

this means that the compiler enforces information flow policies when it type
checks, resulting in almost no additional overheard. however, it's unrealistic
to expect all developers to start having these design considerations and do
everything correctly

=== Dynamic Analysis

runtime checks, can become inefficient for program execution (creates a
substancial "drag"), and very bad feedback loop for developers and auditors
since errors will only be reported for code paths that have actually been
activated, meaning a lot of effort needs to be put into ensuring all potential
code paths are run, e.g. for a testing loop

=== Static Analysis

our lord and savior

usually either source code or binary, we look at source code because it's more
readily available, it gives all the necessary contextual information, and we
make sure we see everything there is to see (binaries compiled for different
platforms will look different)

running static analysis on the source code yields a much higher degree of
confidence since the entire code was checked (including all paths, regardless of
how frequently they actually run and how obscure they may seem) and has exactly
0 impact on runtime

different ways to do it, important concepts, etc: vvv

==== Taint Analysis

...

sources and sinks

declassification

==== Flow Sensitivity

...

==== Call-Site Sensitivity

...

==== Context Sensitivity

...


== The Go Programming Language

what is go

created by google in 2007

systems language but not just, etc.

=== Prevalence

high-profile projects:
- docker: containers tool, used by % of people
- kubernetes: orchestration, used by % of people
- rclone: files, used by % of people

show go usage statistics, e.g. from stackoverflow survey, including "want to use
in the future"

=== Language Overview

#box(fill: orange)[don't know how detailed this should be, diogo did 5 pages but
  he can affort to focus only on very specific things, it's not reasonable for me
  to go as deep for all the possible language features]

some constructs relevant to point out

==== Goroutines

...

==== Channels

...

== Previous Work

previously co-authored a very simple prototype, this work extends it

here referred to as Glowy-Alpha

almost entirely rewritten (only approx % lines written by diogo remain in the
current version)

== Related Work

number of tools already available within the go ecosystem

further comparison with this work's contributions is developed in
\@some-discussion-section

=== Go Flow Levee

...

=== Gosec

...

=== CodeQL

...

=== Goiaba

...

// maybe also go-pointer, whatever that is?

== Summary

...
