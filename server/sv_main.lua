local QBCore = nil
local JailedPlayers = {} -- Cache: [source] = { citizenid = x, name = y, remaining = z }

if Config.Framework == 'qb' then
    QBCore = exports['qb-core']:GetCoreObject()
end

-- ============================================================================
-- FRAMEWORK BRIDGES
-- ============================================================================

local function GetPlayer(source)
    if Config.Framework == 'qbx' then
        return exports.qbx_core:GetPlayer(source)
    else
        return QBCore.Functions.GetPlayer(source)
    end
end

local function GetPlayerByCitizenId(citizenid)
    if Config.Framework == 'qbx' then
        return exports.qbx_core:GetPlayerByCitizenId(citizenid)
    else
        return QBCore.Functions.GetPlayerByCitizenId(citizenid)
    end
end

local function GetCitizenId(source)
    local player = GetPlayer(source)
    if not player then return nil end
    return player.PlayerData.citizenid
end

local function GetPlayerName(source)
    local player = GetPlayer(source)
    if not player then return "Unknown" end
    return player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname
end

local function IsPolice(source)
    local player = GetPlayer(source)
    if not player then return false end
    local jobName = player.PlayerData.job.name
    for _, job in ipairs(Config.PoliceJobs) do
        if job == jobName then
            return true
        end
    end
    return false
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

local function SetJailMetadata(source, time)
    if Config.Framework == 'qbx' then
        exports.qbx_core:SetMetadata(source, 'jailtime', time)
    else
        local player = GetPlayer(source)
        if player then
            player.Functions.SetMetaData('jailtime', time)
        end
    end
end

-- ============================================================================
-- DATABASE & SPANNING LOGIC
-- ============================================================================

-- Register stashes on start if using ox_inventory
MySQL.ready(function()
    -- Perform cleanup or initialization checks if needed
end)

local function LoadJailState(source)
    local citizenid = GetCitizenId(source)
    if not citizenid then return end

    MySQL.single('SELECT * FROM jail_inmates WHERE citizenid = ?', {citizenid}, function(result)
        if result then
            -- Player is marked as jailed in our database
            JailedPlayers[source] = {
                citizenid = citizenid,
                name = result.name,
                remaining = result.remaining_time
            }
            SetJailMetadata(source, result.remaining_time)
            Player(source).state.isJailed = true

            -- Register ox bunk/locker stashes
            if Config.Inventory == 'ox' then
                exports.ox_inventory:RegisterStash('prison_locker_' .. citizenid, 'Prison Locker', 50, 100000, citizenid)
                exports.ox_inventory:RegisterStash('prison_bunk_' .. citizenid, 'Cell Bunk Stash', 30, 50000, citizenid)
            end

            -- Trigger client jail entry
            TriggerClientEvent('void-prison:client:Jailed', source, result.remaining_time, result.saved_appearance)
        else
            -- Check if player metadata wrongly says they are jailed
            local metaTime = 0
            if Config.Framework == 'qbx' then
                metaTime = exports.qbx_core:GetMetadata(source, 'jailtime') or 0
            else
                local p = GetPlayer(source)
                if p then metaTime = p.PlayerData.metadata['jailtime'] or 0 end
            end

            if metaTime > 0 then
                SetJailMetadata(source, 0)
            end
            Player(source).state.isJailed = false
        end
    end)
end

-- Handle QBox / QBCore player loaded events
if Config.Framework == 'qbx' then
    RegisterNetEvent('qbx_core:server:onPlayerLoaded', function(source)
        LoadJailState(source)
    end)
else
    RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
        local src = source
        LoadJailState(src)
    end)
end

AddEventHandler('playerDropped', function()
    local src = source
    if JailedPlayers[src] then
        local data = JailedPlayers[src]
        -- Save remaining time to DB on disconnect
        MySQL.update('UPDATE jail_inmates SET remaining_time = ? WHERE citizenid = ?', {data.remaining, data.citizenid})
        JailedPlayers[src] = nil
    end
end)

-- ============================================================================
-- INVENTORY CONFISCATION
-- ============================================================================

local function ConfiscateInventory(source, citizenid)
    if Config.Inventory == 'ox' then
        exports.ox_inventory:RegisterStash('prison_locker_' .. citizenid, 'Prison Locker', 50, 100000, citizenid)
        local playerItems = exports.ox_inventory:GetInventoryItems(source)
        if playerItems then
            for _, item in pairs(playerItems) do
                if item and item.name then
                    local metadata = item.metadata or {}
                    exports.ox_inventory:AddItem('prison_locker_' .. citizenid, item.name, item.count, metadata)
                    exports.ox_inventory:RemoveItem(source, item.name, item.count, metadata, item.slot)
                end
            end
        end
    else
        -- qb-inventory logic
        local player = GetPlayer(source)
        if player then
            local items = player.PlayerData.items
            if items then
                -- Backup items to DB stashitems table
                MySQL.insert('INSERT INTO stashitems (stash, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?', {
                    'prison_locker_' .. citizenid,
                    json.encode(items),
                    json.encode(items)
                })
                player.Functions.ClearInventory()
            end
        end
    end
end

-- ============================================================================
-- JAIL / UNJAIL CORE LOGIC
-- ============================================================================

local function JailPlayer(targetSrc, time, reason, staffSrc)
    local citizenid = GetCitizenId(targetSrc)
    if not citizenid then return false end

    local name = GetPlayerName(targetSrc)
    reason = reason or "Sentenced by LSPD"
    time = tonumber(time) or 0

    -- Request appearance from client before wiping
    lib.callback('void-prison:client:GetAppearance', targetSrc, function(appearance)
        local appearanceJson = json.encode(appearance)

        -- Confiscate items
        ConfiscateInventory(targetSrc, citizenid)

        -- Save to database
        MySQL.insert('INSERT INTO jail_inmates (citizenid, name, jail_time, remaining_time, reason, saved_appearance) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE remaining_time = ?, reason = ?, saved_appearance = ?', {
            citizenid, name, time, time, reason, appearanceJson, time, reason, appearanceJson
        }, function()
            -- Set local cache
            JailedPlayers[targetSrc] = {
                citizenid = citizenid,
                name = name,
                remaining = time
            }

            SetJailMetadata(targetSrc, time)
            Player(targetSrc).state.isJailed = true

            -- Register stashes
            if Config.Inventory == 'ox' then
                exports.ox_inventory:RegisterStash('prison_locker_' .. citizenid, 'Prison Locker', 50, 100000, citizenid)
                exports.ox_inventory:RegisterStash('prison_bunk_' .. citizenid, 'Cell Bunk Stash', 30, 50000, citizenid)
            end

            -- Send custom billing invoice if okokBilling is enabled
            if Config.OkokBilling.enabled then
                local fineAmount = time * Config.OkokBilling.fineAmountPerMonth
                local author = "LSPD"
                if staffSrc and staffSrc > 0 then author = GetPlayerName(staffSrc) end
                local authorCid = staffSrc > 0 and GetCitizenId(staffSrc) or "SYSTEM"
                
                TriggerServerEvent("okokBilling:CreateCustomInvoice", targetSrc, fineAmount, "Prison Sentence Fine - " .. reason, "LSPD Prison Administration", Config.OkokBilling.society, Config.OkokBilling.societyName, authorCid)
            end

            TriggerClientEvent('void-prison:client:Jailed', targetSrc, time, appearance)
            NotifyPlayer(targetSrc, "You have been jailed for " .. time .. " months/seconds. Reason: " .. reason, "error")

            if staffSrc and staffSrc > 0 then
                NotifyPlayer(staffSrc, "Jailed " .. name .. " for " .. time .. " months/seconds.", "success")
            end
        end)
    end)

    return true
end

local function UnjailPlayer(targetSrc, staffSrc)
    local citizenid = GetCitizenId(targetSrc)
    if not citizenid then return false end

    MySQL.single('SELECT saved_appearance FROM jail_inmates WHERE citizenid = ?', {citizenid}, function(result)
        if result then
            local appearance = json.decode(result.saved_appearance)

            MySQL.update('DELETE FROM jail_inmates WHERE citizenid = ?', {citizenid}, function()
                JailedPlayers[targetSrc] = nil
                SetJailMetadata(targetSrc, 0)
                Player(targetSrc).state.isJailed = false

                TriggerClientEvent('void-prison:client:Unjailed', targetSrc, appearance)
                NotifyPlayer(targetSrc, "You have been released from prison!", "success")

                if staffSrc and staffSrc > 0 then
                    NotifyPlayer(staffSrc, "Released " .. GetPlayerName(targetSrc) .. " from prison.", "success")
                end
            end)
        else
            if staffSrc and staffSrc > 0 then
                NotifyPlayer(staffSrc, "Player is not jailed.", "error")
            end
        end
    end)

    return true
end

-- Exports
exports('JailPlayer', JailPlayer)
exports('UnjailPlayer', UnjailPlayer)

-- Compatibility Events (e.g. for ps-mdt or qb-policejob triggers)
RegisterNetEvent('police:server:JailPlayer', function(playerId, time, reason)
    local src = source
    if src > 0 and not IsPolice(src) then return end
    JailPlayer(playerId, time, reason, src)
end)

RegisterNetEvent('police:server:UnjailPlayer', function(playerId)
    local src = source
    if src > 0 and not IsPolice(src) then return end
    UnjailPlayer(playerId, src)
end)

-- ============================================================================
-- COMMANDS
-- ============================================================================

RegisterCommand('jail', function(source, args)
    local src = source
    if src > 0 and not IsPolice(src) then
        NotifyPlayer(src, "You must be a police officer to use this command.", "error")
        return
    end

    local targetId = tonumber(args[1])
    local jailTime = tonumber(args[2])
    local reason = table.concat(args, " ", 3)

    if not targetId or not jailTime then
        NotifyPlayer(src, "Usage: /jail [ID] [Time] [Reason]", "error")
        return
    end

    local targetPlayer = GetPlayer(targetId)
    if not targetPlayer then
        NotifyPlayer(src, "Target player not online.", "error")
        return
    end

    JailPlayer(targetId, jailTime, reason, src)
end, false)

RegisterCommand('unjail', function(source, args)
    local src = source
    if src > 0 and not IsPolice(src) then
        NotifyPlayer(src, "You must be a police officer to use this command.", "error")
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then
        NotifyPlayer(src, "Usage: /unjail [ID]", "error")
        return
    end

    local targetPlayer = GetPlayer(targetId)
    if not targetPlayer then
        NotifyPlayer(src, "Target player not online.", "error")
        return
    end

    UnjailPlayer(targetId, src)
end, false)

-- ============================================================================
-- COUNTDOWN THREAD
-- ============================================================================

CreateThread(function()
    while true do
        Wait(1000 * Config.JailTimeMultiplier)
        for src, data in pairs(JailedPlayers) do
            if data.remaining > 0 then
                data.remaining = data.remaining - 1
                if data.remaining % 10 == 0 or data.remaining == 0 then
                    -- Sync to DB and metadata periodically
                    MySQL.update('UPDATE jail_inmates SET remaining_time = ? WHERE citizenid = ?', {data.remaining, data.citizenid})
                    SetJailMetadata(src, data.remaining)
                end

                if data.remaining <= 0 then
                    UnjailPlayer(src, 0)
                end
            end
        end
    end
end)

-- ============================================================================
-- NUI TABLET & CALLBACKS
-- ============================================================================

-- Command / Item use to open tablet
RegisterCommand('jailtablet', function(source)
    local src = source
    if not IsPolice(src) then
        NotifyPlayer(src, "You do not have access to the prison monitor.", "error")
        return
    end
    TriggerClientEvent('void-prison:client:OpenTablet', src)
end, false)

-- qb-inventory or ox_inventory item use registration
if Config.Inventory == 'ox' then
    -- If they want to use an item, they can configure it in ox_inventory directly.
    -- Or we can hook it or export it.
else
    -- QBCore item use
    if Config.Framework == 'qb' then
        QBCore.Functions.CreateUseableItem("police_tablet", function(source, item)
            local src = source
            if IsPolice(src) then
                TriggerClientEvent('void-prison:client:OpenTablet', src)
            end
        end)
    end
end

-- Get citizen ID callback
lib.callback.register('void-prison:server:GetCitizenId', function(source)
    return GetCitizenId(source)
end)

-- Get inmate list callback
lib.callback.register('void-prison:server:GetInmateList', function(source)
    if not IsPolice(source) then return {} end

    local promise = promise.new()
    MySQL.query('SELECT * FROM jail_inmates ORDER BY jailed_at DESC', {}, function(results)
        local inmates = {}
        for _, row in ipairs(results) do
            local isOnline = false
            local ply = GetPlayerByCitizenId(row.citizenid)
            if ply then isOnline = true end

            table.insert(inmates, {
                citizenid = row.citizenid,
                name = row.name,
                totalTime = row.jail_time,
                remainingTime = row.remaining_time,
                reason = row.reason,
                online = isOnline,
                jailedAt = row.jailed_at
            })
        end
        promise:resolve(inmates)
    end)
    return Citizen.Await(promise)
end)

-- Update inmate sentence NUI callback
RegisterNetEvent('void-prison:server:UpdateSentence', function(data)
    local src = source
    if not IsPolice(src) then return end

    local targetCid = data.citizenid
    local changeAmount = tonumber(data.amount) or 0 -- negative to reduce, positive to increase

    MySQL.single('SELECT remaining_time FROM jail_inmates WHERE citizenid = ?', {targetCid}, function(result)
        if result then
            local newRemaining = math.max(0, result.remaining_time + changeAmount)

            MySQL.update('UPDATE jail_inmates SET remaining_time = ? WHERE citizenid = ?', {newRemaining, targetCid}, function()
                local targetPlayer = GetPlayerByCitizenId(targetCid)
                if targetPlayer then
                    local targetSrc = targetPlayer.PlayerData.source
                    if JailedPlayers[targetSrc] then
                        JailedPlayers[targetSrc].remaining = newRemaining
                    end
                    SetJailMetadata(targetSrc, newRemaining)
                    TriggerClientEvent('void-prison:client:UpdateJailTime', targetSrc, newRemaining)
                    NotifyPlayer(targetSrc, "Your sentence has been modified. Remaining: " .. newRemaining .. " months/seconds.", "info")
                end
                NotifyPlayer(src, "Updated sentence for citizen ID " .. targetCid .. " by " .. changeAmount .. " months/seconds.", "success")
            end)
        else
            NotifyPlayer(src, "Inmate not found.", "error")
        end
    end)
end)

-- Release early NUI callback
RegisterNetEvent('void-prison:server:ReleaseInmate', function(data)
    local src = source
    if not IsPolice(src) then return end

    local targetCid = data.citizenid
    local targetPlayer = GetPlayerByCitizenId(targetCid)

    if targetPlayer then
        UnjailPlayer(targetPlayer.PlayerData.source, src)
    else
        -- If offline, just delete from database
        MySQL.update('DELETE FROM jail_inmates WHERE citizenid = ?', {targetCid}, function(affectedRows)
            if affectedRows > 0 then
                NotifyPlayer(src, "Released citizen ID " .. targetCid .. " (offline) from database.", "success")
            else
                NotifyPlayer(src, "Inmate not found.", "error")
            end
        end)
    end
end)

-- ============================================================================
-- BUNKS & LOCKER ACTIONS
-- ============================================================================

-- Server callback to open bunk stash or locker
RegisterNetEvent('void-prison:server:OpenBunkStash', function(bunkId)
    local src = source
    local citizenid = GetCitizenId(src)
    if not citizenid then return end

    if not JailedPlayers[src] then
        NotifyPlayer(src, "You are not an inmate.", "error")
        return
    end

    if Config.Inventory == 'ox' then
        -- registered already, just open
        -- We will open it on the client side
    else
        -- qb-inventory open stash
        TriggerClientEvent('inventory:client:SetCurrentStash', src, 'prison_bunk_' .. citizenid)
        TriggerClientEvent('void-prison:client:OpenQbStash', src, 'prison_bunk_' .. citizenid, 30, 50000)
    end
end)

RegisterNetEvent('void-prison:server:OpenLocker', function()
    local src = source
    local citizenid = GetCitizenId(src)
    if not citizenid then return end

    if JailedPlayers[src] then
        NotifyPlayer(src, "You cannot access your locker while imprisoned.", "error")
        return
    end

    -- Check if player has locker stash items
    if Config.Inventory == 'ox' then
        -- Open locker stash
        exports.ox_inventory:RegisterStash('prison_locker_' .. citizenid, 'Prison Locker', 50, 100000, citizenid)
        -- We'll let client open it
    else
        -- qb-inventory open locker
        TriggerClientEvent('inventory:client:SetCurrentStash', src, 'prison_locker_' .. citizenid)
        TriggerClientEvent('void-prison:client:OpenQbStash', src, 'prison_locker_' .. citizenid, 50, 100000)
    end
end)

-- ============================================================================
-- BREAKOUT HANDLERS
-- ============================================================================

local function GetItemCount(source, itemName)
    if Config.Inventory == 'ox' then
        return exports.ox_inventory:Search(source, 'count', itemName) or 0
    else
        local player = GetPlayer(source)
        if player then
            local item = player.Functions.GetItemByName(itemName)
            return item and item.amount or 0
        end
    end
    return 0
end

local function RemoveInventoryItem(source, itemName, amount)
    if Config.Inventory == 'ox' then
        exports.ox_inventory:RemoveItem(source, itemName, amount)
    else
        local player = GetPlayer(source)
        if player then
            player.Functions.RemoveItem(itemName, amount)
            TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[itemName], "remove")
        end
    end
end

local function AlertPolice(message)
    -- Notify all online police officers
    local players = GetPlayers()
    for _, plySrc in ipairs(players) do
        local src = tonumber(plySrc)
        if IsPolice(src) then
            NotifyPlayer(src, message, "error")
        end
    end
end

lib.callback.register('void-prison:server:CanHack', function(source)
    local count = GetItemCount(source, Config.Breakout.RequiredItem)
    if count >= 1 then
        return true
    else
        return false, "You need a " .. Config.Breakout.RequiredItem .. " to hijack this terminal."
    end
end)

RegisterNetEvent('void-prison:server:SuccessHack', function()
    local src = source
    local count = GetItemCount(src, Config.Breakout.RequiredItem)
    if count >= 1 then
        RemoveInventoryItem(src, Config.Breakout.RequiredItem, 1)

        -- Trigger breakout state
        TriggerClientEvent('void-prison:client:SetBreakoutState', -1, true)
        TriggerClientEvent('void-prison:client:TriggerBreakoutEffects', -1, Config.Breakout.BreakoutDuration)

        AlertPolice("PRISON ALARM: HACK DETECTED! INMATES ESCAPING!")

        -- Reset breakout after duration
        CreateThread(function()
            Wait(Config.Breakout.BreakoutDuration * 1000)
            TriggerClientEvent('void-prison:client:SetBreakoutState', -1, false)
            AlertPolice("PRISON ALARM: Grid security restored.")
        end)
    end
end)

RegisterNetEvent('void-prison:server:TriggerSilentAlarm', function()
    AlertPolice("PRISON ALARM: Security grid tampering detected near terminal.")
end)

