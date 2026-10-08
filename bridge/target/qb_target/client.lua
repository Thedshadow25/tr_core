--[[
    qb-target adapter. Scripts always pass ox_target-format options; they are converted here:
        name        -> tracked so remove* can translate names to qb-target labels
        groups      -> job (string, { job = minGrade }; arrays become grade 0)
        items       -> item (count maps become a list of names)
        onSelect    -> action, event / serverEvent / command -> type + event
        canInteract -> canInteract(entity, distance, coords, name)
    qb-target keys options by label, so two options with the same label on one target overwrite
    each other. Everything a resource adds is removed when that resource stops.
]]

local qb = exports['qb-target']

local DEFAULT_DISTANCE = 2.0

local bridge = {}

local labels = {} ---@type table<string, string> option name -> label
local zones = {} ---@type table<string, true>
local added = {} ---@type { remove: string, target: any, labels: string[] }[]
local zoneCount = 0

local function toJobFilter(groups)
    if type(groups) ~= 'table' or not groups[1] then return groups end

    local filter = {}
    for i = 1, #groups do filter[groups[i]] = 0 end
    return filter
end

local function toItemFilter(items)
    if type(items) ~= 'table' or items[1] then return items end
    return TR.utils.keys(items)
end

local function entityCoords(entity)
    if entity and entity ~= 0 and DoesEntityExist(entity) then return GetEntityCoords(entity) end
    return GetEntityCoords(PlayerPedId())
end

local function convertOption(option)
    if option.name then labels[option.name] = option.label end

    local converted = {
        label = option.label,
        icon = option.icon,
        distance = option.distance or DEFAULT_DISTANCE,
        job = toJobFilter(option.groups),
        item = toItemFilter(option.items),
    }

    if option.canInteract then
        converted.canInteract = function(entity, distance)
            return option.canInteract(entity, distance, entityCoords(entity), option.name)
        end
    end

    if option.onSelect then
        converted.action = function(entity)
            local coords = entityCoords(entity)

            option.onSelect({
                entity = entity,
                coords = coords,
                distance = #(GetEntityCoords(PlayerPedId()) - coords),
                name = option.name,
            })
        end
    elseif option.event then
        converted.type, converted.event = 'client', option.event
    elseif option.serverEvent then
        converted.type, converted.event = 'server', option.serverEvent
    elseif option.command then
        converted.type, converted.event = 'command', option.command
    end

    return converted
end

---@return table params qb-target parameters
---@return string[] labels
local function convert(options)
    if options.label then options = { options } end

    local list, names, distance = {}, {}, 0

    for i = 1, #options do
        list[i] = convertOption(options[i])
        names[i] = options[i].label
        distance = math.max(distance, list[i].distance)
    end

    return { options = list, distance = distance }, names
end

local function toLabels(names)
    if names == nil then return nil end
    if type(names) == 'string' then return labels[names] or names end

    local result = {}
    for i = 1, #names do result[i] = labels[names[i]] or names[i] end
    return result
end

local function track(remove, target, optionLabels)
    added[#added + 1] = { remove = remove, target = target, labels = optionLabels }
end

local function nextZoneName(data)
    zoneCount = zoneCount + 1
    return data.name or ('%s:zone:%d'):format(TR.resource, zoneCount)
end

-- Zones -------------------------------------------------------------------------------------------

function bridge.addBoxZone(data)
    local name = nextZoneName(data)
    local coords = TR.utils.toVector3(data.coords)
    local size = TR.utils.toVector3(data.size or vec3(2, 2, 2))

    qb:AddBoxZone(name, coords, size.y, size.x, {
        name = name,
        heading = data.rotation or 0,
        debugPoly = data.debug,
        minZ = coords.z - size.z / 2,
        maxZ = coords.z + size.z / 2,
    }, (convert(data.options)))

    zones[name] = true
    return name
end

function bridge.addSphereZone(data)
    local name = nextZoneName(data)

    qb:AddCircleZone(name, TR.utils.toVector3(data.coords), data.radius or 2.0, {
        name = name,
        debugPoly = data.debug,
        useZ = true,
    }, (convert(data.options)))

    zones[name] = true
    return name
end

function bridge.addPolyZone(data)
    local name = nextZoneName(data)
    local thickness = data.thickness or 4.0
    local z = 0

    for i = 1, #data.points do z = z + data.points[i].z end
    z = z / #data.points

    qb:AddPolyZone(name, data.points, {
        name = name,
        debugPoly = data.debug,
        minZ = z - thickness / 2,
        maxZ = z + thickness / 2,
    }, (convert(data.options)))

    zones[name] = true
    return name
end

function bridge.removeZone(id)
    qb:RemoveZone(id)
    zones[id] = nil
end

-- Models and entities -----------------------------------------------------------------------------

function bridge.addModel(models, options)
    local params, optionLabels = convert(options)
    qb:AddTargetModel(models, params)
    track('RemoveTargetModel', models, optionLabels)
end

function bridge.removeModel(models, names)
    qb:RemoveTargetModel(models, toLabels(names))
end

-- ox_target takes network ids here; qb-target takes entity handles and re-keys networked ones.
local function fromNetIds(netIds)
    if type(netIds) ~= 'table' then netIds = { netIds } end

    local entities = {}

    for i = 1, #netIds do
        if NetworkDoesNetworkIdExist(netIds[i]) then
            entities[#entities + 1] = NetworkGetEntityFromNetworkId(netIds[i])
        end
    end

    return entities
end

function bridge.addEntity(netIds, options)
    local entities = fromNetIds(netIds)
    local params, optionLabels = convert(options)

    qb:AddTargetEntity(entities, params)
    track('RemoveTargetEntity', entities, optionLabels)
end

function bridge.removeEntity(netIds, names)
    qb:RemoveTargetEntity(fromNetIds(netIds), toLabels(names))
end

function bridge.addLocalEntity(entities, options)
    local params, optionLabels = convert(options)

    qb:AddTargetEntity(entities, params)
    track('RemoveTargetEntity', entities, optionLabels)
end

function bridge.removeLocalEntity(entities, names)
    qb:RemoveTargetEntity(entities, toLabels(names))
end

-- Global types ------------------------------------------------------------------------------------

for _, kind in ipairs({ 'Ped', 'Vehicle', 'Object', 'Player' }) do
    local addExport, removeExport = 'AddGlobal' .. kind, 'RemoveGlobal' .. kind

    bridge['addGlobal' .. kind] = function(options)
        local params, optionLabels = convert(options)
        qb[addExport](qb, params)
        track(removeExport, nil, optionLabels)
    end

    bridge['removeGlobal' .. kind] = function(names)
        qb[removeExport](qb, toLabels(names))
    end
end

-- Cleanup -----------------------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(resource)
    if resource ~= TR.resource then return end

    for name in pairs(zones) do qb:RemoveZone(name) end

    for i = 1, #added do
        local entry = added[i]

        if entry.target ~= nil then
            qb[entry.remove](qb, entry.target, entry.labels)
        else
            qb[entry.remove](qb, entry.labels)
        end
    end
end)

return bridge
