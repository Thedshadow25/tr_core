-- lb-tablet: its AddDispatch server export, once per job.
local tablet = exports['lb-tablet']
local bridge = {}

function bridge.alert(alert)
    local radius = alert.blip.radius > 0 and alert.blip.radius or nil

    for _, job in ipairs(alert.jobs) do
        tablet:AddDispatch({
            priority = alert.priority,
            code = alert.code,
            title = alert.title,
            description = alert.message,
            location = { label = alert.street, coords = { x = alert.coords.x, y = alert.coords.y } },
            time = alert.time * 60, -- seconds
            job = job,
            blip = {
                type = radius and 'radius' or 'default',
                radius = radius,
                sprite = alert.blip.sprite,
                color = alert.blip.color,
                size = alert.blip.scale,
                label = alert.title,
            },
        })
    end
end

return bridge
