WarningCodes = {
	['WRN_LB_PHONE_NOT_STARTED'] = {
		code = 'WRN-201',
		message = 'lb-phone integration is waiting for the lb-phone resource to start.'
	},
	['WRN_LUXART_RESOURCE_DEFAULTED'] = {
		code = 'WRN-202',
		message = 'Config.luxartResourceName was empty, so the default "lvc" resource name was applied.'
	},
	['WRN_API_REQUEST_FAILED'] = {
		code = 'WRN-203',
		message = 'A Sonoran Radio API request failed.'
	},
	['WRN_API_ENDPOINT_UNREGISTERED'] = {
		code = 'WRN-204',
		message = 'An API request was attempted for an endpoint type that is not registered.'
	},
	['WRN_GEO_ZONE_SYNC_FAILED'] = {
		code = 'WRN-205',
		message = 'Geo and degrade zones could not be synchronized with the radio service.'
	},
	['WRN_COMMUNITY_CHANNELS_FETCH_FAILED'] = {
		code = 'WRN-206',
		message = 'Community channels could not be fetched for a player request.'
	},
	['WRN_SKIN_SAVE_DEBUG_BLOCKED'] = {
		code = 'WRN-207',
		message = 'A client attempted to save a radio skin while debug mode was disabled.'
	},
	['WRN_CONFIG_RENAME_FAILED'] = {
		code = 'WRN-208',
		message = 'A default configuration file could not be renamed to its writable target path.'
	},
	['WRN_CONFIG_SAVE_FALLBACK'] = {
		code = 'WRN-209',
		message = 'Saving a configuration file failed, so the resource fell back to writing the default file.'
	},
	['WRN_SERVER_IP_USING_EXISTING_ROOM'] = {
		code = 'WRN-210',
		message = 'The server IP update failed, but an existing roomId was reused while retrying in the background.'
	},
	['WRN_SERVER_IP_RETRYING'] = {
		code = 'WRN-211',
		message = 'The server IP update failed and will be retried.'
	},
	['WRN_SERVER_ID_CONFIG_WRITE_FAILED'] = {
		code = 'WRN-212',
		message = 'The resolved serverId could not be written back to config.lua.'
	},
	['WRN_APIKEY_CONVAR_UNINITIALIZED'] = {
		code = 'WRN-213',
		message = 'The apiKey convar was not initialized from sonoranradio.cfg.'
	},
	['WRN_CHATTER_EXCLUSIONS_OVERWRITE_DEPRECATED'] = {
		code = 'WRN-214',
		message = 'Config.chatterExclusions overwrote earpieces.json even though the config path is deprecated.'
	},
	['WRN_CHATTER_EXCLUSIONS_DEPRECATED'] = {
		code = 'WRN-215',
		message = 'Config.chatterExclusions is deprecated.'
	},
	['WRN_MOBILE_REPEATERS_CONFIG_MIGRATED'] = {
		code = 'WRN-216',
		message = 'Legacy Config.repeaterVehicleSpawncodes entries were migrated to mobileRepeaters.json.'
	},
	['WRN_LISTENER_PRO_REQUIRED'] = {
		code = 'WRN-217',
		message = 'Nearby radio chatter and scanners are disabled because they require a Sonoran Radio Pro subscription.'
	}
}

ErrorCodes = {
	['ERR_OX_LIB_NOT_STARTED'] = {
		code = 'ERR-101',
		message = 'ox_lib must be started before this resource.'
	},
	['ERR_OX_LIB_INIT_LOAD_FAILED'] = {
		code = 'ERR-102',
		message = 'The resource could not load @ox_lib/init.lua.'
	},
	['ERR_OX_LIB_NOTIFY_UNAVAILABLE'] = {
		code = 'ERR-103',
		message = 'ox_lib notifications were selected, but lib.notify is unavailable.'
	},
	['ERR_RADIO_ITEM_INVENTORY_MISSING'] = {
		code = 'ERR-104',
		message = 'No supported inventory resource was detected while enforceRadioItem is enabled.'
	},
	['ERR_RADIO_ITEM_FRAMEWORK_MISSING'] = {
		code = 'ERR-105',
		message = 'No supported framework resource was detected while enforceRadioItem is enabled.'
	},
	['ERR_API_CREDENTIALS_MISSING'] = {
		code = 'ERR-106',
		message = 'The API key or community ID is missing from configuration.'
	},
	['ERR_API_FATAL_DISABLED'] = {
		code = 'ERR-107',
		message = 'A fatal API error disabled the resource until configuration is corrected and the resource is restarted.'
	},
	['ERR_API_CRITICAL_ABORTED'] = {
		code = 'ERR-108',
		message = 'A request was aborted because the resource is already in a critical API error state.'
	},
	['ERR_FRAMES_DEPARTMENTS_MISSING'] = {
		code = 'ERR-109',
		message = 'Config.frames.departments is missing for the selected frame permission mode.'
	},
	['ERR_JAMMERS_PERMISSION_MODE_INVALID'] = {
		code = 'ERR-110',
		message = 'The configured permission mode for radio jammers is invalid.'
	},
	['ERR_RADIO_ITEM_CONFIG_MISSING'] = {
		code = 'ERR-111',
		message = 'Radio item enforcement is enabled, but Config.RadioItem is missing.'
	},
	['ERR_SCANNER_ITEM_CONFIG_MISSING'] = {
		code = 'ERR-112',
		message = 'Scanner item enforcement is enabled, but Config.ScannerItem is missing.'
	},
	['ERR_QBOX_OX_RADIO_ITEM_MISSING'] = {
		code = 'ERR-113',
		message = 'The configured radio item does not exist in Ox Inventory on Qbox.'
	},
	['ERR_QBOX_OX_SCANNER_ITEM_MISSING'] = {
		code = 'ERR-114',
		message = 'The configured scanner item does not exist in Ox Inventory on Qbox.'
	},
	['ERR_COMMUNITY_CHANNELS_FETCH_FAILED'] = {
		code = 'ERR-115',
		message = 'Community channels could not be fetched from the radio service.'
	},
	['ERR_SKIN_SAVE_FAILED'] = {
		code = 'ERR-116',
		message = 'A radio skin configuration file could not be saved.'
	},
	['ERR_CONFIG_SAVE_FAILED'] = {
		code = 'ERR-117',
		message = 'A JSON configuration file could not be saved.'
	},
	['ERR_SERVER_IP_SET_FAILED'] = {
		code = 'ERR-118',
		message = 'The resource could not register or update the server IP with the radio service.'
	},
	['ERR_SERVER_IP_INVALID_ROOM'] = {
		code = 'ERR-119',
		message = 'The radio service returned an invalid roomId while setting the server IP.'
	},
	['ERR_FRAMES_CONFIG_MISSING'] = {
		code = 'ERR-120',
		message = 'Config.frames is missing.'
	},
	['ERR_SERVER_SPEAKERS_SET_FAILED'] = {
		code = 'ERR-121',
		message = 'The resource could not synchronize server speaker locations with the radio service.'
	},
	['ERR_SERVER_NAME_SET_FAILED'] = {
		code = 'ERR-122',
		message = 'The resource could not update a user display name in the radio service.'
	},
	['ERR_INVALID_COMMUNITY_ID'] = {
		code = 'ERR-123',
		message = 'The configured community ID is invalid or not enabled for the API.'
	}
}

function getStructuredLogDefinition(key)
	if type(key) ~= 'string' then
		return nil
	end
	return ErrorCodes[key] or WarningCodes[key]
end

function getCurrentResourceFramePrefix()
	if type(GetCurrentResourceName) ~= 'function' then
		return '@@sonoranradio'
	end

	local resourceName = GetCurrentResourceName()
	if type(resourceName) ~= 'string' or resourceName == '' then
		return '@@sonoranradio'
	end

	return '@@' .. resourceName
end

function normalizeLogFrameSource(infoSource)
	if type(infoSource) ~= 'string' or infoSource == '' then
		return nil
	end

	local resourcePrefix = getCurrentResourceFramePrefix()
	if infoSource:find(resourcePrefix, 1, true) ~= 1 then
		return nil
	end

	return infoSource:gsub('^@@[^/\\]+[/\\]?', '')
end

function buildLogFrameLocation(info)
	if type(info) ~= 'table' then
		return nil
	end

	local relativePath = normalizeLogFrameSource(info.source)
	if not relativePath or relativePath == '' then
		return nil
	end

	local lineNumber = tonumber(info.currentline) or tonumber(info.linedefined)
	if lineNumber and lineNumber > 0 then
		return ('%s:%d'):format(relativePath, lineNumber)
	end

	return relativePath
end

function getStructuredLogSourceLabel(stackLevel)
	local info = debug.getinfo(stackLevel or 2, 'nSl')
	if type(info) ~= 'table' then
		return '.'
	end

	return buildLogFrameLocation(info) or '.'
end

function buildStructuredLogBreadcrumbs(stackLevel, maxFrames)
	local frames = {}
	local startLevel = tonumber(stackLevel) or 2
	local frameLimit = tonumber(maxFrames) or 4

	for level = startLevel, startLevel + frameLimit - 1 do
		local info = debug.getinfo(level, 'nSl')
		if type(info) == 'table' then
			local relativePath = normalizeLogFrameSource(info.source)
			if relativePath and relativePath ~= 'lua/sh_logcodes.lua' then
				local location = buildLogFrameLocation(info)
				local functionName = type(info.name) == 'string' and info.name ~= '' and info.name or nil
				if location then
					local line = ('[%d] %s'):format(#frames + 1, location)
					if functionName then
						line = ('%s in `%s`'):format(line, functionName)
					end
					frames[#frames + 1] = line
				end
			end
		end
	end

	if #frames == 0 then
		return nil
	end

	local sections = {
		('Likely cause: %s'):format(frames[1]:gsub('^%[%d+%] ', '')),
		'Trace:',
		table.concat(frames, '\n')
	}
	return table.concat(sections, '\n')
end

function appendStructuredLogBreadcrumbs(level, message, stackLevel, maxFrames)
	if level ~= 'ERROR' and level ~= 'WARNING' then
		return message
	end

	if type(message) ~= 'string' then
		message = tostring(message)
	end

	if message:find('\nTrace:\n', 1, true) or message:find('\nLikely cause:', 1, true) then
		return message
	end

	local breadcrumbs = buildStructuredLogBreadcrumbs((tonumber(stackLevel) or 2) + 1, maxFrames)
	if not breadcrumbs then
		return message
	end

	return ('%s\n%s'):format(message, breadcrumbs)
end

function formatStructuredLogMessage(keyOrMessage, message)
	local definition = getStructuredLogDefinition(keyOrMessage)
	if not definition then
		if message == nil then
			return tostring(keyOrMessage)
		end
		return ('[%s] %s'):format(tostring(keyOrMessage), tostring(message))
	end

	local resolvedMessage = message
	if resolvedMessage == nil or resolvedMessage == '' then
		resolvedMessage = definition.message
	end
	return ('[%s] %s'):format(definition.code, tostring(resolvedMessage))
end
