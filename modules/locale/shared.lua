--[[
    Per-resource translations loaded from the calling resource's locales/<lang>.json.
    The language is set with `setr tr:locale "en"`; missing keys fall back to en.json.
    Nested JSON objects are flattened to dot keys: { "garage": { "title": "x" } } -> "garage.title".
    Remember to add 'locales/*.json' to the resource's `files` so clients can read them.
]]

---@class TRLocale
local locale = {}

local resource = GetCurrentResourceName()
local language = GetConvar('tr:locale', 'en')
local strings

local function flatten(source, prefix, target)
    for key, value in pairs(source) do
        local path = prefix and ('%s.%s'):format(prefix, key) or key

        if type(value) == 'table' then
            flatten(value, path, target)
        else
            target[path] = value
        end
    end
    return target
end

local function loadLanguage(lang)
    local raw = LoadResourceFile(resource, ('locales/%s.json'):format(lang))
    if not raw then return end

    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then
        TR.log.error('locales/%s.json is not valid JSON', lang)
        return
    end

    return flatten(data, nil, {})
end

local function ensureLoaded()
    if strings then return end

    strings = loadLanguage('en') or {}

    if language ~= 'en' then
        local translated = loadLanguage(language)

        if translated then
            for key, value in pairs(translated) do strings[key] = value end
        else
            TR.log.warn('missing locales/%s.json, using en', language)
        end
    end
end

---Translates a key, replacing {placeholders} with values from `vars`.
---@param key string
---@param vars? table<string, any>
---@return string
function locale.t(key, vars)
    ensureLoaded()

    local str = strings[key]
    if str == nil then return key end

    str = tostring(str)
    if not vars then return str end

    return (str:gsub('{([%w_]+)}', function(name)
        local value = vars[name]
        return value ~= nil and tostring(value) or nil
    end))
end

---@return string
function locale.language()
    return language
end

return locale
