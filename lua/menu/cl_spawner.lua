local state = {
	index = 1,
	repeaterId = nil,
	moveSpeed = 0.05
}
local radioScaleform = nil

CreateThread(function()
	radioScaleform = RequestScaleformMovie('INSTRUCTIONAL_BUTTONS')
	while not HasScaleformMovieLoaded(radioScaleform) do
		Wait(0)
	end
end)

Citizen.CreateThread(function()
	WarMenu.CreateMenu('sonoranRadioMenu', 'Radio Repeater Menu')
	WarMenu.SetTitleColor('sonoranRadioMenu', 0, 0, 0, 255)
	WarMenu.SetMenuTitleBackgroundSprite('sonoranRadioMenu', 'radio_menu_header', 'option_1')
	WarMenu.SetSubTitle('sonoranRadioMenu', 'Sonoran Software')
	WarMenu.CreateSubMenu('spawnRadioMenu', 'sonoranRadioMenu', 'Spawn Repeater')
	WarMenu.SetMenuTitleBackgroundSprite('spawnRadioMenu', 'radio_menu_header', 'option_1')
	WarMenu.CreateSubMenu('moveRadioMenu', 'sonoranRadioMenu', 'Move Repeater')
	WarMenu.SetMenuTitleBackgroundSprite('moveRadioMenu', 'radio_menu_header', 'option_1')
	WarMenu.CreateSubMenu('deleteRadioMenu', 'sonoranRadioMenu', 'Delete Repeater')
	WarMenu.SetMenuTitleBackgroundSprite('deleteRadioMenu', 'radio_menu_header', 'option_1')
	while true do
		if WarMenu.IsMenuOpened('sonoranRadioMenu') then -- Main menu processing
			if WarMenu.MenuButton('Spawn Repeater', 'spawnRadioMenu') then
			end
			if WarMenu.MenuButton('Move Repeater', 'moveRadioMenu') then
			end
			if WarMenu.MenuButton('Delete Repeater', 'deleteRadioMenu') then
			end
			WarMenu.Display()
		elseif WarMenu.IsMenuOpened('spawnRadioMenu') then
			spawningRadioRepeater()
			WarMenu.Display()
		elseif WarMenu.IsMenuOpened('moveRadioMenu') then
			movingRadioRepeater()
			WarMenu.Display()
		elseif WarMenu.IsMenuOpened('deleteRadioMenu') then
			deletingRadioRepeater()
			WarMenu.Display()
		end
		Wait(0)
	end
end)

function spawningRadioRepeater()
	local radioRepeaters = {
		'Cell Repeater',
		'Radio Tower',
		'Server Rack'
	}
	if WarMenu.ComboBox('Prop Type:', radioRepeaters, state.index, state.index, function(current)
		state.index = current
	end) then
		local propName = radioRepeaters[state.index];
		if propName == 'Cell Repeater' then
			AddTextEntry('FMMC_MPM_NAA', 'Range: (Default: 1500.0) - Leave blank for default')
			DisplayOnscreenKeyboard(1, 'FMMC_MPM_NAA', 'Range: (Default: 1500.0) - Leave blank for default', '1500.0', '', '', '', 20)
			while (UpdateOnscreenKeyboard() == 0) do
				DisableAllControlActions(0);
				Wait(0)
			end
			local range = ''
			if UpdateOnscreenKeyboard() == 2 then
				range = 1500.0
			end
			if (UpdateOnscreenKeyboard() == 1 and GetOnscreenKeyboardResult()) then
				local input = GetOnscreenKeyboardResult()
				if input == '' then
					range = 1500.0
				else
					range = tonumber(input)
				end
			end
			if range then
				local cellRepeaterData = {
					Id = uuid(),
					Destruction = true,
					NotPhysical = false,
					Swankiness = 0.0,
					PropPosition = GetEntityCoords(PlayerPedId()),
					Range = range,
					AntennaStatus = 'alive',
					Powered = true,
					DontSaveMe = false,
					heading = GetEntityHeading(PlayerPedId()),
					type = 'cellRepeater'
				}
				state.repeaterId = cellRepeaterData.Id
				TriggerEvent('CellRepeater:SpawnCell', cellRepeaterData)
				WarMenu.OpenMenu('moveRadioMenu')
			else
				TriggerEvent('chat:addMessage', {
					color = {
						255,
						0,
						0
					},
					multiline = true,
					args = {
						'Error',
						'Invalid range. It must be a number'
					}
				})
			end
		elseif propName == 'Radio Tower' then
			AddTextEntry('FMMC_MPM_NAA', 'Range: (Default: 1500.0) - Leave blank for default')
			DisplayOnscreenKeyboard(1, 'FMMC_MPM_NAA', 'Range: (Default: 1500.0) - Leave blank for default', '1500.0', '', '', '', 20)
			while (UpdateOnscreenKeyboard() == 0) do
				DisableAllControlActions(0);
				Wait(0)
			end
			local range = ''
			if UpdateOnscreenKeyboard() == 2 then
				range = 1500.0
			end
			if (UpdateOnscreenKeyboard() == 1 and GetOnscreenKeyboardResult()) then
				local input = GetOnscreenKeyboardResult()
				if input == '' then
					range = 1500.0
				else
					range = tonumber(input)
				end
			end
			if range then
				local towerData = {
					Id = uuid(),
					Destruction = true,
					NotPhysical = false,
					Swankiness = 0.0,
					PropPosition = GetEntityCoords(PlayerPedId()),
					Range = range,
					DishStatus = {
						'alive',
						'alive',
						'alive',
						'alive'
					},
					Powered = true,
					DontSaveMe = false,
					type = 'radioTower'
				}
				state.repeaterId = towerData.Id
				TriggerEvent('RadioTower:SpawnTower', towerData)
				WarMenu.OpenMenu('moveRadioMenu')
			else
				TriggerEvent('chat:addMessage', {
					color = {
						255,
						0,
						0
					},
					multiline = true,
					args = {
						'Error',
						'Invalid range. It must be a number'
					}
				})
			end
		elseif propName == 'Server Rack' then
			AddTextEntry('FMMC_MPM_NAA', 'Range: (Default: 1500.0) - Leave blank for default')
			DisplayOnscreenKeyboard(1, 'FMMC_MPM_NAA', 'Range: (Default: 1500.0) - Leave blank for default', '1500.0', '', '', '', 20)
			while (UpdateOnscreenKeyboard() == 0) do
				DisableAllControlActions(0);
				Wait(0)
			end
			local range = ''
			if UpdateOnscreenKeyboard() == 2 then
				range = 1500.0
			end
			if (UpdateOnscreenKeyboard() == 1 and GetOnscreenKeyboardResult()) then
				local input = GetOnscreenKeyboardResult()
				if input == '' then
					range = 1500.0
				else
					range = tonumber(input)
				end
			end
			AddTextEntry('FMMC_MPM_NAA', 'Server Count: (Default: 5) - Leave blank for default - Max 5')
			DisplayOnscreenKeyboard(1, 'FMMC_MPM_NAA', 'Server Count: (Default: 5) - Leave blank for default - Max 5', '5', '', '', '', 20)
			while (UpdateOnscreenKeyboard() == 0) do
				DisableAllControlActions(0);
				Wait(0)
			end
			local serverCount = ''
			if UpdateOnscreenKeyboard() == 2 then
				serverCount = 5
			end
			if (UpdateOnscreenKeyboard() == 1 and GetOnscreenKeyboardResult()) then
				local input = GetOnscreenKeyboardResult()
				if input == '' then
					serverCount = 5
				else
					serverCount = tonumber(input)
				end
			end
			if range and serverCount then
				local rackData = {
					Id = uuid(),
					Destruction = true,
					NotPhysical = false,
					Swankiness = 0.0,
					PropPosition = GetEntityCoords(PlayerPedId()),
					Range = range,
					serverStatus = {},
					Powered = true,
					DontSaveMe = false,
					heading = GetEntityHeading(PlayerPedId()),
					type = 'serverRack'
				}
				for i = 1, serverCount do
					table.insert(rackData.serverStatus, 'alive')
				end
				state.repeaterId = rackData.Id
				TriggerEvent('RadioRacks:SpawnRack', rackData)
				WarMenu.OpenMenu('moveRadioMenu')
			else
				TriggerEvent('chat:addMessage', {
					color = {
						255,
						0,
						0
					},
					multiline = true,
					args = {
						'Error',
						'Invalid range or server count. It must be a number. Max server count is 5'
					}
				})
			end
		end
	end
end

function movingRadioRepeater()
	local radioRepeaters = {};
	local radioRepeatersLabel = {};
	for _, repeater in ipairs(CellRepeaters) do
		table.insert(radioRepeatersLabel, string.sub(repeater.Id, 1, 10) .. '...')
		table.insert(radioRepeaters, repeater.Id)
	end
	for _, repeater in ipairs(Towers) do
		table.insert(radioRepeatersLabel, string.sub(repeater.Id, 1, 10) .. '...')
		table.insert(radioRepeaters, repeater.Id)
	end
	for _, repeater in ipairs(racks) do
		table.insert(radioRepeatersLabel, string.sub(repeater.Id, 1, 10) .. '...')
		table.insert(radioRepeaters, repeater.Id)
	end
	if WarMenu.ComboBox('Select Repeater:', radioRepeatersLabel, state.index, state.index, function(current)
		state.index = current
		state.repeaterId = radioRepeaters[current]
	end) then
	end
	if WarMenu.Button('Confirm Placement') then
		confirmRadioPlacement()
		WarMenu.OpenMenu('sonoranRadioMenu')
	end
	local foundHandle = nil;
	for _, repeater in ipairs(CellRepeaters) do
		if repeater.Id == state.repeaterId then
			foundHandle = repeater
			break
		end
	end
	for _, repeater in ipairs(Towers) do
		if repeater.Id == state.repeaterId then
			foundHandle = repeater
			break
		end
	end
	for _, repeater in ipairs(racks) do
		if repeater.Id == state.repeaterId then
			foundHandle = repeater
			break
		end
	end
	if foundHandle then
		local pressed, input = WarMenu.InputButton('Repeater Range', 'Rpeater Range (Default 1500.0)', tostring(foundHandle.Range), 20, 20)
		if pressed then
			if input == '' then
				foundHandle.Range = 1500.0
			else
				foundHandle.Range = tonumber(input)
			end
		end
		DrawMarker(0, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z + 1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 255, 0, 0, 200, true, true, 2, false, nil, nil,
		           false)
		if foundHandle.type ~= 'serverRack' then
			if IsControlPressed(0, 108) and GetLastInputMethod(0) then -- Movement Keys
				local array = {
					x = foundHandle.PropPosition.x,
					y = foundHandle.PropPosition.y,
					z = foundHandle.PropPosition.z
				}
				array.x = array.x + state.moveSpeed
				foundHandle.PropPosition = vec3(array.x, array.y, array.z)
				SetEntityCoords(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading)
			elseif IsControlPressed(0, 107) and GetLastInputMethod(0) then
				local array = {
					x = foundHandle.PropPosition.x,
					y = foundHandle.PropPosition.y,
					z = foundHandle.PropPosition.z
				}
				array.x = array.x - state.moveSpeed
				foundHandle.PropPosition = vec3(array.x, array.y, array.z)
				SetEntityCoords(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading)
			elseif IsControlPressed(0, 112) and GetLastInputMethod(0) then
				local array = {
					x = foundHandle.PropPosition.x,
					y = foundHandle.PropPosition.y,
					z = foundHandle.PropPosition.z
				}
				array.y = array.y + state.moveSpeed
				foundHandle.PropPosition = vec3(array.x, array.y, array.z)
				SetEntityCoords(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading)
			elseif IsControlPressed(0, 111) and GetLastInputMethod(0) then
				local array = {
					x = foundHandle.PropPosition.x,
					y = foundHandle.PropPosition.y,
					z = foundHandle.PropPosition.z
				}
				array.y = array.y - state.moveSpeed
				foundHandle.PropPosition = vec3(array.x, array.y, array.z)
				SetEntityCoords(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading)
			elseif IsControlPressed(0, 314) and GetLastInputMethod(0) then
				local array = {
					x = foundHandle.PropPosition.x,
					y = foundHandle.PropPosition.y,
					z = foundHandle.PropPosition.z
				}
				array.z = array.z + state.moveSpeed
				foundHandle.PropPosition = vec3(array.x, array.y, array.z)
				SetEntityCoords(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading)
			elseif IsControlPressed(0, 315) and GetLastInputMethod(0) then
				local array = {
					x = foundHandle.PropPosition.x,
					y = foundHandle.PropPosition.y,
					z = foundHandle.PropPosition.z
				}
				array.z = array.z - state.moveSpeed
				foundHandle.PropPosition = vec3(array.x, array.y, array.z)
				SetEntityCoords(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading)
			elseif IsControlPressed(0, 118) and GetLastInputMethod(0) then
				foundHandle.heading = foundHandle.heading + state.moveSpeed
				SetEntityCoords(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading)
			elseif IsControlPressed(0, 117) and GetLastInputMethod(0) then
				foundHandle.heading = foundHandle.heading - state.moveSpeed
				SetEntityCoords(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading)
			elseif IsControlJustReleased(0, 21) and GetLastInputMethod(0) then
				if state.moveSpeed < 2.0 then
					state.moveSpeed = state.moveSpeed + 0.001
				else
					ShowNotification('Cannot Move Faster')
				end
			elseif IsControlJustReleased(0, 132) and GetLastInputMethod(0) then
				if state.moveSpeed > 0.001 then
					state.moveSpeed = state.moveSpeed - 0.001
				else
					ShowNotification('Cannot move slower')
				end
			end
		else
			if IsControlPressed(0, 108) and GetLastInputMethod(0) then -- Movement Keys
				local array = {
					x = foundHandle.PropPosition.x,
					y = foundHandle.PropPosition.y,
					z = foundHandle.PropPosition.z
				}
				array.x = array.x + state.moveSpeed
				foundHandle.PropPosition = vec3(array.x, array.y, array.z)
				SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading)
			elseif IsControlPressed(0, 107) and GetLastInputMethod(0) then
				local array = {
					x = foundHandle.PropPosition.x,
					y = foundHandle.PropPosition.y,
					z = foundHandle.PropPosition.z
				}
				array.x = array.x - state.moveSpeed
				foundHandle.PropPosition = vec3(array.x, array.y, array.z)
				SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading)
			elseif IsControlPressed(0, 112) and GetLastInputMethod(0) then
				local array = {
					x = foundHandle.PropPosition.x,
					y = foundHandle.PropPosition.y,
					z = foundHandle.PropPosition.z
				}
				array.y = array.y + state.moveSpeed
				foundHandle.PropPosition = vec3(array.x, array.y, array.z)
				SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading)
			elseif IsControlPressed(0, 111) and GetLastInputMethod(0) then
				local array = {
					x = foundHandle.PropPosition.x,
					y = foundHandle.PropPosition.y,
					z = foundHandle.PropPosition.z
				}
				array.y = array.y - state.moveSpeed
				foundHandle.PropPosition = vec3(array.x, array.y, array.z)
				SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading)
			elseif IsControlPressed(0, 314) and GetLastInputMethod(0) then
				local array = {
					x = foundHandle.PropPosition.x,
					y = foundHandle.PropPosition.y,
					z = foundHandle.PropPosition.z
				}
				array.z = array.z + state.moveSpeed
				foundHandle.PropPosition = vec3(array.x, array.y, array.z)
				SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading)
			elseif IsControlPressed(0, 315) and GetLastInputMethod(0) then
				local array = {
					x = foundHandle.PropPosition.x,
					y = foundHandle.PropPosition.y,
					z = foundHandle.PropPosition.z
				}
				array.z = array.z - state.moveSpeed
				foundHandle.PropPosition = vec3(array.x, array.y, array.z)
				SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading)
			elseif IsControlPressed(0, 118) and GetLastInputMethod(0) then
				foundHandle.heading = foundHandle.heading + state.moveSpeed
				SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading)
			elseif IsControlPressed(0, 117) and GetLastInputMethod(0) then
				foundHandle.heading = foundHandle.heading - state.moveSpeed
				SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading)
			elseif IsControlJustReleased(0, 21) and GetLastInputMethod(0) then
				if state.moveSpeed < 2.0 then
					state.moveSpeed = state.moveSpeed + 0.001
				else
					ShowNotification('Cannot Move Faster')
				end
			elseif IsControlJustReleased(0, 132) and GetLastInputMethod(0) then
				if state.moveSpeed > 0.001 then
					state.moveSpeed = state.moveSpeed - 0.001
				else
					ShowNotification('Cannot move slower')
				end
			end
		end
		BeginScaleformMovieMethod(radioScaleform, 'CLEAR_ALL')
		EndScaleformMovieMethod()

		BeginScaleformMovieMethod(radioScaleform, 'SET_DATA_SLOT')
		ScaleformMovieMethodAddParamInt(0)
		PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 108))
		PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 107))
		PushScaleformMovieMethodParameterString('Move X')
		EndScaleformMovieMethod()

		BeginScaleformMovieMethod(radioScaleform, 'SET_DATA_SLOT')
		ScaleformMovieMethodAddParamInt(1)
		PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 112))
		PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 111))
		PushScaleformMovieMethodParameterString('Move Y')
		EndScaleformMovieMethod()

		BeginScaleformMovieMethod(radioScaleform, 'SET_DATA_SLOT')
		ScaleformMovieMethodAddParamInt(2)
		PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 314))
		PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 315))
		PushScaleformMovieMethodParameterString('Move Z')
		EndScaleformMovieMethod()

		BeginScaleformMovieMethod(radioScaleform, 'SET_DATA_SLOT')
		ScaleformMovieMethodAddParamInt(3)
		PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 118))
		PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 117))
		PushScaleformMovieMethodParameterString('Rotate')
		EndScaleformMovieMethod()

		BeginScaleformMovieMethod(radioScaleform, 'SET_DATA_SLOT')
		ScaleformMovieMethodAddParamInt(6)
		PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 21))
		PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 36))
		PushScaleformMovieMethodParameterString('Change Speed')
		EndScaleformMovieMethod()

		BeginScaleformMovieMethod(radioScaleform, 'DRAW_INSTRUCTIONAL_BUTTONS')
		ScaleformMovieMethodAddParamInt(0)
		EndScaleformMovieMethod()
		DrawScaleformMovieFullscreen(radioScaleform, 255, 255, 255, 255, 0)
	end
end

function confirmRadioPlacement()
	state.repeaterId = nil
	state.index = 1
	TriggerServerEvent('SonoranRadio::MoveProp', CellRepeaters, Towers, racks)
end

function deletingRadioRepeater()
	local radioRepeaters = {};
	local radioRepeatersLabel = {};
	for _, repeater in ipairs(CellRepeaters) do
		table.insert(radioRepeatersLabel, string.sub(repeater.Id, 1, 10) .. '...')
		table.insert(radioRepeaters, repeater.Id)
	end
	for _, repeater in ipairs(Towers) do
		table.insert(radioRepeatersLabel, string.sub(repeater.Id, 1, 10) .. '...')
		table.insert(radioRepeaters, repeater.Id)
	end
	for _, repeater in ipairs(racks) do
		table.insert(radioRepeatersLabel, string.sub(repeater.Id, 1, 10) .. '...')
		table.insert(radioRepeaters, repeater.Id)
	end
	if WarMenu.ComboBox('Select Repeater:', radioRepeatersLabel, state.index, state.index, function(current)
		state.index = current
		state.repeaterId = radioRepeaters[current]
	end) then
	end
	local foundHandle = nil;
	for _, repeater in ipairs(CellRepeaters) do
		if repeater.Id == state.repeaterId then
			foundHandle = repeater
			break
		end
	end
	for _, repeater in ipairs(Towers) do
		if repeater.Id == state.repeaterId then
			foundHandle = repeater
			break
		end
	end
	for _, repeater in ipairs(racks) do
		if repeater.Id == state.repeaterId then
			foundHandle = repeater
			break
		end
	end
	if foundHandle then
		DrawMarker(0, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z + 1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 255, 0, 0, 200, true, true, 2, false, nil, nil,
		           false)
		if WarMenu.Button('Delete Repeater') then
			DeleteEntity(foundHandle.Handle)
			for k, repeater in ipairs(CellRepeaters) do
				if repeater.Id == state.repeaterId then
					table.remove(CellRepeaters, k)
				end
			end
			for k, repeater in ipairs(Towers) do
				if repeater.Id == state.repeaterId then
					table.remove(Towers, k)
				end
			end
			for k, repeater in ipairs(racks) do
				if repeater.Id == state.repeaterId then
					table.remove(racks, k)
				end
			end
			TriggerEvent('chat:addMessage', {
				color = {
					255,
					0,
					0
				},
				multiline = true,
				args = {
					'Success',
					'Repeater ' .. state.repeaterId .. ' has been deleted.'
				}
			})
			state.repeaterId = nil
			state.index = 1
			confirmRadioPlacement()
			WarMenu.OpenMenu('sonoranRadioMenu')
		end
	end
end

Citizen.CreateThread(function()
	while true do
		Wait(0)
		if state.repeaterId and WarMenu.IsMenuOpened('sonoranRadioMenu') then
			state.repeaterId = nil
			state.index = 1
		end
	end
end)
