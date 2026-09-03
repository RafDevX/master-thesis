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

#let totals = groups.map(group => {
  sample(group.dataset, group.band).len()
})

#let share(status) = groups.map(group => {
  let count = sample(group.dataset, group.band)
    .filter(row => row.status == status)
    .len()

  let pos = groups.position(candidate => candidate == group)
  let total = totals.at(pos)

  return 100 * count / total
})

#let ticks = groups.map(group => {
  if group.dataset == none and group.band == none {
    strong[All]
  } else {
    group.dataset + "." + group.band
  }
});
#ticks.insert(1, [])
#let ticks = ticks.enumerate()
#ticks.remove(1)

#let series = (
  (
    label: [Succeeded],
    color: olive,
    values: share("S"),
  ),
  (
    label: [Diagnostics],
    color: orange,
    values: share("F"),
  ),
  (
    label: [Aborted],
    color: maroon,
    values: share("A"),
  ),
  (
    label: [Crashed],
    color: navy,
    values: share("C"),
  ),
  (
    label: [Empty],
    color: gray,
    values: share("E"),
  ),
)

#let indices = range(groups.len() + 1)
#indices.remove(1)

#let chart = (big: false) => {
  show lq.selector(lq.legend): set grid(columns: 6)

  lq.diagram(
    width: 100%,
    height: if big { 7cm } else { 5.3cm },
    margin: (y: if big { 20% } else { 15% }),
    legend: (position: top + center, dy: if big { -30% } else { -25% }),
    xlabel: [Sample],
    ylabel: [Share of Modules (%)],
    xaxis: (
      ticks: ticks,
      subticks: none,
    ),
    yaxis: (tick-distance: 20),
    ..stacked-bars(indices, series),
    ..indices
      .zip(totals)
      .map(((x, total)) => (x, text(0.8em)[#total]))
      .map(((x, total)) => if x == 0 { (x, strong(total)) } else { (x, total) })
      .map(((x, total)) => lq.place(x, 10%, total)),
  )
}
