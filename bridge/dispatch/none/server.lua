-- No dispatch script running: on-duty players with the alert's jobs get a notification and a blip
-- (tr_core's client shows them).
local _, shared = ...
local bridge = {}

function bridge.alert(alert)
    local payload = {
        coords = alert.coords,
        title = shared.heading(alert),
        message = shared.details(alert),
        time = alert.time,
        blip = alert.blip,
    }
    for _, src in ipairs(shared.players(alert.jobs, true)) do
        TriggerClientEvent('tr_core:dispatch', src, payload)
    end
end

return bridge
