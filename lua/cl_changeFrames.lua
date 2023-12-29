RegisterNetEvent('SonoranRadio::AdminSkinChange', function(frame)
    TriggerEvent('chat:addMessage', {
        args = {
            '^1SonoranRadio',
            'Changed your radio skin to ' .. frame .. ''
        }
    })
    TriggerServerEvent('SonoranRadio::AdminSkinChange', frame)
    SendNUIMessage({
        type = 'setCurrentSkin',
        skin = frame
    })
end)