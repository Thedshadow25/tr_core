TR.player.bridge.registerEvents()

---------------------------------------------------------------------------------------------------
-- Discord webhooks: one shared queue for every TR resource so Discord rate limits are respected.
---------------------------------------------------------------------------------------------------

local queue = {}

local function webhookUrl(channel)
    local url = GetConvar(('tr:webhook:%s'):format(channel), '')
    if url == '' then url = GetConvar('tr:webhook', '') end
    return url ~= '' and url or nil
end

---@param channel string
---@param embed TRDiscordEmbed
---@param origin? string resource that sent the log
exports('discord', function(channel, embed, origin)
    local url = webhookUrl(channel)
    if not url then return end

    embed.color = embed.color or 0x3498DB
    embed.timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
    embed.footer = { text = ('%s • %s'):format(origin or GetInvokingResource() or 'tr_core', channel) }

    queue[#queue + 1] = { url = url, body = json.encode({ username = 'TR Scripts', embeds = { embed } }) }
end)

CreateThread(function()
    while true do
        local entry = table.remove(queue, 1)

        if entry then
            PerformHttpRequest(entry.url, function(status)
                if status < 200 or status >= 300 then
                    TR.log.warn('discord webhook returned HTTP %s', status)
                end
            end, 'POST', entry.body, { ['Content-Type'] = 'application/json' })

            Wait(2000) -- stay under 30 requests per minute per webhook
        else
            Wait(500)
        end
    end
end)

---------------------------------------------------------------------------------------------------

TR.log.info('^2tr_core v%s^7 | framework: %s | inventory: %s | target: %s | keys: %s | fuel: %s | dispatch: %s',
    TR.version, TR.system('framework'), TR.system('inventory'), TR.system('target'), TR.system('keys'), TR.system('fuel'),
    TR.system('dispatch'))
