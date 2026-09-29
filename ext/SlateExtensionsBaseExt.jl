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

# The holder before the script is where the Slate adapter mounts the plot. Slate keeps an element
# marked `data-slate-keep` across runs of the cell, so the plot updates in place.
SlateExtensionsBase.slate_render(p::PlotlyBaseExtras.PlotlyPlot) = html_fragment(
    "<div data-slate-keep=\"plotlybaseextras\"></div>" *
    sprint(io -> PlotlyBaseExtras.render(io, SlateHost(), p)))

# Loading SlateExtensionsBase invalidates code in the PlotlyBaseExtras package image (the `==`, `hash`
# and `convert` methods for `SlateExtensionsBase.Choice`). The package image of this extension keeps the
# render code compiled after that load.
PlotlyBaseExtras.PrecompileTools.@compile_workload begin
    SlateExtensionsBase.slate_render(PlotlyBaseExtras.plot(PlotlyBaseExtras.scatter(y = rand(10))))
end

function __init__()
    provide_assets!(
        PlotlyBaseExtras,
        dirname(PlotlyBaseExtras.get_local_path(PlotlyBaseExtras.ARTIFACT_VERSION)),
    )
end

end
