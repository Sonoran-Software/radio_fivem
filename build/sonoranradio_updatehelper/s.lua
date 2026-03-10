CreateThread(function()
    local helperSignalKey = "sonoranradio_updatehelper_action"
    local action = GetConvar(helperSignalKey, "")
    local res = GetCurrentResourceName()
    local runLock = LoadResourceFile(res, "run.lock")
    local hasRunLock = runLock and runLock:match("^radio")

    -- it is very important to check for both a run.lock and a sonoranradio_updatehelper_action Convar
    -- this is because an older resource would overwrite this file to this version on unzip,
    -- but would still provide a run.lock and no convar
    if action == "radio" or hasRunLock then
        SetConvar(helperSignalKey, "")
        os.remove(GetResourcePath(res) .. "/run.lock")
        ExecuteCommand("refresh")
        Wait(1000)
        ExecuteCommand("restart sonoranradio")
    else
        os.remove(GetResourcePath(res) .. "/run.lock")
        print("sonoranradio_updatehelper is for internal use and should not be started as a resource.")
    end
end)
