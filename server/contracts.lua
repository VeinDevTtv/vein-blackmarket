-- Vein BlackMarket: Contracts server file
local QBCore = nil
local activeContracts = {}
local contractIdCounter = 0
local onlineContractDrop = {}

-- Framework reference
local Framework = nil
Citizen.CreateThread(function()
    if Config.Framework == "qbox" then
        Framework = exports['qbx_core']:GetSharedObject()
        QBCore = Framework
    else -- Default to QBCore
        Framework = exports['qb-core']:GetCoreObject()
        QBCore = Framework
    end
end)

-- Helper function for sending notifications across frameworks
function SendNotification(source, message, notifType, duration)
    if not source or source == 0 then return end
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

-- Generate a new contract for a player
function GenerateContractForPlayer(playerId)
    local Player = Framework.Functions.GetPlayer(playerId)
    
    if not Player then return end
    
    -- Get player rep level to determine available contract difficulty
    local rep = Player.PlayerData.metadata.blackmarketrep or 0
    local availableDifficulties = {"easy"}
    
    if rep >= 10 then
        table.insert(availableDifficulties, "medium")
    end
    
    if rep >= 25 then
        table.insert(availableDifficulties, "hard")
    end
    
    -- Select random difficulty from available options
    local difficulty = availableDifficulties[math.random(1, #availableDifficulties)]
    
    -- Filter locations by difficulty
    local availablePickups = {}
    for _, location in ipairs(Config.PickupLocations) do
        if location.difficulty == difficulty then
            table.insert(availablePickups, location)
        end
    end
    
    local availableDropoffs = {}
    for _, location in ipairs(Config.DropoffLocations) do
        if location.difficulty == difficulty then
            table.insert(availableDropoffs, location)
        end
    end
    
    -- If no locations with matching difficulty, use all locations
    if #availablePickups == 0 then availablePickups = Config.PickupLocations end
    if #availableDropoffs == 0 then availableDropoffs = Config.DropoffLocations end
    
    -- Select random pickup and dropoff
    local pickup = availablePickups[math.random(1, #availablePickups)]
    local dropoff = availableDropoffs[math.random(1, #availableDropoffs)]
    
    -- Calculate payment based on difficulty and distance
    local distance = #(pickup.coords - dropoff.coords)
    local difficultyData = Config.ContractDifficulties[difficulty]
    local distancePayment = distance * 0.1 -- $0.10 per meter
    local basePayment = math.random(difficultyData.basePayment.min, difficultyData.basePayment.max)
    local payment = math.floor((basePayment + distancePayment) * difficultyData.riskMultiplier)
    
    -- Determine if this contract has bonus items
    local hasBonus = false
    local bonusItems = {}
    if difficulty == "medium" or difficulty == "hard" then
        hasBonus = math.random() < 0.3
        
        if hasBonus then
            -- Add random items from the blackmarket items list
            local numItems = math.random(1, 2)
            local itemPool = {}
            
            -- Filter items by rarity based on difficulty
            for _, item in ipairs(Config.BlackMarketItems) do
                if (difficulty == "medium" and item.rarity ~= "rare") or
                   (difficulty == "hard") then
                    table.insert(itemPool, item)
                end
            end
            
            -- Select random items
            for i = 1, numItems do
                if #itemPool > 0 then
                    local idx = math.random(1, #itemPool)
                    table.insert(bonusItems, {
                        name = itemPool[idx].name,
                        label = itemPool[idx].label,
                        amount = math.random(1, 3)
                    })
                    table.remove(itemPool, idx)
                end
            end
        end
    end
    
    -- Create the contract
    contractIdCounter = contractIdCounter + 1
    local contract = {
        id = "contract_" .. contractIdCounter,
        playerId = playerId,
        pickup = pickup,
        dropoff = dropoff,
        difficulty = difficulty,
        payment = payment,
        timeLimit = difficultyData.timeLimit,
        hasBonus = hasBonus,
        bonusItems = bonusItems,
        created = os.time(),
        expires = os.time() + (Config.ContractTimeoutMinutes * 60),
        status = "pending", -- pending, active, completed, failed
        isDecoy = false
    }
    
    -- Add chance for decoy package (false contract) for hard difficulty
    if difficulty == "hard" and math.random() < 0.15 then
        contract.isDecoy = true
        contract.payment = payment * 1.5 -- Higher payment to entice the player
    end
    
    -- Store contract
    activeContracts[contract.id] = contract
    
    -- Send contract to client
    TriggerClientEvent('vein-blackmarket:client:receiveContract', playerId, contract)
    
    return contract
end

-- Accept contract
RegisterNetEvent('vein-blackmarket:server:acceptContract')
AddEventHandler('vein-blackmarket:server:acceptContract', function(contractId)
    local src = source
    local contract = activeContracts[contractId]
    
    if contract and contract.playerId == src and contract.status == "pending" then
        contract.status = "active"
        contract.acceptedTime = os.time()
    end
end)

-- Decline contract
RegisterNetEvent('vein-blackmarket:server:declineContract')
AddEventHandler('vein-blackmarket:server:declineContract', function(contractId)
    local src = source
    local contract = activeContracts[contractId]
    
    if contract and contract.playerId == src and contract.status == "pending" then
        activeContracts[contractId] = nil
    end
end)

-- Package picked up
RegisterNetEvent('vein-blackmarket:server:packagePickedUp')
AddEventHandler('vein-blackmarket:server:packagePickedUp', function(contractId)
    local src = source
    local contract = activeContracts[contractId]
    
    if contract and contract.playerId == src and contract.status == "active" then
        contract.pickedUp = true
        contract.pickupTime = os.time()
    end
end)

-- Complete contract
RegisterNetEvent('vein-blackmarket:server:completeContract')
AddEventHandler('vein-blackmarket:server:completeContract', function(contractId, heatLevel)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    local contract = activeContracts[contractId]
    
    if not contract or not Player then return end
    
    if contract.playerId == src and contract.status == "active" then
        contract.status = "completed"
        contract.completedTime = os.time()
        
        local timeBonus = 0
        if contract.acceptedTime and contract.pickupTime then
            local deliveryTime = os.time() - contract.pickupTime
            local maxTime = contract.timeLimit * 60
            
            -- Bonus for quick delivery
            if deliveryTime < maxTime * 0.5 then
                timeBonus = contract.payment * 0.2
            elseif deliveryTime < maxTime * 0.75 then
                timeBonus = contract.payment * 0.1
            end
        end
        
        local heatBonus = 0
        if heatLevel < 25 then
            -- Bonus for staying under the radar
            heatBonus = contract.payment * 0.15
        end
        
        -- Apply bonuses
        local finalPayment = math.floor(contract.payment + timeBonus + heatBonus)
        
        -- Handle decoy packages
        if contract.isDecoy then
            -- 10% chance to get full payment even if decoy
            if math.random() < 0.1 then
                Player.Functions.AddMoney('cash', finalPayment)
                SendNotification(src, 'You delivered a decoy package but still got paid $' .. finalPayment, 'success')
            else
                SendNotification(src, 'You delivered a decoy package! No payment received.', 'error')
                finalPayment = 0
            end
        else
            -- Normal payout
            Player.Functions.AddMoney('cash', finalPayment)
        end
        
        -- Award bonus items if applicable
        if contract.hasBonus and #contract.bonusItems > 0 and not contract.isDecoy then
            for _, item in ipairs(contract.bonusItems) do
                Player.Functions.AddItem(item.name, item.amount)
                TriggerClientEvent('inventory:client:ItemBox', src, Framework.Shared.Items[item.name], 'add')
                SendNotification(src, 'Bonus item received: ' .. item.label, 'success')
            end
        end
        
        -- Award reputation
        local difficultyData = Config.ContractDifficulties[contract.difficulty]
        local repGain = difficultyData.repGain
        
        -- Bonus rep for low heat
        if heatLevel < 25 then
            repGain = repGain * 1.25
        end
        
        AddPlayerReputation(Player, repGain)
        
        -- Cleanup contract
        activeContracts[contractId] = nil
    end
end)

-- Fail contract
RegisterNetEvent('vein-blackmarket:server:failContract')
AddEventHandler('vein-blackmarket:server:failContract', function(contractId)
    local src = source
    local contract = activeContracts[contractId]
    
    if contract and contract.playerId == src and contract.status == "active" then
        contract.status = "failed"
        contract.failedTime = os.time()
        
        -- Potential rep loss for failed contracts (only medium/hard)
        if contract.difficulty ~= "easy" then
            local Player = Framework.Functions.GetPlayer(src)
            if Player then
                local repLoss = -2
                if contract.difficulty == "hard" then
                    repLoss = -5
                end
                
                AddPlayerReputation(Player, repLoss)
                SendNotification(src, 'Lost reputation: ' .. repLoss, 'error')
            end
        end
        
        -- Cleanup contract
        activeContracts[contractId] = nil
    end
end)

-- Clean up expired contracts
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000) -- Check every minute
        local currentTime = os.time()
        
        for id, contract in pairs(activeContracts) do
            if contract.expires < currentTime and contract.status == "pending" then
                -- Contract expired, remove it
                activeContracts[id] = nil
                
                -- Notify the player if they're online
                local playerId = contract.playerId
                if GetPlayerFromSource(playerId) then
                    SendNotification(playerId, Locales['en']['contract_expired'], 'error')
                end
            end
        end
    end
end)

-- Add reputation to player
function AddPlayerReputation(Player, amount)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    local currentRep = Player.PlayerData.metadata.blackmarketrep or 0
    local newRep = math.max(0, math.min(Config.MaxRepLevel, currentRep + amount))
    
    -- Update metadata
    Player.Functions.SetMetaData('blackmarketrep', newRep)
    
    -- Send notification
    local source = Player.PlayerData.source
    if amount > 0 then
        SendNotification(source, string.format(Locales['en']['rep_increased'], amount), 'success')
    end
    
    -- Check for level up
    local oldLevel, _, _ = GetRepDataForLevel(currentRep)
    local newLevel, _, _ = GetRepDataForLevel(newRep)
    
    if newLevel and oldLevel and newLevel.threshold > oldLevel.threshold then
        SendNotification(source, string.format(Locales['en']['level_up'], newLevel.name), 'success')
        SendNotification(source, string.format(Locales['en']['unlocked'], newLevel.unlocks), 'success')
    end
    
    return newRep
end 