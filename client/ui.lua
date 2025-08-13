local Config = Config

function Disruptor_DrawText2D(x, y, text, scale, r, g, b, a)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(scale, scale)
    SetTextColour(r or 255, g or 255, b or 255, a or 215)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

local function drawRect(x, y, w, h, r, g, b, a)
    DrawRect(x, y, w, h, r, g, b, a)
end

function Disruptor_DrawBracketAroundEntity(ent, color)
    if ent == 0 then return end
    local min, max = GetModelDimensions(GetEntityModel(ent))
    local corners = {
        vector3(min.x, min.y, min.z),
        vector3(min.x, max.y, min.z),
        vector3(max.x, min.y, min.z),
        vector3(max.x, max.y, min.z),
        vector3(min.x, min.y, max.z),
        vector3(min.x, max.y, max.z),
        vector3(max.x, min.y, max.z),
        vector3(max.x, max.y, max.z)
    }
    local screenPts = {}
    for _, off in ipairs(corners) do
        local wpos = GetOffsetFromEntityInWorldCoords(ent, off.x, off.y, off.z)
        local onScreen, sx, sy = GetScreenCoordFromWorldCoord(wpos.x, wpos.y, wpos.z)
        if onScreen then table.insert(screenPts, {sx, sy}) end
    end
    if #screenPts == 0 then return end
    local minX, maxX, minY, maxY = 1, 0, 1, 0
    for _, p in ipairs(screenPts) do
        minX = math.min(minX, p[1]); maxX = math.max(maxX, p[1])
        minY = math.min(minY, p[2]); maxY = math.max(maxY, p[2])
    end
    local w = maxX - minX
    local h = maxY - minY
    local thickness = 0.002
    local len = 0.02
    local r, g, b = table.unpack(color or {0,255,0})
    -- corners
    drawRect(minX + len/2, minY + thickness/2, len, thickness, r,g,b,200)
    drawRect(minX + thickness/2, minY + len/2, thickness, len, r,g,b,200)

    drawRect(maxX - len/2, minY + thickness/2, len, thickness, r,g,b,200)
    drawRect(maxX - thickness/2, minY + len/2, thickness, len, r,g,b,200)

    drawRect(minX + len/2, maxY - thickness/2, len, thickness, r,g,b,200)
    drawRect(minX + thickness/2, maxY - len/2, thickness, len, r,g,b,200)

    drawRect(maxX - len/2, maxY - thickness/2, len, thickness, r,g,b,200)
    drawRect(maxX - thickness/2, maxY - len/2, thickness, len, r,g,b,200)
end

