-- qb-vehiclekeys: keys by plate.
local keys = exports['qb-vehiclekeys']
local bridge = {}

function bridge.hasKeys(vehicle, plate) return keys:HasKeys(plate) end

return bridge
