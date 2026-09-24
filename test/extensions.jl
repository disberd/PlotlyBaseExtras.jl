using PlotlyBaseExtras
using PlotlyBaseExtras: plotly_version
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
                @test_logs (:info, r"with plotly version 2.34.0") savefig(p, "test_savefig.png")
                @test isfile("test_savefig.png")
                @test_logs (:info, r"with plotly version 2.33.0") with(plotly_version => "2.33") do
                    savefig(p, "test_changeversion.png")
                end
                @test isfile("test_changeversion.png")
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
