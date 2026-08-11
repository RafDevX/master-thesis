#import "./dependencies.typ": lq
#import "../content/zz-b-results.typ": results

#let completed = results.filter(
  row => ("S", "F").contains(row.status),
)

#let sample(dataset, band) = {
  if dataset == none and band == none {
    return results
  } else {
    return results.filter(row => (
      (dataset in (row.primary_project_dataset, row.secondary_project_dataset))
        and (band in (row.primary_project_band, row.secondary_project_band))
    ))
  }
}

#let datasets = ("A", "B", "C")
#let bands = ("I", "II", "III", "IV")

#let sum(values) = values.fold(0, (acc, value) => acc + value)

#let avg(values) = sum(values) / values.len()

#let number(row, field, default: 0) = {
  let value = row.at(field, default: "")
  if value == "" {
    default
  } else {
    int(value)
  }
}

#let stacked-bars(
  positions,
  series,
  width: 75%,
) = {
  let base = (0,) * positions.len()
  let plots = ()

  for item in series {
    let top = base.zip(item.values).map(((lower, value)) => lower + value)

    plots.push(
      lq.bar(
        positions,
        top,
        base: base,
        width: width,
        fill: item.color,
        label: item.label,
      ),
    )

    base = top
  }

  plots
}

// lilaq displays legend grids left->right instead of top->down, which can
// look weird, so we re-order the plots for the legend to display better
#let column-first(plots, logical-columns: 2) = {
  let rows = calc.ceil(plots.len() / logical-columns)
  let reordered = ()

  for row in range(rows) {
    for column in range(logical-columns) {
      let index = column * rows + row

      if index < plots.len() {
        reordered.push(plots.at(index))
      }
    }
  }

  reordered
}
