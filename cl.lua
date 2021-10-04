local radActive = false

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
RegisterKeyMapping('radio', 'Sonoran Radio', 'keyboard', '')

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

    cb('OK')
end)