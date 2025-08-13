local QBCore = exports['qb-core']:GetCoreObject()
local Config = Config

-- State
local activeEffects = {}
local officerCooldowns = {}
local perTargetCooldowns = {}
local enabled = true

-- Utils
local function nowMs()
    if type(GetNetworkTimeAccurate) == 'function' then
        return GetNetworkTimeAccurate()
    elseif type(GetNetworkTime) == 'function' then
        return GetNetworkTime()
    else
        return GetGameTimer()
    end
end

local function secs(n) return n * 1000 end

local function isJobAllowed(jobName)
    return Config.allowedJobs[jobName] == true
end

local function isEmergencyJob(job)
    return Config.excludeJobs[job] == true
end

local function getNetId(ent)
    if ent and ent ~= 0 then return NetworkGetNetworkIdFromEntity(ent) end
end

local function withinRange(a, b, range)
    return #(a - b) <= range
end

local function isModelIn(list, model)
    for _, name in ipairs(list) do
        if joaat(name) == model then return true end
    end
    return false
end

local function isVehExcludedByClass(veh)
    -- Server-safe vehicle class detection using model hash
    local model = GetEntityModel(veh)
    if not model or model == 0 then return false end
    local class = nil
    if type(GetVehicleClassFromName) == 'function' then
        class = GetVehicleClassFromName(model)
    end
    if class == nil then return false end
    return Config.excludeClasses[class] == true
end

-- Safe zone check (server authority)
local function isInAnySafeZone(coords)
    if not Config.enableSafeZones then return false end
    for _, z in ipairs(Config.safeZones) do
        if #(coords - z.coords) <= (z.radius or 0.0) then
            return true
        end
    end
    return false
end

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for netId, _ in pairs(activeEffects) do
        local ent = NetworkGetEntityFromNetworkId(netId)
        if ent ~= 0 then
            Entity(ent).state:set('DisruptorActive', false, true)
            Entity(ent).state:set('DisruptorNoStart', false, true)
            Entity(ent).state:set('DisruptorEndsAt', 0, true)
        end
    end
    activeEffects = {}
end)

    -- Independent expiry manager: clears each vehicle when its own timer elapses
    CreateThread(function()
        while true do
            local now = nowMs()
            for netId, eff in pairs(activeEffects) do
                if eff and eff.endsAt and now >= eff.endsAt then
                    local e = NetworkGetEntityFromNetworkId(netId)
                    if e ~= 0 then
                        local st = Entity(e).state
                        st:set('DisruptorNoStart', false, true)
                        st:set('DisruptorActive', false, true)
                        st:set('DisruptorEndsAt', 0, true)
                    end
                    activeEffects[netId] = nil
                    perTargetCooldowns[netId] = nowMs() + secs(Config.perTargetCooldownSeconds)
                end
            end
            Wait(200)
        end
    end)

-- Admin toggle
QBCore.Commands.Add('disruptor_toggle', 'Toggle Engine Disruptor', {}, false, function(src)
    enabled = not enabled
    TriggerClientEvent('QBCore:Notify', -1, ('Engine Disruptor %s'):format(enabled and 'ENABLED' or 'DISABLED'), enabled and 'success' or 'error')
end, 'admin')

-- Exported check for qb-vehiclekeys
exports('IsVehicleLockedByDisruptor', function(veh)
    if not veh or veh == 0 then return false, 0 end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local eff = activeEffects[netId]
    if not eff then return false, 0 end
    local remaining = math.max(0, math.floor((eff.endsAt - nowMs()) / 1000))
    return remaining > 0, remaining
end)

-- Helper to validate police vehicle proximity
-- Server-safe: only allow if the officer is inside a police vehicle (no scanning nearby vehicles server-side)
local function isInPoliceVehicle(ped)
    if not Config.requirePoliceVehicle then return true end
    local inVeh = GetVehiclePedIsIn(ped, false)
    if inVeh ~= 0 then
        local model = GetEntityModel(inVeh)
        if isModelIn(Config.policeVehicleModels, model) then return true end
    end
    return false
end

-- Server validation and apply
RegisterNetEvent('vehdisruptor:sv:attempt', function(data)
    local src = source
    if not enabled or not Config.enabled then
        TriggerClientEvent('vehdisruptor:cl:fail', src, 'BLOCKED: Disabled')
        return
    end

    local officer = QBCore.Functions.GetPlayer(src)
    if not officer then return end
    local job = officer.PlayerData.job and officer.PlayerData.job.name or 'unemployed'
    if not isJobAllowed(job) then
        TriggerClientEvent('vehdisruptor:cl:fail', src, 'BLOCKED: Not police')
        return
    end

    if officerCooldowns[src] and officerCooldowns[src] > nowMs() then
        local left = math.floor((officerCooldowns[src] - nowMs())/1000)
        TriggerClientEvent('vehdisruptor:cl:fail', src, ('BLOCKED: Cooldown %ds'):format(left))
        return
    end

    local netId = data and data.netId
    if not netId then
        TriggerClientEvent('vehdisruptor:cl:fail', src, 'BLOCKED: No target')
        return
    end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then
        TriggerClientEvent('vehdisruptor:cl:fail', src, 'BLOCKED: Invalid vehicle')
        return
    end

    -- officer context: in/near police vehicle
    local ped = GetPlayerPed(src)
    if Config.requirePoliceVehicle then
        if not isInPoliceVehicle(ped) then
            TriggerClientEvent('vehdisruptor:cl:fail', src, 'BLOCKED: Not in a police vehicle')
            return
        end
    end

    -- distance check
    local opos = GetEntityCoords(ped)
    local tpos = GetEntityCoords(veh)
    if not withinRange(opos, tpos, Config.rangeMeters + 0.01) then
        TriggerClientEvent('vehdisruptor:cl:fail', src, 'BLOCKED: Out of range')
        return
    end

    -- siren requirement
    if Config.requireSirenOn then
        local vehCtx = GetVehiclePedIsIn(ped, false)
        if vehCtx == 0 or not IsVehicleSirenOn(vehCtx) then
            TriggerClientEvent('vehdisruptor:cl:fail', src, 'BLOCKED: Siren required')
            return
        end
    end

    -- safezones: officer OR target
    if isInAnySafeZone(opos) or isInAnySafeZone(tpos) then
        TriggerClientEvent('vehdisruptor:cl:fail', src, 'BLOCKED: Safe Zone')
        return
    end

    -- exclusions by model/class
    local model = GetEntityModel(veh)
    if isModelIn(Config.modelBlacklist, model) then
        TriggerClientEvent('vehdisruptor:cl:fail', src, 'BLOCKED: Excluded model')
        return
    end

    if isVehExcludedByClass(veh) then
        TriggerClientEvent('vehdisruptor:cl:fail', src, 'BLOCKED: Excluded class')
        return
    end

    -- NPC exclusion
    if Config.excludeNPC then
        local driver = GetPedInVehicleSeat(veh, -1)
        if driver ~= 0 and not IsPedAPlayer(driver) then
            TriggerClientEvent('vehdisruptor:cl:fail', src, 'BLOCKED: NPC vehicle')
            return
        end
    end

    -- Min target speed
    if Config.minTargetSpeedKmh and Config.minTargetSpeedKmh > 0 then
        local speedKmh = GetEntitySpeed(veh) * 3.6
        if speedKmh < Config.minTargetSpeedKmh then
            TriggerClientEvent('vehdisruptor:cl:fail', src, 'BLOCKED: Target too slow')
            return
        end
    end

    -- Exclude by driver job (police/ems/fire)
    local driver = GetPedInVehicleSeat(veh, -1)
    if driver ~= 0 and IsPedAPlayer(driver) then
        for _, pid in ipairs(GetPlayers()) do
            local ped = GetPlayerPed(pid)
            if ped == driver then
                local p = QBCore.Functions.GetPlayer(tonumber(pid))
                if p then
                    local djob = p.PlayerData.job and p.PlayerData.job.name
                    if djob and isEmergencyJob(djob) then
                        TriggerClientEvent('vehdisruptor:cl:fail', src, 'BLOCKED: Excluded job')
                        return
                    end
                end
                break
            end
        end
    end

    -- uniqueness check removed: client now selects the nearest vehicle explicitly

    -- per-target cooldown
    if perTargetCooldowns[netId] and perTargetCooldowns[netId] > nowMs() then
        TriggerClientEvent('vehdisruptor:cl:fail', src, 'BLOCKED: Target on cooldown')
        return
    end

    -- stacking/refresh
    local existing = activeEffects[netId]
    if existing then
        if Config.allowRefresh and (nowMs() - (existing.lastRefreshed or existing.startedAt)) <= secs(Config.refreshWindowSeconds) and (existing.refreshes or 0) < Config.refreshMaxCount then
            existing.endsAt = nowMs() + secs(Config.lockSeconds)
            existing.lastRefreshed = nowMs()
            existing.refreshes = (existing.refreshes or 0) + 1
            Entity(veh).state:set('DisruptorEndsAt', existing.endsAt, true)
            local plate = (type(GetVehicleNumberPlateText) == 'function' and GetVehicleNumberPlateText(veh)) or 'vehicle'
            TriggerClientEvent('vehdisruptor:cl:success', src, plate, true)
            return
        else
            TriggerClientEvent('vehdisruptor:cl:fail', src, 'BLOCKED: Already disrupted')
            return
        end
    end

    -- activate effect
    local endsAt = nowMs() + secs(Config.lockSeconds)
    activeEffects[netId] = {
        startedAt = nowMs(),
        endsAt = endsAt,
        lastOfficer = src,
    plateCache = (type(GetVehicleNumberPlateText) == 'function' and GetVehicleNumberPlateText(veh)) or 'vehicle',
        refreshes = 0,
    }

    -- set statebag
    local entState = Entity(veh).state
    entState:set('DisruptorActive', true, true)
    entState:set('DisruptorEndsAt', endsAt, true)
    entState:set('DisruptorIssuedBy', src, true)
    entState:set('DisruptorNoStart', true, true)

    -- cooldowns start on success
    officerCooldowns[src] = nowMs() + secs(Config.officerCooldownSeconds)

    -- tell occupants/nearby clients to apply decel and stall
    TriggerClientEvent('vehdisruptor:cl:apply', -1, netId)
    TriggerClientEvent('vehdisruptor:cl:success', src, activeEffects[netId].plateCache, false)
end)

-- Housekeeping if vehicle deletes
AddEventHandler('entityRemoved', function(entity)
    if DoesEntityExist(entity) and GetEntityType(entity) == 2 then
        local netId = NetworkGetNetworkIdFromEntity(entity)
        activeEffects[netId] = nil
        perTargetCooldowns[netId] = nil
    end
end)

-- Usable item registration
QBCore.Functions.CreateUseableItem(Config.itemName, function(source, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Officer job check early feedback
    local job = Player.PlayerData.job and Player.PlayerData.job.name or 'unemployed'
    if not isJobAllowed(job) then
        TriggerClientEvent('vehdisruptor:cl:fail', src, 'BLOCKED: Not police')
        return
    end

    -- Pre-use cooldown gating: show remaining and do not arm
    if officerCooldowns[src] and officerCooldowns[src] > nowMs() then
        local left = math.max(0, math.floor((officerCooldowns[src] - nowMs()) / 1000))
        TriggerClientEvent('vehdisruptor:cl:cooldown', src, left)
        return
    end

    TriggerClientEvent('vehdisruptor:cl:use', src)
end)
