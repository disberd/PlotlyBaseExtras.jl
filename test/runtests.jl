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
@testitem "Slate Host" begin include("slate_host.jl") end
@testitem "PlotlyBase API" begin include("plotlybase_api.jl") end
@testitem "Loading modes" begin include("loading_modes.jl") end
# Pluto does not run on Julia 1.13 yet.
@testitem "Pluto Tests" skip = VERSION >= v"1.13" begin include("notebook_tests.jl") end

@run_package_tests verbose=true