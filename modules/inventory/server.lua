local bridge = TR.bridge('inventory')

---@class TRItem
---@field name string
---@field label string
---@field weight number
---@field stack boolean
---@field description? string

---@class TRUsedSlot
---@field slot integer the slot the item was used from
---@field count integer
---@field metadata table the item's metadata (qb-inventory: info)

---@class TRStash
---@field label string
---@field slots integer
---@field weight integer max weight in grams
---@field owner? string | boolean true = one stash per player, string = specific identifier
---@field groups? table<string, integer> jobs allowed to open it, with minimum grade
---@field coords? vector3

---Inventory-agnostic item API.
---@class TRInventory
local inventory = {}

local function isValidCount(count)
    return math.type(count) == 'integer' and count > 0
end

---@param src integer
---@param item string
---@param count integer
---@param metadata? table
---@return boolean success
---@return string? reason e.g. 'inventory_full'
function inventory.addItem(src, item, count, metadata)
    if not isValidCount(count) then
        TR.log.error('addItem: invalid count %s for %s', count, item)
        return false, 'invalid_count'
    end

    return bridge.addItem(src, item, count, metadata)
end

---Removes items only when the player has enough.
---@param src integer
---@param item string
---@param count integer
---@param metadata? table
---@param slot? integer
---@return boolean success
function inventory.removeItem(src, item, count, metadata, slot)
    if not isValidCount(count) then
        TR.log.error('removeItem: invalid count %s for %s', count, item)
        return false
    end

    if bridge.getCount(src, item, metadata) < count then return false end

    return bridge.removeItem(src, item, count, metadata, slot)
end

---@param src integer
---@param item string
---@param metadata? table
---@return integer
function inventory.getCount(src, item, metadata) return bridge.getCount(src, item, metadata) end

---@param src integer
---@param item string
---@param count? integer default 1
---@param metadata? table
---@return boolean
function inventory.hasItem(src, item, count, metadata)
    return bridge.getCount(src, item, metadata) >= (count or 1)
end

---@param src integer
---@param item string
---@param count integer
---@param metadata? table
---@return boolean
function inventory.canCarry(src, item, count, metadata) return bridge.canCarry(src, item, count, metadata) end

---@class TRSlot
---@field slot integer
---@field count integer
---@field metadata table

---Every slot holding `item`, with its metadata (qb-inventory's `info`), in slot order.
---@param src integer
---@param item string
---@return TRSlot[]
function inventory.getSlots(src, item)
    local slots = bridge.getSlots(src, item) or {}
    table.sort(slots, function(a, b) return a.slot < b.slot end)
    return slots
end

---Replaces the metadata of the item in a slot (e.g. the fuel in a jerry can).
---@param src integer
---@param slot integer
---@param metadata table
---@return boolean success
function inventory.setMetadata(src, slot, metadata)
    if math.type(slot) ~= 'integer' or type(metadata) ~= 'table' then return false end
    return bridge.setMetadata(src, slot, metadata) == true
end

---@param name string
---@return TRItem?
function inventory.getItem(name) return bridge.getItem(name) end

---@param id string
---@param data TRStash
function inventory.registerStash(id, data) bridge.registerStash(id, data) end

---@param src integer
---@param id string
function inventory.openStash(src, id) bridge.openStash(src, id) end

local framework

---Runs `handler(src, used)` when a player uses `item` from their inventory. `used` says which one
---(its slot and metadata), e.g. which of several laptops; check the slot still holds it before acting
---on it later. Register it once, when the resource starts.
---With ox_inventory, give the item no `consume`, `client.export`, `client.status`, `client.usetime`
---or `server.export` in its items.lua entry: ox_inventory handles those itself and never tells the
---framework.
---@param item string
---@param handler fun(src: integer, used: TRUsedSlot)
function inventory.onUse(item, handler)
    framework = framework or TR.bridge('framework')
    framework.registerUsableItem(item, function(src, data)
        local used = bridge.usedSlot(data)
        if not used then
            return TR.log.warn('onUse: %s was used without its slot (%s)', item, type(data))
        end
        handler(tonumber(src), used)
    end)
end

return inventory
