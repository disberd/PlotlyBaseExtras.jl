get_plotly_esm_url(v) = "https://esm.sh/plotly.js-dist-min@$(VersionNumber(v))"
get_plotly_cdn_url(v) = "https://cdn.plot.ly/plotly-$(VersionNumber(v)).min.js"

# We use our custom bundler to download an esm version of the plotly library
get_plotly_download_url(v) = "https://github.com/disberd/PlotlyArtifactsESM/releases/download/v$(VersionNumber(v))/plotly-esm-min.mjs"

"""
mapping a path like "/home/user/.julia/blabla/plotly-1.2.3.min.js" to its contents, read as String
"""
const PLOTLY_DEP_CONTENTS = Dict{String, String}()

function get_local_plotly_contents(v)
    maybe_add_plotly_local(v)
    path = get_local_path(v)
    get!(PLOTLY_DEP_CONTENTS, path) do
        read(path, String)
    end
end

get_local_path(v) = if VersionNumber(v) === ARTIFACT_VERSION
    joinpath(artifact"plotly-esm-min", "plotly-esm-min.mjs")
else
    # We use the UUID explicitly to make this work with PlutoDevMacros even without rootmodule
    scratchspace = get_scratch!(Base.UUID("ba01aadf-c838-43fc-827a-f1961e451c7b"), "plotly-library-esm")
    joinpath(scratchspace, "$(get_local_name(v)).mjs")
end
get_local_name(v) = "plotly-esm-min-$(VersionNumber(v))"

function maybe_add_plotly_local(v)
    ver = VersionNumber(v)
    # Check if the artifact already exists
    path = get_local_path(ver)
    if !isfile(path)
        # We download bundle and save locally
        @info "Downloading a local version of plotly@$v"
        bundle_url = get_plotly_download_url(ver)
        download(bundle_url, path)
    end
    nothing
end




# Identify a remote JS ESM module to be imported when shown in a script. The `extract` argument, if non-empty, will be the name of the property of the remote module to extract
struct _ImportedRemoteJS
    src::String
    extract::String
end
_ImportedRemoteJS(src) = _ImportedRemoteJS(src, "")

function Base.show(io, m::MIME"text/javascript", i::_ImportedRemoteJS)
    write(io, 
        "(await import($(repr(i.src))))"
    )
    if !isempty(i.extract)
        # Extract specific field from the module
        write(io, ".$(i.extract)")
    end
end


# Identify a local (on filesystem) JS ESM module to be imported when shown in a script. The `extract` argument, if non-empty, will be the name of the property of the local module to extract
struct _ImportedLocalJS
    published
    extract::String
    function _ImportedLocalJS(published, extract::AbstractString = "")
        @nospecialize
        new(published, extract)
    end
end


function Base.show(io, m::MIME"text/javascript", i::_ImportedLocalJS)
    write(io, 
        """
        (await (() => {
        window.created_imports = window.created_imports ?? new Map();
        let code = """
    )
    _show_published(io, m, i.published)

    # The module loads from a blob URL. Do not use a data URL: Chrome needs about 10 GB of memory
    # to import the plotly.js bundle (5 MB) from a data URL, and about 200 MB from a blob URL.
    write(io,
        """;
        if(created_imports.has(code)){
            return created_imports.get(code);
        } else {
            const url = URL.createObjectURL(new Blob([code], {type : "text/javascript"}));
            const module_promise = import(url).finally(() => URL.revokeObjectURL(url));
            created_imports.set(code, module_promise);
            return module_promise;
        }
        })())
        """
    )
    if !isempty(i.extract)
        # Extract specific field from the module
        write(io, ".$(i.extract)")
    end
    return nothing
end

_show_published(io::IO, m::MIME, published) = Base.show(io, m, published)
# A plain String is a JS string literal. `print_script` escapes `</` as `<\/`,
# so the literal cannot close the surrounding script tag.
_show_published(io::IO, m::MIME, published::AbstractString) = HypertextLiteral.print_script(io, published)

function import_local_js(code::AbstractString, extract::AbstractString = "")

    code_js = 
        try
        AbstractPlutoDingetjes.Display.published_to_js(code)
    catch e
        @warn "published_to_js did not work" exception=(e,catch_backtrace()) maxlog=1
        repr(code)
    end

    _ImportedLocalJS(code_js, extract)
end


"""
    enable_plutoplotly_offline(;version = get_plotly_version())
Creates a script that loads the plotly library on the current browser session so that it is available even when not connected to internet.

Put this in a separate cell so that the plotly JS library is stored in the browser and available for all plots.
"""
function enable_plutoplotly_offline(;version = get_plotly_version())
    _import = import_local_js(get_local_plotly_contents(version), "default")
    v_str = string(VersionNumber(version))
    @htl("""
        <script>
            const imports = {
                $(v_str): $(_import)
            }
            window.plutoplotly_imports = imports
        </script>
    """)
end

struct _ImportedHybridJS
    object::String
    key::String
    fallback::_ImportedRemoteJS
end
function _ImportedHybridJS(v)
    object = "plutoplotly_imports"
    key = string(VersionNumber(v))
    fallback = _ImportedRemoteJS(get_plotly_esm_url(v), "default")
    return _ImportedHybridJS(object, key, fallback)
end


function Base.show(io::IO, m::MIME"text/javascript", i::_ImportedHybridJS)
    write(io, "window.$(i.object)?.['$(i.key)'] ??")
    show(io, m, i.fallback)
end
# function Base.show(io::IO, m::MIME"text/javascript", i::_ImportedHybridJS)
#     write(io, """await (async function() {
#     let Plotly = window.$(i.object)?.['$(i.key)']
#     if (Plotly == undefined) {
#         console.log("Could not find loaded library among offline imports, trying to load from esm.sh")
#         Plotly = """)
#     show(io, m, i.fallback)
#     write(io, """
#     } else {
#         console.log("Loaded plotly from window.plutoplotly_imports")
#     }
#     return Plotly
# })()""")
# end