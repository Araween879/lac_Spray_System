-- =======================================
-- 📄 FILE: client/ui/spray_menu.lua
-- 🔌 STEP: STEP 7 — ITEM-ONLY SYSTEM + REMOVER
-- ✅ KOMPLETT ÜBERARBEITET: Nur Item-basiert + Entferner-System
-- VERSION: 2.0.0 - FIXED SYNTAX ERRORS
-- =======================================

-- Local Variables
local QBCore = exports['qb-core']:GetCoreObject()

SprayMenu = SprayMenu or {
    isOpen = false,
    currentMenu = nil,
    menuHistory = {},
    playerGang = nil,
    playerGrade = 0,
    nuiFocusActive = false,           -- Track NUI focus state
    overlayPreventionActive = false, -- Prevent unwanted overlays
    currentAccess = {},              -- ✅ NEU: Current access metadata from item
    isRemovalMode = false,           -- ✅ NEU: Entferner-Modus
    removalMetadata = {}             -- ✅ NEU: Entferner-Metadata
}

-- Initialisierung
function SprayMenu:Initialize()
    Debug:Log("MENU", "Initializing item-only spray menu system", nil, "INFO")
    
    -- Hole Gang-Informationen
    self:UpdatePlayerGang()
    
    -- Event Listeners
    self:RegisterEvents()
    
    -- Overlay Prevention System
    self:InitializeOverlayPrevention()
    
    Debug:Log("MENU", "Item-only spray menu system initialized", nil, "SUCCESS")
end

-- Overlay Prevention System
function SprayMenu:InitializeOverlayPrevention()
    CreateThread(function()
        while true do
            Wait(500) -- Check every 500ms
            
            -- Prüfe ob NUI Focus aktiv ist aber Menu geschlossen
            if self.nuiFocusActive and not self.isOpen then
                Debug:Log("MENU", "Detected orphaned NUI focus - cleaning up", nil, "WARN")
                self:ForceCloseNUI()
            end
            
            -- Gang-Änderungen überwachen
            if self.overlayPreventionActive then
                local currentGang = self:GetCurrentPlayerGang()
                if currentGang ~= self.playerGang then
                    Debug:Log("MENU", "Gang change detected during overlay", {
                        old = self.playerGang,
                        new = currentGang
                    }, "INFO")
                    self:HandleGangChange(currentGang)
                end
            end
        end
    end)
end

-- Force close NUI when orphaned
function SprayMenu:ForceCloseNUI()
    SetNuiFocus(false, false)
    self.nuiFocusActive = false
    self.isOpen = false
    self.overlayPreventionActive = false
    self.isRemovalMode = false
    
    -- Send cleanup message to NUI
    SendNUIMessage({
        type = 'forceCloseAll'
    })
    
    Debug:Log("MENU", "Force closed orphaned NUI", nil, "INFO")
end

-- Handle gang changes during UI operations
function SprayMenu:HandleGangChange(newGang)
    self.playerGang = newGang
    
    -- Close any open UIs immediately
    if self.isOpen then
        self:ForceCloseNUI()
        
        lib.notify({
            title = 'Gang-System',
            description = 'Gang-Zugehörigkeit geändert - UI wurde geschlossen',
            type = 'info'
        })
    end
end

-- Improved player gang detection
function SprayMenu:GetCurrentPlayerGang()
    local PlayerData = QBCore.Functions.GetPlayerData()
    
    if PlayerData and PlayerData.gang and PlayerData.gang.name ~= 'none' then
        return PlayerData.gang.name
    end
    
    return nil
end

-- Player Gang aktualisieren
function SprayMenu:UpdatePlayerGang()
    local PlayerData = QBCore.Functions.GetPlayerData()
    
    if PlayerData and PlayerData.gang then
        self.playerGang = PlayerData.gang.name
        self.playerGrade = PlayerData.gang.grade.level or 0
        
        Debug:Log("MENU", "Player gang updated", {
            gang = self.playerGang,
            grade = self.playerGrade
        }, "INFO")
    else
        self.playerGang = nil
        self.playerGrade = 0
        
        Debug:Log("MENU", "No gang data found for player", nil, "WARN")
    end
end

-- Event Registration
function SprayMenu:RegisterEvents()
    -- ✅ NEU: Item-basierte Aktivierung (HAUPT-EVENT)
    RegisterNetEvent('spray:client:openSprayMenu', function(metadata)
        if SprayMenu.isOpen or SprayMenu.overlayPreventionActive then 
            return 
        end
        
        -- Setze Metadata für aktuellen Zugriff
        SprayMenu.currentAccess = metadata or {}
        SprayMenu:OpenMainMenu()
    end)
    
    -- ✅ NEU: Entferner-Modus aktivieren
    RegisterNetEvent('spray:client:activateRemovalMode', function(metadata)
        SprayMenu.removalMetadata = metadata or {}
        SprayMenu:StartRemovalMode()
    end)
    
    -- Gang Update Event
    RegisterNetEvent('QBCore:Client:OnGangUpdate', function(GangInfo)
        local oldGang = SprayMenu.playerGang
        
        if GangInfo then
            SprayMenu.playerGang = GangInfo.name
            SprayMenu.playerGrade = GangInfo.grade.level or 0
        else
            SprayMenu.playerGang = nil
            SprayMenu.playerGrade = 0
        end
        
        -- Close UI if gang changed while open
        if oldGang ~= SprayMenu.playerGang and SprayMenu.isOpen then
            Debug:Log("MENU", "Gang changed while UI open - force closing", {
                oldGang = oldGang,
                newGang = SprayMenu.playerGang
            }, "INFO")
            
            SprayMenu:ForceCloseNUI()
            
            lib.notify({
                title = 'Gang-System',
                description = 'Gang-Zugehörigkeit geändert',
                type = 'info'
            })
        end
    end)
    
    -- Player Logout Event - Cleanup NUI
    RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
        if SprayMenu.isOpen then
            SprayMenu:ForceCloseNUI()
        end
    end)
    
    -- Spray Editor Results
    RegisterNetEvent('spray:client:editorResult', function(result)
        if result.success then
            lib.notify({
                title = 'Spray Editor',
                description = result.message or 'Aktion erfolgreich',
                type = 'success'
            })
        else
            lib.notify({
                title = 'Spray Editor',
                description = result.error or 'Ein Fehler ist aufgetreten',
                type = 'error'
            })
        end
    end)
    
    -- Template Results
    RegisterNetEvent('spray:client:templateResult', function(result)
        if result.success then
            lib.notify({
                title = 'Template',
                description = result.message or 'Template ausgewählt',
                type = 'success'
            })
        else
            lib.notify({
                title = 'Template',
                description = result.error or 'Template-Fehler',
                type = 'error'
            })
        end
    end)
    
    -- URL Results
    RegisterNetEvent('spray:client:urlResult', function(result)
        if result.success then
            lib.notify({
                title = 'URL-Bild',
                description = result.message or 'URL-Bild wird verwendet',
                type = 'success'
            })
        else
            lib.notify({
                title = 'URL-Bild',
                description = result.error or 'URL-Fehler',
                type = 'error'
            })
        end
    end)
    
    -- Placement Start Event
    RegisterNetEvent('spray:client:startPlacement', function(sprayData, placementMode)
        -- Ensure clean close before placement
        if SprayMenu.isOpen then
            lib.hideContext()
            SprayMenu:ForceCloseNUI()
        end
        
        -- Start placement mode
        CreateThread(function()
            Wait(100) -- Short delay for clean transition
            
            if placementMode == 'gizmo' then
                TriggerEvent('spray:client:startGizmoPlacement', sprayData)
            else
                TriggerEvent('spray:client:startManualPlacement', sprayData)
            end
        end)
    end)
    
    -- ✅ NEU: Player Sprays Response
    RegisterNetEvent('spray:client:receivePlayerSprays', function(sprays)
        SprayMenu:ShowPlayerSpraysMenu(sprays)
    end)
end

-- ✅ GEÄNDERT: Hauptmenü öffnen (nur noch Item-basiert)
function SprayMenu:OpenMainMenu()
    -- Prevent opening if already open or if overlay prevention active
    if self.isOpen or self.overlayPreventionActive then 
        Debug:Log("MENU", "Menu open blocked - already open or overlay prevention active", nil, "WARN")
        return 
    end
    
    -- ✅ Item-basierte Validierung (ersetzt Gang-Validation)
    local accessValidation = self:ValidateItemAccess()
    if not accessValidation.allowed then
        self:ShowAccessError(accessValidation.reason)
        return
    end
    
    self.isOpen = true
    self.overlayPreventionActive = true
    self.menuHistory = {}
    
    -- ✅ Dynamisches Menü basierend auf Access-Type
    local options = {}
    local sprayType = self.currentAccess.sprayType or "public"
    local menuTitle = sprayType == "public" and "🎨 Öffentliches Spray-System" or "🎨 Gang Spray System"
    
    table.insert(options, {
        title = '🎨 Custom Editor',
        description = 'Erstelle ein einzigartiges Spray-Design',
        icon = 'paint-brush',
        onSelect = function()
            self:OpenCustomEditor()
        end
    })
    
    table.insert(options, {
        title = '📋 Templates',
        description = sprayType == "public" and 'Wähle aus öffentlichen Templates' or 'Wähle aus Gang-Templates',
        icon = 'images',
        onSelect = function()
            self:OpenTemplateSelector()
        end
    })
    
    table.insert(options, {
        title = '🔗 URL-Bild',
        description = 'Verwende ein Bild von einer URL',
        icon = 'link',
        onSelect = function()
            self:OpenUrlInput()
        end
    })
    
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
    
    lib.registerContext({
        id = 'spray_main_menu',
        title = menuTitle,
        canClose = true,
        options = options,
        onExit = function() -- Handle menu close properly
            self.isOpen = false
            self.overlayPreventionActive = false
        end
    })
    
    lib.showContext('spray_main_menu')
end

-- ✅ NEU: Item-basierte Access-Validierung (ersetzt Gang-Validation)
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

-- Show access error without overlay
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

-- Custom Editor öffnen - Improved NUI handling
function SprayMenu:OpenCustomEditor()
    lib.hideContext()
    
    CreateThread(function()
        Wait(100) -- Delay for smooth transition
        
        -- Safe NUI activation
        self:SafeActivateNUI()
        
        -- Gang-Farben vorbereiten
        local gangColors = self:GetGangColors()
        
        -- Editor öffnen
        SendNUIMessage({
            type = 'openSprayEditor',
            gang = self.playerGang,
            gangColors = gangColors,
            accessType = self.currentAccess.sprayType,
            visible = true -- Explicit visibility flag
        })
        
        Debug:Log("MENU", "Custom editor opened", {
            gang = self.playerGang,
            accessType = self.currentAccess.sprayType,
            colors = #gangColors
        }, "INFO")
    end)
end

-- Template Selector öffnen - Improved NUI handling  
function SprayMenu:OpenTemplateSelector()
    lib.hideContext()
    
    CreateThread(function()
        Wait(100) -- Delay for smooth transition
        
        -- Safe NUI activation
        self:SafeActivateNUI()
        
        -- Template-Daten vorbereiten
        local templates = self:GetAvailableTemplates()
        
        -- Template Selector öffnen
        SendNUIMessage({
            type = 'openTemplateSelector',
            gang = self.playerGang,
            grade = self.playerGrade,
            templates = templates,
            accessType = self.currentAccess.sprayType,
            visible = true -- Explicit visibility flag
        })
        
        Debug:Log("MENU", "Template selector opened", {
            gang = self.playerGang,
            accessType = self.currentAccess.sprayType,
            templates = #templates
        }, "INFO")
    end)
end

-- URL Input öffnen - Improved NUI handling
function SprayMenu:OpenUrlInput()
    lib.hideContext()
    
    CreateThread(function()
        Wait(100) -- Delay for smooth transition
        
        -- Safe NUI activation
        self:SafeActivateNUI()
        
        -- URL Input öffnen
        SendNUIMessage({
            type = 'openUrlInput',
            gang = self.playerGang,
            accessType = self.currentAccess.sprayType,
            visible = true -- Explicit visibility flag
        })
        
        Debug:Log("MENU", "URL input opened", {
            gang = self.playerGang,
            accessType = self.currentAccess.sprayType
        }, "INFO")
    end)
end

-- Safe NUI activation
function SprayMenu:SafeActivateNUI()
    -- Ensure clean state first
    if self.nuiFocusActive then
        SetNuiFocus(false, false)
        Wait(50)
    end
    
    -- Activate NUI
    SetNuiFocus(true, true)
    self.nuiFocusActive = true
    self.isOpen = false -- Menu is closed, NUI is active
    
    Debug:Log("MENU", "NUI safely activated", nil, "INFO")
end

-- Safe NUI deactivation
function SprayMenu:SafeDeactivateNUI()
    SetNuiFocus(false, false)
    self.nuiFocusActive = false
    self.overlayPreventionActive = false
    
    -- Send cleanup message
    SendNUIMessage({
        type = 'closeAll',
        visible = false
    })
    
    Debug:Log("MENU", "NUI safely deactivated", nil, "INFO")
end

-- ✅ NEU: Entferner-Modus starten
function SprayMenu:StartRemovalMode()
    self.isRemovalMode = true
    
    lib.notify({
        title = 'Graffiti-Entferner',
        description = 'Ziele auf ein Spray und drücke [E] zum Entfernen. [ESC] zum Abbrechen.',
        type = 'info',
        duration = 8000
    })
    
    -- Starte Removal-Thread
    CreateThread(function()
        local timeout = GetGameTimer() + 30000 -- 30 Sekunden Timeout
        
        while self.isRemovalMode and GetGameTimer() < timeout do
            Wait(0)
            
            -- E Key für Entfernung
            if IsControlJustPressed(0, 38) then -- E Key
                local success = self:AttemptSprayRemoval()
                if success then
                    self.isRemovalMode = false
                    break
                end
            end
            
            -- ESC zum Abbrechen
            if IsControlJustPressed(0, 177) then -- ESC
                self.isRemovalMode = false
                lib.notify({
                    title = 'Graffiti-Entferner',
                    description = 'Entferner-Modus abgebrochen',
                    type = 'info'
                })
                break
            end
            
            -- Visual Feedback (optional)
            if Config.Debug.enabled then
                local playerCoords = GetEntityCoords(PlayerPedId())
                DrawMarker(1, playerCoords.x, playerCoords.y, playerCoords.z - 1.0, 
                    0, 0, 0, 0, 0, 0, 
                    2.0, 2.0, 0.5, 
                    255, 0, 0, 100, 
                    false, false, 2, false, nil, nil, false)
            end
        end
        
        if GetGameTimer() >= timeout then
            self.isRemovalMode = false
            lib.notify({
                title = 'Graffiti-Entferner',
                description = 'Entferner-Modus Timeout',
                type = 'warning'
            })
        end
    end)
end

-- ✅ NEU: Spray-Entfernung versuchen
function SprayMenu:AttemptSprayRemoval()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local nearbySpray = nil
    local closestDistance = (self.removalMetadata and self.removalMetadata.range) or 5.0
    
    -- Suche naheliegendstes Spray
    if SprayCache and SprayCache.nearby then
        for sprayId, sprayInfo in pairs(SprayCache.nearby) do
            local distance = #(playerCoords - sprayInfo.data.coords)
            
            if distance < closestDistance then
                nearbySpray = sprayId
                closestDistance = distance
            end
        end
    end
    
    if not nearbySpray then
        lib.notify({
            title = 'Graffiti-Entferner',
            description = string.format('Kein Spray in %.1fm Reichweite gefunden', closestDistance),
            type = 'error'
        })
        return false
    end
    
    -- Progress Bar für Entfernung
    local progressTime = 3000
    local success = lib.progressBar({
        duration = progressTime,
        label = 'Graffiti wird entfernt...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'amb@world_human_maid_clean@',
            clip = 'base'
        }
    })
    
    if success then
        -- Sende Entfernungsanfrage an Server (mit Item-Flag)
        TriggerServerEvent('spray:server:removeSprayWithItem', nearbySpray)
        
        Debug:Log("MENU", "Spray removal attempted with item", {
            sprayId = nearbySpray,
            distance = closestDistance
        }, "INFO")
        
        return true
    else
        lib.notify({
            title = 'Graffiti-Entferner',
            description = 'Entfernung abgebrochen',
            type = 'warning'
        })
    end
    
    return false
end

-- Player Sprays anzeigen
function SprayMenu:OpenPlayerSprays()
    -- Request player sprays from server
    TriggerServerEvent('spray:server:getPlayerSprays')
    
    lib.notify({
        title = 'Meine Sprays',
        description = 'Lade Spray-Daten...',
        type = 'info',
        duration = 2000
    })
end

-- ✅ NEU: Player Sprays Menu anzeigen
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
            self:OpenMainMenu()
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
end

-- Spray-Optionen anzeigen
function SprayMenu:ShowSprayOptions(spray)
    local options = {
        {
            title = '📍 Zu Spray teleportieren',
            description = 'Teleportiere dich zu diesem Spray',
            icon = 'map-marker-alt',
            onSelect = function()
                local coords = vector3(spray.position.x, spray.position.y, spray.position.z)
                SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z)
                lib.notify({
                    title = 'Teleport',
                    description = 'Du wurdest zum Spray teleportiert',
                    type = 'success'
                })
            end
        },
        {
            title = '🗑️ Spray löschen',
            description = 'Lösche dieses Spray permanent',
            icon = 'trash',
            onSelect = function()
                self:ConfirmSprayDeletion(spray)
            end
        },
        {
            title = '← Zurück zu Sprays',
            icon = 'arrow-left',
            onSelect = function()
                self:OpenPlayerSprays()
            end
        }
    }
    
    local sprayType = spray.gang_name == "public" and "Öffentlich" or spray.gang_name
    
    lib.registerContext({
        id = 'spray_options',
        title = string.format('Spray #%s (%s)', spray.spray_id:sub(1, 8), sprayType),
        canClose = true,
        options = options,
        onExit = function()
            self.isOpen = false
            self.overlayPreventionActive = false
        end
    })
    
    lib.showContext('spray_options')
end

-- Spray-Löschung bestätigen
function SprayMenu:ConfirmSprayDeletion(spray)
    local sprayType = spray.gang_name == "public" and "öffentliche" or "Gang-"
    
    local alert = lib.alertDialog({
        header = 'Spray löschen',
        content = string.format('Möchtest du dieses %s Spray wirklich permanent löschen?', sprayType),
        centered = true,
        cancel = true
    })
    
    if alert == 'confirm' then
        TriggerServerEvent('spray:server:removeSpray', spray.spray_id, 'owner_delete', false)
        
        lib.notify({
            title = 'Spray gelöscht',
            description = 'Das Spray wurde erfolgreich gelöscht',
            type = 'success'
        })
        
        -- Zurück zur Spray-Liste
        self:OpenPlayerSprays()
    end
end

-- Admin Panel (verkürzt für Platzbedarf)
function SprayMenu:OpenAdminPanel()
    if not self:IsPlayerAdmin() then return end
    
    local options = {
        {
            title = '📊 System-Statistiken',
            description = 'Zeige Spray-System Statistiken',
            icon = 'chart-bar',
            onSelect = function()
                self:ShowSystemStats()
            end
        },
        {
            title = '🧹 System-Cleanup',
            description = 'Räume abgelaufene Sprays auf',
            icon = 'broom',
            onSelect = function()
                TriggerServerEvent('spray:server:adminCleanup')
            end
        },
        {
            title = '🗑️ Public Sprays löschen',
            description = 'Lösche alle öffentlichen Sprays',
            icon = 'user-times',
            onSelect = function()
                local alert = lib.alertDialog({
                    header = 'Public Sprays löschen',
                    content = 'Alle öffentlichen Sprays permanent löschen?',
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
                self:OpenMainMenu()
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

-- ✅ ERWEITERT: Template-Loading für Public + Gang Support
function SprayMenu:GetAvailableTemplates()
    local templates = {}
    
    -- ✅ Public Templates für alle (IMMER verfügbar, Priorität 1)
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
    
    -- Gang Templates nur für Gang-Mitglieder (falls Gang-Access)
    if self.currentAccess and self.currentAccess.sprayType == "gang" and self.playerGang then
        local gangConfig = Config.Gangs.AllowedGangs[self.playerGang]
        
        if gangConfig and gangConfig.templates then
            for _, templateId in ipairs(gangConfig.templates) do
                local templateConfig = Config.Gangs.Templates[templateId]
                if templateConfig then
                    table.insert(templates, {
                        id = templateId,
                        name = templateConfig.name,
                        description = templateConfig.description,
                        filePath = templateConfig.filePath,
                        category = "gang",
                        requiredGrade = templateConfig.requiredGrade or 0,
                        isPublic = false,
                        available = self.playerGrade >= (templateConfig.requiredGrade or 0),
                        priority = 100 + (templateConfig.requiredGrade or 0)
                    })
                end
            end
        end
    end
    
    -- Sortiere nach Priorität (Public Templates zuerst)
    table.sort(templates, function(a, b) 
        return a.priority < b.priority 
    end)
    
    Debug:Log("MENU", "Templates loaded", {
        totalTemplates = #templates,
        publicTemplates = self:CountTemplatesByType(templates, true),
        gangTemplates = self:CountTemplatesByType(templates, false),
        accessType = self.currentAccess.sprayType
    }, "INFO")
    
    return templates
end

-- Helper: Zähle Templates nach Typ
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
    -- Ersetzt durch Item-basierte Validierung
    return self.currentAccess and self.currentAccess.sprayType ~= nil
end

function SprayMenu:IsPlayerAdmin()
    local PlayerData = QBCore.Functions.GetPlayerData()
    return PlayerData and PlayerData.job and 
           (PlayerData.job.name == 'admin' or PlayerData.job.name == 'police') and 
           PlayerData.job.grade.level >= 5
end

function SprayMenu:GetGangColors()
    -- ✅ Public Access: Standard-Farben
    if self.currentAccess.sprayType == "public" then
        return {'#FF0000', '#00FF00', '#0000FF', '#FFFF00', '#FF00FF', '#00FFFF'} -- Regenbogen-Farben
    end
    
    -- Gang Access: Gang-spezifische Farben
    if not self.playerGang or not Config.Gangs.AllowedGangs[self.playerGang] then
        return {'#FF0000', '#00FF00', '#0000FF'} -- Default colors
    end
    
    return Config.Gangs.AllowedGangs[self.playerGang].primaryColors or {'#FF0000'}
end

-- Confirm Full Cleanup (für Admin Panel)
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

-- Show System Stats (für Admin Panel)
function SprayMenu:ShowSystemStats()
    TriggerServerEvent('spray:server:requestSystemStats')
end

-- NUI Callbacks - Enhanced callback handling
RegisterNUICallback('closeEditor', function(data, cb)
    SprayMenu:SafeDeactivateNUI()
    cb('ok')
end)

RegisterNUICallback('saveSprayDesign', function(data, cb)
    SprayMenu:SafeDeactivateNUI()
    TriggerServerEvent('spray:server:saveSprayDesign', data)
    cb('ok')
end)

RegisterNUICallback('useTemplate', function(data, cb)
    SprayMenu:SafeDeactivateNUI()
    TriggerServerEvent('spray:server:useTemplate', data)
    cb('ok')
end)

RegisterNUICallback('useUrlImage', function(data, cb)
    SprayMenu:SafeDeactivateNUI()
    TriggerServerEvent('spray:server:useUrlImage', data)
    cb('ok')
end)

-- ESC Key Handler - Enhanced ESC handling
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

-- Cleanup beim Resource-Stop - Enhanced cleanup
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

-- Initialisierung
CreateThread(function()
    Wait(2000) -- Warte bis alle anderen Systeme geladen sind
    SprayMenu:Initialize()
end)

Debug:Log("MENU", "Item-only spray menu system loaded", nil, "SUCCESS")