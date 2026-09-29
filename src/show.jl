function _host_script_contents(host::Host, pp::PlotlyPlot)
	ScriptContents([
		el.content == ADAPTER_SLOT.content ? adapter_script(host) : el
		for el in pp.script_contents.vec
	])
end

# A plot renders directly into an `IOBuffer` (`repr`, `sprint`, VS Code) or an
# `IOContext{IOBuffer}` (Pluto), the IO types that the hosts pass. Another IO type
# gets the render of an `IOContext{IOBuffer}` that has the properties of `io`, as
# bytes. So with `@nospecialize`, a new IO type compiles only a few small methods.
function render(@nospecialize(io::IO), host::Host, pp::PlotlyPlot; script_id = plotly_script_id(io))
	buf = IOContext(IOBuffer(), io)
	_render(buf, host, pp, script_id)
	write(io, take!(buf.io))
	return nothing
end
render(io::Union{IOBuffer,IOContext{IOBuffer}}, host::Host, pp::PlotlyPlot; script_id = plotly_script_id(io)) =
	_render(io, host, pp, script_id)

function _render(io::Union{IOBuffer,IOContext{IOBuffer}}, host::Host, pp::PlotlyPlot, script_id)
	processed = _process_with_names(pp)
	script_contents = _host_script_contents(host, pp)
	loader = mathjax_loader(host, processed)
	opening, closing = script_wrap(host)
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
			let plot_obj = $(to_js(host, processed))
			plot_obj.layout = removeTypedArray(plot_obj.layout)
			// Get the plotly listeners
			const plotly_listeners = $(pp.plotly_listeners)
			// Get the JS listeners
			const js_listeners = $(pp.js_listeners)
			// Deal with eventual custom classes
			let custom_classlist = $(pp.classList)


			// Load the plotly library
			const Plotly = $(plotly_import(host, get_plotly_version()))$(loader)

			// With a global font cache, the math SVG that plotly.js inserts
			// refers to glyph definitions that are not in the page, so the math
			// is invisible. A page MathJax (Pluto) uses the global cache.
			if ($(force_mathjax_local() || loader.kind === :hosted) && window?.MathJax?.config?.svg?.fontCache === 'global') {
				window.MathJax.config.svg.fontCache = 'local'
			}

			$(script_contents)

			$(closing)
		</script>
	""")
end

function Base.show(@nospecialize(io::IO), ::MIME"application/vnd.julia-vscode.plotpane+html", p::PlotlyPlot)
	render(io, VSCodeHost(), p)
end

function Base.show(@nospecialize(io::IO), ::MIME"text/html", p::PlotlyPlot)
	render(io, current_host(), p)
end