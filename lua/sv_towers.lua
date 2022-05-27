local RadioTower = {
    -- whether the tower can be destroyed or not
    Destruction = true,
    Swankiness = 0.0,
    -- the tower's position (vec3)
    PropPosition = nil,
    -- the range of the tower
    Range = 1500.0,
    DishStatus = {'alive', 'alive', 'alive', 'alive'},
    Powered = true
}

Towers = {}
function GetTower(coords)
    for i = 1, #Towers do
        if Towers[i].PropPosition == coords then
            return Towers[i], i
        end
    end
    return nil, nil
end
function GetTowerFromId(id)
    for _, t in ipairs(Towers) do
        if t.Id == id then
            return t
        end
    end
end


AddEventHandler("SonoranScripts::PowerGrid::RegisterNewDevice", function(coords, entityID, requestID)
    print("SONRAD REGISTER")
    for _, v in pairs(Towers) do
        DebugPrint(("coords: " .. v.PropPosition))
        local dist = #(v.PropPosition.xy - coords.xy)
        DebugPrint("dist: " .. dist)
        DebugPrint(tostring(entityId))
        if dist < 10 then
            TriggerEvent("SonoranScripts::PowerGrid::NewDevice", v.Id, "radiotowers", requestID)
        end
    end
end)

RegisterNetEvent("SonoranScripts::PowerGrid::DeviceDisabled")
AddEventHandler("SonoranScripts::PowerGrid::DeviceDisabled", function(affectedDevices)
    DebugPrint("SONRAD DISABLED " .. json.encode(affectedDevices))
    for _, v in pairs(affectedDevices["radiotowers"]) do
        local tower = GetTowerFromId(v)
        DebugPrint(json.encode(tower))
        tower.Powered = false
        for i = 1, #tower.DishStatus do
            tower.DishStatus[i] = 'dead'
        end
        TriggerClientEvent('RadioTower:SetDishStatus', -1, v, tower.DishStatus)
        TriggerEvent("SonoranCAD::sonrad:SetDishStatus", v, tower.DishStatus)    
    end
    -- TriggerClientEvent("RadioTower:SyncTowers", source, Towers)
    -- TriggerEvent("SonoranCAD::sonrad:SyncTowers", Towers)
    
end)

RegisterNetEvent("SonoranScripts::PowerGrid::DeviceRepaired")
AddEventHandler("SonoranScripts::PowerGrid::DeviceRepaired", function(affectedDevices)
    DebugPrint("SONRAD REPAIRED " .. json.encode(affectedDevices))
    for _, v in pairs(affectedDevices["radiotowers"]) do
        local tower = GetTowerFromId(v)
        tower.Powered = true
        for i = 1, #tower.DishStatus do
            tower.DishStatus[i] = 'alive'
        end
        TriggerClientEvent('RadioTower:SetDishStatus', -1, v, tower.DishStatus)
        TriggerEvent("SonoranCAD::sonrad:SetDishStatus", v, tower.DishStatus)
    end
    -- TriggerClientEvent("RadioTower:SyncTowers", source, Towers)
    -- TriggerEvent("SonoranCAD::sonrad:SyncTowers", Towers)
end)

RegisterCommand("removetowers", function()
    TriggerClientEvent("RadioTower:Shutdown", -1)
    Towers = {}
end, true)

RegisterCommand("savetowers", function()
    local f = assert(io.open(GetResourcePath("sonoranradio").."/towers.json", "w+"))
    f:write(json.encode(Towers))
    f:close()
    print("ok")
end, true)

RegisterCommand("spawntower", function(source)
    local coords = GetEntityCoords(GetPlayerPed(source))
    local tower = shallowcopy(RadioTower)
    tower.Id = uuid()
    tower.PropPosition = coords
    table.insert(Towers, tower)

    TriggerClientEvent("RadioTower:SpawnTower", -1, tower)
end, true)

RegisterNetEvent("RadioTower:clientTowerSync")
AddEventHandler("RadioTower:clientTowerSync", function()
    local source = source
    while #Towers == 0 do
        Wait(10)
    end
    TriggerClientEvent("RadioTower:SyncTowers", source, Towers)
    TriggerEvent("SonoranCAD::sonrad:SyncTowers", Towers)
end)

local DestroyRequests = {}
RegisterNetEvent("RadioTower:Destroy")
AddEventHandler("RadioTower:Destroy", function(coords)
    local handshake = uuid()
    DestroyRequests[source] = { coords = coords, secret = handshake }
    TriggerClientEvent("RadioTower:VerifyLocation", source, handshake)
end)

RegisterNetEvent("RadioTower:KillDish")
AddEventHandler("RadioTower:KillDish", function(towerId, dishIndex)
    local tower = GetTowerFromId(towerId)
    DebugPrint("RadioTower:KillDish", towerId, dishIndex)
    if not tower then return end

    tower.DishStatus[dishIndex] = 'dead'
    TriggerClientEvent('RadioTower:SetDishStatus', -1, towerId, tower.DishStatus)
    TriggerEvent("SonoranCAD::sonrad:SetDishStatus", towerId, tower.DishStatus)
end)

RegisterNetEvent("RadioTower:RepairTower")
AddEventHandler("RadioTower:RepairTower", function(towerId)
    local tower = GetTowerFromId(towerId)
    DebugPrint("RadioTower:RepairTower", towerId)
    if not tower then return end

    for i = 1, #tower.DishStatus do
        tower.DishStatus[i] = 'alive'
    end
    TriggerClientEvent('RadioTower:SetDishStatus', -1, towerId, tower.DishStatus)
    TriggerEvent("SonoranCAD::sonrad:SetDishStatus", towerId, tower.DishStatus)
end)

RegisterNetEvent("RadioTower:clientLocationVerify")
AddEventHandler("RadioTower:clientLocationVerify", function(coords, handshake)
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


AddEventHandler("onResourceStart", function(resource)
    if GetCurrentResourceName() ~= resource then return end
    local t = LoadResourceFile(GetCurrentResourceName(), "towers.json")
    local towers = json.decode(t)
    for i = 1, #towers do
        local obj = shallowcopy(RadioTower)
        if towers[i].Id == nil then
            obj.Id = uuid()
        else
            obj.Id = towers[i].Id
        end
        --obj.Id = uuid()
        obj.PropPosition = vec3(towers[i].PropPosition.x, towers[i].PropPosition.y, towers[i].PropPosition.z)
        obj.Swankiness = towers[i].Swankiness
        obj.Range = towers[i].Range
        obj.Destruction = towers[i].Destruction

        DebugPrint("setting up tower", json.encode(obj))
        table.insert(Towers, obj)
    end
end)
