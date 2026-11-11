-- commands.lua : your own commands, per job: a list of steps NeoSwap runs one after the other - cast a spell, use
-- an ability, wait, wait for your pet, wear a set and hold it, send any command - each step with an optional
-- "only when" condition. Run one with its own slash word (/siphon), /nswap run <name>, or the window's Run button.
--
-- Text in a step can use: {spirit} the elemental spirit for the weather (or, with no elemental weather, the day),
-- {element} that element, {day} the day's element, {weather} the weather's element, {pet} your pet's name.
--
-- job.commands = { { id, name, alias = '/siphon', steps = { { t, v, target, n, cond = { t, v, n, neg } } } } }
local chat   = require('chat');
local store  = require('core.store');
local rules  = require('core.rules');
local game   = require('core.game');
local jobs   = require('core.jobs');

local commands = {};

-- The step kinds. arg: what it takes ('text' + target, 'secs', 'set', 'cond')
commands.STEPS = {
    { key = 'cast',     label = 'Cast a spell',        arg = 'text', target = true, hint = 'Sends /ma "<spell>" <target>. {spirit} = the spirit for the weather or day.' },
    { key = 'ja',       label = 'Use an ability',      arg = 'text', target = true, hint = 'Sends /ja "<ability>" <target>.' },
    { key = 'ws',       label = 'Use a weapon skill',  arg = 'text', target = true, hint = 'Sends /ws "<weapon skill>" <target>.' },
    { key = 'item',     label = 'Use an item',         arg = 'text', target = true, hint = 'Sends /item "<item>" <target>.' },
    { key = 'say',      label = 'Send a command',      arg = 'line', hint = 'Any command, as you\'d type it (/echo, /equip, /lockstyleset...).' },
    { key = 'wait',     label = 'Wait',                arg = 'secs', def = 2, hint = 'Wait this many seconds.' },
    { key = 'pet_out',  label = 'Wait for my pet',     arg = 'secs', def = 20, hint = 'Wait until a pet is out (at most this long; then the command stops).' },
    { key = 'pet_gone', label = 'Wait for no pet',     arg = 'secs', def = 5,  hint = 'Wait until your pet is gone (at most this long).' },
    { key = 'wear',     label = 'Wear a set',          arg = 'set',  hint = 'Put on one of this job\'s sets and hold it until the command ends.' },
    { key = 'mode',     label = 'Switch a mode',       arg = 'mode', hint = 'Turn a mode on, off, or the other way (sets with "Mode is on" follow it).' },
    { key = 'cycle',    label = 'Cycle modes',         arg = 'cycle', hint = 'Modes in a row (Normal, PDT, MDT): turns the next one on and the others off. From the last it goes back to the first.' },
    { key = 'entry',    label = 'Switch an entry',     arg = 'entry', hint = 'Turn one of your custom entries (HELM...) on, off, or the other way.' },
    { key = 'stop',     label = 'Stop unless',         arg = 'cond', hint = 'End the command here unless something is true (MP at least 50%, pet out...).' },
};
commands.BY_STEP = {};
for _, s in ipairs(commands.STEPS) do commands.BY_STEP[s.key] = s; end
commands.TARGETS = { '<me>', '<t>', '<bt>', '<stpc>', '<stpt>', '<st>', '<pet>' };

local SPIRIT = { Fire = 'Fire Spirit', Ice = 'Ice Spirit', Wind = 'Air Spirit', Earth = 'Earth Spirit', Thunder = 'Thunder Spirit',
                 Water = 'Water Spirit', Light = 'Light Spirit', Dark = 'Dark Spirit' };

local function say(msg) print(chat.header('NeoSwap') .. chat.message(msg)); end
local function err(msg) print(chat.header('NeoSwap') .. chat.error(msg)); end

----------------------------------------------------------------------------------------------------
-- The words in {braces}
----------------------------------------------------------------------------------------------------
function commands.fill(text)
    text = tostring(text or '');
    if not text:find('{', 1, true) then return text; end
    local v = game.vana();
    local w = game.weather_element();
    local el = (SPIRIT[w] and w) or v.day_element;
    local pet = game.pet();
    text = text:gsub('{spirit}', SPIRIT[el or ''] or 'Light Spirit')
               :gsub('{element}', el or '')
               :gsub('{day}', v.day_element or '')
               :gsub('{weather}', w or '')
               :gsub('{pet}', pet and pet.name or '');
    return text;
end

----------------------------------------------------------------------------------------------------
-- Data
----------------------------------------------------------------------------------------------------
function commands.list(abbr)
    local j = store.job(abbr);
    if j == nil then return {}; end
    j.commands = j.commands or {};
    return j.commands;
end

function commands.find(abbr, id)
    for i, c in ipairs(commands.list(abbr)) do if c.id == id then return c, i; end end
    return nil;
end

function commands.by_alias(abbr, word)
    word = tostring(word or ''):lower();
    if word == '' then return nil; end
    for _, c in ipairs(commands.list(abbr)) do
        local a = tostring(c.alias or ''):lower();
        if a ~= '' and (a == word or ('/' .. a) == word) then return c; end
    end
    return nil;
end

-- A command for a typed word: your job's first, then the custom entries'. Returns the command and its owner.
function commands.find_alias(abbr, word)
    local c = abbr and commands.by_alias(abbr, word);
    if c then return c, abbr; end
    for _, e in ipairs(store.entries()) do
        c = commands.by_alias(e.key, word);
        if c then return c, e.key; end
    end
    return nil;
end

function commands.by_name(abbr, name)
    name = tostring(name or ''):lower();
    for _, c in ipairs(commands.list(abbr)) do if tostring(c.name or ''):lower() == name then return c; end end
    return commands.by_alias(abbr, name);
end

function commands.new(abbr, from)
    local j = store.job(abbr, true);
    j.commands = j.commands or {};
    local c = from and store.copy(from) or { name = 'New command', alias = '', steps = {} };
    c.button = nil;                                                -- (a copy starts without a button)
    c.id = store.data.next_id;
    store.data.next_id = store.data.next_id + 1;
    j.commands[#j.commands + 1] = c;
    store.touch();
    return c;
end

function commands.remove(abbr, id)
    local _, i = commands.find(abbr, id);
    if i then table.remove(commands.list(abbr), i); store.touch(); end
end

-- Ready-made commands
commands.TEMPLATES = {
    {
        name = 'Elemental Siphon', job = 'SMN', alias = '/siphon',
        hint = 'Calls the spirit for the weather (or the day), wears your Siphon set, uses Elemental Siphon, then releases the spirit.',
        steps = {
            { t = 'ja', v = 'Release', target = '<me>', cond = { t = 'pet_out' } },
            { t = 'pet_gone', n = 5 },
            { t = 'cast', v = '{spirit}', target = '<me>' },
            { t = 'pet_out', n = 20 },
            { t = 'wait', n = 2 },
            { t = 'wear', v = 'Siphon' },
            { t = 'wait', n = 1 },
            { t = 'ja', v = 'Elemental Siphon', target = '<me>' },
            { t = 'wait', n = 3 },
            { t = 'ja', v = 'Release', target = '<me>' },
        },
    },
    {
        name = 'Spirit for the day', job = 'SMN', alias = '/spirit',
        hint = 'Calls the elemental spirit for the weather (or the day).',
        steps = { { t = 'cast', v = '{spirit}', target = '<me>' } },
    },
};

----------------------------------------------------------------------------------------------------
-- Running one
----------------------------------------------------------------------------------------------------
local run = nil;                                                      -- { cmd, abbr, i, until_t, held = { slots } }
commands.engine = nil;                                                -- (set by neoswap.lua: core.engine)

function commands.running() return run and run.cmd or nil, run and run.i or 0; end

local function finish(msg, bad)
    if run == nil then return; end
    local eng = commands.engine;
    if eng then for _, s in ipairs(run.held or {}) do eng.disabled[s] = false; end end
    if msg then if bad then err(msg); else say(msg); end end
    run = nil;
end

function commands.stop(msg) finish(msg or 'Command stopped.'); end

function commands.start(abbr, cmd)
    if run then finish(nil); end
    if cmd == nil or #(cmd.steps or {}) == 0 then err('That command has no steps.'); return false; end
    run = { cmd = cmd, abbr = abbr, i = 1, until_t = nil, held = {} };
    return true;
end

local function queue(line) AshitaCore:GetChatManager():QueueCommand(1, line); end

-- One step; returns true when it's done (go on), false to come back next frame
local function step(s)
    local eng = commands.engine;
    local now = os.clock();
    local t = s.t;
    if t == 'cast' or t == 'ja' or t == 'ws' or t == 'item' then
        local verb = ({ cast = '/ma', ja = '/ja', ws = '/ws', item = '/item' })[t];
        local what = commands.fill(s.v);
        if what == '' then return true; end
        queue(string.format('%s "%s" %s', verb, what, s.target or '<me>'));
        return true;
    elseif t == 'say' then
        local line = commands.fill(s.v);
        if line ~= '' then queue(line); end
        return true;
    elseif t == 'wait' then
        if run.until_t == nil then run.until_t = now + (tonumber(s.n) or 1); end
        if now >= run.until_t then run.until_t = nil; return true; end
        return false;
    elseif t == 'pet_out' or t == 'pet_gone' then
        if run.until_t == nil then run.until_t = now + (tonumber(s.n) or 10); end
        local p = game.pet();
        if (t == 'pet_out' and p ~= nil) or (t == 'pet_gone' and p == nil) then run.until_t = nil; return true; end
        if now >= run.until_t then
            run.until_t = nil;
            if t == 'pet_out' then finish('"' .. run.cmd.name .. '": no pet came out; stopped.', true); return false; end
            return true;
        end
        return false;
    elseif t == 'wear' then
        local set = eng and store.find_by_name(run.abbr, s.v);
        if set == nil then say('"' .. run.cmd.name .. '": no ' .. run.abbr .. ' set called "' .. tostring(s.v) .. '" - skipped.'); return true; end
        local before = {};
        for i = 1, 16 do before[i] = eng.disabled[i]; end
        eng.wear(set, true);
        for i = 1, 16 do if eng.disabled[i] and not before[i] then run.held[#run.held + 1] = i; end end
        return true;
    elseif t == 'mode' then
        local name = commands.fill(s.v or '');
        if name == '' then return true; end
        local on = (s.w == 'on') or (s.w ~= 'off' and not store.mode(name));
        store.set_mode(name, on);
        say('Mode ' .. name .. ': ' .. (on and 'on' or 'off') .. '.');
        return true;
    elseif t == 'cycle' then
        local name = commands.cycle(s.v);
        if name then say('Mode: ' .. name .. '.'); end
        return true;
    elseif t == 'entry' then
        local en = store.entry_by_name(s.v or '');
        if en == nil then say('"' .. run.cmd.name .. '": no custom entry called "' .. tostring(s.v) .. '" - skipped.'); return true; end
        en.active = (s.w == 'on') or (s.w ~= 'off' and not en.active);
        store.touch();
        say(en.name .. ': ' .. (en.active and 'on.' or 'off.'));
        return true;
    elseif t == 'stop' then
        local ok, res = pcall(rules.cond_ok, s.cond or {}, eng.make_ctx());
        if not (ok and res) then finish('"' .. run.cmd.name .. '" stopped: ' .. rules.cond_text(s.cond or {}) .. ' is not true.'); return false; end
        return true;
    end
    return true;
end

-- Modes in a row ("Normal, PDT, MDT"): the one after the mode that's on goes on, the others off. Returns its name.
function commands.cycle_list(text)
    local list = {};
    for w in tostring(text or ''):gmatch('[^,]+') do
        w = w:gsub('^%s+', ''):gsub('%s+$', '');
        if w ~= '' then list[#list + 1] = w; end
    end
    return list;
end
function commands.cycle(text)
    local list = commands.cycle_list(text);
    if #list == 0 then return nil; end
    local at = 0;
    for i, m in ipairs(list) do if store.mode(m) then at = i; end end
    local nxt = list[(at % #list) + 1];
    for _, m in ipairs(list) do if m:lower() ~= nxt:lower() and store.mode(m) then store.set_mode(m, false); end end
    store.set_mode(nxt, true);
    return nxt;
end

function commands.tick()
    if run == nil then return; end
    if not store.is_entry(run.abbr) and jobs.ABBR[jobs.main()] ~= run.abbr then finish('Command stopped (job changed).'); return; end
    -- after a sent command, a beat before the next step (the game needs a moment between actions)
    if run.pause_until and os.clock() < run.pause_until then return; end
    run.pause_until = nil;
    local guard = 0;
    while run and guard < 20 do                                       -- (instant steps run in the same frame)
        guard = guard + 1;
        local s = run.cmd.steps[run.i];
        if s == nil then finish(nil); return; end
        local go = true;
        if s.cond and s.t ~= 'stop' and s.cond.t then
            local ok, res = pcall(rules.cond_ok, s.cond, commands.engine.make_ctx());
            go = ok and res;
        end
        if go then
            local ok, done = pcall(step, s);
            if not ok then finish('"' .. run.cmd.name .. '" step ' .. run.i .. ': ' .. tostring(done), true); return; end
            if not done or run == nil then return; end
            run.i = run.i + 1;
            if s.t == 'cast' or s.t == 'ja' or s.t == 'ws' or s.t == 'item' or s.t == 'say' then
                local nx = run.cmd.steps[run.i];
                if nx and nx.t ~= 'wait' then run.pause_until = os.clock() + 1.0; end
                return;
            end
        else
            run.i = run.i + 1;
        end
    end
end

function commands.on_zone() if run then finish('Command stopped (zoning).'); end end

return commands;
