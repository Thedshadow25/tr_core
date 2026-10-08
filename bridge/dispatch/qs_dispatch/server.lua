-- qs-dispatch: its CreateDispatchCall server event.
local _, shared = ...
local bridge = {}

function bridge.alert(alert)
    local heading, details = shared.heading(alert), shared.details(alert)

    TriggerEvent('qs-dispatch:server:CreateDispatchCall', {
        job = alert.jobs,
        callLocation = alert.coords,
        callCode = { code = alert.code, snippet = alert.title },
        message = details ~= '' and details or alert.title,
        flashes = alert.blip.flash,
        blip = {
            sprite = alert.blip.sprite,
            scale = alert.blip.scale,
            colour = alert.blip.color,
            flashes = alert.blip.flash,
            text = heading,
            time = alert.time * 60000, -- milliseconds
        },
    })
end

return bridge
