#import "../utils/dependencies.typ": codly, zero

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
  - $L_1 <= L_2 <==> L_1 subset.eq L_2$

  #colbreak()

  - $L_1 > L_2 <==> L_1 supset L_2$
  - $L_1 >= L_2 <==> L_1 supset.eq L_2$
]

This means that, for example, ${"X"} < {"X", "Y"}$ and ${"A"} >= {"A"}$, as
expected. Importantly, however, no ordering relation is defined if there is no
subset relation between two labels. For example, ${"X"}$ and ${"Y"}$ are
independent and neither is greater or lesser than the other: both
${"X"} lt.eq.not {"Y"}$ and ${"X"} gt.eq.not {"Y"}$. These
partially-ordered information labels allow expressing security rules.

#pagebreak()

The actual labels used in any particular system are usually domain-specific,
depending on the concrete application of the program in question. However, the
empty label ${}$ with no namespaces is often referred to as *Bottom* (denoted
$bot$), as it constitutes the lower boundary of the security lattice and is
thus always lesser than any other label, i.e.,
$forall n, quad L_n != bot ==> L_n > bot$.

Furthermore, the terms *high* and *low* are often used in the context of
confidentiality to mean secret and public data (respectively), with information
that is low being classified Bottom and any non-Bottom label typically
indicating information considered to be high @cecchetti2017nonmalleable. This
standard terminology allows reasoning about security properties more
succinctly.

In addition, classification-focused security lattices usually define the union
and intersection operations, $union.sq$ and $inter.sq$ respectively, as
corresponding to the set union ($union$) and intersection ($inter$) between two
labels' underlying namespace sets. In particular, this means that, for every
label $L$, it is always true that $L union.sq L = L inter.sq L = L$, while
$L union.sq bot = L$ and $L inter.sq bot = bot$.

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

#pagebreak()

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

In any case, @ifc techniques are commonly qualified in terms of *soundness* and
*precision* (or completeness). The former property means that all insecure
flows are rejected (i.e., no false negatives), while the latter means that
all rejected flows are insecure (i.e., no false positives).

In general, @ifc is profoundly related with studying the relationships between
a program's inputs and its outputs. Many inputs tend to be noteworthy in some
way, either because they comprise secrets (such as @api:short tokens) or because
they are attacker-controlled (such as @http form fields), and most outputs are
either attacker-visible (such as a @cli application's writes to `stdout`) or
critical parts (such as database entries), with the latter case often becoming
inputs to other programs. It is therefore vital and a relevant measure of
security to track if and how these inputs flow into outputs over the course of
the program's lifetime, across all possible execution paths.

#pagebreak()

Tracking flows between inputs and outputs can detect certain kinds of security
problems, as insecure programs may allow attackers to derive information about
secret inputs just from measuring observable outputs *(confidentiality fault),*
or they may allow attackers to compromise correctness by providing specially
crafted values as user-facing inputs that are not validated nor sanitized
*(integrity fault).*

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

==== Implicit Flows <bg:ifc:flows:implicit>

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
value (```go true```) to `isEven`, but though it may seem an innocuous operation
at first, it still represents a security problem because of what implicit
information can be inferred from its execution: an attacker can observe `isEven`
and determine that `secret` is an even number if the former's value is
```go true```, as that is the only possible reason for the highlighted
assignment to have occurred.

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
  specific tasks, or even based on the entire accumulated program runtime;
- #underline[Probabilistic channels]: programs can adjust the probability
  distribution of attacker-visible output datapoints to encode information
  leakage;
- #underline[Resource exhaustion channels]: information can be leaked by means
  of programs signaling through the deliberate exhaustion of finite resources
  observable externally by attackers, such as memory consumption, disk space,
  as well as processing power usage (or relative spikes thereof); and
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

=== Axes and Label Polarity <intro:ifc:axes>

Some @ifc environments define a notion of _label polarity_, where each label
$ell$ is composed of separate confidentiality and integrity aspects. The @flam
@arden2015flam defines projections $ell^(->)$ and $ell^(<-)$ that make these
accessible, respectively, allowing for labels to be normalized as
$ell = p^(->) and q^(<-)$, with $p^(->)$ representing $ell$'s confidentiality
component and $q^(<-)$ its integrity value.

This clear distinction and separation of concerns allows advanced theoretical
models to robustly describe properties based specifically on confidentiality and
integrity, and especially the relationship between them. Nevertheless, such
rigid bindings bring no significant advantages when taking into account this
degree project's limited scope, so this work does not require modeling labels as
the aggregation of two mutually exclusive confidentiality and integrity factors.

Instead, in an endeavor to promote usability and flexibility, this degree
project reasons about labels as comprising a simple set of _tags_ (i.e.,
namespaces), with each tag being optionally bound to an _axis_:

$
  L = {t_1, t_2, ..., t_n}, quad "where" quad t_i = cases(
    italic("name")\, quad & "if plain",
    underline(italic("axis")) thin : thin italic("name")\, quad & "if bound"
  )
$

For example, $L_P = {"secret", "nuclear"}$ is comprised only of plain tags, and
$L_B = {underline("customer") thin : thin "address", thick underline("customer")
  thin : thin "phone-number", thick underline("untrusted") thin : thin "http"}$
has only tags bound to an axis (in this case, the $underline("customer")$ and
$underline("untrusted")$ axes). In addition, plain and bound tags can coexist
within the same label, e.g. as for $L_M = {"john", thick underline("unit") thin
  : thin "accounting"}$.

This (optional) axis-based framing allows both simpler and more complex use
cases than @flam's model would, as stakeholders can choose whether to prefer
simple, plain tags or determine that a certain advanced security requirement
calls for one or more domain-specific orthogonal axes.

In terms of the overarching security lattice and the label ordering it defines,
the same subset-based aforestated relation is still applicable: for instance,

$
  {"alpha", thick underline("dir") thin : "east"}
  < {"alpha", thick "beta", thick
    underline("dir") thin : thin "north", thick
    underline("dir") thin : thin "east"}
$

as axes extend the discussed label properties easily and intuitively.

For convenience, the operator $underline(L)$ is defined as corresponding to the
set of axes mentioned in label $L$, if any. From the examples above,
$underline(L_P) = {}$, while
$underline(L_B) = {underline("customer"), underline("untrusted")}$ and
$underline(L_M) = {underline("unit")}$.

In addition, the axis-restriction operation $L|_A$ is defined as removing all of
a label $L$'s tags that are bound to any axis not contained in set $A$. For
example, if $A = {underline("dir"), underline("untrusted")}$, then
$L_P|_A = L_P$ (all tags are plain, so all are kept),
$L_B|_A = {underline("untrusted") thin : thin "http"}$, and $L_M|_A = {"john"}$.

#pagebreak()

=== Non-Interference

When discussing @ifc and formalizing its application in Information Security,
the property of *non-interference* is often of the highest relevance, used as a
cornerstone or starting point for many proposed models in the field. In essence,
a program exhibits non-interference if its high inputs have no influence on its
low outputs @goguenmesseguer1982noninterference,
meaning that all attacker-visible information is completely independent of any
secret data @rushby1992noninterference @mantel2025noninterference.

This concept is built on the premise that all programs can be described as
functions mapping a sequence of inputs into a sequence of outputs
@mclean1990noninterference, with both the former and the latter each being
reducible to a memory configuration $M$ with projections $M_L$ and $M_H$ to its
low and high parts (respectively). For convenience, the relations $scripts(=)_L$
and $scripts(=)_H$ are defined as equality between memory configurations with
respect solely to their low or high parts:

$ forall X in {L, H}, quad M scripts(=)_X M' <==> M_X = M'_X $

This notation allows reframing non-interference more precisely. Given some
arbitrary program $p$, it is said to be non-interfering if and only if:

$
  forall M_1, M_2, quad
  M_1 scripts(=)_L M_2 quad ==> quad p(M_1) scripts(=)_L p(M_2)
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
underlying sensitive data secret. The output statistical results necessarily
depend on information that is by definition private, so their publication would
never be allowed under strict non-interference.

In addition, another frequent point of criticism against non-interference as a
useful security measure is its poor modeling of non-determinism. According to
the classical definition, programs are assumed to be describable as mathematical
functions of input memory configurations, which implies that they are considered
to be fully deterministic and their output is based solely on their input
@mclean1990noninterference, but in reality this is not always the case, as other
external factors can influence some programs, such as probabilistic seeds, or
processor scheduling patterns in multithreaded applications.

Extensive work has been conducted in an attempt to solve this, usually involving
the reframing of non-interference as a hyperproperty
@clarksonschneider2010hyperproperties, i.e., a property of sets of traces of
execution, capable of capturing differences in output distributions in relation
to known input security characteristics.

However, although this formalization as higher-level and more complex security
conditions is more sound and more precise in the general case, the relevant
attacks necessary to exploit, for instance, probabilistic non-determinism
vulnerabilities are considered out of scope of this degree project as they fall
under the category of other covert channels for information propagation, already
described in @bg:ifc:covert. This means that, for the purpose of this work, it
is sufficient to consider the simplest definition of non-interference, stated
and explained above, even if reliant on determinism.

Lastly, it should be pointed out that non-interference is usually expressed in
much more general terms. For example,
#cite(<goguenmesseguer1982noninterference>, form: "prose")
originally put it as "one group of users, using a certain set of commands, is
noninterfering with another group of users if what the first group does with
those commands has no effect on what the second (...) can see", and
#cite(<rushby1992noninterference>, form: "prose") words it "a security domain
$u$ is noninterfering with domain $v$ if no action performed by $u$ can
influence subsequent output seen by $v$"). However, in the context of this
project, it is equivalent to collapse such domain/user/process-centric
formulations into the simpler concrete versions stated above, based on the
relationship between high and low inputs and outputs.

#pagebreak()

=== Explicit Revocation <intro:ifc:revocation>

This work takes a common approach to bypass the foregoing problem of
non-interference being too strict for real-world usage, essentially allowing
developers the flexibility to explicitly opt-out of the general non-interference
condition at specific points of the program, respecting *revocation overrides*
as an escape hatch for handling trade-offs that cannot be decided
mathematically. This is a pragmatic solution that equips stakeholders with a
tool to adjust their security policies to their respective realities, on a
case-by-case basis, and according to each project's risk acceptance level.

For example, a developer with sufficient trust in their hash function's
irreversibility can explicitly mark it so that @ifc trace enforcement mechanisms
do not consider that it propagates information from the original input, tagging
it as a sanitizer that expressly breaks data flows from input to output.

In recent research, this concept is often referred to as _downgrading_
@cecchetti2017nonmalleable @rushby1992noninterference, which is a general name
encompassing _declassification_ and _endorsement_. These are two very similar
operations, but they hold separate semantics, as the former relates specifically
to confidentiality and the latter to integrity.

This distinction is particularly relevant in environments based on strict label
polarity with labels composed of separate confidentiality and integrity
components, such as @flam @arden2015flam as described in @intro:ifc:axes.

In particular, #cite(<cecchetti2017nonmalleable>, form: "prose") build upon
@flam (and label polarity in general) to introduce _@nmifc,_ an alternative
security condition to non-interference that allows for _robust declassification_
and _transparent endorsement_, placing asymmetric restrictions on these
downgrading operations so that they only take place when it is sound for them to
do so. This is accomplished through the reliance on the duality between
confidentiality and integrity, by only allowing the declassification of values
of sufficient integrity and by permitting only the endorsement of values which
are sufficiently public.

Nevertheless, these notions are largely only necessary because they model
secure downgrading at the language level and between decentralized parties,
since they try to solve problems within inter-party protocols and assume
differing levels of trust between components. The guarantees that @nmifc offers
are beyond the scope of this degree project, since this work's attacker model
assumes that explicit manual overrides (configured and specified directly by the
developer, maintainer, or security auditor, through code annotations or
otherwise) are trusted and should, by definition, be respected.

It is also a goal of this project to strive for simplicity so as to maximize
usability even by stakeholders who are not security experts, so this work does
not keep track of, require, or support strict two-fold label polarity in any
way: all labels are defined equally and flow equally, with arbitrary
user-defined axes serving just as an optional convenience for advanced use cases
and there being no special treatment for axes that end up being coincidentally
confidentiality/integrity-adjacent (nor the attacker model setting forth any
inherent requirement for any such axes, or any axes at all, to even exist within
a project's defined security policy).

This means that it is not possible (nor desired) to apply the checks mandated by
@nmifc for robust declassification and transparent endorsement, as well as that
those two downgrading operations are functionally equivalent in semantics and
behavior, given the lack of polarity. As such, this work contemplates explicit
revocation as its single, unified form of label downgrading.

Revocation of $L_R$ from $L$ is defined as the set difference between them, that
is, $L' = L \\ L_R$, even if it would not otherwise be sound to forget $L_R$
from $L$, assuming $L$ is a value's accumulated label over the course of a
program's execution path. This mechanism allows stakeholders to make informed,
risk-aware decisions and manually override the rigid requirements that would
otherwise be enforced by purely mathematical @ifc principles.

Moreover, this practice of explicit revocation forces codebases to keep a
roster of several crucial-yet-small areas of code that need to be reviewed more
carefully but are clearly identified and can easily be found if the need arises,
simplifying auditing even for large codebases. It prioritizes usability and
flexibility over rigidness, but highlights potentially unsafe decisions so
that their justifications can be noticed and reviewed often.

#pagebreak()

== Enforcement Mechanisms for @ifc:short

// Original title: Enforcement Mechanisms & Paradigms

There are several different paradigms regarding possible kinds of techniques
that can be employed, in practice, for enforcing @ifc:long and its related
conditions and security measures. Evidently, each have their own inherent
advantages and disadvantages, so it is consequential to select the most
appropriate one for each situation, as it is a significant factor in the extent
to which it is possible to reduce friction on developing, maintaining, and
evaluating secure software.

The three most common mechanisms for @ifc enforcement are security type systems,
dynamic analysis, and static analysis.

=== Security Type Systems <intro:enforcement:types>

Security-oriented typing encodes security policies and invariants directly into
a program's source code and stated control flow, embedding security decisions
into the overarching development cycle and commonly taking advantage of language
features to achieve the desired guarantees.

This can be accomplished either through a separate security-specific type
system that is orthogonal to the language's standard typing rules, or it can be
achieved simply by making deliberate use of the language's existing standard
typing and visibility rules in order to indirectly produce the same effect.

In the former case, this often requires development using a security-oriented
language designed expressly with this purpose in mind, with numerous such
languages having been prototyped or released over the past few decades
@palsbergorbek1995trust @smithvolpano1998multithreaded @heintzeriecke1998slam
@banerjee2002javalike, some of them as (breaking) extensions to existing
languages @myers1999jflow @myersliskov2000jif @pottiersimonet2003ml. While these
are robust and usually proven sound, stakeholders often prefer to use widespread
programming languages for their development tasks, or they have a legacy
codebase already bound to some existing language without specific security
typing guarantees.

Conversely, in the latter case, stakeholders have freedom to elect development
in whichever programming language they prefer, provided that it has support for
basic functionality allowing for the manual definition of type wrappers with
secure access/manipulation interfaces. For example, one may declare an
`ApiToken` type that makes its inner string mechanically inaccessible via
language-level features (such as a `private` visibility-modifying keyword) and
only exposes some select, controlled, explicit access points to other parts of
the program, forcing security label downgrading to be made clear and very
explicit when it is necessary. However, this is highly dependent on programmer
discipline, and is naturally prone to human error.

In either case, some form of type-based security has the compelling advantage of
being automatically enforced by the language's native compiler/interpreter,
which by design guarantees a program's compliance with the desired information
flow policy as part of its type-checking step, leading to little additional
overhead. This results in strong enforcement probative value, as the very fact
that the program compiles/runs showcases success.

In spite of that, however, it is unrealistic to expect all developers to always
keep these design considerations in mind and always implement them correctly, or
otherwise restrict themselves only to languages that are capable of providing
strong and sound security guarantees, which means that only the most determined
will tend to use security type systems in real-world projects, making this
solution less robust for the present reality.

=== Dynamic Analysis

Dynamic @ifc enforcement involves performing runtime checks to verify in real
time whether information flows adhere to the configured security policy. This is
often accomplished through the injection of a dynamic security monitor capable
of mediating all information transfers and assessing their legitimacy, comparing
each value under appraisal against what is defined to be an acceptable
information flow.

This is a very flexible and precise strategy, as execution time is exactly when
all relevant information is known about all values in question, especially for
languages with weak or dynamic typing, as well as programs which rely heavily on
functionalities such as dynamic dispatching or reflection. In many cases, it is
simply impossible to predict a program's behavior and assess its security
without context that is only available when the program is running.

However, dynamic analysis can become inefficient for program execution, as it
creates a substantial drag impacting overall performance. Firstly, intercepting
and checking all relevant flows necessarily leads to increased execution time,
especially if affecting frequent operations. Secondly, injecting enforcement
checks implies a larger binary size or requires a custom interpreter, affecting
distribution. Finally, tracking and recording provenance information for all
values (typically by remembering each value's associated security label) entails
more memory usage. Overall, this represents a significant aggregate cost for
dynamic analysis, notwithstanding its unrivaled precision.

Furthermore, and perhaps more crucially, dynamic analysis provides weaker
security guarantees than other @ifc enforcement strategies, since it can only
ever detect issues for execution branches that actually take place. This means
that insecure flows may remain unreported indefinitely simply because they would
only be activated by less common code paths (such as an implausible, yet valid,
attacker-manufactured situation). This is dangerous because a lack of signaling
can offer stakeholders a false sense of security, even if real issues and
vulnerabilities are still present.

Concretely, this means that considerable effort must be put into ensuring all
potential code paths are run, such as by requiring full test coverage (not just
in terms of lines of code, but also taking into account the entire input
possibility space). Without confidence in execution path coverage, dynamic
analysis cannot support a strong feedback loop for developers and auditors, as
errors will only be reported for some portion of all possibilities.

On the other hand, dynamic monitoring, unlike other @ifc enforcement strategies,
offers sufficient flexibility to allow its application at varied levels of
abstraction, since it not only supports simple program-centric controls
@stefan2011lio @yang2012jeeves, but also enforcement at the system level, such
as in the scope of an Operating System ensuring inter-process security
@enck2014taintdroid, or even at the level of the processor's instruction-set
architecture @vachharajani2004rifle.

Dynamic @ifc tracking and enforcement can be software-based, as described above,
but it might also be hardware-based, or even hardware-assisted.
#cite(<chen2021dynamic>, form: "prose") compare the three approaches and
conclude that each presents a different trade-off between flexibility,
performance, and deployment cost. According to the survey's authors, the first
case allows for the most flexibility and makes it simple to modify the security
policy, besides being more scalable and not relying on niche hardware support,
but it has the strong drawback of very high runtime overhead. The second case
has lower overhead and can be transparent to the software layer (except for
interruptions generated in case of detected security breach), but it is
difficult to deploy on commercial systems, entails a high hardware manufacturing
cost, and offers very limited flexibility after production, besides the evident
scalability issues. The third case comprises a good balance between flexibility
and performance, allowing for more fine-grained and configurable security
policies with less overhead than the software-only model, but it can prove
challenging to design and requires delicate coordination between hardware and
software tracking, as well as a custom execution environment.

Finally, as a consequence of its runtime nature, detected illegal information
flows can only be reported during program execution, in which case it must
reject the flow and abort either the current task or the entire program
execution, since it would not be semantically sound to proceed blindly without
applying the flow in question. This means that dynamic enforcement must
necessarily compromise availability in favor of confidentiality or integrity,
even in high-stakes production contexts where uptime is essential.

In general, dynamic analysis brings indisputable benefits in precision and
flexibility when compared to other enforcement paradigms, but this comes at a
heavy cost in terms of performance, resource consumption, need for specialized
equipment, and/or confidence in the reported results.

=== Static Analysis

The remaining major category for @ifc enforcement paradigms is static analysis,
through which a program's information flows are assessed against security
policies ahead of time, rather than during execution. This means that purely
static analysis has a zero-cost impact on runtime performance.

This is usually accomplished through either the examination of a program's
original source code or through the scrutiny of its compiled binary.

On one hand, the latter case is necessarily more sound, in the perfect case, as
it appraises the instructions that will actually be executed
@balakrishnan2010wysinwyx, and thus precludes malicious compiler attacks
@thompson1984trusting as well as compiler-introduced security bugs usually
stemming from well-intentioned optimizations that end up affecting observable
behavior @xu2023cisb.

On the other hand, the former case also brings strong advantages, as source
code analysis is supported by much more detailed contextual information, such as
clear function boundaries, high-level control structures, language-specific
abstractions, exact variable scopes, and datatype definitions. This allows not
only for more useful and targeted diagnostics, but also for more rich and
precise flow tracking across the different layers of the program under
inspection. Static analysis of a program's executable binary, in contrast, is
typically affected by register reuse, loss of symbolic information, and
nontrivial identification of sources and sinks based on raw memory locations.
Implicit flows are especially difficult to track soundly without source code
access, as conditions and effects are sometimes merged together by compiler
optimizations and instructions are organized to privilege branchless arithmetic
that presents equivalent behavior but is less granular in flow.

Given this reasoning, while binary file analysis has legitimate uses for some
very specific use cases, source code analysis tends to be, in general, much more
convenient to use, maintain, and rely on. It makes it simpler to define clear
security policies based on meaningful abstractions rather than memory addresses,
and its higher degree of context allows more focused decision-making, which in
turn permits more precise tracking of information flows.

In spite of this, all static analysis is inevitably less precise (in most cases)
than dynamic analysis, as some context is only known during the program's
execution. This means that, in order to preserve soundness, the analyzer must be
conservative and always assume the worst case scenario for any given situation
unless it can statically prove that a given possibility cannot be true, which
translates into a higher false positive rate than other paradigms. There exist
scenarios in which static analysis is more precise than dynamic analysis,
especially if relying on a "no-sensitive-upgrade" rule that automatically
rejects high assignments to low variables even if they would later be
overwritten @russosabelfeld2010vs, but for most ordinary programs dynamic
analysis tends to prevail, with static analysis relying more on conservative
choices.

However, this reduced precision and the conservativeness required to counteract
it mean that conducting static analysis on a program yields a very high degree
of confidence that the entire codebase was scrutinized, including all possible
code paths, regardless of how frequently they actually run or how obscure they
may seem, all with zero impact on program execution.

Moreover, unlike dynamic analysis, detected security violations are reported
when actually relevant and convenient, rather than during runtime in the form of
a crash or task poisoning#footnote[Some dynamic monitors may surface violations
  in logs without blocking the underlying flow, but that comes at the cost of
  knowingly permitting insecure operations, and in that case the logged
  violations should arguably be addressed just as urgently as if the task had
  been aborted (or even more so), so the point set forth by this paragraph still
  stands.]. This allows potential vulnerabilities to be addressed with the
highest quality fix, in time and when appropriate, even before shipping a new
release, as opposed to, e.g., having developers scramble to apply the fastest
possible fix in order to restore service availability.

Finally, it ought to be noted that security type systems
(@intro:enforcement:types) could be considered under some definitions to be
included in the category of static analysis, but this work distinguishes the two
paradigms based on whether the concrete mechanism is enforced by the language
(or otherwise as part of the normal build pipeline), especially if an existing
compiler essentially accumulates security verification functions in addition to
its standard task of compilation from source code into a target executable
format. For the purposes of this degree project, static analysis is understood
to involve some parallel or complementary examination separate to normal
compilation.

In summary, static analysis is in most cases less precise than its dynamic
counterpart, sometimes relying on conservativeness and overapproximations to
guarantee soundness, but it allows for better usability, more robustness, and
higher confidence, all at zero-cost for program execution.

For the foregoing reasons, and taking into account the trade-off between the
advantages and disadvantages it entails, static analysis of source code
is the @ifc enforcement strategy employed within the scope of the present work.

== Taint Analysis

Within @ifc enforcement, a common technique for tracking information flows is
*taint analysis,* which models symbols and values as being _tainted_ by certain
security labels and traces how that taint flows over the course of the program
under study @livshitslam2005taint.

As a prelude, it is worth noting that taint analysis is a general method that
can be applied in several different ways, including in combination with dynamic
analysis, but the present section focuses on taint analysis when implemented as
part of static code analysis, since that latter paradigm is the one elected for
use by the present degree project.

Taint analysis defines three chief components of interest as part of its
security model. Firstly, *sources* are flow starting points, where data becomes
tainted by a given label; for example, accessing an `API_TOKEN` environment
variable input might constitute a source for label ${"secret"}$. Secondly,
*sinks* are designated security-sensitive operations which enforce a given
security policy; for instance, sending a telemetry beacon might be defined as a
sink that rejects all data with label ${"secret"}$. Finally, the principal part
modeled by taint analysis is the *taint propagation* between values throughout
the course of the program, such as in assignments or function calls.

Putting it all together, taint analysis tracks information flows by tainting
certain values at sources, spreading that taint to other values if they depend
(directly or indirectly) on values that flow from marked sources, and enforcing
a security policy at sink boundaries, when tainted values reach a sensitive
operation that defines conditions for valid flows.

These controls and their applicability constitute the core configuration for an
analyzer employing taint analysis, thus representing the primary interface for
interaction with such a tool. In this work, a specific composition of controls
is denoted a *security policy* and used as input for taint analysis.

=== Security Controls <bg:taint:controls>

This degree project defines the following controls as available to be used in a
security policy:
- *Sources,* assigning labels to values;
- *Revocations,* subtracting labels from values;
- *Allow-Sinks,* enforcing a label tag whitelist (after axis restriction);
- *Deny-Sinks,* enforcing a label tag blacklist; and
- *Assertions,* requiring an exact label match.

Sources follow the simple and intuitive semantics already described above,
adding the specified label tags to a value's existing label. If value has label
$L$ before reaching a configured source with label $cal(L)_"Source"$, then it
is modeled as having label $L' = L union.sq cal(L)_"Source"$.

Revocations have the opposite effect, such that $L' = L \\ cal(L)_"Revocation"$.
These have the semantics already defined in @intro:ifc:revocation and are meant
as an exceptional escape hatch for intentionally overriding taint analysis, such
as in sanitizers. Revocations are unsafe by nature, but represent calculated
and informed manual risk acceptance. Nevertheless, it should be stressed that
revocation uses subtraction rather than full overriding (i.e.,
$L' != cal(L)_"Revocation"$) to force stakeholders to be exhaustively aware
about which tags are being removed. For the same reason, it is redundant for
$cal(L)_"Revocation"$ to ever be $bot$.

Sinks require values passed to them to obey certain constraints. For convenience
and flexibility, two distinct kinds of sinks are defined, representing
near-opposite semantics. In principle, all instances of each kind could be
rewritten as an instance of the other kind, but at the cost of excessive
verbosity, less clear intentions, and more difficult extensibility if more tags
are added to the security lattice modeling the domain, so this work explicitly
differentiates them in an attempt to promote simplicity.

Allow-sinks use whitelist semantics to restrict which tags are permitted in a
value's label; for instance, an allow-sink with label
$cal(L)_"Sink" = {"red", "blue"}$ accepts flows of values tainted with label
$L_alpha = {"red"}$ or $L_beta = {"red", "blue"}$, but not of values tainted
with label $L_gamma = {"green"}$ nor $L_delta = {"red", "blue", "green"}$.
These examples demonstrate an equivalence between whitelist-checking and the
security lattice's native label ordering; i.e., $L <= cal(L)_"Sink"$.

However, allow-sinks have an additional important nuance: before performing the
stated comparison, value labels are restricted to only the axes mentioned in the
sink's inherent label (though plain tags, not bound to any axis, are always
kept). For example, if
$cal(L)_"Sink" = {"purple", thick underline("dir") thin : thin "north"}$, then
the sink accepts $L_epsilon = {"purple"}$ and
$L_zeta = {underline("dir") thin : thin "north"}$, but it also accepts
$L_eta = {"purple", thick underline("unit") thin : thin "accounting"}$,
given that $L_eta$ restricted to axis $underline("dir")$ is just ${"purple"}$,
and ${"purple"} <= {"purple", thick underline("dir") thin : thin "north"}$.

Formally, this means that an allow-sink with label $cal(L)_"Sink"$ accepts a
value tainted with label $L$ if and only if $L|_A <= cal(L)_"Sink"$, where
$A = underline(cal(L)_"Sink")$, as defined in @intro:ifc:axes. Any value tainted
with a label that does not meet this condition is rejected by the allow-sink in
question, signifying an illegal flow.

This behavior, while somewhat convoluted, promotes predictable and intuitive
evaluation of plain tags while still allowing for very powerful patterns when
using axes in advanced use cases. It encourages sink definitions to be clear and
intentional about their associated constraints without depending on complete
knowledge of all other orthogonal axes, keeping controls more extensible, since
adding a new axis to the security policy does not require updating all existing
whitelists to ignore it.

Deny-sinks, as the complementing mechanism, are much simpler but equally
powerful, enforcing a blacklist of label tags by rejecting any label containing
any of the tags in its associated label, without performing any prior axis
restriction. Formally, this means that a deny-sink with label $cal(L)_"Sink"$
accepts a value tainted with label $L$ if and only if
$L inter.sq cal(L)_"Sink" = bot$.

Both kinds of sinks always accept Bottom labels, since, for any $cal(L)_"Sink"$,
it is always true that $bot <= cal(L)_"Sink"$ (and for any $A$, $bot|_A = bot$),
for allow-sinks, as well as that $bot inter.sq cal(L)_"Sink" = bot$, for
deny-sinks.

Finally, assertions are similar to sinks (and often treated equivalently), but
are here defined specifically for traceability, testing, and debugging.
Assertions are thus not intended to be used in real analysis, and are often
omitted in explanations and examples, since sinks are the designated first-class
checks. Given an assertion with label $cal(L)_"Assertion"$, any flow to it by a
value with label $L$ is only considered legal if $L = cal(L)_"Assertion"$; exact
equality is required.

Together, sinks and assertions are denoted *policy enforcement checks* in this
work, as they represent the boundaries at which taint is validated when reaching
security-sensitive operations.

#v(1fr)
#highlight[more paragraphs]
#v(1fr)

=== Intraprocedural and Interprocedural Analysis

Taint analysis can be either intraprocedural or interprocedural depending on
whether it examines each function independently or if it follows flows across
function boundaries, respectively. @bg:taint:intra-inter:example below shows an
insecure program that would be (correctly) rejected by an interprocedural
analysis but (incorrectly) accepted by an intraprocedural analysis.

#figure(
  ```go
  var load = func() int { return source() }
  x = load()
  sink(x)
  ```,
  caption: [Example program rejected under interprocedural analysis],
) <bg:taint:intra-inter:example>

Since the taint information crosses a function boundary, intraprocedural
analysis would generally not be able to recognize that `x` should be high, while
interprocedural analysis would recognize the insecure flow, by propagating the
taint through `load`'s return value.

The present work models information according to interprocedural analysis,
relying on function summaries to propagate labels and metadata across function
boundaries.

#pagebreak()

=== Flow Sensitivity <bg:taint:flow-sensitivity>

A flow-sensitive taint analysis respects the order of statements, while a
flow-insensitive analysis models operations as an unordered set of constraints
@hardekopflin2011flowsensitive. For example, @bg:taint:flow-sensitivity:strong
below shows a (secure) program that would be accepted by a flow-sensitive
analysis but not by a flow-insensitive analysis.

#figure(
  ```go
  var x = source()
  x = 0
  sink(x)
  ```,
  caption: [Example program accepted under flow sensitivity],
) <bg:taint:flow-sensitivity:strong>

While `x` is always overwritten with a Bottom-labeled literal and thus does not
hold any taint when reaching the sink, a flow-insensitive taint analysis would
consider that `x` is permanently tainted by its initialization expression on
line 1, and would never permit its label to be downgraded.

Flow sensitivity is characterized by its support of _strong updates,_ where a
mutation can completely overwrite a value's associated label and produce
absolute effects for any subsequent statements.

The present degree project implements taint analysis as partially
flow-sensitive. Simple cases, such as the one on
@bg:taint:flow-sensitivity:strong are correctly accepted, but the model relies
on weak upgrades for any mutations to symbols declared outside of the current
control-flow split. This heuristic is sound in the general case, but can lead to
a loss of precision in some specific cases; @bg:taint:flow-sensitivity:weak
showcases a situation under which flow sensitivity is not observed by this work,
since in both conditional branches `x`'s label is downgraded to Bottom, but that
is not visible at each assignment's level and so `x` remains high even if it
should be low, since it was defined outside the current control-flow split.

#figure(
  ```go
  var x = source()
  if public % 2 == 0 {
    x = 0
  } else {
    x = 1
  }
  sink(x)
  ```,
  caption: [Example program with incorrect weak update],
) <bg:taint:flow-sensitivity:weak>

This kind of situation is relatively rare (conditional upgrade is much more
common) and this work's handling of mutations is always sound, even if at times
less precise, so it is not worth the much more complex modeling of deferred
control-flow split effect merging to better support programs such as the one in
@bg:taint:flow-sensitivity:weak.

=== Call-Site Sensitivity <bg:taint:call-site-sensitivity>

A call-site-sensitive analysis distinguishes function (or method) invocation
contexts by their call sites, while a call-site-insensitive analysis conflates
information from different invocations of the same function. For example,
@bg:taint:call-site-sensitivity:example below shows a (secure) program that
would be accepted by a call-site-sensitive analysis but rejected by a
call-site-insensitive analysis.

#figure(
  ```go
  var identity = func(x int) int { return x }
  sink(identity(source()))
  sink(identity(0))
  ```,
  caption: [Example program accepted under call-site sensitivity],
) <bg:taint:call-site-sensitivity:example>

While the second invocation of `identity` passes a Bottom-labeled literal as
argument to parameter `x` and should therefore result in a
similarly-Bottom-labeled return value, a call-site-insensitive taint analysis
would model `identity` as exhibiting one single static return value, derived
from one single static argument value, corresponding to the (sound) union of
all possible values passed as that particular argument, across all invocations.
This means that both invocations of `identity` would be tainted high due to the
taint passed by the first invocation, even if independent to the second.

This work's taint analysis model is fully call-site-sensitive. When processing a
function definition, all parameters and similar inputs are assigned synthetic
placeholder tags, with the final calculated return values having their labels
dependent on those synthetic tags. At each call-site, the synthetics are
realized (replaced) with the concrete labels of the values passed as arguments
(and other inputs, such as method receivers) for that particular invocation.

The approach above described uses function summaries and corresponds, for the
most part, to a process first introduced by
#cite(<sharirpnueli1981interprocedural>, form: "prose"). Its modeling of
function outputs as dependent on inputs allows for interprocedural
call-site sensitivity.

#pagebreak()

== The Go Programming Language

Go, sometimes referred to as Golang, is a general-purpose programming language
designed primarily for systems programming @go126spec, but employed for a wide
range of applications. It was developed by Google in 2007 @pike2012go but is now
an open-source project, having amassed more than #zero.num(67000) commits on its
Git repository, authored by more than #zero.num(2300) contributors @gorepo.

The language is compiled and statically typed @godocs, relying on strong typing
and garbage collection @go126spec. It has native first-class support for
concurrency and has no type hierarchy, striving to represent orthogonal
concepts fully independently so as to promote clear abstraction composition
@gofaq.

=== Prevalence

Go is used extensively in modern development. Stack Overflow's 2025 Developer
Survey @stackoverflow2025 listed Go as the 13#super[th] most used language
#footnote[Developers were asked "Which programming, scripting, and markup
  languages have you done extensive development work in over the past year
  (...)?"], just after C and PHP. It further reports that, from its
#zero.num(31771) respondents, $23.4%$ of developers wanted to start working in
Go during the following year.

In particular, there are various well-known, widely-used, high-profile projects
implemented in Go, corroborating the language's relevance. For instance, these
include, but are not limited to, the projects in @bg:go:prevalence:high-profile
below.

#figure(
  table(
    columns: (auto, 1fr, auto, auto),

    table.header(
      strong[Name],
      strong[Function],
      strong[Reported Usage @stackoverflow2025],
      strong[GitHub Stars],
    ),

    link("https://github.com/docker")[Docker],
    [Containerization],
    [$71.1%$],
    [---],

    link("https://github.com/kubernetes/kubernetes")[Kubernetes],
    [Orchestration],
    [$28.5%$],
    [$124 thin "k"$],

    link("https://github.com/gohugoio/hugo")[Hugo],
    [Site Generation],
    [---],
    [$90 thin "k"$],

    link("https://github.com/syncthing/syncthing")[Syncthing],
    [File Sync],
    [---],
    [$87 thin "k"$],

    link("https://github.com/caddyserver/caddy")[Caddy],
    [Web Serving],
    [---],
    [$75 thin "k"$],

    link("https://github.com/hashicorp/terraform")[Terraform],
    [Provisioning],
    [$17.8%$],
    [$49 thin "k"$],

    link("https://github.com/prometheus/prometheus")[Prometheus],
    [Monitoring],
    [$11.8%$],
    [$66 thin "k"$],

    link("https://github.com/traefik/traefik")[Traefik],
    [Proxying],
    [---],
    [$64 thin "k"$],

    link("https://github.com/rclone/rclone")[rclone],
    [File Transfer],
    [---],
    [$59 thin "k"$],

    link("https://github.com/podman-container-tools/podman")[Podman],
    [Containerization],
    [$11.1%$],
    [$32 thin "k"$],
  ),
  caption: [Examples of high-profile projects primarily written in Go],
) <bg:go:prevalence:high-profile>

In @bg:go:prevalence:high-profile above, the "Reported Usage" column
corresponds to the percentage of respondents to the aforementioned Stack
Overflow 2025 Developer Survey's "Cloud development" category question who had
done "extensive development work" with the tool over the previous year, if
applicable. The "GitHub Stars" column denotes to the approximate number of
stars held by the project's main GitHub repository, if any, at the time of
writing.

Besides the open-source environment, Go is also widely used by a multitude of
well-known large companies across the industry, including Google @gogoogle,
Microsoft @microsoftgo, Cloudflare @cloudflarego, PayPal @gopaypal, Netflix
@netflixgo, and Uber @ubergo.

Overall, Go has cemented itself as a key component of the software landscape,
both for public and proprietary code, making it a very suitable focus for
research work. This broad exposure across domains and applications makes Go a
high-value target for malicious attackers, therefore also a prime candidate for
security research.

=== Language Overview

The present subsection aims at providing a high-level introduction to some of
Go's features, constructs, and peculiarities. Emphasis is put on what is most
relevant for easier understanding of the present document and this degree
project's contributions, but it is not intended to be a complete reference to
the language.

Except where otherwise stated, the source for all the claims in this subsection
is the Go 1.26 specification document @go126spec, the authoritative Go
reference. The notable exception is for what regards Go's module system, which
is not part of the core language and is thus described in a separate document
@gomod.

==== Scoping, Packages, and Modules <bg:go:overview:org>

Go programs are organized into _packages,_ which are the language's fundamental
compilation unit. A package named `main` containing a `main` function becomes an
executable, and all other packages it depends on are linked to it.

Packages are composed of one or more source files (usually identified by the
`.go` extension), all in the same directory#footnote[As a convention, for
  standalone packages, but required when within modules.], which form a
collective package scope #footnote[Go documentation typically prefers the term
  "block" for lexical regions, but this work avoids that name to prevent
  ambiguity with block statements, i.e., `{ stmt1; stmt2; }`.] under which all
of the package's symbols are declared. Top-level declarations are package-scoped
and are equally accessible from every file in the package, while only import
declarations are file-scoped.

Encompassing all Go source text, across all packages, is the universe scope
(universe block), which contains all predeclared identifiers, such as `true`,
`nil`, `int64`, and `len`. These may be used (or shadowed) anywhere.

While not technically part of the language, in practice Go code is almost always
organized into _modules,_ higher-level units of operation. Modules are
structured collections of packages, focusing on dependency management, both
internal (between packages of the same module) and external (for re-using code
from other modules).

Modules have a `go.mod` file specifying associated metadata, such as the minimum
required Go version and a comprehensive list of all (external) dependency
version requirements. All packages within a module are versioned, released,
distributed, and depended on together, as a coherent unit.

Each module is identified by its _module path,_ as indicated by a `module`
directive in `go.mod`. This usually corresponds to where the module can be
downloaded from, such as `github.com/user/repo/sub`. Modules can be obtained
directly from its code repository, or alternatively from a module proxy server
(a module mirror, such as the official #link("https://proxy.golang.org").

A module's packages are identified by a _package path_ that is always prefixed
by the module path and then indicates the module's subdirectory under which its
source files are found. For example, a package path of
`github.com/user/repo/sub/utils` represents all the `.go` files in directory
`utils/` of the module accessible at directory `sub/` of the GitHub repository
`user/repo`.

All packages have a native _package name,_ declared at the top of all its source
files with a directive such as ```go package utils```. This name is a single
identifier and must match for all of a package's source files. It is important
to note, however, that it does not necessarily have to match the last component
of the package path; for instance, a package with path `example.com/mod/pkg` may
declare its name with ```go package unrelated```. Other packages' source files
importing `example.com/mod/pkg` without specifying a custom qualifier would
then refer to its exported declarations via `unrelated.Name`, not `pkg.Name`.

In this work, the term "program" is used as a general description for a
semantic unit of functionality, and may apply to both modules and individual
packages depending on the context.

#pagebreak()

==== Goroutines

Goroutines comprise Go's most noteworthy language feature and are frequently
central to the design of many Go programs. They represent independent,
concurrent threads of control, but share the same address space.

Goroutines are cheap and do not correspond directly to physical threads at the
@os level; instead, the language runtime transparently multiplexes one or more
goroutines into dynamically-managed @os threads, growing and shrinking each of
their stacks' memory allocations as necessary, which powers a very
resource-efficient mechanism, without any manual developer intervention @gofaq.

Syntactically, they are deployed using ```go go``` statements, which enclose
function calls; ```go go``` statements cause the associated function call to be
executed in a separate goroutine, i.e., in another thread of execution. The
invoking goroutine evaluates the call's arguments, but then does not wait for
the function to return, and just continues executing the subsequent statements.

#codly(highlighted-lines: (2,))
#figure(
  ```go
  fmt.Println("this always executes first")
  go fmt.Println("but this ...")
  fmt.Println("... and this have no defined ordering")
  ```,
  caption: [Example of spawning a new goroutine],
) <bg:go:overview:goroutines:example>

@bg:go:overview:goroutines:example above shows an example of using a ```go go```
statement (highlighted) to induce the concurrent handling of two invocations of
`fmt.Println`.

The Go development team is very explicit about the semantic distinction
between concurrency and parallelism, which represent related but distinct
concepts. They define them as follows: "concurrency is the _composition_ of
independently executing processes, while parallelism is the simultaneous
_execution_ of (possibly related) computations" @gerrand2013waza. Concretely,
concurrent solutions allow for safe parallelism, but it is not guaranteed that
any occurs.

==== Channels

Channels are Go's native message-passing construct and form an essential part of
the language, particularly when used for concurrent programming. They provide a
core mechanism for communication between goroutines, allowing for
synchronization and coordination between logical threads, without any explicit
locking or special handling.

@bg:go:overview:channels:basic exemplifies how channels are created with
`make` and then operated on via send statements (`<-`) and receive expressions
(`->`). @bg:go:overview:channels:expensive, in turn, demonstrates how channels
can complement goroutines to coordinate expensive calculations, possibly (but
not necessarily) parallelizing workload.

#figure(
  ```go
  ch := make(chan string)

  go func() { ch <- "Hello, world!" }()
  // note the () making this a call! ^^

  msg := <-ch
  fmt.Println(msg)
  ```,
  caption: [Example usage of channels with goroutines],
) <bg:go:overview:channels:basic>

#codly(highlighted-lines: (4, 7, 9, 18))
#figure(
  ```go
  process := func(n int, ch chan<- int) {
    // perform an expensive calculation,
    // then send the result back upstream
    ch <- expensive(n)
  }

  results := make(chan int)
  for i := range 5 {
    go process(inputs[i], results)
  }

  // ... can perform unrelated work here ...

  total := 0
  for j := range 5 {
    // results can arrive in any order, so "result #j"
    // does not necessarily match "input #i"
    total += <-results
    fmt.Println("Collected", j, "out of 5")
  }

  fmt.Println("Sum is", total)
  ```,
  caption: [Example concurrent processing of expensive operations],
) <bg:go:overview:channels:expensive>

Channels can be _directional_ (receive-only, typed as ```go <-chan T```, or
send-only, typed as ```go chan<- T```) or _bidirectional_ (if no restriction is
specified). On line 1 of @bg:go:overview:channels:expensive, for instance, the
`ch` parameter is declared as a channel with send direction, since `process`
only ever needs to send values through `ch`. Nevertheless, the function call at
line 9 is still accepted, despite `results` having a different type from `ch`,
because bidirectional channel are always assignable to directional channel
types.

Moreover, channels can be _buffered_ or _unbuffered._ Channels are unbuffered by
default, in which case all send operations block the current goroutine until a
receiver is ready (i.e., until another goroutine attempts to receive a value
from the same channel). Buffered channels, in contrast, accept a certain number
of values without waiting for a receiver, up to the specified buffer size; when
the buffer is full, send statements block as normal until a concurrent receive
frees up space for more values.

@bg:go:overview:channels:buffered below shows how a buffered channel can be
created by passing a buffer size to `make`. The highlighted send statement would
have blocked forever if `ch` was unbuffered, since there is no simultaneous
receive.

#codly(highlighted-lines: (3,))
#figure(
  ```go
  ch := make(chan rune, 5)

  ch <- 'H'
  ch <- 'i'
  ch <- '!'
  close(ch)

  for x := range ch {
    fmt.Printf("%c", x)
  }
  ```,
  caption: [Example buffered channel usage without goroutine spawning],
) <bg:go:overview:channels:buffered>

Finally, channels can be _closed_ to indicate that no more values will be sent,
as seen in @bg:go:overview:channels:buffered above. Receiving from a closed
channel (after receiving any pending values, if the channel is buffered) never
blocks and yields the element type's zero value (e.g., ```go 0``` for `int`).
This is especially useful to signal termination to for-range loops on channels,
as otherwise they would block forever, thus allowing patterns such as the one
used at the end of @bg:go:overview:channels:buffered.

#pagebreak()

==== Communication Selection

The final major language primitive for supporting concurrent programming is
```go select``` statements, which allow combining multiple channel operations. A
```go select``` statement defines multiple communication cases and, when
executed, chooses exactly one of them to proceed.

A single ```go default``` case may be provided, with all remaining cases
corresponding to channel send or receive operations.

#figure(
  ```go
  num := make(chan int)
  msg := make(chan string)

  go func() { num <- 42 }()
  go func() { msg <- "Special" }()

  select {
  case n := <-num:
    fmt.Println("Number came first", n)
  case m := <-msg:
    fmt.Println("Message came first", m)
  default:
    fmt.Println("Select executed before both sends")
  }
  ```,
  caption: [Example usage of ```go select``` statement],
) <bg:go:overview:select:basic>

In the example above, @bg:go:overview:select:basic, either of the three
`fmt.Println` may execute depending on parallelism and scheduling, but Go
guarantees that exactly one of them will execute. In general, ```go select```
operates as follows:
- if exactly one case is ready (i.e., a receive or send would not block), then
  that case is selected;
- if more than one case is ready, one of them is selected pseudo-randomly;
- if no case is ready and there is a ```go default```, it is selected; and
- if no case is ready and there is no ```go default```, the ```go select```
  statement blocks the current goroutine until any of the cases is ready.

Importantly, cases can appear in any order, and no priority is given to those
first in the source code; if multiple cases are are ready upon selection, all
those cases have an equal probability of being chosen.

Moreover, ```go select``` statements are frequently used in event loops,
capturing the next available value from multiple sources so that it may be
processed before the next iteration. @bg:go:overview:select:event exemplifies
this pattern.

#figure(
  ```go
  keyboard := make(chan KeyboardEvent)
  mouse := make(chan MouseEvent)
  progress := make(chan int)

  go listenForKeyboardEvents(keyboard)
  go listenForMouseEvents(mouse)
  go writeSlowLogs(progress)

  processed := 0
  for {
    select {
    case e := <-keyboard:
      fmt.Println("Key pressed:", e.key)
      processed += 1
    case e := <-mouse:
      fmt.Println("Click at:", e.x, e.y)
      processed += 1
    case progress <- processed:
      processed = 0
    }
  }
  ```,
  caption: [Example event loop using ```go select```],
) <bg:go:overview:select:event>

Overall, ```go select``` statements can prove very useful when orchestrating
tasks at a higher level, especially when combined with other constructs.

==== Closures <bg:go:overview:closures>

As already shown in several of the earlier examples in this chapter, Go supports
function literals, which define in-line anonymous functions.

Go function literals follow closure semantics: they may _capture_ symbols from
their body's surrounding scope by referring to them in their body. Captured
bindings are shared between inner and outer functions, and mutations are
reflected everywhere. @bg:go:overview:closures:example shows an example of
capturing closures.

#codly(highlighted-lines: range(5, 9, inclusive: true))
#figure(
  ```go
  val := 0
  val += 1

  // f captures val
  f := func() int {
    result := val * 2
    val -= 1
    return result
  }

  val += 1
  fmt.Println(val, f(), val, f(), val) // 2, 4, 1, 2, 0
  ```,
  caption: [Example closure with captures],
) <bg:go:overview:closures:example>

In the example above, lines 5 to 9 of @bg:go:overview:closures:example define a
function literal capturing `val`, which is thenceforth a shared binding and thus
susceptible to mutations from both inside and outside the closure. This means
that the anonymous function always sees an up-to-date version of the captured
binding, even if it was changed after the closure's definition.

==== Structs, Embedding, and Promotions <bg:go:overview:structs>

Go supports C-style ```go struct``` datatypes, aggregating typed _fields_ under
a common structure. Each field declaration may specify an optional tag, which is
a string literal exposed via reflection @api:pl, commonly used for configuring
external functionality operating on struct instances.

Fields are accessed through selection operations of the form `x.f`, where `x`
is an expression corresponding to a struct value and `f` is an identifier
matching a declared field name. Structs are initialized using ```go struct```
literals.

A distinctive Go feature is _embedded fields,_ through which another struct is
embedded so that its fields are accessible from the first through its
unqualified type name. This means that if $X$ embeds $Y$, the pseudo-field `Y`
on instances of $X$ is an instance of $Y$.

Moreover, the language defines _field promotion,_ which allows fields from
(recursively) embedded structs to be directly accessible. If there would be
ambiguity, the shallowest depth contributing exactly one field prevails. For
example, the highlighted line 22 of @bg:go:overview:structs:example shows two
equivalent ways of accessing the `big` field. Line 23, in constrast,
demonstrates how no promotion occurs if it would clash with an existing field
name at a higher depth.

#codly(highlighted-lines: (22,))
#figure(
  ```go
  type animal struct {
    name string
    big bool
  }

  porcupine := animal{name: "Spikes", big: false}
  giraffe := animal{"JP", true}

  type dog struct {
    name string
    dateOfBirth string `json:"date_of_birth"`
    animal
  }

  myDog := dog{
    name: "Doggy",
    dateOfBirth: "2013-06-20",
    animal: animal{name: "DVH", big: false},
  }

  fmt.Println(myDog.dateOfBirth) // 2013-06-20
  fmt.Println(myDog.big, myDog.animal.big) // false, false
  fmt.Println(myDog.name, myDog.animal.name) // Doggy, DVH
  ```,
  caption: [Example struct definition and usage],
) <bg:go:overview:structs:example>

On line 11 of @bg:go:overview:structs:example, the field `dateOfBirth` is
declared with a tag following the conventional `namespace:"value"` format, in
this case specifying how the field should be (de)serialized. This could then be
extracted automatically (via reflection) by the implementing mechanism.

Finally, it should be noted that promotion does not apply solely to fields: a
_promoted method_ is defined analogously, hoisting (non-clashing) methods from
the embedded struct's method set to become accessible directly at the embedder's
level, as if they had been there declared.

==== Interfaces and Dynamic Dispatch

Go has no class hierarchy or inheritance, instead relying on _interfaces_ to
express abstract or shared behavior. Interfaces are named collections of method
signatures, with no inherent semantic value.

In particular, interfaces are not implemented directly; instead, types which
(coincidentally or otherwise) declare methods of matching signatures are
automatically considered to implement the interface, without ever referencing
it. A consequence of this is that any code may declare and use whichever
interfaces are necessary without relying on others to manually implement it.

Values may be typed as a particular interface, in which case their method set is
exclusively the interface's method set. Dynamic dispatch is supported, meaning
that invoking a method $m$ on a value $v$ known only to implement some interface
$I$ (which defines $m$) will actually invoke $m$'s implementation for $v$'s
concrete type $T$ as determined at run-time.

The predeclared identifier `any` is syntactic sugar for the empty interface,
```go interface{}```, which all types necessarily implement. Other, more complex
kinds of interfaces exist, but they are omitted here for simplicity, especially
given that the base concept is essentially the same.

==== Build-Tag Constraints <bg:go:overview:build-constraints>

The Go toolchain supports the conditional inclusion of source files depending on
specific environment considerations. This is accomplished through _build
constraints_ @gobuildconstraints, which are composed from build tags. For a
specific compilation process, each build tag is either satisfied or not; if so,
it evaluates to `true` where mentioned in constraint expressions, otherwise it
is `false`.

Tags are either custom user-defined (in which case they have project-specific
semantics), or represent a well-known compilation parameter, such as the
target @os (usually denoted `GOOS`), the target architecture (`GOARCH`), or the
compiler being used (one of `gc` or `gccgo`), among others.

Constraints are primarily specified using a ```go //go:build``` comment at the
top of the applicable source file. For example, a provided build constraint
comment of ```go //go:build (linux && amd64) || gccgo``` indicates that the file
in question should only be included for compilation when targeting Linux systems
using an AMD64 instruction-set architecture, or when using the `gccgo` compiler,
possibly because the file contains non-portable code. In all other cases, it is
omitted.

Typically, two or more complementing source files implement the same interface
(e.g., declare the same top-level symbols) using mutually exclusive build
constraints, so that relying code can transparently invoke platform-specific
@api:pl without needing special handling for each possibility. For instance, a
low-level function interacting directly with @os functionality might be
implemented thrice, for each of `linux`, `darwin`, and `windows`.

In addition to ```go //go:build``` comments, an alternative legacy form of
multiple ```go // +build``` comments is also recognized as declaring build
constraints, though using a different syntax. When formatting a file, the Go
toolchain automatically adds an equivalent ```go //go:build``` if only
```go // +build``` directives are present, since the former are always preferred
and the latter are supported purely for legacy compatibility.

Finally, simple constraints may also be specified via a filename suffix before
the `.go` extension using `GOOS` or `GOARCH` names. For example, a file named
`utils_windows.go` will only be included when Windows is the target @os,
without any need for an explicit ```go //go:build``` directive.

==== Foreign Implementations

Go supports some degree of interoperability with the C programming language,
allowing Go code to invoke C functions and C code to invoke Go functions. The
underlying @ffi mechanism is implemented and controlled by the `cgo` tool
#footnote(link("https://pkg.go.dev/cmd/cgo")).

From Go source code, it is possible to access C-level symbols through the
pseudo-package `C`, i.e., ```go import "C"```. Alternatively, to permit C code
to execute Go functions, they must have an ```go //export SomeName``` coment
immediately preceding their definition.

The pseudo-package `C` contains all accessible C symbols. If its import
directive is immediately preceded by a comment (denoted the _preamble_), then
that comment's contents are included in a header file when compiling the
package's C elements; for instance, an ```go import "C"``` declaration might
follow an ```go // #include <stdio.h>``` preamble.

This kind of @ffi is not given any special handling by the present work, since
it is sound for the `C` package to be treated as any other black box external
dependency. In addition, since any non-Go code is out of scope of this work,
Go invocation from C is not significant for this degree project.

#pagebreak()

== Past Incidents

There are a number of previously-reported security vulnerabilities and past
incidents across the Go ecosystem that could have theoretically been detected by
static taint analysis of source code and subsequently fully eradicated or
mitigated before ever being released, if specialized techniques such as the
ones set forth by this work could have had been part of the respective teams'
development processes.

It should be noted that the incidents mentioned in this section are not
exhaustive and merely constitute representative examples of different security
angles relevant to this degree project's focus. Many other kinds of
vulnerabilities can be made possible by gadgets detectable with static taint
analysis, assuming a sufficiently robust and domain-appropriate security policy.

=== Vulnerability Referencing and Classification

In order to help group the referenced vulnerabilities into logical classes,
this section relies on the @cwe category system
#footnote(link("https://cwe.mitre.org")) maintained by the MITRE Corporation
and sponsored by the U.S. Department of Homeland Security as well as the U.S.
Cybersecurity and Infrastructure Security Agency @cwefaq.

@cwe is a sister project to @cve#footnote(link("https://cve.org")), a
similarly-maintained and similarly-sponsored initiative focused on the
identification, definition and cataloguing of concrete, publicly-disclosed
cybersecurity vulnerabilities @cvefaq.

Finally, the @nvd#footnote(link("https://nvd.nist.gov")) is a third independent
project, operated by the U.S. National Institute of Standards and Technology's
Information Technology Laboratory. Once a vulnerability has been issued a @cve
ID, its record is mirrored on the @nvd and then progressively enriched and
augmented with more detailed information and structured metadata @nvdfaq.

The @cve and @nvd databases and their associated records have become the chief
authoritative sources for referencing public vulnerabilities. Additionally,
records often specify one or more @cwe categories to which the underlying
security problem is mapped.

#pagebreak()

=== Exposure of Sensitive Information

The first major group of interest corresponds to @cwe weakness CWE-200
"Exposure of Sensitive Information to an Unauthorized Actor" @cwe200sensitive.

The most common kind of relevant security issue within this category corresponds
to failure to censor sensitive information from logs, thereby exposing
credentials and other secrets, as is the case for vulnerabilities reported for
Mattermost @cve20231831mattermost @cve20232514mattermost, Jaeger
@cve202010750jaeger, Flux Tofu Controller (then Weave TF-Controller)
@cve202334236weave, Vela @cve202428236vela, and Syft @cve202324827syft. In the
latter case, Syft exposed a critical credential#footnote[Syft provides, among
  other functionalities, build attestations. The leaked credential
  (`SYFT_ATTEST_PASSWORD`) is used to decrypt the attestation private key.] not
only through logs, but also through certain attestations and other payloads
published to public container registries.

Other associated vulnerabilities are mapped directly to CWE-200's more specific
"Insertion of Sensitive Information into Log File" subcategory, CWE-532
@cwe532logs. This includes a critical-severity Cloud Foundry issue caused by
logging a client secret on startup @cve20181264cloudfoundry, another Cloud
Foundry problem where credential logging allowed lower-privileged remote users
(log viewers) to take ownership of created volumes @cve201911283cloudfoundry,
and several related Kubernetes vulnerabilities @cve20208563kubernetes
@cve20208564kubernetes @cve20208565kubernetes @cve20208566kubernetes
@cve20257445kubernetes. Other projects with high or critical severity @cve:pl
mapped to CWE-552 are Docker @cve201913509docker, HashiCorp Vault
@cve202013223vault, HashiCorp consul-template @cve202238149consultemplate,
Mattermost @cve202137861mattermost, Atlantis @cve202452009atlantis, Argo CD
@cve202340029argocd, Weave GitOps @cve202231098weave, NooBaa @cve20213528noobaa,
OpenShift @cve202010752openshift @cve202010712openshift, as well as the
Terraform providers for Linode @cve202627900linode and Microsoft's
Power Platform @cve202447083microsoft.

However, logs are not the only exfiltration medium. Pterodactyl's server
control plane (Wings) exposed secrets into templated configuration files
@cve202652855pterodactyl, while Grafana sent credentials to third-party plugins
@cve202231130grafana @cve202239201grafana, and Mattermost included various
secrets in support packets @cve20262476mattermost @cve20266346mattermost
@cve20266347mattermost.

Several other projects leaked sensitive information through @http @api
endpoints, including Apache ServiceComb Service-Center
@cve202344312servicecomb, Argo CD @cve202126923argocd, and Atlantis
@cve202558445atlantis. KubePi, in particular, included all password hashes in
responses crafted for its user search endpoint, creating a stepping stone for
offline attacks on administrator accounts @cve202337916kubepi. Moreover,
linx-server was vulnerable to a @ssrf attack where it could make sensitive
internal files publicly accessible, due to lack of user input validation in a
public @api endpoint for uploading files from an arbitrary @url
@cve202652101linxserver.

Furthermore, some related vulnerabilities are instead mapped to CWE-209
"Generation of Error Message Containing Sensitive Information" @cwe209error,
such as in free5GC, where publicly-visible errors exposed internal
infrastructure details @cve202642459free5gc, in monetr, where attackers
exploiting a separate @ssrf vulnerability could access the triggered request's
response via monetr's returned error structure @cve202641644monetr, and in the
Algernon, where the web server sent sensitive script source code to remote users
as part of error responses @cve202645728algernon.

Additional categories of interest to this subsection are CWE-212 "Improper
Removal of Sensitive Information Before Storage or Transfer" @cwe212removal,
which includes a Grype issue where registry credentials were included in some
security analysis outputs @cve202565965grype, as well as CWE-312 "Cleartext
Storage of Sensitive Information" @cwe312storage, to which is mapped a Grafana
issue where all direct data-sources' passwords were publicly exposed even if
not used in any public dashboards @cve202627877grafana, among others.

Overall, there are varied attacker-observable information sinks through which
sensitive data can be leaked, frequently resulting in disastrous consequences,
as demonstrated through the vulnerabilities referenced above. Confidentiality is
an essential pillar of cybersecurity, so any improvement in detecting
information leaks is already an exceptional advantage.

=== Path Traversal

Another significant grouping corresponds to CWE-22 "Improper Limitation of a
Pathname to a Restricted Directory ('Path Traversal')" @cwe22path. This usually
happens when an attacker-controlled file path is not sanitized correctly,
meaning that special sequences such as `..` can be used to escape the target
sandbox directory, often leading to arbitrary reads, writes, or execution.

Static taint analysis can, in most cases, identify path traversal, since it
comprises an insecure flow between an untrusted source and a critical part sink.
As such, mechanisms such as those explored in this degree project can report
missing sanitization and thus prevent real security issues.

Path traversal is a widespread category of vulnerabilities; some examples
include missing validation in goshs @cve202635392goshs @cve202635393goshs, Helm
(the Kubernetes package manager) @cve20204053helm, and the GitLab Runner
@cve202013347gitlab. Lack of sanitization in LocalAI similarly allowed
arbitrary file deletion @cve20245182localai from anywhere in the system, and in
the peer-to-peer file distribution tool Dragonfly peers could execute arbitrary
code on other peers' machines @cve202559352dragonfly.

#pagebreak()

=== Injection of Untrusted Input

The last major group important to mention is associated with CWE-74
"Improper Neutralization of Special Elements in Output Used by a Downstream
Component ('Injection')" @cwe74injection and other adjacent categories.

One of the clearest examples of a past incident within this topic is the
Thunderdome Planning Poker failing to sanitize an attacker-controlled username
field before passing it to an @ldap:short query @cve202141232thunderdome. Static
taint analysis would have been able to identify this problem, assuming suitable
sources and sinks.

Furthermore, CWE-77 "Improper Neutralization of Special Elements used in a
Command ('Command Injection')" @cwe77cmd is also mapped to several
vulnerabilities of interest, such as the GitHub @cli tool allowing arbitrary
command injection by not sanitizing untrusted remote responses passed as
arguments to `ssh` @cve202452308github, and the @c2 tool emp3r0r failing to
escape untrusted agent metadata later used in shell commands
@cve202626068emp3r0r.

Another very significant form of injection is @xss, represented in the @cwe
hierarchy by CWE-79 "Improper Neutralization of Input During Web Page
Generation ('Cross-site Scripting')" @cwe79xss. An example past incident
includes Beego missing @html escaping before embedding input in a web page
@cve202530223beego, which could have been detected by taint analysis, as
explained above.

Other related categories include CWE-601 "URL Redirection to Untrusted Site
('Open Redirect')" @cwe601redirect and CWE-918 "Server-Side Request Forgery
(@ssrf:short)" @cwe918ssrf. The former applies, for instance, to a ZITADEL
vulnerability where the server emailed users secret-carrying password reset
links rooted to the (possibly attacker-controlled) `Forwarded` (or
`X-Forwarded-By`) @http header without validating that it matched the
instance's own domain @cve202629067zitadel, and the latter is associated with,
for example, a vulnerability resulting from Prebid Server not validating
untrusted, user-supplied outbound request targets, exposing internal network
services @cve202654735prebid.

In general, while many more related incidents have taken place, these examples
are already sufficient to grasp how static taint analysis can make a real
impact on the Go ecosystem, even if not all possible security problems would be
eradicated. The issues identifiable by this degree project's focus point
make up a significant share of the overall vulnerability landscape, thus
justifying an investment in preventing them by using appropriate security tools
and configuring them to achieve the best possible results.

#pagebreak()

== Previous Work

This degree project's author previously co-authored a small prototype analyzer
for Go source code, here referred to as Glowy-Zero. Said prototype was developed
in equal parts with Diogo Correia as part of a 3 credits project for the
DD2525 Language-Based Security
#footnote(link("https://www.kth.se/student/kurser/kurs/DD2525?l=en"))
course at the KTH Royal Institute of Technology, which is also the present
degree project's host university.

This work extends Glowy-Zero into a much more developed, robust, sound, and
feature-complete static taint analyzer. The original implementation has been
almost completely rewritten, with very few of Diogo's original lines of code
remaining (less than $500$, approximately $1%$ of the current version), almost
exclusively in the Go lexer of the parser library.

A snapshot of Glowy-Zero and the surrounding course project documentation is
publicly available in its now-archived GitHub repository
#footnote(link("https://github.com/ist199211-ist199311/glowy-langsec")), and it
has been MIT-Licensed since the very first commit, thereby not compromising
Glowy's own licensability. Glowy's Git repository is rooted in Glowy-Zero's,
retaining full history; the last Glowy-Zero commit is tagged
`langsec-project-submission`, so a full diff of the changes made within the
framework of the present degree project is easily accessible
#footnote(link("https://github.com/RafDevX/glowy/compare/" + //
"langsec-project-submission...master")).

The fundamental conceptualization and some core properties of the model were
retained from Glowy-Zero, having thus been jointly produced by both original
authors. However, the current version of Glowy has been greatly enhanced for
real-world analysis, in comparison with the former.

Glowy-Zero was a well-grounded, yet very simple first prototype, as expected
given the time and workload constraints associated with a course project. It had
minimal language support and made several unsound assumptions which, while
normal for a small proof-of-concept prioritizing simplicity, are unacceptable
for interacting with real Go projects.

Glowy builds on Glowy-Zero to provide a much more advanced prototype,
implemented with strict ambition for maximal soundness and precision as
permitted within the boundaries of the technical limitations inherent to static
source-code analysis and the standard scope constraints for a degree project,
which, while limited, are still broader than for a course project.

#pagebreak()

== Related Work <bg:related>

Static taint analysis and information flow enforcement are not new developments
within cybersecurity, and extensive work has been conducted on the subject,
targeting a wide range of languages and environments.

Some notable examples include Pysa
#footnote(link("https://pyre-check.org/docs/pysa-basics")), a security-focused
taint analysis tool part of the Pyre static type checker for Python and
developed by Meta (formerly Facebook), the taint-based Security Analysis feature
#footnote(link("https://psalm.dev/docs/security_analyzer")) of the Psalm static
analyzer for PHP, and ODGen
#footnote(link("https://github.com/Song-Li/ODGen")), a static analyzer for
JavaScript and Node.js that relies on Object Dependence Graphs to detect
insecure data flows @likang2022odgen. In addition, a particularly noteworthy
project is FlowDroid
#footnote(link("https://github.com/secure-software-engineering/FlowDroid")),
a Java static data flow tracker with focus on Android applications
@arzt2014flowdroid.

Nevertheless, source analysis is necessarily a language-specific process,
depending significantly on its inherent constructs, functionalities, and
assumptions, as well as what information is made available statically. For
instance, Flowistry#footnote(link("https://github.com/willcrichton/flowistry"))
leverages the (very robust and explicit) Rust ownership system to determine
dependency relationships between symbols and values, applying an
interprocedural and modular @ifc reasoning that is extraordinarily precise even
when dependency source code is unavailable @crichton2022flowistry, but such a
novel and distinctive approach is only possible because it is Rust-specific;
i.e., the same algorithm could not be generalized to other languages.

It thus makes sense to apply data flow and taint analysis techniques to Go
specifically, adapting the underlying, well-known, and state-of-the-art guiding
principles to the particularities of the Go programming language.

There are a number of other tools already available within the Go ecosystem that
implement some form of data flow tracing or adjacent analysis, but at the time
of writing none of them is fully satisfactory for the concrete and specific
goals set forth by the present degree project, even if they each have merit
within their own respective declared areas of operation.

The most significant of these related tools are briefly introduced in the
following subsections, but further comparison with this work's contributions is
presented in @discussion, under @discussion:related.

#pagebreak()

=== Go Pointer

The `golang.org/x/tools/go/pointer` library
#footnote(link("https://pkg.go.dev/golang.org/x/tools/go/pointer")) does not
implement taint analysis and is not intended as an end-user security validator,
but a reasonably simple wrapper around its functionalities could theoretically
form one.

It models possible alias relationships and general points-to heap location
tracing, implementing an algorithm first introduced by
#cite(<andersen1994pointers>, form: "prose") for C. Its documentation claims
deterministic bounded soundness for all pure Go inputs, except those using
reflection or `unsafe.Pointer` conversions, and it is both flow-insensitive and
context-insensitive, thereby representing conservative estimations for where
pointers may point to.

In 2023, the Go team decided to deprecate and freeze Go Pointer
@donovan2023pointer, citing slow execution, scalability issues, difficult to
understand results, fragility, and maintainability workload for runtime and
standard library annotations. This means that the library has not been updated
to support significant new language features up to the most recent release (Go
1.26; the latest version preceding the freeze was Go 1.20), compromising its
soundness for new code.

=== Gotcha

// stands for "Go Taint CHecker Analyzer", but no space to mention it

Relatedly, the `gotcha`#footnote(link("https://github.com/akwick/gotcha")) tool
uses the Go Pointer library described above to implement taint analysis and
report insecure information flows from sources to sinks. It supports broad
definitions of sources and sinks through an input text file listing selected
functions, but does not model security labels (i.e., taint is a binary property)
nor any taint downgrading for sanitizers.

The analyzer uses a context-sensitive worklist and focuses on explicit channel
handling, though no advanced concurrency modeling is supported. The tool and its
underlying conceptualization are the chief subject of a published research
paper @bodden2016gotcha, and were developed as part of Anna-Katharina Wickert's
Master's thesis#footnote[The thesis text is not published and the author did not
  respond to a request for access.] at the Technical University of Darmstadt.

Gotcha is primarily a single-author research artifact and has therefore not been
updated since 2017. It explicitly only supports Go 1.7 and earlier, which means
that it has no support for the major language developments from the past decade,
including modules and generics. As such, it is thus not a realistic candidate
to real use in modern Go projects.

#pagebreak()

=== GoKart

GoKart#footnote(link("https://github.com/praetorian-inc/gokart")) is a static
analysis tool designed for practical vulnerability finding and minimal false
positives. It makes no soundness guarantees, preferring simplicity for
real-world vulnerability detection. GoKart is open-source, but developed by
Praetorian#footnote(link("https://www.praetorian.com")), an offensive security
company.

When an insecure flow is detected, it surfaces source and sink information to
help trace the underlying problem. The analyzer is configured through a
customizable list of sources and sinks, but is not fully flow sensitive and
explicitly mishandles global variables @praetorian2021gokart.

Just as the projects mentioned in the preceding sections, GoKart is also
discontinued: its last change and release took place in 2022 and the project's
GitHub repository has been archived since 2024.

=== Go Flow Levee

Go Flow Levee#footnote(link("https://github.com/google/go-flow-levee")) is a
taint analyzer developed by Google, relying on lower-level ecosystem analysis
primitives to detect insecure flows from sources to sinks, as configured through
@yaml:short files and struct field tags. Sanitizers are supported, and false
positives can be suppressed via ```go // levee.DoNotReport``` source code
annotation comments.

Implicit information flows are not detected, and the analysis is
intraprocedural, considering each single function in isolation.
The documentation is also scarse and incomplete, and some configuration
patterns are somewhat awkward and unintuitive, significantly relying on
indirection.

Kubernetes added this tool to its @ci pipeline in 2021, after a Trail of Bits
codebase audit @trailofbits2019kubernetes identified multiple sensitive data
leakage vulnerabilities @kep1933levee. This led to multiple struct fields being
annotated with `datapolicy:"..."` tags, demonstrating how even large and
high-profile projects can be willing to annotate their source code and take the
time to properly configure their security tools.

However, Go Flow Levee has not had material developments since 2021 and its
GitHub repository is archived. It was dropped from Kubernetes in 2024 for
not supporting modern Go features @, but the `datapolicy` tags remain.

#pagebreak()

=== Gosec

Gosec#footnote(link("https://github.com/securego/gosec")) is an active, broad
source code inspector for statically finding potential security issues. It
applies pattern matching and several different techniques to identify and
surface 7 different categories of errors, matching more than 60 security rules
that it ships with.

One of aforementioned 7 rule categories corresponds to taint analysis, which is
capable of detecting explicit (but not implicit) insecure flows. While it is
technically possible to depend on the taint engine directly and configure its
sources and sinks from a wrapper program, the Gosec @cli restricts analysis to
the 10 built-in rules, respectively tied to SQL injection, command injection,
path traversal, @ssrf, @xss, log injection, @smtp command/header injection,
server-side template injection, unsafe deserialization of untrusted data, and
open redirect vulnerabilities @gosecrules.

While this makes it simpler to extract immediate value from running the tool
without a need for configuration, it also means stagnation for the returns it
yields, since it does not (practically) support customized project-specific
configuration, tailored to the consumer's needs and security model.

In particular, Gosec was explicitly excluded from consideration when Go Flow
Levee was first proposed to be added to Kubernetes, specifically because it
does not allow for project-specific source/sink configuration @kep1933levee.

=== Gruber's Taint Analyzer

The `taint` tool#footnote(link("https://github.com/picatz/taint")) is an
actively-developed static taint analyzer written exclusively by Kent Gruber,
with Claude Code being listed as co-author for all recent commits. In order to
avoid ambiguity, `taint` is here referred to as "Gruber's Taint Analyzer", given
its very generic name.

Besides built-in rules, the analyzer supports flexible source and sink
configuration through @yaml model files, but treats taint as a boolean property
rather than a set of tags. While sources can be optionally tagged with a
vulnerability category (e.g., `sql-injection`), this is only used during error
reporting, and it is not part of the analysis model. In particular, this means
that secret and untrusted data are indistinguishable, so sanitizing for one will
also clear the other, which can be unsafe.

#pagebreak()

=== Argot Taint Analyzer

The final Go-specific project of interest is `ar-go-tools`
#footnote(link("https://github.com/awslabs/ar-go-tools")), developed by Amazon
Web Services and branded as Argot (which stands for Automated Reasoning Go
Tools). It is a collection of static analyzers focusing on different aspects,
the foremost of which (`taint`) a taint analyzer.

It performs whole-program interprocedural analysis using pointer aliasing and
call-graph information. The project claims a strong soundness guarantee for all
Go programs that do not make use of concurrency nor the `unsafe`/`reflect`
packages, though it should be noted that concurrency via goroutines and
channels is a major requirement for many Go projects.

The tool does not infer any starting policy, fully depending on users to define
sources and sinks for each problem type under consideration according to the
documented @yaml format. Specified control targets use @regex matching (e.g.,
a sanitizer rule targeting `"Sanitizer"` applies to any function name containing
the word `Sanitizer`; a literal match would have to be specified as
`"^Sanitizer$"`) and implicit flow tracking is opt-in (disabled by default),
both of which can cause confusion and a false sense of security for users who
do not read the documentation very closely.

=== Multi-Language Tools

Besides the Go-specific tooling presented in the previous subsections, there are
some other noteworthy generic static analyzers with support for a wide range of
programming languages, including Go.

CodeQL's data flow querying
#footnote(link(
  "https://codeql.github.com/docs/codeql-language-guides/"
    + "analyzing-data-flow-in-go",
))
is the clearest example of such a tool, since it allows executing very powerful
semantic queries capable of identifying insecure flows. However, even if
possible, it is not ergonomic to encode sources and sinks in queries (especially
for indirect flows), when compared to a human-readable security policy. In
addition, CodeQL is heavy and not practical to run in developer machines (e.g.,
pre-commit hooks), besides being a commercial product requiring paid licensing
for proprietary use.

Alternatively, Opengrep#footnote(link("https://github.com/opengrep/opengrep"))
uses expressive pattern-based rules and supports advanced handling of many Go
constructs, but is limited to intra-file analysis, rather than taking into
account the whole project-wide context.

#pagebreak()

== Summary

In short, the present work employs taint analysis techniques to statically
identify potentially insecure information flows, based on the systematic
scrutiny of Go source code. There are multiple types of data flows, with this
degree project focusing on explicit and implicit ones, using call-site
sensitivity and partial flow sensitivity to reliably detect them.

Taint analysis tracks how values are propagated throughout a program's execution
paths from sources to sinks, as measured by security labels composed of tags,
which may in turn be plain or bound to an axis, in this work. Two distinct kinds
of sinks are defined, in a novel attempt to combine simplicity with flexibility
in security policy definition, and a mechanism of explicit revocation is
additionally recognized as a manual override for rigid soundness invariants.

Go is a compiled general-purpose programming language with widespread usage and
a number of interesting properties for static analysis and security research in
general. There have been a large number of past security incidents in numerous
Go projects that could have plausibly been detected by static taint analysis,
further cementing the need for research such as that of this degree project.

This work builds on a previous first prototype Glowy-Zero, co-developed for a
course project, though almost the entire implementation has been rewritten, and
only some central concepts remain. There are a number of existing tools with
similar purposes to this work, but none fully satisfy the goals set forth by
the present degree project.
