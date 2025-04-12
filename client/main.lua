local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local CurrentContract = nil
local ActiveContracts = {}
local isLoggedIn = false
local hasPhone = false
local phoneOpen = false
local blips = {}
local heatLevel = 0
local lastPosition = nil
local stationaryTime = 0
local vehicleHealth = nil
local npcWatcher = nil

-- Initialize the resource
Citizen.CreateThread(function()
    while QBCore == nil do
        TriggerEvent('QBCore:GetObject', function(obj) QBCore = obj end)
        Citizen.Wait(0)
    end

    while QBCore.Functions.GetPlayerData() == nil do
        Citizen.Wait(10)
    end

    PlayerData = QBCore.Functions.GetPlayerData()
    isLoggedIn = true
    CheckBurnerPhone()
    
    -- Create dealer blip
    local dealerCoords = vector3(412.35, -1487.52, 30.15) -- Example dealer location
    local dealerBlip = AddBlipForCoord(dealerCoords)
    SetBlipSprite(dealerBlip, 766)
    SetBlipDisplay(dealerBlip, 4)
    SetBlipScale(dealerBlip, 0.7)
    SetBlipColour(dealerBlip, 1)
    SetBlipAsShortRange(dealerBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Burner Phone Dealer")
    EndTextCommandSetBlipName(dealerBlip)
end)

-- Check for updates to player data
RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    isLoggedIn = true
    CheckBurnerPhone()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload')
AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    isLoggedIn = false
    PlayerData = {}
    ClearAllBlips()
    CurrentContract = nil
    ActiveContracts = {}
    heatLevel = 0
    RemoveNPCWatcher()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData')
AddEventHandler('QBCore:Player:SetPlayerData', function(data)
    PlayerData = data
    CheckBurnerPhone()
end)

-- Checking if player has a burner phone
function CheckBurnerPhone()
    local burnerPhone = Config.BurnerPhoneItem
    hasPhone = false
    
    if PlayerData and PlayerData.items then
        for _, item in pairs(PlayerData.items) do
            if item.name == burnerPhone then
                hasPhone = true
                break
            end
        end
    end
    
    if not hasPhone and phoneOpen then
        ClosePhone()
    end
end

RegisterNetEvent('inventory:client:ItemBox')
AddEventHandler('inventory:client:ItemBox', function(data, type)
    if data and data.name == Config.BurnerPhoneItem then
        if type == "add" then
            hasPhone = true
        elseif type == "remove" then
            hasPhone = false
            if phoneOpen then
                ClosePhone()
            end
        end
    end
end)

-- Dealer NPC for buying burner phones
Citizen.CreateThread(function()
    local dealerCoords = vector3(412.35, -1487.52, 30.15) -- Example dealer location
    local dealerModel = "s_m_y_dealer_01"
    
    RequestModel(GetHashKey(dealerModel))
    while not HasModelLoaded(GetHashKey(dealerModel)) do
        Citizen.Wait(1)
    end
    
    -- Create dealer ped
    local dealer = CreatePed(4, GetHashKey(dealerModel), dealerCoords.x, dealerCoords.y, dealerCoords.z, 189.0, false, true)
    FreezeEntityPosition(dealer, true)
    SetEntityInvincible(dealer, true)
    SetBlockingOfNonTemporaryEvents(dealer, true)
    
    while true do
        Citizen.Wait(0)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local dist = #(playerCoords - dealerCoords)
        
        if dist < 2.0 then
            DrawText3D(dealerCoords.x, dealerCoords.y, dealerCoords.z + 1.0, Locales['en']['buy_burner'])
            
            if IsControlJustReleased(0, 38) then -- E key
                TriggerServerEvent('vein-blackmarket:server:buyBurnerPhone')
            end
        end
    end
end)

-- Helper Functions
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)
    local factor = (string.len(text)) / 370
    DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
end

function ClearAllBlips()
    for _, blip in pairs(blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    blips = {}
end

function RemoveNPCWatcher()
    if npcWatcher and DoesEntityExist(npcWatcher) then
        DeleteEntity(npcWatcher)
        npcWatcher = nil
    end
end

-- Main key controls
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if isLoggedIn and hasPhone then
            if IsControlJustReleased(0, 288) then -- F1 key
                TogglePhone()
            end
        end
    end
end)

-- Debug Command
RegisterCommand('blackmarket_debug', function()
    if Config.Debug then
        print('Player Data:', json.encode(PlayerData))
        print('Has Phone:', hasPhone)
        print('Phone Open:', phoneOpen)
        print('Current Contract:', json.encode(CurrentContract))
        print('Active Contracts:', json.encode(ActiveContracts))
        print('Heat Level:', heatLevel)
    end
end) 