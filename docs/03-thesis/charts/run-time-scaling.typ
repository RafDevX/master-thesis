#import "../utils/charts.typ": *

#let permutation-group(row) = {
  let permutations = number(row, "n_build_constraint_permutations")

  if permutations == 1 {
    "one"
  } else if permutations <= 4 {
    "few"
  } else {
    "many"
  }
}

#let series(group) = completed.filter(
  row => permutation-group(row) == group,
)

#let points-x(rows) = rows.map(row => number(row, "sloc"))
#let points-y(rows) = rows.map(
  row => number(row, "global_run_time") / 1e9,
)

// fit log(run-time) = intercept + slope x log(sloc)
#let log-x = points-x(completed).map(calc.ln)
#let log-y = points-y(completed).map(calc.ln)

#let log-x-avg = avg(log-x)
#let log-y-avg = avg(log-y)

#let slope = (
  sum(
    log-x.zip(log-y).map(((x, y)) => (x - log-x-avg) * (y - log-y-avg)),
  )
    / sum(
      log-x.map(x => calc.pow(x - log-x-avg, 2)),
    )
)

#let intercept = log-y-avg - slope * log-x-avg

#let min-x = completed.fold(
  number(completed.first(), "sloc"),
  (current, row) => calc.min(current, number(row, "sloc")),
)
#let max-x = completed.fold(
  number(completed.first(), "sloc"),
  (current, row) => calc.max(current, number(row, "sloc")),
)

#let trend-x = (min-x, max-x)
#let trend-y = trend-x.map(
  x => calc.exp(intercept) * calc.pow(x, slope),
)

#let r2 = {
  let predicted = log-x.map(x => intercept + slope * x)
  let mean-y = log-y.sum() / log-y.len()

  let ss_res = log-y.zip(predicted).map(((y, p)) => calc.pow(y - p, 2)).sum()
  let ss_tot = log-y.map(y => calc.pow(y - mean-y, 2)).sum()

  1 - ss_res / ss_tot
}

#let one-permutation = series("one")
#let few-permutations = series("few")
#let many-permutations = series("many")

#let chart = lq.diagram(
  width: 100%,
  height: 8.5cm,
  legend: (position: top + left),
  xscale: "log",
  yscale: "log",
  xlabel: [Source Lines of Code (SLOC)],
  ylabel: [Global Run Time (sec)],
  lq.scatter(
    points-x(one-permutation),
    points-y(one-permutation),
    color: blue,
    alpha: 50%,
    mark: "o",
    label: [$1$ Build Permutation],
  ),
  lq.scatter(
    points-x(few-permutations),
    points-y(few-permutations),
    color: orange,
    alpha: 50%,
    mark: "+",
    label: [$2 thin - thin 4$ Build Permutations],
  ),
  lq.scatter(
    points-x(many-permutations),
    points-y(many-permutations),
    color: red,
    alpha: 50%,
    mark: "^",
    label: [$>=5$ Build Permutations],
  ),
  lq.plot(
    trend-x,
    trend-y,
    color: black,
    stroke: (thickness: 1pt, dash: "dashed"),
    mark: none,
    label: [Log-Log Fit],
  ),
);
