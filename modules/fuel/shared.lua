--[[
    Vehicle fuel (0..100), independent of the fuel script the server runs.

        server: TR.fuel.get(vehicle)  TR.fuel.set(vehicle, fuel)  TR.fuel.take(vehicle, amount)
        client: TR.fuel.get(vehicle)  TR.fuel.set(vehicle, fuel)

    Prefer the server functions. Scripts that keep fuel on the client (LegacyFuel and its forks) can
    only be changed by the client controlling the car, so the server asks that client.
    Without a supported fuel script the 'none' provider tracks fuel in the car's `fuel` state bag.
]]

---@class TRFuelShared
local fuel = {}

---@param amount any
---@return number?
function fuel.clamp(amount)
    amount = tonumber(amount)
    if not amount or amount ~= amount then return end
    return math.max(0.0, math.min(100.0, amount + 0.0))
end

return fuel
