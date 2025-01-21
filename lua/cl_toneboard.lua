function initToneboard()
    speakers = {}
    local queue = {}
    playingSpeakers = {}
    local speakerStyles = {
        ['speakerSmallWall'] = "hei_prop_bank_alarm_01",
        ['speakerMedium'] = "prop_speaker_05",
        ['speakerMediumWall'] = "prop_out_door_speaker",
        ['speakerLarge'] = "prop_speaker_06"
    }

    RegisterNetEvent('RadioSpeaker:SpawnSpeaker', function(speaker)
        DebugPrint(('spawned speaker %s'):format(speaker))
        table.insert(speakers, speaker)
        DebugPrint('new speaker spawned', speaker.Id)
    end)

    function LoadModelSync(model)
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(1) end
    end

    function GetSpeakerCoords(speaker)
        if DoesEntityExist(speaker.Handle) then
            return GetOffsetFromEntityInWorldCoords(speaker.Handle, 0.0, 0.0, 1.0)
        else
            return vec3(speaker.PropPosition.x, speaker.PropPosition.y,
                        speaker.PropPosition.z)
        end
    end

    function AddSpeakerRange(t)
        if not Config.debug then return end
        -- create a radius blip that indicates the range of the speaker (where edge of circle = 50% capacity)
        local blip = AddBlipForRadius(t.PropPosition.x, t.PropPosition.y,
                                    t.PropPosition.z, t.Range)
        SetBlipAlpha(blip, 614)
        SetBlipColour(blip, 2)
    end

    -- fully creates a speaker based on the given speaker object
    function CreateSpeaker(speaker)
        if DoesEntityExist(speaker.Handle) then DeleteEntity(speaker.Handle) end
        local speakerModelArray = speakerStyles[speaker.type]
        if not speakerModelArray then
            return
        end
        local speakerModel = GetHashKey(speakerModelArray)
        LoadModelSync(speakerModel)
        local coords = speaker.PropPosition
        speaker.Handle = CreateObject(speakerModel, coords, false, false, false)
        while not DoesEntityExist(speaker.Handle) do Wait(0) end
        FreezeEntityPosition(speaker.Handle, true)
        SetEntityCoords(speaker.Handle, coords.x, coords.y, coords.z - 1, true,
                        true, true, false)
        SetEntityHeading(speaker.Handle, speaker.heading)
        SetModelAsNoLongerNeeded(speakerModel)
        speaker.Spawned = true
    end
    -- delete the physical speaker entities
    function DestroySpeaker(speaker)
        if DoesEntityExist(speaker.Handle) then DeleteEntity(speaker.Handle) end
        speaker.Spawned = false
    end

    RegisterNetEvent('SonoranRadio:SyncSpeakers')
    AddEventHandler('SonoranRadio:SyncSpeakers', function(SpeakersServer)
        -- make sure all speakers are cleared before we sync
        for i = 1, #speakers do DestroySpeaker(speakers[i]) end

        speakers = SpeakersServer
        for i = 1, #speakers do AddSpeakerRange(speakers[i]) end
        DebugPrint(('synced %s'):format(json.encode(speakers)))
    end)

    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(10) end
        TriggerServerEvent('SonoranRadio::SyncSpeakers')
        while #speakers == 0 do Wait(50) end
        while true do
            local pCoords = GetEntityCoords(GetPlayerPed(-1))
            for i = 1, #speakers do
                local speaker = speakers[i]
                if not speaker then goto continue end
                local d = #(GetSpeakerCoords(speaker) - pCoords)
                -- if the player is within range (750m), then spawn a physical speaker
                if d < 750.0 and not speaker.Spawned then
                    CreateSpeaker(speaker)
                    DebugPrint(('spawn physical speaker (%f) %s'):format(d,
                                                                        speaker.Id))
                elseif d >= 750.0 and speaker.Spawned then
                    DestroySpeaker(speaker)
                    DebugPrint(('destroy physical speaker (%f) %s'):format(d,
                                                                        speaker.Id))
                end

                -- recreate the speaker completely if anything is missing
                -- NOTE: not including the ladder, as it will be omitted on certain conditions
                local recreate = speaker.Spawned and
                                    not DoesEntityExist(speaker.Handle)
                if recreate then
                    DebugPrint(('speaker:%s component missing, recreating'):format(
                                speaker.Id))
                    -- CreateSpeaker will automatically delete old entities
                    CreateSpeaker(speaker)
                end

                -- if speaker is out of range, then just ignore it
                if d > speaker.Range then goto continue end
                ::continue::
            end
            Wait(3000)
        end
    end)

    -- cleanup speakers on stop
    AddEventHandler('onResourceStop', function(resource)
        if resource ~= GetCurrentResourceName() then return end
        for i = 1, #speakers do DestroySpeaker(speakers[i]) end
        -- make sure the thread doesn't re-spawn them
        speakers = {}
    end)

    RegisterNetEvent('SonoranRadio:PlayTone', function(speakers, tone)
        for _, tonePlay in pairs(tone) do
            DebugPrint(('adding tone %s to speaker %s\'s queue'):format(tonePlay, speakers.Id))
            table.insert(queue, {speaker = speakers, sound = tonePlay})
        end
    end)

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(500);
            if #queue > 0 then
                for i = 1, #queue do
                    if not queue[i] then goto continue end
                    local speaker = queue[i].speaker
                    local tone = queue[i].sound
                    Wait(100)
                    if not playingSpeakers[speaker.Id] then
                        DebugPrint(('playing tone %s on speaker %s'):format(tone,
                                                                          speaker.Id))
                        PlayUrlPos(speaker.Id, tone, 1.0, GetSpeakerCoords(speaker), false)
                        Distance(speaker.Id, speaker.Range)
                        playingSpeakers[speaker.Id] = tone
                    end
                    ::continue::
                end
            end
        end
    end)

    RegisterNetEvent('xSound:songStopPlaying', function(id)
        for k, v in pairs(playingSpeakers) do
            if k == id then
                DebugPrint(('removing speaker %s from playingSpeakers'):format(id))
                for i = 1, #queue do
                    if queue[i].sound == v and queue[i].speaker.Id == k then
                        table.remove(queue, i)
                        DebugPrint(('removed %s from queue'):format(v))
                        break
                    end
                end
                playingSpeakers[k] = nil
                break
            end
        end
    end)
end