# Changelog

All notable changes to this project are in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[unreleased]: https://github.com/disberd/PlotlyBaseExtras.jl/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/disberd/PlotlyBaseExtras.jl/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/disberd/PlotlyBaseExtras.jl/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/disberd/PlotlyBaseExtras.jl/releases/tag/v0.1.0
