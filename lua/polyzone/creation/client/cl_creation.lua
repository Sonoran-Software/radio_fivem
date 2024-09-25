lastCreatedZoneType = nil
lastCreatedZone = nil
createdZoneType = nil
createdZone = nil
drawZone = false

RegisterNetEvent('SonoranRadio:PolyZone:UpdateZ', function(minZ, maxZ)
  if createdZone == nil then
    return
  end
  -- createdZone.minZ = minZ
  -- createdZone.maxZ = maxZ
  handleZInput(minZ, maxZ)
end)

RegisterNetEvent("SonoranRadio:PolyZone:pzcreate")
AddEventHandler("SonoranRadio:PolyZone:pzcreate", function(zoneType, name, args)
  if createdZone ~= nil then
    TriggerEvent('chat:addMessage', {
      color = { 255, 0, 0},
      multiline = true,
      args = {"SonoranRadio Zone Creator", "A shape is already being created!"}
    })
    return
  end

  if zoneType == 'poly' then
    polyStart(name)
  elseif zoneType == "circle" then
    local radius = nil
    if #args >= 3 then radius = tonumber(args[3])
    else radius = tonumber(GetUserInput("Enter radius:")) end
    if radius == nil then
      TriggerEvent('chat:addMessage', {
        color = { 255, 0, 0},
        multiline = true,
        args = {"SonoranRadio Zone Creator", "CircleZone requires a radius (must be a number)!"}
      })
      return
    end
    circleStart(name, radius)
  elseif zoneType == "box" then
    local length = nil
    if #args >= 3 then length = tonumber(args[3])
    else length = tonumber(GetUserInput("Enter length:")) end
    if length == nil or length < 0.0 then
      TriggerEvent('chat:addMessage', {
        color = { 255, 0, 0},
        multiline = true,
        args = {"SonoranRadio Zone Creator", "BoxZone requires a length (must be a positive number)!"}
      })
      return
    end
    local width = nil
    if #args >= 4 then width = tonumber(args[4])
    else width = tonumber(GetUserInput("Enter width:")) end
    if width == nil or width < 0.0 then
      TriggerEvent('chat:addMessage', {
        color = { 255, 0, 0},
        multiline = true,
        args = {"SonoranRadio Zone Creator", "BoxZone requires a width (must be a positive number)!"}
      })
      return
    end
    boxStart(name, 0, length, width)
  else
    return
  end
  createdZoneType = zoneType
  drawZone = true
  disableControlKeyInput()
  drawThread()
  drawInstructions()
end)

RegisterNetEvent("SonoranRadio:PolyZone:pzfinish")
AddEventHandler("SonoranRadio:PolyZone:pzfinish", function(degradeStrength, minY, maxY)
  if createdZone == nil then
    return
  end

  if createdZoneType == 'poly' then
    polyFinish(degradeStrength, minY, maxY)
  elseif createdZoneType == "circle" then
    circleFinish()
  elseif createdZoneType == "box" then
    boxFinish()
  end

  TriggerEvent('chat:addMessage', {
    color = { 0, 255, 0},
    multiline = true,
    args = {"SonoranRadio Zone Creator", "Zone created!"}
  })

  lastCreatedZoneType = createdZoneType
  lastCreatedZone = createdZone

  drawZone = false
  createdZone = nil
  createdZoneType = nil
end)

RegisterNetEvent("SonoranRadio:PolyZone:pzlast")
AddEventHandler("SonoranRadio:PolyZone:pzlast", function()
  if createdZone ~= nil or lastCreatedZone == nil then
    return
  end
  if lastCreatedZoneType == 'poly' then
    TriggerEvent('chat:addMessage', {
      color = { 0, 255, 0},
      multiline = true,
      args = {"SonoranRadio Zone Creator", "The command pzlast only supports BoxZone and CircleZone for now"}
    })
  end

  local name = GetUserInput("Enter name (or leave empty to reuse last zone's name):")
  if name == nil then
    return
  elseif name == "" then
    name = lastCreatedZone.name
  end
  createdZoneType = lastCreatedZoneType
  if createdZoneType == 'box' then
    local minHeight, maxHeight
    if lastCreatedZone.minZ then
      minHeight = lastCreatedZone.center.z - lastCreatedZone.minZ
    end
    if lastCreatedZone.maxZ then
      maxHeight = lastCreatedZone.maxZ - lastCreatedZone.center.z
    end
    boxStart(name, lastCreatedZone.offsetRot, lastCreatedZone.length, lastCreatedZone.width, minHeight, maxHeight)
  elseif createdZoneType == 'circle' then
    circleStart(name, lastCreatedZone.radius, lastCreatedZone.useZ)
  end
  drawZone = true
  disableControlKeyInput()
  drawThread()
  drawInstructions()
end)

RegisterNetEvent("SonoranRadio:PolyZone:pzcancel")
AddEventHandler("SonoranRadio:PolyZone:pzcancel", function()
  if createdZone == nil then
    return
  end

  TriggerEvent('chat:addMessage', {
    color = {255, 0, 0},
    multiline = true,
    args = {"SonoranRadio Zone Creator", "Zone creation canceled!"}
  })

  drawZone = false
  createdZone = nil
  createdZoneType = nil
end)

-- Drawing
local degradeZoneScaleform = nil
Citizen.CreateThread(function()
  degradeZoneScaleform = RequestScaleformMovie('INSTRUCTIONAL_BUTTONS')
  while not HasScaleformMovieLoaded(degradeZoneScaleform) do
    Wait(0)
  end
end)

function drawInstructions()
  while drawZone do
    BeginScaleformMovieMethod(degradeZoneScaleform, 'CLEAR_ALL')
    EndScaleformMovieMethod()

    BeginScaleformMovieMethod(degradeZoneScaleform, 'SET_DATA_SLOT')
    ScaleformMovieMethodAddParamInt(0)
    PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 107))
    PushScaleformMovieMethodParameterString('Rotate X +/-')
    EndScaleformMovieMethod()

    BeginScaleformMovieMethod(degradeZoneScaleform, 'SET_DATA_SLOT')
    ScaleformMovieMethodAddParamInt(1)
    PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 110))
    PushScaleformMovieMethodParameterString('Rotate Y +/-')
    EndScaleformMovieMethod()

    BeginScaleformMovieMethod(degradeZoneScaleform, 'SET_DATA_SLOT')
    ScaleformMovieMethodAddParamInt(2)
    PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 10))
    PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 11))
    PushScaleformMovieMethodParameterString('Max Z +/-')
    EndScaleformMovieMethod()

    -- BeginScaleformMovieMethod(degradeZoneScaleform, 'SET_DATA_SLOT')
    -- ScaleformMovieMethodAddParamInt(3)
    -- PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 11))
    -- PushScaleformMovieMethodParameterString('Max Z -')
    -- EndScaleformMovieMethod()

    BeginScaleformMovieMethod(degradeZoneScaleform, 'SET_DATA_SLOT')
    ScaleformMovieMethodAddParamInt(4)
    PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 121))
    PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 178))
    PushScaleformMovieMethodParameterString('Min Z +/-')
    EndScaleformMovieMethod()

    -- BeginScaleformMovieMethod(degradeZoneScaleform, 'SET_DATA_SLOT')
    -- ScaleformMovieMethodAddParamInt(5)
    -- PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 178))
    -- PushScaleformMovieMethodParameterString('Min Z -')

    BeginScaleformMovieMethod(degradeZoneScaleform, 'SET_DATA_SLOT')
    ScaleformMovieMethodAddParamInt(5)
    PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 36))
    PushScaleformMovieMethodParameterString('Slow Movement')
    EndScaleformMovieMethod()

    BeginScaleformMovieMethod(degradeZoneScaleform, 'DRAW_INSTRUCTIONAL_BUTTONS')
    ScaleformMovieMethodAddParamInt(0)
    EndScaleformMovieMethod()
    DrawScaleformMovieFullscreen(degradeZoneScaleform, 255, 255, 255, 255, 0)
    Wait(0)
  end
end

function drawThread()
  Citizen.CreateThread(function()
    while drawZone do
      if createdZone then
        createdZone:draw()
      end
      Wait(0)
    end
  end)
end

local rad, cos, sin = math.rad, math.cos, math.sin
function PolyZone.rotate(origin, point, theta)
  if theta == 0.0 then return point end

  local p = point - origin
  local pX, pY = p.x, p.y
  theta = rad(theta)
  local cosTheta = cos(theta)
  local sinTheta = sin(theta)
  local x = pX * cosTheta - pY * sinTheta
  local y = pX * sinTheta + pY * cosTheta
  return vector2(x, y) + origin
end
