-- settings_window.lua : the NeoSwap settings panel (General, Timing, Commands), YunaUI style
local imgui  = require('imgui');
local config = require('configs.config');
local theme  = require('ui.theme');
local store  = require('core.store');
local pad    = require('core.pad');
local C, u32, tip, tw = theme.C, theme.u32, theme.tip, theme.tw;
local NEON2 = theme.NEON2;

local settings_window = {};
theme.ROW_W = 380;

local COMMANDS = {
    { '/nswap',                  'show or hide the window (/neoswap too)' },
    { '/nswap min',              'minimize to the NSWP bubble (or back)' },
    { '/nswap on | off',         'turn gear swapping on or off' },
    { '/nswap set <name>',       'put on one of your current job\'s sets now and hold it (Equip now)' },
    { '/nswap unlock',           'let go of held slots (after Equip now / set)' },
    { '/nswap run <command>',    'run one of your job\'s own commands (or type its own /word, like /siphon)' },
    { '/nswap stop',             'stop the command that\'s running' },
    { '/nswap mode <name> [on|off]', 'switch a mode (toggles without on / off) - good in a macro' },
    { '/nswap modes',            'list your modes' },
    { '/nswap disable <slot|all>', 'NeoSwap leaves a slot alone (main, sub, range, ammo, head, neck, ear1...)' },
    { '/nswap enable <slot|all>', 'and stops leaving it alone' },
    { '/nswap lockstyle',        'set your job\'s lockstyle now' },
    { '/nswap macros',           'change to your job\'s macro book and page now' },
    { '/nswap job <JOB>',        'show a job\'s sets in the window' },
    { '/nswap debug',            'print every swap in chat (or not)' },
    { '/nswap save',             'write your sets to disk now (they save by themselves too)' },
    { '/nswap config',           'open or close these settings' },
    { '/nswap opacity 60',       'set the opacity (20 to 100)' },
};

local TABS = {
    { 'general', 'General' },
    { 'timing',  'Timing' },
    { 'controller', 'Controller' },
    { 'commands', 'Commands' },
};

local function pct(v) return string.format('%d%%', math.floor(v * 100 + 0.5)); end
local function secs(v) return string.format('%.1fs', v); end

local function hint(s)
    local W = theme.ROW_W;
    local dl = imgui.GetWindowDrawList();
    local x, y = imgui.GetCursorScreenPos();
    local h = theme.wrapped(dl, x, y, s, W, u32({ C.muted[1], C.muted[2], C.muted[3], 0.85 }));
    imgui.Dummy({ W, h + 2 });
end

local function general(W)
    theme.section('Display', W);
    theme.row_slider('##ns_op', 'Opacity', 'opacity', 0.2, 1.0, 0.05, pct, 'How see-through the window is.');
    theme.row_switch('##ns_fade', 'Fade text too', 'fade_text', 'Off: only the background fades and the text stays crisp.\nOn: everything fades.');
    theme.row_switch('##ns_follow', 'Follow my job', 'follow_job', 'When you change job, the window shows that job\'s sets.');
    theme.row_switch('##ns_btns', 'Show command buttons', 'buttons_shown', 'The on-screen buttons of your commands (turn one on in its command\'s page).');
    theme.row_switch('##ns_btnl', 'Lock command buttons', 'buttons_locked', 'On: the buttons can\'t be dragged by accident.');

    theme.section('Swapping', W);
    theme.row_switch('##ns_eng', 'Swap gear', 'engine_on', 'Off: NeoSwap only edits sets, and your gear is left alone.');
    theme.row_switch('##ns_dbg', 'Show swaps in chat', 'debug', 'Print every piece NeoSwap puts on (to see what a set does).');
    theme.row_switch('##ns_lac', 'Unload LuAshitacast on load', 'unload_lac',
        'LuAshitacast and NeoSwap both swap gear on every action. With this on,\nNeoSwap unloads LuAshitacast when it loads.');
    if theme.button('##ns_lac_now', 'Unload LuAshitacast now', { w = W }) then
        pcall(function() AshitaCore:GetPluginManager():RaiseEvent('luashitacast_unload', {}); end);
        AshitaCore:GetChatManager():QueueCommand(-1, '/addon unload luashitacast');
    end

    theme.section('Your sets', W);
    hint('Saved by themselves, per character, in:');
    hint(store.path or (store.base_dir() .. '<Name>_<id>\\sets.lua'));
    hint('The file before the last save is kept next to it as sets.lua.bak.');
end

local function timing(W)
    theme.section('Spells and shots', W);
    hint('How long the midcast set stays on: a spell\'s cast time, cut by your Fast Cast, plus a margin. The set comes off early if the action ends sooner.');
    theme.row_slider('##ns_fc', 'Fast Cast', 'fast_cast', 0, 80, 1, '%d%%', 'Your Fast Cast in total.');
    theme.row_slider('##ns_so', 'Spell margin', 'spell_offset', 0, 3, 0.1, secs, 'Added to every spell\'s time.');
    theme.row_slider('##ns_sn', 'Snapshot', 'snapshot', 0, 80, 1, '%d%%', 'Your Snapshot in total.');
    theme.row_slider('##ns_rb', 'Ranged attack time', 'ranged_base', 2, 15, 0.5, secs, 'A ranged attack before Snapshot.');
    theme.row_slider('##ns_ro', 'Ranged margin', 'ranged_offset', 0, 3, 0.1, secs);
    theme.section('Others', W);
    theme.row_slider('##ns_ws', 'Weapon skill', 'ws_delay', 1, 6, 0.1, secs, 'How long a weapon skill set is held.');
    theme.row_slider('##ns_ja', 'Ability', 'ja_delay', 1, 6, 0.1, secs, 'How long an ability set is held.');
    theme.row_slider('##ns_ib', 'Item (unknown)', 'item_base', 2, 15, 0.5, secs, 'For items the game gives no use time for.');
    theme.row_slider('##ns_io', 'Item margin', 'item_offset', 0, 3, 0.1, secs);
    theme.row_slider('##ns_pd', 'Pet ability', 'pet_delay', 1, 8, 0.1, secs, 'How long a pet action set is held.');
end

local function bind_row(a)
    local W = theme.ROW_W;
    local key, label, h_ = a[1], a[2], a[3];
    local x0 = imgui.GetCursorPosX();
    imgui.AlignTextToFramePadding();
    imgui.TextColored(C.text, theme.safe(label));
    if h_ and imgui.IsItemHovered() then tip(h_); end
    local cw, clw = 78, 64;
    imgui.SameLine(x0 + W - cw - clw - 6);
    local x, y = imgui.GetCursorScreenPos();
    local listening = pad.listen == key;
    if theme.button('##ns_bc_' .. key, listening and 'Cancel' or 'Change', { w = cw, lit = listening }) then
        if listening then pad.cancel_listen(); else pad.start_listen(key); end
    end
    imgui.SetCursorScreenPos({ x + cw + 6, y });
    if theme.button('##ns_bx_' .. key, 'Clear', { w = clw }) then pad.set_binds(key, {}); end
    -- what it's bound to
    local txt = listening and (key == 'toggle' and 'Press a button, or two together...' or 'Press a button...') or (pad.bind_text(key) or 'Not set');
    local bx, by = imgui.GetCursorScreenPos();
    local bh = imgui.GetFrameHeight();
    local dl = imgui.GetWindowDrawList();
    local pu = 0.5 + 0.5 * math.sin(os.clock() * 5);
    dl:AddRectFilled({ bx, by }, { bx + W, by + bh }, u32(listening and { NEON2[1], NEON2[2], NEON2[3], 0.10 + 0.10 * pu } or { 1, 1, 1, 0.04 }), bh / 2);
    dl:AddRect({ bx, by }, { bx + W, by + bh }, u32(listening and { NEON2[1], NEON2[2], NEON2[3], 0.9 } or { 1, 1, 1, 0.10 }), bh / 2, C.rall, 1);
    local lw, lh = imgui.CalcTextSize(txt);
    dl:AddText({ bx + (W - lw) / 2, by + (bh - lh) / 2 }, u32(listening and NEON2 or { 1, 1, 1, pad.bind_text(key) and 0.95 or 0.45 }), txt);
    imgui.Dummy({ W, bh + 4 });
end

local function controller(W)
    theme.section('Controller', W);
    theme.row_switch('##ns_pe', 'Use a controller', 'pad_enabled',
        'Open NeoSwap with a button combo, then move through it with the D-pad:\nthe jobs, the sets, the equipment slots and the gear for a slot.');
    theme.row_switch('##ns_pb', 'Keep NeoSwap\'s buttons from the game', 'pad_block',
        'While NeoSwap is open, the buttons it uses don\'t also reach the game\n(so the D-pad doesn\'t move your character or the game\'s cursor).');
    hint('Xbox (XInput) and PlayStation / other (DirectInput) pads both work. Press Change, then the button. Each function can have its own button; the defaults cover both kinds of pad.');
    theme.section('Buttons', W);
    for _, a in ipairs(pad.ACTIONS) do bind_row(a); end
    imgui.Dummy({ W, 4 });
    if theme.button('##ns_pad_reset', 'Reset to defaults', { w = W }) then
        local p = config.tbl('pad');
        for k, v in pairs(config.defaults.pad) do
            local c = T{};
            for i, x in ipairs(v) do c[i] = x; end
            p[k] = c;
        end
        config.save();
    end
    theme.section('In NeoSwap', W);
    hint('Left / right move between the jobs, the job\'s sets (or commands), the equipment slots and the gear for a slot. Up / down move inside each. Confirm picks: a job, a set (it opens), a slot (its gear is listed), a piece (it goes in the slot). Back goes one step back, and from the jobs minimizes NeoSwap. The second action button: Equip now on a set, Run on a command, empty a slot. The tab buttons switch Sets / Commands. Conditions, names and timings are set with the mouse.');
end

local function commands(W)
    theme.section('Commands', W);
    local dl2 = imgui.GetWindowDrawList();
    local lh = imgui.GetTextLineHeight();
    local colw = 0;
    for _, c in ipairs(COMMANDS) do colw = math.max(colw, tw(c[1])); end
    colw = math.min(colw + 14, W * 0.5);
    local x0c, y0c = imgui.GetCursorScreenPos();
    local yc = y0c;
    for _, c in ipairs(COMMANDS) do
        local cl = theme.wrap(c[1], colw - 10);
        for k, l in ipairs(cl) do dl2:AddText({ x0c, yc + (k - 1) * lh }, u32(C.acc), l); end
        local lines = theme.wrap(c[2], math.max(80, W - colw));
        for k, l in ipairs(lines) do dl2:AddText({ x0c + colw, yc + (k - 1) * lh }, u32(C.muted), l); end
        yc = yc + math.max(#lines, #cl) * lh + 4;
    end
    imgui.SetCursorScreenPos({ x0c, y0c });
    imgui.Dummy({ W, yc - y0c });
end

function settings_window.draw()
    if not config.get('show_config_gui') then
        if pad.listen then pad.cancel_listen(); end
        return;
    end
    local W = theme.ROW_W;
    local nc, nv = theme.push(1, nil, { 20, 16 });
    imgui.SetNextWindowPos({ tonumber(config.get('cfg_x')) or 1000, tonumber(config.get('cfg_y')) or 140 }, ImGuiCond_FirstUseEver);
    local close = false;
    if imgui.Begin('NeoSwap Settings##neoswap_cfg', { true }, theme.WIN_FLAGS) then
        local dl = imgui.GetWindowDrawList();
        local x0, y0 = imgui.GetCursorScreenPos();
        local _, th = theme.title(dl, x0, y0, 'NEOSWAP', 3, 1.3);
        dl:AddText({ x0 + theme.title_size('NEOSWAP', 1.3) + 10, y0 + th - imgui.GetTextLineHeight() - 1 }, u32(C.muted), 'settings');
        local clicked, hov = theme.icon_button('##ns_cfg_close', x0 + W - 18, y0 + (th - 18) / 2, 'close');
        if hov then tip('Close the settings'); end
        if clicked then close = true; end
        imgui.SetCursorScreenPos({ x0, y0 });
        imgui.Dummy({ W, th });
        local cur = config.get('cfg_tab') or 'general';
        local p = theme.segmented('##ns_cfg_tabs', TABS, cur);
        if p and p ~= cur then config.set('cfg_tab', p); cur = p; end
        imgui.Dummy({ W, 2 });
        if cur == 'timing' then timing(W);
        elseif cur == 'controller' then controller(W);
        elseif cur == 'commands' then commands(W);
        else general(W); end
        theme.remember_pos('cfg_x', 'cfg_y');
    end
    imgui.End();
    theme.pop(nc, nv);
    if close then config.set('show_config_gui', false); end
end

return settings_window;
