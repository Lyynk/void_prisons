local isJailed = false
local jailTime = 0
local isBreakoutActive = false

-- Callback registration to get appearance
lib.callback.register('void-prison:client:GetAppearance', function()
    if Config.Appearance == 'illenium' and exports['illenium-appearance'] then
        return exports['illenium-appearance']:getPedAppearance(PlayerPedId())
    end
    return nil
end)

-- ============================================================================
-- CLOTHING UTILITIES
-- ============================================================================

local function ApplyPrisonUniform()
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    local gender = "male"

    if model == `mp_f_freemode_01` then
        gender = "female"
    end

    local uniform = Config.Uniforms[gender]
    if uniform then
        for _, comp in ipairs(uniform.components) do
            SetPedComponentVariation(ped, comp.componentId, comp.drawableId, comp.textureId, 0)
        end
    end
end

local function RestoreAppearance(appearance)
    if Config.Appearance == 'illenium' and exports['illenium-appearance'] and appearance then
        exports['illenium-appearance']:setPedAppearance(PlayerPedId(), appearance)
    else
        -- Native reload or fallback QBCore reload
        TriggerServerEvent('qb-clothes:retrieveOutfit') -- standard fallback
    end
end

-- ============================================================================
-- EVENTS
-- ============================================================================

RegisterNetEvent('void-prison:client:Jailed', function(time, appearance)
    isJailed = true
    jailTime = time
    isBreakoutActive = false

    -- Teleport to jail spawn
    DoScreenFadeOut(500)
    Wait(500)
    
    local ped = PlayerPedId()
    SetEntityCoords(ped, Config.JailSpawn.x, Config.JailSpawn.y, Config.JailSpawn.z, false, false, false, false)
    SetEntityHeading(ped, Config.JailSpawn.w)
    
    -- Apply clothes
    ApplyPrisonUniform()

    DoScreenFadeIn(500)
end)

RegisterNetEvent('void-prison:client:Unjailed', function(appearance)
    isJailed = false
    jailTime = 0
    isBreakoutActive = false

    -- Teleport to release location
    DoScreenFadeOut(500)
    Wait(500)

    local ped = PlayerPedId()
    SetEntityCoords(ped, Config.ReleaseLocation.x, Config.ReleaseLocation.y, Config.ReleaseLocation.z, false, false, false, false)
    SetEntityHeading(ped, Config.ReleaseLocation.w)

    -- Restore clothes
    RestoreAppearance(appearance)

    DoScreenFadeIn(500)
end)

RegisterNetEvent('void-prison:client:UpdateJailTime', function(time)
    jailTime = time
    if jailTime <= 0 and isJailed then
        isJailed = false
        -- The server will trigger the Unjailed event shortly
    end
end)

RegisterNetEvent('void-prison:client:SetBreakoutState', function(state)
    isBreakoutActive = state
end)

-- Open qb-inventory stash helper
RegisterNetEvent('void-prison:client:OpenQbStash', function(stashName, slots, weight)
    TriggerServerEvent("inventory:server:OpenInventory", "stash", stashName, {
        maxweight = weight or 100000,
        slots = slots or 30
    })
end)

-- ============================================================================
-- BOUNDARY CONTAINMENT THREAD
-- ============================================================================

CreateThread(function()
    while true do
        Wait(5000) -- Check containment every 5 seconds to preserve performance
        if isJailed then
            local ped = PlayerPedId()
            local currentPos = GetEntityCoords(ped)
            local distance = #(currentPos - Config.YardCenter)

            if distance > Config.YardRadius then
                if isBreakoutActive then
                    -- ESCAPED!
                    isJailed = false
                    TriggerServerEvent('void-prison:server:ReleaseInmate', { citizenid = 'self' }) -- wait, we can notify server player has escaped
                    TriggerServerEvent('void-prison:server:UpdateSentence', { citizenid = 'self', amount = -jailTime }) -- clear remaining time
                    lib.notify({
                        title = 'Void Prison',
                        description = 'You have successfully broken out of prison! Escape before the police catch you!',
                        type = 'success',
                        duration = 10000
                    })
                else
                    -- Teleport back and penalize
                    DoScreenFadeOut(500)
                    Wait(500)
                    SetEntityCoords(ped, Config.JailSpawn.x, Config.JailSpawn.y, Config.JailSpawn.z, false, false, false, false)
                    SetEntityHeading(ped, Config.JailSpawn.w)
                    ApplyPrisonUniform()
                    DoScreenFadeIn(500)

                    -- Add penalty
                    TriggerServerEvent('void-prison:server:UpdateSentence', { citizenid = 'self', amount = 30 }) -- Add 30 seconds/months penalty
                    lib.notify({
                        title = 'Void Prison',
                        description = 'Escape attempt failed! Sentence increased by 30 months.',
                        type = 'error'
                    })
                end
            end
        end
    end
end)

-- ============================================================================
-- POINTS INTERACTION USING OX_LIB
-- ============================================================================

-- Bunk points
for _, bunk in ipairs(Config.BunkStashes) do
    local point = lib.points.new({
        coords = bunk.coords,
        distance = 1.5
    })

    function point:onEnter()
        if isJailed then
            lib.showTextUI('[E] Bunk Stash')
        end
    end

    function point:onExit()
        lib.hideTextUI()
    end

    function point:nearby()
        if isJailed and IsControlJustPressed(0, 38) then -- E key
            TriggerServerEvent('void-prison:server:OpenBunkStash', bunk.id)
            if Config.Inventory == 'ox' then
                -- Get player citizen ID client side or trigger server event.
                -- For ox, we can open the stash directly
                lib.callback('void-prison:server:GetCitizenId', false, function(citizenid)
                    if citizenid then
                        exports.ox_inventory:openInventory('stash', { id = 'prison_bunk_' .. citizenid })
                    end
                end)
            end
            Wait(500)
        end
    end
end

-- Seized Locker Point
local lockerPoint = lib.points.new({
    coords = Config.LockerLocation,
    distance = 2.0
})

function lockerPoint:onEnter()
    lib.showTextUI('[E] Seized Locker')
end

function lockerPoint:onExit()
    lib.hideTextUI()
end

function lockerPoint:nearby()
    if IsControlJustPressed(0, 38) then
        if isJailed then
            lib.notify({
                title = 'Void Prison',
                description = 'You cannot access your locker while jailed!',
                type = 'error'
            })
        else
            TriggerServerEvent('void-prison:server:OpenLocker')
            if Config.Inventory == 'ox' then
                lib.callback('void-prison:server:GetCitizenId', false, function(citizenid)
                    if citizenid then
                        exports.ox_inventory:openInventory('stash', { id = 'prison_locker_' .. citizenid })
                    end
                end)
            end
        end
        Wait(500)
    end
end
