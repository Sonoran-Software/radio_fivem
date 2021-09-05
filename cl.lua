RegisterCommand('vue', function()
    SendNUIMessage({type = 'show'})
    SetNuiFocus(true, true)
end)

Citizen.CreateThread(function()
    SetNuiFocus(false, false)
    while true do
        Citizen.Wait(5000)
    end
end)

RegisterCommand('hello', function()
    SendNUIMessage({type = 'hello'})
    SetNuiFocus(true, true)
end)