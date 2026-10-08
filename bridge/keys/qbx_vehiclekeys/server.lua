-- qbx_vehiclekeys: keys belong to the vehicle entity (its session id), not the plate.
local keys = exports.qbx_vehiclekeys
local bridge = {}

function bridge.hasKeys(src, vehicle, plate) return keys:HasKeys(src, vehicle) end
function bridge.giveKeys(src, vehicle, plate) keys:GiveKeys(src, vehicle) end
function bridge.removeKeys(src, vehicle, plate) keys:RemoveKeys(src, vehicle) end

return bridge
