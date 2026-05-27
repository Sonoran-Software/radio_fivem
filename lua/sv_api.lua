local sonoranRadioClient = nil
local sonoranRadioClientKey = nil

local ApiEndpoints = {
	['SET-SERVER-IP'] = true,
	['SET-SERVER-SPEAKERS'] = true,
	['SET-USER-DISPLAY-NAME'] = true,
	['PLAY-TONE'] = true,
	['SET-ZONES'] = true
}

local function getSonoranRadioClientKey()
	return table.concat({
		tostring(Config.apiKey or ''),
		tostring(Config.comId or ''),
		tostring(Config.apiUrl or ''),
		tostring(Config.serverId or ''),
		tostring(Config.debug or false)
	}, '|')
end

local function load_module(path)
  if LoadResourceFile and GetCurrentResourceName then
    local resource_name = GetCurrentResourceName()
    local source = LoadResourceFile(resource_name, path)
    if not source then
      error(("Unable to load module: %s"):format(path))
    end

    local chunk, load_error = load(source, ("@@%s/%s"):format(resource_name, path))
    if not chunk then
      error(load_error)
    end

    return chunk()
  end

  local module_name = path:gsub("^lua/", ""):gsub("%.lua$", ""):gsub("/", ".")
  return require(module_name)
end

local create_client = load_module("lua/sonoran/client.lua")
local create_fivem_adapter = load_module("lua/sonoran/adapters/fivem.lua")
function getSonoranRadioClient()
	local key = getSonoranRadioClientKey()
	if sonoranRadioClient ~= nil and sonoranRadioClientKey == key then
		return sonoranRadioClient
	end

	local clientConfig = {
		product = 2,
		apiKey = Config.apiKey,
		communityId = Config.comId,
		apiUrl = Config.apiUrl,
		defaultServerId = Config.comId,
		logLevel = Config.debug and 'DEBUG' or 'ERROR'
	}
	if Config.serverId ~= nil then
		clientConfig.roomId = Config.serverId
	end

	sonoranRadioClient = exports['Sonoran.Lua']:createClient(clientConfig)
	sonoranRadioClientKey = key
	return sonoranRadioClient
end
function setSonoranRadioClientRoomId(roomId)
	sonoranRadioClient:setRoomId(roomId)
end

local function encodeApiResponse(data)
	if data == nil then
		return nil
	end
	if type(data) == 'string' then
		return data
	end
	return json.encode(data)
end

function formatSonoranApiReason(reason)
	if reason == nil then
		return nil
	end
	if type(reason) == 'string' then
		return reason
	end
	return json.encode(reason)
end

local function finalizeApiRequest(type, result, cb)
	if result and result.success then
		local data = encodeApiResponse(result.data)
		if cb then
			cb(data, true)
		end
		return
	end

	local reason = formatSonoranApiReason(result and result.reason)
	warnLog(('Radio API request failed (%s): %s'):format(tostring(type), tostring(reason)))
	if reason == 'INVALID COMMUNITY ID' or reason == 'API IS NOT ENABLED FOR THIS COMMUNITY' or string.find(tostring(reason), 'IS NOT ENABLED FOR THIS COMMUNITY') or reason == 'INVALID API KEY' then
		errorLog('Fatal: Disabling API - an error was encountered that must be resolved. Please restart the resource after resolving: ' .. tostring(reason))
		Config.critError = true
		sendCritError()
	end
	if cb then
		cb(reason, false)
	end
end

local function callApiEndpoint(type, postData)
	local client = getSonoranRadioClient()
	local payload = postData or {}

	if type == 'SET-SERVER-IP' then
		return client:setServerIpV2(payload)
	elseif type == 'SET-SERVER-SPEAKERS' then
		return client:setInGameSpeakerLocationsV2(payload.locations or {}, Config.comId)
	elseif type == 'SET-USER-DISPLAY-NAME' then
		return client:setUserDisplayNameV2(payload)
	elseif type == 'PLAY-TONE' then
		return client:playToneV2(payload.tones or {}, payload.playTo, Config.comId)
	elseif type == 'SET-ZONES' then
		return client:setZonesV2(payload)
	end
end

function performApiRequest(postData, type, cb)
	if Config.apiKey == nil or Config.comId == nil then
		errorLog('API request failed: API key or community ID is not set. Please ensure you have set these values in your configuration.')
		return
	end
	if ApiEndpoints[type] == nil then
		return warnLog(('API request failed: endpoint %s is not registered. Use the registerApiType function to register this endpoint with the appropriate type.'):format(type))
	end
	assert(type ~= nil, 'No type specified, invalid request.')
	if Config.critError then
		errorLog('API request failed: critical error encountered, API version too low, aborting request.')
		return
	end

	debugLog(('type %s called Sonoran.Lua'):format(type))
	finalizeApiRequest(type, callApiEndpoint(type, postData or {}), cb)
end

AddEventHandler('playerJoining', function()
	if Config.critError then
		TriggerClientEvent('SonoranRadio::CritError', source, true)
	end
end)

function sendCritError()
	SetTimeout(5000, function()
		TriggerClientEvent('SonoranRadio::CritError', -1, true)
	end)
end
