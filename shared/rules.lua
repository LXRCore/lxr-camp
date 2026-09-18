--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-CAMP — Shared rules: where a fire may burn, what it burns
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

LXRCamp = LXRCamp or {}
local C = LXRCamp

local function dist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end
C.Dist = dist

---May a fire burn here? Returns false, reason when not.
function C.MayCamp(pos, camps)
    for _, t in ipairs(Config.Camp.towns or {}) do if dist(pos, t.coords) <= t.radius then return false, 'town' end end
    for _, c in pairs(camps or {}) do if dist(pos, c) < Config.Camp.spacing then return false, 'too_close' end end
    return true
end

---May a piece stand here for this camp?
function C.MayPlace(pos, camp) return dist(pos, camp) <= Config.Camp.radius end

---Piece definition for a catalog item, or nil.
function C.PieceFor(item) for id, p in pairs(Config.Pieces) do if p.item == item then return id, p end end end

---Firewood left after `days` at the daily rate.
function C.Burn(fuel, days) return math.max(0, fuel - math.floor(days) * Config.Fuel.perDay) end

---Days of fire left.
function C.DaysLeft(fuel) return Config.Fuel.perDay > 0 and math.floor(fuel / Config.Fuel.perDay) or 999 end

---Owner, guest, or neither.
function C.Role(camp, citizenid)
    if camp.citizenid == citizenid then return 'owner' end
    for _, g in ipairs(camp.guests or {}) do if g == citizenid then return 'guest' end end
    return nil
end

function C.StashId(camp, pieceId) return ('camp:%d:%d'):format(camp.id, pieceId) end
