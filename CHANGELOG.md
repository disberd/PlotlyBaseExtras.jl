# Changelog

All notable changes to this project are in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `savehtml(path_or_io, plots...; title, head)` writes a standalone HTML page with one or more
  independent plots. With the `:inline` source, the page holds plotly.js and MathJax one time
  for all plots, and shows without a network connection.
- Support for PlotlyBase 0.9 and 0.10. These versions keep the attributes of traces and layouts
  in a `JSON.Object`, and the plot processing now accepts each `AbstractDict`.
- The `slate_asset_min_length` setting (ScopedValue, `change_slate_asset_min_length`, preference
  key `slate_asset_min_length`; default 10000) sets the smallest numeric vector that goes in a
  Slate cell asset. A value larger than any vector keeps all the data as JSON.
- In a static export of a KaimonSlate notebook, a control that drives `@replay` data moves the
  plot with no kernel. All the slices of one move draw in one redraw, and the redraw keeps the zoom
  and legend clicks of the reader. The replayed data can be a vector or a matrix (for example a
  heatmap `z`).

### Changed

- In KaimonSlate 1.10 or later (SlateExtensionsBase 0.11), the numeric vectors of the plot data
  with `slate_asset_min_length` or more numbers go to the page as raw bytes in a cell asset. The
  cell output no longer contains them as JSON text, so the notebook state is smaller and a large
  plot draws sooner. The asset goes into the cell memo and into a static export. Where Slate keeps
  no cell assets (for example a plot in a markdown `{{ }}` interpolation), the data stays JSON.
- A re-run in KaimonSlate, and a reactive re-run in Pluto, keep the zoom, pan, legend clicks, and
  selection of the reader. The package sets a default `layout.uirevision`, but an explicit
  `Layout(uirevision = false)` restores the old behavior.
- The compat bound of SlateExtensionsBase is now `0.10, 0.11`.

## [0.2.2] - 2026-10-05

### Fixed

- In KaimonSlate, a plot output keeps its height while plotly.js loads. Before, a new output was
  0 px tall until the plot drew, so the notebook moved and the live deck changed its scale.

## [0.2.1] - 2026-10-01

### Added

- When the browser refuses the clipboard write, the modebar clipboard button opens a Copy
  dialog with the PNG. Copy the image with right-click → "Copy image". This works in all hosts.

### Changed

- The tooltip of the clipboard button says what the button does on the current page and names
  the double-click export options. A page without the clipboard API shows no `alert()`.

### Deprecated

- `plotly_paste_receiver`. When the browser refuses the clipboard write, the clipboard button
  opens a Copy dialog with the image. Version 0.3 removes the function.

## [0.2.0] - 2026-09-29

### Changed

- BREAKING: Listeners and scripts are `String`s. `add_js_listener!`, `add_plotly_listener!`
  and `push_script!` accept only an `AbstractString`. `p.js_listeners`, `p.plotly_listeners` and
  `p.script_contents.vec` hold `String`s.
- BREAKING: `add_js_listener!`, `add_plotly_listener!` and `push_script!` throw an
  `ArgumentError` for JS code that contains `</script` (in any case) or `<!--`.
- BREAKING: `plutoplotly_paste_receiver` is now `plotly_paste_receiver`.
- BREAKING: `enable_plutoplotly_offline` is now `enable_plotly_offline`.
- BREAKING: `plotly_paste_receiver()` and `enable_plotly_offline()` return `Base.HTML`.
- BREAKING: `nothing` in the plot data becomes `null` in the browser, as in Pluto. `NaN`,
  `Inf` and `-Inf` stay `NaN`, `Infinity` and `-Infinity`.
- BREAKING: The package needs JSON 1. It cannot share an environment with PlotlyJS 0.18.
- The value that `to_js(host, x)` returns writes itself when it has a
  `show(io, ::MIME"text/javascript", v)` method. The package writes every other value as JSON
  text, with each `<` before `/`, `!`, `s` or `S` as `\u003c`.
- `show` of a large plot is faster and uses less memory (plain HTML, Julia 1.13). A scatter with
  10^6 points takes 210 ms and 97 MiB (407 ms and 359 MiB in 0.1). A 1000×1000 heatmap takes
  112 ms (166 ms in 0.1).

### Removed

- BREAKING: `htl_js`. Give the JS code as a `String`.
- BREAKING: The HypertextLiteral dependency and the binding
  `PlotlyBaseExtras.HypertextLiteral`. To use `@htl`, load HypertextLiteral yourself.
- BREAKING: `HypertextLiteral.JavaScript` values in `add_js_listener!`,
  `add_plotly_listener!` and `push_script!`. They give a `MethodError`.
- BREAKING: `PlutoPlot`. Use `PlotlyPlot`.
- BREAKING: `force_pluto_mathjax_local`. Use `force_mathjax_local`.

### Fixed

- The package no longer defines `show` for `HypertextLiteral.JavaScript` values. This method was
  type piracy, and outside Pluto it threw a `MethodError`.

## [0.1.1] - 2026-09-29

### Changed

- The first plot and the first render are faster: −2.2 s in a script and −2.9 s in Pluto.
  With `SlateExtensionsBase` loaded, the first Slate render is also faster.

### Fixed

- In KaimonSlate, a re-run updates the plot in place and does not leak WebGL contexts. A plot
  that Slate discards, or the plot of a deleted cell, releases its WebGL contexts.
- A re-run no longer redraws the whole figure because of the custom modebar buttons (Pluto and
  Slate).
- `show` of a plot with a matrix that has `missing` values (for example
  `heatmap(z = [1.0 missing; 2.0 3.0])`) no longer throws a `MethodError`.

## [0.1.0] - 2026-09-24

### Added

- Initial release.
- Interactive plotly.js figures from PlotlyBase plots in four hosts: Pluto, the VSCode plot pane,
  plain HTML files and KaimonSlate.
- Plotly event listeners and custom JS listeners on a figure.
- Pop-out, resize and clipboard export of a figure.
- MathJax for LaTeX strings in titles and labels.
- Settings for the plotly.js source (`:auto`, `:cdn`, `:inline`, `:hosted`) and the plotly.js
  version.

[unreleased]: https://github.com/disberd/PlotlyBaseExtras.jl/compare/v0.2.2...HEAD
[0.2.2]: https://github.com/disberd/PlotlyBaseExtras.jl/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/disberd/PlotlyBaseExtras.jl/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/disberd/PlotlyBaseExtras.jl/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/disberd/PlotlyBaseExtras.jl/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/disberd/PlotlyBaseExtras.jl/releases/tag/v0.1.0
