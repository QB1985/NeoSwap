-- import.lua : read a LuAshitacast profile into NeoSwap sets.
--
-- A profile is a program, so it isn't read as text: it's run in a sandbox with a stand-in for LuAshitacast
-- (gFunc, gData, gSettings) and asked what it would put on in each situation - standing idle, engaged, resting,
-- idle with a pet out, moving, every weapon skill / ability / spell / pet move it mentions or the job can use,
-- ranged, items. What it puts on becomes the sets: the broad ones (Idle, every weapon skill, a magic skill) with
-- their full gear, the narrow ones (a named weapon skill, a pet out) with only what they change. Its named sets
-- (profile.Sets) that weren't used come too, unticked, as Manual sets. Its macro book / page (from OnLoad) and a
-- set called Lockstyle are offered as well. Nothing it does reaches the game: commands, packets and events are
-- caught, not sent.
local items = require('core.items');
local game  = require('core.game');
local jobs  = require('core.jobs');
local bags  = require('core.bags');
local ABIL  = require('data.abilities');
local tiers = require('core.tiers');

local import = {};

local SLOTS = { main = 0, sub = 1, range = 2, ammo = 3, head = 4, body = 5, hands = 6, legs = 7, feet = 8, neck = 9,
                waist = 10, ear1 = 11, ear2 = 12, ring1 = 13, ring2 = 14, back = 15 };
local NUM_SLOT = { [1] = 0, [2] = 1, [3] = 2, [4] = 3, [5] = 4, [6] = 5, [7] = 6, [8] = 7, [9] = 8, [10] = 9, [11] = 10,
                   [12] = 11, [13] = 12, [14] = 13, [15] = 14, [16] = 15 };
local FAKE = 'NeoSwap Probe';                                         -- (a name no profile has a set for)

local function base_dir() return string.format('%sconfig\\addons\\luashitacast\\', AshitaCore:GetInstallPath()); end

-- The profiles LuAshitacast would load for this character: Name_id\JOB.lua, or Name_JOB.lua
function import.list_files()
    local name, id = game.me();
    local out = {};
    if name == nil then return out; end
    for _, a in ipairs(jobs.ABBR) do
        local p1 = string.format('%s%s_%u\\%s.lua', base_dir(), name, id, a);
        local p2 = string.format('%s%s_%s.lua', base_dir(), name, a);
        if ashita.fs.exists(p1) then out[#out + 1] = { job = a, path = p1, file = name .. '_' .. id .. '\\' .. a .. '.lua' };
        elseif ashita.fs.exists(p2) then out[#out + 1] = { job = a, path = p2, file = name .. '_' .. a .. '.lua' }; end
    end
    return out;
end

----------------------------------------------------------------------------------------------------
-- The sandbox
----------------------------------------------------------------------------------------------------
local function slot_of(k)
    if type(k) == 'number' then return NUM_SLOT[k]; end
    if type(k) ~= 'string' then return nil; end
    return SLOTS[k:lower()];
end

-- what a set's entry means: { name } / { remove = true } / 'skip' (leave alone) / nil (not an item)
local function entry_of(v)
    local n = v;
    if type(v) == 'table' then n = v.Name; end
    if type(n) ~= 'string' then return nil; end
    local l = n:lower():gsub('^%s+', ''):gsub('%s+$', '');
    if l == 'remove' then return { remove = true }; end
    if l == '' or l == 'displaced' or l == 'ignore' then return 'skip'; end
    local e = { name = n };
    -- { Name = 'Chironic Hat', Augment = { 'Mag. Acc.+20', '"Refresh"+1' }, AugPath = 'A', AugRank = 15 }
    if type(v) == 'table' then
        if type(v.Augment) == 'string' then e.augs = { v.Augment };
        elseif type(v.Augment) == 'table' then
            e.augs = {};
            for _, a in pairs(v.Augment) do if type(a) == 'string' then e.augs[#e.augs + 1] = a; end end
            table.sort(e.augs);
            if #e.augs == 0 then e.augs = nil; end
        end
        if type(v.AugPath) == 'string' then e.path = v.AugPath; end
        if type(v.AugRank) == 'number' then e.rank = v.AugRank; end
    end
    return e;
end

local function aug_key(e)
    if e.augs == nil and e.path == nil and e.rank == nil then return ''; end
    return '{' .. table.concat(e.augs or {}, ',') .. '/' .. tostring(e.path or '') .. '/' .. tostring(e.rank or '') .. '}';
end

local function is_set(t)
    if type(t) ~= 'table' then return false; end
    for k, v in pairs(t) do if slot_of(k) ~= nil and type(k) == 'string' and entry_of(v) ~= nil then return true; end end
    return false;
end

local function make_sandbox(path, scen, res)
    local env = {};
    local profile_ref = {};
    local chat = {
        QueueCommand = function(_, _, cmd)
            cmd = tostring(cmd or '');
            local l = cmd:lower();
            local b = l:match('^/macro book (%d+)');
            if b then res.macro.book = tonumber(b); return; end
            local p = l:match('^/macro set (%d+)');
            if p then res.macro.page = tonumber(p); return; end
            local ls = l:match('^/lockstyleset (%d+)');
            if ls then res.lockstyleset = tonumber(ls); return; end
            local sl, item = cmd:match('^/equip%s+(%a+%d?)%s+"(.-)"');
            if sl == nil then sl, item = cmd:match('^/equip%s+(%a+%d?)%s+(.+)$'); end
            if sl and item and scen.buf then
                local s = SLOTS[sl:lower()];
                if s ~= nil then scen.buf[s] = { name = item }; end
            end
        end,
    };
    local fake_packets = { AddOutgoingPacket = function() end, AddIncomingPacket = function() end };
    local core = setmetatable({
        GetChatManager = function() return chat; end,
        GetPacketManager = function() return fake_packets; end,
    }, { __index = function(_, k)
        local f = AshitaCore[k];
        if type(f) == 'function' then return function(_, ...) return f(AshitaCore, ...); end end
        return f;
    end });
    local fake_events = { register = function() end, unregister = function() end };
    local ash = setmetatable({ events = fake_events }, { __index = ashita });

    -- what gets put on
    local function equip(slot, item)
        local s = slot_of(slot);
        if s == nil then return; end
        local e = entry_of(item);
        if e == nil then return; end
        if type(item) == 'string' and item:lower() == 'ignore' then scen.buf[s] = nil; return; end
        if e == 'skip' then return; end
        scen.buf[s] = e;
    end
    local function find_set(name)
        local ref = profile_ref.p and profile_ref.p.Sets;
        if type(ref) ~= 'table' then return nil; end
        name = name:lower();
        for part in name:gmatch('[^%.]+') do
            local found = nil;
            for k, v in pairs(ref) do if type(k) == 'string' and k:lower() == part then found = v; break; end end
            if type(found) ~= 'table' then return nil; end
            ref = found;
        end
        return ref;
    end
    local function equip_set(set)
        if type(set) == 'string' then set = find_set(set); end
        if type(set) ~= 'table' then return; end
        for k, v in pairs(set) do equip(k, v); end
    end
    local noop = function() end;
    local gFunc = setmetatable({
        Equip = equip, EquipSet = equip_set, ForceEquip = equip, ForceEquipSet = equip_set, LockSet = equip_set,
        InterimEquip = noop, InterimEquipSet = noop,
        LockStyle = function(set)
            if type(set) == 'string' then set = find_set(set); end
            if type(set) ~= 'table' then return; end
            local buf = {};
            for k, v in pairs(set) do
                local sl = slot_of(k);
                local e = sl and entry_of(v);
                if sl and e and e ~= 'skip' then buf[sl] = e; end
            end
            res.lockstyle_buf = buf;
        end,
        Combine = function(a, b)
            local t = {};
            for k, v in pairs(a or {}) do t[k] = v; end
            for k, v in pairs(b or {}) do t[k] = v; end
            return t;
        end,
        LoadFile = function(p)
            local dir = path:match('^(.*\\)') or '';
            for _, try in ipairs({ p, p .. '.lua', dir .. p, dir .. p .. '.lua', base_dir() .. p, base_dir() .. p .. '.lua' }) do
                if ashita.fs.exists(try) then
                    local f = loadfile(try);
                    if f then setfenv(f, env); local ok, v = pcall(f); if ok then return v; end end
                end
            end
            return nil;
        end,
    }, { __index = function() return noop; end });

    local gData = setmetatable({
        GetPlayer = function()
            return { Name = 'You', Status = scen.status or 'Idle', HP = 1000, MaxHP = 1000, HPP = 100, MP = 800, MaxMP = 800, MPP = 100,
                     TP = 0, MainJob = scen.job, MainJobLevel = scen.level, MainJobSync = scen.level, SubJob = scen.sub,
                     SubJobLevel = scen.sublevel, SubJobSync = scen.sublevel, IsMoving = scen.moving == true };
        end,
        GetAction = function() return scen.action; end,
        GetActionTarget = function() return { Name = 'Target', Distance = 5, HPP = 100, Id = 1, Index = 1, Status = 'Engaged', Type = 'Monster' }; end,
        GetTarget = function() return { Name = 'Target', Distance = 5, HPP = 100, Id = 1, Index = 1, Status = 'Engaged', Type = 'Monster' }; end,
        GetEnvironment = function()
            return { Area = 'Nowhere', Day = 'Lightsday', DayElement = 'None', Weather = 'Clear', WeatherElement = 'None',
                     RawWeather = 'Clear', RawWeatherElement = 'None', Time = 12.0, MoonPhase = 'Full Moon', MoonPercent = 100,
                     Timestamp = { day = 0, hour = 12, minute = 0 } };
        end,
        GetBuffCount = function() return 0; end,
        GetPet = function() return scen.pet; end,
        GetPetAction = function() return scen.pet_action; end,
        GetEquipment = function() return {}; end,
        GetEquipScreen = function() return {}; end,
        GetParty = function() return { Count = 1, InParty = false, Target = false, ActionTarget = false }; end,
        GetAlliance = function() return { Count = 1, InAlly = false, Target = false, ActionTarget = false }; end,
        GetCurrentCall = function() return scen.call or 'N/A'; end,
        GetTimestamp = function() return { day = 0, hour = 12, minute = 0 }; end,
        GetWeather = function() return 0; end,
        Constants = setmetatable({}, { __index = function() return {}; end }),
    }, { __index = function() return noop; end });

    env.gFunc, env.gData = gFunc, gData;
    env.gSettings = setmetatable({}, { __index = function() return 0; end });
    env.gState = setmetatable({}, { __index = function() return nil; end });
    env.gProfile = nil;
    env.AshitaCore = core;
    env.ashita = ash;
    env.print = noop;
    setmetatable(env, { __index = _G });
    return env, profile_ref;
end

----------------------------------------------------------------------------------------------------
-- Outcomes
----------------------------------------------------------------------------------------------------
local function key_of(buf)
    local t = {};
    for s = 0, 15 do
        local e = buf[s];
        if e then t[#t + 1] = s .. '=' .. (e.remove and '!' or (e.name:lower() .. aug_key(e))); end
    end
    return table.concat(t, '|');
end

local function same(a, b) return a ~= nil and b ~= nil and ((a.remove and b.remove) or (a.name and b.name and a.name:lower() == b.name:lower() and aug_key(a) == aug_key(b))); end

-- what `over` changes from `base`
local function diff(over, base)
    local d = {};
    for s = 0, 15 do
        if over[s] and not same(over[s], base[s]) then d[s] = over[s]; end
    end
    return d;
end

local function empty(buf) return next(buf) == nil; end

-- "Cure IV", or "Cure IV +3"
local function title(names, prefix)
    local t = names[1] or '?';
    if #names > 1 then t = t .. ' +' .. (#names - 1); end
    return prefix and (prefix .. t) or t;
end

----------------------------------------------------------------------------------------------------
-- Reading a profile
----------------------------------------------------------------------------------------------------
-- abbr: the job; level: the level to read it at (profiles with level milestones); sub / sublevel: the support job.
-- Returns { sets = { { name, when, gear, missing, pick, from } }, macro = { book, page }, lockstyle, notes, errors }
local function read_once(path, abbr, level, sub, sublevel)
    local res = { sets = {}, macro = {}, notes = {}, errors = {}, path = path };
    local job = jobs.id(abbr) or 0;
    local scen = { job = abbr, level = level, sub = sub or 'WHM', sublevel = sublevel or math.floor(level / 2), buf = {} };

    local f, err = loadfile(path);
    if not f then res.errors[#res.errors + 1] = 'Could not read the file: ' .. tostring(err); return res; end
    local env, pref = make_sandbox(path, scen, res);
    setfenv(f, env);
    local ok, profile = pcall(f);
    if not ok or type(profile) ~= 'table' then
        res.errors[#res.errors + 1] = 'The profile stopped with an error: ' .. tostring(profile);
        return res;
    end
    pref.p = profile;
    env.gProfile = profile;
    -- the levels the profile changes gear at (numeric keys in its sets: sets.base[10], sets.ability.Jump[50]...)
    res.milestones = {};
    do
        local seen_t, ms = {}, {};
        local function scan(t, d)
            if type(t) ~= 'table' or d > 6 or seen_t[t] then return; end
            seen_t[t] = true;
            for k, v in pairs(t) do
                if type(k) == 'number' and k >= 1 and k <= 99 and k == math.floor(k) and type(v) == 'table' then ms[k] = true; end
                if type(v) == 'table' then scan(v, d + 1); end
            end
        end
        scan(profile.Sets, 0);
        for k in pairs(ms) do res.milestones[#res.milestones + 1] = k; end
        table.sort(res.milestones);
    end
    if type(profile.OnLoad) == 'function' then
        local okl, e = pcall(profile.OnLoad);
        if not okl then res.notes[#res.notes + 1] = 'OnLoad: ' .. tostring(e); end
    end

    local err_seen = {};
    local function run(handler, s)
        scen.buf = {};
        scen.status, scen.pet, scen.pet_action, scen.moving, scen.action = s.status or 'Idle', s.pet, s.pet_action, s.moving, s.action;
        scen.call = handler;
        local fn = profile[handler];
        if type(fn) ~= 'function' then return {}; end
        local okr, e = pcall(fn);
        if not okr then
            local m = handler .. ': ' .. tostring(e);
            if not err_seen[m] and #res.notes < 12 then err_seen[m] = true; res.notes[#res.notes + 1] = m; end
        end
        local b = scen.buf;
        scen.buf = {};
        return b;
    end

    -- names the profile mentions: its quoted strings ("^Cure" -> "Cure") and its set names
    local mentioned = {};
    do
        local fh = io.open(path, 'r');
        local src = fh and fh:read('*a') or '';
        if fh then fh:close(); end
        for q in src:gmatch('"([^"\n]+)"') do mentioned[q:gsub('[%^%$]', ''):gsub('%%%-', '-'):lower()] = true; end
        for q in src:gmatch("'([^'\n]+)'") do mentioned[q:gsub('[%^%$]', ''):gsub('%%%-', '-'):lower()] = true; end
        local function walk(t, d)
            if type(t) ~= 'table' or d > 4 then return; end
            for k, v in pairs(t) do
                if type(k) == 'string' then mentioned[k:lower()] = true; mentioned[k:lower():gsub('_', ' ')] = true; end
                walk(v, d + 1);
            end
        end
        walk(profile.Sets, 0);
    end
    local function mentions(n) return mentioned[n:lower()] or mentioned[n:lower():gsub('%s', '')] or false; end

    local out = {};
    local function add(name, kind, gear, extra)
        if empty(gear) then return; end
        local w = { kind = kind, names = {}, skills = {}, cond = {} };
        if extra then for k, v in pairs(extra) do w[k] = v; end end
        out[#out + 1] = { name = name, when = w, raw = gear, pick = true, from = 'run' };
    end

    ------------------------------------------------------------------ idle / engaged / resting
    local idle = run('HandleDefault', { status = 'Idle' });
    local engaged = run('HandleDefault', { status = 'Engaged' });
    local resting = run('HandleDefault', { status = 'Resting' });
    add('Idle', 'idle', idle);
    -- (Engaged and Resting go on over Idle, so they keep only what they change)
    add('Engaged', 'engaged', diff(engaged, idle));
    add('Resting', 'resting', diff(resting, idle));
    local pet = { Name = 'Pet', HPP = 100, TP = 0, Status = 'Idle', Distance = 3, Id = 1, Index = 1 };
    local idle_pet = run('HandleDefault', { status = 'Idle', pet = pet });
    add('Idle - pet out', 'idle', diff(idle_pet, idle), { cond = { { t = 'pet_out' }, { t = 'status', v = 'Idle' } } });
    local idle_move = run('HandleDefault', { status = 'Idle', moving = true });
    add('Idle - moving', 'idle', diff(idle_move, idle), { cond = { { t = 'moving' }, { t = 'status', v = 'Idle' } } });
    local eng_pet = run('HandleDefault', { status = 'Engaged', pet = pet });
    add('Engaged - pet out', 'engaged', diff(eng_pet, engaged), { cond = { { t = 'pet_out' } } });

    ------------------------------------------------------------------ the general way: generic, by type, by name
    -- probe(name, type) -> outcome. Groups the names whose outcome differs from their type's (or the generic one).
    local function by_name(kind, label, probe, names, types, base_of)
        base_of = base_of or function(o) return o; end
        local generic = base_of(probe(FAKE, nil));
        add(label, kind, generic);
        local groups, order = {}, {};
        local function put(n, d)
            if empty(d) then return; end
            local k = key_of(d);
            if groups[k] == nil then groups[k] = { names = {}, gear = d }; order[#order + 1] = k; end
            local g = groups[k].names;
            g[#g + 1] = n;
        end
        -- ability types ("Blood Pact: Rage" covers every Rage pact)
        local type_out = {};
        for _, t in ipairs(types or {}) do
            local o = base_of(probe(FAKE, t));
            if key_of(o) ~= key_of(generic) then type_out[t] = o; put(t, diff(o, generic)); end
        end
        -- named ones that differ from their type (or from the generic one)
        for _, n in ipairs(names) do
            local o = base_of(probe(n.name, n.type));
            put(n.name, diff(o, (n.type and type_out[n.type]) or generic));
        end
        for _, k in ipairs(order) do
            local g = groups[k];
            add(title(g.names, label .. ': '), kind, g.gear, { names = g.names });
        end
    end

    ------------------------------------------------------------------ weapon skills
    local ws_names = {};
    for _, e in ipairs(game.weaponskills()) do if mentions(e.name) then ws_names[#ws_names + 1] = { name = e.name, id = e.id }; end end
    local ws_id = {};
    for _, e in ipairs(ws_names) do ws_id[e.name] = e.id; end
    by_name('ws', 'Weapon skill', function(n)
        return run('HandleWeaponskill', { status = 'Engaged', action = { ActionType = 'Weaponskill', Name = n, Id = ws_id[n] or 0 } });
    end, ws_names);

    ------------------------------------------------------------------ abilities
    local ja_names, seen = {}, {};
    local all_ja = {};
    for _, e in ipairs(game.abilities()) do all_ja[e.name:lower()] = e; end
    local function add_ja(n)
        local e = all_ja[n:lower()];
        if e and not seen[e.name] then seen[e.name] = true; ja_names[#ja_names + 1] = { name = e.name, type = e.type, id = e.id }; end
    end
    for _, n in ipairs((ABIL[abbr] and ABIL[abbr].ja) or {}) do add_ja(n); end
    for _, e in ipairs(game.abilities()) do if mentions(e.name) then add_ja(e.name); end end
    local ja_id = {};
    for _, e in ipairs(ja_names) do ja_id[e.name] = e.id; end
    by_name('ja', 'Job ability', function(n, t)
        return run('HandleAbility', { status = 'Engaged', action = { ActionType = 'Ability', Name = n, Id = ja_id[n] or 0, Type = t or 'Generic' } });
    end, ja_names, { 'Blood Pact: Rage', 'Blood Pact: Ward', 'Ready', 'Corsair Roll', 'Quick Draw', 'Rune Enchantment' });

    ------------------------------------------------------------------ pet moves (over idle with the pet out)
    local pet_names, pseen = {}, {};
    local function add_pet(n)
        local e = all_ja[n:lower()];
        local nm = e and e.name or n;
        if not pseen[nm:lower()] then pseen[nm:lower()] = true; pet_names[#pet_names + 1] = { name = nm, type = e and e.type or nil }; end
    end
    for _, n in ipairs((ABIL[abbr] and ABIL[abbr].pet) or {}) do add_pet(n); end
    for n in pairs(mentioned) do if all_ja[n] and all_ja[n].type ~= nil then add_pet(n); end end
    by_name('pet', 'Pet action', function(n, t)
        return run('HandleDefault', { status = 'Idle', pet = pet, pet_action = { ActionType = 'Ability', Name = n, Type = t, Id = 0 } });
    end, pet_names, { 'Blood Pact: Rage', 'Blood Pact: Ward', 'Ready' }, function(o) return diff(o, idle_pet); end);

    ------------------------------------------------------------------ spells: every spell, a magic skill, named spells
    local spells, sseen = {}, {};
    local sub_id = jobs.id(scen.sub);
    for _, e in ipairs(game.spells()) do
        local mine = (e.jobs[job] and e.jobs[job] <= level) or (sub_id and e.jobs[sub_id] and e.jobs[sub_id] <= scen.sublevel) or mentions(e.name);
        if mine and not sseen[e.name] then sseen[e.name] = true; spells[#spells + 1] = e; end
    end
    local function spell_action(e)
        return { ActionType = 'Spell', Name = e.name, Id = e.id, Skill = e.skill, Type = e.type or 'White Magic', Element = e.element or 'Non-Elemental',
                 MpCost = e.mp, CastTime = (e.cast or 0) * 250, Recast = 0, MpAftercast = 500, MppAftercast = 60 };
    end
    local function spells_for(handler, kind, label)
        if type(profile[handler]) ~= 'function' or #spells == 0 then return; end
        local outs = {};
        local by_skill, skill_order = {}, {};
        for _, e in ipairs(spells) do
            local o = run(handler, { status = 'Idle', action = spell_action(e) });
            outs[e.name] = o;
            local sk = e.skill or 'Other';
            if by_skill[sk] == nil then by_skill[sk] = { counts = {}, outs = {} }; skill_order[#skill_order + 1] = sk; end
            local k = key_of(o);
            by_skill[sk].counts[k] = (by_skill[sk].counts[k] or 0) + 1;
            by_skill[sk].outs[k] = o;
        end
        -- each skill's usual outcome, and the usual one over all skills
        local skill_out, all_counts, all_outs = {}, {}, {};
        for _, sk in ipairs(skill_order) do
            local best, bk = -1, nil;
            for k, c in pairs(by_skill[sk].counts) do if c > best then best, bk = c, k; end end
            skill_out[sk] = by_skill[sk].outs[bk];
            all_counts[bk] = (all_counts[bk] or 0) + 1;
            all_outs[bk] = skill_out[sk];
        end
        local best, base = -1, {};
        for k, c in pairs(all_counts) do if c > best then best, base = c, all_outs[k]; end end
        add(label, kind, base);
        for _, sk in ipairs(skill_order) do
            if sk ~= 'Other' then
                local d = diff(skill_out[sk], base);
                add(label .. ': ' .. sk, kind, d, { skills = { sk } });
            end
        end
        local groups, order = {}, {};
        for _, e in ipairs(spells) do
            local ref = skill_out[e.skill or 'Other'] or base;
            local d = diff(outs[e.name], ref);
            if not empty(d) then
                local k = (e.skill or '') .. '#' .. key_of(d);
                if groups[k] == nil then groups[k] = { names = {}, gear = d }; order[#order + 1] = k; end
                local g = groups[k].names;
                g[#g + 1] = e.name;
            end
        end
        for _, k in ipairs(order) do
            local g = groups[k];
            add(title(g.names, label .. ': '), kind, g.gear, { names = g.names });
        end
    end
    spells_for('HandlePrecast', 'precast', 'Precast');
    spells_for('HandleMidcast', 'midcast', 'Midcast');

    ------------------------------------------------------------------ ranged, items
    add('Preshot', 'preshot', run('HandlePreshot', { status = 'Engaged', action = { ActionType = 'Ranged', Name = 'Ranged', Id = 0 } }));
    add('Midshot', 'midshot', run('HandleMidshot', { status = 'Engaged', action = { ActionType = 'Ranged', Name = 'Ranged', Id = 0 } }));
    local item_names = {};
    for n in pairs(mentioned) do
        local id = items.find_by_name(n);
        if id and not items.is_equipment(id) and #item_names < 40 then item_names[#item_names + 1] = { name = items.name(id) }; end
    end
    table.sort(item_names, function(a, b) return a.name < b.name; end);
    by_name('item', 'Item use', function(n)
        return run('HandleItem', { status = 'Idle', action = { ActionType = 'Item', Name = n, Id = 0, CastTime = 0, Recast = 0 } });
    end, item_names);

    ------------------------------------------------------------------ the profile's own sets that weren't used
    local used = {};
    for _, s in ipairs(out) do used[key_of(s.raw)] = true; end
    used[key_of(idle)], used[key_of(engaged)], used[key_of(resting)] = true, true, true;
    local manual = {};
    local function walk(t, path, d)
        if type(t) ~= 'table' or d > 4 or #manual >= 60 then return; end
        if is_set(t) then
            local buf = {};
            for k, v in pairs(t) do
                local s = slot_of(k);
                local e = s and entry_of(v);
                if s and e and e ~= 'skip' then buf[s] = e; end
            end
            manual[#manual + 1] = { path = path, buf = buf };
            return;
        end
        -- level milestones: the one for this level
        local best = nil;
        for k in pairs(t) do if type(k) == 'number' and k <= level and (best == nil or k > best) then best = k; end end
        if best and is_set(t[best]) then walk(t[best], path, d + 1); return; end
        for k, v in pairs(t) do if type(k) == 'string' then walk(v, path == '' and k or (path .. '.' .. k), d + 1); end end
    end
    walk(profile.Sets, '', 0);
    table.sort(manual, function(a, b) return a.path < b.path; end);
    for _, m in ipairs(manual) do
        if m.path:lower() == 'lockstyle' then
            res.lockstyle_buf = res.lockstyle_buf or m.buf;
        elseif not used[key_of(m.buf)] and not empty(m.buf) then
            used[key_of(m.buf)] = true;
            out[#out + 1] = { name = m.path, when = { kind = 'manual', names = {}, skills = {}, cond = {} }, raw = m.buf, pick = false, from = 'set' };
        end
    end

    ------------------------------------------------------------------ item names -> items
    local function to_gear(buf)
        local g, miss = {}, {};
        for s = 0, 15 do
            local e = buf[s];
            if e then
                if e.remove then g[s] = { remove = true };
                else
                    local id = items.find_by_name(e.name);
                    if id then g[s] = { id = id, name = items.name(id), augs = e.augs, path = e.path, rank = e.rank };
                    else miss[#miss + 1] = bags.SLOT_NAME[s] .. ': ' .. e.name; end
                end
            end
        end
        return g, miss;
    end
    for _, s in ipairs(out) do
        s.gear, s.missing = to_gear(s.raw);
        s.raw = nil;
        if empty(s.gear) then s.pick = false; end
    end
    res.sets = out;
    if res.lockstyle_buf then
        local buf = {};
        for sl, e in pairs(res.lockstyle_buf) do if sl <= 8 and not e.remove then buf[sl] = e; end end
        res.lockstyle, res.lockstyle_missing = to_gear(buf);
        if empty(res.lockstyle) then res.lockstyle = nil; end
    end
    res.lockstyle_buf = nil;
    res.use_macro = res.macro.book ~= nil;
    res.use_lockstyle = res.lockstyle ~= nil;
    return res;
end

----------------------------------------------------------------------------------------------------
-- Reading at every level the profile changes gear at, into sets with levels (core/tiers.lua)
----------------------------------------------------------------------------------------------------
local function gkey(e)
    if e == nil then return ''; end
    if e.remove then return '!'; end
    local a = '';
    if e.augs or e.path or e.rank then a = '{' .. table.concat(e.augs or {}, ',') .. '/' .. tostring(e.path or '') .. '/' .. tostring(e.rank or '') .. '}'; end
    return tostring(e.id) .. a;
end

local function set_key(s)
    local w = s.when or {};
    local first = (w.names and w.names[1]) or '';
    if s.from == 'set' then first = s.name; end
    local cond = {};
    for _, c in ipairs(w.cond or {}) do cond[#cond + 1] = tostring(c.t) .. (c.neg and '!' or '') .. tostring(c.v or ''); end
    table.sort(cond);
    local base = s.name:gsub('%s%+%d+$', '');                         -- ("Cure +3" and "Cure +5" are the same set)
    return table.concat({ w.kind or '', first:lower(), table.concat(w.skills or {}, ','):lower(), table.concat(cond, ','), (#(w.names or {}) == 0) and base:lower() or '' }, '|');
end

-- level: read at every milestone up to it. Returns what read_once returns, with sets that have levels (s.more),
-- and res.levels = the levels read.
function import.read(path, abbr, level, sub, sublevel)
    local top = read_once(path, abbr, level, sub, sublevel);
    local ms = {};
    for _, m in ipairs(top.milestones or {}) do if m < level then ms[#ms + 1] = m; end end
    top.levels = { level };
    if #(top.errors or {}) > 0 or #ms == 0 then return top; end

    -- read again at each lower milestone (a fresh run each time: profiles keep caches)
    local reads = {};
    for _, m in ipairs(ms) do
        local r = read_once(path, abbr, m, sub, math.min(sublevel or math.floor(m / 2), math.floor(m / 2)));
        if #(r.errors or {}) == 0 then reads[#reads + 1] = { level = m, res = r }; end
    end
    reads[#reads + 1] = { level = level, res = top };
    top.levels = {};
    for _, r in ipairs(reads) do top.levels[#top.levels + 1] = r.level; end

    -- the same set at each level -> one set with levels
    local merged, order = {}, {};
    for _, r in ipairs(reads) do
        for _, s in ipairs(r.res.sets) do
            local k = set_key(s);
            local m = merged[k];
            if m == nil then
                m = { name = s.name, when = s.when, pick = s.pick, from = s.from, missing = {}, at = {}, miss_seen = {} };
                merged[k] = m;
                order[#order + 1] = k;
            end
            -- the highest level's name and narrowing win (it has the most names)
            m.name, m.when, m.pick = s.name, s.when, s.pick;
            m.at[#m.at + 1] = { level = r.level, gear = s.gear };
            for _, x in ipairs(s.missing or {}) do
                if not m.miss_seen[x] then m.miss_seen[x] = true; m.missing[#m.missing + 1] = x; end
            end
        end
    end

    -- each set: the first level's gear, then for each later level what changed from the one before
    local out = {};
    for _, k in ipairs(order) do
        local m = merged[k];
        table.sort(m.at, function(a, b) return a.level < b.level; end);
        local set = { name = m.name, when = m.when, pick = m.pick, from = m.from, missing = m.missing, gear = {}, more = nil };
        local prev = nil;
        local by_level = {};
        for i, a in ipairs(m.at) do
            if i == 1 then
                set.gear = a.gear;
            else
                local d = {};
                for sl = 0, 15 do
                    if a.gear[sl] and gkey(a.gear[sl]) ~= gkey(prev[sl]) then d[sl] = a.gear[sl]; end
                end
                if next(d) ~= nil then
                    -- (changes whose pieces come out at the same level go in one level of the set)
                    local lv = tiers.level(d);
                    if by_level[lv] then for sl, e in pairs(d) do by_level[lv][sl] = e; end
                    else
                        by_level[lv] = d;
                        set.more = set.more or {};
                        set.more[#set.more + 1] = d;
                    end
                end
            end
            prev = a.gear;
        end
        if set.more then tiers.normalize(set, nil); end
        out[#out + 1] = set;
    end
    top.sets = out;
    return top;
end

----------------------------------------------------------------------------------------------------
-- Putting it in
----------------------------------------------------------------------------------------------------
-- replace: the job's sets are replaced (else added to). Returns how many sets came in.
function import.apply(res, abbr, replace)
    local store = require('core.store');
    local j = store.job(abbr, true);
    if replace then j.sets = {}; end
    local n = 0;
    for _, s in ipairs(res.sets) do
        if s.pick then
            local name = s.name;
            if store.find_by_name(abbr, name) then
                local k = 2;
                while store.find_by_name(abbr, name .. ' ' .. k) do k = k + 1; end
                name = name .. ' ' .. k;
            end
            local ns = store.new_set(abbr, s.when.kind, name);
            ns.gear = store.copy(s.gear);
            ns.more = s.more and store.copy(s.more) or nil;
            ns.when = store.copy(s.when);
            n = n + 1;
        end
    end
    if res.use_macro and res.macro.book then
        j.macro = { on = true, book = res.macro.book, page = res.macro.page or (j.macro and j.macro.page) or 1 };
    end
    if res.use_lockstyle and res.lockstyle then
        j.lockstyle = { mode = 'job', set = store.copy(res.lockstyle) };
    end
    store.touch();
    return n;
end

return import;
