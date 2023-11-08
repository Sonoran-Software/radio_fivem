TriggerServerEvent('sonoranscripts::togglerepeater', NetworkGetNetworkIdFromEntity(GetVehiclePedIsIn(PlayerPedId(), false)), DecorGetBool(GetVehiclePedIsIn(PlayerPedId(), false), 'RepeaterActive'),
                   GetEntityCoords(GetVehiclePedIsIn(PlayerPedId(), false)))

RegisterNetEvent('sonoranscripts::mcc_decor', function()
	DecorSetBool(GetVehiclePedIsIn(PlayerPedId(), false), 'RepeaterActive', not DecorGetBool(GetVehiclePedIsIn(PlayerPedId(), false)))
	TriggerServerEvent('sonoranscripts::togglerepeater', NetworkGetNetworkIdFromEntity(GetVehiclePedIsIn(PlayerPedId(), false)), DecorGetBool(GetVehiclePedIsIn(PlayerPedId(), false), 'RepeaterActive'),
	                   GetEntityCoords(GetVehiclePedIsIn(PlayerPedId(), false)))
end)

local function isRegisteredVehicle(veh)
	for i = 1, #config.repeaterVehicleHashes do
		if GetEntityModel(veh) == GetHashKey(config.repeaterVehicleHashes[i]) then
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
		if DecorGetBool(GetVehiclePedIsIn(PlayerPedId(), false), 'RepeaterActive') and NetworkHasControlOfEntity(GetVehiclePedIsIn(PlayerPedId(), false)) then
			TriggerServerEvent('sonoranscripts::updatepos', NetworkGetNetworkIdFromEntity(GetVehiclePedIsIn(PlayerPedId(), false)), GetEntityCoords(GetVehiclePedIsIn(PlayerPedId(), false)))
		end
		local entering = GetVehiclePedIsEntering(PlayerPedId())
		if entering ~= 0 and isRegisteredVehicle(entering) and (GetPedInVehicleSeat(entering, -1) == PlayerPedId() or GetPedInVehicleSeat(entering, 0) == PlayerPedId()) then
			if not DecorIsRegisteredAsType('RepeaterActive', 2) then
				DecorRegister('RepeaterActive', 2)
			end
			if not DecorExistOn(entering, 'RepeaterActive') then
				DecorSetBool(entering, 'RepeaterActive', false)
			end
			if not DecorGetBool(entering, 'RepeaterActive') then
				ShowNotification('Press ~INPUT_CONTEXT~ to enable the radio repeater')
			else
				ShowNotification('Press ~INPUT_CONTEXT~ to disable the radio repeater')
			end
		elseif entering ~= 0 and IsVehicleAttachedToTrailer(entering) and (GetPedInVehicleSeat(entering, -1) == PlayerPedId() or GetPedInVehicleSeat(entering, 0) == PlayerPedId()) then
			local _, trailer = GetVehicleTrailerVehicle(entering)
			if trailer ~= 0 and isRegisteredVehicle(trailer) then
				if not DecorIsRegisteredAsType('RepeaterActive', 2) then
					DecorRegister('RepeaterActive', 2)
				end
				if not DecorExistOn(trailer, 'RepeaterActive') then
					DecorSetBool(trailer, 'RepeaterActive', false)
				end
				if not DecorGetBool(trailer, 'RepeaterActive') then
					ShowNotification('Press ~INPUT_CONTEXT~ to enable the radio repeater on the trailer')
				else
					ShowNotification('Press ~INPUT_CONTEXT~ to disable the radio repeater on the trailer')
				end
			end
		end
		if IsControlJustReleased(0, 38) and entering ~= 0 and isRegisteredVehicle(entering) then
			DecorSetBool(entering, 'RepeaterActive', not DecorGetBool(entering, 'RepeaterActive'))
			TriggerServerEvent('sonoranscripts::togglerepeater', NetworkGetNetworkIdFromEntity(entering), DecorGetBool(entering, 'RepeaterActive'), GetEntityCoords(entering))
			ShowNotification('Radio repeater ' .. (DecorGetBool(entering, 'RepeaterActive') and 'enabled' or 'disabled'))
		end
	end
end)
