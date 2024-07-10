local acePermsForRadio = false
local acePermsForTowerRepair = false
local acePermsForServerRepair = false
local acePermsForAntennaRepair = false
local QBCore = nil
local MessageBuffer = {}
local DebugBuffer = {}
local ErrorBuffer = {}
jsonFileName = 'towers.DEFAULT.json'

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

local function CopyFile(old_path, new_path)
	local old_file = io.open(old_path, 'rb')
	local new_file = io.open(new_path, 'wb')
	if not old_file then
		print('Failed to open source file: ' .. old_path .. ' - please check your folder permissions or rename file manually.')
		return false
	end
	if not new_file then
		print('Failed to create target file: ' .. new_path .. ' - please check your folder permissions or rename file manually.')
		old_file:close()
		return false
	end

	local old_file_sz, new_file_sz
	while true do
		local block = old_file:read(2 ^ 13)
		if not block then
			old_file_sz = old_file:seek('end')
			break
		end
		new_file:write(block)
	end
	old_file:close()
	new_file_sz = new_file:seek('end')
	new_file:close()
	if new_file_sz ~= old_file_sz then
		print('File copy size mismatch')
		return false
	end
	return true
end

AddEventHandler('onResourceStart', function(resourceName)
	if (GetCurrentResourceName() ~= resourceName) then
		return
	end
	exports['sonoranradio']:performApiRequest({
		['id'] = Config.comId,
		['key'] = Config.apiKey
	}, 'SET-SERVER-IP', function(data, success)
		if not success then
			errorLog('Failed to set server IP for radio service. Please check your configuration.')
		end
	end)
	local jsonFile = LoadResourceFile(GetCurrentResourceName(), 'towers.json')
	if not jsonFile then -- Request default if there was an issue getting the regular
		jsonFile = LoadResourceFile(GetCurrentResourceName(), 'towers.DEFAULT.json')
		print('[SonoranRadio] - Using default tower locations - Please update your towers.json file name to prevent this message from appearing.')
		print('[SonoranRadio] - Attempting to rename towers.DEFAULT.json to towers.json')
		if not CopyFile(GetResourcePath(resourceName) .. '/towers.DEFAULT.json', GetResourcePath(resourceName) .. '/towers.json') then
			print('[SonoranRadio] - Failed to rename towers.DEFAULT.json to towers.json')
			jsonFileName = 'towers.DEFAULT.json'
		else
			print('[SonoranRadio] - Successfully renamed towers.DEFAULT.json to towers.json')
			jsonFileName = 'towers.json'
		end
	else
		jsonFileName = 'towers.json'
	end
	local t = LoadResourceFile(GetCurrentResourceName(), jsonFileName)
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
			obj.AntennaStatus = towers[i].AntennaStatus
			DebugPrint('setting up cell repeater', json.encode(obj))
			table.insert(CellRepeaters, obj)
		end
	end
	if Config.frames == nil or not Config.frames then
		print('!!! CRITICAL ERROR !!!')
		print('Config file not found or is outdated. Look for an updated config.CHANGEME.lua and ensure you rename it to config.lua.')
		print('!!! CRITICAL ERROR !!!')
		return
	end
end)

exports('performApiRequest', performApiRequest)
--[[
	Jordan - Radio Consolidation Update
]]

RegisterCommand('removeRadioRepeater', function(source)
	local playerCoords = GetEntityCoords(GetPlayerPed(source))
	local closestTower = nil
	local closestServerRack = nil
	local closestCellRepeater = nil
	for i = 1, #Towers do
		local distBetweenSpawn = #(playerCoords - vec3(Towers[i].PropPosition))
		if distBetweenSpawn <= 10.0 then
			closestTower = Towers[i]
			break
		end
	end
	for i = 1, #Servers do
		local distBetweenSpawn = #(playerCoords - vec3(Servers[i].PropPosition))
		if distBetweenSpawn <= 10.0 then
			closestServerRack = Servers[i]
			break
		end
	end
	for i = 1, #CellRepeaters do
		local distBetweenSpawn = #(playerCoords - vec3(CellRepeaters[i].PropPosition))
		if distBetweenSpawn <= 10.0 then
			closestCellRepeater = CellRepeaters[i]
			break
		end
	end
	local closestDist = 10.0
	local closestObj = nil
	local closestType = nil
	if closestTower ~= nil then
		local towerCoords = vec3(closestTower.PropPosition)
		local dist = #(playerCoords - towerCoords)
		if dist < closestDist then
			closestDist = dist
			closestObj = closestTower
			closestType = 'radioTower'
		end
	end
	if closestServerRack ~= nil then
		local serverRackCoords = vec3(closestServerRack.PropPosition)
		local dist = #(playerCoords - serverRackCoords)
		if dist < closestDist then
			closestDist = dist
			closestObj = closestServerRack
			closestType = 'serverRack'
		end
	end
	if closestCellRepeater ~= nil then
		local cellRepeaterCoords = vec3(closestCellRepeater.PropPosition)
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
				local towerIndex = Towers[i]
				if towerIndex.Id == closestObj.Id then
					table.remove(Towers, i)
					TriggerClientEvent('RadioTower:SyncTowers', -1, Towers)
					TriggerClientEvent('chat:addMessage', source, {
						args = {
							'[SonoranRadio] ^1Radio tower removed'
						}
					})
					break
				end
			end
		elseif closestType == 'serverRack' then
			for i = 1, #Servers do
				local towerIndex = Servers[i]
				if towerIndex.Id == closestObj.Id then
					table.remove(Servers, i)
					TriggerClientEvent('RadioRacks:SyncRacks', -1, Servers)
					TriggerClientEvent('chat:addMessage', source, {
						args = {
							'[SonoranRadio] ^1Server rack removed'
						}
					})
					break
				end
			end
		elseif closestType == 'cellRepeater' then
			for i = 1, #CellRepeaters do
				local towerIndex = CellRepeaters[i]
				if towerIndex.Id == closestObj.Id then
					table.remove(CellRepeaters, i)
					TriggerClientEvent('CellRepeater:SyncCellRepeaters', -1, CellRepeaters)
					TriggerClientEvent('chat:addMessage', source, {
						args = {
							'[SonoranRadio] ^1Cell repeater removed'
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
		local f = assert(io.open(GetResourcePath('sonoranradio') .. '/' .. jsonFileName, 'w+'))
		f:write(json.encode(saveData))
		f:close()
		print('ok')
	else
		TriggerClientEvent('chat:addMessage', source, {
			args = {
				'[SonoranRadio] ^1No radio tower, server rack, or cell repeater found.'
			}
		})
	end
end)

RegisterNetEvent('SonoranRadio::MoveProp', function(cell, towers, racks)
	local saveData = {};
	for _, t in ipairs(towers) do
		if not t.DontSaveMe then
			table.insert(saveData, t)
		end
	end
	for _, t in ipairs(racks) do
		if not t.DontSaveMe then
			table.insert(saveData, t)
		end
	end
	for _, t in ipairs(cell) do
		if not t.DontSaveMe then
			table.insert(saveData, t)
		end
	end
	local f = assert(io.open(GetResourcePath('sonoranradio') .. '/' .. jsonFileName, 'w+'))
	f:write(json.encode(saveData))
	f:close()
	print('ok')
end)

RegisterCommand('radioMenu', function(source)
	if IsPlayerAceAllowed(source, 'radio.towers') then
		TriggerClientEvent('SonoranRadio::OpenRadioMenu', source)
	else
		TriggerClientEvent('chat:addMessage', source, {
			args = {
				'[SonoranRadio] ^1You do not have permission to use this command.'
			}
		})
	end
end)

AddEventHandler('SonoranRadio::core:writeLog', function(level, message)
	if level == 'debug' then
		debugLog(message)
	elseif level == 'info' then
		infoLog(message)
	elseif level == 'error' then
		errorLog(message)
	elseif level == 'warn' then
		warnLog(message)
	else
		debugLog(message)
	end
end)

local function sendConsole(level, color, message)
	local debugging = true
	if Config ~= nil then
		debugging = (Config.debug == true and Config.debug ~= 'false')
	end
	local time = os and os.date('%X') or LocalTime()
	local info = debug.getinfo(3, 'S')
	local source = '.'
	if info.source:find('@@sonoranradio') then
		source = info.source:gsub('@@sonoranradio/', '') .. ':' .. info.linedefined
	end
	local msg = ('[%s][%s:%s%s^7]%s %s^0'):format(time, debugging and source or 'SonoranRadio', color, level, color, message)
	if (debugging and level == 'DEBUG') or (not debugging and level ~= 'DEBUG') or level == 'ERROR' or level == 'WARNING' or level == 'INFO' then
		print(msg)
	end
	if (level == 'ERROR' or level == 'WARNING') and IsDuplicityVersion() then
		table.insert(ErrorBuffer, 1, msg)
	end
	if level == 'DEBUG' and IsDuplicityVersion() then
		if #DebugBuffer > 50 then
			table.remove(DebugBuffer)
		end
		table.insert(DebugBuffer, 1, msg)
	else
		if not IsDuplicityVersion() then
			if #MessageBuffer > 10 then
				table.remove(MessageBuffer)
			end
			table.insert(MessageBuffer, 1, msg)
		end
	end
end

function debugLog(message)
	sendConsole('DEBUG', '^7', message)
end

local ErrorCodes = {
	['INVALID_COMMUNITY_ID'] = 'You have set an invalid community ID, please check your Config and SonoranCMS integration'
}

function logError(err, msg)
	local o = ''
	if msg == nil then
		o = ('ERR %s: %s - See https://sonoran.software/errorcodes for more information.'):format(err, ErrorCodes[err])
	else
		o = ('ERR %s: %s - See https://sonoran.software/errorcodes for more information.'):format(err, msg)
	end
	sendConsole('ERROR', '^1', o)
end

function errorLog(message)
	sendConsole('ERROR', '^1', message)
end

function warnLog(message)
	sendConsole('WARNING', '^3', message)
end

function infoLog(message)
	sendConsole('INFO', '^5', message)
end
