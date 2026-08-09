#import "./dependencies.typ": ansi-render

#let cmd-output(body, text-size: 1em, caption: none, label: none) = {
  pad(
    // figures are centered so we can give a ton of negative padding and it'll
    // only actually use up what it needs
    x: -100pt,
    [#figure(
        // box is required so the render doesn't get left-aligned wrt the
        // caption; we only want to override the figure's center alignment
        // specifically for the rendered code, not the whole layout
        box(
          align(start, ansi-render.ansi-render(
            // we trim the body because files often have a conventional newline
            // at the end, which would look strange here (extra bottom inset)
            body.trim(),
            font: none,
            size: text-size,
            inset: 7.5pt,
            radius: 5pt,
            theme: ansi-render.terminal-themes.one-half-dark,
          )),
        ),
        caption: caption,
      ) #label],
  )
}
