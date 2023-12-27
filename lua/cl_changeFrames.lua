RegisterNetEvent('SonoranRadio::AdminSkinChange', function(frame)
    TriggerServerEvent('SonoranRadio::AdminSkinChange', frame)
    SendNUIMessage({
        type = 'setCurrentSkin',
        skin = frame
    })
end)