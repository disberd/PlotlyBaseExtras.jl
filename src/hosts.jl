abstract type Host end
struct PlainHTML <: Host end
struct PlutoHost <: Host end
struct VSCodeHost <: Host end

current_host() = is_inside_pluto() ? PlutoHost() : PlainHTML()

to_js(::Host, x) = x
to_js(::PlutoHost, x) = AbstractPlutoDingetjes.Display.published_to_js(x)

# Where plotly.js comes from. Each Host declares the sources it supports and
# which one `:auto` picks.
supported_sources(::Host) = (:cdn, :inline)
supported_sources(::PlutoHost) = (:cdn, :inline, :hosted)

auto_source(::Host, version) = :cdn
auto_source(::PlutoHost, version) = :hosted

function plotly_import(host::Host, version)
	source = get_plotly_source()
	source = source === :auto ? auto_source(host, version) : source
	if !(source in supported_sources(host))
		@warn "The source :$source is not supported by $(typeof(host).name.name), using :$(auto_source(host, version)) instead" maxlog=1 _id=(:unsupported_plotly_source, typeof(host), source)
		source = auto_source(host, version)
	end
	return plotly_import(host, Val(source), version)
end

plotly_import(::Host, ::Val{:cdn}, version) = _ImportedRemoteJS(get_plotly_esm_url(version), "default")
plotly_import(host::Host, ::Val{:inline}, version) = _ImportedLocalJS(to_js(host, get_local_plotly_contents(version)), "default")
plotly_import(::PlutoHost, ::Val{:hosted}, version) = _ImportedHybridJS(version)

# The adapter JS and the code around the script body. The default mounts the
# container beside the script tag in an async function, so `await import()` works.
adapter_script(::Host) = plain_adapter_script
adapter_script(::VSCodeHost) = vscode_adapter_script
adapter_script(::PlutoHost) = pluto_adapter_script

script_wrap(::Host) = (JS("(async (currentScript) => {"), JS("})(document.currentScript).catch(console.error);"))
script_wrap(::PlutoHost) = (JS(""), JS("return CONTAINER"))
