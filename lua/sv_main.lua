local acePermsForRadio = false
local acePermsForTowerRepair = false
local acePermsForServerRepair = false
local acePermsForAntennaRepair = false
local QBCore = nil
local MessageBuffer = {}
local DebugBuffer = {}
local ErrorBuffer = {}
local tunnels = {}
scanners = {}
local critError = false
jsonFileName = 'towers.DEFAULT.json'
polyZoneFileName = 'tunnels.DEFAULT.json'
speakersFileName = 'speakers.DEFAULT.json'
chatterFileName = 'earpieces.json'
chatterConfig = {}
local clientConfig = {}

if type(Config) ~= 'table' then
	critError = true
	print('^1!!! CRITICAL ERROR !!!^7')
	print('Sonoran Radio configuration not found! Possible reasons:')
	print('1. You have not renamed config.CHANGEME.lua to config.lua')
	print('2. You have made a syntax error in your config.lua file')
	print('^1!!! CRITICAL ERROR !!!^7')
else
	for k, v in pairs(Config) do
		if k ~= "apiKey" then
			clientConfig[k] = v
		end
	end
	RegisterNetEvent('SonoranRadio::core::RequestEnvironment', function()
		TriggerClientEvent('SonoranRadio::core::ReceiveEnvironment', source, clientConfig)
	end)
	if not IsDuplicityVersion() then
		RegisterNetEvent('SonoranRadio::API:PlayerDeath', function(playerid)
			TriggerEvent('SonoranRadio::PlayerDeath') -- This event will kill the player
		end)
		RegisterNetEvent('SonoranRadio::API:PlayerRevive', function(playerid)
			TriggerEvent('SonoranRadio::PlayerRevive') -- This event will revive the player
		end)
	end
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
		getFramework()
		getInventory()
		if frameworkEnum == 1 then
			QBCore = exports['qb-core']:GetCoreObject()

			if Config.RadioItem == nil then
				errorLog('Radio item is enforced but no item is defined. Please update your configuration. Using default item variables.')
				Config.RadioItem = {
					name = 'sonoran_radio',
					label = 'Sonoran Radio',
					weight = 1,
					description = 'Communicate with others through the Sonoran Radio',
				}
			end
			exports['qb-core']:AddItem(Config.RadioItem.name, {
				name = Config.RadioItem.name,
				label = Config.RadioItem.label,
				weight = Config.RadioItem.weight,
				type = 'item',
				image = 'radio.png',
				unique = true,
				useable = true,
				shouldClose = true,
				combinable = false,
				description = Config.RadioItem.description,
			})
			QBCore.Functions.CreateUseableItem(Config.RadioItem.name, function(source, item)
				local src = source
				local Player = QBCore.Functions.GetPlayer(src)
				local radio = nil
				if type(Player.Functions.GetItemByName) == 'table' then
					radio = Player.Functions.GetItemByName(Config.RadioItem.name)
				elseif type(Player.Functions.HasItem) == 'table' then
					radio = Player.Functions.HasItem(Config.RadioItem.name)
				end
				if not radio then
					return
				end
				if not radio.info.frame then
					TriggerClientEvent('qb-sonrad:use', source, 'default')
				else
					TriggerClientEvent('qb-sonrad:use', source, item.info.frame)
				end
			end)

			if Config.ScannerItem == nil then
				errorLog('Scanner item is enforced but no item is defined. Please update your configuration. Using default item variables.')
				Config.ScannerItem = {
					name = 'sonoran_radio_scanner', -- Item ID
					label = 'Sonoran Radio Scanner', -- Label for the item in your inventory
					weight = 1, -- Weight of the item in your inventory
					description = 'Listen to radio chatter with the Sonoran Radio Scanner', -- Description of the item in your inventory
				}
			end
			exports['qb-core']:AddItem(Config.ScannerItem.name, {
				name = Config.ScannerItem.name,
				label = Config.ScannerItem.label,
				weight = Config.ScannerItem.weight,
				type = 'item',
				image = 'radio.png',
				unique = true,
				useable = true,
				shouldClose = true,
				combinable = false,
				description = Config.ScannerItem.description,
			})
			QBCore.Functions.CreateUseableItem(Config.ScannerItem.name, function(source, item)
				local src = source
				local Player = QBCore.Functions.GetPlayer(src)
				TriggerClientEvent('qb-sonrad:use-scanner', source)
			end)
		elseif frameworkEnum == 2 then
			if Config.RadioItem == nil then
				errorLog('Radio item is enforced but no item is defined. Please update your configuration. Using default item variables.')
				Config.RadioItem = {
					name = 'sonoran_radio',
					label = 'Sonoran Radio',
					weight = 1,
					description = 'Communicate with others through the Sonoran Radio',
				}
			end
			if not exports.ox_inventory:Items(Config.RadioItem.name) then
				errorLog('Ox_Inventory detected on Qbox, ' .. Config.RadioItem.name .. ' could not be found, please ensure you have added it to your /ox_inventory/data/items.lua')
				return
			end
			if not exports.ox_inventory:Items(Config.ScannerItem.name) then
				errorLog('Ox_Inventory detected on Qbox, ' .. Config.ScannerItem.name .. ' could not be found, please ensure you have added it to your /ox_inventory/data/items.lua')
				return
			end
			exports.qbx_core:CreateUseableItem(Config.RadioItem.name, function(source, item)
				local src = source
				local radio = exports.ox_inventory:GetSlotIdWithItem(src, Config.RadioItem.name, {}, false)
				if not radio then
					return
				end
				local itemSlot = exports.ox_inventory:GetSlot(src, radio)
				if not itemSlot.metadata.frame then
					TriggerClientEvent('qb-sonrad:use', source, 'default')
				else
					TriggerClientEvent('qb-sonrad:use', source, itemSlot.metadata.frame)
				end
			end)

			if Config.ScannerItem == nil then
				errorLog('Scanner item is enforced but no item is defined. Please update your configuration. Using default item variables.')
				Config.ScannerItem = {
					name = 'sonoran_radio_scanner', -- Item ID
					label = 'Sonoran Radio Scanner', -- Label for the item in your inventory
					weight = 1, -- Weight of the item in your inventory
					description = 'Listen to radio chatter with the Sonoran Radio Scanner', -- Description of the item in your inventory
				}
			end
			exports.qbx_core:CreateUseableItem(Config.ScannerItem.name, function(source, item)
				TriggerClientEvent('qb-sonrad:use-scanner', source)
			end)
		end
		RegisterNetEvent('SonoranRadio::RemoveDrop::Scanner', function(scanner)
			for k, v in pairs(scanners) do
				if v.dropId == scanner.dropId then
					table.remove(scanners, k)
				end
			end
		end)

		if inventoryEnum == 2 then
			if not lib then
				local chunk = LoadResourceFile('ox_lib', 'init.lua')

				if not chunk then
					errorLog('failed to load resource file @ox_lib/init.lua', 0)
				end

				load(chunk, '@@ox_lib/init.lua', 't')()
			end
			lib.callback.register('getScanners', function(source)
				return scanners
			end)
		end
	end
end

RegisterCommand('sonoranradio', function(source, args, rawCommands)
	if source ~= 0 then
        print("This command can only be used from the server console")
		return
	end
	if not args[1] then
		print('Missing command. Try "sonoranradio help" for help.')
		return
	end
	if args[1] == 'help' then
		print([[
SonoranRadio Help
    help - shows this message
	debugmode - Toggles debugging mode
    update - attempt to update the radio script
]])
	elseif args[1] == 'update' then
		print('Attempting to auto update...')
		RunAutoUpdater(true)
	elseif args[1] == "debugmode" then
        Config.debug = not Config.debug
		TriggerClientEvent('SonoranRadio::core::DebugMode', -1 , Config.debug)
        infoLog(("Debug mode toggled to %s"):format(tostring(Config.debug)))
	else
		print('Missing command. Try \"sonoranradio help\" for help.')
	end
end, true)

RegisterNetEvent('SonoranRadio::CheckPermissions')
AddEventHandler('SonoranRadio::CheckPermissions', function()
	local framePermissions = checkFramePermissions(source)
	local allowedMiniRadio = false
	if Config.acePermsForRadioUsers then
		if IsPlayerAceAllowed(source, 'sonoranradio.miniradio') then
			allowedMiniRadio = true
		end
	else
		allowedMiniRadio = true
	end
	local radioAceAllowed = not Config.acePermsForRadio or IsPlayerAceAllowed(source, 'sonoranradio.use')
	if radioAceAllowed then
		TriggerClientEvent('SonoranRadio::AuthorizeRadio', source, framePermissions, allowedMiniRadio)
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
	local scannerAceAllowed = not Config.acePermsForScanners or IsPlayerAceAllowed(source, 'sonoranradio.scanner')
	if scannerAceAllowed then
		TriggerClientEvent('SonoranRadio::AuthorizeScanners', source)
	end
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
		local Player = nil
		if frameworkEnum == 1 then
			local QBCore = exports['qb-core']:GetCoreObject()
			Player = QBCore.Functions.GetPlayer(source)
		elseif frameworkEnum == 2 then
			Player = exports.qbx_core:GetPlayer(source)
		end

		if not Player then
			return
		end

		local radio = nil
		local radioSlot = nil

		if inventoryEnum == 1 then
			if type(Player.Functions.GetItemByName) == 'function' then
				radio = Player.Functions.GetItemByName(Config.RadioItem.name)
			elseif type(Player.Functions.HasItem) == 'function' then
				radio = Player.Functions.HasItem(Config.RadioItem.name)
			end

			if radio then
				radioSlot = radio.slot
				Player.Functions.RemoveItem(Config.RadioItem.name, 1, radioSlot)
				Player.Functions.AddItem(Config.RadioItem.name, 1, radioSlot, {
					frame = newFrame
				})
			end
		elseif inventoryEnum == 2 then
			local inv = exports.ox_inventory:GetInventory(source) or {}
			for _, item in ipairs(inv) do
				if item.name == Config.RadioItem.name then
					radio = item
					radioSlot = item.slot
					break
				end
			end

			if radio then
				exports.ox_inventory:RemoveItem(source, Config.RadioItem.name, 1, radioSlot)
				exports.ox_inventory:AddItem(source, Config.RadioItem.name, 1, radioSlot, {
					frame = newFrame
				})
			end
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
	getInventory()
	getFramework()
	if critError or not Config or not Config.apiKey or not Config.comId then
		errorLog('API Key or Community ID not set. Please check your configuration.')
		critError = true
		return
	end
	local baseUrl = ""
	local waitTime = 15000
	local retryCount = 0
	Citizen.CreateThread(function()
		while retryCount <= 5 do
			Wait(waitTime)
			if GetConvar('web_baseUrl', '') ~= '' then
				baseUrl = GetConvar('web_baseUrl', '')
			end
			if baseUrl == "" then
				retryCount = retryCount + 1
				if retryCount >= 2 then
					errorLog('ERR 101: Unable to get webBaseURL (CFX Nucleus Proxy URL) on attempt '.. tostring(retryCount) .. '. Radio will be unable to receive push events. https://sonoran.link/radiocodes')
					if retryCount >= 5 then
						errorLog('ERR 101: Maximum retries reached. Please ensure your CFX Nucleus Proxy URL is set correctly. Radio will be unable to receive push events. https://sonoran.link/radiocodes')
						return
					else
						waitTime = waitTime * 2
						print('[SonoranRadio] - Retrying in ' .. tostring(waitTime/1000) .. ' seconds...')
					end
				end
			else
				retryCount = 6
				print('[SonoranRadio] - Attempting to set server IP for radio service... ' .. 'https://'.. baseUrl .. '/sonoranradio/events')
				exports['sonoranradio']:performApiRequest({
					['id'] = Config.comId,
					['key'] = Config.apiKey,
					['pushUrl'] = 'https://'.. baseUrl .. '/sonoranradio/events'
				}, 'SET-SERVER-IP', function(data, success)
					if not success then
						errorLog('Failed to set server IP for radio service. Please check your configuration.')
					end
				end)
			end
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
			obj.heading = towers[i].heading or 0.0

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
			obj.heading = towers[i].heading or 0.0
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
			obj.heading = towers[i].heading or 0.0
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
	local polyZoneFile = LoadResourceFile(GetCurrentResourceName(), 'tunnels.json')
	if not polyZoneFile then -- Request default if there was an issue getting the regular
		polyZoneFile = LoadResourceFile(GetCurrentResourceName(), 'tunnels.DEFAULT.json')
		print('[SonoranRadio] - Using default tunnel locations - Please update your tunnels.json file name to prevent this message from appearing.')
		print('[SonoranRadio] - Attempting to rename tunnels.DEFAULT.json to tunnels.json')
		if not CopyFile(GetResourcePath(resourceName) .. '/tunnels.DEFAULT.json', GetResourcePath(resourceName) .. '/tunnels.json') then
			print('[SonoranRadio] - Failed to rename tunnels.DEFAULT.json to tunnels.json')
			polyZoneFileName = 'tunnels.DEFAULT.json'
		else
			print('[SonoranRadio] - Successfully renamed tunnels.DEFAULT.json to tunnels.json')
			polyZoneFileName = 'tunnels.json'
		end
	else
		polyZoneFileName = 'tunnels.json'
	end
	local polyZones = LoadResourceFile(GetCurrentResourceName(), polyZoneFileName)
	local tnl = json.decode(polyZones)
	for i = 1, #tnl do
		local obj = {}
		obj.points = tnl[i].points
		obj.options = {
			minZ = tnl[i].options.minZ,
			maxZ = tnl[i].options.maxZ,
			degradeStrength = tnl[i].options.degradeStrength,
			name = tnl[i].options.name
		}
		table.insert(tunnels, obj)
	end
	local speakersFile = LoadResourceFile(GetCurrentResourceName(), 'speakers.json')
	if not speakersFile then
		speakersFile = LoadResourceFile(GetCurrentResourceName(), 'speakers.DEFAULT.json')
		print('[SonoranRadio] - Using default tunnel locations - Please update your speakers.json file name to prevent this message from appearing.')
		print('[SonoranRadio] - Attempting to rename speakers.DEFAULT.json to speakers.json')
		if not CopyFile(GetResourcePath(resourceName) .. '/speakers.DEFAULT.json', GetResourcePath(resourceName) .. '/speakers.json') then
			print('[SonoranRadio] - Failed to rename speakers.DEFAULT.json to speakers.json')
			speakersFileName = 'speakers.DEFAULT.json'
		else
			print('[SonoranRadio] - Successfully renamed speakers.DEFAULT.json to speakers.json')
			speakersFileName = 'speakers.json'
		end
	else
		speakersFileName = 'speakers.json'
	end
	local spk = LoadResourceFile(GetCurrentResourceName(), speakersFileName)
	local spkrs = json.decode(spk)
	for i = 1, #spkrs do
		local obj = {}
		if spkrs[i].Id == nil then
			obj.Id = uuid()
		else
			obj.Id = spkrs[i].Id
		end
		obj.PropPosition = vec3(spkrs[i].PropPosition.x, spkrs[i].PropPosition.y, spkrs[i].PropPosition.z)
		obj.heading = spkrs[i].heading
		obj.Range = spkrs[i].Range
		obj.Id = spkrs[i].Id
		obj.type = spkrs[i].type
		obj.Label = spkrs[i].Label
		table.insert(Speakers, obj)
	end
	local locations = {}
	for _, speaker in ipairs(Speakers) do
		table.insert(locations, {
			['label'] = speaker.Label,
			['id'] = speaker.Id
		})
	end
	DebugPrint("Setting up speakers to send to radio API upon first start " .. json.encode(locations))
	exports['sonoranradio']:performApiRequest({
		['id'] = Config.comId,
		['key'] = Config.apiKey,
		['locations'] = locations
	}, 'SET-SERVER-SPEAKERS', function(data, success)
		if not success then
			errorLog('Failed to set server speakers for radio service. Please check your configuration.')
		end
	end)
	local chatterFile = LoadResourceFile(resourceName, 'earpieces.json')
	if not chatterFile then
		chatterFile = LoadResourceFile(resourceName, 'earpieces.DEFAULT.json')
		infoLog('Using default chatter configuration - Please update your earpieces.json file name to prevent this message from appearing.')
		infoLog('Attempting to rename earpieces.DEFAULT.json to earpieces.json')
		if not CopyFile(GetResourcePath(resourceName) .. '/earpieces.DEFAULT.json', GetResourcePath(resourceName) .. '/earpieces.json') then
			errorLog('Failed to rename earpieces.DEFAULT.json to earpieces.json. Please manually rename')
			chatterFileName = 'earpieces.DEFAULT.json'
		else
			infoLog('Successfully renamed earpieces.DEFAULT.json to earpieces.json')
			chatterFileName = 'earpieces.json'
		end
	else
		chatterFileName = 'earpieces.json'
	end
	-- Load JSON
	local chat = LoadResourceFile(resourceName, chatterFileName)
	local chatter = json.decode(chat) or {}
	local luaConfig = {}
	-- Function to check if a config item exists in the JSON
	local function isConfigInJson(jsonTable, configItem)
		for _, item in ipairs(jsonTable) do
			if item.componentId == configItem.componentId and item.drawableId == configItem.drawableId then
				return true -- Found, no need to add
			end
		end
		return false -- Not found
	end

	-- Add missing Config.chatterExclusions to the chatter JSON
	local updated = false
	for _, exclusion in ipairs(Config.chatterExclusions or {}) do
		if not isConfigInJson(chatter, exclusion) then
			table.insert(luaConfig, exclusion)
			updated = true
		end
	end
	chatterConfig = chatter
	-- Save updated earpieces.json if changes were made
	if updated then
		SaveResourceFile(resourceName, 'earpieces.json', json.encode(luaConfig, { indent = true }), -1)
		warnLog('Overwritting earpieces.json with Config.chatterExclusions. Config.chatterExclusions has been depreciated. Please remove this from your config.lua file to prevent any future overwrites. Please see https://sonoran.link/earpiecemigration for more')
		warnLog('Overwritting earpieces.json with Config.chatterExclusions. Config.chatterExclusions has been depreciated. Please remove this from your config.lua file to prevent any future overwrites. Please see https://sonoran.link/earpiecemigration for more')
		warnLog('Overwritting earpieces.json with Config.chatterExclusions. Config.chatterExclusions has been depreciated. Please remove this from your config.lua file to prevent any future overwrites. Please see https://sonoran.link/earpiecemigration for more')
		chatterConfig = luaConfig
	end

	DebugPrint('Loaded chatterConfig ' .. json.encode(chatterConfig))
	if Config.chatterExclusion then
		warnLog('Config.chatterExclusions is deprecated. Please use earpieces.json or /radiomenu in game to manage chatter exclusions.')
	end
end)

exports('performApiRequest', performApiRequest)

RegisterNetEvent('SonoranRadio::MoveProp', function(cell, towers, racks)
	DebugPrint('Processing towers to file ' .. json.encode(towers))
	DebugPrint('Processing racks to file ' .. json.encode(racks))
	DebugPrint('Processing cell to file ' .. json.encode(cell))
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
	SaveResourceFile(GetCurrentResourceName(), jsonFileName, json.encode(saveData, { indent = true }), -1)
	DebugPrint('Saved towers to file ' .. json.encode(saveData))
	Towers = towers
	Servers = racks
	CellRepeaters = cell
	TriggerClientEvent('RadioTower:SyncTowers', -1, Towers)
	TriggerClientEvent('RadioRacks:SyncRacks', -1, Servers)
	TriggerClientEvent('CellRepeater:SyncCellRepeaters', -1, CellRepeaters)
end)

RegisterNetEvent('SonoranRadio::MoveSpeaker', function(speakers)
	DebugPrint('Processing speakers to file ' .. json.encode(speakers))
	local saveData = {};
	for _, t in ipairs(speakers) do
		t.Handle = nil -- Remove the key 'handle'
		t.Spawned = nil -- Remove the key 'spawned'
		table.insert(saveData, t)
	end
	SaveResourceFile(GetCurrentResourceName(), speakersFileName, json.encode(saveData, { indent = true }), -1)
	DebugPrint('Saved speakers to file ' .. json.encode(saveData))
	Speakers = speakers
	local locations = {}
	for _, speaker in ipairs(Speakers) do
		table.insert(locations, {
			['label'] = speaker.Label,
			['id'] = speaker.Id
		})
	end
	DebugPrint("Setting up speakers to send to radio API upon SonoranRadio::MoveSpeaker " .. json.encode(locations))
	exports['sonoranradio']:performApiRequest({
		['id'] = Config.comId,
		['key'] = Config.apiKey,
		['locations'] = locations
	}, 'SET-SERVER-SPEAKERS', function(data, success)
		if not success then
			errorLog('Failed to set server speakers for radio service. Please check your configuration.')
		end
	end)
	TriggerClientEvent('SonoranRadio:SyncSpeakers', -1, Speakers)
end)


RegisterCommand('radioMenu', function(source)
		TriggerClientEvent('SonoranRadio::OpenRadioMenu', source)
end, true)

RegisterNetEvent('SonoranRadio:GetTunnels', function()
	TriggerClientEvent('SonoranRadio:SyncTunnels', source, tunnels)
end)

RegisterNetEvent('SonoranRadio:PolyZone:CreateZone', function(points, name, minY, maxY, degradeStrength)
	local obj = {}
	obj.points = points
	if type(minY) == 'string' then
		minY = tonumber(minY)
	end
	if type(maxY) == 'string' then
		maxY = tonumber(maxY)
	end
	obj.options = {
		minZ = minY,
		maxZ = maxY,
		degradeStrength = degradeStrength,
		name = name
	}
	table.insert(tunnels, obj)
	SaveResourceFile(GetCurrentResourceName(), polyZoneFileName, json.encode(tunnels, { indent = true }), -1)
	TriggerClientEvent('SonoranRadio:SyncTunnels', -1, tunnels)
end)

RegisterNetEvent('SonoranRadio:PolyZone:DeleteZone', function(zoneName)
	for i = 1, #tunnels do
		if tunnels[i].options.name == zoneName then
			table.remove(tunnels, i)
			break
		end
	end
	SaveResourceFile(GetCurrentResourceName(), polyZoneFileName, json.encode(tunnels, { indent = true }), -1)
	TriggerClientEvent('SonoranRadio:SyncTunnels', -1, tunnels)
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
	local info = debug.getinfo(3, 'S')
	local source = '.'
	if info.source:find('@@sonoranradio') then
		source = info.source:gsub('@@sonoranradio/', '') .. ':' .. info.linedefined
	end
	local msg = ('[%s:%s%s^7]%s %s^0'):format(debugging and source or 'SonoranRadio', color, level, color, message)
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

function serverNameChange(data)
	local postData = {
		['id'] = Config.comId,
		['key'] = Config.apiKey,
		['identity'] = data.identity,
		['displayName'] = data.name
	}
	performApiRequest(postData, 'SET-USER-DISPLAY-NAME', function(data, success)
		if not success then
			-- Ignore error if response contains "not found" (404)
			if type(data) == "string" and data:lower():find("not found") then
				debugLog('Failed to set display name, user not found.')
				return
			else
				errorLog('Failed to set server name for radio service. Please check your configuration.')
			end
		end
	end)
end
exports('serverNameChange', serverNameChange)