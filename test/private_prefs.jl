@testmodule PrivatePrefs begin
# Preferences writes to the LocalPreferences.toml of the active project, and the test
# processes that run in parallel share that file. `with_private_prefs(f)` runs `f` with a
# temporary active project, so a preference that `f` writes stays in this process.
# The temporary project lists the package only in `[extras]`: Preferences finds the package
# name there, and package loading ignores it. The old active project stays in LOAD_PATH, so
# `using` works as before.
function with_private_prefs(f)
    old_active = Base.ACTIVE_PROJECT[]
    old_load_path = copy(LOAD_PATH)
    mktempdir() do dir
        project = joinpath(dir, "Project.toml")
        write(project, "[extras]\nPlotlyBaseExtras = \"ba01aadf-c838-43fc-827a-f1961e451c7b\"\n")
        prepend!(LOAD_PATH, filter(!isnothing, [project, Base.active_project()]))
        Base.ACTIVE_PROJECT[] = project
        try
            f()
        finally
            Base.ACTIVE_PROJECT[] = old_active
            copy!(LOAD_PATH, old_load_path)
        end
    end
end
end
