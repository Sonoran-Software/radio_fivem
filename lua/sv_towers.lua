-- RADIO QUALITY (Swankiness): 0.0 - 1.0 (0.0 worst -> 1.0 greatest)
-- TODO: make being furthest away from any tower and/or the repeater(s) cause quality to go down
-- RADIO TOWERS: handle, pos {x, y, z, offset, handle, status}, destruction status (0 - none, 1 - being destroyed, 2 - destroyed) 
local RadioTower = {
    Destruction = false,
    DestructionTimer = 0,
    Swankiness = 0.0,
    PropPosition = nil,
    Range = 200
}

Towers = {}

local function GetTower(coords)
    for i = 1, #Towers do
        if Towers[i].PropPosition == coords then
            return Towers[i], i
        end
    end
    return nil, nil
end

RegisterCommand("removetowers", function()
    TriggerClientEvent("RadioTower:Shutdown", -1)
    Towers = {}
end)

RegisterCommand("savetowers", function()
    local f = assert(io.open(GetResourcePath("sonoranradio").."/towers.json", "w+"))
    f:write(json.encode(Towers))
    f:close()
    print("ok")
end, true)

RegisterNetEvent("RadioTower:Create")
AddEventHandler("RadioTower:Create", function(coords, range)
    local tower = shallowcopy(RadioTower)
    tower.PropPosition = coords
    tower.Range = range
    table.insert(Towers, tower)
    TriggerClientEvent("RadioTower:SyncTowers", -1, Towers)
    TriggerClientEvent("RadioTower:SpawnTower", -1, coords, range)
end)

RegisterNetEvent("RadioTower:clientTowerSync")
AddEventHandler("RadioTower:clientTowerSync", function()
    local source = source
    while #Towers == 0 do
        Wait(10)
    end
    TriggerClientEvent("RadioTower:SyncTowers", source, Towers)
end)

local DestroyRequests = {}
local function uuid()
    math.randomseed(GetGameTimer())
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end
RegisterNetEvent("RadioTower:Destroy")
AddEventHandler("RadioTower:Destroy", function(coords)
    local handshake = uuid()
    DestroyRequests[source] = { coords = coords, secret = handshake }
    TriggerClientEvent("RadioTower:VerifyLocation", source, handshake)
end)
RegisterNetEvent("RadioTower:clientLocationVerify", function(coords, handshake)
    if DestroyRequests[source] == nil or DestroyRequests[source].secret ~= handshake then
        print("ERR: failed handshake")
        return
    end
    local source = source
    local dist1 = coords
    local dist2 = DestroyRequests[source].coords
    local dist = #(dist1 - dist2)
    if dist > 5 then
        print("ERR: failed location check")
    else
        local tower, idx = GetTower(dist2)
        if not tower then
            print("ERR: no tower found")
            return
        end
        tower.Destruction = true
        tower.DestructionTimer = GetGameTimer()
        Towers[idx] = tower
        TriggerClientEvent("RadioTower:SyncTowers", -1)
        TriggerClientEvent("RadioTower:DestroyedTower", source, dist2)
    end
end)


function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

AddEventHandler("onResourceStart", function(resource)
    if GetCurrentResourceName() ~= resource then return end
    local t = LoadResourceFile(GetCurrentResourceName(), "towers.json")
    local towers = json.decode(t)
    for i = 1, #towers do
        print(("setting up tower %s"):format(json.encode(towers[i])))
        local obj = shallowcopy(RadioTower)
        obj.PropPosition = vec3(towers[i].PropPosition.x, towers[i].PropPosition.y, towers[i].PropPosition.z)
        obj.Swankiness = towers[i].Swankiness
        obj.Range = towers[i].Range
        obj.Destruction = towers[i].Destruction
        obj.DestructionTimer = towers[i].DestructionTimer
        table.insert(Towers, obj)
    end
end)