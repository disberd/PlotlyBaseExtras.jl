// The adapter for the Julia VSCode plot pane. The pane wraps the payload in a
// page with `body{margin:0}` and no width or height on the root, and it never
// forwards resize events. So this adapter sizes the container to the viewport
// and re-applies that size on window resize; the core's ResizeObserver then
// lays out the plot to match. Each plot is a full page reload in the pane, so
// there is no teardown. Expects in closure scope (from the Julia preamble in
// src/show.jl + the css binding in src/main_struct.jl): plot_obj, Plotly,
// plotly_listeners, js_listeners, css; and the wrapper's `currentScript`.

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

// Fill the pane. The core removes these inline sizes after the first resize,
// so re-apply them on window resize to keep the container at the pane size.
function fillPane() {
  CONTAINER.style.width = "100vw";
  CONTAINER.style.height = "100vh";
}
fillPane();
window.addEventListener("resize", () => {
  fillPane();
  Plotly.Plots.resize(PLOT);
});

currentScript.insertAdjacentElement("beforebegin", CONTAINER);
