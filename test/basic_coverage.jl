using Test
using PlotlyBaseExtras
using PlotlyBaseExtras: _preprocess, FORCE_FLOAT32, ARTIFACT_VERSION, plotly_version, _process_with_names
using PlotlyBaseExtras.PlotlyBase: ColorScheme, Colors, Cycler, templates
using PlotlyBaseExtras.AbstractPlutoDingetjes
using ScopedValues

p = plot(rand(Int, 4));
_p = p |> _process_with_names
@test first(_p[:data])[:y] isa Vector{Float32}
with(FORCE_FLOAT32 => false) do 
    _p = p |> _process_with_names
    @test first(_p[:data])[:y] isa Vector{Int}
end

@test force_mathjax_local() === false
try
    force_mathjax_local(true)
    @test force_mathjax_local() === true
finally
    force_mathjax_local(false)
end
@test PlutoPlot === PlotlyPlot
@test force_pluto_mathjax_local === force_mathjax_local

@test ColorScheme([Colors.RGB(0.0, 0.0, 0.0), Colors.RGB(1.0, 1.0, 1.0)],
"custom", "twotone, black and white") |> _process_with_names == [(0.0, "rgb(0,0,0)"), (1.0, "rgb(255,255,255)")]
@test _preprocess(SubString("asda",1:3)) === "asd"
@test _preprocess(:lol) === "lol"
@test _process_with_names(true) === true
@test _preprocess(Cycler((1,2))) == [1,2]
@test _process_with_names(1) === 1.0f0 # By default process converts to Float32
@test _preprocess(L"3+2") === raw"$3+2$"
@test all(x -> _preprocess(x) === x, [nothing, missing])

# Check that plotly is the default
@test default_plotly_template() == templates[templates.default]
try
    @test default_plotly_template(:none) == Template()
    @test default_plotly_template("seaborn") == templates[:seaborn]
    @test_logs (:info, "The default plotly template is seaborn") default_plotly_template(;find_matching = true)
finally
    default_plotly_template(templates[templates.default]) 
end
let p = plot(rand(4))
    @test get_image_options(p) == Dict{Symbol,Any}()
    change_image_options!(p; height = 400)
    @test get_image_options(p) == Dict{Symbol,Any}(:height => 400)
    @test_throws "invalid keyword arguments" change_image_options!(p; heights = 400)
end

@test plutoplotly_paste_receiver() isa PlotlyBaseExtras.HypertextLiteral.Result

@test get_plotly_version() === ARTIFACT_VERSION
try
    @test change_plotly_version("2.30") === VersionNumber("2.30.0")
    @test get_plotly_version() === VersionNumber("2.30.0")
    @test VersionNumber("2.33.0") === with(plotly_version => "2.33") do 
        get_plotly_version()
    end 
finally
    # Clear the runtime version, so later tests see the Preferences and default layers.
    change_plotly_version(nothing)
end

@testset "Pluto 1.0 publish_to_js compatibility" begin
    had_plutorunner = isdefined(Main, :PlutoRunner)
    try
        if !had_plutorunner
            @eval Main module PlutoRunner end
        end
        reference_published = AbstractPlutoDingetjes.Display.published_to_js(Dict("x" => 1))
        published = PlotlyBaseExtras.to_js(PlotlyBaseExtras.PlutoHost(), Dict("x" => 1))
        @test typeof(published) === typeof(reference_published)
        called = Ref(false)
        io = IOContext(
            IOBuffer(),
            :is_pluto => true,
            :pluto_published_to_js => (io, x) -> begin
                called[] = (x == Dict("x" => 1))
                write(io, "ok")
            end,
        )
        show(io, MIME"text/javascript"(), published)
        @test called[]
    finally
        if !had_plutorunner && isdefined(Main, :PlutoRunner)
            Base.delete_binding(Main, :PlutoRunner)
        end
    end
end

@testset "Host rendering" begin
    p_plain = plot([123, 456])
    push_script!(p_plain, htl_js("const user_script = true"))
    rendered = sprint(PlotlyBaseExtras.render, PlotlyBaseExtras.PlainHTML(), p_plain)
    @test occursin("123", rendered)
    @test occursin("renderPlot(", rendered)
    @test occursin("insertAdjacentElement", rendered)
    @test occursin("document.currentScript", rendered)
    @test occursin("https://esm.sh/plotly.js-dist-min@", rendered)
    @test occursin(r"\}\)\(document\.currentScript\)\.catch\(console\.error\);\s*</script>\s*$", rendered)
    @test !occursin("invalidation.then", rendered)

    shown = repr(MIME"text/html"(), p_plain)
    @test occursin("document.currentScript", shown)

    adapter_position = findfirst("currentScript.insertAdjacentElement", rendered)
    user_position = findfirst("const user_script = true", rendered)
    @test !isnothing(adapter_position) &&
        !isnothing(user_position) &&
        first(user_position) > first(adapter_position)
end