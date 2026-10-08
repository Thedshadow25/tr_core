--[[
    Server side of TR.mirror (see shared.lua): passes a scene's props, particles and sounds on to
    players near it (client.lua).

        TR.mirror.allowProps('tr_hw_')   once per game: the only models its players may show others
        TR.mirror.start(src, entity, { active = function() return sessions[src] ~= nil end, maxDuration = 250 })
        TR.mirror.stop(src)

    The player's client sends what changed; the server checks it, keeps the latest state and passes
    it on to players within options.range. Game state (Sender:setState) is checked to be short
    lists of plain, bounded integers, at most MAX_STATE_INTS of them in all; a packet that breaks
    any rule ends the mirror. Players who walk up mid-game get the whole state
    at once. A mirror ends when the client says so, its entity is gone, the player leaves, it runs
    past maxDuration, or `active` says the game is over and nothing has come in for 3 seconds.
]]

local Mirror = ... ---@type TRMirror
local options = Mirror.options

local resource = GetCurrentResourceName()
local EVENT, END, RESYNC = resource .. ':mirror', resource .. ':mirrorEnd', resource .. ':mirrorResync'

local mirrors = {} ---@type table<integer, table>
local prefixes = {}
local MAX_PARTS = 256
local MAX_POS = 30000    -- 3 m from rig space's origin, in 0.1 mm
local MAX_OFFSET = 10000 -- 10 m from the entity, in mm
local MAX_STATE_KEYS = 24
local MAX_STATE_INTS = 2000  -- in all of a game's state lists together
local MAX_STATE_INT = 1e7

---Lets players show models whose names start with `prefix` to others.
function Mirror.allowProps(prefix)
    prefixes[#prefixes + 1] = prefix
end

local function int(v, limit)
    return math.type(v) == 'integer' and (not limit or math.abs(v) <= limit)
end

local function name(v, max)
    return type(v) == 'string' and #v <= (max or 32) and v:find('^[%w_]+$') ~= nil
end

local function allowedModel(model)
    if not name(model, 48) then return false end
    for _, prefix in ipairs(prefixes) do
        if model:sub(1, #prefix) == prefix then return true end
    end
    return false
end

local function validLoops(l)
    if type(l) ~= 'table' then return false end

    local count = 0
    for id, loop in pairs(l) do
        count = count + 1
        if count > 8 or not name(id) or type(loop) ~= 'table' or not name(loop[1]) then return false end

        local params = loop[2]
        if params ~= nil then
            if type(params) ~= 'table' then return false end
            local n = 0
            for key, value in pairs(params) do
                n = n + 1
                local kind = type(value)
                if n > 8 or not name(key) or (kind ~= 'number' and kind ~= 'boolean' and not (kind == 'string' and #value <= 32)) then
                    return false
                end
            end
        end
    end

    return true
end

---Game state lists (Sender:setState): short names, plain lists of bounded integers.
local function validState(c)
    if type(c) ~= 'table' then return false end
    local keys, ints = 0, 0
    for key, list in pairs(c) do
        keys = keys + 1
        if keys > MAX_STATE_KEYS or not name(key, 16) then return false end
        if list ~= false then
            if type(list) ~= 'table' then return false end
            local n = #list
            ints = ints + n
            if ints > MAX_STATE_INTS then return false end
            for k, v in pairs(list) do
                if math.type(k) ~= 'integer' or k < 1 or k > n or not int(v, MAX_STATE_INT) then return false end
            end
        end
    end
    return true
end

---A packet from a client, checked before anyone else gets it.
local function validPacket(p)
    if type(p) ~= 'table' then return false end

    local o = p.o
    if o ~= nil then
        if type(o) ~= 'table' or not name(o[1]) then return false end
        for j = 2, 4 do if not int(o[j], MAX_OFFSET) then return false end end
        if not int(o[5], 1800) then return false end
        if o[6] ~= nil and not int(o[6], 1800) then return false end
    end

    local a = p.a
    if a ~= nil then
        if type(a) ~= 'table' or #a > MAX_PARTS * 2 then return false end
        -- Only the resource's own props: nobody gets to spawn arbitrary models on other clients.
        for k = 1, #a, 2 do
            if not int(a[k]) or a[k] < 1 or not allowedModel(a[k + 1]) then return false end
        end
    end

    local set = p.s
    if set ~= nil then
        if type(set) ~= 'table' or #set > MAX_PARTS * 8 or #set % 8 ~= 0 then return false end
        for k = 1, #set, 8 do
            if not int(set[k]) then return false end
            for j = 1, 3 do if not int(set[k + j], MAX_POS) then return false end end
            for j = 4, 6 do if not int(set[k + j], 3600) then return false end end
            if set[k + 7] ~= 0 and set[k + 7] ~= 1 then return false end
        end
    end

    if p.d ~= nil then
        if type(p.d) ~= 'table' or #p.d > MAX_PARTS then return false end
        for k = 1, #p.d do if not int(p.d[k]) then return false end end
    end

    if p.f ~= nil then
        if type(p.f) ~= 'table' or #p.f > 32 then return false end
        for _, e in ipairs(p.f) do
            if type(e) ~= 'table' then return false end
            if e[1] == 's' then
                if not name(e[2]) then return false end
            elseif e[1] == 'x' then
                if not (int(e[2], MAX_POS) and int(e[3], MAX_POS) and int(e[4], MAX_POS)) then return false end
                if not (int(e[5], 500) and e[5] >= 0 and int(e[8], 500) and e[8] >= 0) then return false end
                if not (name(e[6], 64) and name(e[7], 64)) then return false end
            else
                return false
            end
        end
    end

    if p.l ~= nil and not validLoops(p.l) then return false end
    if p.c ~= nil and not validState(p.c) then return false end

    return true
end

---Folds a packet into the kept state. False if it would grow past MAX_PARTS.
local function merge(m, p)
    if p.o then m.origin = p.o end

    for _, n in ipairs(p.d or {}) do
        if m.models[n] then m.count = m.count - 1 end
        m.models[n], m.parts[n] = nil, nil
    end

    local a = p.a or {}
    for k = 1, #a, 2 do
        if not m.models[a[k]] then m.count = m.count + 1 end
        m.models[a[k]] = a[k + 1]
    end
    if m.count > MAX_PARTS then return false end

    local set = p.s or {}
    for k = 1, #set, 8 do
        if m.models[set[k]] then m.parts[set[k]] = table.move(set, k + 1, k + 7, 1, {}) end
    end

    if p.l then m.loops = p.l end

    if p.c then
        for key, list in pairs(p.c) do m.state[key] = list or nil end
        local keys, ints = 0, 0
        for _, list in pairs(m.state) do keys, ints = keys + 1, ints + #list end
        if keys > MAX_STATE_KEYS or ints > MAX_STATE_INTS then return false end
    end
    return true
end

---The whole kept state as one packet, for players who just came near.
local function fullPacket(m)
    local add, set = {}, {}
    for n, model in pairs(m.models) do
        add[#add + 1] = n
        add[#add + 1] = model
        local part = m.parts[n]
        if part then
            set[#set + 1] = n
            table.move(part, 1, 7, #set + 1, set)
        end
    end
    return { r = true, o = m.origin, a = add, s = set, l = m.loops, c = m.state }
end

function Mirror.stop(src)
    local m = mirrors[src]
    if not m then return end

    mirrors[src] = nil
    for viewer in pairs(m.viewers) do TriggerClientEvent(END, viewer, src) end
end

---@param src integer the player playing
---@param entity integer networked entity the props sit on
---@param opts { active: fun(): boolean, maxDuration: number }
function Mirror.start(src, entity, opts)
    Mirror.stop(src)
    mirrors[src] = {
        entity = entity, netId = NetworkGetNetworkIdFromEntity(entity),
        active = opts.active, maxDuration = opts.maxDuration,
        started = os.time(), last = GetGameTimer(),
        models = {}, parts = {}, count = 0, loops = {}, state = {},
        viewers = {},
    }
end

RegisterNetEvent(EVENT, function(packet)
    local src = source
    local m = mirrors[src]
    if not m then return end
    if packet == false then return Mirror.stop(src) end

    if not TR.guard.ratelimit(src, EVENT, { max = 25, window = 1000 }) then return end
    if not validPacket(packet) or not merge(m, packet) then return Mirror.stop(src) end

    m.last = GetGameTimer()
    for viewer in pairs(m.viewers) do TriggerClientEvent(EVENT, viewer, src, m.netId, packet) end
end)

-- A viewer that couldn't use what it got (the entity wasn't there yet) gets the full state next round.
RegisterNetEvent(RESYNC, function(owner)
    local src = source
    local m = mirrors[owner]
    if not m or math.type(owner) ~= 'integer' then return end
    if not TR.guard.ratelimit(src, RESYNC, { max = 4, window = 1000 }) then return end
    m.viewers[src] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    Mirror.stop(src)
    for _, m in pairs(mirrors) do m.viewers[src] = nil end
end)

-- Who is near each game. Also ends mirrors whose game is over but never said so.
function Mirror.watch()
    local now = GetGameTimer()
    local players = GetPlayers()

    for src, m in pairs(mirrors) do
        local over = not DoesEntityExist(m.entity)
            or (not m.active() and now - m.last > 3000)
            or os.time() - m.started > m.maxDuration

        if over then
            Mirror.stop(src)
        elseif m.origin then
            local at = GetEntityCoords(m.entity)
            for _, id in ipairs(players) do
                local viewer = tonumber(id)
                if viewer ~= src then
                    local near = #(GetEntityCoords(GetPlayerPed(viewer)) - at) <= options.range
                    if near and not m.viewers[viewer] then
                        m.viewers[viewer] = true
                        TriggerClientEvent(EVENT, viewer, src, m.netId, fullPacket(m))
                    elseif not near and m.viewers[viewer] then
                        m.viewers[viewer] = nil
                        TriggerClientEvent(END, viewer, src)
                    end
                end
            end
        end
    end
end

local function watchLoop()
    Mirror.watch()
    SetTimeout(500, watchLoop)
end

SetTimeout(500, watchLoop)

return Mirror
