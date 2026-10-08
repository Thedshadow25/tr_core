-- Renewed-Vehiclekeys: keys by plate.
local keys = exports['Renewed-Vehiclekeys']
local bridge = {}

function bridge.hasKeys(vehicle, plate) return keys:hasKey(plate) end

return bridge
