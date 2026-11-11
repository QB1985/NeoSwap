-- gear.lua : the set editor's equipment grid (the game's 4 x 4 equipment menu) and the piece picker beside it,
-- and the totals panel (a set's stat bonuses).
local imgui  = require('imgui');
local theme  = require('ui.theme');
local items  = require('core.items');
local bags   = require('core.bags');
local jobs   = require('core.jobs');
local stats  = require('core.stats');
local augments = require('core.augments');
local C, u32, tip, tw = theme.C, theme.u32, theme.tip, theme.tw;
local NEON, NEON2 = theme.NEON, theme.NEON2;
local nav = require('ui.nav');

local gear = {};
gear.CELL, gear.GAP = 46, 5;
function gear.grid_size() return gear.CELL * 4 + gear.GAP * 3; end

----------------------------------------------------------------------------------------------------
-- The grid. set_gear: [slot 0-15] = { id, name } | { remove = true }.
-- opts: { sel = slot, only = { [slot] = true } (others greyed), bad = { [slot] = 'err'|'warn' }, id = 'prefix' }
-- Returns: clicked slot, right-clicked slot
----------------------------------------------------------------------------------------------------
function gear.grid(dl, set_gear, opts)
    opts = opts or {};
    local x0, y0 = imgui.GetCursorScreenPos();
    local CELL, GAP = gear.CELL, gear.GAP;
    local clicked, rclicked = nil, nil;
    -- slots covered by another piece (a cloak covers Head): what the set wears there won't go on
    local eff = {};
    for s = 0, 15 do
        local g = set_gear and set_gear[s];
        if g == nil and opts.ghost then g = opts.ghost[s]; end
        eff[s] = g;
    end
    local covered = items.blocked_in(eff) or {};
    for i, s in ipairs(bags.SLOT_GRID) do
        local col, row = (i - 1) % 4, math.floor((i - 1) / 4);
        local x, y = x0 + col * (CELL + GAP), y0 + row * (CELL + GAP);
        local usable = opts.only == nil or opts.only[s];
        imgui.SetCursorScreenPos({ x, y });
        local c = imgui.InvisibleButton('##' .. (opts.id or 'g') .. '_cell' .. s, { CELL, CELL });
        local hov = imgui.IsItemHovered();
        if c and usable then clicked = s; end
        if usable and imgui.IsItemClicked(1) then rclicked = s; end
        local sel = opts.sel == s;
        local g = set_gear and set_gear[s];
        local a = usable and 1 or 0.35;
        dl:AddRectFilled({ x, y }, { x + CELL, y + CELL }, u32(sel and { NEON[1] * 0.40, NEON[2] * 0.40, NEON[3] * 0.40, a }
            or ((hov and usable) and { 0.16, 0.15, 0.21, a } or { 0.06, 0.055, 0.08, 0.95 * a })), 7);
        local bad = opts.bad and opts.bad[s];
        local edge = sel and { NEON2[1], NEON2[2], NEON2[3], 0.95 } or { 1, 1, 1, ((hov and usable) and 0.30 or 0.10) * a };
        if bad == 'err' then edge = { C.bad[1], C.bad[2], C.bad[3], 0.9 }; elseif bad == 'warn' then edge = { C.warn[1], C.warn[2], C.warn[3], 0.8 }; end
        dl:AddRect({ x, y }, { x + CELL, y + CELL }, u32(edge), 7, C.rall, (sel or bad) and 1.6 or 1);
        if g and g.id then
            items.draw_icon(dl, g.id, x + (CELL - 32) / 2, y + (CELL - 32) / 2, 32);
            if (g.augs and #g.augs > 0) or g.path then                -- (augmented: a gold corner)
                local gc = u32({ C.gold[1], C.gold[2], C.gold[3], 0.9 * a });
                if not pcall(function() dl:AddTriangleFilled({ x + CELL - 12, y + 2 }, { x + CELL - 2, y + 2 }, { x + CELL - 2, y + 12 }, gc); end) then
                    dl:AddCircleFilled({ x + CELL - 6, y + 6 }, 3, gc, 10);
                end
            end
        elseif g == nil and opts.ghost and opts.ghost[s] and opts.ghost[s].id then
            -- carried on from a lower level: faded
            items.draw_icon(dl, opts.ghost[s].id, x + (CELL - 32) / 2, y + (CELL - 32) / 2, 32);
            dl:AddRectFilled({ x + 1, y + 1 }, { x + CELL - 1, y + CELL - 1 }, u32({ 0.05, 0.045, 0.07, 0.62 }), 7);
        elseif g and g.remove then
            local cx, cy, r = x + CELL / 2, y + CELL / 2, 9;
            local col_ = u32({ C.bad[1], C.bad[2], C.bad[3], 0.75 * a });
            dl:AddCircle({ cx, cy }, r, col_, 20, 1.6);
            dl:AddLine({ cx - r * 0.7, cy + r * 0.7 }, { cx + r * 0.7, cy - r * 0.7 }, col_, 1.6);
        else
            local nm = bags.SLOT_NAME[s];
            imgui.SetWindowFontScale(0.78);
            local w = tw(nm);
            local lh = imgui.GetTextLineHeight();
            dl:AddText({ x + (CELL - w) / 2, y + (CELL - lh) / 2 }, u32({ C.muted[1], C.muted[2], C.muted[3], 0.6 * a }), nm);
            imgui.SetWindowFontScale(1);
        end
        if covered[s] then
            -- covered: hatched over, with a small padlock-like bar
            dl:AddRectFilled({ x + 1, y + 1 }, { x + CELL - 1, y + CELL - 1 }, u32({ 0.05, 0.045, 0.07, 0.55 }), 7);
            local lc = u32({ C.muted[1], C.muted[2], C.muted[3], 0.45 });
            pcall(function()
                dl:PushClipRect({ x + 2, y + 2 }, { x + CELL - 2, y + CELL - 2 }, true);
                for k = -CELL, CELL, 9 do dl:AddLine({ x + k, y + CELL }, { x + k + CELL, y }, lc, 1); end
                dl:PopClipRect();
            end);
        end
        local pad_tip = opts.nav_i == i and not hov and nav.mouse_quiet();
        if opts.nav_i == i then nav.ring(dl, x, y, x + CELL, y + CELL, 7); end
        if pad_tip then nav.tip_beside(x, y, x + CELL); end
        if (hov or pad_tip) and usable then
            local nm = bags.SLOT_NAME[s];
            if covered[s] then nm = nm .. ' (covered by ' .. items.name(covered[s]) .. ': nothing goes on here)'; end
            local how = pad_tip and 'Confirm: change it   Second action: empty the slot' or 'Click: change it   Right-click: empty the slot';
            if g and g.id then
                local extra = { { nm .. (bags.where(g.id) and ('  -  ' .. bags.where(g.id)) or '  -  you don\'t have it'), C.acc },
                                { how, C.muted } };
                local at = augments.want_text(g);
                if at ~= '' then table.insert(extra, 1, { 'Augments: ' .. at, C.gold }); end
                items.tooltip(g.id, g.name, extra);
            elseif g == nil and opts.ghost and opts.ghost[s] and opts.ghost[s].id then
                local gh = opts.ghost[s];
                items.tooltip(gh.id, gh.name, { { nm .. ': carried on from a lower level', C.acc },
                    { pad_tip and 'Confirm: pick a piece for this level' or 'Click: pick a piece for this level', C.muted } });
            elseif g and g.remove then
                tip(nm .. ': taken off (left empty)\n' .. (pad_tip and 'Confirm: change   Second action: leave the slot alone' or 'Click: change   Right-click: leave the slot alone'));
            else
                tip(nm .. ': not part of this set (whatever is on stays on)\n' .. (pad_tip and 'Confirm: pick a piece' or 'Click: pick a piece'));
            end
        elseif (hov or pad_tip) and not usable then
            tip(bags.SLOT_NAME[s] .. ': a lockstyle shows Main to Feet only');
        end
    end
    imgui.SetCursorScreenPos({ x0, y0 });
    imgui.Dummy({ gear.grid_size(), gear.grid_size() });
    return clicked, rclicked;
end

----------------------------------------------------------------------------------------------------
-- The picker: every piece for a slot. opts: { job = id or nil (any job), mode = 'owned' | 'all', style = true }
-- Returns { pick = { id, name } } | { remove = true } | { clear = true } | { close = true } | nil
----------------------------------------------------------------------------------------------------
local search = { '' };
local scope = 'owned';
local only_wearable = true;
local sort_stat = '';            -- '' (by level) or a bonus key ('Haste %', 'Accuracy', 'MP while healing'...)
local only_stat = false;         -- hide pieces without it
local list_cache = { map = {}, n = 0 };
local last_slot = nil;

function gear.reset_search() search[1] = ''; list_cache.map = {}; list_cache.n = 0; end

local function rows_for(slot, job, owned_only, text, all_stats)
    local snap = bags.get();
    local key = table.concat({ slot, job or 0, owned_only and 1 or 0, text, snap.at, only_wearable and 1 or 0, sort_stat, (only_stat and not all_stats) and 1 or 0 }, '|');
    if list_cache.map[key] then return list_cache.map[key]; end
    local rows, seen = {}, {};
    local jl = job and jobs.level(job) or 99;
    -- one row per piece, and per set of augments (two Star Rings with different augments are two rows)
    local function add(id, owned, aug)
        local sig = aug and augments.sig(aug) or '';
        local k = id .. '#' .. sig;
        if seen[k] then return; end
        seen[k] = true;
        local nm = items.name(id);
        local bon = stats.of_copy(id, aug and aug.list or nil);
        if text ~= '' and not nm:lower():find(text, 1, true) and not items.long_name(id):lower():find(text, 1, true)
            and not sig:lower():find(text, 1, true) then
            -- (the search box finds stats too: "haste", "refresh", "mp while healing")
            local hit = false;
            for key in pairs(bon) do if key:lower():find(text, 1, true) then hit = true; break; end end
            if not hit then return; end
        end
        local lv = items.level(id);
        if only_wearable and job and jl > 0 and lv > jl then return; end
        local sv = (sort_stat ~= '') and bon[sort_stat] or nil;
        if only_stat and not all_stats and sort_stat ~= '' and sv == nil then return; end
        rows[#rows + 1] = { id = id, name = nm, level = lv, owned = owned, too_high = job ~= nil and jl > 0 and lv > jl, aug = aug, sig = sig,
                            bon = bon, sv = sv };
    end
    for _, e in ipairs(snap.list) do
        if items.fits(e.id, slot) and (job == nil or items.job_ok(e.id, job)) then add(e.id, true, e.aug); end
    end
    if not owned_only and #text >= 2 then
        local bit_slot = bit.lshift(1, slot);
        local n = 0;
        for _, g in ipairs(items.all_gear()) do
            if bit.band(g.slots, bit_slot) ~= 0 and (job == nil or bit.band(g.jobs, bit.lshift(1, job)) ~= 0)
                and g.lname:find(text, 1, true) then
                if not seen[g.id .. '#'] and bags.owned(g.id) == 0 then add(g.id, false, nil); end
                n = n + 1;
                if n > 300 then break; end
            end
        end
    end
    table.sort(rows, function(a, b)
        if sort_stat ~= '' then
            -- best first (for "damage taken" and the like, lower is better)
            local low = sort_stat:lower():find('taken', 1, true) or sort_stat:lower():find('delay', 1, true) or sort_stat:lower():find('cost', 1, true)
                        or sort_stat:lower():find('interruption', 1, true) or sort_stat:lower():find('enmity', 1, true);
            local va, vb = a.sv, b.sv;
            if (va ~= nil) ~= (vb ~= nil) then return va ~= nil; end
            if va ~= nil and va ~= vb then if low then return va < vb; end return va > vb; end
        end
        if a.owned ~= b.owned then return a.owned; end
        if a.level ~= b.level then return a.level > b.level; end
        if a.name ~= b.name then return a.name < b.name; end
        return a.sig < b.sig;
    end);
    if list_cache.n > 12 then list_cache.map, list_cache.n = {}, 0; end
    list_cache.map[key] = rows;
    list_cache.n = list_cache.n + 1;
    return rows;
end

function gear.picker(dl, W, H, slot, cur, opts)
    opts = opts or {};
    if slot ~= last_slot then last_slot = slot; search[1] = ''; end
    local lh = imgui.GetTextLineHeight();
    local x0, y0 = imgui.GetCursorScreenPos();
    local result = nil;
    dl:AddRectFilled({ x0, y0 }, { x0 + W, y0 + H }, theme.bgc(0.085, 0.080, 0.115, 0.9), 10);
    dl:AddRect({ x0, y0 }, { x0 + W, y0 + H }, u32({ 1, 1, 1, 0.06 }), 10, C.rall, 1);
    local title = (bags.SLOT_NAME[slot] or '?'):upper();
    theme.spaced(dl, x0 + 12, y0 + 9, title, u32({ 0.93, 0.90, 1, 1 }), 2);
    local job_txt = opts.job and ('for ' .. (jobs.ABBR[opts.job] or '?')) or 'any job';
    dl:AddText({ x0 + 18 + theme.spaced_w(title, 2), y0 + 9 }, u32(C.muted), job_txt);
    local cc, ch = theme.icon_button('##gp_close', x0 + W - 28, y0 + 7, 'close', 18);
    if ch then tip('Close the list (back to the totals)'); end
    if cc then result = { close = true }; end

    imgui.SetCursorScreenPos({ x0 + 10, y0 + 32 });
    local seg_w = theme.segmented_w({ { 'owned', 'Mine' }, { 'all', 'Every item' } });
    theme.input('##gp_search', search, 64, W - 30 - seg_w, scope == 'all' and 'Type 2+ letters of any item...' or 'Search your gear...', true);
    imgui.SetCursorScreenPos({ x0 + W - 10 - seg_w, y0 + 34 });
    local p = theme.segmented('##gp_scope', { { 'owned', 'Mine', 'Only pieces you have' },
                                               { 'all', 'Every item', 'Every piece in the game (to plan a set). Type 2 or more letters.' } }, scope);
    if p then scope = p; end
    local ry = y0 + 34 + theme.pill_h() + 10;
    imgui.SetCursorScreenPos({ x0 + 12, ry });
    if opts.job then
        local wc, wh = theme.checkbox('##gp_wear', 'Hide pieces above ' .. (jobs.ABBR[opts.job] or '') .. '\'s level', only_wearable);
        if wh then tip('Hide what this job is too low a level for'); end
        if wc then only_wearable = not only_wearable; list_cache.map = {}; list_cache.n = 0; end
    end
    -- the two fixed rows
    local fx = x0 + W - 12;
    local function small(id, label, hint_)
        local w = theme.pill_w(label);
        fx = fx - w;
        local c, h = theme.pill(id, label, false, fx, ry - 3);
        if h then tip(hint_); end
        fx = fx - 6;
        return c;
    end
    if small('##gp_clear', 'Leave alone', 'Not part of this set: whatever is on stays on') then result = { clear = true }; end
    if not opts.style and small('##gp_remove', 'Take off', 'This set leaves the slot empty') then result = { remove = true }; end

    -- sort by a stat: the stats the pieces for this slot have
    local sy2 = ry + lh + 10;
    do
        local keys, seen = {}, {};
        local all = rows_for(slot, opts.job, scope == 'owned', '', true);
        for _, r in ipairs(all) do for key in pairs(r.bon or {}) do if not seen[key] then seen[key] = true; keys[#keys + 1] = key; end end end
        table.sort(keys, function(a, b)
            local pa, pb = a:sub(1, 5) == 'Pet: ', b:sub(1, 5) == 'Pet: ';
            if pa ~= pb then return not pa; end
            local na, nb = a:gsub(' %%$', ''):gsub('^Pet: ', ''), b:gsub(' %%$', ''):gsub('^Pet: ', '');
            local ra, rb = stats.rank(na), stats.rank(nb);
            if ra ~= rb then return ra < rb; end
            return a < b;
        end);
        local o = { { '', 'Level (best first)' } };
        for _, k in ipairs(keys) do o[#o + 1] = { k, k }; end
        if sort_stat ~= '' and not seen[sort_stat] then o[#o + 1] = { sort_stat, sort_stat }; end
        dl:AddText({ x0 + 12, sy2 + (theme.pill_h() - lh) / 2 }, u32(C.muted), 'Sort by');
        imgui.SetCursorScreenPos({ x0 + 12 + tw('Sort by') + 8, sy2 });
        local pw = math.min(200, W - 150);
        local pk = theme.pick('##gp_sort', o, sort_stat, pw);
        if imgui.IsItemHovered() then tip('Put the pieces with the most of a stat first (every stat the pieces for this slot have).\nTip: the search box finds stats too - type "haste" or "refresh".'); end
        if pk ~= nil then sort_stat = pk; list_cache.map = {}; list_cache.n = 0; end
        if sort_stat ~= '' then
            imgui.SetCursorScreenPos({ x0 + 12 + tw('Sort by') + 8 + pw + 10, sy2 + 2 });
            local oc, oh = theme.checkbox('##gp_only', 'Only with it', only_stat);
            if oh then tip('Hide the pieces without ' .. sort_stat); end
            if oc then only_stat = not only_stat; list_cache.map = {}; list_cache.n = 0; end
        end
    end
    local list_y = sy2 + theme.pill_h() + 8;
    imgui.SetCursorScreenPos({ x0 + 6, list_y });
    local text = (search[1] or ''):lower():gsub('^%s+', ''):gsub('%s+$', '');
    local rows = rows_for(slot, opts.job, scope == 'owned', text);
    local pv = theme.begin_list('##gp_list', W - 12, y0 + H - list_y - 6);
    local ldl = imgui.GetWindowDrawList();
    imgui.Indent(5);
    imgui.Dummy({ 1, 3 });
    local RH = 28;
    if #rows == 0 then
        imgui.Dummy({ 10, 6 });
        local msg = scope == 'all' and #text < 2 and 'Type at least 2 letters to search every item.'
            or (scope == 'owned' and 'Nothing you have fits here' .. (opts.job and (' for ' .. (jobs.ABBR[opts.job] or '')) or '') .. '. Try "Every item".' or 'Nothing found.');
        imgui.TextColored(C.muted, msg);
    end
    local cur_sig = cur and cur.id and augments.want_text(cur) or '';
    gear.picker_count = #rows;
    if opts.nav and opts.nav.pick and #rows == 0 then opts.nav.pick = false; end
    for i, r in ipairs(rows) do
        local x, y = imgui.GetCursorScreenPos();
        local rw = W - 34;
        local has_aug = r.sig ~= '';
        local rh = has_aug and (RH + lh - 2) or RH;
        local c = imgui.InvisibleButton('##gp_row' .. i, { rw, rh });
        local hov = imgui.IsItemHovered();
        local on = cur and cur.id == r.id and (cur_sig == '' or cur_sig == r.sig);
        if on then
            ldl:AddRectFilled({ x, y }, { x + rw, y + rh }, u32({ NEON[1] * 0.32, NEON[2] * 0.32, NEON[3] * 0.32, 0.9 }), 6);
        elseif hov then
            ldl:AddRectFilled({ x, y }, { x + rw, y + rh }, u32({ 1, 1, 1, 0.06 }), 6);
        end
        items.draw_icon(ldl, r.id, x + 3, y + 2, 24);
        local ty = y + (RH - lh) / 2;
        local right = r.level > 0 and ('Lv' .. r.level) or '';
        local rwid = tw(right);
        ldl:AddText({ x + rw - rwid - 6, ty }, u32(r.too_high and C.bad or C.muted), right);
        if sort_stat ~= '' then
            -- the sorted stat's value, before the level
            local v = r.sv;
            local vt = v and ((v > 0 and '+' or '') .. tostring(v) .. (sort_stat:sub(-2) == ' %' and '%' or '')) or '-';
            if sort_stat == 'DEF' and v then vt = tostring(v); end
            local vw = math.max(tw(vt), tw('+00%'));
            ldl:AddText({ x + rw - rwid - 14 - tw(vt), ty }, u32(v and C.gold or { C.muted[1], C.muted[2], C.muted[3], 0.5 }), vt);
            rwid = rwid + vw + 10;
        end
        local where = r.owned and (bags.where(r.id) or '') or 'not owned';
        local ww = math.min(tw(where), rw * 0.35);
        local wfit = theme.fit(where, ww + 1);
        ldl:AddText({ x + rw - rwid - 16 - tw(wfit), ty }, u32({ C.muted[1], C.muted[2], C.muted[3], r.owned and 0.75 or 0.5 }), wfit);
        local nmax = rw - rwid - tw(wfit) - 60;
        ldl:AddText({ x + 34, ty }, u32(r.owned and (on and { 1, 1, 1, 1 } or C.text) or { C.text[1], C.text[2], C.text[3], 0.55 }), theme.fit(r.name, nmax));
        if has_aug then
            imgui.SetWindowFontScale(0.88);
            ldl:AddText({ x + 34, ty + lh - 1 }, u32({ C.gold[1], C.gold[2], C.gold[3], 0.9 }), theme.fit(r.sig, rw - 44));
            imgui.SetWindowFontScale(1);
        end
        local pad_tip = opts.nav and opts.nav.prow == i and not hov and nav.mouse_quiet();
        if pad_tip then nav.tip_beside(x, y, x + rw); end
        if hov or pad_tip then
            local extra = { { r.owned and ('In your ' .. (bags.where(r.id) or '?')) or 'You don\'t have this', r.owned and C.acc or C.warn } };
            if has_aug then table.insert(extra, 1, { 'Augments: ' .. r.sig, C.gold }); end
            items.tooltip(r.id, r.name, extra);
        end
        local pn = opts.nav;
        if pn and pn.prow == i then
            nav.ring(ldl, x, y, x + rw, y + rh, 6);
            if pn.moved then imgui.SetScrollHereY(0.5); pn.moved = false; end
            if pn.pick then c = true; pn.pick = false; end
        end
        if c then
            local pick = { id = r.id, name = r.name };
            if r.aug then
                local e = { augs = {} };
                for _, a in ipairs(r.aug.list or {}) do e.augs[#e.augs + 1] = a; end
                pick.augs = #e.augs > 0 and e.augs or nil;
                pick.path = r.aug.path;
                pick.rank = (r.aug.rank and r.aug.rank > 0) and r.aug.rank or nil;
            end
            result = { pick = pick };
        end
        imgui.SetCursorScreenPos({ x, y + rh + 2 });
    end
    imgui.Dummy({ 10, 4 });
    imgui.Unindent(5);
    theme.end_list(pv);
    imgui.SetCursorScreenPos({ x0, y0 });
    imgui.Dummy({ W, H });
    return result;
end

----------------------------------------------------------------------------------------------------
-- The totals panel
----------------------------------------------------------------------------------------------------
function gear.totals(dl, W, H, set_gear, title)
    local x0, y0 = imgui.GetCursorScreenPos();
    local lh = imgui.GetTextLineHeight();
    dl:AddRectFilled({ x0, y0 }, { x0 + W, y0 + H }, theme.bgc(0.085, 0.080, 0.115, 0.9), 10);
    dl:AddRect({ x0, y0 }, { x0 + W, y0 + H }, u32({ 1, 1, 1, 0.06 }), 10, C.rall, 1);
    theme.spaced(dl, x0 + 12, y0 + 9, (title or 'TOTALS'):upper(), u32({ 0.93, 0.90, 1, 1 }), 2);
    local list, cond = stats.of_set(set_gear);
    imgui.SetCursorScreenPos({ x0 + 6, y0 + 30 });
    local pv = theme.begin_list('##gt_list', W - 12, H - 36);
    local ldl = imgui.GetWindowDrawList();
    local n = 0;
    for s = 0, 15 do if set_gear and set_gear[s] and set_gear[s].id then n = n + 1; end end
    if n == 0 then
        imgui.Dummy({ 4, 4 });
        imgui.TextColored(C.muted, 'Pick a slot on the left and choose a piece.');
        imgui.TextColored(C.muted, 'The bonuses of every piece are added up here.');
    else
        -- the bonuses in columns
        local cols = W > 380 and 3 or 2;
        local cw = (W - 30) / cols;
        local k = 0;
        local sx, sy = imgui.GetCursorScreenPos();
        local pet_started = false;
        local function cell(e)
            local col, row = k % cols, math.floor(k / cols);
            local x, y = sx + 6 + col * cw, sy + row * (lh + 4);
            local label = e.name;
            local v = (e.value > 0 and '+' or '') .. tostring(e.value) .. (e.pct and '%' or '');
            if label == 'DEF' then v = tostring(e.value); end
            ldl:AddText({ x, y }, u32(e.pet and C.acc or C.muted), theme.fit(label, cw - tw(v) - 14));
            ldl:AddText({ x + cw - 10 - tw(v), y }, u32(e.value < 0 and C.warn or C.text), v);
            k = k + 1;
        end
        for _, e in ipairs(list) do
            if e.pet and not pet_started then
                pet_started = true;
                if k % cols ~= 0 then k = k + (cols - k % cols); end
                local row = math.floor(k / cols);
                theme.spaced(ldl, sx + 6, sy + row * (lh + 4) + 4, 'PET', u32({ C.acc[1], C.acc[2], C.acc[3], 0.9 }), 2);
                k = k + cols;
                sy = sy + 6;
            end
            cell(e);
        end
        local rows = math.ceil(k / cols);
        imgui.SetCursorScreenPos({ sx, sy + rows * (lh + 4) + 6 });
        if #list == 0 then imgui.TextColored(C.muted, 'No bonuses read from these pieces.'); end
        if #cond > 0 then
            local cx, cy = imgui.GetCursorScreenPos();
            theme.spaced(ldl, cx + 6, cy, 'ONLY SOMETIMES', u32({ C.muted[1], C.muted[2], C.muted[3], 0.9 }), 2);
            imgui.Dummy({ 10, lh + 4 });
            for _, l in ipairs(cond) do
                local tx, ty = imgui.GetCursorScreenPos();
                local h = theme.wrapped(ldl, tx + 6, ty, l.item .. ':  ' .. l.text, W - 40, u32({ C.muted[1], C.muted[2], C.muted[3], 0.85 }));
                imgui.Dummy({ W - 40, h + 2 });
            end
        end
    end
    theme.end_list(pv);
    imgui.SetCursorScreenPos({ x0, y0 });
    imgui.Dummy({ W, H });
end

-- The summary under a set's card: "HP+40 MP+60 INT+12 MAB+10 ..." in at most `lines` lines. Returns its height.
function gear.summary(dl, x, y, w, set_gear, lines)
    local list = stats.of_set(set_gear);
    local lh = imgui.GetTextLineHeight();
    if #list == 0 then return 0; end
    imgui.SetWindowFontScale(0.88);
    local slh = imgui.GetTextLineHeight();
    local cx, line = x, 1;
    local shown = 0;
    for i, e in ipairs(list) do
        local t = stats.label(e, true);
        local tw_ = tw(t);
        if cx + tw_ > x + w then
            line = line + 1;
            cx = x;
            if line > (lines or 2) then break; end
        end
        local rest = #list - i;
        if line == (lines or 2) and rest > 0 and cx + tw_ + tw('  +' .. rest .. ' more') > x + w then
            dl:AddText({ cx, y + (line - 1) * (slh + 1) }, u32({ C.muted[1], C.muted[2], C.muted[3], 0.7 }), '+' .. (rest + 1) .. ' more');
            shown = -1;
            break;
        end
        dl:AddText({ cx, y + (line - 1) * (slh + 1) }, u32(e.pet and C.acc or (e.value < 0 and C.warn or { 0.80, 0.80, 0.88, 1 })), t);
        cx = cx + tw_ + 10;
        shown = i;
    end
    imgui.SetWindowFontScale(1);
    return math.min(line, lines or 2) * (slh + 1);
end

return gear;
