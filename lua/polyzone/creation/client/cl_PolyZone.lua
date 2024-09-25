local minZ, maxZ = nil, nil

local function handleInput(center)
  local rot = GetGameplayCamRot(2)
  center = handleArrowInput(center, rot.z)
  return center
end

-- function handleZInput(minZ, maxZ)
--   maxZ = maxZ
--   minZ = minZ
--   delta = 0.05

--   if IsDisabledControlPressed(0, 36) then -- ctrl held down
--     delta = 0.01
--   end
--   if IsDisabledControlPressed(0, 314) then -- NumPad +
--     minZ = minZ + delta
--     return minZ + delta, maxZ
--   end
--   if IsDisabledControlPressed(0, 315) then -- NumPad -
--     maxZ = maxZ - delta
--     return minZ, maxZ - delta
--   end
--   return minZ, maxZ
-- end

function polyStart(name)
  local coords = GetEntityCoords(PlayerPedId())
  createdZone = PolyZone:Create({vector2(coords.x, coords.y)}, {name = tostring(name), useGrid=true})
  Citizen.CreateThread(function()
    while createdZone do
      -- Have to convert the point to a vector3 prior to calling handleInput,
      -- then convert it back to vector2 afterwards
      lastPoint = createdZone.points[#createdZone.points]
      lastPoint = vector3(lastPoint.x, lastPoint.y, 0.0)
      lastPoint = handleInput(lastPoint)
      -- createdZone.minZ, createdZone.maxZ = handleZInput(createdZone.minZ, createdZone.maxZ)
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