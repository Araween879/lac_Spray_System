-- Main Configuration für FiveM Gang Spray System
-- Alle kritischen Performance-Limits und System-Einstellungen

Config = Config or {}

-- Performance-kritische Einstellungen (NICHT VERÄNDERN ohne Tests!)
Config.Performance = {
    maxConcurrentDUIs = 10,           -- Maximale gleichzeitige DUI Objekte (Hardware-Limit)
    maxSpraysPerPlayer = 5,           -- Limit pro Spieler (Anti-Spam)
    maxTotalSprays = 200,             -- Server-weites Spray-Limit
    maxSpraysInArea = 8,              -- Max Sprays in 50m Radius (Density Control)
    textureResolution = 1024,         -- 1024x1024 für Balance zwischen Qualität und Performance
    streamingDistance = 150.0,        -- Streaming-Radius (Meter)
    memoryThreshold = 150 * 1024 * 1024,  -- 150MB Memory-Grenze
    
    -- LOD (Level of Detail) Distanzen für Performance-Optimierung
    lodDistances = {
        high = 25.0,                  -- Volle Qualität bis 25m
        medium = 75.0,                -- Mittlere Qualität bis 75m  
        low = 150.0                   -- Niedrige Qualität bis 150m
    },
    
    -- Cleanup und Maintenance Intervalle
    cleanupInterval = 300000,         -- 5 Minuten automatischer Cleanup (ms)
    cacheTimeout = 60000,             -- 1 Minute Permission Cache (ms)
    sprayExpireTime = 7 * 24 * 60 * 60 -- 7 Tage Spray-Lebensdauer (Sekunden)
}

-- DUI System Konfiguration
Config.DUI = {
    editorURL = "nui://spray-system/html/index.html",   -- NUI Paint Editor URL
    proxyServer = "http://localhost:8080/proxy",        -- CORS Proxy für externe Bilder
    defaultTexture = "spray_default",                   -- Fallback Texture
    compressionQuality = 0.8,                          -- 0.0-1.0 Komprimierung
    maxImageSize = 1024 * 1024,                        -- 1MB Limit für Base64 Bilder
    allowedImageTypes = {'png', 'jpg', 'jpeg', 'webp'} -- Erlaubte Bildformate
}

-- Thread-Optimierung für Multi-Threading
Config.Threading = {
    distanceCheckInterval = 500,      -- 500ms zwischen Distance Checks
    renderInterval = 0,               -- Frame-basiert wenn Sprays aktiv (0 = jeder Frame)
    databaseSyncInterval = 30000,     -- 30 Sekunden Database Synchronisation
    heartbeatInterval = 60000,        -- 1 Minute Server Heartbeat
    memoryCheckInterval = 30000       -- 30 Sekunden Memory Monitoring
}

-- Anti-Spam und Rate Limiting
Config.RateLimit = {
    sprayCreationCooldown = 10000,    -- 10 Sekunden zwischen Spray-Erstellung
    sprayRemovalCooldown = 5000,      -- 5 Sekunden zwischen Spray-Entfernung
    maxActionsPerMinute = 6,          -- Maximale Aktionen pro Minute
    banDuration = 300000,             -- 5 Minuten Temp-Ban bei Abuse
    warningThreshold = 3              -- Warnungen vor Temp-Ban
}

-- Physik und Platzierungs-Einstellungen
Config.Physics = {
    raycastDistance = 5.0,            -- Maximale Raycast-Distanz für Spray-Placement
    minSurfaceAngle = 30.0,           -- Minimaler Winkel für gültige Oberflächen
    maxSurfaceAngle = 120.0,          -- Maximaler Winkel für gültige Oberflächen
    spraySize = 2.0,                  -- Standard Spray-Größe (Meter)
    minPlacementDistance = 1.0,       -- Mindestabstand zwischen Sprays
    
    -- Unerlaubte Material-Hashes (Wasser, Glas, etc.)
    forbiddenMaterials = {
        [1913209870] = true,          -- WATER
        [-1595148316] = true,         -- GLASS
        [-461750719] = true,          -- METAL_SOLID_ROAD_SURFACE
        [1109728704] = true           -- CONCRETE_SIDEWALK (optional)
    }
}

-- ✅ GEÄNDERT: Berechtigungssystem - Item-Only & Public Access
Config.Permissions = {
    requireGangMembership = false,    -- ✅ GEÄNDERT: false - Alle können sprayen
    allowPublicSpray = true,          -- ✅ NEU: Öffentliche Sprays erlaubt
    publicSprayLimit = 2,             -- ✅ NEU: Limit für Non-Gang-Members
    minimumGangGrade = 1,             -- Mindest-Gang-Rang für Gang-Features
    adminCanBypass = true,            -- Admins können alle Beschränkungen umgehen
    
    -- ✅ NEU: Item-Only System
    useItemToSpray = true,            -- ✅ NEU: NUR Items aktivieren Spray
    commandAccessDisabled = true,     -- ✅ NEU: /spray Command deaktiviert
    sprayCanRequired = true,          -- ✅ Spray-Dose Item erforderlich
    
    -- ✅ NEU: Entferner-System
    allowItemRemoval = true,          -- ✅ NEU: Entferner-Item aktivieren
    removeOwnSpraysOnly = false,      -- ✅ NEU: Kann alle Sprays entfernen (nicht nur eigene)
    
    -- Gang-spezifische Einstellungen
    gangSpecificColors = true,        -- Gangs haben eigene Farbpaletten
    crossGangOverwrite = false,       -- Kann andere Gang-Sprays übermalen
    neutralZones = {                  -- Bereiche wo keine Sprays erlaubt sind
        {coords = vector3(0.0, 0.0, 0.0), radius = 100.0}, -- Spawn (Beispiel)
    }
}

-- ✅ ERWEITERT: Items und Inventar - Entferner-Support
Config.Items = {
    sprayCanItem = 'spray_can',       -- Item-Name für Spray-Dose
    sprayRemoverItem = 'spray_remover', -- ✅ NEU: Item-Name für Spray-Entferner
    sprayCanUses = 10,                -- Standard-Anzahl Nutzungen pro Dose
    removeSprayUses = 5,              -- ✅ NEU: Nutzungen für Spray-Entferner
    consumeOnUse = true,              -- Items bei Nutzung verbrauchen
    
    -- ✅ NEU: Entferner-spezifische Settings
    removerRange = 5.0,               -- ✅ NEU: 5m Reichweite zum Entfernen
    removerSuccessChance = 0.9,       -- ✅ NEU: 90% Erfolgsrate beim Entfernen
    removerProgressTime = 3000,       -- ✅ NEU: 3 Sekunden Progress Bar
    
    -- Item-Qualität und Durability
    defaultQuality = 100,             -- Standard Item-Qualität
    qualityLossPerUse = 10,           -- Qualitätsverlust pro Nutzung
    minimumQuality = 10               -- Mindest-Qualität für Nutzung
}

-- Audio und Effekte
Config.Effects = {
    playSounds = true,                -- Sound-Effekte aktivieren
    spraySound = 'spray_can_shake',   -- Sound beim Sprayen
    removeSound = 'spray_wipe',       -- Sound beim Entfernen
    soundVolume = 0.3,                -- Lautstärke (0.0-1.0)
    
    -- Partikel-Effekte
    useParticles = true,              -- Partikel-Effekte aktivieren
    sprayParticle = 'core',           -- Partikel-Dictionary
    sprayParticleName = 'ent_sht_steam' -- Partikel-Name
}

-- Debug und Entwicklung
Config.Debug = {
    enabled = false,                  -- Debug-Modus (nur für Entwicklung)
    verboseLogging = false,           -- Erweiterte Logs
    showPerformanceMetrics = false,   -- Performance-Anzeige
    testMode = false,                 -- Test-Modus (umgeht einige Beschränkungen)
    
    -- Debug-Visualisierungen
    showRaycastLines = false,         -- Raycast-Linien anzeigen
    showSprayBounds = false,          -- Spray-Grenzen anzeigen
    showLODDistances = false          -- LOD-Distanzen visualisieren
}

-- Localization Keys (wird durch locale.lua erweitert)
Config.Locale = 'de' -- Standardsprache