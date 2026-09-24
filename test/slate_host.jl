using Test
using ScopedValues
using PlotlyBaseExtras
using PlotlyBaseExtras: PLOTLY_VERSION
using SlateExtensionsBase
using SlateExtensionsBase: slate_render, SlateHtml

slate_extension = Base.get_extension(PlotlyBaseExtras, :SlateExtensionsBaseExt)
SlateHost = slate_extension.SlateHost
p = plot([123, 456])

rendered = slate_render(p)
@test rendered isa SlateHtml
html = rendered.html
@test occursin("123", html)
@test occursin("renderPlot(", html)
@test occursin("currentScript.insertAdjacentElement", html)
@test occursin("/ext-assets/PlotlyBaseExtras/plotly-esm-min.mjs", html)

with(PLOTLY_VERSION => "2.33") do
    html = slate_render(p).html
    @test occursin("https://esm.sh/plotly.js-dist-min@2.33.0", html)
    @test !occursin("/ext-assets/", html)
end

@test showable(SlateExtensionsBase.SlateHtmlMIME(), p)
