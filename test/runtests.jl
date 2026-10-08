using TestItemRunner

@testitem "Aqua" begin
    using PlotlyBaseExtras
    using Aqua
    #= 
    Unfortunately we have deps with ambiguities, so the amibiguities test will
    fail for reasons not directly related to this packages's code.
    We separately test for ambiguities alone on the package, as suggested in one
    comment in https://github.com/JuliaTesting/Aqua.jl/issues/77. Not sure whether
    this is actually correctly identifying ambiguities from this package alone.
    =#
    Aqua.test_all(PlotlyBaseExtras; ambiguities = false)
    Aqua.test_ambiguities(PlotlyBaseExtras)
end

@testitem "Coverage Improvements" begin include("basic_coverage.jl") end
@testitem "Extensions" begin include("extensions.jl") end
# PlutoPlotly limits PlotlyBase to 0.8, so only one CI job installs it.
@testitem "PlotlyExtensionsHelper over PlutoPlotly" skip = Base.find_package("PlutoPlotly") === nothing begin
    # PlutoPlotly registers itself with a lower priority, so the result proves that
    # this package wins over it.
    import PlotlyExtensionsHelper, PlutoPlotly
    @test PlotlyExtensionsHelper.plotly_plot(rand(5)) isa PlotlyBaseExtras.PlotlyPlot
end
@testitem "Slate Host" begin include("slate_host.jl") end
@testitem "VSCode Host" begin include("vscode_host.jl") end
@testitem "PlotlyBase API" begin include("plotlybase_api.jl") end
# These items write preferences, so each one gets a private LocalPreferences.toml.
@testitem "Loading modes" setup = [PrivatePrefs] begin PrivatePrefs.with_private_prefs(() -> include("loading_modes.jl")) end
@testitem "MathJax loading" setup = [PrivatePrefs] begin PrivatePrefs.with_private_prefs(() -> include("mathjax_loading.jl")) end
@testitem "HTML output" begin include("html_output.jl") end
# Pluto does not run on Julia 1.13 yet.
@testitem "Pluto Tests" skip = VERSION >= v"1.13" begin include("notebook_tests.jl") end
@testitem "Browser helper" setup=[BrowserHelper] begin include("browser_helper_test.jl") end
@testitem "Plain HTML host" setup=[BrowserHelper] begin include("plain_html_host.jl") end
@testitem "VSCode host browser" setup=[BrowserHelper] begin include("vscode_host_browser.jl") end
# Local-only: drives a running Pluto server in headless Chrome.
@testitem "Pluto host browser" setup = [BrowserHelper] skip = (VERSION >= v"1.13" || get(ENV, "CI", "") == "true") begin include("pluto_host.jl") end

@run_package_tests verbose=true