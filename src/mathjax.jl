# This hack is necessary to force loading mathjax

const FORCE_MATHJAX_LOCAL = Ref(false)

"""
	force_mathjax_local()::Bool
	force_mathjax_local(flag::Bool)::Bool

Returns `true` if the `PlotlyPlot` `show` method forces svgs produced by MathJax
to be locally cached and `false` otherwise.

The flag can be set at package level by providing the intended boolean value as
argument to the function

With the `global` font cache of MathJax, the math in a plot refers to glyphs
that are not in the page, so it is invisible. When the page provides MathJax
(`mathjax_source` `:hosted`, the default in Pluto), the plot always changes the
cache to `local`. Set this flag to also change it for a MathJax that the page
loaded before the plot, with any other source.

`force_pluto_mathjax_local` is the PlutoPlotly 0.6 name of this function.
"""
force_mathjax_local() = FORCE_MATHJAX_LOCAL[]
force_mathjax_local(flag::Bool) = FORCE_MATHJAX_LOCAL[] = flag

const force_pluto_mathjax_local = force_mathjax_local

## MathJax Settings ##
# Each setting resolves in order: ScopedValue, runtime setter, Preferences.toml, default.
const MATHJAX_MODES = (:auto, :on, :off)
const SUPPORTED_MATHJAX_SOURCES = (:auto, :cdn, :inline, :hosted)
const DEFAULT_MATHJAX_VERSION = v"3.2.2"

const mathjax = ScopedValue{Union{Nothing,Symbol}}(nothing)
const mathjax_version = ScopedValue{Union{Nothing,String,VersionNumber}}(nothing)
const mathjax_source = ScopedValue{Union{Nothing,Symbol}}(nothing)
const RUNTIME_MATHJAX = Ref{Union{Nothing,Symbol}}(nothing)
const RUNTIME_MATHJAX_VERSION = Ref{Union{Nothing,String,VersionNumber}}(nothing)
const RUNTIME_MATHJAX_SOURCE = Ref{Union{Nothing,Symbol}}(nothing)

function _check_mathjax_mode(m::Symbol)
	m in MATHJAX_MODES || throw(ArgumentError("Invalid mathjax mode :$m, valid modes are $(join(MATHJAX_MODES, ", "))"))
	return m
end

function _check_mathjax_source(s::Symbol)
	s in SUPPORTED_MATHJAX_SOURCES || throw(ArgumentError("Invalid mathjax source :$s, valid sources are $(join(SUPPORTED_MATHJAX_SOURCES, ", "))"))
	return s
end

"""
	change_mathjax(mode)
	change_mathjax_version(version)
	change_mathjax_source(source)

Set the MathJax settings at runtime. Pass `nothing` to reset a setting to its
default chain (ScopedValue, then Preferences.toml, then package default).

The settings control whether the core loads MathJax on the page (`mode`, one of
`:auto`, `:on`, `:off`), which MathJax version it loads (`version`, default
`3.2.2`), and where the bundle comes from (`source`, one of `:auto`, `:cdn`,
`:inline`, `:hosted`).
"""
function change_mathjax(m)
	if m === nothing
		RUNTIME_MATHJAX[] = nothing
		return nothing
	end
	mode = _check_mathjax_mode(m isa Symbol ? m : Symbol(m))
	RUNTIME_MATHJAX[] = mode
	return mode
end

function change_mathjax_version(v)
	if v === nothing
		RUNTIME_MATHJAX_VERSION[] = nothing
		return nothing
	end
	ver = VersionNumber(v)
	RUNTIME_MATHJAX_VERSION[] = ver
	return ver
end

function change_mathjax_source(s)
	if s === nothing
		RUNTIME_MATHJAX_SOURCE[] = nothing
		return nothing
	end
	src = _check_mathjax_source(s isa Symbol ? s : Symbol(s))
	RUNTIME_MATHJAX_SOURCE[] = src
	return src
end

# The getters read the Preferences.toml file at each call, so a preference
# change applies without reloading the package.
function get_mathjax()::Symbol
	m = @something mathjax[] RUNTIME_MATHJAX[] Preferences.load_preference(PLOTLY_UUID, "mathjax") :auto
	return _check_mathjax_mode(m isa Symbol ? m : Symbol(m))
end

function get_mathjax_version()::VersionNumber
	v = @something mathjax_version[] RUNTIME_MATHJAX_VERSION[] Preferences.load_preference(PLOTLY_UUID, "mathjax_version") DEFAULT_MATHJAX_VERSION
	return VersionNumber(v)
end

function get_mathjax_source()::Symbol
	s = @something mathjax_source[] RUNTIME_MATHJAX_SOURCE[] Preferences.load_preference(PLOTLY_UUID, "mathjax_source") :auto
	return _check_mathjax_source(s isa Symbol ? s : Symbol(s))
end

# MathJax auto source. Pluto pages ship MathJax 3.2.2, other hosts must load it.
mathjax_auto_source(::PlutoHost) = :hosted
mathjax_auto_source(::Host) = :cdn

# Resolve the MathJax source with the same table and fallback as plotly.js.
# `:hosted` means the page provides MathJax, so the core waits for it.
function mathjax_script(host::Host, version)
	source = get_mathjax_source()
	source = source === :auto ? mathjax_auto_source(host) : source
	if !(source in supported_sources(host))
		@warn "The source :$source is not supported by $(typeof(host).name.name), using :$(mathjax_auto_source(host)) instead" maxlog=1 _id=(:unsupported_mathjax_source, typeof(host), source)
		source = mathjax_auto_source(host)
	end
	return mathjax_script(host, Val(source), version)
end

# Only the v3 bundle path is known. The v4 path is one line when needed.
mathjax_cdn_url(v) = "https://cdn.jsdelivr.net/npm/mathjax@$(VersionNumber(v))/es5/tex-svg.js"

# `:hosted` means the page provides MathJax, so the core waits for it and
# loads no script of its own.
mathjax_script(::Host, ::Val{:hosted}, version) = _MathJaxLoader(:hosted, nothing)

mathjax_script(::Host, ::Val{:cdn}, version) = _MathJaxLoader(:url, mathjax_cdn_url(version))

mathjax_script(host::Host, ::Val{:inline}, version) =
	_MathJaxLoader(:code, to_js(host, get_local_mathjax_contents(version)))

# The MathJax loader the plot script awaits before the core draws. `nothing`
# prints empty, so a plot without MathJax keeps the previous output unchanged.
function mathjax_loader(host::Host, processed)
	_mathjax_wanted(processed) || return _MathJaxLoader(:none, nothing)
	return mathjax_script(host, get_mathjax_version())
end

# The MathJax bundle, downloaded once into a scratch space like the plotly bundles.
const MATHJAX_DEP_CONTENTS = Dict{String,String}()

get_mathjax_download_url(v) = mathjax_cdn_url(v)

get_local_mathjax_path(v) = joinpath(
	get_scratch!(Base.UUID("ba01aadf-c838-43fc-827a-f1961e451c7b"), "mathjax-library"),
	"mathjax-tex-svg-$(VersionNumber(v)).js",
)

function maybe_add_mathjax_local(v)
	ver = VersionNumber(v)
	path = get_local_mathjax_path(ver)
	if !isfile(path)
		@info "Downloading a local version of mathjax@$v"
		download(get_mathjax_download_url(ver), path)
	end
	nothing
end

function get_local_mathjax_contents(v)
	maybe_add_mathjax_local(v)
	path = get_local_mathjax_path(v)
	get!(MATHJAX_DEP_CONTENTS, path) do
		read(path, String)
	end
end

# Printed inside the plot script tag: the loader awaits MathJax before the core
# draws, and all plots on the page share one load promise. `window.__plotlyBaseExtrasMathJax`
# is assigned the promise itself, so a second plot awaits the first load instead
# of starting it again. Errors log and let the plot render without math.
struct _MathJaxLoader
	kind::Symbol
	published
	function _MathJaxLoader(kind::Symbol, published)
		@nospecialize
		new(kind, published)
	end
end

function Base.show(io::IO, ::MIME"text/javascript", l::_MathJaxLoader)
	l.kind === :none && return nothing
	write(io,
		"""

		// Load MathJax, so math labels render on the first draw. The page
		// keeps one shared load promise. A MathJax config stub comes first:
		// the page script is still loading, so wait for it and never
		// overwrite it with a loader of our own.
		await (window.__plotlyBaseExtrasMathJax ??= (async () => {
		try {
		// Wait until the page MathJax reports a version, at most 5 s.
		for (let i = 0; window.MathJax && !window.MathJax.version && i < 100; i++) {
		await new Promise((resolve) => setTimeout(resolve, 50));
		}
		await window.MathJax?.startup?.promise;
		""")
	if l.kind === :hosted
		write(io, """
		} catch (e) {
		console.error("MathJax wait failed:", e);
		}
		})());
		""")
		return nothing
	end
	write(io, "if (window.MathJax?.version) return;\n")
	if l.kind === :url
		write(io, """
		window.MathJax = { svg: { fontCache: "local" }, startup: { typeset: false } };
		await new Promise((resolve, reject) => {
		const s = document.createElement("script");
		s.src = """)
		_show_published(io, MIME"text/javascript"(), l.published)
		write(io, raw"""
		;
		s.onload = resolve;
		s.onerror = () => reject(new Error("Could not load MathJax from " + s.src));
		document.head.appendChild(s);
		});
		""")
	else
		# The bundle text is a JS string literal, escaped so it cannot close the
		# surrounding script tag. An inline classic script runs on insertion.
		write(io, """
		window.MathJax = { svg: { fontCache: "local" }, startup: { typeset: false } };
		await new Promise((resolve) => {
		const s = document.createElement("script");
		s.textContent = """)
		_show_published(io, MIME"text/javascript"(), l.published)
		write(io, raw"""
		;
		document.head.appendChild(s);
		resolve();
		});
		""")
	end
	write(io,
		"""
		await window.MathJax.startup.promise;
		} catch (e) {
		// Leave no half-configured MathJax behind: the stub above without a
		// version would make plotly wait on math typesetting forever.
		if (!window.MathJax?.version) delete window.MathJax;
		console.error("MathJax load failed:", e);
		}
		})());
		""")
	return nothing
end

# The `:auto` mode loads MathJax only when the plot JSON contains `$`. The walk
# covers the same strings the render serializes, without building the JSON.
function _mathjax_wanted(processed)
	mode = get_mathjax()
	mode === :off && return false
	mode === :on && return true
	return _has_dollar(processed)
end

_has_dollar(s::AbstractString) = occursin('$', s)
_has_dollar(d::AbstractDict) = any(_has_dollar, values(d))
_has_dollar(x::Union{Tuple,AbstractArray}) = any(_has_dollar, x)
_has_dollar(::AbstractArray{<:Real}) = false
_has_dollar(x) = false
