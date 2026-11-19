local startEnforcedInventory
local QBCore = nil
local MessageBuffer = {}
local DebugBuffer = {}
local ErrorBuffer = {}
local SupportErrorBuffer = {}
local tunnels = {}
local geoChannels = {}
scanners = {}
local panicStates = {}
local critError = false
chatterConfig = {}
local clientConfig
local sirens = {}
local DevEvents = DeveloperEvents or {}
local communityChannelsCache = nil
local communityChannelsCacheAt = 0
local communityChannelsRawCache = nil
local cadTowerSyncTracker = {}

local SUBSCRIPTION_CACHE_MS = 300000
local subscriptionLevel = 0

local function publishSubscription(level)
	level = tonumber(level) or 0
	local changed = subscriptionLevel ~= level
	subscriptionLevel = level
	Config.subscription = subscriptionLevel

	if clientConfig then
		clientConfig.subscription = subscriptionLevel
	end

	if changed then
		TriggerClientEvent('SonoranRadio::SubscriptionUpdated', -1, subscriptionLevel)
	end
end

function SonoranRadioGetSubscription()
	return subscriptionLevel
end

function SonoranRadioHasSubscription(minimumLevel)
	return subscriptionLevel >= (tonumber(minimumLevel) or 0)
end

function RefreshSonoranRadioSubscription()
	local refresh = promise.new()
	exports['sonoranradio']:performApiRequest({}, 'GET-SERVER-SUBSCRIPTION', function(data, success)
		if success then
			local decoded = type(data) == 'string' and json.decode(data) or data
			local level = decoded and tonumber(decoded.subscription)
			if level ~= nil then
				publishSubscription(level)
			else
				warnLog('WRN_API_REQUEST_FAILED', 'Radio API request failed (GET-SERVER-SUBSCRIPTION): invalid subscription response')
			end
		end

		refresh:resolve(SonoranRadioGetSubscription())
	end)
	return refresh
end
local cadLiveMapSyncFlushIntervalMs = 60000
local cadLiveMapSyncMaxBatchSize = 29
local cadLiveMapSyncState = {
	buffer = {},
	timerActive = false
}

local function getCadCommunityUserIdForPlayer(playerSource)
	if type(playerSource) ~= 'number' or playerSource <= 0 then
		return nil
	end

	if GetResourceState('sonorancad') ~= 'started' then
		return nil
	end

	local ok, communityUserId = pcall(function()
		return exports.sonorancad:getPlayerCommunityUserId(playerSource)
	end)
	if not ok or communityUserId == nil then
		return nil
	end

	communityUserId = tostring(communityUserId)
	if communityUserId == '' then
		return nil
	end
	return communityUserId
end

function BuildSonoranCadTowerSyncData()
	local sonoradData = {}

	for _, t in ipairs(CellRepeaters or {}) do
		table.insert(sonoradData, t)
	end

	for _, t in ipairs(Servers or {}) do
		table.insert(sonoradData, t)
	end

	for _, t in ipairs(Towers or {}) do
		table.insert(sonoradData, t)
	end

	return sonoradData
end

local function DispatchSonoranCadLiveMapSync()
	local sendCount = math.min(#cadLiveMapSyncState.buffer, cadLiveMapSyncMaxBatchSize)
	for _ = 1, sendCount do
		table.remove(cadLiveMapSyncState.buffer, 1)
	end
	TriggerEvent('SonoranCAD::sonrad:SyncTowers', BuildSonoranCadTowerSyncData())
end

local function QueueNextSonoranCadLiveMapSyncFlush()
	if cadLiveMapSyncState.timerActive then
		return
	end

	cadLiveMapSyncState.timerActive = true
	SetTimeout(cadLiveMapSyncFlushIntervalMs, function()
		cadLiveMapSyncState.timerActive = false
		if #cadLiveMapSyncState.buffer > 0 then
			DispatchSonoranCadLiveMapSync()
			if #cadLiveMapSyncState.buffer > 0 then
				QueueNextSonoranCadLiveMapSyncFlush()
			end
		end
	end)
end

function SyncSonoranCadLiveMap()
	table.insert(cadLiveMapSyncState.buffer, {
		queuedAt = os.time()
	})

	QueueNextSonoranCadLiveMapSyncFlush()
end

RegisterNetEvent('SonoranRadio:QueueCadTowerSync')
AddEventHandler('SonoranRadio:QueueCadTowerSync', function(syncType)
	if type(syncType) ~= 'string' then
		return
	end

	local src = source
	if type(src) ~= 'number' then
		src = 0
	end

	local syncState = cadTowerSyncTracker[src] or {}
	syncState[syncType] = true
	cadTowerSyncTracker[src] = syncState

	if syncState.cell and syncState.racks and syncState.towers then
		cadTowerSyncTracker[src] = nil
		SyncSonoranCadLiveMap()
	end
end)

AddEventHandler('playerDropped', function()
	cadTowerSyncTracker[source] = nil
end)

RegisterNetEvent('SonoranRadio::RequestCadCommunityUserId')
AddEventHandler('SonoranRadio::RequestCadCommunityUserId', function()
	local src = source
	TriggerClientEvent('SonoranRadio::CadCommunityUserId', src, getCadCommunityUserIdForPlayer(src))
end)

local function isGeoZoneOptions(options)
	if type(options) ~= 'table' then
		return false
	end
	if options.zoneType == 'geo' then
		return true
	end
	if options.transmitChannels ~= nil or options.scanChannels ~= nil or options.acePerms ~= nil then
		return true
	end
	return false
end

local function isDegradeZoneOptions(options)
	if type(options) ~= 'table' then
		return false
	end
	if options.zoneType == 'degrade' then
		return true
	end
	if options.degradeStrength ~= nil then
		return true
	end
	return false
end

local function removeZoneByName(list, zoneName, predicate)
	if type(list) ~= 'table' or not zoneName then
		return false
	end
	local removed = false
	for i = #list, 1, -1 do
		local options = list[i].options or {}
		if options.name == zoneName and (not predicate or predicate(options)) then
			table.remove(list, i)
			removed = true
		end
	end
	return removed
end

local function resolveZoneType(options, fallbackType)
	if type(options) ~= 'table' then
		return fallbackType
	end
	if options.zoneType == 'geo' or options.zoneType == 'degrade' then
		return options.zoneType
	end
	local geo = isGeoZoneOptions(options)
	local degrade = isDegradeZoneOptions(options)
	if geo and not degrade then
		return 'geo'
	end
	if degrade and not geo then
		return 'degrade'
	end
	return fallbackType
end

local function addGeoAcePerm(target, perm)
	if type(perm) ~= 'string' then
		return
	end
	local cleaned = perm:gsub('^%s+', ''):gsub('%s+$', '')
	if cleaned == '' then
		return
	end
	target[cleaned] = true
end

local function collectGeoAcePerms()
	local perms = {}
	if Config and Config.geoChannels then
		addGeoAcePerm(perms, Config.geoChannels.acePermission)
	end
	for _, zone in ipairs(geoChannels or {}) do
		local options = zone.options or {}
		if type(options.acePerms) == 'table' then
			for _, perm in ipairs(options.acePerms) do
				addGeoAcePerm(perms, perm)
			end
		end
	end
	return perms
end

local function buildGeoPermPayload(src)
	local permSet = collectGeoAcePerms()
	local allowed = {}
	for perm, _ in pairs(permSet) do
		allowed[perm] = IsPlayerAceAllowed(src, perm) and true or false
	end
	return {perms = allowed}
end

local function sendGeoPerms(src)
	if type(src) ~= 'number' or src <= 0 then
		return
	end
	local payload = buildGeoPermPayload(src)
	TriggerClientEvent('SonoranRadio::GeoPerms', src, payload)
end

local function decodeZoneApiData(data)
	if type(data) ~= 'string' then
		return data
	end
	local success, decoded = pcall(json.decode, data)
	if not success then
		return nil
	end
	return decoded
end

local function applyZoneSnapshot(data, reason)
	local snapshot = decodeZoneApiData(data)
	if type(snapshot) ~= 'table' or type(snapshot.geoZones) ~= 'table' or type(snapshot.degradeZones) ~= 'table' then
		warnLog('WRN_GEO_ZONE_SYNC_FAILED', 'The radio service returned an invalid zone snapshot.')
		return false
	end

	geoChannels = snapshot.geoZones
	tunnels = snapshot.degradeZones
	TriggerClientEvent('SonoranRadio:SyncGeoChannels', -1, geoChannels)
	TriggerClientEvent('SonoranRadio:SyncTunnels', -1, tunnels)
	debugLog(('Applied canonical geo and degrade zones (%s): %d geo, %d degrade.'):format(
		tostring(reason or 'unknown'),
		#geoChannels,
		#tunnels
	))
	return true
end

local function refreshZonesFromApi(reason)
	exports['sonoranradio']:performApiRequest({}, 'GET-ZONES', function(data, success)
		if not success then
			warnLog('WRN_GEO_ZONE_SYNC_FAILED', ('Could not retrieve canonical zones (%s).'):format(tostring(reason or 'unknown')))
			return
		end
		applyZoneSnapshot(data, reason)
	end)
end

local function mutateZoneApi(action, zoneType, zoneName, zone)
	local payload = {
		zoneType = zoneType,
		zoneName = zoneName,
		zone = zone
	}
	exports['sonoranradio']:performApiRequest(payload, action, function(data, success)
		if not success then
			warnLog('WRN_GEO_ZONE_SYNC_FAILED', ('The %s %s mutation was rejected by the radio service.'):format(zoneType, action:lower()))
			refreshZonesFromApi('mutation_failed')
			return
		end
		applyZoneSnapshot(data, action:lower())
	end)
end

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
	local enforcedInventoryItemsInitialized = false
	local function setupEnforcedInventoryItems()
		if enforcedInventoryItemsInitialized or not Config.enforceRadioItem then
			return
		end

		getFramework(true)
		getInventory(true)
		if not hasFrameworkInventory() then
			return
		end

		enforcedInventoryItemsInitialized = true
		if frameworkEnum == 1 then
			QBCore = exports['qb-core']:GetCoreObject()

			if Config.RadioItem == nil then
				errorLog('ERR_RADIO_ITEM_CONFIG_MISSING', 'Radio item is enforced but no item is defined. Please update your configuration. Using default item variables.')
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
				errorLog('ERR_SCANNER_ITEM_CONFIG_MISSING', 'Scanner item is enforced but no item is defined. Please update your configuration. Using default item variables.')
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
				errorLog('ERR_RADIO_ITEM_CONFIG_MISSING', 'Radio item is enforced but no item is defined. Please update your configuration. Using default item variables.')
				Config.RadioItem = {
					name = 'sonoran_radio',
					label = 'Sonoran Radio',
					weight = 1,
					description = 'Communicate with others through the Sonoran Radio',
				}
			end
			if Config.ScannerItem == nil then
				errorLog('ERR_SCANNER_ITEM_CONFIG_MISSING', 'Scanner item is enforced but no item is defined. Please update your configuration. Using default item variables.')
				Config.ScannerItem = {
					name = 'sonoran_radio_scanner', -- Item ID
					label = 'Sonoran Radio Scanner', -- Label for the item in your inventory
					weight = 1, -- Weight of the item in your inventory
					description = 'Listen to radio chatter with the Sonoran Radio Scanner', -- Description of the item in your inventory
				}
			end
			if not exports.ox_inventory:Items(Config.RadioItem.name) then
				errorLog('ERR_QBOX_OX_RADIO_ITEM_MISSING', 'Ox_Inventory detected on Qbox, ' .. Config.RadioItem.name .. ' could not be found, please ensure you have added it to your /ox_inventory/data/items.lua')
				return
			end
			if not exports.ox_inventory:Items(Config.ScannerItem.name) then
				errorLog('ERR_QBOX_OX_SCANNER_ITEM_MISSING', 'Ox_Inventory detected on Qbox, ' .. Config.ScannerItem.name .. ' could not be found, please ensure you have added it to your /ox_inventory/data/items.lua')
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
					errorLog('ERR_OX_LIB_INIT_LOAD_FAILED')
				end

				load(chunk, '@@ox_lib/init.lua', 't')()
			end
			lib.callback.register('getScanners', function(source)
				return scanners
			end)
		end
	end

	startEnforcedInventory = function()
		if not Config.enforceRadioItem then return end
		Citizen.CreateThread(function()
			if waitForFrameworkInventory() then
				setupEnforcedInventoryItems()
			end
		end)
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

local function fetchCommunityChannels(cb)
	if not Config or not Config.apiKey or not Config.comId then
		errorLog('ERR_API_CREDENTIALS_MISSING', 'API request failed: API key or community ID is not set.')
		if cb then
			cb(-1, nil, nil)
		end
		return
	end

	local result = getSonoranRadioClient():getCommunityChannelsV2(Config.comId)
	if result.success then
		local raw = type(result.data) == 'string' and result.data or json.encode(result.data)
		if cb then
			cb(200, result.data, raw)
		end
	else
		local reason = formatSonoranApiReason(result.reason)
		if cb then
			cb(-1, nil, reason)
		end
	end
end

local function getCommunityChannelsCached(cb)
	local now = os.time()
	if communityChannelsCache and (now - communityChannelsCacheAt) < 60 then
		if cb then
			cb(200, communityChannelsCache, communityChannelsRawCache)
		end
		return
	end

	fetchCommunityChannels(function(statusCode, payload, raw)
		if statusCode == 200 and payload then
			communityChannelsCache = payload
			communityChannelsRawCache = raw
			communityChannelsCacheAt = os.time()
		end
		if cb then
			cb(statusCode, payload, raw)
		end
	end)
end

RegisterNetEvent('SonoranRadio::RequestCommunityChannels', function()
	local src = source
	if type(src) ~= 'number' or src <= 0 then
		return
	end

	getCommunityChannelsCached(function(statusCode, payload)
		if statusCode == 200 and payload then
			TriggerClientEvent('SonoranRadio::CommunityChannels', src, payload)
		else
			warnLog('WRN_COMMUNITY_CHANNELS_FETCH_FAILED', ('Failed to fetch community channels for %s (status %s).'):format(tostring(src), tostring(statusCode)))
		end
	end)
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
	getchannels - fetch community channels (add "raw" to print full JSON)
    support <ticket ID> - upload diagnostics requested by support
    migrate - import settings and placements into Radio Admin and archive legacy configuration
    update - attempt to update the radio script
]])
	elseif args[1] == 'migrate' then
		MigrateRadioSettings()
	elseif args[1] == 'support' then
		UploadRadioSupportLogs(args[2])
	elseif args[1] == 'getchannels' then
		getCommunityChannelsCached(function(statusCode, payload, raw)
			if statusCode ~= 200 or not payload then
				errorLog('ERR_COMMUNITY_CHANNELS_FETCH_FAILED', ('Get community channels failed (status %s).'):format(tostring(statusCode)))
				if raw then
					print(raw)
				end
				return
			end

			local groups = payload.groups or {}
			local channels = payload.channels or {}
			print(('Community channels fetched: %s groups, %s channels'):format(#groups, #channels))

			if args[2] == 'raw' and raw then
				print(raw)
			end
		end)
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
	if not Config or not Config.init then return end
	local playerId = source
	local radioAceAllowed = not Config.acePermsForRadio or IsPlayerAceAllowed(playerId, 'sonoranradio.use')
	local framePermissions = checkFramePermissions(playerId)
	local allowedMiniRadio = not Config.acePermsForRadioUsers or IsPlayerAceAllowed(playerId, 'sonoranradio.radiousers')
	local allowedGuest = not Config.acePermsForRadioGuests or IsPlayerAceAllowed(playerId, 'sonoranradio.guest')
	if radioAceAllowed then
		TriggerClientEvent('SonoranRadio::AuthorizeRadio', playerId, framePermissions, allowedMiniRadio, allowedGuest, getBackendFrameDefinitions(), getBackendFrameAliases())
	end
	if Config.acePermsForTowerRepair then
		if IsPlayerAceAllowed(playerId, 'sonoranradio.repair') then
			TriggerClientEvent('SonoranRadio::AuthorizeTowers', playerId)
		end
	else
		TriggerClientEvent('SonoranRadio::AuthorizeTowers', playerId)
	end
	if Config.acePermsForServerRepair then
		if IsPlayerAceAllowed(playerId, 'sonoranradio.repairservers') then
			TriggerClientEvent('SonoranRadio::AuthorizeRacks', playerId)
		end
	else
		TriggerClientEvent('SonoranRadio::AuthorizeRacks', playerId)
	end
	if Config.acePermsForAntennaRepair then
		if IsPlayerAceAllowed(playerId, 'sonoranradio.repair') then
			TriggerClientEvent('SonoranRadio::AuthorizeAntennas', playerId)
		end
	else
		TriggerClientEvent('SonoranRadio::AuthorizeAntennas', playerId)
	end

	local scannersAllowed = not Config.acePermsForScanners or IsPlayerAceAllowed(playerId, 'sonoranradio.scanner')
	if scannersAllowed then
		TriggerClientEvent('SonoranRadio::AuthorizeScanners', playerId, true)
	end
	sendGeoPerms(playerId)
end)

-- initialize a valid Config.serverId through SET-SERVER-IP
local function initConfigServerId()
	Config.init = false

	local d = promise.new()
	Citizen.CreateThreadNow(function()
		local overridePushUrl = Config.overridePushUrl or GetConvar('sonoranradio_pushUrl', '')
		if overridePushUrl == '' then
			overridePushUrl = nil
		end

		-- get the current serverId (from a previous) as defined in the convar, config, or kvp
		local serverIdConvar = 'sonoranradio_serverId'
		local function normalizeRoomId(val)
			val = tonumber(val)
			if val == nil or val == 0 then
				return nil
			end
			return val
		end
		local roomId =
			normalizeRoomId(GetConvarInt(serverIdConvar)) or
			normalizeRoomId(Config.serverId) or
			normalizeRoomId(GetResourceKvpInt('standalone_serverId'))

		local function useRoomId(val)
			Config.serverId = val
			SetResourceKvpInt('standalone_serverId', val) -- save the roomId to the resource KVP as a backup
			setSonoranRadioClientRoomId(val) -- set the API client's room id
		end

		-- to create the client config, we must wait for the server-ip to be set so
		-- we have a roomId. If this is the initial setup, then roomId == nil and a new
		-- roomId will be created by the backend
		local maxAttempts = 5
		local attempt = 0
		local resolved = false
		local function tryRequest()
			attempt = attempt + 1
			print('[SonoranRadio] - Attempting to set server IP for radio service...')
			exports['sonoranradio']:performApiRequest({
				['roomId'] = roomId,
				['serverPort'] = GetConvarInt('netPort', 30120),
				['overridePushUrl'] = overridePushUrl,
				['nickname'] = GetConvar('sv_projectName', 'Server w/ Sonoran Radio'),
			}, 'SET-SERVER-IP', function(data, success)
				if not success then
					if attempt >= maxAttempts then
						errorLog('ERR_SERVER_IP_SET_FAILED', ('Failed to set server IP for radio service after %d attempts. Please check the comId and apiKey in your config file.'):format(maxAttempts))
						if not resolved then
							d:reject('failed to update server IP')
						end
						return
					end

					-- start retry
					Citizen.SetTimeout(30000, tryRequest)

					-- if we already have a roomId from a previous successful call, short-circuit to success
					-- but keep retrying in the background so the server IP eventually gets updated
					if attempt == 1 and roomId ~= nil then
						warnLog('WRN_SERVER_IP_USING_EXISTING_ROOM', 'Failed to set server IP for radio service, but using existing roomId (' .. roomId .. '). Retrying in background...')
						useRoomId(roomId)
						resolved = true
						d:resolve(Config.serverId)
					else
						warnLog('WRN_SERVER_IP_RETRYING', ('Failed to set server IP for radio service (attempt %d/%d). Retrying...'):format(attempt, maxAttempts))
					end
					return
				end

				data = json.decode(data) or {}
				local resolvedRoomId = normalizeRoomId(data.roomId)
				if resolvedRoomId == nil then
					errorLog('ERR_SERVER_IP_INVALID_ROOM', 'Failed to set server IP for radio service: invalid roomId returned.')
					if not resolved then
						d:reject('invalid roomId returned')
					end
					return
				end
				-- A background registration retry must not change the room after
				-- its resource settings were loaded. Restart to switch rooms.
				if resolved then
					if resolvedRoomId ~= Config.serverId then
						warnLog('WRN_SERVER_ID_CHANGED')
					end
					return
				end

				-- if the room id doesn't match the one in the convar or config, update the config file
				if resolvedRoomId ~= normalizeRoomId(GetConvarInt(serverIdConvar)) and resolvedRoomId ~= normalizeRoomId(Config.serverId) then
					local configFile = LoadResourceFile(GetCurrentResourceName(), 'config.lua')
					configFile = configFile:gsub("[\n^]Config%.serverId%s*=[^\n]*", "") -- remove other "serverId" instances

					-- insert the new serverId below the apiKey
					configFile = configFile:gsub("Config%.apiKey%s*=%s*.-\n", function(line)
						return line .. 'Config.serverId = '..resolvedRoomId..'\n'
					end, 1)

					local configWriteSuccess = SaveResourceFile(GetCurrentResourceName(), 'config.lua', configFile, -1)
					if not configWriteSuccess then
						-- couldn't write the file, but this is recoverable (kvp is used as backup)
						warnLog('WRN_SERVER_ID_CONFIG_WRITE_FAILED', 'Failed to write "Config.serverId = '..resolvedRoomId..'" to config.lua. Is the file read-only?')
					end
				end

				useRoomId(resolvedRoomId)
				resolved = true
				d:resolve(Config.serverId)
			end)
		end
		tryRequest()
	end)
	return d
end
-- this function creates/initializes the sanitized clientConfig
-- it returns a promise that can be waited with Citizen.Await
--
-- to create the clientConfig, we must wait for the serverId to be set in the config
local function createClientConfig()
	local d = promise.new()
	Citizen.CreateThreadNow(function()
		Citizen.Await(RefreshSonoranRadioSubscription())
		if Config.chatter ~= false and not SonoranRadioHasSubscription(2) then
			warnLog('WRN_LISTENER_PRO_REQUIRED')
		end

		-- create the client config
		local clConfig = {}
		local serverOnly = { apiKey = true, pushUrl = true, overridePushUrl = true, init = true, managedSettings = true }
		for k, v in pairs(Config) do
			if not serverOnly[k] and type(v) ~= 'function' then
				clConfig[k] = v
			end
		end
		clientConfig = clConfig
		d:resolve(clConfig)
	end)
	return d
end

local function keepLivePlacements(nextEntries, current)
	for _, entry in ipairs(current) do
		if entry.DontSaveMe then table.insert(nextEntries, entry) end
	end
	return nextEntries
end

local function loadSignalPlacements()
	Towers = keepLivePlacements({}, Towers)
	Servers = keepLivePlacements({}, Servers)
	CellRepeaters = keepLivePlacements({}, CellRepeaters)
	local signalPlacements = {
		radioTower = { entries = Towers, defaults = RadioTower },
		serverRack = { entries = Servers, defaults = RadioRacks },
		cellRepeater = { entries = CellRepeaters, defaults = CellRepeater }
	}
	for _, saved in ipairs(LoadRadioPlacements('towers.json')) do
		local placement = signalPlacements[saved.type]
		if placement then
			local obj = shallowcopy(placement.defaults)
			obj.Id = saved.Id or uuid()
			obj.PropPosition = vec3(saved.PropPosition.x, saved.PropPosition.y, saved.PropPosition.z)
			for _, field in ipairs({ 'Swankiness', 'Range', 'Destruction', 'NotPhysical', 'Powered', 'heading',
				'DishStatus', 'serverStatus', 'AntennaStatus' }) do
				if saved[field] ~= nil then obj[field] = saved[field] end
			end
			if obj.DishStatus then obj.DishStatus = { table.unpack(obj.DishStatus) } end
			if obj.serverStatus then obj.serverStatus = { table.unpack(obj.serverStatus) } end
			table.insert(placement.entries, obj)
		end
	end
end

local function loadSpeakers()
	Speakers = {}
	local spkrs = LoadRadioPlacements('speakers.json')
	for i = 1, #spkrs do
		local obj = {}
		if spkrs[i].Id == nil then
			obj.Id = uuid()
		else
			obj.Id = spkrs[i].Id
		end
		obj.PropPosition = vec3(spkrs[i].PropPosition.x, spkrs[i].PropPosition.y, spkrs[i].PropPosition.z)
		obj.heading = spkrs[i].heading or 0
		obj.Range = spkrs[i].Range
		obj.type = spkrs[i].type
		obj.Label = spkrs[i].Label
		obj.group = spkrs[i].group or ''
		table.insert(Speakers, obj)
	end
end

local function loadEarpieces()
	local entries, legacy = LoadRadioPlacements('earpieces.json')
	chatterConfig = entries
	if legacy and AddLegacyRadioEarpieces(chatterConfig) then
		warnLog('WRN_CHATTER_EXCLUSIONS_DEPRECATED')
		SaveRadioPlacements('earpieces.json', chatterConfig)
	end
	DebugPrint('Loaded chatterConfig ' .. json.encode(chatterConfig))
end

local function publishSpeakers()
	local locations = {}
	for _, speaker in ipairs(Speakers) do
		table.insert(locations, {
			['label'] = speaker.Label,
			['id'] = speaker.Id,
			['group'] = speaker.group or ''
		})
	end
	DebugPrint('Publishing speaker locations to the Radio API ' .. json.encode(locations))
	exports['sonoranradio']:performApiRequest({
		['locations'] = locations
	}, 'SET-SERVER-SPEAKERS', function(data, success)
		if not success then
			errorLog('ERR_SERVER_SPEAKERS_SET_FAILED', 'Failed to set server speakers for radio service. Please check your configuration.')
		end
	end)
end

local function syncSignalPlacements(target)
	local revision = GetPortalRadioPlacementRevision('towers.json')
	TriggerClientEvent('RadioTower:SyncTowers', target, Towers, revision)
	TriggerClientEvent('RadioRacks:SyncRacks', target, Servers, revision)
	TriggerClientEvent('CellRepeater:SyncCellRepeaters', target, CellRepeaters, revision)
end

function ReloadRadioPlacementRuntime(changed)
	if changed.towers then
		loadSignalPlacements()
		syncSignalPlacements(-1)
		SyncSonoranCadLiveMap()
	end
	if changed.speakers then
		loadSpeakers()
		publishSpeakers()
		TriggerClientEvent('SonoranRadio:SyncSpeakers', -1, Speakers, GetPortalRadioPlacementRevision('speakers.json'))
	end
	if changed.scanners then
		initStaticScanners(LoadRadioPlacements('scanners.json'), true)
	end
	if changed.jammers and type(initStaticJammers) == 'function' then
		initStaticJammers(LoadRadioPlacements('jammers.json'))
	end
	if changed.earpieces then
		loadEarpieces()
		TriggerClientEvent('Chatter:clientChatterSync_c', -1, chatterConfig, GetPortalRadioPlacementRevision('earpieces.json'))
	end
	if changed.mobileRepeaters and type(ReloadMobileRepeaters) == 'function' then
		ReloadMobileRepeaters()
	end
end

AddEventHandler('onResourceStart', function(resourceName)
	if (GetCurrentResourceName() ~= resourceName) then
		return
	end
	if critError or not Config or not Config.apiKey or not Config.comId then
		errorLog('ERR_API_CREDENTIALS_MISSING', 'API Key or Community ID not set. Please check your configuration.')
		critError = true
		return
	end

	local cApiKey = GetConvar('sonoranradio_apiKey', 'NONE')

	if cApiKey == 'NONE' then
		warnLog('WRN_APIKEY_CONVAR_UNINITIALIZED')
	elseif cApiKey == 'protection_initialized' then
		SetConvar('sonoranradio_apiKey', tostring(Config.apiKey))
	end

	SetConvar('sonoranradio_communityID', tostring(Config.comId))

	local registered = pcall(function() Citizen.Await(initConfigServerId()) end)
	if not registered or not InitializeManagedRadioSettings() then return end
	InitializeManagedRadioPlacements()
	Config.init = true

	getInventory()
	getFramework()
	startEnforcedInventory()
	TriggerEvent('SonoranRadio::Internal::SettingsReady')
	if type(InitMobileRepeaters) == 'function' then
		InitMobileRepeaters()
	end
	local initConfigPromise = createClientConfig()

	loadSignalPlacements()
	loadSpeakers()
	initStaticScanners(LoadRadioPlacements('scanners.json'), false)
	if type(initStaticJammers) == 'function' then
		initStaticJammers(LoadRadioPlacements('jammers.json'))
	end
	loadEarpieces()
	MarkRadioPlacementsLoaded()

	-- wait for config to be initialized (for roomId to be present)
	-- this needs to be done before SET-SERVER-SPEAKERS
	local clientConfig = Citizen.Await(initConfigPromise) -- wait for config to be initialized (for roomId to be present)
	Citizen.CreateThread(function()
		while true do
			Citizen.Wait(SUBSCRIPTION_CACHE_MS)
			Citizen.Await(RefreshSonoranRadioSubscription())
		end
	end)

	-- The backend is authoritative for GEO and degradation zones. Push events
	-- provide immediate updates; this periodic read repairs any missed event.
	refreshZonesFromApi('resource_start')
	Citizen.CreateThread(function()
		while true do
			Citizen.Wait(300000)
			refreshZonesFromApi('periodic_reconciliation')
		end
	end)

	publishSpeakers()

	-- provide client config/environment to all players in server
	TriggerClientEvent('SonoranRadio::core::ReceiveEnvironment', -1, clientConfig)

	-- Push Event Handling for Geo Zones
	TriggerEvent('sonoranradio::RegisterPushEvent', 'zone_updated', function(data)
		debugLog('Received zone_updated push event: ' .. json.encode(data))
		if type(data) == 'table' and type(data.payload) == 'table' and
			type(data.payload.geoZones) == 'table' and type(data.payload.degradeZones) == 'table' then
			applyZoneSnapshot(data.payload, 'push_event')
		else
			refreshZonesFromApi('push_event_reconciliation')
		end
	end)
end)

exports('performApiRequest', performApiRequest)

RegisterNetEvent('SonoranRadio::MoveProp', function(cell, towers, racks, expectedRevision)
	local src = source
	if not CanManageRadioPlacements(src) then return end
	if not MatchesRadioPlacementRevision('towers.json', expectedRevision) then
		TriggerClientEvent('SonoranRadio::DisplayError', src, 'Towers changed. Try again with the current placements.')
		return syncSignalPlacements(src)
	end
	if type(cell) ~= 'table' or type(towers) ~= 'table' or type(racks) ~= 'table' then return end
	-- Strip client-only fields (entity handles, blip handles, spawn state) that must
	-- not be stored on the server or forwarded to other clients, where the handle
	-- values would be meaningless or could accidentally match unrelated local objects.
	local clientOnlyFields = { 'Handle', 'Dishes', 'Servers', 'Ladder', 'Spawned', 'DebugBlip' }
	local function stripClientFields(t)
		for _, field in ipairs(clientOnlyFields) do
			t[field] = nil
		end
	end
	local saveData = {}
	local sections = {
		{ incoming = towers, placed = {}, expected = 'radioTower' },
		{ incoming = racks, placed = {}, expected = 'serverRack' },
		{ incoming = cell, placed = {}, expected = 'cellRepeater' }
	}
	for _, section in ipairs(sections) do
		for _, entry in ipairs(section.incoming) do
			if type(entry) ~= 'table' or entry.type ~= section.expected then return end
			if not entry.DontSaveMe then
				stripClientFields(entry)
				table.insert(saveData, entry)
				table.insert(section.placed, entry)
			end
		end
	end
	if not SaveRadioPlacements('towers.json', saveData) then
		TriggerClientEvent('SonoranRadio::DisplayError', src, 'Towers could not be saved. Check the server log.')
		return syncSignalPlacements(src)
	end
	Towers = keepLivePlacements(sections[1].placed, Towers)
	Servers = keepLivePlacements(sections[2].placed, Servers)
	CellRepeaters = keepLivePlacements(sections[3].placed, CellRepeaters)
	syncSignalPlacements(-1)
	SyncSonoranCadLiveMap()
end)

RegisterNetEvent('SonoranRadio::MoveSpeaker', function(speakers, expectedRevision)
	local src = source
	if not CanManageRadioPlacements(src) or type(speakers) ~= 'table' then return end
	if not MatchesRadioPlacementRevision('speakers.json', expectedRevision) then
		TriggerClientEvent('SonoranRadio::DisplayError', src, 'Speakers changed. Try again with the current placements.')
		return TriggerClientEvent('SonoranRadio:SyncSpeakers', src, Speakers, GetPortalRadioPlacementRevision('speakers.json'))
	end
	for _, speaker in ipairs(speakers) do
		if type(speaker) ~= 'table' then return end
		speaker.Handle = nil
		speaker.Spawned = nil
	end
	if not SaveRadioPlacements('speakers.json', speakers) then
		TriggerClientEvent('SonoranRadio::DisplayError', src, 'Speakers could not be saved. Check the server log.')
		TriggerClientEvent('SonoranRadio:SyncSpeakers', src, Speakers, GetPortalRadioPlacementRevision('speakers.json'))
		return
	end
	Speakers = speakers
	publishSpeakers()
	TriggerClientEvent('SonoranRadio:SyncSpeakers', -1, Speakers, GetPortalRadioPlacementRevision('speakers.json'))
end)


RegisterCommand('radioMenu', function(source)
		TriggerClientEvent('SonoranRadio::OpenRadioMenu', source)
end, true)

RegisterNetEvent('SonoranRadio:GetTunnels', function()
	TriggerLatentClientEvent('SonoranRadio:SyncTunnels', source, 10000, tunnels)
end)

RegisterNetEvent('SonoranRadio:GetGeoChannels', function()
	TriggerLatentClientEvent('SonoranRadio:SyncGeoChannels', source, 10000, geoChannels)
end)

RegisterNetEvent('SonoranRadio::RequestGeoPerms', function()
	sendGeoPerms(source)
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
		name = name,
		zoneType = 'degrade'
	}
	mutateZoneApi('CREATE-ZONE', 'degrade', name, obj)
end)

RegisterNetEvent('SonoranRadio:GeoZone:CreateZone', function(points, name, minY, maxY, options)
	local obj = {}
	obj.points = points
	if type(minY) == 'string' then
		minY = tonumber(minY)
	end
	if type(maxY) == 'string' then
		maxY = tonumber(maxY)
	end
	options = options or {}
	obj.options = {
		minZ = minY,
		maxZ = maxY,
		name = name,
		transmitChannels = options.transmitChannels or {},
		scanChannels = options.scanChannels or {},
		acePerms = options.acePerms or {},
		zoneType = 'geo'
	}
	mutateZoneApi('CREATE-ZONE', 'geo', name, obj)
end)

RegisterNetEvent('SonoranRadio:PolyZone:DeleteZone', function(zoneName)
	mutateZoneApi('DELETE-ZONE', 'degrade', zoneName)
end)

RegisterNetEvent('SonoranRadio:GeoZone:UpdateZone', function(zoneName, updates)
	if type(updates) ~= 'table' then
		return
	end
	local updatedZone = nil
	for i = 1, #geoChannels do
		if geoChannels[i].options and geoChannels[i].options.name == zoneName then
			updatedZone = shallowcopy(geoChannels[i])
			updatedZone.options = shallowcopy(geoChannels[i].options)
			updatedZone.options.transmitChannels = updates.transmitChannels or updatedZone.options.transmitChannels or {}
			updatedZone.options.scanChannels = updates.scanChannels or updatedZone.options.scanChannels or {}
			updatedZone.options.acePerms = updates.acePerms or updatedZone.options.acePerms or {}
			updatedZone.options.zoneType = 'geo'
			break
		end
	end
	if not updatedZone then
		warnLog('WRN_GEO_ZONE_SYNC_FAILED', ('Cannot update missing geo zone %s.'):format(tostring(zoneName)))
		return
	end
	mutateZoneApi('UPDATE-ZONE', 'geo', zoneName, updatedZone)
end)

RegisterNetEvent('SonoranRadio:GeoZone:DeleteZone', function(zoneName)
	mutateZoneApi('DELETE-ZONE', 'geo', zoneName)
end)

local function sendConsole(level, color, message, codeKey)
	local debugging = true
	if Config ~= nil then
		debugging = (Config.debug == true and Config.debug ~= 'false')
	end
	local source = getStructuredLogSourceLabel(4)
	local definition = getStructuredLogDefinition(codeKey)
	local payload = definition and definition.includeTrace == false and message or appendStructuredLogBreadcrumbs(level, message, 4)
	local msg = ('[%s:%s%s^7]%s %s^0'):format(debugging and source or 'SonoranRadio', color, level, color, payload)
	if (debugging and level == 'DEBUG') or (not debugging and level ~= 'DEBUG') or level == 'ERROR' or level == 'WARNING' or level == 'INFO' then
		print(msg)
	end
	if (level == 'ERROR' or level == 'WARNING') and IsDuplicityVersion() then
		table.insert(ErrorBuffer, 1, msg)
		table.insert(SupportErrorBuffer, 1, {
			timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
			level = level,
			key = codeKey,
			code = definition and definition.code or nil,
			message = message,
			source = source,
			actionTraceText = payload,
			docs = definition and ('https://sonoranradio.com/error/' .. definition.code) or nil
		})
		if #SupportErrorBuffer > 250 then table.remove(SupportErrorBuffer) end
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

function GetSupportRuntimeInfo()
    return {
        initialized = Config and Config.init == true,
        criticalApiError = critError,
        subscriptionLevel = subscriptionLevel,
        geoZones = geoChannels,
        degradeZones = tunnels,
        towerCount = type(Towers) == 'table' and #Towers or 0,
        rackCount = type(Servers) == 'table' and #Servers or 0,
        cellRepeaterCount = type(CellRepeaters) == 'table' and #CellRepeaters or 0
    }
end

function getSupportErrorBuffer()
	return SupportErrorBuffer
end

function getDebugBuffer()
	return DebugBuffer
end

function debugLog(message)
	sendConsole('DEBUG', '^7', message)
end

function logError(err, msg)
	sendConsole('ERROR', '^1', formatStructuredLogMessage(err, msg), err)
end

function errorLog(codeOrMessage, message)
	sendConsole('ERROR', '^1', formatStructuredLogMessage(codeOrMessage, message), codeOrMessage)
end

function warnLog(codeOrMessage, message)
	sendConsole('WARNING', '^3', formatStructuredLogMessage(codeOrMessage, message), codeOrMessage)
end

function infoLog(message)
	sendConsole('INFO', '^5', message)
end

AddEventHandler('SonoranRadio::core:writeLog', function(level, codeOrMessage, message)
	if level == 'debug' then
		debugLog(message or codeOrMessage)
	elseif level == 'info' then
		infoLog(message or codeOrMessage)
	elseif level == 'error' then
		sendConsole('ERROR', '^1', formatStructuredLogMessage(codeOrMessage, message), codeOrMessage)
	elseif level == 'warn' then
		sendConsole('WARNING', '^3', formatStructuredLogMessage(codeOrMessage, message), codeOrMessage)
	else
		debugLog(message or codeOrMessage)
	end
end)

function serverNameChange(data)
	local postData = {
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
				errorLog('ERR_SERVER_NAME_SET_FAILED', 'Failed to set server name for radio service. Please check your configuration.')
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
