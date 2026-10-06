module SlateExtensionsBaseExt

using PlotlyBaseExtras
import SlateExtensionsBase
using SlateExtensionsBase: html_fragment, provide_assets!, ext_asset_url

struct SlateHost <: PlotlyBaseExtras.Host end

PlotlyBaseExtras.supported_sources(::SlateHost) = (:cdn, :hosted)
PlotlyBaseExtras.auto_source(::SlateHost, version) =
    VersionNumber(version) == PlotlyBaseExtras.ARTIFACT_VERSION ? :hosted : :cdn
PlotlyBaseExtras.adapter_script(::SlateHost) = PlotlyBaseExtras.slate_adapter_script

function PlotlyBaseExtras.plotly_import(::SlateHost, ::Val{:hosted}, version)
    if VersionNumber(version) != PlotlyBaseExtras.ARTIFACT_VERSION
        # Only the artifact bundle is provided as a Slate asset.
        @warn "The hosted source only serves the artifact version $(PlotlyBaseExtras.ARTIFACT_VERSION), loading plotly $(VersionNumber(version)) from cdn instead" maxlog=1 _id=(:slate_hosted_version, version)
        return PlotlyBaseExtras._ImportedRemoteJS(PlotlyBaseExtras.get_plotly_esm_url(version), "default")
    end
    return PlotlyBaseExtras._ImportedRemoteJS(
        ext_asset_url(PlotlyBaseExtras, "plotly-esm-min.mjs"),
        "default",
    )
end

# Large numeric vectors of the plot data go to the page as raw bytes in one Slate cell asset, not as
# JSON text in the script. The asset stays in the cell memo and goes into a static export. The page
# reads each vector as a typed array view of the asset, without a parse. The rest of the data stays
# JSON, with a `{"__pbe_bin": [type, byte offset, length]}` marker in place of each vector.
const BIN_MIN_LENGTH = 1000
const BIN_TYPES = Dict(Float64 => "Float64Array", Float32 => "Float32Array", Int32 => "Int32Array",
    Int16 => "Int16Array", Int8 => "Int8Array", UInt8 => "Uint8Array", UInt16 => "Uint16Array",
    UInt32 => "Uint32Array")
# A BigInt64Array does not mix with JS numbers, so 64-bit integers go as Float64, as JSON.parse gives.
const BinNumber = Union{Float64,Float32,Int64,Int32,Int16,Int8,UInt64,UInt32,UInt16,UInt8}

function _bin!(blob::IOBuffer, v::AbstractVector{<:BinNumber})
    a = eltype(v) <: Union{Int64,UInt64} ? Vector{Float64}(v) : v
    # A typed array view needs an offset that is a multiple of its element size.
    write(blob, zeros(UInt8, -position(blob) & 7))
    offset = position(blob)
    write(blob, a)
    return Dict("__pbe_bin" => (BIN_TYPES[eltype(a)], offset, length(a)))
end

_split!(blob, x) = x
_split!(blob, d::AbstractDict) = Dict{Any,Any}(k => _split!(blob, v) for (k, v) in d)
function _split!(blob, x::AbstractVector)
    T = eltype(x)
    T <: BinNumber && return length(x) >= BIN_MIN_LENGTH ? _bin!(blob, x) : x
    # The rows of a matrix (for example a heatmap `z`) count together.
    T <: AbstractVector{<:BinNumber} && sum(length, x; init = 0) >= BIN_MIN_LENGTH &&
        return map(v -> _bin!(blob, v), x)
    return isbitstype(T) ? x : map(v -> _split!(blob, v), x)
end

struct _AssetData
    tree::Any
    path::String
end

function Base.show(io::IO, ::MIME"text/javascript", d::_AssetData)
    write(io, """await (async (tree, bytes) => {
      const buf = await bytes;
      const put = (x) => {
        if (x === null || typeof x !== "object") return x;
        if (Array.isArray(x)) return x.map(put);
        const b = x.__pbe_bin;
        if (b) return new globalThis[b[0]](buf, b[1], b[2]);
        for (const k in x) x[k] = put(x[k]);
        return x;
      };
      return put(tree);
    })(""")
    PlotlyBaseExtras.write_json(io, d.tree)
    write(io, ", Slate.asset(")
    PlotlyBaseExtras.write_json(io, d.path)
    write(io, "))")
    return nothing
end

# Slate keeps no cell assets in some places (a markdown `{{ }}` interpolation, a `slate_on` handler,
# an SlateExtensionsBase older than 0.11). There the data goes as JSON text.
function PlotlyBaseExtras.to_js(::SlateHost, x::AbstractDict)
    isdefined(SlateExtensionsBase, :slate_save_asset) || return x
    blob = IOBuffer()
    tree = _split!(blob, x)
    position(blob) == 0 && return x
    path = SlateExtensionsBase.slate_save_asset("plotly-data", take!(blob); mime = "application/octet-stream")
    return path === nothing ? x : _AssetData(tree, path)
end

# The holder before the script is where the Slate adapter mounts the plot. Slate keeps an element
# marked `data-slate-keep` across runs of the cell, so the plot updates in place.
# A new holder stays empty until the script loads plotly.js. Its min-height keeps the plot height
# during that time, so the output does not collapse. The height is the height that
# `lib/container.js` gives the container: `layout.height`, else 400 px. The adapter removes the
# min-height when the container is in the holder.
function SlateExtensionsBase.slate_render(p::PlotlyBaseExtras.PlotlyPlot)
    h = p.layout[:height]
    html_fragment(sprint() do io
        print(io, "<div data-slate-keep=\"plotlybaseextras\" style=\"min-height: ", h isa Real ? h : 400, "px\"></div>")
        PlotlyBaseExtras.render(io, SlateHost(), p)
    end)
end

# Loading SlateExtensionsBase invalidates code in the PlotlyBaseExtras package image (the `==`, `hash`
# and `convert` methods for `SlateExtensionsBase.Choice`). The package image of this extension keeps the
# render code compiled after that load. The second render goes through the cell asset path, with a
# Slate context that only gives back a path. Without it, the first large plot of a session compiles
# that path for about 1 s.
PlotlyBaseExtras.PrecompileTools.@compile_workload begin
    SlateExtensionsBase.slate_render(PlotlyBaseExtras.plot(PlotlyBaseExtras.scatter(y = rand(10))))
    ctx = (; save_asset = (name, data; kw...) -> "data/plotly-data.bin")
    task_local_storage(:slate_ctx, ctx) do
        SlateExtensionsBase.slate_render(PlotlyBaseExtras.plot(PlotlyBaseExtras.scatter(y = rand(BIN_MIN_LENGTH))))
    end
end

function __init__()
    provide_assets!(
        PlotlyBaseExtras,
        dirname(PlotlyBaseExtras.get_local_path(PlotlyBaseExtras.ARTIFACT_VERSION)),
    )
end

end
