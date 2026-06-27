--[[
/*******************************************************
 *
 * This code is a component of ICT_Emergency_Call_Handler. It has been licensed to Sonoran Software Systems, LLC for commercial use, including modification.
 * Use of this code is granted in exchange for reasonable compensation to IC Technologies.
 *
 * Unauthorized reproduction, distribution, or modifications is strictly prohibited.
 *
 *******************************************************/
]]

function initLbPhone()
    CallData = {
        status = nil,
        callID = nil,
        src = GetPlayerServerId(PlayerId()),
        hasDispatcher = false,
        dispatcherNames = nil,
        inEmergencyCall = false,
        totalCallLength = 0,
    }
    local number911 = tostring(Config.emergencyCallCommand or "911")
    local function CanCallEmergencyNumber()
        local number = exports["lb-phone"]:GetEquippedPhoneNumber()
        local hasRequiredItem = exports["lb-phone"]:HasPhoneItem(number)

        local airplaneMode = exports["lb-phone"]:GetAirplaneMode()
        DebugPrint("Airplane mode: " .. tostring(airplaneMode))

        local isPhoneDead = exports["lb-phone"]:IsPhoneDead()
        DebugPrint("isPhoneDead: " .. tostring(isPhoneDead))

        DebugPrint("Can call Emergency Number: " .. tostring(hasRequiredItem and not isPhoneDead and not airplaneMode))
        return (hasRequiredItem and not isPhoneDead and not airplaneMode)
    end
    local function GetFormattedCallerName()
        local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber()
        local formattedNumber = exports["lb-phone"]:FormatNumber(phoneNumber)
        local settings = exports["lb-phone"]:GetSettings()
        local callerId = json.encode(settings.name)
        return callerId .. " - " .. formattedNumber
    end

    local function CallTimer()
        Citizen.CreateThread(function()
            while CallData.callID ~= nil do
                Citizen.Wait(100)
                CallData.totalCallLength = CallData.totalCallLength + 100
            end
        end)
    end

    local function EndCall()
        local inCall = exports["lb-phone"]:IsInCall()

        if inCall and CallData.inEmergencyCall then
            if CallData.status == 'inRedial' then
                TriggerServerEvent('SonoranRadio::lb-phone:EndDispatcherRedial', CallData.callID)
            else
                exports["lb-phone"]:EndCustomCall()
            end
        end

        CallData = {
            status = nil,
            src = GetPlayerServerId(PlayerId()),
            hasDispatcher = false,
            dispatcherNames = nil,
            inEmergencyCall = false,
            totalCallLength = 0,
        }

        exports['sonoranradio']:setEmergencyCall(false)
    end

    local data = {
        onCall = function(incomingCall)
            local callID = incomingCall.id
            if CallData.callID == nil then
                incomingCall.setName(number911)
                exports['sonoranradio']:setEmergencyCall(true, GetFormattedCallerName())
                CallData = {
                    status = "callStarted",
                    src = GetPlayerServerId(PlayerId()),
                    callID = callID,
                    callerID = callerId,
                    hasDispatcher = false,
                    dispatcherNames = nil,
                    totalCallLength = 0,
                    inEmergencyCall = true,
                }
                CallTimer()
            end

            while not CallData.hasDispatcher do
                Citizen.Wait(100)

                local inCall = exports["lb-phone"]:IsInCall()

                if not inCall  then
                    DebugPrint("Call ended while waiting for dispatcher.")

                    --DO NOT CHANGE STATUS HERE OR YOU WILL SEND DUPLICATE DATA. THIS IS HANDLED IN THE ONEND FUNCTION AS THIS CHECK WAS TRIGGER BY USER HANGING UP.

                    EndCall()

                    break
                end

                if CallData.hasDispatcher then
                    DebugPrint("Has dispatcher")

                    CallData.status = "dispatcherAnsweredCall"

                    --SONORAN TEAM you can add a UpdateCall function or trigger a server event here depending on your needs and how you want to handle the call data.
                    --UpdateCall("dispatcherAnsweredCall", CallData)

                    incomingCall.accept()

                else
                    --Call will be sent to voicemail automatically by lbphone after 11.3 seconds, ending call before LB sends to voicemail automatically
                    if CallData.totalCallLength >= 10500 then
                        DebugPrint("Call Timed Out before dispatcher answered.")

                        CallData.status = "dispatcherAnsweredCall"

                        --SONORAN TEAM you can add a UpdateCall function or trigger a server event here depending on your needs and how you want to handle the call data.
                        --UpdateCall("callTimedOut", CallData)

                        --Save call data before wiping it with EndCall()
                        local callData = CallData

                        incomingCall.accept()

                        --SONORAN TEAM Put additional features here, if you want it to go to voicemail then remove this check. LB phone will handle the automated voicemail message once the call length reaches 11.3 seconds. Otherwise you can request for user to input text prompt, etc. etc.
                    end
                end
            end
        end,
        onEnd = function()

            DebugPrint("Call ended by onEnd Function - Ended by user.")

            if CallData.hasDispatcher then
                CallData.status = "callEnded"
                --SONORAN TEAM you can add a UpdateCall function or trigger a server event here depending on your needs and how you want to handle the call data.
                --UpdateCall("callEnded", CallData)

            else
                CallData.status = "userEndedCallPreDispatcher"
                --SONORAN TEAM you can add a UpdateCall function or trigger a server event here depending on your needs and how you want to handle the call data.
                --UpdateCall("userEndedCallPreDispatcher", CallData)
            end

            EndCall()

        end,
        onAction = function(action)

        end,
        onKeypad = function(key)

        end
    }

    local NumberCreated, reason = exports["lb-phone"]:CreateCustomNumber(number911, data)

    if not NumberCreated then
        DebugPrint("Error setting custom number!! Error: " .. reason)
    end

    if NumberCreated then
        AddEventHandler('SonoranRadio::API:EmergencyCallDispatcher', function(dispatcherNames)
            -- If dispatcherNames table is empty
            if next(dispatcherNames) == nil then
                if not CallData.hasDispatcher then
                    --Start of call, no dispatcher yet ignoring event.
                    DebugPrint("Call was just started. Ignoring empty dispatcher table.")
                    return
                end
            end

            DebugPrint("Initial Call Answered, dispatcher names: " .. json.encode(dispatcherNames))

            CallData.hasDispatcher = true
            CallData.dispatcherNames = dispatcherNames
        end)

        AddEventHandler('SonoranRadio::API:EmergencyCall', function(enabled)
            if not enabled then
                EndCall()
                return
            end
            if CallData.status ~= nil then return end

            local inCall = exports["lb-phone"]:IsInCall()
            if not CallData.inEmergencyCall and inCall then
                exports['sonoranradio']:setEmergencyCall(false)
                return
            end
            if not CanCallEmergencyNumber() then
                exports['sonoranradio']:setEmergencyCall(false)
                return
            end

            local options = { number = number911 }
            exports["lb-phone"]:CreateCall(options)
        end)
    end

    AddEventHandler('SonoranRadio::API:EmergencyCallRedial', function()
        if GetResourceState('lb-phone') ~= 'started' then return end
        CancelEvent()
        TriggerServerEvent('SonoranRadio::lb-phone:CreateDispatcherRedial')
    end)
    RegisterNetEvent('SonoranRadio::lb-phone:RedialAnswered', function(callId)
        CallData.status = 'inRedial'
        CallData.inEmergencyCall = true
        CallData.callID = callId
        exports['sonoranradio']:setEmergencyCall(true, GetFormattedCallerName())
    end)
    RegisterNetEvent('SonoranRadio::lb-phone:RedialEnded', function()
        CallData.inEmergencyCall = false
        EndCall()
    end)
    RegisterNetEvent('SonoranRadio::lb-phone:EmergencyDial', function()
        TriggerEvent('SonoranRadio::API:EmergencyCall', true)
    end)
end
