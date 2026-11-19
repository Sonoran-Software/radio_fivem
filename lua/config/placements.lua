local resourceName = GetCurrentResourceName()
local maxBytes = 640 * 1024
local kinds = {
	{ kind = 'towers', file = 'towers.json', defaults = 'towers.DEFAULT.json' },
	{ kind = 'speakers', file = 'speakers.json', defaults = 'speakers.DEFAULT.json' },
	{ kind = 'jammers', file = 'jammers.json', defaults = 'jammers.DEFAULT.json' },
	{ kind = 'scanners', file = 'scanners.json', defaults = 'scanners.DEFAULT.json' },
	{ kind = 'earpieces', file = 'earpieces.json', defaults = 'earpieces.DEFAULT.json' },
	{ kind = 'mobileRepeaters', file = 'mobileRepeaters.json', defaults = 'mobileRepeaters.DEFAULT.json' }
}
local files = {}
for _, entry in ipairs(kinds) do files[entry.file] = entry end

local fields = {
	towers = { 'Id', 'type', 'heading', 'Range', 'Powered', 'Destruction', 'NotPhysical', 'Swankiness',
		'DishStatus', 'serverStatus', 'AntennaStatus' },
	speakers = { 'Id', 'type', 'heading', 'Range', 'Label', 'group' },
	jammers = { 'Id', 'Name', 'Note', 'PropModel', 'OffModel', 'Range', 'Strength', 'Active', 'Type' },
	scanners = { 'Id', 'Note', 'Powered', 'ChannelId', 'PropModel' },
	earpieces = { 'componentId', 'drawableId', 'texture' },
	mobileRepeaters = { 'modelHash', 'label', 'range' }
}
local session
local writing = {}
local loaded = false

local function encode(value)
	local ok, payload = pcall(json.encode, value)
	if ok and type(payload) == 'string' and #payload <= maxBytes then return payload end
end

local function decode(raw)
	if type(raw) ~= 'string' or #raw > maxBytes then return nil end
	local ok, value = pcall(json.decode, raw)
	if ok and type(value) == 'table' then return value end
end

local function arraySize(entries, limit)
	if type(entries) ~= 'table' then return nil end
	local size = 0
	for index in pairs(entries) do
		if type(index) ~= 'number' or index % 1 ~= 0 or index < 1 or index > limit then return nil end
		size = size + 1
	end
	for i = 1, size do if entries[i] == nil then return nil end end
	return size
end

local function projectPosition(position, withOrientation)
	local posType = type(position)
	if posType ~= 'table' and posType ~= 'vector3' and posType ~= 'vector4' then return nil end
	local result = { x = position.x, y = position.y, z = position.z }
	if withOrientation and posType == 'table' then
		result.heading = position.heading
		result.exact = position.exact
	end
	return result
end

local function project(kind, entries)
	local size = arraySize(entries, 512)
	if not size then return nil end
	local result = {}
	for i = 1, size do
		local entry = entries[i]
		if type(entry) ~= 'table' then return nil end
		if (kind ~= 'towers' or not entry.DontSaveMe) and (kind ~= 'jammers' or not entry.Temporary) then
			local projected = {}
			for _, key in ipairs(fields[kind]) do projected[key] = entry[key] end
			if kind ~= 'earpieces' and kind ~= 'mobileRepeaters' then
				projected.PropPosition = projectPosition(entry.PropPosition, kind == 'jammers' or kind == 'scanners')
				if not projected.PropPosition then return nil end
			end
			if kind == 'jammers' then projected.Type = entry.Type or entry.type or 'static' end
			result[#result + 1] = projected
		end
	end
	return result
end

local function finite(value)
	return type(value) == 'number' and value == value and math.abs(value) ~= math.huge
end

local function status(value)
	return value == 'alive' or value == 'dead'
end

local function model(value)
	return (type(value) == 'string' and value:match('^[%w_.:@+-]+$') ~= nil) or
		(finite(value) and value >= -0x80000000 and value <= 0xffffffff and value % 1 == 0)
end

local function allEntries(values, limit, validate)
	local count = arraySize(values, limit)
	if not count then return false end
	for i = 1, count do if not validate(values[i]) then return false end end
	return true
end

local function validStoredEntry(kind, entry)
	if kind == 'earpieces' then
		return finite(entry.componentId) and finite(entry.drawableId) and allEntries(entry.texture, 128, finite)
	elseif kind == 'mobileRepeaters' then
		return finite(entry.modelHash) and entry.modelHash ~= 0 and type(entry.label) == 'string' and finite(entry.range)
	end
	local pos = entry.PropPosition
	if type(entry.Id) ~= 'string' or entry.Id == '' or not finite(pos.x) or not finite(pos.y) or not finite(pos.z) then
		return false
	end
	if kind == 'towers' then
		return finite(entry.heading) and finite(entry.Range) and finite(entry.Swankiness) and
			type(entry.Powered) == 'boolean' and type(entry.Destruction) == 'boolean' and type(entry.NotPhysical) == 'boolean' and
			((entry.type == 'radioTower' and allEntries(entry.DishStatus, 64, status)) or
			(entry.type == 'serverRack' and allEntries(entry.serverStatus, 64, status)) or
			(entry.type == 'cellRepeater' and status(entry.AntennaStatus)))
	elseif kind == 'speakers' then
		return finite(entry.heading) and finite(entry.Range) and type(entry.Label) == 'string' and type(entry.group) == 'string' and
			(entry.type == 'speakerSmallWall' or entry.type == 'speakerMedium' or
			entry.type == 'speakerMediumWall' or entry.type == 'speakerLarge')
	elseif not finite(pos.heading) or type(pos.exact) ~= 'boolean' then
		return false
	elseif kind == 'jammers' then
		return finite(entry.Range) and finite(entry.Strength) and type(entry.Active) == 'boolean' and entry.Type == 'static' and
			model(entry.PropModel) and (entry.OffModel == nil or model(entry.OffModel)) and
			type(entry.Name) == 'string' and type(entry.Note) == 'string'
	end
	return type(entry.Powered) == 'boolean' and type(entry.Note) == 'string' and
		(entry.PropModel == nil or model(entry.PropModel)) and (type(entry.ChannelId) == 'string' or finite(entry.ChannelId))
end

local function readRevision(data, kind)
	if type(data) ~= 'table' or type(data.revision) ~= 'number' or
		data.revision < 0 or data.revision > 9007199254740991 or data.revision % 1 ~= 0 then return nil end
	if data.entries == nil or data.entries == json.null then
		if data.revision == 0 then return { revision = 0 } end
		return nil
	end
	local entries = project(kind, data.entries)
	if not entries or data.revision == 0 then return nil end
	for _, entry in ipairs(entries) do if not validStoredEntry(kind, entry) then return nil end end
	return { revision = data.revision, entries = entries }
end

local function readDocument(data)
	if type(data) ~= 'table' or data.schemaVersion ~= 1 or type(data.placements) ~= 'table' then return nil end
	local placements = {}
	for _, entry in ipairs(kinds) do
		local state = readRevision(data.placements[entry.kind], entry.kind)
		if not state then return nil end
		placements[entry.kind] = state
	end
	return { schemaVersion = 1, placements = placements }
end

RegisterManagedRadioBackupSection('placements', 'sonoranradio-placements.json', readDocument)

local function request(scope, method, suffix, value)
	local body = value and encode(value)
	if value and not body then return { status = 400 } end
	local completed = false
	local result = promise.new()
	local function finish(status, raw)
		if completed then return end
		completed = true
		result:resolve({ status = tonumber(status) or 0, data = decode(raw) })
	end
	local headers = { Authorization = 'Bearer ' .. Config.apiKey, Accept = 'application/json' }
	if body then headers['Content-Type'] = 'application/json' end
	local url = ('%s/v2/servers/%s/rooms/%d/fivem-placements%s'):format(
		scope.origin, scope.community, scope.roomId, suffix)
	Citizen.SetTimeout(8000, function() finish(0) end)
	if not pcall(PerformHttpRequest, url, finish, method, body or '', headers, { followLocation = false }) then
		finish(0)
	end
	return Citizen.Await(result)
end

local function writeCache()
	if not SaveManagedRadioConfigBackup(session.scope, 'placements', session.document) then
		print('[SonoranRadio] The saved placements could not be backed up on disk.')
	end
end

local function readLegacyFile(entry)
	local raw = LoadResourceFile(resourceName, entry.file)
	if raw == nil then raw = LoadResourceFile(resourceName, entry.defaults) end
	return raw
end

local function readLocalImport(entry, defaults)
	local raw = readLegacyFile(entry)
	local value = raw == nil and {} or decode(raw)
	if not value then return nil, false end
	if entry.kind == 'mobileRepeaters' then value = NormalizeRadioMobileRepeaterImport(value) end
	if entry.kind == 'earpieces' then AddLegacyRadioEarpieces(value) end
	if raw == nil and next(value) == nil then
		value = defaults and defaults[entry.kind]
		if not value then return nil, true end
	end
	local projected = project(entry.kind, value)
	return projected, projected ~= nil
end

local function importMissing(scope, document, verify)
	-- Ship one immutable seed for fresh rooms. Real legacy files and saved
	-- collections (including explicit empty lists) take precedence.
	local defaults = not verify and decode(LoadResourceFile(resourceName, 'lua/config/placement-defaults.json'))
	local pending = {}
	for _, entry in ipairs(kinds) do
		if document.placements[entry.kind].entries == nil then
			local entries, valid = readLocalImport(entry, defaults)
			if verify and not valid then return nil end
			pending[entry.kind] = entries
		end
	end
	if next(pending) == nil then return document end
	local function import(payload)
		local response = request(scope, 'POST', '/import', { placements = payload })
		local saved = response.status == 200 and readDocument(response.data)
		if saved then document = saved end
		return not not saved, response.status
	end
	local success, statusCode = import(pending)
	if verify then
		if not success then return nil end
		local response = request(scope, 'GET', '')
		local confirmed = response.status == 200 and readDocument(response.data)
		if not confirmed then return nil end
		for kind in pairs(pending) do
			if confirmed.placements[kind].entries == nil then return nil end
		end
		return confirmed
	end
	if success then return document end
	if statusCode ~= 400 then
		print(('[SonoranRadio] Existing placements could not be imported (HTTP %d). Original files are preserved.'):format(statusCode))
		return document
	end
	-- A malformed legacy file should not block unrelated entries.
	for _, entry in ipairs(kinds) do
		if pending[entry.kind] then
			success, statusCode = import({ [entry.kind] = pending[entry.kind] })
			if not success then
				print(('[SonoranRadio] %s could not be imported (HTTP %d). Its original file is preserved.'):format(
					entry.file, statusCode))
				if statusCode ~= 400 then return document end
			end
		end
	end
	return document
end

function VerifyRadioPlacementMigration(scope)
	if next(writing) then return nil end
	local response = request(scope, 'GET', '')
	local document = response.status == 200 and readDocument(response.data)
	if document then return importMissing(scope, document, true) end
end

function InitializeManagedRadioPlacements()
	local scope = GetManagedRadioPlacementScope()
	if not scope then return end
	local response = request(scope, 'GET', '')
	local document = response.status == 200 and readDocument(response.data)
	if document then
		session = { scope = scope, document = importMissing(scope, document) }
		writeCache()
		return
	end

	local cached = ReadManagedRadioConfigBackup(scope, 'placements')
	if cached and (response.status == 0 or response.status == 200 or response.status == 429 or response.status >= 500) then
		session = { scope = scope, document = cached }
		print('[SonoranRadio] Using the last verified placement backup.')
		return
	end
	session = { scope = scope }
	print('[SonoranRadio] Portal placements are unavailable and there is no verified backup. Placement saves are disabled.')
end

function ActivateMigratedRadioPlacements(scope, document)
	local previous = session and session.document
	session = { scope = scope, document = document }
	local changed = {}
	for _, entry in ipairs(kinds) do
		if not previous or previous.placements[entry.kind].revision ~= document.placements[entry.kind].revision then
			changed[entry.kind] = true
		end
	end
	if next(changed) then ReloadRadioPlacementRuntime(changed) end
end

function GetPortalRadioPlacement(file)
	local entry = files[file]
	local state = entry and session and session.document and session.document.placements[entry.kind]
	if not state or not state.entries then return nil end
	-- Startup and live edits mutate runtime objects independently of the snapshot.
	local payload = encode(state.entries)
	local copy = payload and decode(payload)
	if entry.kind == 'mobileRepeaters' and copy then
		return { version = 1, migratedFromConfig = true, vehicles = copy }
	end
	return copy
end

function LoadRadioPlacements(file)
	local entry = assert(files[file], 'Unknown radio placement collection')
	if session then
		if entry.kind == 'mobileRepeaters' then
			return GetPortalRadioPlacement(file) or { version = 1, migratedFromConfig = true, vehicles = {} }
		end
		return GetPortalRadioPlacement(file) or {}
	end
	local raw = readLegacyFile(entry)
	if not raw then return {}, true end
	local ok, value = pcall(json.decode, raw)
	return ok and type(value) == 'table' and value or {}, true
end

function GetPortalRadioPlacementRevision(file)
	local entry = files[file]
	local state = entry and session and session.document and session.document.placements[entry.kind]
	return state and state.revision
end

function MatchesRadioPlacementRevision(file, expected)
	if not session then return true end
	local current = GetPortalRadioPlacementRevision(file)
	return current ~= nil and expected == current
end

function SavePortalRadioPlacement(file, entries)
	local entry = files[file]
	if not entry or not session then return nil end
	local kind = entry.kind
	if not session.document or writing[kind] or type(entries) ~= 'table' then return false end
	if kind == 'mobileRepeaters' then entries = entries.vehicles end
	local projected = project(kind, entries)
	if not projected then return false end
	local current = session.document.placements[kind]
	writing[kind] = true
	local response = request(session.scope, 'PATCH', '/' .. kind, { revision = current.revision, entries = projected })
	writing[kind] = nil
	local saved = response.status == 200 and readRevision(response.data, kind)
	if not saved or saved.revision ~= current.revision + 1 then
		print(('[SonoranRadio] Could not save %s (HTTP %d). Refresh the placements by restarting if Radio Admin changed them.'):format(file, response.status))
		return false
	end
	session.document.placements[kind] = saved
	writeCache()
	return true
end

function SaveRadioPlacements(file, entries)
	if not CanWriteRadioPlacements() then return false end
	local entry = assert(files[file], 'Unknown radio placement collection')
	if session then return SavePortalRadioPlacement(file, entries) end

	-- Only installations still on their legacy configuration write these files.
	local contents = json.encode(entries, { indent = true })
	local saved = SaveResourceFile(resourceName, entry.file, contents, -1)
	if not saved and LoadResourceFile(resourceName, entry.defaults) then
		warnLog('WRN_CONFIG_SAVE_FALLBACK', ('Could not save updated %s, trying to write changes to %s'):format(entry.file, entry.defaults))
		saved = SaveResourceFile(resourceName, entry.defaults, contents, -1)
	end
	if not saved then
		errorLog('ERR_CONFIG_SAVE_FAILED', ('Could not save updated %s. Changes are not saved'):format(entry.file))
	end
	return saved
end

function CanManageRadioPlacements(src)
	return loaded and type(src) == 'number' and src > 0 and IsPlayerAceAllowed(src, 'command.radioMenu')
end

function MarkRadioPlacementsLoaded()
	loaded = true
end

function AwaitRadioPlacements()
	if not Config or not Config.init then return false end
	local deadline = GetGameTimer() + 45000
	while not loaded and GetGameTimer() < deadline do Wait(100) end
	return loaded
end

function AddLegacyRadioEarpieces(entries)
	if not arraySize(entries, 512) then return false end
	local changed = false
	local legacy = type(Config.chatterExclusions) == 'table' and Config.chatterExclusions or {}
	for _, exclusion in ipairs(legacy) do
		if type(exclusion) == 'table' then
			local exists = false
			for _, entry in ipairs(entries) do
				if type(entry) == 'table' and entry.componentId == exclusion.componentId and entry.drawableId == exclusion.drawableId then
					exists = true
					break
				end
			end
			if not exists then
				entries[#entries + 1] = exclusion
				changed = true
			end
		end
	end
	return changed
end
