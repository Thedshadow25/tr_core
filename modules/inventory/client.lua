local bridge = TR.bridge('inventory')

---Inventory-agnostic item API for the local player. Display only; the server decides.
---@class TRInventoryClient
local inventory = {}

---@param item string
---@param metadata? table
---@return integer
function inventory.getCount(item, metadata) return bridge.getCount(item, metadata) end

---@param item string
---@param count? integer default 1
---@param metadata? table
---@return boolean
function inventory.hasItem(item, count, metadata)
    return bridge.getCount(item, metadata) >= (count or 1)
end

---@param name string
---@return TRItem?
function inventory.getItem(name) return bridge.getItem(name) end

---Opens a stash registered on the server with TR.inventory.registerStash.
---@param id string
function inventory.openStash(id) return bridge.openStash(id) end

function inventory.close() bridge.close() end

return inventory
