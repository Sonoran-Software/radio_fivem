if not Config or Config.chatter == false then return end -- if chatter is disabled, skip this script

local radioStates = {}
local lastRadioStatesPush = 0
local DevEvents = DeveloperEvents or {}

local function emitDeveloperEvent(suffix, payload)
	if DevEvents.emit then
		DevEvents.emit(suffix, payload)
	else
		TriggerEvent(('SonoranRadio::Developer:%s'):format(suffix), payload)
	end
end

local function getPlayerPayload(src)
	if DevEvents.playerContext then
		return DevEvents.playerContext(src)
	end
	return {serverId = src}
end

local function pushRadioStatesNow()
	local states = {}
	for ply, info in pairs(radioStates) do
		states[ply] = info.state
	end

	local msgBytes = msgpack.pack_args(states):len()
	local bitrate = math.max(msgBytes / 4.0, 500) * 8
	TriggerLatentClientEvent('SonoranRadio::ReceiveRadioStates', -1, bitrate, states)

	lastRadioStatesPush = GetGameTimer()
end
local function pushRadioStates()
	local toWait = 5000 - (GetGameTimer() - lastRadioStatesPush)
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
	local sanitized = DevEvents.sanitize and DevEvents.sanitize(state) or state
	if sanitized ~= nil then
		emitDeveloperEvent('RadioState:Updated', {
			player = getPlayerPayload(source),
			state = sanitized
		})
	end
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
	SaveJsonConfig('earpieces.json', chatterConfig)
	TriggerClientEvent('Chatter:clientChatterSync_c', -1, chatterConfig)
end)

-- scanners across the entire server
local staticScanners
local globalScanners = {}
RegisterNetEvent('SonoranRadio::pushScanner', function(id, data)
	for _, scanner in ipairs(staticScanners or {}) do
		if scanner.Id == id then
			local previousChannelId = scanner.ChannelId
			scanner.ChannelId = data.channelId
			if not SaveJsonConfig('scanners.json', staticScanners) then
				scanner.ChannelId = previousChannelId
				return TriggerClientEvent('SonoranRadio::DisplayError', source, 'An error prevents your changes from saving (see server log for more)')
			end
			break
		end
	end

	globalScanners[id] = data
	TriggerLatentClientEvent('SonoranRadio::receiveScanners', -1, 10000, globalScanners)
end)
RegisterNetEvent('SonoranRadio::requestScanners', function()
	TriggerLatentClientEvent('SonoranRadio::receiveScanners', source, 10000, globalScanners, staticScanners)
end)

function initStaticScanners(s)
	staticScanners = s
	for _, ss in ipairs(staticScanners) do
		globalScanners[ss.Id] = {
			powered = ss.Powered ~= false,
			channelId = ss.ChannelId,
			pos = vec3(ss.PropPosition.x, ss.PropPosition.y, ss.PropPosition.z)
		}
	end
end

RegisterNetEvent('SonoranRadio::SpawnStaticScanner', function(propModel, propPosition, note)
	local src = source
	local scannerInfo = {
		Id = uuid(),
		Note = note,
		Powered = true,
		ChannelId = 0, -- use the default channel
		PropModel = propModel, -- may be nil, since there is a default prop
		PropPosition = propPosition
	}

	-- add to the scanners.json
	local newStaticScanners = {}
	for _, ss in ipairs(staticScanners) do
		newStaticScanners[#newStaticScanners + 1] = ss
	end
	newStaticScanners[#newStaticScanners + 1] = scannerInfo
	if not SaveJsonConfig('scanners.json', newStaticScanners) then
		return TriggerClientEvent('SonoranRadio::DisplayError', src, 'An error prevents your changes from saving (see server log for more)')
	end

	-- send out new scanner info
	staticScanners = newStaticScanners
	globalScanners[scannerInfo.Id] = {
		powered = scannerInfo.Powered ~= false,
		channelId = scannerInfo.ChannelId,
		pos = vec3(scannerInfo.PropPosition.x, scannerInfo.PropPosition.y, scannerInfo.PropPosition.z)
	}
	TriggerClientEvent('SonoranRadio::receiveScanners', -1, globalScanners, staticScanners)
end)
RegisterNetEvent('SonoranRadio::MoveStaticScanner', function(scannerId, propPosition)
	local src = source

	-- update the scanners.json
	local newStaticScanners = {}
	for _, ss in ipairs(staticScanners) do
		if ss.Id == scannerId then
			-- if ids match, shallow copy the scanner and update the position
			local newScanner = {}
			for k, v in pairs(ss) do
				newScanner[k] = v
			end
			newScanner.PropPosition = propPosition
			ss = newScanner
		end
		newStaticScanners[#newStaticScanners + 1] = ss
	end
	if not SaveJsonConfig('scanners.json', newStaticScanners) then
		return TriggerClientEvent('SonoranRadio::DisplayError', src, 'An error prevents your changes from saving (see server log for more)')
	end

	-- send out new scanner info
	staticScanners = newStaticScanners
	if globalScanners[scannerId] then
		globalScanners[scannerId].pos = vec3(propPosition.x, propPosition.y, propPosition.z)
	end
	TriggerClientEvent('SonoranRadio::receiveScanners', -1, globalScanners, staticScanners)
end)
RegisterNetEvent('SonoranRadio::DeleteStaticScanner', function(scannerId)
	local src = source

	-- remove from the scanners.json
	local newStaticScanners = {}
	for _, ss in ipairs(staticScanners) do
		if ss.Id ~= scannerId then
			newStaticScanners[#newStaticScanners + 1] = ss
		end
	end
	if not SaveJsonConfig('scanners.json', newStaticScanners) then
		return TriggerClientEvent('SonoranRadio::DisplayError', src, 'An error prevents your changes from saving (see server log for more)')
	end

	-- send out new scanner info
	staticScanners = newStaticScanners
	globalScanners[scannerId] = nil
	TriggerClientEvent('SonoranRadio::receiveScanners', -1, globalScanners, staticScanners)
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

	local scannerItemName = Config.ScannerItem and Config.ScannerItem.name or 'sonoran_radio_scanner'
	while Config.enforceRadioItem do
        local QBPlayers = {}

        -- Retrieve players based on the active framework
        if frameworkEnum == 1 then
			QBCore = QBCore or exports['qb-core']:GetCoreObject({'Functions'})
			if QBCore and QBCore.Functions then
				QBPlayers = QBCore.Functions.GetQBPlayers()
			end
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

RegisterNetEvent('SonoranRadio::checkScannerProfilePerms', function(profileInfos)
	local allowedProfileIds = {}
	for _, info in ipairs(profileInfos or {}) do
		local allowed =
			IsPlayerAceAllowed(source, 'sonoranradio.channel.'..info.displayName) or
			IsPlayerAceAllowed(source, 'sonoranradio.channel.'..info.id)
		if allowed then
			table.insert(allowedProfileIds, info.id)
		end
	end

	DebugPrint(('[Scanner] ACE check player=%s profiles=%s allowedProfileIds=%s'):format(
		tostring(source),
		tostring(profileInfos and #profileInfos or 0),
		json.encode(allowedProfileIds)
	))
	TriggerClientEvent('SonoranRadio::allowScannerProfiles', source, allowedProfileIds)
end)
Citizen.CreateThread(function()
	local aceCache = {}
	while true do
		for i = 0, GetNumPlayerIndices() - 1 do
			local playerId = GetPlayerFromIndex(i)
			local hasScannerPerm = not Config.acePermsForScanners or not not IsPlayerAceAllowed(playerId, 'sonoranradio.scanner')
			if aceCache[playerId] ~= hasScannerPerm then
				aceCache[playerId] = hasScannerPerm
				TriggerClientEvent('SonoranRadio::AuthorizeScanners', playerId, hasScannerPerm)
			end

			Citizen.Wait(100)
		end
		Citizen.Wait(5000)
	end
end)

Citizen.CreateThread(function()
	local oxScannerHookRegistered = false
	local function registerOxScannerHook()
		if oxScannerHookRegistered or inventoryEnum ~= 2 then
			return
		end

		oxScannerHookRegistered = true
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

	if Config.enforceRadioItem then
		Citizen.CreateThread(function()
			if waitForFrameworkInventory() then
				registerOxScannerHook()
			end
		end)
	end
end)
