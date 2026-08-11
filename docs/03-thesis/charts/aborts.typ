#import "../utils/charts.typ": *

#let with-abort-reason(reason) = {
  results.filter(row => row.abort_reason == reason).len()
}

#let bars = (
  (
    label: [Parsing Failure],
    color: maroon,
    value: with-abort-reason("P"),
  ),
  (
    label: [World Limit],
    color: navy,
    value: with-abort-reason("W"),
  ),
  (
    label: [Permutation Limit],
    color: eastern,
    value: with-abort-reason("B"),
  ),
).rev()

#let chart = lq.diagram(
  height: 5cm,
  xlabel: [$\#$ Aborted Modules],
  xaxis: (tick-distance: 1, subticks: none),
  yaxis: (
    ticks: bars.map(bar => bar.label).enumerate(),
    subticks: none,
  ),
  lq.hbar(
    bars.map(bar => bar.value),
    range(bars.len()),
    fill: bars.map(bar => bar.color),
  ),
)
