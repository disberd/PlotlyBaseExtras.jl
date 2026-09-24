module PlotlyKaleidoExt

using PlotlyBaseExtras: PlotlyPlot, get_plotly_version, get_mathjax, get_mathjax_version, mathjax_cdn_url, _process_with_names
using PlotlyKaleido: savefig, PlotlyKaleido, restart, P, is_running

# The value of a `--name=value` flag in the command that started Kaleido, or `nothing`.
function kaleido_flag(name)
    prefix = "--$name="
    idx = findfirst(startswith(prefix), P.proc.cmd.exec)
    isnothing(idx) ? nothing : chopprefix(P.proc.cmd.exec[idx], prefix)
end

function get_version_in_kaleido()
    url = kaleido_flag("plotlyjs")
    m = isnothing(url) ? nothing : match(r"https://cdn.plot.ly/plotly-(\d+\.\d+\.\d+).min.js", url)
    return isnothing(m) ? nothing : VersionNumber(only(m.captures))
end

# plotly.js 4 does not support MathJax 2, which Kaleido loads by default, so Kaleido gets the
# same MathJax 3 bundle as the other hosts.
wanted_mathjax() = get_mathjax() === :off ? nothing : mathjax_cdn_url(get_mathjax_version())

function ensure_correct_version()
    pkgversion(PlotlyKaleido) >= v"2.2.1" || return # If we can't change version, we just assume it's correct
    current_version = get_plotly_version()
    mathjax = wanted_mathjax()
    # The command that started Kaleido has the plotly.js version as a CDN URL, see
    # https://github.com/JuliaPlots/PlotlyKaleido.jl/pull/9, and the MathJax URL as a flag.
    if !is_running() || get_version_in_kaleido() != current_version || kaleido_flag("mathjax") != mathjax
        @info "(Re)Starting the kaleido process with plotly version $current_version"
        restart(; plotly_version = current_version, mathjax = something(mathjax, false))
    end
    return
end

# Kaleido gets the processed plot, so it sees the same plotly.js syntax as the other hosts.
function PlotlyKaleido.savefig(io::IO, p::PlotlyPlot, args...; kwargs...)
    ensure_correct_version()
    savefig(io, _process_with_names(p), args...; kwargs...)
end

end
