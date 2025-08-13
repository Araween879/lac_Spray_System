-- Database Schema und Migration für FiveM Gang Spray System
-- Kompatibel mit älteren MySQL/MariaDB Versionen (5.6+)

-- Database Schema Creation und Migration
local DatabaseSchema = {}

-- Haupttabelle für Spray-Daten (ohne erweiterte JSON-Indizes)
local SPRAY_TABLE_SQL = [[
    CREATE TABLE IF NOT EXISTS `gang_sprays` (
        `id` INT(11) NOT NULL AUTO_INCREMENT,
        `spray_id` VARCHAR(64) NOT NULL UNIQUE,
        `citizenid` VARCHAR(50) NOT NULL,
        `gang_name` VARCHAR(50) NOT NULL,
        `gang_grade` INT(11) DEFAULT 0,
        `position` TEXT NOT NULL COMMENT 'JSON Position: {x, y, z, heading, normal}',
        `texture_data` LONGTEXT COMMENT 'Base64 texture data oder URL',
        `texture_type` ENUM('url', 'base64', 'preset') DEFAULT 'preset',
        `texture_hash` VARCHAR(64) COMMENT 'MD5 Hash für Duplikat-Erkennung',
        `metadata` TEXT COMMENT 'JSON Zusätzliche Metadaten',
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `expires_at` TIMESTAMP NULL COMMENT 'Automatisches Ablaufdatum',
        `last_modified` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        `quality` INT(3) DEFAULT 100 COMMENT 'Spray-Qualität (0-100)',
        `views` INT(11) DEFAULT 0 COMMENT 'Anzahl der Betrachtungen',
        PRIMARY KEY (`id`),
        UNIQUE KEY `uk_spray_id` (`spray_id`),
        INDEX `idx_gang` (`gang_name`),
        INDEX `idx_citizenid` (`citizenid`),
        INDEX `idx_expires` (`expires_at`),
        INDEX `idx_created` (`created_at`),
        INDEX `idx_gang_active` (`gang_name`, `expires_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
    COMMENT='Gang Spray System - Haupttabelle für alle Spray-Daten'
]]

-- Texture Cache Tabelle für Performance
local TEXTURE_CACHE_SQL = [[
    CREATE TABLE IF NOT EXISTS `spray_texture_cache` (
        `texture_id` VARCHAR(64) NOT NULL,
        `texture_data` LONGBLOB NOT NULL,
        `mime_type` VARCHAR(50) NOT NULL,
        `file_size` INT(11) NOT NULL,
        `compression_ratio` DECIMAL(3,2) DEFAULT 1.00,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `last_accessed` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        `access_count` INT(11) DEFAULT 0,
        PRIMARY KEY (`texture_id`),
        INDEX `idx_last_accessed` (`last_accessed`),
        INDEX `idx_file_size` (`file_size`),
        INDEX `idx_access_count` (`access_count`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    COMMENT='Texture Cache für häufig verwendete Spray-Texturen'
]]

-- Spam Protection und Rate Limiting Tabelle
local RATE_LIMIT_SQL = [[
    CREATE TABLE IF NOT EXISTS `spray_rate_limits` (
        `citizenid` VARCHAR(50) NOT NULL,
        `action_type` ENUM('create', 'remove', 'modify') NOT NULL,
        `action_count` INT(11) DEFAULT 1,
        `first_action` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `last_action` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        `blocked_until` TIMESTAMP NULL COMMENT 'Temp-Ban bis zu diesem Zeitpunkt',
        PRIMARY KEY (`citizenid`, `action_type`),
        INDEX `idx_blocked_until` (`blocked_until`),
        INDEX `idx_last_action` (`last_action`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    COMMENT='Rate Limiting und Anti-Spam Protection'
]]

-- Audit Log für Administrative Zwecke
local AUDIT_LOG_SQL = [[
    CREATE TABLE IF NOT EXISTS `spray_audit_log` (
        `id` INT(11) NOT NULL AUTO_INCREMENT,
        `action` VARCHAR(50) NOT NULL,
        `spray_id` VARCHAR(64),
        `citizenid` VARCHAR(50) NOT NULL,
        `target_citizenid` VARCHAR(50) COMMENT 'Bei Admin-Aktionen',
        `gang_name` VARCHAR(50),
        `action_data` TEXT COMMENT 'JSON Detaillierte Aktionsdaten',
        `ip_address` VARCHAR(45) COMMENT 'IP für Sicherheit',
        `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        INDEX `idx_citizenid` (`citizenid`),
        INDEX `idx_spray_id` (`spray_id`),
        INDEX `idx_action` (`action`),
        INDEX `idx_timestamp` (`timestamp`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    COMMENT='Audit-Log für alle Spray-Aktionen'
]]

-- Performance Statistics Tabelle
local PERFORMANCE_STATS_SQL = [[
    CREATE TABLE IF NOT EXISTS `spray_performance_stats` (
        `id` INT(11) NOT NULL AUTO_INCREMENT,
        `metric_name` VARCHAR(100) NOT NULL,
        `metric_value` DECIMAL(10,4) NOT NULL,
        `metric_unit` VARCHAR(20) DEFAULT 'ms',
        `server_id` VARCHAR(50) DEFAULT 'default',
        `player_count` INT(11),
        `spray_count` INT(11),
        `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        INDEX `idx_metric_name` (`metric_name`),
        INDEX `idx_timestamp` (`timestamp`),
        INDEX `idx_server_id` (`server_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    COMMENT='Performance-Metriken für Monitoring'
]]

-- Database Migration System (angepasst für kompatible Versionen)
function DatabaseSchema:CreateTables()
    Debug:StartProfile("DatabaseSchema_CreateTables", "DATABASE")
    
    local tables = {
        {name = "gang_sprays", sql = SPRAY_TABLE_SQL},
        {name = "spray_texture_cache", sql = TEXTURE_CACHE_SQL},
        {name = "spray_rate_limits", sql = RATE_LIMIT_SQL},
        {name = "spray_audit_log", sql = AUDIT_LOG_SQL},
        {name = "spray_performance_stats", sql = PERFORMANCE_STATS_SQL}
    }
    
    local successCount = 0
    local totalTables = #tables
    
    for _, table in ipairs(tables) do
        exports.oxmysql:execute(table.sql, {}, function(result)
            if result ~= nil then -- Erfolg auch bei leerem Result
                successCount = successCount + 1
                Debug:Log("DATABASE", string.format("Table '%s' created/verified successfully", table.name), nil, "SUCCESS")
            else
                Debug:Log("DATABASE", string.format("Failed to create table '%s'", table.name), table.sql, "ERROR")
            end
            
            -- Prüfe ob alle Tabellen verarbeitet wurden
            if successCount == totalTables then
                Debug:Log("DATABASE", "All database tables initialized successfully", {
                    tablesCreated = successCount,
                    totalTables = totalTables
                }, "SUCCESS")
                
                -- Führe Post-Migration Optimierungen durch
                DatabaseSchema:OptimizeTables()
            end
        end)
    end
    
    Debug:EndProfile("DatabaseSchema_CreateTables")
end

-- Database Optimization nach Schema-Erstellung (kompatible Version)
function DatabaseSchema:OptimizeTables()
    Debug:StartProfile("DatabaseSchema_OptimizeTables", "DATABASE")
    
    -- ANALYZE TABLE für bessere Query-Performance
    local optimizationQueries = {
        "ANALYZE TABLE gang_sprays, spray_texture_cache, spray_rate_limits",
        -- Einfache Views ohne erweiterte JSON-Funktionen
        [[
        CREATE OR REPLACE VIEW active_sprays AS 
        SELECT * FROM gang_sprays 
        WHERE expires_at IS NULL OR expires_at > NOW()
        ]],
        -- Performance View für Gang-Statistiken
        [[
        CREATE OR REPLACE VIEW gang_spray_stats AS
        SELECT 
            gang_name,
            COUNT(*) as spray_count,
            AVG(quality) as avg_quality,
            MAX(created_at) as last_spray,
            SUM(views) as total_views
        FROM gang_sprays 
        WHERE expires_at IS NULL OR expires_at > NOW()
        GROUP BY gang_name
        ]]
    }
    
    for i, query in ipairs(optimizationQueries) do
        exports.oxmysql:execute(query, {}, function(result)
            if result ~= nil then
                Debug:Log("DATABASE", string.format("Optimization query %d completed", i), nil, "SUCCESS")
            else
                Debug:Log("DATABASE", string.format("Optimization query %d failed", i), query, "WARN")
            end
        end)
    end
    
    Debug:EndProfile("DatabaseSchema_OptimizeTables")
end

-- Schema Version Management für Updates
function DatabaseSchema:CheckSchemaVersion()
    Debug:StartProfile("DatabaseSchema_CheckVersion", "DATABASE")
    
    exports.oxmysql:execute("SELECT VERSION() as mysql_version", {}, function(result)
        if result and result[1] then
            local version = result[1].mysql_version
            Debug:Log("DATABASE", "MySQL Version detected", {version = version}, "INFO")
            
            -- Version-spezifische Optimierungen (vereinfacht)
            if string.find(version, "8.0") or string.find(version, "5.7") then
                -- MySQL 5.7+ Features verfügbar
                DatabaseSchema:ApplyModernOptimizations()
            else
                -- Fallback für ältere Versionen
                DatabaseSchema:ApplyLegacyOptimizations()
            end
        end
    end)
    
    Debug:EndProfile("DatabaseSchema_CheckVersion")
end

-- Moderne Optimierungen für MySQL 5.7+
function DatabaseSchema:ApplyModernOptimizations()
    local optimizations = {
        -- JSON-basierte Position-Indizes (falls unterstützt)
        "ALTER TABLE gang_sprays ADD INDEX idx_pos_x ((CAST(JSON_UNQUOTE(JSON_EXTRACT(position, '$.x')) AS DECIMAL(10,2))))",
        "ALTER TABLE gang_sprays ADD INDEX idx_pos_y ((CAST(JSON_UNQUOTE(JSON_EXTRACT(position, '$.y')) AS DECIMAL(10,2))))"
    }
    
    for _, query in ipairs(optimizations) do
        exports.oxmysql:execute(query, {}, function(result)
            if result ~= nil then
                Debug:Log("DATABASE", "Modern optimization applied", nil, "SUCCESS")
            else
                Debug:Log("DATABASE", "Modern optimization failed (may not be supported)", nil, "INFO")
            end
        end)
    end
end

-- Legacy Optimierungen für ältere MySQL-Versionen
function DatabaseSchema:ApplyLegacyOptimizations()
    -- Für ältere Versionen: Stored Procedures für häufige Queries
    local legacyOptimizations = {
        -- Cleanup Procedure
        [[
        DROP PROCEDURE IF EXISTS CleanupExpiredSprayData
        ]],
        [[
        CREATE PROCEDURE CleanupExpiredSprayData()
        BEGIN
            DELETE FROM gang_sprays 
            WHERE expires_at IS NOT NULL 
            AND expires_at < NOW()
            LIMIT 100;
        END
        ]]
    }
    
    for _, query in ipairs(legacyOptimizations) do
        exports.oxmysql:execute(query, {}, function(result)
            if result ~= nil then
                Debug:Log("DATABASE", "Legacy optimization applied", nil, "SUCCESS")
            end
        end)
    end
end

-- Position-basierte Suche (kompatible Version ohne JSON-Indizes)
function DatabaseSchema:GetNearbySprayData(centerCoords, radius, callback)
    Debug:StartProfile("DatabaseSchema_GetNearbySprayData", "DATABASE")
    
    -- Nutze String-Parsing statt JSON-Funktionen für bessere Kompatibilität
    local query = [[
        SELECT *, 
               CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(position, '"x":', -1), ',', 1) AS DECIMAL(10,2)) as pos_x,
               CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(position, '"y":', -1), ',', 1) AS DECIMAL(10,2)) as pos_y
        FROM gang_sprays 
        WHERE (expires_at IS NULL OR expires_at > NOW())
        AND position LIKE CONCAT('%"x":', ?, '%')
        HAVING pos_x BETWEEN ? AND ?
        AND pos_y BETWEEN ? AND ?
        ORDER BY 
            (POW(pos_x - ?, 2) + POW(pos_y - ?, 2))
        LIMIT 50
    ]]
    
    local minX = centerCoords.x - radius
    local maxX = centerCoords.x + radius
    local minY = centerCoords.y - radius
    local maxY = centerCoords.y + radius
    
    exports.oxmysql:execute(query, {
        string.format('%.2f', centerCoords.x),
        minX, maxX, minY, maxY,
        centerCoords.x, centerCoords.y
    }, function(result)
        if callback then
            callback(result or {})
        end
    end)
    
    Debug:EndProfile("DatabaseSchema_GetNearbySprayData")
end

-- Cleanup alte Sprays (Scheduled Task) - verbesserte Kompatibilität
function DatabaseSchema:CleanupExpiredSprays()
    Debug:StartProfile("DatabaseSchema_CleanupExpiredSprays", "DATABASE")
    
    exports.oxmysql:execute([[
        DELETE FROM gang_sprays 
        WHERE expires_at IS NOT NULL 
        AND expires_at < NOW()
        LIMIT 100
    ]], {}, function(result)
        if result and result.affectedRows then
            if result.affectedRows > 0 then
                Debug:Log("DATABASE", "Expired sprays cleaned up", {
                    deletedSprays = result.affectedRows
                }, "SUCCESS")
                
                -- Log für Audit (vereinfacht)
                DatabaseSchema:LogAuditAction("SYSTEM_CLEANUP", "system", nil, {
                    deletedCount = result.affectedRows,
                    reason = "Automatic cleanup of expired sprays"
                })
            end
        end
    end)
    
    Debug:EndProfile("DatabaseSchema_CleanupExpiredSprays")
end

-- Audit Logging Helper (vereinfacht für Kompatibilität)
function DatabaseSchema:LogAuditAction(action, citizenid, sprayId, actionData)
    local auditData = {
        action = action,
        citizenid = citizenid,
        spray_id = sprayId,
        action_data = type(actionData) == "table" and json.encode(actionData) or tostring(actionData or ""),
        timestamp = os.date('%Y-%m-%d %H:%M:%S')
    }
    
    exports.oxmysql:insert('INSERT INTO spray_audit_log (action, citizenid, spray_id, action_data) VALUES (?, ?, ?, ?)', {
        auditData.action,
        auditData.citizenid,
        auditData.spray_id,
        auditData.action_data
    }, function(insertId)
        if insertId then
            Debug:Log("DATABASE", "Audit log entry created", {insertId = insertId}, "INFO")
        end
    end)
end

-- Performance Monitoring (vereinfacht)
function DatabaseSchema:LogPerformanceMetric(metricName, value, unit, additionalData)
    if not Config.Debug.enabled then return end
    
    local playerCount = GetNumPlayerIndices()
    
    exports.oxmysql:insert([[
        INSERT INTO spray_performance_stats 
        (metric_name, metric_value, metric_unit, player_count, spray_count) 
        VALUES (?, ?, ?, ?, ?)
    ]], {
        metricName,
        value,
        unit or 'ms',
        playerCount,
        additionalData and additionalData.sprayCount or 0
    }, function(insertId)
        if insertId then
            Debug:Log("DATABASE", "Performance metric logged", {metric = metricName, value = value}, "INFO")
        end
    end)
end

-- Initialisierung beim Server-Start
CreateThread(function()
    -- Warte bis MySQL bereit ist
    while GetResourceState('oxmysql') ~= 'started' do
        Wait(100)
    end
    
    Debug:Log("DATABASE", "MySQL connection established", nil, "SUCCESS")
    
    -- Erstelle Database Schema
    DatabaseSchema:CreateTables()
    
    -- Prüfe MySQL Version
    DatabaseSchema:CheckSchemaVersion()
    
    -- Starte Cleanup-Timer (alle 30 Minuten)
    CreateThread(function()
        while true do
            Wait(30 * 60 * 1000) -- 30 Minuten
            DatabaseSchema:CleanupExpiredSprays()
        end
    end)
    
    Debug:Log("DATABASE", "Database schema initialization completed", nil, "SUCCESS")
end)

-- Export für andere Module
return DatabaseSchema