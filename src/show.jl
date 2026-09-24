function _host_script_contents(host::Host, pp::PlotlyPlot)
	ScriptContents([
		el.content == ADAPTER_SLOT.content ? adapter_script(host) : el
		for el in pp.script_contents.vec
	])
end

function render(io::IO, host::Host, pp::PlotlyPlot; script_id = plotly_script_id(io))
	script_contents = _host_script_contents(host, pp)
	opening = host isa PlutoHost ? JS("") : JS("(async (currentScript) => {")
	closing = host isa PlutoHost ? JS("return CONTAINER") : JS("})(document.currentScript).catch(console.error);")
	show(io, MIME"text/html"(), @htl """
		<script id=$(script_id)>$(opening)
			// We start by putting all the variable interpolation here at the beginning
			// We have to convert all typedarrays in the layout to normal arrays. See Issue #25
			function removeTypedArray(o) {
				if (ArrayBuffer.isView(o)) return Array.from(o)
				if (o !== null && typeof o === 'object' && !Array.isArray(o)) {
					const r = {}
					for (const [k, v] of Object.entries(o)) r[k] = removeTypedArray(v)
					return r
				}
				return o
			}

			// Publish the plot object to JS
			let plot_obj = $(to_js(host, _process_with_names(pp)))
			plot_obj.layout = removeTypedArray(plot_obj.layout)
			// Get the plotly listeners
			const plotly_listeners = $(pp.plotly_listeners)
			// Get the JS listeners
			const js_listeners = $(pp.js_listeners)
			// Deal with eventual custom classes
			let custom_classlist = $(pp.classList)


			// Load the plotly library
			const Plotly = $(plotly_import(host, get_plotly_version()))

			// Check if we have to force local mathjax font cache
			if ($(force_mathjax_local()) && window?.MathJax?.config?.svg?.fontCache === 'global') {
				window.MathJax.config.svg.fontCache = 'local'
			}

			$(script_contents)

			$(closing)
		</script>
	""")
end

function Base.show(io::IO, ::MIME"text/html", p::PlotlyPlot)
	render(io, current_host(), p)
end