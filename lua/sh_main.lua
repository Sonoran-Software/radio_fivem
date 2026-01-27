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

function errorLog(message)
	print('[Sonoran Radio - ERROR]:', '^1', message, '^0')
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
	-- Automatically select notification method if set to auto
	local AutoSelectedNotifyMethod = "native"
	if Config.notifications.type == "auto" then
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
	local notifications = Config and Config['notifications'] or {}
	local notificationType = ResolveNotifyMethod(Config.notifications.type)
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


frameworkEnum = 0;
inventoryEnum = 0;
-- Enums | 0 = None, 1 = QBCore, 2 = Ox_Inventory
function getInventory()
	if Config.enforceRadioItem then
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
			errorLog('[ERR-104] No inventory detected but enforceRadioItem is enabled. Ensure you have either qb-inventory or ox_inventory installed. https://sonoran.link/radiocodes')
		end
	end
end

function getFramework()
	if Config.enforceRadioItem then
		if GetResourceState('qbx_core') == 'started' then
			frameworkEnum = 2
			return
		elseif GetResourceState('qb-core') == 'started' then
			frameworkEnum = 1
			return
		else
			frameworkEnum = 0
			errorLog('[ERR-104] No framework detected but enforceRadioItem is enabled. Ensure you have either qb-core or qbx_core installed. https://sonoran.link/radiocodes')
		end
	end
end
