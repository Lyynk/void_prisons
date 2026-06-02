local tabletEntity = nil
local isTabletOpen = false

local function LoadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

-- ============================================================================
-- PROP & ANIMATION CONTROLLER
-- ============================================================================

local function OpenTabletProps()
    local ped = PlayerPedId()
    local modelHash = `prop_cs_tablet`
    
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(10)
    end
    
    local coords = GetEntityCoords(ped)
    local prop = CreateObject(modelHash, coords.x, coords.y, coords.z, true, true, true)
    
    -- Attach to Left Hand (bone 60309)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 60309), 0.03, 0.002, -0.0, 10.0, 160.0, 0.0, true, true, false, true, 1, true)
    tabletEntity = prop

    LoadAnimDict("amb@code_human_in_car_mp_actions@tablet@base")
    TaskPlayAnim(ped, "amb@code_human_in_car_mp_actions@tablet@base", "base", 8.0, -8.0, -1, 49, 0, false, false, false)
end

local function CloseTabletProps()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    if tabletEntity and DoesEntityExist(tabletEntity) then
        DeleteEntity(tabletEntity)
        tabletEntity = nil
    end
    RemoveAnimDict("amb@code_human_in_car_mp_actions@tablet@base")
end

-- ============================================================================
-- NUI TRIGGERS
-- ============================================================================

RegisterNetEvent('void-prison:client:OpenTablet', function()
    if isTabletOpen then return end
    isTabletOpen = true
    
    OpenTabletProps()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openTablet"
    })
end)

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('closeTablet', function(data, cb)
    isTabletOpen = false
    SetNuiFocus(false, false)
    CloseTabletProps()
    cb('ok')
end)

RegisterNUICallback('getInmates', function(data, cb)
    lib.callback('void-prison:server:GetInmateList', false, function(inmates)
        cb(inmates)
    end)
end)

RegisterNUICallback('updateSentence', function(data, cb)
    TriggerServerEvent('void-prison:server:UpdateSentence', {
        citizenid = data.citizenid,
        amount = tonumber(data.amount)
    })
    cb('ok')
end)

RegisterNUICallback('releaseInmate', function(data, cb)
    TriggerServerEvent('void-prison:server:ReleaseInmate', {
        citizenid = data.citizenid
    })
    cb('ok')
end)

-- Clean up on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if isTabletOpen then
            SetNuiFocus(false, false)
            CloseTabletProps()
        end
    end
end)
