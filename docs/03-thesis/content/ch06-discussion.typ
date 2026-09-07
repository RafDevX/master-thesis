#import "../utils/dependencies.typ": codly, zero

#import codly: codly

= Discussion <discussion>

This degree project is centered around several ambitious goals and core tenets,
striving to address a fundamental problem to the utmost extent possible within
the scope and constraints it is bound to. It prioritizes robustness,
flexibility, and usability, aiming to contribute balanced and well-designed
solutions to the overarching field of Cybersecurity.

The present chapter considers each research question and stated goal, weighing
the project's contributions against the overall requirements set forth by this
report and evaluating their merit as a research development.

== Research Questions

This section addresses each of the research questions defined in @intro:rq,
considering them under the light of this work's contributions and results,
as well as linking them to the project goals established in @intro:goals,
which are in turn derived from and a complement to the project's stated
purpose, introduced in @intro:purpose.

In particular, the findings presented in @eval:results of the foregoing @eval,
corresponding to the the auditing of $371$ Go modules, are interpreted in
connection with each research question, establishing a stronger link between the
results and the overarching degree project.

#pagebreak()

=== Information Flow Analyzer <discussion:rq:analyzer>

The first and most foundational research question, @rq-ifc[], centers around
the effective and systematic tracking of information flow in Go problems,
employing static analysis to accomplish it. This research question ties
directly with @pg-tool[], which prescribes the development of a static analysis
tool for detecting potential security vulnerabilities using @ifc techniques,
with support for both confidentiality and integrity use cases.

In consequence, the primary contribution for this degree project is Glowy, a
static analyzer that implements taint tracking to model sources, sinks, and the
propagation between them. It is conceptualized and built specifically for the
Go programming language, focusing on the correct and sound modeling of the Go
evaluation rules and considering the different possibilities for how constructs
may be used or abused to propagate information. As much precision as possible
and available is exerted, but only in strict balance with simplicity and
efficiency.

Glowy comprises not only the theoretical model and algorithms, described chiefly
in @glowy:procedure, but also the extensive software implementation in Rust,
which has specialized handling for almost the entire Go programming language,
with notable exceptions enumerated in @methods:subset.

As a complement and in parallel, a corpus of $230$ independent and focused
benchmarks was produced and organized into $21$ suites, for the purpose of
enumerating and demonstrating possible insecure flows or propagation
opportunities as enabled by the different Go constructs and functionalities.

Besides constituting a self-standing research contribution, this ground truth
doubles as a guarantee of Glowy's extensive support for a wide range of Go
features, since the developed tool successfully passes all $215$ ordinary cases
in the corpus. The remaining $15$ modules are part of Suite X (Failures) and
contain representative examples of features that Glowy explicitly does not
support (i.e., considered out of the declared scope).

In particular, it is worth reiterating that all modules use exclusively
assertions as their sole kind of policy enforcement check, which provides even
stronger assurances that a passing test truly implies correct coverage.

This demonstrates the analyzer's correctness and reliability in a controlled
test environment, corroborating the tool's sound and precise modeling of a
variety of Go constructs.

#pagebreak()

In order to assess Glowy's robustness and observe its behavior when interacting
with real Go modules (not tailored specifically for the analyzer's consumption),
this work conducted the auditing of $371$ Go modules extracted from popular,
open-source, real-world projects using the epistemically-sound selection
method explained in @methods:collection:discovery.

The results, presented in @eval:results, clearly showcase Glowy's capabilities
in detecting true security vulnerabilities, particularly when taking into
account the example findings described in @eval:results:effectiveness.

While it is not possible, as already noted multiple times throughout this
report, to obtain a set of true positives against which to validate the insecure
flows reported by the analysis tool, no in-scope false negative was found
through empirical observation during manual variable-granularity reviews of
the reported result set. It would also be very difficult for such cases to not
be detected and flagged by the benchmarks corpus, which evidences a high
likelihood that any hypothetical false negatives uses very strange constructions
or gadget-like configurations that are not covered by the benchmarks.

In any case, though, the purpose of the analyzer is strictly to report findings
it detects for stakeholder review and potential resolution, but nothing can be
inferred from no findings being reported; i.e., Glowy does not endorse any
conclusions regarding a lack of diagnostics implying a completely secure
proram. Other security vulnerabilities may still be present and undetectable.

It is thus on the presence of diagnostics that Glowy's security value rests,
never on their absence, since the analyzer is intended to aggregate potential
problems rather than perform formal verification of a program's behavior and
underlying security. This distinction is essential and stated multiple times as
clearly as possible, since stakeholders may otherwise make incorrect assumptions
and fallaciously use the tool's lack of diagnostics to evidence an unfounded
sense of security.

In addition, the results reported by Glowy naturally depend on the security
control configuration registered for analysis, which means that some pattern may
in some cases be accepted but in others constitute a violation. This is by
design, since the analyzer and this work explicitly define the property of
security as corresponding to the configured policy, which serves as an
authoritative guide for how the analyzer should operate and make decisions.

This consequently means that Glowy fully trusts the configured security policy,
as well as the source code under analysis (which may contain source-code
annotations that comprise security policy directives). This is necessary and
intentional, given that the analyzers considers developers and other such
stakeholders to be the ultimate truth for a particular project.

Moreover, several figures and inferences in @eval:results demonstrate a clear
support for both confidentiality and integrity, as required by @pg-tool[].
For instance, @eval:results:overview:avg-median-problems,
@eval:results:outliers:problem-boxes, and @eval:results:warnings:median-errors
explicitly distinguish between confidentiality and integrity errors, and
@eval:results:effectiveness describes findings related to either of the two
properties. This is backed, in part, by the label tag axes mechanism, which
enables expressive and flexible security policy definition, while remaining
opt-in so that simple cases do not need axes.

Furthermore, the analyzer retains its usefulness by staying reasonably fast
despite the inherent complexity of the underlying process. In particular,
@eval:results:performance specifies a median global run time of
$152.11$ milliseconds for all $348$ modules which completed analysis, out of
$371$ total.

On another note, Glowy's library-first implementation means that it can easily
be extended to different applications and better adapt to users' workflows,
according to whichever specific requirements and use cases are deemed
appropriate by them, since `glowy` is open-source and can be depended on
directly by other Rust code, for programmatic use. For example, the analyzer can
be used as a base for a code editor extension to show problems in-line and
highlight problems, just based on the existing structured analysis output.

The implemented @cli application is intuitive and optimizes for usability,
striving to respect the two factors ascribed to tool developers that
#cite(<witschey2015adoption>, form: "prose") hypothesize could be tied to
security tool adoption, namely perceived simplicity and understandable
presentation of results.

All in all, Glowy exhibits high effectiveness and soundness within the Go
subset under consideration, per @methods:subset. The analyzer supports several
complex taint propagation paths, as described in @glowy:constructs, and it is
largely agnostic to confidentiality, integrity, and any other axes, thus
generalizing even one level further than otherwise required by the research
question.

In this way, given the reasoning above, this degree projects considers
@pg-tool[] accomplished and @rq-ifc[] answered, including the latter's
sub-questions, @rq-ifc-confidentiality[] and @rq-ifc-integrity[].

#pagebreak()

=== Generic Security Policy

The second research question, @rq-base-policy[], extends the first one by
focusing on configuration, in search of a way to define a reasonable
default security policy that is generally-applicable, explicitly just as a
starting point before a real project-specific policy can be defined by the
appropriate stakeholders.

The associated project goal is @pg-base-policy[], which essentially narrows
down the @rq-base-policy[] by tying it to Glowy concretely: the objective is to
develop a reasonable, even if imperfect, policy to serve as input to the
analyzer.

This is in this work accomplished by the definition of a Base Security Policy,
which ships with the analyzer and is applied by default. The Policy is described
in more detail under @glowy:base-policy.

Glowy's Base Security Policy is subject to the same multi-module evaluation
process as the analyzer itself, since each module audit takes place without
any-project specific configuration and thus relies on the default blanket
directives to extract any security value from the analysis process.

The arguments used in the preceding section for overall effectiveness are thus
also applicable to the Base Security Policy, considering that it is the
default for the analyzer unless explicitly disabled.

However, even though the declared policy is successful at finding
vulnerabilities in the sampled set, it is unfortunately common for the tool to
yield a significant number of false positives as relevant findings collected
during analysis. This happens primarily because the Base Security Policy is
conservative and generic, defining multiple kinds of sources and sinks, but
virtually no revocations, as justified at the end of @glowy:base-policy;
sanitizers only clear input to be used in a specific target context, not for
unconditional broad usage, so they are necessarily situation-dependent and thus
should never be defined in a generic security policy, since sanitizer
sufficiency semantics depends on how the input is used by the project.

For instance, `path.Clean` might sufficiently sanitize a file path if it is
only used for (privileged) file reads, but often it will also be necessary to
independently check that the cleaned path is a descendant of an approved
directory, and even the combination of those two steps does not make the path
safe for, e.g., being included in @html without further escaping, since paths
may contain characters with defined special meaning in @html documents.

The referenced example showcases how a generic policy cannot soundly assume how
each tainted input will be used, as it depends on the project under scrutiny. It
thus nevertheless mean that analysis can report false positives even if input is
already sanitized in a way appropriate for the project.

Glowy's Base Security Policy cannot safely accept a great deal of pattern kinds
without explicit stakeholder instructions that acknowledge and elect the risk
associated with specific operations or chains thereof.

This makes the generic approach taken by this work less appropriate for
mass analysis, but does not compromise the significant usefulness of the base
policy for individual usage within a single project; even if a large number of
false positives is reported, they are usually tied to just some few underlying
root causes which are easy to fix under project-specific configuration. It
would, in comparison, prove too unsound to attempt to do this generically for
arbitrary programs via the base policy itself.

Important to highlight is the fact, though, that this work explicitly defines a
base policy only to better support project and user onboarding, since providing
nothing would require an immediate investment from stakeholders for defining an
appropriate security policy immediately when trialing usage, and greatly
steepen the necessary learning curve, as users would have to learn how to
define a sound policy for their project right away.

Consequently, any scenarios under which the Base Security Policy is of a higher
usefulness than no defined policy are already improvements over the
_status quo_, and in any case it can be argued that reporting real results (even
if with some degree of false positives) has more underlying security value than
worse usability combined with no initial results, the latter factor possibly
causing stakeholders to assume that the project is secure as-is and so there is
no need for additional security tool usage.

Glowy's Base Security Policy is thus still considered a success, as it
recognizes genuine flows in real-world projects and, even if it may generate
false positives, in general they tend to be very evident and trivial, with the
associated risk being very trivially accepted at the local level through one or
few well-placed revocation directives after consideration that they align with
the project's attacker model and security posture. Any reported flows that are
not trivial to safely resolve likely correspond to a real security
vulnerability.

Moreover, false positives are, in the median case, not of a sufficient number to
overwhelm stakeholders, making the workflow manageable even upon first use, and
after which the number of diagnostics can be reduced through explicit
configuration adjustments.

A generic, default security policy can never, and is not intended to, replace
project-specific configuration; it simply serves as a stable starting point for
later iteration and eases stakeholders into the tool's usage patterns.

In conclusion, taking into account the considerations expressed in the
present subsection, this work considers @pg-base-policy[] successfully achieved
and deems @rq-base-policy[] to have been satisfactorily answered.

=== Vulnerability Detection

The following research question, @rq-find-vulns[], asks whether information flow
analysis can identify true security vulnerabilities in Go projects without
domain-specific knowledge. This work connects that question with
@pg-evaluation[], which refers to the evaluation of the developed materials
through the auditing of popular Go projects.

The referenced goal is directly fulfilled by the real-world analysis evaluation
effort described in @eval:real-world and already discussed earlier in this
chapter, in connection with the first research question. An appropriate method
was used to define three datasets based on different metrics of popularity, each
dataset was stratified to guarantee attribute representation, and each stratum
was then pseudo-randomly sampled, obtaining $300$ Go projects.

#let share(count, total) = zero.num(
  calc.round(100 * count / total), // integer precision for simplicity
  suffix: [%],
)

The $371$ modules extracted from those sampled projects were subject to
individual audit with `glowy-cli`, orchestrated by `glowy-eval`, and a total of
$348$ successfully completed analysis, of which $222$ (#share(222, 348))
reported no diagnostics and $126$ (#share(126, 348)) had at least one detected
warning or error.

The final evaluation run took approximately 2h20min, so it would have been
feasible to consider more projects and have more datapoints, but increasing the
sample size would select virtually the entire Dataset C (stratum size of 59) and
it would put too much load on the manual results processing, which is the chief
bottleneck when thousands of diagnostics are emitted.

As mentioned in @discussion:rq:analyzer and described in
@eval:results:effectiveness, true security vulnerabilities were identified in
several real-world Go projects, so this work considers @rq-find-vulns[]
positively answered and @pg-interpret[] accomplished.

#pagebreak()

=== Prevalence of Security Issues

The fourth and final stated research question, @rq-prevalence[], concludes the
work by focusing on the overall presence of detectable security issues in
popular Go projects. @pg-interpret[] complements it, comprising the
interpretation of evaluation results and the general discussion of the
applicability of @ifc in Go.

Naturally, this again ties with the auditing of $371$ real-world Go modules, as
extracted from $300$ popular open-source projects, with an overview of the
results presented in the aforementioned @eval:results.

Here, the overall prevalence cannot be directly quantified, since it was deemed
too costly (in terms of workload) to conduct a fine-grained examination of each
of the $2288$ collected problem reports, understanding each of the $1539$
illegal flows in the context of their source code and individual module purpose,
in addition to investigating the $23$ other modules for which analysis did not
complete.

This would have almost certainly inflated the results processing stage into a
multi-week endeavor, given that while it is simple for project stakeholders to
easily understand reported flows, it is much more difficult for those with zero
domain knowledge (including regarding the very nature and exposure of the
project) to swiftly and systematically comprehend the high-level operations
represented by the reported control paths, as well as additionally determine if
they are affected by an exploitable vulnerability.

In addition, all the time spent manually inspecting each finding would only have
yielded dubious conclusions, as categorizations performed without any
domain knowledge would have a decreased correctness confidence.

Instead, this work opted to perform a high-level survey and cursory review of
the reported findings, only performing a finer-grained inspection for some of
the modules, according to what seemed to exhibit interesting properties.

As such, no exact number can be given regarding detectable vulnerability
prevalence across the results set nor generalized to the entire population
under consideration, but there is provably some degree of prevalence, since
multiple true positives were identified.

Nevertheless, such security issues do not appear to be very widespread in
high-profile projects, as approximately two thirds of completed audits did not
report any problem, only a quarter of completed audits found insecure
information flows, and few of those policy violations were substantial.

#pagebreak()

Concretely, while all errors truthfully represent the literal presence of a
flow deemed insecure, the majority of them do not truly constitute security
issues, either because an in-path sanitizer sufficiently decreases the
propagation's information content, because the exploitation path is not
accessible or is sufficiently protected, or because the candidate issue is
intentional and accepted in accordance with the project's assumptions and risk
assessment.

Overall, static taint tracking combined with flexible security controls
definitely shows promising results, and future work not bound to the same
time and complexity restrictions would almost certainly achieve more refined
results. It is thus this degree project's view that @ifc is an appropriate
and valuable set of mechanisms when used for security vulnerability detection
within the Go programming language.

In light of the stated arguments, this work considers @rq-prevalence[] partially
answered, with @pg-interpret[] being fulfilled by the present subsection.

== Limitations

While this work strives to develop the best possible contributions for the
stated goals, aiming for comprehensiveness, soundness, and precision, it is
still bound to the inevitable time and complexity constraints associated with a
degree project.

As such, there are thus various aspects that were deemed too costly to support
up to the extent that would otherwise be desired or expected, with certain parts
having to be heavily simplified or even put aside completely. In particular,
Glowy is a research prototype and is not feature-complete, nor is the
implementation intended for real production usage at its current state.

@methods already describes, under its @methods:subset, several language-level
features and patterns that are not considered part of the supported subset of
Go, even if it would be desired to have full language support, for evident
reasons. In particular, heap modeling and pointer aliasing, interface-based
dynamic dispatch, reflection, and concurrency ordering are some of the most
significant areas where this work would greatly benefit from improvements,
but the mechanisms required to support them would immensely and unmanageably
increase overall analyzer complexity.

This is especially disappointing for the latter case, as concurrency is Go's
most essential distinguishing trait, but it would also be an overly involved
process to model it soundly and precisely. For instance, correct modeling of the
highlighted race condition in @discussion:limitations:racy-read would require
tracking goroutine lifetimes as well as reasoning for synchronization and
happens-before.

#codly(
  header: pad(
    y: 0.5em,
    [`ifc-benchmarks/suite-x-failures/14-racy-read/main.go`],
  ),
  highlighted-lines: (11, 13),
)
#figure(
  ```go
  package main
  import "fmt"
  // glowy::label::{red}
  const initial = 0
  // glowy::label::{blue}
  const updated = 1
  func main() {
    shared := initial
    observations := make(chan int)
    go func() {
      observations <- shared
    }()
    shared = updated
    observed := <-observations
    // glowy::assert::{red, blue}
    fmt.Println(observed)
  }
  ```,
  caption: [Example race condition between goroutines],
) <discussion:limitations:racy-read>

This case, as shown on @discussion:limitations:racy-read, is not supported
because goroutines are analyzed as immediate calls, meaning that any
potential interleaving or execution delays are not considered.

In addition, one of the most notable limitations is lack of cross-dependency
resolution and handling, with analysis focusing exclusively on one module and
using black-box techniques to model all external code. This leads to severe
lacks of precision and major soundness faults, even if in many cases it is still
correct. Recursively downloading and analyzing all dependencies would introduce
network dependency (i.e., limit sandboxing) and configure much more complex
handling, possibly for no significant benefits in findings.

Moreover, the current label backtrace mechanism does not support representing
revocations in the taint trace chain, since the operation corresponds to the
_absence_ of a label, which is not seamlessly compatible with the current tree
structure. This means that error diagnostics might be confusing for users who
do not realize revocation is taking place. Ideally, the taint trace would track
which directive affected each backtrace, but that would increase complexity and
does not handle the case where a label is fully revoked, becoming $bot$, since
it does not make sense to propagate a Bottom label.

Furthermore, a significant problem experienced during real-world analysis is
regarding the systematic and robust handling of build-tag constraints, since
there is no unified way to know which combinations of custom user-defined tags
are valid, since it is common for there to be some exclusivity or dependency
relationships between them, though purely as a convention.

For the real-world analysis procedure, pinning execution to just a constant set
of build tags, e.g., `linux && amd64`, would probably significantly reduce
warning count, as the analyzer takes the union of all errors across all
permutations. This is not done due to time constraints (since it means that the
tool must support build tag pinning) but also because it is somewhat
disingenuous to presume that some arbitrary combination is representative of
the entire module, thus ensuing in misleading results.

In general, the reason why Glowy performs this enumeration and exhaustive
analysis of build-tag permutations is out of a concern for usability, since
some obscure @cli flag for build tag selection could lead to stakeholders always
executing analysis with the same tags, and thus perhaps missing real insecure
flows that would not be detected because the respective file is never checked,
leaving to a false sense of security, which is arguably worse than the current
exhaustive handling.

Finally, as already mentioned in @intro:enforcement:static, analysis based on
source code assumes that the final set of executed instructions is actually
faithful to the original source code, which means that the compiler, target
@os, processor, and the entire adjacent chain is implicitly trusted. However,
this is not a major problem, as the purpose with the developed analyzer is not
to assert that execution will be secure, but rather just to detect specific
cases when an abstract program is not.

In summary, this work presents a number of significant limitations, as a result
of the necessarily applicable time and simplicity constraints, but they do not
compromise the overall integrity of the contributions, as can be seen from the
evaluation results.

#pagebreak()

== Future Work

In connection with the limitations presented in the preceding section, there are
significant points of improvement that can be considered for future developments
to this work within static taint analysis of Go programs.

First of all, it is paramount that the analyzer should be extended up to the
point of full language support, so that any truly arbitrary Go programs may be
subject to analysis. Argument write-backs are especially important and should
not require a major refactor, as it should be possible to generalize the
existing plumbing for capture write-backs.

Secondly, Glowy's @cli application should support more output formats for more
structured logging and tracking of findings, especially one compliant with the
conventional @sarif specification @fanning2020sarif, so that Glowy can be more
easily integrated with generic tooling and adheres to standard interoperability
practices.

Thirdly, it should be possible to specify sets of mutually exclusive build tags
in the `glowy.toml` project configuration, as well sets of tags that are always
satisfied in tandem, in an attempt to avoid analyzing illegal permutations.

Furthermore, it might make sense to consider pre-analyzing the entire Go
standard library and storing precise taint state for each exported member,
including synthetics-based outcomes for functions and methods. This data could
then be embedded statically within the analyzer and used instead of blackboxing
standard library accesses and calls, which should lead to increased overall
precision due to usage ubiquity, though at the cost of larger binary size and
requiring regeneration upon updates.

Moreover, more refined cross-dependency handling is essential to increase
precision and offer true soundness guarantees, as blackbox handling is an
approximation and not correct in the general case.

Finally, and as a broader scope expansion, it should be considered whether it
would be viable to support each of the additional covert information flow
channels identified in @bg:ifc:covert, such as timing- and exhaustion-based.
This likely comprises, however, a major extension to the existing model and
implementation, so it would possibly be preferred to only consider a subset of
each kind at, at first; for instance, modeling panic-to-recover chains and
adding the `panic` function to the existing early-abort deferred branch labels
mechanism is much simpler than supporting all termination channels.

#pagebreak()

== Comparison to Related Work <discussion:related>

This section briefly compares the present degree project's contributions against
the existing projects introduced in @bg:related.

Firstly, Gotcha's pointer handling makes it more precise than Glowy for all
related flows, but it is, in most cases, strictly inferior to Glowy in terms of
realistic, practical usage, since it only has support Go 1.7 and earlier,
meaning that any modern functionality is not implemented, including modules,
generics, and iterable functions in for-range constructs.

Secondly, GoKart has @sarif output and provides a built-in set of ready-made
checks, targeting vulnerability classes such as @sql injections and @ssrf, and
allows project-extensible configuration through @yaml files. However, Glowy's
supported security controls are much finer-grained, as GoKart only propagates a
single "high"-like boolean taint and allows no conditional selection of sources
and sinks (e.g., by result value position). Importantly, GoKart does not track
control dependencies, i.e., it has no _pc_/branch label, and it is also
discontinued, so Glowy supports more recent version targets.

Thirdly, Go Flow Levee also supports configurable taint analysis, but it does
not ship with any base policy, requiring users to define one before first use.
It is intraprocedural, only supports whole types and struct fields as sources
and whole functions as sinks or classifiers, and, as with GoKart, Go Flow Levee
does not support tracking control dependencies, its taint analysis is bound to a
single boolean taint, and it has also been abandoned for several years.

Gosec, in contrast, is actively maintained and likely the most robust of the
existing tools, including taint analysis rules in its broader static analysis
toolkit, though also without support for detecting implicit flows. It has better
precision than Glowy due to pointer handling, but Glowy is more suitable for
project-specific security policies, as Gosec can only have simple rules added
programmatically and is not designed around that principle. It also only has one
boolean taint, although it is rule-specific.

Gruber's Taint Analyzer (`picatz/taint`) is also under active development and
emits @sarif output, besides supporting precise alias handling, allowing for
detailed project-specific configuration, and including various built-in rules.
It tracks only a single boolean taint, which means no distinction between secret
and untrusted data and an assumption that a sanitizer is applicable to
both properties. It also does not track control flow dependencies.

Finally, the Argot Taint Analyzer is the strongest existing tool, performing
pointer-aware and precise interprocedural analysis based on @regex\-based
security policy configuration, though no initial configuration is provided.
It can also take implicit flows into account (opt-in), but merely rejects all
branches on tainted values, rather than propagating a branch label, so it cannot
distinguish harmless branches from branch-dependent critical operations. This
no-branching-on-secret policy is more robust and protects more against side
channels, but is much more restrictive. Additionally, Argot notably advertises
soundness guarantees unless concurrency, `unsafe`, or reflection are used in
the program under analysis.

Overall, Glowy offers three main advantages over all the aforementioned
projects, in addition to supporting the latest Go release (Go 1.26), which is
not the case for several of them.

The first chief advantage is Glowy's *flexibility,* which enables stakeholders
to define powerful and intuitive security controls in various ways, as
specifically or broadly as required. This work's multi-tag labels allow
multifaceted and extensible security policies, prioritizing expressiveness,
modularity, and versatility; Glowy supports, for instance, revoking a label
without marking it universally safe. Though a single boolean taint is simpler to
use, it severely limits applications, and it can be mimicked with labeling
(e.g., ${"secret"}$) if desired. Glowy is generic when required and simple when
preferred.

Glowy's axes mechanic, in particular, permit very powerful constructions,
promoting the separate reasoning about orthogonal concerns. By having axis
binding be optional, tags seamlessly support a natural learning curve; unbound,
plain tags are preferred for simple situations, but stakeholders can then use
axes to unlock support for more complex use cases, without having to enable any
new feature or learning any new controls, as both kinds are already supported
for free under the same name, and can even coexist simultaneously in the same
labels.

The second principal advance is Glowy's support for *tracking implicit flows,*
which form a significant part of most projects' flows and can have a strong
propagation impact, especially for confidentiality. Glowy's handling of implicit
flows is not limited to just basic branching-on-secret, but also comprises
several mechanisms targeting Go-specific concerns, such as tainting the rest of
a function after ```go if secret { return; }```, and analogously for other
early-abort utilities (e.g., ```go break 'label```), among other mechanics.

The third primary advantage Glowy offers in comparison to the referenced
existing tools is *rich problem reporting,* characterized by concise and simple
to understand error messages, as well as intuitive taint history trace
visualizations based on annotated code snippets which enable users to easily
understand what is insecure and why.

In summary, Glowy introduces substantial new contributions to the research
space, including when compared to the relevant tools within the Go ecosystem,
especially in terms of flexibility, specialized modeling, and usability.

== Reflections

The present degree project and its contributions constitute a significant
advancement in the field of security tooling for the Go programming language,
which is widely used and of growing relevance. The developed static taint
analyzer is designed to conjugate strong security properties with intuitive and
flexible handling.

In particular, through its simple controls and the provided Base Security
Policy, this work makes it more accessible for stakeholders to adopt Glowy,
even without formal security training. This means that more projects can use a
security tool and thus detect potential issues earlier, leading to more secure
software in general.

Digital systems are fundamental to society in this day and age, so increased
confidentiality, integrity, and availability has crucial economic, social, and
environmental implications. This degree project thus contributes, however
marginally, to a better world.

#pagebreak()

== Summary

In short, this degree project answers four complementing research questions,
accomplishing its stated goals to further knowledge regarding @ifc:long when
applied to the Go programming language.

It comprises robust advancements to the field, offering strong advantages in
comparison to existing work within the Go ecosystem, and sets the pace for
future work in the same area.

Overall, this work contributes towards a world with more secure software.
