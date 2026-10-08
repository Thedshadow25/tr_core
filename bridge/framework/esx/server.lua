---@type string, TRFrameworkShared
local _, shared = ...
local ESX = exports.es_extended:getSharedObject()

local bridge = {}

local accounts = { cash = 'money', bank = 'bank', dirty = 'black_money' }

---@return TRJob?
local function normalizeJob(job)
    if not job then return end

    return {
        name = job.name,
        label = job.label,
        grade = job.grade,
        gradeName = job.grade_name,
        gradeLabel = job.grade_label,
        salary = job.grade_salary or 0,
        onDuty = job.onDuty ~= false,
        isBoss = job.grade_name == 'boss',
    }
end

local function getPlayer(src)
    return ESX.GetPlayerFromId(src)
end

function bridge.isLoaded(src)
    return getPlayer(src) ~= nil
end

function bridge.getIdentifier(src)
    local xPlayer = getPlayer(src)
    return xPlayer and xPlayer.getIdentifier()
end

function bridge.getName(src)
    local xPlayer = getPlayer(src)
    return xPlayer and xPlayer.getName()
end

function bridge.getJob(src)
    local xPlayer = getPlayer(src)
    return xPlayer and normalizeJob(xPlayer.getJob())
end

-- ESX has no gangs.
function bridge.getGang() end

function bridge.getGroup(src)
    local xPlayer = getPlayer(src)
    return xPlayer and xPlayer.getGroup()
end

function bridge.isAdmin(src)
    local group = bridge.getGroup(src)
    return group == 'admin' or group == 'superadmin'
end

function bridge.getMoney(src, account)
    local name = shared.account(accounts, account)
    local xPlayer = name and getPlayer(src)
    local data = xPlayer and xPlayer.getAccount(name)
    return data and data.money
end

function bridge.addMoney(src, account, amount, reason)
    local name = shared.account(accounts, account)
    local xPlayer = name and getPlayer(src)
    if not xPlayer then return false end

    xPlayer.addAccountMoney(name, amount, reason)
    return true
end

function bridge.removeMoney(src, account, amount, reason)
    local name = shared.account(accounts, account)
    local xPlayer = name and getPlayer(src)
    if not xPlayer then return false end

    xPlayer.removeAccountMoney(name, amount, reason)
    return true
end

function bridge.getPlayers()
    local players = {}

    for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
        players[#players + 1] = xPlayer.source
    end

    return players
end

function bridge.getSource(identifier)
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    return xPlayer and xPlayer.source
end

---Translates ESX events into tr:* events. Called once by tr_core.
function bridge.registerEvents()
    local emit = shared.serverEmitter(bridge.getJob, bridge.getPlayers())

    AddEventHandler('esx:playerLoaded', function(src) emit.loaded(src) end)

    -- Also fired by esx:playerLogout (multicharacter), so no separate logout handler.
    AddEventHandler('esx:playerDropped', function(src) emit.unloaded(src) end)

    AddEventHandler('esx:setJob', function(src, job) emit.job(src, normalizeJob(job)) end)
end

---Calls fn(src, data) when a player uses `item`. ox_inventory passes the used slot as the third
---argument ({ slot, count, metadata, ... }).
function bridge.registerUsableItem(item, fn)
    ESX.RegisterUsableItem(item, function(src, _, data) fn(src, data) end)
end

return bridge
