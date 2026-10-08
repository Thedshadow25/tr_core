local t = TR.locale.t

RegisterCommand(Config.command, function()
    local ok, reason = TR.callback.await('tr_example:claimReward')

    TR.notify.send({
        description = t(ok and 'reward_claimed' or reason or 'try_again'),
        type = ok and 'success' or 'error',
    })
end, false)
