local RadioTower = {
    Debug = false,
    Destruction = false,
    DestructionTimer = 0,
    Swankiness = 0.0,
    Prop = nil,
    DishProp = nil,
    LadderProp = nil,
    PropPosition = nil,
    DishPropPosition = nil,
    LadderPropPosition = nil,
    Range = 200
}

RadioTower.TowerProps = {
    `prop_radio_tower`
}

Towers = {}
HasSpawnedTowers = false

local function DebugPrint(str)
    if (RadioTower.Debug) then
        print("Sonoran Radio (Towers) - Debug", str)
    end
end

function GetDistance(dist1, dist2)
    local dist = #(dist1 - dist2)
    return dist
end

function GetClosestTower()
    if #Towers < 1 then
        DebugPrint("no towers spawned")
        return nil, nil
    end
    local pedLocation = GetEntityCoords(GetPlayerPed(-1))
    local closest = GetDistance(Towers[1].PropPosition, pedLocation)
    local closestObj = Towers[1]
    for i = 1, #Towers do
        local tower = Towers[i]
        if not tower.Destruction then
            local dist = GetDistance(Towers[i].PropPosition, pedLocation)
            DebugPrint(("tower %s - dist: %s - closest: %s"):format(i, dist, closest))
            if dist < closest then
                closest = dist
                closestObj = Towers[i]
                DebugPrint(("New tower %s, distance: %s"):format(i, dist))
            end
        end
    end
    return closestObj, closest
end

local function GetTower(coords)
    for i = 1, #Towers do
        if Towers[i].PropPosition == coords then
            return Towers[i], i
        end
    end
    return nil, nil
end


local function CreateTower(coords)
    local selectedProp = math.random(1, #RadioTower.TowerProps)
    RequestModel(RadioTower.TowerProps[selectedProp])
    while not HasModelLoaded(RadioTower.TowerProps[selectedProp]) do Wait(10) end
    local tower = CreateObject(RadioTower.TowerProps[selectedProp], coords, true, true, false)
    local tcoords = GetEntityCoords(tower)
    while not DoesEntityExist(tower) do Wait(0) end
    FreezeEntityPosition(tower, true)
    SetEntityCoords(tower, coords.x, coords.y, coords.z - 1, true, true, true, false)
    PlaceObjectOnGroundProperly(tower)
    SetModelAsNoLongerNeeded(RadioTower.TowerProps[selectedProp])

    return tower
end


function RadioTower:Cleanup()
    for i = 1, #Towers do
        local obj = Towers[i]
        if obj.Prop ~= nil then
            DeleteEntity(obj.Prop)
        end
    end
    Towers = {}
end

RegisterCommand("spawntower", function()
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent("RadioTower:Create", coords, 200)
end)

RegisterNetEvent("RadioTower:SyncTowers")
AddEventHandler("RadioTower:SyncTowers", function(towers)
    Towers = towers
    DebugPrint(("synced %s"):format(json.encode(towers)))
    if not HasSpawnedTowers then
        for i = 1, #Towers do
            CreateTower(Towers[i].PropPosition)
        end
        HasSpawnedTowers = true
    end
    DebugPrint("Synced towers")
end)

RegisterNetEvent("RadioTower:SpawnTower")
AddEventHandler("RadioTower:SpawnTower", function(coords, range)
    local tower = shallowcopy(RadioTower)
    tower.PropPosition = CreateTower(coords)
    tower.Range = range
end)

function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else
        copy = orig
    end
    return copy
end

local function SetRadioQuality(quality)
    SendNUIMessage({
        type = 'set_gamestate',
        state = { tower_quality = quality }
    })
end

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(10)
    end
    TriggerServerEvent("RadioTower:clientTowerSync")
end)

CreateThread(function()
    while not HasSpawnedTowers do
        Wait(10)
    end
    while true do
        local tower, distance = GetClosestTower()
        if not tower then
            DebugPrint("no tower found")
        else
            if distance > tower.Range then
                DebugPrint("closest tower out of range")
                SetRadioQuality(0.0)
            else
                local quality = 1.0 - (distance / tower.Range)
                DebugPrint(("closest tower distance: %s - Range: %s - Calculated quality: %s"):format(distance, tower.Range, quality))
                SetRadioQuality(quality)
            end
        end
        Wait(5000)
    end
end)

AddEventHandler("onResourceStop", function(resource)
    if GetCurrentResourceName() ~= resource then return end
    RadioTower:Cleanup()
end)