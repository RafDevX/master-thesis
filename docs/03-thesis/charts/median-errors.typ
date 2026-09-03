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
    .filter(row => (
      number(row, "n_errors") > 0 and number(row, "n_warnings") == 0
    ))
    .map(extractor)
    .sorted()

  let mid = int(values.len() / 2)

  if values.len() == 0 {
    0
  } else if calc.odd(values.len()) {
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

#let chart = (big: false) => {
  show lq.selector(lq.legend): set grid(columns: 6)

  lq.diagram(
    width: 100%,
    height: 6cm,
    legend: (position: top + center, dy: if big { -25% } else { -15% }),
    xlabel: [Sample],
    ylabel: [Median Reported Errors],
    xaxis: (
      ticks: ticks,
      subticks: none,
    ),
    ..stacked-bars(indices, series),
  )
}
