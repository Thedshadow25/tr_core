local QBCore = exports['qb-core']:GetCoreObject()
local inv = exports['qb-inventory']

local bridge = {}
local stashes = {} ---@type table<string, TRStash>

local function itemDef(name)
    return QBCore.Shared.Items[name:lower()]
end

local function playerItems(src)
    local player = QBCore.Functions.GetPlayer(src)
    return player and player.PlayerData.items or {}
end

-- qb-inventory has no metadata filters, so match item.info against every given key.
local function matches(info, metadata)
    if not metadata then return true end
    if type(info) ~= 'table' then return false end

    for key, value in pairs(metadata) do
        if info[key] ~= value then return false end
    end

    return true
end

function bridge.getCount(src, item, metadata)
    if not metadata then return inv:GetItemCount(src, item) or 0 end

    local count = 0

    for _, data in pairs(playerItems(src)) do
        if data.name == item and matches(data.info, metadata) then count = count + data.amount end
    end

    return count
end

function bridge.canCarry(src, item, count)
    return inv:CanAddItem(src, item, count) == true
end

function bridge.addItem(src, item, count, metadata)
    local def = itemDef(item)
    if not def then return false, 'invalid_item' end

    if not inv:CanAddItem(src, item, count) then return false, 'inventory_full' end
    if not inv:AddItem(src, item, count, nil, metadata, TR.resource) then return false, 'failed' end

    TriggerClientEvent('qb-inventory:client:ItemBox', src, def, 'add', count)
    return true
end

function bridge.removeItem(src, item, count, metadata, slot)
    local removed

    if not metadata or slot then
        removed = inv:RemoveItem(src, item, count, slot, TR.resource) == true
    else
        -- Spread the removal over every slot whose metadata matches.
        local remaining = count

        for _, data in pairs(playerItems(src)) do
            if remaining <= 0 then break end

            if data.name == item and matches(data.info, metadata) then
                local amount = math.min(data.amount, remaining)
                if not inv:RemoveItem(src, item, amount, data.slot, TR.resource) then break end
                remaining = remaining - amount
            end
        end

        removed = remaining == 0
    end

    if removed then
        TriggerClientEvent('qb-inventory:client:ItemBox', src, itemDef(item), 'remove', count)
    end

    return removed
end

function bridge.getItem(name)
    local def = itemDef(name)
    if not def then return end

    return { name = def.name, label = def.label, weight = def.weight, stack = not def.unique, description = def.description }
end

function bridge.getSlots(src, item)
    local slots = {}
    for _, data in pairs(playerItems(src)) do
        if data.name == item:lower() then
            slots[#slots + 1] = { slot = data.slot, count = data.amount, metadata = type(data.info) == 'table' and data.info or {} }
        end
    end
    return slots
end

-- qb-inventory has no metadata setter by slot: change the item's info and save the item list.
function bridge.setMetadata(src, slot, metadata)
    local player = QBCore.Functions.GetPlayer(src)
    local items = player and player.PlayerData.items
    if not items or not items[slot] then return false end

    items[slot].info = metadata
    player.Functions.SetPlayerData('items', items)
    return true
end

function bridge.registerStash(id, data)
    stashes[id] = data
end

---@return string? inventoryId
local function resolveStash(src, id)
    local stash = stashes[id]
    if not stash then return end

    if stash.groups and not (TR.player.hasJob(src, stash.groups) or TR.player.hasGang(src, stash.groups)) then return end

    local owner = stash.owner
    if not owner then return id end

    local identifier = TR.player.getIdentifier(src)
    if not identifier then return end

    if owner == true then
        return ('%s:%s'):format(id, identifier)
    elseif owner == identifier then
        return ('%s:%s'):format(id, owner)
    end
end

function bridge.openStash(src, id)
    local inventoryId = resolveStash(src, id)
    if not inventoryId then return end

    local stash = stashes[id]
    inv:OpenInventory(src, inventoryId, { label = stash.label, maxweight = stash.weight, slots = stash.slots })
end

-- qb-inventory opens stashes from the server only, so the client bridge asks through these events.
-- They are namespaced per resource because each resource keeps its own stash registry.
TR.net.on(('%s:tr_openStash'):format(TR.resource), function(src, id)
    local stash = stashes[id]
    if not stash then return end
    if stash.coords and not TR.guard.isNear(src, stash.coords, 5.0) then return end

    bridge.openStash(src, id)
end, { schema = { { type = 'string', max = 128 } }, rateLimit = 2 })

TR.net.on(('%s:tr_closeInventory'):format(TR.resource), function(src)
    inv:CloseInventory(src)
end, { schema = {}, rateLimit = 2 })

---The slot a player used (the item qb-inventory passes to the usable item: metadata is `info`).
function bridge.usedSlot(data)
    local slot = type(data) == 'table' and math.tointeger(tonumber(data.slot))
    if not slot then return end
    return { slot = slot, count = data.amount, metadata = data.info or {} }
end

return bridge
