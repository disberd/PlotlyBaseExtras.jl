# PlotlyBaseExtras

PlotlyBaseExtras renders PlotlyBase plots as interactive plotly.js figures in Pluto notebooks,
plain HTML files, the VSCode plot pane, and KaimonSlate notebooks. A figure supports plotly event
listeners, custom JS listeners, resize, the Export pop-out, and PNG copy to the clipboard. When
the browser refuses the clipboard write, the Copy dialog shows the PNG, and you copy it with
right-click → Copy image. MathJax renders LaTeX strings in titles and labels. The package
re-exports PlotlyBase, so `plot`, `scatter`, and `Layout` need no extra `using`.

## Installation

```julia
using Pkg
Pkg.add("PlotlyBaseExtras")
```

PlotlyBaseExtras 0.2 needs JSON 1, so it cannot share an environment with PlotlyJS 0.18:
PlotlyJS 0.18.18 and WebIO 0.8.21 allow only JSON 0.21 or older.

## One example per host

### Pluto

Return the plot from a cell. The `text/html` show method detects Pluto and renders with the
Pluto adapter:

```julia
using PlotlyBaseExtras

plot(scatter(x = 1:10, y = rand(10)), Layout(title = "A plot in Pluto"))
```

### Plain HTML

`savehtml` writes a standalone HTML page with one or more independent plots, one below the
other:

```julia
using PlotlyBaseExtras

p1 = plot(scatter(x = 1:10, y = rand(10)), Layout(title = "First plot"))
p2 = plot(bar(x = 1:5, y = rand(5)), Layout(title = "Second plot"))

savehtml("plots.html", p1, p2; title = "Two plots")
```

The `head` keyword adds HTML to the page head, for example a `<style>` element. To write your own
page, use `PlotlyBaseExtras.render(io, PlotlyBaseExtras.PlainHTML(), p; script_id)`. It writes
the HTML of one plot. Outside Pluto, `show(io, MIME"text/html"(), p)` writes the same HTML,
because `current_host()` returns `PlainHTML()` there.

### VSCode plot pane

Enter the plot expression in the Julia REPL. The package defines the
`application/vnd.julia-vscode.plotpane+html` show method, so the result opens in the plot pane:

```julia
using PlotlyBaseExtras

plot(scatter(x = 1:10, y = rand(10)), Layout(title = "A plot in VSCode"))
```

### KaimonSlate

Return the plot from a cell. Every Slate worker loads `SlateExtensionsBase`, so the package
extension renders the plot:

```julia
using PlotlyBaseExtras

plot(scatter(x = 1:10, y = rand(10)), Layout(title = "A plot in KaimonSlate"))
```

#### Replayed controls in an export

In a static HTML export of the notebook, a control that drives `@replay` data moves the plot with
no Julia kernel. Put `@replay(control, expression)` where the plot takes the data: a trace
attribute or a layout attribute. The expression gives a vector or a matrix, for example the `z` of
a heatmap. The export computes the expression for each value of the control.
When the reader moves the control, the page draws all the changed data in one redraw and keeps the
zoom and legend clicks of the reader. This plot has a slider in one cell and the plot in the next
cell:

```julia
@bind k Slider(1:10; default = 3, label = "k")
```

```julia
plot(scatter(x = 1:10, y = @replay(k, Float64.(k .* sin.(1:10))), mode = "markers",
             marker = attr(size = 12, color = @replay(k, Float64.(mod.(k .* (1:10), 7))))),
     Layout(title = "k = %{meta[0]}", meta = @replay(k, [Float64(k)]), yaxis = attr(range = [-11, 11])))
```

Follow these rules for `@replay` data in a plot:

- Replay numbers only. For text, such as a title, an annotation, or hover text, put the numbers
  in `meta` and write `%{meta[0]}` in the text. A title shows the number as it is and ignores a
  format such as `%{meta[0]:.1f}`. Round the number in Julia, for example
  `meta = @replay(k, [round(k / 3; digits = 1)])`.
- Compute an expensive part one time. Each `@replay` computes its own expression for each value
  of the control. When several `@replay` use the same expensive computation, compute a table over
  the values of the control outside `@replay`, and index the table in each `@replay`.
- Return the same shape at each value of the control. When the export cannot replay one
  `@replay`, for example because of an error at one value or a shape that changes with the value,
  that part of the figure stays at the exported value while the rest moves. Pad a curve whose
  length changes with `NaN`. plotly.js draws a gap at a `NaN`.
- Keep the same number of traces at each value of the control. When a trace has no data at one
  value, give it `NaN` data. A trace with only `NaN` data draws nothing.
- Name a trace by its role, not by the value that it shows. The trace names and the legend text
  do not change when the control moves.
- Do not replay a scalar attribute, such as a contour level or the `x` of an annotation. The
  export replays arrays only. To move a line with the control, draw the line as a trace with
  `@replay` data.

For a single-file export, call `change_plotly_source(:cdn)` before the plots. With the default
`:hosted` source, the exported page loads plotly.js from the `/ext-assets/` URL of the Slate
server, so the page draws no plot when it opens without that server.

## View state

A re-run of a plot cell in KaimonSlate keeps the view state: the zoom, pan, legend clicks, and
selection of the reader. In Pluto, only a reactive re-run keeps the view state, for example after
a change of an upstream cell or of a `@bind` value. Pluto makes a new plot for a cell that you run
directly, so its view state resets. The package sets `layout.uirevision` to a constant when the
layout has no `uirevision`. Other hosts never draw a shown plot again, so the constant has no
effect there. A page reload resets the view state.

A value that you change in Julia replaces the change of the reader. plotly.js keeps a change of
the reader only while the new figure has the same value for that attribute as the old figure. For
example, a new `xaxis_range` shows after the re-run.

Set `uirevision = false` in the layout to reset the view state on each re-run:

```julia
using PlotlyBaseExtras

plot(scatter(y = rand(10)), Layout(uirevision = false))
```

Per-part values give finer control, see the plotly.js reference of
[`layout.uirevision`](https://plotly.com/javascript/reference/layout/#layout-uirevision). This
plot resets the legend clicks on each re-run, and keeps the x zoom:

```julia
plot(scatter(y = rand(10)), Layout(uirevision = false, xaxis_uirevision = 1))
```

## Settings

Each setting resolves in this order: the ScopedValue, the runtime setter, the `Preferences.toml`
key, then the default. The ScopedValue applies while `with` runs, so wrap the code that renders
the plot. The runtime setter applies for the rest of the session. The preference applies from the
next render, with no reload. Put preferences in the `[PlotlyBaseExtras]` table of
`LocalPreferences.toml`.

| Setting | Values | Default | Set with |
|---|---|---|---|
| `plotly_source` | `:auto`, `:cdn`, `:inline`, `:hosted` | `:auto` | `PlotlyBaseExtras.plotly_source`, `change_plotly_source`, key `plotly_source` |
| `plotly_version` | version, for example `"3.0.1"` | bundled version | `PlotlyBaseExtras.plotly_version`, `change_plotly_version`, key `plotly_version` |
| `mathjax` | `:auto`, `:on`, `:off` | `:auto` | `PlotlyBaseExtras.mathjax`, `change_mathjax`, key `mathjax` |
| `mathjax_version` | version, for example `"3.2.2"` | `3.2.2` | `PlotlyBaseExtras.mathjax_version`, `change_mathjax_version`, key `mathjax_version` |
| `mathjax_source` | `:auto`, `:cdn`, `:inline`, `:hosted` | `:auto` | `PlotlyBaseExtras.mathjax_source`, `change_mathjax_source`, key `mathjax_source` |
| `force_mathjax_local` | `true`, `false` | `false` | `force_mathjax_local(true)` |
| `slate_asset_min_length` | positive integer | `10000` | `PlotlyBaseExtras.slate_asset_min_length`, `change_slate_asset_min_length`, key `slate_asset_min_length` |

In KaimonSlate 1.10 or later, a numeric vector of the plot data with at least
`slate_asset_min_length` numbers goes to the page as raw bytes in a cell asset, not as JSON text in
the cell output. The rows of a matrix count together. The asset makes a large plot draw sooner and
keeps the notebook state small, but the page fetches it in a second request. When the browser is
far from the Slate server, set a larger value. A value larger than any vector, for example
`typemax(Int)`, keeps all the data as JSON.

The first name in each row is the ScopedValue. The following code shows the three ways to set
`plotly_source`:

```julia
using ScopedValues

# ScopedValue, for the duration of `with`
with(PlotlyBaseExtras.plotly_source => :inline) do
    savehtml("plots.html", p1, p2)
end

# Runtime setter, for the rest of the session
change_plotly_source(:inline)
```

```toml
# LocalPreferences.toml, permanent
[PlotlyBaseExtras]
plotly_source = "inline"
```

A page from `savehtml` holds each `:inline` library one time for all its plots. With
`plotly_source` and `mathjax_source` both `:inline`, the page shows without a network connection.

`force_mathjax_local(true)` sets `svg.fontCache` to `"local"` in the MathJax config. With the
`global` font cache, the math in a plot does not display. When the page provides MathJax
(`mathjax_source` `:hosted`, the default in Pluto), the plot always makes this change. Use the flag
when a page loaded MathJax before the plot, with any other source.

### plotly.js sources per host

`:cdn` loads plotly.js from a CDN, `:inline` embeds the library in the HTML, and `:hosted` uses a
URL the host provides. An unsupported source falls back to `:auto`, with one warning.

| Host | `:auto` picks | Supported sources |
|---|---|---|
| Plain HTML | `:cdn` | `:cdn`, `:inline` |
| VSCode plot pane | `:cdn` | `:cdn`, `:inline` |
| Pluto | `:hosted` | `:cdn`, `:inline`, `:hosted` |
| KaimonSlate | `:hosted` for the bundled version, `:cdn` otherwise | `:cdn`, `:hosted` |

### MathJax

With `mathjax = :auto`, MathJax loads only when the plot JSON contains `$`. The mode `:on`
always loads it, and `:off` never loads it. The `mathjax_source` value `:auto` picks `:hosted` in
Pluto, where the page provides MathJax, and `:cdn` in every other host. The loader skips loading
when the page already defines `window.MathJax.version`.

## plotly.js version

The package bundles plotly.js 4.1.1. Set `plotly_version` to use a different version.

### Names that plotly.js 3 and 4 removed

plotly.js 3 and 4 ignore the removed names without a message. The package converts one of them:
a String `title` at any path, for example `Layout(title = "A plot")`, becomes `title.text`. Change
the other names in your code. The following table lists the removed names:

| Removed name | Removed in | Use |
|---|---|---|
| `titlefont`, `titleside`, `titleposition`, `titleoffset` | 3.0 | `title.font`, `title.side`, `title.position`, `title.offset` |
| `autotick` | 3.0 | `tickmode` |
| annotation `ref` | 3.0 | `xref` and `yref` |
| `bardir = "h"` | 3.0 | `orientation = "h"`, with `x` and `y` swapped |
| `heatmapgl` trace | 3.0 | `heatmap` |
| `pointcloud` trace | 3.0 | `scattergl` |
| `scattermapbox`, `choroplethmapbox`, `densitymapbox` traces | 4.0 | `scattermap`, `choroplethmap`, `densitymap` |
| `mapbox` subplot and `accesstoken` | 4.0 | `map` subplot, no token |

plotly.js draws no data for a removed trace type. The package logs one warning when the plot data
has a trace type that the selected `plotly_version` removed. The package does not convert the
names in your JavaScript listener code, for example in a `Plotly.relayout` call.

### Changed defaults in plotly.js 4

plotly.js 4 changed these defaults, and the package keeps them:

- An axis that overlays another axis uses `tickmode = "sync"`.
- A `splom` trace sets `matches = true` on its axes.
- A `geo` subplot uses `fitbounds = "locations"`.
- plotly.js parses colors with the culori library.

plotly.js 4 also shows a modebar button that sends the plot data to Plotly Cloud. The package sets
`showSendToCloud = false` in the plot config, so the button does not show.

### PlotlyKaleido export

`savefig` from PlotlyKaleido exports the plot with the same `plotly_version` and `mathjax_version`
as the other hosts. It restarts Kaleido when one of them changes. Kaleido 0.2.1 cannot export a
`map` subplot with plotly.js 4. To export a map, use plotly.js 2.34:

```julia
with(PlotlyBaseExtras.plotly_version => "2.34") do
    savefig(p, "map.png")
end
```

## PlutoPlotly

PlutoPlotly 0.6 users need no change.
