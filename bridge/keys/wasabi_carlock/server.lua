-- wasabi_carlock: keys by plate.
local keys = exports.wasabi_carlock
local bridge = {}

function bridge.hasKeys(src, vehicle, plate) return keys:HasKey(src, plate) end
function bridge.giveKeys(src, vehicle, plate) keys:GiveKey(src, plate) end
function bridge.removeKeys(src, vehicle, plate) keys:RemoveKey(src, plate) end

return bridge
