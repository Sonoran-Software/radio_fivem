function initThreads()
    local spawnedTalkingLoop = false
    function shouldTalkInGame()
        return (isTalking and Config.talkSync) or isEmergCallActive
    end
    function spawnTalkingLoop()
        Citizen.CreateThread(function()
            while shouldTalkInGame() do
                SetControlNormal(0, 249, 1.0);
                Wait(0)
            end
            spawnedTalkingLoop = false
        end)
    end
    -- 0 MS Thread
    Citizen.CreateThread(function()
        while true do
            if shouldTalkInGame() and not spawnedTalkingLoop then
                spawnedTalkingLoop = true
                spawnTalkingLoop()
            end
            if nuiFocused then -- Disable controls while NUI is focused.
                DisableControlAction(0, 1, nuiFocused) -- LookLeftRight
                DisableControlAction(0, 2, nuiFocused) -- LookUpDown
                DisableControlAction(0, 142, nuiFocused) -- MeleeAttackAlternate
                DisableControlAction(0, 106, nuiFocused) -- VehicleMouseControlOverride
            end
            if Radio.Open then
                DisableControlAction(0, 142, true) -- Attack
                DisableControlAction(0, 200, true) -- Escape
            end
            Wait(0)
            local coords = GetEntityCoords(GetPlayerPed(-1))
            local closestRack = GetClosestVehicle(coords.x, coords.y, coords.z,
                                                  2.0, GetHashKey('serverrack'),
                                                  70)
            if closestRack ~= 0 then
                if GetVehicleBodyHealth(closestRack) < 950 or
                    IsVehicleDoorDamaged(closestRack, 1) or
                    GetVehicleEngineHealth(closestRack) < 950 then
                    goto continueRacks
                end
                local doorOpen = false;
                if IsVehicleDoorFullyOpen(closestRack, 1) then
                    doorOpen = true
                end
                BeginTextCommandDisplayHelp('STRING')
                if doorOpen then
                    AddTextComponentSubstringPlayerName(
                        'Press ~INPUT_WEAPON_SPECIAL_TWO~ to close this rack.')
                else
                    AddTextComponentSubstringPlayerName(
                        'Press ~INPUT_WEAPON_SPECIAL_TWO~ to open this rack.')
                end
                EndTextCommandDisplayHelp(0, false, true, -1)
                DisableControlAction(0, 54, true)
                if IsDisabledControlJustReleased(0, 54) then
                    local Vehicle = closestRack
                    if doorOpen then
                        SetVehicleDoorShut(Vehicle, 1, false)
                    else
                        SetVehicleDoorOpen(Vehicle, 1, false, false)
                    end
                end
            end
            ::continueRacks::
        end
    end)

    -- 500 MS Thread
    Citizen.CreateThread(function()
        local ped = PlayerPedId()
        local playerPos = GetEntityCoords(ped)
        local destroyedMusicList = {}
        while true do
            CheckForCloseMusic()
            local playerPos = GetEntityCoords(GetPlayerPed(-1));
            local playerHeading = GetEntityHeading(GetPlayerPed(-1));
            for k, v in pairs(playingSpeakers) do
                local foundSpeaker = nil
                for i = 1, #speakers do
                    if speakers[i].Id == k then
                        foundSpeaker = speakers[i]
                        break
                    end
                end
                if foundSpeaker then
                    local propPos = GetSpeakerCoords(foundSpeaker);
                    SendNUIMessage({
                        name = foundSpeaker.Id,
                        status = "updateSound",
                        playerX = playerPos.x,
                        playerY = playerPos.y,
                        playerZ = playerPos.z,
                        playerHeading = playerHeading,
                        speakerX = foundSpeaker.PropPosition.x,
                        speakerY = foundSpeaker.PropPosition.y,
                        speakerZ = foundSpeaker.PropPosition.z,
                        maxDistance = foundSpeaker.Range,
                        xsound = true,
                        distance = #(playerPos - propPos)
                    })
                end
            end
            if Config.enforceRadioItem then
                if Config.RadioItem == nil then
                    Config.RadioItem = {
                        name = 'sonoran_radio',
                        label = 'Sonoran Radio',
                        weight = 1,
                        description = 'Communicate with others through the Sonoran Radio'
                    }
                end
                Radio.HasItem = playerHasRadioItem()
                if not Radio.HasItem then
                    SendNUIMessage({ type = 'noRadioItem' })
                end
            end
            ped = PlayerPedId()
            playerPos = GetEntityCoords(ped)
            for k, v in pairs(soundInfo) do
                if v.position ~= nil and v.isDynamic then
                    if #(v.position - playerPos) < (v.distance + 10) then
                        if destroyedMusicList[v.id] then
                            destroyedMusicList[v.id] = nil
                            v.wasSilented = true
                            PlayMusicFromCache(v)
                        end
                    else
                        if not destroyedMusicList[v.id] then
                            destroyedMusicList[v.id] = true
                            v.wasSilented = false
                            DestroySilent(v.id)
                        end
                    end
                end
            end
            if IsVehicleSirenOn(GetVehiclePedIsIn(GetPlayerPed(-1), false)) then
            else
            end
            Citizen.Wait(500)
        end
    end)

    -- 5000 MS Thread
    CreateThread(function()
        while true do
            Wait(5000)
            TriggerServerEvent('SonoranCAD::sonrad:GetUnitInfo')
            TriggerServerEvent('SonoranCAD::sonrad:GetCurrentCall')
        end
    end)

    -- 100 MS Thread
    CreateThread(function()
        while true do
            local veh = GetVehiclePedIsIn(GetPlayerPed(), false)
            local prevState = inVehicle
            -- DebugPrint("Getting Players Vehicle")
            if not IsPedInAnyVehicle(PlayerPedId(), false) then
                -- player is in vehicle
                inVehicle = false
            else
                inVehicle = true
            end
            -- DebugPrint("Updating Radio State")
            SendNUIMessage({type = 'inVehicle', vehState = inVehicle})
            for i = 1, #Towers do
                local tower = Towers[i]
                if tower then
                    local n = tower.Dishes and #tower.Dishes or 0
                    for j = 1, n do
                        local e = tower.Dishes[j]
                        if DecorGetInt(e, 'sonrad_dish') ~= 1 then
                            goto continueTowers
                        end
                        if not IsEntityDead(e) then
                            -- make sure it doesn't explode from gunshots
                            SetVehiclePetrolTankHealth(e, 1000.0)
                        end

                        local health = GetVehicleBodyHealth(e)
                        if health > 500.0 then
                            goto continueTowers
                        end

                        -- here we kill the dish
                        DecorSetInt(e, 'sonrad_dish', 0)
                        DebugPrint('sending dish destroyed server event')
                        TriggerServerEvent('RadioTower:KillDish', tower.Id, j)
                        ::continueTowers::
                    end
                end
            end
            for i = 1, #racks do
                local rack = racks[i]
                if rack then
                    local n = rack.Servers and #rack.Servers or 0
                    for j = 1, n do
                        local e = rack.Servers[j]
                        if IsVehicleEngineOnFire(e) or IsEntityOnFire(e) then
                            StopFireInRange(GetEntityCoords(e), 3.0)
                            StopEntityFire(e)
                        end
                        if DecorGetInt(e, 'sonrad_server') ~= 1 then
                            goto continueRackss
                        end
                        if not IsEntityDead(e) then
                            SetVehiclePetrolTankHealth(e, 1000.0)
                        end
                        local health = GetEntityHealth(e)
                        if health > 980.0 then
                            goto continueRackss
                        end
                        -- here we kill the dish
                        DecorSetInt(e, 'sonrad_server', 0)
                        DebugPrint('sending dish destroyed server event')
                        TriggerServerEvent('RadioRacks:KillServer', rack.Id, j)
                        ::continueRackss::
                    end
                end
            end
            for i = 1, #CellRepeaters do
                local cellRepeater = CellRepeaters[i]
                if cellRepeater then
                    local e = cellRepeater.Handle
                    if DecorGetInt(e, 'sonrad_cellRepeater') ~= 1 then
                        goto continueCellRepeaters
                    end
                    if not IsEntityDead(e) then
                        -- make sure it doesn't explode from gunshots
                        SetVehiclePetrolTankHealth(e, 1000.0)
                    end

                    local health = GetVehicleBodyHealth(e)
                    if health > 500.0 then
                        goto continueCellRepeaters
                    end

                    -- here we kill the dish
                    DecorSetInt(e, 'sonrad_cellRepeater', 0)
                    DebugPrint('sending dish destroyed server event')
                    TriggerServerEvent('CellRepeater:KillAntenna',
                                       cellRepeater.Id)
                    ::continueCellRepeaters::
                end
            end
            Wait(100)
        end
    end)

    function getSignalQuality()
        return math.max(bestCellRepeaterQuality, bestRackQuality, bestTowerQuality)
    end
    exports('getSignalQuality', getSignalQuality)

    -- 1000 MS Thread
    CreateThread(function()
        local QBCore = nil
        if Config.deathDetectionMethod == 'qbcore' and frameworkEnum == 1 then
            QBCore = exports['qb-core']:GetCoreObject()
        end
        TriggerServerEvent('SonoranRadio:GetTunnels')

        local lastTowerQuality = 0.0
        while true do
            if QBCore ~= nil then
                local PlayerData = QBCore.Functions.GetPlayerData()
                if PlayerData ~= nil and PlayerData.metadata ~= nil then
                    -- print("Is Dead: " .. tostring(PlayerData.metadata["isdead"]))
                    -- print("Is Last Stand: " .. tostring(PlayerData.metadata["islaststand"]))
                    QBDeath = PlayerData.metadata['isdead'] or
                                  PlayerData.metadata['inlaststand']
                end
            end

            if Config.deathDetectionMethod == 'auto' or
                Config.deathDetectionMethod == 'qbcore' then
                local IsPlayerDead = IsEntityDead(PlayerPedId()) or QBDeath
                if IsPlayerDead then
                    TriggerEvent('SonoranRadio::PlayerDeath')
                else
                    TriggerEvent('SonoranRadio::PlayerRevive')
                end
            end
            -- Tunnel degradation logic
            local plyPed = PlayerPedId()
            local coord = GetEntityCoords(plyPed)
            local insideZone = false
            local degradeStrength = 0.0
            for _, zone in pairs(polyZonesTable) do
                if zone:isPointInside(coord) then
                    degradeStrength = zone.degradeStrength
                    insideZone = true
                    DebugPrint('Inside Zone: ' .. zone.name)
                    break
                end
            end
            local bestQuality = getSignalQuality()
            if insideZone then
                if bestQuality > 0 then
                    bestQuality = bestQuality * (1 - degradeStrength)
                end
            end

            -- update the tower quality if it has changed significantly
            local delta = bestQuality < 0.1 and 0.01 or 0.05 -- if tower quality <10%, update every 1% change, otherwise update every 5%
            if math.abs(bestQuality - lastTowerQuality) >= delta or
                (bestQuality <= 0.0 and lastTowerQuality > 0.0) then
                lastTowerQuality = bestQuality
                SendNUIMessage({type = 'setTowerQuality', quality = bestQuality})
            end

            for k, v in pairs(soundInfo) do
                if v.playing or v.wasSilented then
                    if getInfo(v.id).timeStamp ~= nil and
                        getInfo(v.id).maxDuration ~= nil then
                        if getInfo(v.id).timeStamp < getInfo(v.id).maxDuration then
                            getInfo(v.id).timeStamp =
                                getInfo(v.id).timeStamp + 1
                        end
                    end
                end
            end
            Wait(1000)
        end
    end)

    -- 3000 MS Thread
    CreateThread(function()
        while true do
            bestTowerQuality = 0.0
            local pCoords = GetEntityCoords(GetPlayerPed(-1))
            for i = 1, #Towers do
                local tower = Towers[i]
                if not tower then goto continue end
                local d = #(GetTowerCoords(tower) - pCoords)
                -- if the player is within range (750m), then spawn a physical tower
                local physical = not Config.noPhysicalTowers and
                                     not tower.NotPhysical
                if d < 750.0 and not tower.Spawned and physical then
                    CreateTower(tower)
                    DebugPrint(('spawn physical tower (%f) %s'):format(d,
                                                                       tower.Id))
                elseif d >= 750.0 and tower.Spawned then
                    DestroyTower(tower)
                    DebugPrint(('destroy physical tower (%f) %s'):format(d,
                                                                         tower.Id))
                end

                -- recreate the tower completely if anything is missing
                -- NOTE: not including the ladder, as it will be omitted on certain conditions
                local recreate = tower.Spawned and
                                     not DoesEntityExist(tower.Handle)
                local n = tower.Dishes and #tower.Dishes or 0
                for j = 1, n do
                    if not recreate then
                        recreate = not DoesEntityExist(tower.Dishes[j])
                    end
                end
                if recreate then
                    DebugPrint(
                        ('tower:%s component missing, recreating'):format(
                            tower.Id))
                    -- CreateTower will automatically delete old entities
                    CreateTower(tower)
                    SyncDishStatus(tower, false)
                end

                -- if tower is out of range, then just ignore it
                if d > tower.Range then goto continue end
                local tQuality = (1.0 - (d / tower.Range)) *
                                     GetTowerCapacity(tower)
                if bestTowerQuality < tQuality then
                    bestTowerQuality = tQuality
                end
                ::continue::
            end

            -- if bestTowerQuality == 0.0 then
            --     DebugPrint('closest tower out of range')
            -- else
            --     DebugPrint(('best tower quality:%.4f'):format(bestTowerQuality))
            -- end
            bestRackQuality = 0.0
            local pCoords = GetEntityCoords(GetPlayerPed(-1))
            for i = 1, #racks do
                local rack = racks[i]
                if not rack then goto continue end
                local d = #(GetRackCoords(rack) - pCoords)
                -- if the player is within range (750m), then spawn a physical rack
                local physical = not Config.noPhysicalRacks and
                                     not rack.NotPhysical
                if d < 750.0 and not rack.Spawned and physical then
                    CreateRack(rack)
                    DebugPrint(
                        ('spawn physical rack (%f) %s'):format(d, rack.Id))
                elseif d >= 750.0 and rack.Spawned then
                    DestroyRack(rack)
                    DebugPrint(('destroy physical rack (%f) %s'):format(d,
                                                                        rack.Id))
                end

                -- recreate the rack completely if anything is missing
                -- NOTE: not including the ladder, as it will be omitted on certain conditions
                local recreate = rack.Spawned and
                                     not DoesEntityExist(rack.Handle)
                local n = rack.Servers and #rack.Servers or 0
                for j = 1, n do
                    if not recreate then
                        recreate = not DoesEntityExist(rack.Servers[j])
                    end
                end
                if recreate then
                    DebugPrint(('rack:%s component missing, recreating'):format(
                                   rack.Id))
                    -- CreateRack will automatically delete old entities
                    CreateRack(rack)
                    SyncServerStatus(rack, false)
                end

                -- if rack is out of range, then just ignore it
                if d > rack.Range then goto continue end
                local tQuality = (1.0 - (d / rack.Range)) *
                                     GetrackCapacity(rack)
                if bestRackQuality < tQuality then
                    bestRackQuality = tQuality
                end
                ::continue::
            end

            -- if bestRackQuality == 0.0 then
            --     DebugPrint('closest rack out of range')
            -- else
            --     DebugPrint(('best rack quality:%.4f'):format(bestRackQuality))
            -- end
            bestCellRepeaterQuality = 0.0
            local pCoords = GetEntityCoords(GetPlayerPed(-1))
            for i = 1, #CellRepeaters do
                local cellRepeater = CellRepeaters[i]
                if not cellRepeater then goto continue end
                local d = #(GetCellRepeaterCoords(cellRepeater) - pCoords)
                -- if the player is within range (750m), then spawn a physical cellRepeater
                local physical = not Config.noPhysicalCellRepeaters and
                                     not cellRepeater.NotPhysical
                if d < 750.0 and not cellRepeater.Spawned and physical then
                    CreateCellRepeater(cellRepeater)
                    DebugPrint(('spawn physical cell repeater (%f) %s'):format(
                                   d, cellRepeater.Id))
                elseif d >= 750.0 and cellRepeater.Spawned then
                    DestroyCellRepeater(cellRepeater)
                    DebugPrint(
                        ('destroy physical cell repeater (%f) %s'):format(d,
                                                                          cellRepeater.Id))
                end

                -- recreate the cellRepeater completely if anything is missing
                -- NOTE: not including the ladder, as it will be omitted on certain conditions
                local recreate = cellRepeater.Spawned and
                                     not DoesEntityExist(cellRepeater.Handle)
                local n = cellRepeater.Dishes and #cellRepeater.Dishes or 0
                for j = 1, n do
                    if not recreate then
                        recreate = not DoesEntityExist(cellRepeater.Dishes[j])
                    end
                end
                if recreate then
                    DebugPrint(
                        ('cellRepeater:%s component missing, recreating'):format(
                            cellRepeater.Id))
                    -- CreateCellRepeater will automatically delete old entities
                    CreateCellRepeater(cellRepeater)
                end

                -- if cellRepeater is out of range, then just ignore it
                if d > cellRepeater.Range then goto continue end
                local tQuality = (1.0 - (d / cellRepeater.Range)) *
                                     GetCellRepeaterCapacity(cellRepeater)
                if bestCellRepeaterQuality < tQuality then
                    bestCellRepeaterQuality = tQuality
                end
                ::continue::
            end

            -- if bestCellRepeaterQuality == 0.0 then
            --     DebugPrint('closest cell repeater out of range')
            -- else
            --     DebugPrint(('best cell repeater quality:%.4f'):format(
            --                    bestCellRepeaterQuality))
            -- end
            -- Check if the players vehicle's radio repeater is active and if the player has control of the vehicle (not in a cutscene, etc.)
            if DecorGetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false),
                            'RepeaterActive') and
                NetworkHasControlOfEntity(
                    GetVehiclePedIsIn(GetPlayerPed(-1), false)) then
                -- Check if the vehicle is not damaged beyond repair. | 0 and below: Engine catches fire and health rapidly declines | 300: Engine is smoking and losing functionality | 1000: Engine is perfectly fine
                if GetVehicleEngineHealth(
                    GetVehiclePedIsIn(GetPlayerPed(-1, false))) < -1000 then
                    -- If the vehicle is damaged beyond repair, disable the repeater and notify the player
                    -- Set the decor bool to false
                    DecorSetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false),
                                 'RepeaterActive', false)
                    -- Trigger the server event to toggle the repeater. Parameters: vehicle network ID, repeater status, vehicle position, repeater range
                    TriggerServerEvent('sonoranscripts::togglerepeater',
                                       NetworkGetNetworkIdFromEntity(
                                           GetVehiclePedIsIn(GetPlayerPed(-1),
                                                             false)))
                    -- Show a notification to the player
                    notifyClient(
                        '~w~ Radio repeater ~o~disabled~w~ due to engine damage')
                    -- Remove the vehicle from the repeater table
                    RepeaterVehicles[GetVehiclePedIsIn(GetPlayerPed(-1), false)] =
                        nil
                end
                -- Update the repeater position every 100ms
                TriggerServerEvent('sonoranscripts::updatepos',
                                   NetworkGetNetworkIdFromEntity(
                                       GetVehiclePedIsIn(GetPlayerPed(-1), false)),
                                   GetEntityCoords(
                                       GetVehiclePedIsIn(GetPlayerPed(-1), false)),
                                   getVehicleConfig(
                                       GetVehiclePedIsIn(GetPlayerPed(-1), false)).range)
            end
            -- Loop through the repeater table and check if the vehicle still exists and if it is damaged beyond repair
            for k, _ in pairs(RepeaterVehicles) do
                if not DoesEntityExist(k) then
                    RepeaterVehicles[k] = nil
                end
                if GetVehicleEngineHealth(k) < -1000 then
                    DecorSetBool(k, 'RepeaterActive', false)
                    TriggerServerEvent('sonoranscripts::togglerepeater',
                                       NetworkGetNetworkIdFromEntity(k))
                    notifyClient(
                        '~w~ Radio repeater ~o~disabled~w~ due to engine damage')
                    RepeaterVehicles[k] = nil
                end
            end
            Wait(3000)
        end
    end)
end
