#import "../utils/charts.typ": *

#let errors-by-project = (:)

#for row in completed {
  let project = row.primary_project
  let errors = number(row, "n_errors")

  errors-by-project.insert(
    project,
    errors-by-project.at(project, default: 0) + errors,
  )
}

#let ranked-projects = (
  errors-by-project
    .pairs()
    .map(((project, errors)) => (
      project: project,
      errors: errors,
    ))
    .filter(item => item.errors > 0)
    .sorted(key: item => -item.errors)
)

#let total-errors = sum(ranked-projects.map(item => item.errors))
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
  item => calc.round(100 * item.errors / total-errors),
)

#let cumulative-shares = {
  outliers
    .fold((0, ()), ((sum, acc), item) => {
      let new = sum + 100 * item.errors / total-errors

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
    height: 7cm,
    ylim: (0, 100),
    ylabel: [Share of Reported Insecure Flows (%)],
    legend: (position: top + left),
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
  )
}
