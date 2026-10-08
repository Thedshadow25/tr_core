--[[
    A simulated rope or hose: a chain of nodes moved by Verlet integration, held together by distance
    constraints and a little stiff (it keeps straight-ish), lying on whatever colliders it is given.
    Pure Lua on vector3s, world space, so it runs on either side.

        local rope = TR.rope.new(2.2, 0.05, { radius = 0.007, bend = 0.3 })
        rope:lay(points)                       -- along a polyline, at rest
        rope.pins[1] = pos                     -- hold a node somewhere (nil lets go)
        rope:feed(1, TR.rope.path(points), 0.2) -- end 1 pushed 0.2 m down a channel (a filler neck)
        rope.colliders = { function(p, r) return p, touching end }
        rope.colliders.select = function(box) return list end -- optional: only the colliders near it
        rope:step(dt)
        rope.p[i]                              -- where node i is

    End 1 is node 1, end 2 the last node. Nodes inside a channel follow its path exactly; the rest
    hang from them. A collider gets a node's position and radius and returns where it may be instead,
    and true if it touched (touching nodes slide less: friction). colliders.select, when there is one,
    gets a box round the whole rope ({ x0, y0, z0, x1, y1, z1 }, world, already grown by how far it can
    move in a step and its radius) once a step and returns the colliders that box can reach: the rest
    are skipped for every node.

    A rope that has settled goes to sleep: it stops moving until what holds it moves (a pin, a
    channel, how far it is fed) or rope:wake() is called. Lying over colliders, the constraints and
    the colliders would otherwise nudge it back and forth by a hair every frame (jitter).
]]

---@class TRRope
local Rope = {}
Rope.__index = Rope

local GRAVITY = -9.81
local STILL = 0.0006     -- metres a node may move in a step and still count as at rest
local STILL_STEPS = 12   -- steps in a row at rest before it sleeps
local SETTLE_STEPS = 75  -- steps after a change it sleeps anyway (a hose that keeps trembling on a collider)
local WAKE = 0.002       -- metres a held node may be from where it was when it fell asleep
local REACH = 0.1        -- metres a node may get from the rope's box in one step (colliders.select)

---A path along a polyline: returns at(s) (the point s metres along it, clamped) and its length.
---@param points vector3[]
function Rope.path(points)
    local lengths, total = { 0.0 }, 0.0
    for i = 2, #points do
        total = total + #(points[i] - points[i - 1])
        lengths[i] = total
    end
    local function at(s)
        if s <= 0.0 then return points[1] end
        if s >= total then return points[#points] end
        local lo, hi = 1, #points
        while hi - lo > 1 do
            local mid = (lo + hi) // 2
            if lengths[mid] <= s then lo = mid else hi = mid end
        end
        local span = lengths[hi] - lengths[lo]
        local t = span > 0 and (s - lengths[lo]) / span or 0.0
        return points[lo] + (points[hi] - points[lo]) * t
    end
    return at, total
end

---@param length number metres
---@param spacing number metres between nodes (rounded so they fit the length)
---@param opts? { radius?: number, bend?: number, damping?: number, friction?: number, iterations?: integer, substeps?: integer, collideEvery?: integer }
function Rope.new(length, spacing, opts)
    opts = opts or {}
    local count = math.max(3, math.floor(length / spacing + 0.5) + 1)
    local self = setmetatable({
        count = count,
        length = length,
        seg = length / (count - 1),
        radius = opts.radius or 0.005,
        bend = opts.bend or 0.3,          -- 0..1: how hard it springs back straight
        damping = opts.damping or 0.03,   -- of its speed lost per step
        friction = opts.friction or 0.7,  -- of its sliding speed lost per step on whatever it rests on
        iterations = opts.iterations or 10,
        substeps = opts.substeps or 2,
        collideEvery = opts.collideEvery or 1, -- colliders every n-th iteration (and the last): cheaper
        p = {},
        prev = {},
        pins = {},       -- [node] = position it is held at
        ends = {},       -- [1 | 2] = { at = path function, fed = metres in }
        colliders = {},
        touching = {},
        fixed = {},
        box = {},
    }, Rope)
    local zero = vec3(0.0, 0.0, 0.0)
    for i = 1, count do self.p[i], self.prev[i] = zero, zero end
    return self
end

---Puts the rope along a polyline, at rest. A rope longer than the line carries on straight past its end.
---@param points vector3[]
function Rope:lay(points)
    local at, total = Rope.path(points)
    local last, before = points[#points], points[#points - 1] or points[#points]
    local dir = #(last - before) > 1e-6 and (last - before) / #(last - before) or vec3(1.0, 0.0, 0.0)
    for i = 1, self.count do
        local s = (i - 1) * self.seg
        local p = s <= total and at(s) or last + dir * (s - total)
        self.p[i], self.prev[i] = p, p
    end
    self:wake()
end

---Pushes end `e` (1 or 2) `fed` metres into a channel along `at` (Rope.path); nil takes it out.
---@param e 1 | 2
---@param at? fun(s: number): vector3
---@param fed? number
function Rope:feed(e, at, fed)
    if not at then
        self.ends[e] = nil
        return
    end
    self.ends[e] = { at = at, fed = math.max(0.0, math.min(fed or 0.0, self.length * 0.9)) }
end

---How far node i is from end e, along the rope.
function Rope:arc(i, e)
    if e == 2 then return (self.count - i) * self.seg end
    return (i - 1) * self.seg
end

---Is node i inside end e's channel?
function Rope:inside(i, e)
    local fed = self.ends[e]
    return fed ~= nil and self:arc(i, e) < fed.fed
end

---Where every held node has to be this step (pins and nodes in a channel).
function Rope:holds()
    local fixed = self.fixed
    for i = 1, self.count do fixed[i] = self.pins[i] end
    for e = 1, 2 do
        local channel = self.ends[e]
        if channel then
            for k = 0, math.floor(channel.fed / self.seg) do
                local i = e == 1 and k + 1 or self.count - k
                local s = channel.fed - k * self.seg
                if s >= 0.0 and i >= 1 and i <= self.count then fixed[i] = channel.at(s) end
            end
        end
    end
    return fixed
end

local function satisfy(p, a, b, rest, wa, wb, k)
    local d = p[b] - p[a]
    local len = #d
    if len < 1e-9 then return end
    local w = wa + wb
    if w <= 0.0 then return end
    local move = d * ((len - rest) / len * k / w)
    if wa > 0.0 then p[a] = p[a] + move * wa end
    if wb > 0.0 then p[b] = p[b] - move * wb end
end

---Pushes every free node out of the colliders. `last`: remember which ones touched (for friction).
function Rope:collide(fixed, last)
    local p, r = self.p, self.radius
    local colliders = self.active or self.colliders
    for i = 1, self.count do
        if not fixed[i] then
            local touched = false
            for _, collide in ipairs(colliders) do
                local q, hit = collide(p[i], r)
                if q then p[i] = q end
                touched = touched or hit
            end
            if last then self.touching[i] = touched end
        end
    end
end

---Lets a sleeping rope move again (it falls back asleep once settled).
function Rope:wake()
    self.asleep, self.still, self.since = false, 0, 0
end

---Whether what holds the rope is where it was when it fell asleep.
local function sameHolds(a, b, n, tolerance)
    for i = 1, n do
        local x, y = a[i], b[i]
        if (x == nil) ~= (y == nil) then return false end
        if x and #(x - y) > tolerance then return false end
    end
    return true
end

---Moves the rope on by dt seconds.
function Rope:step(dt)
    dt = math.min(dt, 1 / 20)
    local h = dt / self.substeps
    local p, prev, n = self.p, self.prev, self.count
    local fall = vec3(0.0, 0.0, GRAVITY * h * h)
    local keep = 1.0 - self.damping
    local fixed = self:holds()
    local seg, bendRest = self.seg, self.seg * 2

    if self.asleep then
        if sameHolds(fixed, self.slept, n, WAKE) then return end
        self:wake()
    end
    -- Being moved (dragged, fed): the settling starts over.
    local held = self.held or {}
    if not sameHolds(fixed, held, n, 1e-4) then self.since, self.still = 0, 0 end
    for i = 1, n do held[i] = fixed[i] end
    self.held = held
    local before = self.before or {}
    self.before = before
    for i = 1, n do before[i] = p[i] end

    -- Only the colliders the rope can reach this step.
    self.active = nil
    local select = self.colliders.select
    if select then
        local x0, y0, z0, x1, y1, z1 = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
        for i = 1, n do
            local q = fixed[i] or p[i]
            if q.x < x0 then x0 = q.x end
            if q.y < y0 then y0 = q.y end
            if q.z < z0 then z0 = q.z end
            if q.x > x1 then x1 = q.x end
            if q.y > y1 then y1 = q.y end
            if q.z > z1 then z1 = q.z end
        end
        local m, box = REACH + self.radius, self.box
        box.x0, box.y0, box.z0, box.x1, box.y1, box.z1 = x0 - m, y0 - m, z0 - m, x1 + m, y1 + m, z1 + m
        self.active = select(box)
    end

    for _ = 1, self.substeps do
        for i = 1, n do
            if fixed[i] then
                p[i], prev[i] = fixed[i], fixed[i]
            else
                local now = p[i]
                local v = (now - prev[i]) * keep
                if self.touching[i] then v = vec3(v.x * (1.0 - self.friction), v.y * (1.0 - self.friction), v.z) end
                prev[i] = now
                p[i] = now + v + fall
            end
        end

        for it = 1, self.iterations do
            for i = 1, n - 1 do
                satisfy(p, i, i + 1, seg, fixed[i] and 0.0 or 1.0, fixed[i + 1] and 0.0 or 1.0, 1.0)
            end
            if self.bend > 0.0 then
                for i = 1, n - 2 do
                    satisfy(p, i, i + 2, bendRest, fixed[i] and 0.0 or 1.0, fixed[i + 2] and 0.0 or 1.0, self.bend * 0.5)
                end
            end
            local last = it == self.iterations
            if last or it % self.collideEvery == 0 then self:collide(fixed, last) end
        end
    end

    -- Settled (or done settling): asleep until what holds it moves.
    local moved = 0.0
    for i = 1, n do
        local d = #(p[i] - before[i])
        if d > moved then moved = d end
    end
    self.still = moved < STILL and (self.still or 0) + 1 or 0
    self.since = (self.since or 0) + 1
    if self.still >= STILL_STEPS or self.since >= SETTLE_STEPS then
        self.asleep = true
        local slept = self.slept or {}
        for i = 1, n do slept[i] = fixed[i] end
        self.slept = slept
        for i = 1, n do prev[i] = p[i] end -- no speed left to carry on with when it wakes
    end
end

---The point s metres along the rope from end 1 (between nodes).
function Rope:at(s)
    local f = math.max(0.0, math.min(s / self.seg, self.count - 1))
    local i = math.floor(f)
    if i >= self.count - 1 then return self.p[self.count] end
    return self.p[i + 1] + (self.p[i + 2] - self.p[i + 1]) * (f - i)
end

---Direction the rope runs at node i (towards end 2).
function Rope:tangent(i)
    local a, b = self.p[math.max(1, i - 1)], self.p[math.min(self.count, i + 1)]
    local d = b - a
    local len = #d
    return len > 1e-9 and d / len or vec3(0.0, 1.0, 0.0)
end

---How much longer the rope is than the straight line between its ends' channels (slack), 0..length.
function Rope:slack()
    local a = self.ends[1] and self.ends[1].fed or 0.0
    local b = self.ends[2] and self.ends[2].fed or 0.0
    local free = self.length - a - b
    local i, j = math.floor(a / self.seg) + 1, self.count - math.floor(b / self.seg)
    if j <= i then return 0.0 end
    return math.max(0.0, free - #(self.p[j] - self.p[i]))
end

return Rope
