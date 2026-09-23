// The only Pluto-aware file.
// Expects in closure scope (from the Julia preamble in src/show.jl + the css
// binding in src/main_struct.jl): plot_obj, Plotly, plotly_listeners,
// js_listeners, css; and Pluto's injected `this` / `invalidation`.
// `CONTAINER` is returned to Pluto by `return CONTAINER` in src/show.jl.

// `this` is the previous run's returned container, or undefined on the first
// run. `renderPlot` maps a falsy value to "no old container" itself.
const { container: CONTAINER, teardown } = renderPlot({
  plot_obj,
  Plotly,
  css,
  plotly_listeners,
  js_listeners,
  oldContainer: this,
});

// `PLOT` is a DOCUMENTED in-scope variable for user listeners
// (add_js_listener! / add_plotly_listener! docstrings). Keep it bound so existing
// user listener code referencing bare `PLOT` keeps working.
const PLOT = CONTAINER.PLOT;

invalidation.then(teardown);
