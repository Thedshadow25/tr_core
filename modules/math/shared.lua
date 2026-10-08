--[[
    Rotation maths for 3D work: props, cameras, ropes. A rotation is { x = vec3, y = vec3, z = vec3 }:
    its local axes expressed in the parent space (the columns of the matrix). Angles are in degrees.

        local Mat, Vec = TR.math.Mat, TR.math.Vec
        local rot = Mat.fromEuler(GetEntityRotation(entity, 2))
        TR.math.lerp(a, b, t)  TR.math.clamp(v, lo, hi)  TR.math.angleDelta(a, b)
]]

---@class TRMath
---@field Mat table rotation matrices: identity, axis, apply, mul, fromEuler, look, toEuler, blend, along
---@field Vec table vectors: dot, cross, length, normalize, lerp, unrotate
local math3d = {}

local Mat, Vec = {}, {}

function Mat.identity()
    return { x = vec3(1.0, 0.0, 0.0), y = vec3(0.0, 1.0, 0.0), z = vec3(0.0, 0.0, 1.0) }
end

---Rotation around one local axis.
---@param axis 'x' | 'y' | 'z'
---@param degrees number
function Mat.axis(axis, degrees)
    local r = math.rad(degrees)
    local c, s = math.cos(r), math.sin(r)

    if axis == 'x' then
        return { x = vec3(1.0, 0.0, 0.0), y = vec3(0.0, c, s), z = vec3(0.0, -s, c) }
    elseif axis == 'y' then
        return { x = vec3(c, 0.0, -s), y = vec3(0.0, 1.0, 0.0), z = vec3(s, 0.0, c) }
    end

    return { x = vec3(c, s, 0.0), y = vec3(-s, c, 0.0), z = vec3(0.0, 0.0, 1.0) }
end

function Mat.apply(m, v)
    return m.x * v.x + m.y * v.y + m.z * v.z
end

---a then b in a's space (a * b).
function Mat.mul(a, b, ...)
    local m = { x = Mat.apply(a, b.x), y = Mat.apply(a, b.y), z = Mat.apply(a, b.z) }
    if ... then return Mat.mul(m, ...) end
    return m
end

---Rotation from GTA euler angles (rotation order 2), e.g. GetEntityRotation(entity, 2).
---@param rot vector3 (pitch, roll, yaw)
function Mat.fromEuler(rot)
    return Mat.mul(Mat.axis('z', rot.z), Mat.axis('x', rot.x), Mat.axis('y', rot.y))
end

---Rotation whose +Y points along `forward`, keeping +Z as close to `up` as possible.
function Mat.look(forward, up)
    local y = Vec.normalize(forward)
    local x = Vec.normalize(Vec.cross(y, up or vec3(0.0, 0.0, 1.0)))
    return { x = x, y = y, z = Vec.cross(x, y) }
end

---Euler angles for SetEntityRotation / SetCamRot with rotation order 2,
---where the matrix is Rz(yaw) * Rx(pitch) * Ry(roll).
---@return vector3 rotation (pitch, roll, yaw)
function Mat.toEuler(m)
    local pitch = math.asin(math.max(-1.0, math.min(1.0, m.y.z)))
    local roll = math.atan(-m.x.z, m.z.z)
    local yaw = math.atan(-m.y.x, m.y.y)
    return vec3(math.deg(pitch), math.deg(roll), math.deg(yaw))
end

---A quaternion { w, x, y, z } for a rotation (kept positive w side).
local function quat(m)
    local m00, m01, m02 = m.x.x, m.y.x, m.z.x
    local m10, m11, m12 = m.x.y, m.y.y, m.z.y
    local m20, m21, m22 = m.x.z, m.y.z, m.z.z
    local tr = m00 + m11 + m22
    if tr > 0 then
        local s = math.sqrt(tr + 1.0) * 2
        return { 0.25 * s, (m21 - m12) / s, (m02 - m20) / s, (m10 - m01) / s }
    elseif m00 > m11 and m00 > m22 then
        local s = math.sqrt(1.0 + m00 - m11 - m22) * 2
        return { (m21 - m12) / s, 0.25 * s, (m01 + m10) / s, (m02 + m20) / s }
    elseif m11 > m22 then
        local s = math.sqrt(1.0 + m11 - m00 - m22) * 2
        return { (m02 - m20) / s, (m01 + m10) / s, 0.25 * s, (m12 + m21) / s }
    end
    local s = math.sqrt(1.0 + m22 - m00 - m11) * 2
    return { (m10 - m01) / s, (m02 + m20) / s, (m12 + m21) / s, 0.25 * s }
end

---Rotation part way (t 0..1) from a to b, the short way round.
function Mat.blend(a, b, t)
    local p, q = quat(a), quat(b)
    local dot = p[1] * q[1] + p[2] * q[2] + p[3] * q[3] + p[4] * q[4]
    local sign = dot < 0 and -1 or 1
    local w, x, y, z = p[1] + (q[1] * sign - p[1]) * t, p[2] + (q[2] * sign - p[2]) * t,
        p[3] + (q[3] * sign - p[3]) * t, p[4] + (q[4] * sign - p[4]) * t
    local n = math.sqrt(w * w + x * x + y * y + z * z)
    w, x, y, z = w / n, x / n, y / n, z / n
    return {
        x = vec3(1 - 2 * (y * y + z * z), 2 * (x * y + w * z), 2 * (x * z - w * y)),
        y = vec3(2 * (x * y - w * z), 1 - 2 * (x * x + z * z), 2 * (y * z + w * x)),
        z = vec3(2 * (x * z + w * y), 2 * (y * z - w * x), 1 - 2 * (x * x + y * y)),
    }
end

---Rotation whose +Y runs along `dir`, any roll (for round things like hose ends).
function Mat.along(dir)
    local y = Vec.normalize(dir)
    local up = math.abs(y.z) > 0.95 and vec3(1.0, 0.0, 0.0) or vec3(0.0, 0.0, 1.0)
    local x = Vec.normalize(Vec.cross(y, up))
    return { x = x, y = y, z = Vec.cross(x, y) }
end

function Vec.dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end

function Vec.cross(a, b)
    return vec3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end

function Vec.length(v) return math.sqrt(Vec.dot(v, v)) end

function Vec.normalize(v)
    local length = Vec.length(v)
    if length < 1e-9 then return vec3(0.0, 1.0, 0.0) end
    return v * (1.0 / length)
end

function Vec.lerp(a, b, t) return a + (b - a) * t end

---Inverse of a rotation applied to v (rotations are orthonormal, so this is the transpose).
function Vec.unrotate(m, v)
    return vec3(Vec.dot(v, m.x), Vec.dot(v, m.y), Vec.dot(v, m.z))
end

math3d.Mat, math3d.Vec = Mat, Vec

function math3d.lerp(a, b, t) return a + (b - a) * t end

function math3d.clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

---Shortest signed difference between two angles in radians.
function math3d.angleDelta(a, b)
    local d = (b - a) % (math.pi * 2)
    if d > math.pi then d = d - math.pi * 2 end
    return d
end

return math3d
