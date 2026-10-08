--[[
    Target-agnostic interaction API. Options use the ox_target format:
    https://overextended.dev/ox_target

        TR.target.addBoxZone({
            coords = vec3(0, 0, 0), size = vec3(2, 2, 2), rotation = 0,
            options = {
                { name = 'myres:open', label = 'Open', icon = 'fa-solid fa-box', distance = 2.0,
                  groups = { police = 0 }, onSelect = function(data) end },
            },
        })

    Works with ox_target and qb-target (converted, see bridge/target/qb_target).
    Options are removed automatically when the resource that added them stops.
]]

---@class TRTarget
---@field addBoxZone fun(data: table): integer | string zone id (opaque: number on ox_target, name on qb-target)
---@field addSphereZone fun(data: table): integer | string zone id
---@field addPolyZone fun(data: table): integer | string zone id
---@field removeZone fun(id: integer | string)
---@field addModel fun(models: number | string | (number | string)[], options: table | table[])
---@field removeModel fun(models: number | string | (number | string)[], names?: string | string[])
---@field addEntity fun(netIds: integer | integer[], options: table | table[])
---@field removeEntity fun(netIds: integer | integer[], names?: string | string[])
---@field addLocalEntity fun(entities: integer | integer[], options: table | table[])
---@field removeLocalEntity fun(entities: integer | integer[], names?: string | string[])
---@field addGlobalPed fun(options: table | table[])
---@field removeGlobalPed fun(names: string | string[])
---@field addGlobalVehicle fun(options: table | table[])
---@field removeGlobalVehicle fun(names: string | string[])
---@field addGlobalObject fun(options: table | table[])
---@field removeGlobalObject fun(names: string | string[])
---@field addGlobalPlayer fun(options: table | table[])
---@field removeGlobalPlayer fun(names: string | string[])
local target = TR.bridge('target')

return target
