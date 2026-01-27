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
local panicStates = {}
local critError = false
chatterConfig = {}
local clientConfig
local sirens = {}
local DevEvents = DeveloperEvents or {}

local function emitDeveloperEvent(suffix, payload)
	if DevEvents.emit then
		DevEvents.emit(suffix, payload)
	else
		TriggerEvent(('SonoranRadio::Developer:%s'):format(suffix), payload)
	end
end

if type(Config) ~= 'table' then
	critError = true
	print('^1!!! CRITICAL ERROR !!!^7')
	print('Sonoran Radio configuration not found! Possible reasons:')
	print('1. You have not renamed config.CHANGEME.lua to config.lua')
	print('2. You have made a syntax error in your config.lua file')
	print('^1!!! CRITICAL ERROR !!!^7')
else
	RegisterNetEvent('SonoranRadio::core::RequestEnvironment', function()
		if clientConfig then
			TriggerClientEvent('SonoranRadio::core::ReceiveEnvironment', source, clientConfig)
		end
	end)
	if not IsDuplicityVersion() then
		RegisterNetEvent('SonoranRadio::API:PlayerDeath', function(playerid)
			TriggerClientEvent('SonoranRadio::PlayerDeath', playerid) -- This event will kill the player
		end)
		RegisterNetEvent('SonoranRadio::API:PlayerRevive', function(playerid)
			TriggerClientEvent('SonoranRadio::PlayerRevive', playerid) -- This event will revive the player
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
	if not Config.radioJammers or Config.radioJammers == nil then
		Config.radioJammers = {
			enabled = true, -- Enable or disable radio jammers
			menuCommand = 'jammers', -- Subcommand to open the jammers menu | e.g. /sonoranradio jammers
			toggleRange = 3.0, -- Distance in meters required to toggle a jammer on/off
			permissionMode = 'none', -- ace, qbcore, esx or none
			acePermission = 'sonoranradio.jammers', -- ACE permission required to use jammers
			allowedJobs = { -- Jobs that can use jammers | Requires permission mode to be set to 'qbcore' or 'esx'
				['hacker'] = {
					grades = { -- Job grades that can use jammers
						1,
						2,
						3
					}
				}
			},
			jammers = {
				-- Define jammers here
				-- Example:
				{
					name = 'Hand Held Jammer', -- Name of the jammer
					model = 'm23_2_prop_m32_hackdevice_01a', -- Model name for the jammer
					offModel = 'm23_2_prop_m32_hackdevice_01a', -- Model name for the jammer when off | Optional
					range = 25, -- Range of the jammer in meters
					strength = 0.5, -- Strength of the jammer (0.0 to 1.0)
					permission = 'sonoranradio.jammer_handheld', -- ACE permission required to use this jammer | Optional
					-- If permission is not set, the jammer will be available to all players that can access the jammers menu
					type = 'handheld', -- Type of jammer (handheld or static)
					itemName = 'sonoran_radio_jammer_handheld', -- Item name for the jammer (if Config.enforceRadioItem is true)
					poweredItemName = 'sonoran_radio_jammer_handheld_on' -- Optional item that replaces the base item while the jammer is powered on
				},
				{
					name = 'Suitcase Jammer', -- Name of the jammer
					model = 'ch_prop_ch_mobile_jammer_01x', -- Model name for the jammer
					offModel = 'ch_prop_ch_mobile_jammer_01x', -- Model name for the jammer when off | Optional
					range = 100, -- Range of the jammer in meters
					strength = 0.8, -- Strength of the jammer (0.0 to 1.0)
					permission = '', -- ACE permission required to use this jammer | Optional
					-- If permission is not set, the jammer will be available to all players that can access the jammers menu
					type = 'static', -- Type of jammer (handheld or static)
					itemName = 'sonoran_radio_jammer_suitcase' -- Item name for the jammer (if Config.enforceRadioItem is true)
				},
				{
					name = 'Case Jammer', -- Name of the jammer
					model = 'h4_prop_h4_jammer_01a', -- Model name for the jammer
					offModel = 'h4_prop_h4_jammer_01a', -- Model name for the jammer when off | Optional
					range = 200, -- Range of the jammer in meters
					strength = 1.0, -- Strength of the jammer (0.0 to 1.0)
					permission = '', -- ACE permission required to use this jammer | Optional
					-- If permission is not set, the jammer will be available to all players that can
					type = 'static', -- Type of jammer (handheld or static)
					itemName = 'sonoran_radio_jammer_case' -- Item name for the jammer (if Config.enforceRadioItem is true)
				},
				{
					name = 'Satelite Jammer', -- Name of the jammer
					model = 'm23_2_prop_m32_jammer_01a', -- Model name for the jammer
					offModel = 'm23_2_prop_m32_jammer_01a', -- Model name for the jammer when off | Optional
					range = 300, -- Range of the jammer in meters
					strength = 1.0, -- Strength of the jammer (0.0 to 1.0)
					permission = '', -- ACE permission required to use this jammer | Optional
					-- If permission is not set, the jammer will be available to all players that can
					type = 'static', -- Type of jammer (handheld or static)
					itemName = 'sonoran_radio_jammer_satelite' -- Item name for the jammer (if Config.enforceRadioItem is true)
				}
			}
		}
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
				TriggerClientEvent('qb-sonrad:use', source, item.info.frame)
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
			local registeredJammerItems = {}
			for _, jammer in ipairs((Config.radioJammers and Config.radioJammers.jammers) or {}) do
				if jammer.type == 'handheld' and jammer.name then
					if jammer.itemName and jammer.itemName ~= '' and not registeredJammerItems[jammer.itemName] then
						exports['qb-core']:AddItem(jammer.itemName, {
							name = jammer.itemName,
							label = jammer.label or jammer.name,
							weight = jammer.weight or 1,
							type = 'item',
							image = jammer.image or 'radio.png',
							unique = true,
							useable = true,
							shouldClose = true,
							combinable = false,
							description = jammer.description or ('Handheld jammer: ' .. jammer.name),
						})
						registeredJammerItems[jammer.itemName] = true
					end
					if jammer.itemName and jammer.itemName ~= '' then
						QBCore.Functions.CreateUseableItem(jammer.itemName, function(source, item)
							TriggerClientEvent('SonoranRadio::Jammers::UseHandheldItem', source, {
								configName = jammer.name,
								item = jammer.itemName,
								powered = false
							})
						end)
					end
					if jammer.poweredItemName and jammer.poweredItemName ~= '' and not registeredJammerItems[jammer.poweredItemName] then
						exports['qb-core']:AddItem(jammer.poweredItemName, {
							name = jammer.poweredItemName,
							label = jammer.poweredLabel or (jammer.label or (jammer.name .. ' (Active)')),
							weight = jammer.poweredWeight or jammer.weight or 1,
							type = 'item',
							image = jammer.poweredImage or jammer.image or 'radio.png',
							unique = true,
							useable = true,
							shouldClose = true,
							combinable = false,
							description = jammer.poweredDescription or ('Powered handheld jammer: ' .. jammer.name),
						})
						registeredJammerItems[jammer.poweredItemName] = true
					end
					if jammer.poweredItemName and jammer.poweredItemName ~= '' then
						QBCore.Functions.CreateUseableItem(jammer.poweredItemName, function(source, item)
							TriggerClientEvent('SonoranRadio::Jammers::UseHandheldItem', source, {
								configName = jammer.name,
								item = jammer.poweredItemName,
								powered = true
							})
						end)
					end
				end
			end
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
			for _, jammer in ipairs((Config.radioJammers and Config.radioJammers.jammers) or {}) do
				if jammer.type == 'handheld' and jammer.name then
					if jammer.itemName and jammer.itemName ~= '' then
						exports.qbx_core:CreateUseableItem(jammer.itemName, function(source, item)
							TriggerClientEvent('SonoranRadio::Jammers::UseHandheldItem', source, {
								configName = jammer.name,
								item = jammer.itemName,
								powered = false
							})
						end)
					end
					if jammer.poweredItemName and jammer.poweredItemName ~= '' then
						exports.qbx_core:CreateUseableItem(jammer.poweredItemName, function(source, item)
							TriggerClientEvent('SonoranRadio::Jammers::UseHandheldItem', source, {
								configName = jammer.name,
								item = jammer.poweredItemName,
								powered = true
							})
						end)
					end
				end
			end
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

RegisterNetEvent('SonoranRadio::PanicState', function(isActive, metadata)
	local src = source
	if type(src) ~= 'number' or src <= 0 then return end

	local state = panicStates[src]
	if not state then
		state = {
			active = false,
			lastUpdated = 0
		}
		panicStates[src] = state
	end

	local active = isActive == true
	if state.active == active then
		state.lastUpdated = os.time()
		return
	end

	state.active = active
	state.lastUpdated = os.time()
	state.metadata = DevEvents.sanitize and DevEvents.sanitize(metadata) or metadata

	local playerPayload
	if DevEvents.playerContext then
		playerPayload = DevEvents.playerContext(src, {
			includeCoords = true,
			includeHeading = true
		})
	else
		playerPayload = {serverId = src}
	end

	local payload = {
		player = playerPayload,
		active = active,
		updatedAt = state.lastUpdated,
		metadata = state.metadata
	}

	if not payload.metadata then
		payload.metadata = nil
	end

	if active then
		emitDeveloperEvent('Panic:Activated', payload)
	else
		emitDeveloperEvent('Panic:Cleared', payload)
	end
end)

AddEventHandler('playerDropped', function()
	local src = source
	local state = panicStates[src]
	if not state then return end

	if state.active then
		local playerPayload
		if DevEvents.playerContext then
			playerPayload = DevEvents.playerContext(src, {includeIdentifiers = true})
		else
			playerPayload = {serverId = src}
		end

		emitDeveloperEvent('Panic:Cleared', {
			player = playerPayload,
			active = false,
			updatedAt = os.time(),
			reason = 'playerDropped',
			metadata = state.metadata
		})
	end

	panicStates[src] = nil
end)

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
	local radioAceAllowed = not Config.acePermsForRadio or IsPlayerAceAllowed(source, 'sonoranradio.use')
	local framePermissions = checkFramePermissions(source)
	local allowedMiniRadio = not Config.acePermsForRadioUsers or IsPlayerAceAllowed(source, 'sonoranradio.radiousers')
	local allowedGuest = not Config.acePermsForRadioGuests or IsPlayerAceAllowed(source, 'sonoranradio.guest')
	if radioAceAllowed then
		TriggerClientEvent('SonoranRadio::AuthorizeRadio', source, framePermissions, allowedMiniRadio, allowedGuest)
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

	local scannersAllowed = not Config.acePermsForScanners or IsPlayerAceAllowed(source, 'sonoranradio.scanner')
	if scannersAllowed then
		TriggerClientEvent('SonoranRadio::AuthorizeScanners', source, true)
	end
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
RegisterNetEvent('SonoranRadio::SaveSkinConfig', function(configPath, config)
	local src = source
	if not Config.debug then
		warnLog(('Player id:%s is attempting to save a radio skin config, even though debug is not enabled (possible security issue)'):format(source))
		return
	end

	local success = SaveResourceFile(GetCurrentResourceName(), configPath, config, -1)
	if success then
		infoLog(('Successfully saved %s'):format(configPath))
		TriggerClientEvent('SonoranRadio::DisplayInfo', src, 'Successfully saved skin.json')
	else
		errorLog(('Could not save %s, skin settings will not be saved'):format(configPath))
		TriggerClientEvent('SonoranRadio::DisplayError', src, 'Could not save skin.json (see server log for more info)')
	end
end)

local function CopyFile(old_path, new_path)
	local old_file = io.open(old_path, 'rb')
	if not old_file then
		print('Failed to open source file: ' .. old_path .. ' - please check your folder permissions or rename file manually.')
		return false
	end
	local new_file = io.open(new_path, 'wb')
	if not new_file then
		print('Failed to create target file: ' .. new_path .. ' - please check your folder permissions or rename file manually.')
		old_file:close()
		return false
	end

	local old_file_sz, new_file_sz
	while true do
		local block = old_file:read(2 ^ 13) -- 8KiB
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
local defaultJsonConfigFiles = {
	['earpieces.json'] = 'earpieces.DEFAULT.json',
	['jammers.json']   = 'jammers.DEFAULT.json',
	['scanners.json']  = 'scanners.DEFAULT.json',
	['speakers.json']  = 'speakers.DEFAULT.json',
	['towers.json']    = 'towers.DEFAULT.json',
	['tunnels.json']   = 'tunnels.DEFAULT.json',
}
function LoadJsonConfig(file)
	local resourceName = GetCurrentResourceName()
	local fileData = LoadResourceFile(resourceName, file)
	if not fileData then
		local defaultFile = defaultJsonConfigFiles[file]
		if not defaultFile then error('no default json config found for '..file) end

		-- Rename default to proper config file for user
		fileData = LoadResourceFile(resourceName, defaultFile)
		infoLog(('%s is not found, attempting to rename %s to %s'):format(file, defaultFile, file))
		local success = CopyFile(GetResourcePath(resourceName)..'/'..defaultFile, GetResourcePath(resourceName)..'/'..file)
		if success then
			infoLog(('Successfully renamed %s to %s'):format(defaultFile, file))
		else
			warnLog(('Failed to rename %s to %s'):format(defaultFile, file))
			file = defaultFile -- when loading below, use the default file
		end
	end
	fileData = LoadResourceFile(resourceName, file)
	return json.decode(fileData) or {}
end
function SaveJsonConfig(file, obj)
	local resourceName = GetCurrentResourceName()
	local contents = json.encode(obj, { indent = true })
	local success = SaveResourceFile(resourceName, file, contents, -1)
	if not success then
		-- file could not be saved (permission issues probably)
		-- try to write to default file with warning
		local defaultFile = defaultJsonConfigFiles[file]
		if not defaultFile then error('no default json config found for '..file) end
		warnLog(('Could not save updated %s, trying to write changes to %s (NOTE: If auto-update is enabled, this file will be replaced during an update)'):format(file, defaultFile))
		success = SaveResourceFile(resourceName, defaultFile, contents, -1)
	end
	if not success then
		-- could not write to default file, write error
		errorLog(('Could not save updated %s. Changes are not saved'):format(defaultJsonConfigFiles[file]))
	end
	return success
end

local function checkPushUrl(url, tries)
	local d = promise.new()
	if not url then return d:resolve(false) end
	tries = tries or 1
	if tries <= 0 then return d:resolve(false) end

	exports['sonoranradio']:HandleHttpRequest(url..'/ping', function(code, data, headers)
		if code == 200 then return d:resolve(true) end

		-- invalid request
		warnLog(('pushUrl check failed for %s, tries left: %d'):format(url, tries - 1))
		checkPushUrl(url, tries - 1):next(function(success)
			d:resolve(success)
		end)
	end, 'GET')
	return d
end
local function getWebPushUrl(checkTries)
	local d = promise.new()
	Citizen.CreateThreadNow(function()
		-- wait for web_baseUrl to be populated
		local webUrl = GetConvar('web_baseUrl', '')
		local tries = 0
		while (not webUrl or webUrl == '') and tries < 3 do
			warnLog('Waiting for web_baseUrl convar...')
			Citizen.Wait(5000)
			tries = tries + 1
			webUrl = GetConvar('web_baseUrl', '')
		end
		if webUrl and webUrl ~= '' then
			local pushUrl = 'https://'..webUrl..'/'..GetCurrentResourceName()..'/events'
			checkPushUrl(pushUrl, checkTries or 5):next(function(success)
				if success then
					d:resolve(pushUrl)
				else
					warnLog(('Tried using %s as pushUrl, but could not send events'):format(pushUrl))
					d:resolve(nil)
				end
			end)
		else
			warnLog('Could not find web_baseUrl convar')
			d:resolve(nil)
		end
	end)
	return d
end
local function getIpPushUrl(checkTries)
	local d = promise.new()
	local port = GetConvar('netPort', '30120')
	exports['sonoranradio']:HandleHttpRequest('https://api.ipify.org', function(code, data)
		if code == 200 then
			local pushUrl = 'http://'..data..':'..port..'/'..GetCurrentResourceName()..'/events'
			checkPushUrl(pushUrl, checkTries or 5):next(function(success)
				if success then
					d:resolve(pushUrl)
				else
					warnLog(('Tried using %s as pushUrl, but could not send events'):format(pushUrl))
					d:resolve(nil)
				end
			end)
		else
			errorLog('Could not obtain public IP address, no internet connection?')
			d:resolve(nil)
		end
	end, 'GET')
	return d
end
local function getPushUrl(tries)
	local d = promise.new()
	local overridePushUrl = Config.overridePushUrl or GetConvar('sonoranradio_pushUrl', '')
	if type(overridePushUrl) == 'string' and overridePushUrl ~= '' then
		infoLog(('Using %s as override pushUrl'):format(overridePushUrl))
		return d:resolve(overridePushUrl)
	end
	getWebPushUrl(tries):next(function(webPushUrl)
		if webPushUrl then
			d:resolve(webPushUrl)
		else
			getIpPushUrl(tries):next(function(ipPushUrl)
				d:resolve(ipPushUrl)
			end)
		end
	end)
	return d
end

-- thread function for keeping the pushUrl up-to-date
local function updatePushUrlThread()
	local lastPushUrl = Config.pushUrl
	while true do
		Citizen.Wait(5 * 60 * 1000)

		local pushUrl = Citizen.Await(getPushUrl(2))
		if pushUrl ~= lastPushUrl then
			infoLog(('Last pushUrl %s is invalid, setting to new pushUrl %s'):format(lastPushUrl, pushUrl))
			lastPushUrl = pushUrl
			exports['sonoranradio']:performApiRequest({
				['id'] = Config.comId,
				['key'] = Config.apiKey,
				['roomId'] = Config.serverId,
				['pushUrl'] = pushUrl,
				-- no need to set nickname since roomId exists
			}, 'SET-SERVER-IP', function(data, success)
				if not success then
					warnLog('Failed to set updated pushUrl for radio service.')
				end
			end)
		end
	end
end

-- this function creates/initializes the sanitized clientConfig
-- it returns a promise that can be waited with Citizen.Await
--
-- to create the clientConfig, we must wait for the serverId to be set in the config,
-- which this function also acomplishes
local function createClientConfig()
	local d = promise.new()
	Config.init = false
	Citizen.CreateThreadNow(function()
		local pushUrl = Citizen.Await(getPushUrl())
		if not pushUrl then
			errorLog('[ERR-101] Could not obtain a valid pushUrl. This could be because of no internet connection, strict firewall settings, or an advanced internet setup')
			errorLog('[ERR-101] Consider setting overridePushUrl in the config.lua to http://ip:port/sonoranradio/events')
			errorLog('[ERR-101] See https://sonoran.link/radiocodes for more info')
			return d:reject('failed to get pushUrl')
		end

		-- turn 0 values into nil so the below "or" chain works
		local function nonZero(val) if val == 0 then return nil else return val end end
		-- get the room id this server intends to use from convar, then config, then backup kvp
		local roomId =
			nonZero(GetConvarInt('sonoranradio_serverId')) or
			nonZero(Config.serverId) or
			nonZero(GetResourceKvpInt('standalone_serverId'))
		-- to create the client config, we must wait for the server-ip to be set so
		-- we have a roomId. If this is the initial setup, then roomId == nil and a new
		-- roomId will be created by the backend
		print('[SonoranRadio] - Attempting to set server IP for radio service... '..pushUrl)
		exports['sonoranradio']:performApiRequest({
			['id'] = Config.comId,
			['key'] = Config.apiKey,
			['roomId'] = roomId,
			['pushUrl'] = pushUrl,
			['serverPort'] = GetConvarInt('netPort', 30120),
			['nickname'] = GetConvar('sv_projectName', 'Server w/ Sonoran Radio'),
		}, 'SET-SERVER-IP', function(data, success)
			if not success then
				errorLog('Failed to set server IP for radio service. Please check the comId and apiKey in your config file.')
				return d:reject('failed to update server IP')
			end

			data = json.decode(data)

			-- if the room id doesn't match the one in the convar or config, update the config file
			if data.roomId ~= GetConvarInt('sonoranradio_serverId') and data.roomId ~= Config.serverId then
				local configFile = LoadResourceFile(GetCurrentResourceName(), 'config.lua')
				configFile = configFile:gsub("[\n^]Config%.serverId%s*=[^\n]*", "") -- remove other "serverId" instances

				-- insert the new serverId below the apiKey
				configFile = configFile:gsub("Config%.apiKey%s*=%s*.-\n", function(line)
					return line .. 'Config.serverId = '..data.roomId..'\n'
				end, 1)

				local configWriteSuccess = SaveResourceFile(GetCurrentResourceName(), 'config.lua', configFile, -1)
				if not configWriteSuccess then
					-- couldn't write the file, but this is recoverable (kvp is used as backup)
					warnLog('Failed to write "Config.serverId = '..data.roomId..'" to config.lua. Is the file read-only?')
				end
			end

			SetResourceKvpInt('standalone_serverId', data.roomId) -- save the roomId to the resource KVP as a backup
			Config.init = true
			Config.serverId = data.roomId
			Config.pushUrl = pushUrl

			-- create the client config
			local clConfig = {}
			for k, v in pairs(Config) do
				if k ~= 'apiKey' and k ~= 'pushUrl' and k ~= 'init' then -- filter out sensitive data
					clConfig[k] = v
				end
			end
			clientConfig = clConfig
			d:resolve(clConfig)
		end)
	end)
	return d
end

AddEventHandler('onResourceStart', function(resourceName)
	if (GetCurrentResourceName() ~= resourceName) then
		return
	end
	if critError or not Config or not Config.apiKey or not Config.comId then
		errorLog('API Key or Community ID not set. Please check your configuration.')
		critError = true
		return
	end
	Config.init = false
	if Config.frames == nil or not Config.frames then
		errorLog('Config.frames is not set. Please check your configuration.')
		critError = true
		return
	end
	getInventory()
	getFramework()
	local initConfigPromise = createClientConfig()

	-- initialize towers
	local towers = LoadJsonConfig('towers.json')
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

	-- initialize polyzone tunnels
	local tnl = LoadJsonConfig('tunnels.json')
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

	-- initialize speakers
	local spkrs = LoadJsonConfig('speakers.json')
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
		obj.group = spkrs[i].group or ''
		table.insert(Speakers, obj)
	end

	local staticScanners = LoadJsonConfig('scanners.json')
	initStaticScanners(staticScanners)

	local staticJammers = LoadJsonConfig('jammers.json')
	if type(initStaticJammers) == 'function' then
		initStaticJammers(staticJammers)
	end

	-- initialize chatter earpieces
	local chatter = LoadJsonConfig('earpieces.json')
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
		warnLog('Overwritting earpieces.json with Config.chatterExclusions. Config.chatterExclusions has been depreciated. Please remove this from your config.lua file to prevent any future overwrites. Please see https://sonoran.link/earpiecemigration for more')
		SaveJsonConfig('earpieces.json', luaConfig)
		chatterConfig = luaConfig
	end

	DebugPrint('Loaded chatterConfig ' .. json.encode(chatterConfig))
	if Config.chatterExclusion then
		warnLog('Config.chatterExclusions is deprecated. Please use earpieces.json or /radiomenu in game to manage chatter exclusions.')
	end

	-- set the speakers via the API
	local locations = {}
	for _, speaker in ipairs(Speakers) do
		table.insert(locations, {
			['label'] = speaker.Label,
			['id'] = speaker.Id,
			['group'] = speaker.group or ''
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

	local clientConfig = Citizen.Await(initConfigPromise) -- wait for config to be initialized (for roomId to be present)
	TriggerClientEvent('SonoranRadio::core::ReceiveEnvironment', -1, clientConfig)
	Citizen.CreateThread(updatePushUrlThread)
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
	SaveJsonConfig('towers.json', saveData)
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
	SaveJsonConfig('speakers.json', saveData)
	DebugPrint('Saved speakers to file ' .. json.encode(saveData))
	Speakers = speakers
	local locations = {}
	for _, speaker in ipairs(Speakers) do
		table.insert(locations, {
			['label'] = speaker.Label,
			['id'] = speaker.Id,
			['group'] = speaker.group or ''
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
	TriggerLatentClientEvent('SonoranRadio:SyncTunnels', source, 10000, tunnels)
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
	SaveJsonConfig('tunnels.json', tunnels)
	TriggerClientEvent('SonoranRadio:SyncTunnels', -1, tunnels)
end)

RegisterNetEvent('SonoranRadio:PolyZone:DeleteZone', function(zoneName)
	for i = 1, #tunnels do
		if tunnels[i].options.name == zoneName then
			table.remove(tunnels, i)
			break
		end
	end
	SaveJsonConfig('tunnels.json', tunnels)
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
		['accId'] = data.identity,
		['displayName'] = data.name
	}
	performApiRequest(postData, 'SET-USER-DISPLAY-NAME', function(data, success)
		if not success then
			-- Ignore error if response contains "Not Found" (404)
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

RegisterNetEvent('SonoranRadio::RequestSirens', function()
	for k, v in pairs(sirens) do
		if v.isOn then
			TriggerClientEvent('sonoranradio:receiveSirenState', source, k, v.isOn, v.netId)
		end
	end
end)

RegisterNetEvent('sonoranradio:syncSirenState')
AddEventHandler('sonoranradio:syncSirenState', function(isOn, netId)
	local src = source
	-- pass along who, on/off, volume, and where
	sirens[src] = {
		isOn = isOn,
		netId = netId
	}
	TriggerClientEvent('sonoranradio:receiveSirenState', -1, src, isOn, netId)
end)

RegisterNetEvent('SonoranRadio::PostalRouteArrived', function()
	local src = source
	local ids = {}
    for _, id in ipairs(GetPlayerIdentifiers(player)) do
        local split = stringsplit(id, ":")
        ids[split[1]] = split[2]
    end
	local sonoranCadMainApi = GetConvar('sonoran_primaryIdentifier', 'steam')
	local apiId = ids[sonoranCadMainApi] or ids['steam'] or ids['license'] or 'unknown'
	local data = {
		['serverId'] = GetConvar('sonoran_serverId', 1),
		['status'] = Config.autoOnSceneStatus.statusEnum,
		['apiId'] = apiId
	}
	exports.sonorancad.performApiRequest(data, 'UNIT_STATUS', function(response, success)
		if not success then
			errorLog('Failed to update unit status on SonoranCAD.')
		end
	end)
end)