-- Helpers shared by every dispatch bridge (loaded once per resource and passed to the provider file).
-- Provider files return { alert = fn(alert) }, where alert is the module's filled-in TRDispatchAlert:
-- every field is set, street is a string ('' when unknown), jobs is a list.

---@class TRDispatchShared
local shared = {}

---The title with its code in front, for scripts without a code field: '10-90 - Title'.
function shared.heading(alert)
    return alert.code ~= '' and ('%s - %s'):format(alert.code, alert.title) or alert.title
end

---The message with the street after it, for scripts without a street field.
function shared.details(alert)
    if alert.street == '' then return alert.message end
    if alert.message == '' then return alert.street end
    return ('%s - %s'):format(alert.message, alert.street)
end

---Players with one of the jobs, on duty or not when `requireDuty` is false (dispatch scripts that keep
---their own duty check it themselves).
---@param jobs string[]
---@param requireDuty? boolean
---@return integer[]
function shared.players(jobs, requireDuty)
    local found = {}
    for _, src in ipairs(TR.player.getPlayers()) do
        if TR.player.hasJob(src, jobs, requireDuty) then found[#found + 1] = src end
    end
    return found
end

---cd_dispatch's notification, which cd_dispatch3d also takes.
function shared.codesign(alert)
    local heading = shared.heading(alert)
    return {
        job_table = alert.jobs,
        coords = alert.coords,
        title = heading,
        message = shared.details(alert),
        flash = alert.priority == 'high' and 1 or 0,
        sound = 1,
        blip = {
            sprite = alert.blip.sprite,
            scale = alert.blip.scale,
            colour = alert.blip.color,
            flashes = alert.blip.flash,
            text = heading,
            time = alert.time, -- minutes
            radius = alert.blip.radius,
        },
    }
end

return shared
