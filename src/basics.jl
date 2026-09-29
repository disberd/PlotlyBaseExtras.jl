const ARTIFACT_VERSION = VersionNumber(read(joinpath(artifact"plotly-esm-min", "VERSION"), String))
const plotly_version = ScopedValue{Union{Nothing, String, VersionNumber}}(nothing)
const plotly_source = ScopedValue{Union{Nothing, Symbol}}(nothing)
const RUNTIME_PLOTLY_VERSION = Ref{Union{Nothing, String, VersionNumber}}(nothing)
const RUNTIME_PLOTLY_SOURCE = Ref{Union{Nothing, Symbol}}(nothing)
# The first template load of the precompile process must run inside a workload:
# the package image keeps the code of a runtime dispatch only when that code
# compiles inside a workload.
@compile_workload PlotlyBase.templates[PlotlyBase.templates.default]
# All PlotlyBase templates, read from their JSON files at precompile time and
# kept in the package image. `__init__` puts them in the template cache of
# PlotlyBase, so that the first `Layout()` does not parse a JSON file.
const PLOTLYBASE_TEMPLATES = Dict(name => PlotlyBase.templates[name] for name in PlotlyBase.templates.available)
const DEFAULT_TEMPLATE = Ref(PlotlyBase.templates[PlotlyBase.templates.default])

"""
	ScriptContents
Wrapper around a vector of `String` elements, each a piece of JavaScript code. `render` writes the elements into the plot script, one per line.

It is used inside the PlotlyPlot to allow modularity and ease customization of the script contents that is used to generate the plotlyjs plot in Javascript.
"""
struct ScriptContents
	vec::Vector{String}
end

function Base.show(io::IO, ::MIME"text/javascript", value::ScriptContents)
	for el ∈ value.vec
		print(io, el, '\n')
	end
end

# JS code goes into the script tag without escapes, so code that can end the tag or
# start an HTML comment in it is not permitted.
function _check_js(code::AbstractString)
	occursin(r"</script|<!--"i, code) && throw(ArgumentError("JS code must not contain `</script` or `<!--`"))
	return String(code)
end


current_cell_id()::Base.UUID = if is_inside_pluto()
	Main.PlutoRunner.currently_running_cell_id[]
else
	Base.UUID(zero(UInt128))
end

## Plotly Settings ##
# Each setting resolves in order: ScopedValue, runtime setter, Preferences.toml, default.
const SUPPORTED_SOURCES = (:auto, :cdn, :inline, :hosted)

function _check_source(s::Symbol)
	s in SUPPORTED_SOURCES || throw(ArgumentError("Invalid plotly source :$s, valid sources are $(join(SUPPORTED_SOURCES, ", "))"))
	return s
end

function change_plotly_version(v)
	if v === nothing
		RUNTIME_PLOTLY_VERSION[] = nothing
		return nothing
	end
	ver = VersionNumber(v)
	maybe_add_plotly_local(ver)
	RUNTIME_PLOTLY_VERSION[] = ver
	return ver
end

function change_plotly_source(s)
	if s === nothing
		RUNTIME_PLOTLY_SOURCE[] = nothing
		return nothing
	end
	src = _check_source(s isa Symbol ? s : Symbol(s))
	RUNTIME_PLOTLY_SOURCE[] = src
	return src
end

# The getters read the Preferences.toml file at each call, so a preference
# change applies without reloading the package.
function get_plotly_version()::VersionNumber
	v = @something plotly_version[] RUNTIME_PLOTLY_VERSION[] Preferences.load_preference(PLOTLY_UUID, "plotly_version") ARTIFACT_VERSION
	return VersionNumber(v)
end

function get_plotly_source()::Symbol
	s = @something plotly_source[] RUNTIME_PLOTLY_SOURCE[] Preferences.load_preference(PLOTLY_UUID, "plotly_source") :auto
	s isa Symbol || (s = Symbol(s))
	return _check_source(s)
end

## Prepend Cell Selector ##
"""
	prepend_cell_selector(selector="")
	prepend_cell_selector(selectors)

Prepends a CSS selector (represented by the argument `selector`) with a selector
of the current pluto-cell (of the form `pluto-cell[id='cell_id']`, where
`cell_id` is the currently running cell).

It can be used to ease creating style sheets (for example with the `@htl` macro,
which you load yourself) with selector that only apply to the cell where they are
executed.

When called with a vector of selectors as input, prepends each selector and
joins them together using `,` as separator.

`prepend_cell_selector("div") = pluto-cell[id='\$cell_id'] div`

`prepend_cell_selector(["div", "span"]) = pluto-cell[id='\$cell_id'] div, pluto-cell[id='\$cell_id'] span`

As example, one can create a plot and force its width to 400px in CSS by using the following snippet:
```julia
@htl \"\"\"
\$(plot(rand(10)))
<style>
	\$(prepend_cell_selector("div.js-plotly-plot")) {
		width: 400px !important;
	}
</style>
\"\"\"
```
"""
prepend_cell_selector(str::AbstractString="")::String = "pluto-cell[id='$(current_cell_id())'] $str" |> strip
prepend_cell_selector(selectors) = join(map(prepend_cell_selector, selectors), ",\n")

const IO_DICT = Ref{Tuple{<:IO, Dict{UInt, Int}}}((IOBuffer(), Dict{UInt, Int}()))
function get_IO_DICT(io::IO)
	old_io = first(IO_DICT[])
	dict = if old_io === io
		last(IO_DICT[])
	else
		d = Dict{UInt, Int}()
		IO_DICT[] = (io, d)
		d
	end
	return dict
end

## Unique Counter ##
function unique_io_counter(io::IO, identifier = "script_id")
	!get(io, :is_pluto, false) && return -1 # We simply return -1 if not inside pluto
	# We extract (or create if not existing) a dictionary that will keep track of instances of the same script name
	dict = get_IO_DICT(io)
	# We use the objectid as the key
	key = objectid(identifier)
	counter = get(dict, key, 0) + 1
	# Update the counter on the dict that is shared within this IOContext
	dict[key] = counter
end

# Using the unique_io_counter inside the show3 method allows to have unique counters for plots within a same cell.
# This does not ensure that the same plot object is always given the same unique script id if the plots are added to the cells with `if...end` blocks.
function plotly_script_id(io::IO)
	counter = unique_io_counter(io, "plotly-plot")
	return "plot_$counter"
end

function find_matching_template(t::Template)
	for name in templates.available
		t == templates[name] && return name
	end
	return missing
end

"""
	default_plotly_template(;find_matching = false)::Template
Returns the current default plotly template (following the synthax
to set Templates from PlotlyBase).

If `find_matching` is set to true, the function will also send a message (using
`@info`) to specify whether the default template is one of the templates
available by default in PlotlyBase (and which one it is) or not.
"""
function default_plotly_template(; find_matching = false)
	template = DEFAULT_TEMPLATE[] 
	if find_matching
		matching = find_matching_template(template)
		if matching isa Missing
			@info "The default template is not one of the predefined ones"
		else
			@info "The default plotly template is $matching"
		end
	end
	template
end

"""
	default_plotly_template(template::Template)::Template
	default_plotly_template(name::Union{Symbol, String})::Template
Set `template` as the current default plotly template (**globally**) to be used by all plots
from PlotlyBaseExtras (unless specifically overridden with Layout).

If called with a `Symbol` or `String`, uses `name` to extract the corresponding
template the default ones available in PlotlyBase and sets it as default.
"""
default_plotly_template(t::Template) = DEFAULT_TEMPLATE[] = t
default_plotly_template(s::String) = default_plotly_template(Symbol(s))
function default_plotly_template(s::Symbol)
	s in templates.available || s === :none || error("The provided template $s is not available")
	template = s === :none ? Template() : templates[s]
	DEFAULT_TEMPLATE[] = template
end