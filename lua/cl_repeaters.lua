MobileRepeaterVehicles = MobileRepeaterVehicles or {}

local function getConfiguredModelHash(vehicleConfig)
	if type(vehicleConfig) ~= 'table' then
		return nil
	end
	if vehicleConfig.modelHash ~= nil then
		return tonumber(vehicleConfig.modelHash)
	end
	if type(vehicleConfig.model) == 'string' and vehicleConfig.model ~= '' then
		return GetHashKey(vehicleConfig.model)
	end
	return nil
end

function isRegisteredVehicle(vehicle)
	if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
		return false
	end
	local modelHash = GetEntityModel(vehicle)
	for _, vehicleConfig in ipairs(MobileRepeaterVehicles) do
		if getConfiguredModelHash(vehicleConfig) == modelHash then
			return true
		end
	end
	return false
end

function getVehicleConfig(vehicle)
	if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
		return false
	end
	local modelHash = GetEntityModel(vehicle)
	for _, vehicleConfig in ipairs(MobileRepeaterVehicles) do
		if getConfiguredModelHash(vehicleConfig) == modelHash then
			return vehicleConfig
		end
	end
	return false
end

local function ensureRepeaterDecor(vehicle)
	if not DecorIsRegisteredAsType('RepeaterActive', 2) then
		DecorRegister('RepeaterActive', 2)
	end
	if not DecorExistOn(vehicle, 'RepeaterActive') then
		DecorSetBool(vehicle, 'RepeaterActive', false)
	end
end

local function getRepeaterNetworkId(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) or not NetworkGetEntityIsNetworked(vehicle) then
		return nil
	end
	local networkId = NetworkGetNetworkIdFromEntity(vehicle)
	if not networkId or networkId <= 0 then
		return nil
	end
	return networkId
end

local function setRepeaterEnabled(vehicle, enabled)
	local networkId = getRepeaterNetworkId(vehicle)
	if not networkId then
		notifyClient('This vehicle is not networked, so its radio repeater cannot be toggled', nil, '~r~')
		return false
	end

	ensureRepeaterDecor(vehicle)
	DecorSetBool(vehicle, 'RepeaterActive', enabled == true)
	TriggerServerEvent('sonoranscripts::togglerepeater', networkId, enabled == true)
	if enabled then
		RepeaterVehicles[vehicle] = true
	else
		RepeaterVehicles[vehicle] = nil
	end
	return true
end

local function getPlayerRepeaterTarget()
	local ped = PlayerPedId()
	local vehicle = GetVehiclePedIsIn(ped, false)
	if vehicle == 0 then
		return 0, false
	end
	if GetPedInVehicleSeat(vehicle, -1) ~= ped and GetPedInVehicleSeat(vehicle, 0) ~= ped then
		return 0, false
	end

	local hasTrailer, trailer = GetVehicleTrailerVehicle(vehicle)
	if hasTrailer and trailer ~= 0 and isRegisteredVehicle(trailer) then
		return trailer, true
	end
	if isRegisteredVehicle(vehicle) then
		return vehicle, false
	end
	return 0, false
end

function initRepeaters()
	RepeaterVehicles = {}
	local lastNotificationKey = nil

	RegisterNetEvent('SonoranRadio::SyncMobileRepeaters', function(vehicles)
		MobileRepeaterVehicles = type(vehicles) == 'table' and vehicles or {}
		for vehicle in pairs(RepeaterVehicles) do
			if not isRegisteredVehicle(vehicle) then
				if DoesEntityExist(vehicle) and DecorExistOn(vehicle, 'RepeaterActive') then
					DecorSetBool(vehicle, 'RepeaterActive', false)
				end
				RepeaterVehicles[vehicle] = nil
			end
		end
	end)

	RegisterNetEvent('sonoranscripts::mcc_decor', function()
		if not Config.enableVehicleRepeaters then
			return
		end
		local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
		if not isRegisteredVehicle(vehicle) then
			return
		end
		ensureRepeaterDecor(vehicle)
		setRepeaterEnabled(vehicle, not DecorGetBool(vehicle, 'RepeaterActive'))
	end)

	Citizen.CreateThread(function()
		DecorRegister('RepeaterActive', 2)
		while true do
			Wait(500)
			if Config.enableVehicleRepeaters then
				local target, isTrailer = getPlayerRepeaterTarget()
				if target ~= 0 then
					ensureRepeaterDecor(target)
					local enabled = DecorGetBool(target, 'RepeaterActive')
					local notificationKey = ('%s:%s'):format(target, tostring(enabled))
					if notificationKey ~= lastNotificationKey then
						local subject = isTrailer and 'Your trailer' or 'This vehicle'
						notifyClient(('%s is equipped with a radio repeater; use the repeater keybind to %s it'):format(subject, enabled and 'disable' or 'enable'), nil, enabled and '~o~' or '~g~')
						lastNotificationKey = notificationKey
					end
				else
					lastNotificationKey = nil
				end
			end
		end
	end)

	RegisterCommand('togglerepeater', function()
		if not Config.enableVehicleRepeaters then
			return
		end

		local ped = PlayerPedId()
		local occupiedVehicle = GetVehiclePedIsIn(ped, false)
		if occupiedVehicle == 0 or (GetPedInVehicleSeat(occupiedVehicle, -1) ~= ped and GetPedInVehicleSeat(occupiedVehicle, 0) ~= ped) then
			return notifyClient('You must be in the driver or front passenger seat to toggle the radio repeater', nil, '~r~')
		end

		local target, isTrailer = getPlayerRepeaterTarget()
		if target == 0 then
			return notifyClient('This vehicle is not equipped with radio repeaters', nil, '~r~')
		end

		ensureRepeaterDecor(target)
		local enabled = not DecorGetBool(target, 'RepeaterActive')
		if setRepeaterEnabled(target, enabled) then
			local subject = isTrailer and 'Trailer radio repeater' or 'Radio repeater'
			notifyClient(('%s %s'):format(subject, enabled and 'enabled' or 'disabled'), nil, enabled and '~g~' or '~o~')
		end
	end)

	if Config.enableVehicleRepeaters then
		Config.mobileRepeaterKeybind = Config.mobileRepeaterKeybind or {}
		Config.mobileRepeaterKeybind.label = Config.mobileRepeaterKeybind.label or 'Toggle Radio Repeater'
		Config.mobileRepeaterKeybind.mapperType = Config.mobileRepeaterKeybind.mapperType or 'keyboard'
		Config.mobileRepeaterKeybind.map = Config.mobileRepeaterKeybind.map or 'g'
		RegisterKeyMapping('togglerepeater', Config.mobileRepeaterKeybind.label, Config.mobileRepeaterKeybind.mapperType, Config.mobileRepeaterKeybind.map)
	end

	TriggerServerEvent('SonoranRadio::RequestMobileRepeaters')
end
