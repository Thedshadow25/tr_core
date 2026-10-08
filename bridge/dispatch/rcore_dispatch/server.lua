-- rcore_dispatch: its sendAlert server event. It has no title, so the text is the title and details.
local _, shared = ...
local bridge = {}

function bridge.alert(alert)
    local details = shared.details(alert)

    TriggerEvent('rcore_dispatch:server:sendAlert', {
        code = alert.code,
        default_priority = alert.priority,
        coords = alert.coords,
        job = alert.jobs,
        text = details ~= '' and ('%s - %s'):format(alert.title, details) or alert.title,
        type = 'alerts',
        blip_time = alert.time * 60, -- seconds
        blip = {
            sprite = alert.blip.sprite,
            colour = alert.blip.color,
            scale = alert.blip.scale,
            text = shared.heading(alert),
            flashes = alert.blip.flash,
            radius = alert.blip.radius,
        },
    })
end

return bridge
