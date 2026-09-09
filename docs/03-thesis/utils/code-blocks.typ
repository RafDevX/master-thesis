#import "./colors.typ"
#import "./dependencies.typ": codly

#import codly: codly

#let setup-codly() = {
  codly(
    zebra-fill: none,
    fill: luma(240),
    highlighted-default-color: colors.code-highlight,
    // no option to make text white, so we have to use a custom formatter
    // (default: https://github.com/Dherse/codly/blob/main/src/lib.typ#L1345)
    lang-format: (lang, icon, color) => box(
      fill: color,
      inset: 5pt,
      stroke: 1pt + color.darken(50%),
      text(
        fill: white,
        lang,
      ),
    ),
    languages: (
      go: (name: "Go", color: colors.go-blue),
      sh: (name: "Shell", color: rgb("#293138")),
      sql: (name: "SQL", color: orange),
      toml: (name: "TOML", color: rgb("#7b341e")),
    ),
  )
}
