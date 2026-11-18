local function chatterEnabled()
	return Config and Config.init and Config.chatter ~= false
end

local function registerChatterEvent(name, handler)
	RegisterNetEvent(name, function(...)
		if chatterEnabled() then handler(...) end
	end)
end

local function startChatterWorker(handler)
	AddEventHandler('SonoranRadio::Internal::SettingsReady', function()
		if chatterEnabled() then Citizen.CreateThread(handler) end
	end)
end

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

registerChatterEvent('SonoranRadio::SetRadioState', function(state)
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

startChatterWorker(function()
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

registerChatterEvent('Chatter:clientChatterSync', function()
	local src = source
	if AwaitRadioPlacements() then
		TriggerClientEvent('Chatter:clientChatterSync_c', src, chatterConfig, GetPortalRadioPlacementRevision('earpieces.json'))
	end
end)

registerChatterEvent('Chatter:saveChatterConfig', function(config, expectedRevision)
	local src = source
	if not CanManageRadioPlacements(src) or type(config) ~= 'table' then return end
	if not MatchesRadioPlacementRevision('earpieces.json', expectedRevision) then
		TriggerClientEvent('SonoranRadio::DisplayError', src, 'Earpieces changed. Try again with the current placements.')
		return TriggerClientEvent('Chatter:clientChatterSync_c', src, chatterConfig, GetPortalRadioPlacementRevision('earpieces.json'))
	end
	if not SaveJsonConfig('earpieces.json', config) then
		TriggerClientEvent('SonoranRadio::DisplayError', src, 'Earpieces could not be saved. Check the server log.')
		TriggerClientEvent('Chatter:clientChatterSync_c', src, chatterConfig, GetPortalRadioPlacementRevision('earpieces.json'))
		return
	end
	chatterConfig = config
	TriggerClientEvent('Chatter:clientChatterSync_c', -1, chatterConfig, GetPortalRadioPlacementRevision('earpieces.json'))
	TriggerClientEvent('chat:addMessage', src, { args = { 'Sonoran Radio', 'Earpieces saved.' } })
end)

-- scanners across the entire server
local staticScanners
local globalScanners = {}
registerChatterEvent('SonoranRadio::pushScanner', function(id, data)
	local src = source
	if not staticScanners or type(data) ~= 'table' or (type(id) ~= 'string' and type(id) ~= 'number') then return end
	if Config.acePermsForScanners and not IsPlayerAceAllowed(src, 'sonoranradio.scanner') then return end
	for index, scanner in ipairs(staticScanners) do
		if scanner.Id == id then
			local requested = data.channelId
			if type(requested) == 'number' then
				if requested < 0 or requested > 9007199254740991 or requested % 1 ~= 0 then return end
			elseif type(requested) ~= 'string' or #requested > 100 or not requested:match('^[%w_.:@+-]+$') then
				return
			end
			local ped = GetPlayerPed(src)
			if ped == 0 then return end
			local player = GetEntityCoords(ped)
			local pos = scanner.PropPosition
			local dx, dy, dz = player.x - pos.x, player.y - pos.y, (player.z - pos.z) * 0.5
			if dx * dx + dy * dy + dz * dz > 25 then return end
			local updated = shallowcopy(scanner)
			updated.ChannelId = requested
			local proposed = shallowcopy(staticScanners)
			proposed[index] = updated
			if requested ~= scanner.ChannelId and not SaveJsonConfig('scanners.json', proposed) then
				return TriggerClientEvent('SonoranRadio::DisplayError', src, 'The scanner channel could not be saved. Check the server log.')
			end
			staticScanners = proposed
			data = { powered = data.powered ~= false, channelId = requested, pos = vec3(pos.x, pos.y, pos.z) }
			break
		end
	end

	globalScanners[id] = data
	TriggerLatentClientEvent('SonoranRadio::receiveScanners', -1, 10000, globalScanners)
end)
registerChatterEvent('SonoranRadio::requestScanners', function()
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

registerChatterEvent('SonoranRadio::SpawnStaticScanner', function(propModel, propPosition, note)
	local src = source
	if not CanManageRadioPlacements(src) then return end
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
registerChatterEvent('SonoranRadio::MoveStaticScanner', function(scannerId, propPosition)
	local src = source
	if not CanManageRadioPlacements(src) then return end

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
registerChatterEvent('SonoranRadio::DeleteStaticScanner', function(scannerId)
	local src = source
	if not CanManageRadioPlacements(src) then return end

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
startChatterWorker(function()
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

registerChatterEvent('SonoranRadio::checkScannerProfilePerms', function(profileInfos)
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
startChatterWorker(function()
	local aceCache = {}
	AddEventHandler('playerDropped', function()
		-- Player IDs can be reused; a new connection must receive its own authorization.
		aceCache[tostring(source)] = nil
	end)
	while true do
		-- Snapshot IDs before yielding: disconnects can invalidate live player indices.
		for _, playerId in ipairs(GetPlayers()) do
			-- A player in the snapshot may have disconnected during the previous wait.
			if GetPlayerName(playerId) then
				local hasScannerPerm = not Config.acePermsForScanners or not not IsPlayerAceAllowed(playerId, 'sonoranradio.scanner')
				if aceCache[playerId] ~= hasScannerPerm then
					aceCache[playerId] = hasScannerPerm
					TriggerClientEvent('SonoranRadio::AuthorizeScanners', playerId, hasScannerPerm)
				end
			end

			Citizen.Wait(100)
		end
		Citizen.Wait(5000)
	end
end)

startChatterWorker(function()
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
