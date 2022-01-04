Towers = {}
HasSpawnedTowers = false

function GetDistance(dist1, dist2)
    local dist = #(dist1 - dist2)
    return dist
end

function GetTowerFromId(towerId)
    for _, t in ipairs(Towers) do
        if t.Id == towerId then
            return t
        end
    end
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
            if dist < closest then
                closest = dist
                closestObj = Towers[i]
            end
        end
    end
    return closestObj, closest
end

local function AddTowerRange(t)
    if not Config.debug then return end
    -- create a radius blip that indicates the range of the tower (where edge of circle = 50% capacity)
    local blip = AddBlipForRadius(t.PropPosition.x, t.PropPosition.y, t.PropPosition.z, t.Range * 0.7937)
    SetBlipAlpha(blip, 127)
    SetBlipColour(blip, 3)
end

local function CreateTowerDishes(tower)
    -- delete the other dishes if they exist
    if tower.Dishes then
        for _, e in ipairs(tower.Dishes) do
            DeleteEntity(e)
        end
    end
    tower.Dishes = {}

    -- create dishes around tower base (in a circle)
    local dishModel = GetHashKey("sonoran")
    RequestModel(dishModel)
    while not HasModelLoaded(dishModel) do Wait(10) end
    local n = 4
    for i = 0, n - 1 do
        local theta = (i * math.pi * 2) / n
        -- in a normal unit circle, cos is x and sin is y. however, we need y to be the forward direction (and 1 @ theta=0.0)
        -- so we do some unconventional stuff here to ascertain the offsets
        local offx = -math.sin(theta) * 1.6
        local offy = math.cos(theta) * 1.6

        local offset = GetOffsetFromEntityInWorldCoords(tower.Handle, offx, offy, 11.75)
        local dishHndl = CreateVehicle(dishModel, offset.x, offset.y, offset.z, 0.0, true, false)
        SetEntityAsMissionEntity(dishHndl, true, true)
        FreezeEntityPosition(dishHndl, true)
        NetworkSetEntityInvisibleToNetwork(dishHndl, true)
        SetVehicleStrong(dishHndl, true)

        -- set the decorator to "1" to alert lower functions that this is a dish
        -- NOTE: later, this is set to 0 when the dish is killed. this is so that the dish doesn't get "destroyed" when it's killed
        DecorSetInt(dishHndl, "sonrad_dish", 1)

        -- update the rotation of the antenna based on the initial rotation of the tower + theta
        -- also, thanks GTA for working in radians in some places and degrees in others (╯°□°）╯︵ ┻━┻
        local baseRot = GetEntityRotation(tower.Handle, 0)
        SetEntityRotation(dishHndl, baseRot.x, baseRot.y, baseRot.z + (theta * 180 / math.pi), 0, true)
        table.insert(tower.Dishes, dishHndl)
    end
    SetModelAsNoLongerNeeded(dishModel)
end
local function CreateTower(tower)
    local towerModel = GetHashKey("prop_radio_tower")
    RequestModel(towerModel)
    while not HasModelLoaded(towerModel) do Wait(10) end

    local coords = tower.PropPosition
    tower.Handle = CreateObject(towerModel, coords, false, false, false)
    while not DoesEntityExist(tower.Handle) do Wait(0) end
    FreezeEntityPosition(tower.Handle, true)
    SetEntityCoords(tower.Handle, coords.x, coords.y, coords.z - 1, true, true, true, false)
    PlaceObjectOnGroundProperly(tower.Handle)

    SetModelAsNoLongerNeeded(towerModel)
    CreateTowerDishes(tower)
    AddTowerRange(tower)
end

RegisterNetEvent("RadioTower:SyncTowers")
AddEventHandler("RadioTower:SyncTowers", function(towers)
    Towers = towers
    DebugPrint(("synced %s"):format(json.encode(towers)))
    if not HasSpawnedTowers then
        for i = 1, #Towers do
            CreateTower(Towers[i])
        end
        HasSpawnedTowers = true
    end
    DebugPrint("Synced towers")
end)

RegisterNetEvent("RadioTower:SpawnTower")
AddEventHandler("RadioTower:SpawnTower", function(tower)
    CreateTower(tower)
    table.insert(Towers, tower)
    if not HasSpawnedTowers then HasSpawnedTowers = true end
end)

RegisterNetEvent("RadioTower:KillDish")
AddEventHandler("RadioTower:KillDish", function(towerId, dishIndex)
    -- find the closest dish to the coordinates
    local tower = GetTowerFromId(towerId)
    if not tower then return end
    local dish = tower.Dishes[dishIndex]
    NetworkExplodeVehicle(dish, false, false)
    -- play a power-down sound for the player
    local coords = GetEntityCoords(dish)
    PlaySoundFromCoord(-1, "Power_Down", coords, "DLC_HEIST_HACKING_SNAKE_SOUNDS", 0, 80)

    -- testing revealed it takes 150ms for explosions to propagate damage to the other dishes
    Citizen.Wait(250)
    for _, e in ipairs(tower.Dishes) do
        if not IsEntityDead(e) then
            SetVehicleFixed(e)
        end
    end
end)

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
    DecorRegister("sonrad_dish", 3)
    while not HasSpawnedTowers do
        Wait(10)
    end
    while true do
        local tower, distance = GetClosestTower()
        if tower then
            if distance > tower.Range then
                DebugPrint("closest tower out of range")
                SetRadioQuality(0.0)
            else
                -- find the # of dishes that are "alive" (aka active)
                local nAlive = 0.0
                for _, e in ipairs(tower.Dishes) do
                    if not IsEntityDead(e) then
                        nAlive = nAlive + 1.0
                    end
                end

                -- base tower quality off of the distance to the tower, and the # of dishes alive
                local quality = (1.0 - (distance / tower.Range)) * (nAlive / #tower.Dishes)
                DebugPrint(("closest tower distance:%fm range:%f dishes:%f quality:%f"):format(distance, tower.Range, nAlive, quality))
                SetRadioQuality(quality)
            end
        end
        Wait(5000)
    end
end)

AddEventHandler('gameEventTriggered', function(name, data)
    if name ~= 'CEventNetworkEntityDamage' then return end

    local victim = table.remove(data, 1)
    local attacker = table.remove(data, 1)

    -- handle extra unk booleans
    local build = GetGameBuildNumber()
    if build >= 2060 then table.remove(data, 1) end
    if build >= 2189 then table.remove(data, 1) end
    for _ = 1, 2 do table.remove(data, 1) end

    local weaponHash = table.remove(data, 1)

    -- lots of condition checking to make sure we're dealing with a tower dish at the right health
    local dType = GetWeaponDamageType(weaponHash)
    if dType ~= 3 and dType ~= 5 then return end
    if DecorGetInt(victim, "sonrad_dish") ~= 1 then return end
    if not GetPlayerPed(-1) == attacker then return end
    if GetVehicleBodyHealth(victim) >= 500 then return end

    -- find the associated tower/antenna based on the victim handle
    local tower, dishIndex
    for _, t in ipairs(Towers) do
        for i, e in ipairs(t.Dishes) do
            if e == victim then
                tower = t
                dishIndex = i
                break
            end
        end
        if tower then break end
    end
    if not tower then return end

    DecorSetInt(victim, "sonrad_dish", 0)
    DebugPrint("sending dish destroyed server event")
    TriggerServerEvent('RadioTower:KillDish', tower.Id, dishIndex)
end)

-- cleanup towers on stop
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for i = 1, #Towers do
        local tower = Towers[i]
        if tower.Handle then
            DeleteEntity(tower.Handle)
        end
        for j = 1, #tower.Dishes do
            DeleteEntity(tower.Dishes[j])
        end
    end
end)
