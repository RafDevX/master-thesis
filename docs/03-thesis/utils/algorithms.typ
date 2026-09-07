#import "./dependencies.typ": lovelace

#let setup-algorithms(body) = {
  // hide caption since already included via lovelace, but we cannot just not
  // have any caption either, otherwise the `outline` would not show it
  show figure.caption.where(kind: "algorithm"): it => []

  body
}

#let algorithm(caption, body) = {
  figure(
    lovelace.pseudocode-list(
      hooks: 0.5em,
      booktabs: true,
      numbered-title: caption,
      line-number-alignment: top + right,
      line-number-supplement: [line],
      body,
    ),
    caption: caption,
    kind: "algorithm",
    supplement: [Algorithm],
  )
}
