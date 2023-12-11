local RepeaterVehicles = {}
local lastNotificaiton = nil

RegisterNetEvent('sonoranscripts::mcc_decor', function()
	DecorSetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive', not DecorGetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false)))
	TriggerServerEvent('sonoranscripts::togglerepeater', NetworkGetNetworkIdFromEntity(GetVehiclePedIsIn(GetPlayerPed(-1), false)),
	                   DecorGetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive'), GetEntityCoords(GetVehiclePedIsIn(GetPlayerPed(-1), false)), 300)
end)

local function isRegisteredVehicle(veh)
	for i = 1, #Config.repeaterVehicleSpawncodes do
		if GetEntityModel(veh) == GetHashKey(Config.repeaterVehicleSpawncodes[i].model) then
			return true
		end
	end
	return false
end

local function getVehicleConfig(veh)
	for i = 1, #Config.repeaterVehicleSpawncodes do
		if GetEntityModel(veh) == GetHashKey(Config.repeaterVehicleSpawncodes[i].model) then
			return Config.repeaterVehicleSpawncodes[i]
		end
	end
	return false
end

Citizen.CreateThread(function()
	DecorRegister('RepeaterActive', 2)
	while true do
		Wait(100)
		-- Check if the players vehicle's radio repeater is active and if the player has control of the vehicle (not in a cutscene, etc.)
		if DecorGetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive') and NetworkHasControlOfEntity(GetVehiclePedIsIn(GetPlayerPed(-1), false)) then
			-- Check if the vehicle is not damaged beyond repair. | 0 and below: Engine catches fire and health rapidly declines | 300: Engine is smoking and losing functionality | 1000: Engine is perfectly fine
			if GetVehicleEngineHealth(GetVehiclePedIsIn(GetPlayerPed(-1, false))) < -1000 then
				-- If the vehicle is damaged beyond repair, disable the repeater and notify the player
				-- Set the decor bool to false
				DecorSetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive', false)
				-- Trigger the server event to toggle the repeater. Parameters: vehicle network ID, repeater status, vehicle position, repeater range
				TriggerServerEvent('sonoranscripts::togglerepeater', NetworkGetNetworkIdFromEntity(GetVehiclePedIsIn(GetPlayerPed(-1), false)))
				-- Show a notification to the player
				notifyClient('~b~[SonoranRadio]:~w~ Radio repeater ~o~disabled~w~ due to engine damage')
				-- Remove the vehicle from the repeater table
				RepeaterVehicles[GetVehiclePedIsIn(GetPlayerPed(-1), false)] = nil
			end
			-- Update the repeater position every 100ms
			TriggerServerEvent('sonoranscripts::updatepos', NetworkGetNetworkIdFromEntity(GetVehiclePedIsIn(GetPlayerPed(-1), false)), GetEntityCoords(GetVehiclePedIsIn(GetPlayerPed(-1), false)),
			                   getVehicleConfig(GetVehiclePedIsIn(GetPlayerPed(-1), false)).range)
		end
		-- Loop through the repeater table and check if the vehicle still exists and if it is damaged beyond repair
		for k, _ in pairs(RepeaterVehicles) do
			if not DoesEntityExist(k) then
				RepeaterVehicles[k] = nil
			end
			if GetVehicleEngineHealth(k) < -1000 then
				DecorSetBool(k, 'RepeaterActive', false)
				TriggerServerEvent('sonoranscripts::togglerepeater', NetworkGetNetworkIdFromEntity(k))
				notifyClient('~b~[SonoranRadio]:~w~ Radio repeater ~o~disabled~w~ due to engine damage')
				RepeaterVehicles[k] = nil
			end
		end
		-- Check if the player is entering a vehicle
		local entering = GetVehiclePedIsEntering(GetPlayerPed(-1))
		-- Check if the player is entering a vehicle and if the vehicle is registered and if the player is in the driver or passenger seat
		if entering ~= 0 and isRegisteredVehicle(GetVehiclePedIsIn(GetPlayerPed(-1), false)) and not IsVehicleAttachedToTrailer(GetVehiclePedIsIn(GetPlayerPed(-1), false))
						and (GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(-1), false), -1) == GetPlayerPed(-1) or GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(-1), false), 0) == GetPlayerPed(-1)) then
			if not DecorIsRegisteredAsType('RepeaterActive', 2) then
				DecorRegister('RepeaterActive', 2)
			end
			-- Check if the vehicle has the decor bool registered and if not, register it
			if not DecorExistOn(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive') then
				DecorSetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive', false)
			end
			-- Check if the vehicle's repeater is enabled and notify the player
			if not DecorGetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive') and lastNotificaiton ~= entering then
				notifyClient('~b~[SonoranRadio]:~w~ This vehicle is equipped with radio repeaters, press "G" to ~g~enable')
				lastNotificaiton = entering
			elseif lastNotificaiton ~= entering then
				-- Check if the vehicle's repeater is disabled and notify the player
				notifyClient('~b~[SonoranRadio]:~w~ This vehicle is equipped with radio repeaters, press "G" to ~o~disable')
				lastNotificaiton = entering
			end
			-- Check if the player is entering a vehicle and if the vehicle is registered and if the player is in the driver or passenger seat and if the vehicle is attached to a trailer
		elseif entering ~= 0 and IsVehicleAttachedToTrailer(GetVehiclePedIsIn(GetPlayerPed(-1), false))
						and (GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(-1), false), -1) == GetPlayerPed(-1) or GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(-1), false), 0) == GetPlayerPed(-1)) then
			local _, trailer = GetVehicleTrailerVehicle(GetVehiclePedIsIn(GetPlayerPed(-1), false))
			-- Check if the trailer is registered
			if trailer ~= 0 and isRegisteredVehicle(trailer) then
				-- Check if the decor bool is registered and register it if not
				if not DecorIsRegisteredAsType('RepeaterActive', 2) then
					DecorRegister('RepeaterActive', 2)
				end
				-- Check if the trailer has the decor bool registered and if not, register it
				if not DecorExistOn(trailer, 'RepeaterActive') then
					DecorSetBool(trailer, 'RepeaterActive', false)
				end
				-- Check if the trailer's repeater is enabled and notify the player
				if not DecorGetBool(trailer, 'RepeaterActive') and lastNotificaiton ~= trailer then
					notifyClient('~b~[SonoranRadio]:~w~ Your trailer is equipped with radio repeaters, press "G" to ~g~enable')
					lastNotificaiton = trailer
				elseif lastNotificaiton ~= trailer then
					-- Check if the trailer's repeater is disabled and notify the player
					notifyClient('~b~[SonoranRadio]:~w~ Your trailer is equipped with radio repeaters, press "G" to ~o~disable')
					lastNotificaiton = trailer
				end
			end
		end
	end
end)

Citizen.CreateThread(function()
	while true do
		Wait(1)
		-- Logic required to pass if statement: 1. Player pressed G, 2. Player is either in the driver or passenger seat
		if IsControlJustReleased(0, 58)
						and (GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(-1), false), -1) == GetPlayerPed(-1) or GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(-1), false), 0) == GetPlayerPed(-1)) then
			-- Check if the player is hauling a trailer
			local isTrailer, trailer = GetVehicleTrailerVehicle(GetVehiclePedIsIn(GetPlayerPed(-1), false))
			-- Check if the player is in a registered vehicle or if the trailer is registered
			if isRegisteredVehicle(GetVehiclePedIsIn(GetPlayerPed(-1), false)) or isRegisteredVehicle(trailer) then
				-- If the player is in a trailer, toggle the repeater on the trailer
				if isTrailer then
					-- Set the decor bool to the opposite of what it currently is
					DecorSetBool(trailer, 'RepeaterActive', not DecorGetBool(trailer, 'RepeaterActive'))
					-- Trigger the server event to toggle the repeater. Parameters: trailer network ID, repeater status, trailer position, repeater range
					TriggerServerEvent('sonoranscripts::togglerepeater', NetworkGetNetworkIdFromEntity(trailer), DecorGetBool(trailer, 'RepeaterActive'), GetEntityCoords(trailer), getVehicleConfig(trailer).range)
					-- Show a notification to the player
					notifyClient('~b~[SonoranRadio]:~w~ Trailer radio repeater ' .. (DecorGetBool(trailer, 'RepeaterActive') and '~g~enabled' or '~o~disabled'))
					-- If the repeater is enabled, add the trailer to the repeater table
					if DecorGetBool(trailer, 'RepeaterActive') then
						RepeaterVehicles[trailer] = true
						-- If the repeater is disabled, remove the trailer from the repeater table
					else
						RepeaterVehicles[trailer] = nil
					end
				else
					-- If the player is in a vehicle, toggle the repeater on the vehicle
					-- Set the decor bool to the opposite of what it currently is
					DecorSetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive', not DecorGetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive'))
					-- Trigger the server event to toggle the repeater. Parameters: vehicle network ID, repeater status, vehicle position, repeater range
					TriggerServerEvent('sonoranscripts::togglerepeater', NetworkGetNetworkIdFromEntity(GetVehiclePedIsIn(GetPlayerPed(-1), false)),
					                   DecorGetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive'), GetEntityCoords(GetVehiclePedIsIn(GetPlayerPed(-1), false)),
					                   getVehicleConfig(GetVehiclePedIsIn(GetPlayerPed(-1), false)).range)
					-- Show a notification to the player
					notifyClient('~b~[SonoranRadio]:~w~ Radio repeater ' .. (DecorGetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive') and '~g~enabled' or '~o~disabled'))
					-- If the repeater is enabled, add the vehicle to the repeater table
					if DecorGetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive') then
						RepeaterVehicles[GetVehiclePedIsIn(GetPlayerPed(-1), false)] = true
						-- If the repeater is disabled, remove the vehicle from the repeater table
					else
						RepeaterVehicles[GetVehiclePedIsIn(GetPlayerPed(-1), false)] = nil
					end
				end
			end
		end
	end
end)
