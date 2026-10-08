-- Every client -> server request goes through a callback or TR.net.on with a schema and rate limit.
TR.callback.register('tr_example:claimReward', function(src)
    local reward = Config.reward

    if not TR.inventory.canCarry(src, reward.item, reward.count) then
        return false, 'inventory_full'
    end

    TR.inventory.addItem(src, reward.item, reward.count)
    return true
end, {
    rateLimit = { max = 1, window = 5000 },
    schema = {},
})
