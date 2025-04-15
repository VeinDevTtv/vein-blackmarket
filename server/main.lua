-- Framework detection
local QBCore = nil
local Framework = nil
local cooldowns = {}

-- Initialize
Citizen.CreateThread(function()
    if Config.Framework == "qbox" then
        -- Try different methods to get QBX Core with error handling
        local success, result = pcall(function()
            return exports['qbx_core']:GetCoreObject()
        end)
        
        if success and result then
            Framework = result
            QBCore = Framework
            print('^2[vein-blackmarket] QBX Core loaded via GetCoreObject^0')
        else
            -- Try alternative methods
            success, result = pcall(function() 
                return exports['qbx_core']:GetSharedObject() 
            end)
            
            if success and result then
                Framework = result
                QBCore = Framework
                print('^2[vein-blackmarket] QBX Core loaded via GetSharedObject^0')
            else
                print('^1[vein-blackmarket] Failed to load QBX Core. Falling back to QBCore.^0')
                
                -- Fall back to QBCore
                success, result = pcall(function() 
                    return exports['qb-core']:GetCoreObject() 
                end)
                
                if success and result then
                    Framework = result
                    QBCore = Framework
                    print('^2[vein-blackmarket] QBCore loaded as fallback^0')
                else
                    print('^1[vein-blackmarket] Failed to load any framework. Resource may not function correctly.^0')
                end
            end
        end
        
        -- Register ox_inventory hook for QBox to track burner phone
        RegisterServerEvent('ox_inventory:itemCount')
        AddEventHandler('ox_inventory:itemCount', function(source, item, count)
            if item == Config.BurnerPhoneItem then
                local hasPhone = count > 0
                TriggerClientEvent('vein-blackmarket:client:updatePhoneStatus', source, hasPhone)
            end
        end)
    else -- Default to QBCore
        local success, result = pcall(function() 
            return exports['qb-core']:GetCoreObject() 
        end)
        
        if success and result then
            Framework = result
            QBCore = Framework
            print('^2[vein-blackmarket] QBCore loaded via GetCoreObject^0')
        else
            print('^1[vein-blackmarket] Failed to load QBCore. Resource may not function correctly.^0')
        end
    end
    
    -- Only continue if framework is loaded
    if Framework then
        -- Add burner phone to Framework items
        CreateBurnerPhoneItem()
        
        -- Start contract generation for players with phones
        Citizen.Wait(10000) -- Wait for server to initialize
        StartContractGeneration()
    else
        print('^1[vein-blackmarket] No framework loaded. Resource initialization halted.^0')
    end
end)

-- Create the burner phone item
function CreateBurnerPhoneItem()
    if not Framework then
        print('^1[vein-blackmarket] Framework not initialized. Cannot create burner phone item.^0')
        return
    end
    
    -- Check if using QBX with ox_inventory
    local isQbox = Config.Framework == "qbox"
    local hasOxInventory = pcall(function() return exports.ox_inventory end)
    
    if isQbox and hasOxInventory then
        -- Register with ox_inventory instead of adding to QBX items
        local success = exports.ox_inventory:RegisterItem({
            name = Config.BurnerPhoneItem,
            label = 'Burner Phone',
            weight = 200,
            stack = true,
            close = true,
            description = 'A disposable phone for underground communications'
        })
        
        if success then
            print('^2[vein-blackmarket] Registered burner phone with ox_inventory^0')
        else
            print('^1[vein-blackmarket] Failed to register burner phone with ox_inventory^0')
        end
    elseif not isQbox then
        -- For regular QBCore, use the traditional method
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
    end
    
    -- Make item usable (works for both ox_inventory and QBCore)
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
    if not Framework then
        print('^1[vein-blackmarket] Framework not initialized. Cannot process burner phone purchase.^0')
        return
    end
    
    local Player = Framework.Functions.GetPlayer(src)
    
    if Player then
        local price = 500
        if Player.PlayerData.money.cash >= price then
            Player.Functions.RemoveMoney('cash', price)
            
            -- Check if using QBX with ox_inventory
            local isQbox = Config.Framework == "qbox"
            local hasOxInventory = pcall(function() return exports.ox_inventory end)
            
            local itemAdded = false
            if isQbox and hasOxInventory then
                -- Use ox_inventory to add item
                itemAdded = exports.ox_inventory:AddItem(src, Config.BurnerPhoneItem, 1)
                if itemAdded then
                    -- Update client
                    TriggerClientEvent('vein-blackmarket:client:updatePhoneStatus', src, true)
                else
                    -- Refund if inventory is full
                    Player.Functions.AddMoney('cash', price)
                    SendNotification(src, 'Your inventory is full!', 'error')
                    return
                end
            else
                -- Use QBCore inventory
                local canCarry = Player.Functions.AddItem(Config.BurnerPhoneItem, 1)
                if canCarry then
                    TriggerClientEvent('inventory:client:ItemBox', src, Framework.Shared.Items[Config.BurnerPhoneItem], 'add')
                    itemAdded = true
                else
                    -- Refund if inventory is full
                    Player.Functions.AddMoney('cash', price)
                    SendNotification(src, 'Your inventory is full!', 'error')
                    return
                end
            end
            
            if itemAdded then
                SendNotification(src, Locales['en']['phone_purchased'], 'success')
                
                -- Generate first contract after short delay
                Citizen.SetTimeout(30000, function()
                    if GetPlayerFromSource(src) then
                        GenerateContractForPlayer(src)
                    end
                end)
            end
        else
            SendNotification(src, Locales['en']['not_enough_money'], 'error')
        end
    end
end)

-- Generate contracts for all players periodically
function StartContractGeneration()
    if not QBCore then
        print('^1[vein-blackmarket] QBCore not initialized. Cannot start contract generation.^0')
        return
    end
    
    Citizen.CreateThread(function()
        while true do
            local players = QBCore.Functions.GetPlayers()
            for _, playerId in ipairs(players) do
                local Player = QBCore.Functions.GetPlayer(playerId)
                
                if Player then
                    -- Check if they have a burner phone and are not on cooldown
                    local hasPhone = false
                    local citizenId = Player.PlayerData.citizenid
                    
                    if Config.Framework == "qbox" then
                        -- Use ox_inventory to check for the item
                        local items = exports.ox_inventory:GetInventoryItems(playerId)
                        for _, item in pairs(items) do
                            if item.name == Config.BurnerPhoneItem then
                                hasPhone = true
                                break
                            end
                        end
                    else
                        -- Use QBCore inventory
                        hasPhone = Player.Functions.GetItemByName(Config.BurnerPhoneItem)
                    end
                    
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
    if not Framework then
        print('^1[vein-blackmarket] Framework not initialized. Cannot process self-destruct.^0')
        return
    end
    
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
    if not QBCore then
        print('^1[vein-blackmarket] QBCore not initialized. Cannot create police blip.^0')
        return
    end
    
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
    if not Framework then return false end
    local Player = Framework.Functions.GetPlayer(src)
    return Player ~= nil
end 