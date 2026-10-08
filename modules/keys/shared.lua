--[[
    Vehicle keys, independent of the keys script the server runs.

        server: TR.keys.hasKeys(src, vehicle)  TR.keys.giveKeys(src, vehicle)  TR.keys.removeKeys(src, vehicle)
        client: TR.keys.hasKeys(vehicle)

    Without a supported keys script the 'none' provider is used and hasKeys is always true.
]]

---@class TRKeysShared
local keys = {}

---Plate text without the padding GTA adds.
---@param vehicle integer
---@return string
function keys.plate(vehicle)
    return TR.utils.trim(GetVehicleNumberPlateText(vehicle) or '')
end

return keys
