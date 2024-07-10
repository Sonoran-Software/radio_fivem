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
	WarMenu.SetMenuTitleBackgroundSprite('spawnRadioMenu', 'sonoran_menu_header', 'option_1')
	WarMenu.CreateSubMenu('moveRadioMenu', 'sonoranRadioMenu', 'Move Repeater')
	WarMenu.SetMenuTitleBackgroundSprite('moveRadioMenu', 'sonoran_menu_header', 'option_1')
	WarMenu.CreateSubMenu('deleteRadioMenu', 'sonoranRadioMenu', 'Delete Repeater')
	WarMenu.SetMenuTitleBackgroundSprite('deleteRadioMenu', 'sonoran_menu_header', 'option_1')
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
		elseif propName == 'Server Rack' then
		end
	end
end

function movingRadioRepeater()
	if state.repeaterId == nil then
		local radioRepeaters = {};
		for _, repeater in ipairs(CellRepeaters) do
			table.insert(radioRepeaters, repeater.Id)
		end
		for _, repeater in ipairs(Towers) do
			table.insert(radioRepeaters, repeater.Id)
		end
		for _, repeater in ipairs(racks) do
			table.insert(radioRepeaters, repeater.Id)
		end
		if WarMenu.ComboBox('Select Repeater:', radioRepeaters, state.index, state.index, function(current)
			state.index = current
			state.repeaterId = radioRepeaters[current]
		end) then
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
			if not foundHandle then
				TriggerEvent('chat:addMessage', {
					color = {
						255,
						0,
						0
					},
					multiline = true,
					args = {
						'Error',
						'No repeater found with that ID'
					}
				})
				return
			end
			Citizen.CreateThread(function()
				while true do
					Citizen.Wait(1)
					if IsPedInAnyVehicle(GetPlayerPed(-1), true) then
						if not HasStreamedTextureDictLoaded('arrow_pointer') then
							RequestStreamedTextureDict('arrow_pointer', true)
							while not HasStreamedTextureDictLoaded('arrow_pointer') do
								Wait(1)
							end
						else
							DrawSprite('basejumping', 'arrow_pointer', 0.700, 0.760, 0.12, 0.185, 0.0, 255, 255, 255, 255)
						end
					end
				end
			end)
		end
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
	if not foundHandle then
		TriggerEvent('chat:addMessage', {
			color = {
				255,
				0,
				0
			},
			multiline = true,
			args = {
				'Error',
				'No repeater found with that ID'
			}
		})
		return
	end
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

function confirmRadioPlacement()
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
	TriggerServerEvent('SonoranRadio::MoveProp', CellRepeaters, Towers, racks)
end
