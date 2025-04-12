-- Police awareness system
local heatNotify = {
    [25] = false,
    [50] = false,
    [75] = false,
    [90] = false
}
local policeAlerted = false
local policeCopsCount = 0
local heatUI = nil
local lastVehicleDamageTime = 0

-- Initialize heat tracking system
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        
        if Config.PoliceAwarenessEnabled and CurrentContract and hasPackage then
            -- Track heat level during active delivery
            ManageHeatLevel()
            
            -- Check for cops to alert
            if heatLevel >= Config.PoliceAlertThreshold and not policeAlerted then
                AlertPolice()
            end
            
            -- Heat decay
            if heatLevel > 0 then
                heatLevel = math.max(0, heatLevel - Config.HeatDecayRate)
            end
            
            -- Reset notification flags if heat drops
            if heatLevel < 25 then
                heatNotify[25] = false
                heatNotify[50] = false
                heatNotify[75] = false
                heatNotify[90] = false
            elseif heatLevel < 50 then
                heatNotify[50] = false
                heatNotify[75] = false
                heatNotify[90] = false
            elseif heatLevel < 75 then
                heatNotify[75] = false
                heatNotify[90] = false
            elseif heatLevel < 90 then
                heatNotify[90] = false
            end
        elseif heatLevel > 0 then
            -- Reset heat when no active contract
            heatLevel = 0
            ResetHeatSystem()
        end
    end
end)

-- Handle heat level calculation
function ManageHeatLevel()
    local playerPed = PlayerPedId()
    
    -- Check if player is in a vehicle
    if IsPedInAnyVehicle(playerPed, false) then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        
        -- Speed check
        local speed = GetEntitySpeed(vehicle) * 3.6 -- Convert to km/h
        if speed > Config.HeatTriggers.speedingThreshold then
            local speedExcess = speed - Config.HeatTriggers.speedingThreshold
            local heatToAdd = math.min(10, speedExcess / 10)
            AddHeat(heatToAdd)
        end
        
        -- Dangerous driving check
        if HasEntityCollidedWithAnything(vehicle) then
            AddHeat(Config.HeatTriggers.dangerousDriving)
        end
        
        -- Vehicle damage check
        local currentHealth = GetVehicleBodyHealth(vehicle)
        if vehicleHealth == nil then
            vehicleHealth = currentHealth
        elseif currentHealth < vehicleHealth - 10 and GetGameTimer() - lastVehicleDamageTime > 1000 then
            AddHeat(Config.HeatTriggers.vehicleDamage)
            lastVehicleDamageTime = GetGameTimer()
            vehicleHealth = currentHealth
        end
        
        -- Stationary check (reset if moving)
        lastPosition = GetEntityCoords(playerPed)
        stationaryTime = 0
    else
        -- On foot checks
        local currentPos = GetEntityCoords(playerPed)
        
        -- Weapon drawn check
        if IsPedArmed(playerPed, 4) then -- 4 = armed with gun
            AddHeat(Config.HeatTriggers.weaponDrawn * 0.2) -- Slower increase per second
        end
        
        -- Stationary time check
        if lastPosition then
            if #(currentPos - lastPosition) < 1.0 then
                stationaryTime = stationaryTime + 1
                
                -- Add heat if stationary for too long in non-interior area
                if stationaryTime > 15 and not GetIsMapRegionHighlighted() then
                    AddHeat(Config.HeatTriggers.prolongedStop * 0.2) -- Slower increase
                end
            else
                stationaryTime = 0
                lastPosition = currentPos
            end
        else
            lastPosition = currentPos
        end
    end
    
    -- Check for nearby police
    local nearbyPolice = false
    local policeVehicles = GetGamePool('CVehicle')
    
    for _, vehicle in ipairs(policeVehicles) do
        local model = GetEntityModel(vehicle)
        if IsVehicleModelAPoliceVehicle(model) then
            local coords = GetEntityCoords(vehicle)
            local playerCoords = GetEntityCoords(playerPed)
            
            if #(coords - playerCoords) < 50.0 then
                nearbyPolice = true
                break
            end
        end
    end
    
    if nearbyPolice then
        AddHeat(2.0) -- Add heat when near police
    end
    
    -- Show heat level on screen
    if heatLevel > 20 then
        DrawHeatUI()
    else
        HideHeatUI()
    end
end

-- Add heat and notify player at thresholds
function AddHeat(amount)
    if not amount or amount <= 0 then return end
    
    local oldHeat = heatLevel
    heatLevel = math.min(Config.MaxHeatLevel, heatLevel + amount)
    
    -- Notify at thresholds
    if oldHeat < 25 and heatLevel >= 25 and not heatNotify[25] then
        heatNotify[25] = true
        SendNotification(Locales['en']['heat_increasing'], 'warning', 3500)
    elseif oldHeat < 50 and heatLevel >= 50 and not heatNotify[50] then
        heatNotify[50] = true
        SendNotification(Locales['en']['heat_increasing'] .. " - " .. Locales['en']['suspicious_activity'], 'warning', 3500)
    elseif oldHeat < 75 and heatLevel >= 75 and not heatNotify[75] then
        heatNotify[75] = true
        SendNotification(Locales['en']['police_alert'], 'error', 3500)
    elseif oldHeat < 90 and heatLevel >= 90 and not heatNotify[90] then
        heatNotify[90] = true
        SendNotification("Police are actively searching for you!", 'error', 5000)
    end
end

-- Reset the heat system
function ResetHeatSystem()
    heatLevel = 0
    policeAlerted = false
    heatNotify = {
        [25] = false,
        [50] = false,
        [75] = false,
        [90] = false
    }
    HideHeatUI()
end

-- Alert police when heat is too high
function AlertPolice()
    if not Config.PoliceAwarenessEnabled or policeAlerted then return end
    
    -- Check if enough police are online
    TriggerServerEvent('police:server:GetCopCount', function(CopCount)
        policeCopsCount = CopCount
        
        if policeCopsCount >= Config.RequiredCops then
            policeAlerted = true
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            
            -- Send alert to police
            TriggerServerEvent('police:server:PoliceAlert', 'Suspicious package delivery in progress')
            
            -- Create a police blip in the area (approximate location, not exact)
            local offsetX = math.random(-100, 100)
            local offsetY = math.random(-100, 100)
            local blipCoords = vector3(playerCoords.x + offsetX, playerCoords.y + offsetY, playerCoords.z)
            
            TriggerServerEvent('vein-blackmarket:server:createPoliceBlip', blipCoords)
            
            -- Reset alert after 2 minutes
            Citizen.SetTimeout(120000, function()
                policeAlerted = false
            end)
        end
    end)
end

-- Draw heat UI on screen
function DrawHeatUI()
    if not Config.PoliceAwarenessEnabled or not CurrentContract or not hasPackage then return end
    
    -- Calculate heat color (green to red)
    local r, g, b = 0, 255, 0 -- Start with green
    
    if heatLevel > 50 then
        -- Transition from green to red
        local factor = (heatLevel - 50) / 50
        g = 255 * (1 - factor)
        r = 255 * factor
    end
    
    -- Draw HUD element
    DrawRect(0.93, 0.15, 0.07, 0.03, 0, 0, 0, 150)
    DrawRect(0.93, 0.15, 0.065 * (heatLevel / 100), 0.02, r, g, b, 200)
    
    SetTextFont(0)
    SetTextScale(0.3, 0.3)
    SetTextColour(255, 255, 255, 255)
    SetTextCentre(true)
    SetTextEntry("STRING")
    AddTextComponentString("HEAT: " .. math.floor(heatLevel) .. "%")
    DrawText(0.93, 0.142)
end

-- Hide heat UI
function HideHeatUI()
    -- Simply stop drawing the UI
end

-- Create police blip (triggered from server)
RegisterNetEvent('vein-blackmarket:client:createPoliceBlip')
AddEventHandler('vein-blackmarket:client:createPoliceBlip', function(coords)
    local alpha = 250
    local suspiciousBlip = AddBlipForRadius(coords.x, coords.y, coords.z, 100.0)
    
    SetBlipHighDetail(suspiciousBlip, true)
    SetBlipColour(suspiciousBlip, 1) -- Red
    SetBlipAlpha(suspiciousBlip, alpha)
    SetBlipDisplay(suspiciousBlip, 4)
    
    -- Create a central marker
    local centralBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(centralBlip, 161) -- Area outline
    SetBlipColour(centralBlip, 1) -- Red
    SetBlipDisplay(centralBlip, 4)
    SetBlipScale(centralBlip, 1.0)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Suspicious Activity")
    EndTextCommandSetBlipName(centralBlip)
    
    -- Fade out blip gradually
    Citizen.CreateThread(function()
        while alpha > 0 do
            Citizen.Wait(300)
            alpha = alpha - 1
            SetBlipAlpha(suspiciousBlip, alpha)
            
            if alpha == 0 then
                RemoveBlip(suspiciousBlip)
                Citizen.Wait(60000) -- 1 minute before removing central blip
                RemoveBlip(centralBlip)
                return
            end
        end
    end)
end) 