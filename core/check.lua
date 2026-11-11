-- check.lua : what's wrong with a job's sets.
--   In a set:     no name, a name used twice, a piece the job can't wear (or not at this level), a piece you don't
--                 own or that's in the Mog House, the same piece in two slots when you own only one, a two-handed
--                 weapon with something other than a grip in Sub, a narrowing that names nothing the game knows.
--   Between sets: two sets that would be put on at the same moment, under the same conditions, at the same
--                 priority, with different gear in the same slot - which one wins would be down to list order.
local items = require('core.items');
local bags  = require('core.bags');
local jobs  = require('core.jobs');
local rules = require('core.rules');
local game  = require('core.game');
local augments = require('core.augments');
local tiers = require('core.tiers');

local check = {};

local cache = {};                                                      -- [job] = { key, res }
local known_cache = {};

local function lower_set(list)
    local t = {};
    for _, n in ipairs(list or {}) do t[tostring(n):lower()] = n; end
    return t;
end

local function known_names(kind)
    if known_cache[kind] then return known_cache[kind]; end
    local t = {};
    if kind == 'ws' then for _, e in ipairs(game.weaponskills()) do t[e.name:lower()] = true; end
    elseif kind == 'ja' then
        for _, e in ipairs(game.abilities()) do t[e.name:lower()] = true; end
        for _, n in ipairs({ 'Blood Pact: Rage', 'Blood Pact: Ward', 'Ready', 'Corsair Roll', 'Quick Draw', 'Rune Enchantment' }) do t[n:lower()] = true; end
    elseif kind == 'spells' then for _, e in ipairs(game.spells()) do t[e.name:lower()] = true; end
    else return nil; end
    known_cache[kind] = t;
    return t;
end

-- Problems in one set: { { level = 'err' | 'warn', text, slot = n or nil } }
local function check_set(abbr, s, names_seen)
    local out = {};
    local function add(level, text, slot) out[#out + 1] = { level = level, text = text, slot = slot }; end
    local job = jobs.id(abbr);                                       -- (nil for a custom entry: any job)
    local jl = job and jobs.level(job) or 0;
    local name = tostring(s.name or ''):gsub('^%s+', ''):gsub('%s+$', '');
    if name == '' then add('err', 'The set has no name.');
    else
        local k = name:lower();
        if names_seen[k] then add('err', 'Another ' .. abbr .. ' set is also called "' .. name .. '".'); end
        names_seen[k] = true;
    end

    -- every level of the set (a tier above your level isn't worn yet, so its level isn't a problem)
    local list = tiers.sorted(s);
    local many = #list > 1;
    local any = false;
    for ti, t in ipairs(list) do
        local tg = t.gear;
        local pre = many and ('Lv' .. ((ti == 1) and 1 or t.level) .. ' - ') or '';
        local function addt(level, text, slot) out[#out + 1] = { level = level, text = pre .. text, slot = slot, tier = tg }; end
        local future = ti > 1 and jl > 0 and t.level > jl;
        local used = {};
        local covered = items.blocked_in(tg) or {};
        for slot = 0, 15 do
            local g = tg[slot];
            if g and (g.id or g.remove) then any = true; end
            if g and g.id and covered[slot] then
                addt('info', bags.SLOT_NAME[slot] .. ': ' .. (g.name or items.name(g.id)) .. ' stays off while '
                    .. items.name(covered[slot]) .. ' is on (it covers that slot).');
            end
            if g and g.id then
                local id, nm, sl = g.id, g.name or items.name(g.id), bags.SLOT_NAME[slot];
                if items.res(id) == nil then addt('err', sl .. ': the game doesn\'t know item ' .. tostring(id) .. '.', slot);
                else
                    local blank = items.blank(id);
                    if blank then
                        -- custom gear: the game's data can't be trusted for slot or job, so only a known wrong slot is an error
                        local known = items.custom(id);
                        local ok_slot = true;
                        if known then ok_slot = false; for _, k in ipairs(known) do if k == slot then ok_slot = true; end end end
                        if not ok_slot then addt('err', sl .. ': ' .. nm .. ' doesn\'t go in this slot.', slot); end
                        addt('info', sl .. ': ' .. nm .. ' is custom server gear; NeoSwap puts it on with /equip.');
                    elseif not items.fits(id, slot) then addt('err', sl .. ': ' .. nm .. ' doesn\'t go in this slot.', slot); end
                    if blank then
                        -- (no job / level data to check)
                    elseif job and not items.job_ok(id, job) then addt('err', sl .. ': ' .. abbr .. ' can\'t wear ' .. nm .. '.', slot);
                    elseif jl > 0 and items.level(id) > jl and not future then
                        addt('warn', string.format('%s: %s needs level %d (your %s is %d).', sl, nm, items.level(id), abbr, jl), slot);
                    end
                    local at = augments.want_text(g);
                    local total, reach = bags.owned_with(g);
                    if total == 0 and at ~= '' and bags.owned(id) > 0 then
                        addt('warn', sl .. ': none of your ' .. nm .. ' has these augments (' .. at .. ').', slot);
                    elseif total == 0 then addt('warn', sl .. ': you don\'t have ' .. nm .. '.', slot);
                    elseif reach == 0 then addt('warn', sl .. ': ' .. nm .. ' is in your ' .. (bags.where(id) or '?') .. ' - move it to your Inventory or a Wardrobe.', slot); end
                    local uk = id .. '#' .. at;
                    used[uk] = used[uk] or { n = 0, slots = {}, g = g };
                    used[uk].n = used[uk].n + 1;
                    used[uk].slots[#used[uk].slots + 1] = sl;
                end
            end
        end
        -- with what carries forward into this level
        local eff = tiers.effective(s, (ti == 1) and 1 or t.level);
        for slot = 0, 15 do
            local g = eff[slot];
            if g and g.id and tg[slot] ~= g then
                local at = augments.want_text(g);
                local uk = g.id .. '#' .. at;
                if used[uk] then used[uk].n = used[uk].n + 1; used[uk].slots[#used[uk].slots + 1] = bags.SLOT_NAME[slot]; end
            end
        end
        for _, u in pairs(used) do
            if u.n > 1 then
                local total = bags.owned_with(u.g);
                if total > 0 and total < u.n then
                    local at = augments.want_text(u.g);
                    addt('err', string.format('%s%s is in %s but you own %d.', items.name(u.g.id), at ~= '' and (' (' .. at .. ')') or '', table.concat(u.slots, ' and '), total));
                end
            end
        end
        local main, sub = eff[0], eff[1];
        if main and main.id and items.two_handed(main.id) and sub and sub.id and not items.is_grip(sub.id) and (tg[0] == main or tg[1] == sub) then
            addt('err', items.name(main.id) .. ' takes both hands: Sub can hold only a grip.', 1);
        end
    end
    if not any then add('warn', 'No gear in this set yet.'); end

    -- the narrowing
    local w = s.when or {};
    local k = rules.BY_KIND[w.kind];
    if k == nil then add('err', 'Pick when this set is used.');
    elseif k.scope ~= nil and w.kind ~= 'pet' and w.kind ~= 'item' then
        local known = known_names(k.scope == 'spells' and 'spells' or w.kind);
        if known then
            for _, n in ipairs(w.names or {}) do
                if not known[tostring(n):lower()] then add('warn', '"' .. tostring(n) .. '" isn\'t a name the game knows; check the spelling.'); end
            end
        end
    end
    for _, c in ipairs(w.cond or {}) do
        local d = rules.BY_COND[c.t];
        if d and d.arg and d.arg ~= 'pct' and d.arg ~= 'num' and d.arg ~= 'hours' and d.arg ~= 'status' and (c.v == nil or c.v == '') then
            add('warn', 'A condition ("' .. d.label .. '") has nothing picked.');
        end
        if (c.t == 'spell_day' or c.t == 'spell_weather' or c.t == 'spell_elem') and k and k.scope ~= 'spells' then
            add('warn', '"' .. d.label .. '" only means something for spell sets.');
        end
    end
    return out;
end

-- Do two narrowings overlap at the same level (all/all, the same skill, the same name)?
local function overlap(a, b)
    local k = rules.BY_KIND[a.kind];
    if k == nil or k.scope == nil then return 'everything'; end
    local an, bn = a.names or {}, b.names or {};
    local as, bs = a.skills or {}, b.skills or {};
    if #an == 0 and #as == 0 and #bn == 0 and #bs == 0 then return 'everything'; end
    local hit = {};
    local bl = lower_set(bn);
    for _, n in ipairs(an) do if bl[tostring(n):lower()] then hit[#hit + 1] = n; end end
    local bsl = lower_set(bs);
    for _, n in ipairs(as) do if bsl[tostring(n):lower()] then hit[#hit + 1] = n; end end
    if #hit > 0 then return table.concat(hit, ', '); end
    return nil;
end

-- Everything for a job: { by_set = { [set id] = { problems } }, conflicts = { { a, b, text, slots } }, errors, warnings }
function check.job(abbr, sets)
    local snap = bags.get();
    local key = tostring(abbr) .. ':' .. tostring(require('core.store').gen or 0) .. ':' .. tostring(snap.at) .. ':' .. tostring(jobs.level(jobs.id(abbr) or 0));
    local c = cache[abbr];
    if c and c.key == key then return c.res; end
    local res = { by_set = {}, conflicts = {}, errors = 0, warnings = 0 };
    local seen = {};
    for _, s in ipairs(sets or {}) do
        local p = check_set(abbr, s, seen);
        res.by_set[s.id] = p;
    end
    -- conflicts between sets
    for i = 1, #(sets or {}) do
        for j = i + 1, #sets do
            local a, b = sets[i], sets[j];
            local wa, wb = a.when or {}, b.when or {};
            if wa.kind == wb.kind and wa.kind ~= 'manual' and a.off ~= true and b.off ~= true
                and (tonumber(a.prio) or 0) == (tonumber(b.prio) or 0)
                and rules.cond_key(wa.cond) == rules.cond_key(wb.cond) then
                local what = overlap(wa, wb);
                if what then
                    local jlv = jobs.level(jobs.id(abbr) or 0);
                    local ea, eb = tiers.effective(a, jlv > 0 and jlv or 99), tiers.effective(b, jlv > 0 and jlv or 99);
                    local slots = {};
                    for s = 0, 15 do
                        local ga, gb = ea[s], eb[s];
                        if ga and gb and (ga.id or ga.remove) and (gb.id or gb.remove) and (ga.id ~= gb.id or (ga.remove ~= gb.remove) or augments.want_text(ga) ~= augments.want_text(gb)) then
                            slots[#slots + 1] = bags.SLOT_NAME[s];
                        end
                    end
                    if #slots > 0 then
                        local c = { a = a.id, b = b.id, slots = slots,
                            text = string.format('"%s" and "%s" are both worn for %s (%s) under the same conditions. "%s" is lower in the list and wins for %s. Give one a higher priority or another condition.',
                                a.name or '?', b.name or '?', rules.BY_KIND[wa.kind].label, what, b.name or '?', table.concat(slots, ', ')) };
                        res.conflicts[#res.conflicts + 1] = c;
                        local pa, pb = res.by_set[a.id], res.by_set[b.id];
                        pa[#pa + 1] = { level = 'err', text = 'Clashes with "' .. (b.name or '?') .. '" (' .. table.concat(slots, ', ') .. ').', other = b.id };
                        pb[#pb + 1] = { level = 'err', text = 'Clashes with "' .. (a.name or '?') .. '" (' .. table.concat(slots, ', ') .. ').', other = a.id };
                    end
                end
            end
        end
    end
    for _, p in pairs(res.by_set) do
        for _, x in ipairs(p) do
            if x.level == 'err' then res.errors = res.errors + 1; elseif x.level == 'warn' then res.warnings = res.warnings + 1; end
        end
    end
    cache[abbr] = { key = key, res = res };
    return res;
end

function check.reset() cache = {}; end

return check;
