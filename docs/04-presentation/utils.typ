#import "./template.typ": *

#let ITEM-BY-ITEM = false

#let item-by-item = if ITEM-BY-ITEM { item-by-item } else { it => it }

#let items-with-notes = (
  offset: 0,
  start-empty: true,
  tight: false,
  ..items,
) => {
  if start-empty and ITEM-BY-ITEM {
    pause

    offset += 1
  }

  item-by-item({
    for item in items.pos() {
      [- #item.item]

      if not tight {
        parbreak()
      }
    }
  })

  for (i, item) in items.pos().enumerate(start: 1) {
    let note = item.at("note", default: none)

    if note != none and note != [] {
      let subslide = if ITEM-BY-ITEM {
        i + offset
      } else {
        none
      }

      speaker-note(subslide: subslide, note)
    }
  }
}

// this should REALLY not be needed, but a million alternative and smarter
// solutions were tried and did not work; typst and touying really clash here
#let hardcode-figure-number = (kind, num) => {
  counter(figure.where(kind: kind)).update(num)
}
