// The adapter for KaimonSlate. It keeps the plot container across runs of the
// cell, as the Pluto adapter does with `this`.
// Expects in closure scope (from the Julia preamble in src/show.jl + the css
// binding in src/main_struct.jl): plot_obj, Plotly, plotly_listeners,
// js_listeners, css; and the wrapper's `currentScript`.
//
// The Slate extension puts a `<div data-slate-keep>` holder just before this
// script. A Slate that supports `data-slate-keep` gives back the holder of the
// previous run, with its container inside. A Slate without that support gives a
// new, empty holder, so each run makes a new container.

const holder = currentScript.previousElementSibling;
// Remove the listeners of the previous run before this run adds its own.
holder.__teardown?.();
const oldContainer = holder.firstElementChild;
const { container: CONTAINER, teardown } = renderPlot({
  plot_obj,
  Plotly,
  css,
  plotly_listeners,
  js_listeners,
  oldContainer,
});

// `PLOT` is a DOCUMENTED in-scope variable for user listeners
// (add_js_listener! / add_plotly_listener!); keep it bound so existing user
// listener code referencing bare `PLOT` keeps working.
const PLOT = CONTAINER.PLOT;

if (!oldContainer) holder.appendChild(CONTAINER);
holder.__teardown = teardown;
// Slate sends `slate:discard` when it removes the holder for good. The
// container is the same in each run, so the listener of the first run is enough.
if (!holder.__discardWired) {
  holder.__discardWired = true;
  holder.addEventListener("slate:discard", () => {
    holder.__teardown?.();
    destroyContainer(CONTAINER);
  });
}
