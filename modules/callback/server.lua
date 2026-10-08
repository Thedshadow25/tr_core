--[[
    Request/response between client and server.

    client -> server:  TR.callback.register(name, handler, options)  /  client: TR.callback.await(name, ...)
    server -> client:  client: TR.callback.register(name, handler)    /  TR.callback.await(name, src, ...)

    Failed calls return nil plus an error code: 'timeout', 'rate_limited', 'invalid_args', 'error'.
]]

---@class TRCallbackOptions
---@field schema? TRSpec[] positional argument specs, see TR.validate
---@field rateLimit? TRRateLimit
---@field flag? boolean report invalid payloads with TR.guard.flag (default true)

---@class TRCallback
local callback = {}

local resource = GetCurrentResourceName()
local timeout = 10000
local pending = {} ---@type table<integer, { src: integer, promise: promise }>
local nextId = 0

---Registers a callback clients can call with TR.callback.await.
---@param name string use 'resource:action' naming
---@param handler fun(src: integer, ...: any): ...
---@param options? TRCallbackOptions
function callback.register(name, handler, options)
    options = options or {}

    RegisterNetEvent(('__tr_cb:%s'):format(name), function(origin, id, ...)
        local src = source

        if type(src) ~= 'number' or src <= 0 then return end
        if type(origin) ~= 'string' or not origin:match('^[%w_%-]+$') or math.type(id) ~= 'integer' then return end

        local function reply(...)
            TriggerClientEvent(('__tr_cbr:%s'):format(origin), src, id, ...)
        end

        if options.rateLimit and not TR.guard.ratelimit(src, name, options.rateLimit) then
            return reply(false, 'rate_limited')
        end

        if options.schema then
            local ok, err = TR.validate.args(options.schema, ...)

            if not ok then
                if options.flag ~= false then
                    TR.guard.flag(src, ('invalid payload for callback %s: %s'):format(name, err))
                end
                return reply(false, 'invalid_args')
            end
        end

        local result = table.pack(pcall(handler, src, ...))

        if not result[1] then
            TR.log.error('callback %s failed: %s', name, result[2])
            return reply(false, 'error')
        end

        reply(true, table.unpack(result, 2, result.n))
    end)
end

RegisterNetEvent(('__tr_cbr:%s'):format(resource), function(id, ...)
    local request = pending[id]

    -- Only the client the request was sent to may answer it.
    if not request or request.src ~= source then return end

    pending[id] = nil
    request.promise:resolve(table.pack(...))
end)

---Asks a client for data and yields until it answers.
---@param name string
---@param src integer
---@param ... any
---@return ...
function callback.await(name, src, ...)
    nextId = nextId < 2147483647 and nextId + 1 or 1
    local id = nextId
    local p = promise.new()

    pending[id] = { src = src, promise = p }
    TriggerClientEvent(('__tr_cb:%s'):format(name), src, resource, id, ...)

    SetTimeout(timeout, function()
        if pending[id] then
            pending[id] = nil
            p:resolve(table.pack(false, 'timeout'))
        end
    end)

    local result = Citizen.Await(p)

    if not result[1] then
        TR.log.debug('callback %s to %d failed: %s', name, src, result[2])
        return nil, result[2]
    end

    return table.unpack(result, 2, result.n)
end

---Sets how long await waits for an answer (ms, default 10000).
---@param ms integer
function callback.setTimeout(ms)
    timeout = ms
end

return callback
