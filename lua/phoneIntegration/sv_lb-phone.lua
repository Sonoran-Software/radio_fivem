local emergencyCallIds = {}
local DevEvents = DeveloperEvents or {}

local function emitDeveloperEvent(suffix, payload)
    if DevEvents.emit then
        DevEvents.emit(suffix, payload)
    else
        TriggerEvent(('SonoranRadio::Developer:%s'):format(suffix), payload)
    end
end

local function deriveCallee(callData)
    if type(callData) ~= 'table' then
        return nil
    end

    local candidate = callData.target or callData.receiver or callData.callee or callData.otherParty
    if type(candidate) ~= 'table' then
        return nil
    end

    local callee = {}

    if type(candidate.serverId) == 'number' then
        callee.serverId = candidate.serverId
    elseif type(candidate.source) == 'number' then
        callee.serverId = candidate.source
    elseif type(candidate.id) == 'number' then
        callee.serverId = candidate.id
    end

    if type(candidate.phoneNumber) == 'string' then
        callee.phoneNumber = candidate.phoneNumber
    elseif type(candidate.number) == 'string' then
        callee.phoneNumber = candidate.number
    end

    if type(candidate.name) == 'string' then
        callee.name = candidate.name
    elseif type(candidate.label) == 'string' then
        callee.name = candidate.label
    end

    if type(candidate.identifier) == 'string' then
        callee.identifier = candidate.identifier
    end

    if next(callee) == nil then
        return nil
    end

    return callee
end

local function createEmergencyRedial(source, requestContext)
    local sanitizedContext = DevEvents.sanitize and DevEvents.sanitize(requestContext) or requestContext
    local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber(source)
    local dispatcherContext = DevEvents.playerContext and DevEvents.playerContext(source) or { serverId = source }
    if dispatcherContext and phoneNumber then
        dispatcherContext.phoneNumber = phoneNumber
    end

    emitDeveloperEvent('DispatcherRedial:Requested', {
        dispatcher = dispatcherContext,
        context = sanitizedContext
    })

    if not phoneNumber then
        DebugPrint('Redial: Could not find phone number of ' .. tostring(source))
        emitDeveloperEvent('DispatcherRedial:Failed', {
            dispatcher = dispatcherContext,
            context = sanitizedContext,
            reason = 'missing_phone_number',
            message = 'Dispatcher does not have an equipped phone number.'
        })
        return
    end

    local callId = exports["lb-phone"]:CreateCall({
        source = source,
        phoneNumber = "Emergency Services"
    }, phoneNumber)

    if not callId then
        DebugPrint('Redial: Could not create emergency services call')
        emitDeveloperEvent('DispatcherRedial:Failed', {
            dispatcher = dispatcherContext,
            context = sanitizedContext,
            reason = 'call_creation_failed',
            message = 'lb-phone returned no call id while creating the dispatcher redial.'
        })
        return
    end

    emergencyCallIds[callId] = {
        callId = callId,
        dispatcher = dispatcherContext,
        context = sanitizedContext,
        startedAt = os.time()
    }

    emitDeveloperEvent('DispatcherRedial:Started', {
        dispatcher = dispatcherContext,
        context = sanitizedContext,
        callId = callId,
        startedAt = emergencyCallIds[callId].startedAt
    })
end

AddEventHandler("lb-phone:callAnswered", function(call)
    if type(call) ~= 'table' then
        return
    end

    local callId = call.callId
    if not callId then
        return
    end

    local redial = emergencyCallIds[callId]
    if redial == nil then
        DebugPrint('Redial: callAnswered received for non-redial callId ' .. tostring(callId))
        return
    end

    local sanitizedCall = DevEvents.sanitize and DevEvents.sanitize(call) or call
    local callee = deriveCallee(sanitizedCall)
    if callee then
        redial.callee = callee
    end

    redial.answeredAt = os.time()

    TriggerClientEvent('SonoranRadio::lb-phone:RedialAnswered', redial.dispatcher.serverId, callId)

    emitDeveloperEvent('DispatcherRedial:Answered', {
        dispatcher = redial.dispatcher,
        callee = redial.callee,
        callId = callId,
        context = redial.context,
        answeredAt = redial.answeredAt,
        call = sanitizedCall
    })
end)

AddEventHandler("lb-phone:callEnded", function(call)
    if type(call) ~= 'table' then
        return
    end

    local callId = call.callId
    if not callId then
        return
    end

    local redial = emergencyCallIds[callId]
    if redial == nil then
        DebugPrint('Redial: callEnded received for non-redial callId ' .. tostring(callId))
        return
    end

    emergencyCallIds[callId] = nil

    local sanitizedCall = DevEvents.sanitize and DevEvents.sanitize(call) or call
    if not redial.callee then
        redial.callee = deriveCallee(sanitizedCall)
    end

    local endedAt = os.time()
    local reason = call.reason or redial.endedBy or 'unknown'

    TriggerClientEvent('SonoranRadio::lb-phone:RedialEnded', redial.dispatcher.serverId)

    emitDeveloperEvent('DispatcherRedial:Ended', {
        dispatcher = redial.dispatcher,
        callee = redial.callee,
        callId = callId,
        context = redial.context,
        reason = reason,
        startedAt = redial.startedAt,
        answeredAt = redial.answeredAt,
        endedAt = endedAt,
        call = sanitizedCall
    })
end)

RegisterNetEvent('SonoranRadio::lb-phone:CreateDispatcherRedial', function(requestContext)
    local resourceState = GetResourceState('lb-phone')
    if resourceState ~= 'started' then
        local sanitizedContext = DevEvents.sanitize and DevEvents.sanitize(requestContext) or requestContext
        local dispatcherContext = DevEvents.playerContext and DevEvents.playerContext(source) or { serverId = source }

        emitDeveloperEvent('DispatcherRedial:Failed', {
            dispatcher = dispatcherContext,
            context = sanitizedContext,
            reason = 'lb_phone_not_started',
            message = 'lb-phone resource is not started (state: ' .. resourceState .. ').'
        })
        return
    end

    createEmergencyRedial(source, requestContext)
end)

RegisterNetEvent('SonoranRadio::lb-phone:EndDispatcherRedial', function(callId)
    if not callId then
        return
    end

    local redial = emergencyCallIds[callId]
    if not redial or redial.dispatcher.serverId ~= source then
        return
    end

    redial.endedBy = 'dispatcher'

    emitDeveloperEvent('DispatcherRedial:CancelRequested', {
        dispatcher = redial.dispatcher,
        callee = redial.callee,
        callId = callId,
        context = redial.context,
        requestedAt = os.time()
    })

    exports['lb-phone']:EndCall(source)
end)
