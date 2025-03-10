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
local frame = GetResourceKvpString('sonoranradio_skin') or 'default'
polyZonesTable = {}
Config = {}

AddEventHandler('onClientResourceStart', function(resourceName)
	if (GetCurrentResourceName() ~= resourceName) then
		return
	end
	TriggerServerEvent('SonoranRadio::core::RequestEnvironment')
end)

RegisterNetEvent('SonoranRadio::core::DebugMode', function(data)
	Config.debug = data
end)

RegisterNetEvent('SonoranRadio::core::ReceiveEnvironment', function(data)
	Config = data
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
end)

function initClient()
	if Config.comId == nil or Config.comId == '' then
		TriggerEvent('chat:addMessage', {
			color = {
				255,
				0,
				0
			},
			multiline = true,
			args = {
				'Sonoran Radio',
				'There is no community ID set for SonoranRadio. Please contact the server owner.'
			}
		})
		critError = true
		return
	end

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

	CreateThread(function()
		while true do
			Wait(5000)
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

	CreateThread(function()
		if Config.enforceRadioItem then
			if frameworkEnum == 1 then
				while QBCore.Functions.GetPlayerData() == nil do
					Wait(10)
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
				hasItem = QBCore.Functions.GetItemByName(itemName) ~= nil
			elseif type(QBCore.Functions.HasItem) == 'table' then
				hasItem = QBCore.Functions.HasItem(itemName) ~= nil
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
		local itemName = Config.RadioItem and Config.RadioItem.name
		if not itemName then
			itemName = 'sonoran_radio'
		end
		return playerHasItem(itemName)
	end

	function radioToggle(frame)
		if not authorized then
			SendNotification('Radio: ~r~No Permission~r~')
			return
		end

		TriggerServerEvent('SonoranRadio::CheckPermissions')

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
		SendNUIMessage({
			type = 'setUiPositions',
			data = json.decode(GetResourceKvpString('ui_pos_dic') or '{}')
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
		if type(displayName) ~= 'string' then
			displayName = GetPlayerName(PlayerId())
		end
		SendNUIMessage({
			type = 'setEmergencyCall',
			enabled = enabled,
			displayName = displayName,
			callCommand = emergencyCallCommand(),
		})
	end
	exports('setEmergencyCall', setEmergencyCall)

	RegisterNetEvent('SonoranRadio::AuthorizeRadio')
	AddEventHandler('SonoranRadio::AuthorizeRadio', function(frames, miniRadio)
		DebugPrint('Authorized for Radio Usage')
		authorized = true
		allowedMiniRadio = miniRadio
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
			SendNUIMessage({
				type = 'refresh'
			})
		elseif action == 'reset' then
			-- debug print ui info to console
			print('SONORAN RADIO UI POSITION DATA')
			print(json.encode(GetResourceKvpString('ui_pos_dic')))

			SetResourceKvp('ui_pos_dic', '{}')
			SendNUIMessage({ type = 'reset' })
		elseif action == 'scanner' and not Config.enforceRadioItem then
			openLocalScanner()
		elseif action == 'displayname' then
			local name = table.concat(args, ' ', 2)
			SendNUIMessage({
				type = 'set_display_name',
				name = name
			})
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
		'displayname'
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

	RegisterKeyMapping('sonradradio', 'Show Radio', 'keyboard', getConfigKeybind('toggle'))
	RegisterKeyMapping('sonradnext', 'Next Channel (In Group)', 'keyboard', getConfigKeybind('nextChannel'))
	RegisterKeyMapping('sonradprev', 'Prev Channel (In Group)', 'keyboard', getConfigKeybind('prevChannel'))
	RegisterKeyMapping('sonradpower', 'Radio Power', 'keyboard', getConfigKeybind('power'))
	RegisterKeyMapping('sonradpanic', 'Radio Panic', 'keyboard', getConfigKeybind('panic'))
	RegisterKeyMapping('sonradgroupnext', 'Next Group', 'keyboard', getConfigKeybind('nextGroup'))
	RegisterKeyMapping('sonradgroupprev', 'Prev Group', 'keyboard', getConfigKeybind('prevGroup'))
	RegisterKeyMapping('sonradvolup', 'Volume Up', 'keyboard', getConfigKeybind('volUp'))
	RegisterKeyMapping('sonradvoldown', 'Volume Down', 'keyboard', getConfigKeybind('volDown'))


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

	function Radio:Talking(toggle)
		local inVeh = IsPedInAnyVehicle(GetPlayerPed(-1), false)
		TriggerEvent('SonoranRadio::API:Talking', toggle, inVeh)
		if self.TalkAnim then
			if toggle and not inVeh then
				if self.Open then
					RequestAnimDict('cellphone@')
					while not HasAnimDictLoaded('cellphone@') do
						Wait(5)
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
						Wait(5)
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
						Wait(5)
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

	-- Citizen.CreateThread(function()
	-- 	while true do
	-- 		Wait(1)
	-- 		if isTalking and Config.talkSync then
	-- 			SetControlNormal(0, 249, 1.0);
	-- 		end
	-- 	end
	-- end)

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
		if IsPlayerFreeAiming(PlayerId()) or IsPedInAnyVehicle(GetPlayerPed(-1)) then
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
			type = 'setStandalone',
			standaloneId = comId,
			standaloneUrl = Config.radioUrl,
			chatter = chatter,
			debug = Config.debug,
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

		if data.type == 'panic' and data.status then
			TriggerServerEvent('SonoranCAD::callcommands:SendPanicApi')
		end

		if data.type == 'emergencyCallStatus' then
			TriggerEvent('SonoranRadio::API:EmergencyCall', data.status)
		elseif data.type == 'emergencyCallDispatcher' then
			TriggerEvent('SonoranRadio::API:EmergencyCallDispatcher', data.available)
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
			SetResourceKvp('ui_pos_dic', json.encode(data.data))
		end

		if data.type == 'stateUpdated' or data.type == 'stateUpdatedEmergencyCall' then
			-- replicate the new state to other clients
			if type(data.state) == 'table' then data.state.gamestate = nil end
			TriggerServerEvent('SonoranRadio::SetRadioState', data.state)
		end

		if data.type == 'emergencyCall' then
			isEmergCallActive = data.enabled
		end

		if data.type == 'refreshScreen' then
			calledSyncAcePerms = false
			handleRefreshScreen()
		end

		if data.type == 'currentSkinUpdated' then
			frame = data.skin
			SetResourceKvp('sonoranradio_skin', frame)
		end

		if data.type == 'setChatterConfig' then
			setScannerProfiles(data.config.profiles, data.config.defaultProfileId)
		end

		cb('OK')
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

	local PlayerDead = false
	local RadioLastState = nil

	RegisterNetEvent('SonoranRadio::PlayerDeath', function()
		PlayerDead = true
		if Config.disableRadioOnDeath then
			if Radio.On then
				Radio.Enabled = false
				Radio:Toggle(false)
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
		frame = frame or 'default'

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

	RegisterNetEvent('QBCore:Client:OnJobUpdate', function(_)
		TriggerServerEvent('SonoranRadio::CheckPermissions')
	end)

	RegisterNetEvent('SonoranRadio::RequestClientData', function()
		TriggerEvent('SonoranRadio:CarRadioPower', Radio.On)
		if Radio.On then
			Wait(1000)
			SendNUIMessage({
				type = "get_connected_users",
			})
		end
		if Config.luxartResourceName == nil then
			Config.luxartResourceName = 'lvc'
		end
	end)

	RegisterNetEvent('SonoranRadio::RefreshScreen', function()
		SendNUIMessage({ type = 'refresh' })
	end)

	local lvcStarted = false
	Citizen.CreateThread(function()
		if GetResourceState(Config.luxartResourceName) == 'started' then
			lvcStarted = true
			AddEventHandler('lvc:UpdateThirdParty', function(data)
				data = json.encode(data)
				data = json.decode(data)
				state_lxsiren = data.state_lxsiren
				state_pwrcall = data.state_pwrcall
				state_airmanu = data.state_airmanu
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
		else
			while true and not lvcStarted do
				if IsVehicleSirenOn(GetVehiclePedIsIn(PlayerPedId(), false)) then
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
				Citizen.Wait(500)
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
					state_lxsiren = data.state_lxsiren
					state_pwrcall = data.state_pwrcall
					state_airmanu = data.state_airmanu
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
	if (level == 'ERROR' or level == 'WARNING') and IsDuplicityVersion() then
		table.insert(ErrorBuffer, 1, msg)
	end
	if level == 'DEBUG' and IsDuplicityVersion() then
		if #DebugBuffer > 50 then
			table.remove(DebugBuffer)
		end
		table.insert(DebugBuffer, 1, msg)
	else
		if not IsDuplicityVersion() then
			if #MessageBuffer > 10 then
				table.remove(MessageBuffer)
			end
			table.insert(MessageBuffer, 1, msg)
		end
	end
end

function errorLog(message)
	sendConsole('ERROR', '^1', message)
end
