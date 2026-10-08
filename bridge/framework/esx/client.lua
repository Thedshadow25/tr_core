---@type string, TRFrameworkShared
local _, shared = ...
local ESX = exports.es_extended:getSharedObject()

local bridge = {}

local accounts = { cash = 'money', bank = 'bank', dirty = 'black_money' }
local notifyTypes = { info = 'info', success = 'success', error = 'error', warning = 'info' }

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

function bridge.isLoaded()
    return ESX.IsPlayerLoaded() == true
end

function bridge.getIdentifier()
    return ESX.GetPlayerData().identifier
end

function bridge.getJob()
    return normalizeJob(ESX.GetPlayerData().job)
end

-- ESX has no gangs.
function bridge.getGang() end

function bridge.getMoney(account)
    local name = shared.account(accounts, account)
    if not name then return end

    local list = ESX.GetPlayerData().accounts or {}

    for i = 1, #list do
        if list[i].name == name then return list[i].money end
    end
end

---@param data TRNotifyData
function bridge.notify(data)
    ESX.ShowNotification(data.description, notifyTypes[data.type] or 'info', data.duration, data.title)
end

---Translates ESX events into tr:* events. Called once by tr_core.
function bridge.registerEvents()
    local emit = shared.clientEmitter(bridge.getJob, bridge.isLoaded)

    RegisterNetEvent('esx:playerLoaded', function() emit.loaded() end)
    RegisterNetEvent('esx:onPlayerLogout', function() emit.unloaded() end)
    RegisterNetEvent('esx:setJob', function(job) emit.job(normalizeJob(job)) end)
end

return bridge
