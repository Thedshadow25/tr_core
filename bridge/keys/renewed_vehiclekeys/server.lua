-- Renewed-Vehiclekeys: keys by plate.
local keys = exports['Renewed-Vehiclekeys']
local bridge = {}

function bridge.hasKeys(src, vehicle, plate) return keys:hasKey(src, plate) end
function bridge.giveKeys(src, vehicle, plate) keys:addKey(src, plate) end
function bridge.removeKeys(src, vehicle, plate) keys:removeKey(src, plate) end

return bridge
