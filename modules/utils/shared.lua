---@class TRUtils
local utils = {}

---@param value number
---@param decimals? integer
---@return number
function utils.round(value, decimals)
    local mult = 10 ^ (decimals or 0)
    local rounded = math.floor(value * mult + 0.5) / mult
    return decimals and decimals > 0 and rounded or math.tointeger(rounded) or rounded
end

---@param value number
---@param min number
---@param max number
---@return number
function utils.clamp(value, min, max)
    return value < min and min or value > max and max or value
end

---Formats a number with thousands separators: 1234567.5 -> "1,234,567.5".
---@param value number
---@param separator? string
---@return string
function utils.formatNumber(value, separator)
    separator = separator or ','
    local sign, int, frac = tostring(value):match('^([-]?)(%d+)(%.?%d*)$')
    if not int then return tostring(value) end

    int = int:reverse():gsub('(%d%d%d)', '%1' .. separator):reverse()
    if int:sub(1, #separator) == separator then int = int:sub(#separator + 1) end

    return sign .. int .. frac
end

---@param value number
---@param symbol? string
---@return string
function utils.formatMoney(value, symbol)
    return (symbol or '$') .. utils.formatNumber(utils.round(value))
end

---@generic T
---@param value T
---@return T
function utils.deepCopy(value)
    if type(value) ~= 'table' then return value end

    local copy = {}
    for k, v in pairs(value) do copy[k] = utils.deepCopy(v) end

    return setmetatable(copy, getmetatable(value))
end

---Deep merges `override` into a copy of `base`. Arrays are replaced, not merged.
---@param base table
---@param override? table
---@return table
function utils.merge(base, override)
    local result = utils.deepCopy(base)
    if not override then return result end

    for k, v in pairs(override) do
        if type(v) == 'table' and type(result[k]) == 'table' and not utils.isArray(v) then
            result[k] = utils.merge(result[k], v)
        else
            result[k] = utils.deepCopy(v)
        end
    end

    return result
end

---@param tbl table
---@return boolean
function utils.isArray(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count == #tbl
end

---@param list table
---@param value any
---@return boolean
function utils.contains(list, value)
    for i = 1, #list do
        if list[i] == value then return true end
    end
    return false
end

---@param tbl table
---@return integer
function utils.count(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

---@param tbl table
---@return any[]
function utils.keys(tbl)
    local keys, n = {}, 0
    for k in pairs(tbl) do
        n = n + 1
        keys[n] = k
    end
    return keys
end

---@param str string
---@return string
function utils.trim(str)
    return (str:gsub('^%s+', ''):gsub('%s+$', ''))
end

---@param str string
---@param separator string plain-text separator
---@return string[]
function utils.split(str, separator)
    local parts, n, start = {}, 0, 1

    while true do
        local i, j = str:find(separator, start, true)
        n = n + 1

        if not i then
            parts[n] = str:sub(start)
            return parts
        end

        parts[n] = str:sub(start, i - 1)
        start = j + 1
    end
end

local alphanumeric = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'

---@param length integer
---@param charset? string
---@return string
function utils.randomString(length, charset)
    charset = charset or alphanumeric
    local out, size = {}, #charset

    for i = 1, length do
        local n = math.random(size)
        out[i] = charset:sub(n, n)
    end

    return table.concat(out)
end

---@return string
function utils.uuid()
    return (('xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'):gsub('[xy]', function(c)
        local v = c == 'x' and math.random(0, 15) or math.random(8, 11)
        return ('%x'):format(v)
    end))
end

---Converts a vector3/vector4/table {x, y, z} to a vector3.
---@param value vector3 | vector4 | { x: number, y: number, z: number } | number[]
---@return vector3
function utils.toVector3(value)
    if type(value) == 'vector3' then return value end
    return vector3(value.x or value[1], value.y or value[2], value.z or value[3])
end

---Yields until `check` returns a truthy value, or until the timeout expires.
---@generic T
---@param check fun(): T?
---@param timeout? integer milliseconds, default 5000; false to wait forever
---@param interval? integer milliseconds between checks, default 0
---@return T?
function utils.waitFor(check, timeout, interval)
    local deadline = timeout ~= false and GetGameTimer() + (timeout or 5000)

    while true do
        local value = check()
        if value then return value end
        if deadline and GetGameTimer() > deadline then return nil end
        Wait(interval or 0)
    end
end

return utils
