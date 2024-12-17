if Config.chatter == false then return end -- if chatter is disabled, skip this script

local radioStates = {}
local function pushRadioStates(s)
	local states = {}
	for ply, info in pairs(radioStates) do
		states[ply] = info.state
	end
	TriggerClientEvent('SonoranRadio::ReceiveRadioStates', s or -1, states)
end

RegisterNetEvent('SonoranRadio::SetRadioState', function(state)
	radioStates[source] = {state = state, lastUpdate = GetGameTimer()}
	pushRadioStates()
end)

Citizen.CreateThread(function()
	local MAX_AGE = 30000

	while true do
		local toRemove = {}

		for ply, info in pairs(radioStates) do
			if info.lastUpdate + MAX_AGE < GetGameTimer() then
				table.insert(toRemove, ply)
			end
		end
		for _, ply in ipairs(toRemove) do
			radioStates[ply] = nil
		end

		if #toRemove > 0 then
			pushRadioStates()
		end

		Citizen.Wait(5000)
	end
end)

RegisterNetEvent('Chatter:clientChatterSync', function()
	local source = source
	while #chatterConfig == 0 do
		Wait(10)
	end
	local sonoradData = {}
	TriggerClientEvent('Chatter:clientChatterSync_c', source, chatterConfig)
end)