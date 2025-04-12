-- Utility Functions

-- Generate a random ID
function GenerateRandomID(length)
    local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    math.randomseed(GetGameTimer())
    local result = ""
    
    for i = 1, length do
        local rand = math.random(1, #charset)
        result = result .. string.sub(charset, rand, rand)
    end
    
    return result
end

-- Check if a vehicle is a police vehicle
function IsVehicleModelAPoliceVehicle(model)
    local policeModels = {
        `police`,
        `police2`,
        `police3`,
        `police4`,
        `policeb`,
        `policet`,
        `sheriff`,
        `sheriff2`,
        `fbi`,
        `fbi2`
    }
    
    for _, policeModel in ipairs(policeModels) do
        if policeModel == model then
            return true
        end
    end
    
    return false
end

-- Get safe coordinate for a ped (for spawning)
function GetSafeCoordForPed(x, y, z, onGround, flags)
    local safeCoords = vector3(x, y, z)
    local outPosition = vector3(0.0, 0.0, 0.0)
    local success = false
    
    for i = 1, 5 do
        success = GetSafeCoordForPed(safeCoords.x, safeCoords.y, safeCoords.z, onGround, outPosition, flags)
        
        if success then
            return outPosition
        else
            safeCoords = vector3(safeCoords.x + math.random(-20, 20), safeCoords.y + math.random(-20, 20), safeCoords.z)
        end
    end
    
    return nil
end

-- Format time to display
function FormatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = seconds % 60
    
    if minutes < 10 then
        minutes = "0" .. minutes
    end
    
    if remainingSeconds < 10 then
        remainingSeconds = "0" .. remainingSeconds
    end
    
    return minutes .. ":" .. remainingSeconds
end

-- Debug logging
function DebugLog(message)
    if Config.Debug then
        print("[vein-blackmarket] " .. message)
    end
end

-- RGB color transition 
function LerpColor(color1, color2, t)
    local r = Lerp(color1.r, color2.r, t)
    local g = Lerp(color1.g, color2.g, t)
    local b = Lerp(color1.b, color2.b, t)
    return {r = r, g = g, b = b}
end

-- Linear interpolation helper
function Lerp(a, b, t)
    return a + (b - a) * t
end

-- Create scrambled text for encrypted messages
function CreateScrambledText(length)
    local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+{}|:<>?-=[]\\;',./`~"
    local result = ""
    
    for i = 1, length do
        local rand = math.random(1, #charset)
        result = result .. string.sub(charset, rand, rand)
    end
    
    return result
end

-- Request and load a model
function LoadModel(model)
    if type(model) == 'string' then model = GetHashKey(model) end
    
    RequestModel(model)
    
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 100 do
        Citizen.Wait(100)
        timeout = timeout + 1
    end
    
    return HasModelLoaded(model)
end

-- Request and load animation dictionary
function LoadAnimDict(dict)
    RequestAnimDict(dict)
    
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 100 do
        Citizen.Wait(100)
        timeout = timeout + 1
    end
    
    return HasAnimDictLoaded(dict)
end

-- Calculate distance between two coordinates
function GetDistance(x1, y1, z1, x2, y2, z2)
    return #(vector3(x1, y1, z1) - vector3(x2, y2, z2))
end

-- Get player's heading direction as a unit vector
function GetHeadingDirection(heading)
    local headingRad = math.rad(heading)
    return vector3(-math.sin(headingRad), math.cos(headingRad), 0.0)
end

-- Get random position in radius around coords
function GetRandomPositionInRadius(coords, radius)
    local angle = math.random() * 2 * math.pi
    local r = radius * math.sqrt(math.random())
    
    local x = coords.x + r * math.cos(angle)
    local y = coords.y + r * math.sin(angle)
    
    return vector3(x, y, coords.z)
end 