// Pluto-agnostic construction and update of the plot container.
// `renderPlot` is the one entry point an Adapter calls; `makeContainer` and
// `updatePlotData` below are internal to this file.
// All per-plot state is stored on the CONTAINER element so the rest of the core
// (clipboard.js / resizer.js) can read it without shared script-scope globals.
// Expects in scope: addClipboardFunctionality (clipboard.js),
// addResizeFunctionality (resizer.js). `html`/`Plotly`/`css` are passed in.

// The Core entry point. Builds (or reuses) one plot container, renders the
// plot, and returns the container plus a `teardown` that removes exactly this
// run's resources (all plotly listeners, the @bind forwarder + JS listeners,
// the resizeObserver). An adapter decides what to pass as `oldContainer`,
// when to call `teardown`, and how to mount the container.
function renderPlot({
  plot_obj,
  Plotly,
  css,
  plotly_listeners = {},
  js_listeners = {},
  oldContainer = null,
}) {
  const firstRun = !oldContainer;
  const CONTAINER = oldContainer ?? makeContainer(Plotly, html, css);
  const PLOT = CONTAINER.PLOT;
  const { controller, resizeObserver } = updatePlotData(
    CONTAINER,
    plot_obj,
    { plotlyListeners: plotly_listeners, jsListeners: js_listeners },
    firstRun
  );
  const teardown = () => {
    // Remove all plotly listeners
    PLOT.removeAllListeners();
    // Remove the @bind forwarder + all JS listeners added this run
    controller.abort();
    // Remove this run's resizeObserver
    resizeObserver.disconnect();
  };
  return { container: CONTAINER, teardown };
}

// Build the container element once (only called on first creation; on a
// reactive re-run the adapter hands the existing container back to
// `renderPlot` as `oldContainer`).
function makeContainer(Plotly, html, css) {
  const CONTAINER = html`<div class='plotlyplot-container'></div>`;
  CONTAINER.Plotly = Plotly;
  // Inject the stylesheet once.
  CONTAINER.appendChild(html`<style>${css}</style>`);
  // Child div that holds the actual Plotly plot.
  CONTAINER.PLOT = CONTAINER.appendChild(html`<div></div>`);
  CONTAINER.isPoppedOut = () => CONTAINER.classList.contains("popped-out");
  return CONTAINER;
}

// Stash the per-plot data on CONTAINER, wire clipboard + resize behaviour, then
// render and attach the user listeners. Runs on every (re-)render. Returns the
// per-run { controller, resizeObserver } so `renderPlot`'s teardown can remove
// exactly the resources this run created on invalidation (the CONTAINER itself
// is reused across reactive re-runs, so these must NOT be stashed on it).
function updatePlotData(CONTAINER, plot_obj, listeners, firstRun) {
  const { Plotly, PLOT } = CONTAINER;
  CONTAINER.plot_obj = plot_obj;
  CONTAINER.original_height = plot_obj.layout?.height;
  CONTAINER.original_width = plot_obj.layout?.width;
  // Flag: remove the fixed inline height/width after the first resize.
  CONTAINER.remove_container_size = firstRun;
  // Fixed height in case the plot sits in a non-fixed-size wrapper (the default).
  const container_height =
    CONTAINER.original_height ?? PLOT.container_height ?? 400;
  CONTAINER.style.height = container_height + "px";
  // Per-run controller: removes the @bind forwarder + all JS listeners when this
  // run is invalidated. Recreated every run because the previous run's controller
  // is aborted on its invalidation.
  const controller = new AbortController();
  // Keep supporting @bind with the old API using PLOT.
  PLOT.addEventListener(
    "input",
    (e) => {
      CONTAINER.value = PLOT.value;
      if (e.bubbles) {
        return;
      }
      CONTAINER.dispatchEvent(new CustomEvent("input"));
    },
    { signal: controller.signal }
  );
  addClipboardFunctionality(CONTAINER, firstRun);
  const resizeObserver = addResizeFunctionality(CONTAINER, firstRun);
  Plotly.react(PLOT, plot_obj).then(() => {
    const { plotlyListeners = {}, jsListeners = {} } = listeners;
    for (const [key, listener_vec] of Object.entries(plotlyListeners)) {
      for (const listener of listener_vec) {
        PLOT.on(key, listener);
      }
    }
    for (const [key, listener_vec] of Object.entries(jsListeners)) {
      for (const listener of listener_vec) {
        PLOT.addEventListener(key, listener, { signal: controller.signal });
      }
    }
  });
  return { controller, resizeObserver };
}
