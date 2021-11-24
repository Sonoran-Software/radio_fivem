local radActive = false

local thisUnit = {}
local unitStatus = nil

local thisCall = {}

local isTalking = false

RegisterNetEvent("SonoranCAD::sonrad:RecvUnitInfo")
AddEventHandler("SonoranCAD::sonrad:RecvUnitInfo", function(unit)
	thisUnit = unit
	if thisUnit ~= nil then
		if unitStatus ~= thisUnit.status then
			unitStatus = thisUnit.status
			SendNUIMessage({
				type = 'unitStatus',
				status = thisUnit.status
			})
			--print('status updated')
		end
	else 
		SendNUIMessage({
			type = 'unitStatus',
			status = -1
		})
	end
end)

RegisterNetEvent("SonoranCAD::sonrad:UpdateCurrentCall")
AddEventHandler("SonoranCAD::sonrad:UpdateCurrentCall", function(call)
	local dispatch = call.dispatch
	print(json.encode(dispatch))
	SendNUIMessage({
		type = 'callUpdate',
		call = dispatch
	})
end)

-- TODO: Push Events for Status Updates
RegisterNetEvent("SonoranCAD::pushevents:UnitUpdate", function(unit, status)
	if thisUnit.id ~= unit.id then return end
	print(status)
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

RegisterCommand('radio', function()
    radActive = not radActive
    Radio:Toggle(radActive)
    SendNUIMessage({
        type = 'setVisible',
        visibility = radActive
    })
    SetNuiFocus(radActive, radActive)
end)

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
RegisterKeyMapping('radio', 'Show Radio', 'keyboard', '')
RegisterKeyMapping('sonradnext', 'Next Preset', 'keyboard', '')
RegisterKeyMapping('sonradprev', 'Prev Preset', 'keyboard', '')
RegisterKeyMapping('sonradpower', 'Radio Power', 'keyboard', '')
RegisterKeyMapping('sonradpanic', 'Radio Panic', 'keyboard', '')

function Radio:Talking(toggle)
	if toggle then
		RequestAnimDict("random@arrests")
		while not HasAnimDictLoaded("random@arrests") do Wait(5) end
		TaskPlayAnim(PlayerPedId(), "random@arrests","generic_radio_chatter", 8.0, 0.0, -1, 49, 0, 0, 0, 0)
	else
		StopAnimTask(PlayerPedId(), "random@arrests","generic_radio_chatter", -4.0)
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
	else
		TaskPlayAnim(playerPed, dictionary, animation, 4.0, -1, -1, 50, 0, false, false, false)
		Citizen.Wait(700)
		StopAnimTask(playerPed, dictionary, animation, 1.0)
		NetworkRequestControlOfEntity(self.Handle)
		while not NetworkHasControlOfEntity(self.Handle) and count < 5000 do
			Citizen.Wait(0)
			count = count + 1
		end
		DetachEntity(self.Handle, true, false)
		DeleteEntity(self.Handle)
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
    print('Sonoran Radio Started!')
end)

function SendNotification(message)
	BeginTextCommandThefeedPost("STRING")
	AddTextComponentSubstringPlayerName(message)
	EndTextCommandThefeedPostTicker(false, false)
end

RegisterNUICallback('data', function(data, cb)
    print('data:' .. json.encode(data))
    if data.type == 'hide' then
        SendNUIMessage({
            type = 'setVisible',
            visibility = false
        })
        radActive = false
        SetNuiFocus(false, false)
        Radio:Toggle(false)
    end

	if data.type == 'notify' then
		SendNotification(data.message)
	end

	if data.type == 'panic' then
		TriggerServerEvent("SonoranCAD::sonrad:RadioPanic")
	end

	if data.type == 'power' then
		TriggerServerEvent('SonoranRadio::RadioPower', data.power, GetPlayerName(PlayerId()))
	end

    cb('OK')
end)

AddEventHandler('onResourceStart', function(resource)
	if GetCurrentResourceName() ~= resource then return end
	print('Sonoran Radio Starting...')
	TriggerEvent("chat:addSuggestion", "/radio", "Open the Sonoran Radio Interface")
	TriggerEvent("chat:addSuggestion", "/radioreset", "Reconnect radio to teamspeak")
	print('Sonoran Radio Started!')
end)

AddEventHandler('onResourceStop', function(resource)
	if GetCurrentResourceName() ~= resource then return end
	print('Sonoran Radio Stopping...')
	TriggerEvent("chat:removeSuggestion", "/radio")
	TriggerEvent("chat:removeSuggestion", "/radioreset")
	Radio:Destroy()
end)

RegisterNetEvent('SonoranRadio::GetRadios:Return')
AddEventHandler('SonoranRadio::GetRadios:Return', function(radios)
    local src = source
	SendNUIMessage({
		type = "getRadios",
		radios = radios
	})
end)