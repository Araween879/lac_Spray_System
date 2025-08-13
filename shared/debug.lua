-- Debug und Performance Monitoring System für Spray-System
-- Funktioniert sowohl Client- als auch Server-seitig

Debug = Debug or {
    enabled = false,
    metrics = {},
    logs = {},
    performanceData = {}
}

-- Aktivierung des Debug-Modus (kann zur Laufzeit geändert werden)
function Debug:Toggle()
    self.enabled = not self.enabled
    local status = self.enabled and "ENABLED" or "DISABLED"
    
    if IsDuplicityVersion() then
        print(string.format("^3[SPRAY DEBUG] Server Debug Mode: %s", status))
    else
        print(string.format("^3[SPRAY DEBUG] Client Debug Mode: %s", status))
        -- Speichere Client-Einstellung persistent
        SetResourceKvpInt("spray_debug_enabled", self.enabled and 1 or 0)
    end
end

-- Initialisierung (lädt gespeicherte Debug-Einstellungen)
function Debug:Initialize()
    if not IsDuplicityVersion() then
        -- Client: Lade gespeicherte Debug-Einstellung
        local savedSetting = GetResourceKvpInt("spray_debug_enabled")
        self.enabled = savedSetting == 1
    else
        -- Server: Nutze ConVar
        self.enabled = GetConvarInt('spray_debug', 0) == 1
    end
    
    if self.enabled then
        print("^2[SPRAY DEBUG] Debug system initialized and ENABLED")
    end
end

-- Erweiterte Logging-Funktion mit Kategorisierung
function Debug:Log(category, message, data, level)
    if not self.enabled then return end
    
    level = level or "INFO"
    local timestamp = os.date("%H:%M:%S")
    local side = IsDuplicityVersion() and "SERVER" or "CLIENT"
    
    local logEntry = {
        timestamp = timestamp,
        side = side,
        category = category,
        level = level,
        message = message,
        data = data,
        gameTime = GetGameTimer()
    }
    
    -- Farb-Kodierung basierend auf Level
    local colorCode = "^7" -- Weiß (Standard)
    if level == "ERROR" then colorCode = "^1"     -- Rot
    elseif level == "WARN" then colorCode = "^3"  -- Gelb  
    elseif level == "SUCCESS" then colorCode = "^2" -- Grün
    elseif level == "INFO" then colorCode = "^4"  -- Blau
    end
    
    -- Console Output
    print(string.format("%s[SPRAY DEBUG] [%s] [%s] [%s] %s", 
        colorCode, side, timestamp, category, message))
    
    -- Data Output wenn vorhanden
    if data then
        if type(data) == "table" then
            print(json.encode(data, {indent = true}))
        else
            print(tostring(data))
        end
    end
    
    -- Log Entry speichern
    table.insert(self.logs, logEntry)
    
    -- Begenze Log-Größe (Performance)
    if #self.logs > 200 then
        table.remove(self.logs, 1)
    end
end

-- Performance Profiling System
function Debug:StartProfile(name, category)
    if not self.enabled then return end
    
    category = category or "GENERAL"
    
    self.metrics[name] = {
        category = category,
        startTime = GetGameTimer(),
        startMem = collectgarbage("count") * 1024, -- Convert KB to Bytes
        side = IsDuplicityVersion() and "SERVER" or "CLIENT"
    }
    
    self:Log("PROFILER", string.format("Started profiling: %s", name), nil, "INFO")
end

function Debug:EndProfile(name)
    if not self.enabled or not self.metrics[name] then return end
    
    local metric = self.metrics[name]
    local duration = GetGameTimer() - metric.startTime
    local memUsed = (collectgarbage("count") * 1024) - metric.startMem
    
    local result = {
        name = name,
        category = metric.category,
        side = metric.side,
        duration = duration,
        memoryUsed = memUsed,
        timestamp = os.date("%H:%M:%S")
    }
    
    -- Performance-Daten speichern
    if not self.performanceData[metric.category] then
        self.performanceData[metric.category] = {}
    end
    table.insert(self.performanceData[metric.category], result)
    
    -- Performance Warning System
    local warningMessage = nil
    local level = "SUCCESS"
    
    if duration > 100 then
        warningMessage = string.format("SLOW OPERATION: %s took %dms", name, duration)
        level = "ERROR"
    elseif duration > 50 then
        warningMessage = string.format("Performance warning: %s took %dms", name, duration)
        level = "WARN"
    end
    
    if memUsed > 1024 * 1024 then -- > 1MB
        local memWarning = string.format("HIGH MEMORY USAGE: %s used %.2f MB", 
            name, memUsed / 1024 / 1024)
        level = "ERROR"
        if warningMessage then
            warningMessage = warningMessage .. " | " .. memWarning
        else
            warningMessage = memWarning
        end
    end
    
    if warningMessage then
        self:Log("PERFORMANCE", warningMessage, result, level)
    else
        self:Log("PROFILER", string.format("Completed: %s (%.2fms, %.2fKB)", 
            name, duration, memUsed / 1024), result, "SUCCESS")
    end
    
    -- Cleanup
    self.metrics[name] = nil
    
    return result
end

-- Memory Monitoring
function Debug:CheckMemoryUsage()
    if not self.enabled then return end
    
    local memUsage = collectgarbage("count") * 1024 -- Bytes
    local side = IsDuplicityVersion() and "SERVER" or "CLIENT"
    
    local memData = {
        side = side,
        currentMemory = memUsage,
        memoryMB = memUsage / 1024 / 1024,
        timestamp = GetGameTimer()
    }
    
    -- Memory Warning Thresholds
    if Config and Config.Performance and Config.Performance.memoryThreshold then
        if memUsage > Config.Performance.memoryThreshold then
            self:Log("MEMORY", string.format("Memory threshold exceeded: %.2f MB", 
                memData.memoryMB), memData, "ERROR")
        elseif memUsage > Config.Performance.memoryThreshold * 0.8 then
            self:Log("MEMORY", string.format("Memory usage high: %.2f MB", 
                memData.memoryMB), memData, "WARN")
        end
    end
    
    return memData
end

-- DUI-spezifisches Debug
function Debug:LogDUIOperation(operation, sprayId, success, details)
    if not self.enabled then return end
    
    local level = success and "SUCCESS" or "ERROR"
    local message = string.format("DUI %s for spray %s: %s", 
        operation, sprayId, success and "SUCCESS" or "FAILED")
    
    self:Log("DUI", message, details, level)
end

-- Network Event Tracking
function Debug:LogNetworkEvent(eventName, source, data, incoming)
    if not self.enabled then return end
    
    local direction = incoming and "RECEIVED" or "SENT"
    local message = string.format("%s network event: %s", direction, eventName)
    
    local eventData = {
        eventName = eventName,
        source = source,
        direction = direction,
        dataSize = data and string.len(json.encode(data)) or 0,
        timestamp = GetGameTimer()
    }
    
    self:Log("NETWORK", message, eventData, "INFO")
end

-- Statistics und Reporting
function Debug:GenerateReport()
    if not self.enabled then return "Debug mode not enabled" end
    
    local report = {
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        side = IsDuplicityVersion() and "SERVER" or "CLIENT",
        totalLogs = #self.logs,
        performanceCategories = {},
        memoryUsage = collectgarbage("count") * 1024
    }
    
    -- Performance-Statistiken pro Kategorie
    for category, measurements in pairs(self.performanceData) do
        if #measurements > 0 then
            local total = 0
            local slowest = 0
            local memoryTotal = 0
            
            for _, measurement in ipairs(measurements) do
                total = total + measurement.duration
                if measurement.duration > slowest then
                    slowest = measurement.duration
                end
                memoryTotal = memoryTotal + measurement.memoryUsed
            end
            
            report.performanceCategories[category] = {
                measurements = #measurements,
                averageDuration = total / #measurements,
                slowestOperation = slowest,
                totalMemoryUsed = memoryTotal,
                averageMemoryUsed = memoryTotal / #measurements
            }
        end
    end
    
    return report
end

-- System Information
function Debug:GetSystemInfo()
    local info = {
        side = IsDuplicityVersion() and "SERVER" or "CLIENT",
        resourceName = GetCurrentResourceName(),
        gameTimer = GetGameTimer(),
        memoryUsage = collectgarbage("count") * 1024,
        debugEnabled = self.enabled,
        totalLogs = #self.logs,
        activeProfiles = 0
    }
    
    -- Zähle aktive Profile
    for _ in pairs(self.metrics) do
        info.activeProfiles = info.activeProfiles + 1
    end
    
    if not IsDuplicityVersion() then
        -- Client-spezifische Informationen
        local playerPed = PlayerPedId()
        info.playerId = PlayerId()
        info.playerCoords = playerPed and GetEntityCoords(playerPed) or vector3(0,0,0)
        info.fps = GetFrameTime() > 0 and math.floor(1.0 / GetFrameTime()) or 0
    else
        -- Server-spezifische Informationen
        info.playerCount = GetNumPlayerIndices()
        info.maxPlayers = GetConvarInt('sv_maxclients', 32)
    end
    
    return info
end

-- Cleanup alte Performance-Daten
CreateThread(function()
    while true do
        Wait(300000) -- 5 Minuten
        
        if Debug.enabled then
            -- Cleanup Performance-Daten älter als 1 Stunde
            local cutoffTime = GetGameTimer() - 3600000
            
            for category, measurements in pairs(Debug.performanceData) do
                local newMeasurements = {}
                for _, measurement in ipairs(measurements) do
                    if measurement.timestamp and 
                       (GetGameTimer() - measurement.timestamp) < 3600000 then
                        table.insert(newMeasurements, measurement)
                    end
                end
                Debug.performanceData[category] = newMeasurements
            end
            
            Debug:Log("CLEANUP", "Cleaned up old performance data", nil, "INFO")
        end
    end
end)

-- Debug Commands (nur Client-seitig)
if not IsDuplicityVersion() then
    RegisterCommand('spray_debug', function(source, args)
        if args[1] == 'toggle' then
            Debug:Toggle()
        elseif args[1] == 'report' then
            local report = Debug:GenerateReport()
            print("^3[SPRAY DEBUG] Performance Report:")
            print(json.encode(report, {indent = true}))
        elseif args[1] == 'memory' then
            local memData = Debug:CheckMemoryUsage()
            print(string.format("^3[SPRAY DEBUG] Memory Usage: %.2f MB", memData.memoryMB))
        elseif args[1] == 'info' then
            local info = Debug:GetSystemInfo()
            print("^3[SPRAY DEBUG] System Info:")
            print(json.encode(info, {indent = true}))
        else
            print("^3[SPRAY DEBUG] Available commands:")
            print("^7/spray_debug toggle - Toggle debug mode")
            print("^7/spray_debug report - Generate performance report")
            print("^7/spray_debug memory - Check memory usage")
            print("^7/spray_debug info - Show system info")
        end
    end, false)
end

-- Initialisierung beim Script-Start
CreateThread(function()
    Wait(1000) -- Warte bis Config geladen ist
    Debug:Initialize()
end)

print("^2[SPRAY DEBUG] Debug system loaded successfully")