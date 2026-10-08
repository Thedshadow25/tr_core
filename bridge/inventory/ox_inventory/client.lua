local ox = exports.ox_inventory

local bridge = {}

function bridge.getCount(item, metadata)
    return ox:GetItemCount(item, metadata) or 0
end

function bridge.getItem(name)
    local item = ox:Items(name)
    if not item then return end

    return { name = item.name, label = item.label, weight = item.weight, stack = item.stack, description = item.description }
end

function bridge.openStash(id)
    return ox:openInventory('stash', id)
end

function bridge.close()
    ox:closeInventory()
end

return bridge
