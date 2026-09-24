using Test
using ScopedValues
using PlotlyBaseExtras
using PlotlyBaseExtras: mathjax, mathjax_version, mathjax_source, PlainHTML, PlutoHost, render
using SlateExtensionsBase

const uuid = PlotlyBaseExtras.PLOTLY_UUID
const SlateHost = Base.get_extension(PlotlyBaseExtras, :SlateExtensionsBaseExt).SlateHost

const LOAD = "__plotlyBaseExtrasMathJax"
const CDN_URL = "https://cdn.jsdelivr.net/npm/mathjax@3.2.2/es5/tex-svg.js"

p_math = plot([1, 2, 3], Layout(title = L"$x^2$"))
p_plain = plot([123, 456])

# Rendering a PlutoHost outside Pluto needs Pluto's published_to_js io key,
# the same setup as the "Host rendering" testset in basic_coverage.jl.
function render_pluto(pp)
    publisher(io, x) = PlotlyBaseExtras.HypertextLiteral.print_script(io, x)
    return sprint() do io
        render(IOContext(io, :pluto_published_to_js => publisher), PlutoHost(), pp)
    end
end

@testset "auto mode" begin
    auto_math = sprint(io -> render(io, PlainHTML(), p_math))
    @test occursin(LOAD, auto_math)
    @test occursin(CDN_URL, auto_math)
    @test occursin("await window.MathJax.startup.promise", auto_math)
    @test occursin("""svg: { fontCache: "local" }""", auto_math)
    # The shared promise and the existing-MathJax guard
    @test occursin("window.__plotlyBaseExtrasMathJax ??=", auto_math)
    @test occursin("if (window.MathJax?.version) return;", auto_math)
    # Loader errors must not stop the plot from rendering
    @test occursin("catch", auto_math)

    # Without a dollar the loader is absent, so the default output stays unchanged
    auto_plain = sprint(io -> render(io, PlainHTML(), p_plain))
    @test !occursin(LOAD, auto_plain)
end

@testset "on and off modes" begin
    on_plain = with(mathjax => :on) do
        sprint(io -> render(io, PlainHTML(), p_plain))
    end
    @test occursin(LOAD, on_plain)
    @test occursin(CDN_URL, on_plain)

    off_math = with(mathjax => :off) do
        sprint(io -> render(io, PlainHTML(), p_math))
    end
    @test !occursin(LOAD, off_math)
    @test !occursin("jsdelivr.net/npm/mathjax", off_math)
end

@testset "version and source" begin
    url = with(mathjax_version => "3.2.1") do
        sprint(io -> render(io, PlainHTML(), p_math))
    end
    @test occursin("https://cdn.jsdelivr.net/npm/mathjax@3.2.1/es5/tex-svg.js", url)
    @test !occursin(CDN_URL, url)

    # The inline bundle replaces the cdn URL. This downloads the 2 MB bundle once.
    inline = with(mathjax_source => :inline) do
        sprint(io -> render(io, PlainHTML(), p_math))
    end
    @test occursin(LOAD, inline)
    @test !occursin("cdn.jsdelivr.net/npm/mathjax", inline)
    # The bundle literal is escaped, so it cannot close the surrounding script tag
    @test length(collect(eachmatch(r"</script", inline))) == 1
    @test occursin("s.textContent =", inline)
end

@testset "PlutoHost" begin
    # The Pluto page already ships MathJax, so :auto is :hosted and emits no loader
    @test !occursin(LOAD, render_pluto(p_math))

    cdn = with(mathjax_source => :cdn) do
        render_pluto(p_math)
    end
    @test occursin(CDN_URL, cdn)
end

@testset "unsupported source fallback" begin
    # PlainHTML does not support :hosted, falls back to :auto with one warning
    fallback = @test_logs (:warn,) with(mathjax_source => :hosted) do
        sprint(io -> render(io, PlainHTML(), p_math))
    end
    @test occursin(CDN_URL, fallback)
end

@testset "SlateHost" begin
    slate_math = sprint(io -> render(io, SlateHost(), p_math))
    @test occursin(LOAD, slate_math)
    @test occursin(CDN_URL, slate_math)
    @test !occursin(LOAD, sprint(io -> render(io, SlateHost(), p_plain)))
end

@testset "settings chain" begin
    @test get_mathjax() === :auto
    @test get_mathjax_version() == v"3.2.2"
    @test get_mathjax_source() === :auto

    try
        PlotlyBaseExtras.Preferences.set_preferences!(uuid,
            "mathjax" => "off", "mathjax_version" => "3.2.0", "mathjax_source" => "cdn";
            force = true)
        @test get_mathjax() === :off
        @test get_mathjax_version() == v"3.2.0"
        @test get_mathjax_source() === :cdn

        change_mathjax(:on)
        change_mathjax_version("3.2.1")
        change_mathjax_source(:inline)
        @test get_mathjax() === :on
        @test get_mathjax_version() == v"3.2.1"
        @test get_mathjax_source() === :inline

        @test with(mathjax => :off) do
            get_mathjax()
        end === :off
        @test with(mathjax_version => "3.2.2") do
            get_mathjax_version()
        end == v"3.2.2"
        @test with(mathjax_source => :hosted) do
            get_mathjax_source()
        end === :hosted
    finally
        PlotlyBaseExtras.Preferences.delete_preferences!(uuid,
            "mathjax", "mathjax_version", "mathjax_source"; force = true)
        change_mathjax(nothing)
        change_mathjax_version(nothing)
        change_mathjax_source(nothing)
    end
    @test get_mathjax() === :auto
    @test get_mathjax_version() == v"3.2.2"
    @test get_mathjax_source() === :auto

    # Runtime setters still work and clear with nothing
    change_mathjax(:off)
    @test get_mathjax() === :off
    change_mathjax(nothing)
    @test get_mathjax() === :auto
    change_mathjax_version("3.2.0")
    @test get_mathjax_version() == v"3.2.0"
    change_mathjax_version(nothing)
    @test get_mathjax_version() == v"3.2.2"
    change_mathjax_source(:cdn)
    @test get_mathjax_source() === :cdn
    change_mathjax_source(nothing)
    @test get_mathjax_source() === :auto

    # Invalid values throw from any layer
    @test_throws ArgumentError with(mathjax => :bogus) do
        get_mathjax()
    end
    @test_throws ArgumentError with(mathjax_source => :bogus) do
        get_mathjax_source()
    end
    @test_throws ArgumentError change_mathjax(:bogus)
    @test_throws ArgumentError change_mathjax_source(:bogus)
    @test_throws ArgumentError change_mathjax_version("not a version")
    try
        PlotlyBaseExtras.Preferences.set_preferences!(uuid, "mathjax" => "bogus"; force = true)
        @test_throws ArgumentError get_mathjax()
    finally
        PlotlyBaseExtras.Preferences.delete_preferences!(uuid, "mathjax"; force = true)
    end
end
