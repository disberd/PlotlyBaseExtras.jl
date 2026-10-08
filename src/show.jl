function _host_script_contents(host::Host, pp::PlotlyPlot)
	ScriptContents([
		el == ADAPTER_SLOT ? adapter_script(host, pp) : el
		for el in pp.script_contents.vec
	])
end

# A JS object with an array of listener functions for each event: `{"event": [f1, f2]}`.
function write_listeners(io::IO, listeners::AbstractDict)
	write(io, '{')
	for (i, (event, codes)) in enumerate(listeners)
		i > 1 && write(io, ", ")
		write_js(io, event)
		write(io, ": [")
		join(io, codes, ", ")
		write(io, ']')
	end
	write(io, '}')
	return nothing
end

# The characters that can end a single-quoted attribute value or start a tag.
_escape_attribute(s) = replace(string(s), '&' => "&amp;", '\'' => "&#39;", '<' => "&lt;")

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
	js = MIME"text/javascript"()
	write(io, "<script id='", _escape_attribute(script_id), "'>", opening, """

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
		let plot_obj = """)
	write_js(io, to_js(host, processed))
	write(io, """

		plot_obj.layout = removeTypedArray(plot_obj.layout)
		// Get the plotly listeners
		const plotly_listeners = """)
	write_listeners(io, pp.plotly_listeners)
	write(io, """

		// Get the JS listeners
		const js_listeners = """)
	write_listeners(io, pp.js_listeners)
	write(io, """

		// Deal with eventual custom classes
		let custom_classlist = """)
	write_js(io, pp.classList)
	write(io, """


		// Load the plotly library
		const Plotly = """)
	show(io, js, plotly_import(host, get_plotly_version()))
	show(io, js, loader)
	write(io, """


		// With a global font cache, the math SVG that plotly.js inserts
		// refers to glyph definitions that are not in the page, so the math
		// is invisible. A page MathJax (Pluto) uses the global cache.
		if (""", string(force_mathjax_local() || loader.kind === :hosted), """ && window?.MathJax?.config?.svg?.fontCache === 'global') {
			window.MathJax.config.svg.fontCache = 'local'
		}

		""")
	show(io, js, script_contents)
	write(io, "\n", closing, "\n</script>\n")
	return nothing
end

function Base.show(@nospecialize(io::IO), ::MIME"application/vnd.julia-vscode.plotpane+html", p::PlotlyPlot)
	render(io, VSCodeHost(), p)
end

function Base.show(@nospecialize(io::IO), ::MIME"text/html", p::PlotlyPlot)
	render(io, current_host(), p)
end

"""
	savehtml(path_or_io, plots...; title = "", head = "")

Write one standalone HTML page with `plots` to `path_or_io` and return `path_or_io`. Each plot is
a `PlotlyPlot` or a `PlotlyBase.Plot`. The plots are independent and show one below the other, in
the order of the arguments.

The page writes `title` in its `<title>` element. It writes `head` as it is in its `<head>`
element, for example a `<style>` element.

The `plotly_source` and `mathjax_source` settings select where plotly.js and MathJax load from,
with the same rules as a plain HTML plot. With the `:inline` source, the page holds each library
one time for all plots and shows the plots without a network connection.

# Examples
```julia
savehtml("plots.html", p1, p2; title = "Two plots")

# A page that shows without a network connection
with(PlotlyBaseExtras.plotly_source => :inline, PlotlyBaseExtras.mathjax_source => :inline) do
	savehtml("plots.html", p1, p2)
end
```
"""
function savehtml(path::AbstractString, plots::Union{PlotlyPlot,PlotlyBase.Plot}...; kwargs...)
	isempty(plots) && throw(ArgumentError("savehtml needs at least one plot"))
	open(io -> savehtml(io, plots...; kwargs...), path, "w")
	return path
end

function savehtml(@nospecialize(io::IO), plots::Union{PlotlyPlot,PlotlyBase.Plot}...; title = "", head = "")
	isempty(plots) && throw(ArgumentError("savehtml needs at least one plot"))
	pps = map(p -> p isa PlotlyPlot ? p : PlotlyPlot(p), plots)
	# The sources resolve as for a plain HTML plot. An `:inline` library goes in the page
	# head one time, and the plots load it from there as `:hosted`.
	version = get_plotly_version()
	plotly_src = resolved_plotly_source(PlainHTML(), version)
	mathjax_src = resolved_mathjax_source(PlainHTML())
	write(io, "<!doctype html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n<title>",
		_escape_attribute(title), "</title>\n", head, "\n")
	js = MIME"text/javascript"()
	if plotly_src === :inline
		# The head stores a promise: a classic script cannot use a top-level `await`.
		write(io, "<script>\nwindow.plutoplotly_imports = window.plutoplotly_imports ?? {};\nwindow.plutoplotly_imports[")
		write_js(io, string(VersionNumber(version)))
		write(io, "] = (async () => ")
		show(io, js, plotly_import(PlainHTML(), Val(:inline), version))
		write(io, ")();\n</script>\n")
	end
	# ponytail: this processes each plot one more time, only for an `:inline` MathJax page.
	if mathjax_src === :inline && any(pp -> _mathjax_wanted(_process_with_names(pp)), pps)
		# The loader sets the page MathJax promise before its first `await`, so the plots find it.
		write(io, "<script>\n(async () => {\n")
		show(io, js, mathjax_script(PlainHTML(), Val(:inline), get_mathjax_version()))
		write(io, "})();\n</script>\n")
	end
	write(io, "</head>\n<body>\n")
	hosted(src) = src === :inline ? :hosted : src
	with(plotly_source => hosted(plotly_src), mathjax_source => hosted(mathjax_src)) do
		for (i, pp) in enumerate(pps)
			render(io, _PlainHTMLPage(), pp; script_id = "plot_$i")
		end
	end
	write(io, "</body>\n</html>\n")
	return io
end