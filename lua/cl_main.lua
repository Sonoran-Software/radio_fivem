local radActive = false

local thisUnit = {}
local unitStatus = nil

isTalking = false
isEmergCallActive = false
allowedMiniRadio = false
local tunnels = {}
local authorized = false
local allowedFrames = {}
local critError = false
local calledSyncAcePerms = false
local frame
polyZonesTable = {}
Config = {}

AddEventHandler('onClientResourceStart', function(resourceName)
	if (GetCurrentResourceName() ~= resourceName) then
		return
	end
	if not Config.radioJammers or Config.radioJammers == nil then
	Config.radioJammers = {
		enabled = true, -- Enable or disable radio jammers
		menuCommand = 'jammers', -- Subcommand to open the jammers menu | e.g. /sonoranradio jammers
		toggleRange = 3.0, -- Distance in meters required to toggle a jammer on/off
		permissionMode = 'none', -- ace, qbcore, esx or none
		acePermission = 'sonoranradio.jammers', -- ACE permission required to use jammers
		allowedJobs = { -- Jobs that can use jammers | Requires permission mode to be set to 'qbcore' or 'esx'
			['hacker'] = {
				grades = { -- Job grades that can use jammers
					1,
					2,
					3
				}
			}
		},
		jammers = {
			-- Define jammers here
			-- Example:
			{
				name = 'Hand Held Jammer', -- Name of the jammer
				model = 'm23_2_prop_m32_hackdevice_01a', -- Model name for the jammer
				offModel = 'm23_2_prop_m32_hackdevice_01a', -- Model name for the jammer when off | Optional
				range = 25, -- Range of the jammer in meters
				strength = 0.5, -- Strength of the jammer (0.0 to 1.0)
				permission = 'sonoranradio.jammer_handheld', -- ACE permission required to use this jammer | Optional
				-- If permission is not set, the jammer will be available to all players that can access the jammers menu
				type = 'handheld', -- Type of jammer (handheld or static)
				itemName = 'sonoran_radio_jammer_handheld', -- Item name for the jammer (if Config.enforceRadioItem is true)
				poweredItemName = 'sonoran_radio_jammer_handheld_on' -- Optional item that replaces the base item while the jammer is powered on
			},
			{
				name = 'Suitcase Jammer', -- Name of the jammer
				model = 'ch_prop_ch_mobile_jammer_01x', -- Model name for the jammer
				offModel = 'ch_prop_ch_mobile_jammer_01x', -- Model name for the jammer when off | Optional
				range = 100, -- Range of the jammer in meters
				strength = 0.8, -- Strength of the jammer (0.0 to 1.0)
				permission = '', -- ACE permission required to use this jammer | Optional
				-- If permission is not set, the jammer will be available to all players that can access the jammers menu
				type = 'static', -- Type of jammer (handheld or static)
				itemName = 'sonoran_radio_jammer_suitcase' -- Item name for the jammer (if Config.enforceRadioItem is true)
			},
			{
				name = 'Case Jammer', -- Name of the jammer
				model = 'h4_prop_h4_jammer_01a', -- Model name for the jammer
				offModel = 'h4_prop_h4_jammer_01a', -- Model name for the jammer when off | Optional
				range = 200, -- Range of the jammer in meters
				strength = 1.0, -- Strength of the jammer (0.0 to 1.0)
				permission = '', -- ACE permission required to use this jammer | Optional
				-- If permission is not set, the jammer will be available to all players that can
				type = 'static', -- Type of jammer (handheld or static)
				itemName = 'sonoran_radio_jammer_case' -- Item name for the jammer (if Config.enforceRadioItem is true)
			},
			{
				name = 'Satelite Jammer', -- Name of the jammer
				model = 'm23_2_prop_m32_jammer_01a', -- Model name for the jammer
				offModel = 'm23_2_prop_m32_jammer_01a', -- Model name for the jammer when off | Optional
				range = 300, -- Range of the jammer in meters
				strength = 1.0, -- Strength of the jammer (0.0 to 1.0)
				permission = '', -- ACE permission required to use this jammer | Optional
				-- If permission is not set, the jammer will be available to all players that can
				type = 'static', -- Type of jammer (handheld or static)
				itemName = 'sonoran_radio_jammer_satelite' -- Item name for the jammer (if Config.enforceRadioItem is true)
			}
		}
	}
	end
	TriggerServerEvent('SonoranRadio::core::RequestEnvironment')
end)

RegisterNetEvent('SonoranRadio::core::DebugMode', function(data)
	Config.debug = data
end)

RegisterNetEvent('SonoranRadio::core::ReceiveEnvironment', function(data)
	Config = data
	frame = GetResourceKvpString('sonoranradio_skin') or Config.defaultSkinId or 'default'
	getFramework()
	getInventory()
	initCell()
	initChatter()
	initMiniRadio()
	initRacks()
	initRepeaters()
	initThreads()
	initToneboard()
	initTowers()
	initClient()
	initScanners()
	initMenu()
	initJammers()
	if Config.phoneResource and Config.phoneResource == 'lb-phone' then
		if GetResourceState('lb-phone') == 'started' then
			-- lb-phone is started, so we can initialize the phone integration
			initLbPhone()
		else
			-- lb-phone is not started, so we need to wait for it to start
			warnLog('The resource lb-phone is not started. Waiting for it to start to initialize phone integration.')
			AddEventHandler('onResourceStart', function(resourceName)
				if resourceName == 'lb-phone' then
					initLbPhone()
				end
			end)
		end
	end
	TriggerServerEvent('SonoranRadio::RequestSirens')
	TriggerServerEvent('SonoranRadio::CheckPermissions')
	if Config.luxartResourceName == nil or Config.luxartResourceName == '' then
		warnLog('No Luxart Vehicle Control resource name set in Config.luxartResourceName. Defaulting to "lvc".')
		Config.luxartResourceName = 'lvc'
	end
end)

function initClient()
	local comId = Config.comId or Config.communityId or Config.standaloneId
	TriggerEvent('SonoranRadio::ClientReady')
	RegisterNetEvent('SonoranCAD::sonrad:GetUnitInfo:Return')
	AddEventHandler('SonoranCAD::sonrad:GetUnitInfo:Return', function(unit)
		SendNUIMessage({
			type = 'unitStatus',
			status = unit.status
		})
		-- TODO: Work with unit cache to fix this.
		-- thisUnit = unit
		-- if thisUnit ~= nil then
		-- 	if unitStatus ~= thisUnit.status then
		-- 		unitStatus = thisUnit.status
		-- 		SendNUIMessage({
		-- 			type = 'unitStatus',
		-- 			status = thisUnit.status
		-- 		})
		-- 		--print('status updated')
		-- 	end
		-- else
		-- 	SendNUIMessage({
		-- 		type = 'unitStatus',
		-- 		status = -1
		-- 	})
		-- end
	end)

	RegisterNetEvent('SonoranCAD::sonrad:UpdateCurrentCall')
	AddEventHandler('SonoranCAD::sonrad:UpdateCurrentCall', function(call)
		local dispatch = call and call.dispatch or nil
		SendNUIMessage({
			type = 'callUpdate',
			call = dispatch
		})
	end)

	Citizen.CreateThread(function()
		while true do
			Citizen.Wait(5000)
			TriggerServerEvent('SonoranCAD::sonrad:GetCurrentCall')
		end
	end)

	Radio = {
		HasItem = false,
		Open = false,
		On = false,
		Enabled = true,
		Handle = nil,
		Hud = 'off',
		Prop = GetHashKey('prop_cs_hand_radio'),
		Bone = 28422,
		Offset = vector3(0.0, 0.0, 0.0),
		Rotation = vector3(0.0, 0.0, 0.0),
		Dictionary = {
			'cellphone@',
			'cellphone@in_car@ds',
			'cellphone@str',
			'random@arrests'
		},
		Animation = {
			'cellphone_text_in',
			'cellphone_text_out',
			'cellphone_call_listen_a',
			'generic_radio_chatter'
		},
		Clicks = true, -- Radio clicks
		TalkAnim = false
	}

	if Config.disableAnimation then
		Radio.TalkAnim = false
	else
		Radio.TalkAnim = true
	end

	local QBCore = nil
	local PlayerData = nil
	if Config.enforceRadioItem then
		if frameworkEnum == 1 then
			QBCore = exports['qb-core']:GetCoreObject()
		end
	end

	Citizen.CreateThread(function()
		if Config.enforceRadioItem then
			if frameworkEnum == 1 then
				while QBCore.Functions.GetPlayerData() == nil do
					Citizen.Wait(10)
				end
			end
		end
	end)

	RegisterNetEvent('qb-sonrad:use')
	AddEventHandler('qb-sonrad:use', function(frame)
		radioToggle(frame)
	end)

	local specialKeyCodes = {
		['b_100'] = 'MouseClick.LeftClick',
		['b_101'] = 'MouseClick.RightClick',
		['b_102'] = 'MouseClick.MiddleClick',
		['b_103'] = 'MouseClick.ExtraBtn1',
		['b_104'] = 'MouseClick.ExtraBtn2',
		['b_105'] = 'MouseClick.ExtraBtn3',
		['b_106'] = 'MouseClick.ExtraBtn4',
		['b_107'] = 'MouseClick.ExtraBtn5',
		['b_108'] = 'MouseClick.ExtraBtn6',
		['b_109'] = 'MouseClick.ExtraBtn7',
		['b_110'] = 'MouseClick.ExtraBtn8',
		['b_115'] = 'WheelMouseMove.Up',
		['b_116'] = 'WheelMouseMove.Up',
		['b_130'] = 'NumpadSubstract',
		['b_131'] = 'NumpadAdd',
		['b_132'] = 'NumpadDecimal',
		['b_134'] = 'NumpadMultiply',
		['b_135'] = 'NumpadEnter',
		['b_136'] = 'Numpad0',
		['b_137'] = 'Numpad1',
		['b_138'] = 'Numpad2',
		['b_139'] = 'Numpad3',
		['b_140'] = 'Numpad4',
		['b_142'] = 'Numpad6',
		['b_144'] = 'Numpad8',
		['b_141'] = 'Numpad5',
		['b_143'] = 'Numpad7',
		['b_145'] = 'Numpad9',
		['b_170'] = 'F1',
		['b_171'] = 'F2',
		['b_172'] = 'F3',
		['b_173'] = 'F4',
		['b_174'] = 'F5',
		['b_175'] = 'F6',
		['b_176'] = 'F7',
		['b_177'] = 'F8',
		['b_178'] = 'F9',
		['b_179'] = 'F10',
		['b_180'] = 'F11',
		['b_181'] = 'F12',
		['b_194'] = 'ArrowUp',
		['b_195'] = 'ArrowDown',
		['b_196'] = 'ArrowLeft',
		['b_197'] = 'ArrowRight',
		['b_198'] = 'Delete',
		['b_199'] = 'Escape',
		['b_200'] = 'Insert',
		['b_210'] = 'Delete',
		['b_211'] = 'Insert',
		['b_212'] = 'End',
		['b_1000'] = 'ShiftLeft',
		['b_1001'] = 'ShiftRight',
		['b_1002'] = 'Tab',
		['b_1003'] = 'Enter',
		['b_1004'] = 'Backspace',
		['b_1006'] = 'ScrollLock',
		['b_1007'] = 'Pause',
		['b_1008'] = 'Home',
		['b_1009'] = 'PageUp',
		['b_1010'] = 'PageDown',
		['b_1011'] = 'NumLock',
		['b_1012'] = 'CapsLock',
		['b_1013'] = 'ControlLeft',
		['b_1014'] = 'ControlRight',
		['b_1015'] = 'AltLeft',
		['b_1016'] = 'AltRight',
		['b_2000'] = 'Space',
		['t_/'] = 'Slash',
		['t_\\'] = 'Backslash',
	}
	local function getPttKey()
		local key = GetControlInstructionalButton(0, 0xE364B8EC, true)
		if specialKeyCodes[key] then
			return 'SpecialKey.' .. specialKeyCodes[key], key
		elseif key:sub(1, 2) == 't_' then
			return key:sub(3)
		else
			print('warning: unknown ptt key code ' .. key)
			return nil
		end
	end
	local function getConfigKeybind(name)
		if Config.keybinds and Config.keybinds[name] then
			return Config.keybinds[name]
		end
		return ''
	end

	function playerHasItem(itemName)
		if not LocalPlayer.state.isLoggedIn then
			return false
		end

		-- Ensure framework and inventory have been initialized
		if frameworkEnum == 0 or inventoryEnum == 0 then
			return false
		end
		if inventoryEnum == 1 then
			-- qb-inventory (QBCore functions)
			local hasItem = false
			if type(QBCore.Functions.GetItemByName) == 'table' then
				hasItem = not not QBCore.Functions.GetItemByName(itemName)
			elseif type(QBCore.Functions.HasItem) == 'table' then
				hasItem = not not QBCore.Functions.HasItem(itemName)
			end

			if not hasItem then
				return false
			end

			local playerData = QBCore.Functions.GetPlayerData()
			return playerData and not playerData.metadata['isdead'] and not playerData.metadata['inlaststand']

		elseif inventoryEnum == 2 then
			-- ox_inventory (asynchronous call converted to synchronous)
			local done = false
			local result = false

			local count = exports.ox_inventory:GetItemCount(itemName)
				if count > 0 then
					local playerData
					if frameworkEnum == 2 then
						playerData = exports.qbx_core:GetPlayerData()
					elseif frameworkEnum == 1 then
						playerData = QBCore.Functions.GetPlayerData()
					end
					result = not playerData.metadata['isdead'] and not playerData.metadata['inlaststand']
				else
					result = false
				end
				done = true
			-- Wait until the asynchronous callback completes (with a timeout of 1000ms)
			local startTime = GetGameTimer()
			while not done and (GetGameTimer() - startTime < 1000) do
				Citizen.Wait(0)
			end

			return result
		else
			return false
		end
	end
	function playerHasRadioItem()
		local itemName = 'sonoran_radio'
		if Config.RadioItem then
			itemName = Config.RadioItem.name
		end
		return playerHasItem(itemName)
	end

	function radioToggle(frame)
		TriggerServerEvent('SonoranRadio::CheckPermissions')
		if not authorized then
			SendNotification('Radio: ~r~No Permission~r~')
			return
		end
		local hasItem = not Config.enforceRadioItem or Radio.HasItem
		if not hasItem then
			TriggerEvent('chat:addMessage', {
				color = {
					255,
					0,
					0
				},
				multiline = true,
				args = {
					'Sonoran Radio',
					'You must have a radio to use this command.'
				}
			})
			DebugPrint('Radio Requested, but player doesn\'t have a radio.')
			return
		end

		radActive = not radActive
		if frame then
			SendNUIMessage({
				type = 'setCurrentSkin',
				skin = frame,
				skins = allowedFrames
			})
		end
		local uiPositions = json.decode(GetResourceKvpString('ui_pos_dic') or '{}')
		setmetatable(uiPositions, {__jsontype = 'object'})
		SendNUIMessage({
			type = 'setUiPositions',
			data = uiPositions,
		})
		SendNUIMessage({
			type = 'setVisible',
			visibility = radActive,
			pttKey = getPttKey()
		})
		if radActive then
			SetNuiFocus(true, true)
		else
			SetNuiFocus(false, false)
		end
		Radio:Toggle(radActive)
	end

	function emergencyCallCommand()
		return Config.emergencyCallCommand or '911'
	end
	function setEmergencyCall(enabled, displayName)
		local playerId = PlayerId()
		if type(displayName) ~= 'string' then
			displayName = nil
		end
		if Config.showEmergencyCallHelp == nil then
			Config.showEmergencyCallHelp = true
		end
		SendNUIMessage({
			type = 'setEmergencyCall',
			enabled = enabled,
			displayName = displayName,
			callCommand = emergencyCallCommand(),
			showHelpText = Config.showEmergencyCallHelp
		})
	end
	exports('setEmergencyCall', setEmergencyCall)

	RegisterNetEvent('SonoranRadio::AuthorizeRadio')
	AddEventHandler('SonoranRadio::AuthorizeRadio', function(frames, miniRadio, guest)
		DebugPrint('Authorized for Radio Usage')
		authorized = true
		allowedMiniRadio = miniRadio
		SendNUIMessage({
			type = 'setGuestAllowed',
			allowed = guest,
		})

		allowedFrames = frames
		SendNUIMessage({
			type = 'setCurrentSkin',
			skin = frame,
			skins = allowedFrames
		})
	end)

	RegisterCommand('radio', function(_, args)
		local action = args[1]
		if action == emergencyCallCommand() then
			setEmergencyCall('toggle')
		elseif action == 'channel' or action == 'scan' or action == 'scanlist' then
			local selectId = tonumber(args[2])
			if selectId == nil then return end

			local passEvents = {
				channel = 'togglePrimaryChannel',
				scan = 'toggleScanChannel',
				scanlist = 'selectScanList'
			}
			SendNUIMessage({ type = passEvents[action], id = selectId })
		elseif action == 'hide' then
			SendNUIMessage({
				type = 'setVisible',
				visibility = false
			})
		elseif action == 'refresh' then
			SendNUIMessage({ type = 'refresh' })
		elseif action == 'reset' then
			-- debug print ui info to console
			print('SONORANRADIO UI DATA')
			print('skin', GetResourceKvpString('sonoranradio_skin'))
			print('pos', GetResourceKvpString('ui_pos_dic'))

			frame = Config.defaultSkinId or 'default'
			DeleteResourceKvp('sonoranradio_skin')
			SetResourceKvp('ui_pos_dic', '{}')
			SendNUIMessage({ type = 'reset', skin = frame })
		elseif action == 'scanner' and not Config.enforceRadioItem then
			openLocalScanner()
		elseif action == 'displayname' then
			local name = table.concat(args, ' ', 2)
			SendNUIMessage({
				type = 'set_display_name',
				name = name
			})
		elseif action == Config.radioJammers.menuCommand then
			TriggerServerEvent('SonoranRadio::Request::OpenJammerMenu')
		else
			radioToggle()
		end
	end)
	RegisterCommand('sonradradio', radioToggle)

	local radioSubcommands = {
		emergencyCallCommand(),
		'channel',
		'scanlist',
		'scan',
		'hide',
		'refresh',
		'reset',
		'displayname',
		Config.radioJammers.menuCommand,
	}
	if not Config.enforceRadioItem then
		table.insert(radioSubcommands, 2, 'scanner')
	end
	local radioSubcommandHint = ''
	for i = 1, #radioSubcommands do
		local hint = radioSubcommands[i]
		if hint:find("%s") then
			hint = '"' .. hint .. '"'
		end

		if i ~= 1 then radioSubcommandHint = radioSubcommandHint .. '|' end
		radioSubcommandHint = radioSubcommandHint .. hint
	end
	TriggerEvent('chat:addSuggestion', '/radio', 'Open or focus Sonoran Radio', {{name = radioSubcommandHint, help = 'Subcommand'}})

	RegisterCommand('radiotalk', function()
		Radio.TalkAnim = not Radio.TalkAnim
		if Radio.TalkAnim then
			SendNotification('Radio Talk Animation: ~g~On~g~')
		else
			SendNotification('Radio Talk Animation: ~r~Off~r~')
		end
	end)
	RegisterKeyMapping('radiotalk', 'Toggle Radio Talk Animation', 'keyboard', '')

	RegisterCommand('radiohud', function(source, args, rawCommand)
		-- toggle Radio.Hud
		Radio.Hud = Radio.Hud == 'off' and 'on' or 'off'
		SendNUIMessage({
			type = 'radioHud',
			size = Radio.Hud
		})
	end)
	TriggerEvent('chat:addSuggestion', '/radiohud', 'Toggle the radio HUD', {})

	RegisterCommand('radiovolume', function(source, args)
		local volume = tonumber(args[1])
		if volume == nil then
			SendNotification('Radio Volume: ~r~Invalid~r~')
			return
		end

		volume = math.min(volume, 250)
		SendNUIMessage({
			type = 'setVolume',
			volume = volume,
		})
		SendNotification('Radio Volume: ~g~' .. volume .. '%~g~')
	end)
	TriggerEvent('chat:addSuggestion', '/radiovolume', 'Change the voice volume of all radios', {{name = 'volume', help = 'The volume percentage (0-250%)'}})

	RegisterNetEvent('SonoranRadio::API:NextPreset')
	AddEventHandler('SonoranRadio::API:NextPreset', function()
		SendNUIMessage({
			type = 'pushButton',
			button = 'next'
		})
	end)

	RegisterNetEvent('SonoranRadio::API:PrevPreset')
	AddEventHandler('SonoranRadio::API:PrevPreset', function()
		SendNUIMessage({
			type = 'pushButton',
			button = 'prev'
		})
	end)

	RegisterNetEvent('SonoranRadio::API:GroupNext')
	AddEventHandler('SonoranRadio::API:GroupNext', function()
		SendNUIMessage({
			type = 'pushButton',
			button = 'group_next'
		})
	end)

	RegisterNetEvent('SonoranRadio::API:GroupPrev')
	AddEventHandler('SonoranRadio::API:GroupPrev', function()
		SendNUIMessage({
			type = 'pushButton',
			button = 'group_prev'
		})
	end)

	RegisterNetEvent('SonoranRadio::API:VolumeUp')
	AddEventHandler('SonoranRadio::API:VolumeUp', function()
		SendNUIMessage({
			type = 'pushButton',
			button = 'vol_up'
		})
	end)

	RegisterNetEvent('SonoranRadio::API:VolumeDown')
	AddEventHandler('SonoranRadio::API:VolumeDown', function()
		SendNUIMessage({
			type = 'pushButton',
			button = 'vol_down'
		})
	end)

	RegisterNetEvent('SonoranRadio::API:PowerToggle')
	AddEventHandler('SonoranRadio::API:PowerToggle', function()
		SendNUIMessage({
			type = 'pushButton',
			button = 'power'
		})
	end)

	RegisterNetEvent('SonoranRadio::API:PanicButton')
	AddEventHandler('SonoranRadio::API:PanicButton', function()
		SendNUIMessage({
			type = 'pushButton',
			button = 'panic'
		})
	end)

	RegisterNetEvent('SonoranRadio::API:SetPreset')
	AddEventHandler('SonoranRadio::API:SetPreset', function(number)
		SendNUIMessage({
			type = 'goToPreset',
			preset = number
		})
	end)

	-- Next
	RegisterCommand('sonradnext', function()
		TriggerEvent('SonoranRadio::API:NextPreset')
	end)

	-- Previous
	RegisterCommand('sonradprev', function()
		TriggerEvent('SonoranRadio::API:PrevPreset')
	end)

	RegisterCommand('sonradgroupnext', function()
		TriggerEvent('SonoranRadio::API:GroupNext')
	end)

	RegisterCommand('sonradgroupprev', function()
		TriggerEvent('SonoranRadio::API:GroupPrev')
	end)

	-- Power
	RegisterCommand('sonradpower', function()
		TriggerEvent('SonoranRadio::API:PowerToggle')
	end)

	-- Panic
	RegisterCommand('sonradpanic', function()
		TriggerEvent('SonoranRadio::API:PanicButton')
	end)

	RegisterCommand('sonradvolup', function()
		TriggerEvent('SonoranRadio::API:VolumeUp')
	end)

	RegisterCommand('sonradvoldown', function()
		TriggerEvent('SonoranRadio::API:VolumeDown')
	end)

	RegisterCommand('sonradtoggleai', function()
		SendNUIMessage({
			type = 'toggle_ai'
		})
	end)

	RegisterKeyMapping('sonradradio', 'Show Radio', 'keyboard', getConfigKeybind('toggle'))
	RegisterKeyMapping('sonradnext', 'Next Channel (In Group)', 'keyboard', getConfigKeybind('nextChannel'))
	RegisterKeyMapping('sonradprev', 'Prev Channel (In Group)', 'keyboard', getConfigKeybind('prevChannel'))
	RegisterKeyMapping('sonradpower', 'Radio Power', 'keyboard', getConfigKeybind('power'))
	RegisterKeyMapping('sonradpanic', 'Radio Panic', 'keyboard', getConfigKeybind('panic'))
	RegisterKeyMapping('sonradgroupnext', 'Next Group', 'keyboard', getConfigKeybind('nextGroup'))
	RegisterKeyMapping('sonradgroupprev', 'Prev Group', 'keyboard', getConfigKeybind('prevGroup'))
	RegisterKeyMapping('sonradvolup', 'Volume Up', 'keyboard', getConfigKeybind('volUp'))
	RegisterKeyMapping('sonradvoldown', 'Volume Down', 'keyboard', getConfigKeybind('volDown'))
	RegisterKeyMapping('sonradtoggleai', 'Toggle AI', 'keyboard', getConfigKeybind('toggleAi'))


	-- add PTT for the standalone radio
	RegisterCommand('+sonradptt', function()
		SendNUIMessage({
			type = 'ptt',
			state = true
		})
	end)
	RegisterCommand('-sonradptt', function()
		SendNUIMessage({
			type = 'ptt',
			state = false
		})
	end)
	RegisterKeyMapping('+sonradptt', 'Radio PTT', 'keyboard', getConfigKeybind('ptt'))

	local function headingToDirectionCallout(heading)
		if heading >= 45 and heading < 135 then
			return 'westbound'
		elseif heading >= 135 and heading < 225 then
			return 'southbound'
		elseif heading >= 225 and heading < 315 then
			return 'eastbound'
		else
			return 'northbound'
		end
	end
	local function isOppositeDirection(a, b)
		if not a or not b then
			return true
		end
		if a == 'southbound' or a == 'westbound' then
			-- swap values so a is always north/east and b is always south/west if opposite
			local tmp = a
			a = b
			b = tmp
		end
		return (a == 'northbound' and b == 'southbound') or (a == 'eastbound' and b == 'westbound')
	end
	local function getCurrentCallout(streetNameCache)
		local ped = PlayerPedId()
		local dir = headingToDirectionCallout(GetEntityHeading(ped))

		-- get the coord of the closest vehicle node (favoring the direction the player is facing)
		local playerCoord = GetEntityCoords(ped)
		local playerForwardCoord = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.0, 0.0)
		local found, coord, heading = GetNthClosestVehicleNodeFavourDirection(
			playerCoord.x, playerCoord.y, playerCoord.z,
			playerForwardCoord.x, playerForwardCoord.y, playerForwardCoord.z,
			0, 0, 0, 0
		)
		if not found or #(playerCoord - coord) > 40 then
			return dir -- not near a street
		end

		-- get the street names at the vehicle node coordinate
		local streetHash, crossStreetHash = GetStreetNameAtCoord(coord.x, coord.y, coord.z)
		local street = streetNameCache[streetHash]
		if streetHash ~= 0 and not street then
			street = GetStreetNameFromHashKey(streetHash)
			streetNameCache[streetHash] = street
		end
		local crossStreet = streetNameCache[crossStreetHash]
		if crossStreetHash ~= 0 and not crossStreet then
			crossStreet = GetStreetNameFromHashKey(crossStreetHash)
			streetNameCache[crossStreetHash] = crossStreet
		end

		return dir, street, crossStreet
	end
	local calloutThreadStatus = 'killed'
	local function autoCalloutsThread()
		local streetNameCache = {}

		local speedAverage = 0.0
		local speedAlpha = 0.1104

		local loc = {}
		local establishedLoc = {}

		while calloutThreadStatus == 'run' do
			local ped = PlayerPedId()
			if IsPedInAnyVehicle(ped, false) then
				local veh = GetVehiclePedIsIn(PlayerPedId(), false)

				-- find the vehicle's current speed (based on the config opt)
				local speed
				if Config.autoCallouts.speedUnit == 'mph' then
					speed = GetEntitySpeed(veh) * 2.23694
				elseif Config.autoCallouts.speedUnit == 'kmh' then
					speed = GetEntitySpeed(veh) * 3.6
				else
					speed = -1
				end
				-- compute the EMA of the vehicle speed
				if speedAverage < 10.0 then
					speedAverage = speed
				else
					speedAverage = (speedAlpha * speed) + (1 - speedAlpha) * speedAverage
				end

				local direction, street, crossStreet = getCurrentCallout(streetNameCache)
				if direction ~= loc.direction then
					loc.direction = direction
					loc.speed = speedAverage
					loc.time = GetGameTimer()
				end
				if street ~= loc.street then
					loc.street = street
					loc.speed = speedAverage
					loc.time = GetGameTimer()
				end

				if (GetGameTimer() - loc.time) > 1525 and loc.street and (loc.street ~= establishedLoc.street or isOppositeDirection(loc.direction, establishedLoc.direction)) then
					establishedLoc.street = loc.street
					establishedLoc.direction = loc.direction
					establishedLoc.speed = loc.speed
					local postalCode = Config.autoCallouts.withPostals and
						exports[Config.autoCallouts.postalResource or 'nearest-postal']:getPostal() or
						nil
					SendNUIMessage({
						type = 'broadcastLocation',
						loc = {
							heading = establishedLoc.direction,
							street = establishedLoc.street,
							postal = postalCode,
							speed = math.floor(establishedLoc.speed / 5.0 + 2.5) * 5.0, -- round to nearest 5
							speeds = 'speeds',
						}
					})
				end
			else
				speedAverage = 0.0
				loc = {}
				establishedLoc = {}
			end

			Citizen.Wait(250)
		end
		calloutThreadStatus = 'killed'
	end

	-- add default for auto callouts
	if Config.autoCallouts == nil then
		Config.autoCallouts = {
			enabled = true,
			speedUnit = 'mph',
		}
	end
	-- if auto callouts are enabled, add the command and keybind
	if Config.autoCallouts.enabled then
		RegisterCommand('sonradtogglecallouts', function()
			if calloutThreadStatus == 'killed' then
				calloutThreadStatus = 'run'
				Citizen.CreateThreadNow(autoCalloutsThread)
				TriggerEvent('chat:addMessage', {
					args = {'Sonoran Radio', 'Auto-Callouts Enabled'},
					color = {255, 0, 0}
				})
			else
				-- ! kill, not killed
				-- ! this prevents multiple auto callout threads if spamming the keybind/command
				calloutThreadStatus = 'kill'
				TriggerEvent('chat:addMessage', {
					args = {'Sonoran Radio', 'Auto-Callouts Disabled'},
					color = {255, 0, 0}
				})
			end
		end)
		RegisterKeyMapping('sonradtogglecallouts', 'Toggle Auto-Callouts', 'keyboard', getConfigKeybind('toggleAutoCallouts'))
	end

	local function emergencyCallRedialNotif()
		local crashout = false
		Citizen.CreateThread(function()
			local start = GetGameTimer()
			local notifs = {}
			PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
			while (GetGameTimer() - start) < 10000 and not crashout do
				BeginTextCommandThefeedPost("STRING")
				AddTextComponentSubstringPlayerName('Emergency Services is trying to re-dial you! Press ~g~Y~s~ within 10s to accept')
				local notifId = EndTextCommandThefeedPostMessagetext("CHAR_CALL911", "CHAR_CALL911", false, 0, "Emergency Services", 'Re-dial')
				table.insert(notifs, notifId)
				Citizen.Wait(1000)
			end
			for _, notifId in ipairs(notifs) do
				ThefeedRemoveItem(notifId)
			end
		end)
		Citizen.CreateThread(function()
			local start = GetGameTimer()
			while (GetGameTimer() - start) < 10000 do
				if IsControlJustReleased(0, 246) then
					crashout = true
					setEmergencyCall(true)
					break
				end
				Citizen.Wait(0)
			end
		end)
	end

	function Radio:Talking(toggle)
		local inVeh = IsPedInAnyVehicle(PlayerPedId(), false)
		TriggerEvent('SonoranRadio::API:Talking', toggle, inVeh)
		if self.TalkAnim then
			if toggle and not inVeh then
				if self.Open then
					RequestAnimDict('cellphone@')
					while not HasAnimDictLoaded('cellphone@') do
						Citizen.Wait(5)
					end
					TaskPlayAnim(PlayerPedId(), 'cellphone@', 'cellphone_text_to_call', 8.0, 0.0, -1, 50, 0, false, false, false)

					-- Wait(300)
					-- RequestAnimDict("cellphone@str")
					-- while not HasAnimDictLoaded("cellphone@str") do Wait(5) end
					-- TaskPlayAnim(PlayerPedId(), "cellphone@str","cellphone_call_listen_a", 8.0, 0.0, -1, 50, 0, false, false, false)

					isTalking = true
				else
					RequestAnimDict('random@arrests')
					while not HasAnimDictLoaded('random@arrests') do
						Citizen.Wait(5)
					end
					TaskPlayAnim(PlayerPedId(), 'random@arrests', 'generic_radio_chatter', 8.0, 0.0, -1, 49, 0, 0, 0, 0)
					isTalking = true
				end
			else
				if self.Open then
					-- cellphone@cellphone_call_to_text
					-- cellphone@cellphone_text_read_base
					--

					-- StopAnimTask(PlayerPedId(), "cellphone@","cellphone_text_to_call", 4.0)
					if inVeh then
						return
					end
					-- Citizen.Wait(700)
					RequestAnimDict('cellphone@')
					while not HasAnimDictLoaded('cellphone@') do
						Citizen.Wait(5)
					end
					-- TaskPlayAnim(PlayerPedId(), "cellphone@", "cellphone_text_in", 4.0, -1, -1, 50, 0, false, false, false)
					TaskPlayAnim(PlayerPedId(), 'cellphone@', 'cellphone_call_to_text', 4.0, -1, -1, 50, 0, false, false, false)
					isTalking = false
				else
					StopAnimTask(PlayerPedId(), 'random@arrests', 'generic_radio_chatter', -4.0)
					isTalking = false
				end
			end
		else
			if isTalking then
				StopAnimTask(PlayerPedId(), 'cellphone@str', 'cellphone_call_listen_a', -4.0)
				StopAnimTask(PlayerPedId(), 'random@arrests', 'generic_radio_chatter', -4.0)
				isTalking = false
			end
		end
	end

	function Radio:Toggle(toggle)
		local playerPed = PlayerPedId()
		local count = 0

		if IsEntityDead(playerPed) then
			self.Open = false

			DetachEntity(self.Handle, true, false)
			DeleteEntity(self.Handle)

			return
		end

		if self.Open == toggle then
			return
		end
		if IsPlayerFreeAiming(PlayerId()) or IsPedInAnyVehicle(PlayerPedId()) then
			return
		end

		self.Open = toggle

		local dictionaryType = 1 + (IsPedInAnyVehicle(playerPed, false) and 1 or 0)
		local animationType = 1 + (self.Open and 0 or 1)
		local dictionary = self.Dictionary[dictionaryType]
		local animation = self.Animation[animationType]

		RequestAnimDict(dictionary)

		while not HasAnimDictLoaded(dictionary) do
			Citizen.Wait(150)
		end

		if self.Open then
			RequestModel(self.Prop)
			while not HasModelLoaded(self.Prop) do
				Citizen.Wait(150)
			end
			self.Handle = CreateObject(self.Prop, 0.0, 0.0, 0.0, true, true, false)
			local bone = GetPedBoneIndex(playerPed, self.Bone)
			SetCurrentPedWeapon(playerPed, GetHashKey('weapon_unarmed'), true)
			AttachEntityToEntity(self.Handle, playerPed, bone, self.Offset.x, self.Offset.y, self.Offset.z, self.Rotation.x, self.Rotation.y, self.Rotation.z, true, false, false, false, 2, true)
			SetModelAsNoLongerNeeded(self.Handle)
			TaskPlayAnim(playerPed, dictionary, animation, 4.0, -1, -1, 50, 0, false, false, false)
		elseif DoesEntityExist(self.Handle) then
			local radioHndl = self.Handle
			TaskPlayAnim(playerPed, dictionary, animation, 4.0, -1, -1, 50, 0, false, false, false)
			Citizen.Wait(700)
			StopAnimTask(playerPed, dictionary, animation, 1.0)
			NetworkRequestControlOfEntity(radioHndl)
			while not NetworkHasControlOfEntity(radioHndl) and count < 5000 do
				Citizen.Wait(0)
				count = count + 1
			end
			DetachEntity(radioHndl, true, false)
			DeleteEntity(radioHndl)
		end
	end

	function Radio:Destroy()
		local playerPed = PlayerPedId()
		local count = 0
		NetworkRequestControlOfEntity(self.Handle)
		while not NetworkHasControlOfEntity(self.Handle) and count < 5000 do
			Citizen.Wait(0)
			count = count + 1
		end
		DetachEntity(self.Handle, true, false)
		DeleteEntity(self.Handle)
	end

	local function initNui()
		local chatter = Config.chatter
		if chatter == nil then chatter = true end
		SendNUIMessage({
			type = 'setConfig',
			standaloneId = comId,
			roomId = Config.serverId,
			standaloneUrl = Config.radioUrl,
			defaultEscapeMode = Config.defaultEscapeMode,
			chatter = chatter,
			debug = Config.debug,
			displayName = GetPlayerName(PlayerId()),
		})
	end
	Citizen.CreateThread(function()
		if critError or Config.critError then return end
		SetNuiFocus(false, false)
		TriggerServerEvent('SonoranRadio::CheckPermissions')
		initNui()

		DebugPrint('Sonoran Radio Started!')
	end)

	function SendNotification(message)
		BeginTextCommandThefeedPost('STRING')
		AddTextComponentSubstringPlayerName(message)
		EndTextCommandThefeedPostTicker(false, false)
	end

	RegisterNUICallback('data', function(data, cb)
		if data.type == 'ready' then
			initNui()
		end

		if data.type == 'escape' then
			radActive = false
			SetNuiFocus(false, false)
			Radio:Toggle(radActive)
		end

		if data.type == 'notify' then
			SendNotification(data.message)
		end

		if data.type == 'panic' then
			TriggerServerEvent('SonoranRadio::PanicState', data.status)
			if data.status then
				if Config.autoPttOnPanic then
					if Config.autoPttOnPanic.enabled then
						Radio:Talking(true)
						SendNUIMessage({
							type = 'ptt',
							state = true
						})
						Citizen.SetTimeout(Config.autoPttOnPanic.duration * 1000, function()
							SendNUIMessage({
								type = 'ptt',
								state = false
							})
							Radio:Talking(false)
						end)
					end
				end
				TriggerServerEvent('SonoranCAD::callcommands:SendPanicApi')
			else
				if Config.autoPttOnPanic then
					if Config.autoPttOnPanic.enabled then
						SendNUIMessage({
							type = 'ptt',
							state = false
						})
						Radio:Talking(false)
					end
				end
			end
		end

		if data.type == 'emergencyCallStatus' then
			isEmergCallActive = data.status
			TriggerEvent('SonoranRadio::API:EmergencyCall', data.status)
		elseif data.type == 'emergencyCallDispatcher' then
			TriggerEvent('SonoranRadio::API:EmergencyCallDispatcher', data.dispatcherNames)
		elseif data.type == 'emergencyCallRedial' then
			TriggerEvent('SonoranRadio::API:EmergencyCallRedial')
			if not WasEventCanceled() then
				emergencyCallRedialNotif()
			end
		end

		if data.type == 'power' then
			handleRadioPower(data.power)
			Radio.On = data.power
		end

		if data.type == 'radioConnected' and data.config.myself and not calledSyncAcePerms then
			-- we don't want to send all profiles since there could be a lot of data,
			-- so just extract the data we need
			local profilesInfo = {}
			for _, prof in ipairs(data.config.profiles) do
				if prof.visibility ~= 'public' then
					table.insert(profilesInfo, { id = prof.id, displayName = prof.displayName, visibility = prof.visibility })
				end
			end
			TriggerServerEvent('SonoranRadio::SyncAcePerms', data.config.myself.accId, profilesInfo, false)
			calledSyncAcePerms = true
		elseif data.type == 'radioNeedsAuth' then
			TriggerServerEvent('SonoranRadio::SyncAcePerms', data.accId, {}, true)
		end

		if data.type == 'talking' then
			Radio:Talking(data.talking)
		end

		if data.type == 'setUiPositions' then
			-- save positions of components in the UI
			setmetatable(data.data, {__jsontype = 'object'})
			SetResourceKvp('ui_pos_dic', json.encode(data.data))
		end

		if data.type == 'stateUpdated' or data.type == 'stateUpdatedEmergencyCall' then
			-- replicate the new state to other clients
			if type(data.state) == 'table' then data.state.gamestate = nil end
			TriggerServerEvent('SonoranRadio::SetRadioState', data.state)
		end

		if data.type == 'refreshScreen' then
			calledSyncAcePerms = false
			handleRefreshScreen()
		end

		if data.type == 'currentSkinUpdated' then
			frame = data.skin
			SetResourceKvp('sonoranradio_skin', frame)
			print('setting current frame', frame)
		end

		if data.type == 'saveSkinConfig' then
			TriggerServerEvent('SonoranRadio::SaveSkinConfig', data.configPath, data.config)
		end

		if data.type == 'chatterInit' then
			chatterForceUpdate() -- force a resend of important chatter info
		end

		if data.type == 'toggle_background_audio_confirm' then
			TriggerEvent('SonoranRadio::API:BackgroundAudio', data.start, data.trackId)
		end

		if data.type == 'routeToPostal' then
			ExecuteCommand('postal '..data.postal)
		end
		if data.type == 'routeToCoordinates' then
			SetNewWaypoint(data.x, data.y)
		end

		cb('OK')
	end)

	RegisterNetEvent('SonoranRadio::EmergencyCallToken')
	RegisterNUICallback('create-emergency-call-token', function(_data, cb)
		local handlerId
		handlerId = AddEventHandler('SonoranRadio::EmergencyCallToken', function(guestToken)
			RemoveEventHandler(handlerId)
			cb({ guestToken = guestToken })
		end)
		TriggerServerEvent('SonoranRadio::CreateEmergencyCallToken')
	end)
	RegisterNetEvent('SonoranRadio::RadioGuestToken')
	RegisterNUICallback('create-guest-token', function(_data, cb)
		local handlerId
		handlerId = AddEventHandler('SonoranRadio::RadioGuestToken', function(guestToken)
			RemoveEventHandler(handlerId)
			cb({
				guestToken = guestToken,
				displayName = GetPlayerName(PlayerId()),
			})
		end)
		TriggerServerEvent('SonoranRadio::CreateGuestToken')
	end)

	AddEventHandler('onResourceStart', function(resource)
		if GetCurrentResourceName() ~= resource then
			return
		end
		getInventory()
		getFramework()

		DebugPrint('Sonoran Radio Starting...')
		TriggerEvent('chat:addSuggestion', '/radio', 'Open the Sonoran Radio Interface')
		TriggerEvent('chat:addSuggestion', '/radioreset', 'Reconnect radio to teamspeak')
		TriggerEvent('chat:addSuggestion', '/radiotalk', 'Toggle your radio talk animation')
		TriggerEvent('chat:addSuggestion', '/radiovolume', 'Change the voice volume of all radios', {{name = 'volume', help = 'The volume percentage (0-250%)'}})
		DebugPrint('Sonoran Radio Started!')
		if GetResourceState('BigDaddy-RadioAnimation') == 'started' then
			print('BigDaddy-RadioAnimation Started... disabling SonoranRadio talk animations')
			Radio.TalkAnim = false
		end
	end)

	AddEventHandler('onResourceStop', function(resource)
		if GetCurrentResourceName() ~= resource then
			return
		end
		DebugPrint('Sonoran Radio Stopping...')
		TriggerEvent('chat:removeSuggestion', '/radio')
		TriggerEvent('chat:removeSuggestion', '/radioreset')
		TriggerEvent('chat:removeSuggestion', '/radiotalk')
		Radio:Destroy()
	end)

	PlayerDead = false
	local RadioLastState = nil

	RegisterNetEvent('SonoranRadio::PlayerDeath', function()
		PlayerDead = true
		if Config.disableRadioOnDeath then
			if Radio.On then
				local inVeh = IsPedInAnyVehicle(PlayerPedId(), false)
				TriggerEvent('SonoranRadio::API:Talking', false, inVeh)
				Radio.Enabled = false
				Radio:Toggle(false)
				isTalking = false
				SendNUIMessage({
					type = 'setVisible',
					visibility = false
				})
				SendNUIMessage({
					type = 'power',
					power = false
				})
				SendNUIMessage({
					type = 'radioHud',
					size = 'off'
				})
				SetNuiFocus(false, false)
				DebugPrint('Radio Disabled Due to Death.')
			end
		end
	end)

	RegisterNetEvent('SonoranRadio::PlayerRevive', function()
		PlayerDead = false
		if Config.disableRadioOnDeath then
			if Config.restoreRadioStateWhenAlive then
				if Radio.Enabled == false then
					SendNUIMessage({
						type = 'power',
						power = true
					})
					SendNUIMessage({
						type = 'radioHud',
						size = Radio.Hud
					})
				end
			end
			Radio.Enabled = true
		end
	end)

	exports('isRadioActive', function()
		return Radio.Enabled
	end)

	local QBDeath = false

	RegisterNetEvent('SonoranRadio:SyncTunnels', function(TunnelsServer)
		tunnels = TunnelsServer
		for _, zoneData in pairs (tunnels) do
			DebugPrint('Attempting to create zone: ' .. zoneData.options.name)
			if not polyZonesTable[zoneData.options.name] then
				DebugPrint('Zone was not found, creating...')
				local points = {}
				for _, point in pairs (zoneData.points) do
					table.insert(points, vector2(point.x, point.y))
				end
				DebugPrint('Creating zone with ' .. #points .. ' points', json.encode(points))
				local options = zoneData.options -- options
				polyZonesTable[zoneData.options.name] = PolyZone:Create(points, {
					name = options.name,
					minZ = options.minZ,
					maxZ = options.maxZ,
					degradeStrength = options.degradeStrength,
					debugGrid = Config.debug
				})
				DebugPrint('Zone created: ' .. zoneData.options.name)
			end
		end
	end)

	RegisterNetEvent('SonoranRadio::AdminSkinChange', function(frame)
		frame = frame or Config.defaultSkinId or 'default'

		if Config.frames.permissionMode == 'qbcore' and Config.enforceRadioItem and not Radio.HasItem then
			TriggerEvent('chat:addMessage', {
				color = {
					255,
					0,
					0
				},
				multiline = true,
				args = {'Sonoran Radio','You must have a radio to change frames.'}
			})
			return
		end

		SendNUIMessage({
			type = 'setCurrentSkin',
			skin = frame
		})
		TriggerEvent('chat:addMessage', {
			args = {
				'^1SonoranRadio',
				'Changed your radio skin to ' .. frame .. ''
			}
		})
	end)

	TriggerEvent('chat:addSuggestion', '/adminskinchange', 'Change your radio skin', {
		{
			name = 'frame',
			help = 'The frame name to change to'
		}
	})

	-- TriggerEvent('chat:addSuggestion', '/spawnradiotower', 'Spawn a radio tower')
	-- TriggerEvent('chat:addSuggestion', '/spawnradiorack', 'Spawn a radio rack', {
	-- 	{
	-- 		name = 'numberOfServers',
	-- 		help = 'The number of servers to spawn'
	-- 	}
	-- })
	-- TriggerEvent('chat:addSuggestion', '/spawnradiocellrepeater', 'Spawn a radio cell repeater')
	-- TriggerEvent('chat:addSuggestion', '/removeradiorepeater', 'Remove the nearest radio repeater')
	TriggerEvent('chat:addSuggestion', '/radiomenu', 'Open the radio repeaters\' spawning/manipulation menu')

	RegisterNetEvent('SonoranRadio::OpenRadioMenu', function()
		WarMenu.OpenMenu('sonoranRadioMenu')
	end)

	AddEventHandler('onResourceStart', function(resourceName)
		if resourceName == 'BigDaddy-RadioAnimation' then
			print('BigDaddy-RadioAnimation Started... disabling SonoranRadio talk animations')
			Radio.TalkAnim = false
		end
	end)

	RegisterNetEvent('SonoranRadio::CritError', function(toggle)
		if toggle then
			critError = true
			TriggerEvent('chat:addMessage', {
				color = {
					255,
					0,
					0
				},
				multiline = true,
				args = {
					'Sonoran Radio',
					'There is a critical error with SonoranRadio configuration. The API key is incorrect or missing. Please contact the server owner.'
				}
			})
		else
			critError = false
		end
	end)
	RegisterNetEvent('SonoranRadio::DisplayError', function(msg)
		TriggerEvent('chat:addMessage', {
			color = {255, 0, 0},
			args = {
				'Sonoran Radio',
				'Error: '..(msg or 'unknown error')
			}
		})
	end)
	RegisterNetEvent('SonoranRadio::DisplayInfo', function(msg)
		TriggerEvent('chat:addMessage', {
			color = {255, 0, 0},
			args = {
				'Sonoran Radio',
				'Info: '..(msg or 'no message?')
			}
		})
	end)

	RegisterNetEvent('QBCore:Client:OnJobUpdate', function(_)
		TriggerServerEvent('SonoranRadio::CheckPermissions')
	end)

	RegisterNetEvent('SonoranRadio::RequestClientData', function()
		TriggerEvent('SonoranRadio:CarRadioPower', Radio.On)
		if Radio.On then
			Citizen.Wait(1000)
			SendNUIMessage({
				type = "get_connected_users",
			})
		end
	end)

	RegisterNetEvent('SonoranRadio::RefreshScreen', function()
		SendNUIMessage({ type = 'refresh' })
	end)

	local lvcStarted = false
	local state_lxsiren = 0
	local state_pwrcall = 0
	local state_airmanu = 0
	local lastVeh = 0
	local lastNetId = nil
	local lastSirenState = false
	Citizen.CreateThread(function()
		if GetResourceState(Config.luxartResourceName) == 'started' then
			lvcStarted = true
			AddEventHandler('lvc:UpdateThirdParty', function(data)
				data = json.encode(data)
				data = json.decode(data)
				state_lxsiren = data.state_lxsiren or 0
				state_pwrcall = data.state_pwrcall or 0
				state_airmanu = data.state_airmanu or 0
				if state_lxsiren > 0 or state_pwrcall > 0 or state_airmanu > 0 then
					SendNUIMessage({
						type = 'siren_toggle',
						state = true
					})
					local ped = PlayerPedId()
					local veh = GetVehiclePedIsIn(ped, false)

					-- Only proceed if you're actually in a vehicle
					if veh and veh ~= 0 then
					-- Optionally check it really is networked
						if NetworkGetEntityIsNetworked(veh) then
							local netId = NetworkGetNetworkIdFromEntity(veh)
							if netId and netId ~= 0 then
							-- safe to send to server now
							TriggerServerEvent('sonoranradio:syncSirenState', true, netId)
							end
						end
					end
				else
					SendNUIMessage({
						type = 'siren_toggle',
						state = false
					})
					local ped = PlayerPedId()
					local veh = GetVehiclePedIsIn(ped, false)

					-- Only proceed if you're actually in a vehicle
					if veh and veh ~= 0 then
					-- Optionally check it really is networked
						if NetworkGetEntityIsNetworked(veh) then
							local netId = NetworkGetNetworkIdFromEntity(veh)
							if netId and netId ~= 0 then
							-- safe to send to server now
							TriggerServerEvent('sonoranradio:syncSirenState', false, netId)
							end
						end
					end
				end
			end)
		else
			while not lvcStarted do
				local ped = PlayerPedId()
				local veh = GetVehiclePedIsIn(ped, false)
				local isDriver = (veh and veh ~= 0) and (GetPedInVehicleSeat(veh, -1) == ped)

				-- VEHICLE CHANGE / EXIT DETECTION (driver only)
				if veh ~= lastVeh then
					-- if we just left being the driver, send siren-off for old vehicle
					if lastVeh and lastVeh ~= 0 and lastNetId then
						TriggerServerEvent('sonoranradio:syncSirenState', false, lastNetId)
					end

					-- update to new vehicle (or none)
					lastVeh = veh

					if isDriver and NetworkGetEntityIsNetworked(veh) then
						lastNetId = NetworkGetNetworkIdFromEntity(veh)
					else
						lastNetId = nil
					end
				end

				-- ONLY WHEN YOU’RE DRIVER, SYNC SIREN
				local sirenState = isDriver and (not not lastNetId) and IsVehicleSirenOn(veh)
				if sirenState ~= lastSirenState then
					lastSirenState = sirenState
					SendNUIMessage({ type = 'siren_toggle', state = sirenState })
					TriggerServerEvent('sonoranradio:syncSirenState', sirenState, lastNetId)
				end

				Citizen.Wait(100)
			end
		end
	end)

	RegisterNetEvent('onResourceStart', function(resourceName)
		if resourceName == Config.luxartResourceName then
			if not lvcStarted then
				lvcStarted = true
				AddEventHandler('lvc:UpdateThirdParty', function(data)
					data = json.encode(data)
					data = json.decode(data)
					state_lxsiren = data.state_lxsiren or 0
					state_pwrcall = data.state_pwrcall or 0
					state_airmanu = data.state_airmanu or 0
					if state_lxsiren > 0 or state_pwrcall > 0 or state_airmanu > 0 then
						SendNUIMessage({
							type = 'siren_toggle',
							state = true
						})
					else
						SendNUIMessage({
							type = 'siren_toggle',
							state = false
						})
					end
				end)
				end
		end
	end)

	AddEventHandler('onResourceStop', function(resourceName)
		if resourceName == Config.luxartResourceName then
			lvcStarted = false
		end
	end)

	if Config.enableBackgroundAudio then
		-- Initialize background audio for vehicles and weapons
		local currentLoopingSounds = {}
		-- Define categorized track IDs
		local TrackIDs = {
			["VEHICLE_SIREN"] = "siren",
			["BOAT"] = "boat_engine",
			["HELI"] = "helicopter_rotors",
			["PISTOL"] = "gunshot_pistol",
			["RIFLE"] = "gunshot_rifle"
		}

		local dists = {
			["VEHICLE_SIREN"] = 0.0,
			["BOAT"] = 0.0,
			["HELI"] = 0.0,
		}

		local DIST_THRESHOLD = 0.05  -- 5% change
		local lastSentState, lastSentVol = false, nil
		local remoteSirens = {}  -- [playerId] = {vol = number, coords = vector3}
		local MAX_DIST = 100.0

		-- Define weapon categories
		local WeaponCategories = {
			["PISTOL"] = {
				`weapon_pistol`,
				`weapon_pistol_mk2`,
				`weapon_combatpistol`,
				`weapon_appistol`,
				`weapon_stungun`,
				`weapon_pistol50`,
				`weapon_snspistol`,
				`weapon_snspistol_mk2`,
				`weapon_heavypistol`,
				`weapon_vintagepistol`,
				`weapon_flaregun`,
				`weapon_marksmanpistol`,
				`weapon_revolver`,
				`weapon_revolver_mk2`,
				`weapon_doubleaction`,
				`weapon_ceramicpistol`,
				`weapon_navyrevolver`,
				`weapon_gadgetpistol`,
				`weapon_stungun_mp`
			},
			["RIFLE"] = {
				`weapon_assaultrifle`,
				`weapon_assaultrifle_mk2`,
				`weapon_carbinerifle`,
				`weapon_carbinerifle_mk2`,
				`weapon_advancedrifle`,
				`weapon_specialcarbine`,
				`weapon_specialcarbine_mk2`,
				`weapon_bullpuprifle`,
				`weapon_bullpuprifle_mk2`,
				`weapon_compactrifle`,
				`weapon_militaryrifle`,
				`weapon_heavyrifle`,
				`weapon_tacticalrifle`,
				`weapon_marksmanrifle`,
				`weapon_marksmanrifle_mk2`,
				`weapon_precisionrifle`,
				`weapon_dbshotgun`,
				`weapon_autoshotgun`,
				`weapon_bullpupshotgun`,
				`weapon_heavyshotgun`,
				`weapon_pumpshotgun`,
				`weapon_pumpshotgun_mk2`,
			}
		}
		-- Utility: check if weapon is suppressed
		local function IsWeaponSuppressed(weapon)
			return IsPedCurrentWeaponSilenced(PlayerPedId())
		end

		-- Utility: get weapon category
		local function GetWeaponCategory(weapon)
			for category, weapons in pairs(WeaponCategories) do
				for _, w in ipairs(weapons) do
					if weapon == w then
						return category
					end
				end
			end
			return nil
		end

		-- Emit NUI event
		local function ToggleAudio(start, trackId, volume)
			SendNUIMessage({
				type = "toggle_background_audio",
				start = start,
				trackId = trackId,
				volume = volume
			})
		end

		RegisterNetEvent('SonoranRadio::API:BackgroundAudio', function(start, trackId)
			if start then
				currentLoopingSounds[trackId] = true
			else
				currentLoopingSounds[trackId] = nil
			end
		end)

		RegisterNetEvent('sonoranradio:receiveSirenState')
		AddEventHandler('sonoranradio:receiveSirenState', function(srcPlayer, isOn, vehNetId)
			if isOn and vehNetId then
				-- store by vehicle network‐ID
				remoteSirens[vehNetId] = true
			elseif vehNetId then
				if not remoteSirens[vehNetId] then
					-- if the vehicle is not in the table, we don't need to do anything
					return
				end
				-- remove by the same network‐ID
				remoteSirens[vehNetId] = nil
			end
		end)

		-- Main thread
		Citizen.CreateThread(function()
			while true do
				Citizen.Wait(500)
				if Radio.On then
					local playerPed = PlayerPedId()
					local playerCoords = GetEntityCoords(playerPed)

					-- Flags & dists
					local anySiren, anyBoat, anyHeli = false, false, false
					local sirenDist, boatDist, heliDist = 0, 0, 0

					-- Scan every networked vehicle
					for _, veh in ipairs(GetGamePool('CVehicle')) do
						if DoesEntityExist(veh) and not IsEntityDead(veh) then
							local vehCoords = GetEntityCoords(veh)
							local dist = #(playerCoords - vehCoords)
							if dist <= MAX_DIST then
								local fraction = dist / MAX_DIST
								local volume   = math.max(0, 1 - fraction)

								-- -- Siren check (LVC states)
								-- if state_lxsiren > 0 or state_pwrcall > 0 or state_airmanu > 0 then
								-- 	anySiren = true
								-- 	sirenDist = math.max(sirenDist, volume)
								-- end

								-- Boat engine (class 14)
								if GetVehicleClass(veh) == 14 and IsVehicleEngineOn(veh) then
									anyBoat   = true
									boatDist  = volume
								end

								-- Helicopter rotors (class 15)
								if GetVehicleClass(veh) == 15 and IsVehicleEngineOn(veh) then
									anyHeli   = true
									heliDist  = volume
								end
							end
						end
					end

					-- Merge in every remote player's siren volume
					local distances = {}

					for key, netId in pairs(remoteSirens) do
						if key ~= 0 then
							local veh = NetworkGetEntityFromNetworkId(key)
							if DoesEntityExist(veh) then
								local pos  = GetEntityCoords(veh)
								local dist = #(playerCoords - pos)
								if dist <= MAX_DIST then
									table.insert(distances, math.max(0, 1 - (dist / MAX_DIST)))
								end
							else
								-- If the vehicle is not valid anymore, remove it from the remoteSirens table
								remoteSirens[key] = nil
							end
						else
							-- remove the entry if the vehicle is not valid anymore
							remoteSirens[key] = nil
						end
					end

					-- pick the highest remote volume, if any
					if #distances > 0 then
						-- math.max over the unpacked table
						local maxRemoteVol = math.max(table.unpack(distances))
						if maxRemoteVol > sirenDist then
							sirenDist = maxRemoteVol
							anySiren  = true
						end
					end
					-- Toggle “siren” sound (only one channel)
					if sirenDist > 0 and not currentLoopingSounds["siren"] then
						ToggleAudio(true,  "siren", sirenDist)
						dists["VEHICLE_SIREN"] = sirenDist

						-- broadcast local change
						if not lastSentState then
							lastSentState, lastSentVol = true, sirenDist
						end
					elseif sirenDist > 0 and currentLoopingSounds["siren"] then
						local old = dists["VEHICLE_SIREN"] or 0
						if math.abs(old - sirenDist) > DIST_THRESHOLD then
							ToggleAudio(true,  "siren", sirenDist)
							dists["VEHICLE_SIREN"] = sirenDist
							lastSentVol = sirenDist
						end

					elseif sirenDist == 0 and currentLoopingSounds["siren"] then
						ToggleAudio(false, "siren", 0.0)
						dists["VEHICLE_SIREN"] = 0
						lastSentState, lastSentVol = false, nil
					end

					-- Toggle “boat_engine” sound
					if anyBoat and not currentLoopingSounds["boat_engine"] then
						ToggleAudio(true, "boat_engine", boatDist)
						dists["BOAT"] = boatDist

					elseif anyBoat and currentLoopingSounds["boat_engine"] then
						local old = dists["BOAT"] or 0
						if math.abs(old - boatDist) > DIST_THRESHOLD then
							ToggleAudio(true,  "boat_engine", boatDist)
							dists["BOAT"] = boatDist
						end

					elseif not anyBoat and currentLoopingSounds["boat_engine"] then
						ToggleAudio(false, "boat_engine", boatDist)
					end

					-- Toggle “helicopter_rotors” sound
					if anyHeli and not currentLoopingSounds["helicopter_rotors"] then
						ToggleAudio(true, "helicopter_rotors", heliDist)
						dists["HELI"] = heliDist

					elseif anyHeli and currentLoopingSounds["helicopter_rotors"] then
						local old = dists["HELI"] or 0
						if math.abs(old - heliDist) > DIST_THRESHOLD then
							ToggleAudio(true,  "helicopter_rotors", heliDist)
							dists["HELI"] = heliDist
						end

					elseif not anyHeli and currentLoopingSounds["helicopter_rotors"] then
						ToggleAudio(false, "helicopter_rotors", heliDist)
					end
				end
			end
		end)
		-- Gunshot listener
		Citizen.CreateThread(function()
			while true do
				if Radio.On then
					local playerPed   = PlayerPedId()
					local playerCoords = GetEntityCoords(playerPed)

					-- 1) Check local player shooting
					if IsPedShooting(playerPed) then
						local weapon   = GetSelectedPedWeapon(playerPed)
						local category = GetWeaponCategory(weapon)
						if category then
							local suppressed = IsPedCurrentWeaponSilenced(playerPed)
							local trackId = suppressed and (TrackIDs[category] .. "_suppressed") or TrackIDs[category]
							ToggleAudio(true, trackId, 1)
							Citizen.Wait(150)
							ToggleAudio(false, trackId, 1)
						end
					end

					-- 2) Now check all _other_ networked players
					for _, ped in ipairs(GetGamePool('CPed')) do
						if ped ~= playerPed
						and DoesEntityExist(ped)
						and not IsPedDeadOrDying(ped)
						and IsPedAPlayer(ped) then

							local pedId = NetworkGetPlayerIndexFromPed(ped)
							if NetworkIsPlayerActive(pedId) and IsPedShooting(ped) then
								local weapon   = GetSelectedPedWeapon(ped)
								local category = GetWeaponCategory(weapon)
								if category then
									local suppressed = IsPedCurrentWeaponSilenced(ped)
									local baseTrackId = suppressed and (TrackIDs[category] .. "_suppressed") or (TrackIDs[category])

									local pedCoords = GetEntityCoords(ped)
									local dist = #(playerCoords - pedCoords)
									if dist <= 100.0 then
										local fraction = dist / 100
										-- invert: 1.0 (at you) → 0.0 (at maxDist)
										local volume = math.max(0, 1 - fraction)
										ToggleAudio(true, baseTrackId, volume)
										Citizen.Wait(150)
										ToggleAudio(false, baseTrackId, volume)
									end
								end
							end
						end
					end
				end
				Citizen.Wait(10)
			end
		end)
	end
end
function handleNameChange(name)
	SendNUIMessage({
		type = 'set_display_name',
		name = name
	})
end

exports('handleNameChange', handleNameChange)


local function sendConsole(level, color, message)
	local debugging = true
	if Config ~= nil then
		debugging = (Config.debug == true and Config.debug ~= 'false')
	end
	local info = debug.getinfo(3, 'S')
	local source = '.'
	if info.source:find('@@sonoranradio') then
		source = info.source:gsub('@@sonoranradio/', '') .. ':' .. info.linedefined
	end
	local msg = ('[%s:%s%s^7]%s %s^0'):format(debugging and source or 'SonoranRadio', color, level, color, message)
	if (debugging and level == 'DEBUG') or (not debugging and level ~= 'DEBUG') or level == 'ERROR' or level == 'WARNING' or level == 'INFO' then
		print(msg)
	end
end

function errorLog(message)
	sendConsole('ERROR', '^1', message)
end

function warnLog(message)
	sendConsole('WARNING', '^3', message)
end
