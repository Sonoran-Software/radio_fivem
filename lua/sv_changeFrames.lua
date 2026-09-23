local BACKEND_FRAME_PREFIX = 'frame:'
local BACKEND_FRAME_REFRESH_SECONDS = 30

local backendFrameDefinitions = {}
local backendFrameIds = {}
local backendFrameAliases = {}
local backendFramesLastAttempt = 0
local backendFramesRefreshing = false

local DEFAULT_VEHICLE_CLASSES = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 17, 18, 19, 20, 21, 22}
local DEFAULT_AIRCRAFT_CLASSES = {15, 16}

local function appendUnique(target, values)
	local seen = {}
	for _, value in ipairs(target) do
		seen[value] = true
	end
	for _, value in ipairs(values or {}) do
		if type(value) == 'string' and not seen[value] then
			seen[value] = true
			table.insert(target, value)
		end
	end
end

local function filterKnownFrames(frames, knownFrames)
	local knownFrameLookup = {}
	for _, knownFrame in ipairs(knownFrames) do
		knownFrameLookup[knownFrame] = true
	end

	local filteredFrames = {}
	for _, frame in ipairs(frames) do
		local resolvedFrame = backendFrameAliases[frame] or frame
		if knownFrameLookup[resolvedFrame] then
			appendUnique(filteredFrames, {resolvedFrame})
		end
	end

	return filteredFrames
end

local function decodeBackendFrames(data)
	if type(data) == 'string' then
		local ok, decoded = pcall(json.decode, data)
		if not ok then
			return nil
		end
		data = decoded
	end
	if type(data) ~= 'table' or type(data.frames) ~= 'table' then
		return nil
	end
	return data.frames
end

local function buildBackendFrameCache(frames)
	local definitions = {}
	local ids = {}
	local aliases = {}

	for _, layout in ipairs(frames) do
		if type(layout) == 'table' and layout.id ~= nil and type(layout.body) == 'table' and type(layout.screen) == 'table' then
			local frameId = BACKEND_FRAME_PREFIX .. tostring(layout.id)
			local frameLayouts = {
				{
					type = 'portable',
					body = layout.body,
					controls = type(layout.controls) == 'table' and layout.controls or {},
					screen = layout.screen
				}
			}
			local variants = type(layout.variants) == 'table' and layout.variants or {}
			if type(variants.vehicle) == 'table' and type(variants.vehicle.body) == 'table' and type(variants.vehicle.screen) == 'table' then
				table.insert(frameLayouts, {
					type = 'vehicle',
					vehicleClasses = type(variants.vehicle.vehicleClasses) == 'table' and variants.vehicle.vehicleClasses or DEFAULT_VEHICLE_CLASSES,
					body = variants.vehicle.body,
					controls = type(variants.vehicle.controls) == 'table' and variants.vehicle.controls or {},
					screen = variants.vehicle.screen
				})
			end
			if type(variants.aircraft) == 'table' and type(variants.aircraft.body) == 'table' and type(variants.aircraft.screen) == 'table' then
				table.insert(frameLayouts, {
					type = 'vehicle',
					vehicleClasses = type(variants.aircraft.vehicleClasses) == 'table' and variants.aircraft.vehicleClasses or DEFAULT_AIRCRAFT_CLASSES,
					body = variants.aircraft.body,
					controls = type(variants.aircraft.controls) == 'table' and variants.aircraft.controls or {},
					screen = variants.aircraft.screen
				})
			end
			for _, legacyFrame in ipairs(type(layout.fivemLegacyFrames) == 'table' and layout.fivemLegacyFrames or {}) do
				if type(legacyFrame) == 'table' and (legacyFrame.type == 'hud' or legacyFrame.type == 'scanner') then
					table.insert(frameLayouts, legacyFrame)
				end
			end
			definitions[frameId] = {
				name = type(layout.name) == 'string' and layout.name or ('Community Frame ' .. tostring(layout.id)),
				frames = frameLayouts
			}
			table.insert(ids, frameId)
			if type(layout.legacySkinId) == 'string' and layout.legacySkinId ~= '' then
				aliases[layout.legacySkinId] = frameId
			end
		end
	end

	backendFrameDefinitions = definitions
	backendFrameIds = ids
	backendFrameAliases = aliases
end

function refreshBackendFrames(force)
	local now = os.time()
	if backendFramesRefreshing then
		return false
	end
	if not force and now - backendFramesLastAttempt < BACKEND_FRAME_REFRESH_SECONDS then
		return false
	end

	backendFramesLastAttempt = now
	backendFramesRefreshing = true
	local refreshed = false
	performApiRequest({}, 'GET-FRAMES', function(data, success)
		if not success then
			return
		end

		local frames = decodeBackendFrames(data)
		if not frames then
			warnLog('WRN_API_REQUEST_FAILED', 'Radio API returned an invalid frame payload. Existing frame data will be retained.')
			return
		end

		buildBackendFrameCache(frames)
		refreshed = true
	end)
	backendFramesRefreshing = false

	if refreshed then
		for _, player in ipairs(GetPlayers()) do
			local playerId = tonumber(player) or player
			TriggerClientEvent(
				'SonoranRadio::BackendFramesUpdated',
				playerId,
				checkFramePermissions(playerId),
				backendFrameDefinitions,
				backendFrameAliases
			)
		end
	end
	return refreshed
end

function getBackendFrameDefinitions()
	refreshBackendFrames(false)
	return backendFrameDefinitions
end

function getBackendFrameAliases()
	refreshBackendFrames(false)
	return backendFrameAliases
end

function getAllAvailableFrames()
	refreshBackendFrames(false)
	local installedFrames = exports.sonoranradio:GetAvailableFrames(GetResourcePath('sonoranradio') .. '/skins')
	local frames = {}
	appendUnique(frames, installedFrames)
	appendUnique(frames, backendFrameIds)
	return frames
end

function isKnownFrame(frameId)
	if type(frameId) ~= 'string' then
		return false
	end
	local resolvedFrame = backendFrameAliases[frameId] or frameId
	for _, knownFrameId in ipairs(getAllAvailableFrames()) do
		if resolvedFrame == knownFrameId then
			return true
		end
	end
	return false
end

local function addDepartmentFrames(allowedFrames, department)
	if type(department) == 'table' then
		appendUnique(allowedFrames, department.allowedFrames or {})
	end
end

function checkFramePermissions(player)
	refreshBackendFrames(false)

	local installedFrames = exports.sonoranradio:GetAvailableFrames(GetResourcePath('sonoranradio') .. '/skins')
	local knownFrames = {}
	appendUnique(knownFrames, installedFrames)
	appendUnique(knownFrames, backendFrameIds)
	local framesConfig = Config.frames
	local allowedFrames = {}

	-- Layouts are managed in the Radio customization menu, while FiveM keeps
	-- ownership of per-player frame permissions through Config.frames.
	if type(framesConfig) ~= 'table' or not framesConfig.permissionMode or framesConfig.permissionMode == 'none' then
		appendUnique(allowedFrames, knownFrames)
	elseif type(framesConfig.departments) ~= 'table' then
		errorLog('ERR_FRAMES_DEPARTMENTS_MISSING', 'Config.frames.departments is missing for permission mode: ' .. tostring(framesConfig.permissionMode) .. ' - returning all available frames')
		appendUnique(allowedFrames, knownFrames)
	elseif framesConfig.permissionMode == 'ace' then
		for _, department in pairs(framesConfig.departments) do
			if department.permissions and department.permissions.ace then
				for _, acePermission in ipairs(department.permissions.ace) do
					if IsPlayerAceAllowed(player, acePermission) then
						addDepartmentFrames(allowedFrames, department)
						break
					end
				end
			end
		end
	elseif framesConfig.permissionMode == 'qbcore' then
		local QBCore = exports['qb-core']:GetCoreObject()
		local QBPlayer = QBCore.Functions.GetPlayer(player)
		for _, department in pairs(framesConfig.departments) do
			if department.permissions and department.permissions.jobs and QBPlayer ~= nil then
				for qbPermission, permission in pairs(department.permissions.jobs) do
					if QBPlayer.PlayerData.job.name == qbPermission then
						for _, grade in ipairs(permission.grades or {}) do
							if QBPlayer.PlayerData.job.grade.level == grade then
								addDepartmentFrames(allowedFrames, department)
								break
							end
						end
					end
				end
			end
		end
	elseif framesConfig.permissionMode == 'qbox' then
		local QBPlayer = exports.qbx_core.GetPlayer(player)
		for _, department in pairs(framesConfig.departments) do
			if department.permissions and department.permissions.jobs and QBPlayer ~= nil then
				for qbPermission, permission in pairs(department.permissions.jobs) do
					if QBPlayer.PlayerData.job.name == qbPermission then
						for _, grade in ipairs(permission.grades or {}) do
							if QBPlayer.PlayerData.job.grade.level == grade then
								addDepartmentFrames(allowedFrames, department)
								break
							end
						end
					end
				end
			end
		end
	elseif framesConfig.permissionMode == 'esx' then
		local ESX = exports['es_extended']:getSharedObject()
		local ESXPlayer = ESX.GetPlayerFromId(player)
		for _, department in pairs(framesConfig.departments) do
			if department.permissions and department.permissions.jobs and ESXPlayer ~= nil then
				for esxPermission, permission in pairs(department.permissions.jobs) do
					if ESXPlayer.job.name == esxPermission then
						for _, grade in ipairs(permission.grades or {}) do
							if ESXPlayer.job.grade == grade then
								addDepartmentFrames(allowedFrames, department)
								break
							end
						end
					end
				end
			end
		end
	end

	return filterKnownFrames(allowedFrames, knownFrames)
end

local function decodeJsonValue(value)
	if type(value) == 'table' then
		return value
	end
	if type(value) ~= 'string' or value == '' then
		return nil
	end
	local ok, decoded = pcall(json.decode, value)
	return ok and decoded or nil
end

local function uploadLegacyFrameImage(image)
	local contents = LoadResourceFile(GetCurrentResourceName(), image.resourcePath)
	if type(contents) ~= 'string' then
		return nil, 'unable to read ' .. tostring(image.resourcePath)
	end
	if #contents > 5 * 1024 * 1024 then
		return nil, tostring(image.resourcePath) .. ' exceeds the 5 MB upload limit'
	end

	local response = nil
	local failure = nil
	performApiRequest({
		fileName = image.fileName,
		fileContent = contents,
		contentType = image.contentType
	}, 'UPLOAD-FRAME-IMAGE', function(data, success)
		if success then
			response = decodeJsonValue(data)
		else
			failure = data
		end
	end)
	if type(response) ~= 'table' or type(response.url) ~= 'string' then
		return nil, failure or ('invalid image upload response for ' .. tostring(image.resourcePath))
	end
	return response.url
end

local function migrateLegacySkins()
	local resourceName = GetCurrentResourceName()
	local skinsPath = GetResourcePath(resourceName) .. '/skins'
	local scan = decodeJsonValue(exports[resourceName]:GetLegacySkinConfigs(skinsPath))
	if type(scan) ~= 'table' or not scan.exists then
		return false
	end
	if type(scan.errors) == 'table' and #scan.errors > 0 then
		warnLog('WRN_API_REQUEST_FAILED', 'Legacy radio skins were not migrated. Fix these issues and restart: ' .. table.concat(scan.errors, '; '))
		return false
	end
	if type(scan.skins) ~= 'table' or #scan.skins == 0 then
		infoLog('The legacy skins folder is empty; nothing needs to be migrated.')
		return false
	end

	infoLog(('Migrating %d legacy radio skin(s) to the Radio backend...'):format(#scan.skins))
	for _, skin in ipairs(scan.skins) do
		for _, image in ipairs(type(skin.images) == 'table' and skin.images or {}) do
			local uploadedUrl, uploadError = uploadLegacyFrameImage(image)
			if not uploadedUrl then
				warnLog('WRN_API_REQUEST_FAILED', 'Legacy radio skin migration stopped before archiving: ' .. tostring(uploadError))
				return false
			end
			for _, frame in ipairs(skin.frames or {}) do
				if type(frame.body) == 'table' and frame.body.image == image.source then
					frame.body.image = uploadedUrl
				end
			end
		end
		skin.images = nil
	end

	local migrationResponse = nil
	local migrationFailure = nil
	performApiRequest({skins = scan.skins}, 'MIGRATE-FRAMES', function(data, success)
		if success then
			migrationResponse = decodeJsonValue(data)
		else
			migrationFailure = data
		end
	end)
	if type(migrationResponse) ~= 'table' or migrationResponse.complete ~= true then
		warnLog('WRN_API_REQUEST_FAILED', 'Legacy radio skin migration was not committed; the skins folder was retained. ' .. tostring(migrationFailure or 'Invalid migration response.'))
		return false
	end

	if not refreshBackendFrames(true) then
		warnLog('WRN_API_REQUEST_FAILED', 'Legacy frames were saved but could not be verified with a fresh backend read. The skins folder was retained for a safe retry.')
		return false
	end
	for _, skin in ipairs(scan.skins) do
		if backendFrameAliases[skin.legacySkinId] == nil then
			warnLog('WRN_API_REQUEST_FAILED', 'Legacy frame verification did not return an alias for ' .. tostring(skin.legacySkinId) .. '. The skins folder was retained.')
			return false
		end
	end

	local archive = decodeJsonValue(exports[resourceName]:ArchiveLegacySkins(skinsPath))
	if type(archive) ~= 'table' or archive.success ~= true then
		warnLog('WRN_API_REQUEST_FAILED', 'Legacy frames were migrated and verified, but the skins folder could not be renamed: ' .. tostring(archive and archive.error or 'unknown filesystem error'))
		return false
	end

	infoLog('Legacy radio skins were migrated and verified. Original files were archived at ' .. tostring(archive.path) .. '.')
	return true
end

CreateThread(function()
	-- Push handlers are registered from a thread so every server script has
	-- finished loading before we publish into sv_pushevents' handler registry.
	-- A forced refresh rebuilds the authoritative cache and immediately sends
	-- the new definitions to every connected NUI client.
	Wait(0)
	TriggerEvent('sonoranradio::RegisterPushEvent', 'frames_updated', function(data)
		debugLog('Received frames_updated push event: ' .. json.encode(data))
		if not refreshBackendFrames(true) then
			warnLog('WRN_API_REQUEST_FAILED', 'Radio frame update push could not be reconciled. Existing frame data will be retained until the next refresh.')
		end
	end)

	Wait(1000)
	migrateLegacySkins()
	while true do
		refreshBackendFrames(true)
		Wait(BACKEND_FRAME_REFRESH_SECONDS * 1000)
	end
end)
