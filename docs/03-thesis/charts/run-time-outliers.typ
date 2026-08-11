#import "../utils/charts.typ": *

#let by-project = (:)

#for row in results {
  let project = row.primary_project
  let run-time = number(row, "global_run_time")
  let sloc = number(row, "sloc")
  let multiplier = number(row, "n_build_constraint_permutations")

  if run-time == 0 or sloc == 0 {
    continue
  }

  let existing = by-project.at(project, default: (:))
  let existing-run-time = existing.at("run-time", default: 0)
  let existing-sloc = existing.at("sloc", default: 0)

  by-project.insert(project, (
    run-time: existing-run-time + run-time,
    sloc: existing-sloc + multiplier * sloc,
  ))
}

#let ranked-projects = (
  by-project
    .pairs()
    .map(((project, item)) => (
      project: project,
      run-time: item.run-time,
      sloc: item.sloc,
    ))
    .sorted(key: item => -item.run-time)
)

#let total-run-time = sum(ranked-projects.map(item => item.run-time))
#let outliers = ranked-projects.slice(
  0,
  calc.min(15, ranked-projects.len()),
)

#let project-label(project) = {
  let clean = project
    .replace("proxy://", "")
    .replace("https://github.com/", "")
    .replace("https://gitlab.com/", "")

  let parts = clean.split("/")

  if parts.len() > 2 {
    parts.slice(parts.len() - 2).join("/")
  } else {
    clean
  }
}

#let individual-shares = outliers.map(
  item => calc.round(100 * item.run-time / total-run-time),
)

#let cumulative-shares = {
  outliers
    .fold((0, ()), ((sum, acc), item) => {
      let new = sum + 100 * item.run-time / total-run-time

      (new, acc + (new,))
    })
    .at(1)
}

#let chart = {
  show: lq.show_(
    lq.tick-label.with(kind: "x"),
    label => box(
      width: 0pt,
      align(right, rotate(-45deg, reflow: true, text(0.9em, label))),
    ),
  )

  lq.diagram(
    width: 100%,
    height: 7.5cm,
    ylim: (0, 100),
    ylabel: [Share of Total Global Run Time (%)],
    legend: (position: horizon + right),
    xaxis: (
      ticks: outliers.map(item => project-label(item.project)).enumerate(),
      subticks: none,
    ),
    yaxis: (tick-distance: 10),
    lq.bar(
      range(outliers.len()),
      individual-shares,
      width: 70%,
      fill: navy,
      label: [Individual Share],
    ),
    lq.plot(
      range(outliers.len()),
      cumulative-shares,
      color: red,
      stroke: 1.5pt,
      mark: "o",
      label: [Cumulative Share],
    ),

    lq.yaxis(
      position: right,
      label: lq.label(angle: 90deg, [Source Lines of Code (SLOC)]),
      lq.plot(
        range(outliers.len()),
        outliers.map(item => item.sloc),
        color: blue,
        stroke: 1.5pt,
        mark: "*",
        label: [Permutation-Scaled SLOC],
      ),
    ),
  )
}
