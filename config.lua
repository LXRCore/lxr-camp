--[[
    ██╗     ██╗  ██╗██████╗        ██████╗ █████╗ ███╗   ███╗██████╗
    ██║     ╚██╗██╔╝██╔══██╗      ██╔════╝██╔══██╗████╗ ████║██╔══██╗
    ██║      ╚███╔╝ ██████╔╝█████╗██║     ███████║██╔████╔██║██████╔╝
    ██║      ██╔██╗ ██╔══██╗╚════╝██║     ██╔══██║██║╚██╔╝██║██╔═══╝
    ███████╗██╔╝ ██╗██║  ██║      ╚██████╗██║  ██║██║ ╚═╝ ██║██║
    ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝       ╚═════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝

    LXR Core - Camp

    A fire, and around it what you carry: a tent, a bedroll, a lockbox, a
    lantern. The camp lives on the server and survives restarts; it eats
    firewood by the day and goes cold without it — a cold camp is struck
    and its pieces wait for the owner. Guests are invited to the fire; a
    stranger can work the lockbox with a pick. The fire is a campfire
    station for lxr-craft.

    Brand:       LXRCore — Lux Empire eXperience RedM Core
    Product:     wolves.land / The Land of Wolves
    Developer:   iBoss21 / LXRCore
    Website:     https://www.lxrcore.com
    Discord:     https://discord.gg/GAhk8cgXe9
    GitHub:      https://github.com/LXRCore

    Version: 3.0.0
    Performance Target: 0.00 ms idle (interact points; a 2 s range loop on the client; an hourly fuel tick on the server)

    © 2026 iBoss21 / LXRCore | lxrcore.com | All Rights Reserved
]]

Config = Config or {}

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ LANGUAGE ██████████████████████████████████████████████
-- ████████████████████████████████████████████████████████████████████████████████
Config.Lang = 'en'

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ THE FIRE ══════════════════════════════════════════════
-- ████████████████████████████████████████████████████████████████████████████████
-- prop names were NOT verified against the game; a model that fails IsModelValid is skipped and the piece is still marked by its prompt
Config.Camp = {
    item = 'campfire_kit',        -- lights the fire; comes back when the camp is struck by its owner
    prop = 'p_campfire01x',
    perPlayer = 1,
    spacing = 60.0,               -- between camps
    towns = {
        { coords = vector3(-300.0, 790.0, 118.0), radius = 300.0 },   -- Valentine
        { coords = vector3(1330.0, -1300.0, 77.0), radius = 300.0 },  -- Rhodes
        { coords = vector3(2640.0, -1220.0, 53.0), radius = 500.0 },  -- Saint Denis
        { coords = vector3(-820.0, -1320.0, 43.0), radius = 300.0 },  -- Blackwater
        { coords = vector3(-3660.0, -2620.0, -13.0), radius = 300.0 }, -- Armadillo
        { coords = vector3(-5500.0, -2940.0, -2.0), radius = 300.0 },  -- Tumbleweed
        { coords = vector3(-1800.0, -390.0, 160.0), radius = 250.0 },  -- Strawberry
    },
    radius = 12.0,                -- pieces go within this of the fire
    guests = 4,
}

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ FIREWOOD ══════════════════════════════════════════════
-- ████████████████████████████████████████████████████████████████████████████████
Config.Fuel = { item = 'wood', perDay = 1, max = 14, start = 2 }   -- one log a day; a camp with no wood left goes cold and is struck

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ PIECES ════════════════════════════════════════════════
-- ████████████████████████████████████████████████████████████████════════════════
-- each piece is a catalog item the owner places from the satchel; `storage` makes it an lxr-inventory stash
Config.Pieces = {
    tent    = { item = 'tent',    prop = 'p_tent01x',     rest = true },
    bedroll = { item = 'bedroll', prop = 'p_bedroll01x',  rest = true },
    lockbox = { item = 'lockbox', prop = 'p_chest01x',    storage = { slots = 20, weight = 60000 }, pick = true },
    lantern = { item = 'lantern', prop = 'p_lantern01x',  light = true },
}
Config.Pick = { enabled = true, item = 'lockpick', report = 'lxr-camp:server:picked', openMinutes = 5 }
Config.Rest = { seconds = 8, health = 25, stress = -20 }   -- what a rest at the tent gives (core needs / metadata through lxr:camp:rested)

Config.Work = { placeMs = 5000, pieceMs = 3000, scenario = 'WORLD_HUMAN_CROUCH_INSPECT' }
Config.Security = { rateLimit = { windowMs = 2000, burst = 6 }, maxDistance = 4.0, promptDistance = 2.0, propRange = 150.0 }
Config.Debug = { printBanner = true, log = true }
