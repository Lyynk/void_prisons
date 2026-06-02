Config = {}

-- Framework Settings
Config.Framework = 'qbx' -- Options: 'qb' (QBCore) or 'qbx' (QBox)
Config.Inventory = 'ox'  -- Options: 'qb' (qb-inventory) or 'ox' (ox_inventory)
Config.Appearance = 'illenium' -- Options: 'qb' (qb-clothing/illenium default compatibility) or 'illenium' (illenium-appearance exports)

-- General Settings
Config.JailTimeMultiplier = 1 -- Multiplier for jail time ticks. 1 tick = 1 second. (Set to 60 if you want 1 month = 1 minute, etc.)
Config.AlertPoliceOnBreakout = true -- Whether police are notified when a breakout is started
Config.PoliceJobs = { 'police', 'bcso', 'sasp', 'sheriff' } -- Jobs considered "police" who can use the jail tablet or receive alerts

-- Jail Locations
Config.JailSpawn = vector4(1759.04, 2587.35, 45.79, 270.0) -- Inmate spawn coordinates inside the prison
Config.ReleaseLocation = vector4(1847.66, 2586.06, 45.67, 270.0) -- Release spot outside the prison gates
Config.LockerLocation = vector3(1840.42, 2579.52, 46.01) -- Seized item retrieval locker
Config.YardCenter = vector3(1690.0, 2560.0, 45.0) -- Center of prison yard
Config.YardRadius = 160.0 -- Safe yard boundaries radius. Leaving without jailbreak triggers teleport back

-- Inmate Bunk Stashes
Config.BunkStashes = {
    { id = "prison_bunk_1", coords = vector3(1769.75, 2584.22, 45.79), label = "Cell Bunk Stash 1" },
    { id = "prison_bunk_2", coords = vector3(1766.19, 2588.16, 45.79), label = "Cell Bunk Stash 2" },
    { id = "prison_bunk_3", coords = vector3(1763.50, 2591.31, 45.79), label = "Cell Bunk Stash 3" },
    { id = "prison_bunk_4", coords = vector3(1759.88, 2594.88, 45.79), label = "Cell Bunk Stash 4" },
}

-- Prison Breakout Config
Config.Breakout = {
    HackCoords = vector3(1792.83, 2603.88, 45.56), -- Location of the terminal to hack
    RequiredItem = 'gate_hack_device', -- Item needed to hack the prison doors
    HackDuration = 15000, -- Duration of the hacking animation in ms
    MinigameType = 'skillcheck', -- Minigame options: 'skillcheck' or 'numbers'
    PoliceAlertCooldown = 60000, -- Cooldown for police notification in ms
    BreakoutDuration = 300, -- How long the gates remain unlocked/jail break is active (in seconds)
}

-- Prison Jobs for Sentence Reduction
Config.Jobs = {
    sweep = {
        name = "Sweeping the Yard",
        points = {
            vector3(1771.55, 2575.25, 45.73),
            vector3(1764.12, 2568.18, 45.68),
            vector3(1755.85, 2561.42, 45.72),
            vector3(1744.15, 2552.12, 45.68),
        },
        duration = 8000, -- time to complete task in ms
        timeReduction = 15, -- sentence reduction in seconds/months
        anim = { dict = "amb@world_human_janitor@broom@idle_a", clip = "idle_a" },
        prop = { model = "prop_tool_broom", bone = 28422, pos = vector3(0.01, 0.04, -0.03), rot = vector3(0.0, 0.0, 0.0) }
    },
    dishes = {
        name = "Washing Dishes",
        points = {
            vector3(1786.12, 2560.85, 45.67),
            vector3(1787.85, 2563.15, 45.67),
        },
        duration = 10000,
        timeReduction = 20,
        anim = { dict = "prop_carry_paddle", clip = "idle" }, -- placeholder anim or custom
        prop = nil
    },
    laundry = {
        name = "Doing Laundry",
        points = {
            vector3(1758.12, 2558.15, 45.67),
            vector3(1760.15, 2559.88, 45.67),
        },
        duration = 12000,
        timeReduction = 25,
        anim = { dict = "amb@prop_human_bum_shopping_cart@male@idle_a", clip = "idle_c" },
        prop = nil
    },
    electrical = {
        name = "Electrical Maintenance",
        points = {
            vector3(1779.15, 2598.12, 45.79),
            vector3(1772.88, 2595.42, 45.79),
        },
        duration = 6000,
        timeReduction = 30,
        anim = { dict = "amb@world_human_welding@male@base", clip = "base" },
        prop = nil
    }
}

-- Integrations
Config.MDT = 'ps-mdt' -- Options: 'ps-mdt' or nil

Config.OkokBilling = {
    enabled = false, -- Enable this to support okokBilling
    society = 'police',
    societyName = 'LSPD',
    fineAmountPerMonth = 150 -- Fine charged per month/second of jail time
}

Config.OkokNotify = {
    enabled = false -- Enable this to support okokNotify alerts
}

-- Jail Uniform Config (if illenium-appearance is not used or to customize default uniforms)
Config.Uniforms = {
    male = {
        components = {
            { componentId = 1, drawableId = 0, textureId = 0 }, -- Mask
            { componentId = 3, drawableId = 0, textureId = 0 }, -- Torso
            { componentId = 4, drawableId = 5, textureId = 7 }, -- Pants (Orange prison pants)
            { componentId = 6, drawableId = 34, textureId = 0 }, -- Shoes
            { componentId = 8, drawableId = 15, textureId = 0 }, -- Undershirt
            { componentId = 11, drawableId = 22, textureId = 0 }, -- Jacket (Orange jumpsuit top)
        },
        props = {}
    },
    female = {
        components = {
            { componentId = 1, drawableId = 0, textureId = 0 },
            { componentId = 3, drawableId = 14, textureId = 0 },
            { componentId = 4, drawableId = 66, textureId = 6 }, -- Pants
            { componentId = 6, drawableId = 35, textureId = 0 }, -- Shoes
            { componentId = 8, drawableId = 15, textureId = 0 },
            { componentId = 11, drawableId = 73, textureId = 0 }, -- Jacket
        },
        props = {}
    }
}
