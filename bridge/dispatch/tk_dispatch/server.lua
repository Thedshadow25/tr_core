-- tk_dispatch: its addCall server export. High priority alerts flash.
local tk = exports.tk_dispatch
local bridge = {}

function bridge.alert(alert)
    tk:addCall({
        title = alert.title,
        code = alert.code,
        message = alert.message,
        coords = alert.coords,
        location = alert.street,
        jobs = alert.jobs,
        removeTime = alert.time * 60000, -- milliseconds
        flash = alert.priority == 'high',
        playSound = true,
        blip = {
            sprite = alert.blip.sprite,
            scale = alert.blip.scale,
            color = alert.blip.color,
            flash = alert.blip.flash,
            radius = alert.blip.radius > 0 and alert.blip.radius or nil,
        },
    })
end

return bridge
