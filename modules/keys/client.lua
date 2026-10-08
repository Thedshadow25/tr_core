local keys = ...
local bridge = TR.bridge('keys')

---@class TRKeysClient : TRKeysShared
---@cast keys TRKeysClient

---@param vehicle integer
---@return boolean
function keys.hasKeys(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    return bridge.hasKeys(vehicle, keys.plate(vehicle)) == true
end

return keys
