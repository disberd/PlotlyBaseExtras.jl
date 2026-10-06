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
# The plot mounts in a holder that Slate keeps across runs of the cell. The holder keeps the
# plot height before the script runs: `layout.height`, else the 400 px default of the container.
@test startswith(html, "<div data-slate-keep=\"plotlybaseextras\" style=\"min-height: 400px\"></div>")
@test startswith(slate_render(plot([1], Layout(height = 250))).html,
    "<div data-slate-keep=\"plotlybaseextras\" style=\"min-height: 250px\"></div>")
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

# In a Slate cell, the large numeric vectors go as raw bytes in one cell asset.
let ext = Base.get_extension(PlotlyBaseExtras, :SlateExtensionsBaseExt),
    saved = Vector{UInt8}[], y = rand(2000), x = collect(1:2000), z = rand(Float32, 40, 30)
    save_asset(name, data; mime = "", dtype = nothing) = (push!(saved, data); "data/plotly-data-0.bin")
    in_cell(f, save_asset) = task_local_storage(f, :slate_ctx, (; save_asset))
    big = plot([scatter(; x, y, name = "big"), heatmap(; z)])

    html = in_cell(() -> slate_render(big).html, save_asset)
    @test occursin("Slate.asset(\"data/plotly-data-0.bin\")", html)
    @test length(saved) == 1
    # Read each marker back as the page does: a typed array view of the asset bytes.
    types = Dict(v => k for (k, v) in ext.BIN_TYPES)
    blob = only(saved)
    function read_bin(m)
        T, offset, n = m["__pbe_bin"]
        @test offset % sizeof(types[T]) == 0
        return reinterpret(types[T], blob[offset+1:offset+n*sizeof(types[T])])
    end
    processed = PlotlyBaseExtras._process_with_names(big)
    tree = in_cell(() -> PlotlyBaseExtras.to_js(ext.SlateHost(), processed), save_asset).tree
    # The test environment sets FORCE_FLOAT32, so compare with the processed data.
    trace = processed[:data][1]
    @test read_bin(tree[:data][1][:x]) == trace[:x]
    @test read_bin(tree[:data][1][:y]) == trace[:y]
    @test tree[:data][1][:name] == "big"
    @test [read_bin(r) for r in tree[:data][2][:z]] == processed[:data][2][:z]
    # 64-bit integers go as Float64: a BigInt64Array does not mix with JS numbers.
    io = IOBuffer()
    m = ext._split!(io, Dict(:x => collect(1:2000)))[:x]
    blob = take!(io)
    @test read_bin(m) == 1:2000 && m["__pbe_bin"][1] == "Float64Array"

    # Small data, or a place where Slate keeps no cell assets: the data stays JSON in the script.
    empty!(saved)
    @test occursin("123", in_cell(() -> slate_render(p).html, save_asset))
    @test isempty(saved)
    html = in_cell(() -> slate_render(big).html, (args...; kw...) -> nothing)
    @test !occursin("Slate.asset", html)
    @test occursin(string(trace[:y][1]), html)
end
