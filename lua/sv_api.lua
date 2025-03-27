local ApiEndpoints = {
	['SET-SERVER-IP'] = 'radio',
	['SET-SERVER-SPEAKERS'] = 'radio',
	['SET-USER-DISPLAY-NAME'] = 'radio'
}

function PerformHttpRequestS(url, cb, method, data, headers)
	if not data then
		data = ''
	end
	if not headers then
		headers = {
			['X-User-Agent'] = 'SonoranRadio'
		}
	end
	exports['sonoranradio']:HandleHttpRequest(url, cb, method, data, headers)
end
local rateLimitedEndpoints = {}

function performApiRequest(postData, type, cb)
	if Config.apiKey == nil or Config.comId == nil then
		errorLog('API request failed: API key or community ID is not set. Please ensure you have set these values in your configuration.')
		return
	end
	local endpoint = nil
	if ApiEndpoints[type] ~= nil then
		endpoint = ApiEndpoints[type]
	else
		return warnLog(('API request failed: endpoint %s is not registered. Use the registerApiType function to register this endpoint with the appropriate type.'):format(type))
	end
	local url = Config.apiUrl .. tostring(endpoint) .. '/' .. tostring(type:lower())
	assert(type ~= nil, 'No type specified, invalid request.')
	if Config.critError then
		errorLog('API request failed: critical error encountered, API version too low, aborting request.')
		return
	end
	if rateLimitedEndpoints[type] == nil then
		PerformHttpRequestS(url, function(statusCode, res, headers)
			debugLog(('type %s called with post data %s to url %s'):format(type, json.encode(postData), url))
			if statusCode == 200 or statusCode == 201 and res ~= nil then
				debugLog('result: ' .. tostring(res))
				if res == 'Sonoran Radio: Backend Service Reached' or res == 'Backend Service Reached' then
					errorLog(('API ERROR: Invalid endpoint (URL: %s). Ensure you\'re using a valid endpoint.'):format(url))
				else
					if res == nil then
						res = {}
						debugLog('Warning: Response had no result, setting to empty table.')
					end
					cb(res, true)
				end
			elseif statusCode == 400 then
				warnLog('Bad request was sent to the API. Enable debug mode and retry your request. Response: ' .. tostring(res))
				-- additional safeguards
				if res == 'INVALID COMMUNITY ID' or res == 'API IS NOT ENABLED FOR THIS COMMUNITY' or string.find(res, 'IS NOT ENABLED FOR THIS COMMUNITY') or res == 'INVALID API KEY' then
					errorLog('Fatal: Disabling API - an error was encountered that must be resolved. Please restart the resource after resolving: ' .. tostring(res))
					Config.critError = true
					sendCritError()
				end
				cb(res, false)
			elseif statusCode == 404 then -- handle 404 requests, like from CHECK_APIID
				warnLog('WARN_404: 404 response from API: ' .. tostring(res))
				cb(res, false)
			elseif statusCode == 429 then -- rate limited :(
				if rateLimitedEndpoints[type] then
					-- don't warn again, it's spammy. Instead, just print a debug
					debugLog(('Endpoint %s ratelimited. Dropping request.'))
					return
				end
				rateLimitedEndpoints[type] = true
				warnLog(
								('WARN_RATELIMIT: You are being ratelimited (last request made to %s) - Ignoring all API requests to this endpoint for 60 seconds. If this is happening frequently, please review your configuration to ensure you\'re not sending data too quickly.'):format(
												type))
				SetTimeout(60000, function()
					rateLimitedEndpoints[type] = nil
					infoLog(('Endpoint %s no longer ignored.'):format(type))
				end)
			elseif string.match(tostring(statusCode), '50') then
				errorLog(('API error returned (%s). Check status.sonoransoftware.com or our Discord to see if there\'s an outage.'):format(statusCode))
				debugLog(('API_ERROR Error returned: %s %s'):format(statusCode, res))
			else
				errorLog(('Radio API ERROR (from %s): %s %s'):format(url, statusCode, json.encode(res)))
			end
		end, 'POST', json.encode(postData), {
			['Content-Type'] = 'application/json'
		})
	else
		debugLog(('Endpoint %s is ratelimited. Dropped request: %s'):format(type, json.encode(postData)))
	end
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