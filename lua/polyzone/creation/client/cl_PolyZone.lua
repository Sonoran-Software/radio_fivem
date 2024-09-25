local minZ = GetEntityCoords(PlayerPedId()).z - 1.0
local maxZ = GetEntityCoords(PlayerPedId()).z + 10.0

local function handleInput(center)
  local rot = GetGameplayCamRot(2)
  center = handleArrowInput(center, rot.z)
  return center
end

function handleZInput(minZInput, maxZInput)
  maxZ = maxZInput
  minZ = minZInput
  delta = 0.05
  if IsDisabledControlPressed(0, 36) then -- ctrl held down
    delta = 0.01
  end
  if IsDisabledControlPressed(0, 10) then -- Page Up
    maxZ = maxZ + delta
  end
  if IsDisabledControlPressed(0, 11) then -- Page Down
    maxZ = maxZ - delta
  end
  if IsDisabledControlPressed(0, 121) then -- Insert
    minZ = minZ + delta
  end
  if IsDisabledControlPressed(0, 178) then -- Delete
    minZ = minZ - delta
  end
  zInputFromPolyzone(minZ, maxZ)
  return minZ, maxZ
end

function polyStart(name)
  local coords = GetEntityCoords(PlayerPedId())
  minZ = coords.z - 1.0
  maxZ = coords.z + 10.0
  createdZone = PolyZone:Create({vector2(coords.x, coords.y)}, {name = tostring(name), useGrid=true})
  Citizen.CreateThread(function()
    while createdZone do
      -- Have to convert the point to a vector3 prior to calling handleInput,
      -- then convert it back to vector2 afterwards
      lastPoint = createdZone.points[#createdZone.points]
      lastPoint = vector3(lastPoint.x, lastPoint.y, 0.0)
      lastPoint = handleInput(lastPoint)
      createdZone.minZ, createdZone.maxZ = handleZInput(minZ, maxZ)
      createdZone.points[#createdZone.points] = lastPoint.xy
      Wait(0)
    end
  end)
  minZ, maxZ = coords.z, coords.z
end

function polyFinish(degradeStrength, minY, maxY)
  TriggerServerEvent("SonoranRadio:PolyZone:CreateZone", createdZone.points, createdZone.name, minY, maxY, degradeStrength)
end

RegisterNetEvent("SonoranRadio:PolyZone:pzadd")
AddEventHandler("SonoranRadio:PolyZone:pzadd", function()
  if createdZone == nil or createdZoneType ~= 'poly' then
    TriggerEvent('chat:addMessage', {
      color = {255, 0, 0},
      multiline = true,
      args = {"SonoranRadio Zone Creator", "You must start a PolyZone before adding points!"}
    })
    return
  end

  local coords = GetEntityCoords(PlayerPedId())

  if (coords.z > maxZ) then
    maxZ = coords.z
  end

  if (coords.z < minZ) then
    minZ = coords.z
  end

  createdZone.points[#createdZone.points + 1] = vector2(coords.x, coords.y)
end)

RegisterNetEvent("SonoranRadio:PolyZone:pzundo")
AddEventHandler("SonoranRadio:PolyZone:pzundo", function()
  if createdZone == nil or createdZoneType ~= 'poly' then
    return
  end

  createdZone.points[#createdZone.points] = nil
  if #createdZone.points == 0 then
    TriggerEvent("SonoranRadio:PolyZone:pzcancel")
  end
end)