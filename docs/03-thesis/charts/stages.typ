#import "../utils/charts.typ": *

#let by-sloc = completed.sorted(
  key: row => number(row, "sloc"),
)

#let sloc-quartile(index) = {
  by-sloc
    .enumerate()
    .filter(((position, _)) => (
      calc.min(3, calc.floor(4 * position / by-sloc.len())) == index
    ))
    .map(((position, row)) => row)
}

#let cost(rows, field, repeated: false) = sum(
  rows.map(row => {
    let time = number(row, field)

    if repeated {
      time * number(row, "n_build_constraint_permutations")
    } else {
      time
    }
  }),
)

#let shares = range(4).map(index => {
  let rows = sloc-quartile(index)

  let parsing = cost(rows, "parsing_time")
  let stage-1 = cost(rows, "avg_stage1_time", repeated: true)
  let stage-2 = cost(rows, "avg_stage2_time", repeated: true)
  let stage-3 = cost(rows, "avg_stage3_time", repeated: true)
  let total = parsing + stage-1 + stage-2 + stage-3

  (
    parsing: 100 * parsing / total,
    stage-1: 100 * stage-1 / total,
    stage-2: 100 * stage-2 / total,
    stage-3: 100 * stage-3 / total,
  )
})

#let series = (
  (
    label: [Parsing],
    color: navy,
    values: shares.map(item => item.parsing),
  ),
  (
    label: [Stage \#1: Top-Level Declarations],
    color: eastern,
    values: shares.map(item => item.stage-1),
  ),
  (
    label: [Stage \#2: Label Stabilization],
    color: maroon,
    values: shares.map(item => item.stage-2),
  ),
  (
    label: [Stage \#3: Policy Enforcement],
    color: orange,
    values: shares.map(item => item.stage-3),
  ),
)

#let chart = {
  show lq.selector(lq.legend): set grid(columns: 4)

  lq.diagram(
    width: 100%,
    height: 6cm,
    legend: (position: top + center, dy: -25%),
    ylim: (0, 100),
    xlabel: [SLOC Quartile (Fewer to More Lines)],
    ylabel: [Share of Reconstructed Time (%)],
    xaxis: (
      ticks: range(4).map(i => (i, [Q#(i + 1)])),
      subticks: none,
    ),
    yaxis: (tick-distance: 10),
    ..column-first(stacked-bars(range(4), series, width: 65%)),
  )
}
