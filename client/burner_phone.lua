-- Phone UI Variables
local phoneModel = joaat(Config.BurnerPhoneModel)
local phoneProps = nil
local usingPhone = false
local hasDecryptedMessages = false
local contactList = {
    { name = Locales['en']['unknown_contact'], messages = {} },
    { name = Locales['en']['the_network'], messages = {} }
}

function TogglePhone()
    if phoneOpen then
        ClosePhone()
    else
        OpenPhone()
    end
end

function OpenPhone()
    if not hasPhone then return end
    
    phoneOpen = true
    usingPhone = true
    hasDecryptedMessages = false
    
    -- Animation and phone prop
    RequestModel(phoneModel)
    while not HasModelLoaded(phoneModel) do
        Citizen.Wait(100)
    end
    
    local playerPed = PlayerPedId()
    local phonePos = vector3(0.0, 0.0, 0.0)
    local phoneRot = vector3(0.0, 0.0, 0.0)
    
    RequestAnimDict("cellphone@")
    while not HasAnimDictLoaded("cellphone@") do
        Citizen.Wait(100)
    end
    
    TaskPlayAnim(playerPed, "cellphone@", "cellphone_text_in", 8.0, -8.0, -1, 50, 0, false, false, false)
    
    phoneProps = CreateObject(phoneModel, 1.0, 1.0, 1.0, true, true, false)
    AttachEntityToEntity(phoneProps, playerPed, GetPedBoneIndex(playerPed, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    
    -- UI
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        contracts = ActiveContracts,
        contacts = contactList,
        reputation = {
            level = GetRepLevel(),
            points = PlayerData.metadata.blackmarketrep or 0
        }
    })
    
    -- Gradually decrypt messages 
    Citizen.CreateThread(function()
        Citizen.Wait(100)
        for i, contact in ipairs(contactList) do
            for j, msg in ipairs(contact.messages) do
                if not msg.decrypted then
                    SendNUIMessage({
                        action = 'decrypt_message',
                        contactIndex = i,
                        messageIndex = j,
                        decryptTime = Config.MessageDecryptTime
                    })
                    
                    Citizen.Wait(Config.MessageDecryptTime * 1000 / #contact.messages)
                    contactList[i].messages[j].decrypted = true
                end
            end
        end
        hasDecryptedMessages = true
    end)
end

function ClosePhone()
    phoneOpen = false
    usingPhone = false
    
    -- Animation
    local playerPed = PlayerPedId()
    StopAnimTask(playerPed, "cellphone@", "cellphone_text_in", 1.0)
    TaskPlayAnim(playerPed, "cellphone@", "cellphone_text_out", 8.0, -8.0, -1, 50, 0, false, false, false)
    Citizen.Wait(500)
    StopAnimTask(playerPed, "cellphone@", "cellphone_text_out", 1.0)
    
    -- Remove prop
    if phoneProps and DoesEntityExist(phoneProps) then
        DeleteObject(phoneProps)
        phoneProps = nil
    end
    
    -- UI
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'close'
    })
end

function GetRepLevel()
    local rep = PlayerData.metadata.blackmarketrep or 0
    local level = "Street Runner"
    
    for threshold, data in pairs(Config.RepLevels) do
        if rep >= threshold then
            level = data.name
        end
    end
    
    return level
end

-- Add a new contract message
function AddContractMessage(contract)
    local message = {
        content = string.format(
            Locales['en']['contract_details'],
            contract.pickup.label,
            contract.dropoff.label,
            Locales['en'][contract.difficulty],
            contract.payment,
            contract.timeLimit
        ),
        time = os.date("%H:%M"),
        sender = "them",
        contractId = contract.id,
        decrypted = false
    }
    
    table.insert(contactList[2].messages, message)
    
    if phoneOpen then
        SendNUIMessage({
            action = 'new_message',
            contactIndex = 2,
            message = message
        })
    end
    
    -- Send notification if phone is not open
    if not phoneOpen then
        TriggerEvent('QBCore:Notify', Locales['en']['new_contract'], 'success', 3500)
        -- Play notification sound
        PlaySoundFrontend(-1, "Text_Arrive_Tone", "Phone_SoundSet_Default", 1)
    end
end

-- UI Callbacks
RegisterNUICallback('close_phone', function(data, cb)
    ClosePhone()
    cb('ok')
end)

RegisterNUICallback('accept_contract', function(data, cb)
    local contractId = data.contractId
    local contract = nil
    
    for i, c in ipairs(ActiveContracts) do
        if c.id == contractId then
            contract = c
            CurrentContract = c
            table.remove(ActiveContracts, i)
            break
        end
    end
    
    if contract then
        -- Response message
        local responseMsg = {
            content = Locales['en']['contract_accepted'],
            time = os.date("%H:%M"),
            sender = "me",
            decrypted = true
        }
        
        table.insert(contactList[2].messages, responseMsg)
        SendNUIMessage({
            action = 'new_message',
            contactIndex = 2,
            message = responseMsg
        })
        
        -- Create blip for pickup location
        local pickupBlip = AddBlipForCoord(contract.pickup.coords)
        SetBlipSprite(pickupBlip, contract.pickup.blip.sprite)
        SetBlipColour(pickupBlip, contract.pickup.blip.color)
        SetBlipDisplay(pickupBlip, 4)
        SetBlipScale(pickupBlip, 0.8)
        SetBlipAsShortRange(pickupBlip, false)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Pickup: " .. contract.pickup.label)
        EndTextCommandSetBlipName(pickupBlip)
        
        table.insert(blips, pickupBlip)
        
        -- Start contract timer
        StartContractTimer(contract)
        
        -- Server event for tracking
        TriggerServerEvent('vein-blackmarket:server:acceptContract', contractId)
    end
    
    cb('ok')
end)

RegisterNUICallback('decline_contract', function(data, cb)
    local contractId = data.contractId
    
    for i, c in ipairs(ActiveContracts) do
        if c.id == contractId then
            table.remove(ActiveContracts, i)
            break
        end
    end
    
    -- Response message
    local responseMsg = {
        content = Locales['en']['contract_declined'],
        time = os.date("%H:%M"),
        sender = "me",
        decrypted = true
    }
    
    table.insert(contactList[2].messages, responseMsg)
    SendNUIMessage({
        action = 'new_message',
        contactIndex = 2,
        message = responseMsg
    })
    
    -- Server event for tracking
    TriggerServerEvent('vein-blackmarket:server:declineContract', contractId)
    
    cb('ok')
end)

RegisterNUICallback('self_destruct', function(data, cb)
    -- Clear all contracts
    ActiveContracts = {}
    CurrentContract = nil
    
    -- Clear all messages
    for i, contact in ipairs(contactList) do
        contactList[i].messages = {}
    end
    
    -- Clear all blips
    ClearAllBlips()
    
    -- Add destruct confirmation message
    local destructMsg = {
        content = "SYSTEM PURGED. ALL DATA ERASED.",
        time = os.date("%H:%M"),
        sender = "system",
        decrypted = true
    }
    
    table.insert(contactList[2].messages, destructMsg)
    
    -- Update UI
    SendNUIMessage({
        action = 'self_destruct_complete',
        contactIndex = 2,
        message = destructMsg
    })
    
    -- Server event for cooldown
    TriggerServerEvent('vein-blackmarket:server:selfDestruct')
    
    cb('ok')
end)

-- Contract timer
function StartContractTimer(contract)
    Citizen.CreateThread(function()
        local timeLeft = contract.timeLimit * 60 -- Convert to seconds
        local warningSent = false
        
        while timeLeft > 0 and CurrentContract and CurrentContract.id == contract.id do
            Citizen.Wait(1000)
            timeLeft = timeLeft - 1
            
            -- Warning at 25% time left
            if not warningSent and timeLeft <= (contract.timeLimit * 60 * 0.25) then
                warningSent = true
                TriggerEvent('QBCore:Notify', "Contract time running out! " .. math.floor(timeLeft/60) .. " minutes left", 'error', 5000)
            end
        end
        
        -- Fail contract if time runs out
        if timeLeft <= 0 and CurrentContract and CurrentContract.id == contract.id then
            FailCurrentContract("Time expired")
        end
    end)
end

-- Contract failure
function FailCurrentContract(reason)
    if not CurrentContract then return end
    
    local failMsg = {
        content = Locales['en']['contract_failed'] .. " " .. reason,
        time = os.date("%H:%M"),
        sender = "them",
        decrypted = true
    }
    
    table.insert(contactList[2].messages, failMsg)
    
    if phoneOpen then
        SendNUIMessage({
            action = 'new_message',
            contactIndex = 2,
            message = failMsg
        })
    end
    
    -- Notify player
    TriggerEvent('QBCore:Notify', Locales['en']['contract_failed'], 'error', 5000)
    
    -- Clear blips
    ClearAllBlips()
    
    -- Server event
    TriggerServerEvent('vein-blackmarket:server:failContract', CurrentContract.id)
    
    -- Clear current contract
    CurrentContract = nil
end

-- Handle receiving new contracts
RegisterNetEvent('vein-blackmarket:client:receiveContract')
AddEventHandler('vein-blackmarket:client:receiveContract', function(contract)
    if #ActiveContracts < Config.MaxActiveContracts then
        table.insert(ActiveContracts, contract)
        AddContractMessage(contract)
    end
end)

-- Phone self-destruct cooldown notification
RegisterNetEvent('vein-blackmarket:client:selfDestructCooldown')
AddEventHandler('vein-blackmarket:client:selfDestructCooldown', function(minutes)
    TriggerEvent('QBCore:Notify', "Burner phone reset. New contacts in " .. minutes .. " minutes.", 'info', 5000)
end) 