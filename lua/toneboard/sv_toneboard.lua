Speakers = {}

TriggerEvent('sonoranradio::RegisterPushEvent', 'PLAY_TONE', function(data)
    print("Received tone data: " .. json.encode(data))
    local tone = data.payload.src;
    print("Playing tone: " .. tone)
    local stationIds = data.payload.ids;
	print("Station IDs: " .. json.encode(stationIds))
	for i = 1, #Speakers do
		local speaker = Speakers[i]
		if speaker then
			for j = 1, #stationIds do
				local stationId = stationIds[j]
				if speaker.Id == stationId then
					print("Playing tone on speaker: " .. speaker.Id)
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
end)
