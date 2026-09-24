using Test
using ScopedValues
using PlotlyBaseExtras
using PlotlyBaseExtras: plotly_version, plotly_source, ARTIFACT_VERSION, PlainHTML, PlutoHost, render
using SlateExtensionsBase

const uuid = PlotlyBaseExtras.PLOTLY_UUID
const SlateHost = Base.get_extension(PlotlyBaseExtras, :SlateExtensionsBaseExt).SlateHost

p = plot([123, 456])

# Rendering a PlutoHost outside Pluto needs Pluto's published_to_js io key,
# the same setup as the "Host rendering" testset in basic_coverage.jl.
function render_pluto(pp)
    # The io key Pluto provides for published_to_js, as in basic_coverage.jl.
    # print_script emits JS values and escapes `</` inside string literals.
    publisher(io, x) = PlotlyBaseExtras.HypertextLiteral.print_script(io, x)
    return sprint() do io
        render(IOContext(io, :pluto_published_to_js => publisher), PlutoHost(), pp)
    end
end

@testset "default outputs" begin
    plain = sprint(io -> render(io, PlainHTML(), p))
    @test occursin("https://esm.sh/plotly.js-dist-min@$(ARTIFACT_VERSION)", plain)

    pluto = render_pluto(p)
    @test occursin("plutoplotly_imports", pluto)

    slate = sprint(io -> render(io, SlateHost(), p))
    @test occursin("/ext-assets/PlotlyBaseExtras/plotly-esm-min.mjs", slate)
end

@testset "PlainHTML" begin
    cdn = sprint(io -> render(io, PlainHTML(), p))
    @test occursin("https://esm.sh/plotly.js-dist-min@", cdn)

    inline = with(plotly_source => :inline) do
        sprint(io -> render(io, PlainHTML(), p))
    end
    @test !occursin("esm.sh", inline)
    @test !occursin("/ext-assets/", inline)
    # The bundle literal is escaped, so it cannot close the surrounding script tag
    @test length(collect(eachmatch(r"</script", inline))) == 1

    # :hosted is not supported on PlainHTML, falls back to :auto with one warning
    fallback = @test_logs (:warn,) with(plotly_source => :hosted) do
        sprint(io -> render(io, PlainHTML(), p))
    end
    @test occursin("https://esm.sh/plotly.js-dist-min@", fallback)
end

@testset "PlutoHost" begin
    cdn = with(plotly_source => :cdn) do
        render_pluto(p)
    end
    @test occursin("https://esm.sh/plotly.js-dist-min@", cdn)

    hosted = with(plotly_source => :hosted) do
        render_pluto(p)
    end
    @test occursin("plutoplotly_imports", hosted)

    inline = with(plotly_source => :inline) do
        render_pluto(p)
    end
    @test !occursin("esm.sh", inline)
    @test !occursin("/ext-assets/", inline)
    @test length(collect(eachmatch(r"</script", inline))) == 1
end

@testset "SlateHost" begin
    slate_cdn = with(plotly_source => :cdn) do
        sprint(io -> render(io, SlateHost(), p))
    end
    @test occursin("https://esm.sh/plotly.js-dist-min@", slate_cdn)

    slate_hosted = with(plotly_source => :hosted) do
        sprint(io -> render(io, SlateHost(), p))
    end
    @test occursin("/ext-assets/PlotlyBaseExtras/plotly-esm-min.mjs", slate_hosted)

    # :inline is not supported on SlateHost, falls back to :auto with one warning
    fallback = @test_logs (:warn,) with(plotly_source => :inline) do
        sprint(io -> render(io, SlateHost(), p))
    end
    @test occursin("/ext-assets/PlotlyBaseExtras/plotly-esm-min.mjs", fallback)
end

@testset "settings chain" begin
    @test get_plotly_version() == ARTIFACT_VERSION
    @test get_plotly_source() === :auto

    try
        PlotlyBaseExtras.Preferences.set_preferences!(uuid, "plotly_version" => "2.33"; force = true)
        PlotlyBaseExtras.Preferences.set_preferences!(uuid, "plotly_source" => "inline"; force = true)
        @test get_plotly_version() == v"2.33"
        @test get_plotly_source() === :inline

        change_plotly_version("2.30")
        change_plotly_source(:cdn)
        @test get_plotly_version() == v"2.30"
        @test get_plotly_source() === :cdn

        @test with(plotly_version => "2.31") do
            get_plotly_version()
        end == v"2.31"
        @test with(plotly_source => :hosted) do
            get_plotly_source()
        end === :hosted
    finally
        PlotlyBaseExtras.Preferences.delete_preferences!(uuid, "plotly_version", "plotly_source"; force = true)
        change_plotly_version(nothing)
        change_plotly_source(nothing)
    end
    @test get_plotly_version() == ARTIFACT_VERSION
    @test get_plotly_source() === :auto

    # Runtime setters still work and clear with nothing
    change_plotly_version("2.30")
    @test get_plotly_version() == v"2.30"
    change_plotly_version(nothing)
    @test get_plotly_version() == ARTIFACT_VERSION
    change_plotly_source(:inline)
    @test get_plotly_source() === :inline
    change_plotly_source(nothing)
    @test get_plotly_source() === :auto

    # Invalid sources throw from any layer
    @test_throws ArgumentError with(plotly_source => :bogus) do
        get_plotly_source()
    end
    @test_throws ArgumentError change_plotly_source(:bogus)
    try
        PlotlyBaseExtras.Preferences.set_preferences!(uuid, "plotly_source" => "bogus"; force = true)
        @test_throws ArgumentError get_plotly_source()
    finally
        PlotlyBaseExtras.Preferences.delete_preferences!(uuid, "plotly_source"; force = true)
    end
end
