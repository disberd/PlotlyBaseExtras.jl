using Test
using PlotlyBaseExtras
using PlotlyBaseExtras: PlainHTML, render
using ScopedValues
const BH = BrowserHelper

p1 = plot(scatter(; x = [1, 2, 3], y = [2, 1, 3]), Layout(; title = "Plain"))
add_js_listener!(p1, "click", "(e) => console.log('host test click')")
p2 = plot(scatter(; x = [1, 2, 3], y = [3, 1, 2]), Layout(; title = L"$\alpha^2$"))

if !BH.chrome_available()
    @warn "Chrome not found: skipping browser tests. Set CHROME_PATH to run them."
    @test_skip true
else
    # The modebar clipboard button, found by a hook that does not depend on the tooltip text.
    COPY_BUTTON = ".modebar-btn[data-val=\"plotlyplot-copy\"]"
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
        button = ".js-plotly-plot $(COPY_BUTTON)"
        @test BH.evaluate(page, "document.querySelector('$(button)').dataset.title") ==
              "Copy PNG to clipboard · double-click: export options"
        visible = BH.evaluate(page, """
            (() => {
                const el = document.querySelector('$(button)');
                return el !== null && el.getBoundingClientRect().width > 0;
            })()
        """) === true
        if visible
            BH.click(page, button)
        else
            BH.evaluate(page, "document.querySelector('$(button)').click()")
        end
        try
            BH.wait_for(page, """
                document.querySelector('$(button)').classList.contains('plotlyplot-copied')
            """; timeout = 20)
        catch err
            error("clipboard acknowledgement 'plotlyplot-copied' did not appear within 20 s; " *
                "the copy likely failed (clipboard API refused?): $(sprint(showerror, err))")
        end
        # A successful copy opens no Copy dialog.
        @test BH.count_nodes(page, "dialog[open]") == 0
        # The button drops the acknowledgement class about one second after the copy.
        BH.wait_for(page, """
            !document.querySelector('$(button)').classList.contains('plotlyplot-copied')
        """; timeout = 3)
        @test isempty(BH.console_errors(page))
    end

    # A page without the clipboard API: the clipboard button opens the Copy dialog.
    no_clipboard_html = sprint() do io
        print(io, """<!doctype html><html><head><meta charset="utf-8"></head><body>""")
        render(io, PlainHTML(), p1)
        print(io, "</body></html>")
    end
    no_clipboard_path = joinpath(mktempdir(), "plain_html_no_clipboard.html")
    write(no_clipboard_path, no_clipboard_html)
    remove_clipboard = "Object.defineProperty(Navigator.prototype, 'clipboard', { get: () => undefined });"
    press_escape(page) = for typ in ("keyDown", "keyUp")
        BH.cdp_call(page, "Input.dispatchKeyEvent";
            params = Dict("type" => typ, "key" => "Escape", "code" => "Escape", "windowsVirtualKeyCode" => 27))
    end
    dialog = ".plotlyplot-container dialog.plotlyplot-copy-dialog"
    BH.with_file(no_clipboard_path; init_script = remove_clipboard) do page
        BH.wait_for(page, "document.querySelector('.js-plotly-plot .main-svg') !== null"; timeout = 60)
        button = ".js-plotly-plot $(COPY_BUTTON)"
        @test BH.evaluate(page, "navigator.clipboard === undefined") === true
        @test BH.evaluate(page, "document.querySelector('$(button)').dataset.title") ==
              "Show PNG to copy (right-click → Copy image) · double-click: export options"

        # A single click opens the dialog inside the plot container, with the image at the export size.
        BH.click(page, button)
        BH.wait_for(page, """
            (() => {
                const img = document.querySelector('$(dialog)[open] img');
                return img !== null && img.complete && img.naturalWidth > 0;
            })()
        """; timeout = 20)
        sizes = BH.evaluate(page, """
            (() => {
                const container = document.querySelector('.plotlyplot-container');
                const gd = container.querySelector('.js-plotly-plot');
                const o = container.plot_obj.config.toImageButtonOptions ?? {};
                const img = container.querySelector('dialog[open] img');
                return {
                    expected: Math.round((o.width ?? gd._fullLayout.width) * (o.scale ?? 1)),
                    actual: img.naturalWidth,
                };
            })()
        """)
        @test sizes["actual"] == sizes["expected"]
        BH.wait_for(page, "document.querySelector('$(dialog) .copy-dialog-size').textContent.endsWith(' px')"; timeout = 5)

        # Esc closes the dialog, and the plot stays.
        press_escape(page)
        BH.wait_for(page, "document.querySelector('$(dialog)').open === false"; timeout = 5)
        @test BH.count_nodes(page, ".plotlyplot-container .js-plotly-plot") == 1
        @test BH.count_nodes(page, ".plotlyplot-container .js-plotly-plot .main-svg") >= 1
        @test isempty(BH.console_errors(page))

        # The Export pop-out stays open when the Copy dialog opens and closes.
        # A double-click is two clicks within 300 ms.
        BH.evaluate(page, """
            (() => {
                const el = document.querySelector('$(button)');
                el.click();
                el.click();
            })()
        """)
        BH.wait_for(page, "document.querySelector('.plotlyplot-container').classList.contains('popped-out')"; timeout = 5)
        BH.click(page, button)
        BH.wait_for(page, "document.querySelector('$(dialog)').open === true"; timeout = 20)
        # A real mouse press on the backdrop, at the corner of the viewport, closes the dialog.
        for typ in ("mousePressed", "mouseReleased")
            BH.cdp_call(page, "Input.dispatchMouseEvent";
                params = Dict("type" => typ, "x" => 1, "y" => 1, "button" => "left", "clickCount" => 1))
        end
        BH.wait_for(page, "document.querySelector('$(dialog)').open === false"; timeout = 5)
        @test BH.evaluate(page, "document.querySelector('.plotlyplot-container').classList.contains('popped-out')") === true
        @test isempty(BH.console_errors(page))
    end

    # `:inline` embeds the plotly.js bundle in the page and imports it from a blob URL.
    inline_html = sprint() do io
        print(io, """<!doctype html><html><head><meta charset="utf-8"></head><body>""")
        with(PlotlyBaseExtras.plotly_source => :inline) do
            render(io, PlainHTML(), p1)
        end
        print(io, "</body></html>")
    end
    inline_path = joinpath(mktempdir(), "plain_html_inline.html")
    write(inline_path, inline_html)
    BH.with_file(inline_path) do page
        BH.wait_for(page, "document.querySelector('.js-plotly-plot .main-svg') !== null"; timeout = 60)
        @test isempty(BH.console_errors(page))
    end
end
