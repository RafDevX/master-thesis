#import "../utils/dependencies.typ": codly

#import codly: codly

= Background <bg>

This degree project comprises contributions to a very particular area of the
Information Security field, therefore it is necessary to present a number of
technical concepts and generally contextualize the work before further
developing on the advances made.

As such, this chapter introduces essential background aspects and terminology,
as well as existing related work, as part of a comprehensive literature review
on the state-of-the-art within this area.

== Information Classification

An important problem within Cybersecurity is how to systematically isolate what
is trusted or secret from untrusted or public information (respectively),
especially in terms of what information should be accessible or used where. This
aligns primarily with the high-level aspects of _confidentiality_ and
_integrity_ of the @cia triad and has widespread implications for how security
vulnerabilities might manifest in software products.

This often involves assigning labels to each piece of information, describing
its level of sensitivity as one or more namespaces, such as
${"Secret", "Nuclear"}$. These labels are organized as a security lattice, with
an ordering relation being partially defined between compatible labels based on
the mathematical subset operation applied to each label's set of namespaces,
where:

#columns(2)[
  - $L_1 < L_2 <==> L_1 subset L_2$
  - $L_1 <= L_2 <==> L_1 L_2$

  #colbreak()

  - $L_1 > L_2 <==> L_1 supset L_2$
  - $L_1 >= L_2 <==> L_1 L_2$
]

This means that, for example, ${"X"} < {"X", "Y"}$ and ${"A"} >= {"A"}$, as
expected. Importantly, however, no ordering relation is defined if there is no
subset relation between two labels. For example, ${"X"}$ and ${"Y"}$ are
independent and neither is greater or lesser than the other: both
${"X"} {"Y"}$ and ${"X"} {"Y"}$. These partially-ordered
information labels allow expressing security rules.

#pagebreak()

The actual labels used in any particular system are usually domain-specific,
depending on the concrete application of the program in question. However, the
empty label ${}$ with no namespaces is often referred to as *Bottom* (denoted
$bot$), as it constitutes the lower boundary of the security lattice and is
thus always lesser than any other label, i.e.,
$forall n, quad L_n bot ==> L_n > bot$.

Furthermore, the terms *high* and *low* are often used in the context of
confidentiality to mean secret and public data (respectively), with information
that is low being classified Bottom and any non-Bottom label indicating
information considered to be high @cecchetti2017nonmalleable.
// if need more: "This standard terminology allows reasoning ..."

Enforcement-wise, theoretical models already exist and have been shown to be
mathematically robust, such as the @mls techniques initially proposed by Bell
and LaPadula in 1973 @belllapadula1973mls and then later further developed by
#cite(<denning1976lattice>, form: "prose"), among other works. Put simply, @mls
is usually centered around categorization of information into labels, the
discretization of each principal's authority as corresponding labels, and the
following core properties (for confidentiality, but analogous for integrity):
- *No read up:* principals cannot access information at a higher classification
  level than their own authority/clearance; and
- *No write down:* principals cannot write information to a lower classification
  level than their own authority, as to prevent downstream leakage.

However, it would be useful to enforce these assurances on arbitrary programs
without relying on them to implement one of these mechanisms correctly, since
such a zero-trust approach would allow principals to independently verify
whether programs are secure (from this perspective) and equip developers with
the necessary tooling to find vulnerabilities in their own projects. In this
light, it thus makes sense to seek methods to validate invariants _ex post
facto,_ as an alternative to rigid implementation constraints.

== Information Flow Control

A chief way to verify software security with respect to confidentiality and
integrity is to employ *Information Flow Control (@ifc:short),* which is the
class of mechanisms used to track how information propagates through a program's
possible execution code paths in order to determine if the information in
question is used securely @hedinsabelfeld2012perspective.

This applies analogously to both confidentiality and integrity guarantees, with
the former being traditionally and intuitively associated with _accessing_
information, while the latter is tied to performing _writes_ and _updates_. In
this work, focus is primarily put on confidentiality, therefore examples and
textual descriptions refer to it for the most part unless otherwise stated.
Nevertheless, identical or reversed logic often applies for integrity, and this
is sometimes highlighted where appropriate.

On the other hand, @ifc does not have so strong a bond with availability, the
third and final component of the @cia triad, as that quality is generally more
linked with program robustness (e.g., memory safety) and the surrounding
infrastructure building and executing the program.

Nevertheless, availability is sometimes indirectly affected by integrity, as
certain erroneous or unexpected data updates can lead to corruption or escape
from assumptions and invariants, which in turn can easily cause denial of
service. In this sense, @ifc is effective against a subset of availability
faults, but only insofar as the intersection with the field of integrity.

In any case, @ifc is profoundly related with studying the relationships between
a program's inputs and its outputs. Many inputs tend to be noteworthy in some
way, either because they comprise secrets (such as @api:short tokens) or because
they are attacker-controlled (such as @http form fields), and most outputs are
either attacker-visible (such as a @cli application's writes to `stdout`) or
critical parts (such as database entries), with the latter case often becoming
inputs to other programs. It is therefore vital and a relevant measure of
security to track if and how these inputs flow into outputs over the course of
the program's lifetime, across all possible execution paths.

Tracking flows between inputs and outputs can detect certain kinds of security
problems, as insecure programs may allow attackers to derive information about
secret inputs just from measuring observable outputs (confidentiality fault),
or allow attackers to compromise correctness by providing specially crafted
values as user-facing inputs that are not validated nor sanitized (integrity
fault).

#v(1fr)
#highlight[ideally add more paragraphs here to fill page]
#v(1fr)

#pagebreak()

=== Observable Flows

It is possible for several different kinds of flows to exist between a program's
inputs and outputs, all of which must be kept in mind for @ifc to ensure
soundness and security for the program in question. These can take place in
isolation, but most often they are found chained together with intermediate
flows, collectively forming one overarching composite flow.

==== Explicit Flows

Explicit flows are the simplest and most obvious sources of security
vulnerabilities within this class, as they represent the direct propagation of
information. For example, take the following excerpt of some Go program:

#codly(highlighted-lines: (2,))
#figure(
  ```go
  secret := 7
  output = secret + 4
  ```,
  caption: [Example of an explicit flow via variable assignment],
) <bg:ifc:flows:explicit:example>

In the snippet above, line 2 showcases a clear breach that would allow an
attacker to fully derive the exact value of `secret` just from the value of
`output`, as they would simply have to reverse the transformation applied. In
this case, it follows trivially from the source code that
$"secret" = "output" - 4$.

==== Implicit Flows

On the other hand, implicit flows are more subtle, as they propagate information
based on contextual details, especially based on conditional operations that
only execute for certain code paths. For example:

#codly(highlighted-lines: (4,))
#figure(
  ```go
  isEven := false

  if secret % 2 == 0 {
    isEven = true
  }
  ```,
  caption: [Example of an implicit flow via conditional assignment],
) <bg:ifc:flows:implicit:example>

Line 4 of the above Go snippet is a simple assignment that binds a constant
value (`true`) to `isEven`, but though it may seem an innocuous operation at
first, it still represents a security problem because of what implicit
information can be inferred from its execution: an attacker can observe `isEven`
and determine that `secret` is an even number if the former's value is `true`,
as that is the only possible reason for the highlighted assignment to have
occurred.

#pagebreak()

The case where `secret` is odd is more challenging to detect, as no operations
in its respective execution branch are problematic, but it is nevertheless still
insecure, since the absence of change can still reveal information. It thus
becomes necessary to check all possible execution paths in order to safely
identify all potential implicit flows within a program.

In general, implicit flows make use of the program's control structure,
conditional behavior, and implementation invariants to indirectly influence
operations. This propagates information in ways that are less obvious and more
difficult to notice, but can still have consequences and effects measurable
and/or exploitable by attackers.

Formally, the difference between implicit and explicit flows is defined by
#cite(<denningdenning1977certification>, form: "prose") as whether the
operation being performed depends or does not depend (respectively) on the value
of some additional piece of information being tracked, such as a secret
input. For example, a context-free direct assignment is independent of any value
besides the value being assigned, so it is considered an explicit flow, as shown
in @bg:ifc:flows:explicit:example. Conversely, contextual assignments within a
branch of a conditional depend on the value of the condition, so the example in
@bg:ifc:flows:implicit:example is an implicit flow.

==== Other Covert Channels <bg:ifc:covert>

In addition to explicit and implicit flows, there are other possible means to
propagate information, particularly when it comes to information leakage and
confidentiality breaches. Concretely,
#cite(<sabelfeldmyers2003lang>, form: "prose") define the following additional
kinds of *covert channels:*

- #underline[Termination channels]: programs can leak one bit of information by
  whether or not they ever terminate their execution (boolean value);
- #underline[Timing channels]: one or more bits of information (depending on
  granularity) can be leaked by the measurable time elapsed during execution of
  specific tasks or the entire program runtime;
- #underline[Probabilistic channels]: programs can adjust the probability
  distribution of attacker-visible output data to encode information leakage;
- #underline[Resource exhaustion channels]: information can be leaked through
  programs signaling through deliberate exhaustion of finite resources
  observable externally by attackers, such as memory consumption, disk space,
  as well as processing power usage or relative spikes; and
- #underline[Power channels]: programs can deliberately perform expensive
  calculations to leak information through host computer power usage patterns.

Each of these poses real security threats that can be exploitable with some
degree of difficulty, especially by dedicated attackers, but this degree project
considers them out of scope due to simplicity and time constraints. This means
that they are not considered as part of the attacker model in question.

In the future, this work could be extended to take into account some of these
alternative covert channels to propagate information, but this would be
difficult in many regards, especially without compromising usability. For
instance, for termination channels, it is well known that the halting problem is
undecidable in the general case @turing1936computable, which means that attempts
at detection would likely rely on heavily restricting the available language
constructs, which would in turn impact what is possible for programs to do.

However, even if not directly in scope, some of these channels become much
harder (or even virtually impossible) to effectively exploit given the
restrictions enforced by this work. For example, probabilistic leakage
necessarily modulates the output based on secret values, which should in most
cases be detected by the @ifc techniques employed within the scope of this
project.

Finally, it is worth noting that #cite(<sabelfeldmyers2003lang>, form: "author")
consider even implicit flows to be covert channels and thus part of the category
under description here, but this work explicitly opts to distinguish implicit
flows from the rest due their importance and first-class focus in this degree
project.

=== Non-Interference

When discussing @ifc and formalizing its application in Information Security,
the property of *non-interference* is often of the highest relevance, used as a
cornerstone or starting point for many proposed models in the field. In essence,
a program exhibits non-interference if its high inputs have no influence on its
low outputs @goguenmesseguer1982noninterference, meaning that all
attacker-visible information is completely independent of any secret data.

This concept is built on the premise that all programs can be described as
functions mapping a sequence of inputs into a sequence of outputs
@mclean1990noninterference, with both the former and the latter each being
reducible to a memory configuration $M$ with projections $M_L$ and $M_H$ to its
low and high parts (respectively). For convenience, the relations $scripts(=)_L$
and $scripts(=)_H$ are defined as equality between memory configurations with
respect solely to their low or high parts:

$ forall X in {L, H}, quad M scripts(=)_X M' <==> M_X = M'_X $

#pagebreak()

This notation allows reframing non-interference more precisely. Given some
arbitrary program $p$, it is said to be non-interfering if and only if:

$
  forall M_1, M_2, quad
  M_1 scripts(=)_L M_2 quad and quad p(M_1) scripts(=)_L p(M_2)
$

However, despite being theoretically appealing, non-interference is generally
considered to be too strict for normal employment and thus not so useful as a
measure of security. Completely and unreservedly forbidding high inputs from
ever influencing low outputs in any way is an ideal and does not reflect the
full extent of what is expected for standard information systems to perform. For
instance, an authentication system should reject login attempts when a provided
password is incorrect, but this is not possible under non-interference, as it
implies different behavior (acceptance or rejection) dependent on a high input
(the correct password for the authenticating user).

Even if in some cases there are alternate solutions that can be made compliant
with non-interference, that is not always possible. In the example above, making
use of hash comparison to check passwords is non-interfering if the correct hash
is considered public (which it normally would not be, to prevent offline brute
force attacks), but in more complex cases there are insurmountable obstacles to
achieving non-interference, such as if a statistics program is intended to
publicize the average and mean of a numerical dataset while keeping the
underlying sensitive data secret. The outputted statistical results necessarily
depend on information that is by definition private, so they would never be
allowed under strict non-interference.

This work takes a simple approach to solve the problem described above,
essentially allowing developers the flexibility to explicitly opt-out of the
general non-interference condition at specific points of the program,
respecting *declassification* as an escape catch for handling trade-offs that
cannot be decided mathematically. This is a pragmatic solution that equips
stakeholders with a tool to adjust their security policies to their respective
realities, on a case-by-case basis, and according to each project's risk
acceptance level.

For example, a developer with sufficient trust in their hash function's
irreversibility can explicitly mark it so that @ifc trace enforcement mechanisms
do not consider that it propagates information from the original input, tagging
it as a sanitizer that expressly breaks data flows from input to output.

Moreover, this practice of explicit declassification forces codebases to have a
roster of several crucial-yet-small areas of code that need to be reviewed more
carefully but are clearly identified and can easily be found if the need arises,
simplifying auditing even for large codebases. It prioritizes usability and
customizability over rigidness, but highlights potentially unsafe decisions so
that their justifications can be noticed and reviewed often.

On the other hand, it is worth noting that a common point of criticism against
non-interference as a useful security measure is its poor modeling of
non-determinism. Programs are assumed to be describable as functions of input
memory configurations, which implies that they are considered to be fully
deterministic and their output is based solely on their input
@mclean1990noninterference, but in reality this is not always the case, as other
external factors can influence some programs, such as probabilistic seeds, or
processor scheduling patterns in multithreaded applications. Allowing
declassification still does not solve this problem, but the attacks referred to
in this paragraph are considered out of scope as they fall under the category of
other covert channels for information propagation, described in @bg:ifc:covert.

#pagebreak()

// raf
// - read fully @cecchetti2017nonmalleable
// - come up with a better word than downgrade for declassification+endorsement
// - use that word in this section and explicitly explain endorsement

== Enforcement Mechanisms for @ifc:short

// Original title: Enforcement Mechanisms & Paradigms

... several different paradigms ...

many different ways

important to reduce friction on developing secure software

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

Go#footnote(link("https://go.dev/"))

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

== Past Incidents

this would fix, specifically in go, ...
@cve20208563kubernetes @cve20208564kubernetes @cve20208565kubernetes
@cve20208566kubernetes @cve20257445kubernetes

also CVE-2024-6104, CVE-2026-27900 - really anything in CWE 532 prolly

try to find integrity examples

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
