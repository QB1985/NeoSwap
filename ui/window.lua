-- window.lua : the NeoSwap window. Jobs down the left (and Global: the lockstyle every job can share, and your
-- modes); the picked job's macros, lockstyle and sets in the middle, each set with its bonuses under it; the set
-- editor on the right: name, the equipment grid with a picker beside it, when it's worn, and what's wrong with it.
local imgui   = require('imgui');
local config  = require('configs.config');
local theme   = require('ui.theme');
local tex     = require('ui.tex');
local gear    = require('ui.gear');
local when    = require('ui.when');
local items   = require('core.items');
local bags    = require('core.bags');
local jobs    = require('core.jobs');
local store   = require('core.store');
local rules   = require('core.rules');
local check   = require('core.check');
local engine  = require('core.engine');
local status  = require('core.status');
local import  = require('core.import');
local tiers   = require('core.tiers');
local commands = require('core.commands');
local cview   = require('ui.commands_view');
local nav     = require('ui.nav');
local pad     = require('core.pad');
local C, u32, tip, tw = theme.C, theme.u32, theme.tip, theme.tw;
local NEON, NEON2 = theme.NEON, theme.NEON2;

local ui = {};
local TITLE = 'NEOSWAP';
local ICON, ICON_GAP = 18, 6;
local RAIL_W = 150;
local SETS_W = 318;

local st = {
    job = nil,            -- the rail's pick: a job abbreviation, or 'global'
    set = nil,            -- the set being edited (id)
    slot = nil,           -- the grid slot whose picker is open
    style = false,        -- editing the job's own lockstyle instead of a set
    del_armed = nil,      -- { id, at }: Delete clicked once
    name_buf = { '' }, name_for = nil,
    mode_buf = { '' },
    scroll_to_set = false,
    tab = 'sets',         -- the middle column: 'sets' or 'cmds' (the job's own commands)
    cmd = nil,            -- the command being edited (id)
    tier = nil,           -- the level (tier) of the set being edited: its gear table
    vis = {},             -- the cards in the middle column, top to bottom (ids, for the controller)
};

local STATUS_COL = { ok = C.good, warn = C.warn, err = C.bad, info = C.acc };

local function say(msg, kind) status.set(msg, kind or 'ok', 5); end

function ui.select_job(abbr) st.job = abbr; st.set = nil; st.slot = nil; st.style = false; st.import = nil; st.cmd = nil; end
cview.on_pick = function(id) st.cmd = id; st.style = false; st.import = nil; end
function ui.select_set(id) st.set = id; st.slot = nil; st.style = false; st.scroll_to_set = true; st.import = nil; end

local function cur_abbr() return jobs.ABBR[jobs.main()]; end
-- A custom entry (HELM...) works with any job
local function usable_now(abbr) return abbr == cur_abbr() or store.is_entry(abbr); end
-- The level sets are seen at: the job's level, or (a custom entry) your main job's
local function view_level(abbr)
    if store.is_entry(abbr) then return jobs.main_level(); end
    return jobs.level(jobs.id(abbr) or 0);
end
local ENTRY_ICONS = require('data.entry_icons');

-- A custom entry's icon (an item's icon, a job emblem, or its first letter)
local icon_pick = require('ui.icon_pick');
local function entry_icon(dl, e, x, y, size, a)
    return icon_pick.draw(dl, e and e.icon, x, y, size, a, e and e.name);
end

local function popup_style() return when.popup_style(); end
local function popup_pop(pv) when.popup_pop(pv); end

----------------------------------------------------------------------------------------------------
-- Title row
----------------------------------------------------------------------------------------------------
local function title_icons(xr, y, h, kinds)
    local by = y + (h - ICON) / 2;
    local hit = nil;
    for i = #kinds, 1, -1 do
        local k = kinds[i];
        local x = xr - (#kinds - i + 1) * ICON - (#kinds - i) * ICON_GAP;
        local clicked, hov = theme.icon_button('##ns_ic_' .. k[1], x, by, k[1]);
        if hov then tip(k[2]); end
        if clicked then hit = k[1]; end
    end
    return hit;
end

local function engine_chip()
    local abbr = cur_abbr();
    if engine.other_caster then return 'Another swapper is running', C.bad,
        'Another addon (LuAshitacast?) is also re-sending your actions, so both swap gear.\nClick to unload LuAshitacast. (/addon unload luashitacast)'; end
    if not config.get('engine_on') then return 'Swapping off', C.muted, 'NeoSwap is not changing your gear.\nClick to turn swapping on.'; end
    if abbr == nil then return 'Not logged in', C.muted, ''; end
    if not engine.active() then return 'No ' .. abbr .. ' sets', C.muted, 'Make a set for ' .. abbr .. ' and NeoSwap starts swapping.\nClick to turn swapping off.'; end
    local act = {};
    for _, k in ipairs(store.active_entry_keys()) do local e = store.entry(k); if e then act[#act + 1] = e.name; end end
    if #act > 0 then
        return 'Swapping: ' .. abbr .. ' + ' .. table.concat(act, ', '), C.good, 'NeoSwap puts your ' .. abbr .. ' sets on as you play, with ' .. table.concat(act, ', ') .. ' over them.\nClick to turn swapping off.';
    end
    return 'Swapping for ' .. abbr, C.good, 'NeoSwap puts your ' .. abbr .. ' sets on as you play.\nClick to turn swapping off.';
end

local function title_row(dl, W)
    local x0, y0 = imgui.GetCursorScreenPos();
    local tw_, th = theme.title(dl, x0, y0, TITLE, 3, 1.3);
    local lh = imgui.GetTextLineHeight();
    local m, s = jobs.main(), jobs.sub();
    local who = m > 0 and string.format('%s%d%s', jobs.ABBR[m] or '?', jobs.main_level(),
        s > 0 and string.format(' / %s%d', jobs.ABBR[s] or '?', jobs.sub_level()) or '') or '';
    dl:AddText({ x0 + tw_ + 10, y0 + th - lh - 1 }, u32(C.muted), who);
    local icons = { { 'gear', 'Settings' }, { 'min', 'Minimize to the NSWP bubble' }, { 'close', 'Close (/nswap brings it back)' } };
    local hit = title_icons(x0 + W, y0, th, icons);

    local rx = x0 + W - (#icons * ICON + (#icons - 1) * ICON_GAP) - 12;
    local cy = y0 + (th - lh - 2) / 2;
    -- the engine
    local label, col, hint_ = engine_chip();
    local cw = theme.chip_w(label);
    theme.chip(dl, rx - cw, cy, label, col);
    imgui.SetCursorScreenPos({ rx - cw, cy });
    if imgui.InvisibleButton('##ns_engine', { cw, lh + 2 }) then
        if engine.other_caster then
            pcall(function() AshitaCore:GetPluginManager():RaiseEvent('luashitacast_unload', {}); end);
            AshitaCore:GetChatManager():QueueCommand(-1, '/addon unload luashitacast');
            engine.other_caster = false;
            say('Asked LuAshitacast to unload.', 'info');
        else
            config.toggle('engine_on');
        end
    end
    if imgui.IsItemHovered() and hint_ ~= '' then tip(hint_); end
    rx = rx - cw - 8;
    -- locked slots
    local locked = engine.locked_slots();
    if #locked > 0 then
        local l = 'Held: ' .. (#locked > 3 and (#locked .. ' slots') or table.concat(locked, ', '));
        local lw = theme.chip_w(l);
        theme.chip(dl, rx - lw, cy, l, C.warn);
        imgui.SetCursorScreenPos({ rx - lw, cy });
        if imgui.InvisibleButton('##ns_unlock', { lw, lh + 2 }) then engine.unlock_all(); say('Every slot is free again.'); end
        if imgui.IsItemHovered() then tip('NeoSwap leaves these slots alone (Equip now holds a set on).\nClick to let go of them. (/nswap unlock)'); end
        rx = rx - lw - 8;
    end
    imgui.SetCursorScreenPos({ x0, y0 });
    imgui.Dummy({ W, th });
    return hit;
end

----------------------------------------------------------------------------------------------------
-- The rail: Global, then the jobs
----------------------------------------------------------------------------------------------------
local function rail(dl, H)
    local x0, y0 = imgui.GetCursorScreenPos();
    local lh = imgui.GetTextLineHeight();
    dl:AddRectFilled({ x0, y0 }, { x0 + RAIL_W, y0 + H }, theme.bgc(0.085, 0.080, 0.115, 0.9), 10);
    dl:AddRect({ x0, y0 }, { x0 + RAIL_W, y0 + H }, u32({ 1, 1, 1, 0.06 }), 10, C.rall, 1);
    local pv = theme.begin_list('##ns_rail', RAIL_W, H);
    local rdl = imgui.GetWindowDrawList();
    imgui.Dummy({ RAIL_W, 4 });
    local function group(name)
        local gx, gy = imgui.GetCursorScreenPos();
        imgui.Dummy({ RAIL_W, lh + 6 });
        theme.spaced(rdl, gx + 10, gy + 4, name, u32({ C.muted[1], C.muted[2], C.muted[3], 0.8 }), 1.5);
        local lx = gx + 10 + theme.spaced_w(name, 1.5) + 8;
        rdl:AddLine({ lx, gy + 4 + lh / 2 }, { gx + RAIL_W - 10, gy + 4 + lh / 2 }, u32({ 1, 1, 1, 0.06 }), 1);
    end
    local function row(key, text, emblem, count, dim, dot, hint_)
        local x, y = imgui.GetCursorScreenPos();
        local h = 26;
        if imgui.InvisibleButton('##ns_tab_' .. key, { RAIL_W - 8, h }) then ui.select_job(key); end
        local hov = imgui.IsItemHovered();
        local sel = st.job == key;
        if sel then
            rdl:AddRectFilled({ x + 4, y }, { x + RAIL_W - 8, y + h }, u32({ NEON[1] * 0.32, NEON[2] * 0.32, NEON[3] * 0.32, 0.9 }), 7);
            rdl:AddRectFilled({ x + 4, y + 5 }, { x + 6, y + h - 5 }, u32(NEON2), 1);
        elseif hov then
            rdl:AddRectFilled({ x + 4, y }, { x + RAIL_W - 8, y + h }, theme.bgc(1, 1, 1, 0.06), 7);
        end
        local tx = x + 12;
        if type(emblem) == 'table' then
            entry_icon(rdl, emblem, x + 10, y + 3, 20, 1); tx = x + 36;
        elseif emblem then
            if tex.job(rdl, emblem, x + 10, y + 3, 20, dim and 0.35 or 1) then tx = x + 36; else tx = x + 14; end
        end
        local room = x + RAIL_W - 18 - tx - ((count and count ~= '') and (tw(count) + 6) or 0);
        rdl:AddText({ tx, y + (h - lh) / 2 }, u32(dim and { 0.45, 0.44, 0.52, 1 } or ((sel or hov) and { 1, 1, 1, 1 } or C.text)), theme.fit(text, room));
        if dot then rdl:AddCircleFilled({ tx + math.min(tw(text), room) + 7, y + h / 2 }, 3, u32(type(dot) == 'table' and dot or C.gold), 12); end
        if count and count ~= '' then
            local cw = tw(count);
            rdl:AddText({ x + RAIL_W - 16 - cw, y + (h - lh) / 2 }, u32({ C.muted[1], C.muted[2], C.muted[3], 0.85 }), count);
        end
        if hov and hint_ then tip(hint_); end
        if sel and nav.is('rail') then
            nav.ring(rdl, x + 9, y + 2, x + RAIL_W - 13, y + h - 2, 6);
            if nav.moved then imgui.SetScrollHereY(0.5); nav.moved = false; end
        end
        imgui.SetCursorScreenPos({ x, y + h + 2 });
    end
    group('GLOBAL');
    row('global', 'Style & modes', nil, nil, false, false, 'Global lockstyle (the look every job can share), and your modes');
    group('JOBS');
    local cm = jobs.main();
    for i, a in ipairs(jobs.ABBR) do
        local lv = jobs.level(i);
        local n = store.count(a);
        local res = n > 0 and check.job(a, store.sets(a)) or nil;
        local cnt = n > 0 and tostring(n) or '';
        local hint_ = jobs.NAME[i] .. (lv > 0 and (' - level ' .. lv) or ' - not unlocked') .. '\n' .. n .. ' set' .. (n == 1 and '' or 's');
        if res and res.errors > 0 then hint_ = hint_ .. '\n' .. res.errors .. ' problem' .. (res.errors == 1 and '' or 's') .. ' to fix'; end
        if i == cm then hint_ = hint_ .. '\nYour job now'; end
        row(a, a, a, cnt, lv == 0 and n == 0, i == cm, hint_);
        if res and res.errors > 0 then
            local _, y = imgui.GetCursorScreenPos();
            rdl:AddCircleFilled({ x0 + RAIL_W - 20 - tw(cnt) - 6, y - 15 }, 3.5, u32(C.bad), 12);
        end
    end
    -- custom entries (HELM, Fishing...)
    group('CUSTOM');
    for _, e in ipairs(store.entries()) do
        local n = store.count(e.key);
        row(e.key, e.name or '?', e, n > 0 and tostring(n) or '', false, e.active and C.good or false,
            (e.name or '') .. '\n' .. n .. ' set' .. (n == 1 and '' or 's') .. '\n' ..
            (e.active and 'On: its sets go on over your job\'s.' or 'Off. Switch it on on its page, or /nswap entry ' .. (e.name or '') .. ' on'));
    end
    do
        local x, y = imgui.GetCursorScreenPos();
        local h = 24;
        if imgui.InvisibleButton('##ns_new_entry', { RAIL_W - 8, h }) then
            local e = store.new_entry('New entry', nil);
            ui.select_job(e.key);
            st.focus_entry_name = true;
        end
        local hov = imgui.IsItemHovered();
        if hov then rdl:AddRectFilled({ x + 4, y }, { x + RAIL_W - 8, y + h }, theme.bgc(1, 1, 1, 0.06), 7); end
        rdl:AddText({ x + 14, y + (h - lh) / 2 }, u32(hov and C.acc or { C.muted[1], C.muted[2], C.muted[3], 0.85 }), '+ New entry');
        if hov then tip('Add your own entry to this list (HELM, Fishing, Crafting...): sets that aren\'t a job\'s.\nSwitch it on and its sets go on over your job\'s, whatever your job.'); end
        imgui.SetCursorScreenPos({ x, y + h + 2 });
    end
    imgui.Dummy({ RAIL_W, 4 });
    theme.end_list(pv);
end

----------------------------------------------------------------------------------------------------
-- The job column: header, macros, lockstyle, modes, sets
----------------------------------------------------------------------------------------------------
local function unique_name(abbr, base)
    if store.find_by_name(abbr, base) == nil then return base; end
    for i = 2, 99 do
        local n = base .. ' ' .. i;
        if store.find_by_name(abbr, n) == nil then return n; end
    end
    return base;
end

local function modes_used(abbr)
    local t, seen = {}, {};
    for _, s in ipairs(store.sets(abbr)) do
        for _, c in ipairs((s.when and s.when.cond) or {}) do
            if c.t == 'mode' and c.v and c.v ~= '' and not seen[c.v:lower()] then seen[c.v:lower()] = true; t[#t + 1] = c.v; end
        end
    end
    table.sort(t);
    return t;
end

local function mode_pills(dl, list, W, idp)
    local x0, y0 = imgui.GetCursorScreenPos();
    local cx, cy = x0, y0;
    for i, m in ipairs(list) do
        local on = store.mode(m);
        local lbl = m .. (on and ': on' or ': off');
        local pw = theme.pill_w(lbl);
        if cx + pw > x0 + W and cx > x0 then cx = x0; cy = cy + theme.pill_h() + 5; end
        local c, h = theme.pill('##' .. idp .. i, lbl, on, cx, cy);
        if h then tip('Mode "' .. m .. '": sets that wait on it are ' .. (on and 'worn' or 'not worn') .. '.\nClick to switch. (/nswap mode ' .. m .. ')'); end
        if c then store.set_mode(m, not on); end
        cx = cx + pw + 5;
    end
    imgui.SetCursorScreenPos({ x0, cy + theme.pill_h() + 4 });
end

local function job_header(dl, abbr, W)
    local job = jobs.id(abbr);
    local x0, y0 = imgui.GetCursorScreenPos();
    local lh = imgui.GetTextLineHeight();
    local E = 38;
    if not tex.job(dl, abbr, x0, y0, E, 1) then E = 0; end
    local tx = x0 + (E > 0 and E + 10 or 0);
    imgui.SetWindowFontScale(1.15);
    dl:AddText({ tx, y0 + 1 }, u32(C.text), jobs.NAME[job] or abbr);
    imgui.SetWindowFontScale(1);
    local lv = jobs.level(job);
    dl:AddText({ tx, y0 + lh + 6 }, u32(C.muted), lv > 0 and ('Level ' .. lv .. (job == jobs.main() and '  -  your job now' or '')) or 'Not unlocked');
    imgui.Dummy({ W, math.max(E, lh * 2 + 8) });

    local j = store.job(abbr, true);
    j.macro = j.macro or { on = false, book = 1, page = 1 };
    -- (rows: the name on the left, the controls from LW on, everything kept inside the column's width W.
    --  Screen positions throughout: SameLine(x) would add the group's indent a second time.)
    local LW = 84;
    local lx = select(1, imgui.GetCursorScreenPos());
    local fh = imgui.GetFrameHeight();
    local function row_label(text, hint_)
        imgui.Spacing();
        local _, y = imgui.GetCursorScreenPos();
        imgui.SetCursorScreenPos({ lx, y });
        imgui.AlignTextToFramePadding();
        imgui.TextColored(C.text, text);
        if hint_ and imgui.IsItemHovered() then tip(hint_); end
        return y;
    end
    local function next_row(y, h) imgui.SetCursorScreenPos({ lx, y + h + 4 }); imgui.Dummy({ W, 0 }); end

    -- macros: the switch, then (on) book, page and Set now on a row of their own
    local y = row_label('Macros', 'Change to this macro book and page when you change to ' .. abbr .. '.');
    imgui.SetCursorScreenPos({ lx + LW, y + (fh - 26) / 2 });
    if theme.switch('##ns_mac_on', j.macro.on == true) then j.macro.on = not j.macro.on; store.touch(); end
    if imgui.IsItemHovered() then tip(j.macro.on and ('On: book and page are set when you change to ' .. abbr) or 'Off: your macros are left as they are'); end
    next_row(y, math.max(fh, 26));
    if j.macro.on then
        local _, y2 = imgui.GetCursorScreenPos();
        local dw, dh = theme.digits_size(40);
        local ty = y2 + (dh - lh) / 2;
        local x = lx + LW;
        dl:AddText({ x, ty }, u32(C.muted), 'Book');
        x = x + tw('Book') + 8;
        imgui.SetCursorScreenPos({ x, y2 });
        local b, bc = theme.digits('ns_mac_b' .. abbr, tonumber(j.macro.book) or 1, 1, 40);
        if bc then j.macro.book = b; store.touch(); end
        x = x + dw + 14;
        dl:AddText({ x, ty }, u32(C.muted), 'Page');
        x = x + tw('Page') + 8;
        imgui.SetCursorScreenPos({ x, y2 });
        local p, pc = theme.digits('ns_mac_p' .. abbr, tonumber(j.macro.page) or 1, 1, 10);
        if pc then j.macro.page = p; store.touch(); end
        x = x + select(1, theme.digits_size(10)) + 14;
        if abbr == cur_abbr() and x + theme.pill_w('Set now') <= lx + W then
            imgui.SetCursorScreenPos({ x, y2 + (dh - theme.pill_h()) / 2 });
            local c, h = theme.button('##ns_mac_go', 'Set now', {});
            if h then tip('Change to this book and page now'); end
            if c then engine.apply_macros(); say('Macro book ' .. j.macro.book .. ', page ' .. j.macro.page .. '.'); end
        end
        next_row(y2, dh);
    end

    -- lockstyle: Off / Global / Own, then (Own) Edit
    j.lockstyle = j.lockstyle or { mode = 'global', set = {} };
    local opts = { { 'off', 'Off', 'No lockstyle for ' .. abbr },
                   { 'global', 'Global', 'The global lockstyle (Global, top of the left list)' },
                   { 'job', 'Own', abbr .. '\'s own lockstyle' } };
    y = row_label('Lockstyle', 'The look this job keeps (set when you change to ' .. abbr .. ' and after zoning).');
    local sw = theme.segmented_w(opts);
    local sx = lx + LW;
    if sx + sw > lx + W then sx = lx + W - sw; end
    imgui.SetCursorScreenPos({ sx, y + (fh - theme.pill_h()) / 2 });
    local pk = theme.segmented('##ns_ls_mode', opts, j.lockstyle.mode);
    if pk and pk ~= j.lockstyle.mode then
        j.lockstyle.mode = pk; store.touch();
        if pk == 'job' then st.style = true; st.slot = nil; end
    end
    local rh = math.max(fh, theme.pill_h());
    local ex = sx + sw + 6;
    local el = st.style and 'Editing' or 'Edit';
    if j.lockstyle.mode == 'job' then
        local ew = tw(el) + 24;
        local ey = y + (fh - theme.pill_h()) / 2;
        if ex + ew > lx + W then ex, ey = lx + LW, y + rh + 6; rh = rh + theme.pill_h() + 6; end   -- (no room: under it)
        imgui.SetCursorScreenPos({ ex, ey });
        local c, h = theme.button('##ns_ls_edit', el, { lit = st.style });
        if h then tip('Build ' .. abbr .. '\'s own look in the editor on the right'); end
        if c then st.style = not st.style; st.slot = nil; st.import = nil; end
    end
    next_row(y, rh);

    -- modes
    local ml = modes_used(abbr);
    if #ml > 0 then
        y = row_label('Modes', 'Your own switches that sets can wait on');
        imgui.SetCursorScreenPos({ lx + LW, y });
        imgui.BeginGroup();
        mode_pills(dl, ml, W - LW, 'ns_jm');
        imgui.EndGroup();
    end
end

-- A custom entry's header: its icon (click to change), name, on / off, delete
local function icon_menu(e)
    icon_pick.menu('##ns_icon_pop', e, { { title = 'GATHERING & CRAFTING', list = ENTRY_ICONS } });
end

local function entry_header(dl, abbr, W)
    local e = store.entry(abbr);
    if e == nil then return; end
    local x0, y0 = imgui.GetCursorScreenPos();
    local lh = imgui.GetTextLineHeight();
    local E = 38;
    imgui.SetCursorScreenPos({ x0, y0 });
    if imgui.InvisibleButton('##ns_entry_icon', { E, E }) then icon_pick.reset_search(); imgui.OpenPopup('##ns_icon_pop'); end
    local ih = imgui.IsItemHovered();
    entry_icon(dl, e, x0, y0, E, 1);
    if ih then
        dl:AddRect({ x0 - 2, y0 - 2 }, { x0 + E + 2, y0 + E + 2 }, u32({ NEON2[1], NEON2[2], NEON2[3], 0.8 }), 6, C.rall, 1.5);
        tip('Click to pick its icon (gathering tools, crafting, job emblems, or any item)');
    end
    icon_menu(e);
    -- the name
    if st.entry_name_for ~= e.key then st.entry_name_for = e.key; st.entry_name = { e.name or '' }; end
    imgui.SetCursorScreenPos({ x0 + E + 10, y0 + (E - theme.pill_h()) / 2 - 2 });
    theme.input('##ns_entry_name', st.entry_name, 32, W - E - 10, 'Name (HELM, Fishing...)', false);
    if st.focus_entry_name then
        pcall(function() imgui.SetKeyboardFocusHere(-1); end);
        st.focus_entry_name = false;
    end
    local nm = (st.entry_name[1] or '');
    if nm ~= (e.name or '') then e.name = nm; store.touch(); end
    imgui.SetCursorScreenPos({ x0, y0 + E + 10 });
    -- on / off
    local y = select(2, imgui.GetCursorScreenPos());
    dl:AddText({ x0, y + (imgui.GetFrameHeight() - lh) / 2 }, u32(C.text), 'Active');
    imgui.SetCursorScreenPos({ x0 + 84, y + (imgui.GetFrameHeight() - 26) / 2 });
    if theme.switch('##ns_entry_on', e.active == true) then e.active = not e.active; store.touch(); end
    if imgui.IsItemHovered() then tip('On: its sets go on over your job\'s sets, whatever your job (Idle over Idle, and so on).\n/nswap entry ' .. (e.name or '') .. ' on|off does the same (in a macro, say).'); end
    -- delete
    local dl_label = (st.del_entry and st.del_entry.key == e.key and os.clock() - st.del_entry.at < 3) and 'Sure?' or 'Delete entry';
    local bw = tw(dl_label) + 24;
    imgui.SetCursorScreenPos({ x0 + W - bw, y + (imgui.GetFrameHeight() - theme.pill_h()) / 2 });
    local dc, dh = theme.button('##ns_entry_del', dl_label, { col = dl_label == 'Sure?' and C.bad or nil });
    if dh then tip('Delete this entry and its sets (click twice)'); end
    if dc then
        if dl_label == 'Sure?' then
            store.remove_entry(e.key);
            st.del_entry = nil;
            ui.select_job(cur_abbr() or 'global');
            say('Deleted the entry.');
            return;
        else st.del_entry = { key = e.key, at = os.clock() }; end
    end
    imgui.SetCursorScreenPos({ x0, y + imgui.GetFrameHeight() + 6 });
    local hx, hy = imgui.GetCursorScreenPos();
    local h = theme.wrapped(dl, hx, hy, e.active and 'On: these sets go on over your job\'s.' or 'Off: these sets are only worn with Equip now or a command.', W,
        u32({ C.muted[1], C.muted[2], C.muted[3], 0.8 }));
    imgui.Dummy({ W, h });
end

-- The "+ New set" menu
local function new_set_menu(abbr)
    local pv = popup_style();
    if imgui.BeginPopup('##ns_new_pop') then
        theme.spaced(imgui.GetWindowDrawList(), imgui.GetCursorScreenPos(), select(2, imgui.GetCursorScreenPos()), 'A SET FOR', u32(C.muted), 2);
        imgui.Dummy({ 200, imgui.GetTextLineHeight() });
        for _, k in ipairs(rules.KINDS) do
            if imgui.Selectable('  ' .. k.label .. '##ns_new_' .. k.key, false, 0, { 220, 0 }) then
                local s = store.new_set(abbr, k.key, unique_name(abbr, k.label));
                ui.select_set(s.id);
            end
            if imgui.IsItemHovered() then tip(k.hint); end
        end
        imgui.EndPopup();
    end
    popup_pop(pv);
end

local KIND_ORDER = {};
for i, k in ipairs(rules.KINDS) do KIND_ORDER[k.key] = i; end

-- A set's card: name, problems, worn-now dot, its trigger, its bonuses
local function set_card(dl, abbr, s, W, res, worn_now)
    local lh = imgui.GetTextLineHeight();
    local x, y = imgui.GetCursorScreenPos();
    local H = lh * 2 + 2 * (math.floor(lh * 0.88) + 1) + 24;
    local c = imgui.InvisibleButton('##ns_card' .. s.id, { W, H });
    local hov = imgui.IsItemHovered();
    local rclick = imgui.IsItemClicked(1);
    local sel = st.set == s.id and not st.style;
    local fill = sel and { NEON[1] * 0.28, NEON[2] * 0.28, NEON[3] * 0.28, 0.95 } or (hov and { 0.13, 0.12, 0.17, 1 } or { 0.075, 0.070, 0.100, 0.9 });
    dl:AddRectFilled({ x, y }, { x + W, y + H }, u32(fill), 9);
    dl:AddRect({ x, y }, { x + W, y + H }, u32(sel and { NEON2[1], NEON2[2], NEON2[3], 0.85 } or { 1, 1, 1, hov and 0.18 or 0.07 }), 9, C.rall, sel and 1.4 or 1);
    local off = s.off == true;
    -- right side: problems, worn now
    local probs = res and res.by_set[s.id] or {};
    local ne, nw = 0, 0;
    for _, p in ipairs(probs) do if p.level == 'err' then ne = ne + 1; elseif p.level == 'warn' then nw = nw + 1; end end
    local rx = x + W - 10;
    if ne + nw > 0 then
        local t = tostring(ne > 0 and ne or nw);
        local col = ne > 0 and C.bad or C.warn;
        local r = 8;
        dl:AddCircleFilled({ rx - r, y + 8 + lh / 2 }, r, u32({ col[1], col[2], col[3], 0.25 }), 16);
        dl:AddCircle({ rx - r, y + 8 + lh / 2 }, r, u32(col), 16, 1.2);
        imgui.SetWindowFontScale(0.85);
        dl:AddText({ rx - r - tw(t) / 2, y + 8 + lh / 2 - imgui.GetTextLineHeight() / 2 }, u32(col), t);
        imgui.SetWindowFontScale(1);
        rx = rx - r * 2 - 6;
    end
    if worn_now then
        local t = 'ON';
        local w = theme.chip_w(t);
        theme.chip(dl, rx - w, y + 7, t, C.good);
        rx = rx - w - 6;
    end
    if off then
        local t = 'OFF';
        local w = theme.chip_w(t);
        theme.chip(dl, rx - w, y + 7, t, C.muted);
        rx = rx - w - 6;
    end
    local name = (s.name and s.name ~= '') and s.name or '(no name)';
    dl:AddText({ x + 12, y + 8 }, u32(off and C.muted or { 1, 1, 1, 1 }), theme.fit(name, rx - x - 18));
    -- the trigger and conditions
    local w = s.when or {};
    local trig = rules.trigger_text(w);
    local conds = {};
    for _, cnd in ipairs(w.cond or {}) do conds[#conds + 1] = rules.cond_text(cnd); end
    local line = trig .. (#conds > 0 and ('  -  ' .. table.concat(conds, ', ')) or '') .. ((tonumber(s.prio) or 0) > 0 and ('  -  priority ' .. s.prio) or '')
        .. (tiers.count(s) > 1 and ('  -  ' .. tiers.count(s) .. ' levels') or '');
    dl:AddText({ x + 12, y + 10 + lh }, u32({ C.acc[1], C.acc[2], C.acc[3], off and 0.5 or 0.9 }), theme.fit(line, W - 24));
    -- the bonuses
    local jlv = view_level(abbr);
    local eff = tiers.effective(s, jlv > 0 and jlv or 99);
    local sh = gear.summary(dl, x + 12, y + 14 + lh * 2, W - 24, eff, 2);
    if sh == 0 then
        local n = 0;
        for sl = 0, 15 do if eff[sl] and (eff[sl].id or eff[sl].remove) then n = n + 1; end end
        dl:AddText({ x + 12, y + 14 + lh * 2 }, u32({ C.muted[1], C.muted[2], C.muted[3], 0.6 }), n == 0 and 'No gear yet' or (n .. ' piece' .. (n == 1 and '' or 's') .. ', no bonuses read'));
    end
    if hov then
        local t = name .. '\n' .. line;
        if #probs > 0 then
            t = t .. '\n';
            for _, p in ipairs(probs) do if p.level ~= 'info' then t = t .. '\n' .. (p.level == 'err' and '! ' or '- ') .. p.text; end end
        end
        if worn_now then t = t .. '\n\nWorn now.'; end
        tip(t .. '\n\nClick: edit   Right-click: more');
    end
    if c then ui.select_set(s.id); end
    if rclick then st.ctx = s.id; imgui.OpenPopup('##ns_card_pop'); end
    st.vis[#st.vis + 1] = s.id;
    if nav.is('list') and nav.row == #st.vis then
        nav.ring(dl, x, y, x + W, y + H, 9);
        if nav.moved then imgui.SetScrollHereY(0.5); nav.moved = false; end
    end
    imgui.SetCursorScreenPos({ x, y + H + 5 });
end

local function card_menu(abbr)
    local pv = popup_style();
    if imgui.BeginPopup('##ns_card_pop') then
        local s = store.find(abbr, st.ctx);
        if s then
            if imgui.Selectable('  Equip now (and hold it)##ns_cm_eq', false, 0, { 220, 0 }) then
                engine.wear(s, true); say('Wearing "' .. s.name .. '". /nswap unlock lets go of it.');
            end
            if imgui.Selectable('  Duplicate##ns_cm_dup', false, 0, { 220, 0 }) then
                local c = store.duplicate(abbr, s.id); if c then ui.select_set(c.id); end
            end
            if imgui.Selectable('  Move up##ns_cm_up', false, 0, { 220, 0 }) then store.move(abbr, s.id, -1); end
            if imgui.Selectable('  Move down##ns_cm_dn', false, 0, { 220, 0 }) then store.move(abbr, s.id, 1); end
            if imgui.Selectable(s.off and '  Turn on##ns_cm_on' or '  Turn off##ns_cm_on', false, 0, { 220, 0 }) then
                s.off = not s.off or nil; store.touch();
            end
            if imgui.BeginMenu('  Copy to job##ns_cm_copy') then
                for _, a in ipairs(jobs.ABBR) do
                    if a ~= abbr and imgui.MenuItem(a .. '##ns_cm_cp' .. a) then
                        store.copy_set_to_job(abbr, s.id, a);
                        say('Copied "' .. s.name .. '" to ' .. a .. '.');
                    end
                end
                imgui.EndMenu();
            end
            imgui.Separator();
            if imgui.Selectable('  Delete##ns_cm_del', false, 0, { 220, 0 }) then
                store.remove(abbr, s.id);
                if st.set == s.id then st.set = nil; end
                say('Deleted "' .. s.name .. '".');
            end
        end
        imgui.EndPopup();
    end
    popup_pop(pv);
end

local function job_column(dl, abbr, W, H)
    local x0, y0 = imgui.GetCursorScreenPos();
    imgui.BeginGroup();
    if store.is_entry(abbr) then entry_header(dl, abbr, W); else job_header(dl, abbr, W); end
    -- Sets / Commands
    imgui.Spacing();
    local ns, nc_ = store.count(abbr), #commands.list(abbr);
    local tp = theme.segmented('##ns_coltab', { { 'sets', 'Sets (' .. ns .. ')', 'This job\'s gear sets' },
        { 'cmds', 'Commands (' .. nc_ .. ')', 'This job\'s own commands: steps NeoSwap runs for you (Elemental Siphon...)' } }, st.tab);
    if tp and tp ~= st.tab then st.tab = tp; st.import = nil; st.style = false; end
    st.vis = {};
    if st.tab == 'cmds' then
        local _, cy = imgui.GetCursorScreenPos();
        cview.list(dl, abbr, W, y0 + H - cy, st.cmd, cview.on_pick, nav.is('list') and nav.row or nil);
        st.vis = cview.order or {};
        imgui.EndGroup();
        return;
    end
    local sets = store.sets(abbr);
    local res = check.job(abbr, sets);
    -- the sets header
    local lh = imgui.GetTextLineHeight();
    local bw = theme.pill_w('+ New set');
    local iw = theme.pill_w('Import');
    local sx, sy = theme.section('Sets', W, bw + iw + 6);
    imgui.SetCursorScreenPos({ x0 + W - bw - iw - 6, sy - 3 });
    local ic, ih = theme.pill('##ns_import', 'Import', st.import ~= nil);
    if ih then tip('Bring in sets from a LuAshitacast profile'); end
    if ic then ui.open_import(abbr); end
    imgui.SetCursorScreenPos({ x0 + W - bw, sy - 3 });
    local nc, nh = theme.pill('##ns_new', '+ New set', true);
    if nh then tip('Make a set: pick what it is for (Idle, a weapon skill, spells...)'); end
    if nc then imgui.OpenPopup('##ns_new_pop'); end
    new_set_menu(abbr);
    imgui.SetCursorScreenPos({ x0, sy + lh + 6 });
    if #res.conflicts > 0 then
        local t = #res.conflicts .. ' clash' .. (#res.conflicts == 1 and '' or 'es') .. ' between sets';
        local cx, cy = imgui.GetCursorScreenPos();
        theme.chip(dl, cx, cy, t, C.bad);
        imgui.Dummy({ W, lh + 4 });
        if imgui.IsItemHovered() then
            local tt = '';
            for _, c in ipairs(res.conflicts) do tt = tt .. (tt ~= '' and '\n\n' or '') .. c.text; end
            tip(tt);
        end
    end
    -- the list
    local _, ly = imgui.GetCursorScreenPos();
    local pv = theme.begin_list('##ns_sets', W, y0 + H - ly);
    local ldl = imgui.GetWindowDrawList();
    imgui.Indent(6);
    imgui.Dummy({ 1, 4 });
    if #sets == 0 then
        imgui.Dummy({ 4, 6 });
        local h = theme.wrapped(ldl, imgui.GetCursorScreenPos(), select(2, imgui.GetCursorScreenPos()),
            'No ' .. abbr .. ' sets yet. "+ New set" makes one: Idle and Engaged first, then weapon skills, abilities and spells.',
            W - 10, u32(C.muted));
        imgui.Dummy({ W - 10, h });
    else
        local worn = usable_now(abbr) and engine.preview() or {};
        -- grouped by trigger, in the trigger list's order (the order inside a group is kept)
        local groups, order = {}, {};
        for _, s in ipairs(sets) do
            local k = (s.when and s.when.kind) or 'idle';
            if groups[k] == nil then groups[k] = {}; order[#order + 1] = k; end
            groups[k][#groups[k] + 1] = s;
        end
        table.sort(order, function(a, b) return (KIND_ORDER[a] or 99) < (KIND_ORDER[b] or 99); end);
        for _, k in ipairs(order) do
            local gx, gy = imgui.GetCursorScreenPos();
            local label = ((rules.BY_KIND[k] and rules.BY_KIND[k].label) or k):upper();
            theme.spaced(ldl, gx + 4, gy + 4, label, u32({ C.muted[1], C.muted[2], C.muted[3], 0.85 }), 1.5);
            imgui.Dummy({ W, lh + 8 });
            for _, s in ipairs(groups[k]) do set_card(ldl, abbr, s, W - 20, res, worn[s.id]); end
        end
    end
    card_menu(abbr);
    imgui.Dummy({ 4, 6 });
    imgui.Unindent(6);
    theme.end_list(pv);
    imgui.EndGroup();
end

----------------------------------------------------------------------------------------------------
-- The editor
----------------------------------------------------------------------------------------------------
local function copy_worn(g, only)
    local n = 0;
    for s = 0, 15 do
        if only == nil or only[s] then
            local e = bags.equipped(s);
            if e then
                local a = bags.worn_augments(s) or {};
                g[s] = { id = e.id, name = items.name(e.id), augs = (a.augs and #a.augs > 0) and a.augs or nil, path = a.path, rank = a.rank };
                n = n + 1;
            end
        end
    end
    store.touch();
    return n;
end

-- The grid with the picker or the totals beside it. g: the gear table to edit. opts: { job, style }
local function gear_block(dl, W, g, opts, bad)
    local GS = gear.grid_size();
    local x0, y0 = imgui.GetCursorScreenPos();
    st.cur_gear, st.cur_style = g, opts.style == true;
    local c, rc = gear.grid(dl, g, { sel = st.slot, only = opts.style and bags.STYLE_SLOTS or nil, bad = bad, id = opts.style and 'ls' or 'set',
                                     nav_i = nav.is('grid') and nav.eq or nil, ghost = opts.ghost });
    if c ~= nil then st.slot = (st.slot == c) and nil or c; gear.reset_search(); end
    if rc ~= nil then g[rc] = nil; store.touch(); end
    local PW = W - GS - 14;
    local PH = math.max(GS + 70, 300);
    imgui.SetCursorScreenPos({ x0 + GS + 14, y0 });
    if st.slot ~= nil then
        local r = gear.picker(dl, PW, PH, st.slot, g[st.slot], { job = opts.job, style = opts.style, nav = nav.is('picker') and nav or nil });
        if r then
            if r.close then st.slot = nil;
            elseif r.clear then g[st.slot] = nil; store.touch();
            elseif r.remove then g[st.slot] = { remove = true }; store.touch();
            elseif r.pick then g[st.slot] = { id = r.pick.id, name = r.pick.name, augs = r.pick.augs, path = r.pick.path, rank = r.pick.rank }; store.touch(); end
        end
    else
        gear.totals(dl, PW, PH, opts.totals or g, opts.style and 'The look' or (opts.totals_title or 'Totals'));
    end
    -- under the grid: hints
    imgui.SetCursorScreenPos({ x0, y0 + GS + 10 });
    local h = theme.wrapped(dl, x0, y0 + GS + 10, opts.style and 'Click a slot to pick its look. Right-click empties it.'
        or 'Click a slot to pick a piece. Right-click: leave the slot alone. Empty slots keep whatever is on.', GS, u32({ C.muted[1], C.muted[2], C.muted[3], 0.7 }));
    imgui.SetCursorScreenPos({ x0, y0 + math.max(PH, GS + 10 + h) + 8 });
    imgui.Dummy({ W, 1 });
end

-- Editing a lockstyle (the global one or a job's own)
local function style_editor(dl, W, set, title, job_id)
    local x0 = imgui.GetCursorPosX();
    theme.section(title, W);
    local bx = imgui.GetCursorPosX();
    if theme.button('##ns_ls_worn', 'Copy what I\'m wearing', {}) then
        local n = copy_worn(set, bags.STYLE_SLOTS);
        say('Copied ' .. n .. ' pieces into the lockstyle.');
    end
    imgui.SameLine();
    if theme.button('##ns_ls_apply', 'Apply now', { lit = true }) then
        local n = engine.lockstyle(set);
        say(n > 0 and ('Lockstyle set (' .. n .. ' pieces).') or 'None of its pieces are in your bags.', n > 0 and 'ok' or 'warn');
    end
    if imgui.IsItemHovered() then tip('Lock this look now (whatever your job).'); end
    imgui.SameLine();
    if theme.button('##ns_ls_clear', 'Clear', {}) then for s = 0, 8 do set[s] = nil; end store.touch(); end
    imgui.Spacing();
    gear_block(dl, W, set, { style = true, job = job_id });
end

local function issues_list(dl, probs, W)
    if probs == nil or #probs == 0 then
        imgui.TextColored(C.good, 'No problems found.');
        return;
    end
    local lh = imgui.GetTextLineHeight();
    for _, p in ipairs(probs) do
        local x, y = imgui.GetCursorScreenPos();
        local col = p.level == 'err' and C.bad or (p.level == 'warn' and C.warn or C.muted);
        dl:AddCircleFilled({ x + 5, y + lh / 2 }, 3.5, u32(col), 12);
        local h = theme.wrapped(dl, x + 16, y, p.text, W - 20, u32(C.text));
        imgui.Dummy({ W, h + 2 });
        if p.slot ~= nil and imgui.IsItemClicked() then st.slot = p.slot; end
        if p.other ~= nil and imgui.IsItemClicked() then ui.select_set(p.other); end
    end
end

local function set_editor(dl, abbr, s, W, res)
    -- the levels: one button per tier (its level), and + for a new one
    if st.name_for ~= s.id then st.tier = nil; end
    local found = false;
    for _, g in ipairs(tiers.all(s)) do if g == st.tier then found = true; end end
    if not found then
        -- start on the tier worn at your level
        local jl = view_level(abbr);
        st.tier = s.gear;
        for k, t in ipairs(tiers.sorted(s)) do if k == 1 or (jl > 0 and t.level <= jl) then st.tier = t.gear; end end
    end
    if tiers.normalize(s, st.tier) then store.touch(); end
    do
        local list = tiers.sorted(s);
        local jl = view_level(abbr);
        local in_use = nil;
        for k, t in ipairs(list) do if k == 1 or (jl > 0 and t.level <= jl) then in_use = t.gear; end end
        local tx, ty = imgui.GetCursorScreenPos();
        local cx = tx;
        for k, t in ipairs(list) do
            local lbl = t.level > 0 and tostring(t.level) or '-';
            local pw = math.max(theme.pill_w(lbl), 40);
            local c, h = theme.pill('##ns_tier' .. k, lbl, t.gear == st.tier, cx, ty);
            if t.gear == in_use and #list > 1 then dl:AddCircleFilled({ cx + theme.pill_w(lbl) - 6, ty + 5 }, 3, u32(C.gold), 10); end
            if h then
                local from = (k == 1) and 'every level' or ('level ' .. t.level);
                tip((t.level > 0 and ('Level ' .. t.level .. ' gear') or 'An empty level') .. ': worn from ' .. from ..
                    (k == 1 and '' or ', over the lower levels (slots it leaves empty carry on from them)') ..
                    (t.gear == in_use and #list > 1 and ('\nThe one your ' .. abbr .. ' wears now.') or '') ..
                    (t.level == 0 and '\nAdd gear to it: an empty level goes away when you leave it.' or ''));
            end
            if c then st.tier = t.gear; st.slot = nil; if tiers.normalize(s, st.tier) then store.touch(); end end
            cx = cx + theme.pill_w(lbl) + 6;
        end
        local ac, ah = theme.pill('##ns_tier_add', '+', false, cx, ty);
        if ah then tip('Add a level: gear for a higher level. Its level is its highest piece;\nfrom that level it replaces the slots it fills, the rest carry on.'); end
        if ac then st.tier = tiers.add(s); st.slot = nil; store.touch(); end
        imgui.SetCursorScreenPos({ tx, ty + theme.pill_h() + 8 });
        imgui.Dummy({ W, 0 });
    end

    -- the name and the buttons
    if st.name_for ~= s.id then st.name_for = s.id; st.name_buf[1] = s.name or ''; end
    local x0, y0 = imgui.GetCursorScreenPos();
    local btns = { { 'eq', 'Equip now', true }, { 'worn', 'Copy worn', false }, { 'dup', 'Duplicate', false },
                   { 'del', (st.del_armed and st.del_armed.id == s.id and os.clock() - st.del_armed.at < 3) and 'Sure?' or 'Delete', false } };
    local bw = 0;
    for _, b in ipairs(btns) do bw = bw + tw(b[2]) + 24 + 6; end
    local nw = math.max(160, W - bw - 10);
    theme.input('##ns_name', st.name_buf, 40, nw, 'Name this set (Idle, Savage Blade, Cure...)', false);
    local nm = (st.name_buf[1] or '');
    if nm ~= (s.name or '') then s.name = nm; store.touch(); end
    local bx = x0 + nw + 10;
    for _, b in ipairs(btns) do
        imgui.SetCursorScreenPos({ bx, y0 + 2 });
        local c, h = theme.button('##ns_b_' .. b[1], b[2], { lit = b[3], col = (b[1] == 'del' and b[2] == 'Sure?') and C.bad or nil });
        if b[1] == 'eq' then
            if h then tip('Put it on now and hold it there (NeoSwap leaves those slots alone)\nuntil you click the Held chip at the top, or /nswap unlock.'); end
            if c then
                if not usable_now(abbr) then say('This is a ' .. abbr .. ' set; you are ' .. (cur_abbr() or '?') .. '.', 'warn');
                else local n = engine.wear(s, true); say('Wearing "' .. s.name .. '"' .. (n == 0 and ' (already on)' or '') .. '.'); end
            end
        elseif b[1] == 'worn' then
            if h then tip('Fill the set with what you are wearing now (empty slots stay empty in the set).'); end
            if c then local n = copy_worn(st.tier or s.gear); say('Copied ' .. n .. ' pieces you are wearing.'); end
        elseif b[1] == 'dup' then
            if h then tip('Make a copy of this set below it.'); end
            if c then local cp = store.duplicate(abbr, s.id); if cp then ui.select_set(cp.id); end end
        elseif b[1] == 'del' then
            if h then tip('Delete this set (click twice).'); end
            if c then
                if st.del_armed and st.del_armed.id == s.id and os.clock() - st.del_armed.at < 3 then
                    store.remove(abbr, s.id); st.set = nil; st.del_armed = nil;
                    say('Deleted "' .. (s.name or '') .. '".');
                    return;
                else st.del_armed = { id = s.id, at = os.clock() }; end
            end
        end
        bx = bx + tw(b[2]) + 24 + 6;
    end
    imgui.SetCursorScreenPos({ x0, y0 + theme.pill_h() + 14 });

    -- the gear
    local probs = res and res.by_set[s.id] or {};
    local bad = {};
    for _, p in ipairs(probs) do if p.slot ~= nil and p.level ~= 'info' and (p.tier == nil or p.tier == st.tier) then bad[p.slot] = (bad[p.slot] == 'err' or p.level == 'err') and 'err' or 'warn'; end end
    s.gear = s.gear or {};
    local from, tlv = tiers.from_level(s, st.tier);
    local multi = tiers.count(s) > 1;
    gear_block(dl, W, st.tier, { job = jobs.id(abbr), ghost = multi and tiers.inherited(s, st.tier) or nil,
        totals = multi and tiers.effective(s, math.max(tlv, 1)) or nil,
        totals_title = multi and ('Totals at Lv' .. math.max(tlv, 1)) or nil }, bad);

    -- when
    theme.section('Use this set when', W);
    if when.draw(s, abbr, W) then store.touch(); end

    -- checks
    theme.section('Checks', W);
    issues_list(dl, probs, W);
    imgui.Dummy({ W, 10 });
end

----------------------------------------------------------------------------------------------------
-- Import from LuAshitacast
----------------------------------------------------------------------------------------------------
function ui.open_import(abbr)
    if st.import then st.import = nil; return; end
    local files = import.list_files();
    local pick = nil;
    for i, f in ipairs(files) do if f.job == abbr then pick = i; end end
    local lv = jobs.level(jobs.id(abbr) or 0);
    st.import = { files = files, pick = pick, level = lv > 0 and lv or 75, res = nil, replace = false, job = abbr };
    st.set, st.slot, st.style = nil, nil, false;
end

function ui.import_page(dl, abbr, W)
    local im = st.import;
    local lh = imgui.GetTextLineHeight();
    theme.section('Import from LuAshitacast', W);
    local function hint(text)
        local x, y = imgui.GetCursorScreenPos();
        local h = theme.wrapped(dl, x, y, text, W, u32({ C.muted[1], C.muted[2], C.muted[3], 0.85 }));
        imgui.Dummy({ W, h + 2 });
    end
    hint('NeoSwap runs the profile (without letting it touch the game) and notes what it puts on when idle, engaged, resting, ' ..
         'with a pet out, moving, for each weapon skill, ability, spell and pet move it knows, and for ranged attacks. ' ..
         'Those become sets. Its other named sets come too, unticked, as Manual sets. Tick what you want, then Import.');

    -- the files
    if #im.files == 0 then
        imgui.TextColored(C.warn, 'No profiles found for this character.');
        hint('LuAshitacast keeps them in ' .. string.format('%sconfig\\addons\\luashitacast\\<Name>_<id>\\JOB.lua', AshitaCore:GetInstallPath()));
        return;
    end
    local x0 = imgui.GetCursorPosX();
    local sx, sy = imgui.GetCursorScreenPos();
    dl:AddText({ sx, sy + (theme.pill_h() - lh) / 2 }, u32(C.text), 'Profile');
    local cx, cy = sx + 90, sy;
    local rowx = cx;
    for i, f in ipairs(im.files) do
        local pw = theme.pill_w(f.job);
        if cx + pw > sx + W and cx > rowx then cx = rowx; cy = cy + theme.pill_h() + 5; end
        local c, h = theme.pill('##ns_imf' .. i, f.job, im.pick == i, cx, cy);
        if h then tip(f.file .. (f.job == abbr and '' or ('\nGoes into ' .. f.job .. '\'s sets'))); end
        if c then im.pick = i; im.res = nil; im.job = f.job; local lv = jobs.level(jobs.id(f.job) or 0); im.level = lv > 0 and lv or 75; end
        cx = cx + pw + 5;
    end
    imgui.SetCursorScreenPos({ sx, cy + theme.pill_h() + 8 });
    imgui.Dummy({ W, 0 });
    if im.pick == nil then hint('Pick a profile.'); return; end
    local f = im.files[im.pick];

    -- the level, and read
    imgui.SetCursorPosX(x0);
    local ly = select(2, imgui.GetCursorScreenPos());
    local _, dh = theme.digits_size(99);
    dl:AddText({ sx, ly + (dh - lh) / 2 }, u32(C.text), 'Up to level');
    imgui.SetCursorScreenPos({ sx + 90, ly });
    local v, ch = theme.digits('ns_im_lv', im.level, 1, 99);
    if ch then im.level = v; im.res = nil; end
    if imgui.IsItemHovered() then tip('Profiles that change gear by level are read at every level they change at, up to this one,\nand each set gets those levels (the buttons above a set\'s name).'); end
    imgui.SetCursorScreenPos({ sx + 90 + select(1, theme.digits_size(99)) + 14, ly + (dh - theme.pill_h()) / 2 });
    local rc, rh = theme.button('##ns_im_read', im.res and 'Read it again' or 'Read ' .. f.job .. '.lua', { lit = im.res == nil });
    if rh then tip(f.file); end
    if rc then
        local sub = jobs.ABBR[jobs.sub()];
        local subl = jobs.sub_level();
        if f.job ~= cur_abbr() or sub == nil then sub, subl = 'WHM', math.floor(im.level / 2); end
        local ok, r = pcall(import.read, f.path, f.job, im.level, sub, subl);
        if ok then im.res = r; else im.res = { sets = {}, macro = {}, notes = {}, errors = { tostring(r) } }; end
    end
    imgui.SetCursorScreenPos({ sx, ly + dh + 8 });
    imgui.Dummy({ W, 0 });

    local r = im.res;
    if r == nil then return; end
    for _, e in ipairs(r.errors or {}) do imgui.TextColored(C.bad, theme.safe(e)); end
    if r.levels and #r.levels > 1 then
        local hx, hy = imgui.GetCursorScreenPos();
        local hh = theme.wrapped(dl, hx, hy, 'Read at ' .. #r.levels .. ' levels (' .. table.concat(r.levels, ', ') .. '): the gear each set changes at a level becomes one of its levels.', W, u32(C.acc));
        imgui.Dummy({ W, hh + 2 });
    end
    if #(r.notes or {}) > 0 then
        imgui.TextColored(C.muted, #r.notes .. ' part' .. (#r.notes == 1 and '' or 's') .. ' of the profile stopped with an error (hover to see).');
        if imgui.IsItemHovered() then tip(table.concat(r.notes, '\n')); end
    end
    if #(r.sets or {}) == 0 then
        if #(r.errors or {}) == 0 then imgui.TextColored(C.warn, 'Nothing was put on in any situation.'); end
        return;
    end

    -- what comes with the sets
    theme.section('Found', W);
    local function tick(id, label, on, hint_)
        local c, h = theme.checkbox(id, label, on);
        if h and hint_ then tip(hint_); end
        return c;
    end
    if r.macro and r.macro.book then
        if tick('##ns_im_mac', string.format('Macros: book %d%s', r.macro.book, r.macro.page and (', page ' .. r.macro.page) or ''), r.use_macro,
            'Its OnLoad changes to this macro book; NeoSwap does it when you change to ' .. f.job .. '.') then r.use_macro = not r.use_macro; end
    end
    if r.lockstyle then
        local n = 0;
        for _ in pairs(r.lockstyle) do n = n + 1; end
        if tick('##ns_im_ls', string.format('Lockstyle: its Lockstyle set (%d pieces) as %s\'s own', n, f.job), r.use_lockstyle) then r.use_lockstyle = not r.use_lockstyle; end
    end
    if r.lockstyleset then imgui.TextColored(C.muted, 'It also uses the game\'s lockstyle set ' .. r.lockstyleset .. ' (not brought in).'); end
    local nsel = 0;
    for _, s in ipairs(r.sets) do if s.pick then nsel = nsel + 1; end end
    imgui.Spacing();
    local p = theme.segmented('##ns_im_mode', { { false, 'Add to ' .. f.job .. '\'s sets' }, { true, 'Replace ' .. f.job .. '\'s sets' } }, im.replace);
    if p ~= nil then im.replace = p; end
    imgui.SameLine();
    if theme.button('##ns_im_all', 'Tick all', {}) then for _, s in ipairs(r.sets) do if next(s.gear) then s.pick = true; end end end
    imgui.SameLine();
    if theme.button('##ns_im_none', 'None', {}) then for _, s in ipairs(r.sets) do s.pick = false; end end
    imgui.SameLine();
    local go, goh = theme.button('##ns_im_go', 'Import ' .. nsel .. ' set' .. (nsel == 1 and '' or 's'), { lit = true, disabled = nsel == 0 and not r.use_macro and not r.use_lockstyle });
    if goh then tip(im.replace and (f.job .. '\'s sets now are deleted first.') or 'Added after the sets ' .. f.job .. ' has.'); end
    if go then
        local n = import.apply(r, f.job, im.replace);
        local job = f.job;
        st.import = nil;
        ui.select_job(job);
        say(string.format('Imported %d set%s into %s from %s.', n, n == 1 and '' or 's', job, f.file));
        return;
    end
    imgui.Spacing();

    -- the sets
    local KO = {};
    for i, k in ipairs(rules.KINDS) do KO[k.key] = i; end
    for i, s in ipairs(r.sets) do
        local x, y = imgui.GetCursorScreenPos();
        local h = lh * 2 + 12;
        local c = imgui.InvisibleButton('##ns_im_row' .. i, { W, h });
        local hov = imgui.IsItemHovered();
        local has = next(s.gear) ~= nil;
        dl:AddRectFilled({ x, y }, { x + W, y + h }, u32(s.pick and { NEON[1] * 0.22, NEON[2] * 0.22, NEON[3] * 0.22, 0.9 } or (hov and { 0.13, 0.12, 0.17, 1 } or { 0.075, 0.070, 0.100, 0.8 })), 7);
        local bs = lh;
        local bxx, byy = x + 10, y + (h - bs) / 2;
        dl:AddRectFilled({ bxx, byy }, { bxx + bs, byy + bs }, u32(s.pick and { NEON[1] * 0.42, NEON[2] * 0.42, NEON[3] * 0.42, 1 } or { 0.10, 0.09, 0.13, 1 }), 4);
        dl:AddRect({ bxx, byy }, { bxx + bs, byy + bs }, u32(s.pick and { NEON2[1], NEON2[2], NEON2[3], 0.9 } or { 1, 1, 1, 0.15 }), 4, C.rall, 1);
        if s.pick then
            dl:AddLine({ bxx + bs * 0.22, byy + bs * 0.52 }, { bxx + bs * 0.42, byy + bs * 0.72 }, u32({ 1, 1, 1, 1 }), 2);
            dl:AddLine({ bxx + bs * 0.42, byy + bs * 0.72 }, { bxx + bs * 0.78, byy + bs * 0.28 }, u32({ 1, 1, 1, 1 }), 2);
        end
        local n = 0;
        for _ in pairs(s.gear) do n = n + 1; end
        local right = n .. ' piece' .. (n == 1 and '' or 's');
        local nlv = 1 + #(s.more or {});
        if nlv > 1 then right = right .. ', ' .. nlv .. ' levels'; end
        local miss = #(s.missing or {});
        if miss > 0 then right = right .. ', ' .. miss .. ' not found'; end
        dl:AddText({ x + W - tw(right) - 10, y + 6 }, u32(miss > 0 and C.warn or C.muted), right);
        dl:AddText({ x + 18 + bs, y + 6 }, u32(has and C.text or C.muted), theme.fit(s.name, W - tw(right) - 50 - bs));
        local conds = {};
        for _, cnd in ipairs(s.when.cond or {}) do conds[#conds + 1] = rules.cond_text(cnd); end
        local line = rules.trigger_text(s.when) .. (#conds > 0 and ('  -  ' .. table.concat(conds, ', ')) or '') .. (s.from == 'set' and '  (a named set the profile didn\'t wear)' or '');
        dl:AddText({ x + 18 + bs, y + 8 + lh }, u32({ C.acc[1], C.acc[2], C.acc[3], 0.85 }), theme.fit(line, W - 40 - bs));
        if hov then
            local t = {};
            for sl = 0, 15 do
                local g = s.gear[sl];
                if g then t[#t + 1] = bags.SLOT_NAME[sl] .. ': ' .. (g.remove and '(taken off)' or g.name); end
            end
            for ti, mg in ipairs(s.more or {}) do
                local lvn = tiers.level(mg);
                local parts = {};
                for sl = 0, 15 do local g = mg[sl]; if g then parts[#parts + 1] = bags.SLOT_NAME[sl] .. ': ' .. (g.remove and '(off)' or g.name); end end
                t[#t + 1] = 'Lv' .. lvn .. ' - ' .. table.concat(parts, ', ');
            end
            for _, m in ipairs(s.missing or {}) do t[#t + 1] = m .. '   - no item by that name'; end
            tip((#t > 0 and table.concat(t, '\n') or 'No gear') .. '\n\nClick to tick or untick');
        end
        if c and has then s.pick = not s.pick; end
        imgui.SetCursorScreenPos({ x, y + h + 4 });
    end
    imgui.Dummy({ W, 8 });
end

local function editor(dl, abbr, W, H)
    local pv = theme.begin_list('##ns_editor', W, H);
    local edl = imgui.GetWindowDrawList();
    imgui.Indent(6);                                                  -- (room for the selection ring at the left edge)
    imgui.Dummy({ 1, 4 });
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 8, 6 });
    local ok, err = pcall(function()
        local AW = W - 20;
        if st.import then
            ui.import_page(edl, abbr, AW);
        elseif st.tab == 'cmds' and not st.style then
            local c = st.cmd and commands.find(abbr, st.cmd) or nil;
            if c then cview.editor(edl, abbr, c, AW);
            else
                imgui.Dummy({ 4, 30 });
                local x, y = imgui.GetCursorScreenPos();
                local h = theme.wrapped(edl, x, y, 'Pick a command on the left, or make one with "+ New command". ' ..
                    'A command is a list of steps NeoSwap runs for you - cast a spell, use an ability, wait for your pet, ' ..
                    'wear a set and hold it, send any command - started with its own slash word (/siphon) or /nswap run <name>. ' ..
                    'For Summoner there is a ready-made Elemental Siphon: it calls the spirit for the weather or the day, wears your Siphon set, siphons, and releases it.',
                    AW, u32(C.muted));
                imgui.Dummy({ AW, h });
            end
        elseif st.style then
            local j = store.job(abbr, true);
            j.lockstyle.set = j.lockstyle.set or {};
            style_editor(edl, AW, j.lockstyle.set, abbr .. ' lockstyle', jobs.id(abbr));
        else
            local s = st.set and store.find(abbr, st.set) or nil;
            if s == nil then
                imgui.Dummy({ 4, 30 });
                local x, y = imgui.GetCursorScreenPos();
                local lines = {
                    'Pick a set on the left to edit it, or make one with "+ New set".',
                    '',
                    'How it works: every set is worn at one moment - Idle, Engaged, Resting, a weapon skill, an',
                    'ability, a spell\'s precast or midcast, a ranged attack, an item, your pet\'s move - and only when',
                    'its conditions are true. Sets that fit the same moment go on one over the other: the broad ones',
                    'first, then the narrow ones (every spell, then a magic skill, then named spells), so each set',
                    'only needs the slots it changes.',
                };
                for i, l in ipairs(lines) do edl:AddText({ x, y + (i - 1) * (imgui.GetTextLineHeight() + 3) }, u32(i == 1 and C.text or C.muted), l); end
                imgui.Dummy({ AW, #lines * (imgui.GetTextLineHeight() + 3) });
            else
                set_editor(edl, abbr, s, AW, check.job(abbr, store.sets(abbr)));
            end
        end
    end);
    if not ok then imgui.TextColored(C.bad, 'Editor error: ' .. tostring(err)); end
    imgui.PopStyleVar(1);
    imgui.Unindent(6);
    theme.end_list(pv);
end

----------------------------------------------------------------------------------------------------
-- Global: the shared lockstyle, and your modes
----------------------------------------------------------------------------------------------------
local function global_page(dl, W, H)
    local pv = theme.begin_list('##ns_global', W, H);
    local gdl = imgui.GetWindowDrawList();
    imgui.Indent(6);
    imgui.Dummy({ 1, 4 });
    local LW = math.min(W - 306, 680);
    local x0, y0 = imgui.GetCursorScreenPos();
    imgui.BeginGroup();
    store.data.lockstyle = store.data.lockstyle or {};
    style_editor(gdl, LW, store.data.lockstyle, 'Global lockstyle', nil);
    local used = {};
    for _, a in ipairs(jobs.ABBR) do
        local j = store.job(a);
        if j and j.lockstyle and j.lockstyle.mode == 'global' and #j.sets > 0 then used[#used + 1] = a; end
    end
    local h = theme.wrapped(gdl, imgui.GetCursorScreenPos(), select(2, imgui.GetCursorScreenPos()),
        'Every job whose Lockstyle is "Global" uses this look' .. (#used > 0 and (' (' .. table.concat(used, ', ') .. ')') or '') ..
        '. Pick Own on a job to give it its own look, or Off for none.', LW, u32(C.muted));
    imgui.Dummy({ LW, h });
    imgui.EndGroup();

    -- modes
    local MX = x0 + LW + 24;
    local MW = W - LW - 40;
    imgui.SetCursorScreenPos({ MX, y0 });
    imgui.BeginGroup();
    theme.section('Modes', MW);
    local mh = theme.wrapped(gdl, MX, select(2, imgui.GetCursorScreenPos()),
        'Your own switches. A set with the condition "Mode is on: PDT" is only worn while PDT is on. ' ..
        'Switch them here, on a job\'s page, or with /nswap mode PDT (on / off / toggle) - in a macro, say.', MW, u32(C.muted));
    imgui.Dummy({ MW, mh + 4 });
    local names = {};
    for m in pairs(store.data.modes) do names[#names + 1] = m; end
    for _, a in ipairs(jobs.ABBR) do for _, m in ipairs(modes_used(a)) do if store.data.modes[m:lower()] == nil then store.data.modes[m:lower()] = false; names[#names + 1] = m:lower(); end end end
    table.sort(names);
    local del = nil;
    for i, m in ipairs(names) do
        local x, y = imgui.GetCursorScreenPos();
        imgui.AlignTextToFramePadding();
        imgui.TextColored(C.text, m);
        imgui.SetCursorScreenPos({ x + MW - 52 - 30, y });
        if theme.switch('##ns_md' .. i, store.mode(m)) then store.set_mode(m, not store.mode(m)); end
        local xc, xh = theme.icon_button('##ns_mdx' .. i, x + MW - 22, y + 4, 'close', 18);
        if xh then tip('Forget this mode (sets that use it keep their condition)'); end
        if xc then del = m; end
        imgui.SetCursorScreenPos({ x, y + 30 });
        imgui.Dummy({ 1, 1 });
    end
    if del then store.data.modes[del] = nil; store.touch(); end
    if #names == 0 then imgui.TextColored({ C.muted[1], C.muted[2], C.muted[3], 0.7 }, 'No modes yet.'); end
    imgui.Spacing();
    local ax, ay = imgui.GetCursorScreenPos();
    theme.input('##ns_mode_new', st.mode_buf, 24, MW - 80, 'New mode (PDT, TH, Nuke...)', false);
    imgui.SetCursorScreenPos({ ax + MW - 72, ay + 2 });
    local nm = (st.mode_buf[1] or ''):gsub('^%s+', ''):gsub('%s+$', '');
    if theme.button('##ns_mode_add', 'Add', { w = 72, lit = nm ~= '', disabled = nm == '' }) then
        store.data.modes[nm:lower()] = false; store.touch(); st.mode_buf[1] = '';
    end
    imgui.EndGroup();
    imgui.Unindent(6);
    theme.end_list(pv);
end

----------------------------------------------------------------------------------------------------
-- The status line
----------------------------------------------------------------------------------------------------
local function status_line(dl, W)
    local lh = imgui.GetTextLineHeight();
    local x, y = imgui.GetCursorScreenPos();
    local right = '';
    if store.owner then right = store.owner.name .. '  -  ' .. (store.dirty_at and 'saving...' or 'saved'); end
    local rw = tw(right);
    dl:AddText({ x + W - rw, y }, u32({ C.muted[1], C.muted[2], C.muted[3], 0.7 }), right);
    local avail = W - rw - 24;
    local msg, kind = status.get();
    if not msg and pad.listen == nil and pad.enabled() and nav.shown() then
        dl:AddText({ x, y }, u32({ C.muted[1], C.muted[2], C.muted[3], 0.75 }), theme.fit(ui.pad_hint(), avail));
        imgui.SetCursorScreenPos({ x, y });
        imgui.Dummy({ W, lh });
        return;
    end
    if msg then
        local col = STATUS_COL[kind] or C.text;
        dl:AddCircleFilled({ x + 4, y + lh / 2 }, 3, u32(col), 12);
        dl:AddText({ x + 12, y }, u32(col), theme.fit(msg, avail));
    elseif engine.last then
        local l = engine.last;
        local ago = os.clock() - l.at;
        local what = ({ default = 'Now', precast = 'Precast', midcast = 'Midcast', ws = 'Weapon skill', ja = 'Ability',
                        preshot = 'Preshot', midshot = 'Midshot', item = 'Item', manual = 'Equipped' })[l.event] or l.event;
        local t = string.format('%s%s: %s   (%ds ago)', what, l.action and (' ' .. l.action) or '', table.concat(l.sets or {}, ' + '), math.floor(ago));
        dl:AddCircleFilled({ x + 4, y + lh / 2 }, 3, u32(C.acc), 12);
        dl:AddText({ x + 12, y }, u32({ C.muted[1], C.muted[2], C.muted[3], 0.9 }), theme.fit(t, avail));
    end
    imgui.SetCursorScreenPos({ x, y });
    imgui.Dummy({ W, lh });
end

----------------------------------------------------------------------------------------------------
-- The controller (as NeoMOG): jobs > sets / commands > the equipment slots > a slot's gear
----------------------------------------------------------------------------------------------------
local function rail_keys()
    local t = { 'global' };
    for _, a in ipairs(jobs.ABBR) do t[#t + 1] = a; end
    for _, e in ipairs(store.entries()) do t[#t + 1] = e.key; end
    return t;
end

function ui.pad_hint()
    local z = nav.zone;
    if z == 'list' then
        return st.tab == 'cmds' and 'Up / down: command   Confirm: open   Second: Run   Left: jobs   LB / RB: Sets / Commands'
            or 'Up / down: set   Confirm: open it   Second: Equip now   Left: jobs   Right: its slots   LB / RB: Sets / Commands';
    elseif z == 'grid' then return 'D-pad: slot   Confirm: its gear   Second: empty the slot   Back: the sets';
    elseif z == 'picker' then return 'Up / down: piece   Confirm: put it in the slot   Back: the slots'; end
    return 'Up / down: job   Right / Confirm: its sets   LB / RB: Sets / Commands   Back: minimize';
end

local function to_list_zone()
    nav.zone = (st.job == 'global') and 'rail' or 'list';
    nav.moved = true;
end

function ui.on_action(a)
    if not store.ready() then return; end
    local z = nav.zone;
    if z == 'picker' and st.slot == nil then z = 'grid'; nav.zone = 'grid'; end
    if a == 'tab_prev' or a == 'tab_next' then
        if st.job == 'global' then return; end
        st.tab = (a == 'tab_prev') and 'sets' or 'cmds';
        st.import, st.style, st.slot = nil, false, nil;
        if z ~= 'rail' then nav.zone = 'list'; end
        nav.row, nav.moved = 1, true;
        return;
    end

    if z == 'rail' then
        local RAIL_KEYS = rail_keys();
        local i = 1;
        for k, key in ipairs(RAIL_KEYS) do if key == st.job then i = k; end end
        if a == 'up' or a == 'down' then
            i = math.max(1, math.min(#RAIL_KEYS, i + (a == 'up' and -1 or 1)));
            ui.select_job(RAIL_KEYS[i]);
            nav.moved = true;
        elseif a == 'right' or a == 'ok' then
            if st.job == 'global' then nav.zone = 'grid'; nav.eq = 1;
            else nav.zone = 'list'; nav.row = 1; nav.moved = true; end
        elseif a == 'back' then
            config.set('minimized', true);
        end
        return;
    end

    if z == 'list' then
        local n = #st.vis;
        local id = st.vis[nav.row];
        if a == 'up' then nav.row = math.max(1, nav.row - 1); nav.moved = true;
        elseif a == 'down' then nav.row = math.max(1, math.min(n, nav.row + 1)); nav.moved = true;
        elseif a == 'left' or a == 'back' then nav.zone = 'rail'; nav.moved = true;
        elseif a == 'ok' and id then
            if st.tab == 'cmds' then cview.on_pick(id);
            else ui.select_set(id); nav.zone = 'grid'; nav.eq = 1; end
        elseif a == 'right' then
            if st.tab == 'sets' and (st.set ~= nil or st.style) then nav.zone = 'grid'; nav.eq = nav.eq or 1; end
        elseif a == 'alt' and id then
            if st.tab == 'cmds' then
                local c = commands.find(st.job, id);
                if c and usable_now(st.job) then commands.start(st.job, c);
                elseif c then say('This is a ' .. st.job .. ' command; change to ' .. st.job .. ' to run it.', 'warn'); end
            else
                local set = store.find(st.job, id);
                if set and usable_now(st.job) then engine.wear(set, true); say('Wearing "' .. set.name .. '". /nswap unlock lets go of it.');
                elseif set then say('This is a ' .. st.job .. ' set; you are ' .. (cur_abbr() or '?') .. '.', 'warn'); end
            end
        end
        return;
    end

    if z == 'grid' then
        local i = nav.eq or 1;
        local col, row = (i - 1) % 4, math.floor((i - 1) / 4);
        local s = bags.SLOT_GRID[i];
        if a == 'left' then
            if col > 0 then nav.eq = i - 1; else to_list_zone(); st.slot = nil; end
        elseif a == 'right' then if col < 3 then nav.eq = i + 1; end
        elseif a == 'up' then if row > 0 then nav.eq = i - 4; end
        elseif a == 'down' then if row < 3 then nav.eq = i + 4; end
        elseif a == 'back' then to_list_zone(); st.slot = nil;
        elseif a == 'ok' and st.cur_gear then
            if st.cur_style and not bags.STYLE_SLOTS[s] then return; end
            st.slot = s;
            gear.reset_search();
            nav.zone, nav.prow, nav.moved = 'picker', 1, true;
        elseif a == 'alt' and st.cur_gear then
            if st.cur_style and not bags.STYLE_SLOTS[s] then return; end
            st.cur_gear[s] = nil;
            store.touch();
        end
        return;
    end

    if z == 'picker' then
        local n = gear.picker_count or 0;
        if a == 'up' then nav.prow = math.max(1, nav.prow - 1); nav.moved = true;
        elseif a == 'down' then nav.prow = math.max(1, math.min(n, nav.prow + 1)); nav.moved = true;
        elseif a == 'ok' then nav.pick = true;
        elseif a == 'back' or a == 'left' then st.slot = nil; nav.zone = 'grid';
        elseif a == 'alt' and st.cur_gear then st.cur_gear[st.slot] = nil; store.touch(); end
        return;
    end
end

----------------------------------------------------------------------------------------------------
-- The window
----------------------------------------------------------------------------------------------------
local function draw_body(dl)
    local W = math.floor(theme.avail());
    local hit = title_row(dl, W);
    imgui.Dummy({ W, 2 });
    local _, ay = theme.avail();
    local lh = imgui.GetTextLineHeight();
    local body_h = ay - lh - 10;
    local x0, y0 = imgui.GetCursorScreenPos();
    if st.job == nil then st.job = cur_abbr() or 'global'; end
    rail(dl, body_h);
    local cx = x0 + RAIL_W + 14;
    local CW = W - RAIL_W - 14;
    imgui.SetCursorScreenPos({ cx, y0 });
    if not store.ready() then
        imgui.TextColored(C.muted, 'Waiting for your character...');
    elseif st.job == 'global' then
        global_page(dl, CW, body_h);
    else
        job_column(dl, st.job, SETS_W, body_h);
        imgui.SetCursorScreenPos({ cx + SETS_W + 14, y0 });
        editor(dl, st.job, CW - SETS_W - 14, body_h);
    end
    imgui.SetCursorScreenPos({ x0, y0 + body_h + 8 });
    status_line(dl, W);
    return hit;
end

-- your job changed: the rail follows
function ui.on_job_change(j)
    if config.get('follow_job') and jobs.ABBR[j] and st.job ~= 'global' then ui.select_job(jobs.ABBR[j]); end
end

----------------------------------------------------------------------------------------------------
-- Minimized: a small round NSWP bubble (click: open, drag: move)
----------------------------------------------------------------------------------------------------
local BUB = 62;
local bub_drag = nil;

local function mouse_pos()
    local mx, my = imgui.GetMousePos();
    if type(mx) == 'table' then mx, my = mx.x or mx[1], mx.y or mx[2]; end
    return mx or 0, my or 0;
end

local function draw_bubble()
    local cfg = config.raw();
    local pad_ = 10;
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0);
    imgui.PushStyleColor(ImGuiCol_WindowBg, { 0, 0, 0, 0 });
    imgui.SetNextWindowPos({ tonumber(cfg.mini_x) or 60, tonumber(cfg.mini_y) or 360 }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ BUB + pad_ * 2, BUB + pad_ * 2 }, ImGuiCond_Always);
    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_NoScrollWithMouse, ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoBackground or 0);
    if imgui.Begin('##neoswap_mini', { true }, flags) then
        local dl = imgui.GetWindowDrawList();
        local wx, wy = imgui.GetWindowPos();
        if type(wx) == 'table' then wx, wy = wx.x or wx[1], wx.y or wx[2]; end
        local cx, cy, R = wx + pad_ + BUB / 2, wy + pad_ + BUB / 2, BUB / 2;
        imgui.SetCursorScreenPos({ cx - R, cy - R });
        imgui.InvisibleButton('##ns_mini_btn', { BUB, BUB });
        local hov = imgui.IsItemHovered();
        local mx, my = mouse_pos();
        if imgui.IsItemActivated() then
            bub_drag = { mx = mx, my = my, x = tonumber(cfg.mini_x) or 60, y = tonumber(cfg.mini_y) or 360, moved = false };
        end
        if bub_drag and imgui.IsItemActive() then
            local dx, dy = mx - bub_drag.mx, my - bub_drag.my;
            if math.abs(dx) + math.abs(dy) > 4 then bub_drag.moved = true; end
            if bub_drag.moved then cfg.mini_x, cfg.mini_y = bub_drag.x + dx, bub_drag.y + dy; end
        end
        if imgui.IsItemDeactivated() and bub_drag then
            if bub_drag.moved then config.save(); else config.set('minimized', false); end
            bub_drag = nil;
        end
        local now = os.clock();
        local pulse = 0.5 + 0.5 * math.sin(now * 2.2);
        for k = 3, 1, -1 do
            dl:AddCircle({ cx, cy }, R + k * 2.5, u32({ NEON[1], NEON[2], NEON[3], (0.05 + 0.04 * pulse) * (hov and 1.8 or 1) }), 40, 3);
        end
        dl:AddCircleFilled({ cx, cy }, R, u32({ C.pbg[1], C.pbg[2], C.pbg[3], 0.94 }), 48);
        dl:AddCircleFilled({ cx, cy - R * 0.35 }, R * 0.62, u32({ 1, 1, 1, 0.025 }), 40);
        dl:AddCircle({ cx, cy }, R, u32({ NEON2[1], NEON2[2], NEON2[3], hov and 1 or 0.75 }), 48, hov and 2.2 or 1.6);
        local a0 = now * 1.6;
        local segs = 14;
        for k = 0, segs - 1 do
            local f = k / segs;
            local b0, b1 = a0 + f * 1.4, a0 + (k + 1) / segs * 1.4;
            local col = { C.hp[1] + (C.mp2[1] - C.hp[1]) * f, C.hp[2] + (C.mp2[2] - C.hp[2]) * f, C.hp[3] + (C.mp2[3] - C.hp[3]) * f, 0.9 * (1 - f) };
            dl:AddLine({ cx + math.cos(b0) * (R - 3), cy + math.sin(b0) * (R - 3) }, { cx + math.cos(b1) * (R - 3), cy + math.sin(b1) * (R - 3) }, u32(col), 2);
        end
        local scale = 1.15;
        local tw_, th_ = theme.title_size('NSWP', scale);
        theme.title(dl, cx - tw_ / 2, cy - th_ / 2, 'NSWP', 1, scale);
        -- swapping: a green dot; off: none
        if engine.active() then dl:AddCircleFilled({ cx + R * 0.70, cy - R * 0.70 }, 4, u32(C.good), 12); end
        if hov and not (bub_drag and bub_drag.moved) then
            local l = engine.last;
            tip('NeoSwap\nClick: open   Drag: move' .. (l and ('\nLast: ' .. table.concat(l.sets or {}, ' + ')) or ''));
        end
    end
    imgui.End();
    imgui.PopStyleColor(1);
    imgui.PopStyleVar(2);
end

function ui.draw()
    if not config.get('show_gui') then return; end
    if config.get('minimized') then draw_bubble(); return; end
    local op = math.max(0.2, math.min(1, tonumber(config.get('opacity')) or 1));
    local fade = config.get('fade_text') == true;
    local nc, nv = theme.push(fade and 1 or op, fade and op or nil, { 14, 12 });
    imgui.SetNextWindowPos({ tonumber(config.get('win_x')) or 140, tonumber(config.get('win_y')) or 110 }, ImGuiCond_FirstUseEver);
    imgui.SetNextWindowSize({ tonumber(config.get('win_w')) or 1180, tonumber(config.get('win_h')) or 740 }, ImGuiCond_FirstUseEver);
    imgui.SetNextWindowSizeConstraints({ 980, 560 }, { 2400, 1600 });
    local hit = nil;
    if imgui.Begin('NeoSwap##neoswap_main', { true }, theme.WIN_FLAGS_RESIZE) then
        local dl = imgui.GetWindowDrawList();
        local ok, res = pcall(draw_body, dl);
        if ok then hit = res; else
            imgui.TextColored(C.bad, 'NeoSwap error (see chat log)');
            if not ui._err_shown then ui._err_shown = true; print('[NeoSwap] draw error: ' .. tostring(res)); end
        end
        theme.remember_pos('win_x', 'win_y');
        local ww, wh = imgui.GetWindowSize();
        if type(ww) == 'table' then ww, wh = ww.x or ww[1], ww.y or ww[2]; end
        local cfg = config.raw();
        if type(ww) == 'number' and (math.abs(ww - (tonumber(cfg.win_w) or 0)) > 0.5 or math.abs(wh - (tonumber(cfg.win_h) or 0)) > 0.5) then
            cfg.win_w, cfg.win_h = ww, wh;
            if not imgui.IsMouseDown(0) then config.save(); end
        end
    end
    imgui.End();
    theme.pop(nc, nv);

    if hit == 'close' then config.set('show_gui', false);
    elseif hit == 'min' then config.set('minimized', true);
    elseif hit == 'gear' then config.toggle('show_config_gui'); end
end

return ui;
