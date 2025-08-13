# Annahmen und erforderliche Anpassungen

## 📋 Gemachte Annahmen während der Entwicklung

### 1. Server-Umgebung
**Annahme:** Standard FiveM Server mit QB-Core Framework
- **Basis:** FiveM Server Build 4752+
- **Framework:** QB-Core (aktuellste Version)
- **Database:** MySQL 8.0+ oder MariaDB 10.5+
- **Memory:** Mindestens 4GB RAM verfügbar

**Mögliche Anpassungen nötig:**
- Ältere Server-Builds benötigen eventuell Native-Anpassungen
- Andere Frameworks (ESX, etc.) erfordern komplette Neuprogrammierung
- Ältere MySQL-Versionen (< 5.7) unterstützen keine JSON-Felder

### 2. Gang-Struktur
**Annahme:** Standard QB-Core Gang-System mit folgenden Gangs:
```lua
['vagos'] = 'Los Santos Vagos'
['ballas'] = 'Ballas'  
['families'] = 'The Families'
['grove'] = 'Grove Street'
['marabunta'] = 'Marabunta Grande'
```

**Gang-Ränge angenommen:**
- 0 = Recruit/Neuling
- 1 = Member/Mitglied  
- 2 = Lieutenant/Leutnant
- 3 = Boss/Anführer

**Erforderliche Anpassungen:**
```lua
-- In config/gangs.lua alle Gang-Namen an deinen Server anpassen:
Config.Gangs.AllowedGangs = {
    ['deine_gang_1'] = {
        name = 'Deine Gang 1',
        color = '#FF0000',
        minimumGrade = 1,  -- An deine Rang-Struktur anpassen
        -- ...
    }
}
```

### 3. Item-System
**Annahme:** Standard QB-Core Items mit folgenden Namen:
- `spray_can` - Spray-Dose für Erstellung
- `spray_remover` - Spray-Entferner

**Erforderliche Anpassungen:**
```sql
-- Items zu deiner items Tabelle hinzufügen oder Namen anpassen
INSERT INTO `items` (`name`, `label`, `weight`, `type`, `useable`) VALUES
('spray_can', 'Spray Dose', 500, 'item', 1),
('spray_remover', 'Spray Entferner', 300, 'item', 1);
```

### 4. Database-Schema
**Annahme:** Standard QB-Core Database mit utf8mb4 Charset
- **Präfix:** Keine Tabellen-Präfixe angenommen
- **JSON-Support:** MySQL 5.7+ JSON-Funktionen
- **Charset:** utf8mb4_unicode_ci

**Mögliche Anpassungen:**
```sql
-- Falls Tabellen-Präfix verwendet wird:
CREATE TABLE `qb_gang_sprays` (...);  -- statt gang_sprays

-- Falls ältere MySQL-Version ohne JSON:
ALTER TABLE gang_sprays 
MODIFY COLUMN position TEXT,
MODIFY COLUMN metadata TEXT;
```

### 5. CORS Proxy Server
**Annahme:** Separater Node.js Server für externe Bild-URLs
- **Port:** 8080 (localhost:8080)
- **Whitelisted Domains:** imgur.com, discordapp.com
- **Image Processing:** Sharp Library für Optimierung

**Erforderliche Anpassungen:**
```javascript
// In cors-proxy/server.js - Port anpassen:
const PORT = process.env.PORT || 8080;

// Erlaubte Domains an deinen Server anpassen:
const allowedDomains = [
    'imgur.com', 
    'i.imgur.com', 
    'cdn.discordapp.com',
    'deine-domain.com'  // Füge eigene Domains hinzu
];
```

### 6. Performance-Konfiguration
**Annahme:** Server mit modernen Specs (50+ Spieler)
- **Concurrent DUIs:** 10 gleichzeitig
- **Texture Resolution:** 1024x1024 Standard
- **Memory Threshold:** 150MB
- **Streaming Distance:** 150m

**Anpassungen für schwächere Server:**
```lua
-- In config/main.lua für kleinere Server:
Config.Performance = {
    maxConcurrentDUIs = 5,        -- Halbiert für 32-Slot Server
    textureResolution = 512,      -- Reduziert für schwächere Hardware
    memoryThreshold = 75 * 1024 * 1024,  -- 75MB für kleinere Server
    streamingDistance = 100.0,    -- Kürzere Distanz
    maxTotalSprays = 75          -- Weniger Sprays gesamt
}
```

### 7. File-Struktur und Paths
**Annahme:** Standard FiveM Resource-Struktur
- **Resource Name:** `spray-system`
- **NUI Path:** `nui://spray-system/html/`
- **Template Path:** `html/presets/`

**Anpassungen bei anderem Resource-Namen:**
```lua
-- In allen Dateien GetCurrentResourceName() wird automatisch angepasst
-- Aber in HTML/JS manuell ändern falls nötig:

// In html/js/spray-editor.js:
const resourceName = 'dein-resource-name';  // Falls hart-kodiert
```

### 8. Debug und Logging
**Annahme:** Debug standardmäßig deaktiviert für Production
- **Console Output:** Nur Errors und Warnings
- **Performance Monitoring:** Deaktiviert
- **Verbose Logging:** Aus

**Aktivierung für Development:**
```lua
-- In config/main.lua für Entwicklung:
Config.Debug = {
    enabled = true,
    verboseLogging = true,
    showPerformanceMetrics = true,
    testMode = true  -- Umgeht einige Beschränkungen
}
```

## 🔧 Spezifische Anpassungen erforderlich

### 1. Gang-System Integration
**Was angepasst werden MUSS:**

```lua
-- config/gangs.lua - Ersetze komplett mit deinen Gangs:
Config.Gangs.AllowedGangs = {
    ['deine_gang_1'] = {
        name = 'Deine Gang Name',
        color = '#HEX_FARBE',
        primaryColors = {'#FARBE1', '#FARBE2', '#FARBE3'},
        templates = {'template_id_1', 'template_id_2'},
        minimumGrade = 1,  -- An dein Rang-System anpassen
        territories = {
            {
                name = "Territory Name",
                center = vector3(x, y, z),  -- An deine Map anpassen
                radius = 200.0
            }
        }
    }
}
```

### 2. Template-Bilder erstellen
**Was erstellt werden MUSS:**

```bash
# Erstelle für jede Gang Template-Bilder:
html/presets/
├── deine_gang_1_logo.png     # Gang-Logo (512x512 empfohlen)
├── deine_gang_1_territory.png   # Territory-Marker
├── deine_gang_2_logo.png
└── default.png               # Fallback-Template (PFLICHT)
```

### 3. Neutral-Zonen definieren
**Was angepasst werden SOLLTE:**

```lua
-- config/main.lua - An deine Map/Spawn-Punkte anpassen:
Config.Permissions.neutralZones = {
    {coords = vector3(dein_spawn_x, dein_spawn_y, dein_spawn_z), radius = 100.0},
    {coords = vector3(krankenhaus_x, krankenhaus_y, krankenhaus_z), radius = 50.0},
    {coords = vector3(polizei_x, polizei_y, polizei_z), radius = 75.0}
}
```

### 4. Item-Bilder hinzufügen
**Was hinzugefügt werden MUSS:**

```bash
# In deinem QB-Core inventory-Ordner:
qb-inventory/html/images/
├── spray_can.png         # Spray-Dose Bild
└── spray_remover.png     # Spray-Entferner Bild
```

### 5. Server-spezifische Limits
**Was möglicherweise angepasst werden MUSS:**

```lua
-- Basierend auf deiner Server-Population:

-- Für 32-Slot Server:
Config.Performance.maxTotalSprays = 50
Config.Performance.maxSpraysPerPlayer = 2

-- Für 128-Slot Server:
Config.Performance.maxTotalSprays = 300  
Config.Performance.maxSpraysPerPlayer = 8

-- Für Test-Server:
Config.Performance.maxTotalSprays = 10
Config.Performance.maxSpraysPerPlayer = 1
```

## ⚠️ Bekannte Limitationen

### 1. FiveM Engine Limits
- **DUI Memory:** Kann nicht vollständig freigegeben werden
- **Texture Streaming:** Begrenzt auf ~200 aktive Texturen
- **Native Limitations:** DrawPoly unterstützt keine echten UV-Maps

### 2. Browser Compatibility
- **NUI Engine:** Basiert auf CEF (Chromium Embedded Framework)
- **Canvas Limits:** 4096x4096 maximale Canvas-Größe
- **Memory Limits:** ~150MB pro Resource in NUI

### 3. Database Performance
- **JSON Queries:** Langsamer als normale Spalten
- **Index Limitations:** JSON-Indizes nur in MySQL 8.0+
- **Storage Overhead:** JSON benötigt mehr Speicherplatz

## 🚀 Empfohlene Optimierungen

### 1. Production-Konfiguration
```lua
-- Optimiert für Live-Server mit 50+ Spielern:
Config.Performance = {
    maxConcurrentDUIs = 8,           -- Konservativ für Stabilität
    textureResolution = 512,         -- Balance zwischen Qualität und Performance
    memoryThreshold = 100 * 1024 * 1024,  -- 100MB sicher für die meisten Server
    streamingDistance = 120.0,       -- Gute Balance für Sichtbarkeit
    cleanupInterval = 600000,        -- 10 Minuten für weniger DB-Load
    sprayExpireTime = 7 * 24 * 60 * 60  -- 7 Tage Standard-Lebensdauer
}
```

### 2. Memory Management
```lua
-- Aggressivere Memory-Kontrolle für schwächere Server:
Config.Performance.memoryThreshold = 75 * 1024 * 1024  -- 75MB
Config.Threading.memoryCheckInterval = 15000  -- Alle 15 Sekunden prüfen
```

### 3. Network Optimization
```lua
-- Reduzierte Update-Frequenz für weniger Network-Traffic:
Config.Threading.distanceCheckInterval = 1000  -- 1 Sekunde statt 500ms
Config.Threading.databaseSyncInterval = 60000  -- 1 Minute statt 30 Sekunden
```

## 📝 Finale Checkliste vor Go-Live

### Pre-Production Tests:
- [ ] **Alle Gang-Namen** in config/gangs.lua angepasst
- [ ] **Template-Bilder** für alle Gangs erstellt
- [ ] **Items** zu QB-Core Database hinzugefügt
- [ ] **Neutral-Zonen** für Map definiert
- [ ] **CORS Proxy** gestartet und getestet
- [ ] **Performance-Limits** an Server angepasst
- [ ] **Database-Schema** vollständig erstellt
- [ ] **Object_gizmo** installiert und funktional

### Functionality Tests:
- [ ] **Template-Sprays** funktionieren
- [ ] **Custom Paint Editor** öffnet und speichert
- [ ] **URL-Bilder** werden geladen (mit Proxy)
- [ ] **Gang-Permissions** korrekt validiert
- [ ] **Spray-Entfernung** funktioniert
- [ ] **Cache-System** lädt/entlädt korrekt
- [ ] **Database-Cleanup** entfernt abgelaufene Sprays

### Performance Tests:
- [ ] **Memory-Usage** unter Threshold
- [ ] **FPS-Impact** < 5 FPS bei maximalen Sprays
- [ ] **Database-Queries** < 50ms Response-Zeit
- [ ] **DUI-Loading** funktioniert ohne Leaks
- [ ] **Network-Traffic** akzeptabel (< 5KB/s pro Spieler)

### Production Monitoring:
- [ ] **Error-Logging** aktiviert
- [ ] **Performance-Metriken** überwacht
- [ ] **Admin-Commands** getestet
- [ ] **Backup-Strategy** für Spray-Daten
- [ ] **Rate-Limiting** gegen Spam aktiv