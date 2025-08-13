-- ✅ GEFIXT: Spray Items Handler - Item System Integration
-- Datei: server/items/spray_items.lua

local QBCore = exports['qb-core']:GetCoreObject()

-- ✅ FIX: Spray Can Item Handler
QBCore.Functions.CreateUseableItem("spray_can", function(source, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        Debug:Log("ITEMS", "Invalid player for spray_can use", {source = src}, "ERROR")
        return
    end
    
    -- ✅ FIX: Check if player has the item
    local sprayCanItem = Player.Functions.GetItemBySlot(item.slot)
    if not sprayCanItem or sprayCanItem.name ~= "spray_can" then
        TriggerClientEvent('QBCore:Notify', src, 'Du hast keine Spray-Dose', 'error')
        return
    end
    
    -- ✅ FIX: Determine spray type from item info
    local sprayType = "public" -- Default
    local gangAccess = nil
    local metadata = {}
    
    if sprayCanItem.info then
        sprayType = sprayCanItem.info.sprayType or "public"
        gangAccess = sprayCanItem.info.gang or nil
        metadata = sprayCanItem.info.metadata or {}
    end
    
    -- ✅ FIX: Access Data für Client
    local accessData = {
        sprayType = sprayType,
        gang = gangAccess,
        itemSlot = item.slot,
        itemInfo = sprayCanItem.info or {},
        metadata = metadata,
        quality = sprayCanItem.info and sprayCanItem.info.quality or 100
    }
    
    -- ✅ FIX: Validation für Gang-Items
    if sprayType == "gang" then
        local playerGang = Player.PlayerData.gang and Player.PlayerData.gang.name
        
        if not playerGang then
            TriggerClientEvent('QBCore:Notify', src, 'Du bist in keiner Gang', 'error')
            return
        end
        
        if gangAccess and gangAccess ~= playerGang then
            TriggerClientEvent('QBCore:Notify', src, 'Diese Spray-Dose gehört einer anderen Gang', 'error')
            return
        end
        
        -- Update access data mit aktueller Gang info
        accessData.gang = playerGang
        accessData.gangGrade = Player.PlayerData.gang.grade.level or 0
    end
    
    -- ✅ FIX: Open Spray Menu mit Access Data
    TriggerClientEvent('spray:client:openMenu', src, accessData)
    
    Debug:Log("ITEMS", "Spray can used successfully", {
        citizenid = Player.PlayerData.citizenid,
        sprayType = sprayType,
        gang = accessData.gang,
        quality = accessData.quality
    }, "SUCCESS")
end)

-- ✅ FIX: Spray Remover Item Handler
QBCore.Functions.CreateUseableItem("spray_remover", function(source, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        Debug:Log("ITEMS", "Invalid player for spray_remover use", {source = src}, "ERROR")
        return
    end
    
    -- ✅ FIX: Check if player has the item
    local removerItem = Player.Functions.GetItemBySlot(item.slot)
    if not removerItem or removerItem.name ~= "spray_remover" then
        TriggerClientEvent('QBCore:Notify', src, 'Du hast keinen Spray-Entferner', 'error')
        return
    end
    
    -- ✅ FIX: Check uses remaining
    local usesRemaining = removerItem.info and removerItem.info.uses or Config.Items.removeSprayUses or 10
    
    if usesRemaining <= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Spray-Entferner ist leer', 'error')
        return
    end
    
    -- ✅ FIX: Access Data für Remover
    local removerData = {
        itemSlot = item.slot,
        usesRemaining = usesRemaining,
        range = removerItem.info and removerItem.info.range or 5.0,
        quality = removerItem.info and removerItem.info.quality or 100
    }
    
    -- ✅ FIX: Start Removal Mode
    TriggerClientEvent('spray:client:startRemovalMode', src, removerData)
    
    Debug:Log("ITEMS", "Spray remover used", {
        citizenid = Player.PlayerData.citizenid,
        usesRemaining = usesRemaining,
        quality = removerData.quality
    }, "SUCCESS")
end)

-- ✅ FIX: Server Events für Item Consumption
RegisterNetEvent('spray:server:consumeSprayCanUse', function(itemSlot)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local sprayCanItem = Player.Functions.GetItemBySlot(itemSlot)
    if not sprayCanItem or sprayCanItem.name ~= "spray_can" then
        return
    end
    
    -- ✅ FIX: Uses System für Spray Can
    local currentUses = sprayCanItem.info and sprayCanItem.info.uses or Config.Items.sprayCanUses or 20
    
    if currentUses <= 1 then
        -- ✅ FIX: Item komplett entfernen
        Player.Functions.RemoveItem("spray_can", 1, itemSlot)
        TriggerClientEvent('QBCore:Notify', src, 'Spray-Dose ist leer und wurde entfernt', 'info')
        
        Debug:Log("ITEMS", "Spray can depleted and removed", {
            citizenid = Player.PlayerData.citizenid,
            slot = itemSlot
        }, "INFO")
    else
        -- ✅ FIX: Uses reduzieren
        local newInfo = sprayCanItem.info or {}
        newInfo.uses = currentUses - 1
        
        -- ✅ FIX: Qualitätsverlust
        if Config.Items.qualityLossPerUse and Config.Items.qualityLossPerUse > 0 then
            newInfo.quality = math.max(
                (newInfo.quality or Config.Items.defaultQuality or 100) - Config.Items.qualityLossPerUse,
                0
            )
        end
        
        Player.Functions.RemoveItem("spray_can", 1, itemSlot)
        Player.Functions.AddItem("spray_can", 1, itemSlot, newInfo)
        
        TriggerClientEvent('QBCore:Notify', src, string.format('Spray-Dose: %d Verwendungen übrig', newInfo.uses), 'info')
        
        Debug:Log("ITEMS", "Spray can use consumed", {
            citizenid = Player.PlayerData.citizenid,
            usesRemaining = newInfo.uses,
            quality = newInfo.quality
        }, "INFO")
    end
end)

RegisterNetEvent('spray:server:consumeSprayRemoverUse', function(itemSlot)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local removerItem = Player.Functions.GetItemBySlot(itemSlot)
    if not removerItem or removerItem.name ~= "spray_remover" then
        return
    end
    
    -- ✅ FIX: Uses System für Spray Remover
    local currentUses = removerItem.info and removerItem.info.uses or Config.Items.removeSprayUses or 10
    
    if currentUses <= 1 then
        -- ✅ FIX: Item komplett entfernen
        Player.Functions.RemoveItem("spray_remover", 1, itemSlot)
        TriggerClientEvent('QBCore:Notify', src, 'Spray-Entferner ist leer und wurde entfernt', 'info')
        
        Debug:Log("ITEMS", "Spray remover depleted and removed", {
            citizenid = Player.PlayerData.citizenid,
            slot = itemSlot
        }, "INFO")
    else
        -- ✅ FIX: Uses reduzieren
        local newInfo = removerItem.info or {}
        newInfo.uses = currentUses - 1
        
        -- ✅ FIX: Qualitätsverlust
        if Config.Items.qualityLossPerUse and Config.Items.qualityLossPerUse > 0 then
            newInfo.quality = math.max(
                (newInfo.quality or Config.Items.defaultQuality or 100) - Config.Items.qualityLossPerUse,
                0
            )
        end
        
        Player.Functions.RemoveItem("spray_remover", 1, itemSlot)
        Player.Functions.AddItem("spray_remover", 1, itemSlot, newInfo)
        
        TriggerClientEvent('QBCore:Notify', src, string.format('Spray-Entferner: %d Verwendungen übrig', newInfo.uses), 'info')
        
        Debug:Log("ITEMS", "Spray remover use consumed", {
            citizenid = Player.PlayerData.citizenid,
            usesRemaining = newInfo.uses,
            quality = newInfo.quality
        }, "INFO")
    end
end)

-- ✅ FIX: Item Creation Helper Functions
function CreateSprayCanItem(citizenid, sprayType, gang, uses, quality)
    local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if not Player then return false end
    
    local itemInfo = {
        sprayType = sprayType or "public",
        gang = gang,
        uses = uses or Config.Items.sprayCanUses or 20,
        quality = quality or Config.Items.defaultQuality or 100,
        metadata = {
            createdAt = os.time(),
            createdBy = citizenid
        }
    }
    
    local success = Player.Functions.AddItem("spray_can", 1, nil, itemInfo)
    
    if success then
        Debug:Log("ITEMS", "Spray can created", {
            citizenid = citizenid,
            sprayType = sprayType,
            gang = gang,
            uses = uses
        }, "SUCCESS")
    end
    
    return success
end

function CreateSprayRemoverItem(citizenid, uses, quality)
    local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if not Player then return false end
    
    local itemInfo = {
        uses = uses or Config.Items.removeSprayUses or 10,
        quality = quality or Config.Items.defaultQuality or 100,
        range = 5.0,
        metadata = {
            createdAt = os.time(),
            createdBy = citizenid
        }
    }
    
    local success = Player.Functions.AddItem("spray_remover", 1, nil, itemInfo)
    
    if success then
        Debug:Log("ITEMS", "Spray remover created", {
            citizenid = citizenid,
            uses = uses,
            quality = quality
        }, "SUCCESS")
    end
    
    return success
end

-- ✅ FIX: Admin Commands für Item Creation
QBCore.Commands.Add("givespraycan", "Give spray can to player", {{name = "id", help = "Player ID"}, {name = "type", help = "public/gang"}, {name = "gang", help = "Gang name (optional)"}}, true, function(source, args)
    local targetId = tonumber(args[1])
    local sprayType = args[2] or "public"
    local gang = args[3]
    
    if not targetId then
        TriggerClientEvent('QBCore:Notify', source, 'Ungültige Player ID', 'error')
        return
    end
    
    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('QBCore:Notify', source, 'Spieler nicht gefunden', 'error')
        return
    end
    
    local success = CreateSprayCanItem(targetPlayer.PlayerData.citizenid, sprayType, gang)
    
    if success then
        TriggerClientEvent('QBCore:Notify', source, string.format('Spray-Dose an %s gegeben', targetPlayer.PlayerData.name), 'success')
        TriggerClientEvent('QBCore:Notify', targetId, 'Du hast eine Spray-Dose erhalten', 'success')
    else
        TriggerClientEvent('QBCore:Notify', source, 'Fehler beim Erstellen der Spray-Dose', 'error')
    end
end, "admin")

QBCore.Commands.Add("givesprayremover", "Give spray remover to player", {{name = "id", help = "Player ID"}}, true, function(source, args)
    local targetId = tonumber(args[1])
    
    if not targetId then
        TriggerClientEvent('QBCore:Notify', source, 'Ungültige Player ID', 'error')
        return
    end
    
    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('QBCore:Notify', source, 'Spieler nicht gefunden', 'error')
        return
    end
    
    local success = CreateSprayRemoverItem(targetPlayer.PlayerData.citizenid)
    
    if success then
        TriggerClientEvent('QBCore:Notify', source, string.format('Spray-Entferner an %s gegeben', targetPlayer.PlayerData.name), 'success')
        TriggerClientEvent('QBCore:Notify', targetId, 'Du hast einen Spray-Entferner erhalten', 'success')
    else
        TriggerClientEvent('QBCore:Notify', source, 'Fehler beim Erstellen des Spray-Entferners', 'error')
    end
end, "admin")

-- ✅ FIX: Export Functions für andere Scripts
exports('CreateSprayCanItem', CreateSprayCanItem)
exports('CreateSprayRemoverItem', CreateSprayRemoverItem)

Debug:Log("ITEMS", "Spray items system loaded", nil, "SUCCESS")