using Test
using ScopedValues
using PlotlyBaseExtras
using PlotlyBaseExtras: plotly_version
using SlateExtensionsBase
using SlateExtensionsBase: slate_render, SlateHtml

@test !isnothing(Base.get_extension(PlotlyBaseExtras, :SlateExtensionsBaseExt))
p = plot([123, 456])

rendered = slate_render(p)
@test rendered isa SlateHtml
html = rendered.html
@test occursin("123", html)
@test occursin("renderPlot(", html)
@test occursin("currentScript.insertAdjacentElement", html)
@test occursin("/ext-assets/PlotlyBaseExtras/plotly-esm-min.mjs", html)

with(plotly_version => "2.33") do
    html = slate_render(p).html
    @test occursin("https://esm.sh/plotly.js-dist-min@2.33.0", html)
    @test !occursin("/ext-assets/", html)
end

@test showable(SlateExtensionsBase.SlateHtmlMIME(), p)

# A `$` label loads MathJax from cdn on Slate, which provides no MathJax asset.
let p_math = plot([1, 2, 3], Layout(title = L"$x^2$"))
    html_math = slate_render(p_math).html
    @test occursin("__plotlyBaseExtrasMathJax", html_math)
    @test occursin("https://cdn.jsdelivr.net/npm/mathjax@3.2.2/es5/tex-svg.js", html_math)
end
