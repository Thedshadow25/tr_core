-- cd_dispatch3d: takes cd_dispatch's notification as a server event.
local _, shared = ...
local bridge = {}

function bridge.alert(alert)
    TriggerEvent('cd_dispatch:AddNotification', shared.codesign(alert))
end

return bridge
