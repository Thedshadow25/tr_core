---@class TRNotifyServer
local notify = {}

---Shows a notification to a player (-1 for everyone).
---@param src integer
---@param data TRNotifyData | string
function notify.send(src, data)
    if type(data) == 'string' then data = { description = data } end
    TriggerClientEvent('tr:notify', src, data)
end

return notify
