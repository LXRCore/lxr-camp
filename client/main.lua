--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-CAMP — Client: the fire you can see, the pieces, the owner's page
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

local LXRCore = exports['lxr-core']:GetCoreObject()
local LXR = exports['lxr-core']:GetLXR()
local C = LXRCamp
local N = Citizen.InvokeNative
local camps, props, busy, open, current, placing = {}, {}, false, false, nil, nil

local function toast(key, kind, vars) LXRCore.Notify(Lang:t(key, vars), kind or 'info') end
local function page(action, payload) SendNUIMessage({ action = action, payload = payload, brand = LXRCore.Brand, lang = Config.Lang, locale = Lang.bundle() }) end
local function citizenid() local d = LXRCore.Functions.GetPlayerData() return d and d.citizenid end
local function work(ms)
    busy = true
    local ped = PlayerPedId()
    N(0x524B54361229154F, ped, joaat(Config.Work.scenario), ms, true, false, false, false)
    Wait(ms)
    ClearPedTasks(ped)
    busy = false
end
local function key(campId, pieceId) return pieceId and ('lxr-camp:%d:%d'):format(campId, pieceId) or ('lxr-camp:%d'):format(campId) end
local function despawn(k)
    local e = props[k]
    if not e then return end
    exports['lxr-interact']:Remove(k)
    if e ~= true and DoesEntityExist(e) then DeleteEntity(e) end
    props[k] = nil
end
local function model(name, x, y, z, heading)
    local hash = joaat(name or '')
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    if not HasModelLoaded(hash) then return nil end
    local e = CreateObject(hash, x, y, z, false, false, false)
    if heading then SetEntityHeading(e, heading) end
    PlaceObjectOnGroundProperly(e)
    FreezeEntityPosition(e, true)
    SetModelAsNoLongerNeeded(hash)
    return e
end
local function register(k, e, coords, label, options)
    if e then props[k] = e exports['lxr-interact']:AddEntity(k, e, { label = label, distance = Config.Security.promptDistance, options = options })
    else props[k] = true exports['lxr-interact']:AddPoint(k, coords, { label = label, distance = Config.Security.promptDistance, options = options }) end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 🔥 THE FIRE + PIECES
-- ═══════════════════════════════════════════════════════════════════════════════
local function openPage(c)
    if open then return end
    local ok, data = LXR.RPC.Server('lxr-camp:open', c.id)
    if not ok then return toast('error.' .. tostring(data), 'error') end
    open = true current = c.id
    SetNuiFocus(true, true)
    page('open', data)
end
local function close() if not open then return end open = false current = nil SetNuiFocus(false, false) page('close') end

local function spawnFire(c)
    local k = key(c.id)
    despawn(k)
    local e = model(Config.Camp.prop, c.x, c.y, c.z)
    register(k, e, vector3(c.x, c.y, c.z), Lang:t('ui.fire'), {
        { label = Lang:t('ui.camp_page'), key = 'J', canInteract = function() local cur = camps[c.id] return cur and cur.owner == citizenid() and not busy end, onSelect = function() openPage(c) end },
        { label = Lang:t('ui.cook'), key = 'E', canInteract = function() return GetResourceState('lxr-craft') == 'started' and not busy end, onSelect = function() TriggerEvent('lxr-craft:client:openAt', 'camp:' .. c.id, 'campfire', Lang:t('ui.fire')) end },
        { label = Lang:t('ui.warm'), key = 'R', canInteract = function() return not busy end, onSelect = function() work(4000) toast('info.warmed', 'info') end },
    })
end
local function spawnPiece(c, p)
    local k = key(c.id, p.id)
    despawn(k)
    local def = Config.Pieces[p.kind]
    if not def then return end
    local e = model(def.prop, p.x, p.y, p.z, p.heading)
    local label = LXRShared.Items[def.item].label
    local options = {}
    if def.storage then
        options[#options + 1] = { label = Lang:t('ui.open'), key = 'J', canInteract = function() return not busy end, onSelect = function()
            local ok, err = LXR.RPC.Server('lxr-camp:use', c.id, p.id)
            if not ok then toast('error.' .. tostring(err), 'error') end
        end }
        if def.pick then options[#options + 1] = { label = Lang:t('ui.pick'), key = 'R', item = Config.Pick.item, canInteract = function() local cur = camps[c.id] return cur and cur.owner ~= citizenid() and not busy end, onSelect = function() TriggerServerEvent('lxr-camp:server:pick', c.id, p.id) end } end
    end
    if def.rest then
        options[#options + 1] = { label = Lang:t('ui.rest'), key = 'J', canInteract = function() return not busy end, onSelect = function()
            local ok, err = LXR.RPC.Server('lxr-camp:use', c.id, p.id)
            if not ok then return toast('error.' .. tostring(err), 'error') end
            work(Config.Rest.seconds * 1000)
            toast('info.rested', 'success')
        end }
    end
    register(k, e, vector3(p.x, p.y, p.z), label, options)
    -- a `light` piece: the game's lantern props glow on their own; no extra native is called here
end
local function despawnCamp(c)
    despawn(key(c.id))
    for _, p in ipairs(c.pieces or {}) do despawn(key(c.id, p.id)) end
end
local function spawnCamp(c) spawnFire(c) for _, p in ipairs(c.pieces or {}) do spawnPiece(c, p) end end

RegisterNetEvent('lxr-camp:client:sync', function(list) for k in pairs(props) do despawn(k) end camps = {} for _, c in ipairs(list) do camps[c.id] = c end end)
RegisterNetEvent('lxr-camp:client:update', function(c)
    local old = camps[c.id]
    camps[c.id] = c
    if old and props[key(c.id)] then despawnCamp(old) spawnCamp(c) end
    if open and current == c.id then local ok, data = LXR.RPC.Server('lxr-camp:open', c.id) if ok then page('update', data) end end
end)
RegisterNetEvent('lxr-camp:client:remove', function(id, why)
    local c = camps[id]
    if c then despawnCamp(c) end
    camps[id] = nil
    if open and current == id then close() end
    if c and c.owner == citizenid() then toast(why == 'cold' and 'info.cold' or 'info.struck', 'warning') end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 🪵 PLACING: the kit lights the fire; pieces go where you stand
-- ═══════════════════════════════════════════════════════════════════════════════
local function spot(ahead)
    local ped = PlayerPedId()
    local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, ahead, 0.0)
    local ok, z = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 1.0, false)
    if not ok then return nil end
    return { x = pos.x, y = pos.y, z = z, heading = GetEntityHeading(ped) }
end
RegisterNetEvent('lxr-camp:client:place', function()
    if busy then return end
    local ped = PlayerPedId()
    if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) then return toast('error.dismount', 'error') end
    local s = spot(1.5)
    if not s then return toast('error.invalid', 'error') end
    local may, why = C.MayCamp(s, camps)
    if not may then return toast('error.' .. why, 'error') end
    work(Config.Work.placeMs)
    local res, err = LXR.RPC.Server('lxr-camp:light', s.x, s.y, s.z)
    if not res then return toast('error.' .. tostring(err), 'error') end
    toast('info.lit', 'success')
end)

RegisterNUICallback('close', function(_, cb) close() cb({ ok = true }) end)
RegisterNUICallback('manage', function(d, cb)
    if not current then return cb({ ok = false }) end
    local arg, pos = d.arg, nil
    if d.what == 'place' then
        close()
        pos = spot(1.2)
        if not pos then return cb({ ok = false }) end
        work(Config.Work.pieceMs)
    elseif d.what == 'invite' then
        local p, dist = LXRCore.Functions.GetClosestPlayer()
        if p == -1 or dist > 6.0 then toast('error.nobody', 'error') return cb({ ok = false }) end
        arg = GetPlayerServerId(p)
    end
    local ok, res, extra = LXR.RPC.Server('lxr-camp:manage', current or d.id, d.what, arg, pos)
    if not ok then toast('error.' .. tostring(res), 'error', { label = extra }) return cb({ ok = false }) end
    if d.what == 'strike' then close() toast('info.struck', 'info') return cb({ ok = true }) end
    cb({ ok = true, data = res })
end)

CreateThread(function()
    while GetResourceState('lxr-interact') ~= 'started' do Wait(1000) end
    while true do
        if LocalPlayer.state.isLoggedIn then
            local pos = GetEntityCoords(PlayerPedId())
            for id, c in pairs(camps) do
                local d = #(pos - vector3(c.x, c.y, c.z))
                if d <= Config.Security.propRange and not props[key(id)] then spawnCamp(c) elseif d > Config.Security.propRange + 20.0 and props[key(id)] then despawnCamp(c) end
            end
        end
        Wait(2000)
    end
end)
RegisterNetEvent('lxr:client:loaded', function() Wait(1500) TriggerServerEvent('lxr-camp:server:ready') end)
RegisterNetEvent('lxr:client:unloaded', function() close() for k in pairs(props) do despawn(k) end camps = {} end)
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then close() for k in pairs(props) do despawn(k) end end end)
CreateThread(function() Wait(2000) if LocalPlayer.state.isLoggedIn then TriggerServerEvent('lxr-camp:server:ready') end end)
exports('Camps', function() return camps end)
