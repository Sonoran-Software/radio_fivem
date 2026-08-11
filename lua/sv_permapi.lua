-- syncs radio user permissions to the server through the API

local displayNameSyncCache = {}

local function trimString(value)
	if type(value) ~= 'string' then
		return nil
	end
	value = value:gsub('^%s+', ''):gsub('%s+$', '')
	if value == '' then
		return nil
	end
	return value
end

local function nameFromCharInfo(charinfo)
	if type(charinfo) ~= 'table' then
		return nil
	end

	local first = trimString(charinfo.firstname or charinfo.firstName)
	local last = trimString(charinfo.lastname or charinfo.lastName)
	if first and last then
		return first .. ' ' .. last
	end
	return first or last or trimString(charinfo.name)
end

local function resolveConfiguredDisplayName(configKey, src)
	if type(Config[configKey]) ~= 'function' then
		return nil
	end

	local ok, name = pcall(Config[configKey], src)
	if not ok then
		print(('sonoranradio: %s failed'):format(configKey), name)
		return nil
	end
	return trimString(name)
end

local function resolveFrameworkDisplayName(src)
	if GetResourceState('qbx_core') == 'started' then
		local ok, player = pcall(function()
			return exports.qbx_core:GetPlayer(src)
		end)
		if ok and player then
			local playerData = player.PlayerData or player
			local name = nameFromCharInfo(playerData and playerData.charinfo)
			if name then return name end
		end
	end

	if GetResourceState('qb-core') == 'started' then
		local ok, player = pcall(function()
			local qb = exports['qb-core']:GetCoreObject()
			return qb and qb.Functions and qb.Functions.GetPlayer(src)
		end)
		if ok and player then
			local playerData = player.PlayerData or player
			local name = nameFromCharInfo(playerData and playerData.charinfo)
			if name then return name end
		end
	end

	if GetResourceState('es_extended') == 'started' then
		local ok, player = pcall(function()
			local esx = exports['es_extended']:getSharedObject()
			return esx and esx.GetPlayerFromId(src)
		end)
		if ok and player then
			local name
			if type(player.getName) == 'function' then
				local nameOk, result = pcall(player.getName, player)
				if nameOk then name = trimString(result) end
			end
			if not name and type(player.get) == 'function' then
				local firstOk, first = pcall(player.get, player, 'firstName')
				local lastOk, last = pcall(player.get, player, 'lastName')
				if not firstOk then first = nil end
				if not lastOk then last = nil end
				name = nameFromCharInfo({ firstName = first, lastName = last })
			end
			if name then return name end
		end
	end

	return nil
end

local function resolvePlayerDisplayName(src)
	return resolveConfiguredDisplayName('getRadioDisplayName', src)
		or resolveConfiguredDisplayName('getGuestDisplayName', src)
		or resolveFrameworkDisplayName(src)
		or trimString(GetPlayerName(src))
end


local function createGuestToken(opts)
	if not opts then opts = {} end
	local payload = {
		serverId = Config.comId,
		roomId = Config.serverId,
		expiresInSeconds = opts.expiresInSeconds,
		lockedCh = opts.emergCall and 'emergcall' or nil,
		permission = opts.permission,
		profilePerms = opts.profilePerms,
	}
	local res = getSonoranRadioClient():createGuestTokenV2(payload)
	if not res.success then
		print('failed to create guest token', formatSonoranApiReason(res.reason))
		return nil
	end
	return res.data
end

local function authorizeRadioUser(accId)
	local res = getSonoranRadioClient():approveMembersV2({accId}, Config.comId)
	if not res.success then
		print('failed to authorize radio users', formatSonoranApiReason(res.reason))
	end
	return res.success
end

local function setRadioUserPerms(accId, perm, profilePerms)
	local res = getSonoranRadioClient():setMemberPermissionsV2({{
		accId = accId,
		perm = perm,
		profilePerms = profilePerms or {},
	}}, Config.comId)
	if not res.success then
		print('failed to set radio user perms', formatSonoranApiReason(res.reason))
	end
	return res.success
end

local function calculateRadioPerm(src)
	local acePermMap = {
		-- bit permission map
		['sonoranradio.admin'] = 1,
		['sonoranradio.communitykick'] = 2,
		['sonoranradio.communityban'] = 4,
		['sonoranradio.radiomove'] = 8,
		['sonoranradio.radiokick'] = 16,
		['sonoranradio.communityapprove'] = 32,
		['sonoranradio.setmynickname'] = 64,
		['sonoranradio.setnickname'] = 128,
		['sonoranradio.radiotones'] = 256,
		['sonoranradio.radiotalkover'] = 512,
	}

	local perm = 0
	for ace, permBit in pairs(acePermMap) do
		if IsPlayerAceAllowed(src, ace) then
			perm = perm | permBit
		end
	end
	return perm
end

local function resolveGuestDisplayName(src)
	return resolveConfiguredDisplayName('getGuestDisplayName', src)
end
local function calculateRadioProfilePerms(source, profileInfos)
	local perms = {}
	for _, profile in ipairs(profileInfos) do
		if profile.id ~= nil and profile.visibility ~= 'public' then
			local allowed = IsPlayerAceAllowed(source, 'sonoranradio.channel.'..profile.id)
			if not allowed and profile.displayName then
				allowed = IsPlayerAceAllowed(source, 'sonoranradio.channel.'..profile.displayName)
			end

			table.insert(perms, {profileId = profile.id, canJoin = allowed})
		end
	end
	return perms
end

local function getRadioProfileInfos()
	local res = getSonoranRadioClient():getCommunityChannelsV2(Config.comId)
	if not res.success then
		print('failed to get radio channel permissions', formatSonoranApiReason(res.reason))
		return {}
	end

	local channels = {}
	if type(res.data) == 'table' then
		channels = res.data.channels or res.data.profiles or {}
	end

	local profileInfos = {}
	for _, profile in ipairs(channels) do
		table.insert(profileInfos, {
			id = profile.id,
			displayName = profile.displayName,
			visibility = profile.visibility,
		})
	end
	return profileInfos
end

-- called from the client after their radio initializes
-- this will sync their permissions to the radio backend (based on their ace permissions)
RegisterNetEvent('SonoranRadio::SyncAcePerms', function(accId, profiles, authorize)
	local src = source
	if src == nil then return end -- don't allow from server
	if not Config.acePermSync then return end -- feature disabled
	if Config.acePermsForRadio and not IsPlayerAceAllowed(src, 'sonoranradio.use') then return end -- access denied

	if authorize then
		if IsPlayerAceAllowed(src, 'sonoranradio.autoapprove') then
			authorizeRadioUser(accId)
			TriggerClientEvent('SonoranRadio::RefreshScreen', src)
		end
	else
		accId = trimString(accId)
		if not accId then return end

		local perm = calculateRadioPerm(src)
		local profilePerms = calculateRadioProfilePerms(src, profiles or {})
		setRadioUserPerms(accId, perm, profilePerms)
	end
end)

RegisterNetEvent('SonoranRadio::SyncPlayerDisplayName', function(accId)
	local src = source
	if src == nil then return end
	if Config.syncPlayerNameToRadio ~= true then return end
	if Config.acePermsForRadio and not IsPlayerAceAllowed(src, 'sonoranradio.use') then return end

	accId = trimString(accId)
	if not accId then return end

	local displayName = resolvePlayerDisplayName(src)
	if not displayName then return end

	local cacheKey = tostring(accId) .. ':' .. displayName
	if displayNameSyncCache[src] == cacheKey then
		return
	end

	performApiRequest({
		accId = accId,
		displayName = displayName,
	}, 'SET-USER-DISPLAY-NAME', function(data, success)
		if success then
			displayNameSyncCache[src] = cacheKey
			return
		end
		if type(data) == 'string' and data:lower():find('not found') then
			debugLog('Failed to sync display name, user not found.')
			return
		end
		errorLog('ERR_SERVER_NAME_SET_FAILED', 'Failed to sync player name to radio display name. Please check your configuration.')
	end)
end)

AddEventHandler('playerDropped', function()
	displayNameSyncCache[source] = nil
end)

-- called from the client when starting a 911 call
-- creates a guest token and sends it back to the client
RegisterNetEvent('SonoranRadio::CreateEmergencyCallToken', function()
	local src = source
	if src == nil then return end

	local payload = createGuestToken({emergCall = true})
	if payload ~= nil then
		TriggerClientEvent('SonoranRadio::EmergencyCallToken', src, payload.guestToken)
	end
end)
-- called from the client after clicking "log in as guest"
-- creates a guest token and sends it back to the client
RegisterNetEvent('SonoranRadio::CreateGuestToken', function()
	local src = source
	if src == nil then return end
	if Config.acePermsForRadioGuests and not IsPlayerAceAllowed(src, 'sonoranradio.guest') then
		return
	end

	local permission = 0
	local profilePerms = {}
	if Config.acePermSync then
		permission = calculateRadioPerm(src)
		profilePerms = calculateRadioProfilePerms(src, getRadioProfileInfos())
	end

	local payload = createGuestToken({
		permission = permission,
		profilePerms = profilePerms,
		expiresInSeconds = 24 * 60 * 60, -- one day
	})
	if payload ~= nil then
		local displayName = resolveGuestDisplayName(src)
		TriggerClientEvent('SonoranRadio::RadioGuestToken', src, payload.guestToken, displayName)
	end
end)
