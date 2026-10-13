--[[
    Menus, the minigame HUD, text prompts and sounds.

    A resource with its own page (ui_page in its fxmanifest) gets its menus, HUD and prompts drawn there:
    the page mounts <Overlays /> from @tr/ui (dev/ui-kit), and the resource doesn't need tr_ui. Resources
    without a page use tr_ui's. The sounds a resource ships (TR.ui.sound.register) play on its own page
    too, and probeFrame reads the frame there; tr_ui's own sounds always come from tr_ui.

        TR.ui.menu.register('tr_example:main', {
            title = 'Garage',
            items = {
                { label = 'Take out', onSelect = function() end },
                { label = 'Close', close = true },
            },
        })
        TR.ui.menu.show('tr_example:main')

        TR.ui.hud.set({ hint = { text = 'Pick the lock' }, strikes = { label = 'Strikes', used = 1, max = 3 } })
        TR.ui.hud.flash('Click', 'success')
        TR.ui.hud.hide()

        TR.ui.textui.show('tr_example:shop', { key = TR.ui.keyOf('tr_example_open', 'E'), text = 'Open the shop' })
        TR.ui.textui.hide('tr_example:shop')

    Item fields (label, icon, onSelect, args, close) are documented in tr_ui/client/menu.lua.
]]

---@class TRUi
local ui = {}

---@param level? integer where the error points, for error()
local function tr_ui(level)
    local state = GetResourceState('tr_ui')
    if state ~= 'started' and state ~= 'starting' then
        error('tr_ui is not running', level or 3)
    end
    return exports.tr_ui
end

local RESOURCE = GetCurrentResourceName()
-- A resource with a page of its own draws TR.ui there (tr_ui draws for itself through its exports).
local ownPage = RESOURCE ~= 'tr_ui' and GetResourceMetadata(RESOURCE, 'ui_page', 0) ~= nil

-- What this resource last sent tr_ui (or its own page), so calls made every frame that change nothing never cross
-- over: a call into another resource copies its arguments over each time and costs far more than
-- comparing them here. Forgotten when tr_ui (re)starts.
local HUD_REFRESH = 1000 -- ms: the same HUD is sent again this often (another resource may have taken it)
local sent = { hud = nil, hudAt = 0, loops = {}, texts = {} }
local sounds -- this resource's own sound files: on its page, else registered again when tr_ui restarts

---Whether a sound plays on this resource's page: one it ships, when it has a page.
local function onPage(name) return ownPage and sounds ~= nil and sounds[name] ~= nil end

AddEventHandler('onClientResourceStart', function(name)
    if name ~= 'tr_ui' then return end
    sent.hud, sent.texts = nil, {}
    for id, l in pairs(sent.loops) do
        if not onPage(l.name) then sent.loops[id] = nil end
    end
    if sounds and not ownPage then exports.tr_ui:registerSounds(sounds) end
end)

local function copy(v)
    if type(v) ~= 'table' then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x) end
    return out
end

local function same(a, b)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then return false end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

-- This resource's own page --------------------------------------------------------------------------
-- The same calls as tr_ui's exports, sent to this resource's page instead. NUI names it takes on that
-- page: messages menu:open, menu:close, hud:set, hud:hide, hud:flash, textui:show, textui:hide,
-- sound:register, sound:play, sound:loop, sound:stop, capture:probe, tr:hello; callbacks tr:ready,
-- menu:select, menu:close, capture:result. The page's own code mustn't use them.

local page = {}
local pageReady, pageQueue = false, {}
local menus, openMenu = {}, nil ---@type table<string, TRMenu>, string?
local prompts = {} ---@type table<string, true>

local function toPage(action, data)
    if not pageReady then
        pageQueue[#pageQueue + 1] = { action = action, data = data }
        return
    end
    SendNUIMessage({ action = action, data = data })
end

---Runs a script's callback without letting its errors break the menu.
local function run(fn, ...)
    if not fn then return end
    local ok, err = pcall(fn, ...)
    if not ok then TR.log.error('menu callback failed: %s', err) end
end

---JSON numbers from the page may arrive as floats; returns a 1-based integer index or nil.
local function toIndex(value)
    value = tonumber(value)
    if not value or value ~= math.floor(value) or value < 0 then return end
    return math.tointeger(value) + 1
end

function page:registerMenu(id, data)
    assert(type(id) == 'string', 'menu id must be a string')
    assert(type(data) == 'table' and type(data.title) == 'string' and type(data.items) == 'table', 'menu needs a title and items')
    menus[id] = data
end

function page:showMenu(id)
    local menu = menus[id]
    if not menu then return TR.log.error('menu "%s" is not registered', id) end

    local items = {}
    for i, item in ipairs(menu.items) do
        items[i] = { label = tostring(item.label), icon = type(item.icon) == 'string' and item.icon or nil }
    end

    openMenu = id
    toPage('menu:open', { id = id, title = menu.title, items = items })
    SetNuiFocus(true, true)
end

function page:hideMenu(runOnClose)
    if not openMenu then return end
    local menu = menus[openMenu]
    openMenu = nil

    toPage('menu:close')
    SetNuiFocus(false, false)
    if runOnClose ~= false and menu then run(menu.onClose) end
end

function page:getOpenMenu() return openMenu end

function page:setHud(state) toPage('hud:set', state) end
function page:hideHud() toPage('hud:hide') end

function page:flashHud(text, tone, duration)
    if type(text) ~= 'string' then return end
    toPage('hud:flash', { text = text, tone = tone or 'default', duration = math.type(duration) == 'integer' and duration or 1600 })
end

function page:showTextUI(id, data)
    if type(id) ~= 'string' or type(data) ~= 'table' or type(data.text) ~= 'string' then return end
    prompts[id] = true
    toPage('textui:show', {
        id = id,
        text = data.text,
        key = data.key ~= nil and tostring(data.key) or nil,
        sub = type(data.sub) == 'string' and data.sub or nil,
    })
end

function page:hideTextUI(id)
    prompts[id] = nil
    toPage('textui:hide', { id = id })
end

function page:isTextUIShown(id) return prompts[id] == true end

local AUDIO = { ogg = true, wav = true, mp3 = true, flac = true, opus = true, webm = true }

---The page fetches the files from this resource (https://cfx-nui-<resource>/<file>). A sound marked
---custom has none: the page plays it with code of its own.
function page:registerSounds(list)
    local out = {}
    for name, sound in pairs(list) do
        local files = {}
        local custom = type(name) == 'string' and type(sound) == 'table' and sound.custom == true
        if custom then
            out[name] = { files = files, custom = true }
        elseif type(name) == 'string' and type(sound) == 'table' and type(sound.files) == 'table' then
            for _, file in ipairs(sound.files) do
                local ext = type(file) == 'string' and not file:find('..', 1, true) and file:match('%.(%w+)$')
                if ext and AUDIO[ext:lower()] then files[#files + 1] = file end
            end
        end
        if #files > 0 then
            out[name] = { files = files, level = tonumber(sound.level), variance = tonumber(sound.variance), loop = sound.loop == true }
        elseif not custom then
            TR.log.warn('sound %s has no audio files it can play', tostring(name))
        end
    end
    toPage('sound:register', { resource = RESOURCE, sounds = out })
end

function page:playSound(name, volume) toPage('sound:play', { name = name, volume = tonumber(volume) }) end

function page:loopSound(id, name, params, volume)
    toPage('sound:loop', { id = id, name = name, params = params, volume = tonumber(volume) })
end

function page:stopSound(id) toPage('sound:stop', { id = id }) end

local probes, nextProbe = {}, 0 ---@type table<integer, promise>, integer

---A frame probe's answer, from tr_ui or this resource's page.
local function probed(id, hits)
    local p = probes[id]
    if not p then return end
    probes[id] = nil
    p:resolve(hits)
end

---Asks the page to look at the game's frame. Returns the probe's id; capture:result brings the answer.
function page:probeFrame(points)
    nextProbe = nextProbe + 1
    toPage('capture:probe', { id = nextProbe, points = points })
    return nextProbe
end

if ownPage then
    -- The page says it's loaded when it mounts, and again when asked: this file may load after it did.
    RegisterNUICallback('tr:ready', function(_, cb)
        cb({})
        pageReady = true
        for i = 1, #pageQueue do SendNUIMessage(pageQueue[i]) end
        pageQueue = {}
    end)
    SendNUIMessage({ action = 'tr:hello' })

    RegisterNUICallback('menu:select', function(data, cb)
        cb({})
        local menu = openMenu and menus[openMenu]
        local index = toIndex(data.index)
        local item = menu and index and menu.items[index]
        if not item then return end

        run(item.onSelect, item.args)
        if item.close then page:hideMenu() end
    end)

    RegisterNUICallback('menu:close', function(_, cb)
        cb({})
        page:hideMenu()
    end)

    RegisterNUICallback('capture:result', function(data, cb)
        cb({})
        local id = type(data) == 'table' and tonumber(data.id)
        if id then probed(math.tointeger(id) or id, type(data.hits) == 'string' and data.hits or false) end
    end)

    -- Stopping with the menu open mustn't leave the mouse stuck on a page that's gone.
    AddEventHandler('onResourceStop', function(name)
        if name == RESOURCE and openMenu then SetNuiFocus(false, false) end
    end)
end

---Where menus, the HUD and prompts go: this resource's page, or tr_ui.
local function backend()
    if ownPage then return page end
    return tr_ui(4)
end

---@class TRUiMenu
ui.menu = {}

---Registers (or replaces) a menu. Use 'resource:name' ids.
---@param id string
---@param data TRMenu
function ui.menu.register(id, data) backend():registerMenu(id, data) end

---@param id string
function ui.menu.show(id) backend():showMenu(id) end

---Closes the open menu. Its onClose runs unless runOnClose is false.
---@param runOnClose? boolean
function ui.menu.hide(runOnClose) backend():hideMenu(runOnClose) end

---@return string? id
function ui.menu.getOpen() return backend():getOpenMenu() end

---Display-only overlay for minigames (hint bar, tools, strikes, meter, screen markers).
---Fields are documented in tr_ui/client/hud.lua.
---@class TRUiHud
ui.hud = {}

---Call every frame with the whole state; only changes are sent to the UI.
---@param state TRHudState
function ui.hud.set(state)
    local now = GetGameTimer()
    if sent.hud and now - sent.hudAt < HUD_REFRESH and same(state, sent.hud) then return end
    sent.hud, sent.hudAt = copy(state), now
    backend():setHud(state)
end

function ui.hud.hide()
    if sent.hud == false then return end
    sent.hud = false
    backend():hideHud()
end

---@param text string
---@param tone? 'default' | 'success' | 'error' | 'muted'
---@param duration? integer ms, default 1600
function ui.hud.flash(text, tone, duration) backend():flashHud(text, tone, duration) end

---Prompts on the right edge of the screen ("[G] Pick the lock"), stacked across resources.
---Fields are documented in tr_ui/client/textui.lua.
---@class TRUiTextUI
ui.textui = {}

---Shows or updates a prompt. Call when it should appear, not every frame. Use 'resource:name' ids.
---@param id string
---@param data { text: string, key?: string, sub?: string }
function ui.textui.show(id, data)
    if same(data, sent.texts[id]) then return end
    sent.texts[id] = copy(data)
    backend():showTextUI(id, data)
end

---@param id string
function ui.textui.hide(id)
    if sent.texts[id] == nil then return end
    sent.texts[id] = nil
    backend():hideTextUI(id)
end

---@param id string
---@return boolean
function ui.textui.isShown(id) return backend():isTextUIShown(id) end

---The key a player has bound to a RegisterKeyMapping command, as a short label ('G', 'E').
---Keys without a plain text label (mouse buttons, some special keys) give `fallback`.
---@param command string
---@param fallback? string
---@return string?
function ui.keyOf(command, fallback)
    local button = GetControlInstructionalButton(0, (joaat(command) | 0x80000000) & 0xFFFFFFFF, true)
    if type(button) == 'string' and button:find('^t_.') then return button:sub(3) end
    return fallback
end

---Sound effects: tr_ui's own (names in tr_ui/client/sound.lua) and the ones a resource ships (register).
---A resource with its own page plays the ones it ships there, without tr_ui; tr_ui's own need tr_ui.
---@class TRUiSound
ui.sound = {}

---Where a sound plays: this resource's page (one it ships), else tr_ui.
local function player(name)
    if onPage(name) then return page end
    return tr_ui(4)
end

---Sound files that ship with this resource, played with play / loop like tr_ui's own. Call it once
---when the resource starts; list the files in your fxmanifest `files`. Give the names a prefix of
---your own (tr_ui's names can't be replaced).
---
---    TR.ui.sound.register({
---        fr_lid_open = { files = { 'sounds/lid_open.ogg' }, level = 0.6 },
---        fr_key = { files = { 'sounds/key-1.ogg', 'sounds/key-2.ogg' }, variance = 0.05 },
---        fr_fan = { files = { 'sounds/fan.ogg' }, loop = true },
---    })
---
---files: one is picked at random each time it plays. level: 0..1, how loud (default 0.7).
---variance: a small random pitch change so repeats don't sound copied (e.g. 0.05).
---loop: play it with sound.loop; params.level 0..1 sets its volume.
---custom: true for a sound the resource's own page plays with code of its own (one made live, or a
---loop that follows its params its own way). It needs no files: the page hears sound:play, sound:loop
---and sound:stop for it, and mounts <Overlays sounds={false} /> so they aren't answered twice.
---@param list table<string, { files?: string[], level?: number, variance?: number, loop?: boolean, custom?: boolean }>
function ui.sound.register(list)
    sounds = list
    if ownPage then return page:registerSounds(list) end
    tr_ui():registerSounds(list)
end

---@param name string
---@param volume? number 0..1
function ui.sound.play(name, volume) player(name):playSound(name, volume) end

---Starts a loop or updates its params; call every frame while it should play.
---@param id string
---@param name string
---@param params? table
---@param volume? number 0..1
function ui.sound.loop(id, name, params, volume)
    local last = sent.loops[id]
    if last and last.name == name and last.volume == volume and same(params, last.params) then return end
    sent.loops[id] = { name = name, volume = volume, params = copy(params) }
    player(name):loopSound(id, name, params, volume)
end

---@param id string
function ui.sound.stop(id)
    local last = sent.loops[id]
    if not last then return end
    sent.loops[id] = nil
    player(last.name):stopSound(id)
end

local listening = false

---Which screen points show a magenta marker (DrawMarker 255, 0, 255) in the current game frame.
---Waits a frame or two for the answer. Keep drawing the markers until it returns. Read on this
---resource's page when it has one (<Overlays /> answers), else by tr_ui.
---@param points number[] flat x, y pairs, 0..1 from the top left (GetScreenCoordFromWorldCoord)
---@param timeout? integer ms, default 2000
---@return string|false hits '1' / '0' per point, or false if the frame couldn't be read
function ui.probeFrame(points, timeout)
    if not ownPage and not listening then
        listening = true
        AddEventHandler('tr_ui:frameProbed', probed)
    end

    local id = backend():probeFrame(points)
    local p = promise.new()
    probes[id] = p
    SetTimeout(timeout or 2000, function()
        if probes[id] then
            probes[id] = nil
            p:resolve(false)
        end
    end)
    return Citizen.Await(p)
end

return ui
