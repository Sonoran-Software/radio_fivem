local radActive = false

local thisUnit = {}
local unitStatus = nil

local isTalking = false
allowedMiniRadio = false
local inVehicle = false

local authorized = false

local allowedFrames = {}
local critError = false

local polyZonesTable = {}

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
	local dispatch = call.dispatch
	DebugPrint(json.encode(dispatch))
	SendNUIMessage({
		type = 'callUpdate',
		call = dispatch
	})
end)

CreateThread(function()
	while true do
		Wait(5000)
		TriggerServerEvent('SonoranCAD::sonrad:GetUnitInfo')
		TriggerServerEvent('SonoranCAD::sonrad:GetCurrentCall')
	end
end)

local Radio = {
	Has = false,
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
	QBCore = exports['qb-core']:GetCoreObject()
	PlayerData = {}
end

CreateThread(function()
	if Config.enforceRadioItem then
		while QBCore.Functions.GetPlayerData() == nil do
			Wait(10)
		end
	end
end)

CreateThread(function()
	while Config.enforceRadioItem do
		Wait(1000)
		if LocalPlayer.state.isLoggedIn then
			-- print("has radio")
			QBCore.Functions.TriggerCallback('qb-sonrad:server:GetItem', function(hasItem)
				if not hasItem then
					Radio.Has = false
					Radio:Toggle(false)
				else
					Radio.Has = true
				end
			end, 'sonoran_radio')
		end
	end
end)

RegisterNetEvent('qb-sonrad:use')
AddEventHandler('qb-sonrad:use', function(frame)
	radioToggle(frame)
end)

-- Disable Attack when Radio is Open
CreateThread(function()
	while true do
		if Radio.Open then
			DisableControlAction(0, 142, true) -- Attack
			DisableControlAction(0, 200, true) -- Escape
		end
		Wait(0)
	end
end)

RegisterNetEvent('SonoranCAD::sonrad:UpdateCurrentCall')
AddEventHandler('SonoranCAD::sonrad:UpdateCurrentCall', function(call)
	local dispatch = call.dispatch
	DebugPrint(json.encode(dispatch))
	SendNUIMessage({
		type = 'callUpdate',
		call = dispatch
	})
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
	['b_2000'] = 'Space'
}
local function getPttKey()
	local key = GetControlInstructionalButton(0, 0xE364B8EC, true)
	if key:sub(1, 2) == 't_' then
		return key:sub(3)
	elseif specialKeyCodes[key] then
		return 'SpecialKey.' .. specialKeyCodes[key], key
	else
		print('warning: unknown ptt key code ' .. key)
		return nil
	end
end

function radioToggle(frame)
	if critError or Config.critError then
		TriggerEvent('chat:addMessage', {
			color = {
				255,
				0,
				0
			},
			multiline = true,
			args = {
				'Sonoran Radio',
				'There is a critical error with SonoranRadio configuration. There is no API Key, an invalid API Key or Community ID set. Please contact the server owner.'
			}
		})
		return
	end
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
		return
	end
	if authorized then
		TriggerServerEvent('SonoranRadio::CheckPermissions')
		if not Config.enforceRadioItem then
			Radio.Has = true
		end
		if Radio.Has then
			if frame == nil then
				frame = 'default'
			end
			SendNUIMessage({
				type = 'setCurrentSkin',
				skin = frame,
				skins = allowedFrames
			})
			radActive = not radActive
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
		else
			if Config.enforceRadioItem then
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
			end
			DebugPrint('Radio Requested, but player doesn\'t have a radio.')
		end
	else
		SendNotification('Radio: ~r~No Permission~r~')
	end
end

RegisterNetEvent('SonoranRadio::AuthorizeRadio')
AddEventHandler('SonoranRadio::AuthorizeRadio', function(frames, miniRadio)
	DebugPrint('Authorized for Radio Usage')
	allowedMiniRadio = miniRadio
	authorized = true
	allowedFrames = frames
	SendNUIMessage({
		type = 'setCurrentSkin',
		skin = frame,
		skins = allowedFrames
	})
end)

RegisterCommand('radio', radioToggle)
RegisterCommand('sonradradio', radioToggle)
TriggerEvent('chat:addSuggestion', '/radio', 'Open the Sonoran Radio Interface')
TriggerEvent('chat:addSuggestion', '/sonradradio', 'Open the Sonoran Radio Interface')
RegisterCommand('radiotalk', function()
	Radio.TalkAnim = not Radio.TalkAnim
	if Radio.TalkAnim then
		SendNotification('Radio Talk Animation: ~g~On~g~')
	else
		SendNotification('Radio Talk Animation: ~r~Off~r~')
	end
end)
RegisterKeyMapping('radiotalk', 'Toggle Radio Talk Animation', 'keyboard', '')

RegisterCommand('radioreset', function(source, args)
	SendNUIMessage({
		type = 'reset'
	})
	if args[1] == 'ui' then
		SetResourceKvp('ui_pos_dic', '{}')
		SendNUIMessage({
			type = 'setUiPositions',
			data = {}
		})
	end
end)
TriggerEvent('chat:addSuggestion', '/radioreset', 'Reconnect radio to teamspeak', {{name = 'ui', help = 'Reset UI Positions'}})

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
-- Talking Animation
-- RegisterCommand('sonradtalk', function()
-- 	Radio:Talking(isTalking)
-- end)

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

-- Power
RegisterCommand('sonradpower', function()
	TriggerEvent('SonoranRadio::API:PowerToggle')
end)

-- Panic
RegisterCommand('sonradpanic', function()
	TriggerEvent('SonoranRadio::API:PanicButton')
end)
RegisterKeyMapping('sonradradio', 'Show Radio', 'keyboard', '')
RegisterKeyMapping('sonradnext', 'Next Preset', 'keyboard', '')
RegisterKeyMapping('sonradprev', 'Prev Preset', 'keyboard', '')
RegisterKeyMapping('sonradpower', 'Radio Power', 'keyboard', '')
RegisterKeyMapping('sonradpanic', 'Radio Panic', 'keyboard', '')

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
RegisterKeyMapping('+sonradptt', 'Radio PTT', 'keyboard', '|')

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

Citizen.CreateThread(function()
	while true do
		Wait(1)
		if isTalking and Config.talkSync then
			SetControlNormal(0, 249, 1.0);
		end
	end
end)

function Radio:Toggle(toggle)
	if critError or Config.critError then
		TriggerEvent('chat:addMessage', {
			color = {
				255,
				0,
				0
			},
			multiline = true,
			args = {
				'Sonoran Radio',
				'There is a critical error with SonoranRadio configuration. There is no API Key, an invalid API Key or Community ID set. Please contact the server owner.'
			}
		})
		return
	end
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
		return
	end
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
	LocalPlayer.state:set('sonoranradio_state', nil, true)

	while true do
		local ped = GetPlayerPed(-1)
		if DoesEntityExist(ped) then
			local pos = GetEntityCoords(ped)
			local posArr = {
				math.floor(pos.x),
				math.floor(pos.y),
				math.floor(pos.z)
			}
			SendNUIMessage({
				type = 'setPos',
				position = posArr
			})
		end
		Citizen.Wait(5000)
	end
	-- For Development Only
	DebugPrint('Sonoran Radio Started!')
end)

function SendNotification(message)
	BeginTextCommandThefeedPost('STRING')
	AddTextComponentSubstringPlayerName(message)
	EndTextCommandThefeedPostTicker(false, false)
end

local function chatterNeedsInput()
	-- wait for anybody to be near the player (or skip if debug mode)
	while #GetActivePlayers() == 1 and not Config.debug do
		Citizen.Wait(100)
	end
	SendNUIMessage({ type = 'chatterWait' })
end

RegisterNUICallback('data', function(data, cb)
	if data.type == 'ready' then
		initNui()
	end

	if data.type == 'hide' then
		radActive = false
		SetNuiFocus(false, false)
		if not inVehicle or data.force then
			SendNUIMessage({
				type = 'setVisible',
				visibility = radActive
			})
		end
		Radio:Toggle(radActive)
	end

	if data.type == 'notify' then
		SendNotification(data.message)
	end

	if data.type == 'panic' then
		TriggerServerEvent('SonoranCAD::callcommands:SendPanicApi')
	end

	if data.type == 'power' then
		handleRadioPower(data.power)
		Radio.On = data.power
	end

	if data.type == 'talking' then
		Radio:Talking(data.talking)
	end

	if data.type == 'setUiPositions' then
		-- save positions of components in the UI
		SetResourceKvp('ui_pos_dic', json.encode(data.data))
	end

	if data.type == 'stateUpdated' then
		-- replicate the new state to other clients
		if type(data.state) == 'table' then data.state.gamestate = nil end
		TriggerServerEvent('SonoranRadio::SetRadioState', data.state)
	end

	if data.type == 'chatterNeedsInput' then
		-- give keyboard input focus
		Citizen.CreateThread(chatterNeedsInput)
	elseif data.type == 'chatterInitialized' then
		if not radActive then
			SetNuiFocus(false, false)
		end
	end

	if data.type == 'chatterNeedsInput' then
		-- give keyboard input focus
		Citizen.CreateThread(chatterNeedsInput)
	end

	if not radActive then
		if data.type == 'chatterNeedsFocus' then
			SetNuiFocus(true, false)
		end

		if data.type == 'chatterInitialized' then
			SetNuiFocus(false, false)
		end
	end


	if data.type == 'home' then
		handleHome()
	end
	cb('OK')
end)

AddEventHandler('onResourceStart', function(resource)
	if GetCurrentResourceName() ~= resource then
		return
	end
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
	for zoneName, zoneData in pairs (Config.polyZones) do
		local points = zoneData.points -- coords
		local options = zoneData.options -- options
		print('Creating PolyZone: ' .. options.name)
		print(json.encode(points))
		print(json.encode(options))
		polyZonesTable[zoneName] = PolyZone:Create(points, {
			name = options.name,
			minZ = options.minZ,
			maxZ = options.maxZ,
		})
		print('Created PolyZone: ' .. options.name)
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

CreateThread(function()
	while true do
		local veh = GetVehiclePedIsIn(GetPlayerPed(), false)
		local prevState = inVehicle
		-- DebugPrint("Getting Players Vehicle")

		if not IsPedInAnyVehicle(PlayerPedId(), false) then
			-- player is in vehicle
			inVehicle = false
		else
			inVehicle = true
		end

		-- DebugPrint("Updating Radio State")
		SendNUIMessage({
			type = 'inVehicle',
			vehState = inVehicle
		})

		if prevState ~= inVehicle then
			SendNUIMessage({
				type = 'setVisible',
				visibility = false
			})
		end

		Wait(100)
	end
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

local QBDeath = false;

CreateThread(function()
	local QBCore = nil
	if Config.deathDetectionMethod == 'qbcore' then
		QBCore = exports['qb-core']:GetCoreObject()
	end

	while true do
		if QBCore ~= nil then
			local PlayerData = QBCore.Functions.GetPlayerData()
			if PlayerData ~= nil then
				-- print("Is Dead: " .. tostring(PlayerData.metadata["isdead"]))
				-- print("Is Last Stand: " .. tostring(PlayerData.metadata["islaststand"]))
				QBDeath = PlayerData.metadata['isdead'] or PlayerData.metadata['inlaststand']
			end
		end

		if Config.deathDetectionMethod == 'auto' or Config.deathDetectionMethod == 'qbcore' then
			local IsPlayerDead = IsEntityDead(PlayerPedId()) or QBDeath
			if IsPlayerDead then
				TriggerEvent('SonoranRadio::PlayerDeath')
			else
				TriggerEvent('SonoranRadio::PlayerRevive')
			end
		end
		-- print("QBDeath:" .. tostring(QBDeath))
		-- print("EntityDead:" .. tostring(IsEntityDead(PlayerPedId())))
		-- print("Radio Enabled: " .. tostring(Radio.Enabled))
		-- Tunnel degredation logic
		local plyPed = PlayerPedId()
        local coord = GetEntityCoords(plyPed)
        local insideZone = false
		for _, zone in pairs(polyZonesTable) do
            if zone:isPointInside(coord) then
                insideZone = true
                break
            end
        end
		local bestQuality = math.max(bestCellRepeaterQuality, bestRackQuality, bestTowerQuality)
		if insideZone then
			if bestQuality > 0 then
				bestQuality = bestQuality * (1 - Config.tunnelDegredationStrength)
			end
		end
		SendNUIMessage({
			type = 'setTowerQuality',
			state = {
				tower_quality = bestQuality
			}
		})
		Wait(1000)
	end
end)

RegisterNetEvent('SonoranRadio::AdminSkinChange', function(frame)
	if Config.frames.permissionMode == 'ace' then
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
	elseif Config.frames.permissionMode == 'qbcore' and Config.enforceRadioItem then
		local QBCore = exports['qb-core']:GetCoreObject()
		local hasRadio = QBCore.Functions.HasItem('sonoran_radio')
		if hasRadio then
			TriggerEvent('chat:addMessage', {
				args = {
					'^1SonoranRadio',
					'Changed your radio skin to ' .. frame .. ''
				}
			})
			TriggerServerEvent('SonoranRadio::AdminSkinChange_s', frame)
			SendNUIMessage({
				type = 'setCurrentSkin',
				skin = frame
			})
		else
			TriggerEvent('chat:addMessage', {
				color = {
					255,
					0,
					0
				},
				multiline = true,
				args = {
					'Sonoran Radio',
					'You must have a radio to change frames.'
				}
			})
		end
	elseif Config.frames.permissionMode == 'qbcore' and not Config.enforceRadioItem then
		TriggerEvent('chat:addMessage', {
			args = {
				'^1SonoranRadio',
				'Changed your radio skin to ' .. frame .. ''
			}
		})
		TriggerServerEvent('SonoranRadio::AdminSkinChange_s', frame)
		SendNUIMessage({
			type = 'setCurrentSkin',
			skin = frame
		})
	else
		TriggerEvent('chat:addMessage', {
			args = {
				'^1SonoranRadio',
				'Changed your radio skin to ' .. frame .. ''
			}
		})
		TriggerServerEvent('SonoranRadio::AdminSkinChange_s', frame)
		SendNUIMessage({
			type = 'setCurrentSkin',
			skin = frame
		})
	end
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

