@testitem "Preprocess" begin
    using PlotlyBaseExtras: _process_with_names, AttrName, _preprocess, AttrName
    l = Layout(;
        title_text = "asd",
        title_x = 0.5
    )
    d = _process_with_names(l, Val(true), AttrName(:layout))
    @test d[:title] isa Dict
    tit = d[:title]
    @test haskey(tit, :text) && tit[:text] == "asd"
    @test haskey(tit, :x) && tit[:x] == 0.5

    # Add a test for nested attrs (Cause of issue #65)
    l = Layout(;
        sliders = [attr(;
            steps = [
                attr(;
                    label = "Step 1",
                    value = 1
                )
            ]
        )]
    )
    d = _process_with_names(l)
    @test d[:sliders][1][:steps][1] isa Dict{Symbol}

    # Misc coverage
    @test_throws ErrorException _preprocess(1im)
    @test length((AttrName(:x)...,)) == 1
end

@testitem "plotly.js 2 names" begin
    using PlotlyBaseExtras: _process_with_names, PlotlyPlot, plotly_version
    using ScopedValues
    using Base.CoreLogging: Warn

    # A String title becomes a Dict at any path, also in a trace and in a template.
    t = Template(layout = Layout(title = "template title"))
    p = Plot(pie(values = [1, 2], title = "pie title"), Layout(title = "layout title", xaxis = attr(title = "x title"), template = t))
    d = _process_with_names(PlotlyPlot(p))
    @test d[:layout][:title] == Dict(:text => "layout title")
    @test d[:layout][:xaxis][:title] == Dict(:text => "x title")
    @test d[:data][1][:title] == Dict(:text => "pie title")
    @test d[:layout][:template][:layout][:title] == Dict(:text => "template title")

    # The core turns off the plotly.js 4 button that sends the plot to Plotly Cloud.
    @test d[:config][:showSendToCloud] === false

    # A removed trace type warns only when the selected plotly.js version removed it. The
    # default template has `heatmapgl` and `scattermapbox` entries, which never warn.
    mapbox = PlotlyPlot(Plot(scattermapbox(lat = [45], lon = [7])))
    @test_logs min_level = Warn with(() -> _process_with_names(mapbox), plotly_version => "2.35")
    @test_logs min_level = Warn _process_with_names(PlotlyPlot(Plot(scatter(y = [1, 2]))))
    d = @test_logs (:warn, r"removed the `scattermapbox` trace type") _process_with_names(mapbox)
    @test d[:data][1][:type] == "scattermapbox"
end