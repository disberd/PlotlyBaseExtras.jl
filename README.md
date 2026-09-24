# PlotlyBaseExtras

PlotlyBaseExtras renders PlotlyBase plots as interactive plotly.js figures in Pluto notebooks,
plain HTML files, the VSCode plot pane, and KaimonSlate notebooks. A figure supports plotly event
listeners, custom JS listeners, pop-out, resize, and clipboard export. MathJax renders LaTeX
strings in titles and labels. The package re-exports PlotlyBase, so `plot`, `scatter`, and
`Layout` need no extra `using`.

## Installation

```julia
using Pkg
Pkg.add("PlotlyBaseExtras")
```

## One example per host

### Pluto

Return the plot from a cell. The `text/html` show method detects Pluto and renders with the
Pluto adapter:

```julia
using PlotlyBaseExtras

plot(scatter(x = 1:10, y = rand(10)), Layout(title = "A plot in Pluto"))
```

### Plain HTML

`render` writes the HTML of one plot. The following code writes a complete page:

```julia
using PlotlyBaseExtras

p = plot(scatter(x = 1:10, y = rand(10)), Layout(title = "A plot in a file"))

open("plot.html", "w") do io
    println(io, "<!doctype html><html><body>")
    PlotlyBaseExtras.render(io, PlotlyBaseExtras.PlainHTML(), p)
    println(io, "</body></html>")
end
```

Outside Pluto, `show(io, MIME"text/html"(), p)` writes the same HTML, because `current_host()`
returns `PlainHTML()` there.

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

The first name in each row is the ScopedValue. The following code shows the three ways to set
`plotly_source`:

```julia
using ScopedValues

# ScopedValue, for the duration of `with`
with(PlotlyBaseExtras.plotly_source => :inline) do
    PlotlyBaseExtras.render(io, PlotlyBaseExtras.PlainHTML(), p)
end

# Runtime setter, for the rest of the session
change_plotly_source(:inline)
```

```toml
# LocalPreferences.toml, permanent
[PlotlyBaseExtras]
plotly_source = "inline"
```

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

## PlutoPlotly

PlutoPlotly 0.6 users need no change.
