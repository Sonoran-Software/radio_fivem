Towers = {}
HasSpawnedTowers = false

function GetDistance(dist1, dist2)
    local dist = #(dist1 - dist2)
    return dist
end
function LoadModelSync(model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(1) end
end

local function GetTowerFromId(id)
    for _, t in ipairs(Towers) do
        if t.Id == id then
            return t
        end
    end
end
local function GetTowerCoords(tower)
    if DoesEntityExist(tower.Handle) then
        return GetOffsetFromEntityInWorldCoords(tower.Handle, 0.0, 0.0, 1.0)
    else
        return tower.PropPosition
    end
end
local function GetClosestTower()
    if #Towers < 1 then
        DebugPrint("no towers spawned")
        return nil, nil
    end
    local pedLocation = GetEntityCoords(GetPlayerPed(-1))
    local d, dObj
    for i = 1, #Towers do
        local location = GetTowerCoords(Towers[i])
        local dist = GetDistance(location, pedLocation)
        if d == nil or dist < d then
            d = dist
            dObj = Towers[i]
        end
    end
    return dObj, d
end
-- returns a value from 0-1 representing the percentage of active dishes
local function GetTowerCapacity(tower)
    if not tower.Dishes or #tower.Dishes < 1 then return 1.0 end
    local n = 0.0
    for i = 1, #tower.Dishes do
        if not IsEntityDead(tower.Dishes[i]) then
            n = n + 1.0
        end
    end
    return n / #tower.Dishes
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
    LoadModelSync(dishModel)
    local n = 4
    for i = 0, n - 1 do
        local theta = (i * math.pi * 2) / n
        -- in a normal unit circle, cos is x and sin is y. however, we need y to be the forward direction (and 1 @ theta=0.0)
        -- so we do some unconventional stuff here to ascertain the offsets
        local offx = -math.sin(theta) * 1.6
        local offy = math.cos(theta) * 1.6

        local offset = GetOffsetFromEntityInWorldCoords(tower.Handle, offx, offy, 11.75)
        local dishHndl = CreateVehicle(dishModel, offset.x, offset.y, offset.z, 0.0, false, false)
        SetEntityAsMissionEntity(dishHndl, true, true)
        FreezeEntityPosition(dishHndl, true)
        if tower.Destruction then
            SetVehicleStrong(dishHndl, true)
        else
            -- turning each dish invincible will make it impossible to destroy the dishes
            -- in turn, disabling tower destruction
            SetEntityInvincible(dishHndl, true)
        end

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
local function CreateTowerLadder(tower)
    if tower.Ladder then
        DeleteEntity(tower.Ladder)
    end
    local model = GetHashKey("prop_radio_tower_ladder")
    LoadModelSync(model)

    local off = GetOffsetFromEntityInWorldCoords(tower.Handle, 0.0, 0.3, -0.4)
    local ladder = CreateObject(model, off.x, off.y, off.z, false, false, false)
    SetEntityRotation(ladder, GetEntityRotation(tower.Handle, 0) + vec(0.0, 0.0, 285.0), 0)

    tower.Ladder = ladder
    SetModelAsNoLongerNeeded(model)
end
local function CreateTower(tower)
    if not Config.noPhysicalTowers then
        local towerModel = GetHashKey("prop_radio_tower")
        LoadModelSync(towerModel)

        local coords = tower.PropPosition
        tower.Handle = CreateObject(towerModel, coords, false, false, false)
        while not DoesEntityExist(tower.Handle) do Wait(0) end
        FreezeEntityPosition(tower.Handle, true)
        SetEntityCoords(tower.Handle, coords.x, coords.y, coords.z - 1, true, true, true, false)
        PlaceObjectOnGroundProperly(tower.Handle)

        SetModelAsNoLongerNeeded(towerModel)
        CreateTowerDishes(tower)
        CreateTowerLadder(tower)
    end
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
    DecorSetInt(dish, "sonrad_dish", 0)
    -- play a power-down sound for the player
    local coords = GetEntityCoords(dish)
    PlaySoundFromCoord(-1, "Power_Down", coords, "DLC_HEIST_HACKING_SNAKE_SOUNDS", 0, 80)
end)

RegisterNetEvent("RadioTower:RepairTower")
AddEventHandler("RadioTower:RepairTower", function(towerId)
    local tower = GetTowerFromId(towerId)
    if not tower then return end
    CreateTowerDishes(tower)
    for _, e in ipairs(tower.Dishes) do
        local coords = GetEntityCoords(e)
        PlaySoundFromCoord(-1, "Success", coords, "DLC_HEIST_HACKING_SNAKE_SOUNDS", 0, 80)
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
        local pCoords = GetEntityCoords(GetPlayerPed(-1))
        local quality = 0.0
        for i = 1, #Towers do
            local tower = Towers[i]
            -- if tower is out of range, then just ignore it
            local d = #(GetTowerCoords(tower) - pCoords)
            if d > tower.Range then goto continue end

            local tQuality = (1.0 - (d / tower.Range)) * GetTowerCapacity(tower)
            if quality < tQuality then quality = tQuality end
            ::continue::
        end

        if quality == 0.0 then
            DebugPrint("closest tower out of range")
        else
            DebugPrint(('best tower quality:%.4f'):format(quality))
        end
        SetRadioQuality(quality)
        Wait(5000)
    end
end)

local function RepairTower(tower)
    local ped = GetPlayerPed(-1)
    TaskStartScenarioInPlace(ped, "WORLD_HUMAN_WELDING", 0, true)

    local start = GetGameTimer()
    -- watch WASD keys, and if pressed then cancel repair
    local controls = {32, 33, 34, 35}
    while (start + (Config.towerRepairTimer or 20) * 1000) > GetGameTimer() do
        for _, c in ipairs(controls) do
            if IsControlPressed(0, c) then
                ClearPedTasksImmediately(ped)
                return
            end
        end
        Wait(0)
    end

    ClearPedTasksImmediately(ped)

    -- recreate the dishes so they don't accidentally repair the tower twice
    -- waiting for the event to propogate
    CreateTowerDishes(tower)
    TriggerServerEvent('RadioTower:RepairTower', tower.Id)
end

CreateThread(function()
    while not HasSpawnedTowers do
        Wait(10)
    end
    while true do
        local tower, distance = GetClosestTower()
        if distance < 2.0 and GetTowerCapacity(tower) < 1.0 then
            BeginTextCommandDisplayHelp("STRING")
            AddTextComponentSubstringPlayerName("Press ~INPUT_DETONATE~ to repair this tower.")
            EndTextCommandDisplayHelp(0, false, true, -1)

            DisableControlAction(0, 47, true)
            if IsDisabledControlJustReleased(0, 47) then
                RepairTower(tower)
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while not HasSpawnedTowers do
        Wait(10)
    end
    while true do
        for i = 1, #Towers do
            local tower = Towers[i]
            local n = tower.Dishes and #tower.Dishes or 0
            for j = 1, n do
                local e = tower.Dishes[j]
                if DecorGetInt(e, 'sonrad_dish') ~= 1 then goto continue end
                if not IsEntityDead(e) then
                    -- make sure it doesn't explode from gunshots
                    SetVehiclePetrolTankHealth(e, 1000.0)
                end

                local health = GetVehicleBodyHealth(e)
                if health > 500.0 then goto continue end

                -- here we kill the dish
                DecorSetInt(e, "sonrad_dish", 0)
                DebugPrint("sending dish destroyed server event")
                TriggerServerEvent('RadioTower:KillDish', tower.Id, j)
                ::continue::
            end
        end
        Wait(250)
    end
end)

-- cleanup towers on stop
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for i = 1, #Towers do
        local tower = Towers[i]
        if tower.Handle then
            DeleteEntity(tower.Handle)
        end
        if tower.Ladder then
            DeleteEntity(tower.Ladder)
        end
        local n = tower.Dishes and #tower.Dishes or 0
        for j = 1, n do
            DeleteEntity(tower.Dishes[j])
        end
    end
end)
