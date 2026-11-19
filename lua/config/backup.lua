local resourceName = GetCurrentResourceName()
local backupFile = 'lua/config/.configuration-cache.json'
local maxBytes = 768 * 1024
local sections = {}

function RegisterManagedRadioBackupSection(name, legacyFile, validate)
	sections[name] = { legacyFile = legacyFile, validate = validate }
end

local function decode(raw)
	if type(raw) ~= 'string' or #raw > maxBytes then return nil end
	local ok, value = pcall(json.decode, raw)
	if ok and type(value) == 'table' then return value end
end

local function matchesScope(saved, scope)
	return type(saved) == 'table' and saved.community == scope.community and
		saved.roomId == scope.roomId and saved.origin == scope.origin
end

local function readBackup(scope)
	local raw = LoadResourceFile(resourceName, backupFile)
	local saved = decode(raw)
	local scoped = saved and saved.version == 1 and matchesScope(saved.scope, scope)
	local backup = { version = 1, scope = scope }
	for name, section in pairs(sections) do
		if scoped then
			backup[name] = section.validate(saved[name])
		elseif raw == nil then
			-- An older installation may need these on its first start after upgrading.
			local legacy = decode(LoadResourceFile(resourceName, section.legacyFile))
			if legacy and matchesScope(legacy.scope, scope) then
				backup[name] = section.validate(legacy.document)
			end
		end
	end
	return backup
end

function ReadManagedRadioConfigBackup(scope, section)
	return readBackup(scope)[section]
end

function SaveManagedRadioConfigBackup(scope, section, document)
	-- Preserve the other verified section when the settings and placement APIs
	-- respond separately or when an in-game editor updates one collection.
	local backup = readBackup(scope)
	backup[section] = document
	local encoded, payload = pcall(json.encode, backup)
	if not encoded or type(payload) ~= 'string' or #payload > maxBytes then return false end
	local ok, saved = pcall(function()
		return exports[resourceName]:WriteManagedRadioConfigBackup(payload)
	end)
	return ok and saved == true
end
