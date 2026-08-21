local BACKEND_FRAME_PREFIX = 'frame:'
local BACKEND_FRAME_REFRESH_SECONDS = 300

local backendFrameDefinitions = {}
local backendFrameIds = {}
local backendFramesLastAttempt = 0
local backendFramesRefreshing = false

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
		if knownFrameLookup[frame] then
			appendUnique(filteredFrames, {frame})
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

	for _, layout in ipairs(frames) do
		if type(layout) == 'table' and layout.id ~= nil and type(layout.body) == 'table' and type(layout.screen) == 'table' then
			local frameId = BACKEND_FRAME_PREFIX .. tostring(layout.id)
			definitions[frameId] = {
				name = type(layout.name) == 'string' and layout.name or ('Community Frame ' .. tostring(layout.id)),
				frames = {
					{
						type = 'portable',
						body = layout.body,
						controls = type(layout.controls) == 'table' and layout.controls or {},
						screen = layout.screen
					}
				}
			}
			table.insert(ids, frameId)
		end
	end

	backendFrameDefinitions = definitions
	backendFrameIds = ids
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
				backendFrameDefinitions
			)
		end
	end
	return refreshed
end

function getBackendFrameDefinitions()
	refreshBackendFrames(false)
	return backendFrameDefinitions
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
	for _, knownFrameId in ipairs(getAllAvailableFrames()) do
		if frameId == knownFrameId then
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

CreateThread(function()
	Wait(1000)
	while true do
		refreshBackendFrames(true)
		Wait(BACKEND_FRAME_REFRESH_SECONDS * 1000)
	end
end)
