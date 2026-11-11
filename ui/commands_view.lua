-- commands_view.lua : the job's own commands (core/commands.lua): the list in the middle column, and the editor
-- on the right - name, slash word, Run, and the steps.
local imgui    = require('imgui');
local theme    = require('ui.theme');
local when     = require('ui.when');
local store    = require('core.store');
local rules    = require('core.rules');
local game     = require('core.game');
local commands = require('core.commands');
local status   = require('core.status');
local C, u32, tip, tw = theme.C, theme.u32, theme.tip, theme.tw;
local NEON, NEON2 = theme.NEON, theme.NEON2;
local nav = require('ui.nav');
local config = require('configs.config');

local view = { sel = nil, del_armed = nil, name_for = nil, name_buf = { '' }, alias_buf = { '' }, label_buf = { '' } };
local buttons = nil;   -- ui.buttons (required on first use)
local icon_pick = require('ui.icon_pick');
local BUTTON_ICONS = require('data.button_icons');

local function say(msg, kind) status.set(msg, kind or 'ok', 5); end

----------------------------------------------------------------------------------------------------
-- The list (middle column)
----------------------------------------------------------------------------------------------------
local function new_menu(abbr, on_pick)
    local pv = when.popup_style();
    if imgui.BeginPopup('##ns_cmd_new_pop') then
        if imgui.Selectable('  An empty command##ns_cn_empty', false, 0, { 260, 0 }) then
            local c = commands.new(abbr, { name = 'New command', alias = '', steps = {} });
            on_pick(c.id);
        end
        local any = false;
        for i, t in ipairs(commands.TEMPLATES) do
            if t.job == abbr then
                if not any then imgui.Separator(); any = true; end
                if imgui.Selectable('  ' .. t.name .. '  (' .. t.alias .. ')##ns_cn_t' .. i, false, 0, { 260, 0 }) then
                    local c = commands.new(abbr, { name = t.name, alias = t.alias, steps = t.steps });
                    on_pick(c.id);
                end
                if imgui.IsItemHovered() then tip(t.hint); end
            end
        end
        local others = false;
        for i, t in ipairs(commands.TEMPLATES) do
            if t.job ~= abbr then
                if not others then imgui.Separator(); others = true; end
                if imgui.Selectable('  ' .. t.name .. '  (' .. t.job .. ')##ns_cn_o' .. i, false, 0, { 260, 0 }) then
                    local c = commands.new(abbr, { name = t.name, alias = t.alias, steps = t.steps });
                    on_pick(c.id);
                end
                if imgui.IsItemHovered() then tip(t.hint .. '\n(made for ' .. t.job .. ')'); end
            end
        end
        imgui.EndPopup();
    end
    when.popup_pop(pv);
end

-- The cards. sel: the picked command id. Returns the id clicked (or nil).
function view.list(dl, abbr, W, H, sel, on_pick, nav_row)
    view.order = {};
    local lh = imgui.GetTextLineHeight();
    local x0, y0 = imgui.GetCursorScreenPos();
    local bw = theme.pill_w('+ New command');
    local _, sy = theme.section('Commands', W, bw);
    imgui.SetCursorScreenPos({ x0 + W - bw, sy - 3 });
    local nc, nh = theme.pill('##ns_cmd_new', '+ New command', true);
    if nh then tip('Make a command: an empty one, or a ready-made one (Elemental Siphon...)'); end
    if nc then imgui.OpenPopup('##ns_cmd_new_pop'); end
    new_menu(abbr, on_pick);
    imgui.SetCursorScreenPos({ x0, sy + lh + 6 });
    local _, ly = imgui.GetCursorScreenPos();
    local pv = theme.begin_list('##ns_cmds', W, y0 + H - ly);
    local ldl = imgui.GetWindowDrawList();
    imgui.Indent(6);
    imgui.Dummy({ 1, 4 });
    local list = commands.list(abbr);
    local running, ri = commands.running();
    if #list == 0 then
        imgui.Dummy({ 4, 6 });
        local x, y = imgui.GetCursorScreenPos();
        local h = theme.wrapped(ldl, x, y, 'No ' .. abbr .. ' commands yet. A command is a list of steps NeoSwap runs for you - ' ..
            'cast, use an ability, wait for your pet, wear a set... - started with its own slash word. "+ New command" has ready-made ones.',
            W - 10, u32(C.muted));
        imgui.Dummy({ W - 10, h });
    end
    for _, c in ipairs(list) do
        local x, y = imgui.GetCursorScreenPos();
        local h = lh * 2 + 18;
        local cw = W - 20;
        local clk = imgui.InvisibleButton('##ns_cmd_card' .. c.id, { cw, h });
        local hov = imgui.IsItemHovered();
        local on = sel == c.id;
        local is_run = running == c;
        ldl:AddRectFilled({ x, y }, { x + cw, y + h }, u32(on and { NEON[1] * 0.28, NEON[2] * 0.28, NEON[3] * 0.28, 0.95 } or (hov and { 0.13, 0.12, 0.17, 1 } or { 0.075, 0.070, 0.100, 0.9 })), 9);
        ldl:AddRect({ x, y }, { x + cw, y + h }, u32(on and { NEON2[1], NEON2[2], NEON2[3], 0.85 } or { 1, 1, 1, hov and 0.18 or 0.07 }), 9, C.rall, on and 1.4 or 1);
        local rx = x + cw - 10;
        local alias = tostring(c.alias or '');
        if alias ~= '' then
            local aw = theme.chip_w(alias);
            theme.chip(ldl, rx - aw, y + 7, alias, C.acc);
            rx = rx - aw - 6;
        end
        if is_run then
            local t = 'RUNNING';
            local w = theme.chip_w(t);
            theme.chip(ldl, rx - w, y + 7, t, C.good);
            rx = rx - w - 6;
        end
        ldl:AddText({ x + 12, y + 8 }, u32({ 1, 1, 1, 1 }), theme.fit(c.name or '(no name)', rx - x - 18));
        local n = #(c.steps or {});
        local line = n .. ' step' .. (n == 1 and '' or 's');
        if is_run then line = 'Step ' .. ri .. ' of ' .. n; end
        ldl:AddText({ x + 12, y + 12 + lh }, u32({ C.acc[1], C.acc[2], C.acc[3], 0.85 }), line);
        if hov then tip((c.name or '') .. (alias ~= '' and ('\nType ' .. alias .. ' to run it') or '') .. '\n\nClick: edit'); end
        if clk then on_pick(c.id); end
        view.order[#view.order + 1] = c.id;
        if nav_row == #view.order then
            nav.ring(ldl, x, y, x + cw, y + h, 9);
            if nav.moved then imgui.SetScrollHereY(0.5); nav.moved = false; end
        end
        imgui.SetCursorScreenPos({ x, y + h + 5 });
    end
    imgui.Dummy({ 4, 6 });
    imgui.Unindent(6);
    theme.end_list(pv);
end

----------------------------------------------------------------------------------------------------
-- The editor
----------------------------------------------------------------------------------------------------
local STEP_OPTS = {};
for _, s in ipairs(commands.STEPS) do STEP_OPTS[#STEP_OPTS + 1] = { s.key, s.label }; end
local COND_OPTS = {};
for _, c in ipairs(rules.CONDS) do COND_OPTS[#COND_OPTS + 1] = { c.key, (c.label:gsub(' %%$', '')) }; end
local TARGET_OPTS = {};
for _, t in ipairs(commands.TARGETS) do TARGET_OPTS[#TARGET_OPTS + 1] = { t, t }; end

-- names to suggest while typing a step's spell / ability / weapon skill
local function suggestions(t, text)
    text = text:lower();
    local src;
    if t == 'cast' then
        src = game.spells();
        local out = {};
        if ('{spirit}'):find(text, 1, true) then out[#out + 1] = { name = '{spirit}' }; end
        for _, e in ipairs(when.match(src, text, 20)) do out[#out + 1] = e; end
        return out;
    elseif t == 'ja' then src = game.abilities();
    elseif t == 'ws' then src = game.weaponskills();
    else return {}; end
    return when.match(src, text, 20);
end

-- A condition editor: type, turn-around, value. Returns changed.
local function cond_editor(id, c, W)
    local changed = false;
    local d = rules.BY_COND[c.t];
    local p = theme.pick('##' .. id .. '_ct', COND_OPTS, c.t, 190);
    if p and p ~= c.t then
        local nd = rules.BY_COND[p];
        c.t, c.v, c.n, c.n2, c.neg = p, nil, nd.def, nd.def2, nil;
        d = nd;
        changed = true;
    end
    if d and d.neg then
        imgui.SameLine();
        local nc, nh = theme.pill('##' .. id .. '_neg', c.neg and 'not' or 'is', c.neg == true);
        if nh then tip(c.neg and ('Now: ' .. d.neg) or ('Now: ' .. d.label) .. '\nClick to turn it around'); end
        if nc then c.neg = not c.neg or nil; changed = true; end
    end
    if d and d.arg then
        imgui.SameLine();
        imgui.BeginGroup();
        if when.cond_value(id, c, d, W) then changed = true; end
        imgui.EndGroup();
    end
    return changed;
end

local function step_row(abbr, cmd, i, s, W, is_cur)
    local changed = false;
    local dl = imgui.GetWindowDrawList();
    local lh = imgui.GetTextLineHeight();
    local id = 'ns_st' .. cmd.id .. '_' .. i;
    local x0, y0 = imgui.GetCursorScreenPos();
    imgui.BeginGroup();
    imgui.Dummy({ 1, 4 });
    -- the number
    local nx = x0 + 10;
    imgui.SetCursorScreenPos({ nx + 26, y0 + 6 });
    local p = theme.pick('##' .. id .. '_t', STEP_OPTS, s.t, 170);
    if p and p ~= s.t then
        local d = commands.BY_STEP[p];
        s.t, s.v, s.n, s.target = p, nil, d.def, d.target and '<me>' or nil;
        if p == 'stop' then s.cond = s.cond or { t = 'mpp_above', n = 50 }; end
        changed = true;
    end
    local d = commands.BY_STEP[s.t] or commands.STEPS[1];
    if imgui.IsItemHovered() then tip(d.hint); end
    imgui.SameLine();
    imgui.BeginGroup();
    local avail = W - 26 - 170 - 90;
    if d.arg == 'text' or d.arg == 'line' then
        local b = when.buf(id .. '_v', s.v or '');
        if not view[id .. '_act'] and b[1] ~= (s.v or '') then b[1] = s.v or ''; end
        local tw_ = d.arg == 'line' and avail or math.max(120, avail - 100);
        local act = theme.input('##' .. id .. '_v', b, 96, tw_, d.arg == 'line' and '/command ...' or (s.t == 'cast' and 'Spell (or {spirit})' or 'Name'), false);
        view[id .. '_act'] = act;
        if (b[1] or '') ~= (s.v or '') then s.v = b[1]; changed = true; end
        if d.target then
            imgui.SameLine();
            local tp = theme.pick('##' .. id .. '_tg', TARGET_OPTS, s.target or '<me>', 90);
            if tp then s.target = tp; changed = true; end
        end
        local txt = (b[1] or ''):gsub('^%s+', '');
        if act and #txt >= 2 then
            local n = 0;
            for _, f in ipairs(suggestions(s.t, txt)) do
                if f.name:lower() ~= txt:lower() then
                    n = n + 1;
                    if n > 6 then break; end
                    if imgui.Selectable('  ' .. f.name .. '##' .. id .. '_sg' .. n, false, 0, { tw_, 0 }) then s.v = f.name; b[1] = f.name; changed = true; end
                end
            end
        end
        if s.v and s.v:find('{', 1, true) then
            imgui.TextColored({ C.muted[1], C.muted[2], C.muted[3], 0.8 }, 'Now: ' .. commands.fill(s.v));
        end
    elseif d.arg == 'secs' then
        local v, ch = theme.digits(id .. '_n', tonumber(s.n) or d.def or 1, 0, 99);
        if ch then s.n = v; changed = true; end
        imgui.SameLine();
        imgui.AlignTextToFramePadding();
        imgui.TextColored(C.muted, s.t == 'wait' and 'seconds' or 'seconds at most');
    elseif d.arg == 'set' then
        local opts = {};
        for _, st in ipairs(store.sets(abbr)) do opts[#opts + 1] = { st.name, st.name }; end
        if #opts == 0 then imgui.TextColored(C.warn, 'No ' .. abbr .. ' sets yet.');
        else
            if s.v and store.find_by_name(abbr, s.v) == nil then table.insert(opts, 1, { s.v, s.v .. ' (missing)' }); end
            local sp = theme.pick('##' .. id .. '_set', opts, s.v or opts[1][1], math.min(220, avail));
            if s.v == nil then s.v = opts[1][1]; changed = true; end
            if sp then s.v = sp; changed = true; end
            if store.find_by_name(abbr, s.v or '') == nil then imgui.TextColored(C.warn, 'No ' .. abbr .. ' set has this name: the step will be skipped.'); end
        end
    elseif d.arg == 'cycle' then
        local b = when.buf(id .. '_cy', s.v or '');
        if not view[id .. '_cyact'] and b[1] ~= (s.v or '') then b[1] = s.v or ''; end
        view[id .. '_cyact'] = theme.input('##' .. id .. '_cy', b, 128, avail, 'Modes, in order: Normal, PDT, MDT', false);
        if (b[1] or '') ~= (s.v or '') then s.v = b[1]; changed = true; end
        local list = commands.cycle_list(s.v);
        if #list > 0 then
            local parts = {};
            for _, m in ipairs(list) do parts[#parts + 1] = store.mode(m) and ('[' .. m .. ']') or m; end
            imgui.TextColored({ C.muted[1], C.muted[2], C.muted[3], 0.8 }, 'Now: ' .. table.concat(parts, '  >  ') .. '   (the one in [ ] is on)');
        end
    elseif d.arg == 'mode' or d.arg == 'entry' then
        local ww = math.min(200, avail - 170);
        if d.arg == 'mode' then
            local b = when.buf(id .. '_m', s.v or '');
            if not view[id .. '_mact'] and b[1] ~= (s.v or '') then b[1] = s.v or ''; end
            view[id .. '_mact'] = theme.input('##' .. id .. '_m', b, 32, ww, 'Mode name (PDT, TH...)', false);
            if (b[1] or '') ~= (s.v or '') then s.v = b[1]; changed = true; end
        else
            local opts = {};
            for _, e in ipairs(store.entries()) do opts[#opts + 1] = { e.name, e.name }; end
            if #opts == 0 then imgui.TextColored(C.warn, 'No custom entries yet (+ New entry, under the jobs).');
            else
                if s.v and store.entry_by_name(s.v) == nil then table.insert(opts, 1, { s.v, s.v .. ' (missing)' }); end
                if s.v == nil then s.v = opts[1][1]; changed = true; end
                local ep = theme.pick('##' .. id .. '_en', opts, s.v, ww);
                if ep then s.v = ep; changed = true; end
            end
        end
        imgui.SameLine();
        local wp = theme.segmented('##' .. id .. '_w', { { 'on', 'On' }, { 'off', 'Off' }, { 'toggle', 'Toggle', 'On if it\'s off, off if it\'s on' } }, s.w or 'toggle');
        if wp then s.w = (wp ~= 'toggle') and wp or nil; changed = true; end
    elseif d.arg == 'cond' then
        s.cond = s.cond or { t = 'mpp_above', n = 50 };
        if cond_editor(id .. '_sc', s.cond, avail) then changed = true; end
    end
    -- only when
    if s.t ~= 'stop' then
        if s.cond and s.cond.t then
            imgui.AlignTextToFramePadding();
            imgui.TextColored(C.muted, 'only when');
            imgui.SameLine();
            if cond_editor(id .. '_oc', s.cond, avail - 80) then changed = true; end
            imgui.SameLine();
            local bx, by = imgui.GetCursorScreenPos();
            local xc, xh = theme.icon_button('##' .. id .. '_ocx', bx + 2, by + 3, 'close', 16);
            if xh then tip('Always do this step'); end
            if xc then s.cond = nil; changed = true; end
        else
            local oc, oh = theme.pill('##' .. id .. '_oc_add', '+ only when', false);
            if oh then tip('Do this step only when something is true (pet out, MP below 50%...)'); end
            if oc then s.cond = { t = 'pet_out' }; changed = true; end
        end
    end
    imgui.EndGroup();
    -- up / down / delete
    local bx = x0 + W - 3 * 22;
    local act = nil;
    for k, b in ipairs({ { 'up', 'Move up' }, { 'down', 'Move down' }, { 'close', 'Remove this step' } }) do
        local c, h = theme.icon_button('##' .. id .. '_' .. b[1], bx + (k - 1) * 22, y0 + 8, b[1], 18);
        if h then tip(b[2]); end
        if c then act = b[1]; end
    end
    imgui.EndGroup();
    local _, y1 = imgui.GetCursorScreenPos();
    y1 = math.max(y1, y0 + theme.pill_h() + 14);
    -- a bar down the left (green while this step runs), the number, a faint line under it
    local bar = is_cur and C.good or { NEON[1], NEON[2], NEON[3], 0.55 };
    dl:AddRectFilled({ x0, y0 + 2 }, { x0 + 3, y1 }, u32(bar), 1.5);
    dl:AddCircleFilled({ nx + 9, y0 + 6 + theme.pill_h() / 2 }, 10, u32(is_cur and { 0.12, 0.40, 0.20, 1 } or { NEON[1] * 0.42, NEON[2] * 0.42, NEON[3] * 0.42, 1 }), 20);
    local t = tostring(i);
    dl:AddText({ nx + 9 - tw(t) / 2, y0 + 6 + theme.pill_h() / 2 - lh / 2 }, u32({ 1, 1, 1, 1 }), t);
    dl:AddLine({ x0 + 10, y1 + 4 }, { x0 + W, y1 + 4 }, u32({ 1, 1, 1, 0.06 }), 1);
    imgui.SetCursorScreenPos({ x0, y1 + 8 });
    imgui.Dummy({ W, 0 });
    return changed, act;
end

function view.editor(dl, abbr, cmd, W)
    local lh = imgui.GetTextLineHeight();
    if view.name_for ~= cmd.id then
        view.name_for = cmd.id;
        view.name_buf[1] = cmd.name or '';
        view.alias_buf[1] = cmd.alias or '';
        view.label_buf[1] = cmd.button and cmd.button.label or '';
    end
    local x0, y0 = imgui.GetCursorScreenPos();
    local running = commands.running();
    local is_run = running == cmd;
    local del_label = (view.del_armed and view.del_armed.id == cmd.id and os.clock() - view.del_armed.at < 3) and 'Sure?' or 'Delete';
    local btns = { { 'run', is_run and 'Stop' or 'Run', true }, { 'dup', 'Duplicate', false }, { 'del', del_label, false } };
    local bw = 0;
    for _, b in ipairs(btns) do bw = bw + tw(b[2]) + 30; end
    local nw = math.max(140, W - bw - 150);
    theme.input('##ns_cmd_name', view.name_buf, 40, nw, 'Name (Elemental Siphon...)', false);
    if (view.name_buf[1] or '') ~= (cmd.name or '') then cmd.name = view.name_buf[1]; store.touch(); end
    imgui.SetCursorScreenPos({ x0 + nw + 8, y0 });
    theme.input('##ns_cmd_alias', view.alias_buf, 24, 130, '/word to run it', false);
    if imgui.IsItemHovered() then tip('Type this in chat (or put it in a macro) to run the command, like /siphon.\nPick a word the game doesn\'t use itself.'); end
    local a = (view.alias_buf[1] or ''):gsub('%s', '');
    if a ~= '' and a:sub(1, 1) ~= '/' then a = '/' .. a; end
    if a ~= (cmd.alias or '') then cmd.alias = a; store.touch(); end
    local bx = x0 + nw + 8 + 138;
    for _, b in ipairs(btns) do
        imgui.SetCursorScreenPos({ bx, y0 + 2 });
        local c, h = theme.button('##ns_cmd_b_' .. b[1], b[2], { lit = b[3], col = (b[2] == 'Sure?') and C.bad or nil });
        if b[1] == 'run' then
            if h then tip(is_run and 'Stop it now' or 'Run it now (as your current job)'); end
            if c then
                if is_run then commands.stop();
                elseif not store.is_entry(abbr) and abbr ~= require('core.jobs').ABBR[require('core.jobs').main()] then say('This is a ' .. abbr .. ' command; change to ' .. abbr .. ' to run it.', 'warn');
                else commands.start(abbr, cmd); end
            end
        elseif b[1] == 'dup' then
            if h then tip('Make a copy'); end
            if c then local n = commands.new(abbr, cmd); n.name = (cmd.name or '') .. ' (copy)'; n.alias = ''; view.sel = n.id; view.on_pick(n.id); end
        elseif b[1] == 'del' then
            if h then tip('Delete this command (click twice)'); end
            if c then
                if b[2] == 'Sure?' then commands.remove(abbr, cmd.id); view.del_armed = nil; view.on_pick(nil); return;
                else view.del_armed = { id = cmd.id, at = os.clock() }; end
            end
        end
        bx = bx + tw(b[2]) + 30;
    end
    imgui.SetCursorScreenPos({ x0, y0 + theme.pill_h() + 14 });
    local alias_dup = false;
    for _, o in ipairs(commands.list(abbr)) do
        if o ~= cmd and o.alias and o.alias ~= '' and o.alias:lower() == (cmd.alias or ''):lower() then alias_dup = true; end
    end
    if alias_dup then imgui.TextColored(C.bad, 'Another ' .. abbr .. ' command uses ' .. cmd.alias .. '.'); end

    -- the on-screen button
    buttons = buttons or require('ui.buttons');
    do
        local bx0, by0 = imgui.GetCursorScreenPos();
        local on = cmd.button ~= nil and cmd.button.on == true;
        imgui.SetCursorScreenPos({ bx0, by0 + 4 });
        imgui.TextColored(C.text, 'Button on screen');
        local th = imgui.IsItemHovered();
        imgui.SetCursorScreenPos({ bx0 + tw('Button on screen') + 12, by0 });
        if theme.switch('##ns_cmd_btn', on) then
            if on then cmd.button.on = false; store.touch(); else buttons.turn_on(cmd); end
            on = not on;
        end
        if th or imgui.IsItemHovered() then
            tip('A button you can put anywhere on screen: click it to run this command, drag it to move it.\n' ..
                (store.is_entry(abbr) and 'It shows on every job.' or ('It shows while you\'re ' .. abbr .. '.')) ..
                '\n/nswap buttons hide | show | lock | unlock');
        end
        if on then
            local lx = bx0 + tw('Button on screen') + 12 + 52 + 14;
            imgui.SetCursorScreenPos({ lx, by0 });
            local mode = (cmd.button.style == 'icon') and 'icon' or 'name';
            local opts = { { 'name', 'Name', 'The button shows text (the command\'s name, or your own label)' },
                           { 'icon', 'Icon', 'The button shows an icon (an item\'s icon or a job emblem)' } };
            local p = theme.segmented('##ns_cmd_bstyle', opts, mode);
            if p and p ~= mode then
                cmd.button.style = (p == 'icon') and 'icon' or nil; mode = p; store.touch();
                if p == 'icon' and cmd.button.icon == nil then icon_pick.reset_search(); imgui.OpenPopup('##ns_btn_icon_pop'); end
            end
            lx = lx + theme.segmented_w(opts) + 10;
            if mode == 'icon' then
                local S = theme.pill_h();
                imgui.SetCursorScreenPos({ lx, by0 });
                if imgui.InvisibleButton('##ns_cmd_bicon', { S, S }) then icon_pick.reset_search(); imgui.OpenPopup('##ns_btn_icon_pop'); end
                local ih = imgui.IsItemHovered();
                dl:AddRectFilled({ lx, by0 }, { lx + S, by0 + S }, u32({ 0.08, 0.075, 0.11, 1 }), 6);
                icon_pick.draw(dl, cmd.button.icon, lx + 2, by0 + 2, S - 4, 1, cmd.name);
                if ih then
                    dl:AddRect({ lx - 2, by0 - 2 }, { lx + S + 2, by0 + S + 2 }, u32({ NEON2[1], NEON2[2], NEON2[3], 0.8 }), 6, C.rall, 1.5);
                    tip('Click to pick the button\'s icon (travel and status items, job emblems, or any item)');
                end
                icon_pick.menu('##ns_btn_icon_pop', cmd.button, { { title = 'HANDY ITEMS', list = BUTTON_ICONS } });
                lx = lx + S + 10;
            else
                imgui.SetCursorScreenPos({ lx, by0 });
                theme.input('##ns_cmd_blabel', view.label_buf, 24, 170, 'Label (' .. theme.fit(cmd.name or '', 90) .. ')', false);
                if imgui.IsItemHovered() then tip('What the button says. Empty: the command\'s name.'); end
                if (view.label_buf[1] or '') ~= (cmd.button.label or '') then
                    cmd.button.label = (view.label_buf[1] ~= '') and view.label_buf[1] or nil; store.touch();
                end
                lx = lx + 180;
            end
            if config.get('buttons_shown') == false then
                imgui.SetCursorScreenPos({ lx, by0 + 4 });
                imgui.TextColored(C.warn or C.muted, 'Buttons are hidden (/nswap buttons show)');
            end
        end
        imgui.SetCursorScreenPos({ bx0, by0 + theme.pill_h() + 10 });
        imgui.Dummy({ 1, 0 });
    end
    local hx, hy = imgui.GetCursorScreenPos();
    local h = theme.wrapped(dl, hx, hy, 'Steps run one after another. A step that sends a command waits a second before the next. ' ..
        'In names: {spirit} = the spirit for the weather (or the day), {element}, {day}, {weather}, {pet}.', W, u32({ C.muted[1], C.muted[2], C.muted[3], 0.8 }));
    imgui.Dummy({ W, h + 2 });

    theme.section('Steps', W);
    local _, cur_i = commands.running();
    local move, del = nil, nil;
    for i, s in ipairs(cmd.steps or {}) do
        local ch, act = step_row(abbr, cmd, i, s, W, is_run and cur_i == i);
        if ch then store.touch(); end
        if act == 'up' and i > 1 then move = { i, i - 1 };
        elseif act == 'down' and i < #cmd.steps then move = { i, i + 1 };
        elseif act == 'close' then del = i; end
    end
    if move then cmd.steps[move[1]], cmd.steps[move[2]] = cmd.steps[move[2]], cmd.steps[move[1]]; store.touch(); end
    if del then table.remove(cmd.steps, del); store.touch(); end
    if #(cmd.steps or {}) == 0 then imgui.TextColored(C.muted, 'No steps yet.'); end
    imgui.Spacing();
    if theme.button('##ns_cmd_addstep', '+ Step', { lit = true }) then imgui.OpenPopup('##ns_cmd_step_pop'); end
    local pv = when.popup_style();
    if imgui.BeginPopup('##ns_cmd_step_pop') then
        for _, d in ipairs(commands.STEPS) do
            if imgui.Selectable('  ' .. d.label .. '##ns_cs_' .. d.key, false, 0, { 220, 0 }) then
                cmd.steps = cmd.steps or {};
                local s = { t = d.key, n = d.def, target = d.target and '<me>' or nil };
                if d.key == 'stop' then s.cond = { t = 'mpp_above', n = 50 }; end
                cmd.steps[#cmd.steps + 1] = s;
                store.touch();
            end
            if imgui.IsItemHovered() then tip(d.hint); end
        end
        imgui.EndPopup();
    end
    when.popup_pop(pv);
    imgui.Dummy({ W, 10 });
end

return view;
