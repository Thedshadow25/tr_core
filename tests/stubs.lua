-- Minimal FiveM runtime stubs for tests (loaded before every test file by dev/lua-test/run.js).

T = {
    context = 'server',
    resource = 'tr_example',
    timer = 0,
    convars = { ['tr:locale'] = 'en' },
    resources = { tr_core = 'started' },
    exports = { tr_core = { discord = function() end } },
    handlers = {},
    fired = {},
    clientEvents = {},
    serverEvents = {},
    aces = {},
    logs = {},
    pass = 0,
    fail = 0,
}

function T.check(name, condition)
    if condition then
        T.pass = T.pass + 1
    else
        T.fail = T.fail + 1
        __out('FAIL ' .. name)
    end
end

function T.done(file)
    __out(('%s: %d passed, %d failed'):format(file, T.pass, T.fail))
    if T.fail > 0 then error('tests failed', 0) end
end

---Fresh TR instance for a context and set of started resources.
function T.boot(context, resources, convars)
    T.context = context
    T.resources = resources
    T.resources.tr_core = 'started'
    T.convars = convars or { ['tr:locale'] = 'en' }
    T.handlers, T.fired, T.clientEvents, T.serverEvents = {}, {}, {}, {}
    TR = nil
    load(LoadResourceFile('tr_core', 'init.lua'), '@init.lua')()
end

function T.count(name) return T.fired[name] and #T.fired[name] or 0 end

-- vectors: like FiveM's, they do arithmetic and type() calls them 'vector3'
local vmt = {}
vmt.__index = vmt
vmt.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, a.z + b.z) end
vmt.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
vmt.__mul = function(a, b)
    if type(a) == 'number' then return vector3(b.x * a, b.y * a, b.z * a) end
    if type(b) == 'number' then return vector3(a.x * b, a.y * b, a.z * b) end
    return vector3(a.x * b.x, a.y * b.y, a.z * b.z)
end
vmt.__div = function(a, b) return vector3(a.x / b, a.y / b, a.z / b) end
vmt.__unm = function(a) return vector3(-a.x, -a.y, -a.z) end
vmt.__eq = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end
vmt.__len = function(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
vmt.__tostring = function(v) return ('vec3(%.4f, %.4f, %.4f)'):format(v.x, v.y, v.z) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, vmt) end
vec3 = vector3
local rawtype = type
function type(v)
    if rawtype(v) == 'table' and getmetatable(v) == vmt then return 'vector3' end
    return rawtype(v)
end

-- runtime
function GetCurrentResourceName() return T.resource end
function IsDuplicityVersion() return T.context == 'server' end
function GetResourceState(name) return T.resources[name] or 'missing' end
function GetConvar(key, default) return T.convars[key] or default end
function GetResourceMetadata() return '0.1.0' end
function GetGameTimer() return T.timer end
function Wait() end
function CreateThread(fn) fn() end
function SetTimeout() end
function IsPlayerAceAllowed(src, ace) return T.aces[src] and T.aces[src][ace] == true end
function GetPlayerName(src) return 'player' .. src end
function GetPlayerPed(src) return src end
function GetEntityCoords(ped) return T.coords and T.coords[ped] or vector3(0, 0, 0) end
function PlayerPedId() return 1 end
function DoesEntityExist(entity) return entity ~= nil and entity ~= 0 end
function NetworkDoesNetworkIdExist(id) return id > 0 end
function NetworkGetEntityFromNetworkId(id) return id + 1000 end

local function addHandler(name, fn)
    T.handlers[name] = T.handlers[name] or {}
    table.insert(T.handlers[name], fn)
end

AddEventHandler = addHandler
RegisterNetEvent = function(name, fn) if fn then addHandler(name, fn) end end

function TriggerEvent(name, ...)
    T.fired[name] = T.fired[name] or {}
    table.insert(T.fired[name], table.pack(...))

    for _, fn in ipairs(T.handlers[name] or {}) do fn(...) end
end

---Simulates a network event from a client.
function T.fromClient(src, name, ...)
    source = src
    for _, fn in ipairs(T.handlers[name] or {}) do fn(...) end
end

function TriggerClientEvent(name, target, ...)
    table.insert(T.clientEvents, { name = name, target = target, args = table.pack(...) })
end

function TriggerServerEvent(name, ...)
    table.insert(T.serverEvents, { name = name, args = table.pack(...) })
end

-- exports.res:fn() reads T.exports; exports('name', fn) registers into T.ownExports, which is
-- also reachable as exports[T.resource] so a resource can call its own exports.
T.ownExports = {}

exports = setmetatable({}, {
    __index = function(_, name)
        if name == T.resource and next(T.ownExports) then
            return setmetatable({}, { __index = function(_, fnName)
                local fn = T.ownExports[fnName]
                return fn and function(_, ...) return fn(...) end
            end })
        end
        return T.exports[name]
    end,
    __call = function(_, name, fn) T.ownExports[name] = fn end,
})

-- NUI
T.nuiMessages, T.nuiCallbacks, T.focus = {}, {}, { false, false }
function SendNUIMessage(message) table.insert(T.nuiMessages, message) end
function RegisterNUICallback(name, fn) T.nuiCallbacks[name] = fn end
function SetNuiFocus(keyboard, mouse) T.focus = { keyboard, mouse } end
function GetInvokingResource() return T.invoking end
function RegisterCommand(name, fn) T.commands = T.commands or {}; T.commands[name] = fn end

---Simulates the web app calling a NUI callback; returns what was passed to cb.
function T.nui(name, data)
    local response
    T.nuiCallbacks[name](data or {}, function(r) response = r end)
    return response
end

---Last SendNUIMessage with the given action.
function T.lastNui(action)
    for i = #T.nuiMessages, 1, -1 do
        if T.nuiMessages[i].action == action then return T.nuiMessages[i] end
    end
end

LocalPlayer = { state = {} }

json = {
    encode = function() return '{}' end,
    decode = function(s) return load(__jsonToLua(s))() end,
}

print = function(s) T.logs[#T.logs + 1] = s end
