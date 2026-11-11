-- rules.lua : when a set is worn. Each set has a trigger (Idle, Engaged, Weapon skill...), what the trigger is
-- narrowed to (which weapon skills, which spells...), and conditions (HP below 50%, Firesday, Mode PDT on...).
--
-- For each moment (standing idle, a spell's precast, a weapon skill...) every set whose trigger, narrowing and
-- conditions fit is put on, one over the other: the broad ones first, then the narrow ones (all spells, then a
-- magic skill, then named spells), and among equals the higher priority, then the one lower in the list.
-- So a set only has to hold the slots it changes.
local game = require('core.game');
local tiers = require('core.tiers');

local rules = {};

-- The triggers. scope: what narrowing it takes ('names', 'spells' or nil). event: the moment it belongs to.
rules.KINDS = {
    { key = 'idle',    label = 'Idle',            event = 'default', hint = 'The base: always worn, with Engaged / Resting sets over it (add "Status is Idle" to keep one out of fights).' },
    { key = 'engaged', label = 'Engaged',         event = 'default', hint = 'Weapon out, fighting. Goes on over your Idle sets: it only needs the slots it changes.' },
    { key = 'resting', label = 'Resting',         event = 'default', hint = 'While /heal is on. Goes on over your Idle sets.' },
    { key = 'chocobo', label = 'Chocobo riding',  event = 'default',
      hint = 'At a chocobo stable (so it\'s on as you rent and get on), while you use a Chocobo Whistle, and while you ride. Goes on over your Idle sets (riding time, movement speed...).' },
    { key = 'precast', label = 'Spell precast',   event = 'precast', scope = 'spells',
      hint = 'Put on as you start casting (Fast Cast). The midcast set goes on right after.' },
    { key = 'midcast', label = 'Spell midcast',   event = 'midcast', scope = 'spells',
      hint = 'Worn while the spell is cast and lands (potency, accuracy, interruption...).' },
    { key = 'ja',      label = 'Job ability',     event = 'ja',      scope = 'names',
      hint = 'Put on just before an ability goes off (Provoke, Jump, Chakra, Blood Pact: Rage...).' },
    { key = 'ws',      label = 'Weapon skill',    event = 'ws',      scope = 'names',
      hint = 'Put on just before a weapon skill goes off.' },
    { key = 'preshot', label = 'Ranged preshot',  event = 'preshot', hint = 'As you start a ranged attack (Snapshot).' },
    { key = 'midshot', label = 'Ranged midshot',  event = 'midshot', hint = 'While the shot is fired (Ranged Accuracy, Attack).' },
    { key = 'item',    label = 'Item use',        event = 'item',    scope = 'names', hint = 'Using an item (Holy Water, food...).' },
    { key = 'pet',     label = 'Pet action',      event = 'pet',     scope = 'names',
      hint = 'While your pet uses an ability or spell (Blood Pacts, Ready, breaths, automaton skills).' },
    { key = 'manual',  label = 'Manual only',     event = 'manual',
      hint = 'Never put on by itself: use Equip now, or /nswap set <name>.' },
};
rules.BY_KIND = {};
-- The order sets go on in, one over the other: Idle (the base), then Engaged / Resting, then the action sets
-- (weapon skills, abilities, spells...), then pet actions. Inside a layer: broad to narrow, priority, list order.
rules.LAYER = { idle = 0, engaged = 1, resting = 1, chocobo = 1, pet = 3 };
for _, k in ipairs(rules.KINDS) do rules.BY_KIND[k.key] = k; end

-- The conditions. arg: 'pct', 'num', 'buff', 'job', 'element', 'hours', 'mode', 'text', or nil (yes / no).
-- neg: the label when it's turned around.
rules.CONDS = {
    { key = 'hpp_below', label = 'HP below %',        arg = 'pct',  def = 50 },
    { key = 'hpp_above', label = 'HP at least %',     arg = 'pct',  def = 75 },
    { key = 'mpp_below', label = 'MP below %',        arg = 'pct',  def = 50 },
    { key = 'mpp_above', label = 'MP at least %',     arg = 'pct',  def = 75 },
    { key = 'tp_atleast', label = 'TP at least',      arg = 'num',  def = 1000, max = 3000 },
    { key = 'tp_below',  label = 'TP below',          arg = 'num',  def = 1000, max = 3000 },
    { key = 'buff',      label = 'Buff is on',        arg = 'buff', neg = 'Buff is off' },
    { key = 'subjob',    label = 'Support job is',    arg = 'job',  neg = 'Support job is not' },
    { key = 'day',       label = 'Day is',            arg = 'element', neg = 'Day is not' },
    { key = 'weather',   label = 'Weather is',        arg = 'element', neg = 'Weather is not' },
    { key = 'spell_day', label = 'Spell element matches the day', neg = 'Spell element is not the day\'s' },
    { key = 'spell_weather', label = 'Spell element matches the weather', neg = 'Spell element is not the weather\'s' },
    { key = 'spell_elem', label = 'Spell element is', arg = 'element', neg = 'Spell element is not' },
    { key = 'hours',     label = 'Vana\'diel time between', arg = 'hours', def = 18, def2 = 6 },
    { key = 'status',    label = 'Status is',         arg = 'status', neg = 'Status is not', hint = 'Idle, Engaged, Resting or Chocobo (riding) - an Idle set with "Status is Idle" stays out of fights.' },
    { key = 'moving',    label = 'Moving',            neg = 'Standing still' },
    { key = 'pet_out',   label = 'Pet is out',        neg = 'No pet out' },
    { key = 'pet_name',  label = 'Pet is',            arg = 'text', neg = 'Pet is not', hint = 'The pet\'s name (Ifrit, Carbuncle, an automaton\'s name...)' },
    { key = 'mode',      label = 'Mode is on',        arg = 'mode', neg = 'Mode is off',
      hint = 'Your own switch. Turn it on and off with the mode pills, or /nswap mode <name>.' },
    { key = 'area',      label = 'Area name has',     arg = 'text', neg = 'Area name does not have', hint = 'Part of the zone\'s name (Jeuno, Dynamis...)' },
    { key = 'has_item',  label = 'I have item',       arg = 'text', neg = 'I don\'t have item', hint = 'An item\'s name (Instant Warp, Warp Ring...): in your Inventory or a Wardrobe.' },
    { key = 'level_below', label = 'Main job level below', arg = 'num', def = 75, max = 99, hint = 'For level sync and capped areas.' },
};
rules.BY_COND = {};
for _, c in ipairs(rules.CONDS) do rules.BY_COND[c.key] = c; end

----------------------------------------------------------------------------------------------------
-- Words
----------------------------------------------------------------------------------------------------
local function list_text(t, max)
    max = max or 3;
    if #t <= max then return table.concat(t, ', '); end
    local a = {};
    for i = 1, max do a[i] = t[i]; end
    return table.concat(a, ', ') .. string.format(' +%d', #t - max);
end

-- "Weapon skill: Savage Blade, Vorpal Blade"
function rules.trigger_text(w)
    local k = rules.BY_KIND[w.kind] or rules.KINDS[1];
    local names, skills = w.names or {}, w.skills or {};
    if k.scope == 'spells' then
        local parts = {};
        if #skills > 0 then parts[#parts + 1] = list_text(skills, 2); end
        if #names > 0 then parts[#parts + 1] = list_text(names, 2); end
        return k.label .. ': ' .. (#parts > 0 and table.concat(parts, '; ') or 'all spells');
    elseif k.scope == 'names' then
        return k.label .. ': ' .. (#names > 0 and list_text(names) or 'all');
    end
    return k.label;
end

function rules.cond_text(c)
    local d = rules.BY_COND[c.t];
    if d == nil then return '?'; end
    local label = (c.neg and d.neg) or d.label;
    local a = d.arg;
    if a == 'pct' then return label:gsub(' %%$', '') .. ' ' .. tostring(c.n or d.def) .. '%';
    elseif a == 'num' then return label .. ' ' .. tostring(c.n or d.def);
    elseif a == 'hours' then return string.format('%s %02d:00 and %02d:00', label, c.n or d.def, c.n2 or d.def2);
    elseif a ~= nil then return label .. ' ' .. tostring(c.v or '?'); end
    return label;
end

-- A key that two sets share when their conditions are the same (order doesn't matter)
function rules.cond_key(cond)
    local t = {};
    for _, c in ipairs(cond or {}) do
        t[#t + 1] = table.concat({ c.t or '', c.neg and '!' or '', tostring(c.v or ''):lower(), tostring(c.n or ''), tostring(c.n2 or '') }, '|');
    end
    table.sort(t);
    return table.concat(t, '&');
end

----------------------------------------------------------------------------------------------------
-- Matching
----------------------------------------------------------------------------------------------------
-- ctx: { status, vitals, buffs, sub, vana, weather, pet, moving, zone, level, action = { name, skill, element, ... },
--        pet_action = { name }, mode = function(name) }. Filled lazily by the engine.
-- Is an item (by name, any case) in your Inventory or a Wardrobe right now?
function rules.have_item(name)
    name = tostring(name or ''):lower():gsub('^%s+', ''):gsub('%s+$', '');
    if name == '' then return false; end
    local items, bags = require('core.items'), require('core.bags');
    local found = false;
    pcall(function()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        for b in pairs(bags.EQUIP_BAGS) do
            local max = tonumber(inv:GetContainerCountMax(b)) or 0;
            for i = 1, max do
                local ci = inv:GetContainerItem(b, i);
                if ci ~= nil and ci.Id ~= nil and ci.Id > 0 and ci.Id ~= 0xFFFF and (ci.Count or 1) > 0 then
                    local n = items.name(ci.Id);
                    if n and n:lower() == name then found = true; return; end
                    local ln = items.long_name and items.long_name(ci.Id);
                    if ln and ln:lower() == name then found = true; return; end
                end
            end
        end
    end);
    return found;
end

local function cond_ok(c, ctx)
    local t = c.t;
    local r;
    if t == 'hpp_below' then r = ctx.vitals().hpp < (c.n or 50);
    elseif t == 'hpp_above' then r = ctx.vitals().hpp >= (c.n or 75);
    elseif t == 'mpp_below' then r = ctx.vitals().mpp < (c.n or 50);
    elseif t == 'mpp_above' then r = ctx.vitals().mpp >= (c.n or 75);
    elseif t == 'tp_atleast' then r = ctx.vitals().tp >= (c.n or 1000);
    elseif t == 'tp_below' then r = ctx.vitals().tp < (c.n or 1000);
    elseif t == 'buff' then r = ctx.buffs()[tostring(c.v or ''):lower()] ~= nil;
    elseif t == 'subjob' then r = (ctx.sub() or ''):upper() == tostring(c.v or ''):upper();
    elseif t == 'day' then r = ctx.vana().day_element == c.v;
    elseif t == 'weather' then r = ctx.weather() == c.v;
    elseif t == 'spell_day' then r = ctx.action ~= nil and ctx.action.element ~= nil and ctx.action.element == ctx.vana().day_element;
    elseif t == 'spell_weather' then r = ctx.action ~= nil and ctx.action.element ~= nil and ctx.action.element == ctx.weather();
    elseif t == 'spell_elem' then r = ctx.action ~= nil and ctx.action.element == c.v;
    elseif t == 'hours' then
        local h, a, b = ctx.vana().hour, c.n or 18, c.n2 or 6;
        if a <= b then r = h >= a and h < b; else r = h >= a or h < b; end
    elseif t == 'status' then r = ctx.status() == (c.v or 'Idle');
    elseif t == 'moving' then r = ctx.moving() == true;
    elseif t == 'pet_out' then r = ctx.pet() ~= nil;
    elseif t == 'pet_name' then local p = ctx.pet(); r = p ~= nil and p.name:lower() == tostring(c.v or ''):lower();
    elseif t == 'mode' then r = ctx.mode(c.v);
    elseif t == 'area' then r = (ctx.zone() or ''):lower():find(tostring(c.v or ''):lower(), 1, true) ~= nil;
    elseif t == 'level_below' then r = ctx.level() < (c.n or 75);
    elseif t == 'has_item' then r = rules.have_item(c.v);
    else r = true; end
    -- (the yes / no conditions with no 'neg' label can still be turned around)
    if c.neg then return not r; end
    return r;
end
rules.cond_ok = cond_ok;

local function has_name(list, name)
    if name == nil then return false; end
    name = name:lower();
    for _, n in ipairs(list or {}) do if tostring(n):lower() == name then return true; end end
    return false;
end

-- How narrow a set's trigger is for this action (0: doesn't apply). Broad sets go on first, narrow ones over them.
function rules.fit(w, ctx)
    local k = rules.BY_KIND[w.kind];
    if k == nil then return 0; end
    local names, skills = w.names or {}, w.skills or {};
    if k.scope == 'spells' then
        local a = ctx.action;
        if #names == 0 and #skills == 0 then return 10; end
        if a and has_name(names, a.name) then return 30; end
        if a and has_name(skills, a.skill) then return 20; end
        return 0;
    elseif k.scope == 'names' then
        local a = (w.kind == 'pet') and ctx.pet_action or ctx.action;
        if #names == 0 then return 10; end
        if a and has_name(names, a.name) then return 30; end
        -- an ability type ("Blood Pact: Rage") covers every ability of that type
        local at = a and (a.ability_type or a.type);
        if at and has_name(names, at) then return 20; end
        return 0;
    end
    return 10;
end

-- The sets (in the order to put them on) for a moment. kinds: the trigger keys that apply.
function rules.pick(sets, kinds, ctx)
    local hits = {};
    for i, s in ipairs(sets or {}) do
        local w = s.when or {};
        if kinds[w.kind] and s.off ~= true then
            local f = rules.fit(w, ctx);
            if f > 0 then
                local ok = true;
                for _, c in ipairs(w.cond or {}) do
                    local good, res = pcall(cond_ok, c, ctx);
                    if not good or not res then ok = false; break; end
                end
                if ok then
                    hits[#hits + 1] = { set = s, score = f + #(w.cond or {}), prio = tonumber(s.prio) or 0, i = i,
                                        layer = rules.LAYER[w.kind] or 2 };
                end
            end
        end
    end
    table.sort(hits, function(a, b)
        if a.layer ~= b.layer then return a.layer < b.layer; end
        if a.score ~= b.score then return a.score < b.score; end
        if a.prio ~= b.prio then return a.prio < b.prio; end
        return a.i < b.i;
    end);
    return hits;
end

-- Put sets one over the other: { [slot] = gear entry }
function rules.layer(hits, level)
    local out = {};
    for _, h in ipairs(hits) do
        local gear = tiers.effective(h.set, level);
        for s = 0, 15 do
            local g = gear[s];
            if g ~= nil and (g.id or g.remove) then out[s] = g; end
        end
    end
    return out;
end

-- The triggers for a moment
function rules.kinds_for(event, status)
    if event == 'default' then
        -- Idle is the base: Engaged and Resting sets go on over it
        local k = { idle = true };
        if status == 'Engaged' then k.engaged = true;
        elseif status == 'Resting' then k.resting = true;
        elseif status == 'Chocobo' then k.chocobo = true;
        elseif status == 'Idle' and ((rules.mounting_until or 0) > os.clock() or require('core.game').near_stable()) then
            k.chocobo = true;                                         -- about to get on
        end
        return k;
    end
    return { [event] = true };
end

return rules;
