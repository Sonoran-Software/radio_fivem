function initScanners()
	if Config.chatter == false then return end

	-- SCANNER PERMS
	local allowed = false
	RegisterNetEvent('SonoranRadio::AuthorizeScanners', function()
		allowed = true
	end)

	-- SCANNER PROFILES
	local allProfiles = {}
	local sProfiles = {}
	local sDefaultProfileId = nil
	local function orderProfiles(profiles)
		local function orderIndexSafe(profile)
			if type(profile.orderIndex) ~= 'number' then
				return math.huge
			else
				return profile.orderIndex
			end
		end
		table.sort(profiles, function(a, b)
			return orderIndexSafe(a) < orderIndexSafe(b)
		end)
		return profiles
	end
	function setScannerProfiles(profiles, defaultProfileId)
		if not profiles then error('set nil config?') end
		-- copy profiles to allProfiles
		-- NOTE: assignment is NOT good enough because we modify the table below
		allProfiles = {}
		for i, prof in ipairs(profiles) do
			allProfiles[i] = prof
		end

		-- remove hidden profiles, which are then queried to see if they are allowed to access them
		local hiddenProfiles = {}
		for i = #profiles, 1, -1 do
			local prof = profiles[i]
			if prof.visibility ~= 'public' then
				table.insert(hiddenProfiles, {id = prof.id, displayName = prof.displayName})
				table.remove(profiles, i)
			end
		end
		if #hiddenProfiles > 0 then
			TriggerServerEvent('SonoranRadio::checkProfilePerms', hiddenProfiles)
		end

		sProfiles = orderProfiles(profiles)
		if defaultProfileId == nil and sProfiles[1] then
			defaultProfileId = sProfiles[1].id
		end
		sDefaultProfileId = defaultProfileId
	end
	RegisterNetEvent('SonoranRadio::allowScannerProfiles', function(profileIds)
		for _, profId in ipairs(profileIds) do
			-- find the profile in allProfiles
			local profile
			for _, prof in ipairs(allProfiles) do
				if prof.id == profId then
					profile = prof
					break
				end
			end

			-- look for the profile in sProfiles
			local sProfIndex
			for i, prof in ipairs(sProfiles) do
				if prof.id == profId then
					sProfIndex = i
					break
				end
			end

			-- add back hidden profile that we allowed
			-- (if it's not already in sProfiles)
			if profile and sProfIndex == nil then
				table.insert(sProfiles, profile)
			end
		end

		sProfiles = orderProfiles(sProfiles)
	end)

	-- STATIC SCANNER LOGIC
	local staticScanners = {}
	Citizen.CreateThread(function()
		local OBJ_RANGE = 100.0
		local OBJ_MODEL = `prop_cs_hand_radio`
		local ssObjects = {}

		while true do
			local myPos = GetEntityCoords(PlayerPedId())
			for _, ss in ipairs(staticScanners) do
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
			Citizen.Wait(500)
		end
	end)
	
	-- SCANNER MENU LOGIC
	local scanners = {}
	local inventoryScannerId = 0
	local function isScannerPowered(id)
		return not not scanners[id] and scanners[id].powered
	end
	local function powerScanner(id, powered)
		if not scanners[id] then
			scanners[id] = {}
		end
		scanners[id].powered = powered
		scanners[id].channelId = sDefaultProfileId
	end
	local function setScannerChannel(id, idx)
		local scanner = scanners[id]
		scanner.channelId = sProfiles[idx].id

		BeginTextCommandThefeedPost('STRING')
		AddTextComponentSubstringPlayerName('Channel: ~b~' .. sProfiles[idx].displayName)
		EndTextCommandThefeedPostTicker(false, false)
	end
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
	WarMenu.CreateMenu('scannerControls', 'Scanner Controls', 'Sonoran Software')
	WarMenu.SetTitleColor('scannerControls', 0, 0, 0, 255)
	WarMenu.SetMenuTitleBackgroundSprite('scannerControls', 'radio_menu_header', 'option_1')
	local function openScannerMenu(scannerId, scannerCoords)
		if not allowed then return end
		if WarMenu.IsMenuOpened('scannerControls') then return end
		WarMenu.OpenMenu('scannerControls')

		local curChId = (scanners[scannerId] and scanners[scannerId].channelId) or sDefaultProfileId
		local chIdx = 1
		local chNames = {}
		for i = 1, #sProfiles do
			chNames[i] = sProfiles[i].displayName
			if sProfiles[i].id == curChId then
				chIdx = i
			end
		end

		Citizen.CreateThreadNow(function()
			while WarMenu.IsMenuOpened('scannerControls') do
				local isPowered = isScannerPowered(scannerId)

				if WarMenu.Button(isPowered and 'Power Off' or 'Power On') then
					powerScanner(scannerId, not isPowered)
				end
				if isPowered then
					local selected, newIdx = WarMenu.ComboBox('Select Channel', chNames, chIdx)
					chIdx = newIdx

					if selected then
						setScannerChannel(scannerId, chIdx)
					end
				end

				if scannerCoords == nil and inventoryScannerId ~= scannerId then
					WarMenu.CloseMenu()
				elseif scannerCoords ~= nil and #(GetEntityCoords(PlayerPedId()) - scannerCoords) > 5.0 then
					WarMenu.CloseMenu()
				end

				WarMenu.Display()
				Citizen.Wait(0)
			end
			pushScanner(scannerId)
		end)
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

		while #sProfiles == 0 do
			Citizen.Wait(250) -- wait for profiles to load
		end
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
	function getScannerChatterSources()
		local sources = {}
		for id, scanner, coords in poweredScanners() do
			table.insert(sources, {
				sourceEntity = coords == nil and PlayerPedId() or nil, -- coords == nil when the scanner is on the player
				pos = coords,
				scanList = {scanner.channelId or sDefaultProfileId},
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
end