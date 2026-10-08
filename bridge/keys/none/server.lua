-- No vehicle keys script running: every player can start every car, so everyone "has keys".
local bridge = {}

function bridge.hasKeys(src, vehicle, plate) return true end
function bridge.giveKeys(src, vehicle, plate) end
function bridge.removeKeys(src, vehicle, plate) end

return bridge
