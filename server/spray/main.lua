-- ✅ GEFIXT: Gang Spray Server Main - Vollständig reparierte Version
-- Datei: server/spray/main.lua

local QBCore = exports['qb-core']:GetCoreObject()

-- ✅ FIX: SpraySystem Class mit verbesserter Database Integration
SpraySystem = {
    activeSprays = {},
    playerCooldowns = {},
    syncedClients = {},
    statistics = {
        totalSprays = 0,
        publicSprays = 0,
        dailyCreations = 0,
        dailyRemovals = 0,
        itemRemovals = 0,
        spraysByGang = {},
        lastResetTime = os.time(),
        performance = {
            avgResponseTime = 0,
            totalQueries = 0,
            errorCount = 0
        }
    },
    
    -- Performance & Security
    spamProtection = {},
    lastCleanupTime = 0,
    cleanupInterval = 300000, -- 5 Minuten
    maxSpraySize = 5 * 1024 * 1024, -- 5MB Base64 Limit
    
    -- Database Connection Pool
    dbPool = {
        activeConnections = 0,
        maxConnections = 10,
        queryQueue = {}
    }
}

-- ✅ FIX: System Initialisierung mit Schema Fix
function SpraySystem:Initialize()
    -- Schema Fix zuerst ausführen
    if SchemaFix then
        SchemaFix:RunMigration()
        -- Warte auf Schema Migration
        CreateThread(function()
            local maxWait = 10000 -- 10 Sekunden max
            local waited = 0
            
            while SchemaFix.isRunning and waited < maxWait do
                Wait(500)
                waited = waited + 500
            end
            
            -- Fortsetzung der Initialisierung
            self:ContinueInitialization()
        end)
    else
        -- Fallback ohne Schema Fix
        Debug:Log("SPRAY", "SchemaFix not available, using fallback initialization", nil, "WARN")
        self:ContinueInitialization()
    end
end

-- ✅ FIX: Fortsetzung der Initialisierung nach Schema Fix
function SpraySystem:ContinueInitialization()
    -- Aktive Sprays laden
    self:LoadActiveSprays()
    
    -- Statistics initialisieren
    self:InitializeStatistics()
    
    -- Cleanup Schedule starten
    self:StartCleanupSchedule()
    
    -- Performance Monitoring
    self:StartPerformanceMonitoring()
    
    Debug:Log("SPRAY", "SpraySystem initialized successfully", {
        activeSprays = self:CountTable(self.activeSprays),
        totalSprays = self.statistics.totalSprays
    }, "SUCCESS")
end

-- ✅ FIX: Callback für Schema Ready
function SpraySystem:OnSchemaReady()
    Debug:Log("SPRAY", "Database schema is ready", nil, "SUCCESS")
    -- Reload active sprays mit vollständigem Schema
    self:LoadActiveSprays()
end

-- ✅ FIX: Database Schema Validation via DatabaseSchema module
function SpraySystem:ValidateDatabaseSchema()
    -- Use DatabaseSchema module for proper MariaDB/MySQL compatibility
    if DatabaseSchema and not DatabaseSchema.isInitialized then
        DatabaseSchema:Initialize()
    else
        Debug:Log("SPRAY", "DatabaseSchema module not found, using fallback", nil, "WARN")
        self:CreateFallbackSchema()
    end
end

-- ✅ FIX: Fallback Schema für Legacy Support
function SpraySystem:CreateFallbackSchema()
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS gang_sprays (
            spray_id VARCHAR(255) PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            gang_name VARCHAR(50) NOT NULL DEFAULT 'public',
            gang_grade INT DEFAULT 0,
            position LONGTEXT NOT NULL,
            rotation LONGTEXT DEFAULT NULL,
            image_data LONGTEXT NOT NULL,
            quality INT DEFAULT 100,
            views INT DEFAULT 0,
            metadata LONGTEXT DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            expires_at TIMESTAMP NULL DEFAULT NULL,
            last_viewed TIMESTAMP NULL DEFAULT NULL,
            
            INDEX idx_citizenid (citizenid),
            INDEX idx_gang_name (gang_name),
            INDEX idx_created_at (created_at),
            INDEX idx_expires_at (expires_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]], {}, function(result)
        if result then
            Debug:Log("SPRAY", "Fallback database schema created", nil, "SUCCESS")
        else
            Debug:Log("SPRAY", "Fallback database schema creation failed", nil, "ERROR")
        end
    end)
end

-- ✅ FIX: Aktive Sprays laden mit sicheren Queries
function SpraySystem:LoadActiveSprays()
    Debug:StartProfile("LoadActiveSprays", "DATABASE")
    
    -- ✅ FIX: Sichere Query die auch ohne alle Spalten funktioniert
    local safeQuery = [[
        SELECT spray_id, citizenid, gang_name, gang_grade, position, 
               image_data, created_at, expires_at
        FROM gang_sprays 
        WHERE expires_at IS NULL OR expires_at > NOW()
        ORDER BY created_at DESC
    ]]
    
    exports.oxmysql:execute(safeQuery, {}, function(result)
        if result then
            self.activeSprays = {}
            
            for _, spray in ipairs(result) do
                -- ✅ FIX: Erweiterte Daten separat laden wenn verfügbar
                self:LoadSprayWithExtendedData(spray)
            end
            
            Debug:Log("SPRAY", "Active sprays loaded (safe mode)", {
                count = #result,
                processed = self:CountTable(self.activeSprays)
            }, "SUCCESS")
        else
            Debug:Log("SPRAY", "Failed to load active sprays", nil, "ERROR")
        end
        
        Debug:EndProfile("LoadActiveSprays")
    end)
end

-- ✅ FIX: Spray mit erweiterten Daten laden
function SpraySystem:LoadSprayWithExtendedData(baseSpray)
    -- Basis Spray Data verarbeiten
    local sprayData = self:ProcessSprayData(baseSpray)
    if not sprayData then
        return
    end
    
    -- Default Werte für fehlende Felder setzen
    sprayData.rotation = nil
    sprayData.quality = 100
    sprayData.views = 0
    sprayData.metadata = nil
    sprayData.last_viewed = nil
    
    -- Versuche erweiterte Daten zu laden (falls Spalten existieren)
    self:TryLoadExtendedData(sprayData.spray_id, function(extendedData)
        if extendedData then
            -- Überschreibe mit echten Daten falls verfügbar
            sprayData.rotation = extendedData.rotation
            sprayData.quality = extendedData.quality or 100
            sprayData.views = extendedData.views or 0
            sprayData.metadata = extendedData.metadata
            sprayData.last_viewed = extendedData.last_viewed
        end
        
        -- Spray zu Cache hinzufügen
        self.activeSprays[sprayData.spray_id] = sprayData
    end)
end

-- ✅ FIX: Versuche erweiterte Daten zu laden
function SpraySystem:TryLoadExtendedData(sprayId, callback)
    -- Query die nur läuft wenn die Spalten existieren
    local extendedQuery = [[
        SELECT rotation, quality, views, metadata, last_viewed
        FROM gang_sprays 
        WHERE spray_id = ?
        LIMIT 1
    ]]
    
    exports.oxmysql:execute(extendedQuery, {sprayId}, function(result)
        if result and result[1] then
            -- Erweiterte Daten verfügbar
            local extended = result[1]
            extended.rotation = self:SafeJsonDecode(extended.rotation)
            extended.metadata = self:SafeJsonDecode(extended.metadata)
            callback(extended)
        else
            -- Keine erweiterten Daten verfügbar
            callback(nil)
        end
    end)
end

-- ✅ FIX: Sichere JSON Decode
function SpraySystem:SafeJsonDecode(data)
    if not data or data == "" then
        return nil
    end
    
    if type(data) == "string" then
        local success, result = pcall(json.decode, data)
        if success then
            return result
        end
    end
    
    return data
end

-- ✅ FIX: Spray Data Processing mit Error Handling
function SpraySystem:ProcessSprayData(spray)
    local success, result = pcall(function()
        return {
            spray_id = spray.spray_id,
            citizenid = spray.citizenid,
            gang_name = spray.gang_name or "public",
            gang_grade = spray.gang_grade or 0,
            position = type(spray.position) == "string" and json.decode(spray.position) or spray.position,
            rotation = type(spray.rotation) == "string" and json.decode(spray.rotation) or spray.rotation,
            quality = spray.quality or 100,
            views = spray.views or 0,
            metadata = type(spray.metadata) == "string" and json.decode(spray.metadata) or spray.metadata,
            created_at = self:ParseTimestamp(spray.created_at),
            expires_at = spray.expires_at and self:ParseTimestamp(spray.expires_at) or nil,
            last_viewed = spray.last_viewed and self:ParseTimestamp(spray.last_viewed) or nil
        }
    end)
    
    if success then
        return result
    else
        Debug:Log("SPRAY", "Failed to process spray data", {
            sprayId = spray.spray_id,
            error = result
        }, "ERROR")
        return nil
    end
end

-- ✅ FIX: Statistics Initialisierung
function SpraySystem:InitializeStatistics()
    exports.oxmysql:execute([[
        SELECT 
            COUNT(*) as total_sprays,
            COUNT(CASE WHEN gang_name = 'public' THEN 1 END) as public_sprays,
            COUNT(CASE WHEN DATE(created_at) = CURDATE() THEN 1 END) as daily_creations
        FROM gang_sprays 
        WHERE expires_at IS NULL OR expires_at > NOW()
    ]], {}, function(result)
        if result and result[1] then
            local stats = result[1]
            self.statistics.totalSprays = stats.total_sprays or 0
            self.statistics.publicSprays = stats.public_sprays or 0
            self.statistics.dailyCreations = stats.daily_creations or 0
        end
    end)
    
    -- Gang Statistics
    exports.oxmysql:execute([[
        SELECT gang_name, COUNT(*) as count 
        FROM gang_sprays 
        WHERE expires_at IS NULL OR expires_at > NOW()
        GROUP BY gang_name
    ]], {}, function(result)
        if result then
            for _, row in ipairs(result) do
                self.statistics.spraysByGang[row.gang_name] = row.count
            end
        end
    end)
end

-- ✅ FIX: Spray erstellen mit verbesserter Validierung
function SpraySystem:CreateSpray(source, sprayData)
    Debug:StartProfile("CreateSpray", "SPRAY")
    
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        Debug:Log("SPRAY", "Invalid player for spray creation", {source = source}, "ERROR")
        Debug:EndProfile("CreateSpray")
        return false
    end
    
    -- ✅ FIX: Spam Protection
    if not self:CheckSpamProtection(source) then
        TriggerClientEvent('QBCore:Notify', source, 'Du erstellst zu schnell Sprays. Warte kurz.', 'error')
        Debug:EndProfile("CreateSpray")
        return false
    end
    
    -- ✅ FIX: Data Validation
    local validation = self:ValidateSprayData(sprayData)
    if not validation.valid then
        TriggerClientEvent('QBCore:Notify', source, validation.reason, 'error')
        Debug:Log("SPRAY", "Spray validation failed", {
            reason = validation.reason,
            source = source
        }, "WARN")
        Debug:EndProfile("CreateSpray")
        return false
    end
    
    -- ✅ FIX: Unique Spray ID generieren
    local sprayId = self:GenerateSprayId()
    
    -- ✅ FIX: Metadata vorbereiten
    local metadata = {
        sprayType = sprayData.sprayType or "public",
        gang = Player.PlayerData.gang and Player.PlayerData.gang.name or "public",
        gangGrade = Player.PlayerData.gang and Player.PlayerData.gang.grade.level or 0,
        creatorName = Player.PlayerData.name,
        serverTime = os.time(),
        quality = 100,
        version = "1.0.0"
    }
    
    -- ✅ FIX: Spray Data Structure erstellen
    local fullSprayData = self:CreateSprayDataStructure(sprayId, source, sprayData, metadata)
    
    -- ✅ FIX: Database Insert mit DatabaseSchema Helper
    if DatabaseSchema and DatabaseSchema.SafeInsertSpray then
        DatabaseSchema:SafeInsertSpray(fullSprayData, function(result)
            if result and result.affectedRows > 0 then
                -- ✅ FIX: Active Sprays Cache aktualisieren
                self.activeSprays[sprayId] = fullSprayData
                
                -- ✅ FIX: Statistics aktualisieren
                self:UpdateStatisticsOnCreate(fullSprayData)
                
                -- ✅ FIX: Clients benachrichtigen
                self:NotifyClientsSprayCreated(fullSprayData)
                
                TriggerClientEvent('QBCore:Notify', source, 'Spray erfolgreich erstellt!', 'success')
                
                Debug:Log("SPRAY", "Spray created successfully", {
                    sprayId = sprayId,
                    gang = fullSprayData.gang_name,
                    citizenid = fullSprayData.citizenid
                }, "SUCCESS")
            else
                Debug:Log("SPRAY", "Database insert failed", {
                    sprayId = sprayId,
                    result = result
                }, "ERROR")
                
                TriggerClientEvent('QBCore:Notify', source, 'Fehler beim Speichern des Sprays', 'error')
            end
            
            Debug:EndProfile("CreateSpray")
        end)
    else
        -- ✅ FIX: Fallback Database Insert
        exports.oxmysql:execute([[
            INSERT INTO gang_sprays 
            (spray_id, citizenid, gang_name, gang_grade, position, rotation, image_data, quality, metadata, expires_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            fullSprayData.spray_id,
            fullSprayData.citizenid,
            fullSprayData.gang_name,
            fullSprayData.gang_grade,
            json.encode(fullSprayData.position),
            fullSprayData.rotation and json.encode(fullSprayData.rotation) or nil,
            fullSprayData.image_data,
            fullSprayData.quality,
            json.encode(fullSprayData.metadata),
            fullSprayData.expires_at
        }, function(result)
            if result and result.affectedRows > 0 then
                -- ✅ FIX: Active Sprays Cache aktualisieren
                self.activeSprays[sprayId] = fullSprayData
                
                -- ✅ FIX: Statistics aktualisieren
                self:UpdateStatisticsOnCreate(fullSprayData)
                
                -- ✅ FIX: Clients benachrichtigen
                self:NotifyClientsSprayCreated(fullSprayData)
                
                TriggerClientEvent('QBCore:Notify', source, 'Spray erfolgreich erstellt!', 'success')
                
                Debug:Log("SPRAY", "Spray created successfully", {
                    sprayId = sprayId,
                    gang = fullSprayData.gang_name,
                    citizenid = fullSprayData.citizenid
                }, "SUCCESS")
            else
                Debug:Log("SPRAY", "Database insert failed", {
                    sprayId = sprayId,
                    result = result
                }, "ERROR")
                
                TriggerClientEvent('QBCore:Notify', source, 'Fehler beim Speichern des Sprays', 'error')
            end
            
            Debug:EndProfile("CreateSpray")
        end)
    end
    
    return true
end

-- ✅ FIX: Player Sprays abrufen mit sicheren Queries
RegisterNetEvent('spray:server:getPlayerSprays', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then 
        Debug:Log("SPRAY", "Invalid player for getPlayerSprays", {source = src}, "ERROR")
        return 
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    Debug:StartProfile("GetPlayerSprays", "DATABASE")
    
    -- ✅ FIX: Sichere Database Query für Player Sprays
    local safeQuery = [[
        SELECT spray_id, gang_name, position, created_at, expires_at
        FROM gang_sprays 
        WHERE citizenid = ? 
        AND (expires_at IS NULL OR expires_at > NOW())
        ORDER BY created_at DESC 
        LIMIT 50
    ]]
    
    exports.oxmysql:execute(safeQuery, {citizenid}, function(result)
        if result then
            -- ✅ FIX: Spray-Daten formatieren mit Default-Werten
            local formattedSprays = {}
            for _, spray in ipairs(result) do
                local sprayData = {
                    spray_id = spray.spray_id,
                    gang_name = spray.gang_name,
                    position = type(spray.position) == "string" and SpraySystem:SafeJsonDecode(spray.position) or spray.position,
                    quality = 100, -- Default für fehlende Spalte
                    views = 0,     -- Default für fehlende Spalte
                    created_at = SpraySystem:ParseTimestamp(spray.created_at),
                    expires_at = spray.expires_at and SpraySystem:ParseTimestamp(spray.expires_at) or nil,
                    metadata = nil  -- Default für fehlende Spalte
                }
                
                table.insert(formattedSprays, sprayData)
            end
            
            -- Versuche erweiterte Daten für jeden Spray zu laden
            SpraySystem:LoadExtendedDataForSprays(formattedSprays, function(enhancedSprays)
                -- ✅ FIX: Daten an Client senden
                TriggerClientEvent('spray:client:receivePlayerSprays', src, enhancedSprays)
                
                Debug:Log("SPRAY", "Player sprays sent", {
                    citizenid = citizenid,
                    count = #enhancedSprays
                }, "INFO")
                
                Debug:EndProfile("GetPlayerSprays")
            end)
        else
            -- ✅ FIX: Leere Liste senden bei Fehler
            TriggerClientEvent('spray:client:receivePlayerSprays', src, {})
            
            Debug:Log("SPRAY", "Failed to get player sprays", {
                citizenid = citizenid
            }, "ERROR")
            
            Debug:EndProfile("GetPlayerSprays")
        end
    end)
end)

-- ✅ FIX: Erweiterte Daten für mehrere Sprays laden
function SpraySystem:LoadExtendedDataForSprays(sprays, callback)
    if #sprays == 0 then
        callback(sprays)
        return
    end
    
    local completedCount = 0
    local totalCount = #sprays
    
    for i, spray in ipairs(sprays) do
        self:TryLoadExtendedData(spray.spray_id, function(extendedData)
            if extendedData then
                -- Erweiterte Daten hinzufügen
                spray.quality = extendedData.quality or 100
                spray.views = extendedData.views or 0
                spray.metadata = extendedData.metadata
            end
            
            completedCount = completedCount + 1
            
            -- Alle Sprays verarbeitet?
            if completedCount >= totalCount then
                callback(sprays)
            end
        end)
    end
end

-- ✅ FIX: Spray entfernen mit verbesserter Logik
function SpraySystem:RemoveSpray(source, sprayId, reason, useRemoverItem)
    Debug:StartProfile("RemoveSpray", "SPRAY")
    
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        Debug:EndProfile("RemoveSpray")
        return false
    end
    
    -- ✅ FIX: Spray existiert prüfen
    local sprayData = self.activeSprays[sprayId]
    if not sprayData then
        TriggerClientEvent('QBCore:Notify', source, 'Spray nicht gefunden', 'error')
        Debug:EndProfile("RemoveSpray")
        return false
    end
    
    -- ✅ FIX: Permission Check
    local hasPermission, permissionReason = GangPermissions:CanRemoveSpray(source, sprayData)
    if not hasPermission then
        TriggerClientEvent('QBCore:Notify', source, permissionReason, 'error')
        Debug:Log("SPRAY", "Spray removal denied", {
            sprayId = sprayId,
            reason = permissionReason,
            source = source
        }, "WARN")
        Debug:EndProfile("RemoveSpray")
        return false
    end
    
    -- ✅ FIX: Item Consumption bei Remover Item
    if useRemoverItem then
        local itemConsumed = GangPermissions:ConsumeSprayRemoverUse(source)
        if not itemConsumed then
            Debug:Log("SPRAY", "Remover item consumption failed", {
                sprayId = sprayId,
                source = source
            }, "WARN")
        end
    end
    
    -- ✅ FIX: Database Delete
    exports.oxmysql:execute('DELETE FROM gang_sprays WHERE spray_id = ?', {sprayId}, function(result)
        if result and result.affectedRows > 0 then
            -- ✅ FIX: Cache entfernen
            self.activeSprays[sprayId] = nil
            
            -- ✅ FIX: Statistics aktualisieren
            self:UpdateStatisticsOnRemove(sprayData, reason, useRemoverItem)
            
            -- ✅ FIX: Clients benachrichtigen
            self:NotifyClientsSprayRemoved(sprayId)
            
            TriggerClientEvent('QBCore:Notify', source, 'Spray entfernt', 'success')
            
            Debug:Log("SPRAY", "Spray removed successfully", {
                sprayId = sprayId,
                reason = reason,
                useRemoverItem = useRemoverItem
            }, "SUCCESS")
        else
            Debug:Log("SPRAY", "Database delete failed", {
                sprayId = sprayId,
                result = result
            }, "ERROR")
        end
        
        Debug:EndProfile("RemoveSpray")
    end)
    
    return true
end

-- ✅ FIX: Spray Data Validation
function SpraySystem:ValidateSprayData(sprayData)
    -- Basic Structure Check
    if not sprayData or type(sprayData) ~= "table" then
        return {valid = false, reason = "Ungültige Spray-Daten"}
    end
    
    -- Image Data Check
    if not sprayData.imageData or type(sprayData.imageData) ~= "string" then
        return {valid = false, reason = "Bild-Daten fehlen"}
    end
    
    -- Size Limit Check
    if #sprayData.imageData > self.maxSpraySize then
        return {valid = false, reason = "Bild zu groß (Max: 5MB)"}
    end
    
    -- Coordinates Check
    if not sprayData.coords or type(sprayData.coords) ~= "table" then
        return {valid = false, reason = "Position fehlt"}
    end
    
    if not sprayData.coords.x or not sprayData.coords.y or not sprayData.coords.z then
        return {valid = false, reason = "Ungültige Position"}
    end
    
    -- Additional Validations
    local locationValidation = self:ValidateLocation(sprayData.coords)
    if not locationValidation.valid then
        return locationValidation
    end
    
    local quotaValidation = self:ValidateQuota(sprayData)
    if not quotaValidation.valid then
        return quotaValidation
    end
    
    return {valid = true}
end

-- ✅ FIX: Location Validation
function SpraySystem:ValidateLocation(coords)
    -- Area Restrictions prüfen
    for _, zone in ipairs(Config.Permissions.neutralZones or {}) do
        local distance = #(coords - zone.coords)
        if distance < zone.radius then
            return {
                valid = false,
                reason = "Sprays in diesem Bereich nicht erlaubt"
            }
        end
    end
    
    -- Minimum Distance Check zu anderen Sprays
    local minDistance = Config.Performance.minimumSprayDistance or 5.0
    for _, spray in pairs(self.activeSprays) do
        if spray.position and spray.position.x and spray.position.y and spray.position.z then
            local distance = math.sqrt(
                (coords.x - spray.position.x)^2 + 
                (coords.y - spray.position.y)^2 + 
                (coords.z - spray.position.z)^2
            )
            
            if distance < minDistance then
                return {
                    valid = false,
                    reason = string.format("Zu nah an anderem Spray (Min: %.1fm)", minDistance)
                }
            end
        end
    end
    
    return {valid = true}
end

-- ✅ FIX: Quota Validation
function SpraySystem:ValidateQuota(sprayData)
    -- Global Spray Limit
    if self.statistics.totalSprays >= (Config.Performance.maxTotalSprays or 1000) then
        return {valid = false, reason = "Server Spray-Limit erreicht"}
    end
    
    -- Gang Spray Limit
    if sprayData.gang and sprayData.gang ~= "public" then
        local gangSprays = self.statistics.spraysByGang[sprayData.gang] or 0
        local maxGangSprays = Config.Gangs.Global.maxGangSpraysTotal or 50
        
        if gangSprays >= maxGangSprays then
            return {valid = false, reason = "Gang Spray-Limit erreicht"}
        end
    end
    
    return {valid = true}
end

-- ✅ FIX: Spray Data Structure erstellen (erweitert)
function SpraySystem:CreateSprayDataStructure(sprayId, source, sprayData, metadata)
    local Player = QBCore.Functions.GetPlayer(source)
    local currentTime = os.date('%Y-%m-%d %H:%M:%S')
    
    -- ✅ FIX: Berechne Ablaufzeit basierend auf Spray-Typ
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
            z = sprayData.coords.z
        },
        rotation = sprayData.rotation and {
            x = sprayData.rotation.x or 0,
            y = sprayData.rotation.y or 0,
            z = sprayData.rotation.z or 0
        } or nil,
        image_data = sprayData.imageData,
        quality = metadata.quality or 100,
        views = 0,
        metadata = metadata,
        created_at = currentTime,
        expires_at = expiresAt
    }
end

-- ✅ FIX: Statistics Update auf Create
function SpraySystem:UpdateStatisticsOnCreate(sprayData)
    self.statistics.totalSprays = self.statistics.totalSprays + 1
    self.statistics.dailyCreations = self.statistics.dailyCreations + 1
    
    if sprayData.gang_name == "public" then
        self.statistics.publicSprays = self.statistics.publicSprays + 1
    end
    
    local gangName = sprayData.gang_name
    self.statistics.spraysByGang[gangName] = (self.statistics.spraysByGang[gangName] or 0) + 1
    
    Debug:Log("SPRAY", "Statistics updated on create", {
        totalSprays = self.statistics.totalSprays,
        gang = gangName
    }, "INFO")
end

-- ✅ FIX: Statistics Update auf Remove
function SpraySystem:UpdateStatisticsOnRemove(sprayData, reason, useRemoverItem)
    self.statistics.totalSprays = math.max(0, self.statistics.totalSprays - 1)
    self.statistics.dailyRemovals = self.statistics.dailyRemovals + 1
    
    if useRemoverItem then
        self.statistics.itemRemovals = self.statistics.itemRemovals + 1
    end
    
    if sprayData.gang_name == "public" then
        self.statistics.publicSprays = math.max(0, self.statistics.publicSprays - 1)
    end
    
    local gangName = sprayData.gang_name
    if self.statistics.spraysByGang[gangName] then
        self.statistics.spraysByGang[gangName] = math.max(0, self.statistics.spraysByGang[gangName] - 1)
    end
    
    Debug:Log("SPRAY", "Statistics updated on remove", {
        totalSprays = self.statistics.totalSprays,
        reason = reason,
        gang = gangName
    }, "INFO")
end

-- ✅ FIX: Spam Protection
function SpraySystem:CheckSpamProtection(source)
    local currentTime = GetGameTimer()
    local playerSpam = self.spamProtection[source]
    
    if not playerSpam then
        self.spamProtection[source] = {
            lastAction = currentTime,
            actionCount = 1
        }
        return true
    end
    
    local timeDiff = currentTime - playerSpam.lastAction
    
    -- Reset Counter nach 60 Sekunden
    if timeDiff > 60000 then
        playerSpam.actionCount = 1
        playerSpam.lastAction = currentTime
        return true
    end
    
    -- Max 3 Aktionen in 60 Sekunden
    if playerSpam.actionCount >= 3 and timeDiff < 60000 then
        return false
    end
    
    -- Update spam protection
    playerSpam.lastAction = currentTime
    playerSpam.actionCount = playerSpam.actionCount + 1
    
    return true
end

-- ✅ FIX: Unique Spray ID generieren
function SpraySystem:GenerateSprayId()
    local timestamp = os.time()
    local random = math.random(1000, 9999)
    return string.format("spray_%d_%d", timestamp, random)
end

-- ✅ FIX: Cleanup Schedule
function SpraySystem:StartCleanupSchedule()
    CreateThread(function()
        while true do
            Wait(self.cleanupInterval)
            
            local currentTime = GetGameTimer()
            if currentTime - self.lastCleanupTime >= self.cleanupInterval then
                self:PerformCleanup()
                self.lastCleanupTime = currentTime
            end
        end
    end)
end

-- ✅ FIX: Performance Cleanup
function SpraySystem:PerformCleanup()
    Debug:StartProfile("PerformCleanup", "CLEANUP")
    
    -- Abgelaufene Sprays entfernen
    exports.oxmysql:execute([[
        DELETE FROM gang_sprays 
        WHERE expires_at IS NOT NULL AND expires_at < NOW()
    ]], {}, function(result)
        if result and result.affectedRows > 0 then
            Debug:Log("SPRAY", "Expired sprays cleaned up", {
                removedCount = result.affectedRows
            }, "INFO")
            
            -- Cache neu laden
            self:LoadActiveSprays()
        end
    end)
    
    -- Spam Protection cleanup
    local currentTime = GetGameTimer()
    for source, data in pairs(self.spamProtection) do
        if currentTime - data.lastAction > 300000 then -- 5 Minuten
            self.spamProtection[source] = nil
        end
    end
    
    -- Garbage Collection
    collectgarbage("collect")
    
    Debug:EndProfile("PerformCleanup")
end

-- ✅ FIX: Performance Monitoring
function SpraySystem:StartPerformanceMonitoring()
    CreateThread(function()
        while true do
            Wait(60000) -- Jede Minute
            
            local memUsage = collectgarbage("count")
            local activeSprayCount = self:CountTable(self.activeSprays)
            
            if memUsage > 100000 or activeSprayCount > 500 then -- Kritische Werte
                Debug:Log("SPRAY", "Performance warning", {
                    memUsage = memUsage,
                    activeSprayCount = activeSprayCount
                }, "WARN")
                
                -- Forced cleanup
                self:PerformCleanup()
            end
        end
    end)
end

-- ✅ FIX: Clients benachrichtigen
function SpraySystem:NotifyClientsSprayCreated(sprayData)
    TriggerClientEvent('spray:client:sprayCreated', -1, sprayData)
end

function SpraySystem:NotifyClientsSprayRemoved(sprayId)
    TriggerClientEvent('spray:client:sprayRemoved', -1, sprayId)
end

-- ✅ FIX: Nearby Spray Data mit Optimierung
function SpraySystem:GetNearbySprayData(coords, radius)
    local nearbySprayData = {}
    local maxRadius = radius or Config.Performance.streamingDistance or 100.0
    
    for sprayId, spray in pairs(self.activeSprays) do
        if spray.position and spray.position.x and spray.position.y and spray.position.z then
            local distance = math.sqrt(
                (coords.x - spray.position.x)^2 + 
                (coords.y - spray.position.y)^2 + 
                (coords.z - spray.position.z)^2
            )
            
            if distance <= maxRadius then
                nearbySprayData[sprayId] = {
                    data = spray,
                    distance = distance
                }
            end
        end
    end
    
    return nearbySprayData
end

-- ✅ UTILITY FUNCTIONS

-- Timestamp Parser
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

-- Table Counter
function SpraySystem:CountTable(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- ✅ FIX: Statistics mit erweiterten Metriken
function SpraySystem:GetStatistics()
    local stats = table.copy(self.statistics)
    
    -- Berechne zusätzliche Metriken
    stats.gangSprayCount = stats.totalSprays - stats.publicSprays
    stats.publicSprayPercentage = stats.totalSprays > 0 and (stats.publicSprays / stats.totalSprays) * 100 or 0
    stats.itemRemovalPercentage = stats.dailyRemovals > 0 and (stats.itemRemovals / stats.dailyRemovals) * 100 or 0
    
    -- Performance Metriken
    stats.memoryUsage = collectgarbage("count")
    stats.activeSprayCount = self:CountTable(self.activeSprays)
    stats.syncedClientsCount = self:CountTable(self.syncedClients)
    
    return stats
end

-- ✅ EVENT HANDLERS

-- Spray erstellen
RegisterNetEvent('spray:server:createSpray', function(sprayData)
    local src = source
    SpraySystem:CreateSpray(src, sprayData)
end)

-- Spray entfernen
RegisterNetEvent('spray:server:removeSpray', function(sprayId, reason, useRemoverItem)
    local src = source
    SpraySystem:RemoveSpray(src, sprayId, reason or "Manual removal", useRemoverItem or false)
end)

-- ✅ FIX: Item-basierte Entfernung Event
RegisterNetEvent('spray:server:removeSprayWithItem', function(sprayId)
    local src = source
    SpraySystem:RemoveSpray(src, sprayId, "Item removal", true)
end)

-- Nearby Spray Data Request
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

-- System Statistics Request
RegisterNetEvent('spray:server:requestSystemStats', function()
    local src = source
    local stats = SpraySystem:GetStatistics()
    TriggerClientEvent('spray:client:receiveSystemStats', src, stats)
end)

-- ✅ FIX: Save Spray Design Event
RegisterNetEvent('spray:server:saveSprayDesign', function(designData)
    local src = source
    
    if designData and designData.imageData then
        local sprayData = {
            coords = GetEntityCoords(GetPlayerPed(src)),
            imageData = designData.imageData,
            sprayType = designData.sprayType or "custom"
        }
        
        SpraySystem:CreateSpray(src, sprayData)
    end
end)

-- ✅ FIX: Use Template Event
RegisterNetEvent('spray:server:useTemplate', function(templateData)
    local src = source
    
    if templateData and templateData.templateId then
        -- Template zu Spray konvertieren
        local template = Config.Gangs.PublicTemplates and Config.Gangs.PublicTemplates[templateData.templateId]
        if not template then
            -- Gang Templates prüfen
            local Player = QBCore.Functions.GetPlayer(src)
            if Player and Player.PlayerData.gang then
                local gangConfig = Config.Gangs.AllowedGangs[Player.PlayerData.gang.name]
                if gangConfig and gangConfig.templates then
                    template = gangConfig.templates[templateData.templateId]
                end
            end
        end
        
        if template then
            local sprayData = {
                coords = GetEntityCoords(GetPlayerPed(src)),
                imageData = template.filePath, -- Template als Referenz
                sprayType = "template",
                templateId = templateData.templateId
            }
            
            SpraySystem:CreateSpray(src, sprayData)
        end
    end
end)

-- ✅ FIX: Use URL Image Event
RegisterNetEvent('spray:server:useUrlImage', function(urlData)
    local src = source
    
    if urlData and urlData.imageUrl then
        -- URL zu Base64 konvertieren (vereinfacht)
        local sprayData = {
            coords = GetEntityCoords(GetPlayerPed(src)),
            imageData = urlData.imageUrl, -- URL als Referenz
            sprayType = "url"
        }
        
        SpraySystem:CreateSpray(src, sprayData)
    end
end)

-- ✅ FIX: Admin Events
RegisterNetEvent('spray:server:adminCleanupExpired', function()
    local src = source
    
    -- Admin Check
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData.job or Player.PlayerData.job.name ~= 'admin' then
        return
    end
    
    SpraySystem:PerformCleanup()
    TriggerClientEvent('QBCore:Notify', src, 'Abgelaufene Sprays wurden entfernt', 'success')
end)

RegisterNetEvent('spray:server:adminFullCleanup', function()
    local src = source
    
    -- Admin Check
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData.job or Player.PlayerData.job.name ~= 'admin' then
        return
    end
    
    exports.oxmysql:execute('DELETE FROM gang_sprays', {}, function(result)
        if result then
            SpraySystem.activeSprays = {}
            SpraySystem:InitializeStatistics()
            
            TriggerClientEvent('spray:client:clearAllSprays', -1)
            TriggerClientEvent('QBCore:Notify', src, 'Alle Sprays wurden entfernt', 'success')
            
            Debug:Log("SPRAY", "Full cleanup performed by admin", {
                admin = Player.PlayerData.citizenid,
                removedCount = result.affectedRows
            }, "WARN")
        end
    end)
end)

-- ✅ FIX: Player Disconnect Cleanup
AddEventHandler('playerDropped', function()
    local src = source
    
    -- Cleanup Player Data
    SpraySystem.spamProtection[src] = nil
    SpraySystem.syncedClients[src] = nil
    
    Debug:Log("SPRAY", "Player data cleaned on disconnect", {source = src}, "INFO")
end)

-- ✅ FIX: Initialisierung mit Schema Fix
CreateThread(function()
    Wait(5000) -- Warte bis alle Dependencies geladen sind
    
    -- Schema Fix zuerst laden
    if not SchemaFix then
        Debug:Log("SPRAY", "SchemaFix module not loaded, using basic initialization", nil, "WARN")
        SpraySystem:ContinueInitialization()
        return
    end
    
    -- Schema Migration starten
    SpraySystem:Initialize()
end)

Debug:Log("SPRAY", "Spray system server loaded", nil, "SUCCESS")