local ox = exports.ox_inventory

local bridge = {}

function bridge.addItem(src, item, count, metadata)
    local success, response = ox:AddItem(src, item, count, metadata)
    return success == true, not success and response or nil
end

function bridge.removeItem(src, item, count, metadata, slot)
    return ox:RemoveItem(src, item, count, metadata, slot) == true
end

function bridge.getCount(src, item, metadata)
    return ox:GetItemCount(src, item, metadata) or 0
end

function bridge.canCarry(src, item, count, metadata)
    return ox:CanCarryItem(src, item, count, metadata) == true
end

function bridge.getItem(name)
    local item = ox:Items(name)
    if not item then return end

    return { name = item.name, label = item.label, weight = item.weight, stack = item.stack, description = item.description }
end

function bridge.getSlots(src, item)
    local slots = {}
    for _, data in pairs(ox:Search(src, 'slots', item) or {}) do
        slots[#slots + 1] = { slot = data.slot, count = data.count, metadata = data.metadata or {} }
    end
    return slots
end

function bridge.setMetadata(src, slot, metadata)
    if not ox:GetSlot(src, slot) then return false end
    ox:SetMetadata(src, slot, metadata)
    return true
end

function bridge.registerStash(id, data)
    ox:RegisterStash(id, data.label, data.slots, data.weight, data.owner, data.groups, data.coords)
end

function bridge.openStash(src, id)
    ox:forceOpenInventory(src, 'stash', id)
end

---The slot a player used (what ox_inventory passes to the framework's usable item).
function bridge.usedSlot(data)
    local slot = type(data) == 'table' and math.tointeger(tonumber(data.slot))
    if not slot then return end
    return { slot = slot, count = data.count, metadata = data.metadata or {} }
end

return bridge
