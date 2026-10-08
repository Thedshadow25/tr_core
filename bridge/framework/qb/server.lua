---@type string, TRFrameworkShared
local _, shared = ...
local QBCore = exports['qb-core']:GetCoreObject()

local bridge = {}

-- QBCore stores dirty money as the markedbills item, so 'dirty' has no account by default.
local accounts = { cash = 'cash', bank = 'bank' }

local function getPlayerData(src)
    local player = QBCore.Functions.GetPlayer(src)
    return player and player.PlayerData
end

function bridge.isLoaded(src)
    return QBCore.Functions.GetPlayer(src) ~= nil
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
    local data = name and getPlayerData(src)
    return data and data.money[name]
end

function bridge.addMoney(src, account, amount, reason)
    local name = shared.account(accounts, account)
    local player = name and QBCore.Functions.GetPlayer(src)
    if not player then return false end

    return player.Functions.AddMoney(name, amount, reason) == true
end

function bridge.removeMoney(src, account, amount, reason)
    local name = shared.account(accounts, account)
    local player = name and QBCore.Functions.GetPlayer(src)
    if not player then return false end

    return player.Functions.RemoveMoney(name, amount, reason) == true
end

function bridge.getPlayers()
    return QBCore.Functions.GetPlayers()
end

function bridge.getSource(identifier)
    local player = QBCore.Functions.GetPlayerByCitizenId(identifier)
    return player and player.PlayerData.source
end

---Translates QBCore events into tr:* events. Called once by tr_core.
function bridge.registerEvents()
    local emit = shared.serverEmitter(bridge.getJob, bridge.getPlayers())

    AddEventHandler('QBCore:Server:PlayerLoaded', function(player) emit.loaded(player.PlayerData.source) end)
    AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) emit.unloaded(src) end)
    AddEventHandler('QBCore:Server:OnJobUpdate', function(src, job) emit.job(src, shared.qbJob(job)) end)
    AddEventHandler('QBCore:Server:SetDuty', function(src, onDuty)
        local job = bridge.getJob(src)
        if job then job.onDuty = onDuty == true end
        emit.job(src, job)
    end)
end

---Calls fn(src, data) when a player uses `item`. qb-inventory passes the used slot's item
---({ slot, amount, info, ... }).
function bridge.registerUsableItem(item, fn)
    QBCore.Functions.CreateUseableItem(item, function(src, data) fn(src, data) end)
end

return bridge
