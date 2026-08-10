#let setup-tables(body) = {
  // more polished look, with stroke only around header and bottom of table
  set table(
    stroke: (_, y) => (
      top: if y <= 1 { 1pt } else { 0pt },
      bottom: 1pt,
    ),
  )

  body
}
