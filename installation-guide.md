# FiveM Gang Spray System - Installation & Setup Guide

## 📋 Voraussetzungen

### Server-Requirements
- **FiveM Server Build**: 4752 oder höher
- **MySQL/MariaDB**: Version 8.0+ empfohlen
- **Node.js**: Version 16+ (für CORS Proxy)
- **RAM**: Mindestens 4GB verfügbar
- **CPU**: Quad-Core empfohlen

### Abhängige Resources
- **qb-core**: Aktuellste Version
- **oxmysql**: Aktuellste Version  
- **ox_lib**: Aktuellste Version
- **object_gizmo**: Für präzise Spray-Platzierung

## 🚀 Schritt-für-Schritt Installation

### 1. Resource-Installation

```bash
# 1. Download und entpacke das Spray-System in deinen resources Ordner
cd /pfad/zu/deinem/server/resources

# 2. Erstelle den spray-system Ordner
mkdir spray-system

# 3. Kopiere alle Dateien in den Ordner entsprechend der Struktur:
spray-system/
├── fxmanifest.lua
├── config/
│   ├── main.lua
│   └── gangs.lua
├── shared/
│   └── debug.lua
├── client/
│   ├── core/
│   │   └── dui_manager.lua
│   ├── spray/
│   │   ├── raycast.lua
│   │   ├── placement.lua
│   │   ├── cache.lua
│   │   └── renderer.lua
│   └── ui/
│       └── spray_menu.lua
├── server/
│   ├── database/
│   │   └── schema.lua
│   ├── permissions/
│   │   └── gang_handler.lua
│   └── spray/
│       └── main.lua
└── html/
    ├── index.html
    ├── css/
    │   └── style.css
    ├── js/
    │   ├── spray-editor.js
    │   ├── template-manager.js
    │   └── performance-monitor.js
    └── presets/
        └── (Template-Bilder)
```

### 2. Database Setup

```sql
-- Führe diese SQL-Befehle in deiner MySQL/MariaDB Datenbank aus:

-- 1. Haupttabelle für Spray-Daten
CREATE TABLE IF NOT EXISTS `gang_sprays` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `spray_id` VARCHAR(64) NOT NULL UNIQUE,
    `citizenid` VARCHAR(50) NOT NULL,
    `gang_name` VARCHAR(50) NOT NULL,
    `gang_grade` INT(11) DEFAULT 0,
    `position` JSON NOT NULL,
    `texture_data` LONGTEXT,
    `texture_type` ENUM('url', 'base64', 'preset') DEFAULT 'preset',
    `texture_hash` VARCHAR(64),
    `metadata` JSON,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `expires_at` TIMESTAMP NULL,
    `last_modified` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `quality` INT(3) DEFAULT 100,
    `views` INT(11) DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_spray_id` (`spray_id`),
    INDEX `idx_gang` (`gang_name`),
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_expires` (`expires_at`),
    INDEX `idx_position_x` ((CAST(`position`->>'$.x' AS DECIMAL(10,2)))),
    INDEX `idx_position_y` ((CAST(`position`->>'$.y' AS DECIMAL(10,2)))),
    INDEX `idx_gang_active` (`gang_name`, `expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Texture Cache Tabelle
CREATE TABLE IF NOT EXISTS `spray_texture_cache` (
    `texture_id` VARCHAR(64) NOT NULL,
    `texture_data` LONGBLOB NOT NULL,
    `mime_type` VARCHAR(50) NOT NULL,
    `file_size` INT(11) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `last_accessed` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `access_count` INT(11) DEFAULT 0,
    PRIMARY KEY (`texture_id`),
    INDEX `idx_last_accessed` (`last_accessed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Rate Limiting Tabelle
CREATE TABLE IF NOT EXISTS `spray_rate_limits` (
    `citizenid` VARCHAR(50) NOT NULL,
    `action_type` ENUM('create', 'remove', 'modify') NOT NULL,
    `action_count` INT(11) DEFAULT 1,
    `first_action` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `last_action` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `blocked_until` TIMESTAMP NULL,
    PRIMARY KEY (`citizenid`, `action_type`),
    INDEX `idx_blocked_until` (`blocked_until`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Audit Log Tabelle
CREATE TABLE IF NOT EXISTS `spray_audit_log` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `action` VARCHAR(50) NOT NULL,
    `spray_id` VARCHAR(64),
    `citizenid` VARCHAR(50) NOT NULL,
    `gang_name` VARCHAR(50),
    `action_data` JSON,
    `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_spray_id` (`spray_id`),
    INDEX `idx_timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 3. CORS Proxy Setup (für URL-Bilder)

```bash
# 1. Erstelle einen neuen Ordner für den Proxy
mkdir cors-proxy
cd cors-proxy

# 2. Initialisiere NPM Projekt
npm init -y

# 3. Installiere Dependencies
npm install express cors axios sharp

# 4. Erstelle server.js (siehe cors-proxy/server.js Inhalt)
# 5. Starte den Proxy-Server
node server.js
```

### 4. Items zu QB-Core hinzufügen

```sql
-- Füge diese Items zu deiner `items` Tabelle hinzu:

INSERT INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`, `type`, `useable`, `shouldClose`, `combinable`, `description`, `image`) VALUES
('spray_can', 'Spray Dose', 500, 0, 1, 'item', 1, 1, NULL, 'Gang Spray für Territory Marking', 'spray_can.png'),
('spray_remover', 'Spray Entferner', 300, 0, 1, 'item', 1, 1, NULL, 'Entfernt Graffiti von Oberflächen', 'spray_remover.png');
```

### 5. Server.cfg Konfiguration

```bash
# Füge diese Zeilen zu deiner server.cfg hinzu:

# Gang Spray System
ensure oxmysql
ensure ox_lib  
ensure qb-core
ensure object_gizmo
ensure spray-system

# Performance Optimierungen
set sv_enforceGameBuild 2699
set onesync on
set onesync_enableInfinity 1
set onesync_distanceCulling true
set onesync_distanceCullVehicles true

# Spray System spezifische ConVars
set spray_debug 0                    # Debug-Modus (0 = aus, 1 = an)
set spray_max_memory 150            # Memory-Limit in MB
set spray_cleanup_interval 300      # Cleanup-Intervall in Sekunden
```

### 6. Template-Bilder hinzufügen

```bash
# Erstelle Template-Bilder in html/presets/
# Empfohlene Auflösung: 512x512 oder 1024x1024 PNG
# Dateien benennen nach Template-IDs:

html/presets/
├── default.png          # Fallback-Template
├── vagos_01.png        # Vagos Logo
├── vagos_02.png        # Vagos Territory
├── ballas_01.png       # Ballas Crown
├── families_01.png     # Families Logo
├── grove_01.png        # Grove Street Logo
└── police_01.png       # Police Badge (optional)
```

## ⚙️ Konfiguration

### 1. Gang-Konfiguration anpassen

Bearbeite `config/gangs.lua`:

```lua
-- Passe Gang-Namen an deine Server-Gangs an
Config.Gangs.AllowedGangs = {
    ['deine_gang_1'] = {
        name = 'Deine Gang 1',
        color = '#FF0000',
        primaryColors = {'#FF0000', '#CC0000', '#990000'},
        templates = {'deine_gang_1_logo', 'deine_gang_1_territory'},
        -- ... weitere Einstellungen
    },
    -- Weitere Gangs...
}
```

### 2. Performance-Tuning

Bearbeite `config/main.lua`:

```lua
-- Passe an deine Server-Performance an
Config.Performance = {
    maxConcurrentDUIs = 8,           -- Reduziere für schwächere Server
    maxSpraysPerPlayer = 3,          -- Limit pro Spieler
    maxTotalSprays = 150,            -- Gesamtlimit
    textureResolution = 512,         -- Reduziere für bessere Performance
    streamingDistance = 100.0,       -- Reduziere Render-Distanz
    memoryThreshold = 100 * 1024 * 1024  -- 100MB für kleinere Server
}
```

### 3. Permission-System

Bearbeite die Gang-Ränge in `config/gangs.lua`:

```lua
-- Passe minimumGrade an deine Gang-Hierarchie an
minimumGrade = 1,  -- 0 = Recruit, 1 = Member, 2 = Lieutenant, 3 = Boss
```

## 🧪 Testing & Debugging

### 1. Funktions-Tests

```bash
# Starte den Server und teste:

# 1. Basic Commands
/spray                    # Öffnet Spray-Menü
/spray_debug             # Aktiviert Debug-Modus
/spray_cache_status      # Zeigt Cache-Status
/spray_stats             # Zeigt Server-Statistiken

# 2. Admin Commands  
/spray_cleanup           # Cleanup abgelaufener Sprays
/spray_remove <spray_id> # Entfernt spezifisches Spray
```

### 2. Debug-Modus aktivieren

```lua
-- In config/main.lua:
Config.Debug = {
    enabled = true,              -- Aktiviert Debug-Logs
    verboseLogging = true,       -- Erweiterte Logs
    showPerformanceMetrics = true -- Performance-Anzeige
}
```

### 3. Häufige Probleme beheben

#### Problem: DUIs werden nicht angezeigt
```bash
# Lösung 1: Prüfe Browser-Cache
# Lösung 2: Reduziere textureResolution in config
# Lösung 3: Prüfe Memory-Limits
```

#### Problem: Database-Fehler
```bash
# Lösung 1: Prüfe MySQL-Version (8.0+ empfohlen)
# Lösung 2: Aktiviere JSON-Unterstützung  
# Lösung 3: Prüfe Charset (utf8mb4)
```

#### Problem: Performance-Issues
```bash
# Lösung 1: Reduziere maxConcurrentDUIs
# Lösung 2: Verkürze streamingDistance
# Lösung 3: Aktiviere LOD-System
```

## 📈 Performance Monitoring

### 1. Server-Monitoring

```bash
# Überwache diese Metriken:
# - Memory Usage: /spray_cache_status
# - FPS Impact: ~3-5 FPS bei 50 Sprays normal
# - Database Load: <50ms Query-Zeit
# - Network Traffic: ~2KB pro Spray
```

### 2. Client-Monitoring

```bash
# Aktiviere Performance-Overlay:
# Strg+Shift+P im Spray-Editor
# Überwache:
# - FPS: Sollte >30 bleiben
# - Memory: <150MB Client-Memory
# - Render-Zeit: <16ms pro Frame
```

## 🔒 Sicherheits-Checkliste

- [ ] **Rate Limiting aktiviert** (Config.RateLimit)
- [ ] **Input Validation aktiv** (Server + Client)
- [ ] **CORS Proxy konfiguriert** (Nur erlaubte Domains)
- [ ] **SQL Injection Schutz** (Prepared Statements)
- [ ] **Memory Limits gesetzt** (Config.Performance)
- [ ] **File Size Limits aktiv** (Max 5MB Bilder)
- [ ] **Gang Permissions korrekt** (Mindest-Ränge)
- [ ] **Audit Logging aktiviert** (spray_audit_log)

## 🎯 Post-Installation

### 1. Gang-Templates erstellen
1. Erstelle PNG-Bilder für jede Gang (512x512px empfohlen)
2. Speichere in `html/presets/` mit korrekten Namen
3. Aktualisiere `config/gangs.lua` Template-Listen
4. Teste Template-Selector im Spiel

### 2. Admin-Training
1. Erkläre `/spray_stats` für Monitoring
2. Zeige `/spray_cleanup` für Wartung  
3. Demonstriere `/spray_remove` für Moderation
4. Aktiviere Debug-Modus für Problemdiagnose

### 3. Player-Tutorial
1. Erstelle Tutorial für Spray-Menü (`/spray`)
2. Erkläre verschiedene Spray-Modi (Template, Editor, URL)
3. Zeige Gang-Territorium und Rivalitäten
4. Informiere über Item-Requirements (Spray Can)

## 🆘 Support & Troubleshooting

### Log-Dateien prüfen
```bash
# Server Console für Server-seitige Errors
# F8 Console für Client-seitige Errors
# MySQL Logs für Database-Issues
# Browser Dev Tools für NUI-Probleme
```

### Performance-Analyse
```bash
# ResProxy für Resource-Performance
# /spray_cache_status für Memory-Nutzung
# FPS Counter für Frame-Impact
# Network Monitor für Traffic-Analyse
```

Bei weiteren Problemen prüfe die Debug-Logs und Performance-Metriken für detaillierte Diagnose-Informationen.