racks = {}

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
local function GetRackFromId(id)
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
local function GetRackCoords(rack)
	if DoesEntityExist(rack.Handle) then
		return GetOffsetFromEntityInWorldCoords(rack.Handle, 0.0, 0.0, 1.0)
	else
		return rack.PropPosition
	end
end

-- returns a value from 0-1 representing the percentage of active dishes
local function GetrackCapacity(tower)
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
local function DestroyRack(rack)
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
local function CreateServerInRack(rack, index, n)
	local serverModel = GetHashKey('server')
	LoadModelSync(serverModel)

	local spawnPos = GetEntityCoords(rack.Handle)
	local serverHndl = CreateVehicle(serverModel, spawnPos.x, spawnPos.y, spawnPos.z, 0.0, false, false)
	SetEntityAsMissionEntity(serverHndl, true, true)
	FreezeEntityPosition(serverHndl, true)
	if rack.Destruction then
		SetVehicleStrong(serverHndl, true)
	else
		-- turning each server invincible will make it impossible to destroy the servers
		-- in turn, disabling rack destruction
		SetEntityInvincible(serverHndl, true)
	end

	-- set the decorator to "1" to alert lower functions that this is a server
	-- NOTE: later, this is set to 0 when the server is killed. this is so that the server doesn't get "destroyed" when it's killed
	DecorSetInt(serverHndl, 'sonrad_server', 1)
	AttachEntityToEntity(serverHndl, rack.Handle, -1, 0, 1, 0.0, 0.0, 0.0, 0, false, false, true, false, 0, true)

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
local function SyncServerStatus(rack, playSound)
	for i = 1, #rack.Servers do
		local server = rack.Servers[i]
		local dead = IsEntityDead(server)

		if rack.serverStatus[i] ~= 'alive' and not dead then
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
local function CreateRack(rack)
	if DoesEntityExist(rack.Handle) then
		DeleteEntity(rack.Handle)
	end
	local rackModel = GetHashKey('serverrack')
	LoadModelSync(rackModel)

	local coords = rack.PropPosition
	rack.Handle = CreateObject(rackModel, coords, false, false, false)
	while not DoesEntityExist(rack.Handle) do
		Wait(0)
	end
	FreezeEntityPosition(rack.Handle, true)
	SetEntityCoords(rack.Handle, coords.x, coords.y, coords.z - 1, true, true, true, false)
	PlaceObjectOnGroundProperly(rack.Handle)
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
local function AddRackRange(t)
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
AddEventHandler('RadioRacks:SyncRacks', function(racks)
	-- make sure all racks are cleared before we sync
	for i = 1, #racks do
		DestroyRack(racks[i])
	end

	racks = racks
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
	while true do
		local pCoords = GetEntityCoords(GetPlayerPed(-1))
		local quality = 0.0
		for i = 1, #racks do
			local rack = racks[i]
			if not rack then
				goto continue
			end
			local d = #(GetRackCoords(rack) - pCoords)
			-- if the player is within range (750m), then spawn a physical rack
			local physical = not Config.noPhysicalracks and not rack.NotPhysical
			if d < 750.0 and not rack.Spawned and physical then
				CreateRack(rack)
				DebugPrint(('spawn physical rack (%f) %s'):format(d, rack.Id))
			elseif d >= 750.0 and rack.Spawned then
				DestroyRack(rack)
				DebugPrint(('destroy physical rack (%f) %s'):format(d, rack.Id))
			end

			-- recreate the rack completely if anything is missing
			-- NOTE: not including the ladder, as it will be omitted on certain conditions
			local recreate = rack.Spawned and not DoesEntityExist(rack.Handle)
			local n = rack.Servers and #rack.Servers or 0
			for j = 1, n do
				if not recreate then
					recreate = not DoesEntityExist(rack.Servers[j])
				end
			end
			if recreate then
				DebugPrint(('rack:%s component missing, recreating'):format(rack.Id))
				-- CreateRack will automatically delete old entities
				CreateRack(rack)
				SyncServerStatus(rack, false)
			end

			-- if rack is out of range, then just ignore it
			if d > rack.Range then
				goto continue
			end

			local tQuality = (1.0 - (d / rack.Range)) * GetrackCapacity(rack)
			if quality < tQuality then
				quality = tQuality
			end
			::continue::
		end

		if quality == 0.0 then
			DebugPrint('closest rack out of range')
		else
			DebugPrint(('best rack quality:%.4f'):format(quality))
		end
		SendNUIMessage({
			type = 'setrackQuality',
			state = {
				rack_quality = quality
			}
		})
		Wait(3000)
	end
end)

local function RepairRack(rack)
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

CreateThread(function()
	while true do
		for i = 1, #racks do
			local rack = racks[i]
			if rack then
				local n = rack.Servers and #rack.Servers or 0
				for j = 1, n do
					local e = rack.Servers[j]
					if DecorGetInt(e, 'sonrad_server') ~= 1 then
						goto continue
					end
					if not IsEntityDead(e) then
						-- make sure it doesn't explode from gunshots
						SetVehiclePetrolTankHealth(e, 1000.0)
					end

					local health = GetVehicleBodyHealth(e)
					if health > 500.0 then
						goto continue
					end

					-- here we kill the dish
					DecorSetInt(e, 'sonrad_server', 0)
					DebugPrint('sending dish destroyed server event')
					TriggerServerEvent('RadioRacks:KillServer', rack.Id, j)
					::continue::
				end
			end
		end
		Wait(250)
	end
end)

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
