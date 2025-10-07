
local function playerHasSingleJammerItem(itemName)
    if not itemName or itemName == '' then return true end
    if frameworkEnum == 0 or inventoryEnum == 0 then return false end

    if inventoryEnum == 1 then
        if not QBCore or not QBCore.Functions then return false end
        if type(QBCore.Functions.GetItemByName) == 'table' then
            return not not QBCore.Functions.GetItemByName(itemName)
        elseif type(QBCore.Functions.HasItem) == 'table' then
            return not not QBCore.Functions.HasItem(itemName)
        end
        return false
    elseif inventoryEnum == 2 then
        local count = exports.ox_inventory:GetItemCount(itemName)
        if count > 0 then
            local playerData
            if frameworkEnum == 2 then
                playerData = exports.qbx_core:GetPlayerData()
            elseif frameworkEnum == 1 and QBCore and QBCore.Functions then
                playerData = QBCore.Functions.GetPlayerData()
            end
            return playerData and not playerData.metadata['isdead'] and not playerData.metadata['inlaststand']
        end
        return false
    end

    return false
end


function playerHasJammerItem(itemName)
    if type(itemName) == 'table' then
        for _, name in ipairs(itemName) do
            if playerHasSingleJammerItem(name) then
                return true
            end
        end
        return false
    end

    return playerHasSingleJammerItem(itemName)
end


function initJammers()
    if not Config.radioJammers or Config.radioJammers.enabled == false then
        return
    end

    jammers = {}
    local StaticJammers = {}
    local handheldEntries = {}
    local jammerObjects = {}
    local handheldObjects = {}
    local configByName = {}

    for _, jammer in ipairs(Config.radioJammers.jammers or {}) do
        if jammer.name then
            configByName[jammer.name] = jammer
        end
    end

    local function getLocalServerId()
        return GetPlayerServerId(PlayerId())
    end

    local jammerScaleform = nil
    local jammerMenuState = {
        index = 1,
        jammerId = nil,
        moveSpeed = 0.05,
        ogCoords = nil,
        ogHeading = nil,
        lastCoordUpdate = nil,
        calculatedHeading = nil,
        note = ''
    }
    local handheldMenuState = {
        index = 1,
        pending = false
    }
    local localHandheldState = {
        active = false,
        id = nil,
        config = nil
    }

    local function clonePosition(pos)
        return {
            x = pos.x,
            y = pos.y,
            z = pos.z,
            heading = pos.heading,
            exact = pos.exact
        }
    end

    local function ensureScaleform()
        if jammerScaleform ~= nil then return end
        jammerScaleform = RequestScaleformMovie('INSTRUCTIONAL_BUTTONS')
        while not HasScaleformMovieLoaded(jammerScaleform) do
            Citizen.Wait(0)
        end
    end

    local function removeJammerObject(id)
        local handle = jammerObjects[id]
        if handle and DoesEntityExist(handle) then
            DeleteObject(handle)
        end
        jammerObjects[id] = nil
    end

    local function ensureJammerObject(jam, myPos)
        myPos = myPos or GetEntityCoords(PlayerPedId())
        local pos = jam.PropPosition or {}
        local coords = vector3(pos.x or 0.0, pos.y or 0.0, pos.z or 0.0)
        local modelName = jam.PropModel or 'ch_prop_ch_mobile_jammer_01x'
        local model = GetHashKey(modelName)

        if #(coords - myPos) > 100.0 then
            removeJammerObject(jam.Id)
            return
        end

        local handle = jammerObjects[jam.Id]
        if not handle or not DoesEntityExist(handle) then
            while not HasModelLoaded(model) do
                RequestModel(model)
                Citizen.Wait(0)
            end
            handle = CreateObject(model, coords.x, coords.y, coords.z, false, true, false)
            SetEntityCollision(handle, false, false)
            SetModelAsNoLongerNeeded(model)
            jammerObjects[jam.Id] = handle
        end

        if DoesEntityExist(handle) then
            SetEntityCoords(handle, coords.x, coords.y, coords.z, false, false, false, true)
            SetEntityHeading(handle, pos.heading or 0.0)
            if pos.exact ~= true then
                PlaceObjectOnGroundOrObjectProperly(handle)
            end
        end
    end

    local function removeHandheldProp(id)
        local handle = handheldObjects[id]
        if handle and DoesEntityExist(handle) then
            DeleteObject(handle)
        end
        handheldObjects[id] = nil
    end

    local function ensureHandheldProp(entry, ped)
        if not ped or ped == 0 then return end
        local modelName = entry.model or entry.offModel or 'm24_2_prop_m42_jammer_01a'
        local model = GetHashKey(modelName)

        local handle = handheldObjects[entry.id]
        if not handle or not DoesEntityExist(handle) then
            while not HasModelLoaded(model) do
                RequestModel(model)
                Citizen.Wait(0)
            end
            handle = CreateObject(model, 0.0, 0.0, 0.0, false, false, false)
            SetEntityCollision(handle, false, false)
            SetEntityAsMissionEntity(handle, true, true)
            SetModelAsNoLongerNeeded(model)
            handheldObjects[entry.id] = handle
        end

        if DoesEntityExist(handle) then
            AttachEntityToEntity(handle, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 2, true)
        end
    end

    Citizen.CreateThread(function()
        while true do
            local myPos = GetEntityCoords(PlayerPedId())
            local keep = {}
            for _, jam in ipairs(StaticJammers) do
                keep[jam.Id] = true
                ensureJammerObject(jam, myPos)
            end
            for id in pairs(jammerObjects) do
                if not keep[id] then
                    removeJammerObject(id)
                end
            end
            Citizen.Wait(500)
        end
    end)

    Citizen.CreateThread(function()
        while true do
            local localId = getLocalServerId()
            for id, entry in pairs(handheldEntries) do
                local ped
                if entry.ownerServerId == localId then
                    ped = PlayerPedId()
                else
                    local player = GetPlayerFromServerId(entry.ownerServerId)
                    if player ~= -1 then
                        ped = GetPlayerPed(player)
                    end
                end
                if ped and DoesEntityExist(ped) then
                    ensureHandheldProp(entry, ped)
                    local coords = GetEntityCoords(ped)
                    if not jammers[id] then jammers[id] = {} end
                    jammers[id].coords = coords
                    jammers[id].range = entry.range
                    jammers[id].strength = entry.strength
                    jammers[id].active = entry.active ~= false
                    jammers[id].type = 'handheld'
                    jammers[id].ownerSrc = entry.ownerServerId
                end
            end
            Citizen.Wait(500)
        end
    end)

    local function jammerLabels()
        local labels = {}
        for _, jam in ipairs(StaticJammers) do
            local label = jam.Note or jam.Name or jam.Id
            if label and #label > 18 then
                label = string.sub(label, 1, 15) .. '...'
            end
            labels[#labels + 1] = label or 'Unknown'
        end
        if #labels == 0 then
            labels[1] = 'No Jammers'
        end
        return labels
    end

    local function findStaticJammerById(id)
        for index, jam in ipairs(StaticJammers) do
            if jam.Id == id then
                return jam, index
            end
        end
        return nil, nil
    end

    local function ensureSelectionState()
        local jam = StaticJammers[jammerMenuState.index]
        if not jam then return nil end
        if jammerMenuState.jammerId ~= jam.Id then
            jammerMenuState.jammerId = jam.Id
            jammerMenuState.ogCoords = clonePosition(jam.PropPosition)
            jammerMenuState.ogHeading = jam.PropPosition.heading or 0.0
            jammerMenuState.moveSpeed = 0.05
        end
        return jam
    end

    local function moveSelectionPreview(jam)
        local handle = jammerObjects[jam.Id]
        if handle and DoesEntityExist(handle) then
            SetEntityCoords(handle, jam.PropPosition.x, jam.PropPosition.y, jam.PropPosition.z, true, true, true, false)
            SetEntityHeading(handle, jam.PropPosition.heading or 0.0)
            if jam.PropPosition.exact ~= true then
                PlaceObjectOnGroundOrObjectProperly(handle)
            end
        end
        if not jammers[jam.Id] then
            jammers[jam.Id] = {}
        end
        jammers[jam.Id].coords = vector3(jam.PropPosition.x, jam.PropPosition.y, jam.PropPosition.z)
        jammers[jam.Id].range = jam.Range or 0.0
        jammers[jam.Id].strength = jam.Strength or 0.0
        jammers[jam.Id].active = jam.Active ~= false
        jammers[jam.Id].type = 'static'
    end

    local function buildStaticOptions()
        local options, valid = {}, {}
        for _, jammer in ipairs(Config.radioJammers.jammers or {}) do
            if jammer.type ~= 'handheld' then
                local allowed = true
                if Config.enforceRadioItem then
                    allowed = playerHasJammerItem(jammer.itemName)
                end
                if allowed then
                    table.insert(options, jammer.name or 'Unknown Jammer')
                    table.insert(valid, jammer)
                end
            end
        end
        return options, valid
    end

    local function buildHandheldOptions()
        local options, valid = {}, {}
        for _, jammer in ipairs(Config.radioJammers.jammers or {}) do
            if jammer.type == 'handheld' then
                local allowed = true
                if Config.enforceRadioItem then
                    allowed = playerHasJammerItem({jammer.itemName, jammer.poweredItemName})
                end
                if allowed then
                    table.insert(options, jammer.name or 'Unknown Jammer')
                    table.insert(valid, jammer)
                end
            end
        end
        return options, valid
    end

    local function spawnJammerMenu()
        local options, valid = buildStaticOptions()
        if #options == 0 then
            WarMenu.Button('No jammers available to spawn', '')
            return
        end

        WarMenu.ComboBox('Select Jammer:', options, jammerMenuState.index, jammerMenuState.index, function(current)
            jammerMenuState.index = current
        end)

        local truncNote = jammerMenuState.note or ''
        if #truncNote > 23 then
            truncNote = string.sub(truncNote, 1, 20) .. '...'
        end
        if WarMenu.Button('Label/Note:', truncNote) then
            AddTextEntry('SRM_JAM_NOTE', 'Static Jammer Label/Note:')
            DisplayOnscreenKeyboard(1, 'SRM_JAM_NOTE', '', jammerMenuState.note or '', '', '', '', 50)
            while UpdateOnscreenKeyboard() == 0 do
                DisableAllControlActions(0)
                Citizen.Wait(0)
            end
            if UpdateOnscreenKeyboard() == 1 then
                jammerMenuState.note = GetOnscreenKeyboardResult() or ''
            else
                showNotification('~r~Error: ~w~Label prompt was cancelled')
            end
        end

        if WarMenu.Button('Confirm') then
            local selection = valid[jammerMenuState.index]
            if selection then
                local coords = GetEntityCoords(PlayerPedId())
                coords = vector3(coords.x, coords.y, coords.z - 1.0)
                local heading = GetEntityHeading(PlayerPedId())
                TriggerServerEvent('SonoranRadio::Request::SpawnJammer', selection, {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z
                }, heading, {
                    note = jammerMenuState.note ~= '' and jammerMenuState.note or nil
                })
                jammerMenuState.index = 1
                jammerMenuState.note = ''
                WarMenu.OpenMenu('jammerMenu')
            end
        end
    end

    local function moveJammerMenu()
        if #StaticJammers == 0 then
            WarMenu.Button('No static jammers configured', '')
            return
        end

        WarMenu.ComboBox('Select Jammer:', jammerLabels(), jammerMenuState.index, jammerMenuState.index, function(current)
            jammerMenuState.index = current
            jammerMenuState.jammerId = nil
        end)

        local jam = ensureSelectionState()
        if not jam then return end
        local propPosition = jam.PropPosition

        if WarMenu.CheckBox('Exact Placement?', propPosition.exact == true) then
            propPosition.exact = not propPosition.exact
            moveSelectionPreview(jam)
        end

        if WarMenu.Button('Confirm Placement') then
            TriggerServerEvent('SonoranRadio::Request::MoveJammer', jam.Id, propPosition)
            jammerMenuState.jammerId = nil
            jammerMenuState.ogCoords = nil
            jammerMenuState.ogHeading = nil
            WarMenu.OpenMenu('jammerMenu')
            return
        end

        if WarMenu.Button('Cancel Move') then
            if jammerMenuState.ogCoords then
                jam.PropPosition = clonePosition(jammerMenuState.ogCoords)
                jam.PropPosition.heading = jammerMenuState.ogHeading
                moveSelectionPreview(jam)
            end
            jammerMenuState.jammerId = nil
            jammerMenuState.ogCoords = nil
            jammerMenuState.ogHeading = nil
            WarMenu.OpenMenu('jammerMenu')
            return
        end

        if IsControlJustReleased(0, 21) and GetLastInputMethod(0) then
            if jammerMenuState.moveSpeed < 0.1 then
                jammerMenuState.moveSpeed = jammerMenuState.moveSpeed * 2.0
                showNotification(('Move speed %.4f'):format(jammerMenuState.moveSpeed))
            else
                showNotification('Cannot move faster')
            end
        elseif IsControlJustReleased(0, 132) and GetLastInputMethod(0) then
            if jammerMenuState.moveSpeed > 0.0005 then
                jammerMenuState.moveSpeed = jammerMenuState.moveSpeed / 2.0
                showNotification(('Move speed %.4f'):format(jammerMenuState.moveSpeed))
            else
                showNotification('Cannot move slower')
            end
        elseif IsControlPressed(0, 108) and GetLastInputMethod(0) then
            propPosition.x = propPosition.x + jammerMenuState.moveSpeed
        elseif IsControlPressed(0, 107) and GetLastInputMethod(0) then
            propPosition.x = propPosition.x - jammerMenuState.moveSpeed
        elseif IsControlPressed(0, 112) and GetLastInputMethod(0) then
            propPosition.y = propPosition.y + jammerMenuState.moveSpeed
        elseif IsControlPressed(0, 111) and GetLastInputMethod(0) then
            propPosition.y = propPosition.y - jammerMenuState.moveSpeed
        elseif IsControlPressed(0, 314) and GetLastInputMethod(0) then
            propPosition.z = propPosition.z + jammerMenuState.moveSpeed
        elseif IsControlPressed(0, 315) and GetLastInputMethod(0) then
            propPosition.z = propPosition.z - jammerMenuState.moveSpeed
        elseif IsControlPressed(0, 118) and GetLastInputMethod(0) then
            propPosition.heading = (propPosition.heading or 0.0) + 0.5
        elseif IsControlPressed(0, 117) and GetLastInputMethod(0) then
            propPosition.heading = (propPosition.heading or 0.0) - 0.5
        end

        moveSelectionPreview(jam)

        DrawMarker(2, propPosition.x, propPosition.y, propPosition.z + 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, propPosition.heading or 0.0, 0.5, 0.5, 0.5, 255, 0, 0, 200, false, false, 2, false, nil, nil, false)

        ensureScaleform()
        if jammerScaleform then
            BeginScaleformMovieMethod(jammerScaleform, 'CLEAR_ALL')
            EndScaleformMovieMethod()

            BeginScaleformMovieMethod(jammerScaleform, 'SET_DATA_SLOT')
            ScaleformMovieMethodAddParamInt(0)
            PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 108))
            PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 107))
            PushScaleformMovieMethodParameterString('Move X')
            EndScaleformMovieMethod()

            BeginScaleformMovieMethod(jammerScaleform, 'SET_DATA_SLOT')
            ScaleformMovieMethodAddParamInt(1)
            PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 112))
            PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 111))
            PushScaleformMovieMethodParameterString('Move Y')
            EndScaleformMovieMethod()

            BeginScaleformMovieMethod(jammerScaleform, 'SET_DATA_SLOT')
            ScaleformMovieMethodAddParamInt(2)
            PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 314))
            PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 315))
            PushScaleformMovieMethodParameterString('Move Z')
            EndScaleformMovieMethod()

            BeginScaleformMovieMethod(jammerScaleform, 'SET_DATA_SLOT')
            ScaleformMovieMethodAddParamInt(3)
            PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 118))
            PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 117))
            PushScaleformMovieMethodParameterString('Rotate')
            EndScaleformMovieMethod()

            BeginScaleformMovieMethod(jammerScaleform, 'SET_DATA_SLOT')
            ScaleformMovieMethodAddParamInt(4)
            PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 21))
            PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 132))
            PushScaleformMovieMethodParameterString('Change Speed')
            EndScaleformMovieMethod()

            BeginScaleformMovieMethod(jammerScaleform, 'DRAW_INSTRUCTIONAL_BUTTONS')
            ScaleformMovieMethodAddParamInt(0)
            EndScaleformMovieMethod()
            DrawScaleformMovieFullscreen(jammerScaleform, 255, 255, 255, 255, 0)
        end
    end

    local function deleteJammerMenu()
        if #StaticJammers == 0 then
            WarMenu.Button('No static jammers configured', '')
            return
        end

        WarMenu.ComboBox('Select Jammer:', jammerLabels(), jammerMenuState.index, jammerMenuState.index, function(current)
            jammerMenuState.index = current
        end)

        local jam = StaticJammers[jammerMenuState.index]
        if not jam then return end

        DrawMarker(2, jam.PropPosition.x, jam.PropPosition.y, jam.PropPosition.z + 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, jam.PropPosition.heading or 0.0, 0.5, 0.5, 0.5, 255, 0, 0, 200, false, false, 2, false, nil, nil, false)

        if WarMenu.Button('Delete Jammer') then
            TriggerServerEvent('SonoranRadio::Request::DeleteJammer', jam.Id)
            if jammerMenuState.index > 1 then
                jammerMenuState.index = jammerMenuState.index - 1
            end
            WarMenu.OpenMenu('jammerMenu')
        end
    end

    local function handheldJammerMenu()
        if localHandheldState.active and localHandheldState.config then
            WarMenu.Button('Active Jammer:', localHandheldState.config.name or 'Unknown')
            if WarMenu.Button(handheldMenuState.pending and 'Powering Off...' or 'Power Off') then
                if not handheldMenuState.pending and localHandheldState.id then
                    handheldMenuState.pending = true
                    TriggerServerEvent('SonoranRadio::Jammers::DeactivateHandheld', localHandheldState.id)
                end
            end
            return
        end

        local options, valid = buildHandheldOptions()
        if #options == 0 then
            WarMenu.Button('No handheld jammers available', '')
            return
        end

        WarMenu.ComboBox('Select Jammer:', options, handheldMenuState.index, handheldMenuState.index, function(current)
            handheldMenuState.index = current
        end)

        if WarMenu.Button(handheldMenuState.pending and 'Powering On...' or 'Power On') then
            if not handheldMenuState.pending then
                local selection = valid[handheldMenuState.index]
                if selection then
                    handheldMenuState.pending = true
                    TriggerServerEvent('SonoranRadio::Jammers::ActivateHandheld', selection.name)
                end
            end
        end
    end

    local function refreshHandheldState(handheldList)
        handheldEntries = {}
        local keep = {}
        if type(handheldList) == 'table' then
            for id, data in pairs(handheldList) do
                local owner = tonumber(data.owner) or data.owner
                handheldEntries[id] = {
                    id = id,
                    name = data.name,
                    ownerServerId = owner,
                    range = data.range or 0.0,
                    strength = data.strength or 0.0,
                    model = data.model,
                    offModel = data.offModel,
                    active = data.active ~= false
                }
                keep[id] = true
                if not jammers[id] then jammers[id] = {} end
                jammers[id].range = handheldEntries[id].range
                jammers[id].strength = handheldEntries[id].strength
                jammers[id].active = handheldEntries[id].active
                jammers[id].type = 'handheld'
                jammers[id].ownerSrc = owner
            end
        end
        for id in pairs(handheldObjects) do
            if not keep[id] then
                removeHandheldProp(id)
                jammers[id] = nil
            end
        end
        if localHandheldState.id and not keep[localHandheldState.id] then
            localHandheldState.active = false
            localHandheldState.id = nil
            localHandheldState.config = nil
        end
        if not localHandheldState.active then
            handheldMenuState.pending = false
        end
    end

    local function refreshSignalState(staticState, staticList, handheldList)
        jammers = {}
        StaticJammers = {}
        local keepStatic = {}
        if type(staticList) == 'table' then
            for i = 1, #staticList do
                local jam = staticList[i]
                local position = jam.PropPosition or {}
                StaticJammers[i] = {
                    Id = jam.Id,
                    Name = jam.Name,
                    Note = jam.Note,
                    PropModel = jam.PropModel,
                    Range = jam.Range,
                    Strength = jam.Strength,
                    Active = jam.Active ~= false,
                    PropPosition = {
                        x = position.x or 0.0,
                        y = position.y or 0.0,
                        z = position.z or 0.0,
                        heading = position.heading or 0.0,
                        exact = position.exact == true
                    }
                }
                if jam.Id then
                    keepStatic[jam.Id] = true
                end
            end
        end
        for id in pairs(jammerObjects) do
            if not keepStatic[id] then
                removeJammerObject(id)
            end
        end
        for id, data in pairs(staticState or {}) do
            jammers[id] = {
                id = id,
                coords = vector3(data.coords.x or 0.0, data.coords.y or 0.0, data.coords.z or 0.0),
                range = data.range or 0.0,
                strength = data.strength or 0.0,
                active = data.active ~= false,
                type = data.type or 'static'
            }
        end
        refreshHandheldState(handheldList)
        if jammerMenuState.index > #StaticJammers then
            jammerMenuState.index = #StaticJammers > 0 and #StaticJammers or 1
        end
    end

    RegisterNetEvent('SonoranRadio::Jammers::Sync', function(staticState, staticList, handheldList)
        refreshSignalState(staticState, staticList, handheldList)
    end)

    RegisterNetEvent('SonoranRadio::OpenJammerMenu', function()
        WarMenu.OpenMenu('jammerMenu')
    end)

    RegisterNetEvent('SonoranRadio::Jammers::HandheldActivated', function(data)
        if not data or not data.id then return end
        handheldMenuState.pending = false
        local owner = tonumber(data.owner) or data.owner
        handheldEntries[data.id] = {
            id = data.id,
            name = data.name,
            ownerServerId = owner,
            range = data.range or 0.0,
            strength = data.strength or 0.0,
            model = data.model,
            offModel = data.offModel,
            active = true
        }
        if not jammers[data.id] then jammers[data.id] = {} end
        jammers[data.id].range = handheldEntries[data.id].range
        jammers[data.id].strength = handheldEntries[data.id].strength
        jammers[data.id].active = true
        jammers[data.id].type = 'handheld'
        jammers[data.id].ownerSrc = owner

        local localId = getLocalServerId()
        if owner == localId then
            localHandheldState.active = true
            localHandheldState.id = data.id
            localHandheldState.config = configByName[data.name]
        end

        local ped
        if owner == localId then
            ped = PlayerPedId()
        else
            local player = GetPlayerFromServerId(owner)
            if player ~= -1 then
                ped = GetPlayerPed(player)
            end
        end
        if ped and DoesEntityExist(ped) then
            ensureHandheldProp(handheldEntries[data.id], ped)
            jammers[data.id].coords = GetEntityCoords(ped)
        end
    end)

    RegisterNetEvent('SonoranRadio::Jammers::HandheldDeactivated', function(data)
        local id
        if type(data) == 'table' then
            id = data.id
        else
            id = data
        end
        if not id then return end
        handheldEntries[id] = nil
        removeHandheldProp(id)
        jammers[id] = nil

        if localHandheldState.id == id then
            localHandheldState.active = false
            localHandheldState.id = nil
            localHandheldState.config = nil
        end

        local owner = type(data) == 'table' and tonumber(data.owner) or nil
        if owner and owner == getLocalServerId() then
            handheldMenuState.pending = false
        end
    end)

    RegisterNetEvent('SonoranRadio::Jammers::HandheldActivationFailed', function(reason)
        handheldMenuState.pending = false
        local messages = {
            invalid_config = 'Invalid handheld jammer selection.',
            missing_permission = 'You do not have permission to use that jammer.',
            already_active = 'A handheld jammer is already active.',
            missing_item = 'You do not have the required jammer item.',
            not_active = 'No handheld jammer is currently active.'
        }
        local msg = messages[reason] or 'Failed to toggle handheld jammer.'
        showNotification(('~r~Error: ~w~%s'):format(msg))
    end)

    RegisterNetEvent('SonoranRadio::Jammers::UseHandheldItem', function(payload)
        if type(payload) ~= 'table' or type(payload.configName) ~= 'string' then return end
        local config = configByName[payload.configName]
        if not config then return end

        if localHandheldState.active then
            if localHandheldState.config and localHandheldState.config.name == config.name then
                if not handheldMenuState.pending and localHandheldState.id then
                    handheldMenuState.pending = true
                    TriggerServerEvent('SonoranRadio::Jammers::DeactivateHandheld', localHandheldState.id)
                end
            else
                showNotification('~r~Error: ~w~Another handheld jammer is already active.')
            end
            return
        end

        if Config.enforceRadioItem and not playerHasJammerItem({config.itemName, config.poweredItemName}) then
            showNotification('~r~Error: ~w~You do not have the required jammer item.')
            return
        end

        if not handheldMenuState.pending then
            handheldMenuState.pending = true
            TriggerServerEvent('SonoranRadio::Jammers::ActivateHandheld', config.name)
        end
    end)

    RegisterNetEvent('menu:back', function(menu)
        if menu.id == 'jammerMoveMenu' and jammerMenuState.jammerId and jammerMenuState.ogCoords then
            local jam = findStaticJammerById(jammerMenuState.jammerId)
            if jam then
                jam.PropPosition = clonePosition(jammerMenuState.ogCoords)
                jam.PropPosition.heading = jammerMenuState.ogHeading
                moveSelectionPreview(jam)
            end
            jammerMenuState.jammerId = nil
            jammerMenuState.ogCoords = nil
            jammerMenuState.ogHeading = nil
        end
    end)

    AddEventHandler('onResourceStop', function(res)
        if res ~= GetCurrentResourceName() then return end
        for id in pairs(jammerObjects) do
            removeJammerObject(id)
        end
        for id in pairs(handheldObjects) do
            removeHandheldProp(id)
        end
    end)

    Citizen.CreateThread(function()
        WarMenu.CreateMenu('sonoranRadioMenuJammers', ' SonoranRadio Jammers')
        WarMenu.SetTitleColor('sonoranRadioMenuJammers', 0, 0, 0, 255)
        WarMenu.SetMenuTitleBackgroundSprite('sonoranRadioMenuJammers', 'radio_menu_header', 'option_1')
        WarMenu.SetSubTitle('sonoranRadioMenuJammers', 'Sonoran Software')

        local function defineJammerMenu(id, parent, title)
            WarMenu.CreateSubMenu(id, parent, title)
            WarMenu.SetMenuTitleBackgroundSprite(id, 'radio_menu_header', 'option_1')
        end

        defineJammerMenu('jammerMenu', 'sonoranRadioMenuJammers', 'Signal Jammers')
        defineJammerMenu('jammerSpawnMenu', 'jammerMenu', 'Spawn Jammer')
        defineJammerMenu('jammerMoveMenu', 'jammerMenu', 'Move Jammer')
        defineJammerMenu('jammerDeleteMenu', 'jammerMenu', 'Delete Jammer')
        defineJammerMenu('jammerHandheldMenu', 'jammerMenu', 'Handheld Jammer')

        while true do
            if WarMenu.IsMenuOpened('sonoranRadioMenuJammers') then
                WarMenu.MenuButton('Spawn Jammer', 'jammerSpawnMenu')
                WarMenu.MenuButton('Move Jammer', 'jammerMoveMenu')
                WarMenu.MenuButton('Delete Jammer', 'jammerDeleteMenu')
                WarMenu.MenuButton('Handheld Jammer', 'jammerHandheldMenu')
                WarMenu.Display()
            end
            if WarMenu.IsMenuOpened('jammerSpawnMenu') then
                spawnJammerMenu()
                WarMenu.Display()
            elseif WarMenu.IsMenuOpened('jammerMoveMenu') then
                moveJammerMenu()
                WarMenu.Display()
            elseif WarMenu.IsMenuOpened('jammerDeleteMenu') then
                deleteJammerMenu()
                WarMenu.Display()
            elseif WarMenu.IsMenuOpened('jammerHandheldMenu') then
                handheldJammerMenu()
                WarMenu.Display()
            end
            Citizen.Wait(0)
        end
    end)

    TriggerServerEvent('SonoranRadio::Jammers::RequestSync')
end

