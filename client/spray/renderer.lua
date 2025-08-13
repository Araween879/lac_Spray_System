-- Spray Renderer System für 3D-Darstellung im Spiel
-- Optimierte Rendering-Pipeline mit LOD und Performance-Monitoring

SprayRenderer = SprayRenderer or {
    activeRenders = {},               -- Aktiv gerenderte Sprays
    renderQueue = {},                 -- Render-Warteschlange
    currentLOD = {},                  -- Aktuelle LOD-Stufe pro Spray
    performanceMetrics = {
        drawCalls = 0,
        renderTime = 0,
        skippedFrames = 0
    },
    renderSettings = {
        enableLOD = true,
        maxDrawCalls = 20,            -- Maximale Draw-Calls pro Frame
        maxRenderDistance = Config.Performance.streamingDistance,
        fadeDistance = 10.0,          -- Distanz für Fade-Out
        enableOcclusion = true        -- Occlusion Culling
    }
}

-- Initialisierung des Renderer-Systems
function SprayRenderer:Initialize()
    Debug:StartProfile("SprayRenderer_Initialize", "RENDERER")
    
    -- Starte Render-Thread
    self:StartRenderThread()
    
    -- Performance-Monitoring
    self:StartPerformanceMonitoring()
    
    Debug:Log("RENDERER", "Spray renderer system initialized", self.renderSettings, "SUCCESS")
    Debug:EndProfile("SprayRenderer_Initialize")
end

-- Haupt-Render-Thread
function SprayRenderer:StartRenderThread()
    CreateThread(function()
        while true do
            local frameStart = GetGameTimer()
            local waitTime = 0
            
            if next(SprayCache.nearby) then
                -- Rendere nur wenn Sprays in der Nähe sind
                self:ProcessRenderQueue()
                self:RenderActivesprays()
                waitTime = 0 -- Render every frame
            else
                waitTime = 100 -- Sleep wenn keine Sprays nearby
            end
            
            -- Performance-Tracking
            local frameTime = GetGameTimer() - frameStart
            self.performanceMetrics.renderTime = frameTime
            
            if frameTime > 16 then -- > 16ms = frame drop
                self.performanceMetrics.skippedFrames = self.performanceMetrics.skippedFrames + 1
            end
            
            Wait(waitTime)
        end
    end)
end

-- Render-Warteschlange verarbeiten
function SprayRenderer:ProcessRenderQueue()
    Debug:StartProfile("SprayRenderer_ProcessRenderQueue", "RENDERER")
    
    local processedCount = 0
    local maxProcessPerFrame = 3 -- Limitiere Verarbeitung pro Frame
    
    for sprayId, renderData in pairs(self.renderQueue) do
        if processedCount >= maxProcessPerFrame then break end
        
        local success = self:SetupSprayRender(sprayId, renderData)
        
        if success then
            self.activeRenders[sprayId] = renderData
            self.renderQueue[sprayId] = nil
            processedCount = processedCount + 1
        else
            -- Entferne fehlgeschlagene Renders
            self.renderQueue[sprayId] = nil
        end
    end
    
    Debug:EndProfile("SprayRenderer_ProcessRenderQueue")
end

-- Aktive Sprays rendern
function SprayRenderer:RenderActivesprays()
    Debug:StartProfile("SprayRenderer_RenderActivesprays", "RENDERER")
    
    local playerCoords = GetEntityCoords(PlayerPedId())
    local drawCalls = 0
    local maxDrawCalls = self.renderSettings.maxDrawCalls
    
    for sprayId, renderData in pairs(self.activeRenders) do
        if drawCalls >= maxDrawCalls then
            break -- Frame-Budget überschritten
        end
        
        -- Distance Check
        local distance = #(playerCoords - renderData.coords)
        
        if distance > self.renderSettings.maxRenderDistance then
            -- Zu weit entfernt - aus aktiven Renders entfernen
            self:RemoveActiveRender(sprayId)
        elseif self:ShouldRenderSpray(sprayId, renderData, distance) then
            self:DrawSpray(sprayId, renderData, distance)
            drawCalls = drawCalls + 1
        end
    end
    
    self.performanceMetrics.drawCalls = drawCalls
    Debug:EndProfile("SprayRenderer_RenderActivesprays")
end

-- Prüfe ob Spray gerendert werden soll
function SprayRenderer:ShouldRenderSpray(sprayId, renderData, distance)
    -- LOD Check
    local lod = SprayCache:CalculateLOD(distance)
    if lod == 'invisible' then
        return false
    end
    
    -- Occlusion Culling (vereinfacht)
    if self.renderSettings.enableOcclusion and distance > 25.0 then
        if not self:IsSprayVisible(renderData.coords, distance) then
            return false
        end
    end
    
    -- Texture Availability Check
    local textureHandle = SprayCache:GetTextureHandle(sprayId)
    if not textureHandle then
        return false
    end
    
    return true
end

-- Vereinfachtes Occlusion Culling
function SprayRenderer:IsSprayVisible(sprayCoords, distance)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    -- Raycast zwischen Spieler und Spray
    local rayHandle = StartShapeTestRay(
        playerCoords.x, playerCoords.y, playerCoords.z,
        sprayCoords.x, sprayCoords.y, sprayCoords.z,
        1, -- World geometry
        playerPed,
        7
    )
    
    local _, hit, _, _, _, _ = GetShapeTestResult(rayHandle)
    
    -- Wenn Raycast blockiert ist, ist Spray verdeckt
    return not hit
end

-- Spray Setup für Rendering
function SprayRenderer:SetupSprayRender(sprayId, renderData)
    Debug:StartProfile("SprayRenderer_SetupSprayRender", "RENDERER")
    
    -- Hole Texture von DUI Manager
    local txdName, textureName = SprayCache:GetTextureHandle(sprayId)
    if not txdName or not textureName then
        Debug:Log("RENDERER", "No texture available for spray", {sprayId = sprayId}, "WARN")
        Debug:EndProfile("SprayRenderer_SetupSprayRender")
        return false
    end
    
    -- Update Render Data
    renderData.txdName = txdName
    renderData.textureName = textureName
    renderData.setupTime = GetGameTimer()
    
    Debug:Log("RENDERER", "Spray render setup completed", {
        sprayId = sprayId,
        txdName = txdName
    }, "SUCCESS")
    
    Debug:EndProfile("SprayRenderer_SetupSprayRender")
    return true
end

-- Spray 3D-Rendering
function SprayRenderer:DrawSpray(sprayId, renderData, distance)
    local txdName = renderData.txdName
    local textureName = renderData.textureName
    
    if not txdName or not textureName then return end
    
    -- Berechne Spray-Größe basierend auf LOD
    local baseSize = Config.Physics.spraySize or 2.0
    local lod = SprayCache:CalculateLOD(distance)
    local size = self:GetSizeForLOD(baseSize, lod, distance)
    
    -- Berechne Alpha basierend auf Distanz
    local alpha = self:CalculateAlpha(distance)
    
    -- Berechne Spray-Ecken basierend auf Surface Normal
    local corners = self:CalculateSprayCorners(renderData.coords, renderData.normal, renderData.rotation, size)
    
    if not corners then return end
    
    -- Render Sprite/Quad
    DrawSprite_3d(
        txdName, textureName,
        corners.topLeft.x, corners.topLeft.y, corners.topLeft.z,
        corners.topRight.x, corners.topRight.y, corners.topRight.z,
        corners.bottomLeft.x, corners.bottomLeft.y, corners.bottomLeft.z,
        corners.bottomRight.x, corners.bottomRight.y, corners.bottomRight.z,
        255, 255, 255, alpha -- RGBA
    )
    
    -- Debug-Visualisierung
    if Config.Debug.showSprayBounds then
        self:DrawSprayDebugBounds(corners, renderData)
    end
end

-- 3D Sprite Drawing (Custom Implementation)
function DrawSprite_3d(txd, texture, x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4, r, g, b, a)
    -- GTA V hat keine native DrawSprite_3d Funktion
    -- Wir verwenden DrawPoly für 3D-Quads
    
    -- Erstes Dreieck (Top-Left, Top-Right, Bottom-Left)
    DrawPoly(
        x1, y1, z1,  -- Top-Left
        x2, y2, z2,  -- Top-Right  
        x3, y3, z3,  -- Bottom-Left
        r, g, b, a
    )
    
    -- Zweites Dreieck (Top-Right, Bottom-Right, Bottom-Left)
    DrawPoly(
        x2, y2, z2,  -- Top-Right
        x4, y4, z4,  -- Bottom-Right
        x3, y3, z3,  -- Bottom-Left
        r, g, b, a
    )
    
    -- UV-Mapping für Texture (approximiert)
    -- GTA V's DrawPoly unterstützt leider keine direkten UV-Koordinaten
    -- Für echte Texture-Mapping müssten wir ein Decal-System verwenden
end

-- Alternative: Decal-basiertes Rendering (bessere Qualität)
function SprayRenderer:DrawSprayAsDecal(sprayId, renderData, distance)
    local txdName = renderData.txdName
    local textureName = renderData.textureName
    
    if not txdName or not textureName then return end
    
    local size = self:GetSizeForLOD(Config.Physics.spraySize, SprayCache:CalculateLOD(distance), distance)
    local alpha = self:CalculateAlpha(distance)
    
    -- GTA V Decal System
    AddDecal(
        9, -- Decal Type (Graffiti)
        renderData.coords.x, renderData.coords.y, renderData.coords.z,
        renderData.normal.x, renderData.normal.y, renderData.normal.z,
        0.0, 0.0, 1.0, -- Up Vector
        size, size, -- Width, Height
        1.0, 1.0, 1.0, alpha / 255.0, -- RGBA (normalized)
        -1.0, -- Timeout (-1 = permanent bis entfernt)
        false, false, -- No fade, no normal map
        txdName, textureName
    )
end

-- Spray-Ecken berechnen für 3D-Quad
function SprayRenderer:CalculateSprayCorners(coords, normal, rotation, size)
    -- Erstelle Basis-Vektoren für das Spray-Quad
    local up = vector3(0, 0, 1)
    local right = normal:cross(up)
    
    -- Falls Normal parallel zu Up ist, verwende anderen Referenz-Vektor
    if #right < 0.1 then
        right = normal:cross(vector3(1, 0, 0))
    end
    
    right = right:normalize()
    local actualUp = right:cross(normal):normalize()
    
    -- Rotiere Vektoren basierend auf Spray-Rotation
    if rotation and rotation.z ~= 0 then
        local angle = math.rad(rotation.z)
        local cos_a = math.cos(angle)
        local sin_a = math.sin(angle)
        
        local rotatedRight = vector3(
            right.x * cos_a - actualUp.x * sin_a,
            right.y * cos_a - actualUp.y * sin_a,
            right.z * cos_a - actualUp.z * sin_a
        )
        
        local rotatedUp = vector3(
            right.x * sin_a + actualUp.x * cos_a,
            right.y * sin_a + actualUp.y * cos_a,
            right.z * sin_a + actualUp.z * cos_a
        )
        
        right = rotatedRight
        actualUp = rotatedUp
    end
    
    -- Berechne Quad-Ecken
    local halfSize = size * 0.5
    local rightOffset = right * halfSize
    local upOffset = actualUp * halfSize
    
    return {
        topLeft = coords - rightOffset + upOffset,
        topRight = coords + rightOffset + upOffset,
        bottomLeft = coords - rightOffset - upOffset,
        bottomRight = coords + rightOffset - upOffset
    }
end

-- LOD-basierte Größen-Berechnung
function SprayRenderer:GetSizeForLOD(baseSize, lod, distance)
    local sizeMultiplier = 1.0
    
    if lod == 'high' then
        sizeMultiplier = 1.0
    elseif lod == 'medium' then
        sizeMultiplier = 0.8
    elseif lod == 'low' then
        sizeMultiplier = 0.6
    else
        sizeMultiplier = 0.4
    end
    
    -- Zusätzliche Distanz-basierte Skalierung
    local distanceScale = math.max(0.5, math.min(1.0, (50.0 - distance) / 50.0))
    
    return baseSize * sizeMultiplier * distanceScale
end

-- Alpha-Berechnung für Fade-Effekt
function SprayRenderer:CalculateAlpha(distance)
    local fadeStart = self.renderSettings.maxRenderDistance - self.renderSettings.fadeDistance
    
    if distance < fadeStart then
        return 255 -- Vollständig sichtbar
    else
        -- Fade-Out über fadeDistance
        local fadeProgress = (distance - fadeStart) / self.renderSettings.fadeDistance
        local alpha = math.max(0, math.min(255, 255 * (1.0 - fadeProgress)))
        return math.floor(alpha)
    end
end

-- Spray zu Render-Queue hinzufügen
function SprayRenderer:QueueSprayForRender(sprayId, sprayData)
    if self.activeRenders[sprayId] or self.renderQueue[sprayId] then
        return -- Bereits in Queue oder aktiv
    end
    
    local renderData = {
        sprayId = sprayId,
        coords = sprayData.coords,
        rotation = sprayData.rotation or vector3(0, 0, 0),
        normal = sprayData.normal or vector3(0, 0, 1),
        gang = sprayData.gang_name,
        textureData = sprayData.textureData,
        queuedAt = GetGameTimer()
    }
    
    self.renderQueue[sprayId] = renderData
    
    Debug:Log("RENDERER", "Spray queued for rendering", {sprayId = sprayId}, "INFO")
end

-- Aktives Render entfernen
function SprayRenderer:RemoveActiveRender(sprayId)
    if self.activeRenders[sprayId] then
        self.activeRenders[sprayId] = nil
        self.currentLOD[sprayId] = nil
        
        Debug:Log("RENDERER", "Active render removed", {sprayId = sprayId}, "INFO")
    end
end

-- Debug-Visualisierung
function SprayRenderer:DrawSprayDebugBounds(corners, renderData)
    if not corners then return end
    
    -- Zeichne Wireframe-Box
    local color = {r = 255, g = 0, b = 0, a = 100}
    
    -- Top Edge
    DrawLine(
        corners.topLeft.x, corners.topLeft.y, corners.topLeft.z,
        corners.topRight.x, corners.topRight.y, corners.topRight.z,
        color.r, color.g, color.b, color.a
    )
    
    -- Right Edge
    DrawLine(
        corners.topRight.x, corners.topRight.y, corners.topRight.z,
        corners.bottomRight.x, corners.bottomRight.y, corners.bottomRight.z,
        color.r, color.g, color.b, color.a
    )
    
    -- Bottom Edge
    DrawLine(
        corners.bottomRight.x, corners.bottomRight.y, corners.bottomRight.z,
        corners.bottomLeft.x, corners.bottomLeft.y, corners.bottomLeft.z,
        color.r, color.g, color.b, color.a
    )
    
    -- Left Edge
    DrawLine(
        corners.bottomLeft.x, corners.bottomLeft.y, corners.bottomLeft.z,
        corners.topLeft.x, corners.topLeft.y, corners.topLeft.z,
        color.r, color.g, color.b, color.a
    )
    
    -- Normal-Vektor
    local normalEnd = renderData.coords + (renderData.normal * 1.0)
    DrawLine(
        renderData.coords.x, renderData.coords.y, renderData.coords.z,
        normalEnd.x, normalEnd.y, normalEnd.z,
        0, 255, 0, 150 -- Grün
    )
end

-- Performance-Monitoring
function SprayRenderer:StartPerformanceMonitoring()
    CreateThread(function()
        while true do
            Wait(5000) -- Alle 5 Sekunden
            
            if Config.Debug.enabled then
                Debug:Log("RENDERER", "Renderer performance metrics", {
                    activeRenders = #self.activeRenders,
                    queuedRenders = #self.renderQueue,
                    drawCalls = self.performanceMetrics.drawCalls,
                    renderTime = self.performanceMetrics.renderTime,
                    skippedFrames = self.performanceMetrics.skippedFrames
                }, "INFO")
            end
            
            -- Reset per-interval metrics
            self.performanceMetrics.skippedFrames = 0
        end
    end)
end

-- Public API für Cache-Integration
function SprayRenderer:UpdateSprayLOD(sprayId, newLOD)
    if self.currentLOD[sprayId] ~= newLOD then
        self.currentLOD[sprayId] = newLOD
        
        -- Trigger re-render wenn nötig
        if self.activeRenders[sprayId] and newLOD == 'invisible' then
            self:RemoveActiveRender(sprayId)
        elseif not self.activeRenders[sprayId] and newLOD ~= 'invisible' then
            local sprayData = SprayCache:GetSprayData(sprayId)
            if sprayData then
                self:QueueSprayForRender(sprayId, sprayData)
            end
        end
    end
end

-- Cache-Event Integration
AddEventHandler('spray:cache:sprayAdded', function(sprayId, sprayData)
    SprayRenderer:QueueSprayForRender(sprayId, sprayData)
end)

AddEventHandler('spray:cache:sprayRemoved', function(sprayId)
    SprayRenderer:RemoveActiveRender(sprayId)
    SprayRenderer.renderQueue[sprayId] = nil
end)

-- Einstellungs-Updates
function SprayRenderer:UpdateRenderSettings(settings)
    for key, value in pairs(settings) do
        if self.renderSettings[key] ~= nil then
            self.renderSettings[key] = value
        end
    end
    
    Debug:Log("RENDERER", "Render settings updated", settings, "INFO")
end

-- Status für Debug-Commands
function SprayRenderer:GetStatus()
    return {
        activeRenders = self:CountTable(self.activeRenders),
        queuedRenders = self:CountTable(self.renderQueue),
        performanceMetrics = self.performanceMetrics,
        renderSettings = self.renderSettings
    }
end

function SprayRenderer:CountTable(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- Commands für Debug
RegisterCommand('spray_renderer_status', function()
    local status = SprayRenderer:GetStatus()
    
    print("=== SPRAY RENDERER STATUS ===")
    print("Active Renders: " .. status.activeRenders)
    print("Queued Renders: " .. status.queuedRenders)
    print("Draw Calls: " .. status.performanceMetrics.drawCalls)
    print("Render Time: " .. status.performanceMetrics.renderTime .. "ms")
    print("Skipped Frames: " .. status.performanceMetrics.skippedFrames)
    print("Max Draw Calls: " .. status.renderSettings.maxDrawCalls)
end, false)

RegisterCommand('spray_renderer_clear', function()
    SprayRenderer.activeRenders = {}
    SprayRenderer.renderQueue = {}
    SprayRenderer.currentLOD = {}
    print("Spray renderer cleared")
end, false)

-- Initialisierung
CreateThread(function()
    Wait(1500) -- Warte bis Cache initialisiert ist
    SprayRenderer:Initialize()
end)

Debug:Log("RENDERER", "Spray renderer system loaded", nil, "SUCCESS")