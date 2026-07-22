local pendingRestart = false
local releaseDownloadUrl = 'https://download.sonoransoftware.com/sonoranradio/fivem/enhanced/latest.zip'
local releaseVersionUrl  = 'https://download.sonoransoftware.com/sonoranradio/fivem/enhanced/version.json'
local helperSignalKey = "sonoranradio_updatehelper_action"

local function signalUpdateHelper()
    SetConvar(helperSignalKey, "radio")
end

local function clearUpdateHelperSignal()
    SetConvar(helperSignalKey, "")
end

local function doUnzip(path)
    local unzipPath = GetResourcePath(GetCurrentResourceName()).."/../"
    print("Unzipping to " .. unzipPath .. ". Waiting for unzip to complete.")
    exports[GetCurrentResourceName()]:UnzipFile(path, unzipPath)
end

AddEventHandler("UnzipFileComplete", function(success, err)
	if success then
        -- Defer only the restart; the update has already been downloaded and unzipped.
        -- The updater thread below will pick this up once the server is empty.
        if not Config.allowUpdateWithPlayers and GetNumPlayerIndices() > 0 then
            pendingRestart = true
            print("Delaying auto-update until server is empty.")
            return
        end
		print("Update Decompressed Successfully...")
		print("Auto-restarting...")
		signalUpdateHelper()
		Wait(1000)
		ExecuteCommand("ensure sonoranradio_updatehelper")
	else
		print("Unzipping of update did not complete successfully!")
		print(err)
	end
end)

local function doUpdate(latest)
    local releaseUrl = ("%s?cb=%s"):format(releaseDownloadUrl, tostring(latest or os.time()))
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
                print(("Failed to download from %s: %s %s"):format(releaseUrl, code, data))
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
        clearUpdateHelperSignal()
    end
    local myVersion = GetResourceMetadata(GetCurrentResourceName(), "version", 0)

    local requestCb = function(code, data, headers)
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
    end
    exports["sonoranradio"]:HandleHttpRequest(releaseVersionUrl, requestCb, 'GET')
end


CreateThread(function()
    while true do
        if pendingRestart then
            -- A completed update is waiting for a resource restart.
            if GetNumPlayerIndices() > 0 then
                print("An update has been applied to Sonoran Radio but requires a resource restart. Restart delayed until server is empty.")
            else
                print("Server is empty, restarting resources...")
                signalUpdateHelper()
                ExecuteCommand("ensure sonoranradio_updatehelper")
            end
        else
            RunAutoUpdater()
        end
        Wait(60000*60)
    end
end)
