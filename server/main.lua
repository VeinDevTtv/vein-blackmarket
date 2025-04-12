-- Framework detection
local QBCore = nil
local Framework = nil

-- Initialize
Citizen.CreateThread(function()
    if Config.Framework == "qbox" then
        Framework = exports['qbx_core']:GetSharedObject()
        QBCore = Framework
    else -- Default to QBCore
        Framework = exports['qb-core']:GetCoreObject()
        QBCore = Framework
    end
    
    -- Add burner phone to Framework items
    CreateBurnerPhoneItem()
    
    -- Start contract generation for players with phones
    Citizen.Wait(10000) -- Wait for server to initialize
    StartContractGeneration()
end)

-- Create the burner phone item
function CreateBurnerPhoneItem()
    Framework.Functions.AddItem(Config.BurnerPhoneItem, {
        name = Config.BurnerPhoneItem,
        label = 'Burner Phone',
        weight = 200,
        type = 'item',
        image = 'burner_phone.png',
        unique = false,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'A disposable phone for underground communications'
    })
    
    Framework.Functions.CreateUseableItem(Config.BurnerPhoneItem, function(source, item)
        local Player = Framework.Functions.GetPlayer(source)
        if Player then
            TriggerClientEvent('vein-blackmarket:client:togglePhone', source)
        end
    end)
end

-- Helper function for cross-framework notifications
function SendNotification(source, message, notifType, duration)
    duration = duration or 3500
    if Config.Framework == "qbox" then
        -- QBox notification
        TriggerClientEvent('qbx_core:notify', source, {
            title = "Black Market",
            description = message,
            type = notifType
        })
    else
        -- Default to QBCore notification
        TriggerClientEvent('QBCore:Notify', source, message, notifType, duration)
    end
end

-- Purchase a burner phone
RegisterNetEvent('vein-blackmarket:server:buyBurnerPhone')
AddEventHandler('vein-blackmarket:server:buyBurnerPhone', function()
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    
    if Player then
        local price = 500
        if Player.PlayerData.money.cash >= price then
            Player.Functions.RemoveMoney('cash', price)
            Player.Functions.AddItem(Config.BurnerPhoneItem, 1)
            TriggerClientEvent('inventory:client:ItemBox', src, Framework.Shared.Items[Config.BurnerPhoneItem], 'add')
            SendNotification(src, Locales['en']['phone_purchased'], 'success')
            
            -- Generate first contract after short delay
            Citizen.SetTimeout(30000, function()
                if GetPlayerFromSource(src) then
                    GenerateContractForPlayer(src)
                end
            end)
        else
            SendNotification(src, Locales['en']['not_enough_money'], 'error')
        end
    end
end)

-- Generate contracts for all players periodically
function StartContractGeneration()
    Citizen.CreateThread(function()
        while true do
            local players = QBCore.Functions.GetPlayers()
            for _, playerId in ipairs(players) do
                local Player = QBCore.Functions.GetPlayer(playerId)
                
                if Player then
                    -- Check if they have a burner phone and are not on cooldown
                    local hasPhone = Player.Functions.GetItemByName(Config.BurnerPhoneItem)
                    local citizenId = Player.PlayerData.citizenid
                    
                    if hasPhone and not cooldowns[citizenId] then
                        -- Random chance to receive a contract
                        -- Higher reputation = higher chance
                        local rep = Player.PlayerData.metadata.blackmarketrep or 0
                        local baseChance = 0.3 -- 30% base chance
                        local repBonus = math.min(0.5, rep / 100) -- Up to 50% bonus based on rep
                        local chance = baseChance + repBonus
                        
                        if math.random() < chance then
                            GenerateContractForPlayer(playerId)
                            
                            -- Set cooldown
                            cooldowns[citizenId] = true
                            Citizen.SetTimeout(Config.NewContractInterval * 60 * 1000, function()
                                cooldowns[citizenId] = false
                            end)
                        end
                    end
                end
            end
            
            Citizen.Wait(5 * 60 * 1000) -- Check every 5 minutes
        end
    end)
end

-- Self-destruct cooldown
RegisterNetEvent('vein-blackmarket:server:selfDestruct')
AddEventHandler('vein-blackmarket:server:selfDestruct', function()
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    
    if Player then
        local citizenId = Player.PlayerData.citizenid
        cooldowns[citizenId] = true
        
        -- Set cooldown
        local minutes = Config.SelfDestructCooldown
        Citizen.SetTimeout(minutes * 60 * 1000, function()
            cooldowns[citizenId] = false
        end)
        
        TriggerClientEvent('vein-blackmarket:client:selfDestructCooldown', src, minutes)
    end
end)

-- Get reputation level data
function GetRepDataForLevel(rep)
    local currentLevel = nil
    local nextLevel = nil
    local nextLevelThreshold = nil
    
    for threshold, data in pairs(Config.RepLevels) do
        if rep >= threshold and (not currentLevel or threshold > currentLevel.threshold) then
            currentLevel = {
                threshold = threshold,
                name = data.name,
                unlocks = data.unlocks
            }
        end
        
        if rep < threshold and (not nextLevel or threshold < nextLevel.threshold) then
            nextLevel = {
                threshold = threshold,
                name = data.name,
                unlocks = data.unlocks
            }
            nextLevelThreshold = threshold
        end
    end
    
    return currentLevel, nextLevel, nextLevelThreshold
end

-- Create police blip event
RegisterNetEvent('vein-blackmarket:server:createPoliceBlip')
AddEventHandler('vein-blackmarket:server:createPoliceBlip', function(coords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player then
        local players = QBCore.Functions.GetPlayers()
        for _, playerId in ipairs(players) do
            local targetPlayer = QBCore.Functions.GetPlayer(playerId)
            if targetPlayer and targetPlayer.PlayerData.job.name == 'police' then
                TriggerClientEvent('vein-blackmarket:client:createPoliceBlip', playerId, coords)
            end
        end
    end
end)

-- Check if a player exists by source
function GetPlayerFromSource(src)
    local Player = Framework.Functions.GetPlayer(src)
    return Player ~= nil
end 