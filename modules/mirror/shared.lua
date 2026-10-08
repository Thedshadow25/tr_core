--[[
    Lets players nearby see a 3D scene someone is using (a minigame, a laptop): its props and
    particles, and hear its sounds. The client side sends and rebuilds scenes (client.lua), the
    server checks what is sent and passes it on (server.lua).

    Load it when the resource starts, on both sides, so its events are there before anyone plays:

        TR.mirror.configure({ range = 30.0, soundRange = 12.0, rate = 100, volume = 0.8 })

    Each resource has its own mirror: its events are named after it (<resource>:mirror).
]]

---@class TRMirror
local Mirror = {
    options = {
        range = 30.0,      -- metres within which players see the props (server)
        soundRange = 12.0, -- metres the sounds carry, quieter the further away (client)
        rate = 100,        -- ms between updates the playing player sends (client)
        volume = 0.8,      -- sound volume right next to the scene, 0..1 (client)
    },
}

---Changes some of the options (the rest keep their values).
---@param options { range?: number, soundRange?: number, rate?: integer, volume?: number }
function Mirror.configure(options)
    for key, value in pairs(options) do Mirror.options[key] = value end
end

return Mirror
