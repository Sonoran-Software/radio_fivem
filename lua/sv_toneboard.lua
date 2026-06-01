Speakers = {}

TriggerEvent('sonoranradio::RegisterPushEvent', 'play_tone', function(data)
	DebugPrint('Received play_tone event from radio service.', json.encode(data))
    local tone = data.payload.src;
    local stationIds = data.payload.ids;
	local tones = {}
	for j = 1, #stationIds do
		for i = 1, #Speakers do
			local speaker = Speakers[i]
			local stationId = stationIds[j]
			if speaker then
				if speaker.Id == stationId then
					table.insert(tones, {speaker = speaker, tone = tone})
				end
			end
		end
	end
	TriggerClientEvent('SonoranRadio:PlayTone', -1, tones)
end)

RegisterNetEvent('SonoranRadio::SyncSpeakers')
AddEventHandler('SonoranRadio::SyncSpeakers', function()
	local source = source
	while #Speakers == 0 do
		Wait(10)
	end
	TriggerClientEvent('SonoranRadio:SyncSpeakers', source, Speakers)
	local locations = {}
	for _, speaker in ipairs(Speakers) do
		table.insert(locations, {
			['label'] = speaker.Label,
			['id'] = speaker.Id,
			['group'] = speaker.group or ''
		})
	end
	DebugPrint('Sending speaker locations to radio service based upon call to SonoranRadio::SyncSpeakers' ..  json.encode(locations))
	exports['sonoranradio']:performApiRequest({
		['locations'] = locations
	}, 'SET-SERVER-SPEAKERS', function(data, success)
		if not success then
			errorLog('ERR_SERVER_SPEAKERS_SET_FAILED', 'Failed to set server speakers for radio service. Please check your configuration.')
		end
	end)
end)
