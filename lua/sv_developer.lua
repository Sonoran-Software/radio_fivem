DeveloperEvents = DeveloperEvents or {}

local MAX_SANITIZE_DEPTH = 4

local function copyTable(original)
    local result = {}
    for key, value in pairs(original) do
        result[key] = value
    end
    return result
end

--- Emit a developer-facing event with the standard Sonoran prefix.
-- @param suffix string The suffix appended to SonoranRadio::Developer:
-- @param payload table? Payload delivered to listeners (optional).
function DeveloperEvents.emit(suffix, payload)
    TriggerEvent(('SonoranRadio::Developer:%s'):format(suffix), payload)
end

--- Shallow sanitization to drop unserializable or nested complex values.
-- Retains strings, numbers, booleans, nil, and tables up to MAX_SANITIZE_DEPTH.
function DeveloperEvents.sanitize(value, depth)
    depth = depth or 1
    if depth > MAX_SANITIZE_DEPTH then
        return nil
    end

    local valueType = type(value)
    if valueType == 'table' then
        local sanitized = {}
        for key, inner in pairs(value) do
            local keyType = type(key)
            if keyType == 'string' or keyType == 'number' then
                local clean = DeveloperEvents.sanitize(inner, depth + 1)
                if clean ~= nil then
                    sanitized[key] = clean
                end
            end
        end
        if next(sanitized) ~= nil then
            return sanitized
        end
        return nil
    end

    if valueType == 'string' or valueType == 'number' or valueType == 'boolean' or value == nil then
        return value
    end

    return nil
end

--- Build a player context table with identifiers and optional location metadata.
-- @param source number The player's server ID.
-- @param opts table? Additional options (includeIdentifiers?, includeCoords?, includeHeading?).
function DeveloperEvents.playerContext(source, opts)
    if type(source) ~= 'number' or source <= 0 then
        return nil
    end

    local context = { serverId = source }

    local name = GetPlayerName(source)
    if name and name ~= '' then
        context.name = name
    end

    opts = opts or {}
    local includeIdentifiers = opts.includeIdentifiers
    if includeIdentifiers == nil then
        includeIdentifiers = true
    end

    if includeIdentifiers then
        local identifiers = GetPlayerIdentifiers(source) or {}
        if #identifiers > 0 then
            context.identifiers = copyTable(identifiers)
        end
    end

    if opts.includeCoords then
        local ped = GetPlayerPed(source)
        if ped and ped ~= 0 then
            local coords = GetEntityCoords(ped)
            if coords then
                context.position = {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z
                }
            end
            if opts.includeHeading then
                context.heading = GetEntityHeading(ped)
            end
        end
    end

    return context
end

--- Utility to merge payload tables without mutating originals.
function DeveloperEvents.merge(basePayload, additional)
    if type(basePayload) ~= 'table' and basePayload ~= nil then
        error('DeveloperEvents.merge expects table or nil base payload')
    end
    if type(additional) ~= 'table' and additional ~= nil then
        error('DeveloperEvents.merge expects table or nil additional payload')
    end

    local result = {}
    if type(basePayload) == 'table' then
        for key, value in pairs(basePayload) do
            result[key] = value
        end
    end
    if type(additional) == 'table' then
        for key, value in pairs(additional) do
            result[key] = value
        end
    end
    return result
end

return DeveloperEvents
