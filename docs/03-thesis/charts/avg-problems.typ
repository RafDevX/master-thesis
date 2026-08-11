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

#let avg-count(extractor) = groups.map(group => {
  let subset = sample(group.dataset, group.band).filter(row => (
    row.status == "F"
  ))
  let count = subset.map(extractor).sum()
  let total = subset.len()
  return count / total
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
    values: avg-count(row => number(row, "n_warnings")),
  ),
  (
    label: [Confidentiality Errors],
    color: maroon,
    values: avg-count(row => number(row, "n_confidentiality_flows")),
  ),
  (
    label: [Integrity Errors],
    color: eastern,
    values: avg-count(row => number(row, "n_integrity_flows")),
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
    ylabel: [Average Reported Problems],
    xaxis: (
      ticks: ticks,
      subticks: none,
    ),
    ..stacked-bars(indices, series),
  )
}
