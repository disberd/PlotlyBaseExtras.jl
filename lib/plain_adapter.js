// The plain HTML-aware file.
// Expects in closure scope (from the Julia preamble in src/show.jl + the css
// binding in src/main_struct.jl): plot_obj, Plotly, plotly_listeners,
// js_listeners, css; and the wrapper's `currentScript`.

const { container: CONTAINER } = renderPlot({
  plot_obj,
  Plotly,
  css,
  plotly_listeners,
  js_listeners,
});

// `PLOT` is a DOCUMENTED in-scope variable for user listeners
// (add_js_listener! / add_plotly_listener!); keep it bound so existing user
// listener code referencing bare `PLOT` keeps working.
const PLOT = CONTAINER.PLOT;

currentScript.insertAdjacentElement("beforebegin", CONTAINER);
