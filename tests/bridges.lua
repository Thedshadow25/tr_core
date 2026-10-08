-- Framework / inventory / target bridge tests against mocks shaped like the real exports.
local check = T.check

---------------------------------------------------------------------------------------------------
-- Shared QBCore / Qbox player data
---------------------------------------------------------------------------------------------------

local function qbPlayerData()
    return {
        source = 1,
        citizenid = 'ABC123',
        charinfo = { firstname = 'John', lastname = 'Doe' },
        job = { name = 'police', label = 'Police', onduty = true, payment = 50, isboss = false, grade = { name = 'Officer', level = 2 } },
        gang = { name = 'ballas', label = 'Ballas', grade = { name = 'OG', level = 3, isboss = true } },
        money = { cash = 100, bank = 1000, crypto = 5 },
        items = {
            [1] = { name = 'water', amount = 3, slot = 1, info = {} },
            [2] = { name = 'weed', amount = 2, slot = 2, info = { quality = 90 } },
            [5] = { name = 'weed', amount = 4, slot = 5, info = { quality = 90 } },
            [6] = { name = 'weed', amount = 1, slot = 6, info = { quality = 10 } },
        },
    }
end

local function qbMoneyFunctions(data)
    return {
        AddMoney = function(moneyType, amount)
            if not data.money[moneyType] then return false end
            data.money[moneyType] = data.money[moneyType] + amount
            return true
        end,
        RemoveMoney = function(moneyType, amount)
            if not data.money[moneyType] then return false end
            data.money[moneyType] = data.money[moneyType] - amount
            return true
        end,
    }
end

local function mockQBCore(data)
    local player = { PlayerData = data, Functions = qbMoneyFunctions(data) }

    local QBCore = {
        Functions = {
            GetPlayer = function(src) return src == 1 and player or nil end,
            GetPlayers = function() return { 1 } end,
            GetPlayerByCitizenId = function(id) return id == data.citizenid and player or nil end,
            GetPlayerData = function() return data end,
            Notify = function(...) T.lastNotify = table.pack(...) end,
            CreateUseableItem = function(item, cb) T.usable[item] = cb end,
        },
        Shared = { Items = {
            water = { name = 'water', label = 'Water', weight = 500, unique = false },
            weed = { name = 'weed', label = 'Weed', weight = 10, unique = false },
            phone = { name = 'phone', label = 'Phone', weight = 700, unique = true },
        } },
    }

    T.exports['qb-core'] = { GetCoreObject = function() return QBCore end }
    T.usable = {}
    return player
end

local function testPlayerServer(label)
    local p = TR.player
    check(label .. ' identifier', p.getIdentifier(1) == 'ABC123')
    check(label .. ' name', p.getName(1) == 'John Doe')

    local job = p.getJob(1)
    check(label .. ' job normalized', job.name == 'police' and job.grade == 2 and job.gradeName == 'Officer'
        and job.salary == 50 and job.onDuty == true and job.isBoss == false)
    check(label .. ' hasJob', p.hasJob(1, { police = 2 }) and not p.hasJob(1, { police = 3 }) and p.hasJob(1, 'police', true))

    local gang = p.getGang(1)
    check(label .. ' gang', gang.name == 'ballas' and gang.grade == 3 and gang.isBoss == true)
    check(label .. ' hasGang', p.hasGang(1, { 'ballas' }) and not p.hasGang(1, 'vagos'))

    check(label .. ' getMoney', p.getMoney(1, 'cash') == 100 and p.getMoney(1, 'bank') == 1000)
    check(label .. ' addMoney', p.addMoney(1, 'bank', 50) and p.getMoney(1, 'bank') == 1050)
    check(label .. ' removeMoney', p.removeMoney(1, 'cash', 40) and p.getMoney(1, 'cash') == 60)
    check(label .. ' removeMoney insufficient', not p.removeMoney(1, 'cash', 1000) and p.getMoney(1, 'cash') == 60)
    check(label .. ' dirty unsupported', p.getMoney(1, 'dirty') == 0 and p.addMoney(1, 'dirty', 5) == false)
    check(label .. ' offline player', p.getMoney(2, 'cash') == 0 and not p.isLoaded(2) and p.getJob(2) == nil)
    check(label .. ' getPlayers', #p.getPlayers() == 1 and p.getPlayers()[1] == 1)
    check(label .. ' getSource', p.getSource('ABC123') == 1 and p.getSource('nope') == nil)

    T.aces[1] = { admin = true }
    check(label .. ' isAdmin', p.isAdmin(1) and p.getGroup(1) == 'admin')
    T.aces[1] = {}
    check(label .. ' not admin', not p.isAdmin(1) and p.getGroup(1) == 'user')
    T.aces[1] = { ['tr.admin'] = true }
    check(label .. ' tr.admin ace', p.isAdmin(1))
    T.aces[1] = nil
end

---------------------------------------------------------------------------------------------------
-- QBCore server
---------------------------------------------------------------------------------------------------

do
    local data = qbPlayerData()
    local player = mockQBCore(data)
    T.boot('server', { ['qb-core'] = 'started', ['qb-inventory'] = 'started' })
    check('qb detected', TR.system('framework') == 'qb' and TR.system('inventory') == 'qb_inventory')

    testPlayerServer('qb')

    T.convars['tr:account:dirty'] = 'crypto'
    check('qb dirty mapped by convar', TR.player.getMoney(1, 'dirty') == 5)
    T.convars['tr:account:dirty'] = nil

    -- lifecycle: tr_core registers the events once; player 1 is already loaded at that point
    TR.player.bridge.registerEvents()
    TriggerEvent('QBCore:Server:PlayerLoaded', player)
    check('qb no duplicate load for seeded player', T.count('tr:playerLoaded') == 0)

    TriggerEvent('QBCore:Server:OnJobUpdate', 1, data.job)
    check('qb identical job sync ignored', T.count('tr:jobUpdated') == 0)

    data.job = { name = 'police', label = 'Police', onduty = true, payment = 80, grade = { name = 'Sergeant', level = 3 } }
    TriggerEvent('QBCore:Server:OnJobUpdate', 1, data.job)
    local fired = T.fired['tr:jobUpdated']
    check('qb job change', T.count('tr:jobUpdated') == 1 and fired[1][2].grade == 3 and fired[1][3].grade == 2)

    TriggerEvent('QBCore:Server:SetDuty', 1, false)
    check('qb duty change', T.count('tr:jobUpdated') == 2 and T.fired['tr:jobUpdated'][2][2].onDuty == false)

    TriggerEvent('QBCore:Server:OnPlayerUnload', 1)
    T.fromClient(1, 'playerDropped')
    check('qb unload once', T.count('tr:playerUnloaded') == 1)

    TriggerEvent('QBCore:Server:PlayerLoaded', player)
    check('qb load after unload', T.count('tr:playerLoaded') == 1)

    -- qb-inventory
    local invCalls = {}
    local slots = data.items
    T.exports['qb-inventory'] = {
        GetItemCount = function(_, src, item)
            local n = 0
            for _, s in pairs(slots) do if s.name == item then n = n + s.amount end end
            return n
        end,
        CanAddItem = function(_, src, item, amount) return amount <= 10 end,
        AddItem = function(_, src, item, amount, slot, info, reason)
            invCalls[#invCalls + 1] = { 'add', item, amount, info, reason }
            return true
        end,
        RemoveItem = function(_, src, item, amount, slot)
            invCalls[#invCalls + 1] = { 'remove', item, amount, slot }
            if slot then slots[slot].amount = slots[slot].amount - amount end
            return true
        end,
        OpenInventory = function(_, src, id, stashData) invCalls[#invCalls + 1] = { 'open', id, stashData } end,
        CloseInventory = function(_, src) invCalls[#invCalls + 1] = { 'close', src } end,
    }

    local inv = TR.inventory
    check('qbinv count', inv.getCount(1, 'water') == 3 and inv.getCount(1, 'weed') == 7)
    check('qbinv count metadata', inv.getCount(1, 'weed', { quality = 90 }) == 6)
    check('qbinv canCarry', inv.canCarry(1, 'water', 5) and not inv.canCarry(1, 'water', 50))

    local ok = inv.addItem(1, 'water', 2, { purity = 1 })
    check('qbinv addItem', ok and invCalls[1][1] == 'add' and invCalls[1][4].purity == 1 and invCalls[1][5] == 'tr_example')
    check('qbinv addItem itembox', T.clientEvents[#T.clientEvents].name == 'qb-inventory:client:ItemBox')

    local full, reason = inv.addItem(1, 'water', 50)
    check('qbinv addItem full', not full and reason == 'inventory_full')
    local bad, badReason = inv.addItem(1, 'nope', 1)
    check('qbinv addItem unknown', not bad and badReason == 'invalid_item')

    invCalls = {}
    check('qbinv removeItem metadata spans slots', inv.removeItem(1, 'weed', 5, { quality = 90 })
        and #invCalls == 2 and slots[2].amount + slots[5].amount == 1)
    check('qbinv removeItem not enough', not inv.removeItem(1, 'weed', 50))
    check('qbinv getItem', inv.getItem('phone').stack == false and inv.getItem('water').label == 'Water')

    -- slots and metadata (qb item names are lowercase; the item list is saved with SetPlayerData)
    local saved
    player.Functions.SetPlayerData = function(key, value) saved = { key, value } end
    local weed = inv.getSlots(1, 'WEED')
    check('qbinv getSlots', #weed == 3 and weed[1].slot == 2 and weed[3].slot == 6 and weed[3].metadata.quality == 10)
    check('qbinv getSlots none', #inv.getSlots(1, 'phone') == 0)
    check('qbinv setMetadata', inv.setMetadata(1, 6, { quality = 55 }) and slots[6].info.quality == 55 and saved[1] == 'items')
    check('qbinv setMetadata empty slot', inv.setMetadata(1, 9, {}) == false and inv.setMetadata(1, 'x', {}) == false)

    -- Item use: qb-inventory calls the usable item with the used slot's item (metadata is `info`).
    local used
    inv.onUse('laptop', function(src, slot) used = { src, slot } end)
    T.usable.laptop(1, { name = 'laptop', slot = 4, amount = 1, info = { serial = 'TR-1' } })
    check('qbinv onUse: the slot and its info', used and used[1] == 1 and used[2].slot == 4 and used[2].count == 1
        and used[2].metadata.serial == 'TR-1')

    -- stashes: groups, owner and client request validation
    invCalls = {}
    inv.registerStash('evidence', { label = 'Evidence', slots = 50, weight = 100000, groups = { police = 0 }, coords = vector3(10, 0, 0) })
    inv.registerStash('locker', { label = 'Locker', slots = 10, weight = 5000, owner = true })
    inv.openStash(1, 'locker')
    check('qbinv personal stash id', invCalls[1][2] == 'locker:ABC123' and invCalls[1][3].maxweight == 5000)

    T.coords = { [1] = vector3(100, 0, 0) }
    T.timer = T.timer + 1000
    T.fromClient(1, 'tr_example:tr_openStash', 'evidence')
    check('qbinv stash too far', #invCalls == 1)
    T.coords = { [1] = vector3(11, 0, 0) }
    T.timer = T.timer + 1000
    T.fromClient(1, 'tr_example:tr_openStash', 'evidence')
    check('qbinv stash open near', #invCalls == 2 and invCalls[2][2] == 'evidence')

    data.job = { name = 'ems', label = 'EMS', onduty = true, grade = { name = 'Medic', level = 0 } }
    data.gang = { name = 'none' }
    T.timer = T.timer + 1000
    T.fromClient(1, 'tr_example:tr_openStash', 'evidence')
    check('qbinv stash wrong job', #invCalls == 2)

    T.timer = T.timer + 1000
    T.fromClient(1, 'tr_example:tr_openStash', 12345)
    check('qbinv stash invalid payload flagged', #invCalls == 2 and T.count('tr:playerFlagged') == 1)
end

---------------------------------------------------------------------------------------------------
-- Qbox server
---------------------------------------------------------------------------------------------------

do
    local data = qbPlayerData()
    local player = { PlayerData = data }
    local money = qbMoneyFunctions(data)

    T.exports.qbx_core = {
        GetPlayer = function(_, src) return src == 1 and player or nil end,
        GetMoney = function(_, src, moneyType)
            if src ~= 1 then return false end
            return data.money[moneyType] or false
        end,
        AddMoney = function(_, src, moneyType, amount) return src == 1 and money.AddMoney(moneyType, amount) end,
        RemoveMoney = function(_, src, moneyType, amount) return src == 1 and money.RemoveMoney(moneyType, amount) end,
        GetPlayersData = function() return { data } end,
        GetPlayerByCitizenId = function(_, id) return id == data.citizenid and player or nil end,
        CreateUseableItem = function(_, item, cb) T.usable[item] = cb end,
    }
    T.usable = {}

    -- qbx_core `provide`s qb-core, so both can look started; Qbox must win.
    T.boot('server', { qbx_core = 'started', ['qb-core'] = 'started', ox_inventory = 'started' })
    check('qbx detected first', TR.system('framework') == 'qbx')

    testPlayerServer('qbx')

    -- Item use: ox_inventory calls Qbox's usable item with the used slot.
    local used
    TR.inventory.onUse('laptop', function(src, slot) used = { src, slot } end)
    T.usable.laptop(1, { name = 'laptop', label = 'Laptop', slot = 7, count = 1, metadata = { serial = 'TR-7' }, weight = 2000 })
    check('qbx onUse: the slot and its metadata', used and used[1] == 1 and used[2].slot == 7 and used[2].metadata.serial == 'TR-7')

    TR.player.bridge.registerEvents()
    TriggerEvent('qbx_core:server:playerLoggedOut', 1)
    TriggerEvent('QBCore:Server:OnPlayerUnload', 1)
    check('qbx logout + unload fires once', T.count('tr:playerUnloaded') == 1)
end

---------------------------------------------------------------------------------------------------
-- ESX server (lifecycle dedupe)
---------------------------------------------------------------------------------------------------

do
    local job = { name = 'police', label = 'Police', grade = 1, grade_name = 'boss', grade_label = 'Chief', grade_salary = 200 }
    local xPlayer = {
        source = 1,
        getIdentifier = function() return 'char1:abc' end,
        getName = function() return 'Jane Roe' end,
        getJob = function() return job end,
        getGroup = function() return 'admin' end,
        getAccount = function(name) return ({ money = { money = 10 }, bank = { money = 20 }, black_money = { money = 30 } })[name] end,
    }

    T.exports.es_extended = { getSharedObject = function() return {
        GetPlayerFromId = function(src) return src == 1 and xPlayer or nil end,
        GetExtendedPlayers = function() return { xPlayer } end,
        GetPlayerFromIdentifier = function(id) return id == 'char1:abc' and xPlayer or nil end,
        RegisterUsableItem = function(item, cb) T.usable[item] = cb end,
    } end }
    T.usable = {}

    T.boot('server', { es_extended = 'started', ox_inventory = 'started' })
    local p = TR.player

    -- Item use: ox_inventory calls ESX.UseItem(source, name, slot data).
    local used
    TR.inventory.onUse('laptop', function(src, slot) used = { src, slot } end)
    T.usable.laptop(1, 'laptop', { name = 'laptop', slot = 2, count = 1, metadata = { serial = 'TR-2' } })
    check('esx onUse: the slot and its metadata', used and used[1] == 1 and used[2].slot == 2 and used[2].metadata.serial == 'TR-2')
    used = nil
    T.usable.laptop(1, 'laptop', { name = 'laptop', slot = 3, count = 1 })
    check('esx onUse: no metadata is an empty table', used and used[2].slot == 3 and next(used[2].metadata) == nil)
    used = nil
    T.usable.laptop(1, 'laptop') -- an inventory that doesn't say which slot
    check('esx onUse: without a slot the handler is not called', used == nil)
    check('esx job boss', p.getJob(1).isBoss and p.getJob(1).gradeLabel == 'Chief')
    check('esx no gang', p.getGang(1) == nil and not p.hasGang(1, 'ballas'))
    check('esx dirty money', p.getMoney(1, 'dirty') == 30)
    check('esx admin', p.isAdmin(1))

    p.bridge.registerEvents()
    TriggerEvent('esx:playerDropped', 1)
    T.fromClient(1, 'playerDropped')
    check('esx drop fires once', T.count('tr:playerUnloaded') == 1)
end

---------------------------------------------------------------------------------------------------
-- Clients
---------------------------------------------------------------------------------------------------

do
    local data = qbPlayerData()
    mockQBCore(data)
    LocalPlayer.state.isLoggedIn = true

    T.boot('client', { ['qb-core'] = 'started', ['qb-inventory'] = 'started', ['qb-target'] = 'started' })
    local p = TR.player
    check('qb client job', p.getJob().grade == 2 and p.hasJob('police'))
    check('qb client gang', p.hasGang({ ballas = 3 }))
    check('qb client money', p.getMoney('bank') == 1000 and p.getMoney('dirty') == 0)

    TR.notify.send({ title = 'Bank', description = 'Paid', type = 'warning' })
    check('qb client notify', T.lastNotify[1] == 'Bank: Paid' and T.lastNotify[2] == 'primary')

    check('qbinv client count', TR.inventory.getCount('weed') == 7 and TR.inventory.hasItem('weed', 5, { quality = 90 }))
    TR.inventory.openStash('locker')
    check('qbinv client open request', T.serverEvents[1].name == 'tr_example:tr_openStash')

    -- lifecycle
    p.bridge.registerEvents()
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    check('qb client no duplicate load', T.count('tr:playerLoaded') == 0)
    TriggerEvent('QBCore:Client:SetDuty', false)
    check('qb client duty', T.count('tr:jobUpdated') == 1 and T.fired['tr:jobUpdated'][1][1].onDuty == false)

    -- qb-target conversion
    local calls = {}
    T.exports['qb-target'] = setmetatable({}, { __index = function(_, name)
        return function(_, ...) calls[#calls + 1] = { name = name, args = table.pack(...) } end
    end })

    local selected
    local zone = TR.target.addBoxZone({
        coords = vector3(10, 20, 30), size = vector3(2, 4, 6), rotation = 90,
        options = {
            { name = 'tr_example:open', label = 'Open', icon = 'fa-solid fa-box', distance = 3.0,
              groups = { 'police', 'ems' }, items = { lockpick = 1 },
              onSelect = function(d) selected = d end },
        },
    })

    local box = calls[1].args
    check('qbt box zone', calls[1].name == 'AddBoxZone' and box[1] == zone and box[3] == 4 and box[4] == 2
        and box[5].heading == 90 and box[5].minZ == 27 and box[5].maxZ == 33)

    local option = box[6].options[1]
    check('qbt option converted', box[6].distance == 3.0 and option.label == 'Open'
        and option.job.police == 0 and option.job.ems == 0 and option.item[1] == 'lockpick')

    option.action(5)
    check('qbt onSelect', selected and selected.entity == 5 and selected.name == 'tr_example:open')

    TR.target.addModel('prop_atm_01', { { name = 'tr_example:atm', label = 'Use ATM', serverEvent = 'tr_example:atm' } })
    check('qbt model server event', calls[2].name == 'AddTargetModel' and calls[2].args[2].options[1].type == 'server')

    TR.target.removeModel('prop_atm_01', 'tr_example:atm')
    check('qbt remove by name -> label', calls[3].name == 'RemoveTargetModel' and calls[3].args[2] == 'Use ATM')

    TR.target.addEntity(7, { label = 'Talk', event = 'tr_example:talk' })
    check('qbt netId -> entity', calls[4].name == 'AddTargetEntity' and calls[4].args[1][1] == 1007)

    TR.target.addGlobalVehicle({ { label = 'Lock', command = 'lock' } })
    check('qbt global', calls[5].name == 'AddGlobalVehicle' and calls[5].args[1].options[1].type == 'command')

    local before = #calls
    TriggerEvent('onResourceStop', 'other_resource')
    check('qbt ignores other resource stop', #calls == before)

    TriggerEvent('onResourceStop', 'tr_example')
    local removed = {}
    for i = before + 1, #calls do removed[calls[i].name] = true end
    check('qbt cleanup on stop', removed.RemoveZone and removed.RemoveTargetModel and removed.RemoveTargetEntity and removed.RemoveGlobalVehicle)
end

do
    local data = qbPlayerData()
    T.exports.qbx_core = {
        GetPlayerData = function() return data end,
        Notify = function(_, ...) T.lastNotify = table.pack(...) end,
    }
    LocalPlayer.state.isLoggedIn = true

    T.boot('client', { qbx_core = 'started', ox_inventory = 'started', ox_target = 'started' })
    check('qbx client job', TR.player.getJob().name == 'police' and TR.player.getIdentifier() == 'ABC123')

    TR.notify.send({ title = 'Bank', description = 'Paid', type = 'info' })
    check('qbx client notify', T.lastNotify[1] == 'Bank' and T.lastNotify[2] == 'inform' and T.lastNotify[4] == 'Paid')

    TR.notify.send('Hello')
    check('qbx client notify string', T.lastNotify[1] == 'Hello' and T.lastNotify[4] == nil)
end

---------------------------------------------------------------------------------------------------
-- Vehicle keys (no keys script: 'none' fallback)
---------------------------------------------------------------------------------------------------

do
    GetVehicleNumberPlateText = function() return ' TR 123 ' end

    T.boot('server', { es_extended = 'started', ox_inventory = 'started' })
    check('keys falls back to none', TR.system('keys') == 'none')
    check('keys none: everyone has keys', TR.keys.hasKeys(1, 5000) == true)
    check('keys plate trimmed', TR.keys.plate(5000) == 'TR 123')
    TR.keys.giveKeys(1, 5000)
    check('keys missing vehicle', TR.keys.hasKeys(1, 0) == false)

    T.boot('client', { es_extended = 'started', ox_inventory = 'started', ox_target = 'started' })
    check('keys client none', TR.keys.hasKeys(5000) == true)
end

---------------------------------------------------------------------------------------------------
-- Vehicle keys scripts: each mock records its calls; the player has keys to 'TR 123' only
---------------------------------------------------------------------------------------------------

do
    GetVehicleNumberPlateText = function(vehicle) return vehicle == 5000 and ' TR 123 ' or 'OTHER' end

    -- [1] resource, [2] provider, [3] client has, [4] server has, [5] give, [6] remove,
    -- [7] true when the script takes the vehicle entity instead of the plate.
    local scripts = {
        { 'zyke_vehiclekeys', 'zyke_vehiclekeys', 'HasKey', 'HasKey', 'GiveKey', 'RemoveKey' },
        { 'qbx_vehiclekeys', 'qbx_vehiclekeys', 'HasKeys', 'HasKeys', 'GiveKeys', 'RemoveKeys', true },
        { 'wasabi_carlock', 'wasabi_carlock', 'HasKey', 'HasKey', 'GiveKey', 'RemoveKey' },
        { 'MrNewbVehicleKeys', 'mrnewb_vehiclekeys', 'HasKeysByPlate', 'HasKeysByPlate', 'GiveKeysByPlate', 'RemoveKeysByPlate' },
        { 'Renewed-Vehiclekeys', 'renewed_vehiclekeys', 'hasKey', 'hasKey', 'addKey', 'removeKey' },
        { 'qb-vehiclekeys', 'qb_vehiclekeys', 'HasKeys', 'HasKeys', 'GiveKeys', 'RemoveKeys' },
    }

    for _, s in ipairs(scripts) do
        local resource, provider, clientHas, serverHas, give, remove, byEntity = table.unpack(s)
        local target = byEntity and 5000 or 'TR 123'
        local calls = {}

        local function mock(context)
            local fns = {}
            fns[context == 'client' and clientHas or serverHas] = function(_, ...)
                local args = { ... }
                local key = context == 'client' and args[1] or args[2]
                return key == target
            end
            fns[give] = function(_, ...) calls[#calls + 1] = { give, ... } end
            fns[remove] = function(_, ...) calls[#calls + 1] = { remove, ... } end
            T.exports[resource] = fns
        end

        mock('server')
        T.boot('server', { es_extended = 'started', ox_inventory = 'started', [resource] = 'started', ['qb-vehiclekeys'] = 'stopped' })
        check(provider .. ' detected', TR.system('keys') == provider)
        check(provider .. ' server has keys', TR.keys.hasKeys(1, 5000) == true and TR.keys.hasKeys(1, 5001) == false)

        TR.keys.giveKeys(1, 5000)
        TR.keys.removeKeys(1, 5000)
        check(provider .. ' give', calls[1] and calls[1][1] == give and calls[1][2] == 1 and calls[1][3] == target)
        check(provider .. ' remove', calls[2] and calls[2][1] == remove and calls[2][2] == 1 and calls[2][3] == target)

        mock('client')
        T.boot('client', { es_extended = 'started', ox_inventory = 'started', ox_target = 'started', [resource] = 'started' })
        check(provider .. ' client has keys', TR.keys.hasKeys(5000) == true and TR.keys.hasKeys(5001) == false)
        T.exports[resource] = nil
    end

    T.boot('server', { es_extended = 'started', ox_inventory = 'started', ['qb-vehiclekeys'] = 'started' }, { ['tr:keys'] = 'wasabi_carlock' })
    check('keys convar override', TR.system('keys') == 'wasabi_carlock')
end

---------------------------------------------------------------------------------------------------
-- ox_inventory slots and metadata
---------------------------------------------------------------------------------------------------

do
    local inventory = { [3] = { slot = 3, name = 'WEAPON_PETROLCAN', count = 1, metadata = { durability = 40, ammo = 40 } },
        [1] = { slot = 1, name = 'WEAPON_PETROLCAN', count = 1 } }
    T.exports.ox_inventory = {
        Search = function(_, src, kind, item)
            local found = {}
            for _, data in pairs(inventory) do if kind == 'slots' and data.name == item then found[#found + 1] = data end end
            return found
        end,
        GetSlot = function(_, src, slot) return inventory[slot] end,
        SetMetadata = function(_, src, slot, metadata) inventory[slot].metadata = metadata end,
    }
    T.boot('server', { es_extended = 'started', ox_inventory = 'started' })
    local cans = TR.inventory.getSlots(1, 'WEAPON_PETROLCAN')
    check('ox getSlots in slot order', #cans == 2 and cans[1].slot == 1 and cans[2].metadata.durability == 40)
    check('ox getSlots no metadata', next(cans[1].metadata) == nil)
    check('ox setMetadata', TR.inventory.setMetadata(1, 3, { durability = 90, ammo = 90 }) and inventory[3].metadata.ammo == 90)
    check('ox setMetadata empty slot', TR.inventory.setMetadata(1, 7, {}) == false)
    T.exports.ox_inventory = nil
end

---------------------------------------------------------------------------------------------------
-- Fuel: state bag scripts (ox_fuel, none) work on the server; client export scripts go via the owner
---------------------------------------------------------------------------------------------------

do
    local bags, native = {}, {}
    Entity = function(vehicle)
        bags[vehicle] = bags[vehicle] or {}
        local state = setmetatable({}, { __index = bags[vehicle] })
        function state:set(key, value, replicate) bags[vehicle][key] = value; bags[vehicle].__replicated = replicate end
        return { state = state }
    end
    GetVehicleFuelLevel = function(vehicle) return native[vehicle] or 65.0 end
    SetVehicleFuelLevel = function(vehicle, value) native[vehicle] = value end
    NetworkGetEntityOwner = function(vehicle) return vehicle == 5000 and 7 or -1 end
    NetworkGetNetworkIdFromEntity = function(vehicle) return vehicle - 1000 end
    NetworkDoesEntityExistWithNetworkId = function(id) return id > 0 end

    -- No fuel script: tracked in the state bag, full until something takes some.
    T.boot('server', { es_extended = 'started', ox_inventory = 'started' })
    check('fuel falls back to none', TR.system('fuel') == 'none')
    check('fuel none starts full', TR.fuel.get(5000) == 100.0)
    check('fuel none take', TR.fuel.take(5000, 30) == 30.0 and TR.fuel.get(5000) == 70.0)
    check('fuel none replicated', bags[5000].__replicated == true)
    check('fuel take stops at empty', TR.fuel.take(5000, 500) == 70.0 and TR.fuel.get(5000) == 0.0)
    check('fuel take from empty', TR.fuel.take(5000, 5) == 0.0)
    check('fuel set clamps', TR.fuel.set(5000, 150) and TR.fuel.get(5000) == 100.0)
    check('fuel set rejects junk', TR.fuel.set(5000, 'lots') == false and TR.fuel.get(5000) == 100.0)
    check('fuel missing vehicle', TR.fuel.get(0) == nil and TR.fuel.set(0, 10) == false and TR.fuel.take(0, 10) == 0.0)

    T.boot('client', { es_extended = 'started', ox_inventory = 'started', ox_target = 'started' })
    bags[5002] = nil
    check('fuel client none starts full', TR.fuel.get(5002) == 100.0)
    TR.fuel.set(5002, 42)
    check('fuel client none sets bag and car', bags[5002].fuel == 42.0 and native[5002] == 42.0)

    -- ox_fuel: the state bag; before ox_fuel has set it, the client reads the car.
    bags = {}
    T.boot('server', { es_extended = 'started', ox_inventory = 'started', ox_fuel = 'started' })
    check('ox_fuel detected', TR.system('fuel') == 'ox_fuel')
    -- Not set by ox_fuel yet: ask the owner, who reads the car (as ox_fuel itself does).
    rawset(TR, 'callback', { await = function(name, src, netId) return src == 7 and 65.0 or nil end })
    check('ox_fuel server unset asks the owner', TR.fuel.get(5000) == 65.0 and TR.fuel.get(5001) == nil)
    check('ox_fuel server set', TR.fuel.set(5000, 55.5) and bags[5000].fuel == 55.5)
    check('ox_fuel server take', TR.fuel.take(5000, 5.5) == 5.5 and bags[5000].fuel == 50.0)
    T.boot('client', { es_extended = 'started', ox_inventory = 'started', ox_target = 'started', ox_fuel = 'started' })
    check('ox_fuel client reads bag', TR.fuel.get(5000) == 50.0)
    check('ox_fuel client unset reads car', TR.fuel.get(5003) == 65.0)

    -- LegacyFuel and its forks: client exports. The server asks the car's owner.
    local scripts = {
        { 'lc_fuel', 'lc_fuel' }, { 'cdn-fuel', 'cdn_fuel' }, { 'ps-fuel', 'ps_fuel' }, { 'LegacyFuel', 'legacyfuel' },
    }
    for _, s in ipairs(scripts) do
        local resource, provider = s[1], s[2]
        local levels = { [5000] = 80.0 }
        T.exports[resource] = {
            GetFuel = function(_, vehicle) return levels[vehicle] end,
            SetFuel = function(_, vehicle, value) levels[vehicle] = value end,
        }

        local started = { es_extended = 'started', ox_inventory = 'started', [resource] = 'started' }
        if resource == 'lc_fuel' then started.LegacyFuel = 'started' end   -- lc_fuel provides LegacyFuel
        T.boot('client', setmetatable({ ox_target = 'started' }, { __index = started }))
        for k, v in pairs(started) do T.resources[k] = v end
        check(provider .. ' detected', TR.system('fuel') == provider)
        check(provider .. ' client get', TR.fuel.get(5000) == 80.0)
        TR.fuel.set(5000, 60)
        check(provider .. ' client set', levels[5000] == 60.0)

        T.boot('server', started)
        local asked
        rawset(TR, 'callback', { await = function(name, src, netId)
            asked = { name, src, netId }
            return levels[netId + 1000]
        end })
        check(provider .. ' server asks the owner', TR.fuel.get(5000) == 60.0 and asked[1] == 'tr_core:fuel:get' and asked[2] == 7 and asked[3] == 4000)
        check(provider .. ' server take', TR.fuel.take(5000, 10) == 10.0)
        local sent = T.clientEvents[#T.clientEvents]
        check(provider .. ' server set goes to the owner', sent.name == 'tr_core:fuel:set' and sent.target == 7 and sent.args[1] == 4000 and sent.args[2] == 50.0)
        check(provider .. ' server no owner', TR.fuel.get(5001) == nil and TR.fuel.set(5001, 10) == false)
        T.exports[resource] = nil
    end

    T.boot('server', { es_extended = 'started', ox_inventory = 'started', ox_fuel = 'started' }, { ['tr:fuel'] = 'legacyfuel' })
    check('fuel convar override', TR.system('fuel') == 'legacyfuel')
end

---------------------------------------------------------------------------------------------------
-- Dispatch: each dispatch script gets the alert in its own shape; without one, on-duty police do
---------------------------------------------------------------------------------------------------

do
    -- 1: police on duty, 2: police off duty, 3: mechanic on duty
    local jobs = { { 'police', true }, { 'police', false }, { 'mechanic', true } }
    local asked
    local function boot(started, convars)
        local resources = { es_extended = 'started', ox_inventory = 'started' }
        for name, state in pairs(started) do resources[name] = state end
        T.boot('server', resources, convars)
        rawset(TR, 'player', {
            getPlayers = function() return { 1, 2, 3 } end,
            hasJob = function(src, filter, requireDuty)
                if requireDuty and not jobs[src][2] then return false end
                for _, job in ipairs(filter) do if job == jobs[src][1] then return true end end
                return false
            end,
        })
        asked = nil
        rawset(TR, 'callback', { await = function(name, src, coords)
            asked = { name, src, coords }
            return '<img src=x onerror=alert(1)>Alta St / Route 68'
        end })
    end
    local function alert(extra)
        local a = { coords = vector3(10, 20, 30), title = 'Suspicious activity', message = 'A laptop online', code = '10-90', name = 'tr_test', source = 1 }
        for k, v in pairs(extra or {}) do a[k] = v end
        return a
    end
    local function fired(name) local list = T.fired[name]; return list and list[#list][1] end

    -- None installed: on-duty players with the job get tr_core's notification and blip.
    boot({})
    check('dispatch falls back to none', TR.system('dispatch') == 'none')
    TR.dispatch.alert(alert())
    local sent = T.clientEvents
    check('none: only on-duty police', #sent == 1 and sent[1].name == 'tr_core:dispatch' and sent[1].target == 1)
    local payload = sent[1].args[1]
    check('none: street asked from the player', asked[1] == 'tr_core:dispatch:street' and asked[2] == 1 and asked[3] == vector3(10, 20, 30))
    check('none: street cleaned of markup', not payload.message:find('[<>=()]') and payload.message:find('Alta St / Route 68', 1, true) ~= nil)
    check('none: code before the title', payload.title == '10-90 - Suspicious activity' and payload.message:sub(1, 18) == 'A laptop online - ')
    check('none: blip defaults', payload.blip.sprite == 161 and payload.blip.color == 1 and payload.blip.radius == 0 and payload.blip.flash == false and payload.time == 5)

    T.clientEvents, asked = {}, nil
    TR.dispatch.alert(alert({ street = 'Vinewood Blvd', priority = 'high', jobs = 'mechanic', code = false, blip = { sprite = 52 } }))
    payload = T.clientEvents[1] and T.clientEvents[1].args[1]
    check('none: a given street is not asked for', asked == nil and payload.message == 'A laptop online - Vinewood Blvd')
    check('none: one job as a string', #T.clientEvents == 1 and T.clientEvents[1].target == 3)
    check('none: high priority flashes, own sprite', payload.blip.flash == true and payload.blip.sprite == 52)

    T.clientEvents, asked = {}, nil
    TR.dispatch.alert(alert({ source = false, code = false, message = false }))
    payload = T.clientEvents[1].args[1]
    check('none: no source, no street', asked == nil and payload.title == 'Suspicious activity' and payload.message == '')
    check('dispatch needs coords and a title', not pcall(TR.dispatch.alert, { title = 'x' }) and not pcall(TR.dispatch.alert, { coords = vector3(0, 0, 0) }))

    -- ps-dispatch 2.x: its notify event, which goes to everyone (its client keeps the job's).
    local metadata = GetResourceMetadata
    local psVersion = '2.2.2'
    GetResourceMetadata = function(resource, key)
        if resource == 'ps-dispatch' and key == 'version' then return psVersion end
        return metadata(resource, key)
    end
    boot({ ['ps-dispatch'] = 'started' })
    TR.dispatch.alert(alert({ street = 'Alta St' }))
    local data = fired('ps-dispatch:server:notify')
    check('ps 2: notify event', TR.system('dispatch') == 'ps_dispatch' and data ~= nil)
    check('ps 2: title, details, code', data.message == 'Suspicious activity' and data.information == 'A laptop online' and data.code == '10-90'
        and data.codeName == 'tr_test' and data.street == 'Alta St')
    check('ps 2: jobs, priority, blip', data.jobs[1] == 'police' and data.priority == 2 and data.alert.length == 5 and data.alert.sprite == 161
        and data.alert.sound == 'Lose_1st')

    -- ps-dispatch 3.x: SendTargetedAlert to the players with the job (its client checks duty).
    psVersion = '3.0.0'
    local targeted
    T.exports['ps-dispatch'] = { SendTargetedAlert = function(_, targets, d) targeted = { targets, d } end }
    boot({ ['ps-dispatch'] = 'started' })
    TR.dispatch.alert(alert({ priority = 'high' }))
    check('ps 3: targeted at the job', targeted and #targeted[1] == 2 and targeted[1][1] == 1 and targeted[1][2] == 2 and T.count('ps-dispatch:server:notify') == 0)
    check('ps 3: listed, red', targeted[2].addToList == true and targeted[2].priority == 1 and targeted[2].alert.flash == true)
    targeted = nil
    TR.dispatch.alert(alert({ jobs = { 'ambulance' } }))
    check('ps 3: nobody with the job, nothing sent', targeted == nil)
    GetResourceMetadata = metadata
    T.exports['ps-dispatch'] = nil

    -- cd_dispatch: to the clients with the job.
    boot({ cd_dispatch = 'started' })
    TR.dispatch.alert(alert({ street = 'Alta St' }))
    sent = T.clientEvents
    data = sent[1] and sent[1].args[1]
    check('cd: to the job', #sent == 2 and sent[1].name == 'cd_dispatch:AddNotification' and sent[1].target == 1 and sent[2].target == 2)
    check('cd: shape', data.job_table[1] == 'police' and data.title == '10-90 - Suspicious activity' and data.message == 'A laptop online - Alta St'
        and data.flash == 0 and type(data.unique_id) == 'string' and data.blip.time == 5 and data.blip.colour == 1)

    -- cd_dispatch3d: cd_dispatch's notification as a server event; detected before cd_dispatch.
    boot({ cd_dispatch3d = 'started', cd_dispatch = 'started' })
    TR.dispatch.alert(alert({ street = 'Alta St' }))
    data = fired('cd_dispatch:AddNotification')
    check('cd3d: detected first', TR.system('dispatch') == 'cd_dispatch3d')
    check('cd3d: server event', data and data.title == '10-90 - Suspicious activity' and #T.clientEvents == 0)

    -- qs-dispatch: its CreateDispatchCall event, blip time in milliseconds.
    boot({ ['qs-dispatch'] = 'started' })
    TR.dispatch.alert(alert({ street = 'Alta St', time = 2 }))
    data = fired('qs-dispatch:server:CreateDispatchCall')
    check('qs: shape', data and data.job[1] == 'police' and data.callLocation == vector3(10, 20, 30) and data.callCode.code == '10-90'
        and data.callCode.snippet == 'Suspicious activity' and data.message == 'A laptop online - Alta St' and data.blip.time == 120000)

    -- rcore_dispatch: its sendAlert event, blip time in seconds.
    boot({ rcore_dispatch = 'started' })
    TR.dispatch.alert(alert({ street = 'Alta St', priority = 'low' }))
    data = fired('rcore_dispatch:server:sendAlert')
    check('rcore: shape', data and data.code == '10-90' and data.default_priority == 'low' and data.type == 'alerts' and data.blip_time == 300
        and data.text == 'Suspicious activity - A laptop online - Alta St' and data.job[1] == 'police')

    -- core_dispatch: its sendAlert export; details and street as extra info.
    local core
    T.exports.core_dispatch = { sendAlert = function(_, d) core = d end }
    boot({ core_dispatch = 'started' })
    TR.dispatch.alert(alert({ street = 'Alta St', priority = 'high' }))
    check('core: shape', core and core.message == 'Suspicious activity' and core.code == '10-90' and core.priority == true and core.blip == 161
        and #core.extraInfo == 2 and core.extraInfo[2].info == 'Alta St')
    T.exports.core_dispatch = nil

    -- lb-tablet: AddDispatch once per job, time in seconds.
    local tablet = {}
    T.exports['lb-tablet'] = { AddDispatch = function(_, d) tablet[#tablet + 1] = d end }
    boot({ ['lb-tablet'] = 'started' })
    TR.dispatch.alert(alert({ street = 'Alta St', jobs = { 'police', 'sheriff' }, blip = { radius = 80 } }))
    check('lb-tablet: once per job', #tablet == 2 and tablet[1].job == 'police' and tablet[2].job == 'sheriff')
    check('lb-tablet: shape', tablet[1].time == 300 and tablet[1].location.label == 'Alta St' and tablet[1].location.coords.x == 10
        and tablet[1].priority == 'medium' and tablet[1].blip.type == 'radius' and tablet[1].blip.radius == 80)
    T.exports['lb-tablet'] = nil

    -- tk_dispatch: addCall, remove time in milliseconds; provides ps-dispatch, qs-dispatch and cd_dispatch.
    local tk
    T.exports.tk_dispatch = { addCall = function(_, d) tk = d end }
    boot({ tk_dispatch = 'started', ['ps-dispatch'] = 'started', ['qs-dispatch'] = 'started', cd_dispatch = 'started' })
    TR.dispatch.alert(alert({ street = 'Alta St' }))
    check('tk: detected over what it provides', TR.system('dispatch') == 'tk_dispatch')
    check('tk: shape', tk and tk.title == 'Suspicious activity' and tk.location == 'Alta St' and tk.removeTime == 300000 and tk.jobs[1] == 'police'
        and tk.blip.radius == nil)

    -- A dispatch script that errors doesn't break the caller.
    T.exports.tk_dispatch = { addCall = function() error('boom') end }
    boot({ tk_dispatch = 'started' })
    check('dispatch error is caught', pcall(TR.dispatch.alert, alert()))
    check('dispatch error is logged', tostring(T.logs[#T.logs]):find('tk_dispatch', 1, true) ~= nil)
    T.exports.tk_dispatch = nil

    -- origen_police: SendAlert once per job.
    local origen = {}
    T.exports.origen_police = { SendAlert = function(_, d) origen[#origen + 1] = d end }
    boot({ origen_police = 'started' })
    TR.dispatch.alert(alert({ street = 'Alta St', jobs = { 'police', 'sheriff' } }))
    check('origen: once per job', #origen == 2 and origen[2].job == 'sheriff' and origen[1].type == 'GENERAL'
        and origen[1].title == '10-90 - Suspicious activity' and origen[1].message == 'A laptop online - Alta St')
    T.exports.origen_police = nil

    -- Detection: a running dispatch script wins over a stopped copy; dispatch scripts over MDTs.
    boot({ ['ps-dispatch'] = 'stopped', cd_dispatch = 'started' })
    check('dispatch: running over a stopped copy', TR.system('dispatch') == 'cd_dispatch')
    boot({ ['ps-dispatch'] = 'stopped' })
    check('dispatch: installed but not started yet', TR.system('dispatch') == 'ps_dispatch')
    boot({ ['lb-tablet'] = 'started', origen_police = 'started', ['ps-dispatch'] = 'started' })
    check('dispatch: dispatch script over an MDT', TR.system('dispatch') == 'ps_dispatch')
    boot({ ['ps-dispatch'] = 'started' }, { ['tr:dispatch'] = 'none' })
    check('dispatch convar override', TR.system('dispatch') == 'none')
end

T.done('bridges')
