// The adapter for the Julia VSCode plot pane. The pane wraps the payload in a
// page with `body{margin:0}` and no width or height on the root. So this
// adapter sizes the container to the viewport with a stylesheet; the core's
// ResizeObserver then lays out the plot to match, also when the pane changes
// size. Each plot is a full page reload in the pane, so there is no teardown.
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

// The container always has the pane size. The core removes the inline size it
// sets after the first layout, so the size must come from a stylesheet: with
// no size, the container follows the content and scrollbars make it resize in
// a loop. `overflow: hidden` stops a sub-pixel overflow from showing
// scrollbars. The extension adds its own "Copy Plot" button over the plot;
// the modebar clipboard button does the same job, so hide it.
document.head.appendChild(html`<style>
  html, body { overflow: hidden; }
  body > .plotlyplot-container { width: 100vw; height: 100vh; }
  #copy-plot-btn { display: none; }
</style>`);
// The inline size replaces the core's default height for the first layout.
CONTAINER.style.width = "100vw";
CONTAINER.style.height = "100vh";

currentScript.insertAdjacentElement("beforebegin", CONTAINER);
