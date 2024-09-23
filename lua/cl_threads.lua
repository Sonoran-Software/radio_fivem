-- 0 MS Thread
Citizen.CreateThread(function()
	while true do
		if isTalking and Config.talkSync then
			SetControlNormal(0, 249, 1.0);
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
		Wait(0)
		local coords = GetEntityCoords(GetPlayerPed(-1))
		local closestRack = GetClosestVehicle(coords.x, coords.y, coords.z, 2.0, GetHashKey('serverrack'), 70)
		if closestRack ~= 0 then
			if GetVehicleBodyHealth(closestRack) < 950 or IsVehicleDoorDamaged(closestRack, 1) or GetVehicleEngineHealth(closestRack) < 950 then
				goto continueRacks
			end
			local doorOpen = false;
			if IsVehicleDoorFullyOpen(closestRack, 1) then
				doorOpen = true
			end
			BeginTextCommandDisplayHelp('STRING')
			if doorOpen then
				AddTextComponentSubstringPlayerName('Press ~INPUT_WEAPON_SPECIAL_TWO~ to close this rack.')
			else
				AddTextComponentSubstringPlayerName('Press ~INPUT_WEAPON_SPECIAL_TWO~ to open this rack.')
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
	local MIN_DIST = 15.0
	while true do
		CheckForCloseMusic()
		local chatterSourcePlayers = {}
		local myPos = GetFinalRenderedCamCoord()
		-- create or update close players in chatterSources
		for _, ply in ipairs(GetActivePlayers()) do
			if ply == PlayerId() then
				goto continue
			end

			local ped = GetPlayerPed(ply)
			if not DoesEntityExist(ped) or #(GetEntityCoords(ped) - myPos) > MIN_DIST then
				goto continue
			end

			local state = playerStates[GetPlayerServerId(ply)]
			if state then
				-- find the index of the existing chatter source
				local idx = 0
				for i = 1, #chatterSources do
					if chatterSources[i].player == ply then
						idx = i
						break
					end
				end
				if idx > 0 then
					chatterSources[idx].state = state
				else
					table.insert(chatterSources, {player = ply, state = state})
				end

				table.insert(chatterSourcePlayers, ply)
			end
			::continue::
		end

		-- remove players that are not chatter sources anymore
		for i = #chatterSources, 1, -1 do
			local keep = false
			for _, ply in ipairs(chatterSourcePlayers) do
				if chatterSources[i].player == ply then
					keep = true
					break
				end
			end
			if not keep then
				table.remove(chatterSources, i)
			end
		end

		-- find the frequencies we need to listen to for chatter
		local listenFreqs = {}
		local function addChatterFreq(freq)
			-- verify if the freq is already in the list
			for i = 1, #listenFreqs do
				if listenFreqs[i][1] == freq[1] and listenFreqs[i][2] == freq[2] then
					return
				end
			end
			table.insert(listenFreqs, freq)
		end
		for _, info in ipairs(chatterSources) do
			addChatterFreq(info.state.freqRecv)
			for i = 1, #info.state.freqScan do
				addChatterFreq(info.state.freqScan[i])
			end
		end
		SendNUIMessage({
			type = 'chatterFrequenciesUpdate',
			freqs = listenFreqs,
		})
        if #playingSpeakers == 0 then goto continueSpeaker end
        local playerPos = GetEntityCoords(GetPlayerPed(-1));
        local playerHeading = GetEntityHeading(GetPlayerPed(-1));
        for _, v in pairs(playingSpeakers) do
            local propPos = GetSpeakerCoords(v);
            SendNUIMessage({
                name = v.Id,
                status = "updateSound",
                playerX = playerPos.x,
                playerY = playerPos.y,
                playerZ = playerPos.z,
                playerHeading = playerHeading,
                speakerX = v.PropPosition.x,
                speakerY = v.PropPosition.y,
                speakerZ = v.PropPosition.z,
                maxDistance = v.Range,
                xsound = true,
                distance = #(playerPos - propPos)
            })
        end
        ::continueSpeaker::
		if Config.enforceRadioItem then
			if LocalPlayer.state.isLoggedIn then
				-- print("has radio")
				QBCore.Functions.TriggerCallback('qb-sonrad:server:GetItem', function(hasItem)
					if not hasItem then
						Radio.Has = false
						Radio:Toggle(false)
					else
						Radio.Has = true
					end
				end, 'sonoran_radio')
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
		Citizen.Wait(500)
	end
end)

-- 5000 MS Thread
CreateThread(function()
	while true do
		Wait(5000)
		TriggerServerEvent('SonoranCAD::sonrad:GetUnitInfo')
		TriggerServerEvent('SonoranCAD::sonrad:GetCurrentCall')
		local ped = GetPlayerPed(-1)
		if DoesEntityExist(ped) then
			local pos = GetEntityCoords(ped)
			local posArr = {
				math.floor(pos.x),
				math.floor(pos.y),
				math.floor(pos.z)
			}
			SendNUIMessage({
				type = 'setPos',
				position = posArr
			})
		end
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
		SendNUIMessage({
			type = 'inVehicle',
			vehState = inVehicle
		})
		if prevState ~= inVehicle then
			SendNUIMessage({
				type = 'setVisible',
				visibility = false
			})
		end
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
				TriggerServerEvent('CellRepeater:KillAntenna', cellRepeater.Id)
				::continueCellRepeaters::
			end
		end
		Wait(100)
	end
end)

-- 1000 MS Thread
CreateThread(function()
	local QBCore = nil
	if Config.deathDetectionMethod == 'qbcore' then
		QBCore = exports['qb-core']:GetCoreObject()
	end
	TriggerServerEvent('SonoranRadio:GetTunnels')
	while true do
		if QBCore ~= nil then
			local PlayerData = QBCore.Functions.GetPlayerData()
			if PlayerData ~= nil then
				-- print("Is Dead: " .. tostring(PlayerData.metadata["isdead"]))
				-- print("Is Last Stand: " .. tostring(PlayerData.metadata["islaststand"]))
				QBDeath = PlayerData.metadata['isdead'] or PlayerData.metadata['inlaststand']
			end
		end

		if Config.deathDetectionMethod == 'auto' or Config.deathDetectionMethod == 'qbcore' then
			local IsPlayerDead = IsEntityDead(PlayerPedId()) or QBDeath
			if IsPlayerDead then
				TriggerEvent('SonoranRadio::PlayerDeath')
			else
				TriggerEvent('SonoranRadio::PlayerRevive')
			end
		end
		-- print("QBDeath:" .. tostring(QBDeath))
		-- print("EntityDead:" .. tostring(IsEntityDead(PlayerPedId())))
		-- print("Radio Enabled: " .. tostring(Radio.Enabled))
		-- Tunnel degredation logic
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
		local bestQuality = math.max(bestCellRepeaterQuality, bestRackQuality, bestTowerQuality)
		if insideZone then
			if bestQuality > 0 then
				bestQuality = bestQuality * (1 - degradeStrength)
			end
		end
		SendNUIMessage({
			type = 'setTowerQuality',
			state = {
				tower_quality = bestQuality
			}
		})
		for k, v in pairs(soundInfo) do
            if v.playing or v.wasSilented then
                if getInfo(v.id).timeStamp ~= nil and getInfo(v.id).maxDuration ~= nil then
                    if getInfo(v.id).timeStamp < getInfo(v.id).maxDuration then
                        getInfo(v.id).timeStamp = getInfo(v.id).timeStamp + 1
                    end
                end
            end
        end
		Wait(1000)
	end
end)
