using Test
using Pluto
using Pluto: ServerSession, SessionActions, Configuration, WorkspaceManager
using Sockets
const BH = BrowserHelper

# Console errors that say nothing about the plots:
# - Pluto's frontend prints the first one while the editor page connects before
#   the notebook registered on the websocket.
# - The `@frompackage` cell of the fixture adds a PlutoDevMacros script
#   (`frompackage-text-replace`). Its `execute_cell_observer` reads the output of
#   a cell that has no `pluto-output` yet and throws a TypeError, which Pluto
#   prints as two errors.
PLUTO_NOISE = ("Notebook does not exist. Not connecting.", "frompackage-text-replace", "execute_cell_observer")
is_noise(error) = any(n -> occursin(n, error), PLUTO_NOISE)

# A port that is free now, so Pluto binds it directly instead of falling back
# to a random one.
function free_port()
    port, server = Sockets.listenany(Sockets.IPv4(0x7f000001), 0)
    close(server)
    return port
end

# Wait until the notebook process started and every cell finished running.
# `executetoken` stays claimed for the whole run, so a free token together
# with a ready process means the run cannot start anymore. The first run also
# instantiates the notebook environment in a separate process, so the
# timeout covers package precompilation.
function wait_cells_ready(notebook; timeout = 600)
    done() = notebook.process_status == "ready" &&
        isready(notebook.executetoken) &&
        all(c -> !c.running && !c.queued, notebook.cells)
    WorkspaceManager.poll(done, timeout, 0.5) ||
        error("notebook cells did not finish within $(timeout) s")
    errored = filter(c -> c.errored, notebook.cells)
    isempty(errored) || error("notebook cells failed: " * join(
        (string(first(split(c.code, '\n')), " → ",
          c.output.body isa AbstractDict ? get(c.output.body, :msg, c.output.body) : c.output.body)
         for c in errored), "; "))
    return
end

if !BH.chrome_available()
    @warn "Chrome not found: skipping browser tests. Set CHROME_PATH to run them."
    @test_skip true
else
    session = ServerSession(; options = Configuration.from_flat_kwargs(;
        port = free_port(),
        launch_browser = false,
        require_secret_for_access = false,
        require_secret_for_open_links = false,
        disable_writing_notebook_files = true,
        workspace_use_distributed_stdlib = true,
    ))
    server_task = @async Pluto.run!(session)
    # `run!` returns as soon as the HTTP server listens.
    server = fetch(server_task)::Pluto.RunningPlutoServer
    notebook = SessionActions.open(session,
        joinpath(@__DIR__, "fixtures", "pluto_host_notebook.jl"); run_async = true)
    try
        wait_cells_ready(notebook)

        BH.with_page("http://127.0.0.1:$(session.options.server.port)/edit?id=$(notebook.notebook_id)";
            timeout = 60) do page
            # Plotly and Pluto's own MathJax load from the network, so both
            # waits get generous timeouts.
            BH.wait_for(page, "document.querySelectorAll('.js-plotly-plot .main-svg').length >= 2"; timeout = 60)
            BH.wait_for(page, "document.querySelector('.gtitle-math-group svg') !== null"; timeout = 60)

            errors = filter(!is_noise, BH.console_errors(page))
            @test isempty(errors)
            @test BH.count_nodes(page, ".js-plotly-plot") == 2
            @test BH.has_visible_svg(page, ".gtitle-math-group")

            # A real mouse click on a point of the first plot fires the custom listener.
            BH.click(page, ".js-plotly-plot .point")
            # The console message arrives asynchronously over CDP.
            deadline = time() + 20
            while time() < deadline && !("host test click" in BH.console_messages(page))
                sleep(0.1)
            end
            @test "host test click" in BH.console_messages(page)
        end
    finally
        SessionActions.shutdown(session, notebook)
        close(server)
    end
end
