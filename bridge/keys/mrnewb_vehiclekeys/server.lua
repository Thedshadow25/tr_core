-- MrNewbVehicleKeys: keys by plate.
local keys = exports.MrNewbVehicleKeys
local bridge = {}

function bridge.hasKeys(src, vehicle, plate) return keys:HasKeysByPlate(src, plate) end
function bridge.giveKeys(src, vehicle, plate) keys:GiveKeysByPlate(src, plate) end
function bridge.removeKeys(src, vehicle, plate) keys:RemoveKeysByPlate(src, plate) end

return bridge
