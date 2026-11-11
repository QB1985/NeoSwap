-- game.lua : what the game is doing now - your status, HP/MP/TP, buffs, Vana'diel day, time and weather, your pet -
-- and the lists of spells, weapon skills and abilities the set editor offers.
-- The memory signatures and the day / weather tables are LuAshitacast's (by Thorny, GPL-3.0).
local game = {};

local pVanaTime, pWeather = 0, 0;

function game.init()
    pcall(function()
        pVanaTime = ashita.memory.find('FFXiMain.dll', 0, 'B0015EC390518B4C24088D4424005068', 0, 0) or 0;
        pWeather  = ashita.memory.find('FFXiMain.dll', 0, '66A1????????663D????72', 0, 0) or 0;
    end);
end

game.ELEMENTS = { 'Fire', 'Ice', 'Wind', 'Earth', 'Thunder', 'Water', 'Light', 'Dark' };
game.DAYS = { 'Firesday', 'Earthsday', 'Watersday', 'Windsday', 'Iceday', 'Lightningday', 'Lightsday', 'Darksday' };
local DAY_ELEMENT = { 'Fire', 'Earth', 'Water', 'Wind', 'Ice', 'Thunder', 'Light', 'Dark' };
-- (weather id + 1) -> element
local WEATHER_ELEMENT = { 'None', 'None', 'None', 'None', 'Fire', 'Fire', 'Water', 'Water', 'Earth', 'Earth', 'Wind', 'Wind',
                          'Ice', 'Ice', 'Thunder', 'Thunder', 'Light', 'Light', 'Dark', 'Dark' };
-- Scholar storms count as weather
local STORM = { [178] = 4, [179] = 12, [180] = 10, [181] = 8, [182] = 14, [183] = 6, [184] = 16, [185] = 18,
                [589] = 5, [590] = 13, [591] = 11, [592] = 9, [593] = 15, [594] = 7, [595] = 17, [596] = 19 };
-- (spell element + 1) -> name
game.SPELL_ELEMENT = { 'Fire', 'Ice', 'Wind', 'Earth', 'Thunder', 'Water', 'Light', 'Dark' };
-- spell skill id -> name
game.SKILLS = { [32] = 'Divine Magic', [33] = 'Healing Magic', [34] = 'Enhancing Magic', [35] = 'Enfeebling Magic',
                [36] = 'Elemental Magic', [37] = 'Dark Magic', [38] = 'Summoning Magic', [39] = 'Ninjutsu', [40] = 'Singing',
                [43] = 'Blue Magic', [44] = 'Geomancy' };
game.SKILL_LIST = { 'Healing Magic', 'Enhancing Magic', 'Enfeebling Magic', 'Divine Magic', 'Elemental Magic', 'Dark Magic',
                    'Summoning Magic', 'Ninjutsu', 'Singing', 'Blue Magic', 'Geomancy' };
-- spell type id -> LuAshitacast's name
game.SPELL_TYPES = { [1] = 'White Magic', [2] = 'Black Magic', [3] = 'Summoning', [4] = 'Ninjutsu', [5] = 'Bard Song', [6] = 'Blue Magic' };
-- the status in the entity list
local STATUS = { [0] = 'Idle', [1] = 'Engaged', [2] = 'Dead', [3] = 'Dead', [4] = 'Zoning', [5] = 'Chocobo', [33] = 'Resting', [85] = 'Chocobo' };
-- (4: in an event / cutscene - nothing is swapped then. 5: riding a chocobo, 85: a mount)

local function mm() return AshitaCore:GetMemoryManager(); end
local function rm() return AshitaCore:GetResourceManager(); end

local function clean(s)
    if type(s) ~= 'string' then return nil; end
    return (s:gsub('%z.*$', ''));
end

----------------------------------------------------------------------------------------------------
-- You
----------------------------------------------------------------------------------------------------
function game.logged_in()
    local ok, sid = pcall(function() return mm():GetParty():GetMemberServerId(0); end);
    return ok and (tonumber(sid) or 0) ~= 0;
end

function game.me()
    local ok, name, id = pcall(function()
        local p = mm():GetParty();
        return p:GetMemberName(0), p:GetMemberServerId(0);
    end);
    if not ok or (tonumber(id) or 0) == 0 then return nil, nil; end
    return clean(name), tonumber(id);
end

function game.status()
    local ok, v = pcall(function()
        local idx = mm():GetParty():GetMemberTargetIndex(0);
        return mm():GetEntity():GetStatus(idx);
    end);
    return STATUS[ok and tonumber(v) or 0] or 'Idle';
end

-- Standing at a chocobo stable: one of the stable's chocobos (an NPC named "Chocobo") within a few yalms, and you're
-- not fighting. Looked at once a second.
local stable = { at = -1, v = false };
game.STABLE_RANGE = 8;
function game.near_stable()
    local now = os.clock();
    if now - stable.at < 1 then return stable.v; end
    stable.at = now;
    local found = false;
    pcall(function()
        local ent = mm():GetEntity();
        local r2 = game.STABLE_RANGE * game.STABLE_RANGE;
        for i = 1, 0x3FF do                                   -- (NPCs and monsters live below 0x400)
            local d = ent:GetDistance(i);
            if d ~= nil and d > 0 and d <= r2 then
                local rf = ent:GetRenderFlags0(i) or 0;
                if bit.band(rf, 0x200) ~= 0 and clean(ent:GetName(i)) == 'Chocobo' then
                    found = true; return;
                end
            end
        end
    end);
    stable.v = found;
    return found;
end

function game.vitals()
    local t = { hp = 0, hpp = 100, mp = 0, mpp = 100, tp = 0, maxmp = 0 };
    pcall(function()
        local p = mm():GetParty();
        t.hp, t.hpp = p:GetMemberHP(0), p:GetMemberHPPercent(0);
        t.mp, t.mpp = p:GetMemberMP(0), p:GetMemberMPPercent(0);
        t.tp = p:GetMemberTP(0);
        t.maxmp = mm():GetPlayer():GetMPMax();
    end);
    return t;
end

function game.zone_name()
    local ok, v = pcall(function()
        return rm():GetString('zones.names', mm():GetParty():GetMemberZone(0));
    end);
    return ok and clean(v) or '';
end

-- Your buffs, by lower-case name: { ['haste'] = 1, ['protect'] = 1, ... }
function game.buffs()
    local t = {};
    pcall(function()
        for _, b in pairs(mm():GetPlayer():GetBuffs()) do
            if b ~= nil and b > 0 and b ~= 255 then
                local n = clean(rm():GetString('buffs.names', b));
                if n and n ~= '' then n = n:lower(); t[n] = (t[n] or 0) + 1; end
            end
        end
    end);
    return t;
end

function game.buff_ids()
    local t = {};
    pcall(function() for _, b in pairs(mm():GetPlayer():GetBuffs()) do if b and b > 0 then t[b] = true; end end end);
    return t;
end

----------------------------------------------------------------------------------------------------
-- Vana'diel: day, hour, weather
----------------------------------------------------------------------------------------------------
function game.vana()
    local t = { day = nil, day_element = nil, hour = 12, minute = 0 };
    if pVanaTime == 0 then return t; end
    pcall(function()
        local pointer = ashita.memory.read_uint32(pVanaTime + 0x34);
        local raw = ashita.memory.read_uint32(pointer + 0x0C) + 92514960;
        local day = math.floor(raw / 3456);
        t.day = game.DAYS[(day % 8) + 1];
        t.day_element = DAY_ELEMENT[(day % 8) + 1];
        t.hour = math.floor(raw / 144) % 24;
        t.minute = math.floor((raw % 144) / 2.4);
    end);
    return t;
end

function game.weather_element()
    local w = 0;
    if pWeather ~= 0 then
        pcall(function()
            local pointer = ashita.memory.read_uint32(pWeather + 0x02);
            w = ashita.memory.read_uint8(pointer + 0);
        end);
    end
    for b in pairs(game.buff_ids()) do if STORM[b] then w = STORM[b]; end end
    return WEATHER_ELEMENT[w + 1] or 'None';
end

----------------------------------------------------------------------------------------------------
-- Your pet
----------------------------------------------------------------------------------------------------
function game.pet()
    local r = nil;
    pcall(function()
        local me = mm():GetParty():GetMemberTargetIndex(0);
        local pi = mm():GetEntity():GetPetTargetIndex(me);
        if pi == 0 or mm():GetEntity():GetHPPercent(pi) == 0 then return; end
        r = { index = pi, name = clean(mm():GetEntity():GetName(pi)) or '', hpp = mm():GetEntity():GetHPPercent(pi),
              id = mm():GetEntity():GetServerId(pi) };
    end);
    return r;
end

----------------------------------------------------------------------------------------------------
-- Names for the editor's pickers (read from the game's resources once)
----------------------------------------------------------------------------------------------------
local lists = {};

-- Weapon skills, with the weapon they belong to: { name, group }
local WS_GROUP = { 'Hand-to-Hand', 'Dagger', 'Sword', 'Great Sword', 'Axe', 'Great Axe', 'Scythe', 'Polearm', 'Katana',
                   'Great Katana', 'Club', 'Staff', 'Archery', 'Marksmanship' };
function game.weaponskills()
    if lists.ws then return lists.ws; end
    local t, seen = {}, {};
    for id = 1, 255 do
        local r = rm():GetAbilityById(id);
        local n = r and r.Name and clean(r.Name[1]);
        if n and #n > 1 and not seen[n:lower()] then
            seen[n:lower()] = true;
            t[#t + 1] = { name = n, id = id, group = WS_GROUP[math.floor((id - 1) / 16) + 1] or 'Other' };
        end
    end
    lists.ws = t;
    return t;
end

-- the ability types LuAshitacast names (by recast timer)
game.ABILITY_TYPES = { [10] = 'Rune Enchantment', [102] = 'Ready', [173] = 'Blood Pact: Rage', [174] = 'Blood Pact: Ward',
                       [193] = 'Corsair Roll', [195] = 'Quick Draw' };

-- Every job ability (names), from the resources: { name, id, type }
function game.abilities()
    if lists.ja then return lists.ja; end
    local t, seen = {}, {};
    for id = 0x200, 0x200 + 1023 do
        local r = rm():GetAbilityById(id);
        local n = r and r.Name and clean(r.Name[1]);
        if n and #n > 1 and not seen[n:lower()] then
            seen[n:lower()] = true;
            t[#t + 1] = { name = n, id = id - 0x200, type = game.ABILITY_TYPES[tonumber(r.RecastTimerId) or -1] };
        end
    end
    table.sort(t, function(a, b) return a.name < b.name; end);
    lists.ja = t;
    return t;
end

-- Every spell: { name, skill, element, jobs = { [job id] = level } }
function game.spells()
    if lists.spells then return lists.spells; end
    local t, seen = {}, {};
    for id = 1, 1023 do
        local r = rm():GetSpellById(id);
        local n = r and r.Name and clean(r.Name[1]);
        if n and #n > 1 and not seen[n:lower()] then
            seen[n:lower()] = true;
            local e = { name = n, id = id, type = game.SPELL_TYPES[tonumber(r.Type) or 0], cast = tonumber(r.CastTime) or 0,
                        mp = tonumber(r.ManaCost) or 0, skill = game.SKILLS[tonumber(r.Skill) or 0] or 'Other',
                        element = game.SPELL_ELEMENT[(tonumber(r.Element) or 15) + 1], jobs = {} };
            pcall(function()
                for j = 1, 22 do
                    local lv = tonumber(r.LevelRequired[j + 1]) or -1;
                    if lv > 0 and lv < 100 then e.jobs[j] = lv; end
                end
            end);
            t[#t + 1] = e;
        end
    end
    table.sort(t, function(a, b) return a.name < b.name; end);
    lists.spells = t;
    lists.spell_by_name = {};
    for _, e in ipairs(t) do lists.spell_by_name[e.name] = e; end
    return t;
end

function game.spell_info(name)
    if lists.spell_by_name == nil then game.spells(); end
    return lists.spell_by_name[name];
end

-- Buff names (for "buff is on" conditions)
function game.buff_names()
    if lists.buffs then return lists.buffs; end
    local t, seen = {}, {};
    for id = 1, 640 do
        local n = nil;
        pcall(function() n = clean(rm():GetString('buffs.names', id)); end);
        if n and #n > 1 and not seen[n:lower()] then
            seen[n:lower()] = true;
            t[#t + 1] = { name = n };
        end
    end
    table.sort(t, function(a, b) return a.name < b.name; end);
    lists.buffs = t;
    return t;
end

return game;
