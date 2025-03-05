function initScanners()
	if Config.chatter == false then return end
	local inMenu = false
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
	local function advScanner(id, n)
		local scanner = scanners[id]
		local curIndex = -n + 1
		for i = 1, #sProfiles do
			if sProfiles[i].id == scanner.channelId then
				curIndex = i
			end
		end

		local nextIndex = (curIndex + n - 1) % #sProfiles + 1
		scanner.channelId = sProfiles[nextIndex].id

		BeginTextCommandThefeedPost('STRING')
		AddTextComponentSubstringPlayerName('Channel: ~b~' .. sProfiles[nextIndex].displayName)
		EndTextCommandThefeedPostTicker(false, false)
	end
	local function pushScanner(id)
		if id ~= 0 then
			TriggerServerEvent('SonoranRadio::pushScanner', id, scanners[id])
		end
	end
	RegisterNetEvent('SonoranRadio::receiveScanners', function(s)
		local localScanner = scanners[0]
		scanners = s
		scanners[0] = localScanner
	end)

	RegisterNetEvent('menu:close', function(menu)
		if menu.id == 'scannerControls' then
			inMenu = false
		end
	end)
	-- SCANNER MENUS
	WarMenu.CreateMenu('scannerControls', 'Scanner Controls', 'Sonoran Software')
	WarMenu.SetTitleColor('scannerControls', 0, 0, 0, 255)
	WarMenu.SetMenuTitleBackgroundSprite('scannerControls', 'radio_menu_header', 'option_1')
	function openScanner(scannerId, startCoords)
		if not allowed then return end
		if WarMenu.IsMenuOpened('scannerControls') then return end
		Citizen.CreateThread(function()
			WarMenu.OpenMenu('scannerControls')
			inMenu = true
			while WarMenu.IsMenuOpened('scannerControls') do
				local isPowered = isScannerPowered(scannerId)

				if WarMenu.Button(isPowered and 'Power Off' or 'Power On') then
					powerScanner(scannerId, not isPowered)
				end
				if isPowered then
					if WarMenu.Button('Next Channel') then
						advScanner(scannerId, 1)
					end
					if WarMenu.Button('Previous Channel') then
						advScanner(scannerId, -1)
					end
				end

				if startCoords == nil and inventoryScannerId ~= scannerId then
					WarMenu.CloseMenu()
				elseif startCoords ~= nil and #(GetEntityCoords(PlayerPedId()) - startCoords) > 5.0 then
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
			openScanner(inventoryScannerId)
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
	Citizen.CreateThread(function()
		AddTextEntry('SONRAD_SCANNER_USE', 'Press ~INPUT_CONTEXT~ to use the scanner')

		while true do
			local myPos = GetEntityCoords(PlayerPedId())
			local nearDropId = nil
			local nearDropDist = 5.0
			for dropId, drop in pairs(scannerDrops) do
				local coords = vec3(drop.coords.x, drop.coords.y, drop.coords.z)
				local dist = #(coords - myPos)
				if dist < nearDropDist then
					nearDropId = dropId
					nearDropDist = dist
				end
			end

			if allowed and nearDropId and not WarMenu.IsAnyMenuOpened() then
				BeginTextCommandDisplayHelp('SONRAD_SCANNER_USE')
				EndTextCommandDisplayHelp(0, false, true, 100)

				if IsControlJustReleased(0, 38) then
					openScanner(nearDropId, myPos)
				end

				Citizen.Wait(0)
			else
				Citizen.Wait(500)
			end
		end
	end)

	-- SCANNER CHATTER API
	function getScannerChatterSources()
		local sources = {}

		for id, scanner in pairs(scanners) do
			if scanner.powered then
				local sourcePos
				if id == inventoryScannerId then -- local scanner
					sourcePos = GetEntityCoords(PlayerPedId())
				elseif scannerDrops[id] then -- dropped scanner
					sourcePos = vec3(scannerDrops[id].coords.x, scannerDrops[id].coords.y, scannerDrops[id].coords.z)
				end

				local myPos = GetFinalRenderedCamCoord()
				if sourcePos and #(sourcePos - myPos) < 15.0 then
					table.insert(sources, {
						sourceEntity = id == inventoryScannerId and PlayerPedId() or nil,
						pos = sourcePos,
						scanList = {scanner.channelId},
					})
				end
			end
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