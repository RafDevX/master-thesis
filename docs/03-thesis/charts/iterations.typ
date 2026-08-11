#import "../utils/charts.typ": *

#let ecdf-plot(key, color) = {
  let points-x = completed
    .map(row => number(row, key))
    .filter(value => value > 0)
    .sorted()

  let points-y = points-x
    .enumerate()
    .map(((index, _)) => 100 * (index + 1) / points-x.len())

  lq.plot(
    points-x,
    points-y,
    step: end,
    color: color,
    stroke: 1.5pt,
    mark: none,
  )
}

#let chart = lq.diagram(
  width: 80%,
  height: 6cm,
  xlim: (1, auto),
  ylim: (0, 100),
  xlabel: [$\#$ Max Stabilization Iterations],
  ylabel: [Converged Modules (%)],
  xaxis: (subticks: none),
  yaxis: (tick-distance: 20),
  ecdf-plot("max_convergence_iterations", maroon),
);
