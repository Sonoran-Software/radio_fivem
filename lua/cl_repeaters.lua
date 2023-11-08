RegisterNetEvent('sonoranscripts::mcc_decor', function()
	DecorSetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive', not DecorGetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false)))
	TriggerServerEvent('sonoranscripts::togglerepeater', NetworkGetNetworkIdFromEntity(GetVehiclePedIsIn(GetPlayerPed(-1), false)),
	                   DecorGetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive'), GetEntityCoords(GetVehiclePedIsIn(GetPlayerPed(-1), false)))
end)

local function isRegisteredVehicle(veh)
	for i = 1, #Config.repeaterVehicleHashes do
		if GetEntityModel(veh) == GetHashKey(Config.repeaterVehicleHashes[i]) then
			return true
		end
	end
	return false
end

-- Draw notificaiton above map
local function ShowNotification(text)
	SetNotificationTextEntry('STRING')
	AddTextComponentString(text)
	DrawNotification(false, false)
end

Citizen.CreateThread(function()
	DecorRegister('RepeaterActive', 2)
	while true do
		Wait(100)
		if DecorGetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive') and NetworkHasControlOfEntity(GetVehiclePedIsIn(GetPlayerPed(-1), false)) then
			TriggerServerEvent('sonoranscripts::updatepos', NetworkGetNetworkIdFromEntity(GetVehiclePedIsIn(GetPlayerPed(-1), false)), GetEntityCoords(GetVehiclePedIsIn(GetPlayerPed(-1), false)))
		end
		local entering = GetVehiclePedIsEntering(GetPlayerPed(-1))
		if entering ~= 0 and isRegisteredVehicle(GetVehiclePedIsIn(GetPlayerPed(-1), false)) and not IsVehicleAttachedToTrailer(GetVehiclePedIsIn(GetPlayerPed(-1), false))
						and (GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(-1), false), -1) == GetPlayerPed(-1) or GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(-1), false), 0) == GetPlayerPed(-1)) then
			if not DecorIsRegisteredAsType('RepeaterActive', 2) then
				DecorRegister('RepeaterActive', 2)
			end
			if not DecorExistOn(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive') then
				DecorSetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive', false)
			end
			if not DecorGetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive') then
				ShowNotification('~b~[SonoranRadio]:~w~ This vehicle is equipped with radio repeaters, press "G" to enable')
			else
				ShowNotification('~b~[SonoranRadio]:~w~ This vehicle is equipped with radio repeaters, press "G" to disable')
			end
		elseif entering ~= 0 and IsVehicleAttachedToTrailer(GetVehiclePedIsIn(GetPlayerPed(-1), false))
						and (GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(-1), false), -1) == GetPlayerPed(-1) or GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(-1), false), 0) == GetPlayerPed(-1)) then
			local _, trailer = GetVehicleTrailerVehicle(GetVehiclePedIsIn(GetPlayerPed(-1), false))
			if trailer ~= 0 and isRegisteredVehicle(trailer) then
				if not DecorIsRegisteredAsType('RepeaterActive', 2) then
					DecorRegister('RepeaterActive', 2)
				end
				if not DecorExistOn(trailer, 'RepeaterActive') then
					DecorSetBool(trailer, 'RepeaterActive', false)
				end
				if not DecorGetBool(trailer, 'RepeaterActive') then
					ShowNotification('~b~[SonoranRadio]:~w~ Your trailer is equipped with radio repeaters, press "G" to enable')
				else
					ShowNotification('~b~[SonoranRadio]:~w~ Your trailer is equipped with radio repeaters, press "G" to disable')
				end
			end
		end
	end
end)

Citizen.CreateThread(function()
	while true do
		Wait(1)
		if IsControlJustReleased(0, 58)
						and (GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(-1), false), -1) == GetPlayerPed(-1) or GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(-1), false), 0) == GetPlayerPed(-1)) then
			local isTrailer, trailer = GetVehicleTrailerVehicle(GetVehiclePedIsIn(GetPlayerPed(-1), false))
			if isRegisteredVehicle(GetVehiclePedIsIn(GetPlayerPed(-1), false)) or isRegisteredVehicle(trailer) then
				if isTrailer then
					DecorSetBool(trailer, 'RepeaterActive', not DecorGetBool(trailer, 'RepeaterActive'))
					TriggerServerEvent('sonoranscripts::togglerepeater', NetworkGetNetworkIdFromEntity(trailer), DecorGetBool(trailer, 'RepeaterActive'), GetEntityCoords(trailer))
					ShowNotification('~b~[SonoranRadio]:~w~ Trailer radio repeater ' .. (DecorGetBool(trailer, 'RepeaterActive') and 'enabled' or 'disabled'))
				else
					DecorSetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive', not DecorGetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive'))
					TriggerServerEvent('sonoranscripts::togglerepeater', NetworkGetNetworkIdFromEntity(GetVehiclePedIsIn(GetPlayerPed(-1), false)),
					                   DecorGetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive'), GetEntityCoords(GetVehiclePedIsIn(GetPlayerPed(-1), false)))
					ShowNotification('~b~[SonoranRadio]:~w~ Radio repeater ' .. (DecorGetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive') and 'enabled' or 'disabled'))
				end
			end
		end
	end
end)
