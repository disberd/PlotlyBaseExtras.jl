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
p = plot(scatter(; x = [1, 2, 3], y = [2, 1, 3]), Layout(; title = "A"))
add_js_listener!(p, "click", "(e) => console.log('slate_basic click A')")
add_plotly_listener!(p, "plotly_click", "(e) => console.log('slate_basic plotly_click A')")
p

#%% code id=plot_b
p = plot(bar(; x = ["a", "b", "c"], y = [3, 1, 2]), Layout(; title = "B"))
add_js_listener!(p, "click", "(e) => console.log('slate_basic click B')")
add_plotly_listener!(p, "plotly_click", "(e) => console.log('slate_basic plotly_click B')")
p
