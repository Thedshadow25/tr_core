--[[
    Database access through oxmysql, plus versioned migrations.

        local rows = TR.db.query('SELECT * FROM users WHERE job = ?', { 'police' })
        local id = TR.db.insert('INSERT INTO my_table (owner) VALUES (?)', { identifier })

    All functions yield, so call them from a thread (event handlers and callbacks already are).
]]

---@class TRMigration
---@field id string unique and never renamed, e.g. '001_create_tables'
---@field up string | string[] | fun(db: TRDb) one statement per string

---@class TRDb
local db = {}

local resource = GetCurrentResourceName()
local oxmysql = exports.oxmysql

local function await(method, query, params)
    local p = promise.new()

    oxmysql[method](nil, query, params, function(result, err)
        if err then return p:reject(err) end
        p:resolve(result)
    end, resource, true)

    return Citizen.Await(p)
end

---@param query string
---@param params? table
---@return table[] rows
function db.query(query, params) return await('query', query, params) end

---@param query string
---@param params? table
---@return table? row first row
function db.single(query, params) return await('single', query, params) end

---@param query string
---@param params? table
---@return any value first column of the first row
function db.scalar(query, params) return await('scalar', query, params) end

---@param query string
---@param params? table
---@return integer? insertId
function db.insert(query, params) return await('insert', query, params) end

---@param query string
---@param params? table
---@return integer affectedRows
function db.update(query, params) return await('update', query, params) end

---Runs all queries atomically. Accepts { { query = '...', values = {...} }, ... } or { 'query', ... }.
---@param queries table
---@param params? table shared parameters
---@return boolean success
function db.transaction(queries, params) return await('transaction', queries, params) end

---Applies migrations that have not run yet for this resource, in order.
---Returns false and stops at the first failure.
---@param migrations TRMigration[]
---@return boolean success
function db.migrate(migrations)
    db.query([[
        CREATE TABLE IF NOT EXISTS `tr_migrations` (
            `resource` VARCHAR(64) NOT NULL,
            `id` VARCHAR(128) NOT NULL,
            `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`resource`, `id`)
        )
    ]])

    local applied = {}

    for _, row in ipairs(db.query('SELECT `id` FROM `tr_migrations` WHERE `resource` = ?', { resource })) do
        applied[row.id] = true
    end

    for i = 1, #migrations do
        local migration = migrations[i]
        assert(type(migration.id) == 'string' and migration.up, ('migration #%d needs an id and up'):format(i))

        if not applied[migration.id] then
            local ok, err = pcall(function()
                local up = migration.up

                if type(up) == 'function' then
                    up(db)
                else
                    if type(up) == 'string' then up = { up } end
                    for j = 1, #up do db.query(up[j]) end
                end
            end)

            if not ok then
                TR.log.error('migration %s failed: %s', migration.id, err)
                return false
            end

            db.insert('INSERT INTO `tr_migrations` (`resource`, `id`) VALUES (?, ?)', { resource, migration.id })
            TR.log.info('applied migration %s', migration.id)
        end
    end

    return true
end

return db
