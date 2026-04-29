-- syncs radio user permissions to the server through the API

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
	if type(Config.getGuestDisplayName) ~= 'function' then
		return nil
	end
	local ok, name = pcall(Config.getGuestDisplayName, src)
	if not ok then
		print('sonoranradio: getGuestDisplayName failed', name)
		return nil
	end
	if type(name) ~= 'string' then
		return nil
	end
	if name == '' then
		return nil
	end
	return name
end
local function calculateRadioProfilePerms(source, profileInfos)
	local perms = {}
	for _, profile in ipairs(profileInfos) do
		if profile.visibility ~= 'public' then
			local allowed = IsPlayerAceAllowed(source, 'sonoranradio.channel.'..profile.id)
			if not allowed and profile.displayName then
				allowed = IsPlayerAceAllowed(source, 'sonoranradio.channel.'..profile.displayName)
			end

			table.insert(perms, {profileId = profile.id, canJoin = allowed})
		end
	end
	return perms
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
		local perm = calculateRadioPerm(src)
		local profilePerms = calculateRadioProfilePerms(src, profiles or {})
		setRadioUserPerms(accId, perm, profilePerms)
	end
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

	local payload = createGuestToken({
		permission = calculateRadioPerm(src),
		expiresInSeconds = 24 * 60 * 60, -- one day
	})
	if payload ~= nil then
		local displayName = resolveGuestDisplayName(src)
		TriggerClientEvent('SonoranRadio::RadioGuestToken', src, payload.guestToken, displayName)
	end
end)
