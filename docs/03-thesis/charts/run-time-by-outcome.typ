#import "../utils/charts.typ": *

#let for-status(status) = {
  let rows = if status == none {
    results
  } else {
    results.filter(row => row.status == status)
  }

  rows
    .map(row => number(row, "global_run_time"))
    .filter(time => time != 0)
    .map(time => time / 1e9)
}

#let outcomes = (
  (
    label: strong[All],
    color: black,
    data: for-status(none),
    zoom: true,
  ),
  (
    label: [Succeeded],
    color: olive,
    data: for-status("S"),
    zoom: true,
  ),
  (
    label: [Diagnostics],
    color: orange,
    data: for-status("F"),
    zoom: false,
  ),
  (
    label: [Aborted],
    color: maroon,
    data: for-status("A"),
    zoom: true,
  ),
  (
    label: [Crashed],
    color: navy,
    data: for-status("C"),
    zoom: false,
  ),
).rev()

#let chart(zoom: false) = {
  let filtered = if zoom {
    outcomes.filter(outcome => outcome.zoom)
  } else {
    outcomes
  }

  lq.diagram(
    width: 100%,
    height: if zoom { 3cm } else { 4cm },
    margin: (y: 10%),
    xlabel: [Global Run Time (sec)],
    yaxis: (
      ticks: filtered.map(outcome => outcome.label).enumerate(),
      subticks: none,
    ),
    ..filtered
      .enumerate()
      .map(((y, outcome)) => lq.hboxplot(
        outcome.data,
        y: y,
        median: 2pt + outcome.color,
        fill: outcome.color.transparentize(80%),
        outliers: none,
      )),
  )
}
