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

# In a Slate cell, the numeric vectors with at least `slate_asset_min_length` numbers go as raw bytes
# in one cell asset.
let ext = Base.get_extension(PlotlyBaseExtras, :SlateExtensionsBaseExt),
    saved = Vector{UInt8}[], y = rand(2000), x = collect(1:2000), z = rand(Float32, 40, 30)
    save_asset(name, data; mime = "", dtype = nothing) = (push!(saved, data); "data/plotly-data-0.bin")
    in_cell(f, save_asset) = task_local_storage(f, :slate_ctx, (; save_asset))
    min_length(f, n) = with(f, PlotlyBaseExtras.slate_asset_min_length => n)
    big = plot([scatter(; x, y, name = "big"), heatmap(; z)])

    html = min_length(1000) do
        in_cell(() -> slate_render(big).html, save_asset)
    end
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
    to_js(n) = min_length(n) do
        in_cell(() -> PlotlyBaseExtras.to_js(ext.SlateHost(), processed), save_asset)
    end
    tree = to_js(1000).tree
    # The test environment sets FORCE_FLOAT32, so compare with the processed data.
    trace = processed[:data][1]
    @test read_bin(tree[:data][1][:x]) == trace[:x]
    @test read_bin(tree[:data][1][:y]) == trace[:y]
    @test tree[:data][1][:name] == "big"
    @test [read_bin(r) for r in tree[:data][2][:z]] == processed[:data][2][:z]
    # The 30 rows of 40 numbers of `z` count together: 1200 numbers.
    @test haskey(to_js(1200).tree[:data][2][:z][1], "__pbe_bin")
    tree = to_js(1201).tree
    @test tree[:data][2][:z] == processed[:data][2][:z]
    @test haskey(tree[:data][1][:y], "__pbe_bin")
    # 64-bit integers go as Float64: a BigInt64Array does not mix with JS numbers.
    io = IOBuffer()
    m = ext._split!(io, Dict(:x => collect(1:2000)), 1000)[:x]
    blob = take!(io)
    @test read_bin(m) == 1:2000 && m["__pbe_bin"][1] == "Float64Array"

    # Data under the limit (the default limit is 10^4), a limit larger than any vector, or a place
    # where Slate keeps no cell assets: the data stays JSON in the script.
    empty!(saved)
    @test occursin(string(trace[:y][1]), in_cell(() -> slate_render(big).html, save_asset))
    @test to_js(typemax(Int)) === processed
    @test isempty(saved)
    html = min_length(1000) do
        in_cell(() -> slate_render(big).html, (args...; kw...) -> nothing)
    end
    @test !occursin("Slate.asset", html)
    @test occursin(string(trace[:y][1]), html)
end
