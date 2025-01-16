function initScanners()
	if Config.chatter == false then return end

	-- SCANNER PERMS
	local allowed = false
	RegisterNetEvent('SonoranRadio::AuthorizeScanners', function()
		allowed = true
	end)

	-- SCANNER PROFILES
	local sProfiles = {}
	local sDefaultProfileId = nil
	function setScannerProfiles(profiles, defaultProfileId)
		local function orderIndexSafe(profile)
			if type(profile.orderIndex) ~= 'number' then
				return math.huge
			else
				return profile.orderIndex
			end
		end

		if not profiles then error('set nil config?') end

		-- remove hidden profiles
		for i = #profiles, 1, -1 do
			if profiles[i].visibility ~= 'public' then
				table.remove(profiles, i)
			end
		end
		-- sort by order index and save
		table.sort(profiles, function(a, b)
			return orderIndexSafe(a) < orderIndexSafe(b)
		end)
		sProfiles = profiles

		if defaultProfileId == nil and sProfiles[1] then
			defaultProfileId = sProfiles[1].id
		end
		sDefaultProfileId = defaultProfileId
	end

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

	-- SCANNER MENUS
	WarMenu.CreateMenu('scannerControls', 'Scanner Controls', 'Sonoran Software')
	WarMenu.SetTitleColor('scannerControls', 0, 0, 0, 255)
	WarMenu.SetMenuTitleBackgroundSprite('scannerControls', 'radio_menu_header', 'option_1')
	function openScanner(scannerId, startCoords)
		if not allowed then return end

		Citizen.CreateThread(function()
			WarMenu.OpenMenu('scannerControls')
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

				local myPos = GetEntityCoords(PlayerPedId())
				if startCoords ~= nil and #(myPos - startCoords) > 5.0 then
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

	-- qb-inventory INTEGRATION
	local scannerDrops = {
		['test'] = {coords = {
			x = 1756.12,
			y = 3263.28,
			z = 41.33
		}}
	}
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

				-- query every 5s
				Citizen.Wait(5000)
			end
		end)

		Citizen.CreateThread(function()
			AddTextEntry('SONRAD_SCANNER_USE', 'Press ~INPUT_CONTEXT~ to use the scanner')

			while true do
				local myPos = GetFinalRenderedCamCoord()
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
						openScanner(nearDropId)
					end

					Citizen.Wait(0)
				else
					Citizen.Wait(500)
				end
			end
		end)
	end

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
end
