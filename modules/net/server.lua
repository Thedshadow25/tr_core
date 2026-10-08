---@class TRNetOptions
---@field schema? TRSpec[] positional argument specs, see TR.validate
---@field rateLimit? TRRateLimit
---@field flag? boolean report invalid payloads with TR.guard.flag (default true)

---@class TRNet
local net = {}

---Registers a client -> server event with source, payload and rate limit checks.
---The handler receives (src, ...) and never runs for invalid or local triggers.
---@param name string use 'resource:action' naming
---@param handler fun(src: integer, ...: any)
---@param options? TRNetOptions
function net.on(name, handler, options)
    options = options or {}

    RegisterNetEvent(name, function(...)
        local src = source

        if type(src) ~= 'number' or src <= 0 then return end

        if options.rateLimit and not TR.guard.ratelimit(src, name, options.rateLimit) then
            return TR.log.debug('%s rate limited for %d', name, src)
        end

        if options.schema then
            local ok, err = TR.validate.args(options.schema, ...)

            if not ok then
                if options.flag ~= false then
                    TR.guard.flag(src, ('invalid payload for %s: %s'):format(name, err))
                end
                return
            end
        end

        local ok, err = pcall(handler, src, ...)
        if not ok then TR.log.error('event %s failed: %s', name, err) end
    end)
end

return net
