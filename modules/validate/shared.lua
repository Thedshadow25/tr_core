--[[
    Schema validation for anything that crosses the network.

    A spec is either a type name or a table:
        'number'                        required number
        'string?'                       optional string
        { type = 'integer', min = 1, max = 100 }
        { type = 'string', min = 1, max = 24, pattern = '^[%w ]+$' }
        { type = 'string', enum = { 'cash', 'bank' } }
        { type = 'table', fields = { label = 'string', amount = 'integer' }, strict = true }
        { type = 'array', items = 'integer', max = 10 }

    Types: any, nil, boolean, number, integer, string, table, array, vector3, vector4.
    Numbers are always checked for NaN and infinity.
]]

---@alias TRSpecType 'any' | 'nil' | 'boolean' | 'number' | 'integer' | 'string' | 'table' | 'array' | 'vector3' | 'vector4'

---@class TRSpecTable
---@field type TRSpecType
---@field optional? boolean
---@field min? number number/integer: min value, string/array: min length
---@field max? number number/integer: max value, string/array: max length
---@field enum? any[]
---@field pattern? string Lua pattern the string must match
---@field fields? table<string, TRSpec> table: field specs
---@field strict? boolean table: reject keys not listed in `fields`
---@field items? TRSpec array: spec for every element

---@alias TRSpec TRSpecType | string | TRSpecTable

---@class TRValidate
local validate = {}

---@param spec TRSpec
---@return TRSpecTable
local function normalize(spec)
    if type(spec) ~= 'string' then return spec end

    local optional = spec:sub(-1) == '?'
    return { type = optional and spec:sub(1, -2) or spec, optional = optional }
end

local function isFinite(n)
    return n == n and n ~= math.huge and n ~= -math.huge
end

local function checkRange(spec, size, path, unit)
    if spec.min and size < spec.min then
        return false, ('%s must be at least %s%s'):format(path, spec.min, unit)
    end
    if spec.max and size > spec.max then
        return false, ('%s must be at most %s%s'):format(path, spec.max, unit)
    end
    return true
end

---@param spec TRSpec
---@param value any
---@param path? string name used in error messages
---@return boolean ok
---@return string? error
function validate.value(spec, value, path)
    spec = normalize(spec)
    path = path or 'value'

    local expected = spec.type
    local actual = type(value)

    if value == nil then
        if spec.optional or expected == 'nil' or expected == 'any' then return true end
        return false, ('%s is required'):format(path)
    end

    if expected == 'any' then
        -- no type restriction
    elseif expected == 'integer' then
        if actual ~= 'number' or not isFinite(value) or math.floor(value) ~= value then
            return false, ('%s must be an integer'):format(path)
        end
    elseif expected == 'array' then
        if actual ~= 'table' then return false, ('%s must be an array'):format(path) end
    elseif actual ~= expected then
        return false, ('%s must be a %s (got %s)'):format(path, expected, actual)
    end

    if actual == 'number' then
        if not isFinite(value) then return false, ('%s must be a finite number'):format(path) end
        local ok, err = checkRange(spec, value, path, '')
        if not ok then return false, err end
    elseif actual == 'string' then
        local ok, err = checkRange(spec, #value, path, ' characters')
        if not ok then return false, err end

        if spec.pattern and not value:match(spec.pattern) then
            return false, ('%s has an invalid format'):format(path)
        end
    end

    if spec.enum then
        local found = false
        for i = 1, #spec.enum do
            if spec.enum[i] == value then
                found = true
                break
            end
        end
        if not found then return false, ('%s is not an allowed value'):format(path) end
    end

    if expected == 'table' and spec.fields then
        for key, fieldSpec in pairs(spec.fields) do
            local ok, err = validate.value(fieldSpec, value[key], ('%s.%s'):format(path, key))
            if not ok then return false, err end
        end

        if spec.strict then
            for key in pairs(value) do
                if spec.fields[key] == nil then
                    return false, ('%s has unexpected field "%s"'):format(path, tostring(key))
                end
            end
        end
    elseif expected == 'array' then
        local length = #value

        for key in pairs(value) do
            if math.type(key) ~= 'integer' or key < 1 or key > length then
                return false, ('%s must be a sequential array'):format(path)
            end
        end

        local ok, err = checkRange(spec, length, path, ' items')
        if not ok then return false, err end

        if spec.items then
            for i = 1, length do
                ok, err = validate.value(spec.items, value[i], ('%s[%d]'):format(path, i))
                if not ok then return false, err end
            end
        end
    end

    return true
end

---Validates positional arguments; extra arguments are rejected.
---@param schema TRSpec[]
---@param ... any
---@return boolean ok
---@return string? error
function validate.args(schema, ...)
    local count = select('#', ...)

    if count > #schema then
        return false, ('expected at most %d arguments, got %d'):format(#schema, count)
    end

    for i = 1, #schema do
        local ok, err = validate.value(schema[i], (select(i, ...)), ('arg #%d'):format(i))
        if not ok then return false, err end
    end

    return true
end

return validate
