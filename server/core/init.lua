-- Server Core Initialisierung
-- Lädt und initialisiert alle Server-seitigen Systeme

local QBCore = exports['qb-core']:GetCoreObject()

-- Global verfügbare Server-Objekte
_G.QBCore = QBCore

-- Warte bis alle Systeme bereit sind
CreateThread(function()
    -- Warte auf QBCore
    while not QBCore do
        Wait(100)
        QBCore = exports['qb-core']:GetCoreObject()
    end
    
    -- Warte auf MySQL Resource
    while GetResourceState('oxmysql') ~= 'started' do
        Wait(100)
    end
    
    print("^2[SPRAY SYSTEM] Server core systems initialized^0")
end)

print("^3[SPRAY SYSTEM] Server core loading...^0")