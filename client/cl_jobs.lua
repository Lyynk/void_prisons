-- ============================================================================
-- PRISON JOBS INTERACTIVE MECHANICS
-- ============================================================================

local currentProp = nil

local function SpawnJobProp(modelName, bone, pos, rot)
    local ped = PlayerPedId()
    local modelHash = GetHashKey(modelName)
    
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(10)
    end
    
    local coords = GetEntityCoords(ped)
    local prop = CreateObject(modelHash, coords.x, coords.y, coords.z, true, true, true)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, bone), pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
    
    currentProp = prop
    return prop
end

local function RemoveJobProp()
    if currentProp and DoesEntityExist(currentProp) then
        DeleteEntity(currentProp)
        currentProp = nil
    end
end

local function LoadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

local function PerformJob(jobKey, jobConfig)
    local ped = PlayerPedId()
    
    -- Load animation
    LoadAnimDict(jobConfig.anim.dict)
    TaskPlayAnim(ped, jobConfig.anim.dict, jobConfig.anim.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
    
    -- Spawn prop if needed
    if jobConfig.prop then
        SpawnJobProp(jobConfig.prop.model, jobConfig.prop.bone, jobConfig.prop.pos, jobConfig.prop.rot)
    end

    -- Progress Circle
    local completed = lib.progressCircle({
        duration = jobConfig.duration,
        label = jobConfig.name,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
        }
    })

    -- Cleanup anim & prop
    ClearPedTasks(ped)
    RemoveJobProp()
    RemoveAnimDict(jobConfig.anim.dict)

    if completed then
        TriggerServerEvent('void-prison:server:CompleteJob', jobKey)
    else
        lib.notify({
            title = 'Void Prison',
            description = 'Work interrupted.',
            type = 'error'
        })
    end
end

-- ============================================================================
-- JOB INITIALIZATION (Points registration)
-- ============================================================================

CreateThread(function()
    for jobKey, jobConfig in pairs(Config.Jobs) do
        for i, pointCoords in ipairs(jobConfig.points) do
            local point = lib.points.new({
                coords = pointCoords,
                distance = 1.8
            })

            function point:onEnter()
                local isJailed = LocalPlayer.state.isJailed
                if isJailed then
                    lib.showTextUI('[E] ' .. jobConfig.name)
                end
            end

            function point:onExit()
                lib.hideTextUI()
            end

            function point:nearby()
                local isJailed = LocalPlayer.state.isJailed
                if isJailed and IsControlJustPressed(0, 38) then -- E key
                    lib.hideTextUI()

                    if jobKey == 'electrical' then
                        -- Electrical job requires a skillcheck first!
                        local success = lib.skillCheck({'easy', 'easy', 'medium'}, {'w', 'a', 's', 'd'})
                        if success then
                            PerformJob(jobKey, jobConfig)
                        else
                            lib.notify({
                                title = 'Void Prison',
                                description = 'You short-circuited the panel and shocked yourself!',
                                type = 'error'
                            })
                            -- Play shocking effect/animation
                            local ped = PlayerPedId()
                            PlayPain(ped, 7, 0)
                            TaskPlayAnim(ped, "combat@damage@rb_react", "rb_react_left", 8.0, -8.0, 1000, 0, 0, false, false, false)
                        end
                    else
                        PerformJob(jobKey, jobConfig)
                    end
                    
                    Wait(2000) -- cooldown/delay
                end
            end
        end
    end
end)
