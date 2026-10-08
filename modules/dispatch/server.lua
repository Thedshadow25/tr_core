---@class TRDispatchBlip
---@field sprite? integer default 161
---@field color? integer default 1 (red)
---@field scale? number default 1.0
---@field radius? number metres: also shows an area this big around the spot (default 0, none)
---@field flash? boolean default: high priority alerts flash

---@class TRDispatchAlert
---@field coords vector3 where it happened
---@field title string short, e.g. 'Suspicious network activity'
---@field message? string the details
---@field code? string e.g. '10-90'
---@field name? string the kind of alert, e.g. 'tr_fraud_atm' (dispatch scripts that sort or mute alerts by kind)
---@field jobs? string | string[] job names that get it (default 'police')
---@field priority? 'low' | 'medium' | 'high' default 'medium'
---@field time? number minutes it stays on the map (default 5)
---@field street? string where, in words; asked from `source`'s game when left out
---@field source? integer the player it is about
---@field blip? TRDispatchBlip

---@class TRDispatch
local dispatch = {}

local bridge
local priorities = { low = true, medium = true, high = true }

---A street name from a player's game. Only what street names are made of, so a modified client
---can't put markup into another script's dispatch UI.
---@return string
local function cleanStreet(street)
    if type(street) ~= 'string' then return '' end
    return (street:gsub("[^%w %-%.,'/&]", ''):sub(1, 64))
end

---@param alert TRDispatchAlert
local function normalize(alert)
    local coords = type(alert) == 'table' and alert.coords
    assert(coords and tonumber(coords.x) and tonumber(coords.y), 'TR.dispatch.alert needs coords')
    assert(type(alert.title) == 'string' and alert.title ~= '', 'TR.dispatch.alert needs a title')

    local blip = alert.blip or {}
    local priority = priorities[alert.priority] and alert.priority or 'medium'
    local jobs = alert.jobs or 'police'

    return {
        coords = vector3(coords.x + 0.0, coords.y + 0.0, (tonumber(coords.z) or 0) + 0.0),
        title = alert.title,
        message = alert.message or '',
        code = alert.code or '',
        name = alert.name or 'tr_alert',
        jobs = type(jobs) == 'table' and jobs or { jobs },
        priority = priority,
        time = tonumber(alert.time) or 5,
        street = alert.street,
        source = alert.source,
        blip = {
            sprite = blip.sprite or 161,
            color = blip.color or 1,
            scale = blip.scale or 1.0,
            radius = blip.radius or 0,
            flash = blip.flash == nil and priority == 'high' or blip.flash == true,
        },
    }
end

---Alerts the police (or the alert's jobs) through the server's dispatch script. Without one, on-duty
---players with those jobs get a notification and a blip. Returns right away: the street name is
---asked from the player's game first, when the alert has a `source` and no `street`.
---@param alert TRDispatchAlert
function dispatch.alert(alert)
    alert = normalize(alert)
    bridge = bridge or TR.bridge('dispatch')

    CreateThread(function()
        if not alert.street and alert.source then
            alert.street = cleanStreet(TR.callback.await('tr_core:dispatch:street', alert.source, alert.coords))
        end
        alert.street = alert.street or ''

        local ok, err = pcall(bridge.alert, alert)
        if not ok then TR.log.error('dispatch alert through %s failed: %s', TR.system('dispatch'), err) end
    end)
end

return dispatch
