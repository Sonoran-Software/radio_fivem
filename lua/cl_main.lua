local radActive = false

local thisUnit = {}
local unitStatus = nil

local thisCall = {}

local isTalking = false

local inVehicle = false

RegisterNetEvent("SonoranCAD::sonrad:GetUnitInfo:Return")
AddEventHandler("SonoranCAD::sonrad:GetUnitInfo:Return", function(unit)
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

RegisterNetEvent("SonoranCAD::sonrad:UpdateCurrentCall")
AddEventHandler("SonoranCAD::sonrad:UpdateCurrentCall", function(call)
	local dispatch = call.dispatch
	DebugPrint(json.encode(dispatch))
	SendNUIMessage({
		type = 'callUpdate',
		call = dispatch
	})
end)

-- TODO: Push Events for Status Updates
RegisterNetEvent("SonoranCAD::pushevents:UnitUpdate", function(unit, status)
	if thisUnit.id ~= unit.id then return end
	DebugPrint(status)
	SendNUIMessage({
		type = 'unitStatus',
		status = status
	})
end)

CreateThread(function()
	while true do
		Wait(5000)
		TriggerServerEvent("SonoranCAD::sonrad:GetUnitInfo")
		TriggerServerEvent("SonoranCAD::sonrad:GetCurrentCall")
	end
end)

local Radio = {
	Has = false,
	Open = false,
	On = false,
	Enabled = true,
	Handle = nil,
	Prop = `prop_cs_hand_radio`,
	Bone = 28422,
	Offset = vector3(0.0, 0.0, 0.0),
	Rotation = vector3(0.0, 0.0, 0.0),
	Dictionary = {
		"cellphone@",
		"cellphone@in_car@ds",
		"cellphone@str",    
		"random@arrests",  
	},
	Animation = {
		"cellphone_text_in",
		"cellphone_text_out",
		"cellphone_call_listen_a",
		"generic_radio_chatter",
	},
	Clicks = true, -- Radio clicks
}

-- Disable Attack when Radio is Open
CreateThread(function()
	while true do
		if Radio.Open then
			DisableControlAction(0, 142, true)
		end
		Wait(0)
	end
end)

local function radioToggle()
	radActive = not radActive
	Radio:Toggle(radActive)
	SendNUIMessage({
		type = 'setVisible',
		visibility = radActive
	})
	if radActive then
		SetNuiFocus(true, true)
		SetNuiFocusKeepInput(true)
	else
		SetNuiFocus(false, false)
	end
end

RegisterCommand('radio', radioToggle)
RegisterCommand('sonradradio', radioToggle)

RegisterCommand('radioreset', function()
	SendNUIMessage({
		type = 'reset'
	})
end)

-- Talking Animation
RegisterCommand('sonradtalk', function()
	isTalking = not isTalking
	Radio:Talking(isTalking)
end)

-- Next
RegisterCommand('sonradnext', function()
    SendNUIMessage({
        type = 'pushButton',
        button = 'next'
    })
end)

-- Previous
RegisterCommand('sonradprev', function()
    SendNUIMessage({
        type = 'pushButton',
        button = 'prev'
    })
end)

-- Power
RegisterCommand('sonradpower', function()
    SendNUIMessage({
        type = 'pushButton',
        button = 'power'
    })
end)

-- Panic
RegisterCommand('sonradpanic', function()
    SendNUIMessage({
        type = 'pushButton',
        button = 'panic'
    })
end)
RegisterKeyMapping('sonradradio', 'Show Radio', 'keyboard', '')
RegisterKeyMapping('sonradnext', 'Next Preset', 'keyboard', '')
RegisterKeyMapping('sonradprev', 'Prev Preset', 'keyboard', '')
RegisterKeyMapping('sonradpower', 'Radio Power', 'keyboard', '')
RegisterKeyMapping('sonradpanic', 'Radio Panic', 'keyboard', '')

function Radio:Talking(toggle)
	local inVeh = IsPedInAnyVehicle(GetPlayerPed(-1), false)
	if toggle and not inVeh then
		if self.Open then
			RequestAnimDict("cellphone@str")
			while not HasAnimDictLoaded("cellphone@str") do Wait(5) end
			TaskPlayAnim(PlayerPedId(), "cellphone@str","cellphone_call_listen_a", 8.0, 0.0, -1, 49, 0, 0, 0, 0)
		else
			RequestAnimDict("random@arrests")
			while not HasAnimDictLoaded("random@arrests") do Wait(5) end
			TaskPlayAnim(PlayerPedId(), "random@arrests","generic_radio_chatter", 8.0, 0.0, -1, 49, 0, 0, 0, 0)
		end
	else
		if self.Open then
			StopAnimTask(PlayerPedId(), "cellphone@str","cellphone_call_listen_a", -4.0)
			if inVeh then return end
			Citizen.Wait(700)
			RequestAnimDict("cellphone@")
			while not HasAnimDictLoaded("cellphone@") do Wait(5) end
			TaskPlayAnim(PlayerPedId(), "cellphone@", "cellphone_text_in", 4.0, -1, -1, 50, 0, false, false, false)
		else
			StopAnimTask(PlayerPedId(), "random@arrests","generic_radio_chatter", -4.0)
		end
	end
	RequestAnimDict()
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
		SetCurrentPedWeapon(playerPed, `weapon_unarmed`, true)
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

Citizen.CreateThread(function()
    SetNuiFocus(false, false)
    while true do
        local ped = GetPlayerPed(-1)
        if DoesEntityExist(ped) then
            local pos = GetEntityCoords(ped)
            local posArr = {math.floor(pos.x), math.floor(pos.y), math.floor(pos.z)}
            SendNUIMessage({type = 'setPos', position = posArr })
        end
        Citizen.Wait(5000)
    end
    -- For Development Only
    DebugPrint('Sonoran Radio Started!')
end)

CreateThread(function()
	while true do
		local hours = GetClockHours()
		local minutes = GetClockMinutes()
		if hours < 9 then hours = "0" .. tostring(hours) end
		if minutes < 9 then minutes = "0" .. tostring(minutes) end
		SendNUIMessage({type = 'time', time = hours .. ':' .. minutes})
		Wait(500)
	end
end)

function SendNotification(message)
	BeginTextCommandThefeedPost("STRING")
	AddTextComponentSubstringPlayerName(message)
	EndTextCommandThefeedPostTicker(false, false)
end

RegisterNUICallback('data', function(data, cb)
    --print('data:' .. json.encode(data))
    if data.type == 'hide' then
		toggleRadio()
    end

	if data.type == 'notify' then
		SendNotification(data.message)
	end

	if data.type == 'panic' then
		TriggerServerEvent('SonoranCAD::callcommands:SendPanicApi')
	end

	if data.type == 'power' then
		TriggerServerEvent('SonoranRadio::RadioPower', data.power, GetPlayerName(PlayerId()))
	end

	if data.type == 'talking' then
		Radio:Talking(data.talking)
	end

    cb('OK')
end)

AddEventHandler('onResourceStart', function(resource)
	if GetCurrentResourceName() ~= resource then return end
	DebugPrint('Sonoran Radio Starting...')
	TriggerEvent("chat:addSuggestion", "/radio", "Open the Sonoran Radio Interface")
	TriggerEvent("chat:addSuggestion", "/radioreset", "Reconnect radio to teamspeak")
	DebugPrint('Sonoran Radio Started!')
end)

AddEventHandler('onResourceStop', function(resource)
	if GetCurrentResourceName() ~= resource then return end
	DebugPrint('Sonoran Radio Stopping...')
	TriggerEvent("chat:removeSuggestion", "/radio")
	TriggerEvent("chat:removeSuggestion", "/radioreset")
	Radio:Destroy()
end)

RegisterNetEvent('SonoranRadio::GetRadios:Return')
AddEventHandler('SonoranRadio::GetRadios:Return', function(radios)
	SendNUIMessage({
		type = "getRadios",
		radios = radios
	})
end)

CreateThread(function()
	while true do

		local veh = GetVehiclePedIsIn(GetPlayerPed(), false)
		local prevState = inVehicle
		--DebugPrint("Getting Players Vehicle")

		if not IsPedInAnyVehicle(PlayerPedId(), false) then 
			-- player is in vehicle
			inVehicle = false
		else
			inVehicle = true
		end

		--DebugPrint("Updating Radio State")
		SendNUIMessage({
			type = "inVehicle",
			vehState = inVehicle
		})
		
		Wait(100)
	end
end)