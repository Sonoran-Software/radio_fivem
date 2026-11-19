local resourceName = GetCurrentResourceName()
local cacheFile = 'sonoranradio-settings.json'
local maxBytes = 96 * 1024
local schemaVersion = 1
local defaultApiUrl = 'https://api.sonoranradio.com/'
local source = assert(LoadResourceFile(resourceName, 'lua/config/defaults.lua'))
local defaults = assert(load(source, '@lua/config/defaults.lua', 't', {}))()

local migrating = false
local startupFinished = false
local managedSettingsActive = false

-- Match the published shape for downloads and backups. During an import, copy
-- only documented fields and let the API fill missing values from its defaults.
local function matchShape(value, model, complete)
	if type(model) == 'function' then return model(value, complete) end
	if type(value) ~= type(model) then return nil, false end
	if type(value) == 'number' then return value, value == value and math.abs(value) ~= math.huge end
	if type(value) ~= 'table' then return value, true end

	local result = {}
	for key, field in pairs(model) do
		if complete or value[key] ~= nil then
			local entry, valid = matchShape(value[key], field, complete)
			if not valid then return nil, false end
			result[key] = entry
		end
	end
	if complete then
		for key in pairs(value) do
			if model[key] == nil then return nil, false end
		end
	end
	return result, true
end

local function collection(model, list, limit)
	return function(value, complete)
		if type(value) ~= 'table' then return nil, false end
		local result = {}
		local count = 0
		for key, item in pairs(value) do
			count = count + 1
			if count > limit then return nil, false end
			if list then
				if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then return nil, false end
			elseif type(key) ~= 'string' or key == '' then
				return nil, false
			end
			local entry, valid = matchShape(item, model, complete)
			if not valid then return nil, false end
			result[key] = entry
		end
		if list then
			for index = 1, count do
				if result[index] == nil then return nil, false end
			end
		end
		return result, true
	end
end

local function optionalText(value)
	if value == nil or value == json.null then return nil, true end
	return value, type(value) == 'string'
end

local function choices(values)
	return function(value) return value, values[value] == true end
end

local shape = matchShape(defaults, defaults, true)
local grades = collection(0, true, 64)
local jobs = collection({ grades = grades }, false, 32)
shape.defaultSkinId = optionalText
shape.frames.permissionMode = choices({ ace = true, qbcore = true, qbox = true, esx = true, none = true })
shape.frames.departments = collection({
	label = '',
	permissions = { jobs = jobs, ace = collection('', true, 64) },
	allowedFrames = collection('', true, 64),
}, false, 32)
shape.radioJammers.permissionMode = choices({ ace = true, qbcore = true, esx = true, none = true })
shape.radioJammers.allowedJobs = collection(function(value, complete)
	-- Existing jammer configurations also accept a flat job grade list.
	if not complete and type(value) == 'table' and value[1] ~= nil and value.grades == nil then
		value = { grades = value }
	end
	return matchShape(value, { grades = grades }, complete)
end, false, 32)
local jammerShape = shape.radioJammers.jammers[1]
jammerShape.type = choices({ handheld = true, static = true })
jammerShape.offModel = optionalText
jammerShape.itemName = optionalText
jammerShape.poweredItemName = optionalText
shape.radioJammers.jammers = collection(jammerShape, true, 64)

local function usesManagedSettingsByDefault()
	if type(Config) ~= 'table' then return false end
	if Config.managedSettings ~= nil then return Config.managedSettings == true end
	-- Inspect the original file before filling defaults. Existing gameplay settings
	-- stay active until the operator explicitly migrates them.
	for key in pairs(shape) do
		local value = Config[key]
		if value ~= nil then
			if key ~= 'notifications' or type(value) ~= 'table' then return false end
			-- A local callback can coexist with portal-controlled notification settings.
			for option in pairs(shape.notifications) do
				if value[option] ~= nil then return false end
			end
		end
	end
	return true
end

local managedByDefault = usesManagedSettingsByDefault()
if type(Config) == 'table' then
	if Config.apiUrl == nil then Config.apiUrl = defaultApiUrl end
	if Config.radioUrl == nil then Config.radioUrl = 'https://sonoranradio.com' end
	if Config.debug == nil then Config.debug = false end
	if managedByDefault and Config.allowAutoUpdate == nil then Config.allowAutoUpdate = true end
	for key, value in pairs(defaults) do
		if Config[key] == nil and (managedByDefault or key == 'radioJammers') then
			Config[key] = value
		end
	end
	if Config.heavySignalDegradeInWater == nil then Config.heavySignalDegradeInWater = true end
end

local function collectSettings()
	local incoming = {}
	for key in pairs(shape) do incoming[key] = Config[key] end
	for _, key in ipairs({ 'heavySignalDegradeInWater', 'radioJammers' }) do
		if type(incoming[key]) == 'boolean' then
			incoming[key] = { enabled = incoming[key] }
		end
	end
	return matchShape(incoming, shape, false)
end

local function decodeJson(raw)
	if type(raw) ~= 'string' or #raw > maxBytes then return nil end
	local ok, value = pcall(json.decode, raw)
	if ok and type(value) == 'table' then return value end
end

local function encodeJson(value)
	local ok, encoded = pcall(json.encode, value)
	if ok and type(encoded) == 'string' and #encoded <= maxBytes then return encoded end
end

local function readSettings(value)
	if type(value) ~= 'table' or value.schemaVersion ~= schemaVersion or
		type(value.settings) ~= 'table' or type(value.configured) ~= 'boolean' or
		type(value.revision) ~= 'number' or value.revision < 0 or
		value.revision % 1 ~= 0 then return nil end

	local settings, valid = matchShape(value.settings, shape, true)
	if not valid then return nil end
	return {
		schemaVersion = schemaVersion,
		configured = value.configured,
		revision = value.revision,
		settings = settings,
	}
end

local function applySettings(settings)
	local notificationHook = type(Config.notifications) == 'table' and Config.notifications.custom
	for key in pairs(shape) do Config[key] = settings[key] end
	if type(Config.defaultSkinId) ~= 'string' then Config.defaultSkinId = nil end
	if type(notificationHook) == 'function' then
		Config.notifications.custom = notificationHook
	elseif Config.notifications.type == 'custom' then
		Config.notifications.type = 'auto'
		print('[SonoranRadio] Custom notifications require a local Lua callback; using automatic notifications.')
	end
end

local function getScope()
	local serverId = Config and Config.comId
	if type(serverId) == 'number' and math.tointeger(serverId) and serverId > 0 then serverId = tostring(serverId) end
	local roomId = Config and math.tointeger(tonumber(Config.serverId) or 0)
	local apiOrigin = Config and tostring(Config.apiUrl or defaultApiUrl):gsub('/+$', '')
	if type(serverId) ~= 'string' or not serverId:match('^[%w_-]+$') or #serverId > 128 or
		not roomId or roomId < 1 or roomId > 2147483647 or
		(not apiOrigin:match('^https://[%w.%-]+$') and not apiOrigin:match('^https://[%w.%-]+:%d+$')) or
		type(Config.apiKey) ~= 'string' or Config.apiKey == '' or Config.apiKey == 'YOUR API KEY' or
		Config.apiKey:find('[\r\n]') then
		return nil
	end
	return {
		community = serverId:upper(),
		roomId = roomId,
		origin = apiOrigin:lower(),
	}
end

local function scopeKey(scope)
	return ('managed_config:%s:%s:%d'):format(scope.origin, scope.community, scope.roomId)
end

local function request(scope, method, managed, body)
	local completed = false
	local result = promise.new()
	local function finish(status, raw)
		if completed then return end
		completed = true
		result:resolve({ status = tonumber(status) or 0, document = decodeJson(raw) })
	end
	local url = ('%s/v2/servers/%s/rooms/%d/fivem-settings'):format(scope.origin, scope.community, scope.roomId)
	if method == 'POST' then url = url .. '/migrate' end
	local headers = { Authorization = 'Bearer ' .. Config.apiKey, Accept = 'application/json' }
	if method == 'GET' then headers['X-FiveM-Settings-Mode'] = managed and 'managed' or 'legacy' end
	if body then headers['Content-Type'] = 'application/json' end
	local version = GetResourceMetadata(resourceName, 'version', 0)
	if version then headers['X-FiveM-Resource-Version'] = version end
	Citizen.SetTimeout(8000, function() finish(0) end)
	local sent = pcall(PerformHttpRequest, url, finish, method, body or '', headers, { followLocation = false })
	if not sent then finish(0) end
	return Citizen.Await(result)
end

local function readCache(scope)
	local cached = decodeJson(LoadResourceFile(resourceName, cacheFile))
	if not cached or type(cached.scope) ~= 'table' then return nil end
	if cached.scope.community ~= scope.community or cached.scope.roomId ~= scope.roomId or
		cached.scope.origin ~= scope.origin then return nil end
	return readSettings(cached.document)
end

local function writeCache(scope, document)
	local encoded = encodeJson({ scope = scope, document = document })
	if not encoded then return false end
	local ok, saved = pcall(function()
		return exports[resourceName]:SaveManagedRadioSettings(encoded)
	end)
	return ok and saved == true
end

local function markManaged(scope)
	SetResourceKvp(scopeKey(scope), '1')
end

local function isManaged(scope)
	return managedByDefault or GetResourceKvpString(scopeKey(scope)) == '1'
end

-- Resolve startup settings after the Radio server ID is established and before
-- the resource publishes settings or registers configuration-dependent features.
function InitializeManagedRadioSettings()
	local scope = getScope()
	if not scope then
		if managedByDefault then
			print('[SonoranRadio] Managed settings require valid credentials, a Radio server ID, and an HTTPS API origin.')
			return false
		end
		startupFinished = true
		return true
	end

	local cached = readCache(scope)
	local managed = cached ~= nil or isManaged(scope)
	local response = request(scope, 'GET', managed)
	local document = response.status == 200 and readSettings(response.document)

	if document and managed then
		if not writeCache(scope, document) then
			print('[SonoranRadio] Loaded portal settings. The server could not update the local settings backup.')
		end
		markManaged(scope)
		applySettings(document.settings)
		managedSettingsActive = true
	elseif document and not managed then
		warnLog('WRN_SETTINGS_MIGRATION_AVAILABLE')
	elseif cached and (response.status == 0 or response.status == 200 or response.status == 429 or response.status >= 500) then
		applySettings(cached.settings)
		managedSettingsActive = true
		print('[SonoranRadio] The settings service is unavailable. Using the last verified local settings.')
	elseif managed then
		print(('[SonoranRadio] Managed settings could not be loaded (HTTP %d). Check the community and server settings, then restart.'):format(response.status))
		return false
	else
		print('[SonoranRadio] The settings service could not be verified. Continuing with the existing local configuration.')
	end

	startupFinished = true
	return true
end

function GetManagedRadioPlacementScope()
	if managedSettingsActive then return getScope() end
end

local function equalData(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= 'table' then return a == b end
	for key, val in pairs(a) do
		if not equalData(val, b[key]) then return false end
	end
	for key in pairs(b) do
		if a[key] == nil then return false end
	end
	return true
end

function MigrateRadioSettings()
	if migrating then return end
	local scope = getScope()
	if not startupFinished or not scope then
		print('[SonoranRadio] Finish starting the configured Radio server before migrating settings.')
		return
	end

	migrating = true
	Citizen.CreateThread(function()
		local ok, err = pcall(function()
			local managed = isManaged(scope)
			local current = request(scope, 'GET', managed)
			local before = current.status == 200 and readSettings(current.document)
			if not before then return 'Could not verify the portal configuration. Try again after checking your connection.' end
			if managed and not before.configured then
				return 'This installation already uses portal defaults. There is no legacy configuration to import.'
			end
			local document = before
			if not before.configured then
				local settings, valid = collectSettings()
				if not valid then return 'A legacy setting has an invalid format. Check your local configuration and try again.' end
				local encoded = encodeJson({ settings = settings })
				if not encoded then return 'The legacy settings could not be serialized within the size limit.' end
				local saved = request(scope, 'POST', managed, encoded)
				local posted = saved.status == 200 and readSettings(saved.document)
				if not posted or not posted.configured then
					return ('The portal did not accept the migration (HTTP %d). The local files were preserved.'):format(saved.status)
				end
				local verified = request(scope, 'GET', managed)
				document = verified.status == 200 and readSettings(verified.document)
				if not document or not document.configured or document.revision ~= posted.revision or
					not equalData(document.settings, posted.settings) then
					return 'The upload could not be verified. Retry the command before restarting.'
				end
			end

			if not writeCache(scope, document) then
				return 'The portal settings are available, but the local backup could not be written. Fix the resource folder permissions and run the command again.'
			end
			markManaged(scope)
			if before.configured then
				return 'Settings already exist in the portal. No upload was sent. The verified settings were saved locally; restart sonoranradio to apply them.'
			end
			return 'Settings migrated and backed up. Manage them in Radio Admin and restart sonoranradio to apply them. Your original local configuration was preserved.'
		end)
		migrating = false
		-- Details can contain server-supplied or local values; never print raw errors.
		print('[SonoranRadio] ' .. (ok and err or 'Configuration migration failed. The original configuration was preserved.'))
	end)
end
