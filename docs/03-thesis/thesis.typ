#import "./acronyms.typ": acronyms
#import "./utils/algorithms.typ": setup-algorithms
#import "./utils/code-blocks.typ": setup-codly
#import "./utils/dependencies.typ": codly, glossarium, kthesis
#import "./utils/enum-refs.typ": setup-enum-refs
#import "./utils/tables.typ": setup-tables

#import codly: codly, codly-init
#import glossarium: make-glossary, print-glossary, register-glossary
#import kthesis: kth-thesis, setup-appendices

#show: make-glossary
#register-glossary(acronyms)

#show: setup-tables
#show: setup-enum-refs
#show: setup-algorithms
#show: codly-init
#setup-codly()

// Use "at al." when citing references with 3+ authors, per IEEE Style Guide.
// Upstream wrongly does so only at 7+ authors, so we use a modified file.
// https://github.com/typst/hayagriva/issues/164
// This does not change bibliography style, only in-text citations.
#set cite(style: "./assets/ieee-et-al-3.csl")

// --------------------------------------------------------------------- //
// ---------- MAIN THESIS TEMPLATE ENTRYPOINT & CONFIGURATION ---------- //
// --------------------------------------------------------------------- //
#show: kth-thesis.with(
  primary-lang: "en",
  localized-info: (
    en: (
      title: "Glowy: Flexibly Tracking Information Flow in Go Programs",
      subtitle: "Striving for Soundness, Efficiency, and Usability",
      abstract: include "./content/abstract-1-en.typ",
      keywords: ("Information flow", "Static analysis", "Taint analysis", "Go"),
    ),
    sv: (
      title: "Svenska Översättningen av Titeln",
      subtitle: "Svenska Översättningen av Undertiteln",
      abstract: include "./content/abstract-2-sv.typ",
      keywords: ("Ord1", "Ord2"),
    ),
    // pt: (
    //   alpha-3: "por",
    //   title: "Tradução em Português do Título",
    //   subtitle: "Tradução em Português do Subtítulo",
    //   abstract-heading: "Resumo",
    //   keywords-heading: "Palavras-chave",
    //   abstract: include "./content/abstract-3-pt.typ",
    //   keywords: ("Cães", "Nuggets de frango"),
    // ),
  ),
  authors: (
    (
      first-name: "Rafael",
      last-names: "Serra e Oliveira",
      email: "rmfseo@kth.se",
      user-id: "rmfseo",
      school: "School of Electrical Engineering and Computer Science",
    ),
  ),
  supervisors: (
    (
      first-name: "Musard",
      last-names: "Balliu",
      email: "musard@kth.se",
      user-id: "musard",
      school: "School of Electrical Engineering and Computer Science",
      department: "Department of Theoretical Computer Science",
    ),
  ),
  examiner: (
    first-name: "Philipp",
    last-names: "Haller",
    email: "phaller@example.com",
    user-id: "phaller",
    school: "School of Electrical Engineering and Computer Science",
    department: "Department of Theoretical Computer Science",
  ),
  course: (
    code: "DA237X",
    credits: 30,
  ),
  degree: (
    code: "TCYSM",
    name: "Master's Program, Cybersecurity",
    subject-area: "Computer Science and Engineering",
    kind: "Master of Science",
    cycle: 2,
  ),
  national-subject-categories: ("10201", "10206", "10211"),
  school: "EECS",
  trita-number: "2026:0000", // TODO
  host-company: none,
  host-org: none,
  opponents: ("John Doe",), // TODO
  presentation: (
    language: "en",
    slot: datetime(
      year: 2026,
      month: 8,
      day: 25,
      hour: 11,
      minute: 0,
      second: 0,
    ),
    online: none, // TODO
    location: (
      room: "4523 (Stefan Arnborg)",
      address: "Lindstedtsvägen 5",
      city: "Stockholm",
    ),
  ),
  cover-image: none,
  acknowledgements: include "content/acknowledgements.typ",
  extra-preambles: (
    (
      heading: "List of Algorithms",
      body: outline(title: none, target: figure.where(
        kind: "algorithm",
        outlined: true,
      )),
    ),
    (
      heading: "Acronyms and Abbreviations",
      body: print-glossary(
        acronyms,
        disable-back-references: true,
        shorthands: (
          "short",
          "long",
          "plural",
          "longplural",
        ),
      ),
    ),
  ),
  doc-date: datetime.today(), // TODO
  doc-city: "Stockholm",
  doc-extra-keywords: ("master thesis",),
  with-for-diva: false,
  style: (
    use-arial: false,
    more-sans-serif: false,
    fancy-chapters: true,
  ),
)

#include "./content/ch01-introduction.typ"
#include "./content/ch02-background.typ"
#include "./content/ch03-methods.typ"
#include "./content/ch04-glowy.typ"
#include "./content/ch05-evaluation.typ"
#include "./content/ch06-discussion.typ"
#include "./content/ch07-conclusion.typ"

#bibliography("references.yaml", title: "References")

#show: setup-appendices
#include "./content/zz-a-usage.typ"
#include "./content/zz-b-results.typ"
