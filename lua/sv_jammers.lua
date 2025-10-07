local jammerState = {}
local staticJammers = {}
local handheldState = {}

local function isJammerEnabled()
    return Config.radioJammers and Config.radioJammers.enabled ~= false
end

local function jammerConfigList()
    if not Config.radioJammers then return {} end
    return Config.radioJammers.jammers or {}
end

local function getAllowedGrades(data)
    if type(data) ~= 'table' then return {} end
    if data.grades then return data.grades end
    return data
end

local function hasConfigPermission(src, cfg)
    if not cfg or not cfg.permission or cfg.permission == '' then
        return true
    end
    return IsPlayerAceAllowed(src, cfg.permission)
end

local function checkJammerPermissions(src)
    if not Config.radioJammers then return false end
    local permMode = Config.radioJammers.permissionMode
    if permMode == nil or permMode == 'none' then
        return true
    elseif permMode == 'ace' then
        return IsPlayerAceAllowed(src, Config.radioJammers.acePermission or '')
    elseif permMode == 'qbcore' then
        local Player
        if frameworkEnum == 1 then
            local core = QBCore or exports['qb-core']:GetCoreObject()
            Player = core and core.Functions.GetPlayer(src)
        elseif frameworkEnum == 2 then
            Player = exports.qbx_core and exports.qbx_core:GetPlayer(src)
        end
        if not Player or not Player.PlayerData or not Player.PlayerData.job then
            return false
        end
        local allowedJobs = Config.radioJammers.allowedJobs or {}
        for job, data in pairs(allowedJobs) do
            if Player.PlayerData.job.name == job then
                for _, grade in ipairs(getAllowedGrades(data)) do
                    if Player.PlayerData.job.grade and Player.PlayerData.job.grade.level >= grade then
                        return true
                    end
                end
            end
        end
        return false
    elseif permMode == 'esx' then
        local ESX = exports['es_extended'] and exports['es_extended']:getSharedObject()
        if not ESX then return false end
        local ESXPlayer = ESX.GetPlayerFromId(src)
        if not ESXPlayer or not ESXPlayer.job then return false end
        local allowedJobs = Config.radioJammers.allowedJobs or {}
        for job, data in pairs(allowedJobs) do
            if ESXPlayer.job.name == job then
                for _, grade in ipairs(getAllowedGrades(data)) do
                    if ESXPlayer.job.grade and ESXPlayer.job.grade >= grade then
                        return true
                    end
                end
            end
        end
        return false
    else
        errorLog('SonoranRadio: Invalid permission mode for radio jammers - ' .. tostring(permMode))
        return false
    end
end

local function cloneStaticState()
    local payload = {}
    for id, data in pairs(jammerState) do
        payload[id] = {
            id = id,
            coords = {x = data.coords.x, y = data.coords.y, z = data.coords.z},
            heading = data.heading,
            exact = data.exact,
            range = data.range,
            strength = data.strength,
            active = data.active,
            model = data.model,
            offModel = data.offModel,
            note = data.note,
            type = data.type or 'static'
        }
    end
    return payload
end

local function cloneHandheldState()
    local payload = {}
    for id, entry in pairs(handheldState) do
        payload[id] = {
            id = id,
            owner = entry.owner,
            name = entry.config.name,
            range = entry.config.range,
            strength = entry.config.strength,
            active = entry.active,
            model = entry.config.model,
            offModel = entry.config.offModel,
            type = 'handheld'
        }
    end
    return payload
end

local function pushJammers(target)
    if not isJammerEnabled() then return end
    TriggerClientEvent('SonoranRadio::Jammers::Sync', target or -1, cloneStaticState(), staticJammers, cloneHandheldState())
end

local function upsertState(entry)
    if not entry or not entry.Id then return end
    local pos = entry.PropPosition or {}
    jammerState[entry.Id] = {
        coords = vector3(tonumber(pos.x) or 0.0, tonumber(pos.y) or 0.0, tonumber(pos.z) or 0.0),
        heading = tonumber(pos.heading) or 0.0,
        exact = pos.exact == true,
        range = tonumber(entry.Range) or 0.0,
        strength = tonumber(entry.Strength) or 0.0,
        active = entry.Active ~= false,
        model = entry.PropModel,
        offModel = entry.OffModel,
        note = entry.Note,
        type = entry.Type or entry.type or 'static'
    }
end

local function saveJammers()
    SaveJsonConfig('jammers.json', staticJammers)
end

local function findConfigJammer(name)
    if type(name) ~= 'string' then return nil end
    for _, jammer in ipairs(jammerConfigList()) do
        if jammer.name == name then
            return jammer
        end
    end
    return nil
end

local function findStaticJammer(jammerId)
    for index, jammer in ipairs(staticJammers) do
        if jammer.Id == jammerId then
            return jammer, index
        end
    end
    return nil, nil
end

local function playerHasHandheldInventory(src, cfg)
    if not Config.enforceRadioItem then return true end
    if not cfg then return true end
    local names = {}
    if cfg.itemName and cfg.itemName ~= '' then table.insert(names, cfg.itemName) end
    if cfg.poweredItemName and cfg.poweredItemName ~= '' then table.insert(names, cfg.poweredItemName) end
    if #names == 0 then return true end

    if inventoryEnum == 1 then
        local core = QBCore or exports['qb-core']:GetCoreObject()
        local Player = core and core.Functions.GetPlayer(src)
        if not Player then return false end
        if Player.Functions.GetItemByName then
            for _, name in ipairs(names) do
                if Player.Functions.GetItemByName(name) then
                    return true
                end
            end
        end
        if Player.Functions.HasItem then
            for _, name in ipairs(names) do
                if Player.Functions.HasItem(name) then
                    return true
                end
            end
        end
        return false
    elseif inventoryEnum == 2 then
        for _, name in ipairs(names) do
            if exports.ox_inventory:Search(src, 'count', name) > 0 then
                return true
            end
        end
        return false
    end
    return true
end

local function swapHandheldInventory(src, cfg, activating, skipInventory, giveBase)
    if skipInventory or not Config.enforceRadioItem then return false end
    if not cfg then return end
    local baseItem = cfg.itemName
    local poweredItem = cfg.poweredItemName
    if not poweredItem or poweredItem == '' then return false end

    if inventoryEnum == 1 then
        local core = QBCore or exports['qb-core']:GetCoreObject()
        local Player = core and core.Functions.GetPlayer(src)
        if not Player then return false end
        if activating then
            local removedBase = false
            if baseItem and baseItem ~= '' and Player.Functions.GetItemByName then
                local item = Player.Functions.GetItemByName(baseItem)
                if item then
                    Player.Functions.RemoveItem(baseItem, 1, item.slot)
                    removedBase = true
                end
            end
            Player.Functions.AddItem(poweredItem, 1)
            return removedBase
        else
            if Player.Functions.GetItemByName then
                local powered = Player.Functions.GetItemByName(poweredItem)
                if powered then
                    Player.Functions.RemoveItem(poweredItem, 1, powered.slot)
                end
            end
            if giveBase and baseItem and baseItem ~= '' then
                Player.Functions.AddItem(baseItem, 1)
            end
        end
    elseif inventoryEnum == 2 then
        if activating then
            local removedBase = false
            if baseItem and baseItem ~= '' then
                local count = exports.ox_inventory:Search(src, 'count', baseItem)
                if count > 0 then
                    exports.ox_inventory:RemoveItem(src, baseItem, 1)
                    removedBase = true
                end
            end
            exports.ox_inventory:AddItem(src, poweredItem, 1)
            return removedBase
        else
            local count = exports.ox_inventory:Search(src, 'count', poweredItem)
            if count > 0 then
                exports.ox_inventory:RemoveItem(src, poweredItem, 1)
            end
            if giveBase and baseItem and baseItem ~= '' then
                exports.ox_inventory:AddItem(src, baseItem, 1)
            end
        end
    end
    return false
end

local function removeHandheldByOwner(src, skipInventory)
    local removed = false
    for id, entry in pairs(handheldState) do
        if entry.owner == src then
            swapHandheldInventory(src, entry.config, false, skipInventory, entry.hadBaseItem)
            handheldState[id] = nil
            removed = true
            TriggerClientEvent('SonoranRadio::Jammers::HandheldDeactivated', -1, {
                id = id,
                owner = src,
                name = entry.config.name
            })
        end
    end
    if removed then
        pushJammers()
    end
end

function initStaticJammers(initialJammers)
    staticJammers = type(initialJammers) == 'table' and initialJammers or {}
    jammerState = {}
    for _, entry in ipairs(staticJammers) do
        if entry.Id == nil then entry.Id = uuid() end
        entry.PropPosition = entry.PropPosition or {}
        entry.PropPosition.x = tonumber(entry.PropPosition.x) or 0.0
        entry.PropPosition.y = tonumber(entry.PropPosition.y) or 0.0
        entry.PropPosition.z = tonumber(entry.PropPosition.z) or 0.0
        entry.PropPosition.heading = tonumber(entry.PropPosition.heading) or 0.0
        entry.PropPosition.exact = entry.PropPosition.exact == true
        entry.Range = tonumber(entry.Range) or 0.0
        entry.Strength = tonumber(entry.Strength) or 0.0
        entry.Active = entry.Active ~= false
        entry.Type = entry.Type or entry.type or 'static'
        upsertState(entry)
    end
    pushJammers()
end

RegisterNetEvent('SonoranRadio::Request::OpenJammerMenu', function()
    local src = source
    if not isJammerEnabled() then
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 0, 0},
            multiline = true,
            args = {'SonoranRadio', 'Radio jammers are disabled on this server.'}
        })
        return
    end
    if checkJammerPermissions(src) then
        TriggerClientEvent('SonoranRadio::OpenJammerMenu', src)
        pushJammers(src)
    else
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 0, 0},
            multiline = true,
            args = {'SonoranRadio', 'You do not have permission to access the radio jammer menu.'}
        })
    end
end)

RegisterNetEvent('SonoranRadio::Jammers::RequestSync', function()
    local src = source
    if not isJammerEnabled() then return end
    pushJammers(src)
end)

RegisterNetEvent('SonoranRadio::Request::SpawnJammer', function(selectedJammer, coords, heading, metadata)
    local src = source
    if not isJammerEnabled() then return end
    if not checkJammerPermissions(src) then return end
    if type(selectedJammer) ~= 'table' or type(selectedJammer.name) ~= 'string' then return end

    local cfg = findConfigJammer(selectedJammer.name)
    if not cfg or cfg.type == 'handheld' then return end
    if not hasConfigPermission(src, cfg) then
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 0, 0},
            multiline = true,
            args = {'SonoranRadio', 'You do not have permission to use this jammer.'}
        })
        return
    end

    coords = coords or {}
    local x = tonumber(coords.x) or 0.0
    local y = tonumber(coords.y) or 0.0
    local z = tonumber(coords.z) or 0.0
    if x == 0.0 and y == 0.0 and z == 0.0 then
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            local pos = GetEntityCoords(ped)
            x, y, z = pos.x, pos.y, pos.z
        end
    end
    local jammerEntry = {
        Id = uuid(),
        Name = cfg.name,
        PropModel = cfg.model,
        OffModel = cfg.offModel,
        Range = tonumber(cfg.range) or 0.0,
        Strength = tonumber(cfg.strength) or 0.0,
        Active = true,
        PropPosition = {
            x = x,
            y = y,
            z = z,
            heading = tonumber(heading) or 0.0,
            exact = metadata and metadata.exact == true
        },
        Note = metadata and metadata.note or nil,
        Type = cfg.type or 'static'
    }
    table.insert(staticJammers, jammerEntry)
    upsertState(jammerEntry)
    saveJammers()
    pushJammers()
end)

RegisterNetEvent('SonoranRadio::Request::MoveJammer', function(jammerId, propPosition)
    local src = source
    if not isJammerEnabled() then return end
    if not checkJammerPermissions(src) then return end
    if type(jammerId) ~= 'string' then return end
    if type(propPosition) ~= 'table' then return end

    local entry = findStaticJammer(jammerId)
    if not entry then return end

    entry.PropPosition.x = tonumber(propPosition.x) or entry.PropPosition.x
    entry.PropPosition.y = tonumber(propPosition.y) or entry.PropPosition.y
    entry.PropPosition.z = tonumber(propPosition.z) or entry.PropPosition.z
    entry.PropPosition.heading = tonumber(propPosition.heading) or entry.PropPosition.heading or 0.0
    entry.PropPosition.exact = propPosition.exact == true
    upsertState(entry)
    saveJammers()
    pushJammers()
end)

RegisterNetEvent('SonoranRadio::Request::DeleteJammer', function(jammerId)
    local src = source
    if not isJammerEnabled() then return end
    if not checkJammerPermissions(src) then return end
    if type(jammerId) ~= 'string' then return end

    local _, index = findStaticJammer(jammerId)
    if not index then return end

    table.remove(staticJammers, index)
    jammerState[jammerId] = nil
    saveJammers()
    pushJammers()
end)

RegisterNetEvent('SonoranRadio::Jammers::ActivateHandheld', function(configName)
    local src = source
    if not isJammerEnabled() then return end
    if not checkJammerPermissions(src) then return end
    if type(configName) ~= 'string' then return end

    local cfg = findConfigJammer(configName)
    if not cfg or cfg.type ~= 'handheld' then
        TriggerClientEvent('SonoranRadio::Jammers::HandheldActivationFailed', src, 'invalid_config')
        return
    end
    if not hasConfigPermission(src, cfg) then
        TriggerClientEvent('SonoranRadio::Jammers::HandheldActivationFailed', src, 'missing_permission')
        return
    end
    for _, entry in pairs(handheldState) do
        if entry.owner == src then
            TriggerClientEvent('SonoranRadio::Jammers::HandheldActivationFailed', src, 'already_active')
            return
        end
    end
    if not playerHasHandheldInventory(src, cfg) then
        TriggerClientEvent('SonoranRadio::Jammers::HandheldActivationFailed', src, 'missing_item')
        return
    end

    local id = uuid()
    local newEntry = {
        owner = src,
        config = {
            name = cfg.name,
            model = cfg.model,
            offModel = cfg.offModel,
            range = tonumber(cfg.range) or 0.0,
            strength = tonumber(cfg.strength) or 0.0,
            itemName = cfg.itemName,
            poweredItemName = cfg.poweredItemName
        },
        active = true,
        hadBaseItem = false
    }
    handheldState[id] = newEntry
    handheldState[id].hadBaseItem = swapHandheldInventory(src, handheldState[id].config, true)
    pushJammers()
    TriggerClientEvent('SonoranRadio::Jammers::HandheldActivated', -1, {
        id = id,
        owner = src,
        name = cfg.name,
        model = cfg.model,
        offModel = cfg.offModel,
        range = tonumber(cfg.range) or 0.0,
        strength = tonumber(cfg.strength) or 0.0
    })
end)

RegisterNetEvent('SonoranRadio::Jammers::DeactivateHandheld', function(jammerId)
    local src = source
    if type(jammerId) ~= 'string' then return end
    local entry = handheldState[jammerId]
    if not entry or entry.owner ~= src then
        TriggerClientEvent('SonoranRadio::Jammers::HandheldActivationFailed', src, 'not_active')
        return
    end

    swapHandheldInventory(src, entry.config, false, false, entry.hadBaseItem)
    handheldState[jammerId] = nil
    pushJammers()
    TriggerClientEvent('SonoranRadio::Jammers::HandheldDeactivated', -1, {
        id = jammerId,
        owner = src,
        name = entry.config.name
    })
end)

AddEventHandler('playerDropped', function()
    local src = source
    removeHandheldByOwner(src, true)
end)
