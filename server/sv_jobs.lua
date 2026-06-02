local Bridge = exports['void_bridge']:GetBridge()

local function GetPlayer(source)
    return Bridge.GetPlayer(source)
end

local function NotifyPlayer(source, message, type)
    Bridge.Notify(source, message, type)
end

-- ============================================================================
-- JOB COMPLETION HANDLER
-- ============================================================================

RegisterNetEvent('void-prison:server:CompleteJob', function(jobType)
    local src = source
    local playerState = Player(src).state
    if not playerState.isJailed then
        NotifyPlayer(src, "You are not jailed, you cannot do this work.", "error")
        return
    end

    local jobConfig = Config.Jobs[jobType]
    if not jobConfig then return end

    local player = GetPlayer(src)
    if not player then return end
    
    local citizenid = player.GetData().citizenid
    if not citizenid then return end

    MySQL.single('SELECT remaining_time FROM jail_inmates WHERE citizenid = ?', {citizenid}, function(result)
        if result then
            local timeReduction = jobConfig.timeReduction or 10
            local newRemaining = math.max(0, result.remaining_time - timeReduction)

            MySQL.update('UPDATE jail_inmates SET remaining_time = ? WHERE citizenid = ?', {newRemaining, citizenid}, function()
                -- Update metadata
                player.SetMetaData('jailtime', newRemaining)

                TriggerClientEvent('void-prison:client:UpdateJailTime', src, newRemaining)

                if newRemaining <= 0 then
                    -- Trigger release
                    TriggerEvent('void-prison:server:UnjailPlayer', src)
                else
                    NotifyPlayer(src, "Worked off " .. timeReduction .. " months/seconds! Remaining: " .. newRemaining .. " months/seconds.", "success")
                end

                -- CONTRABAND / BREAKOUT ITEMS DROP CHANCE (8% chance)
                if math.random(1, 100) <= 8 then
                    local rewardItem = 'gate_hack_device'
                    local rewardCount = 1
                    
                    local success = Bridge.Inventory.AddItem(src, rewardItem, rewardCount)
                    if success then
                        NotifyPlayer(src, "You found something useful in the trash/floor... Shh, keep it hidden!", "success")
                    end
                end
            end)
        end
    end)
end)
