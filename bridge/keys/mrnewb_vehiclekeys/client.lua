-- MrNewbVehicleKeys: keys by plate.
local keys = exports.MrNewbVehicleKeys
local bridge = {}

function bridge.hasKeys(vehicle, plate) return keys:HasKeysByPlate(plate) end

return bridge
