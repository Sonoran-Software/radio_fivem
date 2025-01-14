Speakers = {}

TriggerEvent('sonoranradio::RegisterPushEvent', 'play_tone', function(data)
	DebugPrint('Received play_tone event from radio service.', json.encode(data))
    local tone = data.payload.src;
    local stationIds = data.payload.ids;
	for i = 1, #Speakers do
		local speaker = Speakers[i]
		if speaker then
			for j = 1, #stationIds do
				local stationId = stationIds[j]
				if speaker.Id == stationId then
					TriggerClientEvent('SonoranRadio:PlayTone', -1, speaker, tone)
				end
			end
		end
	end
end)

RegisterNetEvent('SonoranRadio::SyncSpeakers')
AddEventHandler('SonoranRadio::SyncSpeakers', function()
	local source = source
	while #Speakers == 0 do
		Wait(10)
	end
	TriggerClientEvent('SonoranRadio:SyncSpeakers', source, Speakers)
	exports['sonoranradio']:performApiRequest({
		['id'] = Config.comId,
		['key'] = Config.apiKey,
		['locations'] = locations
	}, 'SET-SERVER-SPEAKERS', function(data, success)
		if not success then
			errorLog('Failed to set server speakers for radio service. Please check your configuration.')
		end
	end)
end)
