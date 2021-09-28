local radActive = false

RegisterCommand('radio', function()
    radActive = not radActive
    SendNUIMessage({
        type = 'setVisible',
        visibility = radActive
    })
    SetNuiFocus(radActive, radActive)
end)

Citizen.CreateThread(function()
    SetNuiFocus(false, false)
    while true do
        local ped = GetPlayerPed(-1)
        if DoesEntityExist(ped) then
            local pos = GetEntityCoords(ped)
            local posArr = {math.floor(pos.x), math.floor(pos.y), math.floor(pos.z)}
            SendNUIMessage({type = 'setPos', position = posArr })
        end
        Citizen.Wait(5000)
    end
    -- For Development Only
    print('Sonoran Radio Started!')
end)

RegisterCommand('hello', function()
    SendNUIMessage({type = 'hello'})
end)

RegisterNUICallback('data', function(data, cb)
    print('data:' .. json.encode(data))
    if data.type == 'hide' then
        SendNUIMessage({
            type = 'setVisible',
            visibility = false
        })
        radActive = false
        SetNuiFocus(false, false)
    end

    cb('OK')
end)