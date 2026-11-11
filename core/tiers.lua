-- tiers.lua : a set's levels. A set can hold gear for several levels: each level's gear is a tier, and a tier's level
-- is the highest level among its pieces. At your level, every tier at or below it is put on, lowest first, so lower
-- gear carries forward until a higher tier replaces that slot. (The lowest tier always counts.)
--
-- Stored as set.gear (the lowest tier) and set.more = { gear, gear, ... } (the others), so a set with one level is
-- just set.gear, as before.
local items = require('core.items');

local tiers = {};

function tiers.empty(g)
    for s = 0, 15 do if g and g[s] and (g[s].id or g[s].remove) then return false; end end
    return true;
end

-- A tier's level: its highest piece (0 for an empty tier)
function tiers.level(g)
    local lv = 0;
    for s = 0, 15 do
        local e = g and g[s];
        if e and e.id then lv = math.max(lv, items.level(e.id)); end
    end
    return lv;
end

-- Every tier, lowest level first: { { gear, level } }
function tiers.sorted(set)
    local t = {};
    set.gear = set.gear or {};
    t[1] = { gear = set.gear, level = tiers.level(set.gear), i = 1 };
    for k, g in ipairs(set.more or {}) do t[#t + 1] = { gear = g, level = tiers.level(g), i = k + 1 }; end
    table.sort(t, function(a, b)
        if a.level ~= b.level then return a.level < b.level; end
        return a.i < b.i;
    end);
    return t;
end

function tiers.count(set) return 1 + #(set.more or {}); end

-- Tidy: drop empty tiers (except `keep`, the one being edited), keep at least one, lowest level in set.gear.
-- Returns true if anything changed.
function tiers.normalize(set, keep)
    local before = tiers.count(set);
    local first = set.gear;
    local list = {};
    for _, t in ipairs(tiers.sorted(set)) do
        if not tiers.empty(t.gear) or t.gear == keep then list[#list + 1] = t.gear; end
    end
    if #list == 0 then list[1] = keep or set.gear or {}; end
    set.gear = list[1];
    local more = {};
    for i = 2, #list do more[#more + 1] = list[i]; end
    set.more = (#more > 0) and more or nil;
    return tiers.count(set) ~= before or set.gear ~= first;
end

-- Add an empty tier; returns it
function tiers.add(set)
    set.more = set.more or {};
    local g = {};
    set.more[#set.more + 1] = g;
    return g;
end

-- The gear worn at a level: the tiers at or below it, lowest first (the lowest one always)
function tiers.effective(set, level)
    local list = tiers.sorted(set);
    if #list == 1 then return list[1].gear; end
    level = tonumber(level) or 99;
    local out = {};
    for k, t in ipairs(list) do
        if k == 1 or t.level <= level then
            for s = 0, 15 do
                local e = t.gear[s];
                if e and (e.id or e.remove) then out[s] = e; end
            end
        end
    end
    return out;
end

-- What the tiers below `g` hand on to it (shown faded in its empty slots)
function tiers.inherited(set, g)
    local out = {};
    for _, t in ipairs(tiers.sorted(set)) do
        if t.gear == g then break; end
        for s = 0, 15 do
            local e = t.gear[s];
            if e and (e.id or e.remove) then out[s] = e; end
        end
    end
    return out;
end

-- The level a tier is worn from (for labels): its level, or 1 for the lowest
function tiers.from_level(set, g)
    local list = tiers.sorted(set);
    for k, t in ipairs(list) do if t.gear == g then return (k == 1) and 1 or t.level, t.level; end end
    return 1, 0;
end

-- Every tier's gear (for checks)
function tiers.all(set)
    local t = { set.gear or {} };
    for _, g in ipairs(set.more or {}) do t[#t + 1] = g; end
    return t;
end

return tiers;
