// The adapter for KaimonSlate. It keeps the plot container across runs of the
// cell, as the Pluto adapter does with `this`.
// Expects in closure scope (from the Julia preamble in src/show.jl + the css
// binding in src/main_struct.jl): plot_obj, Plotly, plotly_listeners,
// js_listeners, css; and the wrapper's `currentScript`.
//
// The Slate extension puts a `<div data-slate-keep>` holder just before this
// script. A Slate that supports `data-slate-keep` gives back the holder of the
// previous run, with its container inside. In other cases (a Slate without that
// support, a resync, a markdown re-render) Slate gives a new, empty holder. Then
// the adapter finds the container of the previous run in a map for the page and
// uses it again.

const holder = currentScript.previousElementSibling;

// The map key is the cell id plus the index of the holder among the holders of
// the cell, so each plot of a cell keeps its own container. Slate does not
// document `data-cid`. KaimonSlate puts it on the cell element (notebook.js),
// but also on other elements, for example the activity log. The activity log
// keeps entries for deleted cells. Thus the adapter uses only the
// `.cell[data-cid]` element. Out of this element, the adapter does not use the
// map and each run makes a new container.
const cell = holder.closest(".cell[data-cid]");
const cid = cell?.dataset.cid;
const key =
  cell &&
  `${cid}:${[...cell.querySelectorAll('[data-slate-keep="plotlybaseextras"]')].indexOf(holder)}`;
// Each run of this script is a new closure, so the map is on `globalThis`.
const mounts = (globalThis.plotlybaseextras_slate_containers ??= new Map());

// A new, empty holder: use the container of the previous run again if Slate
// removed it from the document. A connected container stays where it is.
const last = key && mounts.get(key);
if (last && !holder.firstElementChild && !last.container.isConnected) {
  holder.appendChild(last.container);
  holder.__teardown = last.teardown;
}
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

// `@replay`: in a static export, a moved control gives one slice of shipped data per mark
// (`replay_marks`, from the Slate extension). The slices of one move arrive in separate callbacks,
// one for each mark, so the adapter collects them and draws them with one `Plotly.react` in the
// next frame. A batch on a microtask does not work: a microtask runs between two event listeners,
// so one move would draw once per mark. The redraw starts from `PLOT.data` and `PLOT.layout`, so it
// keeps what the reader did (zoom, legend clicks). Live, `wire` does nothing: the cell runs again
// in Julia.
function setReplayPath(obj, path, value) {
  const keys = path.replace(/\[(\d+)\]/g, ".$1").split(".");
  const last = keys.pop();
  for (const k of keys) obj = obj[k] ??= {};
  obj[last] = value;
}
// A slice of an export has Float32 values, and a text template prints `meta` as it is: 9.1 shows
// as 9.100000381469727. Julia writes a Float32 with the shortest text that gives the same Float32,
// so the adapter does the same for `meta`. The other paths stay as they are: plotly.js formats an
// axis value itself, and a large slice would cost a text conversion of each number on each move.
function shortFloat32(v) {
  if (Math.fround(v) !== v) return v; // Not a Float32 value, or NaN.
  for (let p = 1; p < 9; p++) if (Math.fround(+v.toPrecision(p)) === v) return +v.toPrecision(p);
  return +v.toPrecision(9); // Nine digits give back each Float32.
}
// The key is the mark, not its `id`: the same replayed data in two places gives two marks with the
// same `id`. A later slice for a mark replaces the earlier one.
const replayPending = new Map();
function applyReplay(slice, mark) {
  if (!replayPending.size)
    requestAnimationFrame(() => {
      for (let [m, s] of replayPending) {
        // Slate gives a matrix slice as rows (`s[r][c]` is element (r, c)). Julia writes a matrix
        // as its columns (`_nested_arrays` in src/preprocess.jl), so the adapter makes columns.
        if (Array.isArray(s[0])) s = s[0].map((_, c) => s.map((row) => row[c]));
        else if (m.path === "meta") s = Array.from(s, shortFloat32);
        setReplayPath(m.trace === null ? PLOT.layout : PLOT.data[m.trace], m.path, s);
      }
      replayPending.clear();
      Plotly.react(PLOT, PLOT.data, PLOT.layout);
    });
  replayPending.set(mark, slice);
}
if (replay_marks.length) globalThis.Slate?.replay?.wire(replay_marks, applyReplay);

if (!oldContainer) holder.appendChild(CONTAINER);
// The container sets its own height. Remove the min-height that the Slate
// extension gives the holder, or a kept holder keeps the height of the
// previous run.
holder.style.minHeight = "";
holder.__teardown = teardown;

if (key) {
  mounts.set(key, { cid, container: CONTAINER, teardown });
  // Destroy the containers of the cells that are no longer in the document.
  // Slate does not tell the adapter when it deletes a cell. A cell that shows
  // fewer plots than before keeps the containers of the other plots until the
  // cell is deleted.
  const cids = new Set([...document.querySelectorAll(".cell[data-cid]")].map((el) => el.dataset.cid));
  for (const [k, m] of mounts) {
    if (cids.has(m.cid)) continue;
    m.teardown();
    destroyContainer(m.container);
    mounts.delete(k);
  }
}

// Slate sends `slate:discard` when it removes the holder for good. The
// container is the same in each run, so the listener of the first run is enough.
if (!holder.__discardWired) {
  holder.__discardWired = true;
  holder.addEventListener("slate:discard", () => {
    // A new holder can have the container now. Then it is not for this holder to destroy.
    if (CONTAINER.parentElement !== holder) return;
    holder.__teardown?.();
    destroyContainer(CONTAINER);
    // Remove the map entry, so that the sweep does not destroy the container again.
    for (const [k, m] of mounts) if (m.container === CONTAINER) mounts.delete(k);
  });
}
