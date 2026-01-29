local plugin_handlers = {}

RegisterNetEvent('sonoranradio::RegisterPushEvent',
                 function(type, event) plugin_handlers[type] = event end)

SetHttpHandler(function(req, res)
    local path = req.path
    local method = req.method

    if method == 'GET' and path == '/events/ping' then
        res.writeHead(200, {['Content-Type'] = 'text/plain'})
        res.send('pong')
        return
    end

    if method == 'POST' and path == '/events' then
        req.setDataHandler(function(data)
            if not data then
                res.send(json.encode({['error'] = 'bad request'}))
                return
            end
            local body = json.decode(data)
            if not body then
                res.send(json.encode({['error'] = 'bad request'}))
                return
            end
            if body.key and body.key:upper() == Config.apiKey:upper() then
                if plugin_handlers[body.type] ~= nil then
                    plugin_handlers[body.type](body)
                    res.send('ok')
                    return
                else
                    TriggerEvent('SonoranRadio::core:writeLog', 'debug', 'Received push event for unregistered type: ' .. tostring(body.type))
                    res.send('Event not registered')
                end
            else
                TriggerEvent('SonoranRadio::core:writeLog', 'debug', 'Received push event with invalid API key.')
                res.send('Bad API Key')
                return
            end
        end)
    end
end)
