## add listeners ##
"""
	add_js_listener!(p::PlotlyPlot, event_name::String, listener::AbstractString)

Add a custom *javascript* `listener` (the code of a JS function, as a string) to the `PlotlyPlot` object `p`, and associated to the javascript event specified by `event_name`.
If the code contains `</script` (in any case) or `<!--`, the function throws an `ArgumentError`.

The listeners are added to the HTML plot div after rendering. The div where the plot is inserted can be accessed using the variable named `PLOT` inside the listener code.

# Differences with `add_plotly_listener!`
This function adds standard javascript events via the `addEventListener` function. These events differ from the plotly specific events.

Inside the plot area, plotly.js puts a cover element over the page when a mouse button goes down.
With a mouse or another pointer that can hover, the `dblclick` event then goes to `document.body`
and not to `PLOT`, so a `"dblclick"` listener does not run there. It runs only in the areas
outside the plotly drag areas, for example the title. To catch a double click in the plot area,
use `add_plotly_listener!(p, "plotly_doubleclick", listener)`.

See also: [`add_plotly_listener!`](@ref)

# Examples:
```julia
p = PlotlyPlot(Plot(rand(10), Layout(uirevision = 1)))
add_js_listener!(p, "mousedown", \"\"\"
function(e) {

console.log(PLOT) // logs the plot div inside the developer console when pressing down the mouse

}
\"\"\")
```
"""
function add_js_listener!(p::PlotlyPlot, event_name::String, listener::AbstractString)
	push!(get!(p.js_listeners, event_name, String[]), _check_js(listener))
	return p
end

## add class ##
"""
	add_class!(p::PlotlyPlot, className::String)

Add a CSS class with name `className` to the list of custom classes that are added to the PLOT div when displayed inside Pluto. This can be used to give custom CSS styles to certain plots.

See also: [`remove_class!`](@ref)
"""
function add_class!(p::PlotlyPlot, className::String)
	cl = p.classList
	if className ∉ cl
		push!(cl, className)
	end
	return p
end

## remove class ##

"""
	remove_class!(p::PlotlyPlot, className::String)

Remove a CSS class with name `className` (if present) from the list of custom classes that are added to the PLOT div when displayed inside Pluto. This can be used to give custom CSS styles to certain plots.

See also: [`add_class!`](@ref)
"""
function remove_class!(p::PlotlyPlot, className::String)
	cl = p.classList
	idx = findfirst(x -> x === className, cl)
	if idx !== nothing
		deleteat!(cl, idx)
	end
	return p
end

## Push Script ##
"""
	push_script!(p::PlotlyPlot, items::AbstractString...)
Add the JS code in `items` at the end of the plot show method script.
If the code contains `</script` (in any case) or `<!--`, the function throws an `ArgumentError`.
"""
function push_script!(p::PlotlyPlot, items::AbstractString...)
	@nospecialize
	push!(p.script_contents.vec, map(_check_js, items)...)
	return p
end

## plotly listener ##
"""
	add_plotly_listener!(p::PlotlyPlot, event_name::String, listener::AbstractString)

Add a custom *javascript* `listener` (the code of a JS function, as a string) to the `PlotlyPlot` object `p`, and associated to the [plotly event](https://plotly.com/javascript/plotlyjs-events/) specified by `event_name`.
If the code contains `</script` (in any case) or `<!--`, the function throws an `ArgumentError`.

The listeners are added to the HTML plot div after rendering. The div where the plot is inserted can be accessed using the variable named `PLOT` inside the listener code.

# Differences with `add_js_listener!`
This function adds a listener using the plotly internal events via the `on` function. These events differ from the standard javascript ones and provide data specific to the plot.

See also: [`add_js_listener!`](@ref)

# Examples:
```julia
p = PlotlyPlot(Plot(rand(10), Layout(uirevision = 1)))
add_plotly_listener!(p, "plotly_relayout", \"\"\"
function(e) {

console.log(PLOT) // logs the plot div inside the developer console

}
\"\"\")
```
"""
function add_plotly_listener!(p::PlotlyPlot, event_name::String, listener::AbstractString)
	push!(get!(p.plotly_listeners, event_name, String[]), _check_js(listener))
	return p
end