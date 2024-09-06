local pendingRestart = false
local releaseDownloadUrl = 'https://download.sonoransoftware.com/sonoranradio/fivem/latest.zip'
local releaseVersionUrl  = 'https://download.sonoransoftware.com/sonoranradio/fivem/version.json '

function PerformHttpRequestS(url, cb, method, data, headers)
    if not data then
        data = ""
    end
    if not headers then
        headers = {["X-User-Agent"] = "SonoranCAD"}
    end
    exports["sonoranradio"]:HandleHttpRequest(url, cb, method, data, headers)
end

local function doUnzip(path)
    local unzipPath = GetResourcePath(GetCurrentResourceName()).."/../"
    exports[GetCurrentResourceName()]:UnzipFile(path, unzipPath)
    print("Unzipping to " .. unzipPath .. ". Waiting for unzip to complete.")
    if not Config.allowUpdateWithPlayers and GetNumPlayerIndices() > 0 then
        pendingRestart = true
        print("Delaying auto-update until server is empty.")
        return
    end
end

AddEventHandler("UnzipFileComplete", function(success, err)
	if success then
		print("Update Decompressed Successfully...")
		print("Auto-restarting...")
		local f = assert(io.open(GetResourcePath("sonoranradio_updatehelper").."/run.lock", "w+"))
		f:write("radio")
		f:close()
		Wait(1000)
		ExecuteCommand("ensure sonoranradio_updatehelper")
	else
		print("Unzipping of update did not complete successfully!")
		print(err)
	end
end)

local function doUpdate(latest)
    local releaseUrl = releaseDownloadUrl
    PerformHttpRequest(releaseUrl, function(code, data, headers)
        if code == 200 then
            local savePath = GetResourcePath(GetCurrentResourceName()).."/update.zip"
            local f = assert(io.open(savePath, 'wb'))
            f:write(data)
            f:close()
            print("Saved file...")
            doUnzip(savePath)
        else
            if not Config.enableCanary then
                print(("Failed to download from %s: %s %s"):format(realUrl, code, data))
            end
        end
    end, "GET")
    
end

function RunAutoUpdater(manualRun)
    local f = LoadResourceFile(GetCurrentResourceName(), "/update.zip")
    if f ~= nil then
        -- remove the update file and stop the helper
        ExecuteCommand("stop sonoranradio_updatehelper")
        os.remove(GetResourcePath(GetCurrentResourceName()).."/update.zip")
        os.remove(GetResourcePath("sonoranradio_updatehelper").."/run.lock")
    end
    local versionFile = releaseVersionUrl
    local myVersion = GetResourceMetadata(GetCurrentResourceName(), "version", 0)

    PerformHttpRequestS(versionFile, function(code, data, headers)
        if code == 200 then
            local remote = json.decode(data)
            if remote == nil then
                print(("Failed to get a valid response for %s. Skipping."):format(k))
                print(("Raw output for %s: %s"):format(k, data))
            else
                Config.latestVersion = remote.resource
                _, _, v1, v2, v3 = string.find( myVersion, "(%d+)%.(%d+)%.(%d+)" )
                if v1 == nil or v2 == nil or v3 == nil then return end
                _, _, r1, r2, r3 = string.find( remote.resource, "(%d+)%.(%d+)%.(%d+)" )
                if (string.find(myVersion, "-beta")) then
                    v3 = v3 - 0.5
                end
                print(("my: %s remote: %s"):format(myVersion, remote.resource))
                local latestVersion = r3+(r2*100)+(r1*1000)
                local localVersion = v3+(v2*100)+(v1*1000)

                assert(localVersion ~= nil, "Failed to parse local version. "..tostring(localVersion))
                assert(latestVersion ~= nil, "Failed to parse remote version. "..tostring(latestVersion))

                if latestVersion > localVersion then
                    if not Config.allowAutoUpdate then
                        print("^3|===========================================================================|")
                        print("^3|                        ^5SonoranRadio Update Available")
                        print("^3|                             ^8Current : " .. localVersion)
                        print("^3|                             ^2Latest  : " .. latestVersion)
                        print("^3| Download at: ^4"..releaseDownloadUrl)
                        print("^3|===========================================================================|^7")
                        if Config.allowAutoUpdate == nil then
                            print("You have not configured the automatic updater. Please set allowAutoUpdate in config.json to allow updates.")
                        end
                    else
                        print("Running auto-update now...")
                        doUpdate(remote.resource)
                    end
                else
                    if manualRun then
                        print(("No updates available. Detected version %s, latest version is %s"):format(localVersion, latestVersion))
                    end
                end
            end
        end
    end, "GET")
end


CreateThread(function()
    while true do
        if pendingRestart then
            if GetNumPlayerIndices() > 0 then
                print("An update has been applied to SonoranCAD but requires a resource restart. Restart delayed until server is empty.")
            else
                print("Server is empty, restarting resources...")
                local f = assert(io.open(GetResourcePath("sonoranradio_updatehelper").."/run.lock", "w+"))
                f:write("radio")
                f:close()
                ExecuteCommand("ensure sonoranradio_updatehelper")
            end
        else
            RunAutoUpdater()
        end
        Wait(60000*60)
    end
end)