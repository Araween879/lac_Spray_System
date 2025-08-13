-- Gang-spezifische Konfiguration für das Spray-System
-- Definiert erlaubte Gangs, Farben und Spray-Templates

-- Initialisiere Config falls nicht vorhanden
if not Config then
    Config = {}
end

Config.Gangs = Config.Gangs or {}

-- Erlaubte Gangs mit spezifischen Einstellungen
Config.Gangs.AllowedGangs = {
    ['vagos'] = {
        name = 'Los Santos Vagos',
        color = '#FFFF00',                    -- Gelb (Hex)
        primaryColors = {'#FFFF00', '#FFA500', '#FFD700'}, -- Erlaubte Hauptfarben
        templates = {'vagos_01', 'vagos_02', 'vagos_03'},  -- Vordefinierte Templates
        maxSpraysPerTerritory = 3,            -- Maximale Sprays pro Gebiet
        sprayExpireTime = 604800,             -- 7 Tage (Sekunden)
        canOverwriteOthers = false,           -- Kann andere Gang-Sprays überschreiben
        minimumGrade = 1,                     -- Mindest-Rang (1 = Member)
        
        -- Gang-spezifische Gebiete
        territories = {
            {
                name = "Vagos Territory East",
                center = vector3(331.3, -2012.9, 22.3),
                radius = 200.0,
                bonusExpireTime = 1209600           -- 14 Tage in eigenem Gebiet
            }
        }
    },

    ['ballas'] = {
        name = 'Ballas',
        color = '#800080',                    -- Lila
        primaryColors = {'#800080', '#9932CC', '#4B0082'},
        templates = {'ballas_01', 'ballas_02', 'ballas_03'},
        maxSpraysPerTerritory = 3,
        sprayExpireTime = 604800,
        canOverwriteOthers = false,
        minimumGrade = 1,
        
        territories = {
            {
                name = "Ballas Territory",
                center = vector3(84.3, -1969.5, 20.9),
                radius = 150.0,
                bonusExpireTime = 1209600
            }
        }
    },

    ['families'] = {
        name = 'The Families',
        color = '#00FF00',                    -- Grün
        primaryColors = {'#00FF00', '#32CD32', '#228B22'},
        templates = {'families_01', 'families_02', 'families_03'},
        maxSpraysPerTerritory = 3,
        sprayExpireTime = 604800,
        canOverwriteOthers = false,
        minimumGrade = 1,
        
        territories = {
            {
                name = "Grove Street Territory",
                center = vector3(-174.2, -1602.4, 33.2),
                radius = 180.0,
                bonusExpireTime = 1209600
            }
        }
    },

    ['grove'] = {
        name = 'Grove Street',
        color = '#006400',                    -- Dunkelgrün
        primaryColors = {'#006400', '#228B22', '#32CD32'},
        templates = {'grove_01', 'grove_02', 'grove_03'},
        maxSpraysPerTerritory = 4,            -- Grove Street bekommt mehr Sprays
        sprayExpireTime = 604800,
        canOverwriteOthers = false,
        minimumGrade = 0,                     -- Niedrigster Rang erlaubt
        
        territories = {
            {
                name = "Grove Street Hood",
                center = vector3(-174.2, -1602.4, 33.2),
                radius = 200.0,
                bonusExpireTime = 1209600
            }
        }
    },

    ['marabunta'] = {
        name = 'Marabunta Grande',
        color = '#0066CC',                    -- Blau
        primaryColors = {'#0066CC', '#4169E1', '#1E90FF'},
        templates = {'marabunta_01', 'marabunta_02', 'marabunta_03'},
        maxSpraysPerTerritory = 3,
        sprayExpireTime = 604800,
        canOverwriteOthers = false,
        minimumGrade = 1,
        
        territories = {
            {
                name = "Marabunta Territory",
                center = vector3(1434.0, -1491.9, 63.6),
                radius = 160.0,
                bonusExpireTime = 1209600
            }
        }
    }
}

-- Job-basierte Organisationen (optional, wenn Config.Permissions.allowJobSpray = true)
Config.Gangs.AllowedJobs = {
    ['police'] = {
        name = 'LSPD',
        color = '#0000FF',                    -- Blau
        primaryColors = {'#0000FF', '#000080', '#4169E1'},
        templates = {'police_01', 'police_warning'},
        maxSpraysPerTerritory = 2,
        sprayExpireTime = 1209600,            -- 14 Tage (länger für offizielle Markierungen)
        canOverwriteOthers = true,            -- Police kann Gang-Sprays überschreiben
        minimumGrade = 2,                     -- Officer oder höher
        
        -- Spezielle Bereiche für Police
        allowedAreas = {
            {center = vector3(425.1, -979.5, 30.7), radius = 100.0}, -- Mission Row PD
            {center = vector3(1853.1, 3690.0, 34.3), radius = 80.0}   -- Sandy Shores PD
        }
    }
}

-- ✅ NEU: Public Templates für alle Spieler
Config.Gangs.PublicTemplates = {
    ['public_01'] = {
        name = "Basic Graffiti",
        description = "Einfaches Graffiti Design für alle",
        filePath = "html/presets/public_01.png",
        category = "public",
        requiredGrade = 0,                    -- Alle können es nutzen
        isPublic = true,                      -- ✅ Markierung als öffentlich
        priority = 1                          -- ✅ Anzeigepriorität
    },
    ['public_02'] = {
        name = "Street Tag",
        description = "Street Art Tag Style", 
        filePath = "html/presets/public_02.png",
        category = "public",
        requiredGrade = 0,
        isPublic = true,
        priority = 2
    },
    ['public_03'] = {
        name = "Wildstyle",
        description = "Wildstyle Graffiti Design",
        filePath = "html/presets/public_03.png", 
        category = "public",
        requiredGrade = 0,
        isPublic = true,
        priority = 3
    },
    ['public_04'] = {
        name = "Tribal Design",
        description = "Tribal Spray Pattern",
        filePath = "html/presets/public_04.png",
        category = "public", 
        requiredGrade = 0,
        isPublic = true,
        priority = 4
    },
    ['public_05'] = {
        name = "Abstract Art",
        description = "Abstraktes Kunstwerk",
        filePath = "html/presets/public_05.png",
        category = "public",
        requiredGrade = 0,
        isPublic = true,
        priority = 5
    }
}

-- ✅ ERWEITERT: Vordefinierte Spray-Templates mit Gang-Markierung
Config.Gangs.Templates = {
    -- Vagos Templates
    ['vagos_01'] = {
        name = "Vagos Logo",
        description = "Klassisches Vagos Gang-Symbol",
        filePath = "html/presets/vagos_01.png",
        category = "logo",
        requiredGrade = 1,
        isPublic = false,                     -- ✅ NEU: Gang-spezifisch
        requiredGang = "vagos"                -- ✅ NEU: Erforderliche Gang
    },
    ['vagos_02'] = {
        name = "Vagos Territory",
        description = "Territory-Markierung",
        filePath = "html/presets/vagos_02.png", 
        category = "territory",
        requiredGrade = 2,
        isPublic = false,
        requiredGang = "vagos"
    },
    ['vagos_03'] = {
        name = "Vagos Warning",
        description = "Warnung an Rivalen",
        filePath = "html/presets/vagos_03.png",
        category = "warning",
        requiredGrade = 1,
        isPublic = false,
        requiredGang = "vagos"
    },

    -- Ballas Templates
    ['ballas_01'] = {
        name = "Ballas Crown",
        description = "Ballas Gang Crown Symbol",
        filePath = "html/presets/ballas_01.png",
        category = "logo",
        requiredGrade = 1,
        isPublic = false,
        requiredGang = "ballas"
    },
    ['ballas_02'] = {
        name = "Ballas Turf",
        description = "Turf-Kontrolle Markierung",
        filePath = "html/presets/ballas_02.png",
        category = "territory", 
        requiredGrade = 2,
        isPublic = false,
        requiredGang = "ballas"
    },
    ['ballas_03'] = {
        name = "Ballas Tag",
        description = "Standard Gang Tag",
        filePath = "html/presets/ballas_03.png",
        category = "tag",
        requiredGrade = 1,
        isPublic = false,
        requiredGang = "ballas"
    },

    -- Families Templates  
    ['families_01'] = {
        name = "Families F",
        description = "The Families Logo",
        filePath = "html/presets/families_01.png",
        category = "logo",
        requiredGrade = 1,
        isPublic = false,
        requiredGang = "families"
    },
    ['families_02'] = {
        name = "Families Hood",
        description = "Neighborhood Marking",
        filePath = "html/presets/families_02.png",
        category = "territory",
        requiredGrade = 2,
        isPublic = false,
        requiredGang = "families"
    },
    ['families_03'] = {
        name = "Families Unity",
        description = "Gang Unity Symbol",
        filePath = "html/presets/families_03.png",
        category = "unity",
        requiredGrade = 1,
        isPublic = false,
        requiredGang = "families"
    },

    -- Grove Street Templates
    ['grove_01'] = {
        name = "Grove Street",
        description = "Grove Street Gang Logo",
        filePath = "html/presets/grove_01.png",
        category = "logo",
        requiredGrade = 0,
        isPublic = false,
        requiredGang = "grove"
    },
    ['grove_02'] = {
        name = "GSF Territory", 
        description = "Grove Street Families Territory",
        filePath = "html/presets/grove_02.png",
        category = "territory",
        requiredGrade = 1,
        isPublic = false,
        requiredGang = "grove"
    },
    ['grove_03'] = {
        name = "Grove Power",
        description = "Grove Street Power Symbol",
        filePath = "html/presets/grove_03.png",
        category = "power",
        requiredGrade = 2,
        isPublic = false,
        requiredGang = "grove"
    },

    -- Marabunta Templates
    ['marabunta_01'] = {
        name = "Marabunta Logo",
        description = "Marabunta Grande Symbol",
        filePath = "html/presets/marabunta_01.png",
        category = "logo",
        requiredGrade = 1,
        isPublic = false,
        requiredGang = "marabunta"
    },
    ['marabunta_02'] = {
        name = "Marabunta Territory",
        description = "Territory Control Marker",
        filePath = "html/presets/marabunta_02.png",
        category = "territory",
        requiredGrade = 2,
        isPublic = false,
        requiredGang = "marabunta"
    },
    ['marabunta_03'] = {
        name = "Marabunta Warning",
        description = "Warning to Rivals",
        filePath = "html/presets/marabunta_03.png",
        category = "warning",
        requiredGrade = 1,
        isPublic = false,
        requiredGang = "marabunta"
    },

    -- Police Templates (wenn Jobs erlaubt)
    ['police_01'] = {
        name = "LSPD Badge",
        description = "Offizielles LSPD Symbol",
        filePath = "html/presets/police_01.png",
        category = "official",
        requiredGrade = 2,
        isPublic = false,
        requiredJob = "police"
    },
    ['police_warning'] = {
        name = "Crime Scene",
        description = "Tatort-Markierung",
        filePath = "html/presets/police_warning.png",
        category = "warning",
        requiredGrade = 1,
        isPublic = false,
        requiredJob = "police"
    }
}

-- Rivalitäten und Allianzen (beeinflusst Überschreibungs-Rechte)
Config.Gangs.Rivalries = {
    ['vagos'] = {'ballas', 'families'},      -- Vagos sind Rivalen von Ballas und Families
    ['ballas'] = {'vagos', 'grove'},         -- Ballas sind Rivalen von Vagos und Grove
    ['families'] = {'vagos', 'marabunta'},   -- Families sind Rivalen von Vagos und Marabunta
    ['grove'] = {'ballas'},                  -- Grove ist Rivale von Ballas
    ['marabunta'] = {'families'}             -- Marabunta ist Rivale von Families
}

Config.Gangs.Alliances = {
    ['families'] = {'grove'},                -- Families und Grove sind verbündet
    ['grove'] = {'families'}                 -- Gegenseitige Allianz
}

-- Spray-Kategorien mit verschiedenen Berechtigungen
Config.Gangs.Categories = {
    ['logo'] = {
        name = "Gang Logo",
        description = "Offizielles Gang-Symbol",
        requiredGrade = 1,
        expireMultiplier = 1.0               -- Standard Lebensdauer
    },
    ['territory'] = {
        name = "Territory Marking", 
        description = "Gebiets-Markierung",
        requiredGrade = 2,                   -- Höhere Berechtigung erforderlich
        expireMultiplier = 1.5               -- 50% längere Lebensdauer
    },
    ['warning'] = {
        name = "Warning",
        description = "Warnung oder Drohung",
        requiredGrade = 1,
        expireMultiplier = 0.8               -- 20% kürzere Lebensdauer
    },
    ['tag'] = {
        name = "Gang Tag",
        description = "Einfacher Gang Tag",
        requiredGrade = 0,                   -- Niedrigste Berechtigung
        expireMultiplier = 0.7               -- Kürzeste Lebensdauer
    },
    -- ✅ NEU: Public Category
    ['public'] = {
        name = "Public Graffiti",
        description = "Öffentliches Graffiti für alle",
        requiredGrade = 0,                   -- ✅ Alle können es nutzen
        expireMultiplier = 0.5               -- ✅ Kürzere Lebensdauer für Public Sprays
    }
}

-- Globale Gang-Einstellungen
Config.Gangs.Global = {
    allowNeutralPlayers = true,              -- ✅ GEÄNDERT: true - Nicht-Gang-Mitglieder können sprayen
    neutralPlayerGang = 'public',            -- ✅ GEÄNDERT: 'public' statt 'civilian'
    maxGangSpraysTotal = 50,                 -- Maximale Sprays pro Gang server-weit
    maxPublicSpraysTotal = 25,               -- ✅ NEU: Maximale Public Sprays server-weit
    territoryBonusMultiplier = 2.0,          -- Lebensdauer-Bonus im eigenen Gebiet
    crossGangPenalty = 0.5,                  -- Lebensdauer-Malus in fremdem Gebiet
    
    -- Automatische Cleanup-Regeln
    autoCleanupEnabled = true,               -- Automatisches Löschen abgelaufener Sprays
    cleanupInterval = 3600,                  -- Cleanup alle 60 Minuten (Sekunden)
    warningBeforeExpire = 86400              -- 24h Warnung vor Ablauf (Sekunden)
}