local resourceName = GetCurrentResourceName()
local cacheFile = 'sonoranradio-placements.json'
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
for _, entry in ipairs(kinds) do files[entry.file] = entry.kind end

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

local function readCache(scope)
	local cached = decode(LoadResourceFile(resourceName, cacheFile))
	if not cached or type(cached.scope) ~= 'table' or cached.scope.community ~= scope.community or
		cached.scope.roomId ~= scope.roomId or cached.scope.origin ~= scope.origin then return nil end
	return readDocument(cached.document)
end

local function writeCache()
	local payload = encode({ scope = session.scope, document = session.document })
	local success, saved = pcall(function()
		return payload and exports[resourceName]:SaveManagedRadioPlacements(payload)
	end)
	if not success or not saved then
		print('[SonoranRadio] The saved placements could not be backed up on disk.')
	end
end

local function readLocalImport(entry)
	local raw = LoadResourceFile(resourceName, entry.file)
	if raw == nil then raw = LoadResourceFile(resourceName, entry.defaults) end
	local value = raw == nil and {} or decode(raw)
	if not value then return nil end
	if entry.kind == 'mobileRepeaters' then value = NormalizeRadioMobileRepeaterImport(value) end
	if entry.kind == 'earpieces' then AddLegacyRadioEarpieces(value) end
	if raw == nil and next(value) == nil then return nil end
	return project(entry.kind, value)
end

local function importMissing()
	local pending = {}
	for _, entry in ipairs(kinds) do
		if session.document.placements[entry.kind].entries == nil then
			pending[entry.kind] = readLocalImport(entry)
		end
	end
	if next(pending) == nil then return end
	local function import(payload)
		local response = request(session.scope, 'POST', '/import', { placements = payload })
		local document = response.status == 200 and readDocument(response.data)
		if document then session.document = document end
		return not not document, response.status
	end
	local success, statusCode = import(pending)
	if success then return end
	if statusCode ~= 400 then
		print(('[SonoranRadio] Existing placements could not be imported (HTTP %d). Original files are preserved.'):format(statusCode))
		return
	end
	-- A malformed legacy file should not block unrelated entries.
	for _, entry in ipairs(kinds) do
		if pending[entry.kind] then
			success, statusCode = import({ [entry.kind] = pending[entry.kind] })
			if not success then
				print(('[SonoranRadio] %s could not be imported (HTTP %d). Its original file is preserved.'):format(
					entry.file, statusCode))
				if statusCode ~= 400 then return end
			end
		end
	end
end

function InitializeManagedRadioPlacements()
	local scope = GetManagedRadioPlacementScope()
	if not scope then return end
	local response = request(scope, 'GET', '')
	local document = response.status == 200 and readDocument(response.data)
	if document then
		session = { scope = scope, document = document }
		importMissing()
		writeCache()
		return
	end

	local cached = readCache(scope)
	if cached and (response.status == 0 or response.status == 200 or response.status == 429 or response.status >= 500) then
		session = { scope = scope, document = cached }
		print('[SonoranRadio] Using the last verified placement backup.')
		return
	end
	-- Older backends have no placements endpoint. Keep their local editor until
	-- this room has a portal snapshot. Other failures must not accept local writes.
	if response.status ~= 404 or cached then session = { scope = scope } end
	print('[SonoranRadio] Portal placements are unavailable. Using the original placement files.')
end

function GetPortalRadioPlacement(file)
	local kind = files[file]
	local state = kind and session and session.document and session.document.placements[kind]
	if not state or not state.entries then return nil end
	-- Startup and live edits mutate runtime objects independently of the snapshot.
	local payload = encode(state.entries)
	local copy = payload and decode(payload)
	if kind == 'mobileRepeaters' and copy then
		return { version = 1, migratedFromConfig = true, vehicles = copy }
	end
	return copy
end

function GetPortalRadioPlacementRevision(file)
	local kind = files[file]
	local state = kind and session and session.document and session.document.placements[kind]
	return state and state.revision
end

function MatchesRadioPlacementRevision(file, expected)
	if not session then return true end
	local current = GetPortalRadioPlacementRevision(file)
	return current ~= nil and expected == current
end

function SavePortalRadioPlacement(file, entries)
	local kind = files[file]
	if not kind or not session then return nil end
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
