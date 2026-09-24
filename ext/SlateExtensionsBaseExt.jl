module SlateExtensionsBaseExt

using PlotlyBaseExtras
import SlateExtensionsBase
using SlateExtensionsBase: html_fragment, provide_assets!, ext_asset_url

struct SlateHost <: PlotlyBaseExtras.Host end

function PlotlyBaseExtras.plotly_import(host::SlateHost, version)
    if VersionNumber(version) == PlotlyBaseExtras.ARTIFACT_VERSION
        return PlotlyBaseExtras._ImportedRemoteJS(
            ext_asset_url(PlotlyBaseExtras, "plotly-esm-min.mjs"),
            "default",
        )
    end
    invoke(PlotlyBaseExtras.plotly_import, Tuple{PlotlyBaseExtras.Host, Any}, host, version)
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
