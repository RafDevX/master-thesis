#import "../utils/charts.typ": *

#let problems = (
  (
    label: [Warnings],
    color: orange,
    key: "n_warnings",
  ),
  (
    label: [Conf. Errors],
    color: maroon,
    key: "n_confidentiality_flows",
  ),
  (
    label: [Int. Errors],
    color: eastern,
    key: "n_integrity_flows",
  ),
).rev()

#let reported(key) = {
  completed.map(row => number(row, key)).filter(val => val > 0)
}

#let chart = lq.diagram(
  width: 100%,
  height: 3.7cm,
  margin: (y: 15%),
  xlabel: [$\#$ Diagnostics per Module],
  yaxis: (
    ticks: problems.map(problem => problem.label).enumerate(),
    subticks: none,
  ),
  ..problems
    .enumerate()
    .map(((y, problem)) => lq.hboxplot(
      reported(problem.key),
      y: y,
      median: 2pt + problem.color,
      fill: problem.color.transparentize(80%),
      outliers: none,
    )),
)
