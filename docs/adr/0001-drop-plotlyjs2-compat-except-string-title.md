# Only the String title keeps a plotly.js 2 shim

plotly.js 3.0 and 4.0 removed many plotly.js 2 attributes and trace types, and plotly.js 4 drops
them without a message. The core converts one of them: a String `title` at any path becomes
`Dict(:text => s)`, because `Layout(title = "...")` and `attr(title = "...")` are the normal
PlotlyBase idiom. The core drops the others: `titlefont`, `titleside`, `titleposition`,
`titleoffset`, `autotick`, `annotation.ref`, `bardir`, the `heatmapgl` and `pointcloud` traces,
the `*mapbox` traces, and the `mapbox` subplot. The README lists each dropped name and its
replacement. A removed trace type in the plot data gives a one-time warning when the selected
plotly.js version has removed it, because plotly.js 4 draws an empty plot for it.

## Considered options

- A rewrite rule for each removed name, in Julia. Each rule has to merge into a sibling
  attribute or swap data (`bardir`), and each needs a test. These names were deprecated for years
  before plotly.js 3 removed them.
- A JavaScript pass before `Plotly.react`. PlotlyKaleido export runs its own page, so this pass
  does not reach it, and the Julia rules have to exist anyway.
