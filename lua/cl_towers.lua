-- RADIO QUALITY (Swankiness): 0.0 - 1.0 (0.0 worst -> 1.0 greatest)
-- TODO: make being furthest away from any tower and/or the repeater(s) cause quality to go down
-- RADIO TOWERS: handle, pos {x, y, z, offset, handle, status}, destruction status (0 - none, 1 - being destroyed, 2 - destroyed) 
local RadioTower = {
    Destruction = false,
    DestructionTimer = 0,
    Swankiness = 0.0,
    Prop = nil,
    DishProp = nil,
    PropPosition = nil,
    Range = 200
}
-- Used for the repeater and the prop that is needed to be destroyed in order to disrupt signals
RadioTower.RepeaterProps = {
    `prop_satdish_2_a`,
}

-- Currently only GTA props (future: custom props)
RadioTower.TowerProps = {
    `prop_radiomast01`,
    `prop_radiomast02`,
}

Towers = {}
HasSpawnedTowers = false


function GetDistance(dist1, dist2)
    local dist = #(dist1 - dist2)
    return dist
end

function GetClosestTower()
    if #Towers < 1 then
        print("no towers spawned")
        return nil, nil
    end
    local pedLocation = GetEntityCoords(GetPlayerPed(-1))
    local closest = GetDistance(Towers[1].PropPosition, pedLocation)
    local closestObj = Towers[1]
    for i = 1, #Towers do
        local tower = Towers[i]
        if not tower.Destruction then
            local dist = GetDistance(Towers[i].PropPosition, pedLocation)
            print(("tower %s - dist: %s - closest: %s"):format(i, dist, closest))
            if dist < closest then
                closest = dist
                closestObj = Towers[i]
                print(("New tower %s, distance: %s"):format(i, dist))
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


function CreateTower(coords)
    -- TODO:
    -- Add tower and then spawn radio mast and the repeater prop and attach it (if not in the list already & spawned)
    -- CreateObject()
    -- AttachEntityToEntityPhysically()
    -- PARAMS: (entity1, entity2, boneIndex1, boneIndex2, xPos1, yPos1, zPos1, xPos2, yPos2, zPos2, xRot, yRot, zRot, breakForce, true, true, true, false, 1)
    -- the breakforce will prove useful

    local selectedProp = math.random(1, #RadioTower.TowerProps)
    RequestModel(RadioTower.TowerProps[selectedProp])
    while not HasModelLoaded(RadioTower.TowerProps[selectedProp]) do Wait(10) end
    --coords = vec3(towers[i].PropPosition.x, towers[i].PropPosition.y, towers[i].PropPosition.z)
    local tower = CreateObject(RadioTower.TowerProps[selectedProp], coords, true, true, false)
    while not DoesEntityExist(tower) do Wait(0) end
    FreezeEntityPosition(tower, true)
    SetEntityCoords(tower, coords.x, coords.y, coords.z - 1, true, true, true, false)
    SetModelAsNoLongerNeeded(RadioTower.TowerProps[selectedProp])

    -- Dish
    --[[local model = RadioTower.RepeaterProps[1]
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end
    local dish = CreateObject(model, GetEntityCoords(tower), true, true, false)
    local offset = {
        x = 0.5,
        y = 0.5,
        z = 5
    }
    local tcoords = GetEntityCoords(tower)
    AttachEntityToEntityPhysically(dish, tower, -1, -1, tcoords.x, tcoords.y, tcoords.z, offset.x, offset.y, offset.z, 0, 0, 0, 5, false, false, true, false, 2)
    SetModelAsNoLongerNeeded(RadioTower.RepeaterProps[1])
    self.DishProp = dish
    print(("Attach dish %s at tower %s"):format(json.encode(GetEntityCoords(self.DishProp)), json.encode(tcoords)))
    --]]
    return tower
end

function RadioTower:Cleanup()
    -- TODO: clean up every thing for towers and delete objects/props for resource stop/restart.
    for i = 1, #Towers do
        local obj = Towers[i]
        if obj.DishProp ~= nil then
            DeleteEntity(obj.DishProp)
        end
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
    print(("synced %s"):format(json.encode(towers)))
    if not HasSpawnedTowers then
        for i = 1, #Towers do
            CreateTower(Towers[i].PropPosition)
        end
        HasSpawnedTowers = true
    end
    print("Synced towers")
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
    else -- number, string, boolean, etc
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
            print("no tower found")
        else
            if distance > tower.Range then
                print("closest tower out of range")
                SetRadioQuality(0.0)
            else
                local quality = 1.0 - (distance / tower.Range)
                print(("closest tower distance: %s - Range: %s - Calculated quality: %s"):format(distance, tower.Range, quality))
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