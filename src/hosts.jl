abstract type Host end
struct PlainHTML <: Host end
struct PlutoHost <: Host end

current_host() = is_inside_pluto() ? PlutoHost() : PlainHTML()

to_js(::Host, x) = x
to_js(::PlutoHost, x) = AbstractPlutoDingetjes.Display.published_to_js(x)

plotly_import(::Host, version) = _ImportedRemoteJS(get_plotly_esm_url(version), "default")
plotly_import(::PlutoHost, version) = _ImportedHybridJS(version)

adapter_script(::PlutoHost) = pluto_adapter_script
adapter_script(::PlainHTML) = plain_adapter_script
