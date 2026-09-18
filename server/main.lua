--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-CAMP — Server: the camps live here
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

local LXRCore = exports['lxr-core']:GetCoreObject()
local LXR = exports['lxr-core']:GetLXR()
local C = LXRCamp
local RES = GetCurrentResourceName()
local camps, buckets = {}, {}    -- id → camp { id, citizenid, x, y, z, fuel, burnt_at, guests, pieces = { id → { id, kind, x, y, z, heading, open_until } } }

local function limited(src)
    local b = buckets[src]
    local now = GetGameTimer()
    if not b or now - b.at > Config.Security.rateLimit.windowMs then b = { at = now, n = 0 } buckets[src] = b end
    b.n = b.n + 1
    return b.n > Config.Security.rateLimit.burst
end
local function player(src) return LXRCore.Functions.GetPlayer(src) end
local function near(src, p, d)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and #(GetEntityCoords(ped) - vector3(p.x, p.y, p.z)) <= (d or Config.Security.maxDistance)
end
local function nameOf(cid)
    local P = LXRCore.Functions.GetPlayerByCitizenId(cid) or LXRCore.Functions.GetOfflinePlayerByCitizenId(cid)
    local c = P and P.PlayerData and P.PlayerData.charinfo
    return c and ((c.firstname or '') .. ' ' .. (c.lastname or '')) or cid
end
local function decode(s) local ok, t = pcall(json.decode, s or '') return ok and type(t) == 'table' and t or {} end

LXRCore.DB.RegisterMigration(RES, '0001_camp', [[
CREATE TABLE IF NOT EXISTS `lxr_camps` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
  `fuel` INT NOT NULL DEFAULT 0,
  `burnt_at` INT NOT NULL DEFAULT 0,
  `guests` TEXT NULL,
  PRIMARY KEY (`id`), KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS `lxr_camp_pieces` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `camp` INT NOT NULL,
  `kind` VARCHAR(24) NOT NULL,
  `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL, `heading` FLOAT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`), KEY `camp` (`camp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS `lxr_camp_lost` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `item` VARCHAR(64) NOT NULL,
  `amount` INT NOT NULL,
  `info` TEXT NULL,
  PRIMARY KEY (`id`), KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]])

local function public(c)
    local pieces = {}
    for _, p in pairs(c.pieces) do pieces[#pieces + 1] = { id = p.id, kind = p.kind, x = p.x, y = p.y, z = p.z, heading = p.heading, openUntil = p.open_until or 0 } end
    return { id = c.id, owner = c.citizenid, x = c.x, y = c.y, z = c.z, fuel = c.fuel, daysLeft = C.DaysLeft(c.fuel), guests = c.guests, pieces = pieces }
end
local function book(c)
    local guests = {}
    for _, g in ipairs(c.guests) do guests[#guests + 1] = { citizenid = g, name = nameOf(g) } end
    local pieces = {}
    for _, p in pairs(c.pieces) do pieces[#pieces + 1] = { id = p.id, kind = p.kind, label = LXRShared.Items[Config.Pieces[p.kind].item].label } end
    table.sort(pieces, function(a, b) return a.id < b.id end)
    local kinds = {}
    for id, def in pairs(Config.Pieces) do kinds[#kinds + 1] = { id = id, item = def.item, label = LXRShared.Items[def.item].label, storage = def.storage ~= nil, rest = def.rest == true, light = def.light == true } end
    table.sort(kinds, function(a, b) return a.id < b.id end)
    return { id = c.id, fuel = c.fuel, fuelMax = Config.Fuel.max, daysLeft = C.DaysLeft(c.fuel), fuelItem = LXRShared.Items[Config.Fuel.item].label, guests = guests, maxGuests = Config.Camp.guests, pieces = pieces, kinds = kinds }
end
local function broadcast(c) TriggerClientEvent('lxr-camp:client:update', -1, public(c)) end
local function save(c) LXRCore.DB.UpdateAsync('UPDATE lxr_camps SET fuel = ?, burnt_at = ?, guests = ? WHERE id = ?', { c.fuel, c.burnt_at, json.encode(c.guests), c.id }) end
local function station(c) if GetResourceState('lxr-craft') == 'started' then exports['lxr-craft']:AddStation('camp:' .. c.id, 'campfire', Lang:t('ui.fire'), vector3(c.x, c.y, c.z)) end end
local function lose(cid, item, amount, info) LXRCore.DB.InsertAsync('INSERT INTO lxr_camp_lost (citizenid, item, amount, info) VALUES (?, ?, ?, ?)', { cid, item, amount, json.encode(info or {}) }) end

---strike a camp: pieces (and what the lockboxes hold) to the owner's lost pile; the kit too unless the owner packs it
local function strike(c, why, toOwnerSatchel)
    for _, p in pairs(c.pieces) do
        local def = Config.Pieces[p.kind]
        if def.storage and GetResourceState('lxr-inventory') == 'started' then
            for _, it in ipairs(exports['lxr-inventory']:GetStashItems(C.StashId(c, p.id)) or {}) do lose(c.citizenid, it.name, it.amount, it.info) end
            exports['lxr-inventory']:ClearStash(C.StashId(c, p.id))
        end
        lose(c.citizenid, def.item, 1)
    end
    if not toOwnerSatchel then lose(c.citizenid, Config.Camp.item, 1) end
    LXRCore.DB.UpdateAsync('DELETE FROM lxr_camp_pieces WHERE camp = ?', { c.id })
    LXRCore.DB.UpdateAsync('DELETE FROM lxr_camps WHERE id = ?', { c.id })
    if GetResourceState('lxr-craft') == 'started' then exports['lxr-craft']:RemoveStation('camp:' .. c.id) end
    camps[c.id] = nil
    TriggerClientEvent('lxr-camp:client:remove', -1, c.id, why)
    LXRCore.Emit('lxr:camp:struck', nil, c.id, c.citizenid, why)
    if Config.Debug.log then LXRCore.Log.info('camp', ('camp %d struck (%s)'):format(c.id, why)) end
end

CreateThread(function()
    Wait(1000)
    local rows = LXRCore.DB.Query('SELECT id, citizenid, x, y, z, fuel, burnt_at, guests FROM lxr_camps') or {}
    for _, r in ipairs(rows) do camps[r.id] = { id = r.id, citizenid = r.citizenid, x = r.x, y = r.y, z = r.z, fuel = r.fuel, burnt_at = r.burnt_at, guests = decode(r.guests), pieces = {} } end
    for _, p in ipairs(LXRCore.DB.Query('SELECT id, camp, kind, x, y, z, heading FROM lxr_camp_pieces') or {}) do if camps[p.camp] and Config.Pieces[p.kind] then camps[p.camp].pieces[p.id] = { id = p.id, kind = p.kind, x = p.x, y = p.y, z = p.z, heading = p.heading } end end
    Wait(2000)
    for _, c in pairs(camps) do station(c) end
    if Config.Debug.printBanner then print(('^1[lxr-camp]^7 v%s — %d camps burning'):format(GetResourceMetadata(RES, 'version', 0), #rows)) end
end)

local function mine(cid) for _, c in pairs(camps) do if c.citizenid == cid then return c end end end
local function campNear(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    local pos = GetEntityCoords(ped)
    for _, c in pairs(camps) do if #(pos - vector3(c.x, c.y, c.z)) <= Config.Camp.radius + 2.0 then return c end end
end

-- the kit lights the fire; whatever was lost from an old camp comes back to the satchel first
LXRCore.Items.RegisterUsable(Config.Camp.item, function(src) TriggerClientEvent('lxr-camp:client:place', src) end)

LXR.RPC.Register('lxr-camp:light', function(src, x, y, z)
    if limited(src) then return false, 'rate' end
    local P = player(src)
    if not P or type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' then return false, 'invalid' end
    local pos = { x = x, y = y, z = z }
    if not near(src, pos) then return false, 'too_far' end
    local cid = P.PlayerData.citizenid
    if mine(cid) then return false, 'have_camp' end
    local okC, why = C.MayCamp(pos, camps)
    if not okC then return false, why end
    if not P.Functions.RemoveItem(Config.Camp.item, 1, nil, 'camp:light') then return false, 'no_kit' end
    local id = LXRCore.DB.Insert('INSERT INTO lxr_camps (citizenid, x, y, z, fuel, burnt_at, guests) VALUES (?, ?, ?, ?, ?, ?, ?)', { cid, x, y, z, Config.Fuel.start, os.time(), '[]' })
    local c = { id = id, citizenid = cid, x = x, y = y, z = z, fuel = Config.Fuel.start, burnt_at = os.time(), guests = {}, pieces = {} }
    camps[id] = c
    station(c) broadcast(c)
    -- the lost pile: pieces from a struck camp come home
    local lost = LXRCore.DB.Query('SELECT id, item, amount, info FROM lxr_camp_lost WHERE citizenid = ?', { cid }) or {}
    local back = 0
    for _, l in ipairs(lost) do if P.Functions.AddItem(l.item, l.amount, nil, decode(l.info), 'camp:lost') then back = back + 1 LXRCore.DB.Update('DELETE FROM lxr_camp_lost WHERE id = ?', { l.id }) end end
    if back > 0 then LXRCore.Notify(src, Lang:t('info.lost_back', { n = back }), 'info', 8000) end
    LXRCore.Emit('lxr:camp:lit', nil, src, id)
    return true, id
end)

LXR.RPC.Register('lxr-camp:open', function(src, id)
    if limited(src) then return false, 'rate' end
    local P, c = player(src), camps[tonumber(id) or 0]
    if not P or not c then return false, 'invalid' end
    if not near(src, c, Config.Camp.radius + 2.0) then return false, 'too_far' end
    if C.Role(c, P.PlayerData.citizenid) ~= 'owner' then return false, 'not_yours' end
    return true, book(c)
end)

LXR.RPC.Register('lxr-camp:manage', function(src, id, what, arg, pos)
    if limited(src) then return false, 'rate' end
    local P, c = player(src), camps[tonumber(id) or 0]
    if not P or not c then return false, 'invalid' end
    if not near(src, c, Config.Camp.radius + 2.0) then return false, 'too_far' end
    local cid = P.PlayerData.citizenid
    if C.Role(c, cid) ~= 'owner' then return false, 'not_yours' end
    if what == 'fuel' then
        local n = math.max(1, math.min(Config.Fuel.max - c.fuel, math.floor(tonumber(arg) or 1)))
        if n < 1 then return false, 'full' end
        if not P.Functions.RemoveItem(Config.Fuel.item, n, nil, 'camp:fuel') then return false, 'no_fuel', LXRShared.Items[Config.Fuel.item].label end
        c.fuel = c.fuel + n
        save(c) broadcast(c)
    elseif what == 'place' then
        local def = Config.Pieces[tostring(arg)]
        if not def or type(pos) ~= 'table' then return false, 'invalid' end
        if not C.MayPlace(pos, c) then return false, 'too_far_fire' end
        if not P.Functions.RemoveItem(def.item, 1, nil, 'camp:piece') then return false, 'no_piece', LXRShared.Items[def.item].label end
        local pid = LXRCore.DB.Insert('INSERT INTO lxr_camp_pieces (camp, kind, x, y, z, heading) VALUES (?, ?, ?, ?, ?, ?)', { c.id, arg, pos.x, pos.y, pos.z, tonumber(pos.heading) or 0.0 })
        c.pieces[pid] = { id = pid, kind = arg, x = pos.x, y = pos.y, z = pos.z, heading = tonumber(pos.heading) or 0.0 }
        broadcast(c)
    elseif what == 'take' then
        local p = c.pieces[tonumber(arg) or 0]
        if not p then return false, 'invalid' end
        local def = Config.Pieces[p.kind]
        if def.storage and GetResourceState('lxr-inventory') == 'started' and #(exports['lxr-inventory']:GetStashItems(C.StashId(c, p.id)) or {}) > 0 then return false, 'not_empty' end
        if not LXRCore.Inventory.CanCarry(src, def.item, 1) then return false, 'too_heavy' end
        P.Functions.AddItem(def.item, 1, nil, nil, 'camp:take')
        c.pieces[p.id] = nil
        LXRCore.DB.UpdateAsync('DELETE FROM lxr_camp_pieces WHERE id = ?', { p.id })
        broadcast(c)
    elseif what == 'invite' then
        local T = LXRCore.Functions.GetPlayer(tonumber(arg) or -1)
        if not T or T == P then return false, 'nobody' end
        if #c.guests >= Config.Camp.guests then return false, 'too_many_guests' end
        for _, g in ipairs(c.guests) do if g == T.PlayerData.citizenid then return false, 'already_guest' end end
        c.guests[#c.guests + 1] = T.PlayerData.citizenid
        save(c) broadcast(c)
        LXRCore.Notify(T.PlayerData.source, Lang:t('info.invited', { name = nameOf(cid) }), 'success')
    elseif what == 'uninvite' then
        for i, g in ipairs(c.guests) do if g == arg then table.remove(c.guests, i) break end end
        save(c) broadcast(c)
    elseif what == 'strike' then
        if not LXRCore.Inventory.CanCarry(src, Config.Camp.item, 1) then return false, 'too_heavy' end
        P.Functions.AddItem(Config.Camp.item, 1, nil, nil, 'camp:strike')
        strike(c, 'owner', true)
        return true, nil
    else return false, 'invalid' end
    return true, book(c)
end)

-- pieces: the lockbox opens for owner and guests (or after a pick), the tent rests
LXR.RPC.Register('lxr-camp:use', function(src, id, pieceId)
    if limited(src) then return false, 'rate' end
    local P, c = player(src), camps[tonumber(id) or 0]
    local p = c and c.pieces[tonumber(pieceId) or 0]
    if not P or not p then return false, 'invalid' end
    if not near(src, p) then return false, 'too_far' end
    local def = Config.Pieces[p.kind]
    local role = C.Role(c, P.PlayerData.citizenid)
    if def.storage then
        if not role and not (p.open_until and os.time() <= p.open_until) then return false, 'locked' end
        if GetResourceState('lxr-inventory') ~= 'started' then return false, 'invalid' end
        exports['lxr-inventory']:OpenInventory(src, 'stash', C.StashId(c, p.id), { label = Lang:t('ui.lockbox'), slots = def.storage.slots, weight = def.storage.weight })
        return true, 'stash'
    elseif def.rest then
        if not role then return false, 'locked' end
        LXRCore.Emit('lxr:camp:rested', nil, src, c.id, Config.Rest)
        return true, 'rest'
    end
    return false, 'invalid'
end)

RegisterNetEvent('lxr-camp:server:pick', function(id, pieceId)
    local src = source
    if limited(src) or not Config.Pick.enabled then return end
    local P, c = player(src), camps[tonumber(id) or 0]
    local p = c and c.pieces[tonumber(pieceId) or 0]
    if not P or not p or not Config.Pieces[p.kind].pick then return end
    if C.Role(c, P.PlayerData.citizenid) then return end
    if not near(src, p) then return end
    if LXRCore.Inventory.GetItemCount(src, Config.Pick.item) < 1 then return LXRCore.Notify(src, Lang:t('error.no_pick', { label = LXRShared.Items[Config.Pick.item].label }), 'error') end
    TriggerClientEvent('lxr-lockpick:client:start', src, { door = ('camp:%d:%d'):format(c.id, p.id), label = Lang:t('ui.lockbox'), report = Config.Pick.report })
end)
RegisterNetEvent(Config.Pick.report, function(door, broke)
    local src = source
    local cid, pid = tostring(door):match('^camp:(%d+):(%d+)$')
    local c = cid and camps[tonumber(cid)]
    local p = c and c.pieces[tonumber(pid)]
    local P = player(src)
    if not P or not p or not near(src, p) then return end
    if broke then P.Functions.RemoveItem(Config.Pick.item, 1, nil, 'camp:pick broke') return LXRCore.Notify(src, Lang:t('error.pick_broke'), 'warning') end
    p.open_until = os.time() + Config.Pick.openMinutes * 60
    broadcast(c)
    LXRCore.Log.info('camp', ('lockbox %d at camp %d picked'):format(p.id, c.id), { source = src, owner = c.citizenid })
    local O = LXRCore.Functions.GetPlayerByCitizenId(c.citizenid)
    if O then LXRCore.Notify(O.PlayerData.source, Lang:t('info.robbed'), 'warning', 8000) end
end)

RegisterNetEvent('lxr-camp:server:ready', function()
    local src = source
    local list = {}
    for _, c in pairs(camps) do list[#list + 1] = public(c) end
    TriggerClientEvent('lxr-camp:client:sync', src, list)
end)

-- the fire eats a log a day; out of wood, the camp is struck
CreateThread(function()
    while true do
        Wait(3600000)
        local now = os.time()
        for _, c in pairs(camps) do
            local days = math.floor((now - (c.burnt_at or now)) / 86400)
            if days >= 1 then
                c.fuel = C.Burn(c.fuel, days)
                c.burnt_at = (c.burnt_at or now) + days * 86400
                if c.fuel <= 0 then strike(c, 'cold', false) else save(c) broadcast(c) end
            end
        end
    end
end)

AddEventHandler('playerDropped', function() buckets[source] = nil end)
exports('CampsOf', function(cid) local out = {} for _, c in pairs(camps) do if c.citizenid == cid then out[#out + 1] = { id = c.id, x = c.x, y = c.y, z = c.z } end end return out end)
exports('Role', function(cid, id) local c = camps[id] return c and C.Role(c, cid) end)
