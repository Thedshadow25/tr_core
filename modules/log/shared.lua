---@alias TRLogLevel 'error' | 'warn' | 'info' | 'debug'

---@class TRLog
local log = {}

local levels = { error = 1, warn = 2, info = 3, debug = 4 }
local colors = { error = '^1', warn = '^3', info = '^5', debug = '^9' }

-- `setr tr:loglevel debug` to see debug output (setr so clients can read it).
local threshold = levels[GetConvar('tr:loglevel', 'info')] or levels.info

---@param level TRLogLevel
---@param message any
---@param ... any string.format arguments
local function write(level, message, ...)
    if levels[level] > threshold then return end

    if select('#', ...) > 0 then
        message = tostring(message):format(...)
    elseif type(message) == 'table' then
        message = json.encode(message, { indent = true })
    end

    print(('%s[%s]^7 %s'):format(colors[level], level:upper(), tostring(message)))
end

---@param level TRLogLevel
---@return boolean
function log.enabled(level)
    return levels[level] <= threshold
end

function log.error(message, ...) write('error', message, ...) end
function log.warn(message, ...) write('warn', message, ...) end
function log.info(message, ...) write('info', message, ...) end
function log.debug(message, ...) write('debug', message, ...) end

return log
