-- TR.ui on a resource's own page (modules/ui), the tr_ui fallback, and the loader's tr_core_version check.
local check = T.check

local metadata = GetResourceMetadata
local meta = {}
GetResourceMetadata = function(resource, key)
    local m = meta[resource]
    if m then return m[key] end
    return metadata(resource, key)
end

local function boot(resource, resources)
    T.resource = resource
    T.nuiMessages, T.nuiCallbacks, T.focus = {}, {}, { false, false }
    T.boot('client', resources or {})
end

local function count(action)
    local n = 0
    for _, m in ipairs(T.nuiMessages) do if m.action == action then n = n + 1 end end
    return n
end

-- Own page ---------------------------------------------------------------------------------------

meta.tr_core = { version = '1.1.0' }
meta.tr_fraud = { ui_page = 'web/dist/index.html' }
boot('tr_fraud')

local calls = {}
local function record(name) return function(...) calls[#calls + 1] = { name = name, args = table.pack(...) } end end
local function called(name)
    local n, last = 0, nil
    for _, c in ipairs(calls) do if c.name == name then n, last = n + 1, c end end
    return n, last
end

TR.ui.menu.register('tr_fraud:atm', {
    title = 'Which card?',
    items = {
        { label = 'Maze Bank 1234', icon = 'credit-card', args = 4, onSelect = record('pick') },
        { label = 'Boom', onSelect = function() error('script bug') end },
        { label = 'Fleeca 9876', icon = 5, args = 7, close = true, onSelect = record('pick') },
    },
    onClose = record('close'),
})

check('own: asks the page if it has loaded', T.nuiMessages[1] and T.nuiMessages[1].action == 'tr:hello')
check('own: its callbacks', T.nuiCallbacks['tr:ready'] and T.nuiCallbacks['menu:select'] and T.nuiCallbacks['menu:close'])

TR.ui.menu.show('tr_fraud:atm')
check('own: held until the page is ready', count('menu:open') == 0 and TR.ui.menu.getOpen() == 'tr_fraud:atm')
check('own: menu takes focus', T.focus[1] == true and T.focus[2] == true)

T.nui('tr:ready')
local open = T.lastNui('menu:open')
check('own: sent once ready', open ~= nil and open.data.title == 'Which card?' and open.data.id == 'tr_fraud:atm')
check('own: only labels and icons go to the page', #open.data.items == 3 and open.data.items[1].label == 'Maze Bank 1234' and open.data.items[1].onSelect == nil)
check('own: icons go to the page, bad ones are dropped', open.data.items[1].icon == 'credit-card' and open.data.items[2].icon == nil and open.data.items[3].icon == nil)
T.nui('tr:ready')
check('own: ready twice sends nothing twice', count('menu:open') == 1)

T.nui('menu:select', { index = 0.0 })
local n, last = called('pick')
check('own: pick with args (float index)', n == 1 and last.args[1] == 4 and TR.ui.menu.getOpen() == 'tr_fraud:atm')

T.nui('menu:select', { index = 1 })
check('own: a callback error stays contained', TR.ui.menu.getOpen() == 'tr_fraud:atm')

T.nui('menu:select', { index = -1 })
T.nui('menu:select', { index = 'x' })
T.nui('menu:select', { index = 99 })
check('own: bad indexes ignored', called('pick') == 1 and TR.ui.menu.getOpen() == 'tr_fraud:atm')

T.nui('menu:select', { index = 2 })
n, last = called('pick')
check('own: close item picks, then closes', n == 2 and last.args[1] == 7 and TR.ui.menu.getOpen() == nil)
check('own: onClose ran', called('close') == 1)
check('own: focus given back', T.focus[1] == false and T.focus[2] == false)
check('own: page told to close', T.nuiMessages[#T.nuiMessages].action == 'menu:close')

TR.ui.menu.show('tr_fraud:atm')
T.nui('menu:close')
check('own: closing from the page runs onClose', called('close') == 2 and TR.ui.menu.getOpen() == nil and T.focus[1] == false)

TR.ui.menu.show('tr_fraud:atm')
TR.ui.menu.hide(false)
check('own: hide(false) skips onClose', called('close') == 2 and TR.ui.menu.getOpen() == nil)

local before = count('menu:open')
TR.ui.menu.show('nope')
check('own: unknown menu not shown', count('menu:open') == before and T.focus[1] == false)

local hud = { meter = { label = 'Reading card', duration = 6000, run = 1 }, hint = { text = 'Reading card' } }
TR.ui.hud.set(hud)
TR.ui.hud.set({ meter = { label = 'Reading card', duration = 6000, run = 1 }, hint = { text = 'Reading card' } })
check('own: HUD sent once while it stays the same', count('hud:set') == 1 and T.lastNui('hud:set').data.meter.duration == 6000)
T.timer = T.timer + 1500
TR.ui.hud.set(hud)
check('own: and again after a second', count('hud:set') == 2)
TR.ui.hud.hide()
TR.ui.hud.hide()
check('own: HUD hidden once', count('hud:hide') == 1)
TR.ui.hud.flash('Paid', 'success')
local flash = T.lastNui('hud:flash')
check('own: flash', flash and flash.data.text == 'Paid' and flash.data.tone == 'success' and flash.data.duration == 1600)

TR.ui.textui.show('tr_fraud:atm', { key = 'E', text = 'Use cloned card' })
check('own: prompt shown', TR.ui.textui.isShown('tr_fraud:atm') and T.lastNui('textui:show').data.key == 'E')
TR.ui.textui.hide('tr_fraud:atm')
TR.ui.textui.hide('tr_fraud:atm')
check('own: prompt hidden once', not TR.ui.textui.isShown('tr_fraud:atm') and count('textui:hide') == 1)

TR.ui.sound.register({
    fr_beep = { files = { 'sounds/beep.wav' }, level = 0.6, variance = 0.05 },
    fr_slide = { files = { 'sounds/slide.ogg', 'sounds/../../x.wav', 'notes.txt' }, loop = true },
    fr_none = { files = { 'readme.md' } },
})
local reg = T.lastNui('sound:register')
check('own: its sounds go to its page, only files it can play', reg and reg.data.resource == 'tr_fraud'
    and reg.data.sounds.fr_beep.files[1] == 'sounds/beep.wav' and reg.data.sounds.fr_beep.level == 0.6
    and reg.data.sounds.fr_beep.variance == 0.05 and #reg.data.sounds.fr_slide.files == 1
    and reg.data.sounds.fr_slide.files[1] == 'sounds/slide.ogg' and reg.data.sounds.fr_slide.loop == true
    and reg.data.sounds.fr_none == nil)
TR.ui.sound.play('fr_beep', 0.5)
local played = T.lastNui('sound:play')
check('own: played on its page', played and played.data.name == 'fr_beep' and played.data.volume == 0.5)
TR.ui.sound.loop('fr:slide', 'fr_slide', { level = 0.3 })
TR.ui.sound.loop('fr:slide', 'fr_slide', { level = 0.3 })
check('own: a loop on its page, sent once while it stays the same', count('sound:loop') == 1
    and T.lastNui('sound:loop').data.id == 'fr:slide' and T.lastNui('sound:loop').data.params.level == 0.3)
for _, fn in ipairs(T.handlers.onClientResourceStart or {}) do fn('tr_ui') end
TR.ui.sound.loop('fr:slide', 'fr_slide', { level = 0.3 })
check('own: tr_ui starting doesn\'t restart it', count('sound:loop') == 1)
TR.ui.sound.stop('fr:slide')
TR.ui.sound.stop('fr:slide')
check('own: stopped once', count('sound:stop') == 1 and T.lastNui('sound:stop').data.id == 'fr:slide')
local okTick, tickErr = pcall(TR.ui.sound.play, 'tick')
check('own: tr_ui\'s own sounds still need tr_ui', not okTick and tostring(tickErr):find('tr_ui is not running', 1, true) ~= nil)

-- Sounds the page plays with code of its own need no files.
TR.ui.sound.register({ fr_hum = { custom = true }, fr_empty = {} })
reg = T.lastNui('sound:register')
check('own: a custom sound is registered without files', reg.data.sounds.fr_hum ~= nil and reg.data.sounds.fr_hum.custom == true
    and #reg.data.sounds.fr_hum.files == 0 and reg.data.sounds.fr_empty == nil)
TR.ui.sound.play('fr_hum', 0.4)
check('own: and played on its page', T.lastNui('sound:play').data.name == 'fr_hum' and T.lastNui('sound:play').data.volume == 0.4)

-- Frame probes are read on its page too.
do
    local savedPromise, savedCitizen = promise, Citizen
    promise = { new = function() return { resolve = function(self, value) self.value, self.done = value, true end } end }
    Citizen = { Await = function(p) return p end }

    local first = TR.ui.probeFrame({ 0.25, 0.5 })
    local probe = T.lastNui('capture:probe')
    check('own: a frame probe goes to its page', T.nuiCallbacks['capture:result'] ~= nil and probe ~= nil
        and probe.data.id == 1 and probe.data.points[1] == 0.25 and probe.data.points[2] == 0.5 and not first.done)
    T.nui('capture:result', { id = 1.0, hits = '1' })
    check('own: its answer comes back (float id)', first.done and first.value == '1')
    T.nui('capture:result', { id = 1, hits = '0' })
    check('own: an answer twice changes nothing', first.value == '1')

    local second = TR.ui.probeFrame({ 0.1, 0.1 })
    check('own: probes are numbered', T.lastNui('capture:probe').data.id == 2)
    T.nui('capture:result', { id = 2 })
    check('own: a frame that couldn\'t be read is false', second.done and second.value == false)
    T.nui('capture:result', 'junk')
    T.nui('capture:result', { id = 'x', hits = '1' })

    promise, Citizen = savedPromise, savedCitizen
end

TR.ui.menu.show('tr_fraud:atm')
for _, fn in ipairs(T.handlers.onResourceStop or {}) do fn('tr_fraud') end
check('own: stopping with the menu open gives focus back', T.focus[1] == false)

-- No page: tr_ui ---------------------------------------------------------------------------------

local sent = {}
T.exports.tr_ui = setmetatable({}, { __index = function(_, name)
    return function(_, ...) sent[#sent + 1] = { name = name, args = table.pack(...) } end
end })

meta.tr_minigames = {}
boot('tr_minigames', { tr_ui = 'started' })
TR.ui.menu.register('tr_minigames:x', { title = 'X', items = {} })
TR.ui.hud.set({ hint = { text = 'Pick the lock' } })
check('no page: goes to tr_ui', #sent == 2 and sent[1].name == 'registerMenu' and sent[2].name == 'setHud')
check('no page: takes no NUI callbacks', next(T.nuiCallbacks) == nil and #T.nuiMessages == 0)
sent = {}
TR.ui.sound.register({ mg_beep = { files = { 'sounds/beep.wav' } } })
TR.ui.sound.play('mg_beep')
TR.ui.sound.play('tick')
check('no page: its sounds and tr_ui\'s go to tr_ui', #sent == 3 and sent[1].name == 'registerSounds' and sent[2].name == 'playSound'
    and sent[2].args[1] == 'mg_beep' and sent[3].args[1] == 'tick' and #T.nuiMessages == 0)

boot('tr_minigames', {})
local ok, err = pcall(TR.ui.hud.set, { hint = { text = 'x' } })
check('no page, no tr_ui: says so', not ok and tostring(err):find('tr_ui is not running', 1, true) ~= nil)

-- tr_ui has a page of its own, but it is the one drawing for everyone else.
meta.tr_ui = { ui_page = 'web/dist/index.html' }
sent = {}
boot('tr_ui', { tr_ui = 'started' })
TR.ui.hud.hide()
check('tr_ui itself: its exports, not tr_core\'s page', #sent == 1 and sent[1].name == 'hideHud' and T.nuiCallbacks['tr:ready'] == nil)

-- tr_core_version ------------------------------------------------------------------------------------

local function bootsWith(has, needs)
    meta.tr_core = { version = has }
    meta.tr_x = { tr_core_version = needs }
    T.resource = 'tr_x'
    local okBoot, msg = pcall(T.boot, 'client', {})
    return okBoot, msg
end

check('version: same is fine', (bootsWith('1.1.0', '1.1.0')))
check('version: newer is fine', (bootsWith('1.2.0', '1.1.0')) and (bootsWith('2.0', '1.9.9')) and (bootsWith('1.10.0', '1.9.0')))
local okOld, msg = bootsWith('1.0.0', '1.1.0')
check('version: older stops it, and says what to do', not okOld and msg:find('tr_x needs tr_core 1.1.0 or newer, but this server has tr_core 1.0.0: update tr_core', 1, true) ~= nil)
check('version: older, by a patch', not (bootsWith('1.1.0', '1.1.1')))
local okUse, useMsg = pcall(function() return TR.locale end)
check('version: older, and the rest of the resource says the same', not okUse and tostring(useMsg):find('tr_x needs tr_core 1.1.1 or newer', 1, true) ~= nil)
meta.tr_x = {}
T.resource = 'tr_x'
check('version: nothing asked, nothing checked', (pcall(T.boot, 'client', {})))

GetResourceMetadata = metadata
T.exports.tr_ui = nil
T.done('ui')
