local QBCore = nil
if Config.Framework == 'qb' then
    QBCore = exports['qb-core']:GetCoreObject()
end

local function GetPlayer(source)
    if Config.Framework == 'qbx' then
        return exports.qbx_core:GetPlayer(source)
    else
        return QBCore.Functions.GetPlayer(source)
    end
end

local function NotifyPlayer(source, message, type)
    if Config.OkokNotify.enabled then
        TriggerClientEvent('okokNotify:Alert', source, 'Void Prison', message, 5000, type or 'info', true)
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Void Prison',
            description = message,
            type = type or 'info'
        })
    end
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

    -- Verify cooldown or distance here if needed, but since it's client checked we do basic validation
    local citizenid = nil
    local player = GetPlayer(src)
    if player then citizenid = player.PlayerData.citizenid end
    if not citizenid then return end

    MySQL.single('SELECT remaining_time FROM jail_inmates WHERE citizenid = ?', {citizenid}, function(result)
        if result then
            local timeReduction = jobConfig.timeReduction or 10
            local newRemaining = math.max(0, result.remaining_time - timeReduction)

            MySQL.update('UPDATE jail_inmates SET remaining_time = ? WHERE citizenid = ?', {newRemaining, citizenid}, function()
                -- Update metadata and event to client
                if Config.Framework == 'qbx' then
                    exports.qbx_core:SetMetadata(src, 'jailtime', newRemaining)
                else
                    player.Functions.SetMetaData('jailtime', newRemaining)
                end

                TriggerClientEvent('void-prison:client:UpdateJailTime', src, newRemaining)

                if newRemaining <= 0 then
                    -- Unjailed immediately inside sv_main loop, but we trigger it here to be responsive
                    TriggerEvent('void-prison:server:UnjailPlayer', src) -- wait, we can just call the unjail function if exported, or sv_main handles it
                else
                    NotifyPlayer(src, "Worked off " .. timeReduction .. " months/seconds! Remaining: " .. newRemaining .. " months/seconds.", "success")
                end

                -- CONTRA BRAND / BREAKOUT ITEMS DROP CHANCE (5% chance)
                if math.random(1, 100) <= 8 then
                    local rewardItem = 'gate_hack_device' -- or a component
                    -- We can award standard breakout components or items
                    local rewardCount = 1
                    
                    if Config.Inventory == 'ox' then
                        exports.ox_inventory:AddItem(src, rewardItem, rewardCount)
                    else
                        -- qb-inventory
                        player.Functions.AddItem(rewardItem, rewardCount)
                        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[rewardItem], "add")
                    end
                    NotifyPlayer(src, "You found something useful in the trash/floor... Shh, keep it hidden!", "success")
                end
            end)
        end
    end)
end)
