--[[
    Frequently used local player values, refreshed by tr_core every 100 ms
    so scripts do not call the same natives every frame.

        if TR.cache.vehicle then ... end
        TR.cache.on('vehicle', function(vehicle, previous) end)

    Values are false when not applicable (e.g. vehicle while on foot).
]]

---@class TRCache
---@field playerId integer
---@field serverId integer
---@field ped integer
---@field vehicle integer | false
---@field seat integer | false -1 is the driver
---@field weapon integer | false
local cache = {}

local listeners = {} ---@type table<string, fun(value: any, previous: any)[]>

local function currentSeat(ped, vehicle)
    for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        if GetPedInVehicleSeat(vehicle, seat) == ped then return seat end
    end
    return false
end

---Reads every cached value from natives. Used by tr_core to detect changes.
---@return table<string, any>
function cache.snapshot()
    local playerId = PlayerId()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    local armed, weapon = GetCurrentPedWeapon(ped, true)

    vehicle = vehicle ~= 0 and vehicle or false

    return {
        playerId = playerId,
        serverId = GetPlayerServerId(playerId),
        ped = ped,
        vehicle = vehicle,
        seat = vehicle and currentSeat(ped, vehicle) or false,
        weapon = armed and weapon or false,
    }
end

---Runs `cb(value, previous)` whenever a cached value changes.
---@param key 'ped' | 'vehicle' | 'seat' | 'weapon' | 'playerId' | 'serverId'
---@param cb fun(value: any, previous: any)
function cache.on(key, cb)
    listeners[key] = listeners[key] or {}
    table.insert(listeners[key], cb)
end

for key, value in pairs(cache.snapshot()) do cache[key] = value end

AddEventHandler('tr:cache', function(key, value)
    local previous = cache[key]
    if previous == value then return end

    cache[key] = value

    local list = listeners[key]
    if not list then return end

    for i = 1, #list do
        local ok, err = pcall(list[i], value, previous)
        if not ok then TR.log.error('cache listener for %s failed: %s', key, err) end
    end
end)

return cache
