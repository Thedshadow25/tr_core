--[[
    Props, camera and mouse picking for a 3D scene fixed to an entity (a minigame on a car, say).

        local scene = TR.scene.new(entity, offset, pitch, yaw)
        local part = scene:spawn('cover', 'tr_hw_cover', pos, rot)   part.pos = ...   scene:update()  every frame
        scene:destroy()

    Everything is positioned in rig space: a frame fixed to `entity` at `offset` (entity space),
    turned by `yaw` degrees around the entity's Z axis, then tilted by `pitch` degrees around its own
    X axis. +Y points away from the player, +Z up. Every prop moves with the entity each frame, so a
    rocking car doesn't leave the props behind. Props are local to this player; TR.mirror shows them
    to players nearby. Rotations are TR.math matrices.
]]

local math3d = TR.math
local Mat, Vec, lerp, clamp = math3d.Mat, math3d.Vec, math3d.lerp, math3d.clamp

---@class TRScene
local Scene = {}
Scene.__index = Scene

local UP = vec3(0.0, 0.0, 1.0)

local function loadModel(name)
    local hash = joaat(name)
    if not IsModelInCdimage(hash) then error(('model %s is not streamed'):format(name), 0) end

    RequestModel(hash)
    local deadline = GetGameTimer() + 5000

    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then error(('model %s did not load'):format(name), 0) end
        Wait(0)
    end

    return hash
end

---A bone's position in the entity's own space, or nil if it has no such bone.
function Scene.boneOffset(entity, name)
    local bone = GetEntityBoneIndexByName(entity, name)
    if bone == -1 then return end

    local world = GetWorldPositionOfEntityBone(entity, bone)
    return GetOffsetFromEntityGivenWorldCoords(entity, world.x, world.y, world.z)
end

---@param entity integer
---@param offset vector3 where rig space starts, in the entity's own space
---@param pitch number degrees the rig tilts around its X axis
---@param yaw? number degrees the rig turns around the entity's Z axis (0: +Y is the entity's forward)
function Scene.new(entity, offset, pitch, yaw)
    local self = setmetatable({ entity = entity, parts = {}, hashes = {} }, Scene)
    self:setPlacement(offset, pitch, yaw)
    return self
end

---Moves rig space (and every prop with it), e.g. while tuning a fit live.
function Scene:setPlacement(offset, pitch, yaw)
    self.offset, self.pitch, self.yaw = offset, pitch, yaw or 0.0
    self.placementChanged = true
    self:update()
end

-- Rig placement -------------------------------------------------------------------------------

local STILL_POS, STILL_ROT = 0.0002, 0.00001 -- the entity moving less than this (m, axis) counts as still

---Recomputes where the rig is from the entity and moves the props and the camera. Props are only
---touched when they moved (their pos or rot changed, or the entity did): `scene.moved` says whether
---the entity did this frame.
function Scene:update()
    local coords, angles = GetEntityCoords(self.entity), GetEntityRotation(self.entity, 2)
    local last = self.entityAt
    if last and #(coords - last.coords) < STILL_POS and #(angles - last.angles) < STILL_ROT and not self.placementChanged then
        self.moved = false
    else
        local entityRot = Mat.fromEuler(angles)
        self.rot = Mat.mul(entityRot, Mat.axis('z', self.yaw), Mat.axis('x', self.pitch))
        self.pos = coords + Mat.apply(entityRot, self.offset)
        self.entityAt = { coords = coords, angles = angles }
        self.moved, self.placementChanged = true, false
    end

    for _, part in pairs(self.parts) do self:place(part) end
    if self.cam then self:updateCamera() end
end

function Scene:toWorld(p)
    return self.pos + Mat.apply(self.rot, p)
end

local function sameRot(a, b)
    return a == b or (a.x == b.x and a.y == b.y and a.z == b.z)
end

---Puts a prop where it belongs, unless it is there already (one native, no angles).
function Scene:place(part)
    local placed = part.placed
    if placed and not self.moved and placed.pos == part.pos and sameRot(placed.rot, part.rot) then return end
    part.placed = { pos = part.pos, rot = part.rot }

    local world = self:toWorld(part.pos)
    local rot = Mat.mul(self.rot, part.rot)
    SetEntityMatrix(part.entity, rot.y.x, rot.y.y, rot.y.z, rot.x.x, rot.x.y, rot.x.z, rot.z.x, rot.z.y, rot.z.z,
        world.x, world.y, world.z)
end

-- Props ---------------------------------------------------------------------------------------

---Spawns a local prop. pos/rot are in rig space and can be changed on the returned part.
function Scene:spawn(id, model, pos, rot)
    self:remove(id)

    local hash = loadModel(model)
    self.hashes[hash] = true

    local world = self:toWorld(pos or vec3(0.0, 0.0, 0.0))
    local entity = CreateObjectNoOffset(hash, world.x, world.y, world.z, false, false, false)

    SetEntityCollision(entity, false, false)
    FreezeEntityPosition(entity, true)
    SetEntityInvincible(entity, true)
    SetEntityLodDist(entity, 50)

    local part = { entity = entity, model = model, pos = pos or vec3(0.0, 0.0, 0.0), rot = rot or Mat.identity(), visible = true }
    self.parts[id] = part
    self:place(part)
    return part
end

function Scene:get(id) return self.parts[id] end

function Scene:remove(id)
    local part = self.parts[id]
    if not part then return end

    if DoesEntityExist(part.entity) then DeleteEntity(part.entity) end
    self.parts[id] = nil
end

function Scene:setVisible(id, visible)
    local part = self.parts[id]
    if not part or part.visible == visible then return end

    part.visible = visible
    SetEntityVisible(part.entity, visible, false)
end

---Loads every model up front so nothing pops in mid-game.
function Scene:preload(models)
    for _, model in ipairs(models) do self.hashes[loadModel(model)] = true end
end

-- Camera --------------------------------------------------------------------------------------

---Starts exactly where the gameplay camera is and glides down to the column, so the player sees
---the camera move through their own car instead of cutting away.
function Scene:createCamera(pos, target, fov)
    local from = GetGameplayCamCoord()
    local look = Mat.apply(Mat.fromEuler(GetGameplayCamRot(2)), vec3(0.0, 1.0, 0.0))

    self.camPos = Vec.unrotate(self.rot, from - self.pos)
    self.camTarget = self.camPos + Vec.unrotate(self.rot, look)
    self.fov = GetGameplayCamFov()
    self.camGoalPos, self.camGoalTarget, self.fovGoal = pos, target, fov
    self.camSpeed = 2.6
    self.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)

    self:updateCamera()
    RenderScriptCams(true, false, 0, true, false)
end

---Moves the camera smoothly to a new rig-space position.
function Scene:moveCamera(pos, target)
    self.camGoalPos, self.camGoalTarget = pos, target
    self.camSpeed = 5.0
end

---True once the camera has (nearly) reached where it is going.
function Scene:cameraSettled()
    return Vec.length(self.camPos - self.camGoalPos) < 0.01
end

function Scene:updateCamera()
    local k = clamp(GetFrameTime() * self.camSpeed, 0.0, 1.0)
    self.camPos = Vec.lerp(self.camPos, self.camGoalPos, k)
    self.camTarget = Vec.lerp(self.camTarget, self.camGoalTarget, k)
    self.fov = lerp(self.fov, self.fovGoal, k)
    self.camRot = Mat.look(self.camTarget - self.camPos, UP)

    local world = self:toWorld(self.camPos)
    local rot = Mat.toEuler(Mat.mul(self.rot, self.camRot))

    SetCamCoord(self.cam, world.x, world.y, world.z)
    SetCamRot(self.cam, rot.x, rot.y, rot.z, 2)
    SetCamFov(self.cam, self.fov)
end

---Rig-space position of the camera, for aiming tools at it.
function Scene:cameraPosition() return self.camPos end

-- Picking -------------------------------------------------------------------------------------

local function tangents(fov)
    local v = math.tan(math.rad(fov) / 2)
    return v * GetAspectRatio(false), v
end

---Projects a rig-space point to screen (0..1). Returns nil when behind the camera.
function Scene:project(p)
    local d = p - self.camPos
    local depth = Vec.dot(d, self.camRot.y)
    if depth < 0.001 then return end

    local th, tv = tangents(self.fov)
    local x = Vec.dot(d, self.camRot.x) / (depth * th)
    local y = Vec.dot(d, self.camRot.z) / (depth * tv)
    return 0.5 + x * 0.5, 0.5 - y * 0.5
end

---Ray through a screen point, in rig space.
function Scene:ray(sx, sy)
    local th, tv = tangents(self.fov)
    local dir = self.camRot.y + self.camRot.x * ((sx - 0.5) * 2 * th) + self.camRot.z * ((0.5 - sy) * 2 * tv)
    return self.camPos, Vec.normalize(dir)
end

---Where the ray through a screen point crosses the plane `axis = value` (rig space).
---@param axis 'x' | 'y' | 'z'
function Scene:onPlane(sx, sy, axis, value)
    local origin, dir = self:ray(sx, sy)
    if math.abs(dir[axis]) < 1e-6 then return origin end
    return origin + dir * ((value - origin[axis]) / dir[axis])
end

---Distance between two screen points in pixels.
function Scene.pixels(ax, ay, bx, by)
    local w, h = GetActiveScreenResolution()
    local dx, dy = (ax - bx) * w, (ay - by) * h
    return math.sqrt(dx * dx + dy * dy)
end

---Closest point to (sx, sy) on a rig-space polyline, measured on screen.
---@return number pixels, vector3 point, number along 0..1 along the line
function Scene:nearestOnLine(points, sx, sy)
    local w, h = GetActiveScreenResolution()
    local best, bestPoint, bestAlong = math.huge, points[1], 0

    for i = 1, #points - 1 do
        local ax, ay = self:project(points[i])
        local bx, by = self:project(points[i + 1])

        if ax and bx then
            local abx, aby = (bx - ax) * w, (by - ay) * h
            local apx, apy = (sx - ax) * w, (sy - ay) * h
            local len2 = abx * abx + aby * aby
            local t = len2 > 0 and clamp((apx * abx + apy * aby) / len2, 0, 1) or 0
            local dx, dy = apx - abx * t, apy - aby * t
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist < best then
                best = dist
                bestPoint = Vec.lerp(points[i], points[i + 1], t)
                bestAlong = (i - 1 + t) / (#points - 1)
            end
        end
    end

    return best, bestPoint, bestAlong
end

-- Effects -------------------------------------------------------------------------------------

---One burst of particles at a rig-space point.
---@param fx { asset: string, name: string, scale: number }
function Scene:sparks(p, fx, scale)
    if self.mirror then self.mirror:sparks(p, fx, scale) end

    RequestNamedPtfxAsset(fx.asset)
    if not HasNamedPtfxAssetLoaded(fx.asset) then return end

    local world = self:toWorld(p)
    UseParticleFxAssetNextCall(fx.asset)
    StartParticleFxNonLoopedAtCoord(fx.name, world.x, world.y, world.z, 0.0, 0.0, 0.0, fx.scale * (scale or 1.0), false, false, false)
end

---Point light in rig space, for one frame.
function Scene:light(p, r, g, b, range, intensity)
    local world = self:toWorld(p)
    DrawLightWithRange(world.x, world.y, world.z, r, g, b, range, intensity)
end

---Torch from the camera so the rig is readable at night, for one frame. `brightness` (default
---4.0) is GTA's light intensity; a few centimetres from shiny metal, much over 1 turns it white.
function Scene:torch(brightness)
    if brightness and brightness <= 0 then return end
    local from = self:toWorld(self.camPos + self.camRot.x * 0.05)
    local dir = Mat.apply(self.rot, Vec.normalize(self.camTarget - self.camPos))
    DrawSpotLight(from.x, from.y, from.z, dir.x, dir.y, dir.z, 245, 248, 255, 1.2, brightness or 4.0, 0.0, 55.0, 30.0)
end

function Scene:destroy()
    for id in pairs(self.parts) do self:remove(id) end
    for hash in pairs(self.hashes) do SetModelAsNoLongerNeeded(hash) end

    if self.cam then
        RenderScriptCams(false, true, 500, true, false)
        DestroyCam(self.cam, false)
        self.cam = nil
    end
end

return Scene
