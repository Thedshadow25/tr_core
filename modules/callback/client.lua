---@class TRCallback
local callback = {}

local resource = GetCurrentResourceName()
local timeout = 10000
local pending = {} ---@type table<integer, promise>
local nextId = 0

RegisterNetEvent(('__tr_cbr:%s'):format(resource), function(id, ...)
    local p = pending[id]
    if not p then return end

    pending[id] = nil
    p:resolve(table.pack(...))
end)

---Calls a server callback and yields until it answers.
---Returns the handler's values, or nil plus an error code on failure.
---@param name string
---@param ... any
---@return ...
function callback.await(name, ...)
    nextId = nextId < 2147483647 and nextId + 1 or 1
    local id = nextId
    local p = promise.new()

    pending[id] = p
    TriggerServerEvent(('__tr_cb:%s'):format(name), resource, id, ...)

    SetTimeout(timeout, function()
        if pending[id] then
            pending[id] = nil
            p:resolve(table.pack(false, 'timeout'))
        end
    end)

    local result = Citizen.Await(p)

    if not result[1] then
        TR.log.warn('callback %s failed: %s', name, result[2])
        return nil, result[2]
    end

    return table.unpack(result, 2, result.n)
end

---Non-blocking version of await; `cb` receives the same values.
---@param name string
---@param cb fun(...: any)
---@param ... any
function callback.trigger(name, cb, ...)
    local args = table.pack(...)

    CreateThread(function()
        cb(callback.await(name, table.unpack(args, 1, args.n)))
    end)
end

---Registers a callback the server can call with TR.callback.await(name, src, ...).
---@param name string
---@param handler fun(...: any): ...
function callback.register(name, handler)
    RegisterNetEvent(('__tr_cb:%s'):format(name), function(origin, id, ...)
        local result = table.pack(pcall(handler, ...))

        if not result[1] then
            TR.log.error('callback %s failed: %s', name, result[2])
            return TriggerServerEvent(('__tr_cbr:%s'):format(origin), id, false, 'error')
        end

        TriggerServerEvent(('__tr_cbr:%s'):format(origin), id, true, table.unpack(result, 2, result.n))
    end)
end

---Sets how long await waits for an answer (ms, default 10000).
---@param ms integer
function callback.setTimeout(ms)
    timeout = ms
end

return callback
