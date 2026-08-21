function initScanners()
	if Config.chatter == false then return end

	-- SCANNER PERMS
	local allowed = false
	RegisterNetEvent('SonoranRadio::AuthorizeScanners', function(perm)
		allowed = perm
	end)

	-- STATIC SCANNER LOGIC
	StaticScanners = {}
	local ssObjects = {}
	Citizen.CreateThread(function()
		local OBJ_RANGE = 100.0

		while true do
			local myPos = GetEntityCoords(PlayerPedId())
			local ssIdSet = {}
			for _, ss in ipairs(StaticScanners) do
				ssIdSet[ss.Id] = true

				local model = GetHashKey(ss.PropModel or 'prop_cs_hand_radio')
				local pos = vec3(ss.PropPosition.x, ss.PropPosition.y, ss.PropPosition.z)
				local dist = #(pos - myPos)

				if dist < OBJ_RANGE then
					if ssObjects[ss.Id] == nil then
						-- we are in range, but the obj is not spawned
						while not HasModelLoaded(model) do
							RequestModel(model)
							Citizen.Wait(0)
						end
						-- create the object in the world
						-- NOTE: position/heading and set below
						local obj = CreateObject(model, pos.x, pos.y, pos.z, false, true, false)
						SetEntityCollision(obj, false, false)
						SetModelAsNoLongerNeeded(model)
						ssObjects[ss.Id] = obj
					end

					SetEntityCoords(ssObjects[ss.Id], pos.x, pos.y, pos.z, false, false, false, true)
					SetEntityHeading(ssObjects[ss.Id], ss.PropPosition.heading)
					if not ss.PropPosition.exact then
						PlaceObjectOnGroundOrObjectProperly(ssObjects[ss.Id])
					end
				elseif ssObjects[ss.Id] ~= nil then
					-- we are out of range, but the object still exists
					DeleteObject(ssObjects[ss.Id])
					ssObjects[ss.Id] = nil
				end
			end

			-- cleanup objects for scanners that were deleted / don't exist
			for id, obj in pairs(ssObjects) do
				if not ssIdSet[id] then
					DeleteObject(ssObjects[id])
					ssObjects[id] = nil
				end
			end

			Citizen.Wait(500)
		end
	end)
	function getNearestStaticScanner(coord, nearDist)
		nearDist = nearDist or math.huge
		local nearScanner
		for _, ss in ipairs(StaticScanners) do
			local ssCoord = vec3(ss.PropPosition.x, ss.PropPosition.y, ss.PropPosition.z)
			local d = #(coord - ssCoord)
			if d < nearDist then
				nearDist = d
				nearScanner = ss
			end
		end
		return nearScanner
	end
	AddEventHandler('onResourceStop', function(res)
		if res ~= GetCurrentResourceName() then return end
		-- this resource is stopping, cleanup
		for _, obj in pairs(ssObjects) do
			DeleteObject(obj)
		end
	end)
	
	-- SCANNER MENU LOGIC
	local scanners = {}
	local inventoryScannerId = 0
	local function pushScanner(id)
		if id ~= 0 then
			TriggerServerEvent('SonoranRadio::pushScanner', id, scanners[id])
		end
	end
	RegisterNetEvent('SonoranRadio::receiveScanners', function(state, static)
		local localScanner = scanners[0]
		scanners = state
		scanners[0] = localScanner

		if static then
			StaticScanners = static
		end
	end)

	-- SCANNER MENUS
	local function openScannerMenu(scannerId, scannerCoords)
		if not allowed then
			DebugPrint(('[Scanner] Open denied scannerId=%s'):format(tostring(scannerId)))
			return
		end
		local scanner = scanners[scannerId]
		DebugPrint(('[Scanner] Opening scannerId=%s stateFound=%s powered=%s channelId=%s'):format(
			tostring(scannerId),
			tostring(scanner ~= nil),
			tostring(scanner and scanner.powered),
			tostring(scanner and scanner.channelId)
		))
		PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
		SendNUIMessage({ type = 'openScanner', id = scannerId, state = scanner })
		SetNuiFocus(true, true)
	end
	function openLocalScanner()
		if inventoryScannerId ~= nil then
			openScannerMenu(inventoryScannerId)
		end
	end

	local scannerDrops = {}
	local scannerUseEventRegistered = false
	local scannerInventoryThreadStarted = false
	local function registerScannerUseEvent()
		if scannerUseEventRegistered then
			return
		end

		scannerUseEventRegistered = true
		RegisterNetEvent('qb-sonrad:use-scanner', function()
			openLocalScanner()
		end)
	end

	local function setupInventoryScannerIntegration()
		if scannerInventoryThreadStarted or not Config.enforceRadioItem or not hasFrameworkInventory() then
			return
		end

		if frameworkEnum == 1 and inventoryEnum == 1 then
			registerScannerUseEvent()
			scannerInventoryThreadStarted = true
			Citizen.CreateThread(function()
				local QBCore = exports['qb-core']:GetCoreObject()
				while Config.enforceRadioItem do
					if GetResourceState('qb-inventory') == 'started' then
						local scannerItemName = Config.ScannerItem and Config.ScannerItem.name or 'sonoran_radio_scanner'

						-- find all qb-inventory drops containing scanner items
						QBCore.Functions.TriggerCallback('qb-inventory:server:GetCurrentDrops', function(drops)
							scannerDrops = {}
							for dropId, drop in pairs(drops) do
								for _, item in ipairs(drop.items) do
									if item.name == scannerItemName then
										local scannerId = item.info.scannerId or dropId
										scannerDrops[scannerId] = drop
										break
									end
								end
							end
						end)
						-- find the scanner in the player's inventory
						inventoryScannerId = nil
						local playerData = QBCore.Functions.GetPlayerData()
						for _, item in ipairs(playerData.items or {}) do
							if item.name == scannerItemName then
								inventoryScannerId = item.info.scannerId or 0
								break
							end
						end
					end

					-- query every 1s
					Citizen.Wait(1000)
				end
			end)
		elseif inventoryEnum == 2 then
			registerScannerUseEvent()
			scannerInventoryThreadStarted = true
			if not lib then
				if GetResourceState('ox_lib') ~= 'started' then
					error('ox_lib must be started before this resource.', 0)
				end
				local chunk = LoadResourceFile('ox_lib', 'init.lua')
				if not chunk then
					error('failed to load resource file @ox_lib/init.lua', 0)
				end
				load(chunk, '@@ox_lib/init.lua', 't')()
			end

			Citizen.CreateThread(function()
				while Config.enforceRadioItem do
					local scannerItemName = Config.ScannerItem and Config.ScannerItem.name or 'sonoran_radio_scanner'
					lib.callback('getScanners', false, function(scanners)
						scannerDrops = {}
						for dropId, scanner in pairs(scanners) do
							local scannerId = scanner.metadata.scannerId or dropId
							scannerDrops[scannerId] = scanner
						end
					end)
					inventoryScannerId = nil
					local playerItem = exports.ox_inventory:GetPlayerItems()
					if playerItem and type(playerItem) == 'table' then
						for _, item in pairs(playerItem) do
							if item.name == scannerItemName then
								inventoryScannerId = item.metadata.scannerId or 0
								break
							end
						end
					end
					-- query every 1s
					Citizen.Wait(1000)
				end
			end)
		end
	end

	if Config.enforceRadioItem then
		Citizen.CreateThread(function()
			if waitForFrameworkInventory() then
				setupInventoryScannerIntegration()
			end
		end)
	end

	local function getClosestWorldScanner(maxDistance)
		local AXIS_WEIGHT = vec3(1.0, 1.0, 0.5) -- treat vertical component as less important
		local myPos = GetEntityCoords(PlayerPedId())
		local nearScannerId = nil
		local nearScannerCoords = vec(0.0, 0.0, 0.0)
		local nearScannerDist = maxDistance or math.huge

		-- find the nearest scanner as a drop
		for dropId, drop in pairs(scannerDrops) do
			local coords = vec3(drop.coords.x, drop.coords.y, drop.coords.z)
			local dist = #((coords - myPos) * AXIS_WEIGHT)
			if dist < nearScannerDist then
				nearScannerId = dropId
				nearScannerDist = dist
				nearScannerCoords = coords
			end
		end
		-- find the nearest static scanner
		for id, scanner in pairs(scanners) do
			if type(scanner.pos) == 'vector3' then
				local dist = #((scanner.pos - myPos) * AXIS_WEIGHT)
				if dist < nearScannerDist then
					nearScannerId = id
					nearScannerDist = dist
					nearScannerCoords = scanner.pos
				end
			end
		end

		return nearScannerId, nearScannerCoords
	end
	Citizen.CreateThread(function()
		TriggerServerEvent('SonoranRadio::requestScanners')
		AddTextEntry('SONRAD_SCANNER_USE', 'Press ~INPUT_CONTEXT~ to use the scanner')

		while true do
			local scannerId, scannerCoords = getClosestWorldScanner(2.5)

			if allowed and scannerId and not displayHelpLock then
				displayHelpLock = true
				BeginTextCommandDisplayHelp('SONRAD_SCANNER_USE')
				EndTextCommandDisplayHelp(0, false, true, 100)

				if IsControlJustReleased(0, 38) then
					openScannerMenu(scannerId, scannerCoords)
				end

				Citizen.Wait(0)
				displayHelpLock = false
			else
				Citizen.Wait(500)
			end
		end
	end)

	-- an iterator over powered scanners and their coordinates
	-- see getScannerChatterSources for use
	local function poweredScanners()
		local next, tbl, key = pairs(scanners)
		return function()
			while true do
				local id, scanner = next(tbl, key)
				key = id
				if id == nil then
					return nil, nil, nil -- end of iterator
				end

				if not scanner.powered then
					-- pass
				elseif id == inventoryScannerId then
					return id, scanner, nil -- scanner is on player
				elseif scannerDrops[id] then
					local dropCoords = scannerDrops[id].coords
					return id, scanner, vec3(dropCoords.x, dropCoords.y, dropCoords.z)
				elseif type(scanner.pos) == 'vector3' then
					-- this is a static scanner (i.e. its position cannot change)
					return id, scanner, scanner.pos
				end
			end
		end
	end
	-- SCANNER CHATTER API
	local sDefaultProfileId = 0
	function getScannerChatterSources()
		local sources = {}
		for id, scanner, coords in poweredScanners() do
			local chId = scanner.channelId
			if chId == 0 then
				chId = sDefaultProfileId
			end
			table.insert(sources, {
				sourceEntity = coords == nil and PlayerPedId() or nil, -- coords == nil when the scanner is on the player
				pos = coords,
				scanList = {chId},
			})
		end
		return sources
	end
	AddEventHandler('ox_inventory:updateInventory', function(changes)
		local scannerItemName = Config.ScannerItem and Config.ScannerItem.name or 'sonoran_radio_scanner'
		for _, change in pairs(changes) do
			if not change then
				goto continue
			end
			if change.name == scannerItemName then
				local sourcePos = GetEntityCoords(PlayerPedId())
				for id, scanner in pairs(scannerDrops) do
					if #(sourcePos - vec3(scannerDrops[id].coords.x, scannerDrops[id].coords.y, scannerDrops[id].coords.z)) < 20 then
						TriggerServerEvent('SonoranRadio::RemoveDrop::Scanner', scannerDrops[id])
					end
				end
			end
		end
		::continue::
	end)

	RegisterNUICallback('scanners', function(data, cb)
		if data.type == 'setChatterConfig' then
			DebugPrint(('[Scanner] Chatter config callback profiles=%s defaultProfileId=%s'):format(
				tostring(data.config and data.config.profiles and #data.config.profiles or 0),
				tostring(data.config and data.config.defaultProfileId)
			))
			sDefaultProfileId = data.config.defaultProfileId or data.config.profiles[1].id
		end

		if data.type == 'setScanner' then
			if not scanners[data.id] then scanners[data.id] = {} end
			scanners[data.id].powered = data.state.powered
			scanners[data.id].channelId = data.state.channelId
		end

		if data.type == 'saveScanner' then
			pushScanner(data.id)
		end

		if data.type == 'requestProfilePerms' then
			DebugPrint(('[Scanner] Requesting ACE permissions profiles=%s'):format(
				tostring(data.profiles and #data.profiles or 0)
			))
			TriggerServerEvent('SonoranRadio::checkScannerProfilePerms', data.profiles)
		end

		cb('OK')
	end)
	RegisterNetEvent('SonoranRadio::allowScannerProfiles', function(allowedProfileIds)
		DebugPrint(('[Scanner] ACE response allowedProfileIds=%s'):format(json.encode(allowedProfileIds or {})))
		SendNUIMessage({ type = 'allowScannerProfiles', profileIds = allowedProfileIds })
	end)
end
