function initRacks()
	racks = {}
	bestRackQuality = 0.0
	local rightToRepair = false

	--[[
		Checks if a user has the right to repair racks
	]]
	RegisterNetEvent('SonoranRadio::AuthorizeRacks')
	AddEventHandler('SonoranRadio::AuthorizeRacks', function()
		DebugPrint('Authorized for Rack Repair')
		rightToRepair = true
	end)

	-- FUNCTIONS FOR RACKS

	--[[
		Gets the specified rack object
		@param id The rack ID (string)
	]]
	function GetRackFromId(id)
		for i = 1, #racks do
			if racks[i].Id == id then
				return racks[i]
			end
		end
	end

	--[[
		Gets the specified rack's coords
		@param rack The rack to get the coords of (object)
	]]
	function GetRackCoords(rack)
		if DoesEntityExist(rack.Handle) then
			return GetOffsetFromEntityInWorldCoords(rack.Handle, 0.0, 0.0, 1.0)
		else
			return rack.PropPosition
		end
	end

	-- returns a value from 0-1 representing the percentage of active dishes
	function GetrackCapacity(tower)
		if #tower.serverStatus < 1 then
			return 1.0
		end

		local n = 0.0
		for i = 1, #tower.serverStatus do
			if tower.serverStatus[i] == 'alive' then
				n = n + 1.0
			end
		end
		return n / #tower.serverStatus
	end

	--[[
		Destroys the specified rack
		@param rack The rack to destroy (object)
	]]
	function DestroyRack(rack)
		if DoesEntityExist(rack.Handle) then
			DeleteEntity(rack.Handle)
		end
		local n = rack.Servers and #rack.Servers or 0
		for j = 1, n do
			DeleteEntity(rack.Servers[j])
		end
		rack.Servers = {}
		rack.Spawned = false
	end

	--[[
		Create the server in the specified rack
		@param rack The rack to create the server in (object)
		@param index The index of the server to create (number)
		@param n The power output of the server (number)
	]]
	function CreateServerInRack(rack, index, n)
		local initial_zOffset = 0.5
		local zOffset_increment = 0.3
		local zOffset = initial_zOffset + zOffset_increment * (index - 1)
		local serverModel = GetHashKey('sonoranserver')
		LoadModelSync(serverModel)
		local spawnPos = GetEntityCoords(rack.Handle)
		local serverHndl = CreateVehicle(serverModel, spawnPos.x, spawnPos.y, spawnPos.z, 0.0, false, false)
		if rack.Destruction then
			SetVehicleStrong(serverHndl, true)
			SetDisableVehicleEngineFires(serverHndl, true)
			SetDisableVehiclePetrolTankFires(serverHndl, true)
			SetVehicleExplodesOnHighExplosionDamage(serverHndl, true)
		else
			-- turning each dish invincible will make it impossible to destroy the dishes
			-- in turn, disabling tower destruction
			SetEntityInvincible(serverHndl, true)
		end
		-- set the decorator to "1" to alert lower functions that this is a server
		-- NOTE: later, this is set to 0 when the server is killed. this is so that the server doesn't get "destroyed" when it's killed
		DecorSetInt(serverHndl, 'sonrad_server', 1)
		AttachEntityToEntity(serverHndl, rack.Handle, -1, 0.05, 0, zOffset, 0.0, 0.0, 0, false, false, false, false, 0, true)

		SetModelAsNoLongerNeeded(serverModel)
		if not rack.Servers then
			rack.Servers = {}
		end
		if DoesEntityExist(rack.Servers[index]) then
			DeleteEntity(rack.Servers[index])
		end
		rack.Servers[index] = serverHndl
	end

	--[[
		Update the status of the specified rack
		@param rack The rack to update (object)
		@param playSound Whether to play a sound when the status is updated (boolean)
	]]
	function SyncServerStatus(rack, playSound)
		if not rack.Servers then
			return
		end
		for i = 1, #rack.Servers do
			local server = rack.Servers[i]
			local dead = IsEntityDead(server)

			if rack.serverStatus[i] ~= 'alive' and not dead then
				FreezeEntityPosition(server, false)
				DetachEntity(server, false, false)
				local serverCoords = GetEntityCoords(server)
				local moveOffsetX = 0;
				local moveOffsetY = 0;
				local serverHeading = GetEntityHeading(server)
				serverHeading = serverHeading + 180.0 -- invert the heading to get the direction the server is facing (0 is the back of the server, 180 is the front)
				if serverHeading > 360.0 then
					serverHeading = serverHeading - 360.0
				end
				if serverHeading < 45 or serverHeading > 315 then -- Facing "North"
					local varianceFromTrue = 0; -- 0 degrees is true north
					if serverHeading > 0 then -- Facing "North" and "West"
						varianceFromTrue = serverHeading;
					elseif serverHeading > 315 then -- Facing "North" and "East"
						varianceFromTrue = serverHeading - 360;
					end
					moveOffsetY = 0.5 -- move the server to the north
					if varianceFromTrue ~= 0 then
						moveOffsetX = varianceFromTrue / 45 * 0.5 -- move the server to the east or west based on percentage of 45 degrees
						moveOffsetX = moveOffsetX * -1 -- invert the offset because if the server is facing "North East" X should be positive | If the server is facing "North West" X should be negative
					end
				elseif serverHeading >= 225 and serverHeading <= 315 then -- Facing "East"
					local varianceFromTrue = 0; -- 0 degrees is true east
					if serverHeading < 315 and serverHeading > 270 then -- Facing "East" and "North"
						varianceFromTrue = 315 - serverHeading; -- Facing "North East" Y should be positive | If the server is facing "South East" Y should be negative
					elseif serverHeading > 225 then -- Facing "East" and "South"
						varianceFromTrue = serverHeading - 270;
					end
					moveOffsetX = 0.5
					if varianceFromTrue ~= 0 then
						moveOffsetY = varianceFromTrue / 45 * 0.5
					end
				elseif serverHeading >= 135 and serverHeading <= 225 then -- Facing "South"
					local varianceFromTrue = 0; -- 0 degrees is true south
					if serverHeading < 225 and serverHeading > 180 then -- Facing "South" and "East"
						varianceFromTrue = 225 - serverHeading; -- Facing "South East" Y should be positive | If the server is facing "South West" Y should be negative
					elseif serverHeading > 135 then -- Facing "South" and "West"
						varianceFromTrue = serverHeading - 180;
					end
					moveOffsetY = -0.5
					if varianceFromTrue ~= 0 then
						moveOffsetX = varianceFromTrue / 45 * 0.5 -- move the server to the east or west based on percentage of 45 degrees
					end
				elseif serverHeading >= 45 and serverHeading <= 135 then -- Facing "West"
					local varianceFromTrue = 0; -- 0 degrees is true west
					if serverHeading < 135 and serverHeading > 90 then -- Facing "West" and "South"
						varianceFromTrue = 135 - serverHeading; -- Facing "South West" Y should be positive | If the server is facing "North West" Y should be negative
					elseif serverHeading > 45 then -- Facing "West" and "North"
						varianceFromTrue = serverHeading - 90;
					end
					if varianceFromTrue ~= 0 then
						moveOffsetY = varianceFromTrue / 45 * 0.5 -- move the server to the north or south based on percentage of 45 degrees
					end
					moveOffsetX = -0.5
				end
				SetEntityCoords(server, serverCoords.x + moveOffsetX, serverCoords.y + moveOffsetY, serverCoords.z, false, false, false, false)
				NetworkExplodeVehicle(server, false, false)
				DecorSetInt(server, 'sonrad_server', 0)
				-- play a power-down sound for the player
				if playSound then
					local coords = GetEntityCoords(server)
					PlaySoundFromCoord(-1, 'Power_Down', coords, 'DLC_HEIST_HACKING_SNAKE_SOUNDS', 0, 80)
				end
			elseif rack.serverStatus[i] == 'alive' and dead then
				CreateServerInRack(rack, i, #rack.serverStatus)
				if playSound then
					local coords = GetEntityCoords(server)
					PlaySoundFromCoord(-1, 'Success', coords, 'DLC_HEIST_HACKING_SNAKE_SOUNDS', 0, 80)
				end
			end
		end
	end

	--[[
		Create the rack for servers to go into
		@param rack The rack to create (object)
	]]
	function CreateRack(rack)
		if DoesEntityExist(rack.Handle) then
			DeleteEntity(rack.Handle)
		end
		local rackModel = GetHashKey('serverrack')
		LoadModelSync(rackModel)
		local coords = rack.PropPosition
		rack.Handle = CreateVehicle(rackModel, coords, false, false, false)
		while not DoesEntityExist(rack.Handle) do
			Wait(0)
		end
		SetDisableVehicleEngineFires(rack.Handle, true)
		SetDisableVehiclePetrolTankFires(rack.Handle, true)
		SetEntityCoordsNoOffset(rack.Handle, coords.x, coords.y, coords.z - 1.1, false, false, false, false)
		FreezeEntityPosition(rack.Handle, true)
		local calculatedHeading = rack.heading + 180.0 -- invert the heading to get the direction the server is facing (0 is the back of the server, 180 is the front)
		if calculatedHeading > 360.0 then
			calculatedHeading = calculatedHeading - 360.0
		end
		SetEntityHeading(rack.Handle, calculatedHeading)
		SetModelAsNoLongerNeeded(rackModel)
		for i = 1, #rack.serverStatus do
			CreateServerInRack(rack, i, #rack.serverStatus)
		end
		SyncServerStatus(rack, false)
		rack.Spawned = true
	end

	--[[
		Add the debug circle to show the range of the server rack
		@param rack The rack to load (object)
	]]
	function AddRackRange(t)
		if not Config.debug then
			return
		end
		-- create a radius blip that indicates the range of the server rack (where edge of circle = 50% capacity)
		local blip = AddBlipForRadius(t.PropPosition.x, t.PropPosition.y, t.PropPosition.z, t.Range * 0.7937)
		SetBlipAlpha(blip, 127)
		SetBlipColour(blip, 3)
	end

	-- EVENTS

	--[[
		Event to spawn a rack
	]]
	RegisterNetEvent('RadioRacks:SpawnRack', function(rack)
		DebugPrint(('spawned %s'):format(json.encode(rack)))
		table.insert(racks, rack)
		AddRackRange(rack)
		DebugPrint('new rack spawned', rack.Id)
	end)

	--[[
		Event to sync racks between server and clients
	]]
	RegisterNetEvent('RadioRacks:SyncRacks')
	AddEventHandler('RadioRacks:SyncRacks', function(racksFromServer)
		-- make sure all racks are cleared before we sync
		for i = 1, #racks do
			DestroyRack(racks[i])
		end

		racks = racksFromServer
		for i = 1, #racks do
			AddRackRange(racks[i])
		end
		DebugPrint(('synced %s'):format(json.encode(racks)))
	end)

	--[[
		Event to sync a single rack
	]]
	RegisterNetEvent('RadioRacks:SyncOneRack')
	AddEventHandler('RadioRacks:SyncOneRack', function(rackId, rack)
		for i = 1, #racks do
			if racks[i].Id == rackId then
				DestroyRack(racks[i])
				racks[i] = rack
				DebugPrint('synced rack', rackId)
				break
			end
		end
	end)

	--[[
		Event to set a server status
	]]
	RegisterNetEvent('RadioRacks:SetServerStatus')
	AddEventHandler('RadioRacks:SetServerStatus', function(rackId, serverStatus)
		local rack = GetRackFromId(rackId)
		if not rack then
			return
		end
		rack.serverStatus = serverStatus
		SyncServerStatus(rack, true)
	end)

	CreateThread(function()
		while not NetworkIsPlayerActive(PlayerId()) do
			Wait(10)
		end
		TriggerServerEvent('RadioRacks:clientRackSync')
		while #racks == 0 do
			Wait(50)
		end

		DecorRegister('sonrad_server', 3)
		-- while true do
		-- 	bestRackQuality = 0.0
		-- 	local pCoords = GetEntityCoords(GetPlayerPed(-1))
		-- 	for i = 1, #racks do
		-- 		local rack = racks[i]
		-- 		if not rack then
		-- 			goto continue
		-- 		end
		-- 		local d = #(GetRackCoords(rack) - pCoords)
		-- 		-- if the player is within range (750m), then spawn a physical rack
		-- 		local physical = not Config.noPhysicalRacks and not rack.NotPhysical
		-- 		if d < 750.0 and not rack.Spawned and physical then
		-- 			CreateRack(rack)
		-- 			DebugPrint(('spawn physical rack (%f) %s'):format(d, rack.Id))
		-- 		elseif d >= 750.0 and rack.Spawned then
		-- 			DestroyRack(rack)
		-- 			DebugPrint(('destroy physical rack (%f) %s'):format(d, rack.Id))
		-- 		end

		-- 		-- recreate the rack completely if anything is missing
		-- 		-- NOTE: not including the ladder, as it will be omitted on certain conditions
		-- 		local recreate = rack.Spawned and not DoesEntityExist(rack.Handle)
		-- 		local n = rack.Servers and #rack.Servers or 0
		-- 		for j = 1, n do
		-- 			if not recreate then
		-- 				recreate = not DoesEntityExist(rack.Servers[j])
		-- 			end
		-- 		end
		-- 		if recreate then
		-- 			DebugPrint(('rack:%s component missing, recreating'):format(rack.Id))
		-- 			-- CreateRack will automatically delete old entities
		-- 			CreateRack(rack)
		-- 			SyncServerStatus(rack, false)
		-- 		end

		-- 		-- if rack is out of range, then just ignore it
		-- 		if d > rack.Range then
		-- 			goto continue
		-- 		end
		-- 		local tQuality = (1.0 - (d / rack.Range)) * GetrackCapacity(rack)
		-- 		if bestRackQuality < tQuality then
		-- 			bestRackQuality = tQuality
		-- 		end
		-- 		::continue::
		-- 	end

		-- 	if bestRackQuality == 0.0 then
		-- 		DebugPrint('closest rack out of range')
		-- 	else
		-- 		DebugPrint(('best rack quality:%.4f'):format(bestRackQuality))
		-- 	end
		-- 	-- SendNUIMessage({
		-- 	-- 	type = 'setrackQuality',
		-- 	-- 	state = {
		-- 	-- 		rack_quality = quality
		-- 	-- 	}
		-- 	-- })
		-- 	Wait(3000)
		-- end
	end)

	function RepairRack(rack)
		if rightToRepair then
			local ped = GetPlayerPed(-1)
			TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_WELDING', 0, true)

			local start = GetGameTimer()
			-- watch WASD keys, and if pressed then cancel repair
			local controls = {
				32,
				33,
				34,
				35
			}
			while (start + (Config.rackRepairTimer or 20) * 1000) > GetGameTimer() do
				for _, c in ipairs(controls) do
					if IsControlPressed(0, c) then
						ClearPedTasksImmediately(ped)
						return
					end
				end
				Wait(0)
			end

			ClearPedTasksImmediately(ped)

			-- recreate the Servers so they don't accidentally repair the rack twice
			-- waiting for the event to propogate
			TriggerServerEvent('RadioRacks:RepairRack', rack.Id)
		else
			SendNotification('Radio: ~r~No Repair Permission~r~')
		end
	end

	-- Variable Thread, cannot be consolidated
	CreateThread(function()
		while true do
			-- get the closest (spawned) rack
			local coords = GetEntityCoords(GetPlayerPed(-1))
			local rack, d
			for i = 1, #racks do
				local t = racks[i]
				if t then
					if t.Spawned then
						local td = #(GetRackCoords(t) - coords)
						if d == nil or td < d then
							rack = t
							d = td
						end
					end
				end
			end
			if rack ~= nil and d < 2.0 and GetrackCapacity(rack) < 1.0 then
				BeginTextCommandDisplayHelp('STRING')
				AddTextComponentSubstringPlayerName('Press ~INPUT_DETONATE~ to repair this rack.')
				EndTextCommandDisplayHelp(0, false, true, -1)

				DisableControlAction(0, 47, true)
				if IsDisabledControlJustReleased(0, 47) then
					RepairRack(rack)
				end

				Wait(0)
			else
				Wait(500)
			end
		end
	end)

	-- CreateThread(function()
	-- 	while true do
	-- 		Wait(0)
	-- 		local coords = GetEntityCoords(GetPlayerPed(-1))
	-- 		local closestRack = GetClosestVehicle(coords.x, coords.y, coords.z, 2.0, GetHashKey('serverrack'), 70)
	-- 		if closestRack ~= 0 then
	-- 			if GetVehicleBodyHealth(closestRack) < 950 or IsVehicleDoorDamaged(closestRack, 1) or GetVehicleEngineHealth(closestRack) < 950 then
	-- 				goto continue
	-- 			end
	-- 			local doorOpen = false;
	-- 			if IsVehicleDoorFullyOpen(closestRack, 1) then
	-- 				doorOpen = true
	-- 			end
	-- 			BeginTextCommandDisplayHelp('STRING')
	-- 			if doorOpen then
	-- 				AddTextComponentSubstringPlayerName('Press ~INPUT_WEAPON_SPECIAL_TWO~ to close this rack.')
	-- 			else
	-- 				AddTextComponentSubstringPlayerName('Press ~INPUT_WEAPON_SPECIAL_TWO~ to open this rack.')
	-- 			end
	-- 			EndTextCommandDisplayHelp(0, false, true, -1)
	-- 			DisableControlAction(0, 54, true)
	-- 			if IsDisabledControlJustReleased(0, 54) then
	-- 				local Vehicle = closestRack
	-- 				if doorOpen then
	-- 					SetVehicleDoorShut(Vehicle, 1, false)
	-- 				else
	-- 					SetVehicleDoorOpen(Vehicle, 1, false, false)
	-- 				end
	-- 			end
	-- 		end
	-- 		::continue::
	-- 	end
	-- end)

	-- CreateThread(function()
	-- 	while true do
	-- 		for i = 1, #racks do
	-- 			local rack = racks[i]
	-- 			if rack then
	-- 				local n = rack.Servers and #rack.Servers or 0
	-- 				for j = 1, n do
	-- 					local e = rack.Servers[j]
	-- 					if IsVehicleEngineOnFire(e) or IsEntityOnFire(e) then
	-- 						StopFireInRange(GetEntityCoords(e), 3.0)
	-- 						StopEntityFire(e)
	-- 					end
	-- 					if DecorGetInt(e, 'sonrad_server') ~= 1 then
	-- 						goto continue
	-- 					end
	-- 					if not IsEntityDead(e) then
	-- 						SetVehiclePetrolTankHealth(e, 1000.0)
	-- 					end
	-- 					local health = GetEntityHealth(e)
	-- 					if health > 980.0 then
	-- 						goto continue
	-- 					end
	-- 					-- here we kill the dish
	-- 					DecorSetInt(e, 'sonrad_server', 0)
	-- 					DebugPrint('sending dish destroyed server event')
	-- 					TriggerServerEvent('RadioRacks:KillServer', rack.Id, j)
	-- 					::continue::
	-- 				end
	-- 			end
	-- 		end
	-- 		Wait(250)
	-- 	end
	-- end)

	-- cleanup racks on stop
	AddEventHandler('onResourceStop', function(resource)
		if resource ~= GetCurrentResourceName() then
			return
		end
		for i = 1, #racks do
			DestroyRack(racks[i])
		end
		-- make sure the thread doesn't re-spawn them
		racks = {}
	end)
end