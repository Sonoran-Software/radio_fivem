CreateThread(function()
    local res = GetCurrentResourceName()
    local line = LoadResourceFile(res, "run.lock")
    if line and line:match("^radio") then
        ExecuteCommand("refresh")
        Wait(1000)
        ExecuteCommand("restart sonoranradio")
    else
        os.remove(GetResourcePath(GetCurrentResourceName()) .. "/run.lock")
        print("sonoranradio_updatehelper is for internal use and should not be started as a resource.")
    end
    os.remove(GetResourcePath(GetCurrentResourceName()) .. "/run.lock")
end)
