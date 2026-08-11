local activeRepeaters = {}
local mobileRepeaterConfig = {
	version = 1,
	migratedFromConfig = false,
	vehicles = {}
}
local mobileRepeatersInitialized = false
local activeRepeaterTrackerStarted = false
local mobileRepeaterConfigFile = 'mobileRepeaters.json'
local destroyedEngineHealth = -1000.0

local function trim(value)
	return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function normalizeModelHash(value)
	if type(value) == 'number' then
		return math.floor(value)
	end
	if type(value) ~= 'string' then
		return nil
	end

	local cleaned = trim(value)
	if cleaned == '' then
		return nil
	end

	local numericHash = tonumber(cleaned)
	if numericHash then
		return math.floor(numericHash)
	end
	return GetHashKey(cleaned)
end

local function normalizeVehicleConfig(entry)
	if type(entry) ~= 'table' then
		return nil
	end

	local modelHash = normalizeModelHash(entry.modelHash or entry.model)
	if not modelHash or modelHash == 0 then
		return nil
	end

	local label = trim(entry.label)
	if label == '' then
		label = ('Vehicle %s'):format(modelHash)
	end
	label = label:sub(1, 64)

	local range = tonumber(entry.range) or 200.0
	if range ~= range then
		range = 200.0
	end
	range = math.max(1.0, math.min(range, 10000.0))

	return {
		modelHash = modelHash,
		label = label,
		range = range
	}
end

local function normalizeVehicleList(entries)
	local vehicles = {}
	local indexesByHash = {}
	local changed = false

	for _, entry in ipairs(type(entries) == 'table' and entries or {}) do
		local normalized = normalizeVehicleConfig(entry)
		if normalized then
			local existingIndex = indexesByHash[normalized.modelHash]
			if existingIndex then
				vehicles[existingIndex] = normalized
				changed = true
			else
				table.insert(vehicles, normalized)
				indexesByHash[normalized.modelHash] = #vehicles
			end
			if entry.modelHash ~= normalized.modelHash or entry.model ~= nil or entry.label ~= normalized.label or tonumber(entry.range) ~= normalized.range then
				changed = true
			end
		else
			changed = true
		end
	end

	return vehicles, indexesByHash, changed
end

local function syncMobileRepeaters(target)
	TriggerClientEvent('SonoranRadio::SyncMobileRepeaters', target or -1, mobileRepeaterConfig.vehicles)
end

local function saveMobileRepeaters(vehicles)
	local nextConfig = {
		version = 1,
		migratedFromConfig = true,
		vehicles = vehicles
	}
	if not SaveJsonConfig(mobileRepeaterConfigFile, nextConfig) then
		return false
	end
	mobileRepeaterConfig = nextConfig
	syncMobileRepeaters(-1)
	return true
end

local function canManageMobileRepeaters(src)
	return type(src) == 'number' and src > 0 and IsPlayerAceAllowed(src, 'command.radioMenu')
end

local function sendConfigError(src, message)
	TriggerClientEvent('SonoranRadio::DisplayError', src, message)
end

local function getNetworkVehicle(src, networkId, requireNearby)
	networkId = tonumber(networkId)
	if not networkId or networkId <= 0 then
		return nil
	end

	local vehicle = NetworkGetEntityFromNetworkId(networkId)
	if vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then
		return nil
	end

	if requireNearby then
		local playerPed = GetPlayerPed(src)
		if playerPed == 0 or not DoesEntityExist(playerPed) then
			return nil
		end
		local playerCoords = GetEntityCoords(playerPed)
		local vehicleCoords = GetEntityCoords(vehicle)
		local x = playerCoords.x - vehicleCoords.x
		local y = playerCoords.y - vehicleCoords.y
		local z = playerCoords.z - vehicleCoords.z
		if (x * x + y * y + z * z) > 225.0 then
			return nil
		end
	end

	return vehicle
end

local function getVehicleRepeaterConfig(vehicle)
	if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
		return nil
	end
	local modelHash = GetEntityModel(vehicle)
	for _, vehicleConfig in ipairs(mobileRepeaterConfig.vehicles) do
		if vehicleConfig.modelHash == modelHash then
			return vehicleConfig
		end
	end
	return nil
end

local function buildRepeaterTower(vehicle, vehicleConfig)
	return {
		Destruction = false,
		NotPhysical = true,
		Swankiness = 0.0,
		PropPosition = GetEntityCoords(vehicle),
		DishStatus = {
			'alive',
			'alive',
			'alive',
			'alive'
		},
		Range = vehicleConfig.range,
		Powered = true,
		DontSaveMe = true
	}
end

local function disableActiveRepeater(networkId)
	local activeRepeater = activeRepeaters[networkId]
	if activeRepeater then
		exports['sonoranradio']:updateTower(activeRepeater.towerId, nil)
		activeRepeaters[networkId] = nil
	end
end

local function startActiveRepeaterTracker()
	if activeRepeaterTrackerStarted then
		return
	end
	activeRepeaterTrackerStarted = true

	Citizen.CreateThread(function()
		while true do
			Citizen.Wait(3000)
			for networkId, activeRepeater in pairs(activeRepeaters) do
				local vehicle = getNetworkVehicle(0, networkId, false)
				local vehicleConfig = getVehicleRepeaterConfig(vehicle)
				local engineHealth = vehicle and GetVehicleEngineHealth(vehicle) or nil
				if not vehicleConfig or vehicleConfig.modelHash ~= activeRepeater.modelHash or
					(engineHealth and engineHealth < destroyedEngineHealth) then
					disableActiveRepeater(networkId)
				else
					exports['sonoranradio']:updateTower(activeRepeater.towerId, buildRepeaterTower(vehicle, vehicleConfig))
				end
			end
		end
	end)
end

function InitMobileRepeaters()
	if mobileRepeatersInitialized then
		return
	end
	mobileRepeatersInitialized = true
	startActiveRepeaterTracker()

	local loaded = LoadJsonConfig(mobileRepeaterConfigFile)
	local loadedVehicles = loaded.vehicles
	local changed = false
	if type(loadedVehicles) ~= 'table' then
		-- Accept an early array-only format and normalize it to the versioned schema.
		loadedVehicles = loaded
		changed = true
	end

	local vehicles, indexesByHash, normalized = normalizeVehicleList(loadedVehicles)
	changed = changed or normalized or loaded.version ~= 1

	local migratedFromConfig = loaded.migratedFromConfig == true
	local migratedCount = 0
	if not migratedFromConfig then
		local legacyEntries = type(Config.repeaterVehicleSpawncodes) == 'table' and Config.repeaterVehicleSpawncodes or {}
		for _, legacyEntry in ipairs(legacyEntries) do
			local normalizedLegacy = normalizeVehicleConfig(legacyEntry)
			if normalizedLegacy and not indexesByHash[normalizedLegacy.modelHash] then
				table.insert(vehicles, normalizedLegacy)
				indexesByHash[normalizedLegacy.modelHash] = #vehicles
				migratedCount = migratedCount + 1
			end
		end
		migratedFromConfig = true
		changed = true
	end

	mobileRepeaterConfig = {
		version = 1,
		migratedFromConfig = migratedFromConfig,
		vehicles = vehicles
	}

	local saved = true
	if changed then
		saved = SaveJsonConfig(mobileRepeaterConfigFile, mobileRepeaterConfig)
	end
	if migratedCount > 0 and saved then
		warnLog('WRN_MOBILE_REPEATERS_CONFIG_MIGRATED', ('Migrated %d vehicle repeater configuration(s) to %s. Remove Config.repeaterVehicleSpawncodes and use /radiomenu for future changes.'):format(migratedCount, mobileRepeaterConfigFile))
	end
end

RegisterNetEvent('SonoranRadio::RequestMobileRepeaters', function()
	if not mobileRepeatersInitialized then
		return
	end
	syncMobileRepeaters(source)
end)

RegisterNetEvent('SonoranRadio::SaveMobileRepeaterVehicle', function(networkId, label, range)
	local src = source
	if not canManageMobileRepeaters(src) then
		return sendConfigError(src, 'You do not have permission to configure mobile repeaters.')
	end

	local vehicle = getNetworkVehicle(src, networkId, true)
	if not vehicle then
		return sendConfigError(src, 'The selected vehicle is unavailable or too far away.')
	end

	local vehicleConfig = normalizeVehicleConfig({
		modelHash = GetEntityModel(vehicle),
		label = label,
		range = range
	})
	if not vehicleConfig then
		return sendConfigError(src, 'The selected vehicle configuration is invalid.')
	end

	local vehicles = {}
	local updated = false
	for _, existing in ipairs(mobileRepeaterConfig.vehicles) do
		if existing.modelHash == vehicleConfig.modelHash then
			table.insert(vehicles, vehicleConfig)
			updated = true
		else
			table.insert(vehicles, existing)
		end
	end
	if not updated then
		table.insert(vehicles, vehicleConfig)
	end

	if not saveMobileRepeaters(vehicles) then
		return sendConfigError(src, 'Could not save mobileRepeaters.json. Check the server log.')
	end
	TriggerClientEvent('SonoranRadio::MobileRepeaterSaved', src, vehicleConfig, updated)
end)

RegisterNetEvent('SonoranRadio::DeleteMobileRepeaterVehicle', function(modelHash)
	local src = source
	if not canManageMobileRepeaters(src) then
		return sendConfigError(src, 'You do not have permission to configure mobile repeaters.')
	end

	modelHash = normalizeModelHash(modelHash)
	if not modelHash then
		return sendConfigError(src, 'The selected mobile repeater configuration is invalid.')
	end

	local vehicles = {}
	local removed = false
	for _, existing in ipairs(mobileRepeaterConfig.vehicles) do
		if existing.modelHash == modelHash then
			removed = true
		else
			table.insert(vehicles, existing)
		end
	end
	if not removed then
		return sendConfigError(src, 'That mobile repeater configuration no longer exists.')
	end
	if not saveMobileRepeaters(vehicles) then
		return sendConfigError(src, 'Could not save mobileRepeaters.json. Check the server log.')
	end

	for networkId, activeRepeater in pairs(activeRepeaters) do
		if activeRepeater.modelHash == modelHash then
			disableActiveRepeater(networkId)
		end
	end
	TriggerClientEvent('SonoranRadio::MobileRepeaterDeleted', src)
end)

RegisterNetEvent('sonoranscripts::togglerepeater', function(networkId, enabled)
	if Config.enableVehicleRepeaters ~= true then
		return
	end
	local src = source
	local vehicle = getNetworkVehicle(src, networkId, true)
	local vehicleConfig = getVehicleRepeaterConfig(vehicle)
	if not vehicleConfig then
		return
	end

	if enabled == true then
		disableActiveRepeater(networkId)
		activeRepeaters[networkId] = {
			towerId = exports['sonoranradio']:createTower(buildRepeaterTower(vehicle, vehicleConfig)),
			modelHash = vehicleConfig.modelHash
		}
	else
		disableActiveRepeater(networkId)
	end
end)

RegisterNetEvent('sonoranscripts::updatepos', function(networkId)
	if Config.enableVehicleRepeaters ~= true then
		return
	end
	local src = source
	local vehicle = getNetworkVehicle(src, networkId, true)
	local vehicleConfig = getVehicleRepeaterConfig(vehicle)
	local activeRepeater = activeRepeaters[networkId]
	if not vehicleConfig or not activeRepeater then
		return
	end
	exports['sonoranradio']:updateTower(activeRepeater.towerId, buildRepeaterTower(vehicle, vehicleConfig))
end)

function RegPrint(...)
	print('^5[SONRAD]^7', ...)
end
