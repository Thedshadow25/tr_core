local fuel = ...
local bridge = TR.bridge('fuel')

---@class TRFuel : TRFuelShared
---@cast fuel TRFuel

---The client controlling a car (fuel kept on the client can only be read and changed there).
---@param vehicle integer
---@return integer? src
local function owner(vehicle)
    local src = NetworkGetEntityOwner(vehicle)
    if src and src > 0 then return src end
end

---Yields while it asks the car's owner, for fuel scripts that keep fuel on the client.
---@param vehicle integer
---@return number? fuel nil if the car is gone or nobody controls it
function fuel.get(vehicle)
    if not DoesEntityExist(vehicle) then return end

    local amount = bridge.get(vehicle)
    if amount == nil then
        local src = owner(vehicle)
        if not src then return end
        amount = TR.callback.await('tr_core:fuel:get', src, NetworkGetNetworkIdFromEntity(vehicle))
    end

    return fuel.clamp(amount)
end

---@param vehicle integer
---@param amount number 0..100
---@return boolean done false if the car is gone or nobody controls it
function fuel.set(vehicle, amount)
    amount = fuel.clamp(amount)
    if not amount or not DoesEntityExist(vehicle) then return false end
    if bridge.set(vehicle, amount) then return true end

    local src = owner(vehicle)
    if not src then return false end
    TriggerClientEvent('tr_core:fuel:set', src, NetworkGetNetworkIdFromEntity(vehicle), amount)
    return true
end

---Takes up to `amount` fuel out of a car (a siphon, a leak).
---@param vehicle integer
---@param amount number
---@return number taken what was actually taken (less when the tank runs dry, 0 on failure)
function fuel.take(vehicle, amount)
    amount = fuel.clamp(amount)
    local current = fuel.get(vehicle)
    if not amount or not current then return 0.0 end

    local taken = math.min(amount, current)
    if taken <= 0 or not fuel.set(vehicle, current - taken) then return 0.0 end
    return taken
end

return fuel
