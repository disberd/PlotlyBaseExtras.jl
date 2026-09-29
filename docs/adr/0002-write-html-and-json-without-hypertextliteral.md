# The package writes its HTML and JSON without HypertextLiteral

`render` writes the plot HTML itself, and the package has no HypertextLiteral (HTL) dependency.
One writer, `write_js`, writes each value that `to_js(host, x)` returns. A value with a
`show(io, ::MIME"text/javascript", v)` method writes itself, for example the Pluto
`published_to_js` object. The writer writes every other value as JSON text that the browser runs
as a JS expression, with `NaN` and `±Infinity` kept. It writes each `<` before `/`, `!`, `s` or
`S` as `\u003c`, so the text cannot end or change the script element. The `:inline` plotly.js
and MathJax bundles go through the same writer. Listeners and scripts are `String`s. The
functions that add them throw an `ArgumentError` for code with `</script` or `<!--`.

HTL cost time in every host, and the package used only four HTL features. The measurements are
from a prototype without HTL, on Julia 1.13, with a plain HTML `show`:

- A scatter with 10^6 points: 407 ms and 359 MiB with HTL, 210 ms and 97 MiB without.
- A 1000×1000 heatmap: 166 ms with HTL, 112 ms without.
- In Pluto, one HTL method invalidates 17 PlutoRunner methods that run for each cell. The
  recompilation after `using` is 815 ms with HTL, 490 ms without.

The change breaks the 0.1 API, so it comes in 0.2.0. JSON 1 is a direct dependency. PlotlyJS
0.18.18 and WebIO 0.8.21 allow only JSON 0.21 or older, so the package cannot share an
environment with PlotlyJS 0.18. `nothing` in the plot data becomes `null`. HTL wrote `undefined`,
and Pluto already sends `null`.

## Considered options

- Keep HTL. The costs above stay. A precompile workload removes the compile cost for known
  types. Each new value type or IO type still compiles the HTL JS printer again, 11–23 ms for
  each array type.
- A JS literal printer in the package. It is a second JSON writer next to JSON.jl, which
  PlotlyBase loads anyway.
- The data as `JSON.parse('…')`. In the browser, the compile and run of the scatter data take
  266 ms, against 349 ms for the JSON text. For the heatmap, 102 ms against 198 ms. This saves
  about 100 ms of a plot draw of about 2.4 s. `JSON.parse` changes `NaN` and `±Infinity` to
  `null`, for example in an axis range.
- A JS marker type: a package `JS` struct that `htl_js` returns, with a package extension that
  converts `HypertextLiteral.JavaScript` values. No code outside the package used the HTL API of
  the package. A `String` is sufficient for the three functions that add JS code.
