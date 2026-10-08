local QBCore = exports['qb-core']:GetCoreObject()

local bridge = {}

local function matches(info, metadata)
    if not metadata then return true end
    if type(info) ~= 'table' then return false end

    for key, value in pairs(metadata) do
        if info[key] ~= value then return false end
    end

    return true
end

function bridge.getCount(item, metadata)
    local data = QBCore.Functions.GetPlayerData()
    local count = 0

    for _, slot in pairs(data and data.items or {}) do
        if slot.name == item and matches(slot.info, metadata) then count = count + slot.amount end
    end

    return count
end

function bridge.getItem(name)
    local def = QBCore.Shared.Items[name:lower()]
    if not def then return end

    return { name = def.name, label = def.label, weight = def.weight, stack = not def.unique, description = def.description }
end

function bridge.openStash(id)
    TriggerServerEvent(('%s:tr_openStash'):format(TR.resource), id)
end

function bridge.close()
    TriggerServerEvent(('%s:tr_closeInventory'):format(TR.resource))
end

return bridge
