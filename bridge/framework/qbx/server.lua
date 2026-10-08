---@type string, TRFrameworkShared
local _, shared = ...
local qbx = exports.qbx_core

local bridge = {}

-- Qbox has no dirty money account by default; map one with `setr tr:account:dirty "<type>"`.
local accounts = { cash = 'cash', bank = 'bank' }

local function getPlayerData(src)
    local player = qbx:GetPlayer(src)
    return player and player.PlayerData
end

function bridge.isLoaded(src)
    return qbx:GetPlayer(src) ~= nil
end

function bridge.getIdentifier(src)
    local data = getPlayerData(src)
    return data and data.citizenid
end

function bridge.getName(src)
    local data = getPlayerData(src)
    local info = data and data.charinfo
    return info and ('%s %s'):format(info.firstname, info.lastname)
end

function bridge.getJob(src)
    local data = getPlayerData(src)
    return data and shared.qbJob(data.job)
end

function bridge.getGang(src)
    local data = getPlayerData(src)
    return data and shared.qbGang(data.gang)
end

function bridge.getGroup(src)
    return shared.aceGroup(src)
end

function bridge.isAdmin(src)
    return IsPlayerAceAllowed(src, 'admin') or IsPlayerAceAllowed(src, 'god')
end

function bridge.getMoney(src, account)
    local name = shared.account(accounts, account)
    if not name then return end

    local amount = qbx:GetMoney(src, name)
    return amount ~= false and amount or nil
end

function bridge.addMoney(src, account, amount, reason)
    local name = shared.account(accounts, account)
    if not name then return false end

    return qbx:AddMoney(src, name, amount, reason) == true
end

function bridge.removeMoney(src, account, amount, reason)
    local name = shared.account(accounts, account)
    if not name then return false end

    return qbx:RemoveMoney(src, name, amount, reason) == true
end

function bridge.getPlayers()
    local players = {}

    for _, data in ipairs(qbx:GetPlayersData()) do
        players[#players + 1] = data.source
    end

    return players
end

function bridge.getSource(identifier)
    local player = qbx:GetPlayerByCitizenId(identifier)
    return player and player.PlayerData.source
end

---Translates Qbox events into tr:* events. Called once by tr_core.
function bridge.registerEvents()
    local emit = shared.serverEmitter(bridge.getJob, bridge.getPlayers())

    AddEventHandler('QBCore:Server:PlayerLoaded', function(player) emit.loaded(player.PlayerData.source) end)
    AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) emit.unloaded(src) end)
    AddEventHandler('qbx_core:server:playerLoggedOut', function(src) emit.unloaded(src) end)
    AddEventHandler('QBCore:Server:OnJobUpdate', function(src, job) emit.job(src, shared.qbJob(job)) end)
    AddEventHandler('QBCore:Server:SetDuty', function(src, onDuty)
        local job = bridge.getJob(src)
        if job then job.onDuty = onDuty == true end
        emit.job(src, job)
    end)
end

---Calls fn(src, data) when a player uses `item`. ox_inventory passes the used slot
---({ slot, count, metadata, ... }).
function bridge.registerUsableItem(item, fn)
    qbx:CreateUseableItem(item, function(src, data) fn(src, data) end)
end

return bridge
