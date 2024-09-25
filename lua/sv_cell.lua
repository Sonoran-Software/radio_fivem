local CellRepeater = {
	-- whether the tower can be destroyed or not
	Destruction = true,
	NotPhysical = false,
	Swankiness = 0.0,
	-- the tower's position (vec3)
	PropPosition = nil,
	-- the range of the tower
	Range = 1500.0,
	AntennaStatus = 'alive',
	Powered = true,
	DontSaveMe = false,
	heading = 0.0,
	type = 'cellRepeater'
}

CellRepeaters = {}
function GetCellRepeaters(coords)
	for i = 1, #CellRepeaters do
		if CellRepeaters[i].PropPosition == coords then
			return CellRepeaters[i], i
		end
	end
	return nil, nil
end
function GetCellRepeatersFromId(id)
	for _, t in ipairs(CellRepeaters) do
		if t.Id == id then
			return t
		end
	end
end

AddEventHandler('SonoranScripts::PowerGrid::RegisterNewDevice', function(coords, entityID, requestID)
	print('SONRAD REGISTER')
	for _, v in pairs(CellRepeaters) do
		DebugPrint(('coords: ' .. v.PropPosition))
		local dist = #(v.PropPosition.xy - coords.xy)
		DebugPrint('dist: ' .. dist)
		DebugPrint(tostring(entityId))
		if dist < 10 then
			TriggerEvent('SonoranScripts::PowerGrid::NewDevice', v.Id, 'cellrepeaters', requestID)
		end
	end
end)

RegisterNetEvent('SonoranScripts::PowerGrid::DeviceDisabled')
AddEventHandler('SonoranScripts::PowerGrid::DeviceDisabled', function(affectedDevices)
	DebugPrint('SONRAD DISABLED ' .. json.encode(affectedDevices))
	for _, v in pairs(affectedDevices['radioCellRepeaters']) do
		local tower = GetCellRepeatersFromId(v)
		DebugPrint(json.encode(tower))
		tower.Powered = false
        tower.AntennaStatus = 'dead'
		TriggerClientEvent('CellRepeater:SetAntennaStatus', -1, v, tower.AntennaStatus)
		TriggerEvent('SonoranCAD::sonrad:SetAntennaStatus', v, tower.AntennaStatus)
	end
	-- TriggerClientEvent("CellRepeater:SyncCellRepeaters", source, CellRepeaters)
	-- TriggerEvent("SonoranCAD::sonrad:SyncCellRepeaters", CellRepeaters)

end)

RegisterNetEvent('SonoranScripts::PowerGrid::DeviceRepaired')
AddEventHandler('SonoranScripts::PowerGrid::DeviceRepaired', function(affectedDevices)
	DebugPrint('SONRAD REPAIRED ' .. json.encode(affectedDevices))
	for _, v in pairs(affectedDevices['radioCellRepeaters']) do
		local tower = GetCellRepeatersFromId(v)
		tower.Powered = true
        tower.AntennaStatus = 'alive'
		TriggerClientEvent('CellRepeater:AntennaStatus', -1, v, tower.AntennaStatus)
		TriggerEvent('SonoranCAD::sonrad:AntennaStatus', v, tower.AntennaStatus)
	end
	-- TriggerClientEvent("CellRepeater:SyncCellRepeaters", source, CellRepeaters)
	-- TriggerEvent("SonoranCAD::sonrad:SyncCellRepeaters", CellRepeaters)
end)

-- RegisterCommand('removeCellRepeaters', function()
-- 	TriggerClientEvent('CellRepeater:Shutdown', -1)
-- 	CellRepeaters = {}
-- end, true)

-- RegisterCommand('saveCellRepeaters', function()
-- 	local saveCellRepeaters = {}
-- 	for _, t in ipairs(CellRepeaters) do
-- 		if not t.DontSaveMe then
-- 			table.insert(saveCellRepeaters, t)
-- 		end
-- 	end
-- 	local f = assert(io.open(GetResourcePath('sonoranradio') .. '/cellRepeaters.json', 'w+'))
-- 	f:write(json.encode(saveCellRepeaters))
-- 	f:close()
-- 	print('ok')
-- end, true)

-- RegisterCommand('spawnRadioCellRepeater', function(source)
-- 	local coords = GetEntityCoords(GetPlayerPed(source))
-- 	local heading = GetEntityHeading(GetPlayerPed(source))
-- 	local tower = shallowcopy(CellRepeater)
-- 	tower.Id = uuid()
-- 	tower.PropPosition = coords
-- 	tower.heading = heading
-- 	table.insert(CellRepeaters, tower)

-- 	TriggerClientEvent('CellRepeater:SpawnCell', -1, tower)
-- 	local saveData = {};
-- 	for _, t in ipairs(Towers) do
-- 		if not t.DontSaveMe then
-- 			table.insert(saveData, t)
-- 		end
-- 	end
-- 	for _, t in ipairs(Servers) do
-- 		if not t.DontSaveMe then
-- 			table.insert(saveData, t)
-- 		end
-- 	end
-- 	for _, t in ipairs(CellRepeaters) do
-- 		if not t.DontSaveMe then
-- 			table.insert(saveData, t)
-- 		end
-- 	end
-- 	local f = assert(io.open(GetResourcePath('sonoranradio') .. '/' .. jsonFileName, 'w+'))
-- 	f:write(json.encode(saveData))
-- 	f:close()
-- 	print('ok')

-- end, true)

RegisterNetEvent('CellRepeater:clientCellRepeatersync')
AddEventHandler('CellRepeater:clientCellRepeatersync', function()
	local source = source
	while #CellRepeaters == 0 do
		Wait(10)
	end
	TriggerClientEvent('CellRepeater:SyncCellRepeaters', source, CellRepeaters)
	local sonoradData = {}
	for _, t in ipairs(CellRepeaters) do
		if not t.DontSaveMe then
			table.insert(sonoradData, t)
		end
	end
	for _, t in ipairs(Servers) do
		if not t.DontSaveMe then
			table.insert(sonoradData, t)
		end
	end
	for _, t in ipairs(Towers) do
		if not t.DontSaveMe then
			table.insert(sonoradData, t)
		end
	end
	TriggerEvent('SonoranCAD::sonrad:SyncTowers', sonoradData)
end)

local DestroyRequests = {}
RegisterNetEvent('CellRepeater:Destroy')
AddEventHandler('CellRepeater:Destroy', function(coords)
	local handshake = uuid()
	DestroyRequests[source] = {
		coords = coords,
		secret = handshake
	}
	TriggerClientEvent('CellRepeater:VerifyLocation', source, handshake)
end)

RegisterNetEvent('CellRepeater:KillAntenna')
AddEventHandler('CellRepeater:KillAntenna', function(towerId)
	local tower = GetCellRepeatersFromId(towerId)
	DebugPrint('CellRepeater:KillAntenna', towerId)
	if not tower then
		return
	end

	tower.AntennaStatus = 'dead'
	TriggerClientEvent('CellRepeater:AntennaStatus', -1, towerId, tower.AntennaStatus)
	TriggerEvent('SonoranCAD::sonrad:AntennaStatus', towerId, tower.AntennaStatus)
end)

RegisterNetEvent('CellRepeater:RepairAntenna')
AddEventHandler('CellRepeater:RepairAntenna', function(towerId)
	local tower = GetCellRepeatersFromId(towerId)
	DebugPrint('CellRepeater:RepairAntenna', towerId)
	if not tower then
		return
	end
    tower.AntennaStatus = 'alive'
	TriggerClientEvent('CellRepeater:AntennaStatus', -1, towerId, tower.AntennaStatus)
	TriggerEvent('SonoranCAD::sonrad:AntennaStatus', towerId, tower.AntennaStatus)
end)

RegisterNetEvent('CellRepeater:clientLocationVerify')
AddEventHandler('CellRepeater:clientLocationVerify', function(coords, handshake)
	if DestroyRequests[source] == nil or DestroyRequests[source].secret ~= handshake then
		print('ERR: failed handshake')
		return
	end
	local source = source
	local dist1 = coords
	local dist2 = DestroyRequests[source].coords
	local dist = #(dist1 - dist2)
	if dist > 5 then
		print('ERR: failed location check')
	else
		local tower, idx = GetCellRepeaters(dist2)
		if not tower then
			print('ERR: no tower found')
			return
		end
		tower.Destruction = true
		tower.DestructionTimer = GetGameTimer()
		CellRepeaters[idx] = tower
		TriggerClientEvent('CellRepeater:SyncCellRepeaters', -1)
		TriggerClientEvent('CellRepeater:DestroyedTower', source, dist2)
	end
end)

-- API
exports('createCellRepeater', function(config)
	local obj = shallowcopy(CellRepeater)
	obj.Id = uuid()
	obj.NotPhysical = true
	for k, v in pairs(config) do
		obj[k] = v
	end
	obj.DontSaveMe = true
	obj.ApiResource = GetInvokingResource()
	table.insert(CellRepeaters, obj)
	TriggerClientEvent('CellRepeater:spawncell', -1, obj)
	TriggerEvent('SonoranCAD::sonrad:SyncCellRepeaters', CellRepeaters)
	DebugPrint('tower spawned by an api', obj.Id, obj.ApiResource)
	return obj.Id
end)
exports('updateCellRepeater', function(towerId, config)
	for i = 1, #CellRepeaters do
		if CellRepeaters[i].Id == towerId then
			DebugPrint('tower updated by an api', towerId, GetInvokingResource())
			if config == nil then
				TriggerEvent('SonoranCAD::sonrad:SyncOneTower', towerId, nil)
				TriggerClientEvent('CellRepeater:SyncOneTower', -1, towerId, nil)
				table.remove(CellRepeaters, i)
			else
				for k, v in pairs(config) do
					CellRepeaters[i][k] = v
				end
				TriggerClientEvent('CellRepeater:SyncOneTower', -1, towerId, CellRepeaters[i])
				TriggerEvent('SonoranCAD::sonrad:SyncOneTower', towerId, CellRepeaters[i])
			end
			return config and CellRepeaters[i].Id or ''
		end
	end
	return nil
end)

AddEventHandler('onResourceStop', function(resource)
	local hadChange = false
	local i = 1
	while i <= #CellRepeaters do
		if CellRepeaters[i].ApiResource == resource then
			DebugPrint('removing cell repeater after resource shutdown', CellRepeaters[i].Id)
			table.remove(CellRepeaters, i)
			hadChange = true
		else
			i = i + 1
		end
	end

	-- sync all CellRepeaters with all clients
	if hadChange then
		TriggerClientEvent('CellRepeater:SyncCellRepeaters', -1, CellRepeaters)
	end
end)
