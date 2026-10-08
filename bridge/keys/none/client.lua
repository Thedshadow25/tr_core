-- No vehicle keys script running: every player can start every car, so everyone "has keys".
local bridge = {}

function bridge.hasKeys(vehicle, plate) return true end

return bridge
