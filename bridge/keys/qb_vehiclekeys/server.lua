-- qb-vehiclekeys: keys by plate.
local keys = exports['qb-vehiclekeys']
local bridge = {}

function bridge.hasKeys(src, vehicle, plate) return keys:HasKeys(src, plate) end
function bridge.giveKeys(src, vehicle, plate) keys:GiveKeys(src, plate) end
function bridge.removeKeys(src, vehicle, plate) keys:RemoveKeys(src, plate) end

return bridge
