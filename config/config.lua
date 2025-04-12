Config = {}

-- Framework Selection
Config.Framework = "qbox" -- Options: "qbcore", "qbox"

-- General Settings
Config.Debug = false
Config.UseQBCore = false

-- Burner Phone Settings
Config.BurnerPhoneItem = 'burner_phone'
Config.BurnerPhoneModel = 'prop_npc_phone'
Config.SelfDestructCooldown = 60 -- minutes
Config.MessageDecryptTime = 5 -- seconds

-- Contract Settings
Config.NewContractInterval = 30 -- minutes
Config.MaxActiveContracts = 3
Config.ContractTimeoutMinutes = 60
Config.ContractDifficulties = {
    ['easy'] = {
        riskMultiplier = 1.0,
        basePayment = {min = 500, max = 1500},
        repGain = 5,
        policeInterest = 10,
        timeLimit = 20 -- minutes
    },
    ['medium'] = {
        riskMultiplier = 1.5,
        basePayment = {min = 1500, max = 3000},
        repGain = 10,
        policeInterest = 25,
        timeLimit = 15 -- minutes
    },
    ['hard'] = {
        riskMultiplier = 2.0,
        basePayment = {min = 3000, max = 6000},
        repGain = 15,
        policeInterest = 40,
        timeLimit = 10 -- minutes
    }
}

-- Reputation System
Config.MaxRepLevel = 100
Config.RepLevels = {
    [0] = {name = "Street Runner", unlocks = "Basic contracts only"},
    [10] = {name = "Known Associate", unlocks = "Medium difficulty contracts"},
    [25] = {name = "Trusted Courier", unlocks = "Hard difficulty contracts"},
    [50] = {name = "Shadow Mover", unlocks = "Bonus item contracts"},
    [75] = {name = "Ghost Operator", unlocks = "VIP contracts"},
    [100] = {name = "Untouchable", unlocks = "Special black market access"}
}

-- Police Awareness System
Config.PoliceAwarenessEnabled = true
Config.MaxHeatLevel = 100
Config.HeatDecayRate = 0.5 -- per second
Config.HeatTriggers = {
    speedingThreshold = 120, -- km/h
    dangerousDriving = 10, -- heat points for dangerous driving
    weaponDrawn = 25, -- heat points when weapon is drawn
    prolongedStop = 15, -- heat points when staying in same area
    vehicleDamage = 5, -- heat points for each vehicle damage event
}
Config.PoliceAlertThreshold = 75
Config.RequiredCops = 2

-- Pickup/Dropoff Locations
Config.PickupLocations = {
    -- Format: {coords = vector3(x, y, z), label = "Name", blip = {sprite = 1, color = 1}, difficulty = "easy"}
    {coords = vector3(1142.55, -984.96, 46.23), label = "Back Alley Dumpster", blip = {sprite = 440, color = 1}, difficulty = "easy"},
    {coords = vector3(956.12, -1549.61, 30.55), label = "Abandoned Warehouse", blip = {sprite = 440, color = 1}, difficulty = "medium"},
    {coords = vector3(321.58, 189.87, 103.67), label = "Parking Garage", blip = {sprite = 440, color = 1}, difficulty = "easy"},
    {coords = vector3(-1149.71, -1601.55, 4.39), label = "Beach Hideout", blip = {sprite = 440, color = 1}, difficulty = "medium"},
    {coords = vector3(1240.94, -3168.35, 5.86), label = "Docks Container", blip = {sprite = 440, color = 1}, difficulty = "hard"},
    {coords = vector3(-66.71, 6253.93, 31.49), label = "Northern Safehouse", blip = {sprite = 440, color = 1}, difficulty = "hard"}
}

Config.DropoffLocations = {
    {coords = vector3(1217.68, -668.03, 63.51), label = "Vinewood Hills", blip = {sprite = 440, color = 2}, difficulty = "medium"},
    {coords = vector3(-591.69, -1774.43, 23.18), label = "Hidden Beach Cave", blip = {sprite = 440, color = 2}, difficulty = "hard"},
    {coords = vector3(-1578.19, -76.23, 54.23), label = "Golf Club", blip = {sprite = 440, color = 2}, difficulty = "medium"},
    {coords = vector3(111.25, -2333.91, 5.97), label = "Industrial Zone", blip = {sprite = 440, color = 2}, difficulty = "easy"},
    {coords = vector3(2132.46, 4783.77, 40.97), label = "Farm Outskirts", blip = {sprite = 440, color = 2}, difficulty = "hard"},
    {coords = vector3(-1521.08, 852.11, 181.59), label = "Mountain Cabin", blip = {sprite = 440, color = 2}, difficulty = "hard"}
}

-- Item Information
Config.BlackMarketItems = {
    {name = "cryptostick", label = "Cryptostick", description = "Digital currency storage", weight = 1, rarity = "common"},
    {name = "black_usb", label = "Black USB", description = "Contains sensitive information", weight = 1, rarity = "rare"},
    {name = "counterfeit_cash", label = "Counterfeit Cash", description = "Fake bills", weight = 5, rarity = "common"},
    {name = "weapon_parts", label = "Weapon Parts", description = "Disassembled gun components", weight = 7, rarity = "uncommon"},
    {name = "security_card_01", label = "Security Card", description = "Access to restricted areas", weight = 1, rarity = "rare"}
}

-- NPC Settings
Config.NPCWatchers = true
Config.NPCWatcherModels = {"s_m_m_bouncer_01", "s_m_y_dealer_01", "g_m_y_lost_01"} 