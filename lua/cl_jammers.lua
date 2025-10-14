
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
    local jammerObjectModels = {}
    local handheldObjects = {}
    local lastJammerDropKeys = {}
    local configByName = {}
    local jammerItemMap = {}

    for _, jammer in ipairs(Config.radioJammers.jammers or {}) do
        if jammer.name then
            configByName[jammer.name] = jammer
        end
        if jammer.itemName and jammer.itemName ~= '' then
            jammerItemMap[jammer.itemName] = jammer
        end
        if jammer.poweredItemName and jammer.poweredItemName ~= '' then
            jammerItemMap[jammer.poweredItemName] = jammer
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
    local handheldMenuState = {index = 1, pending = false, action = nil}
    local pendingHandheldMenuOpen = nil
    local localHandheldState = {active = false, id = nil, config = nil, powered = false}

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
        jammerObjectModels[id] = nil
    end

    local function ensureJammerObject(jam, myPos)
        myPos = myPos or GetEntityCoords(PlayerPedId())
        local pos = jam.PropPosition or {}
        local coords = vector3(pos.x or 0.0, pos.y or 0.0, pos.z or 0.0)
        local isActive = jam.Active ~= false
        local modelName = isActive and (jam.PropModel or 'ch_prop_ch_mobile_jammer_01x') or
                              (jam.OffModel or jam.PropModel or 'ch_prop_ch_mobile_jammer_01x')
        if jammerObjectModels[jam.Id] ~= modelName then
            removeJammerObject(jam.Id)
        end
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
            jammerObjectModels[jam.Id] = modelName
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

    if Config.enforceRadioItem and frameworkEnum == 1 and inventoryEnum == 1 then
        Citizen.CreateThread(function()
            while Config.radioJammers and Config.radioJammers.enabled ~= false do
                QBCore = QBCore or (exports['qb-core'] and exports['qb-core']:GetCoreObject()) or QBCore
                if QBCore and GetResourceState('qb-inventory') == 'started' then
                    QBCore.Functions.TriggerCallback('qb-inventory:server:GetCurrentDrops', function(drops)
                        if type(drops) ~= 'table' then drops = {} end
                        local seen = {}
                        for dropId, drop in pairs(drops) do
                            local dropKey = tostring(dropId)
                            seen[dropKey] = true
                            local jammerData = findJammerInDrop(drop)
                            if jammerData then
                                local coords = drop.coords or drop.position or drop.location
                                local dropVec = nil
                                if coords then
                                    if type(coords) == 'vector3' then
                                        dropVec = coords
                                    elseif type(coords) == 'table' and coords.x and coords.y and coords.z then
                                        dropVec = vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
                                    end
                                end
                                if dropVec then
                                    local playerCoords = GetEntityCoords(PlayerPedId())
                                    if #(playerCoords - dropVec) <= 7.0 then
                                        local signature = jammerData.config.name .. ':' .. (jammerData.isPowered and '1' or '0')
                                        if lastJammerDropKeys[dropKey] ~= signature then
                                            lastJammerDropKeys[dropKey] = signature
                                            TriggerServerEvent('SonoranRadio::Jammers::PlaceFromDroppedItem', dropId, jammerData.config.name, {
                                                x = dropVec.x,
                                                y = dropVec.y,
                                                z = dropVec.z
                                            }, jammerData.isPowered)
                                        end
                                    end
                                end
                            end
                        end
                        for dropKey in pairs(lastJammerDropKeys) do
                            if not seen[dropKey] then
                                lastJammerDropKeys[dropKey] = nil
                            end
                        end
                    end)
                end
                Citizen.Wait(1000)
            end
        end)
    end

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
                    local isActive = entry.active ~= false
                    jammers[id].coords = coords
                    jammers[id].range = entry.range
                    jammers[id].strength = entry.strength
                    jammers[id].active = isActive
                    jammers[id].type = 'handheld'
                    jammers[id].ownerSrc = entry.ownerServerId
                    if entry.ownerServerId == localId then
                        localHandheldState.powered = isActive
                    end
                end
            end
            Citizen.Wait(500)
        end
    end)
    Citizen.CreateThread(function()
        local lastToggle = 0
        while true do
            local ped = PlayerPedId()
            local myPos = GetEntityCoords(ped)
            local nearest, nearestDist
            for _, jam in ipairs(StaticJammers) do
                if jam and jam.PropPosition then
                    local coords = vector3(jam.PropPosition.x, jam.PropPosition.y, jam.PropPosition.z)
                    local dist = #(coords - myPos)
                    if not nearestDist or dist < nearestDist then
                        nearest = jam
                        nearestDist = dist
                    end
                end
            end

            local maxRange = (Config.radioJammers and Config.radioJammers.toggleRange) or 3.0
            if nearest and nearestDist and nearestDist <= maxRange then
                local message = nearest.Active ~= false and
                                    'Press ~INPUT_CONTEXT~ to power off this jammer' or
                                    'Press ~INPUT_CONTEXT~ to power on this jammer'
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(message)
                EndTextCommandDisplayHelp(0, false, true, 1000)

                if IsControlJustReleased(0, 38) and (GetGameTimer() - lastToggle) > 1000 then
                    lastToggle = GetGameTimer()
                    showNotification('Toggling jammer power, please wait...')
                    Wait(200)
                    local label = nearest.name
                    if not label and nearest then label = nearest.Name or nearest.Note end
                    label = label or 'Jammer'
                    local message = nearest.Active and (label .. ' powered on.') or (label .. ' powered off.')
                    TriggerServerEvent('SonoranRadio::Request::ToggleJammerPower', nearest.Id)
                    showNotification(message)
                end
                Citizen.Wait(0)
            else
                Citizen.Wait(500)
            end
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

    local function focusHandheldMenuSelection(targetName)
        local _, valid = buildHandheldOptions()
        if targetName then
            for idx, jammer in ipairs(valid) do
                if jammer.name == targetName then
                    handheldMenuState.index = idx
                    return
                end
            end
        end
        if #valid > 0 then
            handheldMenuState.index = math.min(handheldMenuState.index, #valid)
            if handheldMenuState.index < 1 then
                handheldMenuState.index = 1
            end
        end
    end

    local function findJammerInDrop(drop)
        if type(drop) ~= 'table' then return nil end
        local itemList = drop.items or drop.inventory or drop.contents
        if type(itemList) ~= 'table' then return nil end
        for _, item in pairs(itemList) do
            if type(item) == 'table' and item.name then
                local config = jammerItemMap[item.name]
                if config then
                    return {
                        config = config,
                        isPowered = config.poweredItemName and item.name == config.poweredItemName,
                        info = item.info,
                        amount = item.amount or item.count or item.quantity or 1
                    }
                end
            end
        end
        return nil
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
                WarMenu.OpenMenu('sonoranRadioMenuJammers')
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
            WarMenu.OpenMenu('sonoranRadioMenuJammers')
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
            WarMenu.OpenMenu('sonoranRadioMenuJammers')
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
            WarMenu.OpenMenu('sonoranRadioMenuJammers')
        end
    end

    local function handheldJammerMenu()
        if localHandheldState.active and localHandheldState.config then
            local label = localHandheldState.config.name or 'Unknown'
            WarMenu.Button('Active Jammer:', label)

            local powerCaption
            if handheldMenuState.pending and handheldMenuState.action == 'toggle' then
                powerCaption = 'Toggle Power...'
            else
                powerCaption = localHandheldState.powered and
                                   'Toggle Power (Currently On)' or
                                   'Toggle Power (Currently Off)'
            end

            if WarMenu.Button(powerCaption) then
                if not handheldMenuState.pending and localHandheldState.id then
                    handheldMenuState.pending = true
                    handheldMenuState.action = 'toggle'
                    TriggerServerEvent('SonoranRadio::Jammers::ToggleHandheldPower',
                                       localHandheldState.id)
                end
            end

            local stowLabel = (handheldMenuState.pending and handheldMenuState.action == 'stow') and
                                  'Stowing...' or 'Stow Jammer'
            if WarMenu.Button(stowLabel) then
                if not handheldMenuState.pending and localHandheldState.id then
                    handheldMenuState.pending = true
                    handheldMenuState.action = 'stow'
                    TriggerServerEvent('SonoranRadio::Jammers::DeactivateHandheld',
                                       localHandheldState.id)
                end
            end

            local placeLabel = (handheldMenuState.pending and handheldMenuState.action == 'place') and
                                   'Placing...' or 'Place On Ground'
            if WarMenu.Button(placeLabel) then
                if not handheldMenuState.pending and localHandheldState.id then
                    handheldMenuState.pending = true
                    handheldMenuState.action = 'place'
                    TriggerServerEvent('SonoranRadio::Jammers::PlaceHandheldOnGround',
                                       localHandheldState.id)
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

        local activateLabel = (handheldMenuState.pending and handheldMenuState.action == 'activate') and
                                  'Powering On...' or 'Power On'
        if WarMenu.Button(activateLabel) then
            if not handheldMenuState.pending then
                local selection = valid[handheldMenuState.index]
                if selection then
                    handheldMenuState.pending = true
                    handheldMenuState.action = 'activate'
                    TriggerServerEvent('SonoranRadio::Jammers::ActivateHandheld',
                                       selection.name)
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
                if owner == getLocalServerId() then
                    localHandheldState.active = true
                    localHandheldState.id = id
                    localHandheldState.config = configByName[data.name]
                    localHandheldState.powered = handheldEntries[id].active
                end
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
            localHandheldState.powered = false
        end
        if not localHandheldState.active then
            handheldMenuState.pending = false
            handheldMenuState.action = nil
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
                    OffModel = jam.OffModel,
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
        WarMenu.OpenMenu('sonoranRadioMenuJammers')
    end)

    RegisterNetEvent('SonoranRadio::Jammers::HandheldActivated', function(data)
        if not data or not data.id then return end
        handheldMenuState.pending = false
        handheldMenuState.action = nil
        local owner = tonumber(data.owner) or data.owner
        local isActive = data.active ~= false
        handheldEntries[data.id] = {
            id = data.id,
            name = data.name,
            ownerServerId = owner,
            range = data.range or 0.0,
            strength = data.strength or 0.0,
            model = data.model,
            offModel = data.offModel,
            active = isActive
        }
        if not jammers[data.id] then jammers[data.id] = {} end
        jammers[data.id].range = handheldEntries[data.id].range
        jammers[data.id].strength = handheldEntries[data.id].strength
        jammers[data.id].active = isActive
        jammers[data.id].type = 'handheld'
        jammers[data.id].ownerSrc = owner

        local localId = getLocalServerId()
        if owner == localId then
            localHandheldState.active = true
            localHandheldState.id = data.id
            localHandheldState.config = configByName[data.name]
            localHandheldState.powered = isActive
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
            localHandheldState.powered = false
        end

        local owner = type(data) == 'table' and tonumber(data.owner) or nil
        if owner and owner == getLocalServerId() then
            handheldMenuState.pending = false
            handheldMenuState.action = nil
        end
    end)

    RegisterNetEvent('SonoranRadio::Jammers::HandheldActivationFailed', function(reason)
        handheldMenuState.pending = false
        handheldMenuState.action = nil
        local messages = {
            invalid_config = 'Invalid handheld jammer selection.',
            missing_permission = 'You do not have permission to use that jammer.',
            already_active = 'A handheld jammer is already active.',
            missing_item = 'You do not have the required jammer item.',
            not_active = 'No handheld jammer is currently active.',
            no_ped = 'Unable to determine your position.'
        }
        local msg = messages[reason] or 'Failed to toggle handheld jammer.'
        showNotification(('~r~Error: ~w~%s'):format(msg))
    end)

    RegisterNetEvent('SonoranRadio::Jammers::HandheldPowerChanged', function(data)
        if type(data) ~= 'table' or not data.id then return end
        local isActive = data.active ~= false
        if handheldEntries[data.id] then
            handheldEntries[data.id].active = isActive
        end
        if jammers[data.id] then
            jammers[data.id].active = isActive
        end
        local owner = tonumber(data.owner) or data.owner
        if localHandheldState.id == data.id then
            localHandheldState.powered = isActive
        end
        if owner == getLocalServerId() then
            handheldMenuState.pending = false
            handheldMenuState.action = nil
            local label = data.name or (localHandheldState.config and localHandheldState.config.name) or 'Handheld Jammer'
            local message = isActive and (label .. ' powered on.') or (label .. ' powered off.')
            showNotification(message)
        end
    end)

    RegisterNetEvent('SonoranRadio::Jammers::ToggleResult', function(result)
        if type(result) ~= 'table' or result.success ~= false then return end
        local reasons = {
            no_permission = 'You do not have permission to toggle this jammer.',
            too_far = 'Move closer to the jammer to toggle it.',
            not_found = 'This jammer could not be found.',
            no_ped = 'Unable to determine your position.'
        }
        local msg = reasons[result.reason] or 'Failed to toggle jammer.'
        showNotification(('~r~Error: ~w~%s'):format(msg))
    end)

    RegisterNetEvent('SonoranRadio::Jammers::ToggleBroadcast', function(data)
        if type(data) ~= 'table' or not data.id then return end
        local active = data.active ~= false
        local jam
        for _, entry in ipairs(StaticJammers) do
            if entry.Id == data.id then
                jam = entry
                break
            end
        end
        if not jam and data.coords then
            jam = {
                Id = data.id,
                Name = data.name,
                Note = data.note,
                PropModel = data.propModel,
                OffModel = data.offModel,
                Range = data.range or 0.0,
                Strength = data.strength or 0.0,
                Active = active,
                PropPosition = {
                    x = data.coords.x or 0.0,
                    y = data.coords.y or 0.0,
                    z = data.coords.z or 0.0,
                    heading = data.coords.heading or 0.0,
                    exact = data.coords.exact == true
                }
            }
            table.insert(StaticJammers, jam)
        elseif jam then
            jam.Active = active
            if data.propModel then jam.PropModel = data.propModel end
            if data.offModel then jam.OffModel = data.offModel end
            if data.coords then
                jam.PropPosition.x = data.coords.x or jam.PropPosition.x
                jam.PropPosition.y = data.coords.y or jam.PropPosition.y
                jam.PropPosition.z = data.coords.z or jam.PropPosition.z
                jam.PropPosition.heading = data.coords.heading or jam.PropPosition.heading or 0.0
                jam.PropPosition.exact = data.coords.exact == true
            end
            if data.range ~= nil then jam.Range = data.range end
            if data.strength ~= nil then jam.Strength = data.strength end
        end

        jammers[data.id] = jammers[data.id] or {}
        if data.coords then
            jammers[data.id].coords =
                vector3(data.coords.x or 0.0, data.coords.y or 0.0, data.coords.z or 0.0)
        elseif jam and jam.PropPosition then
            jammers[data.id].coords =
                vector3(jam.PropPosition.x or 0.0, jam.PropPosition.y or 0.0, jam.PropPosition.z or 0.0)
        end
        if data.range ~= nil then
            jammers[data.id].range = data.range
        elseif jam then
            jammers[data.id].range = jam.Range or jammers[data.id].range
        end
        if data.strength ~= nil then
            jammers[data.id].strength = data.strength
        elseif jam then
            jammers[data.id].strength = jam.Strength or jammers[data.id].strength
        end
        jammers[data.id].active = active
        jammers[data.id].type = 'static'

        removeJammerObject(data.id)
        if jam then
            ensureJammerObject(jam, GetEntityCoords(PlayerPedId()))
        end

        -- local label = data.name
        -- if not label and jam then label = jam.Name or jam.Note end
        -- label = label or 'Jammer'
        -- local message = active and (label .. ' powered on.') or (label .. ' powered off.')
        -- showNotification(message)
    end)

    RegisterNetEvent('SonoranRadio::Jammers::SpawnBroadcast', function(data)
        if type(data) ~= 'table' or not data.Id then return end
        local pos = data.PropPosition or {}
        local entry = {
            Id = data.Id,
            Name = data.Name,
            Note = data.Note,
            PropModel = data.PropModel,
            OffModel = data.OffModel,
            Range = data.Range or 0.0,
            Strength = data.Strength or 0.0,
            Active = data.Active ~= false,
            PropPosition = {
                x = pos.x or 0.0,
                y = pos.y or 0.0,
                z = pos.z or 0.0,
                heading = pos.heading or 0.0,
                exact = pos.exact == true
            }
        }

        local existing = nil
        for _, jam in ipairs(StaticJammers) do
            if jam.Id == entry.Id then
                existing = jam
                break
            end
        end
        if existing then
            existing.Name = entry.Name
            existing.Note = entry.Note
            existing.PropModel = entry.PropModel
            existing.OffModel = entry.OffModel
            existing.Range = entry.Range
            existing.Strength = entry.Strength
            existing.Active = entry.Active
            existing.PropPosition = entry.PropPosition
        else
            table.insert(StaticJammers, entry)
            existing = entry
        end

        jammers[entry.Id] = jammers[entry.Id] or {}
        jammers[entry.Id].coords =
            vector3(entry.PropPosition.x, entry.PropPosition.y, entry.PropPosition.z)
        jammers[entry.Id].range = entry.Range
        jammers[entry.Id].strength = entry.Strength
        jammers[entry.Id].active = entry.Active
        jammers[entry.Id].type = 'static'

        removeJammerObject(entry.Id)
        local ownerId = tonumber(data.Owner) or data.Owner
        if ownerId == getLocalServerId() then
            local label = entry.Name or 'Jammer'
            showNotification(label .. ' placed on ground.')
        end
        ensureJammerObject(existing, GetEntityCoords(PlayerPedId()))
    end)
    RegisterNetEvent('SonoranRadio::Jammers::UseHandheldItem', function(payload)
        if type(payload) ~= 'table' or type(payload.configName) ~= 'string' then return end
        local config = configByName[payload.configName]
        if not config then return end

        if localHandheldState.active and localHandheldState.config and localHandheldState.config.name ~= config.name then
            showNotification('~r~Error: ~w~Another handheld jammer is already active.')
            return
        end

        if Config.enforceRadioItem and not playerHasJammerItem({config.itemName, config.poweredItemName}) then
            showNotification('~r~Error: ~w~You do not have the required jammer item.')
            return
        end

        handheldMenuState.pending = false
        handheldMenuState.action = nil
        focusHandheldMenuSelection(config.name)

        if localHandheldState.active and localHandheldState.config and localHandheldState.config.name == config.name then
            if type(payload.powered) == 'boolean' then
                localHandheldState.powered = payload.powered
            end
        end

        pendingHandheldMenuOpen = config.name
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

        defineJammerMenu('jammerSpawnMenu', 'sonoranRadioMenuJammers', 'Spawn Jammer')
        defineJammerMenu('jammerMoveMenu', 'sonoranRadioMenuJammers', 'Move Jammer')
        defineJammerMenu('jammerDeleteMenu', 'sonoranRadioMenuJammers', 'Delete Jammer')
        defineJammerMenu('jammerHandheldMenu', 'sonoranRadioMenuJammers', 'Handheld Jammer')

        while true do
            if pendingHandheldMenuOpen then
                WarMenu.OpenMenu('sonoranRadioMenuJammers')
                WarMenu.OpenMenu('jammerHandheldMenu')
                pendingHandheldMenuOpen = nil
            end
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

