--[[
    Client side of TR.mirror (see shared.lua): sends the scene being played, rebuilds other players'.

        local mirror = TR.mirror.sender(scene, 'hotwire')   -- the player playing
        mirror:sound('tick')  mirror:setLoops({ buzz = { 'buzz', { pattern = 'pulse' } } })
        mirror:tick(now)  every frame;  mirror:stop()  when the game ends
        scene.mirror = mirror   -- Scene:sparks reports its particles itself
        mirror.collect = function(m) m:setState('hose', { 12, 40, 7 }) end -- game state, at each update

    The Sender sends what changed in its scene (props added, moved, removed), one-shot sounds,
    particles and looping sounds, every options.rate ms. The server keeps the latest state and
    relays it to players within options.range (server.lua). Each of them builds a Replica: the same
    props on the same entity, eased between updates, with sounds that get quieter with distance. A
    game can add per-frame local effects to its replicas with
    TR.mirror.effects[game] = function(replica, now) ... end, and clean up after them with
    TR.mirror.teardown[game] = function(replica) ... end.

    What isn't a scene prop (a hose of a hundred pieces, say) can go as game state instead: lists of
    integers by key, sent only when they change, in replica.state on the other side for the game's
    effects to draw.

    Packets (positions and rotations are integers):
        o = { game, x, y, z, pitch, yaw }   where rig space sits on the entity (offset in mm, angles in 0.1 deg)
        a = { n, model, ... }           props added, by number
        s = { n, x, y, z, rx, ry, rz, visible, ... }   rig-space position in 0.1 mm, rotation in 0.1 deg
        d = { n, ... }                  props removed
        f = { { 's', name } | { 'x', x, y, z, scale%, asset, name, size% }, ... }   sounds and particles
        l = { [id] = { name, params } } every looping sound right now
        c = { [key] = { int, ... } | false }   game state that changed (false: gone)
        r = true                        full state: drop whatever was there before
]]

local Mirror = ... ---@type TRMirror
Mirror.effects = {} ---@type table<string, fun(replica: table, now: integer)>
Mirror.teardown = {} ---@type table<string, fun(replica: table)>

local math3d = TR.math
local Mat, Vec = math3d.Mat, math3d.Vec
local Scene = TR.scene
local options = Mirror.options

local resource = GetCurrentResourceName()
local EVENT, END, RESYNC = resource .. ':mirror', resource .. ':mirrorEnd', resource .. ':mirrorResync'

local POS, ROT = 1e4, 10

local function q(v, scale) return math.floor(v * scale + 0.5) end

local function sameList(a, b)
    for k = 1, #a do if a[k] ~= b[k] then return false end end
    return true
end

local function sameInts(a, b)
    if #a ~= #b then return false end
    for k = 1, #a do if a[k] ~= b[k] then return false end end
    return true
end

local function sameFlat(a, b)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then return false end
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

---@param a table<string, { [1]: string, [2]: table? }>
local function sameLoops(a, b)
    for id, loop in pairs(a) do
        local other = b[id]
        if not other or other[1] ~= loop[1] or not sameFlat(loop[2], other[2]) then return false end
    end
    for id in pairs(b) do if not a[id] then return false end end
    return true
end

-- Sender: the player playing -----------------------------------------------------------------

local Sender = {}
Sender.__index = Sender

---@param scene table
---@param game string what is played (a minigame's name), for Mirror.effects on the other side
function Mirror.sender(scene, game)
    return setmetatable({
        scene = scene,
        game = game,
        ids = {},   -- scene id -> number
        parts = {}, -- number -> scene part (a respawned id gets a new number)
        sent = {},  -- number -> last packed transform
        next = 1,
        events = {},
        loops = {}, sentLoops = {},
        state = {}, sentState = {},
        last = -math.huge,
    }, Sender)
end

local function pack(part)
    local p, e = part.pos, Mat.toEuler(part.rot)
    return { q(p.x, POS), q(p.y, POS), q(p.z, POS), q(e.x, ROT), q(e.y, ROT), q(e.z, ROT), part.visible and 1 or 0 }
end

function Sender:sound(name)
    self.events[#self.events + 1] = { 's', name }
end

---@param fx { asset: string, name: string, scale: number }
function Sender:sparks(p, fx, scale)
    self.events[#self.events + 1] = {
        'x', q(p.x, POS), q(p.y, POS), q(p.z, POS), q(scale or 1.0, 100), fx.asset, fx.name, q(fx.scale, 100),
    }
end

---Game state for the replicas' effects: a list of integers under `key` (false: gone). Pass a new
---list each time; only lists that changed are sent.
---@param list integer[] | false
function Sender:setState(key, list)
    self.state[key] = list
end

---Every looping sound playing right now, by id: { name, params }. Call every frame.
---@param loops table<string, { [1]: string, [2]: table? }>
function Sender:setLoops(loops)
    self.loops = loops
end

---Everything that changed since the last packet, or nil.
function Sender:delta()
    local scene = self.scene
    local packet, add, set, del = {}, {}, {}, {}
    local any = false

    local yaw = scene.yaw or 0.0
    if not self.placed or self.placed[1] ~= scene.offset or self.placed[2] ~= scene.pitch or self.placed[3] ~= yaw then
        self.placed = { scene.offset, scene.pitch, yaw }
        local o = scene.offset
        packet.o, any = { self.game, q(o.x, 1000), q(o.y, 1000), q(o.z, 1000), q(scene.pitch, ROT), q(yaw, ROT) }, true
    end

    for id, n in pairs(self.ids) do
        if scene.parts[id] ~= self.parts[n] then
            del[#del + 1] = n
            self.ids[id], self.parts[n], self.sent[n] = nil, nil, nil
        end
    end

    for id, part in pairs(scene.parts) do
        local n = self.ids[id]
        if not n then
            n = self.next
            self.next = n + 1
            self.ids[id], self.parts[n] = n, part
            add[#add + 1] = n
            add[#add + 1] = part.model
        end

        local packed, sent = pack(part), self.sent[n]
        if not sent or not sameList(packed, sent) then
            self.sent[n] = packed
            set[#set + 1] = n
            for k = 1, 7 do set[#set + 1] = packed[k] end
        end
    end

    if #del > 0 then packet.d, any = del, true end
    if #add > 0 then packet.a, any = add, true end
    if #set > 0 then packet.s, any = set, true end
    if #self.events > 0 then packet.f, self.events, any = self.events, {}, true end

    if not sameLoops(self.loops, self.sentLoops) then
        self.sentLoops = self.loops
        packet.l, any = self.loops, true
    end

    local changed
    for key, list in pairs(self.state) do
        local sent = self.sentState[key]
        if list == false then
            if sent ~= nil then
                changed = changed or {}
                changed[key], self.sentState[key] = false, nil
            end
            self.state[key] = nil
        elseif not sent or not sameInts(list, sent) then
            changed = changed or {}
            changed[key], self.sentState[key] = list, list
        end
    end
    if changed then packet.c, any = changed, true end

    return any and packet or nil
end

function Sender:tick(now)
    if now - self.last < options.rate then return end
    self.last = now
    if self.collect then self.collect(self) end

    local packet = self:delta()
    if packet then TriggerServerEvent(EVENT, packet) end
end

function Sender:stop()
    TriggerServerEvent(EVENT, false)
end

-- Replica: everyone else nearby --------------------------------------------------------------

local Replica = {}
Replica.__index = Replica

local replicas = {} ---@type table<integer, table> by the playing player's server id

---Sound volume where the camera is: full next to the props, silent at options.soundRange.
function Mirror.volumeAt(scene)
    local d = Vec.length(GetFinalRenderedCamCoord() - scene.pos)
    local k = 1.0 - d / options.soundRange
    if k <= 0.0 then return 0.0 end
    return options.volume * k * k
end

---Eases rotation a toward b (keeps it a proper rotation).
local function blend(a, b, k)
    local y = Vec.normalize(Vec.lerp(a.y, b.y, k))
    local z = Vec.lerp(a.z, b.z, k)
    local x = Vec.normalize(Vec.cross(y, z))
    return { x = x, y = y, z = Vec.cross(x, y) }
end

local function placement(o)
    return vec3(o[2] / 1000, o[3] / 1000, o[4] / 1000), o[5] / ROT, (o[6] or 0) / ROT
end

function Replica.new(owner, netId, entity, origin)
    local self = setmetatable({
        owner = owner,
        netId = netId,
        entity = entity,
        game = origin[1],
        scene = Scene.new(entity, placement(origin)),
        targets = {}, -- number -> { pos, rot, visible, model }
        loops = {},   -- id -> { name, params } as the player plays them
        state = {},   -- key -> { int, ... }: the game's own state (Sender:setState)
        playing = {}, -- local loop ids started here
        queue = {},
        alive = true,
    }, Replica)

    CreateThread(function()
        local ok, err = pcall(self.run, self)
        if not ok then TR.log.error('mirror failed: %s', err) end
        self:destroy()
    end)

    return self
end

---The replica's prop showing `model`, if any, for Mirror.effects. Set target.ownVisibility to
---show or hide it yourself instead of following the player's scene.
---@return integer? id, table? part, table? target
function Replica:find(model)
    for n, target in pairs(self.targets) do
        local part = self.scene:get(n)
        if target.model == model and part then return n, part, target end
    end
end

function Replica:apply(packet)
    local scene, targets = self.scene, self.targets

    if packet.r then
        for n in pairs(targets) do scene:remove(n) end
        targets = {}
        self.targets = targets
        self.state = {}
    end
    for key, list in pairs(packet.c or {}) do self.state[key] = list or nil end

    if packet.o then scene:setPlacement(placement(packet.o)) end

    for _, n in ipairs(packet.d or {}) do
        scene:remove(n)
        targets[n] = nil
    end

    local add = packet.a or {}
    for k = 1, #add, 2 do
        local n, model = add[k], add[k + 1]
        -- Spawning waits for the model to load, so it happens here in the replica's thread.
        if pcall(scene.spawn, scene, n, model) then targets[n] = { model = model, fresh = true } end
    end

    local set = packet.s or {}
    for k = 1, #set, 8 do
        local n = set[k]
        local target, part = targets[n], scene:get(n)
        if target and part then
            target.pos = vec3(set[k + 1] / POS, set[k + 2] / POS, set[k + 3] / POS)
            target.rot = Mat.fromEuler(vec3(set[k + 4] / ROT, set[k + 5] / ROT, set[k + 6] / ROT))
            target.visible = set[k + 7] == 1
            if target.fresh then part.pos, part.rot, target.fresh = target.pos, target.rot, false end
            if not target.ownVisibility then scene:setVisible(n, target.visible) end
        end
    end

    if packet.l then self.loops = packet.l end

    for _, e in ipairs(packet.f or {}) do
        if e[1] == 's' then
            local volume = Mirror.volumeAt(scene)
            if volume > 0.01 then TR.ui.sound.play(e[2], volume) end
        elseif e[1] == 'x' then
            scene:sparks(vec3(e[2] / POS, e[3] / POS, e[4] / POS), { asset = e[6], name = e[7], scale = e[8] / 100 }, e[5] / 100)
        end
    end
end

function Replica:run()
    while self.alive and DoesEntityExist(self.entity) do
        while #self.queue > 0 and self.alive do self:apply(table.remove(self.queue, 1)) end

        -- Updates come ~10 times a second; ease toward them so the props move smoothly.
        local k = 1.0 - math.exp(-GetFrameTime() * 15.0)
        for n, target in pairs(self.targets) do
            local part = self.scene:get(n)
            if part and target.pos and (part.pos ~= target.pos or part.rot ~= target.rot) then
                if #(part.pos - target.pos) < 0.0002 and #(part.rot.y - target.rot.y) < 0.0005
                    and #(part.rot.z - target.rot.z) < 0.0005 then
                    part.pos, part.rot = target.pos, target.rot
                else
                    part.pos = Vec.lerp(part.pos, target.pos, k)
                    part.rot = blend(part.rot, target.rot, k)
                end
            end
        end

        local effects = Mirror.effects[self.game]
        if effects then effects(self, GetGameTimer()) end

        self.scene:update()
        self:playLoops()
        Wait(0)
    end
end

function Replica:loopId(id)
    return ('mirror:%d:%s'):format(self.owner, id)
end

function Replica:playLoops()
    local volume = math.floor(Mirror.volumeAt(self.scene) * 20 + 0.5) / 20 -- steps, so tr_ui only hears about real changes

    for id, loop in pairs(self.loops) do
        if volume > 0 then
            TR.ui.sound.loop(self:loopId(id), loop[1], loop[2], volume)
            self.playing[id] = true
        end
    end

    for id in pairs(self.playing) do
        if not self.loops[id] or volume <= 0 then
            TR.ui.sound.stop(self:loopId(id))
            self.playing[id] = nil
        end
    end
end

function Replica:destroy()
    local teardown = Mirror.teardown[self.game]
    if teardown then
        local ok, err = pcall(teardown, self)
        if not ok then TR.log.error('mirror teardown failed: %s', err) end
    end
    for id in pairs(self.playing) do TR.ui.sound.stop(self:loopId(id)) end
    self.scene:destroy()
    if replicas[self.owner] == self then replicas[self.owner] = nil end
end

RegisterNetEvent(EVENT, function(owner, netId, packet)
    local replica = replicas[owner]

    if replica and packet.r and replica.netId ~= netId then
        replica.alive = false
        replica = nil
    end

    if not replica then
        -- Changes are useless without the full state they apply to: ask for it again.
        local entity = NetworkDoesNetworkIdExist(netId) and NetworkGetEntityFromNetworkId(netId) or 0
        if not packet.r or not packet.o or entity == 0 or not DoesEntityExist(entity) then
            return TriggerServerEvent(RESYNC, owner)
        end

        replica = Replica.new(owner, netId, entity, packet.o)
        replicas[owner] = replica
    end

    replica.queue[#replica.queue + 1] = packet
end)

RegisterNetEvent(END, function(owner)
    local replica = replicas[owner]
    if replica then replica.alive = false end
    replicas[owner] = nil
end)

return Mirror
