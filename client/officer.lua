local QBCore = exports['qb-core']:GetCoreObject()
local Config = Config

local aiming = false
local aimVeh = 0
local aimNet = 0
local hint = ''

local function isModelIn(list, model)
    for _, name in ipairs(list) do if joaat(name) == model then return true end end
    return false
end

local function isNearPoliceVehicle()
    if not Config.requirePoliceVehicle then return true end
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local handle, veh = FindFirstVehicle()
    local success
    repeat
        if veh ~= 0 and isModelIn(Config.policeVehicleModels, GetEntityModel(veh)) then
            if #(pos - GetEntityCoords(veh)) <= Config.nearPoliceVehicleMeters then
                EndFindVehicle(handle); return true
            end
        end
        success, veh = FindNextVehicle(handle)
    until not success
    EndFindVehicle(handle)
    return false
end

local function findNearestVehicle(maxDist)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local nearest, nearestDist = 0, maxDist + 0.01
    local myVeh = GetVehiclePedIsIn(ped, false)
    local handle, veh = FindFirstVehicle()
    local success
    repeat
        if veh ~= 0 and IsEntityAVehicle(veh) then
            local d = #(pos - GetEntityCoords(veh))
            if d <= maxDist and d < nearestDist then
                -- skip your own vehicle as a target
                if veh ~= myVeh then
                    -- optionally avoid targeting police vehicles
                    if not isModelIn(Config.policeVehicleModels, GetEntityModel(veh)) then
                        nearest = veh
                        nearestDist = d
                    end
                end
            end
        end
        success, veh = FindNextVehicle(handle)
    until not success
    EndFindVehicle(handle)
    return nearest, nearest ~= 0 and GetEntityCoords(nearest) or pos
end

local function canUseNow()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 and not isModelIn(Config.policeVehicleModels, GetEntityModel(veh)) and Config.requirePoliceVehicle then
        return false, 'BLOCKED: Not in/near police vehicle'
    end
    if not isNearPoliceVehicle() then return false, 'BLOCKED: Not in/near police vehicle' end
    if exports['Vehicle-stop']:IsInSafeZone(GetEntityCoords(ped)) then
        return false, 'BLOCKED: Safe Zone'
    end
    return true, ''
end

local function drawOfficerHint(status, plate, dist, cooldownLeft)
    if not Config.showOfficerHints then return end
    local color = {255,0,0}
    local text = status
    if status == 'READY' then
        color = {0,255,0}
        text = ('LOCK READY — %s — %0.1fm'):format(plate or '????', dist or 0.0)
    end
    Disruptor_DrawText2D(0.5, 0.80, text, 0.4, color[1], color[2], color[3], 220)
end

-- Arm and fire usage
local function tryFire()
    if aimVeh == 0 then return end
    -- progress/hold
    QBCore.Functions.Progressbar('disruptor_arm', 'Arming disruptor…', Config.armHoldMs, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        TriggerServerEvent('vehdisruptor:sv:attempt', { netId = aimNet })
    end, function()
        -- cancel noop
    end)
end

-- Keybind: Fire lock while aiming (FiveM key mapping)
RegisterCommand('vehdisruptor_lock', function()
    if aiming then
        tryFire()
    end
end, false)
RegisterKeyMapping('vehdisruptor_lock', 'Vehicle Disruptor: Lock nearest vehicle', 'keyboard', 'J')

RegisterNetEvent('vehdisruptor:cl:fail', function(msg)
    QBCore.Functions.Notify(msg or 'Failed', 'error')
end)

RegisterNetEvent('vehdisruptor:cl:success', function(plate, refreshed)
    QBCore.Functions.Notify(('Locked on %s. Disruption active (30s).'):format(plate or 'vehicle'), refreshed and 'primary' or 'success')
end)

-- Pre-use cooldown feedback
RegisterNetEvent('vehdisruptor:cl:cooldown', function(seconds)
    if type(seconds) ~= 'number' then seconds = 0 end
    QBCore.Functions.Notify(('Cooldown %ds'):format(math.floor(seconds)), 'error')
end)

-- Usable item
RegisterNetEvent('vehdisruptor:cl:use', function()
    aiming = not aiming
    if aiming then QBCore.Functions.Notify('Disruptor armed. Press J to lock the nearest vehicle within range.', 'primary') end
end)

CreateThread(function()
    while true do
        local sleep = 500
        if aiming then
            sleep = 0
        local veh, hitPos = findNearestVehicle(Config.rangeMeters)
            aimVeh = veh
            aimNet = veh ~= 0 and NetworkGetNetworkIdFromEntity(veh) or 0
            if veh ~= 0 then
                local plate = QBCore.Functions.GetPlate(veh)
                local dist = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(veh))
                local ok, reason = canUseNow()
                if ok and dist <= Config.rangeMeters + 0.01 then
                    Disruptor_DrawBracketAroundEntity(veh, {0,255,0})
                    drawOfficerHint('READY', plate, dist)
                else
                    Disruptor_DrawBracketAroundEntity(veh, {255,0,0})
                    drawOfficerHint(reason or 'BLOCKED', plate, dist)
                end
            end
            if IsControlJustReleased(0, 177) then -- backspace cancel
                aiming = false
                QBCore.Functions.Notify('Disruptor disarmed.', 'primary')
            end
        end
        Wait(sleep)
    end
end)
