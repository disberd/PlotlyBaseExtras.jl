using Test
using PlotlyBaseExtras
using PlotlyBaseExtras: PlainHTML, render
const BH = BrowserHelper

p1 = plot(scatter(; x = [1, 2, 3], y = [2, 1, 3]), Layout(; title = "Plain"))
add_js_listener!(p1, "click", "(e) => console.log('host test click')")
p2 = plot(scatter(; x = [1, 2, 3], y = [3, 1, 2]), Layout(; title = L"$\alpha^2$"))

if !BH.chrome_available()
    @warn "Chrome not found: skipping browser tests. Set CHROME_PATH to run them."
    @test_skip true
else
    # One complete page with both plots, served over http so the clipboard API works.
    page_html = sprint() do io
        print(io, """<!doctype html><html><head><meta charset="utf-8"></head><body>""")
        render(io, PlainHTML(), p1)
        render(io, PlainHTML(), p2)
        print(io, "</body></html>")
    end
    path = joinpath(mktempdir(), "plain_html_host.html")
    write(path, page_html)

    BH.with_file(path) do page
        # Plotly and MathJax load from the network, so allow generous timeouts.
        BH.wait_for(page, "document.querySelectorAll('.js-plotly-plot .main-svg').length >= 2"; timeout = 60)
        BH.wait_for(page, "document.querySelector('.gtitle-math-group svg') !== null"; timeout = 60)

        @test isempty(BH.console_errors(page))
        @test BH.count_nodes(page, ".js-plotly-plot") == 2
        @test BH.has_visible_svg(page, ".gtitle-math-group")

        # A real mouse click on a point of the first plot fires the custom listener.
        BH.click(page, ".js-plotly-plot .point")
        # The console message arrives asynchronously over CDP.
        deadline = time() + 20
        while time() < deadline && !("host test click" in BH.console_messages(page))
            sleep(0.1)
        end
        @test "host test click" in BH.console_messages(page)

        # Clipboard acknowledgement on the modebar button of the first plot.
        button = ".js-plotly-plot [data-title=\"Copy PNG to Clipboard\"]"
        visible = BH.evaluate(page, """
            (() => {
                const el = document.querySelector('.js-plotly-plot [data-title="Copy PNG to Clipboard"]');
                return el !== null && el.getBoundingClientRect().width > 0;
            })()
        """) === true
        if visible
            BH.click(page, button)
        else
            BH.evaluate(page, """
                document.querySelector('.js-plotly-plot [data-title="Copy PNG to Clipboard"]').click()
            """)
        end
        try
            BH.wait_for(page, """
                document.querySelector('.js-plotly-plot [data-title="Copy PNG to Clipboard"]').classList.contains('plotlyplot-copied')
            """; timeout = 20)
        catch err
            error("clipboard acknowledgement 'plotlyplot-copied' did not appear within 20 s; " *
                "the copy likely failed (clipboard API refused?): $(sprint(showerror, err))")
        end
        # The button drops the acknowledgement class about one second after the copy.
        BH.wait_for(page, """
            !document.querySelector('.js-plotly-plot [data-title="Copy PNG to Clipboard"]').classList.contains('plotlyplot-copied')
        """; timeout = 3)
        @test isempty(BH.console_errors(page))
    end
end
