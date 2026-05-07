#import "@preview/kthesis:0.1.5": kth-thesis, setup-appendices

#import "@preview/glossarium:0.5.8": (
  make-glossary, print-glossary, register-glossary,
)
#import "./acronyms.typ": acronyms
#show: make-glossary
#register-glossary(acronyms)

// --------------------------------------------------------------------- //
// ---------- MAIN THESIS TEMPLATE ENTRYPOINT & CONFIGURATION ---------- //
// --------------------------------------------------------------------- //
#show: kth-thesis.with(
  primary-lang: "en",
  localized-info: (
    en: (
      title: "Glowy: Efficiently Tracking Information Flow in Go",
      subtitle: "A Modern Approach to Problem-Solving", // TODO
      abstract: include "./content/abstract-1-en.typ",
      keywords: ("Dogs", "Chicken nuggets"),
    ),
    sv: (
      title: "Svenska Översättningen av Titeln",
      subtitle: "Svenska Översättningen av Undertiteln",
      abstract: include "./content/abstract-2-sv.typ",
      keywords: ("Hundar", "Kycklingnuggets"),
    ),
    pt: (
      alpha-3: "por",
      title: "Tradução em Português do Título",
      subtitle: "Tradução em Português do Subtítulo",
      abstract-heading: "Resumo",
      keywords-heading: "Palavras-chave",
      abstract: include "./content/abstract-3-pt.typ",
      keywords: ("Cães", "Nuggets de frango"),
    ),
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
  opponents: none, // TODO
  presentation: none,
  acknowledgements: include "content/acknowledgements.typ",
  extra-preambles: (
    (heading: "Acronyms and Abbreviations", body: print-glossary(acronyms)),
  ),
  doc-date: datetime.today(), // TODO
  doc-city: "Stockholm",
  doc-extra-keywords: ("master thesis",),
  with-for-diva: true,
  style: (
    use-arial: false,
    more-sans-serif: false,
  ),
)

#include "./content/ch01-introduction.typ"
#include "./content/ch02-background.typ"
#include "./content/ch03-method.typ"
#include "./content/ch04-the-thing.typ"
#include "./content/ch05-results.typ"
#include "./content/ch06-discussion.typ"
#include "./content/ch07-conclusion.typ"

#bibliography("references.yaml", title: "References")

#show: setup-appendices
#include "./content/zz-a-usage.typ"
#include "./content/zz-b-else.typ"
