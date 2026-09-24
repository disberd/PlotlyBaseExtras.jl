using Test
using PlotlyBaseExtras
using PlotlyBaseExtras: LaTeXStrings

const BH = BrowserHelper

# The plot pane shows one plot per page, so each plot goes into its own
# copy of the pane page template. Outside VSCode the plot pane MIME is not
# a text MIME, so `repr` returns bytes that need an explicit String().
mime = MIME"application/vnd.julia-vscode.plotpane+html"()
template = read(joinpath(@__DIR__, "fixtures", "vscode_plotpane_template.html"), String)
pane_page(pp) = replace(template, "{{PAYLOAD}}" => String(repr(mime, pp)))

p1 = plot(scatter(; x = [1, 2, 3], y = [2, 1, 3]), Layout(; title = "Plain"))
add_js_listener!(p1, "click", "(e) => console.log('host test click')")
p2 = plot(scatter(; x = [1, 2, 3], y = [3, 1, 2]), Layout(; title = LaTeXStrings.L"$\alpha^2$"))

# plotly.js and MathJax load from the network, so both pages get long timeouts.
DRAWN = "document.querySelectorAll('.js-plotly-plot .main-svg').length >= 1"

if !BH.chrome_available()
    @warn "Chrome not found: skipping browser tests. Set CHROME_PATH to run them."
    @test_skip true
else
    dir = mktempdir()

    page1 = joinpath(dir, "p1.html")
    write(page1, pane_page(p1))
    BH.with_file(page1) do page
        BH.wait_for(page, DRAWN; timeout = 60)
        @test BH.count_nodes(page, ".js-plotly-plot") == 1
        @test isempty(BH.console_errors(page))
        # The pane sizes the plot to the viewport.
        box = BH.evaluate(page, """
            (() => {
                const r = document.querySelector('.js-plotly-plot .main-svg').getBoundingClientRect();
                return {w: r.width, h: r.height};
            })()
        """)
        @test abs(box["w"] - BH.evaluate(page, "window.innerWidth")) <= 2
        @test abs(box["h"] - BH.evaluate(page, "window.innerHeight")) <= 2
        # Spy on console.log so the wait has a page-side condition; the spy
        # calls the real console, so console_messages still records the event.
        BH.evaluate(page, """
            (() => {
                window.__log = [];
                const orig = console.log;
                console.log = (...a) => { window.__log.push(a.join(' ')); orig(...a); };
            })()
        """)
        BH.click(page, ".js-plotly-plot .point")
        BH.wait_for(page, "window.__log.some(m => m.includes('host test click'))"; timeout = 60)
        @test "host test click" in BH.console_messages(page)
        @test isempty(BH.console_errors(page))
    end

    page2 = joinpath(dir, "p2.html")
    write(page2, pane_page(p2))
    BH.with_file(page2) do page
        BH.wait_for(page, DRAWN; timeout = 60)
        BH.wait_for(page, "document.querySelector('.gtitle-math-group svg') !== null"; timeout = 60)
        @test BH.count_nodes(page, ".js-plotly-plot") == 1
        @test BH.has_svg(page, ".gtitle-math-group")
        @test isempty(BH.console_errors(page))
    end
end
