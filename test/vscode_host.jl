using Test
using ScopedValues
using PlotlyBaseExtras
using PlotlyBaseExtras: plotly_source, ARTIFACT_VERSION, render, VSCodeHost

p = plot([123, 456])

@testset "VSCodeHost rendering" begin
    html = sprint(io -> render(io, VSCodeHost(), p))
    @test occursin("123", html)
    @test occursin("renderPlot(", html)
    @test occursin("currentScript.insertAdjacentElement", html)
    # The plot fills the pane and re-lays out on window resize.
    @test occursin("100vw", html)
    @test occursin("100vh", html)
    @test occursin("window.addEventListener(\"resize\"", html)
    @test occursin("Plotly.Plots.resize(PLOT)", html)
    # Default settings load plotly.js from esm.sh.
    @test occursin("https://esm.sh/plotly.js-dist-min@$(ARTIFACT_VERSION)", html)
end

@testset "VSCodeHost :hosted fallback" begin
    fallback = @test_logs (:warn,) with(plotly_source => :hosted) do
        sprint(io -> render(io, VSCodeHost(), p))
    end
    @test occursin("https://esm.sh/plotly.js-dist-min@", fallback)
end

@testset "VSCodeHost plot pane MIME" begin
    mime = MIME"application/vnd.julia-vscode.plotpane+html"()
    @test showable(mime, p)
    # Outside VSCode this MIME is not a text MIME, so `repr` returns bytes.
    # Compare modulo the script id.
    strip_id(s) = replace(s, r"plot_-?\d+" => "plot_X")
    @test strip_id(String(repr(mime, p))) == strip_id(sprint(io -> render(io, VSCodeHost(), p)))
end
