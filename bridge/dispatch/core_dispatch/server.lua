-- core_dispatch: its sendAlert server export. The details and street go in its extra info lines.
local core = exports.core_dispatch
local bridge = {}

function bridge.alert(alert)
    local extraInfo = {}
    if alert.message ~= '' then extraInfo[#extraInfo + 1] = { icon = 'fa-info-circle', info = alert.message } end
    if alert.street ~= '' then extraInfo[#extraInfo + 1] = { icon = 'fa-map-marker-alt', info = alert.street } end

    core:sendAlert({
        code = alert.code,
        message = alert.title,
        extraInfo = extraInfo,
        coords = alert.coords,
        priority = alert.priority == 'high', -- its urgent flag
        job = alert.jobs,
        blip = alert.blip.sprite,
        color = alert.blip.color,
    })
end

return bridge
