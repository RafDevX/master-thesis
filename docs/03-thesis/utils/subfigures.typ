#import "./dependencies.typ": headcount, subpar

#let subfigures(..args) = subpar.grid(
  ..args,
  numbering: headcount.dependent-numbering("1.1"),
  numbering-sub-ref: headcount.dependent-numbering("1.1(a)"),
)
