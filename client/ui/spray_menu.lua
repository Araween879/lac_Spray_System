-- ✅ GEFIXT: Gang Spray Menu System - Vollständig reparierte Version
-- Datei: client/ui/spray_menu.lua

local QBCore = exports['qb-core']:GetCoreObject()
local lib = exports.ox_lib

-- ✅ FIX: SprayMenu Class mit verbessertem State Management
SprayMenu = {
    isOpen = false,
    nuiFocusActive = false,
    overlayPreventionActive = false,
    isRemovalMode = false,
    currentAccess = nil,
    playerGang = nil,
    playerGrade = 0,
    lastMenuOpenTime = 0,
    menuCooldown = 500, -- Anti-spam protection
    
    -- Debug & Performance
    debugMode = Config.Debug and Config.Debug.enabled or false,
    performanceMode = false
}

-- ✅ FIX: Initialisierung mit verbesserter Error Handling
function SprayMenu:Initialize()
    -- Player Data laden
    self:RefreshPlayerData()
    
    -- Event Listeners registrieren
    self:RegisterEventHandlers()
    
    -- Performance Monitoring
    if self.debugMode then
        self:StartPerformanceMonitoring()
    end
    
    Debug:Log("MENU", "Spray menu system initialized", {
        gang = self.playerGang,
        grade = self.playerGrade,
        debugMode = self.debugMode
    }, "SUCCESS")
end

-- ✅ FIX: Player Data Refresh
function SprayMenu:RefreshPlayerData()
    local PlayerData = QBCore.Functions.GetPlayerData()
    
    if PlayerData then
        self.playerGang = PlayerData.gang and PlayerData.gang.name or nil
        self.playerGrade = PlayerData.gang and PlayerData.gang.grade.level or 0
        
        Debug:Log("MENU", "Player data refreshed", {
            gang = self.playerGang,
            grade = self.playerGrade
        }, "INFO")
    else
        Debug:Log("MENU", "Failed to get player data", nil, "WARN")
    end
end

-- ✅ FIX: Event Handlers registrieren
function SprayMenu:RegisterEventHandlers()
    -- Player Data Update
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        Wait(2000) -- Warte bis alle Systeme geladen sind
        self:RefreshPlayerData()
    end)
    
    RegisterNetEvent('QBCore:Client:OnGangUpdate', function()
        self:RefreshPlayerData()
    end)
    
    -- Spray System Events
    RegisterNetEvent('spray:client:receivePlayerSprays', function(sprays)
        self:ShowPlayerSpraysMenu(sprays)
    end)
    
    RegisterNetEvent('spray:client:receiveSystemStats', function(stats)
        self:ShowSystemStats(stats)
    end)
    
    -- NUI Callbacks
    self:RegisterNUICallbacks()
    
    Debug:Log("MENU", "Event handlers registered", nil, "INFO")
end

-- ✅ FIX: NUI Callbacks mit verbesserter Error Handling
function SprayMenu:RegisterNUICallbacks()
    -- Editor schließen
    RegisterNUICallback('closeEditor', function(data, cb)
        self:SafeDeactivateNUI()
        cb('ok')
        Debug:Log("MENU", "Editor closed via NUI callback", nil, "INFO")
    end)
    
    -- Spray Design speichern
    RegisterNUICallback('saveSprayDesign', function(data, cb)
        self:SafeDeactivateNUI()
        
        if data and data.imageData then
            TriggerServerEvent('spray:server:saveSprayDesign', data)
            Debug:Log("MENU", "Spray design saved", {
                hasImageData = data.imageData ~= nil,
                gang = data.gang
            }, "INFO")
        else
            Debug:Log("MENU", "Invalid spray design data", data, "ERROR")
        end
        
        cb('ok')
    end)
    
    -- Template verwenden
    RegisterNUICallback('useTemplate', function(data, cb)
        self:SafeDeactivateNUI()
        
        if data and data.templateId then
            TriggerServerEvent('spray:server:useTemplate', data)
            Debug:Log("MENU", "Template selected", {
                templateId = data.templateId
            }, "INFO")
        else
            Debug:Log("MENU", "Invalid template data", data, "ERROR")
        end
        
        cb('ok')
    end)
    
    -- URL Bild verwenden
    RegisterNUICallback('useUrlImage', function(data, cb)
        self:SafeDeactivateNUI()
        
        if data and data.imageUrl then
            TriggerServerEvent('spray:server:useUrlImage', data)
            Debug:Log("MENU", "URL image selected", {
                url = data.imageUrl
            }, "INFO")
        else
            Debug:Log("MENU", "Invalid URL image data", data, "ERROR")
        end
        
        cb('ok')
    end)
    
    -- Template Modal schließen
    RegisterNUICallback('closeTemplate', function(data, cb)
        -- Kein NUI deactivate hier, nur Modal schließen
        Debug:Log("MENU", "Template modal closed", nil, "INFO")
        cb('ok')
    end)
    
    -- URL Input Modal schließen
    RegisterNUICallback('closeUrlInput', function(data, cb)
        -- Kein NUI deactivate hier, nur Modal schließen
        Debug:Log("MENU", "URL input modal closed", nil, "INFO")
        cb('ok')
    end)
end

-- ✅ FIX: Main Menu mit Item-basiertem Access
function SprayMenu:OpenMainMenu(itemData)
    -- Cooldown prüfen
    local currentTime = GetGameTimer()
    if currentTime - self.lastMenuOpenTime < self.menuCooldown then
        Debug:Log("MENU", "Menu open blocked by cooldown", nil, "WARN")
        return
    end
    self.lastMenuOpenTime = currentTime
    
    -- Clean State sicherstellen
    if self.nuiFocusActive then
        self:SafeDeactivateNUI()
        Wait(100)
    end
    
    -- ✅ FIX: Item-basierte Access Validierung
    if itemData then
        self.currentAccess = itemData
    else
        Debug:Log("MENU", "No item data provided for menu access", nil, "ERROR")
        return
    end
    
    local accessValidation = self:ValidateItemAccess()
    if not accessValidation.allowed then
        self:ShowAccessError(accessValidation.reason)
        return
    end
    
    -- Menu State setzen
    self.isOpen = true
    self.overlayPreventionActive = true
    
    -- Menu Options basierend auf Access Type
    local options = {}
    local sprayType = self.currentAccess.sprayType or "public"
    local menuTitle = sprayType == "public" and "🎨 Öffentliches Spray-System" or "🎨 Gang Spray System"
    
    -- ✅ FIX: Custom Editor Option
    table.insert(options, {
        title = '🎨 Custom Editor',
        description = 'Erstelle ein einzigartiges Spray-Design',
        icon = 'paint-brush',
        onSelect = function()
            self:OpenCustomEditor()
        end
    })
    
    -- ✅ FIX: Templates Option
    table.insert(options, {
        title = '📋 Templates',
        description = sprayType == "public" and 'Wähle aus öffentlichen Templates' or 'Wähle aus Gang-Templates',
        icon = 'images',
        onSelect = function()
            self:OpenTemplateSelector()
        end
    })
    
    -- ✅ FIX: URL-Bild Option
    table.insert(options, {
        title = '🔗 URL-Bild',
        description = 'Verwende ein Bild von einer URL',
        icon = 'link',
        onSelect = function()
            self:OpenUrlInput()
        end
    })
    
    -- ✅ FIX: Meine Sprays Option
    table.insert(options, {
        title = '📊 Meine Sprays',
        description = 'Verwalte deine erstellten Sprays',
        icon = 'list',
        onSelect = function()
            self:OpenPlayerSprays()
        end
    })
    
    -- Admin-Optionen hinzufügen
    if self:IsPlayerAdmin() then
        table.insert(options, {
            title = '⚙️ Admin Panel',
            description = 'Spray-System verwalten',
            icon = 'cog',
            onSelect = function()
                self:OpenAdminPanel()
            end
        })
    end
    
    -- ✅ FIX: Context Menu mit verbessertem Exit Handler
    lib.registerContext({
        id = 'spray_main_menu',
        title = menuTitle,
        canClose = true,
        options = options,
        onExit = function()
            self.isOpen = false
            self.overlayPreventionActive = false
            Debug:Log("MENU", "Main menu closed", nil, "INFO")
        end
    })
    
    lib.showContext('spray_main_menu')
    
    Debug:Log("MENU", "Main menu opened", {
        sprayType = sprayType,
        optionsCount = #options,
        accessType = self.currentAccess.sprayType
    }, "INFO")
end

-- ✅ FIX: Custom Editor öffnen mit korrektem NUI Focus
function SprayMenu:OpenCustomEditor()
    lib.hideContext()
    
    CreateThread(function()
        Wait(150) -- Längerer Delay für smooth transition
        
        -- ✅ FIX: Safe NUI activation
        self:SafeActivateNUI()
        
        -- Gang-Farben vorbereiten
        local gangColors = self:GetGangColors()
        
        -- ✅ FIX: Editor öffnen mit korrekten Parametern
        SendNUIMessage({
            type = 'openSprayEditor',
            gang = self.playerGang,
            gangColors = gangColors,
            accessType = self.currentAccess.sprayType,
            visible = true,
            action = 'show'
        })
        
        Debug:Log("MENU", "Custom editor opened", {
            gang = self.playerGang,
            accessType = self.currentAccess.sprayType,
            colorsCount = #gangColors,
            nuiFocus = self.nuiFocusActive
        }, "INFO")
    end)
end

-- ✅ FIX: Template Selector öffnen mit verbesserter Template Loading
function SprayMenu:OpenTemplateSelector()
    lib.hideContext()
    
    CreateThread(function()
        Wait(150) -- Delay für smooth transition
        
        -- ✅ FIX: Safe NUI activation
        self:SafeActivateNUI()
        
        -- ✅ FIX: Template-Daten vorbereiten
        local templates = self:GetAvailableTemplates()
        
        -- ✅ FIX: Template Selector öffnen
        SendNUIMessage({
            type = 'openTemplateSelector',
            gang = self.playerGang,
            grade = self.playerGrade,
            templates = templates,
            accessType = self.currentAccess.sprayType,
            visible = true,
            action = 'show'
        })
        
        Debug:Log("MENU", "Template selector opened", {
            gang = self.playerGang,
            accessType = self.currentAccess.sprayType,
            templatesCount = #templates
        }, "INFO")
    end)
end

-- ✅ FIX: URL Input öffnen mit verbesserter NUI handling
function SprayMenu:OpenUrlInput()
    lib.hideContext()
    
    CreateThread(function()
        Wait(150) -- Delay für smooth transition
        
        -- ✅ FIX: Safe NUI activation
        self:SafeActivateNUI()
        
        -- ✅ FIX: URL Input öffnen
        SendNUIMessage({
            type = 'openUrlInput',
            gang = self.playerGang,
            accessType = self.currentAccess.sprayType,
            visible = true,
            action = 'show'
        })
        
        Debug:Log("MENU", "URL input opened", {
            gang = self.playerGang,
            accessType = self.currentAccess.sprayType
        }, "INFO")
    end)
end

-- ✅ FIX: Player Sprays öffnen mit Server Request
function SprayMenu:OpenPlayerSprays()
    lib.hideContext()
    
    -- Loading Notification
    lib.notify({
        title = 'Meine Sprays',
        description = 'Lade Spray-Daten...',
        type = 'info',
        duration = 2000
    })
    
    -- ✅ FIX: Request player sprays from server
    TriggerServerEvent('spray:server:getPlayerSprays')
    
    Debug:Log("MENU", "Player sprays requested", nil, "INFO")
end

-- ✅ FIX: Safe NUI activation mit Body Class Management
function SprayMenu:SafeActivateNUI()
    -- Ensure clean state first
    if self.nuiFocusActive then
        SetNuiFocus(false, false)
        Wait(100)
    end
    
    -- ✅ FIX: Activate NUI mit beiden Parametern
    SetNuiFocus(true, true) -- Keyboard + Mouse
    self.nuiFocusActive = true
    self.isOpen = false -- Menu ist geschlossen, NUI ist aktiv
    
    -- ✅ FIX: Add body class for CSS compatibility
    SendNUIMessage({
        type = 'setBodyClass',
        class = 'nui-focus-active',
        add = true
    })
    
    Debug:Log("MENU", "NUI safely activated", {
        focus = true,
        keyboard = true
    }, "INFO")
end

-- ✅ FIX: Safe NUI deactivation mit Body Class Cleanup
function SprayMenu:SafeDeactivateNUI()
    SetNuiFocus(false, false)
    self.nuiFocusActive = false
    self.overlayPreventionActive = false
    
    -- ✅ FIX: Remove body class
    SendNUIMessage({
        type = 'setBodyClass',
        class = 'nui-focus-active',
        add = false
    })
    
    -- ✅ FIX: Send cleanup message to NUI
    SendNUIMessage({
        type = 'closeAll',
        visible = false,
        action = 'hide'
    })
    
    Debug:Log("MENU", "NUI safely deactivated", nil, "INFO")
end

-- ✅ FIX: Force NUI Close für Emergency Cleanup
function SprayMenu:ForceCloseNUI()
    SetNuiFocus(false, false)
    self.nuiFocusActive = false
    self.isOpen = false
    self.overlayPreventionActive = false
    self.isRemovalMode = false
    
    -- ✅ FIX: Multiple cleanup messages mit Body Class Cleanup
    for i = 1, 3 do
        SendNUIMessage({
            type = 'closeAll',
            visible = false,
            action = 'forceHide'
        })
        
        SendNUIMessage({
            type = 'setBodyClass',
            class = 'nui-focus-active',
            add = false
        })
        
        SendNUIMessage({
            type = 'setBodyClass', 
            class = 'nui-modal-open',
            add = false
        })
    end
    
    Debug:Log("MENU", "NUI force closed with body class cleanup", nil, "WARN")
end

-- ✅ FIX: Item-basierte Access-Validierung
function SprayMenu:ValidateItemAccess()
    -- Prüfe ob Item-basierter Zugriff vorhanden
    if not self.currentAccess or not self.currentAccess.sprayType then
        return {
            allowed = false,
            reason = "Bitte verwende eine Spray-Dose um das Menü zu öffnen"
        }
    end
    
    -- Validiere Access-Metadaten
    if self.currentAccess.sprayType == "public" then
        return {
            allowed = true,
            reason = "Öffentlicher Zugang erlaubt",
            accessType = "public"
        }
    elseif self.currentAccess.sprayType == "gang" then
        -- Gang-Zugehörigkeit prüfen
        if not self.playerGang then
            return {
                allowed = false,
                reason = "Du bist in keiner Gang"
            }
        end
        
        return {
            allowed = true,
            reason = "Gang-Zugang erlaubt",
            accessType = "gang"
        }
    elseif self.currentAccess.sprayType == "job" then
        return {
            allowed = true,
            reason = "Job-Zugang erlaubt", 
            accessType = "job"
        }
    end
    
    return {
        allowed = false,
        reason = "Ungültiger Zugangs-Typ"
    }
end

-- ✅ FIX: Show Access Error ohne overlay
function SprayMenu:ShowAccessError(reason)
    lib.notify({
        title = 'Spray-System',
        description = reason,
        type = 'error',
        duration = 5000
    })
    
    Debug:Log("MENU", "Access validation failed", {
        reason = reason,
        currentAccess = self.currentAccess
    }, "WARN")
end

-- ✅ FIX: Available Templates laden mit Public + Gang Support
function SprayMenu:GetAvailableTemplates()
    local templates = {}
    
    -- ✅ FIX: Public Templates für alle (IMMER verfügbar, Priorität 1)
    if Config.Gangs.PublicTemplates then
        for templateId, templateConfig in pairs(Config.Gangs.PublicTemplates) do
            table.insert(templates, {
                id = templateId,
                name = templateConfig.name,
                description = templateConfig.description,
                filePath = templateConfig.filePath,
                category = "public",
                requiredGrade = 0,
                isPublic = true,
                available = true,
                priority = templateConfig.priority or 1
            })
        end
    end
    
    -- ✅ FIX: Gang Templates nur für Gang-Mitglieder (falls Gang-Access)
    if self.currentAccess and self.currentAccess.sprayType == "gang" and self.playerGang then
        local gangConfig = Config.Gangs.AllowedGangs[self.playerGang]
        
        if gangConfig and gangConfig.templates then
            for templateId, templateConfig in pairs(gangConfig.templates) do
                local isAvailable = self.playerGrade >= (templateConfig.requiredGrade or 0)
                
                table.insert(templates, {
                    id = templateId,
                    name = templateConfig.name,
                    description = templateConfig.description,
                    filePath = templateConfig.filePath,
                    category = templateConfig.category or "gang",
                    requiredGrade = templateConfig.requiredGrade or 0,
                    isPublic = false,
                    available = isAvailable,
                    priority = templateConfig.priority or 2
                })
            end
        end
        
        -- ✅ FIX: Global Gang Templates
        if Config.Gangs.GlobalTemplates then
            for templateId, templateConfig in pairs(Config.Gangs.GlobalTemplates) do
                local isAvailable = self.playerGrade >= (templateConfig.requiredGrade or 0)
                
                table.insert(templates, {
                    id = templateId,
                    name = templateConfig.name,
                    description = templateConfig.description,
                    filePath = templateConfig.filePath,
                    category = templateConfig.category or "global",
                    requiredGrade = templateConfig.requiredGrade or 0,
                    isPublic = false,
                    available = isAvailable,
                    priority = templateConfig.priority or 3
                })
            end
        end
    end
    
    -- ✅ FIX: Templates nach Priorität sortieren
    table.sort(templates, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        end
        return a.name < b.name
    end)
    
    Debug:Log("MENU", "Templates loaded", {
        totalCount = #templates,
        publicCount = self:CountTemplatesByType(templates, true),
        gangCount = self:CountTemplatesByType(templates, false),
        accessType = self.currentAccess.sprayType
    }, "INFO")
    
    return templates
end

-- ✅ FIX: Player Sprays Menu anzeigen
function SprayMenu:ShowPlayerSpraysMenu(sprays)
    if not sprays or #sprays == 0 then
        lib.notify({
            title = 'Meine Sprays',
            description = 'Du hast noch keine Sprays erstellt',
            type = 'info'
        })
        return
    end
    
    local options = {}
    
    for _, spray in ipairs(sprays) do
        local sprayType = spray.gang_name == "public" and "Öffentlich" or spray.gang_name
        local createdDate = spray.created_at and os.date("%d.%m.%Y %H:%M", spray.created_at) or "Unbekannt"
        
        table.insert(options, {
            title = string.format("Spray #%s", spray.spray_id:sub(1, 8)),
            description = string.format("Typ: %s | Erstellt: %s", sprayType, createdDate),
            icon = spray.gang_name == "public" and 'user' or 'users',
            metadata = {
                {label = 'Position', value = string.format("%.1f, %.1f, %.1f", 
                    spray.position.x or 0, spray.position.y or 0, spray.position.z or 0)},
                {label = 'Qualität', value = (spray.quality or 100) .. '%'},
                {label = 'Views', value = tostring(spray.views or 0)},
                {label = 'Typ', value = sprayType}
            },
            onSelect = function()
                self:ShowSprayOptions(spray)
            end
        })
    end
    
    -- Back Button
    table.insert(options, {
        title = '← Zurück',
        icon = 'arrow-left',
        onSelect = function()
            self:OpenMainMenu(self.currentAccess)
        end
    })
    
    lib.registerContext({
        id = 'spray_player_sprays',
        title = '📊 Meine Sprays (' .. #sprays .. ')',
        canClose = true,
        options = options,
        onExit = function()
            self.isOpen = false
            self.overlayPreventionActive = false
        end
    })
    
    lib.showContext('spray_player_sprays')
    
    Debug:Log("MENU", "Player sprays menu shown", {
        sprayCount = #sprays
    }, "INFO")
end

-- ✅ FIX: Spray Options anzeigen
function SprayMenu:ShowSprayOptions(spray)
    local options = {
        {
            title = '📍 Zu Spray teleportieren',
            description = 'Teleportiert dich zu diesem Spray',
            icon = 'map-marker',
            onSelect = function()
                self:TeleportToSpray(spray)
            end
        },
        {
            title = '🗑️ Spray löschen',
            description = 'Lösche dieses Spray permanent',
            icon = 'trash',
            onSelect = function()
                self:ConfirmDeleteSpray(spray)
            end
        },
        {
            title = '← Zurück',
            icon = 'arrow-left',
            onSelect = function()
                -- Zurück zur Player Sprays Liste
                TriggerServerEvent('spray:server:getPlayerSprays')
            end
        }
    }
    
    lib.registerContext({
        id = 'spray_options',
        title = 'Spray #' .. spray.spray_id:sub(1, 8),
        canClose = true,
        options = options,
        onExit = function()
            self.isOpen = false
            self.overlayPreventionActive = false
        end
    })
    
    lib.showContext('spray_options')
end

-- ✅ FIX: Admin Panel
function SprayMenu:OpenAdminPanel()
    local options = {
        {
            title = '📊 System Statistiken',
            description = 'Zeige Spray-System Statistiken',
            icon = 'chart-bar',
            onSelect = function()
                TriggerServerEvent('spray:server:requestSystemStats')
            end
        },
        {
            title = '🧹 Abgelaufene Sprays löschen',
            description = 'Lösche alle abgelaufenen Sprays',
            icon = 'clock',
            onSelect = function()
                local alert = lib.alertDialog({
                    header = 'Abgelaufene Sprays löschen',
                    content = 'Möchtest du alle abgelaufenen Sprays löschen?',
                    centered = true,
                    cancel = true
                })
                
                if alert == 'confirm' then
                    TriggerServerEvent('spray:server:adminCleanupExpired')
                end
            end
        },
        {
            title = '🗑️ Public Sprays löschen',
            description = 'Lösche alle öffentlichen Sprays',
            icon = 'users',
            onSelect = function()
                local alert = lib.alertDialog({
                    header = 'Public Sprays löschen',
                    content = 'Möchtest du ALLE öffentlichen Sprays löschen?',
                    centered = true,
                    cancel = true
                })
                
                if alert == 'confirm' then
                    ExecuteCommand('spray_clear_public')
                end
            end
        },
        {
            title = '🗑️ Alle Sprays löschen',
            description = 'Lösche ALLE Sprays (Vorsicht!)',
            icon = 'exclamation-triangle',
            onSelect = function()
                self:ConfirmFullCleanup()
            end
        },
        {
            title = '← Zurück',
            icon = 'arrow-left',
            onSelect = function()
                self:OpenMainMenu(self.currentAccess)
            end
        }
    }
    
    lib.registerContext({
        id = 'spray_admin_panel',
        title = '⚙️ Admin Panel',
        canClose = true,
        options = options,
        onExit = function()
            self.isOpen = false
            self.overlayPreventionActive = false
        end
    })
    
    lib.showContext('spray_admin_panel')
end

-- ✅ UTILITY FUNCTIONS

-- Zähle Templates nach Typ
function SprayMenu:CountTemplatesByType(templates, isPublic)
    local count = 0
    for _, template in ipairs(templates) do
        if template.isPublic == isPublic then
            count = count + 1
        end
    end
    return count
end

-- Utility Functions
function SprayMenu:CanUseSpraySystem()
    return self.currentAccess and self.currentAccess.sprayType ~= nil
end

function SprayMenu:IsPlayerAdmin()
    local PlayerData = QBCore.Functions.GetPlayerData()
    return PlayerData and PlayerData.job and 
           (PlayerData.job.name == 'admin' or PlayerData.job.name == 'police') and 
           PlayerData.job.grade.level >= 5
end

function SprayMenu:GetGangColors()
    -- ✅ FIX: Public Access: Standard-Farben
    if self.currentAccess.sprayType == "public" then
        return {'#FF0000', '#00FF00', '#0000FF', '#FFFF00', '#FF00FF', '#00FFFF'}
    end
    
    -- Gang Access: Gang-spezifische Farben
    if not self.playerGang or not Config.Gangs.AllowedGangs[self.playerGang] then
        return {'#FF0000', '#00FF00', '#0000FF'}
    end
    
    return Config.Gangs.AllowedGangs[self.playerGang].primaryColors or {'#FF0000'}
end

-- ✅ FIX: Performance Monitoring
function SprayMenu:StartPerformanceMonitoring()
    CreateThread(function()
        while true do
            Wait(30000) -- Alle 30 Sekunden
            
            if self.nuiFocusActive and not self.isRemovalMode then
                local memUsage = collectgarbage("count")
                
                if memUsage > 50000 then -- > 50MB
                    Debug:Log("MENU", "High memory usage detected", {
                        memUsage = memUsage
                    }, "WARN")
                    
                    self.performanceMode = true
                    collectgarbage("collect")
                end
            end
        end
    end)
end

-- ✅ FIX: Teleport zu Spray
function SprayMenu:TeleportToSpray(spray)
    if spray and spray.position then
        SetEntityCoords(PlayerPedId(), spray.position.x, spray.position.y, spray.position.z + 1.0, false, false, false, true)
        
        lib.notify({
            title = 'Teleportiert',
            description = 'Du wurdest zu deinem Spray teleportiert',
            type = 'success'
        })
        
        Debug:Log("MENU", "Player teleported to spray", {
            sprayId = spray.spray_id:sub(1, 8),
            position = spray.position
        }, "INFO")
    end
end

-- ✅ FIX: Spray löschen bestätigen
function SprayMenu:ConfirmDeleteSpray(spray)
    local alert = lib.alertDialog({
        header = 'Spray löschen',
        content = 'Möchtest du dieses Spray wirklich permanent löschen?',
        centered = true,
        cancel = true
    })
    
    if alert == 'confirm' then
        TriggerServerEvent('spray:server:removeSpray', spray.spray_id, "Player deletion", false)
        
        lib.notify({
            title = 'Spray gelöscht',
            description = 'Dein Spray wurde erfolgreich gelöscht',
            type = 'success'
        })
        
        Debug:Log("MENU", "Spray deletion confirmed", {
            sprayId = spray.spray_id:sub(1, 8)
        }, "INFO")
        
        -- Zurück zur Liste
        Wait(1000)
        TriggerServerEvent('spray:server:getPlayerSprays')
    end
end

-- Full Cleanup bestätigen
function SprayMenu:ConfirmFullCleanup()
    local alert = lib.alertDialog({
        header = '⚠️ WARNUNG: Alle Sprays löschen',
        content = 'Dies wird ALLE Sprays auf dem Server permanent löschen!\n\nBist du dir absolut sicher?',
        centered = true,
        cancel = true
    })
    
    if alert == 'confirm' then
        TriggerServerEvent('spray:server:adminFullCleanup')
        
        lib.notify({
            title = 'Admin Cleanup',
            description = 'Vollständige Spray-Bereinigung gestartet',
            type = 'success'
        })
    end
end

-- ✅ FIX: Enhanced ESC Key Handler
CreateThread(function()
    while true do
        Wait(0)
        
        if IsControlJustPressed(0, 322) then -- ESC Key
            if SprayMenu.nuiFocusActive or SprayMenu.isOpen or SprayMenu.isRemovalMode then
                -- Clean close sequence
                if SprayMenu.isOpen then
                    lib.hideContext()
                end
                
                if SprayMenu.isRemovalMode then
                    SprayMenu.isRemovalMode = false
                end
                
                SprayMenu:SafeDeactivateNUI()
                
                Debug:Log("MENU", "UI closed via ESC key", nil, "INFO")
            end
        end
    end
end)

-- ✅ FIX: Cleanup beim Resource-Stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if SprayMenu.isOpen then
            lib.hideContext()
        end
        
        SprayMenu:ForceCloseNUI()
        SprayMenu.isRemovalMode = false
        
        Debug:Log("MENU", "Spray menu cleanup completed", nil, "INFO")
    end
end)

-- ✅ FIX: Initialisierung mit Delay
CreateThread(function()
    Wait(2000) -- Warte bis alle anderen Systeme geladen sind
    SprayMenu:Initialize()
end)

Debug:Log("MENU", "Item-only spray menu system loaded", nil, "SUCCESS")