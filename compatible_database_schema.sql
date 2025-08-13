-- Kompatibles Database Schema für ältere MySQL/MariaDB Versionen
-- Funktioniert mit MySQL 5.6+ und MariaDB 10.2+

-- 1. Haupttabelle für Spray-Daten (ohne JSON-Indizes)
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
    -- Separate Spalten für häufige Position-Queries (bessere Performance)
    `pos_x` DECIMAL(10,2) AS (JSON_UNQUOTE(JSON_EXTRACT(position, '$.x'))) STORED,
    `pos_y` DECIMAL(10,2) AS (JSON_UNQUOTE(JSON_EXTRACT(position, '$.y'))) STORED,
    `pos_z` DECIMAL(10,2) AS (JSON_UNQUOTE(JSON_EXTRACT(position, '$.z'))) STORED,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_spray_id` (`spray_id`),
    INDEX `idx_gang` (`gang_name`),
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_expires` (`expires_at`),
    INDEX `idx_created` (`created_at`),
    INDEX `idx_position_xy` (`pos_x`, `pos_y`),
    INDEX `idx_gang_active` (`gang_name`, `expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Gang Spray System - Haupttabelle für alle Spray-Daten';

-- 2. Texture Cache Tabelle
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
COMMENT='Texture Cache für häufig verwendete Spray-Texturen';

-- 3. Rate Limiting Tabelle
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
COMMENT='Rate Limiting und Anti-Spam Protection';

-- 4. Audit Log Tabelle
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
COMMENT='Audit-Log für alle Spray-Aktionen';

-- 5. Performance Statistics Tabelle
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
COMMENT='Performance-Metriken für Monitoring';

-- 6. Optimierte Views für häufige Queries
CREATE OR REPLACE VIEW active_sprays AS 
SELECT 
    id,
    spray_id,
    citizenid,
    gang_name,
    gang_grade,
    position,
    texture_data,
    texture_type,
    texture_hash,
    metadata,
    created_at,
    expires_at,
    quality,
    views,
    pos_x,
    pos_y,
    pos_z
FROM gang_sprays 
WHERE expires_at IS NULL OR expires_at > NOW();

-- 7. View für Gang-Statistiken
CREATE OR REPLACE VIEW gang_spray_stats AS
SELECT 
    gang_name,
    COUNT(*) as spray_count,
    AVG(quality) as avg_quality,
    MAX(created_at) as last_spray,
    SUM(views) as total_views,
    MIN(pos_x) as min_x,
    MAX(pos_x) as max_x,
    MIN(pos_y) as min_y,
    MAX(pos_y) as max_y
FROM gang_sprays 
WHERE expires_at IS NULL OR expires_at > NOW()
GROUP BY gang_name;

-- 8. Stored Procedure für Position-basierte Queries (optional)
DELIMITER $$
CREATE PROCEDURE GetNearbySprayData(
    IN center_x DECIMAL(10,2),
    IN center_y DECIMAL(10,2),
    IN search_radius DECIMAL(10,2)
)
BEGIN
    SELECT 
        spray_id,
        gang_name,
        position,
        texture_data,
        texture_type,
        created_at,
        quality,
        SQRT(POWER(pos_x - center_x, 2) + POWER(pos_y - center_y, 2)) as distance
    FROM gang_sprays
    WHERE 
        (expires_at IS NULL OR expires_at > NOW())
        AND pos_x BETWEEN (center_x - search_radius) AND (center_x + search_radius)
        AND pos_y BETWEEN (center_y - search_radius) AND (center_y + search_radius)
        AND SQRT(POWER(pos_x - center_x, 2) + POWER(pos_y - center_y, 2)) <= search_radius
    ORDER BY distance;
END$$
DELIMITER ;

-- 9. Test-Daten einfügen (optional, für Testing)
INSERT INTO `gang_sprays` (
    `spray_id`, 
    `citizenid`, 
    `gang_name`, 
    `gang_grade`, 
    `position`, 
    `texture_data`, 
    `texture_type`, 
    `quality`
) VALUES (
    'test_spray_001',
    'ABC12345',
    'vagos',
    1,
    '{"x": 100.0, "y": 200.0, "z": 30.0, "rx": 0, "ry": 0, "rz": 45, "normal": {"x": 0, "y": 0, "z": 1}}',
    'vagos_01',
    'preset',
    100
);

-- 10. Optimierung ausführen
ANALYZE TABLE gang_sprays;
ANALYZE TABLE spray_texture_cache;
ANALYZE TABLE spray_rate_limits;
ANALYZE TABLE spray_audit_log;