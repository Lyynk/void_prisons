local isHacking = false

-- Load animation dictionary helper
local function LoadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

-- ============================================================================
-- BREAKOUT HACK ZONE INTERACTION
-- ============================================================================

local breakoutPoint = lib.points.new({
    coords = Config.Breakout.HackCoords,
    distance = 1.5
})

function breakoutPoint:onEnter()
    lib.showTextUI('[E] Hack Prison Grid Security')
end

function breakoutPoint:onExit()
    lib.hideTextUI()
end

function breakoutPoint:nearby()
    if IsControlJustPressed(0, 38) and not isHacking then
        lib.hideTextUI()
        
        -- Server check if they have the required hacking item
        lib.callback('void-prison:server:CanHack', false, function(canHack, errorMsg)
            if canHack then
                StartHacking()
            else
                lib.notify({
                    title = 'Void Prison',
                    description = errorMsg or 'You do not have the required tools to hack this terminal.',
                    type = 'error'
                })
            end
        end)
        Wait(2000)
    end
end

-- ============================================================================
-- HACKING MECHANICS
-- ============================================================================

function StartHacking()
    isHacking = true
    local ped = PlayerPedId()

    -- Play hacking animation
    LoadAnimDict("anim@heists@ornate_bank@hack")
    TaskPlayAnim(ped, "anim@heists@ornate_bank@hack", "hack_loop", 8.0, -8.0, -1, 1, 0, false, false, false)

    -- Progress circle for hacking duration
    local completed = lib.progressCircle({
        duration = Config.Breakout.HackDuration,
        label = "Bypassing Mainframe...",
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
        }
    })

    if completed then
        -- Play hacking minigame
        local success = lib.skillCheck({'medium', 'medium', 'hard', 'hard'}, {'w', 'a', 's', 'd'})

        if success then
            -- Trigger breakout success on server
            TriggerServerEvent('void-prison:server:SuccessHack')
        else
            lib.notify({
                title = 'Void Prison',
                description = 'Hack failed! The alarm has been silently triggered!',
                type = 'error'
            })
            TriggerServerEvent('void-prison:server:TriggerSilentAlarm')
        end
    else
        lib.notify({
            title = 'Void Prison',
            description = 'Hack cancelled.',
            type = 'error'
        })
    end

    ClearPedTasks(ped)
    RemoveAnimDict("anim@heists@ornate_bank@hack")
    isHacking = false
end

-- ============================================================================
-- ALARMS AND CLIENT EFFECTS
-- ============================================================================

local alarmActive = false

RegisterNetEvent('void-prison:client:TriggerBreakoutEffects', function(duration)
    if alarmActive then return end
    alarmActive = true

    -- Alert message
    lib.notify({
        title = 'PRISON ALERT',
        description = 'PRISON BREAK IN PROGRESS! MAIN GRID COMPROMISED!',
        type = 'error',
        duration = 10000
    })

    -- Play prison alarm sound
    PlaySoundFrontend(-1, "Lose_1st_Reason_Fade_Out", "WastedSounds", true)
    
    -- Loop alarm sound or visual flashes if desired
    CreateThread(function()
        local endTime = GetGameTimer() + (duration * 1000)
        while GetGameTimer() < endTime do
            -- Flashing red lights client-side or ambient sounds
            PlaySoundFrontend(-1, "Police_Generator_Off", "DLC_HALLOWEEN_SOUNDS", true)
            Wait(3000)
        end
        alarmActive = false
    end)
end)
