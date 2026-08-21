#import "./template.typ": *
#import "../03-thesis/acronyms.typ": acronyms
#import "../03-thesis/utils/code-blocks.typ": setup-codly
#import "../03-thesis/utils/dependencies.typ": codly, glossarium
#import "../03-thesis/utils/enum-refs.typ": wrapped-enum-numbering

#import codly: codly-init
#import glossarium: make-glossary, print-glossary, register-glossary

#let HANDOUT = false

#show: codly-init
#show: make-glossary

// typst eval --root .. 'query(<pdfpc-file>).first().value' \
//   --in ./presentation.typ > ./presentation.pdfpc
#let pdfpc-config = pdfpc.config(
  duration-minutes: 25,
  last-minutes: 5,
  note-font-size: 21,
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
    frozen-counters: (
      counter(figure.where(kind: raw)),
    ),
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

#title-slide()

#speaker-note[
  Hello
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

  components.adaptive-columns(outline(depth: 1))
}

= Section A

== Heading

hello @thompson1984trusting

...

#title-slide()
