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

-- RADIO QUALITY (Swankiness): 0.0 - 1.0 (0.0 worst -> 1.0 greatest)
-- TODO: make being furthest away from any tower and/or the repeater(s) cause quality to go down
-- RADIO TOWERS: handle, pos {x, y, z, offset, handle, status}, destruction status (0 - none, 1 - being destroyed, 2 - destroyed) 
local RadioTower = {
    Destruction = false,
    DestructionTimer = 0,
    Swankiness = 0.0,

    RadioTower.Towers = {},

    -- Used for the repeater and the prop that is needed to be destroyed in order to disrupt signals
    RadioTower.RepeaterProps = {
        "prop_satdish_2_a",
    },

    -- Currently only GTA props (future: custom props)
    RadioTower.Props = {
        "prop_radiomast01",
        "prop_radiomast02",
    },
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

function RadioTower:AddTower(x, y, z, offset, handle, status)
    -- TODO:
    -- Add tower and then spawn radio mast and the repeater prop and attach it (if not in the list already & spawned)
    -- CreateObject()
    -- AttachEntityToEntityPhysically()
    -- PARAMS: (entity1, entity2, boneIndex1, boneIndex2, xPos1, yPos1, zPos1, xPos2, yPos2, zPos2, xRot, yRot, zRot, breakForce, true, true, true, false, 1)
    -- the breakforce will prove useful
end

-- todo check nearby towers and setup/do things for destroying or repairing
function RadioTower:GetNearbyTower()
    local towers = RadioTower.Locations

    for k in pairs(towers) do
    end
end

-- manage the props/objects and whether they are spawned or not
function RadioTower:ManageObjects()
    local objects = RadioTower.TrackedObjects

    for k in pairs(objects) do
    end
end

function RadioTower:Cleanup()
    -- TODO: clean up every thing for towers and delete objects/props for resource stop/restart.
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

AddEventHandler('onResourceStart', function(resource)
	if GetCurrentResourceName() ~= resource then return end
	print('Sonoran Radio Starting...')
	TriggerEvent("chat:addSuggestion", "/radio", "Open the Sonoran Radio Interface")
	print('Sonoran Radio Started!')
end)

AddEventHandler('onResourceStop', function(resource)
	if GetCurrentResourceName() ~= resource then return end
	print('Sonoran Radio Stopping...')
	TriggerEvent("chat:removeSuggestion", "/radio")
	Radio:Toggle(false)
end)