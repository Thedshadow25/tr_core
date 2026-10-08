TR.player.bridge.registerEvents()

RegisterNetEvent('tr:notify', function(data)
    TR.notify.send(data)
end)

-- The server's TR.fuel asks the client controlling a car when the fuel script keeps fuel on the client.
TR.callback.register('tr_core:fuel:get', function(netId)
    if not NetworkDoesEntityExistWithNetworkId(netId) then return end
    return TR.fuel.get(NetworkGetEntityFromNetworkId(netId))
end)

RegisterNetEvent('tr_core:fuel:set', function(netId, amount)
    if not NetworkDoesEntityExistWithNetworkId(netId) then return end
    TR.fuel.set(NetworkGetEntityFromNetworkId(netId), amount)
end)

-- The server's TR.dispatch asks the player an alert is about for the street name (the server has no map).
TR.callback.register('tr_core:dispatch:street', function(coords)
    local street, crossing = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local name, cross = GetStreetNameFromHashKey(street), GetStreetNameFromHashKey(crossing)
    return cross ~= '' and ('%s / %s'):format(name, cross) or name
end)

-- TR.dispatch with no dispatch script on the server: the alert as a notification and a blip.
RegisterNetEvent('tr_core:dispatch', function(alert)
    if alert.message ~= '' then
        TR.notify.send({ title = alert.title, description = alert.message, type = 'warning', duration = 10000 })
    else
        TR.notify.send({ description = alert.title, type = 'warning', duration = 10000 })
    end
    PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', true)

    local x, y, z = alert.coords.x, alert.coords.y, alert.coords.z
    local blip = AddBlipForCoord(x, y, z)
    SetBlipSprite(blip, alert.blip.sprite)
    SetBlipColour(blip, alert.blip.color)
    SetBlipScale(blip, alert.blip.scale + 0.0)
    SetBlipFlashes(blip, alert.blip.flash)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(alert.title)
    EndTextCommandSetBlipName(blip)

    local area
    if alert.blip.radius > 0 then
        area = AddBlipForRadius(x, y, z, alert.blip.radius + 0.0)
        SetBlipColour(area, alert.blip.color)
        SetBlipAlpha(area, 100)
    end

    SetTimeout(math.floor(alert.time * 60000), function()
        RemoveBlip(blip)
        if area then RemoveBlip(area) end
    end)
end)

-- Single source of truth for TR.cache: detect changes here and broadcast them to every resource.
CreateThread(function()
    local last = TR.cache.snapshot()

    while true do
        Wait(100)

        for key, value in pairs(TR.cache.snapshot()) do
            if last[key] ~= value then
                last[key] = value
                TriggerEvent('tr:cache', key, value)
            end
        end
    end
end)
