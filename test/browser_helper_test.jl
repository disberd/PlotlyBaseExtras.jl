using Test
const BH = BrowserHelper

if !BH.chrome_available()
    @warn "Chrome not found: skipping browser tests. Set CHROME_PATH to run them."
    @test_skip true
else
    fixture = joinpath(@__DIR__, "fixtures", "browser_helper.html")
    BH.with_file(fixture) do page
        @test BH.count_nodes(page, "#btn") == 1
        @test BH.has_svg(page, "#math")
        errors = BH.console_errors(page)
        @test occursin("fixture error", only(errors))
        BH.click(page, "#btn")
        BH.wait_for(page, "window.__clicked === true")
        @test "clicked" in BH.console_messages(page)
    end
end
