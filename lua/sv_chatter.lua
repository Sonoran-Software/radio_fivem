if not Config or Config.chatter == false then return end -- if chatter is disabled, skip this script

local radioStates = {}
local lastRadioStatesPush = 0

local function pushRadioStatesNow()
	local states = {}
	for ply, info in pairs(radioStates) do
		states[ply] = info.state
	end

	TriggerClientEvent('SonoranRadio::ReceiveRadioStates', -1, states)
	lastRadioPush = GetGameTimer()
end
local function pushRadioStates()
	local toWait = 2500 - (GetGameTimer() - lastRadioStatesPush)
	if toWait <= 0 then
		-- push radio states immediately
		pushRadioStatesNow()
		return
	end

	local last = lastRadioStatesPush
	Citizen.CreateThread(function()
		Citizen.Wait(toWait)
		-- if lastRadioStatesPush was updated, another thread already pushed the states
		if last == lastRadioStatesPush then pushRadioStatesNow() end
	end)
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
	if Config.enforceRadioItem then
		if frameworkEnum == 1 then
			repeat
				Citizen.Wait(1000)
				QBCore = exports['qb-core']:GetCoreObject({'Functions'})
			until QBCore ~= nil
		end
	end

	local scannerItemName = Config.ScannerItem and Config.ScannerItem.name or 'sonoran_radio_scanner'
	while Config.enforceRadioItem do
        local QBPlayers = {}

        -- Retrieve players based on the active framework
        if frameworkEnum == 1 then
            QBPlayers = QBCore.Functions.GetQBPlayers()
        elseif frameworkEnum == 2 then
            QBPlayers = exports.qbx_core:GetQBPlayers()
        end
        for _, Player in pairs(QBPlayers) do
			if not Player then
				goto continue
			end
			local updatedItems = false
            local items = Player.PlayerData.items or {}

            for _, item in ipairs(items) do
                if item.name == scannerItemName then
                    -- Ensure item.info exists before checking/updating scannerId
					if inventoryEnum == 1 then
						if not item.info then
							item.info = {}
						end
						if item.info.scannerId == nil then
							updatedItems = true
							item.info.scannerId = genId()
						end
					elseif inventoryEnum == 2 then
						if item.metadata.scannerId == nil then
							updatedItems = true
						end
					end
                end
            end

            if updatedItems then
                -- Update player items based on the active framework
                if frameworkEnum == 1 then
                    Player.Functions.SetPlayerData('items', items)
                elseif frameworkEnum == 2 then
					local scannerInInv = exports.ox_inventory:Search(Player.PlayerData.source, 'slots', scannerItemName)
					if not scannerInInv then return end
					for k, v in pairs(scannerInInv) do
						scannerInInv = v
						break
					end

					scannerInInv.metadata.scannerId = genId()
					exports.ox_inventory:SetMetadata(Player.PlayerData.source, scannerInInv.slot, scannerInInv.metadata)
                end
            end
			::continue::
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

Citizen.CreateThread(function()
	Wait(5000)
	if inventoryEnum == 2 then
		local hookId = exports.ox_inventory:registerHook('swapItems', function(payload)
			local scannerItemName = Config.ScannerItem and Config.ScannerItem.name or 'sonoran_radio_scanner'
			if payload.action == 'move' and payload.fromType == 'player' and payload.toType == 'drop' then
				if payload.fromSlot.name == scannerItemName then
					local src = payload.source
					local coords = GetEntityCoords(GetPlayerPed(src))
					payload.fromSlot.coords = coords
					table.insert(scanners, payload.fromSlot)
				end
			end
			return true
		end, {
			print = false,
		})
	end
end)