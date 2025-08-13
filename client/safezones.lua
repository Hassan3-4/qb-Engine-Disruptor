local Config = Config

local function isInSafeZone(coords)
    if not Config.enableSafeZones then return false end
    for _, z in ipairs(Config.safeZones) do
        if #(coords - z.coords) <= (z.radius or 0.0) then
            return true
        end
    end
    return false
end

exports('IsInSafeZone', isInSafeZone)
