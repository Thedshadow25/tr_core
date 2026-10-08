-- TR target options use the ox_target option format, so this bridge is a thin pass-through.
-- ox_target removes a resource's options automatically when that resource stops.
local ox = exports.ox_target

local bridge = {}

function bridge.addBoxZone(data) return ox:addBoxZone(data) end
function bridge.addSphereZone(data) return ox:addSphereZone(data) end
function bridge.addPolyZone(data) return ox:addPolyZone(data) end
function bridge.removeZone(id) ox:removeZone(id, true) end

function bridge.addModel(models, options) ox:addModel(models, options) end
function bridge.removeModel(models, names) ox:removeModel(models, names) end

function bridge.addEntity(netIds, options) ox:addEntity(netIds, options) end
function bridge.removeEntity(netIds, names) ox:removeEntity(netIds, names) end

function bridge.addLocalEntity(entities, options) ox:addLocalEntity(entities, options) end
function bridge.removeLocalEntity(entities, names) ox:removeLocalEntity(entities, names) end

function bridge.addGlobalPed(options) ox:addGlobalPed(options) end
function bridge.removeGlobalPed(names) ox:removeGlobalPed(names) end
function bridge.addGlobalVehicle(options) ox:addGlobalVehicle(options) end
function bridge.removeGlobalVehicle(names) ox:removeGlobalVehicle(names) end
function bridge.addGlobalObject(options) ox:addGlobalObject(options) end
function bridge.removeGlobalObject(names) ox:removeGlobalObject(names) end
function bridge.addGlobalPlayer(options) ox:addGlobalPlayer(options) end
function bridge.removeGlobalPlayer(names) ox:removeGlobalPlayer(names) end

return bridge
