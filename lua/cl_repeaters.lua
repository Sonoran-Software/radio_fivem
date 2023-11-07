TriggerServerEvent(
    'sonoranscripts::togglerepeater',
    NetworkGetNetworkIdFromEntity(GetVehiclePedIsIn(PlayerPedId(), false)),
    DecorGetBool(GetVehiclePedIsIn(PlayerPedId(), false), 'RepeaterActive'),
    GetEntityCoords(GetVehiclePedIsIn(PlayerPedId(), false))
)

 RegisterNetEvent(
     'sonoranscripts::mcc_decor',
     function()
         DecorSetBool(GetVehiclePedIsIn(PlayerPedId(), false), 'RepeaterActive', not DecorGetBool(GetVehiclePedIsIn(PlayerPedId(), false)))
         TriggerServerEvent(
             'sonoranscripts::togglerepeater',
             NetworkGetNetworkIdFromEntity(GetVehiclePedIsIn(PlayerPedId(), false)),
             DecorGetBool(GetVehiclePedIsIn(PlayerPedId(), false), 'RepeaterActive'),
             GetEntityCoords(GetVehiclePedIsIn(PlayerPedId(), false))
         )
     end
 )

 Citizen.CreateThread(
    function()
        DecorRegister('RepeaterActive', 2)
    end

    if DecorGetBool(GetVehiclePedIsIn(PlayerPedId(), false), 'RepeaterActive') and NetworkHasControlOfEntity(GetVehiclePedIsIn(PlayerPedId(), false)) then
        TriggerServerEvent(
        'sonoranscripts::updatepos',
        NetworkGetNetworkIdFromEntity(GetVehiclePedIsIn(PlayerPedId(), false)),
        GetEntityCoords(GetVehiclePedIsIn(PlayerPedId(), false))
        )
    end
end)

