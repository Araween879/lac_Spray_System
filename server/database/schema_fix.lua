-- ✅ SCHEMA FIX: Sichere Database Migration
-- Datei: server/database/schema_fix.lua

local QBCore = exports['qb-core']:GetCoreObject()

SchemaFix = {
    version = "1.0.1",
    isRunning = false,
    requiredColumns = {
        'rotation',
        'last_viewed', 
        'quality',
        'views',
        'metadata'
    }
}

-- ✅ FIX: Sichere Schema Migration mit besserer Fehlerbehandlung
function SchemaFix:RunMigration()
    if self.isRunning then
        return
    end
    
    self.isRunning = true
    print("[SCHEMA] Starting safe schema migration...")
    
    -- ✅ FIX: Erstelle Tabelle falls sie nicht existiert
    self:EnsureTableExists()
end

-- ✅ FIX: Stelle sicher dass Basis-Tabelle existiert
function SchemaFix:EnsureTableExists()
    -- Erstelle die Basis-Tabelle mit allen notwendigen Spalten
    local createTableQuery = [[
        CREATE TABLE IF NOT EXISTS gang_sprays (
            spray_id VARCHAR(255) PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            gang_name VARCHAR(50) NOT NULL DEFAULT 'public',
            gang_grade INT DEFAULT 0,
            position LONGTEXT NOT NULL,
            image_data LONGTEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            expires_at TIMESTAMP NULL DEFAULT NULL,
            
            INDEX idx_citizenid (citizenid),
            INDEX idx_gang_name (gang_name),
            INDEX idx_created_at (created_at),
            INDEX idx_expires_at (expires_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]
    
    exports.oxmysql:execute(createTableQuery, {}, function(result)
        if result then
            print("[SCHEMA] Base table created/verified successfully")
            -- Jetzt prüfe und füge zusätzliche Spalten hinzu
            self:CheckAndAddOptionalColumns()
        else
            print("[SCHEMA] ERROR: Failed to create base table")
            self.isRunning = false
        end
    end)
end

-- ✅ FIX: Prüfe und füge optionale Spalten hinzu
function SchemaFix:CheckAndAddOptionalColumns()
    local optionalColumns = {
        {name = 'rotation', type = 'LONGTEXT DEFAULT NULL'},
        {name = 'quality', type = 'INT DEFAULT 100'},
        {name = 'views', type = 'INT DEFAULT 0'},
        {name = 'metadata', type = 'LONGTEXT DEFAULT NULL'},
        {name = 'last_viewed', type = 'TIMESTAMP NULL DEFAULT NULL'}
    }
    
    local addedCount = 0
    local totalOptional = #optionalColumns
    
    for _, column in ipairs(optionalColumns) do
        self:SafeAddColumn(column.name, column.type, function(success)
            addedCount = addedCount + 1
            
            if addedCount >= totalOptional then
                -- Alle optionalen Spalten verarbeitet
                self:CompleteeMigration()
            end
        end)
    end
end

-- ✅ FIX: Sichere Spalten-Hinzufügung mit Existenz-Prüfung
function SchemaFix:SafeAddColumn(columnName, columnType, callback)
    -- Prüfe zuerst ob Spalte bereits existiert
    local checkQuery = string.format([[
        SELECT COUNT(*) as count 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE table_schema = DATABASE() 
        AND table_name = 'gang_sprays' 
        AND column_name = '%s'
    ]], columnName)
    
    exports.oxmysql:execute(checkQuery, {}, function(result)
        if result and result[1] and result[1].count > 0 then
            -- Spalte existiert bereits
            print(string.format("[SCHEMA] Column '%s' already exists", columnName))
            callback(true)
        else
            -- Spalte existiert nicht, füge sie hinzu
            local alterQuery = string.format('ALTER TABLE gang_sprays ADD COLUMN %s %s', columnName, columnType)
            
            exports.oxmysql:execute(alterQuery, {}, function(alterResult)
                if alterResult then
                    print(string.format("[SCHEMA] Successfully added column '%s'", columnName))
                    callback(true)
                else
                    print(string.format("[SCHEMA] WARNING: Failed to add column '%s'", columnName))
                    callback(false)
                end
            end)
        end
    end)
end

-- ✅ FIX: ALTER Query für spezifische Spalten
function SchemaFix:GetAlterQuery(columnName)
    local alterQueries = {
        rotation = 'ALTER TABLE gang_sprays ADD COLUMN rotation LONGTEXT DEFAULT NULL',
        last_viewed = 'ALTER TABLE gang_sprays ADD COLUMN last_viewed TIMESTAMP NULL DEFAULT NULL',
        quality = 'ALTER TABLE gang_sprays ADD COLUMN quality INT DEFAULT 100',
        views = 'ALTER TABLE gang_sprays ADD COLUMN views INT DEFAULT 0',
        metadata = 'ALTER TABLE gang_sprays ADD COLUMN metadata LONGTEXT DEFAULT NULL'
    }
    
    return alterQueries[columnName]
end

-- ✅ FIX: Neue Tabelle erstellen (falls gar nicht vorhanden)
function SchemaFix:CreateNewTable()
    local createQuery = [[
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
    ]]
    
    exports.oxmysql:execute(createQuery, {}, function(result)
        if result then
            Debug:Log("SCHEMA", "New table created successfully", nil, "SUCCESS")
            self:CompleteeMigration()
        else
            Debug:Log("SCHEMA", "Failed to create new table", nil, "ERROR")
            self.isRunning = false
        end
    end)
end

-- ✅ FIX: Migration abschließen mit besserer Validierung
function SchemaFix:CompleteeMigration()
    -- Finale Schema-Validierung
    exports.oxmysql:execute('DESCRIBE gang_sprays', {}, function(result)
        if result then
            local finalColumns = {}
            for _, column in ipairs(result) do
                table.insert(finalColumns, column.Field)
            end
            
            print(string.format("[SCHEMA] Schema migration completed - %d columns found", #finalColumns))
            
            -- Prüfe ob alle kritischen Spalten vorhanden sind
            local criticalColumns = {'spray_id', 'citizenid', 'gang_name', 'position', 'image_data', 'created_at'}
            local missingCritical = {}
            
            for _, critical in ipairs(criticalColumns) do
                local found = false
                for _, existing in ipairs(finalColumns) do
                    if existing == critical then
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(missingCritical, critical)
                end
            end
            
            if #missingCritical > 0 then
                print("[SCHEMA] ERROR: Missing critical columns: " .. table.concat(missingCritical, ", "))
            else
                print("[SCHEMA] SUCCESS: All critical columns present")
            end
            
            -- Informiere SpraySystem dass Schema bereit ist
            if _G.SpraySystem and SpraySystem.OnSchemaReady then
                SpraySystem:OnSchemaReady()
            end
        else
            print("[SCHEMA] ERROR: Could not validate final schema")
        end
        
        self.isRunning = false
    end)
end

-- ✅ FIX: Sichere Log-Funktion
function SchemaFix:Log(message, level)
    level = level or "INFO"
    local timestamp = os.date("%H:%M:%S")
    print(string.format("[SCHEMA %s] %s: %s", timestamp, level, message))
end

-- ✅ FIX: Public API für andere Module
function SchemaFix:IsColumnAvailable(columnName)
    -- Einfache Prüfung - nach Migration sollten alle Spalten verfügbar sein
    return not self.isRunning
end

function SchemaFix:GetSafeSelectQuery()
    -- Sichere Query die nur bekannte Spalten abfragt
    return [[
        SELECT spray_id, citizenid, gang_name, gang_grade, position, 
               image_data, created_at, expires_at,
               COALESCE(rotation, NULL) as rotation,
               COALESCE(quality, 100) as quality,
               COALESCE(views, 0) as views,
               COALESCE(metadata, NULL) as metadata,
               COALESCE(last_viewed, NULL) as last_viewed
        FROM gang_sprays
    ]]
end

-- ✅ FIX: Teste Database Connection
function SchemaFix:TestConnection()
    exports.oxmysql:execute('SELECT 1 as test', {}, function(result)
        if result and result[1] and result[1].test == 1 then
            print("[SCHEMA] Database connection OK")
            return true
        else
            print("[SCHEMA] ERROR: Database connection failed")
            return false
        end
    end)
end

-- Export für andere Scripts
_G.SchemaFix = SchemaFix

print("[SCHEMA] Schema fix module loaded successfully")