-- Server-seitige Spray-System Hauptlogik
-- Koordiniert alle Spray-Operationen zwischen Client, Database und Permission System
-- ✅ ERWEITERT: Item-Handler + Public Spray Support + Entferner-System

local QBCore = exports['qb-core']:GetCoreObject()

SpraySystem = SpraySystem or {
    activeSprays = {},                -- Cache aller aktiven Sprays
    spamProtection = {},              -- Anti-Spam Protection
    statistics = {
        totalSprays = 0,
        spraysByGang = {},
        publicSprays = 0,             -- ✅ NEU: Public Spray Counter
        dailyCreations = 0,
        dailyRemovals = 0,
        itemRemovals = 0              -- ✅ NEU: Item-basierte Entfernungen
    },
    syncedClients = {}                -- Clients die Spray-Daten erhalten haben
}

-- Initialisierung des Server-Systems
function SpraySystem:Initialize()
    Debug:StartProfile("SpraySystem_Initialize", "SPRAY_SERVER")
    
    -- Lade existierende Sprays aus Database
    self:LoadSprayDatabase()
    
    -- ✅ NEU: Registriere Item-Handler
    self:RegisterItemHandlers()
    
    -- Starte Cleanup-Timer
    self:StartCleanupTimer()
    
    -- Starte Sync-Timer für Clients
    self:StartClientSyncTimer()
    
    Debug:Log("SPRAY_SERVER", "Spray system server initialized", {
        totalSprays = #self.activeSprays
    }, "SUCCESS")
    
    Debug:EndProfile("SpraySystem_Initialize")
end

-- ✅ NEU: Item-Handler Registrierung
function SpraySystem:RegisterItemHandlers()
    Debug:Log("SPRAY_SERVER", "Registering item handlers", nil, "INFO")
    
    -- ✅ Spray Can Item Handler
    QBCore.Functions.CreateUseableItem(Config.Items.sprayCanItem, function(source, item)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return end
        
        Debug:Log("SPRAY_SERVER", "Spray can item used", {
            citizenid = Player.PlayerData.citizenid,
            itemSlot = item.slot,
            uses = item.info and item.info.uses or "unknown"
        }, "INFO")
        
        -- Item Checks
        if not item or item.amount < 1 then
            TriggerClientEvent('QBCore:Notify', source, 'Keine Spray-Dose vorhanden', 'error')
            return
        end
        
        -- Permission Pre-Check
        local canSpray, reason, metadata = GangPermissions:CanUseSpray(source)
        if not canSpray then
            TriggerClientEvent('QBCore:Notify', source, reason, 'error')
            return
        end
        
        -- Aktiviere Spray-Menü
        TriggerClientEvent('spray:client:openSprayMenu', source, metadata)
        
        -- Zusätzliche Benachrichtigung für bessere UX
        local sprayType = metadata.sprayType or "unknown"
        local accessMessage = sprayType == "public" and "Öffentliches Spray-Menü geöffnet" or "Gang Spray-Menü geöffnet"
        
        TriggerClientEvent('QBCore:Notify', source, accessMessage, 'info')
    end)
    
    -- ✅ Spray Remover Item Handler
    QBCore.Functions.CreateUseableItem(Config.Items.sprayRemoverItem, function(source, item)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return end
        
        Debug:Log("SPRAY_SERVER", "Spray remover item used", {
            citizenid = Player.PlayerData.citizenid,
            itemSlot = item.slot,
            uses = item.info and item.info.uses or "unknown"
        }, "INFO")
        
        -- Item Checks
        if not item or item.amount < 1 then
            TriggerClientEvent('QBCore:Notify', source, 'Kein Graffiti-Entferner vorhanden', 'error')
            return
        end
        
        -- Permission Check für Entferner
        local removerCheck = GangPermissions:ValidateSprayRemoverItem(Player)
        if not removerCheck.valid then
            TriggerClientEvent('QBCore:Notify', source, removerCheck.reason, 'error')
            return
        end
        
        -- Aktiviere Entferner-Modus
        TriggerClientEvent('spray:client:activateRemovalMode', source, removerCheck.metadata)
        
        TriggerClientEvent('QBCore:Notify', source, 'Graffiti-Entferner aktiviert - Ziele auf ein Spray', 'info')
    end)
    
    Debug:Log("SPRAY_SERVER", "Item handlers registered successfully", nil, "SUCCESS")
end

-- Lade alle Sprays aus der Database
function SpraySystem:LoadSprayDatabase()
    Debug:StartProfile("SpraySystem_LoadSprayDatabase", "DATABASE")
    
    exports.oxmysql:execute('SELECT * FROM gang_sprays WHERE expires_at IS NULL OR expires_at > NOW()', {}, function(result)
        if result then
            for _, sprayData in ipairs(result) do
                -- Konvertiere JSON-Felder
                if sprayData.position then
                    sprayData.position = json.decode(sprayData.position)
                end
                
                if sprayData.metadata then
                    sprayData.metadata = json.decode(sprayData.metadata)
                end
                
                -- Füge zu aktivem Cache hinzu
                self.activeSprays[sprayData.spray_id] = sprayData
                
                -- ✅ Update Statistiken mit Public Support
                self.statistics.totalSprays = self.statistics.totalSprays + 1
                
                if sprayData.gang_name == "public" then
                    self.statistics.publicSprays = self.statistics.publicSprays + 1
                else
                    self.statistics.spraysByGang[sprayData.gang_name] = (self.statistics.spraysByGang[sprayData.gang_name] or 0) + 1
                end
            end
            
            Debug:Log("SPRAY_SERVER", "Spray database loaded", {
                loadedSprays = #result,
                publicSprays = self.statistics.publicSprays,
                gangs = self:CountTable(self.statistics.spraysByGang)
            }, "SUCCESS")
        else
            Debug:Log("SPRAY_SERVER", "No sprays found in database", nil, "INFO")
        end
    end)
    
    Debug:EndProfile("SpraySystem_LoadSprayDatabase")
end

-- ✅ ERWEITERT: Spray erstellen mit Public Support
function SpraySystem:CreateSpray(source, sprayData)
    Debug:StartProfile("SpraySystem_CreateSpray", "SPRAY_SERVER")
    
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        Debug:Log("SPRAY_SERVER", "Invalid player for spray creation", {source = source}, "ERROR")
        Debug:EndProfile("SpraySystem_CreateSpray")
        return false
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Comprehensive Permission Check
    local canSpray, reason, metadata = GangPermissions:CanUseSpray(source)
    if not canSpray then
        TriggerClientEvent('QBCore:Notify', source, reason, 'error')
        Debug:Log("SPRAY_SERVER", "Spray creation permission denied", {
            citizenid = citizenid,
            reason = reason
        }, "WARN")
        
        Debug:EndProfile("SpraySystem_CreateSpray")
        return false
    end
    
    -- Server-seitige Validierung
    local validationResult = self:ValidateSprayCreation(source, sprayData, metadata)
    if not validationResult.valid then
        TriggerClientEvent('QBCore:Notify', source, validationResult.reason, 'error')
        Debug:EndProfile("SpraySystem_CreateSpray")
        return false
    end
    
    -- ✅ Public vs Gang Spray Handling
    local sprayType = metadata.sprayType or "gang"
    local gangName = sprayType == "public" and "public" or (metadata.gang or "unknown")
    
    -- Generiere eindeutige Spray-ID
    local sprayId = self:GenerateSprayId(citizenid, gangName, sprayType)
    
    -- ✅ Erstelle Spray-Datenstruktur mit Public Support
    local spray = self:CreateSprayDataStructure(sprayId, source, sprayData, metadata)
    spray.gang_name = gangName  -- ✅ Setze Gang-Name entsprechend
    
    -- Speichere in Database
    local dbSuccess = self:SaveSprayToDatabase(spray)
    if not dbSuccess then
        TriggerClientEvent('QBCore:Notify', source, 'Fehler beim Speichern in Datenbank', 'error')
        Debug:EndProfile("SpraySystem_CreateSpray")
        return false
    end
    
    -- Item verbrauchen
    local itemConsumed = GangPermissions:ConsumeSprayCanUse(source)
    
    -- Füge zu aktivem Cache hinzu
    self.activeSprays[sprayId] = spray
    
    -- ✅ Update Statistiken mit Public Support
    self:UpdateCreationStatistics(spray)
    
    -- Synchronisiere mit allen nearby Clients
    self:SyncSprayToNearbyClients(spray)
    
    -- ✅ Erfolgs-Notification mit Typ-Info
    local successMessage = sprayType == "public" and 'Öffentliches Spray erfolgreich erstellt!' or 'Gang-Spray erfolgreich erstellt!'
    TriggerClientEvent('QBCore:Notify', source, successMessage, 'success')
    
    -- Audit Log
    self:LogSprayAction('CREATE', source, sprayId, {
        gang = gangName,
        sprayType = sprayType,
        position = sprayData.coords,
        textureType = sprayData.textureData and sprayData.textureData.type or "unknown"
    })
    
    Debug:Log("SPRAY_SERVER", "Spray created successfully", {
        sprayId = sprayId,
        citizenid = citizenid,
        gang = gangName,
        sprayType = sprayType,
        itemConsumed = itemConsumed
    }, "SUCCESS")
    
    Debug:EndProfile("SpraySystem_CreateSpray")
    return true, sprayId
end

-- ✅ ERWEITERT: Spray-Entfernung mit Item-Support
function SpraySystem:RemoveSpray(source, sprayId, reason, useRemoverItem)
    Debug:StartProfile("SpraySystem_RemoveSpray", "SPRAY_SERVER")
    
    local spray = self.activeSprays[sprayId]
    if not spray then
        TriggerClientEvent('QBCore:Notify', source, 'Spray nicht gefunden', 'error')
        Debug:EndProfile("SpraySystem_RemoveSpray")
        return false
    end
    
    -- ✅ Permission Check für Removal (mit Item-Support)
    local canRemove, removeReason, metadata = GangPermissions:CanRemoveSpray(source, sprayId)
    if not canRemove then
        TriggerClientEvent('QBCore:Notify', source, removeReason, 'error')
        Debug:EndProfile("SpraySystem_RemoveSpray")
        return false
    end
    
    -- ✅ Item-basierte Entfernung
    if useRemoverItem and metadata and metadata.successChance then
        -- Erfolgsrate prüfen
        local successChance = metadata.successChance or 1.0
        local randomRoll = math.random()
        
        Debug:Log("SPRAY_SERVER", "Item removal attempt", {
            sprayId = sprayId,
            successChance = successChance,
            roll = randomRoll,
            success = randomRoll <= successChance
        }, "INFO")
        
        if randomRoll > successChance then
            -- Fehlschlag - Item trotzdem verbrauchen
            local itemConsumed = GangPermissions:ConsumeSprayRemoverUse(source)
            TriggerClientEvent('QBCore:Notify', source, 'Entfernung fehlgeschlagen - Spray zu hartnäckig!', 'error')
            
            -- Log für Audit
            self:LogSprayAction('REMOVE_FAILED', source, sprayId, {
                reason = "Item removal failed",
                successChance = successChance,
                itemConsumed = itemConsumed
            })
            
            Debug:EndProfile("SpraySystem_RemoveSpray")
            return false
        end
        
        -- Erfolg - Item verbrauchen
        local itemConsumed = GangPermissions:ConsumeSprayRemoverUse(source)
        if not itemConsumed then
            TriggerClientEvent('QBCore:Notify', source, 'Graffiti-Entferner aufgebraucht', 'warning')
        end
        
        self.statistics.itemRemovals = self.statistics.itemRemovals + 1
    end
    
    -- Entferne aus Database
    exports.oxmysql:execute('DELETE FROM gang_sprays WHERE spray_id = ?', {sprayId}, function(affectedRows)
        if affectedRows > 0 then
            Debug:Log("SPRAY_SERVER", "Spray removed from database", {sprayId = sprayId}, "SUCCESS")
        end
    end)
    
    -- Entferne aus aktivem Cache
    self.activeSprays[sprayId] = nil
    
    -- ✅ Update Statistiken mit Public Support
    self:UpdateRemovalStatistics(spray)
    
    -- Synchronisiere Removal mit Clients
    self:SyncSprayRemovalToClients(sprayId)
    
    -- Audit Log
    self:LogSprayAction('REMOVE', source, sprayId, {
        reason = reason,
        originalGang = spray.gang_name,
        useRemoverItem = useRemoverItem or false,
        method = useRemoverItem and "item" or "permission"
    })
    
    local removeMessage = useRemoverItem and 'Graffiti erfolgreich entfernt' or 'Spray entfernt'
    TriggerClientEvent('QBCore:Notify', source, removeMessage, 'success')
    
    Debug:Log("SPRAY_SERVER", "Spray removed successfully", {
        sprayId = sprayId,
        reason = reason,
        method = useRemoverItem and "item" or "permission"
    }, "SUCCESS")
    
    Debug:EndProfile("SpraySystem_RemoveSpray")
    return true
end

-- Spray-Erstellung validieren (erweitert für Public Support)
function SpraySystem:ValidateSprayCreation(source, sprayData, metadata)
    -- Basis-Validierung
    if not sprayData.coords or not sprayData.normal then
        return {valid = false, reason = "Ungültige Spray-Position"}
    end
    
    -- Texture-Daten validieren
    if not sprayData.textureData or not sprayData.textureData.type then
        return {valid = false, reason = "Ungültige Texture-Daten"}
    end
    
    -- Texture-Größe prüfen (Base64)
    if sprayData.textureData.type == 'base64' and sprayData.textureData.data then
        local sizeInBytes = string.len(sprayData.textureData.data) * 0.75 -- Base64 zu Bytes
        if sizeInBytes > Config.DUI.maxImageSize then
            return {valid = false, reason = "Texture zu groß"}
        end
    end
    
    -- Proximity Check zu anderen Sprays
    local proximityCheck = self:CheckSprayProximity(sprayData.coords)
    if not proximityCheck.valid then
        return proximityCheck
    end
    
    -- ✅ Server Limits prüfen (mit Public Support)
    local limitCheck = self:CheckServerLimits(metadata.gang or "public", metadata.sprayType)
    if not limitCheck.valid then
        return limitCheck
    end
    
    -- Area Restrictions prüfen
    local areaCheck = self:CheckAreaRestrictions(sprayData.coords)
    if not areaCheck.valid then
        return areaCheck
    end
    
    return {valid = true}
end

-- Proximity Check zu anderen Sprays
function SpraySystem:CheckSprayProximity(coords)
    local minDistance = Config.Physics.minPlacementDistance
    
    for sprayId, spray in pairs(self.activeSprays) do
        if spray.position then
            local sprayCoords = vector3(spray.position.x, spray.position.y, spray.position.z)
            local distance = #(coords - sprayCoords)
            
            if distance < minDistance then
                return {
                    valid = false,
                    reason = string.format("Zu nah an anderem Spray (%.1fm entfernt)", distance)
                }
            end
        end
    end
    
    return {valid = true}
end

-- ✅ ERWEITERT: Server Limits mit Public Support
function SpraySystem:CheckServerLimits(gang, sprayType)
    -- Gesamte Server-Sprays
    if self.statistics.totalSprays >= Config.Performance.maxTotalSprays then
        return {valid = false, reason = "Server Spray-Limit erreicht"}
    end
    
    if sprayType == "public" then
        -- Public Spray Limits
        local maxPublicSprays = Config.Gangs.Global.maxPublicSpraysTotal or 25
        if self.statistics.publicSprays >= maxPublicSprays then
            return {valid = false, reason = "Server Public Spray-Limit erreicht"}
        end
    else
        -- Gang-spezifische Limits
        local gangSprays = self.statistics.spraysByGang[gang] or 0
        local maxGangSprays = Config.Gangs.Global.maxGangSpraysTotal or 50
        
        if gangSprays >= maxGangSprays then
            return {valid = false, reason = "Gang Spray-Limit erreicht"}
        end
    end
    
    return {valid = true}
end

-- Area Restrictions prüfen
function SpraySystem:CheckAreaRestrictions(coords)
    for _, zone in ipairs(Config.Permissions.neutralZones or {}) do
        local distance = #(coords - zone.coords)
        if distance < zone.radius then
            return {
                valid = false,
                reason = "Sprays in diesem Bereich nicht erlaubt"
            }
        end
    end
    
    return {valid = true}
end

-- Spray-Datenstruktur erstellen (erweitert)
function SpraySystem:CreateSprayDataStructure(sprayId, source, sprayData, metadata)
    local Player = QBCore.Functions.GetPlayer(source)
    local currentTime = os.date('%Y-%m-%d %H:%M:%S')
    
    -- ✅ Berechne Ablaufzeit basierend auf Spray-Typ
    local expiresAt = nil
    local baseExpireTime = Config.Performance.sprayExpireTime
    
    if metadata.sprayType == "public" then
        -- Public Sprays haben kürzere Lebensdauer
        local publicMultiplier = Config.Gangs.Categories.public and Config.Gangs.Categories.public.expireMultiplier or 0.5
        baseExpireTime = math.floor(baseExpireTime * publicMultiplier)
    end
    
    if baseExpireTime > 0 then
        expiresAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + baseExpireTime)
    end
    
    return {
        spray_id = sprayId,
        citizenid = Player.PlayerData.citizenid,
        gang_name = metadata.gang or "public",
        gang_grade = metadata.gangGrade or 0,
        position = {
            x = sprayData.coords.x,
            y = sprayData.coords.y,
            z = sprayData.coords.z,
            rx = sprayData.rotation and sprayData.rotation.x or 0,
            ry = sprayData.rotation and sprayData.rotation.y or 0,
            rz = sprayData.rotation and sprayData.rotation.z or 0,
            normal = {
                x = sprayData.normal.x,
                y = sprayData.normal.y,
                z = sprayData.normal.z
            }
        },
        texture_data = self:ProcessTextureData(sprayData.textureData),
        texture_type = sprayData.textureData.type,
        texture_hash = self:GenerateTextureHash(sprayData.textureData),
        metadata = {
            scale = sprayData.scale or 1.0,
            placementMethod = sprayData.metadata and sprayData.metadata.placementMethod or 'manual',
            sprayType = metadata.sprayType or "gang",  -- ✅ Spray-Typ in Metadata
            isPublic = metadata.isPublic or false,      -- ✅ Public Flag
            clientVersion = GetResourceMetadata(GetCurrentResourceName(), "version", 0) or "1.0.0",
            serverTime = currentTime
        },
        created_at = currentTime,
        expires_at = expiresAt,
        quality = 100,
        views = 0
    }
end

-- Texture-Daten verarbeiten
function SpraySystem:ProcessTextureData(textureData)
    if textureData.type == 'base64' then
        -- Komprimiere Base64 falls nötig
        return self:CompressBase64(textureData.data)
    elseif textureData.type == 'url' then
        -- Validiere und speichere URL
        return self:ValidateAndStoreURL(textureData.url)
    elseif textureData.type == 'preset' then
        -- Template-ID zurückgeben
        return textureData.preset or textureData.template
    end
    
    return nil
end

-- Base64 Komprimierung (vereinfacht)
function SpraySystem:CompressBase64(base64Data)
    -- Für echte Implementierung würde hier eine Komprimierung stattfinden
    -- Derzeit einfach Return (Platzhalter)
    return base64Data
end

-- URL validieren und speichern
function SpraySystem:ValidateAndStoreURL(url)
    -- URL-Validierung
    if not url or not string.match(url, "^https?://") then
        return nil
    end
    
    -- Für Production: URL in Whitelist prüfen oder Content-Type validieren
    return url
end

-- Texture Hash generieren für Duplikat-Erkennung
function SpraySystem:GenerateTextureHash(textureData)
    local hashString = textureData.type .. "_" .. (textureData.data or textureData.url or textureData.preset or "")
    
    -- Einfacher Hash (für Production: echte MD5/SHA1 verwenden)
    local hash = 0
    for i = 1, #hashString do
        hash = (hash * 31 + string.byte(hashString, i)) % 2147483647
    end
    
    return tostring(hash)
end

-- ✅ ERWEITERT: Spray-ID generieren mit Public Support
function SpraySystem:GenerateSprayId(citizenid, gang, sprayType)
    local timestamp = os.time()
    local random = math.random(1000, 9999)
    local prefix = sprayType == "public" and "PUB" or "GANG"
    
    return string.format("%s_%s_%s_%d_%d", prefix, gang:upper(), citizenid:sub(-4), timestamp, random)
end

-- Spray in Database speichern
function SpraySystem:SaveSprayToDatabase(spray)
    Debug:StartProfile("SpraySystem_SaveSprayToDatabase", "DATABASE")
    
    local success = false
    
    exports.oxmysql:insert('INSERT INTO gang_sprays (spray_id, citizenid, gang_name, gang_grade, position, texture_data, texture_type, texture_hash, metadata, expires_at, quality) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        spray.spray_id,
        spray.citizenid,
        spray.gang_name,
        spray.gang_grade,
        json.encode(spray.position),
        spray.texture_data,
        spray.texture_type,
        spray.texture_hash,
        json.encode(spray.metadata),
        spray.expires_at,
        spray.quality
    }, function(insertId)
        if insertId then
            success = true
            Debug:Log("SPRAY_SERVER", "Spray saved to database", {
                sprayId = spray.spray_id,
                insertId = insertId
            }, "SUCCESS")
        else
            Debug:Log("SPRAY_SERVER", "Failed to save spray to database", {
                sprayId = spray.spray_id
            }, "ERROR")
        end
    end)
    
    -- Warte auf Database Response (synchron für Validierung)
    local timeout = 0
    while success == false and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    
    Debug:EndProfile("SpraySystem_SaveSprayToDatabase")
    return success
end

-- Client-Synchronisation
function SpraySystem:SyncSprayToNearbyClients(spray)
    local sprayCoords = vector3(spray.position.x, spray.position.y, spray.position.z)
    
    for playerId in pairs(self.syncedClients) do
        local playerCoords = GetEntityCoords(GetPlayerPed(playerId))
        if playerCoords and #(sprayCoords - playerCoords) < Config.Performance.streamingDistance * 1.5 then
            TriggerClientEvent('spray:client:addSpray', playerId, spray)
        end
    end
end

function SpraySystem:SyncSprayRemovalToClients(sprayId)
    for playerId in pairs(self.syncedClients) do
        TriggerClientEvent('spray:client:removeSpray', playerId, sprayId)
    end
end

-- ✅ ERWEITERT: Statistiken mit Public Support
function SpraySystem:UpdateCreationStatistics(spray)
    self.statistics.totalSprays = self.statistics.totalSprays + 1
    self.statistics.dailyCreations = self.statistics.dailyCreations + 1
    
    if spray.gang_name == "public" then
        self.statistics.publicSprays = self.statistics.publicSprays + 1
    else
        self.statistics.spraysByGang[spray.gang_name] = (self.statistics.spraysByGang[spray.gang_name] or 0) + 1
    end
end

function SpraySystem:UpdateRemovalStatistics(spray)
    self.statistics.totalSprays = math.max(0, self.statistics.totalSprays - 1)
    self.statistics.dailyRemovals = self.statistics.dailyRemovals + 1
    
    if spray.gang_name == "public" then
        self.statistics.publicSprays = math.max(0, self.statistics.publicSprays - 1)
    else
        self.statistics.spraysByGang[spray.gang_name] = math.max(0, (self.statistics.spraysByGang[spray.gang_name] or 0) - 1)
    end
end

-- Audit Logging
function SpraySystem:LogSprayAction(action, source, sprayId, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    exports.oxmysql:insert('INSERT INTO spray_audit_log (action, spray_id, citizenid, gang_name, action_data) VALUES (?, ?, ?, ?, ?)', {
        action,
        sprayId,
        Player.PlayerData.citizenid,
        data.gang or (Player.PlayerData.gang and Player.PlayerData.gang.name),
        json.encode(data)
    })
end

-- Cleanup-Timer für abgelaufene Sprays
function SpraySystem:StartCleanupTimer()
    CreateThread(function()
        while true do
            Wait(Config.Performance.cleanupInterval)
            self:CleanupExpiredSprays()
        end
    end)
end

function SpraySystem:CleanupExpiredSprays()
    Debug:StartProfile("SpraySystem_CleanupExpiredSprays", "CLEANUP")
    
    local cleanedCount = 0
    local publicCleaned = 0
    local currentTime = os.time()
    
    for sprayId, spray in pairs(self.activeSprays) do
        local shouldCleanup = false
        
        -- Check Expiration
        if spray.expires_at then
            local expirationTime = self:ParseTimestamp(spray.expires_at)
            if currentTime > expirationTime then
                shouldCleanup = true
            end
        end
        
        -- Check Quality degradation
        if spray.quality and spray.quality <= 0 then
            shouldCleanup = true
        end
        
        if shouldCleanup then
            -- Remove from database
            exports.oxmysql:execute('DELETE FROM gang_sprays WHERE spray_id = ?', {sprayId})
            
            -- Update statistics
            if spray.gang_name == "public" then
                publicCleaned = publicCleaned + 1
                self.statistics.publicSprays = math.max(0, self.statistics.publicSprays - 1)
            else
                self.statistics.spraysByGang[spray.gang_name] = math.max(0, (self.statistics.spraysByGang[spray.gang_name] or 0) - 1)
            end
            
            -- Remove from cache
            self.activeSprays[sprayId] = nil
            
            -- Sync removal to clients
            self:SyncSprayRemovalToClients(sprayId)
            
            cleanedCount = cleanedCount + 1
            
            Debug:Log("SPRAY_SERVER", "Expired spray cleaned up", {
                sprayId = sprayId,
                gang = spray.gang_name
            }, "INFO")
        end
    end
    
    if cleanedCount > 0 then
        Debug:Log("SPRAY_SERVER", "Cleanup completed", {
            cleanedSprays = cleanedCount,
            publicCleaned = publicCleaned,
            gangCleaned = cleanedCount - publicCleaned
        }, "SUCCESS")
        self.statistics.totalSprays = self.statistics.totalSprays - cleanedCount
    end
    
    Debug:EndProfile("SpraySystem_CleanupExpiredSprays")
end

-- Client-Sync Timer
function SpraySystem:StartClientSyncTimer()
    CreateThread(function()
        while true do
            Wait(30000) -- 30 Sekunden
            self:SyncNearbySprayData()
        end
    end)
end

function SpraySystem:SyncNearbySprayData()
    for playerId in pairs(self.syncedClients) do
        local playerPed = GetPlayerPed(playerId)
        if playerPed and DoesEntityExist(playerPed) then
            local playerCoords = GetEntityCoords(playerPed)
            local nearbySprayData = self:GetNearbySprayData(playerCoords, Config.Performance.streamingDistance)
            
            if next(nearbySprayData) then
                TriggerClientEvent('spray:client:syncSprayData', playerId, nearbySprayData)
            end
        end
    end
end

function SpraySystem:GetNearbySprayData(coords, distance)
    local nearbySprayData = {}
    
    for sprayId, spray in pairs(self.activeSprays) do
        if spray.position then
            local sprayCoords = vector3(spray.position.x, spray.position.y, spray.position.z)
            local sprayDistance = #(coords - sprayCoords)
            
            if sprayDistance <= distance then
                nearbySprayData[#nearbySprayData + 1] = spray
            end
        end
    end
    
    return nearbySprayData
end

-- Anti-Spam Protection
function SpraySystem:CheckSpamProtection(source)
    local currentTime = GetGameTimer()
    local playerId = tostring(source)
    
    if not self.spamProtection[playerId] then
        self.spamProtection[playerId] = {
            lastAction = 0,
            actionCount = 0,
            windowStart = currentTime
        }
    end
    
    local playerSpam = self.spamProtection[playerId]
    
    -- Reset window if needed (1 minute windows)
    if currentTime - playerSpam.windowStart > 60000 then
        playerSpam.actionCount = 0
        playerSpam.windowStart = currentTime
    end
    
    -- Check rate limit
    if currentTime - playerSpam.lastAction < Config.RateLimit.sprayCreationCooldown then
        return false
    end
    
    -- Check actions per minute
    if playerSpam.actionCount >= Config.RateLimit.maxActionsPerMinute then
        return false
    end
    
    -- Update spam protection
    playerSpam.lastAction = currentTime
    playerSpam.actionCount = playerSpam.actionCount + 1
    
    return true
end

-- Hilfsfunktionen
function SpraySystem:ParseTimestamp(timestamp)
    if type(timestamp) == "string" then
        local year, month, day, hour, min, sec = timestamp:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
        if year then
            return os.time({
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = tonumber(hour),
                min = tonumber(min),
                sec = tonumber(sec)
            })
        end
    end
    return 0
end

function SpraySystem:CountTable(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- Public API für andere Resources
function SpraySystem:GetSprayData(sprayId)
    return self.activeSprays[sprayId]
end

function SpraySystem:GetAllSprayData()
    return self.activeSprays
end

function SpraySystem:GetSpraysByGang(gangName)
    local gangSprayData = {}
    for sprayId, spray in pairs(self.activeSprays) do
        if spray.gang_name == gangName then
            gangSprayData[sprayId] = spray
        end
    end
    return gangSprayData
end

-- ✅ ERWEITERT: Statistiken mit Public Support
function SpraySystem:GetStatistics()
    local stats = table.copy(self.statistics)
    
    -- Berechne zusätzliche Metriken
    stats.gangSprayCount = stats.totalSprays - stats.publicSprays
    stats.publicSprayPercentage = stats.totalSprays > 0 and (stats.publicSprays / stats.totalSprays) * 100 or 0
    stats.itemRemovalPercentage = stats.dailyRemovals > 0 and (stats.itemRemovals / stats.dailyRemovals) * 100 or 0
    
    return stats
end

-- Event Handlers
RegisterNetEvent('spray:server:createSpray', function(sprayData)
    local src = source
    SpraySystem:CreateSpray(src, sprayData)
end)

RegisterNetEvent('spray:server:removeSpray', function(sprayId, reason, useRemoverItem)
    local src = source
    SpraySystem:RemoveSpray(src, sprayId, reason or "Manual removal", useRemoverItem or false)
end)

-- ✅ NEU: Item-basierte Entfernung Event
RegisterNetEvent('spray:server:removeSprayWithItem', function(sprayId)
    local src = source
    SpraySystem:RemoveSpray(src, sprayId, "Item removal", true)
end)

RegisterNetEvent('spray:server:requestNearbySprayData', function()
    local src = source
    local playerPed = GetPlayerPed(src)
    
    if playerPed and DoesEntityExist(playerPed) then
        local playerCoords = GetEntityCoords(playerPed)
        local nearbySprayData = SpraySystem:GetNearbySprayData(playerCoords, Config.Performance.streamingDistance)
        
        TriggerClientEvent('spray:client:syncSprayData', src, nearbySprayData)
        SpraySystem.syncedClients[src] = true
    end
end)

RegisterNetEvent('spray:server:requestSprayStatistics', function()
    local src = source
    local stats = SpraySystem:GetStatistics()
    TriggerClientEvent('spray:client:receiveStatistics', src, stats)
end)

-- ✅ NEU: Player Spray Query Event
RegisterNetEvent('spray:server:getPlayerSprays', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    exports.oxmysql:execute('SELECT * FROM gang_sprays WHERE citizenid = ? AND (expires_at IS NULL OR expires_at > NOW()) ORDER BY created_at DESC', {
        citizenid
    }, function(result)
        TriggerClientEvent('spray:client:receivePlayerSprays', src, result or {})
    end)
end)

-- Player Connect/Disconnect Handlers
AddEventHandler('playerConnecting', function()
    local src = source
    -- Client wird zu syncedClients hinzugefügt wenn er Spray-Daten anfordert
end)

AddEventHandler('playerDropped', function(reason)
    local src = tonumber(source)
    if SpraySystem.syncedClients[src] then
        SpraySystem.syncedClients[src] = nil
    end
    if SpraySystem.spamProtection[tostring(src)] then
        SpraySystem.spamProtection[tostring(src)] = nil
    end
end)

-- NUI Callbacks für Template System
RegisterNetEvent('spray:server:getTemplates', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local gang = data.gang or (Player.PlayerData.gang and Player.PlayerData.gang.name)
    local templates = {}
    
    -- ✅ NEU: Public Templates für alle hinzufügen (Priorität)
    if Config.Gangs.PublicTemplates then
        for templateId, templateConfig in pairs(Config.Gangs.PublicTemplates) do
            table.insert(templates, {
                id = templateId,
                name = templateConfig.name,
                category = templateConfig.category,
                description = templateConfig.description,
                filePath = templateConfig.filePath,
                requiredGrade = 0,
                isPublic = true,
                priority = templateConfig.priority or 999
            })
        end
    end
    
    -- Gang Templates (nur für Gang-Mitglieder)
    if gang and Config.Gangs.AllowedGangs[gang] then
        local gangConfig = Config.Gangs.AllowedGangs[gang]
        
        for _, templateId in ipairs(gangConfig.templates or {}) do
            local templateConfig = Config.Gangs.Templates[templateId]
            if templateConfig then
                table.insert(templates, {
                    id = templateId,
                    name = templateConfig.name,
                    category = templateConfig.category,
                    description = templateConfig.description,
                    filePath = templateConfig.filePath,
                    requiredGrade = templateConfig.requiredGrade,
                    isPublic = false,
                    priority = 100 + (templateConfig.requiredGrade or 0)
                })
            end
        end
    end
    
    -- Sortiere nach Priorität (Public Templates zuerst)
    table.sort(templates, function(a, b) return a.priority < b.priority end)
    
    TriggerClientEvent('spray:client:receiveTemplates', src, {
        success = true,
        templates = templates,
        gang = gang
    })
end)

RegisterNetEvent('spray:server:useTemplate', function(data)
    local src = source
    local templateId = data.templateId
    local gang = data.gang
    
    -- Validate template access
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local templateConfig = nil
    
    -- ✅ Check Public Templates first
    if Config.Gangs.PublicTemplates[templateId] then
        templateConfig = Config.Gangs.PublicTemplates[templateId]
        -- Public Templates sind für alle verfügbar
    elseif Config.Gangs.Templates[templateId] then
        templateConfig = Config.Gangs.Templates[templateId]
        
        -- Gang Template - prüfe Berechtigung
        local playerGang = Player.PlayerData.gang and Player.PlayerData.gang.name
        if playerGang ~= gang then
            TriggerClientEvent('spray:client:templateResult', src, {
                success = false,
                error = "Gang-Berechtigung ungültig"
            })
            return
        end
        
        -- Check grade requirement für Gang Templates
        local playerGrade = Player.PlayerData.gang.grade.level
        if playerGrade < (templateConfig.requiredGrade or 0) then
            TriggerClientEvent('spray:client:templateResult', src, {
                success = false,
                error = string.format("Benötigt Gang-Rang %d (aktuell: %d)", templateConfig.requiredGrade, playerGrade)
            })
            return
        end
    else
        TriggerClientEvent('spray:client:templateResult', src, {
            success = false,
            error = "Template nicht gefunden"
        })
        return
    end
    
    -- Prepare template data for placement
    local templateData = {
        type = 'preset',
        preset = templateId,
        template = templateConfig
    }
    
    TriggerClientEvent('spray:client:startPlacement', src, templateData, 'auto')
    TriggerClientEvent('spray:client:templateResult', src, {
        success = true,
        message = "Template wird verwendet"
    })
end)

RegisterNetEvent('spray:server:useUrlImage', function(data)
    local src = source
    local imageUrl = data.imageUrl
    local gang = data.gang
    
    -- Basic URL validation
    if not imageUrl or not string.match(imageUrl, "^https?://") then
        TriggerClientEvent('spray:client:urlResult', src, {
            success = false,
            error = "Ungültige URL"
        })
        return
    end
    
    -- Prepare URL data for placement
    local urlData = {
        type = 'url',
        url = imageUrl
    }
    
    TriggerClientEvent('spray:client:startPlacement', src, urlData, 'manual')
    TriggerClientEvent('spray:client:urlResult', src, {
        success = true,
        message = "URL-Bild wird verwendet"
    })
end)

-- NUI Editor Callbacks
RegisterNetEvent('spray:server:saveSprayDesign', function(data)
    local src = source
    local textureData = data.textureData
    local metadata = data.metadata
    
    if not textureData then
        TriggerClientEvent('spray:client:editorResult', src, {
            success = false,
            error = "Keine Texture-Daten"
        })
        return
    end
    
    -- Prepare custom design data for placement
    local designData = {
        type = 'base64',
        data = textureData,
        metadata = metadata
    }
    
    TriggerClientEvent('spray:client:startPlacement', src, designData, 'gizmo')
    TriggerClientEvent('spray:client:editorResult', src, {
        success = true,
        message = "Custom Design wird verwendet"
    })
end)

RegisterNetEvent('spray:server:closeEditor', function()
    local src = source
    -- Cleanup für Editor (falls nötig)
    Debug:Log("SPRAY_SERVER", "Editor closed", {source = src}, "INFO")
end)

-- ✅ ERWEITERT: Admin Commands mit Public Support
RegisterCommand('spray_stats', function(source, args)
    if source == 0 or GangPermissions:IsPlayerAdmin(source) then
        local stats = SpraySystem:GetStatistics()
        
        if source == 0 then
            print("=== SPRAY SYSTEM STATISTICS ===")
            print("Total Sprays: " .. stats.totalSprays)
            print("Public Sprays: " .. stats.publicSprays)
            print("Gang Sprays: " .. stats.gangSprayCount)
            print("Daily Creations: " .. stats.dailyCreations)
            print("Daily Removals: " .. stats.dailyRemovals)
            print("Item Removals: " .. stats.itemRemovals)
            print("Sprays by Gang:")
            for gang, count in pairs(stats.spraysByGang) do
                print("  " .. gang .. ": " .. count)
            end
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 255, 0 },
                multiline = true,
                args = { "Spray Stats", 
                    string.format("Total: %d | Public: %d | Gang: %d | Today: +%d -%d", 
                        stats.totalSprays, stats.publicSprays, stats.gangSprayCount, 
                        stats.dailyCreations, stats.dailyRemovals) }
            })
        end
    end
end, false)

RegisterCommand('spray_cleanup', function(source, args)
    if source == 0 or GangPermissions:IsPlayerAdmin(source) then
        SpraySystem:CleanupExpiredSprays()
        
        local msg = "Spray cleanup executed"
        if source == 0 then
            print(msg)
        else
            TriggerClientEvent('QBCore:Notify', source, msg, 'success')
        end
    end
end, false)

RegisterCommand('spray_remove', function(source, args)
    if not GangPermissions:IsPlayerAdmin(source) then return end
    
    local sprayId = args[1]
    if not sprayId then
        TriggerClientEvent('QBCore:Notify', source, 'Verwendung: /spray_remove <spray_id>', 'error')
        return
    end
    
    local success = SpraySystem:RemoveSpray(source, sprayId, "Admin removal")
    if success then
        TriggerClientEvent('QBCore:Notify', source, 'Spray entfernt: ' .. sprayId, 'success')
    else
        TriggerClientEvent('QBCore:Notify', source, 'Spray nicht gefunden: ' .. sprayId, 'error')
    end
end, false)

-- ✅ NEU: Public Spray Admin Commands
RegisterCommand('spray_clear_public', function(source, args)
    if not GangPermissions:IsPlayerAdmin(source) then return end
    
    local count = 0
    for sprayId, spray in pairs(SpraySystem.activeSprays) do
        if spray.gang_name == "public" then
            SpraySystem:RemoveSpray(source, sprayId, "Admin public cleanup")
            count = count + 1
        end
    end
    
    local msg = string.format("Removed %d public sprays", count)
    if source == 0 then
        print(msg)
    else
        TriggerClientEvent('QBCore:Notify', source, msg, 'success')
    end
end, false)

-- Exports für andere Resources
exports('GetSprayData', function(sprayId)
    return SpraySystem:GetSprayData(sprayId)
end)

exports('GetSpraysByGang', function(gangName)
    return SpraySystem:GetSpraysByGang(gangName)
end)

exports('GetSprayStatistics', function()
    return SpraySystem:GetStatistics()
end)

exports('RemoveSpray', function(sprayId, reason)
    return SpraySystem:RemoveSpray(0, sprayId, reason or "External removal")
end)

-- ✅ NEU: QBCore Callback für Player Sprays
QBCore.Functions.CreateCallback('spray:server:getPlayerSprays', function(source, cb, citizenid)
    exports.oxmysql:execute('SELECT * FROM gang_sprays WHERE citizenid = ? AND (expires_at IS NULL OR expires_at > NOW()) ORDER BY created_at DESC LIMIT 20', {
        citizenid
    }, function(result)
        cb(result or {})
    end)
end)

-- Daily Statistics Reset
CreateThread(function()
    local lastResetDay = os.date("*t").day
    
    while true do
        Wait(3600000) -- Check every hour
        
        local currentDay = os.date("*t").day
        if currentDay ~= lastResetDay then
            -- Reset daily statistics
            SpraySystem.statistics.dailyCreations = 0
            SpraySystem.statistics.dailyRemovals = 0
            SpraySystem.statistics.itemRemovals = 0
            lastResetDay = currentDay
            
            Debug:Log("SPRAY_SERVER", "Daily statistics reset", nil, "INFO")
        end
    end
end)

-- Resource Start/Stop Handlers
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Warte bis QBCore und MySQL bereit sind
        CreateThread(function()
            while not QBCore do
                Wait(100)
            end
            
            -- Warte bis MySQL bereit ist
            while GetResourceState('oxmysql') ~= 'started' do
                Wait(100)
            end
            
            SpraySystem:Initialize()
        end)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Debug:Log("SPRAY_SERVER", "Spray system shutting down", {
            totalSprays = SpraySystem.statistics.totalSprays,
            publicSprays = SpraySystem.statistics.publicSprays,
            activeClients = SpraySystem:CountTable(SpraySystem.syncedClients)
        }, "INFO")
    end
end)

Debug:Log("SPRAY_SERVER", "Spray system server script loaded with item support", nil, "SUCCESS")