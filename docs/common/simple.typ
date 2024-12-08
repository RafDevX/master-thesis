
#let kthblue = rgb("#004791")
#let kthnavy = rgb("#000061")

#let full_author = [Rafael Serra e Oliveira (#link("mailto:rmfseo@kth.se"))]

#let header(title, doc_name) = {
  context if [#here().page()] == [1] { } else {
    set text(10pt)
    smallcaps(title)
    h(1fr)
    smallcaps[KTH MSc Cybersecurity: #doc_name]
    line(length: 100%, stroke: 0.5pt + rgb("#888"))
  }
}

#let footer() = {
  set text(10pt)
  line(length: 100%, stroke: 0.5pt + rgb("#888"))
  full_author
  h(1fr)
  [Page ]
  context counter(page).display("1 of 1", both: true)
}

#let setup_simple(
  title: none,
  doc_name: none,
  keywords: (),
  written_date: none,
  content,
) = {
  set document(
    title: title,
    author: "Rafael Serra e Oliveira",
    keywords: keywords + ("cybersecurity", "master thesis"),
    date: written_date,
  )

  set page("a4", header: header(title, doc_name), footer: footer())
  set par(justify: true)
  show link: it => text(fill: kthblue, underline(it))

  align(
    center,
    {
      grid(
        columns: (auto, auto),
        rows: (95pt, auto),
        align: (center + horizon, start + horizon),
        column-gutter: 1.5em,
        image("./KTH_logo_RGB_bla.svg"),
        {
          block(text(size: 16pt, strong(title)))
          block(text(size: 14pt, strong(doc_name)))

          v(1fr)

          set par(spacing: 0.8em)
          set text(size: 12pt)
          block(strong(full_author))
          block({
            [DA237X --- ]
            smallcaps(written_date.display("[month repr:long] [year]"))
          })
          block(
            text(
              fill: kthnavy,
              strong(
                delta: 150,
                smallcaps[KTH Royal Institute of Technology],
              ),
            ),
          )
        },
      )

      v(0.5em)
      line(length: 70%, stroke: 1.5pt + black)
      v(0.5em)
    },
  )

  set heading(numbering: "1.1.")
  show heading: it => text(fill: kthnavy, it)

  content
}
