-- DUI Manager für FiveM Gang Spray System
-- Optimiertes Memory Management mit DUI Pool und Performance-Monitoring

DUIManager = DUIManager or {
    pool = {},                        -- DUI Object Pool für Wiederverwendung
    activeCount = 0,                  -- Anzahl aktiver DUIs
    memoryUsage = 0,                  -- Geschätzte Memory-Nutzung in Bytes
    textureRegistry = {},             -- Registry für Texture-Handles
    lastCleanup = 0,                  -- Letzter Cleanup-Zeitpunkt
    statistics = {                    -- Performance-Statistiken
        created = 0,
        destroyed = 0,
        recycled = 0,
        memoryPeakUsage = 0
    }
}

-- Initialisierung des DUI Managers
function DUIManager:Initialize()
    Debug:StartProfile("DUIManager_Initialize", "DUI")
    
    -- Registriere Cleanup-Handler
    AddEventHandler('onResourceStop', function(resourceName)
        if resourceName == GetCurrentResourceName() then
            self:DestroyAllDUIs()
        end
    end)
    
    -- Starte Memory-Monitoring Thread
    self:StartMemoryMonitor()
    
    Debug:Log("DUI", "DUI Manager initialized", {
        maxConcurrentDUIs = Config.Performance.maxConcurrentDUIs,
        memoryThreshold = Config.Performance.memoryThreshold
    }, "SUCCESS")
    
    Debug:EndProfile("DUIManager_Initialize")
end

-- Hauptfunktion: DUI abrufen oder erstellen (mit Pool-Wiederverwendung)
function DUIManager:GetOrCreateDUI(sprayId, textureData)
    Debug:StartProfile("DUIManager_GetOrCreateDUI", "DUI")
    
    -- Memory-Threshold prüfen BEVOR neue DUI erstellt wird
    if self.memoryUsage > Config.Performance.memoryThreshold then
        Debug:Log("DUI", "Memory threshold exceeded, forcing cleanup", {
            currentMemory = self.memoryUsage,
            threshold = Config.Performance.memoryThreshold
        }, "WARN")
        self:ForceCleanupOldest()
    end
    
    -- Prüfe ob DUI bereits existiert
    if self.pool[sprayId] then
        local duiData = self.pool[sprayId]
        duiData.lastAccessed = GetGameTimer()
        duiData.accessCount = (duiData.accessCount or 0) + 1
        
        Debug:Log("DUI", "Recycled existing DUI", {sprayId = sprayId}, "SUCCESS")
        self.statistics.recycled = self.statistics.recycled + 1
        
        Debug:EndProfile("DUIManager_GetOrCreateDUI")
        return duiData
    end
    
    -- Prüfe Concurrent-Limit
    if self.activeCount >= Config.Performance.maxConcurrentDUIs then
        Debug:Log("DUI", "Concurrent DUI limit reached, cleaning up oldest", {
            activeCount = self.activeCount,
            limit = Config.Performance.maxConcurrentDUIs
        }, "WARN")
        self:CleanupOldestDUI()
    end
    
    -- Erstelle neue DUI
    local duiData = self:CreateNewDUI(sprayId, textureData)
    
    Debug:EndProfile("DUIManager_GetOrCreateDUI")
    return duiData
end

-- Neue DUI erstellen mit Error-Handling
function DUIManager:CreateNewDUI(sprayId, textureData)
    Debug:StartProfile("DUIManager_CreateNewDUI", "DUI")
    
    local duiURL = self:GenerateDUIURL(textureData)
    
    -- Erstelle DUI mit Fehlerbehandlung
    local duiObj = CreateDui(duiURL, Config.Performance.textureResolution, Config.Performance.textureResolution)
    
    if not duiObj then
        Debug:Log("DUI", "Failed to create DUI object", {
            sprayId = sprayId,
            url = duiURL,
            resolution = Config.Performance.textureResolution
        }, "ERROR")
        
        Debug:EndProfile("DUIManager_CreateNewDUI")
        return nil
    end
    
    -- Hole DUI Handle
    local duiHandle = GetDuiHandle(duiObj)
    if not duiHandle then
        DestroyDui(duiObj)
        Debug:Log("DUI", "Failed to get DUI handle", {sprayId = sprayId}, "ERROR")
        
        Debug:EndProfile("DUIManager_CreateNewDUI")
        return nil
    end
    
    -- Erstelle Runtime Texture
    local txdName = 'spray_' .. sprayId
    local txd = CreateRuntimeTxd(txdName)
    local textureName = 'texture'
    local texture = CreateRuntimeTextureFromDuiHandle(txd, textureName, duiHandle)
    
    -- Berechne Memory-Nutzung (RGBA = 4 Bytes pro Pixel)
    local memorySize = Config.Performance.textureResolution * Config.Performance.textureResolution * 4
    
    -- Erstelle DUI-Datenstruktur
    local duiData = {
        dui = duiObj,
        handle = duiHandle,
        txd = txd,
        txdName = txdName,
        texture = texture,
        textureName = textureName,
        sprayId = sprayId,
        url = duiURL,
        textureData = textureData,
        memorySize = memorySize,
        created = GetGameTimer(),
        lastAccessed = GetGameTimer(),
        accessCount = 1,
        status = 'active'
    }
    
    -- Registriere in Pool
    self.pool[sprayId] = duiData
    self.activeCount = self.activeCount + 1
    self.memoryUsage = self.memoryUsage + memorySize
    self.statistics.created = self.statistics.created + 1
    
    -- Update Peak Memory
    if self.memoryUsage > self.statistics.memoryPeakUsage then
        self.statistics.memoryPeakUsage = self.memoryUsage
    end
    
    -- Registriere Texture für einfachen Zugriff
    self.textureRegistry[sprayId] = {
        txdName = txdName,
        textureName = textureName
    }
    
    Debug:LogDUIOperation("CREATE", sprayId, true, {
        memorySize = memorySize,
        totalMemory = self.memoryUsage,
        activeCount = self.activeCount
    })
    
    Debug:EndProfile("DUIManager_CreateNewDUI")
    return duiData
end

-- URL für DUI generieren basierend auf Texture-Typ
function DUIManager:GenerateDUIURL(textureData)
    if not textureData then
        return 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==' -- 1x1 transparent PNG
    end
    
    if textureData.type == 'editor' then
        return Config.DUI.editorURL
    elseif textureData.type == 'base64' and textureData.data then
        return textureData.data
    elseif textureData.type == 'url' and textureData.url then
        -- Verwende CORS Proxy für externe URLs
        return Config.DUI.proxyServer .. '?url=' .. encodeURI(textureData.url)
    elseif textureData.type == 'preset' and textureData.preset then
        -- Für Presets: Lade aus HTML Assets
        return string.format('nui://%s/html/presets/%s.png', GetCurrentResourceName(), textureData.preset)
    end
    
    -- Fallback auf Default Texture
    return string.format('nui://%s/html/presets/default.png', GetCurrentResourceName())
end

-- Älteste DUI cleanup (LRU - Least Recently Used)
function DUIManager:CleanupOldestDUI()
    Debug:StartProfile("DUIManager_CleanupOldestDUI", "DUI")
    
    local oldest = nil
    local oldestTime = GetGameTimer()
    
    -- Finde älteste DUI basierend auf lastAccessed
    for sprayId, duiData in pairs(self.pool) do
        if duiData.lastAccessed < oldestTime then
            oldest = sprayId
            oldestTime = duiData.lastAccessed
        end
    end
    
    if oldest then
        self:DestroyDUI(oldest)
        Debug:Log("DUI", "Cleaned up oldest DUI", {
            sprayId = oldest,
            ageMs = GetGameTimer() - oldestTime
        }, "SUCCESS")
    end
    
    Debug:EndProfile("DUIManager_CleanupOldestDUI")
end

-- Mehrere älteste DUIs cleanup (bei Memory-Überschreitung)
function DUIManager:ForceCleanupOldest(count)
    count = count or math.ceil(Config.Performance.maxConcurrentDUIs * 0.3) -- 30% cleanup
    
    Debug:StartProfile("DUIManager_ForceCleanupOldest", "DUI")
    
    -- Sammle alle DUIs mit ihren Access-Zeiten
    local duiList = {}
    for sprayId, duiData in pairs(self.pool) do
        table.insert(duiList, {
            sprayId = sprayId,
            lastAccessed = duiData.lastAccessed,
            accessCount = duiData.accessCount or 0
        })
    end
    
    -- Sortiere nach LRU (Least Recently Used) + Access Count
    table.sort(duiList, function(a, b)
        -- Primär: Ältere zuerst
        if a.lastAccessed ~= b.lastAccessed then
            return a.lastAccessed < b.lastAccessed
        end
        -- Sekundär: Weniger genutzte zuerst
        return a.accessCount < b.accessCount
    end)
    
    -- Lösche die ältesten DUIs
    local deletedCount = 0
    for i = 1, math.min(count, #duiList) do
        self:DestroyDUI(duiList[i].sprayId)
        deletedCount = deletedCount + 1
    end
    
    Debug:Log("DUI", "Force cleanup completed", {
        deletedCount = deletedCount,
        remainingDUIs = self.activeCount,
        memoryFreed = deletedCount * (Config.Performance.textureResolution * Config.Performance.textureResolution * 4)
    }, "SUCCESS")
    
    Debug:EndProfile("DUIManager_ForceCleanupOldest")
end

-- Einzelne DUI zerstören
function DUIManager:DestroyDUI(sprayId)
    local duiData = self.pool[sprayId]
    if not duiData then return false end
    
    Debug:StartProfile("DUIManager_DestroyDUI", "DUI")
    
    -- Setze URL auf blank (wichtig für Memory-Freigabe)
    if duiData.dui and DoesUrlExist(duiData.url) then
        SetDuiUrl(duiData.dui, 'about:blank')
        Wait(50) -- Kurze Pause für Browser-Cleanup
    end
    
    -- Zerstöre DUI Object
    if duiData.dui then
        DestroyDui(duiData.dui)
    end
    
    -- Update Statistiken
    self.activeCount = self.activeCount - 1
    self.memoryUsage = self.memoryUsage - duiData.memorySize
    self.statistics.destroyed = self.statistics.destroyed + 1
    
    -- Entferne aus Registry
    self.pool[sprayId] = nil
    self.textureRegistry[sprayId] = nil
    
    Debug:LogDUIOperation("DESTROY", sprayId, true, {
        memoryFreed = duiData.memorySize,
        remainingMemory = self.memoryUsage,
        remainingDUIs = self.activeCount
    })
    
    Debug:EndProfile("DUIManager_DestroyDUI")
    
    -- Trigger Garbage Collection wenn viel Memory freigeworden ist
    if duiData.memorySize > 10 * 1024 * 1024 then -- > 10MB
        collectgarbage("step", 100)
    end
    
    return true
end

-- Alle DUIs zerstören (Resource Stop)
function DUIManager:DestroyAllDUIs()
    Debug:StartProfile("DUIManager_DestroyAllDUIs", "DUI")
    
    local destroyedCount = 0
    local freedMemory = 0
    
    for sprayId, duiData in pairs(self.pool) do
        -- Setze URL auf blank
        if duiData.dui then
            SetDuiUrl(duiData.dui, 'about:blank')
        end
        
        Wait(10) -- Kleine Pause zwischen DUI-Zerstörungen
        
        -- Zerstöre DUI
        if duiData.dui then
            DestroyDui(duiData.dui)
        end
        
        freedMemory = freedMemory + duiData.memorySize
        destroyedCount = destroyedCount + 1
    end
    
    -- Reset aller Daten
    self.pool = {}
    self.textureRegistry = {}
    self.activeCount = 0
    self.memoryUsage = 0
    
    Debug:Log("DUI", "All DUIs destroyed on resource stop", {
        destroyedCount = destroyedCount,
        freedMemory = freedMemory
    }, "SUCCESS")
    
    Debug:EndProfile("DUIManager_DestroyAllDUIs")
    
    -- Force Garbage Collection
    collectgarbage("collect")
end

-- Texture Handle für Rendering abrufen
function DUIManager:GetTextureHandle(sprayId)
    local textureInfo = self.textureRegistry[sprayId]
    if not textureInfo then return nil end
    
    return textureInfo.txdName, textureInfo.textureName
end

-- DUI URL aktualisieren (für Paint Editor)
function DUIManager:UpdateDUIContent(sprayId, newTextureData)
    local duiData = self.pool[sprayId]
    if not duiData then return false end
    
    Debug:StartProfile("DUIManager_UpdateDUIContent", "DUI")
    
    local newURL = self:GenerateDUIURL(newTextureData)
    
    -- Aktualisiere DUI URL
    SetDuiUrl(duiData.dui, newURL)
    
    -- Update Metadaten
    duiData.url = newURL
    duiData.textureData = newTextureData
    duiData.lastAccessed = GetGameTimer()
    
    Debug:Log("DUI", "DUI content updated", {
        sprayId = sprayId,
        newURL = newURL
    }, "SUCCESS")
    
    Debug:EndProfile("DUIManager_UpdateDUIContent")
    return true
end

-- Memory Monitoring Thread
function DUIManager:StartMemoryMonitor()
    CreateThread(function()
        while true do
            Wait(Config.Threading.memoryCheckInterval)
            
            if self.activeCount > 0 then
                Debug:CheckMemoryUsage()
                
                -- Auto-Cleanup bei kritischer Memory-Nutzung
                if self.memoryUsage > Config.Performance.memoryThreshold * 0.9 then
                    Debug:Log("DUI", "Critical memory usage detected, starting auto-cleanup", {
                        currentMemory = self.memoryUsage,
                        threshold = Config.Performance.memoryThreshold
                    }, "WARN")
                    
                    self:ForceCleanupOldest(3) -- Cleanup 3 älteste DUIs
                end
                
                -- Performance-Statistiken loggen
                if Config.Debug.enabled then
                    self:LogPerformanceStats()
                end
            end
        end
    end)
end

-- Performance-Statistiken loggen
function DUIManager:LogPerformanceStats()
    local stats = {
        activeCount = self.activeCount,
        memoryUsage = self.memoryUsage,
        memoryUsageMB = self.memoryUsage / 1024 / 1024,
        memoryPeakMB = self.statistics.memoryPeakUsage / 1024 / 1024,
        totalCreated = self.statistics.created,
        totalDestroyed = self.statistics.destroyed,
        totalRecycled = self.statistics.recycled,
        efficiency = self.statistics.recycled / math.max(self.statistics.created, 1) * 100
    }
    
    Debug:Log("DUI", "Performance statistics", stats, "INFO")
end

-- Status-Informationen abrufen (für Debug-Commands)
function DUIManager:GetStatus()
    local status = {
        activeCount = self.activeCount,
        maxConcurrent = Config.Performance.maxConcurrentDUIs,
        memoryUsage = self.memoryUsage,
        memoryUsageMB = math.floor(self.memoryUsage / 1024 / 1024 * 100) / 100,
        memoryThresholdMB = math.floor(Config.Performance.memoryThreshold / 1024 / 1024 * 100) / 100,
        statistics = self.statistics,
        duiList = {}
    }
    
    -- Detaillierte DUI-Liste für Debug
    for sprayId, duiData in pairs(self.pool) do
        table.insert(status.duiList, {
            sprayId = sprayId,
            age = GetGameTimer() - duiData.created,
            lastAccessed = GetGameTimer() - duiData.lastAccessed,
            accessCount = duiData.accessCount or 0,
            memorySize = duiData.memorySize,
            type = duiData.textureData and duiData.textureData.type or 'unknown'
        })
    end
    
    return status
end

-- Public API für andere Module
function DUIManager:GetTextureForSpray(sprayId)
    return self:GetTextureHandle(sprayId)
end

function DUIManager:IsSprayLoaded(sprayId)
    return self.pool[sprayId] ~= nil
end

function DUIManager:GetMemoryUsage()
    return self.memoryUsage
end

-- Initialisierung beim Script-Start
CreateThread(function()
    Wait(500) -- Warte bis Config geladen ist
    DUIManager:Initialize()
end)