module SlateExtensionsBaseExt

using PlotlyBaseExtras
import SlateExtensionsBase
using SlateExtensionsBase: html_fragment, provide_assets!, ext_asset_url

struct SlateHost <: PlotlyBaseExtras.Host end

PlotlyBaseExtras.supported_sources(::SlateHost) = (:cdn, :hosted)
PlotlyBaseExtras.auto_source(::SlateHost, version) =
    VersionNumber(version) == PlotlyBaseExtras.ARTIFACT_VERSION ? :hosted : :cdn

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

SlateExtensionsBase.slate_render(p::PlotlyBaseExtras.PlotlyPlot) =
    html_fragment(sprint(io -> PlotlyBaseExtras.render(io, SlateHost(), p)))

function __init__()
    provide_assets!(
        PlotlyBaseExtras,
        dirname(PlotlyBaseExtras.get_local_path(PlotlyBaseExtras.ARTIFACT_VERSION)),
    )
end

end
