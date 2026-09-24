abstract type Host end
struct PlainHTML <: Host end
struct PlutoHost <: Host end

current_host() = is_inside_pluto() ? PlutoHost() : PlainHTML()

to_js(::Host, x) = x
to_js(::PlutoHost, x) = AbstractPlutoDingetjes.Display.published_to_js(x)

plotly_import(::Host, version) = _ImportedRemoteJS(get_plotly_esm_url(version), "default")
plotly_import(::PlutoHost, version) = _ImportedHybridJS(version)

# The adapter JS and the code around the script body. The default mounts the
# container beside the script tag in an async function, so `await import()` works.
adapter_script(::Host) = plain_adapter_script
adapter_script(::PlutoHost) = pluto_adapter_script

script_wrap(::Host) = (JS("(async (currentScript) => {"), JS("})(document.currentScript).catch(console.error);"))
script_wrap(::PlutoHost) = (JS(""), JS("return CONTAINER"))
