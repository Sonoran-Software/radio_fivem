function initMiniRadio()
    nuiFocused = false
    isRegistered = false
    usingTablet = false
    isMiniVisible = false

    -- Debugging Information
    isDebugging = true
    local activeChannels = {}

    function DebugMessage(message, module)
        if not isDebugging then return end
        if module ~= nil then message = "[" .. module .. "] " .. message end
        print(message .. "\n")
    end

    -- Initialization Procedure
    Citizen.CreateThread(function()
        Wait(1000)
        -- Set Default Module Sizes
        InitModuleSize("hud")
        InitModuleConfig("hud")
        InitModulePos("hud")
        -- Disable Controls Loop
        -- while true do
        --     if nuiFocused then -- Disable controls while NUI is focused.
        --         DisableControlAction(0, 1, nuiFocused) -- LookLeftRight
        --         DisableControlAction(0, 2, nuiFocused) -- LookUpDown
        --         DisableControlAction(0, 142, nuiFocused) -- MeleeAttackAlternate
        --         DisableControlAction(0, 106, nuiFocused) -- VehicleMouseControlOverride
        --     end
        --     Citizen.Wait(0) -- Yield until next frame.
        -- end
    end)

    function InitModuleSize(module)
        -- Check if the size of the specified module is already configured.
        local moduleWidth = GetResourceKvpString(module .. "width")
        local moduleHeight = GetResourceKvpString(module .. "height")
        if moduleWidth ~= nil and moduleHeight ~= nil then
            DebugMessage("retrieving saved presets", module)
            -- Send message to NUI to resize the specified module.
            SetModuleSize(module, moduleWidth, moduleHeight)
            SendNUIMessage({type = "refresh", module = module, miniradio = true})
        end
    end

    function InitModuleConfig(module)
        local moduleMaxRows = GetResourceKvpString(module .. "maxrows")
        if moduleMaxRows ~= nil then
            DebugMessage("retrieving config presets", module)
            -- Send messsage to NUI to update config of specified module.
            SetModuleConfigValue(module, "maxrows", moduleMaxRows)
            SendNUIMessage({type = "refresh", module = module, miniradio = true})
        end
    end

    function SetModuleConfigValue(module, key, value)
        DebugMessage(("MODULE %s Setting %s to %s"):format(module, key, value))
        SendNUIMessage({
            type = "config",
            module = module,
            key = key,
            value = value,
            miniradio = true
        })
        DebugMessage("saving config value to kvp")
        SetResourceKvp(module .. key, value)
    end

    -- Set a Module's Size
    function SetModuleSize(module, width, height)
        DebugMessage(("MODULE %s SIZE %s - %s"):format(module, width, height))
        -- Send message to NUI to resize the specified module.
        DebugMessage("sending resize message to nui", module)
        SendNUIMessage({
            type = "resize",
            module = module,
            newWidth = width,
            newHeight = height,
            miniradio = true
        })

        DebugMessage("saving module size to kvp")
        SetResourceKvp(module .. "width", width)
        SetResourceKvp(module .. "height", height)
    end

    -- Refresh a Module
    function RefreshModule(module)
        DebugMessage("sending refresh message to nui", module)
        SendNUIMessage({type = "refresh", module = module, miniradio = true})
    end

    function InitModulePos(module)
        local moduleX = GetResourceKvpString(module .. "x")
        local moduleY = GetResourceKvpString(module .. "y")
        if moduleX ~= nil and moduleY ~= nil then
            DebugMessage("retrieving saved presets", module)
            SetModulePos(module, moduleX, moduleY)
        end
    end

    function SetModulePos(module, x, y)
        DebugMessage(("MODULE %s POS %s - %s"):format(module, x, y))
        SendNUIMessage({
            type = "setMiniRadioUIPosition",
            module = module,
            x = x,
            y = y,
            miniradio = true
        })
        DebugMessage("saving module pos to kvp")
        SetResourceKvp(module .. "x", x)
        SetResourceKvp(module .. "y", y)
    end

    -- Display a Module
    function DisplayModule(module, show)
        DebugMessage("sending display message to nui " .. tostring(show), module)
        SendNUIMessage({
            type = "display",
            module = module,
            enabled = show,
            miniradio = true
        })
    end

    -- Print a chat message to the current player
    function PrintChatMessage(text)
        TriggerEvent('chatMessage', "System", {255, 0, 0}, text)
    end

    -- Set the focus state of the NUI
    function SetFocused(focused)
        nuiFocused = focused
        SetNuiFocus(nuiFocused, nuiFocused)
    end

    -- Remove NUI focus
    RegisterNUICallback('NUIFocusOff', function()
        SetFocused(false)
        PrintChatMessage("Mini-Radio focus " ..
                            (nuiFocused and "enabled" or "disabled"))
    end)

    function openradiousers()
        isMiniVisible = not isMiniVisible
        DisplayModule("hud", isMiniVisible)
        if not GetResourceKvpString("shownTutorial") then
            ShowHelpMessage()
            SetResourceKvp("shownTutorial", "yes")
        end
    end

    RegisterNUICallback('ShowHelp', function(data, cb) ShowHelpMessage() end)

    function ShowHelpMessage()
        PrintChatMessage(
            "• Use /radiousers to toggle the Mini Radio open and closed\n• Open your radio to enable moving the Mini Radio\n• Use /radiouserssize [width] [height]\n• Use /radiousersrefresh to refresh the Mini Radio\n• Use /radiousersrows [rows] to set the number of users shown on the Mini Radio.")
    end

    -- Mini Module Commands
    -- Register the command to open the Mini-Radio
    RegisterCommand("radiousers", function(source, args, rawCommand)
        if not allowedMiniRadio then
            TriggerEvent("chat:addMessage", {
                color = {255, 0, 0},
                multiline = true,
                args = {
                    "Radio Users",
                    "You are not allowed to use the Radio Users panel."
                }
            })
            return
        end
        setActiveUsers(activeChannels)
        openradiousers()
        SendNUIMessage({
            type = 'setMiniRadioUIPosition',
            data = json.decode(GetResourceKvpString('miniradioui_pos_dic') or '{}'),
            miniradio = true
        })
    end)
    RegisterKeyMapping('radiousers', 'Toggle Radio Users', 'keyboard', '')
    TriggerEvent('chat:addSuggestion', '/radiousers', "Toggle the Mini-Radio panel.", {})
    -- Register the command to show the help message
    RegisterCommand("radiousershelp", function() ShowHelpMessage() end)
    TriggerEvent('chat:addSuggestion', '/radiousershelp', "Show the Mini-Radio help message.", {})
    -- Register the command to resize the Mini-Radio
    TriggerEvent('chat:addSuggestion', '/radiouserssize',
                "Resize the Mini-Radio to specific width and height in pixels.", {
        {name = "Width", help = "Width in pixels"},
        {name = "Height", help = "Height in pixels"}
    })
    RegisterCommand("radiouserssize", function(source, args, rawCommand)
        if not args[1] and not args[2] then return end
        SetModuleSize("hud", args[1], args[2])
    end)

    -- Register the command to refresh the Mini-Radio
    RegisterCommand("radiousersrefresh", function() RefreshModule("hud") end)
    TriggerEvent('chat:addSuggestion', '/radiousersrefresh', "Refresh the Mini-Radio.", {})
    -- Register the command to set the number of rows shown on the Mini-Radio
    RegisterCommand("radiousersrows", function(source, args, rawCommand)
        if #args ~= 1 then
            PrintChatMessage("Please specify a number of rows to display.")
            return
        else
            SetModuleConfigValue("hud", "maxrows", tonumber(args[1]) - 1)
            PrintChatMessage("Maximum Mini-Radio users set to " .. args[1])
        end
    end)
    TriggerEvent('chat:addSuggestion', '/radiousersrows',
                "Specify max number of users shown on Mini-Radio.",
                {{name = "rows", help = "any number (default 10)"}})

    RegisterNUICallback("VisibleEvent", function(data, cb)
        if data.module == "hud" then isMiniVisible = data.state end
        cb({ok = true})
    end)

    -- Mini-Radio Events
    function setActiveUsers(channels)
        SendNUIMessage({type = 'channelSync', channels = channels, miniradio = true})
    end

    AddEventHandler('onClientResourceStart',
                    function(resourceName) -- When resource starts, stop the GUI showing.
        if (GetCurrentResourceName() ~= resourceName) then return end
        SetFocused(false)
    end)

    local function findChannel(channelName)
        for i, channel in ipairs(activeChannels) do
            if channel.channelName == channelName then return i end
        end
        return nil
    end

    RegisterNUICallback('UpdateConnectedUsers', function(users, cb)
        activeChannels = {}
        for _, user in ipairs(users.users) do
            local channelIndex = findChannel(user.channelName)
            -- If channel already exists, add the user to the activeUsers list
            if channelIndex then
                table.insert(activeChannels[channelIndex].activeUsers,
                            {name = user.displayName, isTalking = user.isTalking})
            else
                -- If channel doesn't exist, create a new entry for it
                table.insert(activeChannels, {
                    channelName = user.channelName,
                    activeUsers = {{name = user.displayName, isTalking = user.isTalking}}
                })
            end
        end
        TriggerEvent('SonoranRadio:CarRadioUpdate', {signal = getSignalQuality(), users = users})
        setActiveUsers(activeChannels)
        cb('OK')
    end)

    function handleRadioPower(powerState)
        TriggerEvent('SonoranRadio:CarRadioPower', powerState)
        if not powerState then
            activeChannels = {}
            setActiveUsers(activeChannels)
        end
    end

    function handleRefreshScreen()
        activeChannels = {}
        setActiveUsers(activeChannels)
    end

    RegisterNUICallback('SaveMiniRadioPos', function(data)
        SetModulePos("hud", data.x, data.y)
    end)
end