-- zyke_vehiclekeys: keys by plate. Its engine is driven by the vehicle's `engine` state bag, which is
-- also how its own hotwire starts a car without giving a key.
local keys = exports.zyke_vehiclekeys
local bridge = {}

function bridge.hasKeys(src, vehicle, plate) return keys:HasKey(src, plate) end
function bridge.giveKeys(src, vehicle, plate) keys:GiveKey(src, plate, true) end
function bridge.removeKeys(src, vehicle, plate) keys:RemoveKey(src, plate) end
function bridge.startEngine(src, vehicle, plate) Entity(vehicle).state:set('engine', true, true) end

return bridge
