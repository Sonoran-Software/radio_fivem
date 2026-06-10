function uuid()
	local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
	return string.gsub(template, '[xy]', function(c)
		local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
		return string.format('%x', v)
	end)
end

function shallowcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in pairs(orig) do
			copy[orig_key] = orig_value
		end
	else
		copy = orig
	end
	return copy
end

function DebugPrint(...)
	if (Config.debug) then
		print('Sonoran Radio - Debug', ...)
	end
end

function errorLog(codeOrMessage, message)
	local source = getStructuredLogSourceLabel(3)
	local payload = appendStructuredLogBreadcrumbs('ERROR', formatStructuredLogMessage(codeOrMessage, message), 3)
	print(('[%s:^1ERROR^7]^1 %s^0'):format(source, payload))
end

function showNotification(notification, urgent)
	if urgent == nil then
		urgent = true
	end
	SetNotificationTextEntry('STRING')
	AddTextComponentString(notification)
	DrawNotification(urgent, true)
end

function notifyClient(notification, urgent, colorCode)
	local notifications = (Config and Config.notifications) or {}
	local configuredType = notifications.type or 'native'

	-- Automatically select notification method if set to auto
	local AutoSelectedNotifyMethod = "native"
	if configuredType == "auto" then
		if GetResourceState("lation_ui") == "started" then
			AutoSelectedNotifyMethod = "lation_ui"
		elseif GetResourceState("ox_lib") == "started" then
			AutoSelectedNotifyMethod = "ox_lib"
		elseif GetResourceState("pNotify") == "started" then
			AutoSelectedNotifyMethod = "pNotify"
		elseif GetResourceState("okokNotify") == "started" then
			AutoSelectedNotifyMethod = "okokNotify"
		else
			AutoSelectedNotifyMethod = "native"
		end
	end

	local function ResolveNotifyMethod(cfgValue)
		if cfgValue == "auto" then
			return AutoSelectedNotifyMethod
		end
		return cfgValue
	end
	local notificationType = ResolveNotifyMethod(configuredType)
	local title = notifications['notificationTitle'] or 'SonoranRadio'
	local prefix = ('[%s] '):format(title)
	local formattedNotification = notification
	local plainNotification = notification

	if notificationType == 'native' and colorCode and colorCode ~= '' then
		formattedNotification = colorCode .. notification
	end
	if notificationType ~= 'native' and type(notification) == 'string' then
		plainNotification = notification:gsub('~[%w_]~', '')
	end

	if notificationType == 'native' then
		showNotification(('~b~%s~w~%s'):format(prefix, formattedNotification), urgent)
	elseif notificationType == 'okokNotify' then
		exports['okokNotify']:Alert(title, '' .. plainNotification, 10000, 'info')
	elseif notificationType == 'ox_lib' then
		if not lib then
			if GetResourceState('ox_lib') ~= 'started' then
				errorLog('ERR_OX_LIB_NOT_STARTED')
				return
			end
			local chunk = LoadResourceFile('ox_lib', 'init.lua')
			if not chunk then
				errorLog('ERR_OX_LIB_INIT_LOAD_FAILED')
				return
			end
			load(chunk, '@@ox_lib/init.lua', 't')()
		end
		if lib and lib.notify then
			local oxLibConfig = notifications['ox_lib'] or {}
			local oxNotify = {
				title = title,
				description = plainNotification,
				type = oxLibConfig['type'] or 'inform'
			}
			if oxLibConfig['position'] then
				oxNotify.position = oxLibConfig['position']
			end
			if oxLibConfig['duration'] then
				oxNotify.duration = oxLibConfig['duration']
			end
			lib.notify(oxNotify)
		else
			errorLog('ERR_OX_LIB_NOTIFY_UNAVAILABLE')
		end
	elseif notificationType == 'pNotify' then
		print('Using pNotify for notifications')
		TriggerEvent('pNotify:SendNotification', {
			text = ('<b>%s</b><br>%s'):format(title, plainNotification),
			type = 'info',
			timeout = 5000,
			layout = 'topRight'
		})
	elseif notificationType == 'ox_lib' then
		exports.ox_lib:notify({
			title = title,
			description = plainNotification,
			type = 'info',
			duration = 5000,
			position = 'top-right'
		})
	elseif notificationType == 'lation_ui' then
		exports.lation_ui:notify({
			title = title,
			message = plainNotification,
			type = 'info',
			duration = 5000,
		})
	elseif notificationType == 'custom' then
		notifications['custom'](plainNotification)
	elseif notificationType == 'chat' then
		TriggerEvent('chat:addMessage', {
			template = ('<div class="chat-message sonoran-radio"><b>%s</b> {0}</div>'):format(title),
			args = { plainNotification }
		})
	end
end


-- Framework enums | 0 = None, 1 = QBCore, 2 = Qbox
-- Inventory enums | 0 = None, 1 = QB-compatible, 2 = Ox_Inventory
frameworkEnum = 0
inventoryEnum = 0

local depState = {
	frameworkMissingLogged = false,
	inventoryMissingLogged = false,
	resolvedLogged = false,
}

local function enforceRadioItemEnabled()
	return Config and Config.enforceRadioItem == true
end

local function dependencyInfoLog(message)
	if type(infoLog) == 'function' then
		infoLog(message)
	else
		print('[Sonoran Radio - INFO]:', '^5', message, '^0')
	end
end

function getInventory(silent)
	if GetResourceState('qb-inventory') == 'started' then
		inventoryEnum = 1
	elseif GetResourceState('ox_inventory') == 'started' then
		inventoryEnum = 2
	elseif GetResourceState('qs-inventory') == 'started' then
		inventoryEnum = 1
	elseif GetResourceState('core_inventory') == 'started' then
		inventoryEnum = 1
	else
		inventoryEnum = 0
	end

	if inventoryEnum == 0 then
		if enforceRadioItemEnabled() and not silent and not depState.inventoryMissingLogged then
			depState.inventoryMissingLogged = true
			errorLog('ERR_RADIO_ITEM_INVENTORY_MISSING', 'No inventory detected but enforceRadioItem is enabled. Ensure you have either qb-inventory or ox_inventory installed. Sonoran Radio will re-check after 30 seconds.')
		end
	else
		local loggedMissing = depState.frameworkMissingLogged or depState.inventoryMissingLogged
		local shouldLogResolved = hasFrameworkInventory() and not depState.resolvedLogged and loggedMissing
		if shouldLogResolved then
			depState.resolvedLogged = true
			dependencyInfoLog('Framework and inventory dependencies detected. Sonoran Radio item integrations are now initializing.')
		end
	end

	return inventoryEnum
end

function getFramework(silent)
	if GetResourceState('qbx_core') == 'started' then
		frameworkEnum = 2
	elseif GetResourceState('qb-core') == 'started' then
		frameworkEnum = 1
	else
		frameworkEnum = 0
	end

	if frameworkEnum == 0 then
		if enforceRadioItemEnabled() and not silent and not depState.frameworkMissingLogged then
			depState.frameworkMissingLogged = true
			errorLog('ERR_RADIO_ITEM_FRAMEWORK_MISSING', 'No framework detected but enforceRadioItem is enabled. Ensure you have either qb-core or qbx_core installed. Sonoran Radio will re-check after 30 seconds.')
		end
	else
		local loggedMissing = depState.frameworkMissingLogged or depState.inventoryMissingLogged
		local shouldLogResolved = hasFrameworkInventory() and not depState.resolvedLogged and loggedMissing
		if shouldLogResolved then
			depState.resolvedLogged = true
			dependencyInfoLog('Framework and inventory dependencies detected. Sonoran Radio item integrations are now initializing.')
		end
	end

	return frameworkEnum
end

function hasFrameworkInventory()
	if not enforceRadioItemEnabled() then
		return true
	end

	return frameworkEnum ~= 0 and inventoryEnum ~= 0
end

local frameworkInventoryWatcherStarted = false
local function startFrameworkInventoryWatcher()
	if not enforceRadioItemEnabled() then
		return
	end

	getFramework()
	getInventory()

	if frameworkInventoryWatcherStarted or hasFrameworkInventory() then
		return
	end

	frameworkInventoryWatcherStarted = true
	Citizen.CreateThread(function()
		while enforceRadioItemEnabled() and not hasFrameworkInventory() do
			Citizen.Wait(30000)
			getFramework(true)
			getInventory(true)
		end
	end)
end

function waitForFrameworkInventory()
	startFrameworkInventoryWatcher()
	while enforceRadioItemEnabled() and not hasFrameworkInventory() do
		Citizen.Wait(1000)
	end
	return hasFrameworkInventory()
end

AddEventHandler('onResourceStart', function(resourceName)
	if not enforceRadioItemEnabled() then
		return
	end

	if
		resourceName == 'qb-core' or
		resourceName == 'qbx_core' or
		resourceName == 'qb-inventory' or
		resourceName == 'ox_inventory' or
		resourceName == 'qs-inventory' or
		resourceName == 'core_inventory'
	then
		getFramework(true)
		getInventory(true)
	end
end)
