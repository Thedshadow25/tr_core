---'dirty' is black_money on ESX. QBCore/Qbox have no dirty account unless mapped with
---`setr tr:account:dirty "<money type>"`; until then it reads 0 and add/remove return false.
---@alias TRAccount 'cash' | 'bank' | 'dirty'

---@class TRJob
---@field name string
---@field label string
---@field grade integer
---@field gradeName string
---@field gradeLabel string
---@field salary integer
---@field onDuty boolean
---@field isBoss boolean

---Gangs exist on QBCore and Qbox; on ESX getGang always returns nil.
---@class TRGang
---@field name string
---@field label string
---@field grade integer
---@field gradeName string
---@field isBoss boolean

---Job / gang filter accepted by hasJob and hasGang:
---  'police'                          any grade
---  { 'police', 'sheriff' }           any of these, any grade
---  { police = 2, sheriff = 0 }       job with a minimum grade
---@alias TRJobFilter string | string[] | table<string, integer>

---@class TRPlayerShared
local player = {}

player.accounts = { cash = true, bank = true, dirty = true }

---@param job TRJob | TRGang | nil
---@param filter TRJobFilter
---@param requireDuty? boolean ignored for gangs
---@return boolean
function player.matchJob(job, filter, requireDuty)
    if not job then return false end
    if requireDuty and not job.onDuty then return false end

    if type(filter) == 'string' then return job.name == filter end

    if filter[1] then
        for i = 1, #filter do
            if filter[i] == job.name then return true end
        end
        return false
    end

    local minGrade = filter[job.name]
    return minGrade ~= nil and job.grade >= minGrade
end

return player
