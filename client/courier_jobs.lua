local pickupBlip = nil
local dropoffBlip = nil
local packageObject = nil
local hasPackage = false
local packageProp = 'prop_cs_package_01' -- Default package prop
local zoneBlip = nil
local decoyPackages = {}

-- Contract pickup/dropoff zones handling
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if CurrentContract and not hasPackage then
            -- Pickup handling
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local pickupCoords = CurrentContract.pickup.coords
            local dist = #(playerCoords - pickupCoords)
            
            if dist < 30.0 and not DoesEntityExist(packageObject) then
                CreatePackageAtPickup(CurrentContract)
            end
            
            if dist < 2.0 and DoesEntityExist(packageObject) then
                DrawText3D(pickupCoords.x, pickupCoords.y, pickupCoords.z + 0.5, Locales['en']['pickup_item'])
                
                if IsControlJustReleased(0, 38) then -- E key
                    PickupPackage()
                end
            end
        elseif CurrentContract and hasPackage then
            -- Dropoff handling
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local dropoffCoords = CurrentContract.dropoff.coords
            local dist = #(playerCoords - dropoffCoords)
            
            if dist < 2.0 then
                DrawText3D(dropoffCoords.x, dropoffCoords.y, dropoffCoords.z + 0.5, Locales['en']['dropoff_item'])
                
                if IsControlJustReleased(0, 38) then -- E key
                    DropoffPackage()
                end
            end
        end
    end
end)

-- Create package at pickup location
function CreatePackageAtPickup(contract)
    if DoesEntityExist(packageObject) then return end
    
    local packageCoords = contract.pickup.coords
    
    RequestModel(GetHashKey(packageProp))
    while not HasModelLoaded(GetHashKey(packageProp)) do
        Citizen.Wait(10)
    end
    
    packageObject = CreateObject(GetHashKey(packageProp), packageCoords.x, packageCoords.y, packageCoords.z - 1.0, false, false, false)
    PlaceObjectOnGroundProperly(packageObject)
    FreezeEntityPosition(packageObject, true)
    SetEntityAsMissionEntity(packageObject, true, true)
    
    -- Create decoy packages for hard contracts
    if contract.difficulty == "hard" then
        CreateDecoyPackages(contract)
    end
end

-- Create decoy packages for harder contracts
function CreateDecoyPackages(contract)
    local pickupCoords = contract.pickup.coords
    local numDecoys = math.random(2, 4)
    
    for i = 1, numDecoys do
        local offsetX = math.random(-10, 10)
        local offsetY = math.random(-10, 10)
        local decoyCoords = vector3(pickupCoords.x + offsetX, pickupCoords.y + offsetY, pickupCoords.z)
        
        RequestModel(GetHashKey(packageProp))
        while not HasModelLoaded(GetHashKey(packageProp)) do
            Citizen.Wait(10)
        end
        
        local decoy = CreateObject(GetHashKey(packageProp), decoyCoords.x, decoyCoords.y, decoyCoords.z - 1.0, false, false, false)
        PlaceObjectOnGroundProperly(decoy)
        FreezeEntityPosition(decoy, true)
        SetEntityAsMissionEntity(decoy, true, true)
        
        table.insert(decoyPackages, decoy)
    end
end

-- Pickup the package
function PickupPackage()
    if not DoesEntityExist(packageObject) or hasPackage then return end
    
    RequestAnimDict("anim@heists@box_carry@")
    while not HasAnimDictLoaded("anim@heists@box_carry@") do
        Citizen.Wait(10)
    end
    
    local playerPed = PlayerPedId()
    
    -- Animation and attaching package to player
    TaskPlayAnim(playerPed, "anim@heists@box_carry@", "idle", 8.0, -8.0, -1, 50, 0, false, false, false)
    AttachEntityToEntity(packageObject, playerPed, GetPedBoneIndex(playerPed, 60309), 0.025, 0.08, 0.255, -145.0, 290.0, 0.0, true, true, false, true, 1, true)
    
    hasPackage = true
    -- Notify other modules about package status
    TriggerEvent('vein-blackmarket:client:setHasPackage', true)
    
    -- Remove pickup blip and create dropoff blip
    if pickupBlip and DoesBlipExist(pickupBlip) then
        RemoveBlip(pickupBlip)
    end
    
    -- Create the dropoff blip
    dropoffBlip = AddBlipForCoord(CurrentContract.dropoff.coords)
    SetBlipSprite(dropoffBlip, CurrentContract.dropoff.blip.sprite)
    SetBlipColour(dropoffBlip, CurrentContract.dropoff.blip.color)
    SetBlipDisplay(dropoffBlip, 4)
    SetBlipScale(dropoffBlip, 0.8)
    SetBlipAsShortRange(dropoffBlip, false)
    SetBlipRoute(dropoffBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Dropoff: " .. CurrentContract.dropoff.label)
    EndTextCommandSetBlipName(dropoffBlip)
    
    table.insert(blips, dropoffBlip)
    
    -- Clean up any decoy packages
    CleanupDecoyPackages()
    
    -- Set contract state on server
    TriggerServerEvent('vein-blackmarket:server:packagePickedUp', CurrentContract.id)
    
    -- Create NPC watchers if enabled and contract difficulty is medium or hard
    if Config.NPCWatchers and (CurrentContract.difficulty == "medium" or CurrentContract.difficulty == "hard") then
        CreateNPCWatcher()
    end
end

-- Clean up decoy packages
function CleanupDecoyPackages()
    for _, decoy in ipairs(decoyPackages) do
        if DoesEntityExist(decoy) then
            DeleteEntity(decoy)
        end
    end
    
    decoyPackages = {}
end

-- Drop off the package
function DropoffPackage()
    if not hasPackage or not DoesEntityExist(packageObject) then return end
    
    local playerPed = PlayerPedId()
    
    -- Stop carrying animation
    ClearPedTasks(playerPed)
    DetachEntity(packageObject, true, true)
    DeleteEntity(packageObject)
    packageObject = nil
    hasPackage = false
    -- Notify other modules about package status
    TriggerEvent('vein-blackmarket:client:setHasPackage', false)
    
    -- Remove blip
    if dropoffBlip and DoesBlipExist(dropoffBlip) then
        RemoveBlip(dropoffBlip)
    end
    
    -- Remove NPC watcher if present
    RemoveNPCWatcher()
    
    -- Complete the contract
    CompleteContract()
end

-- Complete the contract and get paid
function CompleteContract()
    if not CurrentContract then return end
    
    -- Send completion to server for payment
    TriggerServerEvent('vein-blackmarket:server:completeContract', CurrentContract.id, heatLevel)
    
    -- Add completion message to phone
    local successMsg = {
        content = string.format(Locales['en']['contract_completed'], CurrentContract.payment),
        time = os.date("%H:%M"),
        sender = "them",
        decrypted = true
    }
    
    table.insert(contactList[2].messages, successMsg)
    
    if phoneOpen then
        SendNUIMessage({
            action = 'new_message',
            contactIndex = 2,
            message = successMsg
        })
    end
    
    -- Notification
    SendNotification(string.format(Locales['en']['contract_completed'], CurrentContract.payment), 'success', 5000)
    
    -- Clear contract data
    CurrentContract = nil
    
    -- Reset heat level
    heatLevel = 0
end

-- Create NPC watcher to follow player
function CreateNPCWatcher()
    if npcWatcher and DoesEntityExist(npcWatcher) then
        DeleteEntity(npcWatcher)
    end
    
    -- Select random NPC model
    local modelIndex = math.random(1, #Config.NPCWatcherModels)
    local watcherModel = Config.NPCWatcherModels[modelIndex]
    
    RequestModel(GetHashKey(watcherModel))
    while not HasModelLoaded(GetHashKey(watcherModel)) do
        Citizen.Wait(10)
    end
    
    -- Spawn watcher at a distance from player
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local spawnDistance = 40.0
    local angle = math.random() * 2 * math.pi
    
    local spawnX = playerCoords.x + spawnDistance * math.cos(angle)
    local spawnY = playerCoords.y + spawnDistance * math.sin(angle)
    local spawnZ = playerCoords.z
    
    -- Check for ground height
    local ground, groundZ = GetGroundZFor_3dCoord(spawnX, spawnY, 9999.0, 0)
    if ground then
        spawnZ = groundZ
    end
    
    -- Create watcher NPC
    npcWatcher = CreatePed(4, GetHashKey(watcherModel), spawnX, spawnY, spawnZ, 0.0, true, true)
    SetPedRandomComponentVariation(npcWatcher, 0)
    SetPedKeepTask(npcWatcher, true)
    SetPedAsEnemy(npcWatcher, false)
    SetBlockingOfNonTemporaryEvents(npcWatcher, true)
    SetPedCombatAttributes(npcWatcher, 17, true)
    
    -- Start following behavior
    Citizen.CreateThread(function()
        while npcWatcher and DoesEntityExist(npcWatcher) and CurrentContract do
            local playerPos = GetEntityCoords(PlayerPedId())
            local watcherPos = GetEntityCoords(npcWatcher)
            local distance = #(playerPos - watcherPos)
            
            -- If too far, teleport closer
            if distance > 100.0 then
                local spawnDistance = 50.0
                local angle = math.random() * 2 * math.pi
                
                local spawnX = playerPos.x + spawnDistance * math.cos(angle)
                local spawnY = playerPos.y + spawnDistance * math.sin(angle)
                local spawnZ = playerPos.z
                
                local ground, groundZ = GetGroundZFor_3dCoord(spawnX, spawnY, 9999.0, 0)
                if ground then
                    spawnZ = groundZ
                end
                
                SetEntityCoords(npcWatcher, spawnX, spawnY, spawnZ, false, false, false, false)
            end
            
            -- Follow behavior
            if distance > 15.0 and distance < 50.0 then
                TaskGoToEntity(npcWatcher, PlayerPedId(), -1, 10.0, 2.0, 0, 0)
            elseif distance <= 15.0 then
                ClearPedTasks(npcWatcher)
                TaskStandStill(npcWatcher, 5000)
                
                -- Sometimes make them use phone
                if math.random() < 0.3 then
                    TaskStartScenarioInPlace(npcWatcher, "WORLD_HUMAN_STAND_MOBILE", 0, true)
                end
            end
            
            -- Check if player is looking at watcher
            if IsPlayerFreeAiming(PlayerId()) then
                local entity = GetEntityPlayerIsFreeAimingAt(PlayerId())
                if entity == npcWatcher then
                    TaskSmartFleePed(npcWatcher, PlayerPedId(), 100.0, -1, false, false)
                    Citizen.Wait(5000)
                end
            end
            
            Citizen.Wait(3000)
        end
    end)
end

-- World Immersion: Random ambient events during delivery
function TriggerRandomAmbientEvent()
    local eventType = math.random(1, 4)
    
    if eventType == 1 and CurrentContract and CurrentContract.difficulty == "hard" then
        -- Police patrol car drives by
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local roadPosition = GetSafeCoordForPed(playerCoords.x + 40.0, playerCoords.y, playerCoords.z, false, 16)
        
        if roadPosition then
            local policeCar = CreateVehicle(GetHashKey("police"), roadPosition.x, roadPosition.y, roadPosition.z, 0.0, true, false)
            local driver = CreatePedInsideVehicle(policeCar, 6, GetHashKey("s_m_y_cop_01"), -1, true, false)
            
            TaskVehicleDriveToCoord(driver, policeCar, playerCoords.x - 60.0, playerCoords.y, playerCoords.z, 17.0, 0, GetEntityModel(policeCar), 786603, 5.0, 1.0)
            
            -- Delete after some time
            Citizen.SetTimeout(30000, function()
                if DoesEntityExist(policeCar) then
                    DeletePed(driver)
                    DeleteVehicle(policeCar)
                end
            end)
        end
    elseif eventType == 2 then
        -- Suspicious NPC watching
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local spawnDistance = 20.0
        local angle = math.random() * 2 * math.pi
        
        local spawnX = playerCoords.x + spawnDistance * math.cos(angle)
        local spawnY = playerCoords.y + spawnDistance * math.sin(angle)
        local spawnZ = playerCoords.z
        
        local ground, groundZ = GetGroundZFor_3dCoord(spawnX, spawnY, 9999.0, 0)
        if ground then
            spawnZ = groundZ
        end
        
        local suspiciousNPC = CreatePed(4, GetHashKey("a_m_y_business_03"), spawnX, spawnY, spawnZ, 0.0, true, true)
        
        TaskTurnPedToFaceEntity(suspiciousNPC, playerPed, 5000)
        TaskStartScenarioInPlace(suspiciousNPC, "WORLD_HUMAN_STAND_MOBILE", 0, true)
        
        -- Delete after some time
        Citizen.SetTimeout(15000, function()
            if DoesEntityExist(suspiciousNPC) then
                TaskSmartFleePed(suspiciousNPC, playerPed, 100.0, -1, false, false)
                
                Citizen.SetTimeout(10000, function()
                    DeletePed(suspiciousNPC)
                end)
            end
        end)
    elseif eventType == 3 and CurrentContract and CurrentContract.difficulty == "hard" then
        -- Police helicopter flyby (distant)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        local heliCoords = vector3(
            playerCoords.x + math.random(-200, 200),
            playerCoords.y + math.random(-200, 200),
            playerCoords.z + 50.0
        )
        
        local heli = CreateVehicle(GetHashKey("polmav"), heliCoords.x, heliCoords.y, heliCoords.z, 0.0, true, false)
        local pilot = CreatePedInsideVehicle(heli, 6, GetHashKey("s_m_y_pilot_01"), -1, true, false)
        SetHeliBladesFullSpeed(heli)
        
        local destination = vector3(
            playerCoords.x + math.random(-200, 200),
            playerCoords.y + math.random(-200, 200),
            playerCoords.z + 50.0
        )
        
        TaskHeliMission(pilot, heli, 0, 0, destination.x, destination.y, destination.z, 4, 25.0, 10.0, -1.0, 10, 10, -1.0, 0)
        
        -- Delete after some time
        Citizen.SetTimeout(45000, function()
            if DoesEntityExist(heli) then
                DeletePed(pilot)
                DeleteVehicle(heli)
            end
        end)
    elseif eventType == 4 and math.random() < 0.3 then
        -- Radio chatter notification
        local messages = {
            "We have reports of suspicious activity near " .. GetStreetNameFromHashKey(GetStreetNameAtCoord(GetEntityCoords(PlayerPedId()))),
            "All units be advised, possible illegal transaction in progress in the area",
            "Witness reported an individual carrying a suspicious package",
            "Keep an eye out for a courier in your district"
        }
        
        local message = messages[math.random(1, #messages)]
        SendNotification(message, 'error', 5000)
        PlaySoundFrontend(-1, "Beep_Red", "DLC_HEIST_HACKING_SNAKE_SOUNDS", 1)
    end
end

-- Trigger random ambient events during active contracts
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(30000) -- Check every 30 seconds
        
        if CurrentContract and hasPackage then
            -- 40% chance to trigger event
            if math.random() < 0.4 then
                TriggerRandomAmbientEvent()
            end
        end
    end
end) 