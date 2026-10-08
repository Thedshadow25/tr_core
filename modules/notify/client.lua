---@alias TRNotifyType 'info' | 'success' | 'error' | 'warning'

---@class TRNotifyData
---@field title? string
---@field description string
---@field type? TRNotifyType default 'info'
---@field duration? integer milliseconds, default 5000

---@class TRNotify
local notify = {}

---Shows a notification through tr_ui when it is running, otherwise through the framework.
---@param data TRNotifyData | string
function notify.send(data)
    if type(data) == 'string' then data = { description = data } end

    data.type = data.type or 'info'
    data.duration = data.duration or 5000

    if GetResourceState('tr_ui') == 'started' then
        return exports.tr_ui:notify(data)
    end

    TR.player.bridge.notify(data)
end

return notify
