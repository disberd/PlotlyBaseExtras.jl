@testmodule BrowserHelper begin

using HTTP
using HTTP.WebSockets
using JSON

const CHROME_CANDIDATES = [
    "google-chrome",
    "google-chrome-stable",
    "chromium",
    "chromium-browser",
    "chrome",
]

function find_chrome()
    env = get(ENV, "CHROME_PATH", "")
    if !isempty(env) && isfile(env)
        return env
    end
    for candidate in CHROME_CANDIDATES
        path = Sys.which(candidate)
        path === nothing || return path
    end
    return nothing
end

chrome_available() = find_chrome() !== nothing

# --- CDP page ---------------------------------------------------------------

mutable struct CDPPage
    ws::WebSockets.WebSocket
    # Router task -> caller. One answer per sent command id.
    responses::Channel{Any}
    next_id::Int
    errors::Vector{String}
    messages::Vector{String}
    loaded::Bool
    lock::ReentrantLock
end

function CDPPage(ws)
    CDPPage(ws, Channel{Any}(32), 0, String[], String[], false, ReentrantLock())
end

function handle_message(page, msg)
    if haskey(msg, "id")
        put!(page.responses, msg["id"] => msg)
        return
    end
    method = get(msg, "method", "")
    params = get(msg, "params", Dict{String,Any}())
    if method == "Runtime.exceptionThrown"
        push_error(page, get(params, "text", "exception"))
    elseif method == "Runtime.consoleAPICalled"
        # An object argument (an Error, a DOM node) has no `value`, only a `description`.
        text = join((stringify(get(a, "value", get(a, "description", nothing))) for a in get(params, "args", [])), " ")
        lock(page.lock) do
            push!(page.messages, text)
        end
        get(params, "type", "") == "error" && push_error(page, text)
    elseif method == "Log.entryAdded"
        entry = get(params, "entry", Dict{String,Any}())
        if get(entry, "level", "") == "error"
            # A page without a favicon link always produces a favicon 404
            # error. It carries no signal, so drop it.
            occursin("favicon.ico", get(entry, "url", "")) || push_error(page, get(entry, "text", "error"))
        end
    elseif method == "Page.loadEventFired"
        lock(page.lock) do
            page.loaded = true
        end
    end
    return
end

stringify(v) = v === nothing ? "undefined" : v isa AbstractString ? String(v) : JSON.json(v)

function push_error(page, text)
    lock(page.lock) do
        push!(page.errors, String(text))
    end
    return
end

"Background task: read every websocket message and route it."
function read_loop(page)
    try
        for msg in page.ws
            handle_message(page, JSON.parse(String(msg)))
        end
    catch err
        # A closed socket ends the loop. Anything else is a real fault.
        err isa Base.IOError || err isa WebSockets.WebSocketError || rethrow()
    finally
        close(page.responses)
    end
    return
end

"Send one CDP command and wait for its answer. Never blocks forever."
function cdp_call(page, method; params = Dict{String,Any}(), timeout = 15.0)
    id = lock(page.lock) do
        page.next_id += 1
    end
    WebSockets.send(page.ws, JSON.json(Dict("id" => id, "method" => method, "params" => params)))
    deadline = time() + timeout
    while true
        remaining = deadline - time()
        remaining <= 0 && error("CDP call $method timed out after $timeout s")
        got = timedwait(() -> isready(page.responses), remaining; pollint = 0.01)
        got == :timed_out && error("CDP call $method timed out after $timeout s")
        rid, msg = take!(page.responses)
        rid == id && return msg
    end
end

# --- page lifecycle ---------------------------------------------------------

# HTTP 1.x pools the connection that served an earlier GET to the same
# DevTools endpoint and hands the dead socket to the websocket handshake.
# HTTP 2.x evicts stale connections on its own, and rejects `forcenew`.
ws_open(f, ws_url) = if Base.pkgversion(HTTP).major < 2
    WebSockets.open(f, ws_url; suppress_close_error = true, forcenew = true)
else
    WebSockets.open(f, ws_url; suppress_close_error = true)
end

"Open the page websocket, enable the domains, and run `f(page)` inside it.
The socket closes when `f` returns."
function with_connected_page(f, ws_url; timeout = 30.0)
    ws_open(ws_url) do ws
        page = CDPPage(ws)
        reader = Threads.@spawn read_loop(page)
        try
            for domain in ("Runtime", "Log", "Page")
                cdp_call(page, "$(domain).enable"; timeout = timeout)
            end
            return f(page)
        finally
            close(page.ws)
            # An abrupt Chrome death ends the reader with a socket error.
            # Never let it mask the failure that caused it.
            try wait(reader) catch end
        end
    end
end

"The clipboard API needs an explicit permission grant. Some Chrome builds reject the call; the tests can run without it, so ignore failure."
function grant_clipboard(page)
    origin = get(get(get(cdp_call(page, "Runtime.evaluate";
        params = Dict("expression" => "location.origin", "returnByValue" => true),
        timeout = 5.0), "result", Dict{String,Any}()), "result", Dict{String,Any}()), "value", "http://127.0.0.1")
    try
        cdp_call(page, "Browser.grantPermissions";
            params = Dict(
                "permissions" => ["clipboardReadWrite", "clipboardSanitizedWrite"],
                "origin" => origin,
            ),
            timeout = 5.0,
        )
    catch
    end
    return
end

function navigate(page, url; timeout = 30.0)
    cdp_call(page, "Page.navigate"; params = Dict("url" => url), timeout = timeout)
    # The flag is level-triggered, so a load event that fires between the
    # navigate call and the check is not lost.
    loaded() = lock(page.lock) do
        page.loaded
    end
    if timedwait(loaded, timeout; pollint = 0.05) == :timed_out
        error("page load timed out after $timeout s")
    end
    return
end

# --- public API -------------------------------------------------------------

"""
    with_page(f, url; timeout = 30)

Open `url` in headless Chrome and run `f(page)`. When `PLOTLY_CDP_URL` points
at a running browser (for example `http://127.0.0.1:50006`), a new tab is
created there and closed at the end; other tabs stay untouched. Every browser
resource the helper created is always released.
"""
function with_page(f, url::AbstractString; timeout = 30)
    cdp_url = get(ENV, "PLOTLY_CDP_URL", "")
    if !isempty(cdp_url)
        return with_remote_page(f, url, cdp_url; timeout = timeout)
    end
    chrome = find_chrome()
    chrome === nothing && error("no Chrome executable found, set CHROME_PATH")
    return with_local_page(f, url, chrome; timeout = timeout)
end

function with_local_page(f, url, chrome; timeout = 30)
    user_data = mktempdir()
    proc = Ref{Union{Base.Process,Nothing}}(nothing)
    stderr_pipe = Base.Pipe()
    try
        cmd = Cmd(String[
            chrome,
            "--headless=new",
            "--no-sandbox",
            "--disable-gpu",
            "--remote-debugging-port=0",
            "--remote-allow-origins=*",
            "--user-data-dir=$(user_data)",
            "about:blank",
        ])
        cmd = pipeline(cmd; stderr = stderr_pipe)
        proc[] = run(cmd; wait = false)
        ws_base = devtools_base(stderr_pipe; timeout = timeout)
        return with_page_target(f, ws_base, url; timeout = timeout)
    finally
        kill_chrome(proc[])
        # Chrome helper processes can outlive the main process for a moment
        # and keep writing into the profile. Retry once, then leave the
        # leftover in the temp directory rather than fail the test.
        try
            rm(user_data; force = true, recursive = true)
        catch
            sleep(1)
            try
                rm(user_data; force = true, recursive = true)
            catch
            end
        end
    end
end

function with_remote_page(f, url, cdp_url; timeout = 30)
    base = rstrip(cdp_url, '/')
    version = JSON.parse(String(HTTP.get("$base/json/version").body))
    browser_ws = version["webSocketDebuggerUrl"]
    ws_open(browser_ws) do bws
        inbox = Channel{Any}(32)
        reader = Threads.@spawn ws_read_loop(bws, inbox)
        target_id = browser_call(inbox, bws, "Target.createTarget";
            params = Dict("url" => "about:blank"), timeout = timeout)["result"]["targetId"]
        try
            ws_url = target_ws_url(base, target_id)
            return with_connected_page(ws_url; timeout = timeout) do page
                grant_clipboard(page)
                navigate(page, url; timeout = timeout)
                return f(page)
            end
        finally
            browser_call(inbox, bws, "Target.closeTarget";
                params = Dict("targetId" => target_id), timeout = timeout)
        end
    end
end

function with_page_target(f, http_base, url; timeout = 30)
    targets = JSON.parse(String(HTTP.get("$http_base/json/list").body))
    page_target = first(t for t in targets if get(t, "type", "") == "page")
    return with_connected_page(page_target["webSocketDebuggerUrl"]; timeout = timeout) do page
        grant_clipboard(page)
        navigate(page, url; timeout = timeout)
        return f(page)
    end
end

# --- local chrome plumbing --------------------------------------------------

"Read Chrome stderr until it prints the DevTools websocket URL."
function devtools_base(pipe; timeout)
    marker = "DevTools listening on "
    read_task = Threads.@spawn begin
        while !eof(pipe)
            line = readline(pipe)
            occursin(marker, line) && return strip(replace(line, marker => ""))
        end
        return nothing
    end
    result = timedwait(() -> istaskdone(read_task), timeout; pollint = 0.05)
    result == :timed_out && error("Chrome did not report a DevTools port within $timeout s")
    ws_url = fetch(read_task)
    ws_url === nothing && error("Chrome exited before reporting a DevTools port")
    close(pipe)
    m = match(r":(\d+)/", ws_url)
    m === nothing && error("cannot parse DevTools port from $ws_url")
    return "http://127.0.0.1:$(m.captures[1])"
end

function kill_chrome(proc)
    proc === nothing && return
    try
        process_running(proc) && kill(proc)
        wait(proc)
    catch
    end
    return
end

# --- remote browser plumbing ------------------------------------------------

"One-shot CDP call over a browser-level websocket. Never blocks forever."
function browser_call(inbox, ws, method; params = Dict{String,Any}(), timeout = 10.0)
    id = abs(rand(Int))
    WebSockets.send(ws, JSON.json(Dict("id" => id, "method" => method, "params" => params)))
    deadline = time() + timeout
    remaining = timeout
    while remaining > 0
        got = timedwait(() -> isready(inbox), remaining; pollint = 0.01)
        got == :timed_out && break
        msg = take!(inbox)
        haskey(msg, "id") && msg["id"] == id && return msg
        remaining = deadline - time()
    end
    error("browser call $method timed out after $timeout s")
end

"Route raw websocket text into `inbox`. A closed socket ends the loop."
function ws_read_loop(ws, inbox)
    try
        for msg in ws
            put!(inbox, JSON.parse(String(msg)))
        end
    catch err
        err isa Base.IOError || err isa WebSockets.WebSocketError || rethrow()
    finally
        close(inbox)
    end
end

function target_ws_url(base, target_id)
    targets = JSON.parse(String(HTTP.get("$base/json/list").body))
    target = first(t for t in targets if get(t, "id", "") == target_id)
    return target["webSocketDebuggerUrl"]
end

# --- static file server -----------------------------------------------------

const CONTENT_TYPES = Dict(
    ".html" => "text/html; charset=utf-8",
    ".js" => "text/javascript; charset=utf-8",
    ".mjs" => "text/javascript; charset=utf-8",
    ".css" => "text/css; charset=utf-8",
)

"""
    with_file(f, path; kwargs...)

Serve the directory of `path` over HTTP and open `/basename(path)` in a page.
An http origin is required because `file://` is not a secure context and the
clipboard API would stay unavailable.
"""
function with_file(f, path; kwargs...)
    root = Ref(dirname(abspath(path)))
    handler = request -> begin
        name = HTTP.URI(request.target).path
        name = lstrip(name, '/')
        file = normpath(joinpath(root[], name))
        # Only files inside the served directory are readable.
        if isfile(file) && startswith(file, normpath(root[]))
            ext = last(splitext(file))
            return HTTP.Response(200, ["Content-Type" => get(CONTENT_TYPES, ext, "application/octet-stream")], read(file))
        end
        return HTTP.Response(404, "not found")
    end
    server = HTTP.serve!(handler, "127.0.0.1", 8080; listenany = true)
    try
        port = HTTP.port(server)
        return with_page(f, "http://127.0.0.1:$(port)/$(basename(path))"; kwargs...)
    finally
        close(server)
    end
end

# --- page API ---------------------------------------------------------------

"""
    evaluate(page, js)

Run `js` in the page and return the resulting value. Throws when the page throws.
"""
function evaluate(page, js::AbstractString)
    result = cdp_call(page, "Runtime.evaluate";
        params = Dict(
            "expression" => js,
            "returnByValue" => true,
            "awaitPromise" => true,
        ),
    )
    details = get(result, "exceptionDetails", nothing)
    details === nothing || evaluate_error(details)
    # Runtime.evaluate answers with {result = {result = {...}}}:
    # the command result holds a second `result` with the remote object.
    return get(get(get(result, "result", Dict{String,Any}()), "result", Dict{String,Any}()), "value", nothing)
end

function evaluate_error(details)
    exc = get(details, "exception", nothing)
    text = get(details, "text", "page error")
    exc === nothing || (text *= " " * stringify(get(exc, "description", get(exc, "value", nothing))))
    error("page evaluate failed: $(text)")
end

"""
    wait_for(page, js_condition; timeout = 20)

Poll `js_condition` until it returns a truthy value. Errors on timeout.
"""
function wait_for(page, js_condition; timeout = 20)
    deadline = time() + timeout
    while time() < deadline
        value = evaluate(page, js_condition)
        (value !== nothing && value !== false) && return value
        sleep(0.1)
    end
    error("wait_for timed out after $timeout s: $js_condition")
end

function console_errors(page)
    return lock(page.lock) do
        copy(page.errors)
    end
end

function console_messages(page)
    return lock(page.lock) do
        copy(page.messages)
    end
end

count_nodes(page, selector) =
    Int(evaluate(page, "document.querySelectorAll($(JSON.json(selector))).length"))

"Scroll the first match into view, then a real mouse press and release at its centre."
function click(page, selector)
    box = evaluate(page, """
        (() => {
            const el = document.querySelector($(JSON.json(selector)));
            if (!el) return null;
            el.scrollIntoView({block: 'center'});
            const r = el.getBoundingClientRect();
            return {x: r.x + r.width / 2, y: r.y + r.height / 2};
        })()
    """)
    box === nothing && error("no element matches $selector")
    for typ in ("mousePressed", "mouseReleased")
        cdp_call(page, "Input.dispatchMouseEvent";
            params = Dict(
                "type" => typ,
                "x" => box["x"],
                "y" => box["y"],
                "button" => "left",
                "clickCount" => 1,
            ),
        )
    end
    return
end

"True when the first match is or contains an `svg` element with a non-zero box."
function has_visible_svg(page, selector)
    return evaluate(page, """
        (() => {
            const el = document.querySelector($(JSON.json(selector)));
            if (!el) return false;
            const svg = el.tagName.toLowerCase() === 'svg' ? el : el.querySelector('svg');
            if (!svg) return false;
            const r = svg.getBoundingClientRect();
            return r.width > 0 && r.height > 0;
        })()
    """) === true
end

end # testmodule
