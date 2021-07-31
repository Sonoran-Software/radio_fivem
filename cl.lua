RegisterCommand('radio', function()
    SendNUIMessage({type = 'show'})
    SetNuiFocus(true, true)
end)

RegisterNUICallback('data', function(data, cb)
    if data.type == 'hide' then
        SendNUIMessage({type = 'hide'})
        SetNuiFocus(false, false)
    end

    cb('OK')
end)

Citizen.CreateThread(function()
    SetNuiFocus(false, false)
    while true do
        local ped = GetPlayerPed(-1)
        if DoesEntityExist(ped) then
            local pos = GetEntityCoords(ped)
            local posArr = {math.floor(pos.x), math.floor(pos.y), math.floor(pos.z)}
            SendNUIMessage({type = 'update_position', position = posArr})
        end
        Citizen.Wait(5000)
    end
end)
