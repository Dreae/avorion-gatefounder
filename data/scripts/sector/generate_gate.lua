package.path = package.path .. ";data/scripts/lib/?.lua"

include ("gate_util")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace PlayerGateGenerator
PlayerGateGenerator = {}

function PlayerGateGenerator.initialize(target_x, target_y, factionIndex)
    local x, y = Sector():getCoordinates()
    if onServer() then
        local dir = vec3(target_x - x, 0, target_y - y)
        normalize_ip(dir)

        local position = MatrixLookUp(dir, vec3(0, 1, 0))
        position.pos = dir * 2000

        make_gate(target_x, target_y, position, factionIndex)
    end

    terminate()
end
