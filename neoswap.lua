addon.name    = 'NeoSwap';
addon.author  = 'KS1985';
addon.version = '0.9.3';
addon.desc    = 'Gear swapping without writing a profile: build your sets in an equipment menu, say when each is worn (idle, engaged, resting, weapon skills, abilities, spells, ranged, items, pet moves, with conditions), see their bonuses and clashes. Lockstyle and macro book per job. Restyled after YunaUI.';
addon.link    = 'https://github.com/QB1985/NeoSwap';

require('common');
local chat = require('chat');

local config  = require('configs.config');
local store   = require('core.store');
local game    = require('core.game');
local bags    = require('core.bags');
local items   = require('core.items');
local jobs    = require('core.jobs');
local engine  = require('core.engine');
local commands = require('core.commands');
commands.engine = engine;
local check   = require('core.check');
local stats   = require('core.stats');
local tex     = require('ui.tex');
local pad     = require('core.pad');
local nav     = require('ui.nav');
local ui      = require('ui.window');
local settings_window = require('ui.settings_window');
local buttons = require('ui.buttons');

local function say(msg) print(chat.header(addon.name) .. chat.message(msg)); end
local function err(msg) print(chat.header(addon.name) .. chat.error(msg)); end

----------------------------------------------------------------------------------------------------
-- Your character: its sets are loaded once you're in game (and again if you log in as someone else)
----------------------------------------------------------------------------------------------------
local loaded_for = nil;
local function ensure_loaded()
    local name, id = game.me();
    if name == nil or name == '' then return false; end
    local key = name .. ':' .. id;
    if loaded_for == key then return true; end
    if store.dirty_at then store.save_now(); end
    loaded_for = key;
    store.load(name, id);
    check.reset();
    local n = 0;
    for _, j in pairs(store.data.jobs) do n = n + #(j.sets or {}); end
    say(string.format('%d set%s loaded for %s.', n, n == 1 and '' or 's', name));
    return true;
end

engine.on_job_change = function(j) ui.on_job_change(j); end

-- the controller drives the window (as in NeoMOG)
pad.is_open = function() return config.get('show_gui') == true and not config.get('minimized'); end
pad.on_action = function(a)
    if a == 'toggle' then
        if config.get('show_gui') and not config.get('minimized') then config.set('minimized', true);
        else config.set('show_gui', true); config.set('minimized', false); nav.zone = 'rail'; end
        return;
    end
    if pad.is_open() then ui.on_action(a); end
end

ashita.events.register('load', 'neoswap_load_cb', function()
    game.init();
    if config.get('unload_lac') then
        pcall(function() AshitaCore:GetPluginManager():RaiseEvent('luashitacast_unload', {}); end);
        AshitaCore:GetChatManager():QueueCommand(-1, '/addon unload luashitacast');
    end
end);

----------------------------------------------------------------------------------------------------
-- Commands
----------------------------------------------------------------------------------------------------
local function cur_abbr() return jobs.ABBR[jobs.main()]; end

ashita.events.register('command', 'neoswap_command_cb', function(e)
    local args = e.command:args();
    if #args == 0 then return; end
    local cmd = args[1]:lower();
    -- one of your own commands (/siphon...)
    if cmd ~= '/neoswap' and cmd ~= '/nswap' then
        if not store.ready() then return; end
        local c, owner = commands.find_alias(cur_abbr(), cmd);
        if c then
            e.blocked = true;
            commands.start(owner, c);
        end
        return;
    end
    e.blocked = true;

    local sub = args[2] and args[2]:lower() or nil;
    local rest = table.concat(args, ' ', 3);
    if sub == nil or sub == 'toggle' then
        if config.get('show_gui') and config.get('minimized') then config.set('minimized', false);
        else config.toggle('show_gui'); end
    elseif sub == 'show' then config.set('show_gui', true); config.set('minimized', false);
    elseif sub == 'hide' then config.set('show_gui', false);
    elseif sub == 'min' or sub == 'minimize' then config.set('show_gui', true); config.toggle('minimized');
    elseif sub == 'config' or sub == 'settings' then config.toggle('show_config_gui');
    elseif sub == 'on' then config.set('engine_on', true); say('Swapping on.');
    elseif sub == 'off' then config.set('engine_on', false); say('Swapping off: your gear is left alone.');
    elseif sub == 'debug' then say('Showing swaps in chat: ' .. (config.toggle('debug') and 'on' or 'off') .. '.');
    elseif sub == 'save' then if store.save_now() then say('Saved to ' .. tostring(store.path)); end
    elseif sub == 'set' or sub == 'equip' then
        local abbr = cur_abbr();
        local s = abbr and store.find_by_name(abbr, rest);
        if s == nil then err('No ' .. tostring(abbr) .. ' set called "' .. rest .. '".'); return; end
        engine.wear(s, true);
        say('Wearing "' .. s.name .. '" (held: /nswap unlock lets go).');
    elseif sub == 'run' then
        local abbr = cur_abbr();
        local c = abbr and commands.by_name(abbr, rest);
        if c == nil then err('No ' .. tostring(abbr) .. ' command called "' .. rest .. '".'); return; end
        commands.start(abbr, c);
    elseif sub == 'entry' then
        -- /nswap entry <name> [on|off|toggle]
        local word = args[#args] and args[#args]:lower();
        local onoff = (word == 'on' or word == 'off' or word == 'toggle') and word or nil;
        local name = onoff and table.concat(args, ' ', 3, #args - 1) or rest;
        local en = store.entry_by_name(name);
        if en == nil then err('No custom entry called "' .. name .. '".'); return; end
        if onoff == 'on' or onoff == 'off' then en.active = onoff == 'on'; else en.active = not en.active; end
        store.touch();
        say(en.name .. ': ' .. (en.active and 'on - its sets go on over your job\'s.' or 'off.'));
    elseif sub == 'stop' then
        if commands.running() then commands.stop(); else say('No command is running.'); end
    elseif sub == 'item' then
        -- /nswap item <name>: what the game's data says about a piece, and where yours are
        local items = require('core.items');
        local id = tonumber(rest) or items.find_by_name(rest);
        if id == nil then err('No item called "' .. rest .. '".'); return; end
        local r = items.res(id);
        local total, reach = bags.owned(id);
        say(string.format('%s (id %d): slots %d, jobs 0x%X, level %d, flags 0x%X, icon %s',
            items.name(id), id, tonumber(r.Slots) or 0, tonumber(r.Jobs) or 0, tonumber(r.Level) or 0,
            tonumber(r.Flags) or 0, (tonumber(r.ImageSize) or 0) > 0 and 'yes' or 'none'));
        say(string.format('  You have %d (%d in Inventory / Wardrobes). Put on with: %s', total, reach,
            items.blank(id) and '/equip (custom gear)' or 'equip packet'));
    elseif sub == 'unlock' then engine.unlock_all(); say('Every slot is free again.');
    elseif sub == 'disable' or sub == 'enable' then
        local on = sub == 'disable';
        local w = (args[3] or ''):lower();
        if w == 'all' or w == '' then
            for i = 1, 16 do engine.disabled[i] = on; end
            say(on and 'NeoSwap leaves every slot alone.' or 'Every slot is free again.');
        else
            local s = bags.slot_from_word(w);
            if s == nil then err('No slot called "' .. w .. '" (main, sub, range, ammo, head, neck, ear1, ear2, body, hands, ring1, ring2, back, waist, legs, feet).'); return; end
            engine.disabled[s + 1] = on;
            say(bags.SLOT_NAME[s] .. (on and ': left alone.' or ': free again.'));
        end
    elseif sub == 'mode' then
        local name = args[3];
        if name == nil then err('Usage: /nswap mode <name> [on|off|toggle]'); return; end
        local v = args[4] and args[4]:lower() or nil;
        local on;
        if v == 'on' or v == 'true' or v == '1' then on = true;
        elseif v == 'off' or v == 'false' or v == '0' then on = false;
        else on = not store.mode(name); end
        store.set_mode(name, on);
        say('Mode ' .. name .. ': ' .. (on and 'on' or 'off') .. '.');
    elseif sub == 'cycle' then
        -- /nswap cycle Normal PDT MDT  (or with commas)
        local text = rest:find(',', 1, true) and rest or rest:gsub('%s+', ',');
        local name = commands.cycle(text);
        if name == nil then err('Usage: /nswap cycle <mode> <mode> ...'); return; end
        say('Mode: ' .. name .. '.');
    elseif sub == 'modes' then
        local t = {};
        for m, v in pairs(store.data and store.data.modes or {}) do t[#t + 1] = m .. (v and ' (on)' or ' (off)'); end
        table.sort(t);
        say(#t > 0 and ('Modes: ' .. table.concat(t, ', ')) or 'No modes yet.');
    elseif sub == 'lockstyle' or sub == 'ls' then engine.apply_lockstyle(false);
    elseif sub == 'macros' or sub == 'macro' then
        if not engine.apply_macros() then say('Macros aren\'t set for ' .. tostring(cur_abbr()) .. ' (turn them on on its page).'); end
    elseif sub == 'job' then
        local a = (args[3] or ''):upper();
        if jobs.id(a) == nil then err('No job "' .. a .. '".'); return; end
        config.set('show_gui', true); config.set('minimized', false);
        ui.select_job(a);
    elseif sub == 'buttons' or sub == 'button' then
        -- /nswap buttons [show|hide|lock|unlock]
        local w = (args[3] or ''):lower();
        if w == 'show' or w == 'on' then config.set('buttons_shown', true);
        elseif w == 'hide' or w == 'off' then config.set('buttons_shown', false);
        elseif w == 'lock' then config.set('buttons_locked', true);
        elseif w == 'unlock' then config.set('buttons_locked', false);
        elseif w == '' then config.set('buttons_shown', config.get('buttons_shown') == false);
        else err('Use: /nswap buttons [show|hide|lock|unlock]'); return; end
        say('Command buttons: ' .. (config.get('buttons_shown') == false and 'hidden' or 'shown') ..
            (config.get('buttons_locked') and ', locked.' or ', drag to move.'));
    elseif sub == 'opacity' then
        local n = tonumber(args[3]);
        if n == nil then say(string.format('Opacity is %d%%.', math.floor(config.num('opacity') * 100 + 0.5))); return; end
        if n > 1 then n = n / 100; end
        config.set('opacity', math.max(0.2, math.min(1, n)));
    else
        say('Commands: /nswap, /nswap on|off, /nswap set <name>, /nswap run <command>, /nswap stop, /nswap entry <name> [on|off|toggle], /nswap unlock, /nswap mode <name> [on|off|toggle], /nswap cycle <modes...>, /nswap modes, /nswap disable|enable <slot|all>, /nswap lockstyle, /nswap macros, /nswap job <JOB>, /nswap debug, /nswap save, /nswap config, /nswap min, /nswap opacity <20-100>');
    end
end);

----------------------------------------------------------------------------------------------------
-- Packets
----------------------------------------------------------------------------------------------------
ashita.events.register('packet_in', 'neoswap_packet_in_cb', function(e)
    local id = e.id;
    if id == 0x01E or id == 0x01F or id == 0x020 or id == 0x01D or id == 0x01C or id == 0x050 or id == 0x116 then
        bags.invalidate();
    elseif id == 0x00A then
        bags.invalidate();
        pcall(commands.on_zone);
    elseif id == 0x01B then
        bags.invalidate();
    end
    local ok, er = pcall(engine.on_packet_in, e);
    if not ok and config.get('debug') then err('packet_in: ' .. tostring(er)); end
end);

ashita.events.register('packet_out', 'neoswap_packet_out_cb', function(e)
    local ok, er = pcall(engine.on_packet_out, e);
    if not ok then
        -- never leave an action held back because of an error
        err('Swap error: ' .. tostring(er));
        engine.action = nil;
    end
end);

----------------------------------------------------------------------------------------------------
-- The controller
----------------------------------------------------------------------------------------------------
ashita.events.register('xinput_button', 'neoswap_xbtn_cb', function(e) pcall(pad.on_xinput_button, e); end);
ashita.events.register('dinput_button', 'neoswap_dbtn_cb', function(e) pcall(pad.on_dinput_button, e); end);
ashita.events.register('xinput_state', 'neoswap_xstate_cb', function(e) pcall(pad.on_xinput_state, e); end);

----------------------------------------------------------------------------------------------------
-- Every frame
----------------------------------------------------------------------------------------------------
ashita.events.register('d3d_present', 'neoswap_present_cb', function()
    if not game.logged_in() then return; end
    if not ensure_loaded() then return; end
    pcall(engine.tick);
    pcall(commands.tick);
    pcall(pad.tick);
    pcall(store.tick);
    ui.draw();
    pcall(buttons.draw);
    settings_window.draw();
end);

ashita.events.register('unload', 'neoswap_unload_cb', function()
    if store.dirty_at then store.save_now(); end
    items.unload();
    tex.unload();
end);

print(chat.header(addon.name) .. chat.success('v' .. addon.version .. ' loaded. /nswap shows the window, /nswap config the settings.'));
