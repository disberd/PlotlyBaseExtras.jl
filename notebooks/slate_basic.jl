try; import KaimonSlate; catch; error("This is a Kaimon Slate notebook — running it as plain Julia needs the KaimonSlate runtime in this environment. Add it with `import Pkg; Pkg.add(\"KaimonSlate\")`, or open it in Kaimon Slate."); end; KaimonSlate.standalone!(@__MODULE__; dir=@__DIR__)

#%% code id=setup
using PlotlyBaseExtras

#%% md id=check
@md"""
# Slate Plotly check

Check that both plots render, that each plot can be re-run, and that clicking a plot writes its
matching JavaScript and Plotly event message to the browser console.
"""

#%% code id=plot_a
pa = plot(scatter(; x = [1, 2, 3], y = [3, 1, 2]), Layout(; title = "A"))
add_js_listener!(pa, "click", "(e) => console.log('slate_basic click A')")
add_plotly_listener!(pa, "plotly_click", "(e) => console.log('slate_basic plotly_click A')")
pa

#%% code id=plot_b
pb = plot(bar(; x = ["a", "b", "c"], y = [3, 1, 2]), Layout(; title = "B"))
add_js_listener!(pb, "click", "(e) => console.log('slate_basic click B')")
add_plotly_listener!(pb, "plotly_click", "(e) => console.log('slate_basic plotly_click B')")
pb

# ╔═╡ Slate.config · per-notebook settings (Settings panel)
#   docid = df4532db-81bf-448a-96be-7eb1b7af97d5
# ╚═╡
