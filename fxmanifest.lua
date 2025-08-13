-- ✅ UPDATED: FiveM Gang Spray System
-- Advanced DUI-based Graffiti System with QB-Core Integration
fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_fxv2_oal 'yes'

author 'Gang Spray Development Team'
description 'Advanced Gang Spray System with Paint Editor'
version '1.0.1'

-- Kritische Dependencies in korrekter Ladereihenfolge
dependencies {
    'qb-core',          -- QB-Core Framework (Essential)
    'oxmysql',          -- Database System (Essential) 
    'ox_lib'            -- UI Library (Essential)
}

-- Shared Scripts - REIHENFOLGE IST KRITISCH!
shared_scripts {
    '@ox_lib/init.lua',               -- Ox-lib Initialisierung (KRITISCH: Erste Zeile!)
    '@qb-core/shared/locale.lua',     -- QB-Core Locale System
    'shared/debug.lua',               -- ✅ FIX: Debug System ZUERST laden
    'config/main.lua',                -- Main Config nach Debug
    'config/gangs.lua',               -- Gang Config danach
    'config/items.lua'                -- Item Config zuletzt
}

-- Client Scripts mit optimierter Ladereihenfolge
client_scripts {
    'client/core/dui_manager.lua',    -- DUI Manager zuerst
    'client/spray/raycast.lua',       -- Raycast System
    'client/spray/cache.lua',         -- Cache System
    'client/spray/placement.lua',     -- Placement System
    'client/spray/renderer.lua',      -- Renderer System
    'client/ui/spray_menu.lua'        -- UI zuletzt
}

-- Server Scripts mit Database-Integration
server_scripts {
    'server/core/init.lua',           -- Server Core Init
    'server/database/schema.lua',     -- ✅ ORIGINAL: Database Schema
    'server/database/schema_fix.lua', -- ✅ NEU: Schema Migration Fix
    'server/permissions/gang_handler.lua',  -- Gang Permission System
    'server/spray/main.lua'           -- Main Server Logic
}

-- NUI Files für Fabric.js Paint Editor
ui_page 'html/index.html'

files {
    'html/index.html',                -- Main HTML File
    'html/js/spray-editor.js',        -- JavaScript Files
    'html/js/template-manager.js',
    'html/js/performance-monitor.js',
    'html/css/style.css',             -- Styling
    'html/presets/default.png'        -- Default Template (mindestens diese eine Datei)
}

-- Export für andere Resources
exports {
    'GetNearbySprayData',             -- Public API für andere Scripts
    'CanPlaceSprayAtLocation',        -- Location Validation
    'GetPlayerSprayPermissions'       -- Permission Check
}