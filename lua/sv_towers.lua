RadioTower = {
	-- whether the tower can be destroyed or not
	Destruction = true,
	NotPhysical = false,
	Swankiness = 0.0,
	-- the tower's position (vec3)
	PropPosition = nil,
	-- the range of the tower
	Range = 1500.0,
	DishStatus = {
		'alive',
		'alive',
		'alive',
		'alive'
	},
	Powered = true,
	DontSaveMe = false,
	heading = 0.0,
	type = 'radioTower'
}

Towers = {}
function GetTower(coords)
	for i = 1, #Towers do
		if Towers[i].PropPosition == coords then
			return Towers[i], i
		end
	end
	return nil, nil
end
function GetTowerFromId(id)
	for _, t in ipairs(Towers) do
		if t.Id == id then
			return t
		end
	end
end

AddEventHandler('SonoranScripts::PowerGrid::RegisterNewDevice', function(coords, entityID, requestID)
	print('SONRAD REGISTER')
	for _, v in pairs(Towers) do
		DebugPrint(('coords: ' .. v.PropPosition))
		local dist = #(v.PropPosition.xy - coords.xy)
		DebugPrint('dist: ' .. dist)
		DebugPrint(tostring(entityId))
		if dist < 10 then
			TriggerEvent('SonoranScripts::PowerGrid::NewDevice', v.Id, 'radiotowers', requestID)
		end
	end
end)

RegisterNetEvent('SonoranScripts::PowerGrid::DeviceDisabled')
AddEventHandler('SonoranScripts::PowerGrid::DeviceDisabled', function(affectedDevices)
	DebugPrint('SONRAD DISABLED ' .. json.encode(affectedDevices))
	for _, v in pairs(affectedDevices['radiotowers']) do
		local tower = GetTowerFromId(v)
		DebugPrint(json.encode(tower))
		tower.Powered = false
		for i = 1, #tower.DishStatus do
			tower.DishStatus[i] = 'dead'
		end
		TriggerClientEvent('RadioTower:SetDishStatus', -1, v, tower.DishStatus)
		TriggerEvent('SonoranCAD::sonrad:SetDishStatus', v, tower.DishStatus)
	end
	SyncSonoranCadLiveMap()

end)

RegisterNetEvent('SonoranScripts::PowerGrid::DeviceRepaired')
AddEventHandler('SonoranScripts::PowerGrid::DeviceRepaired', function(affectedDevices)
	DebugPrint('SONRAD REPAIRED ' .. json.encode(affectedDevices))
	for _, v in pairs(affectedDevices['radiotowers']) do
		local tower = GetTowerFromId(v)
		tower.Powered = true
		for i = 1, #tower.DishStatus do
			tower.DishStatus[i] = 'alive'
		end
		TriggerClientEvent('RadioTower:SetDishStatus', -1, v, tower.DishStatus)
		TriggerEvent('SonoranCAD::sonrad:SetDishStatus', v, tower.DishStatus)
	end
	SyncSonoranCadLiveMap()
end)

-- RegisterCommand('removetowers', function()
-- 	TriggerClientEvent('RadioTower:Shutdown', -1)
-- 	Towers = {}
-- end, true)

-- RegisterCommand('savetowers', function()
-- 	local saveTowers = {}
-- 	for _, t in ipairs(Towers) do
-- 		if not t.DontSaveMe then
-- 			table.insert(saveTowers, t)
-- 		end
-- 	end
-- 	local f = assert(io.open(GetResourcePath('sonoranradio') .. '/' .. jsonFileName, 'w+'))
-- 	f:write(json.encode(saveTowers))
-- 	f:close()
-- 	print('ok')
-- end, true)

-- RegisterCommand('spawnRadioTower', function(source)
-- 	local coords = GetEntityCoords(GetPlayerPed(source))
-- 	local tower = shallowcopy(RadioTower)
-- 	tower.Id = uuid()
-- 	tower.PropPosition = coords
-- 	table.insert(Towers, tower)
-- 	TriggerClientEvent('RadioTower:SpawnTower', -1, tower)
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

RegisterNetEvent('RadioTower:clientTowerSync')
AddEventHandler('RadioTower:clientTowerSync', function()
	local source = source
	while #Towers == 0 do
		Wait(10)
	end
	TriggerLatentClientEvent('RadioTower:SyncTowers', source, 10000, Towers)
	TriggerEvent('SonoranRadio:QueueCadTowerSync', 'towers')
end)

RegisterNetEvent('RadioTower:KillDish')
AddEventHandler('RadioTower:KillDish', function(towerId, dishIndex)
	local tower = GetTowerFromId(towerId)
	DebugPrint('RadioTower:KillDish', towerId, dishIndex)
	if not tower then
		return
	end

	tower.DishStatus[dishIndex] = 'dead'
	TriggerClientEvent('RadioTower:SetDishStatus', -1, towerId, tower.DishStatus)
	TriggerEvent('SonoranCAD::sonrad:SetDishStatus', towerId, tower.DishStatus)
	TriggerEvent('SonoranRadio::API:TowerDishDestroyed', source, towerId, tower.DishStatus)
	SyncSonoranCadLiveMap()
end)

RegisterNetEvent('RadioTower:RepairTower')
AddEventHandler('RadioTower:RepairTower', function(towerId)
	local tower = GetTowerFromId(towerId)
	DebugPrint('RadioTower:RepairTower', towerId)
	if not tower then
		return
	end

	for i = 1, #tower.DishStatus do
		tower.DishStatus[i] = 'alive'
	end
	TriggerClientEvent('RadioTower:SetDishStatus', -1, towerId, tower.DishStatus)
	TriggerEvent('SonoranCAD::sonrad:SetDishStatus', towerId, tower.DishStatus)
	TriggerEvent('SonoranRadio::API:TowerRepaired', source, towerId, tower.DishStatus)
	SyncSonoranCadLiveMap()
end)

RegisterNetEvent('RadioTower:RepairAllTowers')
AddEventHandler('RadioTower:RepairAllTowers', function()
	DebugPrint('RadioTower:RepairAllTowers')

	-- any reasonable community should have <100
	for _, tower in ipairs(Towers) do
		local needsRepair = false
		for i = 1, #tower.DishStatus do
			needsRepair = needsRepair or tower.DishStatus[i] ~= 'alive'
			tower.DishStatus[i] = 'alive'
		end

		if needsRepair then
			TriggerClientEvent('RadioTower:SetDishStatus', -1, tower.Id, tower.DishStatus)
			TriggerEvent('SonoranCAD::sonrad:SetDishStatus', tower.Id, tower.DishStatus)
			TriggerEvent('SonoranRadio::API:TowerRepaired', source, tower.Id, tower.DishStatus)
		end
	end
	SyncSonoranCadLiveMap()
end)

-- API
exports('createTower', function(config)
	local obj = shallowcopy(RadioTower)
	obj.Id = uuid()
	obj.NotPhysical = true
	for k, v in pairs(config) do
		obj[k] = v
	end
	obj.DontSaveMe = true
	obj.ApiResource = GetInvokingResource()
	table.insert(Towers, obj)
	TriggerClientEvent('RadioTower:SpawnTower', -1, obj)
	TriggerEvent('SonoranCAD::sonrad:SyncTowers', Towers)
	SyncSonoranCadLiveMap()
	DebugPrint('tower spawned by an api', obj.Id, obj.ApiResource)
	return obj.Id
end)
exports('updateTower', function(towerId, config)
	if towerId == nil then
		RegPrint('Failed to update tower, ID is nil')
		return
	end
	for i = 1, #Towers do
		if Towers[i].Id == towerId then
			DebugPrint('tower updated by an api', towerId, GetInvokingResource())
			if config == nil then
				TriggerEvent('SonoranCAD::sonrad:SyncOneTower', towerId, nil)
				TriggerClientEvent('RadioTower:SyncOneTower', -1, towerId, nil)
				table.remove(Towers, i)
			else
				for k, v in pairs(config) do
					Towers[i][k] = v
				end
				TriggerClientEvent('RadioTower:SyncOneTower', -1, towerId, Towers[i])
				TriggerEvent('SonoranCAD::sonrad:SyncOneTower', towerId, Towers[i])
			end
			SyncSonoranCadLiveMap()
			return config and Towers[i].Id or ''
		end
	end
	return nil
end)

AddEventHandler('onResourceStop', function(resource)
	local hadChange = false
	local i = 1
	while i <= #Towers do
		if Towers[i].ApiResource == resource then
			DebugPrint('removing tower after resource shutdown', Towers[i].Id)
			table.remove(Towers, i)
			hadChange = true
		else
			i = i + 1
		end
	end

	-- sync all towers with all clients
	if hadChange then
		TriggerClientEvent('RadioTower:SyncTowers', -1, Towers)
		SyncSonoranCadLiveMap()
	end
end)
