local QBCore = exports['qb-core']:GetCoreObject()
local Config = Config


local function kmh(speed)
    return speed * 3.6
end

local function ms(speedKmh)
    return speedKmh / 3.6
end

local function rampSpeedLimit(veh, startKmh)
    local targetProfile
    for _, prof in ipairs(Config.decelProfiles) do
        if startKmh >= prof.minSpeed then
            targetProfile = prof; break
        end
    end
    if not targetProfile then targetProfile = Config.decelProfiles[#Config.decelProfiles] end

    local duration = targetProfile.duration
    local startSpeed = ms(startKmh)
    local targetSpeed = ms(targetProfile.targetSpeed)
    local startTime = GetGameTimer()

    local sfxPlayed = false
    while GetGameTimer() - startTime < duration * 1000 do
        if not sfxPlayed and Config.playSfx then
            sfxPlayed = true
            -- simple frontend buzz
            PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        end
        local t = (GetGameTimer() - startTime) / (duration * 1000)
        local cap = startSpeed + (targetSpeed - startSpeed) * t
        local current = GetEntitySpeed(veh)
        if current > cap then
            -- gently limit by disabling throttle and reducing torque
            DisableControlAction(0, 71, true) -- W
            SetVehicleCheatPowerIncrease(veh, -0.5)
        end
        Wait(0)
    end

    -- Stall engine once more at end of ramp
    SetVehicleEngineOn(veh, false, true, true)
end

local function drawHudTimer(endsAt)
    if not Config.showHudTimer then return end
    local now = (type(GetNetworkTimeAccurate) == 'function' and GetNetworkTimeAccurate())
        or (type(GetNetworkTime) == 'function' and GetNetworkTime())
        or GetGameTimer()
    local remaining = math.max(0, math.floor((endsAt - now)/1000))
    Disruptor_DrawText2D(0.5, 0.85, ('Engine lock: %ds'):format(remaining), 0.4, 255,255,255,200)
end

RegisterNetEvent('vehdisruptor:cl:apply', function(netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 then return end

    local st = Entity(veh).state
    if not st or not st.DisruptorNoStart then return end

    local driver = GetPedInVehicleSeat(veh, -1)
    if driver ~= 0 then
        if Config.showCivilianNotify then
            QBCore.Functions.Notify('Police device detected: Your engine is being shut down and locked for 30 seconds.', 'error')
        end
    end

    local startKmh = kmh(GetEntitySpeed(veh))
    rampSpeedLimit(veh, startKmh)

    -- Enforce engine off during lock window
    local nowBase = (type(GetNetworkTimeAccurate) == 'function' and GetNetworkTimeAccurate())
        or (type(GetNetworkTime) == 'function' and GetNetworkTime())
        or GetGameTimer()
    local endsAt = st.DisruptorEndsAt or (nowBase + 30000)
    local ped = PlayerPedId()
    while true do
        local now = (type(GetNetworkTimeAccurate) == 'function' and GetNetworkTimeAccurate())
            or (type(GetNetworkTime) == 'function' and GetNetworkTime())
            or GetGameTimer()
        if now >= endsAt then break end
        if GetIsVehicleEngineRunning(veh) then
            SetVehicleEngineOn(veh, false, false, true)
        end
        -- prevent throttle
        DisableControlAction(0, 71, true)
        Wait(200)
        st = Entity(veh).state
        if not (st and st.DisruptorNoStart) then break end
    end
    -- small hint after lock ends
    if Config.showCivilianNotify then
        QBCore.Functions.Notify('Engine lock ended. Press G to start your engine.', 'success')
    end
end)

-- Tiny HUD tick for drivers while locked
CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                local st = Entity(veh).state
                if st and st.DisruptorNoStart and (st.DisruptorEndsAt or 0) > 0 then
                    sleep = 0
                    drawHudTimer(st.DisruptorEndsAt)
                end
            end
        end
        Wait(sleep)
    end
end)
