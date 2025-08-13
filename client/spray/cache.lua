-- Spray Cache System für optimierte Performance
-- LOD-basiertes Loading und Memory Management

SprayCache = SprayCache or {
    all = {},                         -- Alle bekannten Sprays (Metadaten)
    nearby = {},                      -- Sprays in Streaming-Distanz
    loaded = {},                      -- Vollständig geladene Sprays mit DUI
    statistics = {
        totalSprays = 0,
        loadedSprays = 0,
        memoryUsage = 0,
        cacheHits = 0,
        cacheMisses = 0
    },
    lastUpdate = 0,
    updateInterval = 1000,            -- 1 Sekunde zwischen Updates
    maxLoadedSprays = Config.Performance.maxConcurrentDUIs or 10
}

-- Initialisierung des Cache-Systems
function SprayCache:Initialize()
    Debug:StartProfile("SprayCache_Initialize", "CACHE")
    
    -- Starte Update-Thread
    self:StartUpdateThread()
    
    -- Registriere Cleanup bei Resource Stop
    AddEventHandler('onResourceStop', function(resourceName)
        if resourceName == GetCurrentResourceName() then
            self:ClearAll()
        end
    end)
    
    Debug:Log("CACHE", "Spray cache system initialized", {
        maxLoadedSprays = self.maxLoadedSprays,
        updateInterval = self.updateInterval
    }, "SUCCESS")
    
    Debug:EndProfile("SprayCache_Initialize")
end

-- Haupt-Update-Thread für Cache-Management
function SprayCache:StartUpdateThread()
    CreateThread(function()
        while true do
            Wait(self.updateInterval)
            
            local currentTime = GetGameTimer()
            if currentTime - self.lastUpdate > self.updateInterval then
                self:UpdateCache()
                self.lastUpdate = currentTime
            end
        end
    end)
end

-- Cache Update-Logik
function SprayCache:UpdateCache()
    Debug:StartProfile("SprayCache_UpdateCache", "CACHE")
    
    local playerCoords = GetEntityCoords(PlayerPedId())
    if not playerCoords then
        Debug:EndProfile("SprayCache_UpdateCache")
        return
    end
    
    -- Phase 1: Berechne Distanzen und LOD
    local nearbySprayData = {}
    local loadCandidates = {}
    
    for sprayId, sprayData in pairs(self.all) do
        local distance = #(playerCoords - sprayData.coords)
        
        if distance < Config.Performance.streamingDistance then
            local lod = self:CalculateLOD(distance)
            
            nearbySprayData[sprayId] = {
                data = sprayData,
                distance = distance,
                lod = lod,
                priority = self:CalculatePriority(sprayData, distance, lod)
            }
            
            -- Kandidat für Loading wenn high/medium LOD
            if lod == 'high' or lod == 'medium' then
                table.insert(loadCandidates, {
                    sprayId = sprayId,
                    priority = nearbySprayData[sprayId].priority,
                    distance = distance
                })
            end
        end
    end
    
    self.nearby = nearbySprayData
    
    -- Phase 2: Load Management
    self:ManageLoading(loadCandidates)
    
    -- Phase 3: Unload distant sprays
    self:UnloadDistantSprays()
    
    -- Phase 4: Update Statistics
    self:UpdateStatistics()
    
    Debug:EndProfile("SprayCache_UpdateCache")
end

-- LOD Berechnung basierend auf Distanz
function SprayCache:CalculateLOD(distance)
    if distance < Config.Performance.lodDistances.high then
        return 'high'
    elseif distance < Config.Performance.lodDistances.medium then
        return 'medium'
    elseif distance < Config.Performance.lodDistances.low then
        return 'low'
    else
        return 'invisible'
    end
end

-- Prioritäts-Berechnung für Loading-Queue
function SprayCache:CalculatePriority(sprayData, distance, lod)
    local priority = 1000 - distance  -- Näher = höhere Priorität
    
    -- LOD-Bonus
    if lod == 'high' then
        priority = priority + 500
    elseif lod == 'medium' then
        priority = priority + 200
    end
    
    -- Gang-Relevanz (eigene Gang höhere Priorität)
    local Player = QBCore and QBCore.Functions.GetPlayerData()
    if Player and Player.gang and Player.gang.name == sprayData.gang_name then
        priority = priority + 300
    end
    
    -- Neuere Sprays höhere Priorität
    local ageBonus = math.max(0, 100 - ((GetGameTimer() - (sprayData.created_at or 0)) / 3600000)) -- Alter in Stunden
    priority = priority + ageBonus
    
    -- View-basierte Priorität (Sprays im Sichtfeld)
    local isInView = self:IsSprayInPlayerView(sprayData.coords, distance)
    if isInView then
        priority = priority + 400
    end
    
    return priority
end

-- Prüfe ob Spray im Sichtfeld des Spielers ist
function SprayCache:IsSprayInPlayerView(sprayCoords, distance)
    if distance > 50.0 then return false end -- Zu weit für Sichtfeld-Check
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local forwardVector = GetEntityForwardVector(playerPed)
    local toSpray = sprayCoords - playerCoords
    
    -- Normalisiere Vektoren
    local forwardNorm = forwardVector / #forwardVector
    local toSprayNorm = toSpray / #toSpray
    
    -- Berechne Winkel (Dot Product)
    local dotProduct = forwardNorm.x * toSprayNorm.x + forwardNorm.y * toSprayNorm.y + forwardNorm.z * toSprayNorm.z
    local angle = math.deg(math.acos(math.max(-1, math.min(1, dotProduct))))
    
    -- Sichtfeld von 120 Grad (60 Grad jede Seite)
    return angle < 60.0
end

-- Loading Management mit Prioritäts-Queue
function SprayCache:ManageLoading(loadCandidates)
    Debug:StartProfile("SprayCache_ManageLoading", "CACHE")
    
    -- Sortiere nach Priorität
    table.sort(loadCandidates, function(a, b)
        return a.priority > b.priority
    end)
    
    local currentlyLoaded = self:CountLoadedSprays()
    local loadSlots = self.maxLoadedSprays - currentlyLoaded
    
    -- Lade neue Sprays basierend auf verfügbaren Slots
    for i = 1, math.min(#loadCandidates, loadSlots) do
        local candidate = loadCandidates[i]
        
        if not self.loaded[candidate.sprayId] then
            self:LoadSpray(candidate.sprayId)
        end
    end
    
    Debug:EndProfile("SprayCache_ManageLoading")
end

-- Spray laden (DUI erstellen)
function SprayCache:LoadSpray(sprayId)
    Debug:StartProfile("SprayCache_LoadSpray", "CACHE")
    
    local sprayData = self.all[sprayId]
    if not sprayData then
        Debug:Log("CACHE", "Spray data not found for loading", {sprayId = sprayId}, "ERROR")
        Debug:EndProfile("SprayCache_LoadSpray")
        return false
    end
    
    -- Prüfe ob bereits geladen
    if self.loaded[sprayId] then
        Debug:EndProfile("SprayCache_LoadSpray")
        return true
    end
    
    -- Erstelle DUI über DUIManager
    local duiData = DUIManager:GetOrCreateDUI(sprayId, sprayData.textureData)
    
    if duiData then
        self.loaded[sprayId] = {
            sprayData = sprayData,
            duiData = duiData,
            loadedAt = GetGameTimer(),
            lastAccessed = GetGameTimer()
        }
        
        self.statistics.loadedSprays = self.statistics.loadedSprays + 1
        self.statistics.cacheHits = self.statistics.cacheHits + 1
        
        Debug:Log("CACHE", "Spray loaded successfully", {
            sprayId = sprayId,
            gang = sprayData.gang_name,
            loadedCount = self.statistics.loadedSprays
        }, "SUCCESS")
        
        Debug:EndProfile("SprayCache_LoadSpray")
        return true
    else
        self.statistics.cacheMisses = self.statistics.cacheMisses + 1
        
        Debug:Log("CACHE", "Failed to load spray", {sprayId = sprayId}, "ERROR")
        Debug:EndProfile("SprayCache_LoadSpray")
        return false
    end
end

-- Entfernte Sprays entladen
function SprayCache:UnloadDistantSprays()
    Debug:StartProfile("SprayCache_UnloadDistantSprays", "CACHE")
    
    local unloadedCount = 0
    
    for sprayId, loadedData in pairs(self.loaded) do
        -- Prüfe ob Spray noch nearby ist
        if not self.nearby[sprayId] then
            self:UnloadSpray(sprayId)
            unloadedCount = unloadedCount + 1
        elseif self.nearby[sprayId].lod == 'invisible' then
            -- Auch unsichtbare Sprays entladen
            self:UnloadSpray(sprayId)
            unloadedCount = unloadedCount + 1
        end
    end
    
    if unloadedCount > 0 then
        Debug:Log("CACHE", "Unloaded distant sprays", {count = unloadedCount}, "INFO")
    end
    
    Debug:EndProfile("SprayCache_UnloadDistantSprays")
end

-- Einzelnes Spray entladen
function SprayCache:UnloadSpray(sprayId)
    local loadedData = self.loaded[sprayId]
    if not loadedData then return false end
    
    -- DUI über DUIManager zerstören
    DUIManager:DestroyDUI(sprayId)
    
    -- Aus Cache entfernen
    self.loaded[sprayId] = nil
    self.statistics.loadedSprays = math.max(0, self.statistics.loadedSprays - 1)
    
    Debug:Log("CACHE", "Spray unloaded", {sprayId = sprayId}, "INFO")
    return true
end

-- Spray-Daten hinzufügen oder aktualisieren
function SprayCache:AddOrUpdateSpray(sprayId, sprayData)
    Debug:StartProfile("SprayCache_AddOrUpdateSpray", "CACHE")
    
    local wasNew = self.all[sprayId] == nil
    
    -- Konvertiere Koordinaten zu Vector3 falls nötig
    if sprayData.position and type(sprayData.position) == 'table' then
        sprayData.coords = vector3(sprayData.position.x, sprayData.position.y, sprayData.position.z)
        sprayData.rotation = vector3(sprayData.position.rx or 0, sprayData.position.ry or 0, sprayData.position.rz or 0)
        sprayData.normal = sprayData.position.normal or vector3(0, 0, 1)
    end
    
    self.all[sprayId] = sprayData
    
    if wasNew then
        self.statistics.totalSprays = self.statistics.totalSprays + 1
        Debug:Log("CACHE", "New spray added to cache", {
            sprayId = sprayId,
            gang = sprayData.gang_name,
            totalSprays = self.statistics.totalSprays
        }, "SUCCESS")
    else
        Debug:Log("CACHE", "Spray updated in cache", {sprayId = sprayId}, "INFO")
    end
    
    Debug:EndProfile("SprayCache_AddOrUpdateSpray")
end

-- Spray aus Cache entfernen
function SprayCache:RemoveSpray(sprayId)
    Debug:StartProfile("SprayCache_RemoveSpray", "CACHE")
    
    -- Entlade falls geladen
    if self.loaded[sprayId] then
        self:UnloadSpray(sprayId)
    end
    
    -- Entferne aus allen Caches
    if self.all[sprayId] then
        self.all[sprayId] = nil
        self.statistics.totalSprays = math.max(0, self.statistics.totalSprays - 1)
    end
    
    if self.nearby[sprayId] then
        self.nearby[sprayId] = nil
    end
    
    Debug:Log("CACHE", "Spray removed from cache", {
        sprayId = sprayId,
        remainingTotal = self.statistics.totalSprays
    }, "SUCCESS")
    
    Debug:EndProfile("SprayCache_RemoveSpray")
end

-- Proximity Check für Platzierung
function SprayCache:CheckProximity(coords, minDistance)
    for sprayId, sprayData in pairs(self.all) do
        local distance = #(coords - sprayData.coords)
        
        if distance < minDistance then
            return {
                valid = false,
                reason = string.format("Zu nah an Spray '%s' (%.1fm)", sprayId, distance),
                conflictingSpray = sprayId
            }
        end
    end
    
    return {valid = true}
end

-- Texture Handle für Rendering abrufen
function SprayCache:GetTextureHandle(sprayId)
    local loadedData = self.loaded[sprayId]
    if not loadedData then
        return nil
    end
    
    -- Update Last Accessed
    loadedData.lastAccessed = GetGameTimer()
    
    return DUIManager:GetTextureHandle(sprayId)
end

-- LOD-basierte Texture-Qualität abrufen
function SprayCache:GetTextureForLOD(sprayId, lod)
    local textureHandle = self:GetTextureHandle(sprayId)
    if not textureHandle then return nil end
    
    -- Für verschiedene LOD-Stufen könnten hier verschiedene Texturen zurückgegeben werden
    -- Derzeit verwenden wir die gleiche Texture für alle LODs
    return textureHandle
end

-- Spray-Daten für bestimmte Gang abrufen
function SprayCache:GetSpraysByGang(gangName)
    local gangSprays = {}
    
    for sprayId, sprayData in pairs(self.all) do
        if sprayData.gang_name == gangName then
            gangSprays[sprayId] = sprayData
        end
    end
    
    return gangSprays
end

-- Statistiken aktualisieren
function SprayCache:UpdateStatistics()
    local loadedCount = self:CountLoadedSprays()
    local memoryUsage = DUIManager:GetMemoryUsage()
    
    self.statistics.loadedSprays = loadedCount
    self.statistics.memoryUsage = memoryUsage
    
    -- Memory-Warnung
    if memoryUsage > Config.Performance.memoryThreshold * 0.8 then
        Debug:Log("CACHE", "High memory usage detected", {
            memoryUsage = memoryUsage,
            threshold = Config.Performance.memoryThreshold
        }, "WARN")
    end
end

-- Hilfsfunktionen
function SprayCache:CountLoadedSprays()
    local count = 0
    for _ in pairs(self.loaded) do
        count = count + 1
    end
    return count
end

function SprayCache:IsSprayLoaded(sprayId)
    return self.loaded[sprayId] ~= nil
end

function SprayCache:IsSprayNearby(sprayId)
    return self.nearby[sprayId] ~= nil
end

function SprayCache:GetSprayData(sprayId)
    return self.all[sprayId]
end

function SprayCache:GetNearbySprayData()
    return self.nearby
end

function SprayCache:GetLoadedSprayData()
    return self.loaded
end

-- Cache-Optimierung und Cleanup
function SprayCache:OptimizeCache()
    Debug:StartProfile("SprayCache_OptimizeCache", "CACHE")
    
    local optimizedCount = 0
    
    -- Entferne veraltete Nearby-Einträge
    for sprayId, nearbyData in pairs(self.nearby) do
        if not self.all[sprayId] then
            self.nearby[sprayId] = nil
            optimizedCount = optimizedCount + 1
        end
    end
    
    -- Cleanup verwaiste Loaded-Einträge
    for sprayId, loadedData in pairs(self.loaded) do
        if not self.all[sprayId] then
            self:UnloadSpray(sprayId)
            optimizedCount = optimizedCount + 1
        end
    end
    
    Debug:Log("CACHE", "Cache optimization completed", {
        optimizedEntries = optimizedCount
    }, "SUCCESS")
    
    Debug:EndProfile("SprayCache_OptimizeCache")
end

-- Kompletten Cache leeren
function SprayCache:ClearAll()
    Debug:StartProfile("SprayCache_ClearAll", "CACHE")
    
    local totalCleared = self.statistics.totalSprays
    
    -- Entlade alle geladenen Sprays
    for sprayId in pairs(self.loaded) do
        self:UnloadSpray(sprayId)
    end
    
    -- Leere alle Caches
    self.all = {}
    self.nearby = {}
    self.loaded = {}
    
    -- Reset Statistiken
    self.statistics = {
        totalSprays = 0,
        loadedSprays = 0,
        memoryUsage = 0,
        cacheHits = 0,
        cacheMisses = 0
    }
    
    Debug:Log("CACHE", "Cache cleared completely", {
        totalCleared = totalCleared
    }, "SUCCESS")
    
    Debug:EndProfile("SprayCache_ClearAll")
end

-- Bulk-Loading für Server-Sync
function SprayCache:BulkAddSprays(sprayArray)
    Debug:StartProfile("SprayCache_BulkAddSprays", "CACHE")
    
    local addedCount = 0
    
    for _, sprayData in ipairs(sprayArray) do
        if sprayData.spray_id then
            self:AddOrUpdateSpray(sprayData.spray_id, sprayData)
            addedCount = addedCount + 1
        end
    end
    
    Debug:Log("CACHE", "Bulk spray addition completed", {
        addedCount = addedCount,
        totalSprays = self.statistics.totalSprays
    }, "SUCCESS")
    
    Debug:EndProfile("SprayCache_BulkAddSprays")
end

-- Cache-Status für Debug
function SprayCache:GetStatus()
    return {
        statistics = self.statistics,
        nearbyCount = self:CountTable(self.nearby),
        loadedCount = self:CountTable(self.loaded),
        allCount = self:CountTable(self.all),
        memoryUsage = DUIManager:GetMemoryUsage(),
        lastUpdate = self.lastUpdate
    }
end

function SprayCache:CountTable(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- Event Handlers für Server-Sync
RegisterNetEvent('spray:client:syncSprayData', function(sprays)
    SprayCache:BulkAddSprays(sprays)
end)

RegisterNetEvent('spray:client:addSpray', function(sprayData)
    SprayCache:AddOrUpdateSpray(sprayData.spray_id, sprayData)
end)

RegisterNetEvent('spray:client:removeSpray', function(sprayId)
    SprayCache:RemoveSpray(sprayId)
end)

RegisterNetEvent('spray:client:updateSpray', function(sprayData)
    SprayCache:AddOrUpdateSpray(sprayData.spray_id, sprayData)
end)

-- Commands für Debug
RegisterCommand('spray_cache_status', function()
    local status = SprayCache:GetStatus()
    
    print("=== SPRAY CACHE STATUS ===")
    print("Total Sprays: " .. status.allCount)
    print("Nearby Sprays: " .. status.nearbyCount)
    print("Loaded Sprays: " .. status.loadedCount)
    print("Memory Usage: " .. string.format("%.2f MB", status.memoryUsage / 1024 / 1024))
    print("Cache Hits: " .. status.statistics.cacheHits)
    print("Cache Misses: " .. status.statistics.cacheMisses)
    print("Last Update: " .. (GetGameTimer() - status.lastUpdate) .. "ms ago")
end, false)

RegisterCommand('spray_cache_clear', function()
    SprayCache:ClearAll()
    print("Spray cache cleared")
end, false)

RegisterCommand('spray_cache_optimize', function()
    SprayCache:OptimizeCache()
    print("Spray cache optimized")
end, false)

-- Initialisierung
CreateThread(function()
    Wait(1000) -- Warte bis andere Systeme initialisiert sind
    SprayCache:Initialize()
end)

Debug:Log("CACHE", "Spray cache system loaded", nil, "SUCCESS")