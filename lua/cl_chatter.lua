function initChatter()
	if Config.chatter == false then return end -- if chatter is disabled, skip this script

	local playerStates = {}
	RegisterNetEvent('SonoranRadio::ReceiveRadioStates', function(states)
		playerStates = states
	end)

	local function pedHasComponent(ped, componentId, drawableId, textureId)
		local drawableOffset = 14
		if componentId >= drawableOffset then -- components 14 and above are props (hats, glasses, etc)
			return GetPedDrawableVariation(ped, componentId - drawableOffset) == drawableId and
				(not textureId or GetPedTextureVariation(ped, componentId - drawableOffset) == textureId - 1)
		else
			return GetPedPropIndex(ped, componentId) == drawableId and
				(not textureId or GetPedPropTextureIndex(ped, componentId) == textureId - 1)
		end
	end

	local chatterSources = {}

	-- find the near players, and send the required channels to listen on
	Citizen.CreateThread(function()
		local MIN_DIST = 15.0

		while true do
			local allChatterSources = {}
			local myPos = GetFinalRenderedCamCoord()
			-- create or update close players in chatterSources
			for _, ply in ipairs(GetActivePlayers()) do
				-- player is me, skip
				if ply == PlayerId() then
					goto continue
				end
				-- player not close enough, skip
				local ped = GetPlayerPed(ply)
				if not DoesEntityExist(ped) or #(GetEntityCoords(ped) - myPos) > MIN_DIST then
					goto continue
				end
				-- player doesn't have radio state, skip
				local state = playerStates[GetPlayerServerId(ply)]
				if not state then
					goto continue
				end

				-- check if the ped is excluded from chatter because of a clothing item
				if type(Config.chatterExclusions) == 'table' then
					for _, exclusion in ipairs(Config.chatterExclusions) do
						if pedHasComponent(ped, exclusion.componentId, exclusion.drawableId, exclusion.texture) then
							goto continue
						end
					end
				end

				-- insert the chatter source
				table.insert(allChatterSources, {player = ply, state = state})
				::continue::
			end

			-- find whether the closest source is an emergency call
			local closest = math.huge
			local closestIsEmergencyCall = false
			for i = 1, #allChatterSources do
				local cs = allChatterSources[i]
				local dist = #(GetEntityCoords(GetPlayerPed(cs.player)) - myPos)
				if dist < closest then
					closest = dist
					closestIsEmergencyCall = type(cs.state.primaryChId) == 'string'
				end
			end

			-- filter out emergency or non-emergency sources based on closestIsEmergencyCall
			for i = #allChatterSources, 1, -1 do
				local isEmergencyCall = type(allChatterSources[i].state.primaryChId) == 'string'
				if isEmergencyCall ~= closestIsEmergencyCall then
					table.remove(allChatterSources, i)
				end
			end

			chatterSources = allChatterSources

			-- find the frequencies we need to listen to for chatter
			-- duplicates don't matter because it's handled in the frontend
			local listenChannelIds = {}
			for _, info in ipairs(chatterSources) do
				if info.state.spec ~= 2 then goto continue end

				table.insert(listenChannelIds, info.state.primaryChId)
				for i = 1, #info.state.scannedChIds do
					table.insert(listenChannelIds, info.state.scannedChIds[i])
				end
				::continue::
			end
			SendNUIMessage({
				type = 'chatterChannelsUpdate',
				channelIds = listenChannelIds,
			})

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
		if not cur or not last then
			return true
		end
		return #(cur - last) > threshold
	end

	local function doesVehicleHaveAllWindowsIntact(veh)
		local windowBones = {
			[0] = 'window_lf',
			[1] = 'window_rf',
			[2] = 'window_lr',
			[3] = 'window_rr',
			-- tbh idk what these windows are
			[4] = 'window_lm',
			[5] = 'window_rm',
			--
			[6] = 'windscreen',
			[7] = 'windscreen_r',
		}
		for windowIndex, boneName in pairs(windowBones) do
			local boneIndex = GetEntityBoneIndexByName(veh, boneName)
			if boneIndex >= 0 and not IsVehicleWindowIntact(veh, windowIndex) then
				return false
			end
		end
		return true
	end

	-- keep chatter source positions updated
	Citizen.CreateThread(function()
		local throttleMillis = 20
		local lastUpdate = 0
		local lastPos = nil
		local lastIsMuffled = false
		while true do
			local closestSourcePly = nil
			local closestSourcePos = nil
			local closestSourceDist = math.huge

			-- find the closest chatter source
			-- NOTE: the closest is the only one that matters rn, since chatter only supports one source
			local myPos = GetFinalRenderedCamCoord()
			for _, info in ipairs(chatterSources) do
				local pos = GetEntityCoords(GetPlayerPed(info.player))
				local dist = #(myPos - pos)
				if dist < closestSourceDist then
					closestSourceDist = dist
					closestSourcePos = pos
					closestSourcePly = info.player
				end
			end

			-- check if the closest source is muffled
			local isMuffled = false
			local ped = GetPlayerPed(closestSourcePly)
			if DoesEntityExist(ped) then
				local veh = GetVehiclePedIsIn(ped, false)
				isMuffled = DoesEntityExist(veh) and doesVehicleHaveAllWindowsIntact(veh)
			end

			local needsUpdate = (closestSourcePos ~= lastPos and vectorChanged(closestSourcePos, lastPos, 1.0)) or isMuffled ~= lastIsMuffled
			if needsUpdate then
				lastPos = closestSourcePos
				lastIsMuffled = isMuffled

				local sources = closestSourcePos ~= nil and {closestSourcePos} or {}
				SendNUIMessage({
					type = 'chatterSourcesUpdate',
					sources = sources,
					isMuffled = isMuffled,
				})

				-- wait for the throttle
				local diff = lastUpdate + throttleMillis - GetGameTimer()
				if diff > 0 then
					Citizen.Wait(diff)
					lastUpdate = GetGameTimer()
				end
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
	CreateThread(function()
		while not NetworkIsPlayerActive(PlayerId()) do
			Wait(10)
		end
		TriggerServerEvent('Chatter:clientChatterSync')
		while #chatterConfig == 0 do
			Wait(50)
		end
	end)
	RegisterNetEvent('Chatter:clientChatterSync_c', function(chatterConfigServer)
		chatterConfig = chatterConfigServer
		for index, _ in ipairs(chatterConfig) do
			if not WarMenu.DoesMenuExist('editItem_' .. index) then
				WarMenu.CreateSubMenu('editItem_' .. index, 'chatterMenu', 'Edit Item ' .. index)
			end
		end
	end)
end