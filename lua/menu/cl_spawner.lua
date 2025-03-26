local state = {
	index = 1,
	repeaterId = nil,
	moveSpeed = 0.05,
	ogCoords = nil,
	ogHeading = nil,
	lastCoordUpdate = nil,
	calculatedHeading = nil
}

local toneboardState = {
	index = 1,
	speakerId = nil,
	moveSpeed = 0.05,
	ogCoords = nil,
	ogHeading = nil,
	lastCoordUpdate = nil,
	calculatedHeading = nil
}

local selectedConfig = {
    componentId = nil,
    drawableId = nil,
    texture = {}
}

local currentTexture = nil
local hoveredTexture = nil -- Track the currently hovered texture

chatterConfig = {}

local textureNames = {
    "Head", "Mask", "Hair", "Torso", "Legs", "Bags", "Feet", "Accessories",
    "Undershirt", "Body Armor", "Decals", "Tops"
}

local propNames = {
    "Hat", "Glasses", "Earrings", "Watches", "Bracelets"
}

local creatingZone = false
local radioScaleform = nil
local zoneVisibility = Config.debug

local polyzoneState = {
	index = 1,
	zoneId = nil,
}
CreateThread(function()
	radioScaleform = RequestScaleformMovie('INSTRUCTIONAL_BUTTONS')
	while not HasScaleformMovieLoaded(radioScaleform) do
		Wait(0)
	end
end)

Citizen.CreateThread(function()
	WarMenu.CreateMenu('sonoranRadioMenu', ' SonoranRadio Menu')
	WarMenu.SetTitleColor('sonoranRadioMenu', 0, 0, 0, 255)
	WarMenu.SetMenuTitleBackgroundSprite('sonoranRadioMenu', 'radio_menu_header', 'option_1')
	WarMenu.SetSubTitle('sonoranRadioMenu', 'Sonoran Software')
	WarMenu.CreateSubMenu('spawnRadioMenu', 'sonoranRadioMenu', 'Spawn Repeater')
	WarMenu.SetMenuTitleBackgroundSprite('spawnRadioMenu', 'radio_menu_header', 'option_1')
	WarMenu.CreateSubMenu('moveRadioMenu', 'sonoranRadioMenu', 'Move Repeater')
	WarMenu.SetMenuTitleBackgroundSprite('moveRadioMenu', 'radio_menu_header', 'option_1')
	WarMenu.CreateSubMenu('deleteRadioMenu', 'sonoranRadioMenu', 'Delete Repeater')
	WarMenu.SetMenuTitleBackgroundSprite('deleteRadioMenu', 'radio_menu_header', 'option_1')
	WarMenu.CreateSubMenu('degradeMenu', 'sonoranRadioMenu', 'Degradation Zones')
	WarMenu.SetMenuTitleBackgroundSprite('degradeMenu', 'radio_menu_header', 'option_1')
	WarMenu.CreateSubMenu('degradeEditMenu', 'degradeMenu', 'Modify Degradation Zones')
	WarMenu.SetMenuTitleBackgroundSprite('degradeEditMenu', 'radio_menu_header', 'option_1')
	WarMenu.CreateSubMenu('degradeDeleteMenu', 'degradeEditMenu', 'Confirm Deletion')
	WarMenu.SetMenuTitleBackgroundSprite('degradeDeleteMenu', 'radio_menu_header', 'option_1')
	WarMenu.CreateSubMenu('toneboardMenu', 'sonoranRadioMenu', 'Toneboard Speaker Menu')
	WarMenu.SetMenuTitleBackgroundSprite('toneboardMenu', 'radio_menu_header', 'option_1')
	WarMenu.CreateSubMenu('toneboardSpawnMenu', 'toneboardMenu', 'Spawn Speaker')
	WarMenu.SetMenuTitleBackgroundSprite('toneboardSpawnMenu', 'radio_menu_header', 'option_1')
	WarMenu.CreateSubMenu('toneboardMoveMenu', 'toneboardMenu', 'Move Speaker')
	WarMenu.SetMenuTitleBackgroundSprite('toneboardMoveMenu', 'radio_menu_header', 'option_1')
	WarMenu.CreateSubMenu('toneboardDeleteMenu', 'toneboardMenu', 'Delete Speaker')
	WarMenu.CreateSubMenu('chatterMenu', 'sonoranRadioMenu', 'Configure Chatter Earpieces')
	WarMenu.SetMenuTitleBackgroundSprite('chatterMenu', 'radio_menu_header', 'option_1')
	WarMenu.CreateSubMenu('addChatterConfig', 'chatterMenu', 'Add Earpiece Item')
	WarMenu.SetMenuTitleBackgroundSprite('addChatterConfig', 'radio_menu_header', 'option_1')
	WarMenu.CreateSubMenu('editChatterConfig', 'chatterMenu', 'Remove Earpiece Item')
	WarMenu.SetMenuTitleBackgroundSprite('editChatterConfig', 'radio_menu_header', 'option_1')
	WarMenu.CreateSubMenu('deleteChatterConfig', 'chatterMenu', 'Delete Earpiece Config')
	WarMenu.SetMenuTitleBackgroundSprite('deleteChatterConfig', 'radio_menu_header', 'option_1')
		-- Pre-create all drawable submenus
	for drawable = 0, 11 do
		WarMenu.CreateSubMenu('drawable_' .. drawable, 'addChatterConfig', 'Select ' .. textureNames[drawable + 1])
		WarMenu.SetMenuTitleBackgroundSprite('drawable_' .. drawable, 'radio_menu_header', 'option_1')
	end

	-- Pre-create all prop submenus
	for tmpProp = 0, 4 do
		local realProp = (tmpProp > 2) and (tmpProp + 3) or tmpProp
		WarMenu.CreateSubMenu('prop_' .. tmpProp, 'addChatterConfig', 'Select ' .. propNames[tmpProp + 1])
		WarMenu.SetMenuTitleBackgroundSprite('prop_' .. tmpProp, 'radio_menu_header', 'option_1')
	end
	for index, _ in ipairs(chatterConfig) do
        WarMenu.CreateSubMenu('editItem_' .. index, 'chatterMenu', 'Edit Item ' .. index)
    end
	while true do
		if WarMenu.IsMenuOpened('sonoranRadioMenu') then -- Main menu processing
			if WarMenu.MenuButton('Spawn Repeater', 'spawnRadioMenu') then
			end
			if WarMenu.MenuButton('Move Repeater', 'moveRadioMenu') then
			end
			if WarMenu.MenuButton('Delete Repeater', 'deleteRadioMenu') then
			end
			if WarMenu.MenuButton('Degradation Zones', 'degradeMenu') then
			end
			if WarMenu.MenuButton('Toneboard Speaker Menu', 'toneboardMenu') then
			end
			if Config.chatter then
				if WarMenu.MenuButton('Configure Earpiece Chatter', 'chatterMenu') then
				end
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
		elseif WarMenu.IsMenuOpened('degradeMenu') then
			degradeMenu()
			WarMenu.Display()
		elseif WarMenu.IsMenuOpened('degradeEditMenu') then
			degradeEditMenu()
			WarMenu.Display()
		elseif WarMenu.IsMenuOpened('degradeDeleteMenu') then
			local zone = polyZonesTable[polyzoneState.zoneId]
			if WarMenu.Button('Delete ' .. polyzoneState.zoneId) then
                zone:destroy()
				polyZonesTable[polyzoneState.zoneId] = nil
				TriggerServerEvent('SonoranRadio:PolyZone:DeleteZone', polyzoneState.zoneId)
				TriggerEvent('chat:addMessage', {
					color = {
						255,
						0,
						0
					},
					multiline = true,
					args = {
						'Success',
						'Zone ' .. polyzoneState.zoneId .. ' has been deleted.'
					}
				})
				polyzoneState.index = 1
                polyzoneState.zoneId = nil
				WarMenu.OpenMenu('degradeEditMenu')
			end
			WarMenu.Display()
	elseif WarMenu.IsMenuOpened('toneboardMenu') then
			toneboardMenu()
			WarMenu.Display()
		elseif WarMenu.IsMenuOpened('toneboardSpawnMenu') then
			toneboardSpawnMenu()
			WarMenu.Display()
		elseif WarMenu.IsMenuOpened('toneboardMoveMenu') then
			toneboardMoveMenu()
			WarMenu.Display()
		elseif WarMenu.IsMenuOpened('toneboardDeleteMenu') then
			toneboardDeleteMenu()
			WarMenu.Display()
		elseif WarMenu.IsMenuOpened('chatterMenu') then
			chatterMenu()
			WarMenu.Display()
		elseif WarMenu.IsMenuOpened('addChatterConfig') then
			addChatterConfig()
			WarMenu.Display()
		elseif WarMenu.IsMenuOpened('editChatterConfig') then
			editChatterConfig()
			WarMenu.Display()
		elseif WarMenu.IsMenuOpened('deleteChatterConfig') then
			deleteChatterConfig()
			WarMenu.Display()
		end
		-- Loop for Drawables (Components)
		for drawable = 0, 11 do
			local menuId = 'drawable_' .. drawable
			if WarMenu.IsMenuOpened(menuId) then
				local currentDrawable = GetPedDrawableVariation(PlayerPedId(), drawable)
				local maxTextures = GetNumberOfPedTextureVariations(PlayerPedId(), drawable, currentDrawable)

				-- Select Drawable
				if WarMenu.Button("Select Drawable", string.format("Drawable ID: %d", currentDrawable)) then
					selectedConfig.componentId = drawable
					selectedConfig.drawableId = currentDrawable
					selectedConfig.texture = {}
				end

				for i = 0, maxTextures - 1 do
					local isSelected = selectedConfig.texture[i + 1] ~= nil -- Check if texture is selected

					-- Use CheckBox and hover detection
					if WarMenu.CheckBox(string.format("Texture #%d", i + 1), isSelected, function(checked)
						if checked then
							selectedConfig.texture[i + 1] = i
						else
							selectedConfig.texture[i + 1] = nil
						end
					end) then
						-- This triggers when CheckBox is interacted with
					end

					-- Hover state detection (AFTER CheckBox)
					if WarMenu.IsItemHovered() then
						hoveredTexture = i -- Track the hovered texture
					end
				end

				-- Highlight the hovered texture only once outside the loop
				if hoveredTexture ~= nil then
					SetPedComponentVariation(PlayerPedId(), drawable, currentDrawable, hoveredTexture, 0)
				else
					-- Restore to default texture when not hovering
					SetPedComponentVariation(PlayerPedId(), drawable, currentDrawable, currentTexture, 0)
				end
				-- Save Config
				if WarMenu.Button("Save Config", "Confirm Selection") then
					local finalConfig = {
						componentId = drawable,
						drawableId = currentDrawable,
						texture = {}
					}

					-- Collect selected textures
					for _, texture in pairs(selectedConfig.texture) do
						table.insert(finalConfig.texture, texture)
					end

					table.insert(chatterConfig, finalConfig)
					TriggerServerEvent('Chatter:saveChatterConfig', chatterConfig)
					TriggerEvent('chat:addMessage', {
						color = {
							255,
							0,
							0
						},
						multiline = true,
						args = {
							'Earpiece Config',
							'Config saved successfully'
						}
					})

					-- Reset selectedConfig
					selectedConfig = {
						componentId = nil,
						drawableId = nil,
						texture = {}
					}
					WarMenu.OpenMenu('chatterMenu')
				end

				WarMenu.Display()
			end
		end

		-- Props Loop (Existing Code)
		for tmpProp = 0, 4 do
			local realProp = (tmpProp >= 3) and (tmpProp + 3) or tmpProp
			local menuId = 'prop_' .. tmpProp
			if WarMenu.IsMenuOpened(menuId) then
				local currentProp = GetPedPropIndex(PlayerPedId(), realProp)
				local maxTextures = GetNumberOfPedPropTextureVariations(PlayerPedId(), realProp, currentProp)
				if WarMenu.Button("Select Prop", string.format("Prop ID: %d", currentProp)) then
					selectedConfig.componentId = realProp
					selectedConfig.drawableId = currentProp
					selectedConfig.texture = {}
				end

				for i = 0, maxTextures - 1 do
					local isSelected = selectedConfig.texture[i + 1] ~= nil -- Check if texture is selected
					local hoverState = WarMenu.IsItemHovered() -- Check if this item is being hovered over
					-- Highlight the component if hovering
					if hoverState then
						SetPedPropIndex(PlayerPedId(), realProp, currentProp, i, 2) -- Change texture to the current selection
					else
						-- Restore the default texture (use i=0 as the default texture for simplicity)
						SetPedPropIndex(PlayerPedId(), realProp, currentProp, 0, 2)
					end

					WarMenu.CheckBox(string.format("Texture #%d", i + 1), isSelected, function(checked)
						if checked then
							-- Add texture to the selectedConfig
							selectedConfig.texture[i + 1] = i
						else
							-- Remove texture from the selectedConfig
							selectedConfig.texture[i + 1] = nil
						end
					end)
				end
				if WarMenu.Button("Save Config", "Confirm Selection") then
					local finalConfig = {
						componentId = realProp,
						drawableId = currentProp,
						texture = {}
					}

					for _, texture in pairs(selectedConfig.texture) do
						table.insert(finalConfig.texture, texture)
					end
					table.insert(chatterConfig, finalConfig)
					TriggerServerEvent('Chatter:saveChatterConfig', chatterConfig)
					TriggerEvent('chat:addMessage', {
						color = {
							255,
							0,
							0
						},
						multiline = true,
						args = {
							'Earpiece Config',
							'Config saved successfully'
						}
					})

					selectedConfig = {
						componentId = nil,
						drawableId = nil,
						texture = {}
					}
					WarMenu.OpenMenu('chatterMenu')
				end

				WarMenu.Display()
			end
			for index, item in ipairs(chatterConfig or {}) do
				local menuId = 'editItem_' .. index
				if WarMenu.IsMenuOpened(menuId) then
					if WarMenu.Button("Remove Earpiece Item", "Confirm Removal") then
						table.remove(chatterConfig, index)
						TriggerServerEvent('Chatter:saveChatterConfig', chatterConfig)
						TriggerEvent('chat:addMessage', {
							color = {
								255,
								0,
								0
							},
							multiline = true,
							args = {
								'Earpiece Config',
								'Earpiece removed successfully'
							}
						})
						WarMenu.OpenMenu('chatterMenu')
					end
					WarMenu.Display()
				end
			end
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
				confirmRadioPlacement()
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
					heading = GetEntityHeading(PlayerPedId()),
					type = 'radioTower'
				}
				state.repeaterId = towerData.Id
				TriggerEvent('RadioTower:SpawnTower', towerData)
				confirmRadioPlacement()
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
				confirmRadioPlacement()
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
		if state.repeaterId ~= state.lastCoordUpdate then
			state.ogCoords = foundHandle.PropPosition
			if foundHandle.type == 'serverRack' then
				local calculatedHeading = foundHandle.heading + 180.0 -- invert the heading to get the direction the server is facing (0 is the back of the server, 180 is the front)
				if calculatedHeading > 360.0 then
					calculatedHeading = calculatedHeading - 360.0
					state.ogHeading = calculatedHeading
				else
					state.ogHeading = calculatedHeading
				end
			else
				state.ogHeading = foundHandle.heading or 0.0
			end
			state.lastCoordUpdate = state.repeaterId
		end
		local pressed, input = WarMenu.InputButton('Repeater Range', 'Rpeater Range (Default 1500.0)', tostring(foundHandle.Range), 20, tostring(foundHandle.Range))
		if pressed then
			if input == '' then
				foundHandle.Range = 1500.0
			else
				foundHandle.Range = tonumber(input)
			end
			confirmRadioPlacement()
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
				SetEntityHeading(foundHandle.Handle, foundHandle.heading or 0)
			elseif IsControlPressed(0, 107) and GetLastInputMethod(0) then
				local array = {
					x = foundHandle.PropPosition.x,
					y = foundHandle.PropPosition.y,
					z = foundHandle.PropPosition.z
				}
				array.x = array.x - state.moveSpeed
				foundHandle.PropPosition = vec3(array.x, array.y, array.z)
				SetEntityCoords(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading or 0)
			elseif IsControlPressed(0, 112) and GetLastInputMethod(0) then
				local array = {
					x = foundHandle.PropPosition.x,
					y = foundHandle.PropPosition.y,
					z = foundHandle.PropPosition.z
				}
				array.y = array.y + state.moveSpeed
				foundHandle.PropPosition = vec3(array.x, array.y, array.z)
				SetEntityCoords(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading or 0)
			elseif IsControlPressed(0, 111) and GetLastInputMethod(0) then
				local array = {
					x = foundHandle.PropPosition.x,
					y = foundHandle.PropPosition.y,
					z = foundHandle.PropPosition.z
				}
				array.y = array.y - state.moveSpeed
				foundHandle.PropPosition = vec3(array.x, array.y, array.z)
				SetEntityCoords(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading or 0)
			elseif IsControlPressed(0, 314) and GetLastInputMethod(0) then
				local array = {
					x = foundHandle.PropPosition.x,
					y = foundHandle.PropPosition.y,
					z = foundHandle.PropPosition.z
				}
				array.z = array.z + state.moveSpeed
				foundHandle.PropPosition = vec3(array.x, array.y, array.z)
				SetEntityCoords(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading or 0)
			elseif IsControlPressed(0, 315) and GetLastInputMethod(0) then
				local array = {
					x = foundHandle.PropPosition.x,
					y = foundHandle.PropPosition.y,
					z = foundHandle.PropPosition.z
				}
				array.z = array.z - state.moveSpeed
				foundHandle.PropPosition = vec3(array.x, array.y, array.z)
				SetEntityCoords(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading or 0)
			elseif IsControlPressed(0, 118) and GetLastInputMethod(0) then
				foundHandle.heading = (foundHandle.heading or 0) + state.moveSpeed
				SetEntityCoords(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading or 0)
			elseif IsControlPressed(0, 117) and GetLastInputMethod(0) then
				foundHandle.heading = (foundHandle.heading or 0) - state.moveSpeed
				SetEntityCoords(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading or 0)
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

			elseif IsControlPressed(0, 107) and GetLastInputMethod(0) then
				local array = {
					x = foundHandle.PropPosition.x,
					y = foundHandle.PropPosition.y,
					z = foundHandle.PropPosition.z
				}
				array.x = array.x - state.moveSpeed
				foundHandle.PropPosition = vec3(array.x, array.y, array.z)
				SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)

			elseif IsControlPressed(0, 112) and GetLastInputMethod(0) then
				local array = {
					x = foundHandle.PropPosition.x,
					y = foundHandle.PropPosition.y,
					z = foundHandle.PropPosition.z
				}
				array.y = array.y + state.moveSpeed
				foundHandle.PropPosition = vec3(array.x, array.y, array.z)
				SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)

			elseif IsControlPressed(0, 111) and GetLastInputMethod(0) then
				local array = {
					x = foundHandle.PropPosition.x,
					y = foundHandle.PropPosition.y,
					z = foundHandle.PropPosition.z
				}
				array.y = array.y - state.moveSpeed
				foundHandle.PropPosition = vec3(array.x, array.y, array.z)
				SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)

			elseif IsControlPressed(0, 314) and GetLastInputMethod(0) then
				local array = {
					x = foundHandle.PropPosition.x,
					y = foundHandle.PropPosition.y,
					z = foundHandle.PropPosition.z
				}
				array.z = array.z + state.moveSpeed
				foundHandle.PropPosition = vec3(array.x, array.y, array.z)
				SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z, true, true, true, false)

			elseif IsControlPressed(0, 315) and GetLastInputMethod(0) then
				local array = {
					x = foundHandle.PropPosition.x,
					y = foundHandle.PropPosition.y,
					z = foundHandle.PropPosition.z
				}
				array.z = array.z - state.moveSpeed
				foundHandle.PropPosition = vec3(array.x, array.y, array.z)
				SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z, true, true, true, false)

			elseif IsControlPressed(0, 118) and GetLastInputMethod(0) then
				foundHandle.heading = foundHandle.heading + state.moveSpeed
				if not state.calculatedHeading then
					local calculatedHeading = foundHandle.heading + 180.0 -- invert the heading to get the direction the server is facing (0 is the back of the server, 180 is the front)
					if calculatedHeading > 360.0 then
						calculatedHeading = calculatedHeading - 360.0
					end
					foundHandle.heading = calculatedHeading
					state.calculatedHeading = true
				end
				SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading)
			elseif IsControlPressed(0, 117) and GetLastInputMethod(0) then
				foundHandle.heading = foundHandle.heading - state.moveSpeed
				if not state.calculatedHeading then
					local calculatedHeading = foundHandle.heading + 180.0 -- invert the heading to get the direction the server is facing (0 is the back of the server, 180 is the front)
					if calculatedHeading > 360.0 then
						calculatedHeading = calculatedHeading - 360.0
					end
					foundHandle.heading = calculatedHeading
					state.calculatedHeading = true
				end
				SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
				SetEntityHeading(foundHandle.Handle, foundHandle.heading)
			elseif IsControlJustReleased(0, 21) and GetLastInputMethod(0) then
				if state.moveSpeed < 2.0 then
					state.moveSpeed = state.moveSpeed + 0.001
				else
					showNotification('Cannot Move Faster')
				end
			elseif IsControlJustReleased(0, 132) and GetLastInputMethod(0) then
				if state.moveSpeed > 0.001 then
					state.moveSpeed = state.moveSpeed - 0.001
				else
					showNotification('Cannot move slower')
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
	state.ogHeading = nil
	state.ogCoords = nil
	state.lastCoordUpdate = nil
	state.calculatedHeading = false

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
					if DoesEntityExist(repeater.Ladder) then
						DeleteEntity(repeater.Ladder)
					end
					local n = repeater.Dishes and #repeater.Dishes or 0
					for j = 1, n do
						DeleteEntity(repeater.Dishes[j])
					end
					table.remove(Towers, k)
				end
			end
			for k, repeater in ipairs(racks) do
				if repeater.Id == state.repeaterId then
					local n = repeater.Servers and #repeater.Servers or 0
					for j = 1, n do
						DeleteEntity(repeater.Servers[j])
					end
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
			state.lastCoordUpdate = nil

			confirmRadioPlacement()
			WarMenu.OpenMenu('sonoranRadioMenu')
		end
	end
end

RegisterNetEvent('menu:back', function(menu)
	if menu.id == 'moveRadioMenu' and state.repeaterId and state.ogCoords then
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
			foundHandle.PropPosition = state.ogCoords
			if foundHandle.type ~= 'serverRack' then
				SetEntityCoords(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
			else
				SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
			end
			SetEntityHeading(foundHandle.Handle, state.ogHeading)
			state.repeaterId = nil
			state.index = 1
			state.ogHeading = nil
			state.ogCoords = nil
			state.lastCoordUpdate = nil
			state.calculatedHeading = nil
		end
	elseif menu.id == 'sonoranRadioMenu' and state.repeaterId then
		state.repeaterId = nil
		state.index = 1
		state.ogHeading = nil
		state.ogCoords = nil
		state.lastCoordUpdate = nil
		state.calculatedHeading = nil
	elseif menu.id == 'degradeMenu' and creatingZone then
		creatingZone = false
		TriggerEvent('SonoranRadio:PolyZone:pzcancel')
	end
end)

local degradeStrength = 0.5
local minY = string.sub(tostring(GetEntityCoords(PlayerPedId()).z - 1), 1, 5)
local maxY = string.sub(tostring(GetEntityCoords(PlayerPedId()).z + 10), 1, 5)
function setMinMax()
	minY = string.sub(tostring(GetEntityCoords(PlayerPedId()).z - 1), 1, 5)
	maxY = string.sub(tostring(GetEntityCoords(PlayerPedId()).z + 10), 1, 5)
end

function zInputFromPolyzone(min, max)
	if min == nil or max == nil then
		minY = string.sub(tostring(GetEntityCoords(PlayerPedId()).z - 1), 1, 5)
		maxY = string.sub(tostring(GetEntityCoords(PlayerPedId()).z + 10), 1, 5)
		return
	end
	minY = string.sub(tostring(min), 1, 5)
	maxY = string.sub(tostring(max), 1, 5)
end

function degradeMenu()
	if WarMenu.Button('Create Degradation Zone') then
		setMinMax()
		creatingZone = true
		local pos = GetEntityCoords(PlayerPedId())
		local s1, s2 = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
		local street1 = GetStreetNameFromHashKey(s1)
		local street2 = GetStreetNameFromHashKey(s2)
		local streetLabel = street1
		if street2 ~= nil then
			streetLabel = streetLabel .. " " .. street2
			streetLabel = string.sub(streetLabel, 1, 15) .. "..."
		end
		AddTextEntry('FMMC_MPM_NAA', 'Degradation Zone Name: (Default: Cross Streets) - Leave blank for default')
		DisplayOnscreenKeyboard(1, 'FMMC_MPM_NAA', 'Degradation Zone Name: (Default: Cross Streets) - Leave blank for default', streetLabel, '', '', '', 20)
		while (UpdateOnscreenKeyboard() == 0) do
			DisableAllControlActions(0);
			Wait(0)
		end
		local zoneName = ''
		if UpdateOnscreenKeyboard() == 2 then
			zoneName = streetLabel
		end
		if (UpdateOnscreenKeyboard() == 1 and GetOnscreenKeyboardResult()) then
			local input = GetOnscreenKeyboardResult()
			if input == '' then
				zoneName = streetLabel
			else
				zoneName = input
			end
		end
		TriggerEvent('SonoranRadio:PolyZone:pzcreate', 'poly', zoneName, nil)
		TriggerEvent('SonoranRadio:PolyZone:UpdateZ', tonumber(minY), tonumber(maxY))
	end
	if WarMenu.MenuButton('Edit Degradation Zone', 'degradeEditMenu') then
	end
	local pressed, input = WarMenu.InputButton('Degradation Strength', 'Degradation Strength (0.0-1.0 - Higher is more)', tostring(degradeStrength), 5, tostring(degradeStrength))
	if pressed then
		if pressed then
			if input == '' then
				degradeStrength = 0.5
			elseif tonumber(input) <= 1.0 and tonumber(input) >= 0.0 then
				degradeStrength = tonumber(input)
			else
				degradeStrength = 1.0
				TriggerEvent('chat:addMessage', {
					color = {
						255,
						0,
						0
					},
					multiline = true,
					args = {
						'Error',
						'Degradation strength must be between 0.0 and 1.0, defaulting to 1.0'
					}
				})
			end
		end
	end
	if WarMenu.Button('Add Point to Zone') then
		TriggerEvent('SonoranRadio:PolyZone:pzadd')
	end
	if WarMenu.Button('Undo Last Point') then
		TriggerEvent('SonoranRadio:PolyZone:pzundo')
	end
	local minYPressed, minYInput = WarMenu.InputButton('Min Z', 'Min Z (Default: ' .. minY .. ')', minY, 5, minY)
	if minYPressed then
		if minYInput == '' then
			minY = 45.0
		else
			minY = tonumber(minYInput)
		end
		TriggerEvent('SonoranRadio:PolyZone:UpdateZ', tonumber(minY), tonumber(maxY))
	end
	local maxYPressed, maxYInput = WarMenu.InputButton('Max Z', 'Max Z (Default: ' .. maxY .. ')', maxY, 5, maxY)
	if maxYPressed then
		if maxYInput == '' then
			maxY = 59.0
		else
			maxY = tonumber(maxYInput)
		end
		TriggerEvent('SonoranRadio:PolyZone:UpdateZ', tonumber(minY), tonumber(maxY))
	end
	if WarMenu.Button('Finish Zone Creation') then
		creatingZone = false
		TriggerEvent('SonoranRadio:PolyZone:pzfinish', degradeStrength, minY, maxY)
	end
	if WarMenu.Button('Cancel Zone Creation') then
		creatingZone = false
		TriggerEvent('SonoranRadio:PolyZone:pzcancel')
	end
end

local function getClosestPointOnLineSegment(A, B, P, defaultZ)
    defaultZ = defaultZ or P.z or 0
    -- Use defaultZ if A.z or B.z are missing
    local A3 = vector3(A.x, A.y, defaultZ)
    local B3 = vector3(B.x, B.y, defaultZ)

    local AB = B3 - A3
    local AP = P - A3
    local ab2 = (AB.x * AB.x) + (AB.y * AB.y) + (AB.z * AB.z)
    local ap_ab = (AP.x * AB.x) + (AP.y * AB.y) + (AP.z * AB.z)
    local t = math.max(0, math.min(1, ap_ab / ab2))

    return A3 + (AB * t)
end

local function getClosestPointOnPolygon(polygon, P)
    -- If the polygon has minZ and maxZ, use the midpoint as the default z value.
    local defaultZ = (polygon.minZ and polygon.maxZ) and ((polygon.minZ + polygon.maxZ) / 2) or P.z or 0

    local closestPoint = nil
    local minDistance = math.huge

    for i = 1, #polygon do
        local currentPoint = polygon[i]
        local nextPoint = polygon[i + 1] or polygon[1] -- Loop back to the first point

        -- Pass in defaultZ so that A and B get a valid z value
        local pointOnSegment = getClosestPointOnLineSegment(currentPoint, nextPoint, P, defaultZ)
        local distance = #(P - pointOnSegment)

        if distance < minDistance then
            minDistance = distance
            closestPoint = pointOnSegment
        end
    end

    return closestPoint, minDistance
end

function degradeEditMenu()
    local buttonLabel = zoneVisibility and "Hide Zones" or "Show Zones"

    -- Toggle all zones' visibility
    if WarMenu.Button(buttonLabel) then
        zoneVisibility = not zoneVisibility
    end

	for _, zone in pairs(polyZonesTable) do -- Use `pairs()` instead of `ipairs()`
		if zoneVisibility then
			zone:toggleDraw(true, {0, 255, 0}) -- Green when visible
		else
			zone:toggleDraw(false) -- Hide when disabled
		end
	end

    -- Generate a sorted list of zone names for the ComboBox
    local polyZoneLabels = {}
    local zoneKeys = {}

    for zoneName, _ in pairs(polyZonesTable) do
        table.insert(polyZoneLabels, zoneName)
        table.insert(zoneKeys, zoneName) -- Store actual keys separately
    end

    -- Handle zone selection from ComboBox
    if WarMenu.ComboBox('Select Zone:', polyZoneLabels, polyzoneState.index, polyzoneState.index, function(current)
        -- Get the selected zone name
        local selectedZoneName = zoneKeys[current]

        -- Reset previous zone color to green (if zones are visible)
        if polyzoneState.index and polyzoneState.zoneId and zoneVisibility then
            polyZonesTable[polyzoneState.zoneId]:toggleDraw(true, {0, 255, 0}) -- Green
        else
            if polyzoneState.zoneId then
                polyZonesTable[polyzoneState.zoneId]:toggleDraw(false) -- Hide
            end
        end
        -- Update selected state
        polyzoneState.index = current
        polyzoneState.zoneId = selectedZoneName

		local zone = polyZonesTable[polyzoneState.zoneId]
		if zone then
			zone:toggleDraw(true, {255, 0, 0}) -- Red
			local playerPed = PlayerPedId()
			local playerCoords = GetEntityCoords(playerPed)

			-- Get closest distance
			local _, distance = getClosestPointOnPolygon(zone.points, playerCoords)

			if WarMenu.Button('Distance to ' .. polyzoneState.zoneId .. ': ' .. string.format("%.1f", distance) .. 'm') then
			end

			-- Delete Zone
			if WarMenu.Button('Delete Zone') then
				WarMenu.OpenMenu('degradeDeleteMenu')
			end
		end
    end) then
	end
end


function toneboardSpawnMenu()
	local toneboards = {
		'Speaker (Small - Wall)',
		'Speaker (Medium)',
		'Speaker (Medium - Wall)',
		'Speaker (Large)',
		}
	if WarMenu.ComboBox('Speaker Type:', toneboards, toneboardState.index, toneboardState.index, function(current)
		toneboardState.index = current
	end) then
		local propName = toneboards[toneboardState.index];
		if propName == 'Speaker (Small - Wall)' then
			AddTextEntry('FMMC_MPM_NAA', 'Range: (Default: 40.0) - Leave blank for default')
			DisplayOnscreenKeyboard(1, 'FMMC_MPM_NAA', 'Range: (Default: 40.0) - Leave blank for default', '40.0', '', '', '', 40)
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
			local pos = GetEntityCoords(PlayerPedId())
			local s1, s2 = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
			local street1 = GetStreetNameFromHashKey(s1)
			local street2 = GetStreetNameFromHashKey(s2)
			local streetLabel = street1
			if street2 ~= nil then
				streetLabel = streetLabel .. " " .. street2
			end
			AddTextEntry('FMMC_MPM_NAA', 'Speaker Label: (Default: Cross Roads) - Leave blank for default')
			DisplayOnscreenKeyboard(1, 'FMMC_MPM_NAA', 'Speaker Label: (Default: Cross Roads) - Leave blank for default', streetLabel, '', '', '', 40)
			while (UpdateOnscreenKeyboard() == 0) do
				DisableAllControlActions(0);
				Wait(0)
			end
			local speakerLabel = ''
			if UpdateOnscreenKeyboard() == 2 then
				speakerLabel = streetLabel
			end
			if (UpdateOnscreenKeyboard() == 1 and GetOnscreenKeyboardResult()) then
				local input = GetOnscreenKeyboardResult()
				if input == '' then
					speakerLabel = streetLabel
				else
					speakerLabel = input
				end
			end
			if range and speakerLabel then
				local speakerData = {
					Id = uuid(),
					PropPosition = GetEntityCoords(PlayerPedId()),
					heading = GetEntityHeading(PlayerPedId()),
					type = 'speakerSmallWall',
					Range = range,
					Label = speakerLabel
				}
				toneboardState.speakerId = speakerData.Id
				TriggerEvent('RadioSpeaker:SpawnSpeaker', speakerData)
				confirmSpeakerPlacement()
				WarMenu.OpenMenu('toneboardMoveMenu')
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
						'Invalid range or label. Range must be a number'
					}
				})
			end
		elseif propName == 'Speaker (Medium)' then
			AddTextEntry('FMMC_MPM_NAA', 'Range: (Default: 40.0) - Leave blank for default')
			DisplayOnscreenKeyboard(1, 'FMMC_MPM_NAA', 'Range: (Default: 40.0) - Leave blank for default', '40.0', '', '', '', 20)
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
			local pos = GetEntityCoords(PlayerPedId())
			local s1, s2 = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
			local street1 = GetStreetNameFromHashKey(s1)
			local street2 = GetStreetNameFromHashKey(s2)
			local streetLabel = street1
			if street2 ~= nil then
				streetLabel = streetLabel .. " " .. street2
			end
			AddTextEntry('FMMC_MPM_NAA', 'Speaker Label: (Default: Cross Roads) - Leave blank for default')
			DisplayOnscreenKeyboard(1, 'FMMC_MPM_NAA', 'Speaker Label: (Default: Cross Roads) - Leave blank for default', streetLabel, '', '', '', 40)
			while (UpdateOnscreenKeyboard() == 0) do
				DisableAllControlActions(0);
				Wait(0)
			end
			local speakerLabel = ''
			if UpdateOnscreenKeyboard() == 2 then
				speakerLabel = streetLabel
			end
			if (UpdateOnscreenKeyboard() == 1 and GetOnscreenKeyboardResult()) then
				local input = GetOnscreenKeyboardResult()
				if input == '' then
					speakerLabel = streetLabel
				else
					speakerLabel = input
				end
			end
			if range and speakerLabel then
				local speakerData = {
					Id = uuid(),
					PropPosition = GetEntityCoords(PlayerPedId()),
					heading = GetEntityHeading(PlayerPedId()),
					type = 'speakerMedium',
					Range = range,
					Label = speakerLabel
				}
				toneboardState.speakerId = speakerData.Id
				TriggerEvent('RadioSpeaker:SpawnSpeaker', speakerData)
				confirmSpeakerPlacement()
				WarMenu.OpenMenu('toneboardMoveMenu')
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
						'Invalid range or label. Range must be a number'
					}
				})
			end
		elseif propName == 'Speaker (Medium - Wall)' then
			AddTextEntry('FMMC_MPM_NAA', 'Range: (Default: 40.0) - Leave blank for default')
			DisplayOnscreenKeyboard(1, 'FMMC_MPM_NAA', 'Range: (Default: 40.0) - Leave blank for default', '40.0', '', '', '', 20)
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
			local pos = GetEntityCoords(PlayerPedId())
			local s1, s2 = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
			local street1 = GetStreetNameFromHashKey(s1)
			local street2 = GetStreetNameFromHashKey(s2)
			local streetLabel = street1
			if street2 ~= nil then
				streetLabel = streetLabel .. " " .. street2
			end
			AddTextEntry('FMMC_MPM_NAA', 'Speaker Label: (Default: Cross Roads) - Leave blank for default')
			DisplayOnscreenKeyboard(1, 'FMMC_MPM_NAA', 'Speaker Label: (Default: Cross Roads) - Leave blank for default', streetLabel, '', '', '', 40)
			while (UpdateOnscreenKeyboard() == 0) do
				DisableAllControlActions(0);
				Wait(0)
			end
			local speakerLabel = ''
			if UpdateOnscreenKeyboard() == 2 then
				speakerLabel = streetLabel
			end
			if (UpdateOnscreenKeyboard() == 1 and GetOnscreenKeyboardResult()) then
				local input = GetOnscreenKeyboardResult()
				if input == '' then
					speakerLabel = streetLabel
				else
					speakerLabel = input
				end
			end
			if range and speakerLabel then
				local speakerData = {
					Id = uuid(),
					PropPosition = GetEntityCoords(PlayerPedId()),
					heading = GetEntityHeading(PlayerPedId()),
					type = 'speakerMediumWall',
					Range = range,
					Label = speakerLabel
				}
				toneboardState.speakerId = speakerData.Id
				TriggerEvent('RadioSpeaker:SpawnSpeaker', speakerData)
				confirmSpeakerPlacement()
				WarMenu.OpenMenu('toneboardMoveMenu')
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
						'Invalid range or label. Range must be a number'
					}
				})
			end
		elseif propName == 'Speaker (Large)' then
			AddTextEntry('FMMC_MPM_NAA', 'Range: (Default: 40.0) - Leave blank for default')
			DisplayOnscreenKeyboard(1, 'FMMC_MPM_NAA', 'Range: (Default: 40.0) - Leave blank for default', '40.0', '', '', '', 20)
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
			local pos = GetEntityCoords(PlayerPedId())
			local s1, s2 = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
			local street1 = GetStreetNameFromHashKey(s1)
			local street2 = GetStreetNameFromHashKey(s2)
			local streetLabel = street1
			if street2 ~= nil then
				streetLabel = streetLabel .. " " .. street2
			end
			AddTextEntry('FMMC_MPM_NAA', 'Speaker Label: (Default: Cross Roads) - Leave blank for default')
			DisplayOnscreenKeyboard(1, 'FMMC_MPM_NAA', 'Speaker Label: (Default: Cross Roads) - Leave blank for default', streetLabel, '', '', '', 40)
			while (UpdateOnscreenKeyboard() == 0) do
				DisableAllControlActions(0);
				Wait(0)
			end
			local speakerLabel = ''
			if UpdateOnscreenKeyboard() == 2 then
				speakerLabel = streetLabel
			end
			if (UpdateOnscreenKeyboard() == 1 and GetOnscreenKeyboardResult()) then
				local input = GetOnscreenKeyboardResult()
				if input == '' then
					speakerLabel = streetLabel
				else
					speakerLabel = input
				end
			end
			if range and speakerLabel then
				local speakerData = {
					Id = uuid(),
					PropPosition = GetEntityCoords(PlayerPedId()),
					heading = GetEntityHeading(PlayerPedId()),
					type = 'speakerLarge',
					Range = range,
					Label = speakerLabel
				}
				toneboardState.speakerId = speakerData.Id
				TriggerEvent('RadioSpeaker:SpawnSpeaker', speakerData)
				confirmSpeakerPlacement()
				WarMenu.OpenMenu('toneboardMoveMenu')
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
						'Invalid range or label. Range must be a number'
					}
				})
			end
		end
	end
end

function confirmSpeakerPlacement()
	toneboardState.speakerId = nil
	toneboardState.index = 1
	toneboardState.ogHeading = nil
	toneboardState.ogCoords = nil
	toneboardState.lastCoordUpdate = nil
	toneboardState.calculatedHeading = false
	TriggerServerEvent('SonoranRadio::MoveSpeaker', speakers)
end

function toneboardMoveMenu()
	local speakersNew = {};
	local speakersLabel = {};
	for _, speaker in ipairs(speakers) do
		table.insert(speakersLabel, string.sub(speaker.Id, 1, 10) .. '...')
		table.insert(speakersNew, speaker.Id)
	end
	if WarMenu.ComboBox('Select Speaker:', speakersLabel, toneboardState.index, toneboardState.index, function(current)
		toneboardState.index = current
		toneboardState.speakerId = speakersNew[current]
	end) then
	end
	if WarMenu.Button('Confirm Placement') then
		confirmSpeakerPlacement()
		WarMenu.OpenMenu('toneboardMenu')
	end
	local foundHandle = nil;
	for _, speaker in ipairs(speakers) do
		if speaker.Id == toneboardState.speakerId then
			foundHandle = speaker
			break
		end
	end
	if foundHandle then
		if toneboardState.speakerId ~= toneboardState.lastCoordUpdate then
			toneboardState.ogCoords = foundHandle.PropPosition
			toneboardState.ogHeading = foundHandle.heading or 0.0
			toneboardState.lastCoordUpdate = toneboardState.speakerId
		end
		local pressed, input = WarMenu.InputButton('Speaker Range', 'Speaker Range (Default 40.0)', tostring(foundHandle.Range), 20, tostring(foundHandle.Range))
		if pressed then
			if input == '' then
				foundHandle.Range = 40.0
			else
				foundHandle.Range = tonumber(input)
			end
			confirmRadioPlacement()
		end
		DrawMarker(0, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z + 1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 255, 0, 0, 200, true, true, 2, false, nil, nil,
				false)
		if IsControlPressed(0, 108) and GetLastInputMethod(0) then -- Movement Keys
			local array = {
				x = foundHandle.PropPosition.x,
				y = foundHandle.PropPosition.y,
				z = foundHandle.PropPosition.z
			}
			array.x = array.x + toneboardState.moveSpeed
			foundHandle.PropPosition = vec3(array.x, array.y, array.z)
			SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
		elseif IsControlPressed(0, 107) and GetLastInputMethod(0) then
			local array = {
				x = foundHandle.PropPosition.x,
				y = foundHandle.PropPosition.y,
				z = foundHandle.PropPosition.z
			}
			array.x = array.x - toneboardState.moveSpeed
			foundHandle.PropPosition = vec3(array.x, array.y, array.z)
			SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)

		elseif IsControlPressed(0, 112) and GetLastInputMethod(0) then
			local array = {
				x = foundHandle.PropPosition.x,
				y = foundHandle.PropPosition.y,
				z = foundHandle.PropPosition.z
			}
			array.y = array.y + toneboardState.moveSpeed
			foundHandle.PropPosition = vec3(array.x, array.y, array.z)
			SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)

		elseif IsControlPressed(0, 111) and GetLastInputMethod(0) then
			local array = {
				x = foundHandle.PropPosition.x,
				y = foundHandle.PropPosition.y,
				z = foundHandle.PropPosition.z
			}
			array.y = array.y - toneboardState.moveSpeed
			foundHandle.PropPosition = vec3(array.x, array.y, array.z)
			SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)

		elseif IsControlPressed(0, 314) and GetLastInputMethod(0) then
			local array = {
				x = foundHandle.PropPosition.x,
				y = foundHandle.PropPosition.y,
				z = foundHandle.PropPosition.z
			}
			array.z = array.z + toneboardState.moveSpeed
			foundHandle.PropPosition = vec3(array.x, array.y, array.z)
			SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)

		elseif IsControlPressed(0, 315) and GetLastInputMethod(0) then
			local array = {
				x = foundHandle.PropPosition.x,
				y = foundHandle.PropPosition.y,
				z = foundHandle.PropPosition.z
			}
			array.z = array.z - toneboardState.moveSpeed
			foundHandle.PropPosition = vec3(array.x, array.y, array.z)
			SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)

		elseif IsControlPressed(0, 118) and GetLastInputMethod(0) then
			foundHandle.heading = foundHandle.heading + toneboardState.moveSpeed
			if not toneboardState.calculatedHeading then
				local calculatedHeading = foundHandle.heading + 180.0 -- invert the heading to get the direction the server is facing (0 is the back of the server, 180 is the front)
				if calculatedHeading > 360.0 then
					calculatedHeading = calculatedHeading - 360.0
				end
				foundHandle.heading = calculatedHeading
				toneboardState.calculatedHeading = true
			end
			SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
			SetEntityHeading(foundHandle.Handle, foundHandle.heading)
		elseif IsControlPressed(0, 117) and GetLastInputMethod(0) then
			foundHandle.heading = foundHandle.heading - toneboardState.moveSpeed
			if not toneboardState.calculatedHeading then
				local calculatedHeading = foundHandle.heading + 180.0 -- invert the heading to get the direction the server is facing (0 is the back of the server, 180 is the front)
				if calculatedHeading > 360.0 then
					calculatedHeading = calculatedHeading - 360.0
				end
				foundHandle.heading = calculatedHeading
				toneboardState.calculatedHeading = true
			end
			SetEntityCoordsNoOffset(foundHandle.Handle, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z - 1, true, true, true, false)
			SetEntityHeading(foundHandle.Handle, foundHandle.heading)
		elseif IsControlJustReleased(0, 21) and GetLastInputMethod(0) then
			if toneboardState.moveSpeed < 2.0 then
				toneboardState.moveSpeed = toneboardState.moveSpeed + 0.001
			else
				showNotification('Cannot Move Faster')
			end
		elseif IsControlJustReleased(0, 132) and GetLastInputMethod(0) then
			if toneboardState.moveSpeed > 0.001 then
				toneboardState.moveSpeed = toneboardState.moveSpeed - 0.001
			else
				showNotification('Cannot move slower')
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

function toneboardDeleteMenu()
	local speakersNew = {};
	local speakersLabel = {};
	for _, speaker in ipairs(speakers) do
		table.insert(speakersLabel, string.sub(speaker.Id, 1, 10) .. '...')
		table.insert(speakersNew, speaker.Id)
	end
	if WarMenu.ComboBox('Select Speaker:', speakersLabel, toneboardState.index, toneboardState.index, function(current)
		toneboardState.index = current
		toneboardState.speakerId = speakersNew[current]
	end) then
	end
	local foundHandle = nil;
	for _, speaker in ipairs(speakers) do
		if speaker.Id == toneboardState.speakerId then
			foundHandle = speaker
			break
		end
	end
	if foundHandle then
		DrawMarker(0, foundHandle.PropPosition.x, foundHandle.PropPosition.y, foundHandle.PropPosition.z + 1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 255, 0, 0, 200, true, true, 2, false, nil, nil,
		           false)
		if WarMenu.Button('Delete Speaker') then
			DeleteEntity(foundHandle.Handle)
			for k, speaker in ipairs(speakers) do
				if speaker.Id == toneboardState.speakerId then
					table.remove(speakers, k)
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
					'Speaker ' .. toneboardState.speakerId .. ' has been deleted.'
				}
			})
			toneboardState.speakerId = nil
			toneboardState.index = 1
			toneboardState.lastCoordUpdate = nil
			confirmSpeakerPlacement()
			WarMenu.OpenMenu('toneboardMenu')
		end
	end
end

function toneboardMenu()
	if WarMenu.Button('Spawn New Speaker') then
		WarMenu.OpenMenu('toneboardSpawnMenu')
	end
	if WarMenu.Button('Move Speaker') then
		WarMenu.OpenMenu('toneboardMoveMenu')
	end
	if WarMenu.Button('Delete Speaker') then
		WarMenu.OpenMenu('toneboardDeleteMenu')
	end
end

-- Jordan 12/16/2024 | Chatter Menu

-- Main Chatter Menu
function chatterMenu()
	if not chatterConfig then
		if WarMenu.Button('Chatter Is Currently Disabled') then
		end
	else
		if WarMenu.Button('Add Earpiece Item') then
			WarMenu.OpenMenu('addChatterConfig')
		end
		if WarMenu.Button('Remove Earpiece Item') then
			WarMenu.OpenMenu('editChatterConfig')
		end
	end
end

-- Add Chatter Config Menu
function addChatterConfig()
	-- Credit: TomGrobbe: https://github.com/TomGrobbe/vMenu/blob/724099fa735565d359d119f8cf415a23f3b108a5/vMenu/menus/PlayerAppearance.cs#L623
    -- Drawables
-- Drawables (0-11)
	for drawable = 0, 11 do
		local currentDrawable = GetPedDrawableVariation(PlayerPedId(), drawable) -- Current drawable ID
		local menuId = 'drawable_' .. drawable

		-- Check if menu is opened for this drawable
		if WarMenu.MenuButton(textureNames[drawable + 1], menuId) then
			currentTexture = GetPedTextureVariation(PlayerPedId(), drawable) -- Current texture ID
			-- Highlight the current component the player is wearing
			SetPedComponentVariation(PlayerPedId(), drawable, currentDrawable, currentTexture, 2)
		end
	end

	-- Props (0-4 mapped to real IDs)
	for tmpProp = 0, 4 do
		local realProp = (tmpProp >= 3) and (tmpProp + 3) or tmpProp
		local currentProp = GetPedPropIndex(PlayerPedId(), realProp) -- Current prop ID
		local menuId = 'prop_' .. tmpProp

		-- Check if menu is opened for this prop
		if WarMenu.MenuButton(propNames[tmpProp + 1], menuId) then
			-- Highlight the current prop the player is wearing
			if currentProp ~= -1 then -- Only apply if a prop is currently worn
				currentTexture = GetPedPropTextureIndex(PlayerPedId(), realProp) -- Current prop texture ID
			end
		end
	end
end

function editChatterConfig()
	if #chatterConfig == 0 then
		TriggerServerEvent('Chatter:clientChatterSync')
		TriggerEvent('chat:addMessage', {
			color = {
				255,
				0,
				0
			},
			multiline = true,
			args = {
				'Error',
				'No earpiece config found. Please try again.'
			}
		})
		WarMenu.OpenMenu('chatterMenu')
		return
	end
	for index, item in ipairs(chatterConfig) do
		if not item.componentId or not item.drawableId then
			TriggerEvent('chat:addMessage', {
				color = {
					255,
					0,
					0
				},
				multiline = true,
				args = {
					'Error',
					'Invalid earpiece config found for item at index ' .. index .. '. Please manually correct this in the earpieces.json.'
				}
			})
		else
			local label = string.format("Component %d | Drawable %d", item.componentId, item.drawableId)
			if WarMenu.MenuButton(label, 'editItem_' .. index) then
				-- Create a submenu for each item
				WarMenu.CreateSubMenu('editItem_' .. index, 'editChatterConfig', 'Edit Item')
			end
		end
	end
end