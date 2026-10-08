-- origen_police: its SendAlert server export, once per job.
local _, shared = ...
local origen = exports.origen_police
local bridge = {}

function bridge.alert(alert)
    local heading, details = shared.heading(alert), shared.details(alert)

    for _, job in ipairs(alert.jobs) do
        origen:SendAlert({
            coords = alert.coords,
            title = heading,
            type = 'GENERAL',
            message = details,
            job = job,
        })
    end
end

return bridge
