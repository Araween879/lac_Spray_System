-- Raycast System für präzise Spray-Platzierung
-- Optimierte Surface-Detection mit Material-Validation und Normale-Berechnung

RaycastSystem = RaycastSystem or {
    cache = {},                       -- Cache für häufige Raycast-Resultate
    lastRaycast = 0,                  -- Letzter Raycast-Zeitpunkt (Performance)
    statistics = {
        totalRaycasts = 0,
        successfulHits = 0,
        invalidSurfaces = 0,
        cacheHits = 0
    }
}

-- Hauptfunktion: Raycast für Spray-Platzierung
function RaycastSystem:CastSprayRay(maxDistance, useCache)
    maxDistance = maxDistance or Config.Physics.raycastDistance
    useCache = useCache == nil and true or useCache
    
    Debug:StartProfile("RaycastSystem_CastSprayRay", "RAYCAST")
    
    self.statistics.totalRaycasts = self.statistics.totalRaycasts + 1
    
    -- Performance-Optimierung: Limitiere Raycast-Frequenz
    local currentTime = GetGameTimer()
    if currentTime - self.lastRaycast < 50 then -- Max 20 Raycasts pro Sekunde
        Debug:EndProfile("RaycastSystem_CastSprayRay")
        return self.lastResult
    end
    self.lastRaycast = currentTime
    
    local playerPed = PlayerPedId()
    if not playerPed or not DoesEntityExist(playerPed) then
        Debug:Log("RAYCAST", "Invalid player ped for raycast", nil, "ERROR")
        Debug:EndProfile("RaycastSystem_CastSprayRay")
        return nil
    end
    
    -- Hole Player-Position und Blickrichtung
    local playerCoords = GetEntityCoords(playerPed)
    local forwardVector = GetEntityForwardVector(playerPed)
    local endCoords = playerCoords + (forwardVector * maxDistance)
    
    -- Cache-Key für wiederholte Raycasts an ähnlichen Positionen
    local cacheKey = nil
    if useCache then
        cacheKey = string.format("%.1f_%.1f_%.1f_%.1f", 
            playerCoords.x, playerCoords.y, playerCoords.z, maxDistance)
        
        if self.cache[cacheKey] and (currentTime - self.cache[cacheKey].timestamp) < 1000 then
            self.statistics.cacheHits = self.statistics.cacheHits + 1
            Debug:EndProfile("RaycastSystem_CastSprayRay")
            return self.cache[cacheKey].result
        end
    end
    
    -- StartShapeTestRay mit optimierten Flags
    local rayHandle = StartShapeTestRay(
        playerCoords.x, playerCoords.y, playerCoords.z,
        endCoords.x, endCoords.y, endCoords.z,
        1,          -- Flag 1: World geometry (Buildings, Ground)
        playerPed,  -- Ignoriere Player
        7           -- Collision Group 7: Ignoriere Vegetation und temporäre Objekte
    )
    
    -- GetShapeTestResultEx für erweiterte Surface-Informationen
    local retval, hit, hitCoords, surfaceNormal, materialHash, entityHit = GetShapeTestResultEx(rayHandle)
    
    if not hit then
        Debug:Log("RAYCAST", "No surface hit", {
            playerCoords = playerCoords,
            endCoords = endCoords,
            distance = maxDistance
        }, "INFO")
        
        Debug:EndProfile("RaycastSystem_CastSprayRay")
        return nil
    end
    
    self.statistics.successfulHits = self.statistics.successfulHits + 1
    
    -- Validiere die getroffene Oberfläche
    local validationResult = self:ValidateSurface(hitCoords, surfaceNormal, materialHash, entityHit)
    
    if not validationResult.valid then
        self.statistics.invalidSurfaces = self.statistics.invalidSurfaces + 1
        
        Debug:Log("RAYCAST", "Invalid surface detected", {
            reason = validationResult.reason,
            materialHash = materialHash,
            surfaceAngle = validationResult.surfaceAngle
        }, "WARN")
        
        Debug:EndProfile("RaycastSystem_CastSprayRay")
        return nil
    end
    
    -- Berechne Rotation basierend auf Surface Normal
    local rotation = self:CalculateRotationFromNormal(surfaceNormal)
    
    -- Erstelle Raycast-Result
    local result = {
        coords = hitCoords,
        normal = surfaceNormal,
        rotation = rotation,
        material = materialHash,
        entity = entityHit,
        surfaceAngle = validationResult.surfaceAngle,
        timestamp = currentTime,
        -- Zusätzliche Metadaten
        metadata = {
            distance = #(playerCoords - hitCoords),
            materialName = self:GetMaterialName(materialHash),
            isValid = true,
            raycastId = self.statistics.totalRaycasts
        }
    }
    
    -- Cache-Result speichern
    if useCache and cacheKey then
        self.cache[cacheKey] = {
            result = result,
            timestamp = currentTime
        }
        
        -- Cleanup alter Cache-Einträge
        self:CleanupCache()
    end
    
    self.lastResult = result
    
    Debug:Log("RAYCAST", "Successful spray raycast", {
        coords = hitCoords,
        distance = result.metadata.distance,
        material = result.metadata.materialName,
        angle = validationResult.surfaceAngle
    }, "SUCCESS")
    
    Debug:EndProfile("RaycastSystem_CastSprayRay")
    return result
end

-- Surface-Validation mit erweiterten Checks
function RaycastSystem:ValidateSurface(coords, normal, materialHash, entity)
    Debug:StartProfile("RaycastSystem_ValidateSurface", "RAYCAST")
    
    local validation = {
        valid = true,
        reason = nil,
        surfaceAngle = 0,
        checks = {}
    }
    
    -- 1. Surface Normal Check
    if not normal or (normal.x == 0 and normal.y == 0 and normal.z == 0) then
        validation.valid = false
        validation.reason = "Invalid surface normal"
        validation.checks.normal = false
        Debug:EndProfile("RaycastSystem_ValidateSurface")
        return validation
    end
    validation.checks.normal = true
    
    -- 2. Surface Angle Check (gegen Boden)
    local angleToGround = math.deg(math.acos(math.abs(normal.z)))
    validation.surfaceAngle = angleToGround
    
    if angleToGround < Config.Physics.minSurfaceAngle then
        validation.valid = false
        validation.reason = "Surface too flat (ceiling/floor)"
        validation.checks.angle = false
        Debug:EndProfile("RaycastSystem_ValidateSurface")
        return validation
    end
    
    if angleToGround > Config.Physics.maxSurfaceAngle then
        validation.valid = false
        validation.reason = "Surface too steep"
        validation.checks.angle = false
        Debug:EndProfile("RaycastSystem_ValidateSurface")
        return validation
    end
    validation.checks.angle = true
    
    -- 3. Material Hash Check (verbotene Materialien)
    if materialHash and Config.Physics.forbiddenMaterials[materialHash] then
        validation.valid = false
        validation.reason = "Forbidden material: " .. self:GetMaterialName(materialHash)
        validation.checks.material = false
        Debug:EndProfile("RaycastSystem_ValidateSurface")
        return validation
    end
    validation.checks.material = true
    
    -- 4. Entity Check (falls getroffen)
    if entity and entity ~= 0 then
        local entityType = GetEntityType(entity)
        
        -- Verbiete Sprays auf Fahrzeugen und Peds
        if entityType == 2 then -- Vehicle
            validation.valid = false
            validation.reason = "Cannot spray on vehicles"
            validation.checks.entity = false
            Debug:EndProfile("RaycastSystem_ValidateSurface")
            return validation
        elseif entityType == 1 then -- Ped
            validation.valid = false
            validation.reason = "Cannot spray on peds"
            validation.checks.entity = false
            Debug:EndProfile("RaycastSystem_ValidateSurface")
            return validation
        end
        
        -- Prüfe ob Entity ein bewegliches Objekt ist
        if entityType == 3 then -- Object
            local model = GetEntityModel(entity)
            -- Liste problematischer Objekte (Türen, bewegliche Objekte)
            local problematicModels = {
                [`prop_door_01`] = true,
                [`prop_gate_01`] = true,
                -- Weitere problematische Models hier hinzufügen
            }
            
            if problematicModels[model] then
                validation.valid = false
                validation.reason = "Cannot spray on movable objects"
                validation.checks.entity = false
                Debug:EndProfile("RaycastSystem_ValidateSurface")
                return validation
            end
        end
    end
    validation.checks.entity = true
    
    -- 5. Proximity Check (andere Sprays in der Nähe)
    local nearbyCheck = self:CheckNearbySprayProximity(coords)
    if not nearbyCheck.valid then
        validation.valid = false
        validation.reason = nearbyCheck.reason
        validation.checks.proximity = false
        Debug:EndProfile("RaycastSystem_ValidateSurface")
        return validation
    end
    validation.checks.proximity = true
    
    -- 6. Zone Check (verbotene Bereiche)
    local zoneCheck = self:CheckForbiddenZones(coords)
    if not zoneCheck.valid then
        validation.valid = false
        validation.reason = zoneCheck.reason
        validation.checks.zone = false
        Debug:EndProfile("RaycastSystem_ValidateSurface")
        return validation
    end
    validation.checks.zone = true
    
    Debug:EndProfile("RaycastSystem_ValidateSurface")
    return validation
end

-- Rotation-Berechnung basierend auf Surface Normal
function RaycastSystem:CalculateRotationFromNormal(normal)
    Debug:StartProfile("RaycastSystem_CalculateRotationFromNormal", "RAYCAST")
    
    -- Normalisiere den Normal-Vektor
    local length = math.sqrt(normal.x^2 + normal.y^2 + normal.z^2)
    if length == 0 then
        Debug:EndProfile("RaycastSystem_CalculateRotationFromNormal")
        return vector3(0.0, 0.0, 0.0)
    end
    
    local normalizedNormal = vector3(normal.x / length, normal.y / length, normal.z / length)
    
    -- Berechne Euler-Winkel aus Normal-Vektor
    local pitch = math.deg(math.asin(-normalizedNormal.y))
    local yaw = math.deg(math.atan2(normalizedNormal.x, normalizedNormal.z))
    local roll = 0.0 -- Roll normalerweise 0 für Wand-Sprays
    
    -- Korrigiere extreme Winkel
    if pitch > 90 then pitch = pitch - 180 end
    if pitch < -90 then pitch = pitch + 180 end
    if yaw > 180 then yaw = yaw - 360 end
    if yaw < -180 then yaw = yaw + 360 end
    
    local rotation = vector3(pitch, roll, yaw)
    
    Debug:EndProfile("RaycastSystem_CalculateRotationFromNormal")
    return rotation
end

-- Nähe-Check für andere Sprays (Anti-Clustering)
function RaycastSystem:CheckNearbySprayProximity(coords)
    -- Diese Funktion wird vom SprayCache-System aufgerufen
    -- Implementierung erfolgt in spray_cache.lua
    if SprayCache and SprayCache.CheckProximity then
        return SprayCache:CheckProximity(coords, Config.Physics.minPlacementDistance)
    end
    
    return {valid = true, reason = nil}
end

-- Zone-Check für verbotene Bereiche
function RaycastSystem:CheckForbiddenZones(coords)
    for _, zone in ipairs(Config.Permissions.neutralZones or {}) do
        local distance = #(coords - zone.coords)
        if distance < zone.radius then
            return {
                valid = false,
                reason = "Cannot spray in protected zone"
            }
        end
    end
    
    return {valid = true, reason = nil}
end

-- Material-Name für Debug-Zwecke
function RaycastSystem:GetMaterialName(materialHash)
    local materials = {
        [1913209870] = "WATER",
        [-1595148316] = "GLASS",
        [-461750719] = "METAL_SOLID_ROAD_SURFACE",
        [1109728704] = "CONCRETE_SIDEWALK",
        [581794674] = "CONCRETE",
        [435688960] = "CONCRETE_PAVEMENT",
        [-700658213] = "TARMAC",
        [951832588] = "TARMAC_PAINTED",
        [1333033863] = "RUMBLE_STRIP",
        [435688960] = "BRICK",
        -- Weitere Material-Hashes hier hinzufügen
    }
    
    return materials[materialHash] or string.format("UNKNOWN_%d", materialHash or 0)
end

-- Cache-Cleanup (entferne alte Einträge)
function RaycastSystem:CleanupCache()
    local currentTime = GetGameTimer()
    local cleanupThreshold = 5000 -- 5 Sekunden
    
    for key, cacheEntry in pairs(self.cache) do
        if (currentTime - cacheEntry.timestamp) > cleanupThreshold then
            self.cache[key] = nil
        end
    end
end

-- Erweiterte Raycast-Funktion für Object Placement (object_gizmo)
function RaycastSystem:CastObjectPlacementRay(maxDistance)
    local result = self:CastSprayRay(maxDistance, false) -- Ohne Cache für Object Placement
    
    if not result then return nil end
    
    -- Erweiterte Validierung für Object Placement
    if result.metadata.distance < 2.0 then
        Debug:Log("RAYCAST", "Object placement too close to player", {
            distance = result.metadata.distance
        }, "WARN")
        return nil
    end
    
    return result
end

-- Performance-Statistiken abrufen
function RaycastSystem:GetStatistics()
    local stats = table.copy(self.statistics)
    
    if stats.totalRaycasts > 0 then
        stats.hitRate = (stats.successfulHits / stats.totalRaycasts) * 100
        stats.validSurfaceRate = ((stats.successfulHits - stats.invalidSurfaces) / stats.totalRaycasts) * 100
        stats.cacheHitRate = (stats.cacheHits / stats.totalRaycasts) * 100
    else
        stats.hitRate = 0
        stats.validSurfaceRate = 0
        stats.cacheHitRate = 0
    end
    
    stats.cacheSize = #self.cache
    
    return stats
end

-- Debug-Visualisierung (nur im Debug-Modus)
function RaycastSystem:VisualizeRaycast(result)
    if not Config.Debug.showRaycastLines or not result then return end
    
    -- Zeichne Linie vom Spieler zur Hit-Position
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    CreateThread(function()
        local endTime = GetGameTimer() + 2000 -- 2 Sekunden anzeigen
        
        while GetGameTimer() < endTime do
            Wait(0)
            
            -- Raycast-Linie
            DrawLine(
                playerCoords.x, playerCoords.y, playerCoords.z,
                result.coords.x, result.coords.y, result.coords.z,
                255, 0, 0, 150 -- Rote Linie
            )
            
            -- Surface Normal als Linie
            local normalEnd = result.coords + (result.normal * 0.5)
            DrawLine(
                result.coords.x, result.coords.y, result.coords.z,
                normalEnd.x, normalEnd.y, normalEnd.z,
                0, 255, 0, 200 -- Grüne Normal-Linie
            )
        end
    end)
end

-- Public API für andere Module
function RaycastSystem:GetLastResult()
    return self.lastResult
end

function RaycastSystem:ClearCache()
    self.cache = {}
    Debug:Log("RAYCAST", "Raycast cache cleared", nil, "INFO")
end

-- Initialisierung
CreateThread(function()
    Wait(100)
    Debug:Log("RAYCAST", "Raycast system initialized", nil, "SUCCESS")
end)