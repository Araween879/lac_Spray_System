-- ✅ GEFIXT: Database Schema - MariaDB Kompatibel
-- Datei: server/database/schema.lua

local QBCore = exports['qb-core']:GetCoreObject()

DatabaseSchema = {
    version = "1.0.0",
    isInitialized = false,
    requiredTables = {
        "gang_sprays"
    }
}

-- ✅ FIX: MariaDB/MySQL kompatible Schema Erstellung
function DatabaseSchema:Initialize()
    Debug:Log("DATABASE", "Starting database schema initialization", nil, "INFO")
    
    -- Detect Database Version
    self:DetectDatabaseVersion()
    
    -- Create Tables
    self:CreateSprayTable()
    
    -- Verify Schema
    self:VerifySchema()
    
    -- Migration if needed
    self:RunMigrations()
    
    self.isInitialized = true
    Debug:Log("DATABASE", "Database schema initialization completed", nil, "SUCCESS")
end

-- ✅ FIX: Database Version Detection
function DatabaseSchema:DetectDatabaseVersion()
    exports.oxmysql:execute('SELECT VERSION() as version', {}, function(result)
        if result and result[1] then
            local version = result[1].version
            local isMariaDB = string.find(version:lower(), "mariadb") ~= nil
            local isMySQLOld = not isMariaDB and string.find(version, "^5%.") ~= nil
            
            DatabaseSchema.isMariaDB = isMariaDB
            DatabaseSchema.isMySQLOld = isMySQLOld
            DatabaseSchema.dbVersion = version
            
            Debug:Log("DATABASE", "Database detected", {
                version = version,
                isMariaDB = isMariaDB,
                isMySQLOld = isMySQLOld
            }, "INFO")
        end
    end)
end

-- ✅ FIX: Spray Table mit MariaDB Kompatibilität
function DatabaseSchema:CreateSprayTable()
    local sqlQuery
    
    -- ✅ FIX: MariaDB/MySQL 5.7+ kompatible Syntax
    if self.isMariaDB or self.isMySQLOld then
        -- MariaDB/Ältere MySQL Versionen
        sqlQuery = [[
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
    else
        -- MySQL 8.0+ mit JSON Support
        sqlQuery = [[
            CREATE TABLE IF NOT EXISTS gang_sprays (
                spray_id VARCHAR(255) PRIMARY KEY,
                citizenid VARCHAR(50) NOT NULL,
                gang_name VARCHAR(50) NOT NULL DEFAULT 'public',
                gang_grade INT DEFAULT 0,
                position JSON NOT NULL,
                rotation JSON DEFAULT NULL,
                image_data LONGTEXT NOT NULL,
                quality INT DEFAULT 100,
                views INT DEFAULT 0,
                metadata JSON DEFAULT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                expires_at TIMESTAMP NULL DEFAULT NULL,
                last_viewed TIMESTAMP NULL DEFAULT NULL,
                
                INDEX idx_citizenid (citizenid),
                INDEX idx_gang_name (gang_name),
                INDEX idx_created_at (created_at),
                INDEX idx_expires_at (expires_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]]
    end
    
    exports.oxmysql:execute(sqlQuery, {}, function(result)
        if result then
            Debug:Log("DATABASE", "Gang sprays table created/verified", {
                isMariaDB = self.isMariaDB,
                useJSON = not (self.isMariaDB or self.isMySQLOld)
            }, "SUCCESS")
        else
            Debug:Log("DATABASE", "Failed to create gang sprays table", nil, "ERROR")
        end
    end)
end

-- ✅ FIX: Schema Verification
function DatabaseSchema:VerifySchema()
    exports.oxmysql:execute('DESCRIBE gang_sprays', {}, function(result)
        if result then
            local columns = {}
            for _, column in ipairs(result) do
                columns[column.Field] = column.Type
            end
            
            -- Required Columns Check
            local requiredColumns = {
                'spray_id', 'citizenid', 'gang_name', 'gang_grade',
                'position', 'image_data', 'quality', 'views',
                'created_at', 'expires_at'
            }
            
            local missingColumns = {}
            for _, colName in ipairs(requiredColumns) do
                if not columns[colName] then
                    table.insert(missingColumns, colName)
                end
            end
            
            if #missingColumns > 0 then
                Debug:Log("DATABASE", "Missing required columns", {
                    missing = missingColumns
                }, "WARN")
                
                self:AddMissingColumns(missingColumns)
            else
                Debug:Log("DATABASE", "Schema verification passed", {
                    columnsFound = #result
                }, "SUCCESS")
            end
        else
            Debug:Log("DATABASE", "Table gang_sprays does not exist", nil, "ERROR")
        end
    end)
end

-- ✅ FIX: Missing Columns hinzufügen
function DatabaseSchema:AddMissingColumns(missingColumns)
    for _, columnName in ipairs(missingColumns) do
        local alterQuery = self:GetAlterQueryForColumn(columnName)
        
        if alterQuery then
            exports.oxmysql:execute(alterQuery, {}, function(result)
                if result then
                    Debug:Log("DATABASE", "Column added", {
                        column = columnName
                    }, "SUCCESS")
                else
                    Debug:Log("DATABASE", "Failed to add column", {
                        column = columnName
                    }, "ERROR")
                end
            end)
        end
    end
end

-- ✅ FIX: Alter Query für spezifische Columns
function DatabaseSchema:GetAlterQueryForColumn(columnName)
    local dataType = (self.isMariaDB or self.isMySQLOld) and 'LONGTEXT' or 'JSON'
    
    local alterQueries = {
        rotation = string.format('ALTER TABLE gang_sprays ADD COLUMN rotation %s DEFAULT NULL', dataType),
        last_viewed = 'ALTER TABLE gang_sprays ADD COLUMN last_viewed TIMESTAMP NULL DEFAULT NULL',
        metadata = string.format('ALTER TABLE gang_sprays ADD COLUMN metadata %s DEFAULT NULL', dataType),
        views = 'ALTER TABLE gang_sprays ADD COLUMN views INT DEFAULT 0',
        quality = 'ALTER TABLE gang_sprays ADD COLUMN quality INT DEFAULT 100'
    }
    
    return alterQueries[columnName]
end

-- ✅ FIX: Database Migrations
function DatabaseSchema:RunMigrations()
    -- Migration 1: Add missing indexes
    self:AddMissingIndexes()
    
    -- Migration 2: Data cleanup
    self:CleanupOldData()
end

-- ✅ FIX: Missing Indexes hinzufügen
function DatabaseSchema:AddMissingIndexes()
    local indexes = {
        {name = 'idx_citizenid', columns = 'citizenid'},
        {name = 'idx_gang_name', columns = 'gang_name'},
        {name = 'idx_created_at', columns = 'created_at'},
        {name = 'idx_expires_at', columns = 'expires_at'}
    }
    
    for _, index in ipairs(indexes) do
        local checkQuery = string.format([[
            SELECT COUNT(*) as count FROM INFORMATION_SCHEMA.STATISTICS 
            WHERE table_schema = DATABASE() 
            AND table_name = 'gang_sprays' 
            AND index_name = '%s'
        ]], index.name)
        
        exports.oxmysql:execute(checkQuery, {}, function(result)
            if result and result[1] and result[1].count == 0 then
                local createIndexQuery = string.format(
                    'CREATE INDEX %s ON gang_sprays (%s)',
                    index.name,
                    index.columns
                )
                
                exports.oxmysql:execute(createIndexQuery, {}, function(indexResult)
                    if indexResult then
                        Debug:Log("DATABASE", "Index created", {
                            indexName = index.name
                        }, "SUCCESS")
                    end
                end)
            end
        end)
    end
end

-- ✅ FIX: Old Data Cleanup
function DatabaseSchema:CleanupOldData()
    -- Remove expired sprays
    exports.oxmysql:execute([[
        DELETE FROM gang_sprays 
        WHERE expires_at IS NOT NULL AND expires_at < NOW()
    ]], {}, function(result)
        if result and result.affectedRows > 0 then
            Debug:Log("DATABASE", "Expired sprays cleaned up", {
                removedCount = result.affectedRows
            }, "INFO")
        end
    end)
end

-- ✅ FIX: JSON Helper Functions für MariaDB
DatabaseSchema.JsonHelper = {
    encode = function(data)
        if type(data) == "table" then
            return json.encode(data)
        end
        return tostring(data)
    end,
    
    decode = function(data)
        if type(data) == "string" and data ~= "" then
            local success, result = pcall(json.decode, data)
            if success then
                return result
            end
        end
        return data
    end,
    
    isSupported = function()
        return not (DatabaseSchema.isMariaDB or DatabaseSchema.isMySQLOld)
    end
}

-- ✅ FIX: Safe Query Helpers
function DatabaseSchema:SafeInsertSpray(sprayData, callback)
    local query = [[
        INSERT INTO gang_sprays 
        (spray_id, citizenid, gang_name, gang_grade, position, rotation, image_data, quality, metadata, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]
    
    local params = {
        sprayData.spray_id,
        sprayData.citizenid,
        sprayData.gang_name,
        sprayData.gang_grade,
        self.JsonHelper.encode(sprayData.position),
        sprayData.rotation and self.JsonHelper.encode(sprayData.rotation) or nil,
        sprayData.image_data,
        sprayData.quality,
        sprayData.metadata and self.JsonHelper.encode(sprayData.metadata) or nil,
        sprayData.expires_at
    }
    
    exports.oxmysql:execute(query, params, callback)
end

function DatabaseSchema:SafeSelectSprays(whereClause, params, callback)
    local query = string.format([[
        SELECT spray_id, citizenid, gang_name, gang_grade, position, rotation, 
               image_data, quality, views, metadata, created_at, expires_at, last_viewed
        FROM gang_sprays %s
    ]], whereClause or '')
    
    exports.oxmysql:execute(query, params or {}, function(result)
        if result and callback then
            -- Process JSON fields
            for _, row in ipairs(result) do
                row.position = self.JsonHelper.decode(row.position)
                row.rotation = self.JsonHelper.decode(row.rotation)
                row.metadata = self.JsonHelper.decode(row.metadata)
            end
            
            callback(result)
        elseif callback then
            callback(nil)
        end
    end)
end

-- ✅ FIX: Public API
function GetDatabaseHelper()
    return DatabaseSchema
end

-- Export für andere Scripts
_G.DatabaseSchema = DatabaseSchema

Debug:Log("DATABASE", "Database schema module loaded", nil, "SUCCESS")