local CellRepeaters = {}

local rightToRepair = false

RegisterNetEvent('SonoranRadio::AuthorizeAntennas')
AddEventHandler('SonoranRadio::AuthorizeAntennas', function()
	DebugPrint('Authorized for cellRepeater Repair')
	rightToRepair = true
end)

function GetDistance(dist1, dist2)
	local dist = #(dist1 - dist2)
	return dist
end
function LoadModelSync(model)
	RequestModel(model)
	while not HasModelLoaded(model) do
		Wait(1)
	end
end

local function GetCellRepeaterFromId(id)
	for i = 1, #CellRepeaters do
		if CellRepeaters[i].Id == id then
			return CellRepeaters[i]
		end
	end
end
local function GetCellRepeaterCoords(cellRepeater)
	if DoesEntityExist(cellRepeater.Handle) then
		return GetOffsetFromEntityInWorldCoords(cellRepeater.Handle, 0.0, 0.0, 1.0)
	else
		return vec3(cellRepeater.PropPosition.x, cellRepeater.PropPosition.y, cellRepeater.PropPosition.z)
	end
end
-- returns a value from 0-1 representing the percentage of active dishes
local function GetCellRepeaterCapacity(cellRepeater)
	local n = 0.0
	if cellRepeater.AntennaStatus == 'alive' then
		n = 1.0
	end
	return n
end

local function AddCellRepeaterRange(t)
	if not Config.debug then
		return
	end
	-- create a radius blip that indicates the range of the cellRepeater (where edge of circle = 50% capacity)
	local blip = AddBlipForRadius(t.PropPosition.x, t.PropPosition.y, t.PropPosition.z, t.Range * 0.7937)
	SetBlipAlpha(blip, 127)
	SetBlipColour(blip, 3)
end

-- fully creates a cellRepeater based on the given cellRepeater object
local function CreateCellRepeater(cellRepeater)
	if DoesEntityExist(cellRepeater.Handle) then
		DeleteEntity(cellRepeater.Handle)
	end
	local CellRepeaterModel = GetHashKey('mobilecell')
	LoadModelSync(CellRepeaterModel)

	local coords = cellRepeater.PropPosition
	cellRepeater.Handle = CreateVehicle(CellRepeaterModel, coords, false, false, false)
	while not DoesEntityExist(cellRepeater.Handle) do
		Wait(0)
	end
	DecorSetInt(cellRepeater.Handle, 'sonrad_cellRepeater', 1)
	FreezeEntityPosition(cellRepeater.Handle, true)
	SetEntityCoords(cellRepeater.Handle, coords.x, coords.y, coords.z - 1, true, true, true, false)
	SetEntityHeading(cellRepeater.Handle, cellRepeater.heading)
	SetModelAsNoLongerNeeded(CellRepeaterModel)
	cellRepeater.Spawned = true
end
-- delete the physical cellRepeater entities
local function DestroyCellRepeater(cellRepeater)
	if DoesEntityExist(cellRepeater.Handle) then
		DeleteEntity(cellRepeater.Handle)
	end
	if DoesEntityExist(cellRepeater.Ladder) then
		DeleteEntity(cellRepeater.Ladder)
	end
	local n = cellRepeater.Dishes and #cellRepeater.Dishes or 0
	for j = 1, n do
		DeleteEntity(cellRepeater.Dishes[j])
	end
	cellRepeater.Dishes = {}
	cellRepeater.Spawned = false
end

RegisterNetEvent('CellRepeater:SyncCellRepeaters')
AddEventHandler('CellRepeater:SyncCellRepeaters', function(CellRepeatersServer)
	-- make sure all CellRepeaters are cleared before we sync
	for i = 1, #CellRepeaters do
		DestroyCellRepeater(CellRepeaters[i])
	end

	CellRepeaters = CellRepeatersServer
	for i = 1, #CellRepeaters do
		AddCellRepeaterRange(CellRepeaters[i])
	end
	DebugPrint(('synced %s'):format(json.encode(CellRepeaters)))
end)

RegisterNetEvent('CellRepeater:SyncOneTower')
AddEventHandler('CellRepeater:SyncOneTower', function(cellRepeaterId, cellRepeater)
	for i = 1, #CellRepeaters do
		if CellRepeaters[i].Id == cellRepeaterId then
			DestroyCellRepeater(CellRepeaters[i])
			CellRepeaters[i] = cellRepeater
			DebugPrint('synced cellRepeater', cellRepeaterId)
			break
		end
	end
end)

RegisterNetEvent('CellRepeater:SpawnCell')
AddEventHandler('CellRepeater:SpawnCell', function(cellRepeater)
	DebugPrint(('spawned %s'):format(json.encode(cellRepeater)))
	table.insert(CellRepeaters, cellRepeater)
	AddCellRepeaterRange(cellRepeater)
	DebugPrint('new cellRepeater spawned', cellRepeater.Id)
end)

local function SyncAntennaStatus(antenna, playSound)
	local antennaHandle = antenna.Handle
	local dead = IsEntityDead(antennaHandle)

	if antenna.AntennaStatus ~= 'alive' and not dead then
		NetworkExplodeVehicle(antennaHandle, false, false)
		DecorSetInt(antennaHandle, 'sonrad_cellRepeater', 0)
		-- play a power-down sound for the player
		if playSound then
			local coords = GetEntityCoords(antennaHandle)
			PlaySoundFromCoord(-1, 'Power_Down', coords, 'DLC_HEIST_HACKING_SNAKE_SOUNDS', 0, 80)
		end
	elseif antenna.AntennaStatus == 'alive' and dead then
		CreateCellRepeater(antenna)
		if playSound then
			local coords = GetEntityCoords(antennaHandle)
			PlaySoundFromCoord(-1, 'Success', coords, 'DLC_HEIST_HACKING_SNAKE_SOUNDS', 0, 80)
		end
	end
end

RegisterNetEvent('CellRepeater:AntennaStatus')
AddEventHandler('CellRepeater:AntennaStatus', function(cellRepeaterId, AntennaStatus)
	local cellRepeater = GetCellRepeaterFromId(cellRepeaterId)
	if not cellRepeater then
		return
	end
	cellRepeater.AntennaStatus = AntennaStatus
	SyncAntennaStatus(cellRepeater, true)
end)

CreateThread(function()
	while not NetworkIsPlayerActive(PlayerId()) do
		Wait(10)
	end
	TriggerServerEvent('CellRepeater:clientCellRepeatersync')
	while #CellRepeaters == 0 do
		Wait(50)
	end
	DecorRegister('sonrad_cellRepeater', 3)
	while true do
		local pCoords = GetEntityCoords(GetPlayerPed(-1))
		local quality = 0.0
		for i = 1, #CellRepeaters do
			local cellRepeater = CellRepeaters[i]
			if not cellRepeater then
				goto continue
			end
			local d = #(GetCellRepeaterCoords(cellRepeater) - pCoords)
			-- if the player is within range (750m), then spawn a physical cellRepeater
			local physical = not Config.noPhysicalCellRepeaters and not cellRepeater.NotPhysical
			if d < 750.0 and not cellRepeater.Spawned and physical then
				CreateCellRepeater(cellRepeater)
				DebugPrint(('spawn physical cell repeater (%f) %s'):format(d, cellRepeater.Id))
			elseif d >= 750.0 and cellRepeater.Spawned then
				DestroyCellRepeater(cellRepeater)
				DebugPrint(('destroy physical cell repeater (%f) %s'):format(d, cellRepeater.Id))
			end

			-- recreate the cellRepeater completely if anything is missing
			-- NOTE: not including the ladder, as it will be omitted on certain conditions
			local recreate = cellRepeater.Spawned and not DoesEntityExist(cellRepeater.Handle)
			local n = cellRepeater.Dishes and #cellRepeater.Dishes or 0
			for j = 1, n do
				if not recreate then
					recreate = not DoesEntityExist(cellRepeater.Dishes[j])
				end
			end
			if recreate then
				DebugPrint(('cellRepeater:%s component missing, recreating'):format(cellRepeater.Id))
				-- CreateCellRepeater will automatically delete old entities
				CreateCellRepeater(cellRepeater)
			end

			-- if cellRepeater is out of range, then just ignore it
			if d > cellRepeater.Range then
				goto continue
			end

			local tQuality = (1.0 - (d / cellRepeater.Range)) * GetCellRepeaterCapacity(cellRepeater)
			if quality < tQuality then
				quality = tQuality
			end
			::continue::
		end

		if quality == 0.0 then
			DebugPrint('closest cell repeater out of range')
		else
			DebugPrint(('best cell repeater quality:%.4f'):format(quality))
		end
		SendNUIMessage({
			type = 'setTowerQuality',
			state = {
				tower_quality = quality
			}
		})
		Wait(3000)
	end
end)

local function RepairCellRepeater(cellRepeater)
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
		while (start + (Config.antennaRepairTimer or 20) * 1000) > GetGameTimer() do
			for _, c in ipairs(controls) do
				if IsControlPressed(0, c) then
					ClearPedTasksImmediately(ped)
					return
				end
			end
			Wait(0)
		end

		ClearPedTasksImmediately(ped)

		-- recreate the dishes so they don't accidentally repair the cellRepeater twice
		-- waiting for the event to propogate
		TriggerServerEvent('CellRepeater:RepairAntenna', cellRepeater.Id)
	else
		SendNotification('Radio: ~r~No Repair Permission~r~')
	end
end

CreateThread(function()
	while true do
		-- get the closest (spawned) cellRepeater
		local coords = GetEntityCoords(GetPlayerPed(-1))
		local cellRepeater, d
		for i = 1, #CellRepeaters do
			local t = CellRepeaters[i]
			if t then
				if t.Spawned then
					local td = #(GetCellRepeaterCoords(t) - coords)
					if d == nil or td < d then
						cellRepeater = t
						d = td
					end
				end
			end
		end

		if cellRepeater ~= nil and d < 2.0 and GetCellRepeaterCapacity(cellRepeater) < 1.0 then
			BeginTextCommandDisplayHelp('STRING')
			AddTextComponentSubstringPlayerName('Press ~INPUT_DETONATE~ to repair this cell repeater.')
			EndTextCommandDisplayHelp(0, false, true, -1)

			DisableControlAction(0, 47, true)
			if IsDisabledControlJustReleased(0, 47) then
				RepairCellRepeater(cellRepeater)
			end

			Wait(0)
		else
			Wait(500)
		end
	end
end)

CreateThread(function()
	while true do
		for i = 1, #CellRepeaters do
			local cellRepeater = CellRepeaters[i]
			if cellRepeater then
				local e = cellRepeater.Handle
				if DecorGetInt(e, 'sonrad_cellRepeater') ~= 1 then
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
				DecorSetInt(e, 'sonrad_cellRepeater', 0)
				DebugPrint('sending dish destroyed server event')
				TriggerServerEvent('CellRepeater:KillAntenna', cellRepeater.Id)
				::continue::
			end
		end
		Wait(250)
	end
end)

-- cleanup CellRepeaters on stop
AddEventHandler('onResourceStop', function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end
	for i = 1, #CellRepeaters do
		DestroyCellRepeater(CellRepeaters[i])
	end
	-- make sure the thread doesn't re-spawn them
	CellRepeaters = {}
end)
