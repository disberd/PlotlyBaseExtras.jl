using Test
using JSON
using PlotlyBaseExtras
using PlotlyBaseExtras: PlainHTML, VSCodeHost, render, write_js, get_local_plotly_contents
using SlateExtensionsBase

const SlateHost = Base.get_extension(PlotlyBaseExtras, :SlateExtensionsBaseExt).SlateHost
# The hosts that write the plot data as text in the script.
const text_hosts = (PlainHTML(), VSCodeHost(), SlateHost())

@testset "Strings in the data cannot end the script" begin
    p = plot(
        scatter(y = [1, 2, 3], text = ["</script><b>a</b>", "<!-- b", "c"]),
        Layout(title = "</SCRIPT> t"),
    )
    for host in text_hosts
        html = sprint(io -> render(io, host, p))
        # Only the closing tag that PBE writes at the end.
        @test length(collect(eachmatch(r"</script"i, html))) == 1
        @test endswith(html, "</script>\n")
        @test !occursin("<!--", html)
        # The strings are in the data, with the escaped forms. A `<` before other characters stays.
        @test occursin("\"\\u003c/script><b>a\\u003c/b>\"", html)
        @test occursin("\"\\u003c!-- b\"", html)
        @test occursin("\"\\u003c/SCRIPT> t\"", html)
    end
end

@testset "NaN and Inf in the data" begin
    p = plot(scatter(y = [NaN, Inf, -Inf]), Layout(xaxis = attr(range = [-Inf, Inf])))
    html = sprint(io -> render(io, PlainHTML(), p))
    @test occursin(r"\"y\"\s*:\s*\[\s*NaN\s*,\s*Infinity\s*,\s*-Infinity\s*\]", html)
    @test occursin(r"\"range\"\s*:\s*\[\s*-Infinity\s*,\s*Infinity\s*\]", html)
end

@testset "Bad JS code throws" begin
    p = plot([1, 2])
    bad = ("a </script> b", "a </SCRIPT> b", "a </ScRiPt b", "a <!-- b")
    good = "(e) => console.log('<b>x</b>', 1 < 2, '<script')"
    for code in bad
        @test_throws ArgumentError add_js_listener!(p, "click", code)
        @test_throws ArgumentError add_plotly_listener!(p, "plotly_click", code)
        @test_throws ArgumentError push_script!(p, code)
        @test_throws ArgumentError push_script!(p, good, code)
    end
    @test add_js_listener!(p, "click", good) === p
    @test add_plotly_listener!(p, "plotly_click", good) === p
    @test push_script!(p, good, good) === p
    @test p.js_listeners["click"] == [good]
    @test p.plotly_listeners["plotly_click"] == [good]
    @test count(==(good), p.script_contents.vec) == 2
end

@testset "script_id is escaped" begin
    html = sprint(io -> render(io, PlainHTML(), plot([1, 2]); script_id = "a'b&c<d"))
    @test startswith(html, "<script id='a&#39;b&amp;c&lt;d'>")
end

@testset "The inline bundle reads back" begin
    bundle = get_local_plotly_contents(get_plotly_version())
    # The bundle has text that the writer must escape.
    @test occursin(r"<[/!sS]", bundle)
    written = sprint(write_js, bundle)
    @test !occursin(r"<[/!sS]", written)
    @test JSON.parse(written) == bundle
end
