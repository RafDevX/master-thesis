#import "../utils/charts.typ": *

#let groups = (
  ((dataset: none, band: none),) // grand total
    + datasets
      .map(dataset => bands.map(band => (
        dataset: dataset,
        band: band,
      )))
      .flatten()
)

#let median-count(extractor) = groups.map(group => {
  let values = sample(group.dataset, group.band)
    .filter(row => row.status == "F")
    .map(extractor)
    .sorted()

  let mid = int(values.len() / 2)

  if calc.odd(values.len()) {
    values.at(mid)
  } else {
    (values.at(mid - 1) + values.at(mid)) / 2
  }
})

#let ticks = (
  groups
    .map(group => {
      if group.dataset == none and group.band == none {
        strong[All]
      } else {
        group.dataset + "." + group.band
      }
    })
    .enumerate()
)

#let series = (
  (
    label: [Warnings],
    color: orange,
    values: median-count(row => number(row, "n_warnings")),
  ),
  (
    label: [Confidentiality Errors],
    color: maroon,
    values: median-count(row => number(row, "n_confidentiality_flows")),
  ),
  (
    label: [Integrity Errors],
    color: eastern,
    values: median-count(row => number(row, "n_integrity_flows")),
  ),
)

#let indices = range(groups.len())

#let chart = {
  show lq.selector(lq.legend): set grid(columns: 6)

  lq.diagram(
    width: 105%,
    height: 6cm,
    legend: (position: top + center, dy: -15%),
    xlabel: [Sample],
    ylabel: lq.label(angle: 90deg, [Median Reported Problems]),
    xaxis: (
      ticks: ticks,
      subticks: none,
    ),
    yaxis: (position: right),
    ..stacked-bars(indices, series),
  )
}
