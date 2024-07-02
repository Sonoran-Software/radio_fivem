local acePermsForRadio = false
local acePermsForTowerRepair = false
local acePermsForServerRepair = false
local acePermsForAntennaRepair = false
local QBCore = nil

if Config == nil then
	print('!!! CRITICAL ERROR !!!')
	print('Config file not found, did you forget to rename it?')
	print('!!! CRITICAL ERROR !!!')
else
	if Config.acePermsForRadio ~= nil then
		acePermsForRadio = Config.acePermsForRadio
	end

	if Config.acePermsForTowerRepair ~= nil then
		acePermsForTowerRepair = Config.acePermsForTowerRepair
	end

	if Config.acePermsForServerRepair ~= nil then
		acePermsForServerRepair = Config.acePermsForServerRepair
	end

	if Config.enforceRadioItem then
		QBCore = exports['qb-core']:GetCoreObject()
		exports['qb-core']:AddItem('sonoran_radio', {
			name = 'sonoran_radio',
			label = 'Sonoran Radio',
			weight = 10,
			type = 'item',
			image = 'radio.png',
			unique = true,
			useable = true,
			shouldClose = true,
			combinable = false,
			description = 'Communicate with others through the Sonoran Radio'
		})
		QBCore.Functions.CreateUseableItem('sonoran_radio', function(source, item)
			local src = source
			local Player = QBCore.Functions.GetPlayer(src)
			local radio = Player.Functions.GetItemByName('sonoran_radio')
			if not radio then
				return
			end
			if not radio.info.frame then
				TriggerClientEvent('qb-sonrad:use', source, 'default')
			else
				TriggerClientEvent('qb-sonrad:use', source, item.info.frame)
			end
		end)

		QBCore.Functions.CreateCallback('qb-sonrad:server:GetItem', function(source, cb, item)
			local src = source
			local Player = QBCore.Functions.GetPlayer(src)
			if Player ~= nil then
				local RadioItem = Player.Functions.GetItemByName(item)
				if RadioItem ~= nil and not Player.PlayerData.metadata['isdead'] and not Player.PlayerData.metadata['inlaststand'] then
					cb(true)
				else
					cb(false)
				end
			else
				cb(false)
			end
		end)
	end
end

RegisterCommand('sradio', function(source, args, rawCommands)
	if source ~= 0 then
		print('This command can only be used from console.')
		return
	end
	if not args[1] then
		print('Missing command. Try "sradio help" fro help.')
		return
	end
	if args[1] == 'help' then
		print([[
SonoranRadio Help
    help - shows this message
    update - attempt to update the radio script
]])
	elseif args[1] == 'update' then
		print('Attempting to auto update...')
		RunAutoUpdater(true)
	else
		print('Missing command. Try \"sradio help\" for help.')
	end
end, true)

RegisterNetEvent('SonoranRadio::CheckPermissions')
AddEventHandler('SonoranRadio::CheckPermissions', function()
	local framePermissions = checkFramePermissions(source)
	if acePermsForRadio then
		if IsPlayerAceAllowed(source, 'sonoranradio.use') then
			TriggerClientEvent('SonoranRadio::AuthorizeRadio', source, framePermissions)
		end
	else
		TriggerClientEvent('SonoranRadio::AuthorizeRadio', source, framePermissions)
	end
	if acePermsForTowerRepair then
		if IsPlayerAceAllowed(source, 'sonoranradio.repair') then
			TriggerClientEvent('SonoranRadio::AuthorizeTowers', source)
		end
	else
		TriggerClientEvent('SonoranRadio::AuthorizeTowers', source)
	end
	if acePermsForServerRepair then
		if IsPlayerAceAllowed(source, 'sonoranradio.repairservers') then
			TriggerClientEvent('SonoranRadio::AuthorizeRacks', source)
		end
	else
		TriggerClientEvent('SonoranRadio::AuthorizeRacks', source)
	end
	if acePermsForAntennaRepair then
		if IsPlayerAceAllowed(source, 'sonoranradio.repair') then
			TriggerClientEvent('SonoranRadio::AuthorizeAntennas', source)
		end
	else
		TriggerClientEvent('SonoranRadio::AuthorizeAntennas', source)
	end
end)

local radios = {}

RegisterNetEvent('SonoranRadio::RadioPower')
AddEventHandler('SonoranRadio::RadioPower', function(power, playername)
	local src = source
	if power then
		radios[tonumber(src)] = {
			id = src,
			name = playername
		}
	else
		radios[tonumber(src)] = nil
	end
	TriggerClientEvent('SonoranRadio::GetRadios:Return', -1, radios)
end)

RegisterNetEvent('SonoranRadio::Msg:ToServer')
AddEventHandler('SonoranRadio::Msg:ToServer', function(recipient, payload)
	local sender = source
	TriggerClientEvent('SonoranRadio::Msg:ToClient', recipient, sender, payload)
end)

function validFrame(frame)
	for _, department in pairs(Config.frames.departments) do
		for _, allowedFrame in ipairs(department.allowedFrames or {}) do
			if allowedFrame == frame then
				return true
			end
		end
	end
	return false
end

RegisterCommand('adminskinchange', function(source, args, rawCommand)
	if IsPlayerAceAllowed(source, 'sonoranradio.admin') then
		local validFrames = {};
		for _, department in pairs(Config.frames.departments) do
			for _, frame in ipairs(department.allowedFrames or {}) do
				table.insert(validFrames, frame)
			end
		end
		if not validFrame(args[1]) then
			TriggerClientEvent('chat:addMessage', source, {
				args = {
					'^1SonoranRadio',
					'Invalid frame name. Valid frames are: ' .. table.concat(validFrames, ', ')
				}
			})
		else
			TriggerClientEvent('SonoranRadio::AdminSkinChange', source, args[1])
		end
	else
		TriggerClientEvent('chat:addMessage', source, {
			args = {
				'^1SonoranRadio',
				'You do not have permission to use this command.'
			}
		})
	end
end)

RegisterNetEvent('SonoranRadio::AdminSkinChange_s', function(newFrame)
	if Config.enforceRadioItem then
		local QBCore = exports['qb-core']:GetCoreObject()
		local Player = QBCore.Functions.GetPlayer(source)
		local radio = Player.Functions.GetItemByName('sonoran_radio')
		if radio ~= nil then
			local radioSlot = radio.slot
			Player.Functions.RemoveItem('sonoran_radio', 1, radioSlot)
			Player.Functions.AddItem('sonoran_radio', 1, radioSlot, {
				frame = newFrame
			})
		end
	end
end)

AddEventHandler('onResourceStart', function(resourceName)
	if (GetCurrentResourceName() ~= resourceName) then
		return
	end
	if Config.frames == nil or not Config.frames then
		print('!!! CRITICAL ERROR !!!')
		print('Config file not found or is outdated. Look for an updated config.CHANGEME.lua and ensure you rename it to config.lua.')
		print('!!! CRITICAL ERROR !!!')
		return
	end
end)

--[[
	Jordan - Radio Consolidation Update
]]

AddEventHandler('onResourceStart', function(resource)
	if GetCurrentResourceName() ~= resource then
		return
	end
	local t = LoadResourceFile(GetCurrentResourceName(), 'towers.json')
	local towers = json.decode(t)
	for i = 1, #towers do
		if towers[i].type == 'radioTower' then
			local obj = shallowcopy(RadioTower)
			if towers[i].Id == nil then
				obj.Id = uuid()
			else
				obj.Id = towers[i].Id
			end
			-- obj.Id = uuid()
			obj.PropPosition = vec3(towers[i].PropPosition.x, towers[i].PropPosition.y, towers[i].PropPosition.z)
			obj.Swankiness = towers[i].Swankiness
			obj.Range = towers[i].Range
			obj.Destruction = towers[i].Destruction

			DebugPrint('setting up tower', json.encode(obj))
			table.insert(Towers, obj)
		elseif towers[i].type == 'serverRack' then
			local obj = shallowcopy(RadioRacks)
			if towers[i].Id == nil then
				obj.Id = uuid()
			else
				obj.Id = towers[i].Id
			end
			-- obj.Id = uuid()
			obj.PropPosition = vec3(towers[i].PropPosition.x, towers[i].PropPosition.y, towers[i].PropPosition.z)
			obj.Swankiness = towers[i].Swankiness
			obj.Range = towers[i].Range
			obj.Destruction = towers[i].Destruction
			obj.serverStatus = towers[i].serverStatus
			obj.heading = towers[i].heading
			DebugPrint('setting up rack', json.encode(obj))
			table.insert(Servers, obj)
		elseif towers[i].type == 'cellRepeater' then
			local obj = shallowcopy(CellRepeaters)
			if towers[i].Id == nil then
				obj.Id = uuid()
			else
				obj.Id = towers[i].Id
			end
			-- obj.Id = uuid()
			obj.PropPosition = vec3(towers[i].PropPosition.x, towers[i].PropPosition.y, towers[i].PropPosition.z)
			obj.heading = towers[i].heading
			obj.Swankiness = towers[i].Swankiness
			obj.Range = towers[i].Range
			obj.Destruction = towers[i].Destruction

			DebugPrint('setting up cell repeater', json.encode(obj))
			table.insert(CellRepeaters, obj)
		end
	end
end)

RegisterCommand('removeRadioTower', function()
	local playerCoords = GetEntityCoords(GetPlayerPed(-1))
	local closestTower = GetClosestObjectOfType(playerCoords, 10.0, GetHashKey('prop_radio_tower'), false, false, false)
	local closestServerRack = GetClosestObjectOfType(playerCoords, 10.0, GetHashKey('serverrack'), false, false, false)
	local closestCellRepeater = GetClosestObjectOfType(playerCoords, 10.0, GetHashKey('mobilecell'), false, false, false)

	local closestDist = 10.0
	local closestObj = nil
	local closestType = nil

	if closestTower ~= 0 then
		local towerCoords = GetEntityCoords(closestTower)
		local dist = #(playerCoords - towerCoords)
		if dist < closestDist then
			closestDist = dist
			closestObj = closestTower
			closestType = 'radioTower'
		end
	end
	if closestServerRack ~= 0 then
		local serverRackCoords = GetEntityCoords(closestServerRack)
		local dist = #(playerCoords - serverRackCoords)
		if dist < closestDist then
			closestDist = dist
			closestObj = closestServerRack
			closestType = 'serverRack'
		end
	end
	if closestCellRepeater ~= 0 then
		local cellRepeaterCoords = GetEntityCoords(closestCellRepeater)
		local dist = #(playerCoords - cellRepeaterCoords)
		if dist < closestDist then
			closestDist = dist
			closestObj = closestCellRepeater
			closestType = 'cellRepeater'
		end
	end
	if closestObj ~= nil then
		if closestType == 'radioTower' then
			for i = 1, #Towers do
				local distBetweenSpawn = #(GetEntityCoords(closestObj) - vec3(Towers[i].PropPosition))
				if distBetweenSpawn <= 0.5 then
					table.remove(Towers, i)
					TriggerClientEvent('RadioTower:SyncTowers', -1, Towers)
					TriggerClientEvent('chat:addMessage', source, {
						args = {
							'^1Radio tower removed'
						}
					})
					break
				end
			end
		elseif closestType == 'serverRack' then
			for i = 1, #Servers do
				local distBetweenSpawn = #(GetEntityCoords(closestObj) - vec3(Servers[i].PropPosition))
				if distBetweenSpawn <= 0.5 then
					table.remove(Servers, i)
					TriggerClientEvent('RadioRacks:SyncRacks', -1, Servers)
					TriggerClientEvent('chat:addMessage', source, {
						args = {
							'^1Server rack removed'
						}
					})
					break
				end
			end
		elseif closestType == 'cellRepeater' then
			for i = 1, #CellRepeaters do
				local distBetweenSpawn = #(GetEntityCoords(closestObj) - vec3(CellRepeaters[i].PropPosition))
				if distBetweenSpawn <= 0.5 then
					table.remove(CellRepeaters, i)
					TriggerClientEvent('CellRepeater:SyncCellRepeaters', -1, CellRepeaters)
					TriggerClientEvent('chat:addMessage', source, {
						args = {
							'^1Cell repeater removed'
						}
					})
					break
				end
			end
		end
		local saveData = {};
		for _, t in ipairs(Towers) do
			if not t.DontSaveMe then
				table.insert(saveData, t)
			end
		end
		for _, t in ipairs(Servers) do
			if not t.DontSaveMe then
				table.insert(saveData, t)
			end
		end
		for _, t in ipairs(CellRepeaters) do
			if not t.DontSaveMe then
				table.insert(saveData, t)
			end
		end
		local f = assert(io.open(GetResourcePath('sonoranradio') .. '/towers.json', 'w+'))
		f:write(json.encode(saveData))
		f:close()
		print('ok')
	else
		TriggerClientEvent('chat:addMessage', source, {
			args = {
				'^1No radio tower, server rack, or cell repeater found.'
			}
		})
	end
end)
