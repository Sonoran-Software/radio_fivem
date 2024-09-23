Citizen.CreateThread(function()
	while true do
		Wait(0)
		if isTalking and Config.talkSync then
			SetControlNormal(0, 249, 1.0);
		end
        if nuiFocused then -- Disable controls while NUI is focused.
            DisableControlAction(0, 1, nuiFocused) -- LookLeftRight
            DisableControlAction(0, 2, nuiFocused) -- LookUpDown
            DisableControlAction(0, 142, nuiFocused) -- MeleeAttackAlternate
            DisableControlAction(0, 106, nuiFocused) -- VehicleMouseControlOverride
        end
	end
end)

Citizen.CreateThread(function()
	local MIN_DIST = 15.0

	while true do
		local chatterSourcePlayers = {}
		local myPos = GetFinalRenderedCamCoord()
		-- create or update close players in chatterSources
		for _, ply in ipairs(GetActivePlayers()) do
			if ply == PlayerId() then
				goto continue
			end

			local ped = GetPlayerPed(ply)
			if not DoesEntityExist(ped) or #(GetEntityCoords(ped) - myPos) > MIN_DIST then
				goto continue
			end

			local state = playerStates[GetPlayerServerId(ply)]
			if state then
				-- find the index of the existing chatter source
				local idx = 0
				for i = 1, #chatterSources do
					if chatterSources[i].player == ply then
						idx = i
						break
					end
				end
				if idx > 0 then
					chatterSources[idx].state = state
				else
					table.insert(chatterSources, {player = ply, state = state})
				end

				table.insert(chatterSourcePlayers, ply)
			end
			::continue::
		end

		-- remove players that are not chatter sources anymore
		for i = #chatterSources, 1, -1 do
			local keep = false
			for _, ply in ipairs(chatterSourcePlayers) do
				if chatterSources[i].player == ply then
					keep = true
					break
				end
			end
			if not keep then
				table.remove(chatterSources, i)
			end
		end

		-- find the frequencies we need to listen to for chatter
		local listenFreqs = {}
		local function addChatterFreq(freq)
			-- verify if the freq is already in the list
			for i = 1, #listenFreqs do
				if listenFreqs[i][1] == freq[1] and listenFreqs[i][2] == freq[2] then
					return
				end
			end
			table.insert(listenFreqs, freq)
		end
		for _, info in ipairs(chatterSources) do
			addChatterFreq(info.state.freqRecv)
			for i = 1, #info.state.freqScan do
				addChatterFreq(info.state.freqScan[i])
			end
		end
		SendNUIMessage({
			type = 'chatterFrequenciesUpdate',
			freqs = listenFreqs,
		})
        if #playingSpeakers == 0 then goto continueSpeaker end
        local playerPos = GetEntityCoords(GetPlayerPed(-1));
        local playerHeading = GetEntityHeading(GetPlayerPed(-1));
        for _, v in pairs(playingSpeakers) do
            local propPos = GetSpeakerCoords(v);
            SendNUIMessage({
                name = v.Id,
                status = "updateSound",
                playerX = playerPos.x,
                playerY = playerPos.y,
                playerZ = playerPos.z,
                playerHeading = playerHeading,
                speakerX = v.PropPosition.x,
                speakerY = v.PropPosition.y,
                speakerZ = v.PropPosition.z,
                maxDistance = v.Range,
                xsound = true,
                distance = #(playerPos - propPos)
            })
        end
        ::continueSpeaker::
		Citizen.Wait(500)
	end
end)