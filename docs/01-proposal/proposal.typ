#import "../common/simple.typ": setup_simple

#show: setup_simple.with(
  title: "Tracking Information Flow in Go",
  doc_name: "Degree Project Proposal",
  keywords: ("information flow", "non-interference", "static analysis"),
  written_date: datetime(year: 2024, month: 12, day: 12),
)

= Thesis Title
// [Provide a preliminary title, which gives an indication of what the
// degree project will be about]

Tracking Information Flow in Go

= Background <background>
// [Name and briefly describe the research area within which the project
// is being carried out. Describe how the project is connected to current
// research or development. Describe why the project is of interest and
// to whom, and in particular explain the interest of the organization or
// company within which the project is carried out.]

An important problem within cybersecurity is how to systematically separate what
is trusted or secret from untrusted or public data, especially in terms of what
information should be accessible or used where. This aligns with the high-level
aspects of *Confidentiality* and *Integrity* of the CIA triad and has widespread
implications for how security vulnerabilities might manifest within software
products.

Theoretical models already exist and have been shown to be mathematically
robust, such as initially proposed by Bell and LaPadula in 1973 @bell-lapadula
and further developed by Denning in 1976 @dorothy. However, it would be
desirable to enforce this on arbitrary programs without relying on them to
implement one of these mechanisms correctly. Such a zero-trust approach would
allow principals to independently verify whether programs are secure (from this
perspective) and equip developers with the necessary tooling to find
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
relevant throughout the world, such as
#link("https://github.com/docker", [Docker]) and
#link("https://github.com/rclone/rclone", [rclone]), which showcases its growing
relevance.

Go is compiled, statically typed, and counts with a number of interesting
constructs that while on the one hand extend its usefulness for programmers, on
the other hand also present new challenges for information flow control such as
concurrency (via _goroutines_) and message-passing (via _channels_).

The student has previously co-authored a Rust tool called
#link("https://github.com/ist199211-ist199311/glowy-langsec", "Glowy") as part
of a project within the course
#link("https://www.kth.se/student/kurser/kurs/DD2525?l=en",
 "DD2525 Language-Based Security") which implements taint tracking to perform
static analysis of Go projects and detect insecure flows. However, this was
merely a prototype with minimal language support and it is now desired to extend
it further so that it can be used in real-life settings.

This proposed extension and especially the necessary theoretical developments
that precede it is what forms the basis for the student's degree project work.

#pagebreak()

= Research Questions
// [A degree project must investigate a specific research/technical
// question. Provisionally state the question that the project will
// target.]

This degree project will aim to investigate:

#[
  #set enum(
    full: true,
    numbering: (..nums) => strong[RQ#numbering("1.1.", ..nums)],
  )

  + How to efficiently track information flow in Go programs through static
    analysis?
    + How to systematically detect flows of secret data to public outputs?
      #smallcaps[(Confidentiality)]
    + How to systematically detect flows of untrusted data to critical parts?
      #smallcaps[(Integrity)]
  + Can information flow control effectively identify security vulnerabilities
    in arbitrary Go programs?
  + How prevalent are detectable security vulnerabilities in popular
    production-grade tools and frameworks written in Go?
]

= Hypothesis
// [What is the expected outcome of the investigation?]

It is expected that the degree project yields at least a partial success in
terms of establishing a theoretical method for efficiently and effectively
tracking information dependencies in Go programs. Nevertheless, the resulting
model is likely to be significantly conservative in various aspects, such as by
reporting potentially insecure flows for all construct usages which have their
effective safety dependent on runtime constraints (e.g., dynamically indexing an
array of elements with different classifications).

Furthermore, it is not probable that the project outcome allows for drawing
definite conclusions regarding security vulnerability prevalence across
source-available Go projects, but it may nevertheless serve as a basis for
future, larger-scale studies.

= Research Method
// [What method will be used for answering the research question, e.g.,
// how will observations be collected and conclusions drawn?]

Firstly, a theoretical procedure will be devised for performing information flow
static analysis on Go source code, taking into account the different
language-specific constructs and the possible interactions between them. This
will be based on previous work already published for other languages and
pseudo-languages.

Secondly, the aforementioned tool *Glowy* will be refactored and extended to
implement such a model of information tracking analysis tailored to Go code.
This will allow for testing and consequently easier detection of inherent flaws
in the proposed algorithm, therefore driving a continuous cycle of improvements
to the overall work.

Finally, the finished tool will be run against a number of various
production-grade Go-based projects in order to both attempt to identify security
vulnerabilities present across their codebase and also to find and mitigate
weaknesses in the tool itself. Due to time constraints, it is likely that very
few projects will be able to be tested, but in any case the developed
methodology may be generalized and further applied in future work.

= Student's Background
// [Describe the knowledge (courses and/or experiences) you have that
// makes this an appropriate project for you.]

The student has, as previously mentioned, taken
#link("https://www.kth.se/student/kurser/kurs/DD2525?l=en",
  "DD2525 Language-Based Security"), wherein he learned about information flow
control and co-developed *Glowy,* a tool central to this proposal. He also has a
solid basis of cybersecurity in general, having achieved grade A in a myriad of
relevant courses as a student in KTH's Master's Program in Cybersecurity,
including #link("https://www.kth.se/student/kurser/kurs/DD2391?l=en",
  "DD2391 Cybersecurity Overview") (which he also assisted in teaching as
_Amanuens_).

Moreover, he has obtained grade A in
#link("https://www.kth.se/student/kurser/kurs/DD2481?l=en",
  "DD2481 Principles of Programming Languages") and
#link("https://www.kth.se/student/kurser/kurs/DD2482?l=en",
  "DD2482 Automated Software Testing and DevOps"), where he learned fundamentals
in programming languages theory and usable continuous testing (respectively),
which may prove invaluable for this proposed endeavor.

#pagebreak()

= Suggested Examiner at KTH
// [You may suggest an examiner at KTH. State if you have been in contact
// with the examiner and received a preliminary expression of interest to
// serve as examiner.]

Prof. Philipp Haller (#link("mailto:phaller@kth.se")), Associate Professor at
EECS, has shown preliminary interest in serving as examiner for this degree
project.

= Suggested Supervisor at KTH
// [You may suggest a supervisor at KTH. State if you have been in
// contact with the supervisor and received a preliminary expression of
// interest to serve as supervisor.]

Prof. Musard Balliu (#link("mailto:musard@kth.se")), Associate Professor at
EECS, has shown preliminary interest in serving as a supervisor for this degree
project.

= Resources
// [What is already available at the company (or other host institution)
// in the form of previous projects, software, expertise, etc. that the
// project can build on?]

As detailed in @background, the student has previously developed a tool that
will be very useful as a base and starting point for this degree project.

The suggested supervisor, Prof. Musard Balliu, has extensive experience teaching
and researching information flow control, as well as a wide network of renowned
contacts with the necessary expertise to provide support throughout the
project's time span.

= Eligibility
// [Verify that you are eligible to start your degree project, that is,
// that you fulfill the basic requirements of starting the project, and
// also have completed all the courses that are relevant for the
// project.]

The student is enrolled in the *Master's Program in Cybersecurity* at KTH
(#link("https://www.kth.se/en/studies/master/cybersecurity", "TCYSM")), through
which he is expected to have completed 91.5 ECTS credits in courses at the
second cycle level by the end of HT24. This includes
#link("https://www.kth.se/student/kurser/kurs/AK2030?l=en",
  "AK2030 Theory and Methodology of Science"), which the student obtained a
passing grade for in Period 1 of 2024/2025.

= Study Planning
// [List all the courses that you will need to complete during or after
// the degree project, and describe how and when you plan to complete
// those courses. This is aimed to ensure that the thesis really is one
// of the last elements of your education.]

Simultaneously with the degree project, the student plans to take the remaining
2 modules of #link("https://www.kth.se/student/kurser/kurs/DD2303",
  "DD2303 The Cybersecurity Engineer's Role in Society") in VT25, which
correspond to a total of 0.5 ECTS credits.

This, together with #link("https://www.kth.se/student/kurser/kurs/DA237X?l=en",
  "DA237X"), is sufficient for the student to graduate with a Master's degree.
No other courses will be taken.

#bibliography("references.yaml", title: "References")
