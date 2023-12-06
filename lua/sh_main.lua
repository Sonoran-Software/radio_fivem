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
