using Test
using PlotlyBaseExtras
using SlateExtensionsBase: slate_render, ReplayArray
using ScopedValues
const BH = BrowserHelper

if !BH.chrome_available()
    @warn "Chrome not found: skipping browser tests. Set CHROME_PATH to run them."
    @test_skip true
else
    # Four marks: a trace field, a nested trace field, a matrix and a layout field that the title
    # reads.
    replay(data, id) = ReplayArray(data, id, "k", 1, Any[1, 2, 3])
    p = plot([scatter(y = replay([1.0, 2.0, 3.0], "y"), name = "first"),
            scatter(y = [3, 2, 1], mode = "markers", name = "second",
                marker = attr(color = replay([2.0, 4.0, 6.0], "color"))),
            heatmap(z = replay([1.0 3.0 5.0; 2.0 4.0 6.0], "z"), showscale = false)],
        Layout(title = "k = %{meta[0]}", meta = replay([1.1], "meta")))
    # The test calls plotly.js directly, for the draw count of a plain `Plotly.react`.
    sc = p.script_contents.vec
    insert!(sc, findfirst(==(PlotlyBaseExtras.ADAPTER_SLOT), sc), "globalThis.testPlotly = Plotly")
    html = with(() -> slate_render(p).html, PlotlyBaseExtras.plotly_source => :cdn)

    # A stub of the Slate page API of a static export. As in KaimonSlate, `wire` adds one listener
    # for each mark, each listener gives its slice from a promise callback, and the slices of the
    # start value draw one time on load. A slice is what `Slate.replay.slice` of KaimonSlate gives:
    # the export narrows the data to Float32, and a matrix (column-major) becomes an array of rows.
    stub = """
    const f32 = (a) => Array.from(new Float32Array(a));
    const slice = (m, v) => {
      if (m.path === "meta") return f32([v + 0.1]);
      if (m.path === "z") {
        const flat = f32([1, 2, 3, 4, 5, 6].map((x) => x * v));
        return [0, 1].map((r) => [0, 1, 2].map((c) => flat[c * 2 + r]));
      }
      return f32([v, v + 1, v + 2].map((x) => x * (m.trace + 1)));
    };
    globalThis.Slate = { isLive: () => false, replay: { wire(marks, apply) {
      const input = document.getElementById("control");
      for (const m of marks) {
        input.addEventListener("input", () => Promise.resolve().then(() => apply(slice(m, +input.value), m)));
        Promise.resolve().then(() => apply(slice(m, +input.value), m));
      }
    } } };
    // Wait until the draws of the last change are done.
    globalThis.settle = () => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(() => setTimeout(r, 100))));
    // Two moves from a script, in one task: the listeners of both run before any slice.
    globalThis.move = async (...values) => {
      const input = document.getElementById("control");
      draws = 0;
      for (const v of values) {
        input.value = v;
        input.dispatchEvent(new Event("input"));
      }
      await settle();
      return draws;
    };
    """
    path = joinpath(mktempdir(), "slate_replay.html")
    write(path, """
    <!doctype html><html><head><meta charset="utf-8"></head><body>
    <input id="control" type="number" value="1">
    <script>$stub</script>
    $html
    </body></html>
    """)

    BH.with_file(path) do page
        BH.wait_for(page, "document.querySelector('.js-plotly-plot .main-svg') !== null"; timeout = 60)
        state = """({
            y: Array.from(gd.data[0].y),
            color: Array.from(gd.data[1].marker.color),
            z: Array.from(gd.data[2].z, (row) => Array.from(row)),
            meta: Array.from(gd.layout.meta),
            title: document.querySelector(".gtitle").textContent,
        })"""
        # The slices of the start value give the figure that Julia drew: a matrix has the same
        # layout as the matrix that Julia writes, and the title shows no Float32 noise.
        BH.evaluate(page, """(async () => {
            globalThis.gd = document.querySelector(".js-plotly-plot");
            await settle();
        })()""")
        @test BH.evaluate(page, state) == Dict("y" => [1, 2, 3], "color" => [2, 4, 6],
            "z" => [[1, 2], [3, 4], [5, 6]], "meta" => [1.1], "title" => "k = 1.1")
        # The draws of one plain `Plotly.react` that changes the same four attributes.
        plain = BH.evaluate(page, """(async () => {
            globalThis.draws = 0;
            gd.on("plotly_afterplot", () => draws++);
            draws = 0;
            gd.data[0].y = [9, 9, 9];
            gd.data[1].marker.color = [9, 9, 9];
            gd.data[2].z = [[9, 9], [9, 9], [9, 9]];
            gd.layout.meta = [9];
            await testPlotly.react(gd, gd.data, gd.layout);
            await settle();
            return draws;
        })()""")
        @test plain >= 1
        # One move draws as much as one plain `Plotly.react`, with each slice at its path. The move
        # is a real key press: the browser fires `input`, and a microtask runs between two
        # listeners, as on a real slider move.
        BH.evaluate(page, "draws = 0; document.getElementById('control').focus()")
        for typ in ("rawKeyDown", "keyUp")
            BH.cdp_call(page, "Input.dispatchKeyEvent";
                params = Dict("type" => typ, "key" => "ArrowUp", "code" => "ArrowUp", "windowsVirtualKeyCode" => 38))
        end
        @test BH.evaluate(page, "settle().then(() => draws)") == plain
        @test BH.evaluate(page, state) == Dict("y" => [2, 3, 4], "color" => [4, 6, 8],
            "z" => [[2, 4], [6, 8], [10, 12]], "meta" => [2.1], "title" => "k = 2.1")

        # Two moves in one frame give one redraw, and the last values win. The redraw keeps a zoom
        # and a hidden trace.
        BH.evaluate(page, """(async () => {
            await testPlotly.relayout(gd, { "xaxis.range": [0.5, 1.5] });
            await testPlotly.restyle(gd, { visible: "legendonly" }, [1]);
            await settle();
        })()""")
        @test BH.evaluate(page, "move(6, 7)") == plain
        @test BH.evaluate(page, state) == Dict("y" => [7, 8, 9], "color" => [14, 16, 18],
            "z" => [[7, 14], [21, 28], [35, 42]], "meta" => [7.1], "title" => "k = 7.1")
        @test BH.evaluate(page, "gd.layout.xaxis.range") == [0.5, 1.5]
        @test BH.evaluate(page, "gd.data[1].visible") == "legendonly"
        @test isempty(BH.console_errors(page))
    end
end
