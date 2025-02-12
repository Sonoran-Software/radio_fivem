-- syncs radio user permissions to the server through the API

local function httpRequest(method, url, data, headers)
	local d = promise.new()
	exports['sonoranradio']:HandleHttpRequest(url, function(statusCode, res, headers)
		d:resolve({status = statusCode, payload = res, headers = headers})
	end, method, data, headers)
	return d
end

local function authorizeRadioUser(accId)
	local url = Config.apiUrl..'api/servers/'..Config.comId..'/members/emplace'
	local payload = {
		apiKey = Config.apiKey,
		accIds = {accId},
	}
	local res = Citizen.Await(httpRequest('POST', url, json.encode(payload)))
	local err = res.status == nil or res.status >= 400
	if err then
		print('failed to authorize radio users', res.status, res.payload)
	end
	return not err
end

local function setRadioUserPerms(accId, perm, profilePerms)
	local url = Config.apiUrl..'api/servers/'..Config.comId..'/members/permissions'
	local payload = {
		apiKey = Config.apiKey,
		userPerms = {{
			accId = accId,
			perm = perm,
			profilePerms = profilePerms or {},
		}}
	}
	local res = Citizen.Await(httpRequest('POST', url, json.encode(payload)))
	local err = res.status == nil or res.status >= 400
	if err then
		print('failed to set radio user perms', res.status, res.payload)
	end
	return not err
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
	if Config.acePermsForRadio and not IsPlayerAceAllowed(src, 'sonoranradio.autoapprove') then return end -- access denied

	if authorize then
		authorizeRadioUser(accId)
		TriggerClientEvent('SonoranRadio::RefreshScreen', src)
	else
		local perm = calculateRadioPerm(src)
		local profilePerms = calculateRadioProfilePerms(src, profiles or {})
		setRadioUserPerms(accId, perm, profilePerms)
	end
end)
