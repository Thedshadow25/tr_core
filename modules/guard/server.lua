---@alias TRRateLimit integer | { max: integer, window?: integer } max calls per window (ms, default 1000)

---@class TRGuard
local guard = {}

local resource = GetCurrentResourceName()
local buckets = {} ---@type table<integer, table<string, { tokens: number, updated: integer }>>

AddEventHandler('playerDropped', function()
    buckets[source] = nil
end)

---Token-bucket rate limiter. Returns false when `src` exceeded the limit for `key`.
---@param src integer
---@param key string
---@param limit TRRateLimit
---@return boolean allowed
function guard.ratelimit(src, key, limit)
    local max, window

    if type(limit) == 'table' then
        max, window = limit.max, limit.window or 1000
    else
        max, window = limit, 1000
    end

    local now = GetGameTimer()
    local playerBuckets = buckets[src]

    if not playerBuckets then
        playerBuckets = {}
        buckets[src] = playerBuckets
    end

    local bucket = playerBuckets[key]

    if not bucket then
        playerBuckets[key] = { tokens = max - 1, updated = now }
        return true
    end

    bucket.tokens = math.min(max, bucket.tokens + (now - bucket.updated) * (max / window))
    bucket.updated = now

    if bucket.tokens < 1 then return false end

    bucket.tokens = bucket.tokens - 1
    return true
end

---Server-side position check (requires OneSync).
---@param src integer
---@param coords vector3 | vector4 | table
---@param maxDistance number
---@return boolean
function guard.isNear(src, coords, maxDistance)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    return #(GetEntityCoords(ped) - TR.utils.toVector3(coords)) <= maxDistance
end

---Reports suspicious behaviour. Logs it, sends it to the 'security' webhook and fires
---`tr:playerFlagged` (src, resource, reason, details) so an anticheat or ban system can act on it.
---@param src integer
---@param reason string
---@param details? table
function guard.flag(src, reason, details)
    local name = GetPlayerName(src) or 'unknown'

    TR.log.warn('flagged %s (%d): %s', name, src, reason)

    TR.log.discord('security', {
        title = 'Player flagged',
        description = reason,
        color = 0xE74C3C,
        fields = {
            { name = 'Player', value = ('%s (%d)'):format(name, src), inline = true },
            { name = 'Resource', value = resource, inline = true },
            details and { name = 'Details', value = ('```json\n%s\n```'):format(json.encode(details)) } or nil,
        },
    })

    TriggerEvent('tr:playerFlagged', src, resource, reason, details)
end

return guard
