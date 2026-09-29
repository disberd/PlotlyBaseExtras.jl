module PlotlyBaseExtras

using PlotlyBase

import JSON
using AbstractPlutoDingetjes
using Dates
using Scratch
using TOML
using Colors
using ColorSchemes
using LaTeXStrings
using Markdown
using Downloads: download
using Artifacts
import Preferences
using ScopedValues
using PrecompileTools
# This is similar to `@reexport` but does not exports undefined names and can
# also avoid exporting the module name
function re_export(m::Module; skip_modname = false)
    mod_name = nameof(m)
    nms = names(m)
    exprts = filter(nms) do n
        isdefined(m, n) && (!skip_modname || n != mod_name)
    end
    eval(:(using .$mod_name))
    eval(:(export $(exprts...)))
end

re_export(PlotlyBase; skip_modname = false)
export PlotlyPlot, get_plotly_version, change_plotly_version,
get_plotly_source, change_plotly_source,
get_mathjax, change_mathjax, get_mathjax_version, change_mathjax_version,
get_mathjax_source, change_mathjax_source,
force_mathjax_local, add_plotly_listener!,
add_class!, remove_class!, add_js_listener!, default_plotly_template,
get_image_options, change_image_options!, plotly_paste_receiver
export plot, push_script!, prepend_cell_selector
export make_subplots
export enable_plotly_offline
# From utilities.jl
export sample_colorscheme, discrete_colorscale
# Package UUID. The notebooks load this package through PlutoDevMacros, where the module has no package id, so preferences are read by UUID.
const PLOTLY_UUID = Base.UUID("ba01aadf-c838-43fc-827a-f1961e451c7b")
public Host, PlainHTML, PlutoHost, VSCodeHost, current_host, render, to_js, plotly_import,
supported_sources, auto_source, plotly_source, plotly_version,
mathjax, mathjax_version, mathjax_source


include("local_plotly_library.jl")

include("basics.jl")
include("main_struct.jl")
include("hosts.jl")
include("paste_receiver.jl")
include("mathjax.jl")
include("preprocess.jl")
include("js_helpers.jl")
include("show.jl")
# Forward methods of PlotlyBase to support PlotlyPlot objects
include("plotlybase_forward.jl")
include("utilities.jl")

function __init__()
    # A template that is already in the cache stays there: the layouts made
    # before this package loaded refer to it, and `_process_with_names` compares
    # templates with `===`.
    cache = PlotlyBase.templates.templates
    for (name, template) in PLOTLYBASE_TEMPLATES
        ismissing(get(cache, name, missing)) && (cache[name] = template)
    end
end

# function __init__()
	# if !is_inside_pluto()
	# 	@warn "You loaded this package outside of Pluto, this is not the intended behavior and you should use either PlotlyBase or PlotlyJS directly.\nNOTE: If you receive this warning during pre-compilation or sysimage creation, you can ignore this warning."
	# end
# end

@setup_workload begin
    # Pluto renders with an `IOContext{IOBuffer}` that has this key. The stub lets
    # the workload run the code of the Pluto host outside Pluto.
    pluto_io = IOContext(IOBuffer(), :pluto_published_to_js => (io, x) -> print(io, "null"))
    @compile_workload begin
        x = 1:10
        y = rand(10)
        z = rand(10, 10)
        dates = Date(2020):Day(1):Date(2020, 1, 10)
        # Common trace types and common value types of the keyword arguments
        traces = [
            scatter(; x, y, mode = "markers", name = "a", showlegend = true, opacity = 0.5,
                marker = attr(size = 5, color = colorant"red", line_width = 1)),
            scatter(; x = collect(x), y = rand(1:5, 10), text = string.(x), line_color = "blue",
                hovertext = nothing, marker_symbol = :circle),
            scatter(; x = dates, y = 1:2:20, line = Dict(:dash => "dot")),
            scatter(; x = collect(dates), y = [1.0, missing, 3.0]),
            scatter(; x = collect(DateTime(2020):Hour(1):DateTime(2020, 1, 1, 9)), y = rand(Float32, 10)),
            bar(; x = ["a", "b"], y = [1, 2]),
            heatmap(; z, colorscale = "Viridis"),
            contour(; z, colorscale = discrete_colorscale(:viridis, 3)),
            surface(; z),
            scatter3d(; x = y, y, z = y),
            histogram(; x = y),
            box(; y),
            pie(; values = [1, 2], labels = ["a", "b"]),
            scattergeo(; lat = y, lon = y),
        ]
        layout = Layout(; title = "title", xaxis_title = "x", yaxis = attr(title = "y", range = [0, 1]),
            xaxis = attr(range = [Date(2020), Date(2020, 1, 10)]), width = 500, height = 400.0,
            legend = attr(x = 0.5, font_size = 12))
        p = plot(traces, layout)
        relayout!(p; showlegend = false, xaxis_title = "new")
        restyle!(p, 1; marker_color = "green")
        update!(p, Dict(:opacity => 1); layout = Layout(xaxis_type = "log"))
        add_plotly_listener!(p, "plotly_click", "e => console.log(e)")
        add_js_listener!(p, "mousedown", "e => console.log(e)")
        add_class!(p, "custom")
        s = make_subplots(rows = 2, cols = 2)
        add_trace!(s, scatter(; y); row = 1, col = 2)
        add_trace!(s, bar(; x = ["a", "b"], y = [1, 2]); row = 2, col = 1)
        q = plot(scatter(; x, y))
        # The walk that looks for `$` stops at the first match: only one plot has math.
        math = plot(scatter(; y), Layout(title = L"$\alpha$"))
        # `Any` makes each call below a runtime dispatch, as in the hosts, so that
        # the package image keeps these entry points. Each call uses the IO type
        # that the host passes to `show`.
        plots = Any[p, s, math, plot(y), plot(z), plot(heatmap(; z), Layout(title = "t")), [q q], [q; q], [q q; q q]]
        for pl in plots
            repr(MIME"text/html"(), pl)  # IOBuffer: repr, sprint, Documenter
            show(IOContext(IOBuffer()), MIME"text/html"(), pl)  # Pluto
            repr(MIME"application/vnd.julia-vscode.plotpane+html"(), pl)  # VSCode
            render(pluto_io, PlutoHost(), pl)  # Pluto
        end
        sprint(show, MIME"text/html"(), q)
    end
    # Users call `plot` at the top level, through a runtime dispatch. The workload
    # inlines `plot`, so these entry points need explicit directives.
    precompile(plot, (Any,))
    precompile(plot, (Any, Any))
end

end