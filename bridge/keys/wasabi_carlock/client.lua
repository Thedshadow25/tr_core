-- wasabi_carlock: keys by plate.
local keys = exports.wasabi_carlock
local bridge = {}

function bridge.hasKeys(vehicle, plate) return keys:HasKey(plate) end

return bridge
