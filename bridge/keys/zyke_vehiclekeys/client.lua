-- zyke_vehiclekeys: keys by plate.
local keys = exports.zyke_vehiclekeys
local bridge = {}

function bridge.hasKeys(vehicle, plate) return keys:HasKey(plate) end

return bridge
