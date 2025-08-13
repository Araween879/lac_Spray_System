-- Spray Placement System mit object_gizmo Integration
-- Präzise 3D-Positionierung und Vorschau-System
-- ✅ VEREINFACHT: Item-Only System - Permission Check entfernt

PlacementSystem = PlacementSystem or {
    isActive = false,
    previewObject = nil,
    currentTextureData = nil,
    placementMode = 'manual',  -- 'manual', 'auto', 'gizmo'
    lastRaycastResult = nil,
    placementConstraints = {
        minDistance = 1.0,
        maxDistance = 5.0,
        snapToSurface = true,
        alignToNormal = true
    }
}

-- Hauptfunktion: Starte Spray-Platzierung
function PlacementSystem:StartPlacement(textureData, mode)
    Debug:StartProfile("PlacementSystem_StartPlacement", "PLACEMENT")
    
    if self.isActive then
        self:CancelPlacement()
    end
    
    self.currentTextureData = textureData
    self.placementMode = mode or 'manual'
    self.isActive = true
    
    -- ✅ VEREINFACHT: Permission Check entfernt (wurde bereits beim Item-Use geprüft)
    local hasPermission = self:CheckPlacementRequirements()
    if not hasPermission then
        Debug:EndProfile("PlacementSystem_StartPlacement")
        return false
    end
    
    -- Starte entsprechenden Platzierungsmodus
    local success = false
    if self.placementMode == 'gizmo' then
        success = self:StartGizmoPlacement()
    elseif self.placementMode == 'auto' then
        success = self:StartAutoPlacement()
    else
        success = self:StartManualPlacement()
    end
    
    if success then
        Debug:Log("PLACEMENT", "Spray placement started", {
            mode = self.placementMode,
            textureType = textureData.type
        }, "SUCCESS")
    else
        self:CancelPlacement()
    end
    
    Debug:EndProfile("PlacementSystem_StartPlacement")
    return success
end

-- ✅ GEÄNDERT: Vereinfachte Requirement-Checks (nur noch Basic Checks)
function PlacementSystem:CheckPlacementRequirements()
    local playerPed = PlayerPedId()
    
    -- Basic Checks
    if not playerPed or not DoesEntityExist(playerPed) then
        lib.notify({
            title = 'Spray System',
            description = 'Ungültiger Spieler',
            type = 'error'
        })
        return false
    end
    
    -- Vehicle Check
    if IsPedInAnyVehicle(playerPed, false) then
        lib.notify({
            title = 'Spray System',
            description = 'Du kannst nicht in einem Fahrzeug sprayen',
            type = 'error'
        })
        return false
    end
    
    -- Water Check
    if IsPedSwimming(playerPed) then
        lib.notify({
            title = 'Spray System',
            description = 'Du kannst nicht im Wasser sprayen',
            type = 'error'
        })
        return false
    end
    
    -- Combat Check
    if IsPedInCombat(playerPed, 0) then
        lib.notify({
            title = 'Spray System',
            description = 'Du kannst nicht im Kampf sprayen',
            type = 'error'
        })
        return false
    end
    
    -- ✅ ENTFERNT: Item-Check (wird bereits beim Item-Use gemacht)
    -- ✅ ENTFERNT: Permission-Check (wird bereits beim Item-Use gemacht)
    
    return true
end

-- Manuelle Platzierung mit Raycast-Preview
function PlacementSystem:StartManualPlacement()
    Debug:StartProfile("PlacementSystem_StartManualPlacement", "PLACEMENT")
    
    -- Ox-lib Text UI für Kontrolls
    lib.showTextUI('[E] Platzieren | [R] Rotieren | [Mausrad] Größe | [ESC] Abbrechen', {
        position = "top-center",
        icon = 'spray-can'
    })
    
    -- Starte Preview-Loop
    CreateThread(function()
        local lastValidPosition = nil
        local rotationOffset = 0.0
        local sizeMultiplier = 1.0
        
        while self.isActive do
            Wait(0)
            
            -- Input Handling
            if IsControlJustPressed(0, 38) then -- E Key
                if lastValidPosition then
                    self:ConfirmPlacement(lastValidPosition, rotationOffset, sizeMultiplier)
                    break
                end
            end
            
            if IsControlJustPressed(0, 45) then -- R Key
                rotationOffset = (rotationOffset + 45.0) % 360.0
                PlaySoundFrontend(-1, "CLICK_BACK", "WEB_NAVIGATION_SOUNDS_PHONE", 1)
            end
            
            if IsControlPressed(0, 241) then -- Mouse Wheel Up
                sizeMultiplier = math.min(sizeMultiplier + 0.1, 2.0)
            elseif IsControlPressed(0, 242) then -- Mouse Wheel Down
                sizeMultiplier = math.max(sizeMultiplier - 0.1, 0.5)
            end
            
            if IsControlJustPressed(0, 177) then -- ESC
                self:CancelPlacement()
                break
            end
            
            -- Raycast für Preview-Position
            local raycastResult = RaycastSystem:CastSprayRay(self.placementConstraints.maxDistance)
            
            if raycastResult then
                lastValidPosition = raycastResult
                self:UpdatePreviewObject(raycastResult, rotationOffset, sizeMultiplier)
            else
                lastValidPosition = nil
                self:HidePreviewObject()
            end
        end
        
        lib.hideTextUI()
        self:HidePreviewObject()
    end)
    
    Debug:EndProfile("PlacementSystem_StartManualPlacement")
    return true
end

-- Object Gizmo Platzierung (präzise 3D-Manipulation)
function PlacementSystem:StartGizmoPlacement()
    Debug:StartProfile("PlacementSystem_StartGizmoPlacement", "PLACEMENT")
    
    -- Prüfe ob object_gizmo verfügbar ist
    if not exports.object_gizmo then
        lib.notify({
            title = 'Spray System',
            description = 'Object Gizmo nicht verfügbar',
            type = 'error'
        })
        Debug:EndProfile("PlacementSystem_StartGizmoPlacement")
        return false
    end
    
    -- Initial Raycast für Startposition
    local raycastResult = RaycastSystem:CastObjectPlacementRay(self.placementConstraints.maxDistance)
    if not raycastResult then
        lib.notify({
            title = 'Spray System',
            description = 'Keine geeignete Oberfläche gefunden',
            type = 'error'
        })
        Debug:EndProfile("PlacementSystem_StartGizmoPlacement")
        return false
    end
    
    -- Erstelle Preview-Object
    local model = `prop_cs_spray_can`  -- Placeholder-Model
    lib.requestModel(model)
    
    self.previewObject = CreateObject(model, raycastResult.coords.x, raycastResult.coords.y, raycastResult.coords.z, false, false, false)
    SetEntityRotation(self.previewObject, raycastResult.rotation.x, raycastResult.rotation.y, raycastResult.rotation.z, 2, true)
    SetEntityAlpha(self.previewObject, 150, false)
    
    -- Ox-lib Progress mit object_gizmo
    lib.showTextUI('[PFEILE] Bewegen | [STRG+PFEILE] Rotieren | [ENTER] Bestätigen | [ESC] Abbrechen')
    
    CreateThread(function()
        -- Starte object_gizmo
        local gizmoResult = exports.object_gizmo:useGizmo(self.previewObject, {
            enableMovement = true,
            enableRotation = true,
            enableScaling = false,
            snapToGround = false,
            gridSnap = 0.1,
            rotationSnap = 15.0
        })
        
        lib.hideTextUI()
        
        if gizmoResult and gizmoResult.confirmed then
            -- Hole finale Position und Rotation
            local finalCoords = GetEntityCoords(self.previewObject)
            local finalRotation = GetEntityRotation(self.previewObject, 2)
            
            local placementData = {
                coords = finalCoords,
                rotation = finalRotation,
                normal = raycastResult.normal, -- Verwende ursprüngliche Surface Normal
                metadata = {
                    placementMethod = 'gizmo',
                    originalSurface = raycastResult.coords
                }
            }
            
            self:ConfirmPlacement(placementData, 0.0, 1.0)
        else
            self:CancelPlacement()
        end
        
        -- Cleanup Preview Object
        if self.previewObject then
            DeleteObject(self.previewObject)
            self.previewObject = nil
        end
    end)
    
    Debug:EndProfile("PlacementSystem_StartGizmoPlacement")
    return true
end

-- Auto-Platzierung (direkter Raycast ohne Preview)
function PlacementSystem:StartAutoPlacement()
    Debug:StartProfile("PlacementSystem_StartAutoPlacement", "PLACEMENT")
    
    local raycastResult = RaycastSystem:CastSprayRay(self.placementConstraints.maxDistance)
    
    if raycastResult then
        -- Direkter Raycast-Check und Platzierung
        local placementData = {
            coords = raycastResult.coords,
            rotation = raycastResult.rotation,
            normal = raycastResult.normal,
            metadata = {
                placementMethod = 'auto',
                distance = raycastResult.metadata.distance
            }
        }
        
        self:ConfirmPlacement(placementData, 0.0, 1.0)
    else
        lib.notify({
            title = 'Spray System',
            description = 'Keine geeignete Oberfläche gefunden',
            type = 'error'
        })
        self:CancelPlacement()
    end
    
    Debug:EndProfile("PlacementSystem_StartAutoPlacement")
    return true
end

-- Preview Object erstellen und aktualisieren
function PlacementSystem:UpdatePreviewObject(raycastResult, rotationOffset, sizeMultiplier)
    if not self.previewObject then
        local model = `prop_cs_spray_can`
        lib.requestModel(model)
        
        self.previewObject = CreateObject(model, raycastResult.coords.x, raycastResult.coords.y, raycastResult.coords.z, false, false, false)
        SetEntityAlpha(self.previewObject, 150, false)
        SetEntityCollision(self.previewObject, false, false)
    end
    
    -- Position und Rotation aktualisieren
    local finalRotation = vector3(
        raycastResult.rotation.x,
        raycastResult.rotation.y,
        raycastResult.rotation.z + rotationOffset
    )
    
    SetEntityCoords(self.previewObject, raycastResult.coords.x, raycastResult.coords.y, raycastResult.coords.z, false, false, false, false)
    SetEntityRotation(self.previewObject, finalRotation.x, finalRotation.y, finalRotation.z, 2, true)
    
    -- Größe durch Alpha-Simulation (echter Scaling würde Collision beeinflussen)
    local alpha = math.floor(100 + (sizeMultiplier - 1.0) * 50)
    SetEntityAlpha(self.previewObject, math.max(50, math.min(255, alpha)), false)
    
    -- Visual Effects für Preview
    if Config.Effects.useParticles then
        self:CreatePreviewParticles(raycastResult.coords)
    end
end

function PlacementSystem:HidePreviewObject()
    if self.previewObject then
        SetEntityAlpha(self.previewObject, 0, false)
    end
end

function PlacementSystem:CreatePreviewParticles(coords)
    -- Leichte Partikel-Effekte für Preview (nicht zu aufdringlich)
    if not HasNamedPtfxAssetLoaded("core") then
        RequestNamedPtfxAsset("core")
        return
    end
    
    UseParticleFxAssetNextCall("core")
    StartParticleFxNonLoopedAtCoord(
        "ent_dst_dust_impact_light",
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        0.1, -- Scale
        false, false, false
    )
end

-- Platzierung bestätigen
function PlacementSystem:ConfirmPlacement(placementData, rotationOffset, sizeMultiplier)
    Debug:StartProfile("PlacementSystem_ConfirmPlacement", "PLACEMENT")
    
    -- Finale Daten zusammenstellen
    local finalData = {
        coords = placementData.coords,
        rotation = vector3(
            placementData.rotation.x,
            placementData.rotation.y,
            (placementData.rotation.z + rotationOffset) % 360.0
        ),
        normal = placementData.normal,
        textureData = self.currentTextureData,
        scale = sizeMultiplier,
        metadata = placementData.metadata or {}
    }
    
    -- ✅ VEREINFACHT: Erweiterte Client-Validierung (optional)
    if not self:ValidateBeforePlacement(finalData) then
        Debug:EndProfile("PlacementSystem_ConfirmPlacement")
        return false
    end
    
    -- Progress Bar für Spray-Aktion
    local success = lib.progressBar({
        duration = 5000,
        label = 'Spray wird aufgetragen...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
            mouse = false
        },
        anim = {
            dict = 'switch@franklin@lamar_tagging_wall',
            clip = 'lamar_tagging_wall_loop_lamar',
            flag = 49
        },
        prop = {
            model = `prop_cs_spray_can`,
            pos = vec3(0.0, 0.0, 0.07),
            rot = vec3(0.0, 0.0, 0.0),
            bone = 28422
        }
    })
    
    if success then
        -- Sende an Server
        TriggerServerEvent('spray:server:createSpray', finalData)
        
        -- Sound Effects
        if Config.Effects.playSounds then
            PlaySoundFromEntity(-1, Config.Effects.spraySound or "spray_can_shake", PlayerPedId(), 0, 0, 0)
        end
        
        lib.notify({
            title = 'Spray System',
            description = 'Spray wurde platziert',
            type = 'success'
        })
        
        Debug:Log("PLACEMENT", "Spray placement confirmed", finalData, "SUCCESS")
    else
        lib.notify({
            title = 'Spray System',
            description = 'Spray-Vorgang abgebrochen',
            type = 'warning'
        })
    end
    
    self:CancelPlacement()
    Debug:EndProfile("PlacementSystem_ConfirmPlacement")
    return success
end

-- ✅ VEREINFACHT: Optionale Validierung vor Platzierung
function PlacementSystem:ValidateBeforePlacement(data)
    -- Distance Check zu anderen Sprays
    local nearbyCheck = self:CheckNearbySprayDistance(data.coords)
    if not nearbyCheck.valid then
        lib.notify({
            title = 'Spray System',
            description = nearbyCheck.reason,
            type = 'error'
        })
        return false
    end
    
    -- Height Check (nicht zu hoch/niedrig)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local heightDiff = math.abs(data.coords.z - playerCoords.z)
    
    if heightDiff > 3.0 then
        lib.notify({
            title = 'Spray System',
            description = 'Position zu weit von deiner Höhe entfernt',
            type = 'error'
        })
        return false
    end
    
    -- Area-spezifische Checks
    local areaCheck = self:CheckRestrictedAreas(data.coords)
    if not areaCheck.valid then
        lib.notify({
            title = 'Spray System',
            description = areaCheck.reason,
            type = 'error'
        })
        return false
    end
    
    return true
end

-- Check Distanz zu anderen Sprays
function PlacementSystem:CheckNearbySprayDistance(coords)
    if not SprayCache or not SprayCache.nearby then
        return {valid = true}
    end
    
    for sprayId, sprayInfo in pairs(SprayCache.nearby) do
        local distance = #(coords - sprayInfo.data.coords)
        
        if distance < Config.Physics.minPlacementDistance then
            return {
                valid = false,
                reason = string.format("Zu nah an anderem Spray (%.1fm entfernt, min: %.1fm)", 
                    distance, Config.Physics.minPlacementDistance)
            }
        end
    end
    
    return {valid = true}
end

-- Check für verbotene Bereiche
function PlacementSystem:CheckRestrictedAreas(coords)
    for _, zone in ipairs(Config.Permissions.neutralZones or {}) do
        local distance = #(coords - zone.coords)
        if distance < zone.radius then
            return {
                valid = false,
                reason = "Sprays in diesem Bereich nicht erlaubt"
            }
        end
    end
    
    return {valid = true}
end

-- Platzierung abbrechen
function PlacementSystem:CancelPlacement()
    Debug:StartProfile("PlacementSystem_CancelPlacement", "PLACEMENT")
    
    self.isActive = false
    self.currentTextureData = nil
    self.lastRaycastResult = nil
    
    -- Cleanup Preview Object
    if self.previewObject then
        DeleteObject(self.previewObject)
        self.previewObject = nil
    end
    
    -- Hide UI
    lib.hideTextUI()
    
    -- Clear Notifications
    lib.hideContext()
    
    Debug:Log("PLACEMENT", "Spray placement cancelled", nil, "INFO")
    Debug:EndProfile("PlacementSystem_CancelPlacement")
end

-- Event Handlers
RegisterNetEvent('spray:client:startPlacement', function(textureData, mode)
    PlacementSystem:StartPlacement(textureData, mode)
end)

RegisterNetEvent('spray:client:startManualPlacement', function(textureData)
    PlacementSystem:StartPlacement(textureData, 'manual')
end)

RegisterNetEvent('spray:client:startGizmoPlacement', function(textureData)
    PlacementSystem:StartPlacement(textureData, 'gizmo')
end)

RegisterNetEvent('spray:client:cancelPlacement', function()
    PlacementSystem:CancelPlacement()
end)

-- Cleanup beim Resource Stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        PlacementSystem:CancelPlacement()
    end
end)

-- Toggle Platzierungs-Modus (für Debug/Testing)
RegisterCommand('spray_placement_mode', function(source, args)
    if not PlacementSystem.isActive then
        lib.notify({
            title = 'Spray System',
            description = 'Keine aktive Platzierung',
            type = 'error'
        })
        return
    end
    
    local modes = {'manual', 'auto', 'gizmo'}
    local currentIndex = 1
    
    for i, mode in ipairs(modes) do
        if mode == PlacementSystem.placementMode then
            currentIndex = i
            break
        end
    end
    
    local nextIndex = (currentIndex % #modes) + 1
    PlacementSystem.placementMode = modes[nextIndex]
    
    lib.notify({
        title = 'Spray System',
        description = 'Modus gewechselt zu: ' .. PlacementSystem.placementMode,
        type = 'info'
    })
end, false)

Debug:Log("PLACEMENT", "Item-only placement system initialized", nil, "SUCCESS")