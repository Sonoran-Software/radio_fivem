function initChatter()
	if Config.chatter == false then return end -- if chatter is disabled, skip this script

	local playerStates = {}
	RegisterNetEvent('SonoranRadio::ReceiveRadioStates', function(states)
		playerStates = states
	end)

	local function pedHasComponent(ped, componentId, drawableId, textureId)
		DebugPrint(('Checking is ped has valid chatter exception component. Ped: %s | Component ID: %s | Drawable ID: %s | Texture ID: %s'):format(ped, componentId, drawableId, textureId))
		local drawableOffset = 14
		if componentId >= drawableOffset then -- components 14 and above are props (hats, glasses, etc)
			DebugPrint('Component ID is a prop (over 14)')
			DebugPrint('Does Drawable ID match? ' .. tostring(GetPedDrawableVariation(ped, componentId - drawableOffset) == drawableId))
			DebugPrint('Does Texture ID match? ' .. tostring(not textureId or GetPedTextureVariation(ped, componentId - drawableOffset) == textureId ))
			return GetPedDrawableVariation(ped, componentId - drawableOffset) == drawableId and
				(not textureId or GetPedTextureVariation(ped, componentId - drawableOffset) == textureId)
		else
			DebugPrint('Component ID is not a prop (under 14)')
			DebugPrint('Does Drawable ID match? ' .. tostring(GetPedDrawableVariation(ped, componentId) == drawableId))
			DebugPrint('Does Texture ID match? ' .. tostring(not textureId or GetPedTextureVariation(ped, componentId) == textureId))
			return GetPedPropIndex(ped, componentId) == drawableId and
				(not textureId or GetPedPropTextureIndex(ped, componentId) == textureId)
		end
	end

	local function getPlayerScanList(ply)
		local state = playerStates[GetPlayerServerId(ply)]
		if not state then return nil end -- they don't have a state

		local scanList = {state.primaryChId}
		for _, chId in ipairs(state.scannedChIds) do
			table.insert(scanList, chId)
		end
		return scanList
	end

	-- used for debugging
	local psuedoChatterSources = {
		-- {pos = vec3(1759.71, 3245.96, 41.79), scanList = {6, 136}}
	}

	local CHATTER_MIN_DIST = 15.0
	local chatterSources = {}

	-- find the near players, and send the required channels to listen on
	Citizen.CreateThread(function()

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
				if not DoesEntityExist(ped) or #(GetEntityCoords(ped) - myPos) > CHATTER_MIN_DIST then
					goto continue
				end
				-- player doesn't have radio state, skip
				local scanList = getPlayerScanList(ply)
				if not scanList then
					goto continue
				end

				-- check if the ped is excluded from chatter because of a clothing item
				if type(chatterConfig) == 'table' then
					DebugPrint('Checking chatter exclusions')
					for _, exclusion in ipairs(chatterConfig) do
						for _, texture in ipairs(exclusion.texture) do
							local hasComponent = pedHasComponent(ped, exclusion.componentId, exclusion.drawableId, texture)
							DebugPrint('Has component: ' .. tostring(hasComponent))
							if hasComponent then
								DebugPrint('Excluded from chatter due to component ' .. exclusion.componentId)
								goto continue
							end
						end
					end
				end

				-- insert the chatter source
				table.insert(allChatterSources, {
					sourceEntity = ped,
					scanList = scanList,
				})
				::continue::
			end

			for _, source in ipairs(getScannerChatterSources()) do
				table.insert(allChatterSources, source)
			end
			if Config.debug and psuedoChatterSources then
				for _, source in ipairs(psuedoChatterSources) do
					table.insert(allChatterSources, source)
				end
			end
			chatterSources = allChatterSources

			Citizen.Wait(500)
		end
	end)

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
		local hasAnyWindows = false
		for windowIndex, boneName in pairs(windowBones) do
			local boneIndex = GetEntityBoneIndexByName(veh, boneName)
			if boneIndex >= 0 then
				hasAnyWindows = true
				if not IsVehicleWindowIntact(veh, windowIndex) then
					return false
				end
			end
		end
		return hasAnyWindows
	end
	local function doesVehicleHaveAllDoorsClosed(veh)
		local doorBones = {
			[0] = 'door_dside_f',
			[1] = 'door_pside_f',
			[2] = 'door_dside_r',
			[3] = 'door_pside_r',
		}
		local hasAnyDoors = false
		for doorIndex, boneName in pairs(doorBones) do
			local boneIndex = GetEntityBoneIndexByName(veh, boneName)
			if boneIndex >= 0 then
				hasAnyDoors = true
				if GetVehicleDoorAngleRatio(veh, doorIndex) > 0.05 then
					return false
				end
			end
		end
		return hasAnyDoors
	end
	local function isVehicleAudioMuffled(veh)
		return doesVehicleHaveAllDoorsClosed(veh) and doesVehicleHaveAllWindowsIntact(veh)
	end

	local function containsAll(tbl1, tbl2)
		local function countElements(tbl)
			local counts = {}
			for _, value in ipairs(tbl) do
				counts[value] = (counts[value] or 0) + 1
			end
			return counts
		end

		local counts1 = countElements(tbl1 or {})
		local counts2 = countElements(tbl2 or {})
		for key, count in pairs(counts1) do
			if counts2[key] ~= count then
				return false -- mismatched counts
			end
		end
		return true
	end

	-- keep chatter source positions updated
	Citizen.CreateThread(function()
		local last = {
			pos = nil,
			scanList = {},
			isMuffled = false,
			isSpatial = true,
		}
		while true do
			local closestSourcePos = nil
			local closestSourceDist = CHATTER_MIN_DIST
			local closestSourceInfo = nil
			-- find the closest chatter source
			-- NOTE: the closest is the only one that matters rn, since chatter only supports one source
			local myPos = GetFinalRenderedCamCoord()
			for _, info in ipairs(chatterSources) do
				local pos = DoesEntityExist(info.sourceEntity) and GetEntityCoords(info.sourceEntity) or info.pos
				if pos then
					local dist = #(myPos - pos)
					if dist < closestSourceDist then
						closestSourcePos = pos
						closestSourceDist = dist
						closestSourceInfo = info
					end
				end
			end

			local updatePayload

			-- reset the chatter sources if nothing is nearby
			if not closestSourceInfo and last.pos ~= nil then
				last.pos = nil
				updatePayload = {
					sources = {},
					channelIds = {},
					isMuffled = false,
					isSpatial = true,
				}
			elseif not closestSourceInfo then
				-- pass
			else
				-- whether or not spatiality should be applied
				local isSpatial = closestSourceInfo.sourceEntity ~= PlayerPedId()

				-- check if the closest source is muffled (ped in vehicle with all windows/doors closed)
				local isMuffled = false
				if isSpatial and DoesEntityExist(closestSourceInfo.sourceEntity) and IsEntityAPed(closestSourceInfo.sourceEntity) then
					local veh = GetVehiclePedIsIn(closestSourceInfo.sourceEntity, false)
					isMuffled = DoesEntityExist(veh) and isVehicleAudioMuffled(veh)
				end

				-- check if all conditions are the similar (if not, then update)
				local similar =
					isMuffled == last.isMuffled and
					isSpatial == last.isSpatial and
					(closestSourcePos == last.pos or not vectorChanged(closestSourcePos, last.pos, 1.0)) and
					containsAll(closestSourceInfo.scanList, last.scanList)
				if not similar then
					last.pos = closestSourcePos
					last.scanList = closestSourceInfo.scanList
					last.isMuffled = isMuffled
					last.isSpatial = isSpatial

					updatePayload = {
						sources = {closestSourcePos},
						channelIds = closestSourceInfo.scanList,
						isMuffled = isMuffled,
						isSpatial = isSpatial,
					}
				end
			end

			-- send update payload if given
			if updatePayload then
				updatePayload.type = 'chatterSourcesUpdate'
				SendNUIMessage(updatePayload)
			end

			Citizen.Wait(0)
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

	-- display location of psuedo chatter sources in world
	Citizen.CreateThread(function()
		while Config.debug and psuedoChatterSources do
			for _, source in ipairs(psuedoChatterSources) do
				local pos = source.pos -- TODO: include entities
				DrawMarker(1, pos.x, pos.y, pos.z, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 255, 0, 0, 255, false, false, 2, false, nil, nil, false)
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