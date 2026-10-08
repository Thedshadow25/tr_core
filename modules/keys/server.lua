local keys = ...
local bridge = TR.bridge('keys')

---@class TRKeys : TRKeysShared
---@cast keys TRKeys

---@param src integer
---@param vehicle integer
---@return boolean
function keys.hasKeys(src, vehicle)
    if not DoesEntityExist(vehicle) then return false end
    return bridge.hasKeys(src, vehicle, keys.plate(vehicle)) == true
end

---@param src integer
---@param vehicle integer
function keys.giveKeys(src, vehicle)
    if not DoesEntityExist(vehicle) then return end
    bridge.giveKeys(src, vehicle, keys.plate(vehicle))
end

---@param src integer
---@param vehicle integer
function keys.removeKeys(src, vehicle)
    if not DoesEntityExist(vehicle) then return end
    bridge.removeKeys(src, vehicle, keys.plate(vehicle))
end

---Runs a car's engine for a player without giving keys (after a hotwire), where the keys script
---supports that. Elsewhere the keys script keeps the engine off for players without keys.
---@param src integer
---@param vehicle integer
---@return boolean supported
function keys.startEngine(src, vehicle)
    if not DoesEntityExist(vehicle) or not bridge.startEngine then return false end
    bridge.startEngine(src, vehicle, keys.plate(vehicle))
    return true
end

return keys
