using Test
using PlotlyBaseExtras
using SlateExtensionsBase: slate_render, ReplayArray
using ScopedValues
const BH = BrowserHelper

if !BH.chrome_available()
    @warn "Chrome not found: skipping browser tests. Set CHROME_PATH to run them."
    @test_skip true
else
    # Three marks: a trace field, a nested trace field and a layout field that the title reads.
    replay(data, id) = ReplayArray(data, id, "k", 1, Any[1, 2, 3])
    p = plot([scatter(y = replay([1.0, 2.0, 3.0], "y"), name = "first"),
            scatter(y = [3, 2, 1], mode = "markers", name = "second",
                marker = attr(color = replay([1.0, 2.0, 3.0], "color")))],
        Layout(title = "k = %{meta[0]}", meta = replay([1.0], "meta")))
    # The test calls plotly.js directly, for the draw count of a plain `Plotly.react`.
    sc = p.script_contents.vec
    insert!(sc, findfirst(==(PlotlyBaseExtras.ADAPTER_SLOT), sc), "globalThis.testPlotly = Plotly")
    html = with(() -> slate_render(p).html, PlotlyBaseExtras.plotly_source => :cdn)

    # A stub of the Slate page API of a static export. As in KaimonSlate, `wire` adds one listener
    # for each mark, and each listener gives its slice from a promise callback.
    stub = """
    const slice = (m, v) => m.path === "meta" ? [v] : [v, v + 1, v + 2].map((x) => x * (m.trace + 1));
    globalThis.Slate = { isLive: () => false, replay: { wire(marks, apply) {
      const input = document.getElementById("control");
      for (const m of marks)
        input.addEventListener("input", () => Promise.resolve().then(() => apply(slice(m, +input.value), m)));
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
            meta: Array.from(gd.layout.meta),
            title: document.querySelector(".gtitle").textContent,
        })"""
        # The draws of one plain `Plotly.react` that changes the same three attributes.
        plain = BH.evaluate(page, """(async () => {
            globalThis.gd = document.querySelector(".js-plotly-plot");
            globalThis.draws = 0;
            gd.on("plotly_afterplot", () => draws++);
            await settle();
            draws = 0;
            gd.data[0].y = [9, 9, 9];
            gd.data[1].marker.color = [9, 9, 9];
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
        @test BH.evaluate(page, state) ==
              Dict("y" => [2, 3, 4], "color" => [4, 6, 8], "meta" => [2], "title" => "k = 2")

        # Two moves in one frame give one redraw, and the last values win. The redraw keeps a zoom
        # and a hidden trace.
        BH.evaluate(page, """(async () => {
            await testPlotly.relayout(gd, { "xaxis.range": [0.5, 1.5] });
            await testPlotly.restyle(gd, { visible: "legendonly" }, [1]);
            await settle();
        })()""")
        @test BH.evaluate(page, "move(6, 7)") == plain
        @test BH.evaluate(page, state) ==
              Dict("y" => [7, 8, 9], "color" => [14, 16, 18], "meta" => [7], "title" => "k = 7")
        @test BH.evaluate(page, "gd.layout.xaxis.range") == [0.5, 1.5]
        @test BH.evaluate(page, "gd.data[1].visible") == "legendonly"
        @test isempty(BH.console_errors(page))
    end
end
