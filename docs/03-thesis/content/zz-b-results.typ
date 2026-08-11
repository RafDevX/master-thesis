#import "../utils/dependencies.typ": zero

= Detailed Results <results>

#let results = csv("../assets/results.csv", row-type: dictionary)

The table starting on the next page lists all #results.len() Go modules that
were subjected to static taint analysis within the scope of the present degree
project.

The version and sample columns correspond to the module's primary project, since
those were the authoritative values used to coordinate analysis. The single
module duplicated across datasets is marked with a footnote identifying its
secondary project's version and sample, even if only the primary project's
version is associated with the results presented.

Moreover, the version reported for each module corresponds to its primary
project's Git revision hash. For Dataset A modules for which the source did not
make a revision hash available, the `proxy.golang.org` identifying version
number is included instead.

The two rightmost columns indicate the number of problems Glowy reported for the
module in question, discriminated into warnings (W) and errors (E). Naturally,
these values are only provided for modules with outcome Diagnostics, as they are
undefined for the rest.

// #let three-dots = [#sym.dot.c #sym.dot.c #sym.dot.c]

The outcome classes are abbreviated for layout convenience, with the following
shorthands being used:

#pad(x: -2.5%, align(center, table(
  columns: (auto, auto, auto),

  table.header(strong[Key], strong[Outcome], strong[Description]),

  text(olive)[`OK`],
  [Succeeded],
  [Analysis completed with no problems reported],

  text(orange)[`DIAG`],
  [Diagnostics],
  [Analysis completed with at least one problem],

  text(maroon)[`ABORT`], [Aborted], [Glowy rejected performing taint analysis],

  text(navy)[`CRASH`],
  [Crashed],
  [Analysis could not be completed due to analyzer fault],

  [`EMPTY`], [Empty], [No Go files admitted],
)))

In addition, for Aborts, #text(maroon)[`PARSE`] denotes a parsing error,
#text(maroon)[`WRLDS`] excessive enumerable words $(>2^20)$, and
#text(maroon)[`PERMS`] too many build permutations $(>256)$.

#pagebreak()

#let outcome-order = ("S", "F", "A", "C", "E")
#let abort-reason-order = ("P", "W", "B")

#let badly-formatted = "gitlab.com/golangdojo/bootcamp/2intermediate/"
#let module-for(row) = {
  if row.module.starts-with(badly-formatted) {
    // typst tries to fit it in one line (and fails)
    raw(badly-formatted)
    linebreak()
    raw(row.module.slice(badly-formatted.len()))
  } else {
    raw(row.module)
  }

  if row.secondary_project != "" {
    footnote[This module has a secondary project from sample
      #row.secondary_project_dataset.#row.secondary_project_band with version
      #raw(row.secondary_project_rev_hash.slice(0, 6)). Only the primary
      project's version (as reported in the table) was analyzed, not this
      secondary one.]
  }
}

#let version-for(row) = {
  let hash = if row.primary_project_rev_hash != "" {
    row.primary_project_rev_hash
  } else if (
    row.primary_project_rev_name.match(regex(
      `^v\d+\.\d+\.\d+-\d{14}\-`.text,
    ))
      != none
  ) {
    row.primary_project_rev_name.split("-").at(2)
  } else {
    return row.primary_project_rev_name
  }

  hash.slice(0, 6)
}

#let outcome-for(row) = {
  let status = row.status

  if status == "S" {
    text(olive, [OK])
  } else if status == "F" {
    text(orange, [DIAG])
  } else if status == "A" {
    let reason = if row.abort_reason == "P" {
      [PARSE]
    } else if row.abort_reason == "W" {
      [WRLDS]
    } else if row.abort_reason == "B" {
      [PERMS]
    }

    text(maroon, [ABORT \ (#reason)])
  } else if status == "C" {
    text(navy, [CRASH])
  } else if status == "E" {
    [EMPTY]
  } else {
    panic("Unknown status", status)
  }
}

#let format-count(count) = {
  if count == "" {
    align(center, text(gray)[---])
  } else {
    zero.num(count)
  }
}

#{
  set text(size: 0.8em)
  set table.cell(breakable: false)

  pad(x: -10%, table(
    columns: (auto, auto, auto, auto, auto, auto),
    stroke: 0.5pt,
    align: (
      start + horizon,
      center + horizon,
      center + horizon,
      center + horizon,
      right + horizon,
      right + horizon,
    ),

    table.header(
      strong[Module Path],
      strong[Version],
      strong[Sample],
      strong[Outcome],
      strong[\#W],
      strong[\#E],
    ),

    ..results
      .sorted(key: row => (
        outcome-order.position(status => status == row.status),
        if row.status == "A" {
          abort-reason-order.position(reason => reason == row.abort_reason)
        } else {
          0
        },
        -if row.status == "F" {
          int(row.n_warnings) + int(row.n_errors)
        } else {
          0
        },
        row.module,
      ))
      .map(row => (
        module-for(row),
        raw(version-for(row)),
        row.primary_project_dataset + "." + row.primary_project_band,
        strong(outcome-for(row)),
        format-count(row.n_warnings),
        format-count(row.n_errors),
      ))
      .flatten(),
  ))
}

The table below additionally lists the $23$ projects not represented above due
to not containing any detectable Go module. The split is purely stylistic.

#pad(x: -10%, columns(2, {
  set text(size: 0.8em)
  set table.cell(breakable: false)

  table(
    columns: (auto, auto, auto),
    stroke: 0.5pt,
    align: (
      start + horizon,
      center + horizon,
      center + horizon,
    ),

    table.header(strong[Project @url], strong[Version], strong[Sample]),

    [`https://github.com/AliyunContainerService/log-pilot`],
    [`2daafbd`],
    [B.IV],

    [`https://github.com/ChimeraCoder/gojson`], [`3a20883`], [B.II],

    [`https://github.com/Knetic/govaluate`], [`f8c03df`], [B.II],

    [`https://github.com/aws/amazon-ecs-cli`], [`04cc135`], [B.III],

    [`https://github.com/loklak/loklak_go_api`], [`b636367`], [B.IV],

    [`https://github.com/nytlabs/streamtools`], [`069fc28`], [B.IV],

    [`https://github.com/qax-os/goreporter`], [`f7c5d0f`], [B.II],

    [`https://github.com/twitchyliquid64/subnet`], [`e9eb00b`], [B.IV],

    [`https://github.com/tylerstillwater/graceful`], [`51351a1`], [B.IV],

    [`https://github.com/xianlubird/mydocker`], [`ab3bd5e`], [B.III],

    [`https://gitlab.com/IsolatedOctopi/greenboost`], [`b1d25fc`], [C.II],

    [`https://gitlab.com/akitaonrails/clip-cutter`], [`67fa1fd`], [C.III],

    [`https://gitlab.com/ambrevar/demlo`], [`047a67c`], [C.III],

    [`https://gitlab.com/davidjpeacock/kurly`], [`98dfbfc`], [C.II],

    [`https://gitlab.com/eduar/go-programming`], [`fb014d0`], [C.IV],

    [`https://gitlab.com/esr/pytogo`], [`a6ba376`], [C.III],

    [`https://gitlab.com/kathelix/ci-cd/gitlab/merge-requests-triggers`],
    [`495895c`],
    [C.IV],

    [`https://gitlab.com/minds/minds`], [`8be057d`], [C.I],

    [`https://gitlab.com/n0r1sk/docker-volume-cephfs`], [`526c18f`], [C.IV],

    [`https://gitlab.com/pantomath-io/demo-grpc`], [`9b2ed43`], [C.III],

    [`https://gitlab.com/semkodev/hercules`], [`249aec1`], [C.III],

    [`https://gitlab.com/sj1k/gorice`], [`9fa8c6c`], [C.III],

    [`https://gitlab.com/tuxether/anancus`], [`a8c8e1b`], [C.III],
  )
}))
