---@type string, TRFrameworkShared
local _, shared = ...
local QBCore = exports['qb-core']:GetCoreObject()

local bridge = {}

local accounts = { cash = 'cash', bank = 'bank' }
local notifyTypes = { info = 'primary', success = 'success', error = 'error', warning = 'primary' }

local function getPlayerData()
    return QBCore.Functions.GetPlayerData() or {}
end

function bridge.isLoaded()
    return LocalPlayer.state.isLoggedIn == true
end

function bridge.getIdentifier()
    return getPlayerData().citizenid
end

function bridge.getJob()
    return shared.qbJob(getPlayerData().job)
end

function bridge.getGang()
    return shared.qbGang(getPlayerData().gang)
end

function bridge.getMoney(account)
    local name = shared.account(accounts, account)
    local money = name and getPlayerData().money
    return money and money[name]
end

---@param data TRNotifyData
function bridge.notify(data)
    local text = data.title and ('%s: %s'):format(data.title, data.description) or data.description
    QBCore.Functions.Notify(text, notifyTypes[data.type] or 'primary', data.duration)
end

---Translates QBCore events into tr:* events. Called once by tr_core.
function bridge.registerEvents()
    local emit = shared.clientEmitter(bridge.getJob, bridge.isLoaded)

    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() emit.loaded() end)
    RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() emit.unloaded() end)
    RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job) emit.job(shared.qbJob(job)) end)
    RegisterNetEvent('QBCore:Client:SetDuty', function(onDuty)
        local job = bridge.getJob()
        if job then job.onDuty = onDuty == true end
        emit.job(job)
    end)
end

return bridge
