local eventPrefix = '__PolyZone__:'

function triggerZoneEvent(eventName, ...)
  TriggerClientEvent(eventPrefix .. eventName, -1, ...)
end

RegisterNetEvent("SonoranRadio:PolyZone:TriggerZoneEvent")
AddEventHandler("SonoranRadio:PolyZone:TriggerZoneEvent", triggerZoneEvent)

exports("TriggerZoneEvent", triggerZoneEvent)