---@class TRLog
local log = ...

---@class TRDiscordEmbed
---@field title? string
---@field description? string
---@field color? integer
---@field fields? { name: string, value: string, inline?: boolean }[]

---Queues a Discord embed for the webhook set with `set tr:webhook:<channel> "url"`
---(falls back to `tr:webhook`). Use `set`, not `setr`, so the URL never reaches clients.
---@param channel string e.g. 'money', 'admin', 'security'
---@param embed TRDiscordEmbed
function log.discord(channel, embed)
    exports.tr_core:discord(channel, embed, GetCurrentResourceName())
end

return log
