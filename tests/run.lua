--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-CAMP — Offline tests: items, placement, fuel, roles, locale parity
     Usage (from the lxr-camp folder):  lua tests/run.lua [--mock out.js en|ka]
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

local CORE = os.getenv('LXR_CORE_PATH') or '../lxr-core'
package.path = CORE .. '/?.lua;' .. package.path
local ok = pcall(function() require('tests.lib.fxshim') end)
if not ok then print('lxr-core shim not found at ' .. CORE) os.exit(2) end
local Shim = require('tests.lib.fxshim')
for _, f in ipairs({ 'shared/main.lua', 'shared/locale.lua', 'locales/en.lua', 'config.lua', 'shared/catalog.lua', 'shared/items.lua', 'shared/prices.lua' }) do Shim.load(CORE .. '/' .. f) end
Config = nil Locale = nil
Shim.load('shared/locale.lua') Shim.load('locales/en.lua') Shim.load('locales/ka.lua') Shim.load('config.lua') Shim.load('shared/rules.lua')
local C = LXRCamp

local passed, failed = 0, 0
local function test(name, fn) local okT, err = xpcall(fn, debug.traceback) if okT then passed = passed + 1 print('  ^ ok   ' .. name) else failed = failed + 1 print('  x FAIL ' .. name .. '\n' .. err) end end
local function eq(a, b, msg) if a ~= b then error((msg or 'eq') .. ': expected ' .. tostring(b) .. ' got ' .. tostring(a), 2) end end

print('lxr-camp offline tests')
test('every piece and the kit, fuel and pick are catalog items', function()
    assert(LXRShared.Items[Config.Camp.item] and LXRShared.Items[Config.Fuel.item] and LXRShared.Items[Config.Pick.item])
    for id, p in pairs(Config.Pieces) do assert(LXRShared.Items[p.item], id) assert(p.prop, id) local pid = C.PieceFor(p.item) eq(pid, id) end
    assert(C.PieceFor('bread') == nil)
end)
test('a fire may not burn in town or on another camp; pieces stay near the fire', function()
    assert(C.MayCamp({ x = 0, y = 0, z = 0 }, {}))
    local t = Config.Camp.towns[1]
    local okT, why = C.MayCamp({ x = t.coords.x, y = t.coords.y, z = t.coords.z }, {}) assert(not okT) eq(why, 'town')
    local okC, why2 = C.MayCamp({ x = 0, y = 0, z = 0 }, { { x = 10, y = 0, z = 0 } }) assert(not okC) eq(why2, 'too_close')
    assert(C.MayPlace({ x = 5, y = 0, z = 0 }, { x = 0, y = 0, z = 0 })) assert(not C.MayPlace({ x = 50, y = 0, z = 0 }, { x = 0, y = 0, z = 0 }))
end)
test('the fire eats a log a day', function()
    eq(C.Burn(5, 2), 5 - 2 * Config.Fuel.perDay) eq(C.Burn(1, 9), 0) eq(C.DaysLeft(7), math.floor(7 / Config.Fuel.perDay))
end)
test('roles', function()
    local c = { citizenid = 'A', guests = { 'B' } }
    eq(C.Role(c, 'A'), 'owner') eq(C.Role(c, 'B'), 'guest') assert(C.Role(c, 'C') == nil)
    eq(C.StashId({ id = 3 }, 7), 'camp:3:7')
end)
test('locale parity', function()
    local en, ka = Locale.Bundles.en, Locale.Bundles.ka
    local missing = {}
    for k in pairs(en) do if ka[k] == nil then missing[#missing + 1] = k end end
    eq(#missing, 0, 'ka missing: ' .. table.concat(missing, ', '))
end)
print(('%d passed, %d failed'):format(passed, failed))
if arg and arg[1] == '--mock' and arg[2] then
    Config.Lang = arg[3] or 'en'
    local kinds = {}
    for id, def in pairs(Config.Pieces) do kinds[#kinds + 1] = { id = id, item = def.item, label = LXRShared.Items[def.item].label, storage = def.storage ~= nil, rest = def.rest == true, light = def.light == true } end
    table.sort(kinds, function(a, b) return a.id < b.id end)
    local f = assert(io.open(arg[2], 'w'))
    f:write('window.__LXR_MOCK__ = ' .. json.encode({ action = 'open', payload = { id = 4, fuel = 5, fuelMax = Config.Fuel.max, daysLeft = 5, fuelItem = 'Firewood', guests = { { citizenid = 'LXR9F8E7D', name = 'Nino Kvaratskhelia' } }, maxGuests = Config.Camp.guests, pieces = { { id = 11, kind = 'tent', label = 'Tent' }, { id = 12, kind = 'lockbox', label = 'Lockbox' } }, kinds = kinds }, lang = Config.Lang, locale = Lang.bundle(), brand = { name = 'The Land of Wolves', theme = 'night' } }) .. ';\n')
    f:close()
    print('mock written to ' .. arg[2])
end
os.exit(failed == 0 and 0 or 1)
