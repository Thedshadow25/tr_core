-- ps-dispatch. 3.x takes alerts from server scripts through its SendTargetedAlert export (its notify
-- event is for clients: it rate limits by player). 2.x takes them through the notify event, which
-- sends them to everyone; its client keeps the ones for the player's job.
local _, shared = ...
local ps = exports['ps-dispatch']
local major = tonumber(tostring(GetResourceMetadata('ps-dispatch', 'version', 0)):match('^%s*(%d+)')) or 2
local bridge = {}

local function call(alert)
    return {
        message = alert.title, -- ps-dispatch's title
        information = alert.message ~= '' and alert.message or nil,
        code = alert.code,
        codeName = alert.name,
        icon = 'fas fa-triangle-exclamation',
        priority = alert.priority == 'high' and 1 or 2, -- 1 is red
        coords = alert.coords,
        street = alert.street,
        jobs = alert.jobs,
        alert = {
            sprite = alert.blip.sprite,
            color = alert.blip.color,
            scale = alert.blip.scale,
            radius = alert.blip.radius,
            length = alert.time, -- minutes
            flash = alert.blip.flash,
            offset = false,
            sound = 'Lose_1st',
            sound2 = 'GTAO_FM_Events_Soundset',
        },
    }
end

function bridge.alert(alert)
    local data = call(alert)

    if major >= 3 then
        -- Its client still checks the job and duty; this keeps the call off everyone else's game.
        local targets = shared.players(alert.jobs)
        if #targets == 0 then return end
        data.addToList = true
        ps:SendTargetedAlert(targets, data)
    else
        TriggerEvent('ps-dispatch:server:notify', data)
    end
end

return bridge
