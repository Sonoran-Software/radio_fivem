nuiFocused = false
isRegistered = false
usingTablet = false
isMiniVisible = false

-- Debugging Information
isDebugging = true

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
    -- Disable Controls Loop
    while true do
        if nuiFocused then -- Disable controls while NUI is focused.
            DisableControlAction(0, 1, nuiFocused) -- LookLeftRight
            DisableControlAction(0, 2, nuiFocused) -- LookUpDown
            DisableControlAction(0, 142, nuiFocused) -- MeleeAttackAlternate
            DisableControlAction(0, 106, nuiFocused) -- VehicleMouseControlOverride
        end
        Citizen.Wait(0) -- Yield until next frame.
    end
end)

function InitModuleSize(module)
    -- Check if the size of the specified module is already configured.
    local moduleWidth = GetResourceKvpString(module .. "width")
    local moduleHeight = GetResourceKvpString(module .. "height")
    if moduleWidth ~= nil and moduleHeight ~= nil then
        DebugMessage("retrieving saved presets", module)
        -- Send message to NUI to resize the specified module.
        SetModuleSize(module, moduleWidth, moduleHeight)
        SendNUIMessage({type = "refresh", module = module})
    end
end

function InitModuleConfig(module)
    local moduleMaxRows = GetResourceKvpString(module .. "maxrows")
    if moduleMaxRows ~= nil then
        DebugMessage("retrieving config presets", module)
        -- Send messsage to NUI to update config of specified module.
        SetModuleConfigValue(module, "maxrows", moduleMaxRows)
        SendNUIMessage({type = "refresh", module = module})
    end
end

function SetModuleConfigValue(module, key, value)
    DebugMessage(("MODULE %s Setting %s to %s"):format(module, key, value))
    SendNUIMessage({type = "config", module = module, key = key, value = value})
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
        newHeight = height
    })

    DebugMessage("saving module size to kvp")
    SetResourceKvp(module .. "width", width)
    SetResourceKvp(module .. "height", height)
end

-- Refresh a Module
function RefreshModule(module)
    DebugMessage("sending refresh message to nui", module)
    SendNUIMessage({type = "refresh", module = module})
end

-- Display a Module
function DisplayModule(module, show)
    DebugMessage("sending display message to nui " .. tostring(show), module)
    if not isRegistered then apiCheck = true end
    SendNUIMessage({
        type = "display",
        module = module,
        enabled = show
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
RegisterNUICallback('NUIFocusOff', function() SetFocused(false) end)

function openMiniRadio()
    isMiniVisible = not isMiniVisible
    DisplayModule("hud", isMiniVisible)
    if not GetResourceKvpString("shownTutorial") then
        ShowHelpMessage()
        SetResourceKvp("shownTutorial", "yes")
    end
end

function ShowHelpMessage()
    PrintChatMessage(
        "• Use /miniradio to toggle the Mini Radio open and closed\n• Use /miniradiofocus to enable moving the Mini Radio\n• Use /miniradiosize [width] [height]\n• Use /miniradiorefresh to refresh the Mini Radio\n• Use /miniradiorows [rows] to set the number of users shown on the Mini Radio.")
end

-- Mini Module Commands
RegisterCommand("miniradio",
                function(source, args, rawCommand) openMiniRadio() end, false)
RegisterKeyMapping('miniradio', 'Mini CAD', 'keyboard', '')

RegisterCommand("miniradiohelp", function() ShowHelpMessage() end)

TriggerEvent('chat:addSuggestion', '/miniradiosize',
             "Resize the Mini-Radio to specific width and height in pixels.", {
    {name = "Width", help = "Width in pixels"},
    {name = "Height", help = "Height in pixels"}
})
RegisterCommand("miniradiosize", function(source, args, rawCommand)
    if not args[1] and not args[2] then return end
    SetModuleSize("hud", args[1], args[2])
end)
RegisterCommand("miniradiorefresh", function() RefreshModule("hud") end)

RegisterCommand("miniradiorows", function(source, args, rawCommand)
    if #args ~= 1 then
        PrintChatMessage("Please specify a number of rows to display.")
        return
    else
        SetModuleConfigValue("hud", "maxrows", tonumber(args[1]) - 1)
        PrintChatMessage("Maximum Mini-Radio users set to " .. args[1])
    end
end)
TriggerEvent('chat:addSuggestion', '/miniradiorows',
             "Specify max number of users shown on Mini-Radio.",
             {{name = "rows", help = "any number (default 10)"}})

RegisterCommand("miniradiofocus", function()
    SetFocused(not nuiFocused)
    PrintChatMessage("Mini-Radio focus " ..
                         (nuiFocused and "enabled" or "disabled"))
end)
TriggerEvent('chat:addSuggestion', '/miniradiofocus',
             "Enable or disable moving the Mini-Radio.", {})
RegisterNUICallback("ShowHelp", function() ShowHelpMessage() end)

RegisterNUICallback("VisibleEvent", function(data, cb)
    if data.module == "hud" then isMiniVisible = data.state end
    cb({ok = true})
end)

-- Mini-Radio Events
function setActiveUsers(users)
    SendNUIMessage({type = 'userSync', activeUsers = users})
end

AddEventHandler('onClientResourceStart',
                function(resourceName) -- When resource starts, stop the GUI showing.
    if (GetCurrentResourceName() ~= resourceName) then return end
    SetFocused(false)
end)

RegisterCommand('testminiradio', function()
    local users = {}
    local randomNames = {
        "John Doe", "Jane Doe", "John Smith", "Jane Smith", "John Johnson",
        "Jane Johnson", "John Brown", "Jane Brown", "John White", "Jane White"
    }
    for i = 1, 10 do
        table.insert(users, {name = randomNames[math.random(1, #randomNames)]})
    end
end)
