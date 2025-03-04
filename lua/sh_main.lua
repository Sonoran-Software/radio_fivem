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

function showNotification(notification, urgent)
	if urgent == nil then
		urgent = true
	end
	SetNotificationTextEntry('STRING')
	AddTextComponentString(notification)
	DrawNotification(urgent, true)
end

function notifyClient(notification, urgent)
	if Config['notifications']['type'] == 'native' then
		showNotification('~b~[SonoranRadio] ~w~' .. notification, urgent)
	elseif Config['notifications']['type'] == 'okokNotify' then
		exports['okokNotify']:Alert('SonoranRadio', '' .. notification, 10000, 'info')
	elseif Config['notifications']['type'] == 'pNotify' then
		exports.pNotify:SendNotification({
			['type'] = 'info',
			['text'] = '~b~[SonoranRadio] ~w~' .. notification
		})
	elseif Config['notifications']['type'] == 'custom' then
		Config['notifications']['custom'](notification)
    elseif Config['notifications']['type'] == 'chat' then
        TriggerEvent('chat:addMessage', {
            template = '<div class="chat-message sonoran-radio"><b>SonoranRadio</b> {0}</div>',
            args = { notification }
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