function initScanners()
	if Config.chatter == false then return end

	-- SCANNER PERMS
	local allowed = false
	RegisterNetEvent('SonoranRadio::AuthorizeScanners', function()
		allowed = true
	end)

	-- STATIC SCANNER LOGIC
	local staticScanners = {}
	local ssObjects = {}
	Citizen.CreateThread(function()
		local OBJ_RANGE = 100.0
		local OBJ_MODEL = `prop_cs_hand_radio`

		while true do
			local myPos = GetEntityCoords(PlayerPedId())
			local ssIdSet = {}
			for _, ss in ipairs(staticScanners) do
				ssIdSet[ss.Id] = true

				local pos = vec3(ss.PropPosition.x, ss.PropPosition.y, ss.PropPosition.z)
				local dist = #(pos - myPos)

				if dist < OBJ_RANGE and ssObjects[ss.Id] == nil then
					-- we are in range, but the obj is not spawned
					while not HasModelLoaded(OBJ_MODEL) do
						RequestModel(OBJ_MODEL)
						Citizen.Wait(0)
					end
					-- create the object in the world
					local obj = CreateObject(OBJ_MODEL, pos.x, pos.y, pos.z, false, true, false)
					SetEntityHeading(obj, ss.PropPosition.heading)
					SetEntityCollision(obj, false, false)
					if not ss.PropPosition.exact then
						PlaceObjectOnGroundOrObjectProperly(obj)
					end
					SetModelAsNoLongerNeeded(OBJ_MODEL)
					ssObjects[ss.Id] = obj
				elseif dist >= OBJ_RANGE and ssObjects[ss.Id] ~= nil then
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
		for _, ss in ipairs(staticScanners) do
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
			staticScanners = static
		end
	end)

	-- SCANNER MENUS
	local function openScannerMenu(scannerId, scannerCoords)
		if not allowed then return end
		PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
		SendNUIMessage({ type = 'openScanner', id = scannerId, state = scanners[scannerId] })
		SetNuiFocus(true, true)
	end
	function openLocalScanner()
		if inventoryScannerId ~= nil then
			openScannerMenu(inventoryScannerId)
		end
	end

	local scannerDrops = {}
	if frameworkEnum == 1 and inventoryEnum == 1 then
		-- qb-inventory INTEGRATION
		if Config.enforceRadioItem then
			RegisterNetEvent('qb-sonrad:use-scanner', function()
				openLocalScanner()
			end)

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
		end
	elseif inventoryEnum == 2 then
		if Config.enforceRadioItem then
			RegisterNetEvent('qb-sonrad:use-scanner', function()
				openLocalScanner()
			end)
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

			if allowed and scannerId and not WarMenu.IsAnyMenuOpened() then
				BeginTextCommandDisplayHelp('SONRAD_SCANNER_USE')
				EndTextCommandDisplayHelp(0, false, true, 100)

				if IsControlJustReleased(0, 38) then
					openScannerMenu(scannerId, scannerCoords)
				end

				Citizen.Wait(0)
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

		cb('OK')
	end)
end