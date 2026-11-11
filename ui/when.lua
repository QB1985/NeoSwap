-- when.lua : the "Use this set when" part of the set editor: the trigger, what it's narrowed to (weapon skills,
-- abilities, spells, magic skills, items, pet moves), the conditions, and the priority.
local imgui  = require('imgui');
local theme  = require('ui.theme');
local rules  = require('core.rules');
local game   = require('core.game');
local jobs   = require('core.jobs');
local store  = require('core.store');
local ABIL   = require('data.abilities');
local C, u32, tip, tw = theme.C, theme.u32, theme.tip, theme.tw;
local NEON, NEON2 = theme.NEON, theme.NEON2;

local when = {};

local bufs = {};                                                      -- text boxes: [id] = { text }
local function buf(id, init)
    local b = bufs[id];
    if b == nil then b = { init or '' }; bufs[id] = b; end
    return b;
end
function when.reset() bufs = {}; end

local function popup_style()
    local pv = 0;
    for _, v in ipairs({ { ImGuiStyleVar_WindowPadding, { 10, 8 } }, { ImGuiStyleVar_ItemSpacing, { 6, 4 } },
                         { ImGuiStyleVar_PopupRounding, 8 }, { ImGuiStyleVar_PopupBorderSize, 1 } }) do
        if v[1] ~= nil then imgui.PushStyleVar(v[1], v[2]); pv = pv + 1; end
    end
    imgui.PushStyleColor(ImGuiCol_PopupBg, { 0.055, 0.050, 0.075, 0.98 });
    imgui.PushStyleColor(ImGuiCol_Border, { NEON2[1], NEON2[2], NEON2[3], 0.35 });
    imgui.PushStyleColor(ImGuiCol_Header, { NEON[1] * 0.42, NEON[2] * 0.42, NEON[3] * 0.42, 1 });
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, { 1, 1, 1, 0.08 });
    imgui.PushStyleColor(ImGuiCol_HeaderActive, { 1, 1, 1, 0.16 });
    return pv;
end
local function popup_pop(pv) imgui.PopStyleColor(5); imgui.PopStyleVar(pv); end
when.popup_style, when.popup_pop = popup_style, popup_pop;

local function label(text, x)
    imgui.SetCursorPosX(x or imgui.GetCursorPosX());
    imgui.AlignTextToFramePadding();
    imgui.TextColored(C.muted, theme.safe(text));
end

----------------------------------------------------------------------------------------------------
-- Name chips with an x each, and a search box that suggests names. Returns true if the list changed.
----------------------------------------------------------------------------------------------------
local function contains(list, n)
    n = tostring(n):lower();
    for _, v in ipairs(list) do if tostring(v):lower() == n then return true; end end
    return false;
end

-- cands: function(text) -> { { name, group = 'Sword' / note } } (best first)
local function name_list(id, list, W, cands, hint, free)
    local changed = false;
    local dl = imgui.GetWindowDrawList();
    local lh = imgui.GetTextLineHeight();
    -- the chips
    local x0, y0 = imgui.GetCursorScreenPos();
    local cx, cy = x0, y0;
    local remove = nil;
    for i, n in ipairs(list) do
        local t = tostring(n);
        local w = tw(t) + 34;
        if cx + w > x0 + W and cx > x0 then cx = x0; cy = cy + theme.pill_h() + 5; end
        local h = theme.pill_h();
        dl:AddRectFilled({ cx, cy }, { cx + w, cy + h }, u32({ NEON[1] * 0.30, NEON[2] * 0.30, NEON[3] * 0.30, 1 }), h / 2);
        dl:AddRect({ cx, cy }, { cx + w, cy + h }, u32({ NEON2[1], NEON2[2], NEON2[3], 0.55 }), h / 2, C.rall, 1);
        dl:AddText({ cx + 10, cy + (h - lh) / 2 }, u32({ 1, 1, 1, 1 }), t);
        local xx, xy = cx + w - 14, cy + h / 2;
        imgui.SetCursorScreenPos({ xx - 8, cy });
        if imgui.InvisibleButton('##' .. id .. '_x' .. i, { 16, h }) then remove = i; end
        local xh = imgui.IsItemHovered();
        local ic = u32({ 1, 1, 1, xh and 1 or 0.55 });
        dl:AddLine({ xx - 3, xy - 3 }, { xx + 3, xy + 3 }, ic, 1.5);
        dl:AddLine({ xx - 3, xy + 3 }, { xx + 3, xy - 3 }, ic, 1.5);
        if xh then tip('Remove ' .. t); end
        cx = cx + w + 5;
    end
    if remove then table.remove(list, remove); changed = true; end
    if #list > 0 then cy = cy + theme.pill_h() + 6; end
    imgui.SetCursorScreenPos({ x0, cy });
    -- the search box
    local b = buf(id .. '_add');
    theme.input('##' .. id .. '_in', b, 64, math.min(W, 320), hint, true);
    local text = (b[1] or ''):gsub('^%s+', ''):gsub('%s+$', '');
    if #text >= 1 then
        local found = cands(text:lower()) or {};
        local shown = 0;
        local sx, sy = imgui.GetCursorScreenPos();
        local rw = math.min(W, 320);
        local any_exact = false;
        for _, f in ipairs(found) do
            if shown >= 8 then break; end
            if not contains(list, f.name) then
                shown = shown + 1;
                local x, y = imgui.GetCursorScreenPos();
                local c = imgui.InvisibleButton('##' .. id .. '_s' .. shown, { rw, lh + 6 });
                local hov = imgui.IsItemHovered();
                dl:AddRectFilled({ x, y }, { x + rw, y + lh + 6 }, u32(hov and { 0.16, 0.15, 0.21, 1 } or { 0.075, 0.07, 0.10, 0.95 }), 4);
                dl:AddText({ x + 10, y + 3 }, u32(hov and { 1, 1, 1, 1 } or C.text), f.name);
                if f.group then dl:AddText({ x + rw - tw(f.group) - 10, y + 3 }, u32(C.muted), f.group); end
                if c then list[#list + 1] = f.name; b[1] = ''; changed = true; end
                if f.name:lower() == text:lower() then any_exact = true; end
            end
        end
        if free and not any_exact and not contains(list, text) then
            local x, y = imgui.GetCursorScreenPos();
            local c = imgui.InvisibleButton('##' .. id .. '_free', { rw, lh + 6 });
            local hov = imgui.IsItemHovered();
            dl:AddRectFilled({ x, y }, { x + rw, y + lh + 6 }, u32(hov and { 0.16, 0.15, 0.21, 1 } or { 0.075, 0.07, 0.10, 0.95 }), 4);
            dl:AddText({ x + 10, y + 3 }, u32(C.acc), 'Add "' .. text .. '" as typed');
            if c then list[#list + 1] = text; b[1] = ''; changed = true; end
        elseif shown == 0 then
            imgui.TextColored(C.muted, 'No match.');
        end
    end
    return changed;
end

-- Candidates
local function match(list, text, max, extra_group)
    local out = {};
    for _, e in ipairs(list) do
        if e.name:lower():find(text, 1, true) then
            out[#out + 1] = { name = e.name, group = e.group or extra_group, starts = e.name:lower():sub(1, #text) == text };
            if #out > (max or 200) then break; end
        end
    end
    table.sort(out, function(a, b)
        if a.starts ~= b.starts then return a.starts; end
        return a.name < b.name;
    end);
    return out;
end

local function job_first(names, text, all, job_label)
    local t = {};
    local seen = {};
    for _, n in ipairs(names or {}) do
        if n:lower():find(text, 1, true) then t[#t + 1] = { name = n, group = job_label }; seen[n:lower()] = true; end
    end
    for _, e in ipairs(match(all, text, 200)) do
        if not seen[e.name:lower()] then t[#t + 1] = e; end
    end
    return t;
end

local ABILITY_TYPES = { { name = 'Blood Pact: Rage', group = 'every Rage pact' }, { name = 'Blood Pact: Ward', group = 'every Ward pact' },
                        { name = 'Ready', group = 'every Ready move' }, { name = 'Corsair Roll', group = 'every roll' },
                        { name = 'Quick Draw', group = 'every shot' }, { name = 'Rune Enchantment', group = 'every rune' } };

----------------------------------------------------------------------------------------------------
-- One condition's value
----------------------------------------------------------------------------------------------------
local ELEMENT_OPTS = {};
for _, e in ipairs(game.ELEMENTS) do ELEMENT_OPTS[#ELEMENT_OPTS + 1] = { e, e }; end
local JOB_OPTS = {};
for _, a in ipairs(jobs.ABBR) do JOB_OPTS[#JOB_OPTS + 1] = { a, a }; end

local function cond_value(id, c, d, W)
    local changed = false;
    local a = d.arg;
    if a == 'pct' then
        local v, ch = theme.digits(id .. '_n', c.n or d.def, 0, 100);
        if ch then c.n = v; changed = true; end
    elseif a == 'num' then
        local v, ch = theme.digits(id .. '_n', c.n or d.def, 0, d.max or 3000);
        if ch then c.n = v; changed = true; end
    elseif a == 'hours' then
        local v, ch = theme.digits(id .. '_a', c.n or d.def, 0, 23);
        if ch then c.n = v; changed = true; end
        imgui.SameLine();
        imgui.AlignTextToFramePadding();
        imgui.TextColored(C.muted, 'and');
        imgui.SameLine();
        local v2, ch2 = theme.digits(id .. '_b', c.n2 or d.def2, 0, 23);
        if ch2 then c.n2 = v2; changed = true; end
    elseif a == 'element' then
        local p = theme.pick(id .. '_e', ELEMENT_OPTS, c.v or 'Fire', 130);
        if c.v == nil then c.v = 'Fire'; changed = true; end
        if p then c.v = p; changed = true; end
    elseif a == 'status' then
        local p = theme.pick(id .. '_st', { { 'Idle', 'Idle' }, { 'Engaged', 'Engaged' }, { 'Resting', 'Resting' }, { 'Chocobo', 'Chocobo' } }, c.v or 'Idle', 110);
        if c.v == nil then c.v = 'Idle'; changed = true; end
        if p then c.v = p; changed = true; end
    elseif a == 'job' then
        local p = theme.pick(id .. '_j', JOB_OPTS, c.v or 'WAR', 100);
        if c.v == nil then c.v = 'WAR'; changed = true; end
        if p then c.v = p; changed = true; end
    elseif a == 'buff' or a == 'mode' or a == 'text' then
        local b = buf(id .. '_t', c.v or '');
        if not bufs[id .. '_t_active'] and b[1] ~= (c.v or '') then b[1] = c.v or ''; end
        local active = theme.input('##' .. id .. '_t', b, 48, math.min(W, 220),
            a == 'buff' and 'Buff name (Haste, Sneak...)' or (a == 'mode' and 'Mode name (PDT, TH...)' or 'Text...'), false);
        bufs[id .. '_t_active'] = active;
        local v = (b[1] or ''):gsub('^%s+', ''):gsub('%s+$', '');
        if v ~= (c.v or '') then c.v = v; changed = true; end
        -- suggestions for buffs and modes
        if active and #v >= 1 then
            local list = {};
            if a == 'buff' then list = match(game.buff_names(), v:lower(), 30);
            elseif a == 'mode' then
                for m in pairs(store.data and store.data.modes or {}) do if m:find(v:lower(), 1, true) then list[#list + 1] = { name = m }; end end
            end
            local n = 0;
            for _, f in ipairs(list) do
                if f.name:lower() ~= v:lower() then
                    n = n + 1;
                    if n > 6 then break; end
                    if imgui.Selectable('  ' .. f.name .. '##' .. id .. '_sg' .. n, false, 0, { math.min(W, 220), 0 }) then
                        c.v = f.name; b[1] = f.name; changed = true;
                    end
                end
            end
        end
    end
    return changed;
end

when.cond_value = cond_value;
when.name_list = name_list;
when.match = match;
when.buf = buf;

----------------------------------------------------------------------------------------------------
-- The whole section. s = the set, abbr = its job. Returns true if anything changed.
----------------------------------------------------------------------------------------------------
function when.draw(s, abbr, W)
    local changed = false;
    s.when = s.when or { kind = 'idle' };
    local w = s.when;
    w.names, w.skills, w.cond = w.names or {}, w.skills or {}, w.cond or {};
    local dl = imgui.GetWindowDrawList();
    local job = jobs.id(abbr);
    local LW = 120;                                                   -- (the labels' column)

    -- the trigger
    local x0 = imgui.GetCursorPosX();
    label('Use it for', x0);
    imgui.SameLine(x0 + LW);
    local opts = {};
    for _, k in ipairs(rules.KINDS) do opts[#opts + 1] = { k.key, k.label }; end
    local p = theme.pick('##wh_kind', opts, w.kind, 200);
    if p and p ~= w.kind then
        w.kind = p;
        local k = rules.BY_KIND[p];
        if k.scope == nil then w.names, w.skills = {}, {}; end
        if k.scope ~= 'spells' then w.skills = {}; end
        changed = true;
    end
    local k = rules.BY_KIND[w.kind] or rules.KINDS[1];
    imgui.SameLine();
    imgui.AlignTextToFramePadding();
    local hx = imgui.GetCursorPosX();
    local hint_w = math.max(60, W - (hx - x0));
    imgui.TextColored({ C.muted[1], C.muted[2], C.muted[3], 0.8 }, theme.safe(theme.fit(k.hint or '', hint_w)));
    if imgui.IsItemHovered() and k.hint then tip(k.hint); end

    -- the narrowing
    if k.scope == 'spells' then
        imgui.Spacing();
        label('Magic skill', x0);
        imgui.SameLine(x0 + LW);
        local sx, sy = imgui.GetCursorScreenPos();
        local cx, cy = sx, sy;
        local avail = W - LW;
        for i, sk in ipairs(game.SKILL_LIST) do
            local lbl = sk:gsub(' Magic$', '');
            local pw = theme.pill_w(lbl);
            if cx + pw > sx + avail and cx > sx then cx = sx; cy = cy + theme.pill_h() + 5; end
            local on = contains(w.skills, sk);
            local c, h = theme.pill('##wh_sk' .. i, lbl, on, cx, cy);
            if h then tip(on and ('Not ' .. sk) or ('Every ' .. sk .. ' spell')); end
            if c then
                if on then for j = #w.skills, 1, -1 do if w.skills[j]:lower() == sk:lower() then table.remove(w.skills, j); end end
                else w.skills[#w.skills + 1] = sk; end
                changed = true;
            end
            cx = cx + pw + 5;
        end
        imgui.SetCursorScreenPos({ sx - LW, cy + theme.pill_h() + 8 });
        label('Spells', x0);
        imgui.SameLine(x0 + LW);
        imgui.BeginGroup();
        if name_list('wh_sp', w.names, W - LW, function(t)
            local all = game.spells();
            local out = {};
            for _, e in ipairs(match(all, t, 300)) do
                local se = game.spell_info(e.name);
                local lv = se and job and se.jobs[job];
                out[#out + 1] = { name = e.name, group = (se and se.skill or '') .. (lv and ('  ' .. abbr .. lv) or ''), mine = lv ~= nil, starts = e.starts };
            end
            table.sort(out, function(a, b)
                if a.mine ~= b.mine then return a.mine; end
                if a.starts ~= b.starts then return a.starts; end
                return a.name < b.name;
            end);
            return out;
        end, 'Add a spell (Cure IV, Stoneskin...)', false) then changed = true; end
        imgui.EndGroup();
        if #w.names == 0 and #w.skills == 0 then
            imgui.SetCursorPosX(x0 + LW);
            imgui.TextColored(C.acc, 'Every spell.');
        end
        imgui.SetCursorPosX(x0 + LW);
        imgui.TextColored({ C.muted[1], C.muted[2], C.muted[3], 0.75 }, 'Named spells win over a magic skill, a magic skill over every spell.');
    elseif k.scope == 'names' then
        imgui.Spacing();
        local what = ({ ws = 'Weapon skills', ja = 'Abilities', item = 'Items', pet = 'Pet moves' })[w.kind] or 'Names';
        label(what, x0);
        imgui.SameLine(x0 + LW);
        imgui.BeginGroup();
        local hint_, cands, free;
        if w.kind == 'ws' then
            hint_ = 'Add a weapon skill (empty: all of them)';
            cands = function(t) return match(game.weaponskills(), t, 200); end;
        elseif w.kind == 'ja' then
            hint_ = 'Add an ability (empty: all of them)';
            cands = function(t)
                local own = (ABIL[abbr] and ABIL[abbr].ja) or {};
                local out = {};
                for _, e in ipairs(ABILITY_TYPES) do if e.name:lower():find(t, 1, true) then out[#out + 1] = e; end end
                for _, e in ipairs(job_first(own, t, game.abilities(), abbr)) do out[#out + 1] = e; end
                return out;
            end;
        elseif w.kind == 'pet' then
            hint_ = 'Add a pet move (empty: every pet action)';
            free = true;
            cands = function(t)
                local own = (ABIL[abbr] and ABIL[abbr].pet) or {};
                local out = {};
                for _, e in ipairs(ABILITY_TYPES) do if e.name:lower():find(t, 1, true) then out[#out + 1] = e; end end
                for _, e in ipairs(job_first(own, t, game.abilities(), abbr)) do out[#out + 1] = e; end
                return out;
            end;
        else
            hint_ = 'Add an item name (empty: every item)';
            free = true;
            cands = function() return {}; end;
        end
        if name_list('wh_nm', w.names, W - LW, cands, hint_, free) then changed = true; end
        if #w.names == 0 then imgui.TextColored(C.acc, 'All ' .. what:lower() .. '.'); end
        imgui.EndGroup();
    end

    -- the conditions
    imgui.Spacing();
    label('Only when', x0);
    imgui.SameLine(x0 + LW);
    imgui.BeginGroup();
    local del = nil;
    if #w.cond == 0 then
        imgui.AlignTextToFramePadding();
        imgui.TextColored({ C.muted[1], C.muted[2], C.muted[3], 0.8 }, 'Always (no conditions).');
    end
    for i, c in ipairs(w.cond) do
        local d = rules.BY_COND[c.t];
        if d then
            local id = 'wh_c' .. s.id .. '_' .. i;
            local cx = imgui.GetCursorPosX();
            -- turn it around (not)
            local lbl = (c.neg and d.neg) or d.label;
            if d.arg == 'pct' then lbl = lbl:gsub(' %%$', ''); end
            local can_neg = d.neg ~= nil;
            if can_neg then
                local nc, nh = theme.pill('##' .. id .. '_neg', lbl, c.neg == true);
                if nh then tip('Click to turn it around: "' .. ((c.neg and d.label) or d.neg) .. '"'); end
                if nc then c.neg = not c.neg; changed = true; end
            else
                imgui.AlignTextToFramePadding();
                imgui.TextColored(C.text, theme.safe(lbl));
                if d.hint and imgui.IsItemHovered() then tip(d.hint); end
            end
            if d.arg then
                imgui.SameLine();
                imgui.BeginGroup();
                if cond_value(id, c, d, W - LW - 200) then changed = true; end
                imgui.EndGroup();
            end
            imgui.SameLine();
            local bx, by = imgui.GetCursorScreenPos();
            local xc, xh = theme.icon_button('##' .. id .. '_del', bx + 4, by + 3, 'close', 18);
            if xh then tip('Remove this condition'); end
            if xc then del = i; end
            imgui.SetCursorPosX(cx);
            imgui.Dummy({ 1, 2 });
        end
    end
    if del then table.remove(w.cond, del); changed = true; end
    if theme.button('##wh_addc', '+ Condition', {}) then imgui.OpenPopup('##wh_addc_pop'); end
    if imgui.IsItemHovered() then tip('Only use this set when something is true (HP below 50%, a buff, a mode, the day...)'); end
    local pv = popup_style();
    if imgui.BeginPopup('##wh_addc_pop') then
        for _, d in ipairs(rules.CONDS) do
            local spell_only = d.key == 'spell_day' or d.key == 'spell_weather' or d.key == 'spell_elem';
            if not spell_only or k.scope == 'spells' then
                if imgui.Selectable('  ' .. d.label:gsub(' %%$', '') .. '##wh_ac_' .. d.key, false, 0, { 260, 0 }) then
                    w.cond[#w.cond + 1] = { t = d.key, n = d.def, n2 = d.def2 };
                    changed = true;
                end
                if d.hint and imgui.IsItemHovered() then tip(d.hint); end
            end
        end
        imgui.EndPopup();
    end
    popup_pop(pv);
    imgui.EndGroup();

    -- priority, and on / off
    imgui.Spacing();
    label('Priority', x0);
    imgui.SameLine(x0 + LW);
    local pr, pch = theme.digits('wh_prio' .. s.id, tonumber(s.prio) or 0, 0, 99);
    if pch then s.prio = pr; changed = true; end
    if imgui.IsItemHovered() then tip('When two sets are worn at the same moment, the higher priority goes on top.'); end
    imgui.SameLine();
    imgui.AlignTextToFramePadding();
    imgui.TextColored({ C.muted[1], C.muted[2], C.muted[3], 0.8 }, 'Higher goes on top when two sets overlap.');
    imgui.SameLine();
    local ox = imgui.GetCursorPosX();
    local right = x0 + W - 52 - tw('Use this set') - 10;
    if right > ox then imgui.SameLine(right); end
    imgui.AlignTextToFramePadding();
    imgui.TextColored(C.text, 'Use this set');
    imgui.SameLine();
    if theme.switch('##wh_on' .. s.id, s.off ~= true) then s.off = not (s.off == true) or nil; changed = true; end
    if imgui.IsItemHovered() then tip('Off: kept, but never put on by itself (to try things out).'); end

    return changed;
end

return when;
