---@type TRPlayerShared
local shared = ...
local bridge = TR.bridge('framework')

---Framework-agnostic API for the local player.
---@class TRPlayerClient : TRPlayerShared
local player = setmetatable({}, { __index = shared })

---Raw framework bridge. Only for tr_core internals; scripts should use the functions below.
player.bridge = bridge

---@return boolean
function player.isLoaded() return bridge.isLoaded() end

---@return string?
function player.getIdentifier() return bridge.getIdentifier() end

---@return TRJob?
function player.getJob() return bridge.getJob() end

---@param filter TRJobFilter
---@param requireDuty? boolean
---@return boolean
function player.hasJob(filter, requireDuty)
    return shared.matchJob(bridge.getJob(), filter, requireDuty)
end

---@return TRGang?
function player.getGang() return bridge.getGang() end

---@param filter TRJobFilter
---@return boolean
function player.hasGang(filter)
    return shared.matchJob(bridge.getGang(), filter)
end

---Display only. Never trust client-side money for anything that matters.
---@param account TRAccount
---@return integer
function player.getMoney(account)
    assert(shared.accounts[account], ('invalid account "%s"'):format(account))
    return bridge.getMoney(account) or 0
end

---Runs `cb()` when the character is loaded, or right away if it already is.
---@param cb fun()
function player.onLoaded(cb)
    AddEventHandler('tr:playerLoaded', cb)
    if bridge.isLoaded() then CreateThread(cb) end
end

---@param cb fun()
function player.onUnloaded(cb)
    AddEventHandler('tr:playerUnloaded', cb)
end

---@param cb fun(job: TRJob, lastJob: TRJob?)
function player.onJobUpdated(cb)
    AddEventHandler('tr:jobUpdated', cb)
end

return player
