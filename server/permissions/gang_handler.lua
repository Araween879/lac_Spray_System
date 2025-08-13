-- Gang Permission Handler für QB-Core Integration
-- Optimiertes Caching-System mit Rate-Limiting und Anti-Spam Protection
-- ✅ ERWEITERT: Public Access + Item-basierte Entfernung

local QBCore = exports['qb-core']:GetCoreObject()

GangPermissions = GangPermissions or {
    permissionCache = {},             -- Cache für Gang-Berechtigungen
    rateLimitCache = {},              -- Rate-Limiting Cache
    spamProtection = {},              -- Anti-Spam Protection
    statistics = {
        permissionChecks = 0,
        cacheMisses = 0,
        cacheHits = 0,
        deniedAttempts = 0,
        rateLimitBlocks = 0,
        publicSpraysCreated = 0,      -- ✅ NEU: Public Spray Statistiken
        itemRemovals = 0              -- ✅ NEU: Item-basierte Entfernungen
    }
}

-- ✅ ERWEITERT: Hauptfunktion mit Public Access Support
function GangPermissions:CanUseSpray(source)
    Debug:StartProfile("GangPermissions_CanUseSpray", "PERMISSIONS")
    
    self.statistics.permissionChecks = self.statistics.permissionChecks + 1
    
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        Debug:Log("PERMISSIONS", "Invalid player for permission check", {source = source}, "ERROR")
        Debug:EndProfile("GangPermissions_CanUseSpray")
        return false, "Ungültiger Spieler"
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Cache-Check für Performance
    local cachedPermission = self:GetCachedPermission(source, citizenid)
    if cachedPermission then
        self.statistics.cacheHits = self.statistics.cacheHits + 1
        Debug:EndProfile("GangPermissions_CanUseSpray")
        return cachedPermission.allowed, cachedPermission.reason, cachedPermission.metadata
    end
    
    self.statistics.cacheMisses = self.statistics.cacheMisses + 1
    
    -- ✅ NEU: Public Spray Check hat HÖCHSTE Priorität
    if Config.Permissions.allowPublicSpray then
        local publicCheck = self:ValidatePublicSprayAccess(source, Player)
        if publicCheck.allowed then
            local result = {allowed = true, reason = publicCheck.reason, metadata = publicCheck.metadata}
            self:CachePermission(source, citizenid, result)
            
            Debug:Log("PERMISSIONS", "Public spray access granted", {
                citizenid = citizenid,
                sprayType = "public"
            }, "SUCCESS")
            
            Debug:EndProfile("GangPermissions_CanUseSpray")
            return true, publicCheck.reason, publicCheck.metadata
        else
            -- Wenn Public Access fehlschlägt, logge Grund aber versuche Gang-Access
            Debug:Log("PERMISSIONS", "Public spray access failed", {
                citizenid = citizenid,
                reason = publicCheck.reason
            }, "INFO")
        end
    end
    
    -- Rate-Limiting Check für Gang-Sprays
    local rateLimitResult = self:CheckRateLimit(source, citizenid, 'create')
    if not rateLimitResult.allowed then
        self.statistics.rateLimitBlocks = self.statistics.rateLimitBlocks + 1
        Debug:Log("PERMISSIONS", "Rate limit exceeded", {
            citizenid = citizenid,
            reason = rateLimitResult.reason
        }, "WARN")
        
        Debug:EndProfile("GangPermissions_CanUseSpray")
        return false, rateLimitResult.reason
    end
    
    local playerData = Player.PlayerData
    
    -- 1. Admin Bypass Check
    if Config.Permissions.adminCanBypass and self:IsPlayerAdmin(source) then
        local result = {allowed = true, reason = "Admin Bypass", metadata = {admin = true}}
        self:CachePermission(source, citizenid, result)
        
        Debug:Log("PERMISSIONS", "Admin bypass granted", {citizenid = citizenid}, "SUCCESS")
        Debug:EndProfile("GangPermissions_CanUseSpray")
        return true, "Admin Berechtigung", result.metadata
    end
    
    -- 2. Gang Membership Check (nur wenn erforderlich)
    if Config.Permissions.requireGangMembership then
        local gangCheck = self:ValidateGangMembership(playerData)
        if not gangCheck.valid then
            self.statistics.deniedAttempts = self.statistics.deniedAttempts + 1
            self:CachePermission(source, citizenid, {allowed = false, reason = gangCheck.reason})
            
            Debug:Log("PERMISSIONS", "Gang membership denied", {
                citizenid = citizenid,
                gang = playerData.gang and playerData.gang.name or "none",
                reason = gangCheck.reason
            }, "WARN")
            
            Debug:EndProfile("GangPermissions_CanUseSpray")
            return false, gangCheck.reason
        end
        
        -- Gang-basierte Berechtigung
        local gangMetadata = self:CreateGangMetadata(playerData, gangCheck)
        local result = {allowed = true, reason = "Gang-Berechtigung erteilt", metadata = gangMetadata}
        self:CachePermission(source, citizenid, result)
        
        Debug:EndProfile("GangPermissions_CanUseSpray")
        return true, result.reason, gangMetadata
    end
    
    -- 3. Job-based Check (wenn erlaubt)
    local jobCheck = nil
    if Config.Permissions.allowJobSpray then
        jobCheck = self:ValidateJobPermission(playerData)
        if jobCheck.valid then
            local jobMetadata = self:CreateJobMetadata(playerData, jobCheck)
            local result = {allowed = true, reason = "Job-Berechtigung erteilt", metadata = jobMetadata}
            self:CachePermission(source, citizenid, result)
            
            Debug:EndProfile("GangPermissions_CanUseSpray")
            return true, result.reason, jobMetadata
        end
    end
    
    -- Fallback: Kein Zugang
    self.statistics.deniedAttempts = self.statistics.deniedAttempts + 1
    Debug:Log("PERMISSIONS", "All permission checks failed", {citizenid = citizenid}, "WARN")
    
    Debug:EndProfile("GangPermissions_CanUseSpray")
    return false, "Keine Berechtigung für Spray-System"
end

-- ✅ NEU: Public Spray Access Validation
function GangPermissions:ValidatePublicSprayAccess(source, Player)
    Debug:StartProfile("GangPermissions_ValidatePublicSprayAccess", "PERMISSIONS")
    
    local citizenid = Player.PlayerData.citizenid
    
    -- 1. Rate-Limiting Check für Public Users
    local rateLimitResult = self:CheckRateLimit(source, citizenid, 'create')
    if not rateLimitResult.allowed then
        Debug:EndProfile("GangPermissions_ValidatePublicSprayAccess")
        return {
            allowed = false,
            reason = rateLimitResult.reason
        }
    end
    
    -- 2. Item Check (Spray Can) - KRITISCH für Item-Only System
    local itemCheck = self:ValidateSprayCanItem(Player)
    if not itemCheck.valid then
        Debug:EndProfile("GangPermissions_ValidatePublicSprayAccess")
        return {
            allowed = false,
            reason = itemCheck.reason
        }
    end
    
    -- 3. Public Spray Limit Check
    local limitCheck = self:CheckPublicPlayerSprayLimit(citizenid)
    if not limitCheck.valid then
        Debug:EndProfile("GangPermissions_ValidatePublicSprayAccess")
        return {
            allowed = false,
            reason = limitCheck.reason
        }
    end
    
    -- 4. Server-weite Public Spray Limits
    local globalLimitCheck = self:CheckGlobalPublicSprayLimit()
    if not globalLimitCheck.valid then
        Debug:EndProfile("GangPermissions_ValidatePublicSprayAccess")
        return {
            allowed = false,
            reason = globalLimitCheck.reason
        }
    end
    
    self.statistics.publicSpraysCreated = self.statistics.publicSpraysCreated + 1
    
    Debug:EndProfile("GangPermissions_ValidatePublicSprayAccess")
    
    return {
        allowed = true,
        reason = "Öffentliches Spray erlaubt",
        metadata = {
            sprayType = "public",
            gang = "public",
            gangGrade = 0,
            sprayCanUses = itemCheck.uses,
            playerLimits = limitCheck.limits,
            globalLimits = globalLimitCheck.limits,
            timestamp = os.time(),
            isPublic = true,
            publicAccess = true
        }
    }
end

-- ✅ NEU: Public Player Spray Limit Check
function GangPermissions:CheckPublicPlayerSprayLimit(citizenid)
    local maxSprays = Config.Permissions.publicSprayLimit or 2
    
    -- Synchroner Check für bessere Performance
    local sprayCount = 0
    exports.oxmysql:scalar('SELECT COUNT(*) FROM gang_sprays WHERE citizenid = ? AND gang_name = "public" AND (expires_at IS NULL OR expires_at > NOW())', {
        citizenid
    }, function(result)
        sprayCount = result or 0
    end)
    
    -- Warte kurz für DB Response
    Wait(100)
    
    if sprayCount >= maxSprays then
        return {
            valid = false,
            reason = string.format("Öffentliches Spray-Limit erreicht (%d/%d)", sprayCount, maxSprays)
        }
    end
    
    return {
        valid = true,
        limits = {
            current = sprayCount,
            maximum = maxSprays,
            remaining = maxSprays - sprayCount
        }
    }
end

-- ✅ NEU: Global Public Spray Limit Check
function GangPermissions:CheckGlobalPublicSprayLimit()
    local maxGlobalPublic = Config.Gangs.Global.maxPublicSpraysTotal or 25
    
    local globalCount = 0
    exports.oxmysql:scalar('SELECT COUNT(*) FROM gang_sprays WHERE gang_name = "public" AND (expires_at IS NULL OR expires_at > NOW())', {}, function(result)
        globalCount = result or 0
    end)
    
    Wait(100)
    
    if globalCount >= maxGlobalPublic then
        return {
            valid = false,
            reason = string.format("Server-weites Public Spray-Limit erreicht (%d/%d)", globalCount, maxGlobalPublic)
        }
    end
    
    return {
        valid = true,
        limits = {
            current = globalCount,
            maximum = maxGlobalPublic,
            remaining = maxGlobalPublic - globalCount
        }
    }
end

-- ✅ ERWEITERT: Gang Membership Validation (bleibt bestehend)
function GangPermissions:ValidateGangMembership(playerData)
    if not playerData.gang or playerData.gang.name == 'none' then
        return {valid = false, reason = "Nicht in einer Gang"}
    end
    
    -- Prüfe ob Gang erlaubt ist
    if not Config.Gangs.AllowedGangs[playerData.gang.name] then
        return {valid = false, reason = "Gang nicht autorisiert für Sprays"}
    end
    
    local gangConfig = Config.Gangs.AllowedGangs[playerData.gang.name]
    
    -- Mindest-Rang Check
    if playerData.gang.grade.level < gangConfig.minimumGrade then
        return {
            valid = false, 
            reason = string.format("Gang-Rang zu niedrig (benötigt: %d, aktuell: %d)", 
                gangConfig.minimumGrade, playerData.gang.grade.level)
        }
    end
    
    return {
        valid = true,
        gangConfig = gangConfig,
        gangName = playerData.gang.name,
        grade = playerData.gang.grade.level
    }
end

-- Job Permission Validation (bleibt bestehend)
function GangPermissions:ValidateJobPermission(playerData)
    if not Config.Permissions.allowJobSpray then
        return {valid = false, reason = "Job-Sprays nicht erlaubt"}
    end
    
    if not playerData.job or playerData.job.name == 'unemployed' then
        return {valid = false, reason = "Kein gültiger Job"}
    end
    
    -- Prüfe ob Job erlaubt ist
    if not Config.Gangs.AllowedJobs[playerData.job.name] then
        return {valid = false, reason = "Job nicht autorisiert für Sprays"}
    end
    
    local jobConfig = Config.Gangs.AllowedJobs[playerData.job.name]
    
    -- Mindest-Rang Check
    if playerData.job.grade.level < jobConfig.minimumGrade then
        return {
            valid = false,
            reason = string.format("Job-Rang zu niedrig (benötigt: %d, aktuell: %d)",
                jobConfig.minimumGrade, playerData.job.grade.level)
        }
    end
    
    return {
        valid = true,
        jobConfig = jobConfig,
        jobName = playerData.job.name,
        grade = playerData.job.grade.level
    }
end

-- Spray Can Item Validation (bleibt bestehend aber kritisch für Item-Only)
function GangPermissions:ValidateSprayCanItem(Player)
    local sprayItem = Player.Functions.GetItemByName(Config.Items.sprayCanItem)
    
    if not sprayItem then
        return {valid = false, reason = "Keine Spray-Dose vorhanden"}
    end
    
    -- Prüfe Item-Qualität
    local quality = sprayItem.info and sprayItem.info.quality or Config.Items.defaultQuality
    if quality < Config.Items.minimumQuality then
        return {valid = false, reason = "Spray-Dose zu beschädigt"}
    end
    
    -- Prüfe Verwendungen
    local uses = sprayItem.info and sprayItem.info.uses or Config.Items.sprayCanUses
    if uses <= 0 then
        return {valid = false, reason = "Spray-Dose ist leer"}
    end
    
    return {
        valid = true,
        uses = uses,
        quality = quality,
        item = sprayItem
    }
end

-- ✅ NEU: Spray Remover Item Validation
function GangPermissions:ValidateSprayRemoverItem(Player)
    local removerItem = Player.Functions.GetItemByName(Config.Items.sprayRemoverItem)
    
    if not removerItem then
        return {valid = false, reason = "Kein Graffiti-Entferner vorhanden"}
    end
    
    -- Prüfe Uses
    local uses = removerItem.info and removerItem.info.uses or Config.Items.removeSprayUses
    if uses <= 0 then
        return {valid = false, reason = "Graffiti-Entferner ist aufgebraucht"}
    end
    
    -- Prüfe Qualität
    local quality = removerItem.info and removerItem.info.quality or Config.Items.defaultQuality
    if quality < Config.Items.minimumQuality then
        return {valid = false, reason = "Graffiti-Entferner zu beschädigt"}
    end
    
    return {
        valid = true,
        uses = uses,
        quality = quality,
        item = removerItem,
        metadata = {
            remainingUses = uses,
            itemQuality = quality,
            successChance = Config.Items.removerSuccessChance or 0.9,
            range = Config.Items.removerRange or 5.0
        }
    }
end

-- ✅ ERWEITERT: Spray-Entfernung Permission Check
function GangPermissions:CanRemoveSpray(source, sprayId)
    Debug:StartProfile("GangPermissions_CanRemoveSpray", "PERMISSIONS")
    
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        Debug:EndProfile("GangPermissions_CanRemoveSpray")
        return false, "Ungültiger Spieler"
    end
    
    -- Admin kann immer entfernen
    if self:IsPlayerAdmin(source) then
        Debug:EndProfile("GangPermissions_CanRemoveSpray")
        return true, "Admin Berechtigung", {admin = true}
    end
    
    -- ✅ NEU: Item-basierte Entfernung (HÖCHSTE Priorität)
    if Config.Permissions.allowItemRemoval then
        local removerCheck = self:ValidateSprayRemoverItem(Player)
        if removerCheck.valid then
            Debug:Log("PERMISSIONS", "Item-based removal granted", {
                citizenid = Player.PlayerData.citizenid,
                sprayId = sprayId,
                uses = removerCheck.uses
            }, "SUCCESS")
            
            Debug:EndProfile("GangPermissions_CanRemoveSpray")
            return true, "Entferner-Item verwendet", removerCheck.metadata
        else
            Debug:Log("PERMISSIONS", "Item-based removal failed", {
                citizenid = Player.PlayerData.citizenid,
                reason = removerCheck.reason
            }, "WARN")
        end
    end
    
    -- Bestehende Gang-basierte Entfernung...
    local spray = SpraySystem and SpraySystem:GetSprayData(sprayId)
    if not spray then
        Debug:EndProfile("GangPermissions_CanRemoveSpray")
        return false, "Spray nicht gefunden"
    end
    
    -- Eigenes Spray
    if spray.citizenid == Player.PlayerData.citizenid then
        Debug:EndProfile("GangPermissions_CanRemoveSpray")
        return true, "Eigenes Spray", {owner = true}
    end
    
    -- Gang-Leader kann Gang-Sprays entfernen
    local playerData = Player.PlayerData
    if playerData.gang and playerData.gang.name == spray.gang_name and playerData.gang.grade.level >= 3 then
        Debug:EndProfile("GangPermissions_CanRemoveSpray")
        return true, "Gang-Leader Berechtigung", {gangLeader = true}
    end
    
    -- Rivalen-Gang kann übermalen (falls aktiviert)
    if Config.Gangs.AllowedGangs[playerData.gang.name] and Config.Gangs.AllowedGangs[playerData.gang.name].canOverwriteOthers then
        local rivalries = Config.Gangs.Rivalries[playerData.gang.name] or {}
        for _, rival in ipairs(rivalries) do
            if rival == spray.gang_name then
                Debug:EndProfile("GangPermissions_CanRemoveSpray")
                return true, "Rivalen-Gang Überschreibung", {rivalry = true}
            end
        end
    end
    
    Debug:EndProfile("GangPermissions_CanRemoveSpray")
    return false, "Keine Berechtigung zum Entfernen"
end

-- ✅ NEU: Entferner-Item verbrauchen
function GangPermissions:ConsumeSprayRemoverUse(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local removerItem = Player.Functions.GetItemByName(Config.Items.sprayRemoverItem)
    if not removerItem then return false end
    
    local currentUses = removerItem.info and removerItem.info.uses or Config.Items.removeSprayUses
    
    if currentUses <= 1 then
        -- Item komplett entfernen
        Player.Functions.RemoveItem(Config.Items.sprayRemoverItem, 1, removerItem.slot)
        TriggerClientEvent('QBCore:Notify', source, 'Graffiti-Entferner ist leer und wurde entfernt', 'info')
        
        Debug:Log("PERMISSIONS", "Spray remover depleted and removed", {
            citizenid = Player.PlayerData.citizenid
        }, "INFO")
        
        return false
    else
        -- Reduziere Uses
        local newInfo = removerItem.info or {}
        newInfo.uses = currentUses - 1
        
        -- Qualitätsverlust
        if Config.Items.qualityLossPerUse > 0 then
            newInfo.quality = math.max(
                (newInfo.quality or Config.Items.defaultQuality) - Config.Items.qualityLossPerUse,
                0
            )
        end
        
        Player.Functions.RemoveItem(Config.Items.sprayRemoverItem, 1, removerItem.slot)
        Player.Functions.AddItem(Config.Items.sprayRemoverItem, 1, removerItem.slot, newInfo)
        
        Debug:Log("PERMISSIONS", "Spray remover use consumed", {
            citizenid = Player.PlayerData.citizenid,
            remainingUses = newInfo.uses,
            quality = newInfo.quality
        }, "INFO")
        
        self.statistics.itemRemovals = self.statistics.itemRemovals + 1
        
        return true
    end
end

-- Item Consumption beim Sprayen (bestehend, bleibt gleich)
function GangPermissions:ConsumeSprayCanUse(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local sprayItem = Player.Functions.GetItemByName(Config.Items.sprayCanItem)
    if not sprayItem then return false end
    
    local currentUses = sprayItem.info and sprayItem.info.uses or Config.Items.sprayCanUses
    
    if currentUses <= 1 then
        -- Item komplett entfernen
        Player.Functions.RemoveItem(Config.Items.sprayCanItem, 1, sprayItem.slot)
        TriggerClientEvent('QBCore:Notify', source, 'Spray-Dose ist leer und wurde entfernt', 'error')
        
        Debug:Log("PERMISSIONS", "Spray can depleted and removed", {
            citizenid = Player.PlayerData.citizenid
        }, "INFO")
        
        return false
    else
        -- Reduziere Uses
        local newInfo = sprayItem.info or {}
        newInfo.uses = currentUses - 1
        
        if Config.Items.qualityLossPerUse > 0 then
            newInfo.quality = math.max(
                (newInfo.quality or Config.Items.defaultQuality) - Config.Items.qualityLossPerUse,
                0
            )
        end
        
        Player.Functions.RemoveItem(Config.Items.sprayCanItem, 1, sprayItem.slot)
        Player.Functions.AddItem(Config.Items.sprayCanItem, 1, sprayItem.slot, newInfo)
        
        Debug:Log("PERMISSIONS", "Spray can use consumed", {
            citizenid = Player.PlayerData.citizenid,
            remainingUses = newInfo.uses,
            quality = newInfo.quality
        }, "INFO")
        
        return true
    end
end

-- ✅ NEU: Metadata Creation Helper
function GangPermissions:CreateGangMetadata(playerData, gangCheck)
    return {
        sprayType = "gang",
        gang = playerData.gang.name,
        gangGrade = playerData.gang.grade.level,
        gangConfig = gangCheck.gangConfig,
        timestamp = os.time(),
        isPublic = false
    }
end

function GangPermissions:CreateJobMetadata(playerData, jobCheck)
    return {
        sprayType = "job",
        gang = playerData.job.name,
        gangGrade = playerData.job.grade.level,
        job = playerData.job.name,
        jobGrade = playerData.job.grade.level,
        jobConfig = jobCheck.jobConfig,
        timestamp = os.time(),
        isPublic = false
    }
end

-- Rate Limiting System (bleibt bestehend)
function GangPermissions:CheckRateLimit(source, citizenid, actionType)
    local currentTime = os.time()
    local key = citizenid .. '_' .. actionType
    
    if not self.rateLimitCache[key] then
        self.rateLimitCache[key] = {
            count = 0,
            firstAction = currentTime,
            lastAction = currentTime,
            blocked = false,
            blockedUntil = 0
        }
    end
    
    local rateData = self.rateLimitCache[key]
    
    -- Prüfe ob noch blockiert
    if rateData.blocked and currentTime < rateData.blockedUntil then
        local remainingTime = rateData.blockedUntil - currentTime
        return {
            allowed = false,
            reason = string.format("Rate-Limit aktiv noch %d Sekunden", remainingTime)
        }
    elseif rateData.blocked and currentTime >= rateData.blockedUntil then
        -- Blockierung aufheben
        rateData.blocked = false
        rateData.count = 0
        rateData.firstAction = currentTime
    end
    
    -- Prüfe Cooldown zwischen Aktionen
    local cooldown = actionType == 'create' and Config.RateLimit.sprayCreationCooldown or Config.RateLimit.sprayRemovalCooldown
    if (currentTime * 1000) - (rateData.lastAction * 1000) < cooldown then
        return {
            allowed = false,
            reason = string.format("Warte noch %.1f Sekunden", (cooldown - ((currentTime * 1000) - (rateData.lastAction * 1000))) / 1000)
        }
    end
    
    -- Reset Count nach einer Minute
    if currentTime - rateData.firstAction > 60 then
        rateData.count = 0
        rateData.firstAction = currentTime
    end
    
    -- Prüfe Aktionen pro Minute
    rateData.count = rateData.count + 1
    rateData.lastAction = currentTime
    
    if rateData.count > Config.RateLimit.maxActionsPerMinute then
        -- Temp-Ban verhängen
        rateData.blocked = true
        rateData.blockedUntil = currentTime + (Config.RateLimit.banDuration / 1000)
        
        -- Log in Database
        exports.oxmysql:insert('INSERT INTO spray_rate_limits (citizenid, action_type, action_count, blocked_until) VALUES (?, ?, ?, FROM_UNIXTIME(?)) ON DUPLICATE KEY UPDATE action_count = action_count + 1, blocked_until = FROM_UNIXTIME(?)', {
            citizenid,
            actionType,
            rateData.count,
            rateData.blockedUntil,
            rateData.blockedUntil
        })
        
        Debug:Log("PERMISSIONS", "Rate limit exceeded - temp ban issued", {
            citizenid = citizenid,
            actionType = actionType,
            count = rateData.count,
            banDuration = Config.RateLimit.banDuration / 1000
        }, "ERROR")
        
        return {
            allowed = false,
            reason = string.format("Zu viele Aktionen! Blockiert für %d Sekunden", Config.RateLimit.banDuration / 1000)
        }
    end
    
    return {allowed = true, remaining = Config.RateLimit.maxActionsPerMinute - rateData.count}
end

-- Permission Caching System (bleibt bestehend)
function GangPermissions:CachePermission(source, citizenid, result, customTimeout)
    local timeout = customTimeout or Config.Performance.cacheTimeout
    
    self.permissionCache[source] = {
        citizenid = citizenid,
        result = result,
        timestamp = GetGameTimer(),
        timeout = timeout
    }
end

function GangPermissions:GetCachedPermission(source, citizenid)
    local cached = self.permissionCache[source]
    
    if not cached then return nil end
    
    -- Prüfe Timeout
    if (GetGameTimer() - cached.timestamp) > cached.timeout then
        self.permissionCache[source] = nil
        return nil
    end
    
    -- Prüfe ob noch derselbe Spieler
    if cached.citizenid ~= citizenid then
        self.permissionCache[source] = nil
        return nil
    end
    
    return cached.result
end

-- Administrative Funktionen (bleiben bestehend)
function GangPermissions:IsPlayerAdmin(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    -- QB-Core Admin Check
    return QBCore.Functions.HasPermission(source, 'admin') or 
           QBCore.Functions.HasPermission(source, 'god')
end

function GangPermissions:HasValidGang(playerData)
    return playerData.gang and 
           playerData.gang.name ~= 'none' and 
           Config.Gangs.AllowedGangs[playerData.gang.name] ~= nil
end

-- Cache Cleanup (bleibt bestehend)
function GangPermissions:CleanupCache()
    local currentTime = GetGameTimer()
    local cleanedCount = 0
    
    for source, cached in pairs(self.permissionCache) do
        if (currentTime - cached.timestamp) > cached.timeout then
            self.permissionCache[source] = nil
            cleanedCount = cleanedCount + 1
        end
    end
    
    -- Rate Limit Cache cleanup
    local currentUnixTime = os.time()
    for key, rateData in pairs(self.rateLimitCache) do
        if not rateData.blocked and (currentUnixTime - rateData.lastAction) > 300 then -- 5 Minuten
            self.rateLimitCache[key] = nil
        end
    end
    
    if cleanedCount > 0 then
        Debug:Log("PERMISSIONS", "Permission cache cleaned", {cleanedEntries = cleanedCount}, "INFO")
    end
end

-- ✅ ERWEITERT: Statistiken abrufen
function GangPermissions:GetStatistics()
    local stats = table.copy(self.statistics)
    
    -- Berechne zusätzliche Metriken
    if stats.permissionChecks > 0 then
        stats.successRate = ((stats.permissionChecks - stats.deniedAttempts) / stats.permissionChecks) * 100
        stats.cacheHitRate = (stats.cacheHits / stats.permissionChecks) * 100
        stats.publicSprayRate = (stats.publicSpraysCreated / stats.permissionChecks) * 100
    else
        stats.successRate = 0
        stats.cacheHitRate = 0
        stats.publicSprayRate = 0
    end
    
    return stats
end

-- Event Handlers (erweitert)
RegisterNetEvent('spray:server:requestPermissionCheck', function()
    local src = source
    local canUse, reason, metadata = GangPermissions:CanUseSpray(src)
    
    TriggerClientEvent('spray:client:permissionResult', src, canUse, reason, metadata)
end)

-- ✅ NEU: Entferner Permission Check Event
RegisterNetEvent('spray:server:requestRemovalPermission', function(sprayId)
    local src = source
    local canRemove, reason, metadata = GangPermissions:CanRemoveSpray(src, sprayId)
    
    TriggerClientEvent('spray:client:removalPermissionResult', src, canRemove, reason, metadata, sprayId)
end)

-- Cleanup Timer (bleibt bestehend)
CreateThread(function()
    while true do
        Wait(60000) -- 1 Minute
        GangPermissions:CleanupCache()
    end
end)

-- Player Disconnect Cleanup (bleibt bestehend)
AddEventHandler('playerDropped', function(reason)
    local source = tonumber(source)
    if GangPermissions.permissionCache[source] then
        GangPermissions.permissionCache[source] = nil
    end
end)

Debug:Log("PERMISSIONS", "Gang permission handler initialized with public access support", nil, "SUCCESS")