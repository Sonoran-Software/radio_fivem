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
	TriggerClientEvent('Chatter:clientChatterSync_c', source, chatterConfig)
end)

RegisterNetEvent('Chatter:saveChatterConfig', function(config)
	chatterConfig = config
	SaveResourceFile(GetCurrentResourceName(), 'earpieces.json', json.encode(chatterConfig, { indent = true }), -1)
	TriggerClientEvent('Chatter:clientChatterSync_c', -1, chatterConfig)
end)

-- scanners across the entire server
local globalScanners = {}
RegisterNetEvent('SonoranRadio::pushScanner', function(id, data)
	globalScanners[id] = data
	TriggerClientEvent('SonoranRadio::receiveScanners', -1, globalScanners)
end)

-- check for radio scanners and add metadata if needed
Citizen.CreateThread(function()
	local function genId()
		local id
		repeat
			id = tostring(math.random(1, 999999))
		until not globalScanners[id]
		return id
	end

	local QBCore
	repeat
		Citizen.Wait(1000)
		QBCore = exports['qb-core']:GetCoreObject({'Functions'})
	until QBCore ~= nil

	local scannerItemName = Config.ScannerItem and Config.ScannerItem.name or 'sonoran_radio_scanner'
	while Config.enforceRadioItem do
		local QBPlayers = QBCore.Functions.GetQBPlayers()
		for _, Player in ipairs(QBPlayers) do
			local updatedItems = false
			for _, item in ipairs(Player.PlayerData.items or {}) do
				if item.name == scannerItemName and item.info.scannerId == nil then
					updatedItems = true
					item.info.scannerId = genId()
				end
			end

			if updatedItems then
				Player.Functions.SetPlayerData('items', Player.PlayerData.items)
			end
		end

		Citizen.Wait(1000)
	end
end)

RegisterNetEvent('SonoranRadio::checkProfilePerms', function(profileInfos)
	local allowedProfileIds = {}
	for _, info in ipairs(profileInfos) do
		local allowed = not Config.acePermsForScanners or
			IsPlayerAceAllowed(source, 'sonoranradio.channel.'..info.displayName)
		if allowed then
			table.insert(allowedProfileIds, info.id)
		end
	end

	if #allowedProfileIds > 0 then
		TriggerClientEvent('SonoranRadio::allowScannerProfiles', source, allowedProfileIds)
	end
end)
