function initRepeaters()
    RepeaterVehicles = {}
    lastNotificaiton = nil

    RegisterNetEvent('sonoranscripts::mcc_decor', function()
        DecorSetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false), 'RepeaterActive',
                    not DecorGetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false)))
        TriggerServerEvent('sonoranscripts::togglerepeater',
                        NetworkGetNetworkIdFromEntity(
                            GetVehiclePedIsIn(GetPlayerPed(-1), false)),
                        DecorGetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false),
                                        'RepeaterActive'), GetEntityCoords(
                            GetVehiclePedIsIn(GetPlayerPed(-1), false)), 300)
    end)

    function isRegisteredVehicle(veh)
        for i = 1, #Config.repeaterVehicleSpawncodes do
            if GetEntityModel(veh) ==
                GetHashKey(Config.repeaterVehicleSpawncodes[i].model) then
                return true
            end
        end
        return false
    end

    function getVehicleConfig(veh)
        for i = 1, #Config.repeaterVehicleSpawncodes do
            if GetEntityModel(veh) ==
                GetHashKey(Config.repeaterVehicleSpawncodes[i].model) then
                return Config.repeaterVehicleSpawncodes[i]
            end
        end
        return false
    end

    Citizen.CreateThread(function()
        DecorRegister('RepeaterActive', 2)
        while true do
            Wait(1)
            -- Check if the player is entering a vehicle
            local entering = GetVehiclePedIsEntering(GetPlayerPed(-1))
            if entering ~= 0 and
                isRegisteredVehicle(GetVehiclePedIsIn(GetPlayerPed(-1), false)) and
                not IsVehicleAttachedToTrailer(
                    GetVehiclePedIsIn(GetPlayerPed(-1), false)) and
                (GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(-1), false), -1) ==
                    GetPlayerPed(-1) or
                    GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(-1), false),
                                        0) == GetPlayerPed(-1)) then
                if not DecorIsRegisteredAsType('RepeaterActive', 2) then
                    DecorRegister('RepeaterActive', 2)
                end
                -- Check if the vehicle has the decor bool registered and if not, register it
                if not DecorExistOn(GetVehiclePedIsIn(GetPlayerPed(-1), false),
                                    'RepeaterActive') then
                    DecorSetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false),
                                'RepeaterActive', false)
                end
                -- Check if the vehicle's repeater is enabled and notify the player
                if not DecorGetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false),
                                    'RepeaterActive') and lastNotificaiton ~=
                    entering then
                    notifyClient(
                        '~w~ This vehicle is equipped with radio repeaters, press "G" to ~g~enable')
                    lastNotificaiton = entering
                elseif lastNotificaiton ~= entering then
                    -- Check if the vehicle's repeater is disabled and notify the player
                    notifyClient(
                        '~w~ This vehicle is equipped with radio repeaters, press "G" to ~o~disable')
                    lastNotificaiton = entering
                end
                -- Check if the player is entering a vehicle and if the vehicle is registered and if the player is in the driver or passenger seat and if the vehicle is attached to a trailer
            elseif entering ~= 0 and
                IsVehicleAttachedToTrailer(
                    GetVehiclePedIsIn(GetPlayerPed(-1), false)) and
                (GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(-1), false), -1) ==
                    GetPlayerPed(-1) or
                    GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(-1), false),
                                        0) == GetPlayerPed(-1)) then
                local _, trailer = GetVehicleTrailerVehicle(GetVehiclePedIsIn(
                                                                GetPlayerPed(-1),
                                                                false))
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
                    if not DecorGetBool(trailer, 'RepeaterActive') and
                        lastNotificaiton ~= trailer then
                        notifyClient(
                            '~w~ Your trailer is equipped with radio repeaters, press "G" to ~g~enable')
                        lastNotificaiton = trailer
                    elseif lastNotificaiton ~= trailer then
                        -- Check if the trailer's repeater is disabled and notify the player
                        notifyClient(
                            '~w~ Your trailer is equipped with radio repeaters, press "G" to ~o~disable')
                        lastNotificaiton = trailer
                    end
                end
            end
        end
    end)

    RegisterCommand('togglerepeater', function()
        if (GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(-1), false), -1) ==
            GetPlayerPed(-1) or
            GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(-1), false), 0) ==
            GetPlayerPed(-1)) then
            -- Check if the player is hauling a trailer
            local isTrailer, trailer = GetVehicleTrailerVehicle(GetVehiclePedIsIn(
                                                                    GetPlayerPed(-1),
                                                                    false))
            -- Check if the player is in a registered vehicle or if the trailer is registered
            if isRegisteredVehicle(GetVehiclePedIsIn(GetPlayerPed(-1), false)) or
                isRegisteredVehicle(trailer) then
                -- If the player is in a trailer, toggle the repeater on the trailer
                if isTrailer then
                    -- Set the decor bool to the opposite of what it currently is
                    DecorSetBool(trailer, 'RepeaterActive',
                                not DecorGetBool(trailer, 'RepeaterActive'))
                    -- Trigger the server event to toggle the repeater. Parameters: trailer network ID, repeater status, trailer position, repeater range
                    TriggerServerEvent('sonoranscripts::togglerepeater',
                                    NetworkGetNetworkIdFromEntity(trailer),
                                    DecorGetBool(trailer, 'RepeaterActive'),
                                    GetEntityCoords(trailer),
                                    getVehicleConfig(trailer).range)
                    -- Show a notification to the player
                    notifyClient('~w~ Trailer radio repeater ' ..
                                    (DecorGetBool(trailer, 'RepeaterActive') and
                                        '~g~enabled' or '~o~disabled'))
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
                    DecorSetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false),
                                'RepeaterActive', not DecorGetBool(
                                    GetVehiclePedIsIn(GetPlayerPed(-1), false),
                                    'RepeaterActive'))
                    -- Trigger the server event to toggle the repeater. Parameters: vehicle network ID, repeater status, vehicle position, repeater range
                    TriggerServerEvent('sonoranscripts::togglerepeater',
                                    NetworkGetNetworkIdFromEntity(
                                        GetVehiclePedIsIn(GetPlayerPed(-1), false)),
                                    DecorGetBool(
                                        GetVehiclePedIsIn(GetPlayerPed(-1), false),
                                        'RepeaterActive'), GetEntityCoords(
                                        GetVehiclePedIsIn(GetPlayerPed(-1), false)),
                                    getVehicleConfig(
                                        GetVehiclePedIsIn(GetPlayerPed(-1), false)).range)
                    -- Show a notification to the player
                    notifyClient('~w~ Radio repeater ' ..
                                    (DecorGetBool(
                                        GetVehiclePedIsIn(GetPlayerPed(-1), false),
                                        'RepeaterActive') and '~g~enabled' or
                                        '~o~disabled'))
                    -- If the repeater is enabled, add the vehicle to the repeater table
                    if DecorGetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false),
                                    'RepeaterActive') then
                        RepeaterVehicles[GetVehiclePedIsIn(GetPlayerPed(-1), false)] =
                            true
                        -- If the repeater is disabled, remove the vehicle from the repeater table
                    else
                        RepeaterVehicles[GetVehiclePedIsIn(GetPlayerPed(-1), false)] =
                            nil
                    end
                end
            else
                notifyClient('~r~This vehicle is not equipped with radio repeaters')
            end
        else
            notifyClient(
                '~r~You must be in the driver or passenger seat to toggle the radio repeater')
        end
    end)

    if Config.enableVehicleRepeaters then
        if not Config.mobileRepeaterKeybind then
            Config.mobileRepeaterKeybind = {
                mapperType = 'keyboard',
                map = 'g',
                label = 'Toggle Radio Repeater'
            }
        end
        if not Config.mobileRepeaterKeybind.label then
            Config.mobileRepeaterKeybind.label = 'Toggle Radio Repeater'
        end
        if not Config.mobileRepeaterKeybind.mapperType then
            Config.mobileRepeaterKeybind.mapperType = 'keyboard'
        end
        if not Config.mobileRepeaterKeybind.map then
            Config.mobileRepeaterKeybind.map = 'g'
        end
        RegisterKeyMapping('togglerepeater', Config.mobileRepeaterKeybind.label, Config.mobileRepeaterKeybind.mapperType, Config.mobileRepeaterKeybind.map)
    end

    -- Citizen.CreateThread(function()
    --     while true do
    --         Wait(1)
    --         -- Logic required to pass if statement: 1. Player pressed G, 2. Player is either in the driver or passenger seat
    --         if IsControlJustReleased(0, 58) and
    --             (GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(-1), false), -1) ==
    --                 GetPlayerPed(-1) or
    --                 GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(-1), false),
    --                                     0) == GetPlayerPed(-1)) then
    --             -- Check if the player is hauling a trailer
    --             local isTrailer, trailer = GetVehicleTrailerVehicle(
    --                                            GetVehiclePedIsIn(GetPlayerPed(-1),
    --                                                              false))
    --             -- Check if the player is in a registered vehicle or if the trailer is registered
    --             if isRegisteredVehicle(GetVehiclePedIsIn(GetPlayerPed(-1), false)) or
    --                 isRegisteredVehicle(trailer) then
    --                 -- If the player is in a trailer, toggle the repeater on the trailer
    --                 if isTrailer then
    --                     -- Set the decor bool to the opposite of what it currently is
    --                     DecorSetBool(trailer, 'RepeaterActive',
    --                                  not DecorGetBool(trailer, 'RepeaterActive'))
    --                     -- Trigger the server event to toggle the repeater. Parameters: trailer network ID, repeater status, trailer position, repeater range
    --                     TriggerServerEvent('sonoranscripts::togglerepeater',
    --                                        NetworkGetNetworkIdFromEntity(trailer),
    --                                        DecorGetBool(trailer, 'RepeaterActive'),
    --                                        GetEntityCoords(trailer),
    --                                        getVehicleConfig(trailer).range)
    --                     -- Show a notification to the player
    --                     notifyClient(
    --                         '~w~ Trailer radio repeater ' ..
    --                             (DecorGetBool(trailer, 'RepeaterActive') and
    --                                 '~g~enabled' or '~o~disabled'))
    --                     -- If the repeater is enabled, add the trailer to the repeater table
    --                     if DecorGetBool(trailer, 'RepeaterActive') then
    --                         RepeaterVehicles[trailer] = true
    --                         -- If the repeater is disabled, remove the trailer from the repeater table
    --                     else
    --                         RepeaterVehicles[trailer] = nil
    --                     end
    --                 else
    --                     -- If the player is in a vehicle, toggle the repeater on the vehicle
    --                     -- Set the decor bool to the opposite of what it currently is
    --                     DecorSetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false),
    --                                  'RepeaterActive', not DecorGetBool(
    --                                      GetVehiclePedIsIn(GetPlayerPed(-1), false),
    --                                      'RepeaterActive'))
    --                     -- Trigger the server event to toggle the repeater. Parameters: vehicle network ID, repeater status, vehicle position, repeater range
    --                     TriggerServerEvent('sonoranscripts::togglerepeater',
    --                                        NetworkGetNetworkIdFromEntity(
    --                                            GetVehiclePedIsIn(GetPlayerPed(-1),
    --                                                              false)),
    --                                        DecorGetBool(
    --                                            GetVehiclePedIsIn(GetPlayerPed(-1),
    --                                                              false),
    --                                            'RepeaterActive'), GetEntityCoords(
    --                                            GetVehiclePedIsIn(GetPlayerPed(-1),
    --                                                              false)),
    --                                        getVehicleConfig(
    --                                            GetVehiclePedIsIn(GetPlayerPed(-1),
    --                                                              false)).range)
    --                     -- Show a notification to the player
    --                     notifyClient('~w~ Radio repeater ' ..
    --                                      (DecorGetBool(
    --                                          GetVehiclePedIsIn(GetPlayerPed(-1),
    --                                                            false),
    --                                          'RepeaterActive') and '~g~enabled' or
    --                                          '~o~disabled'))
    --                     -- If the repeater is enabled, add the vehicle to the repeater table
    --                     if DecorGetBool(GetVehiclePedIsIn(GetPlayerPed(-1), false),
    --                                     'RepeaterActive') then
    --                         RepeaterVehicles[GetVehiclePedIsIn(GetPlayerPed(-1),
    --                                                            false)] = true
    --                         -- If the repeater is disabled, remove the vehicle from the repeater table
    --                     else
    --                         RepeaterVehicles[GetVehiclePedIsIn(GetPlayerPed(-1),
    --                                                            false)] = nil
    --                     end
    --                 end
    --             end
    --         end
    --     end
    -- end)
end