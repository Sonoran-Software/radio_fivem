local emergencyCallIds = {}
local function createEmergencyRedial(source)
    local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber(source)
    if not phoneNumber then
        DebugPrint('Redial: Could not find phone number of '..source)
        return
    end

    local callId = exports["lb-phone"]:CreateCall({
        source = source,
        phoneNumber = "Emergency Services"
    }, phoneNumber)
    if not callId then
        DebugPrint('Redial: Could not create emergency services call')
        return
    end

    emergencyCallIds[callId] = source
end

AddEventHandler("lb-phone:callAnswered", function(call)
    local source = emergencyCallIds[call.callId]
    if source == nil then
        return
    end
    TriggerClientEvent('SonoranRadio::lb-phone:RedialAnswered', source, call.callId)
end)

AddEventHandler("lb-phone:callEnded", function(call)
    local source = emergencyCallIds[call.callId]
    emergencyCallIds[call.callId] = nil
    TriggerClientEvent('SonoranRadio::lb-phone:RedialEnded', source)
end)

RegisterNetEvent('SonoranRadio::lb-phone:CreateDispatcherRedial', function()
    if GetResourceState('lb-phone') ~= 'started' then return end
    createEmergencyRedial(source)
end)
RegisterNetEvent('SonoranRadio::lb-phone:EndDispatcherRedial', function(callId)
    if emergencyCallIds[callId] ~= source then return end
    exports['lb-phone']:EndCall(source)
end)
