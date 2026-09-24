using PlotlyBaseExtras
using PlotlyBaseExtras: plotly_version, mathjax, ARTIFACT_VERSION
using Test
using ScopedValues

## PlotlyKaleido Extension ##
using PlotlyKaleido
if Sys.islinux()
    # We only test this in linux as the library fail in CI on Mac OS and Windows
    PlotlyKaleido.start()

    try
        mktempdir() do dir
            cd() do 
                p = plot(rand(10,4))
                @test_logs (:info, Regex("with plotly version $ARTIFACT_VERSION")) savefig(p, "test_savefig.png")
                @test isfile("test_savefig.png")
                @test_logs (:info, r"with plotly version 2.33.0") with(plotly_version => "2.33") do
                    savefig(p, "test_changeversion.png")
                end
                @test isfile("test_changeversion.png")

                # plotly.js 3 dropped the String title, and plotly.js 4 dropped MathJax 2.
                # The export gets the processed plot and the MathJax 3 bundle, so both titles show.
                p = plot(rand(3), Layout(title = "String title", xaxis_title = L"\alpha^2"))
                savefig(p, "titles.svg")
                svg = read("titles.svg", String)
                @test occursin("String title", svg)
                @test occursin(r"xtitle-math-group[^>]*><svg", svg)

                # A change of the MathJax setting restarts Kaleido without MathJax.
                @test_logs (:info, r"Starting the kaleido process") with(mathjax => :off) do
                    savefig(p, "titles_nomath.svg")
                end
                @test !occursin(r"xtitle-math-group[^>]*><svg", read("titles_nomath.svg", String))
            end
        end
    finally
        PlotlyKaleido.kill_kaleido()
    end
end

## Unitful Extension ##
using PlotlyBaseExtras: _process_with_names
using Unitful: °, ustrip

uv_r = range(0°, 100°; step = 1°)
@test _process_with_names(uv_r) == collect(0:100)
uv_a = rand(3,5) .* °
uv_a_strip = ustrip.(uv_a)
@test _process_with_names(uv_a) == _process_with_names(uv_a_strip)

## PlotlyExtensionsHelper Extension ##
# PlutoPlotly registers itself with a lower priority, so the result proves that
# this package wins over it.
import PlotlyExtensionsHelper, PlutoPlotly
@test PlotlyExtensionsHelper.plotly_plot(rand(5)) isa PlotlyBaseExtras.PlotlyPlot
