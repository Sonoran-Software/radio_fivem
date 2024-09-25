RadioRacks = {
	-- whether the rack can be destroyed or not
	Destruction = true,
	NotPhysical = false,
	Swankiness = 0.0,
	-- the rack's position (vec3)
	PropPosition = nil,
	-- the range of the rack
	Range = 1500.0,
	serverStatus = {},
	Powered = true,
	DontSaveMe = false,
	heading = 0.0,
	type = 'serverRack'
}

Servers = {}
function GetRack(coords)
	for i = 1, #Servers do
		if Servers[i].PropPosition == coords then
			return Servers[i], i
		end
	end
	return nil, nil
end
function GetServerFromId(id)
	for _, t in ipairs(Servers) do
		if t.Id == id then
			return t
		end
	end
end

AddEventHandler('SonoranScripts::PowerGrid::RegisterNewDevice', function(coords, entityID, requestID)
	print('SONRAD REGISTER')
	for _, v in pairs(Servers) do
		DebugPrint(('coords: ' .. v.PropPosition))
		local dist = #(v.PropPosition.xy - coords.xy)
		DebugPrint('dist: ' .. dist)
		DebugPrint(tostring(entityId))
		if dist < 10 then
			TriggerEvent('SonoranScripts::PowerGrid::NewDevice', v.Id, 'radioServerRack', requestID)
		end
	end
end)

RegisterNetEvent('SonoranScripts::PowerGrid::DeviceDisabled')
AddEventHandler('SonoranScripts::PowerGrid::DeviceDisabled', function(affectedDevices)
	DebugPrint('SONRAD DISABLED ' .. json.encode(affectedDevices))
	for _, v in pairs(affectedDevices['radioServerRack']) do
		local rack = GetServerFromId(v)
		DebugPrint(json.encode(rack))
		rack.Powered = false
		for i = 1, #rack.serverStatus do
			rack.serverStatus[i] = 'dead'
		end
		TriggerClientEvent('RadioRacks:SetServerStatus', -1, v, rack.serverStatus)
		TriggerEvent('SonoranCAD::sonrad:SetserverStatus', v, rack.serverStatus)
	end
	-- TriggerClientEvent("RadioRacks:SyncRacks", source, Servers)
	-- TriggerEvent("SonoranCAD::sonrad:SyncServers", Servers)

end)

RegisterNetEvent('SonoranScripts::PowerGrid::DeviceRepaired')
AddEventHandler('SonoranScripts::PowerGrid::DeviceRepaired', function(affectedDevices)
	DebugPrint('SONRAD REPAIRED ' .. json.encode(affectedDevices))
	for _, v in pairs(affectedDevices['radioServerRack']) do
		local rack = GetServerFromId(v)
		rack.Powered = true
		for i = 1, #rack.serverStatus do
			rack.serverStatus[i] = 'alive'
		end
		TriggerClientEvent('RadioRacks:SetServerStatus', -1, v, rack.serverStatus)
		TriggerEvent('SonoranCAD::sonrad:SetserverStatus', v, rack.serverStatus)
	end
	-- TriggerClientEvent("RadioRacks:SyncRacks", source, Servers)
	-- TriggerEvent("SonoranCAD::sonrad:SyncServers", Servers)
end)

-- RegisterCommand('removeServers', function()
-- 	TriggerClientEvent('RadioRacks:Shutdown', -1)
-- 	Servers = {}
-- end, true)

-- RegisterCommand('saveServers', function()
-- 	local saveServers = {}
-- 	for _, t in ipairs(Servers) do
-- 		if not t.DontSaveMe then
-- 			table.insert(saveServers, t)
-- 		end
-- 	end
-- 	local f = assert(io.open(GetResourcePath('sonoranradio') .. '/servers.json', 'w+'))
-- 	f:write(json.encode(saveServers))
-- 	f:close()
-- 	print('ok')
-- end, true)

-- RegisterCommand('spawnRadioRack', function(source, args)
--     if #args < 1 then
--         return TriggerClientEvent('chat:addMessage', source, {args = {'^1Usage: /spawnRack <numberOfServers>'}})
--     end
--     if not tonumber(args[1]) then
--         return TriggerClientEvent('chat:addMessage', source, {args = {'^1Usage: /spawnRack <numberOfServers>'}})
--     end
-- 	if tonumber(args[1]) > 5 then
-- 		return TriggerClientEvent('chat:addMessage', source, {args = {'^1You can only spawn up to 5 servers at a time.'}})
-- 	end
--     local serverCount = tonumber(args[1])
-- 	local coords = GetEntityCoords(GetPlayerPed(source))
-- 	local rack = shallowcopy(RadioRacks)
--     for i = 1, serverCount do
--         table.insert(rack.serverStatus, 'alive')
--     end
-- 	rack.Id = uuid()
-- 	rack.PropPosition = coords
-- 	rack.heading = GetEntityHeading(GetPlayerPed(source))
-- 	table.insert(Servers, rack)
-- 	TriggerClientEvent('RadioRacks:SpawnRack', -1, rack)
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

RegisterNetEvent('RadioRacks:clientRackSync')
AddEventHandler('RadioRacks:clientRackSync', function()
	local source = source
	while #Servers == 0 do
		Wait(10)
	end
	local sonoradData = {}
	TriggerClientEvent('RadioRacks:SyncRacks', source, Servers)
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
RegisterNetEvent('RadioRacks:Destroy')
AddEventHandler('RadioRacks:Destroy', function(coords)
	local handshake = uuid()
	DestroyRequests[source] = {
		coords = coords,
		secret = handshake
	}
	TriggerClientEvent('RadioRacks:VerifyLocation', source, handshake)
end)

RegisterNetEvent('RadioRacks:KillServer')
AddEventHandler('RadioRacks:KillServer', function(towerId, dishIndex)
	local rack = GetServerFromId(towerId)
	DebugPrint('RadioRacks:KillServer', towerId, dishIndex)
	if not rack then
		return
	end

	rack.serverStatus[dishIndex] = 'dead'
	TriggerClientEvent('RadioRacks:SetServerStatus', -1, towerId, rack.serverStatus)
	TriggerEvent('SonoranCAD::sonrad:SetserverStatus', towerId, rack.serverStatus)
end)

RegisterNetEvent('RadioRacks:RepairRack')
AddEventHandler('RadioRacks:RepairRack', function(towerId)
	local rack = GetServerFromId(towerId)
	DebugPrint('RadioRacks:RepairRack', towerId)
	if not rack then
		return
	end

	for i = 1, #rack.serverStatus do
		rack.serverStatus[i] = 'alive'
	end
	TriggerClientEvent('RadioRacks:SetServerStatus', -1, towerId, rack.serverStatus)
	TriggerEvent('SonoranCAD::sonrad:SetserverStatus', towerId, rack.serverStatus)
end)

RegisterNetEvent('RadioRacks:clientLocationVerify')
AddEventHandler('RadioRacks:clientLocationVerify', function(coords, handshake)
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
		local rack, idx = GetRack(dist2)
		if not rack then
			print('ERR: no rack found')
			return
		end
		rack.Destruction = true
		rack.DestructionTimer = GetGameTimer()
		Servers[idx] = rack
		TriggerClientEvent('RadioRacks:SyncRacks', -1, Servers)
		TriggerClientEvent('RadioRacks:DestroyedRack', source, dist2)
	end
end)

-- API
exports('createRack', function(config)
	local obj = shallowcopy(RadioRacks)
	obj.Id = uuid()
	obj.NotPhysical = true
	for k, v in pairs(config) do
		obj[k] = v
	end
	obj.DontSaveMe = true
	obj.ApiResource = GetInvokingResource()
	table.insert(Servers, obj)
	TriggerClientEvent('RadioRacks:SpawnRack', -1, obj)
	TriggerEvent('SonoranCAD::sonrad:SyncServers', Servers)
	DebugPrint('rack spawned by an api', obj.Id, obj.ApiResource)
	return obj.Id
end)
exports('updateRack', function(towerId, config)
	for i = 1, #Servers do
		if Servers[i].Id == towerId then
			DebugPrint('rack updated by an api', towerId, GetInvokingResource())
			if config == nil then
				TriggerEvent('SonoranCAD::sonrad:SyncOneRack', towerId, nil)
				TriggerClientEvent('RadioRacks:SyncOneRack', -1, towerId, nil)
				table.remove(Servers, i)
			else
				for k, v in pairs(config) do
					Servers[i][k] = v
				end
				TriggerClientEvent('RadioRacks:SyncOneRack', -1, towerId, Servers[i])
				TriggerEvent('SonoranCAD::sonrad:SyncOneRack', towerId, Servers[i])
			end
			return config and Servers[i].Id or ''
		end
	end
	return nil
end)

AddEventHandler('onResourceStop', function(resource)
	local hadChange = false
	local i = 1
	while i <= #Servers do
		if Servers[i].ApiResource == resource then
			DebugPrint('removing rack after resource shutdown', Servers[i].Id)
			table.remove(Servers, i)
			hadChange = true
		else
			i = i + 1
		end
	end

	-- sync all Servers with all clients
	if hadChange then
		TriggerClientEvent('RadioRacks:SyncRacks', -1, Servers)
	end
end)
