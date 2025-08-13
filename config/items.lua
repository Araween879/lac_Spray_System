-- ✅ ITEM CONFIGURATION: Gang Spray System
-- Datei: config/items.lua

Config = Config or {}

-- ✅ KORREKTE QB-CORE ITEM NAMES (aus shared/items.lua)
Config.Items = {
    -- ===== SPRAY CANS =====
    sprayCanGang = 'spray_can_gang',              -- Gang Spray-Dose
    sprayCanPublic = 'spray_can_public',          -- Öffentliche Spray-Dose  
    sprayCanPremium = 'spray_can_premium',        -- Premium Gang Spray-Dose
    
    -- ===== REMOVER ITEMS =====
    sprayRemover = 'spray_remover',               -- Standard Graffiti-Entferner
    sprayRemoverPro = 'spray_remover_pro',        -- Profi Graffiti-Entferner
    
    -- ===== ZUSATZ ITEMS =====
    sprayTemplateKit = 'spray_template_kit',      -- Template Kit
    paintBrushSet = 'paint_brush_set',            -- Paint Brush Set
    sprayColorPack = 'spray_color_pack',          -- Farben Pack
    
    -- ===== ITEM SETTINGS =====
    defaultSprayUses = 10,                        -- Standard Anwendungen pro Dose
    defaultRemoverUses = 5,                       -- Standard Anwendungen pro Entferner
    qualityLossPerUse = 5,                        -- Qualitätsverlust pro Anwendung
    defaultQuality = 100,                         -- Standard Qualität neuer Items
    
    -- ===== ACCESS CONTROL =====
    publicItems = {                               -- Items die öffentlich nutzbar sind
        'spray_can_public',
        'spray_template_kit'
    },
    
    gangItems = {                                 -- Items die nur Gang-Mitglieder nutzen können
        'spray_can_gang',
        'spray_can_premium'
    },
    
    removerItems = {                              -- Items zum Entfernen von Sprays
        'spray_remover',
        'spray_remover_pro'
    },
    
    -- ===== ITEM METADATA DEFAULTS =====
    defaultMetadata = {
        spray_can_gang = {
            sprayType = 'gang',
            uses = 10,
            quality = 100
        },
        spray_can_public = {
            sprayType = 'public', 
            uses = 15,
            quality = 100
        },
        spray_can_premium = {
            sprayType = 'gang',
            uses = 20,
            quality = 100,
            premium = true
        },
        spray_remover = {
            uses = 5,
            quality = 100
        },
        spray_remover_pro = {
            uses = 10,
            quality = 100,
            professional = true
        }
    }
}

-- ✅ ITEM VALIDATION FUNCTIONS
Config.ItemValidation = {
    -- Prüft ob Item eine Spray-Dose ist
    isSprayItem = function(itemName)
        return itemName == Config.Items.sprayCanGang or 
               itemName == Config.Items.sprayCanPublic or 
               itemName == Config.Items.sprayCanPremium
    end,
    
    -- Prüft ob Item ein Entferner ist
    isRemoverItem = function(itemName)
        for _, remover in ipairs(Config.Items.removerItems) do
            if itemName == remover then
                return true
            end
        end
        return false
    end,
    
    -- Prüft ob Item öffentlich nutzbar ist
    isPublicItem = function(itemName)
        for _, publicItem in ipairs(Config.Items.publicItems) do
            if itemName == publicItem then
                return true
            end
        end
        return false
    end,
    
    -- Prüft ob Item Gang-spezifisch ist
    isGangItem = function(itemName)
        for _, gangItem in ipairs(Config.Items.gangItems) do
            if itemName == gangItem then
                return true
            end
        end
        return false
    end,
    
    -- Holt Spray-Typ aus Item
    getSprayType = function(itemName)
        if Config.ItemValidation.isPublicItem(itemName) then
            return 'public'
        elseif Config.ItemValidation.isGangItem(itemName) then
            return 'gang'
        else
            return 'unknown'
        end
    end
}

-- ✅ ITEM SHOP CONFIGURATION (für Shops/NPCs)
Config.ItemShops = {
    -- Hardware Store
    hardware_store = {
        items = {
            {item = 'spray_can_public', price = 50, label = 'Öffentliche Spray-Dose'},
            {item = 'spray_remover', price = 75, label = 'Graffiti-Entferner'},
            {item = 'spray_template_kit', price = 25, label = 'Template Kit'}
        },
        locations = {
            {x = 46.7, y = -1749.6, z = 29.6, h = 45.0}, -- Hardware Store
        }
    },
    
    -- Gang Supplier (Schwarzmarkt)
    gang_supplier = {
        items = {
            {item = 'spray_can_gang', price = 150, label = 'Gang Spray-Dose'},
            {item = 'spray_can_premium', price = 300, label = 'Premium Gang Spray-Dose'},
            {item = 'spray_remover_pro', price = 200, label = 'Profi Graffiti-Entferner'},
            {item = 'paint_brush_set', price = 100, label = 'Paint Brush Set'},
            {item = 'spray_color_pack', price = 80, label = 'Spray Farben Pack'}
        },
        requiresGang = true,
        locations = {
            {x = 1273.3, y = -1709.9, z = 54.8, h = 110.0}, -- Gang Area
        }
    }
}

-- ✅ BACKWARDS COMPATIBILITY (für alte Config-Referenzen)
Config.SprayItem = Config.Items.sprayCanGang          -- Deprecated: Verwende Config.Items.sprayCanGang
Config.RemoverItem = Config.Items.sprayRemover        -- Deprecated: Verwende Config.Items.sprayRemover

-- ✅ FIX: Debug Log nur wenn verfügbar
if _G.Debug and Debug.Log then
    Debug:Log("CONFIG", "Item configuration loaded", {
        sprayItems = #Config.Items.gangItems + #Config.Items.publicItems,
        removerItems = #Config.Items.removerItems
    }, "SUCCESS")
else
    print("[CONFIG] Item configuration loaded successfully")
end