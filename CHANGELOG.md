# Changelog

All notable changes to this project are in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[unreleased]: https://github.com/disberd/PlotlyBaseExtras.jl/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/disberd/PlotlyBaseExtras.jl/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/disberd/PlotlyBaseExtras.jl/releases/tag/v0.1.0
