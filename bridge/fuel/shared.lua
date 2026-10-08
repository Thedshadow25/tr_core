-- Helpers shared by every fuel bridge (loaded once per resource and passed to the provider file).
-- Fuel is 0..100 everywhere. Provider files return { get = fn(vehicle), set = fn(vehicle, fuel) }:
--   client: get reads the car's fuel, set changes it (sticks only on the client that controls the car).
--   server: get returns nil and set returns false when only the controlling client can do it; the
--           module then asks that client.

---@class TRFuelShared
local shared = {}

---LegacyFuel style scripts: client exports GetFuel / SetFuel that keep the fuel in a decorator. The
---decorator syncs from the car's owner, so the server can neither read nor write it.
---@param resource string
function shared.exportsClient(resource)
    local script = exports[resource]
    return {
        get = function(vehicle) return script:GetFuel(vehicle) end,
        set = function(vehicle, fuel) script:SetFuel(vehicle, fuel) end,
    }
end

function shared.exportsServer()
    return {
        get = function() return nil end,
        set = function() return false end,
    }
end

---Scripts that keep the fuel in the car's `fuel` state bag (ox_fuel). The server owns the state bag;
---the script's client applies it to the car. `default` is used before the script has set it.
---@param default? number
function shared.stateClient(default)
    return {
        get = function(vehicle) return Entity(vehicle).state.fuel or default or GetVehicleFuelLevel(vehicle) end,
        set = function(vehicle, fuel)
            SetVehicleFuelLevel(vehicle, fuel + 0.0)
            Entity(vehicle).state:set('fuel', fuel, true)
        end,
    }
end

---@param default? number
function shared.stateServer(default)
    return {
        get = function(vehicle) return Entity(vehicle).state.fuel or default end,
        set = function(vehicle, fuel)
            Entity(vehicle).state:set('fuel', fuel, true)
            return true
        end,
    }
end

return shared
