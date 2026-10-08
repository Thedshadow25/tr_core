-- Helpers shared by every framework bridge (loaded once per resource and passed to the provider file).

---@class TRFrameworkShared
local shared = {}

---Resolves a TR account name to the framework's account name.
---Override per server with `setr tr:account:<name> "<framework account>"`, e.g. tr:account:dirty "blackmoney".
---@param defaults table<string, string?>
---@param name TRAccount
---@return string?
function shared.account(defaults, name)
    local override = GetConvar(('tr:account:%s'):format(name), '')
    if override ~= '' then return override end
    return defaults[name]
end

---Ace-based staff group used by QBCore and Qbox (`add_ace group.admin admin allow`).
---@param src integer
---@return string
function shared.aceGroup(src)
    for _, group in ipairs({ 'god', 'admin', 'mod' }) do
        if IsPlayerAceAllowed(src, group) then return group end
    end
    return 'user'
end

---Normalizes a QBCore / Qbox job table.
---@return TRJob?
function shared.qbJob(job)
    if not job then return end

    local grade = job.grade or {}

    return {
        name = job.name,
        label = job.label,
        grade = grade.level or 0,
        gradeName = grade.name,
        gradeLabel = grade.name,
        salary = job.payment or grade.payment or 0,
        onDuty = job.onduty == true,
        isBoss = (job.isboss or grade.isboss) == true,
    }
end

---Normalizes a QBCore / Qbox gang table.
---@return TRGang?
function shared.qbGang(gang)
    if not gang or gang.name == 'none' then return end

    local grade = gang.grade or {}

    return {
        name = gang.name,
        label = gang.label,
        grade = grade.level or 0,
        gradeName = grade.name,
        isBoss = (gang.isboss or grade.isboss) == true,
    }
end

local function sameJob(a, b)
    if a == nil or b == nil then return a == b end
    return a.name == b.name and a.grade == b.grade and a.onDuty == b.onDuty
end

---Server lifecycle emitter. Frameworks fire overlapping events (logout + drop, repeated job syncs);
---this turns them into exactly one tr:playerLoaded / tr:playerUnloaded / tr:jobUpdated each.
---@param getJob fun(src: integer): TRJob?
---@param loadedPlayers integer[] players already loaded when tr_core starts
function shared.serverEmitter(getJob, loadedPlayers)
    local jobs, loaded = {}, {}

    for _, src in ipairs(loadedPlayers) do
        loaded[src] = true
        jobs[src] = getJob(src)
    end

    local emitter = {}

    function emitter.loaded(src)
        if loaded[src] then return end
        loaded[src] = true
        jobs[src] = getJob(src)
        TriggerEvent('tr:playerLoaded', src)
    end

    function emitter.unloaded(src)
        if not loaded[src] then return end
        loaded[src], jobs[src] = nil, nil
        TriggerEvent('tr:playerUnloaded', src)
    end

    ---@param job TRJob?
    function emitter.job(src, job)
        if not loaded[src] or sameJob(job, jobs[src]) then return end
        local last = jobs[src]
        jobs[src] = job
        TriggerEvent('tr:jobUpdated', src, job, last)
    end

    AddEventHandler('playerDropped', function()
        emitter.unloaded(source)
    end)

    return emitter
end

---Client lifecycle emitter, same guarantees as serverEmitter.
---@param getJob fun(): TRJob?
---@param isLoaded fun(): boolean
function shared.clientEmitter(getJob, isLoaded)
    local loaded = isLoaded()
    local job = loaded and getJob() or nil
    local emitter = {}

    function emitter.loaded()
        -- The framework updates its player data in its own handler for the same event; wait for it.
        TR.utils.waitFor(isLoaded, 10000)
        if loaded then return end
        loaded, job = true, getJob()
        TriggerEvent('tr:playerLoaded')
    end

    function emitter.unloaded()
        if not loaded then return end
        loaded, job = false, nil
        TriggerEvent('tr:playerUnloaded')
    end

    ---@param newJob TRJob?
    function emitter.job(newJob)
        if not loaded or sameJob(newJob, job) then return end
        local last = job
        job = newJob
        TriggerEvent('tr:jobUpdated', newJob, last)
    end

    return emitter
end

return shared
