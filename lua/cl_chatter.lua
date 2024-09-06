if not Config.chatter then return end -- if chatter is disabled, skip this script

local chatterSources = {}

-- find the near players, and send the required freqs to listen on
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

			local plyObj = ply == PlayerId() and LocalPlayer or Player(ply)
			local state = plyObj.state['sonoranradio_state']
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
		print('chatter players', json.encode(chatterSourcePlayers))

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
		print('chatter freqs', json.encode(listenFreqs))

		Citizen.Wait(500)
	end
end)

local function getForwardVector(pitch, yaw)
	pitch = math.rad(pitch)
	yaw = math.rad(yaw)
	local x = -math.sin(yaw) * math.cos(pitch)
	local y = math.cos(yaw) * math.cos(pitch)
	local z = math.sin(pitch)

	return vec3(x, y, z)
end
local function getUpVector(roll)
	roll = math.rad(roll)
	local x = math.sin(roll)
	local y = 0
	local z = math.cos(roll)
	return vec3(x, y, z)
end
local function vectorChanged(cur, last, threshold)
	threshold = threshold or 0.05
	if not last then
		return true
	end
	return #(cur - last) > threshold
end

Citizen.CreateThread(function()
	local throttleMillis = 20
	local lastUpdate = 0
	local lastCount = 0
	while true do
		local needsUpdate = lastCount ~= #chatterSources
		lastCount = #chatterSources

		local sourcePositions = {}
		for _, info in ipairs(chatterSources) do
			local pos = GetEntityCoords(GetPlayerPed(info.player))
			if vectorChanged(pos, info.pos, 1.0) then
				needsUpdate = true
				info.pos = pos
			end
			table.insert(sourcePositions, pos)
		end

		if needsUpdate then
			local myPos = GetFinalRenderedCamCoord()
			table.sort(sourcePositions, function(a, b)
				return #(a - myPos) < #(b - myPos)
			end)

			-- wait for the throttle
			local diff = lastUpdate + throttleMillis - GetGameTimer()
			if diff > 0 then
				Citizen.Wait(diff)
			end
			SendNUIMessage({
				type = 'chatterSourcesUpdate',
				sources = sourcePositions,
			})
		end
		Citizen.Wait(0)
	end
end)

-- keep the camera position and rotation updated
Citizen.CreateThread(function()
	local throttleMillis = 20
	local lastUpdate = 0

	local lastCoord, lastForward, lastUp
	while true do
		local coord = GetFinalRenderedCamCoord()

		local rot = GetFinalRenderedCamRot(2)
		local forward = getForwardVector(rot.x, rot.z)
		local up = getUpVector(rot.y)

		local needsUpdate = vectorChanged(coord, lastCoord, 1.0) or vectorChanged(forward, lastForward) or vectorChanged(up, lastUp)
		if needsUpdate and GetGameTimer() - lastUpdate > throttleMillis then
			lastUpdate = GetGameTimer()
			lastCoord = coord
			lastForward = forward
			lastUp = up

			SendNUIMessage({
				type = 'chatterCameraUpdate',
				coord = coord,
				forward = forward,
				up = up,
			})
		end

		Citizen.Wait(0)
	end
end)
