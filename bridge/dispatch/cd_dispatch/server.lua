-- cd_dispatch: the server sends the notification to the clients, which check the job and duty.
-- Sent only to players with the job so nobody else's game gets the call.
local _, shared = ...
local bridge = {}

function bridge.alert(alert)
    local data = shared.codesign(alert)
    data.unique_id = tostring(math.random(1000000, 9999999))

    for _, src in ipairs(shared.players(alert.jobs)) do
        TriggerClientEvent('cd_dispatch:AddNotification', src, data)
    end
end

return bridge
