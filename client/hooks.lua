local Config = Config
local QBCore = exports['qb-core']:GetCoreObject()

-- Exported guard for qb-vehiclekeys to call client-side (optional); primary export lives server-side.
exports('IsVehicleLockedClient', function(veh)
    local state = Entity(veh).state
    local endsAt = state and state.DisruptorEndsAt or 0
    local noStart = state and state.DisruptorNoStart or false
    local remaining = math.max(0, math.floor((endsAt - GetGameTimer())/1000))
    return noStart and remaining > 0, remaining
end)

-- Fallback guard: re-stall engine if some script turns it on during lock
CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                local st = Entity(veh).state
                if st and st.DisruptorNoStart then
                    sleep = 100
                    if GetIsVehicleEngineRunning(veh) then
                        SetVehicleEngineOn(veh, false, false, true)
                        if Config.showCivilianNotify then
                            QBCore.Functions.Notify(('Engine temporarily locked (%ds)'):format(math.max(0, math.floor((st.DisruptorEndsAt - GetGameTimer())/1000))), 'error')
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
