-- pad.lua : the controller. XInput (Xbox) and DirectInput (PlayStation and others) buttons, the bindings you set
-- in the Controller settings tab, and the open / close combo. (NeoMOG's, with NeoSwap's actions.)
--
-- Button ids (the same as YunaUI's): x<n> = XInput button bit n (0 D-pad up, 1 down, 2 left, 3 right, 4 Start,
-- 5 Back, 6 / 7 stick clicks, 8 LB, 9 RB, 12 A, 13 B, 14 X, 15 Y); d<n> = DirectInput button n (48 + the button's
-- number); pu / pd / pl / pr = a DirectInput D-pad (its angle, read as four buttons).
local ffi    = require('ffi');
local config = require('configs.config');

local pad = {};

pcall(ffi.cdef, [[
    typedef struct { uint16_t wButtons; uint8_t bLeftTrigger; uint8_t bRightTrigger; int16_t sThumbLX, sThumbLY, sThumbRX, sThumbRY; } NEOSWAP_XPAD;
    typedef struct { uint32_t dwPacketNumber; NEOSWAP_XPAD Gamepad; } NEOSWAP_XSTATE;
]]);

-- What can be bound, in the order the settings show them
pad.ACTIONS = {
    { 'toggle',   'Open / minimize NeoSwap', 'Opens the window; pressed again, minimizes it to the NSWP bubble.\nOne button, or two held together (such as Back + Start). Pick something the game doesn\'t use.', true },
    { 'up',       'Up' },
    { 'down',     'Down' },
    { 'left',     'Left' },
    { 'right',    'Right' },
    { 'ok',       'Confirm',      'Pick the highlighted thing: a job, a set (opens it), a slot (lists its gear), a piece (puts it in the slot).' },
    { 'back',     'Back',         'One step back: piece list > slots > sets > jobs; from the jobs, minimize NeoSwap.' },
    { 'alt',      'Second action', 'On a set: Equip now. On a command: Run. On a slot: empty it.' },
    { 'tab_prev', 'Sets tab',     'Show the job\'s sets.' },
    { 'tab_next', 'Commands tab', 'Show the job\'s commands.' },
};

local XNAME = { [0] = 'D-pad up', [1] = 'D-pad down', [2] = 'D-pad left', [3] = 'D-pad right', [4] = 'Start', [5] = 'Back',
                [6] = 'Left stick', [7] = 'Right stick', [8] = 'LB', [9] = 'RB', [12] = 'A', [13] = 'B', [14] = 'X', [15] = 'Y' };
local PNAME = { pu = 'D-pad up', pd = 'D-pad down', pl = 'D-pad left', pr = 'D-pad right' };

function pad.button_name(id)
    if PNAME[id] then return PNAME[id] .. ' (DInput)'; end
    local k, n = id:sub(1, 1), tonumber(id:sub(2)) or 0;
    if k == 'x' then return XNAME[n] or ('Button ' .. n); end
    return 'Button ' .. (n - 47);
end

function pad.binds(action)
    local p = config.get('pad');
    local v = type(p) == 'table' and p[action] or nil;
    if type(v) ~= 'table' then
        v = config.defaults.pad[action];
    end
    return v or {};
end

-- The button for an action on the pad used last (for on-screen hints): 'X', 'Button 1'... or nil
function pad.hint_button(action)
    local b = pad.binds(action);
    local want = pad.last_kind or 'x';
    for _, id in ipairs(b) do
        local k = (id:sub(1, 1) == 'x') and 'x' or 'd';
        if k == want then return pad.button_name(id); end
    end
    return b[1] and pad.button_name(b[1]) or nil;
end

function pad.bind_text(action)
    local b = pad.binds(action);
    if #b == 0 then return nil; end
    local t = {};
    for _, id in ipairs(b) do t[#t + 1] = pad.button_name(id); end
    return table.concat(t, action == 'toggle' and ' + ' or '  or  ');
end

function pad.set_binds(action, list)
    local p = config.tbl('pad');
    p[action] = T(list or {});
    config.save();
end

----------------------------------------------------------------------------------------------------
-- State
----------------------------------------------------------------------------------------------------
pad.held = {};                 -- [id] = true while held
pad.listen = nil;              -- the action being bound (waiting for a press)
pad.on_action = nil;           -- function(action): set by the window
pad.is_open = nil;             -- function(): is the window open
pad.last_input = -100;         -- os.clock() of the last button NeoSwap used
local got, listen_t = nil, 0;
local fired = false;           -- the open / close combo went off (until it's let go)
local last_fire = {};          -- [action] = os.clock(): one press seen by two drivers counts once
local repeat_ = nil;           -- { action, next } for a held direction
local xprev = 0;               -- XInput buttons last frame (from xinput_state)

function pad.enabled() return config.get('pad_enabled') == true; end
function pad.active() return pad.enabled() and pad.is_open ~= nil and pad.is_open(); end

function pad.start_listen(action)
    pad.listen, got, listen_t = action, {}, os.clock();
end
function pad.cancel_listen() pad.listen, got = nil, nil; end

local function fire(action)
    local now = os.clock();
    if now - (last_fire[action] or -9) < 0.12 then return; end
    last_fire[action] = now;
    pad.last_input = now;
    if pad.on_action then pcall(pad.on_action, action); end
    if action == 'up' or action == 'down' or action == 'left' or action == 'right' then
        repeat_ = { action = action, next = now + 0.38 };
    end
end

local function actions_for(id)
    local t = {};
    for _, a in ipairs(pad.ACTIONS) do
        if a[1] ~= 'toggle' then
            for _, b in ipairs(pad.binds(a[1])) do if b == id then t[#t + 1] = a[1]; break; end end
        end
    end
    return t;
end

-- Every button change. Returns true when the game shouldn't get it.
function pad.event(id, down)
    if not pad.enabled() and pad.listen == nil then return false; end
    if down then pad.last_kind = (id:sub(1, 1) == 'x') and 'x' or 'd'; end
    local was = pad.held[id] == true;
    pad.held[id] = down or nil;

    -- binding: every button pressed together (two at most for the combo), kept once they're all let go
    if pad.listen then
        if os.clock() - listen_t > 10 then pad.cancel_listen(); return false; end
        if down then
            local have = false;
            for _, v in ipairs(got) do if v == id then have = true; end end
            if not have and #got < (pad.listen == 'toggle' and 2 or 1) then got[#got + 1] = id; end
        else
            local any = false;
            for _, v in ipairs(got) do if pad.held[v] then any = true; end end
            if not any and #got > 0 then
                pad.set_binds(pad.listen, got);
                pad.listen, got = nil, nil;
            end
        end
        return true;
    end

    -- the open / close combo
    local combo = pad.binds('toggle');
    if #combo > 0 then
        local inC, all = false, true;
        for _, v in ipairs(combo) do
            if v == id then inC = true; end
            if not pad.held[v] then all = false; end
        end
        if inC then
            if down and all and not fired then
                fired = true;
                pad.last_input = os.clock();
                if pad.on_action then pcall(pad.on_action, 'toggle'); end
                return true;
            end
            if not down then
                local any = false;
                for _, v in ipairs(combo) do if pad.held[v] then any = true; end end
                if not any then fired = false; end
                return true;
            end
            if fired then return true; end
        end
    end

    if not pad.active() then return false; end
    local acts = actions_for(id);
    if #acts == 0 then return false; end
    if down and not was then
        for _, a in ipairs(acts) do fire(a); end
    elseif not down and repeat_ then
        for _, a in ipairs(acts) do if repeat_.action == a then repeat_ = nil; end end
    end
    return config.get('pad_block') ~= false;
end

-- Every frame: a held direction repeats
function pad.tick()
    if repeat_ == nil then return; end
    if not pad.active() then repeat_ = nil; return; end
    local still = false;
    for _, b in ipairs(pad.binds(repeat_.action)) do if pad.held[b] then still = true; end end
    if not still then repeat_ = nil; return; end
    local now = os.clock();
    if now >= repeat_.next then
        repeat_.next = now + 0.085;
        last_fire[repeat_.action] = -9;
        local a = repeat_.action;
        fire(a);
        repeat_ = { action = a, next = now + 0.085 };
    end
end

----------------------------------------------------------------------------------------------------
-- The Ashita events
----------------------------------------------------------------------------------------------------
function pad.on_xinput_button(e)
    local b, st = e.button, e.state or 0;
    if type(b) ~= 'number' then return; end
    if pad.event('x' .. b, st ~= 0) then e.blocked = true; end
end

local POV = { pu = false, pd = false, pl = false, pr = false };
function pad.on_dinput_button(e)
    local b, st = e.button, e.state or 0;
    if type(b) ~= 'number' then return; end
    if b == 32 then                                                   -- (the D-pad: an angle in hundredths of a degree, or -1)
        local a = tonumber(st) or -1;
        if a < 0 or a >= 36000 then a = -1; end
        local want = {
            pu = a >= 0 and (a >= 31500 or a <= 4500),
            pr = a >= 0 and a >= 4500 and a <= 13500,
            pd = a >= 0 and a >= 13500 and a <= 22500,
            pl = a >= 0 and a >= 22500 and a <= 31500,
        };
        local block = false;
        for k, v in pairs(want) do
            if v ~= POV[k] then
                POV[k] = v;
                if pad.event(k, v) then block = true; end
            elseif v and pad.active() and #actions_for(k) > 0 and config.get('pad_block') ~= false then
                block = true;
            end
        end
        if block then e.blocked = true; end
        return;
    end
    if b < 48 then return; end                                        -- (a stick's position, not a button)
    if pad.event('d' .. b, st >= 128) then e.blocked = true; end
end

-- XInput: some set-ups never send the button events, so the state is read too (each press counts once),
-- and while NeoSwap has the pad its buttons are taken out of what the game reads.
function pad.on_xinput_state(e)
    if e.state == nil then return; end
    local wb = 0;
    local ok = pcall(function() wb = tonumber(ffi.cast('NEOSWAP_XSTATE*', e.state).Gamepad.wButtons) or 0; end);
    if not ok then return; end
    if wb ~= xprev then
        for n = 0, 15 do
            local m = bit.lshift(1, n);
            local d, w = bit.band(wb, m) ~= 0, bit.band(xprev, m) ~= 0;
            if d ~= w and (pad.held['x' .. n] == true) ~= d then pad.event('x' .. n, d); end
        end
        xprev = wb;
    end
    if e.state_modified == nil then return; end
    local mask = 0;
    if pad.listen then
        mask = 0xFFFF;
    else
        if fired then
            for _, v in ipairs(pad.binds('toggle')) do
                local n = v:sub(1, 1) == 'x' and tonumber(v:sub(2));
                if n then mask = bit.bor(mask, bit.lshift(1, n)); end
            end
        end
        if pad.active() and config.get('pad_block') ~= false then
            for _, a in ipairs(pad.ACTIONS) do
                if a[1] ~= 'toggle' then
                    for _, v in ipairs(pad.binds(a[1])) do
                        local n = v:sub(1, 1) == 'x' and tonumber(v:sub(2));
                        if n then mask = bit.bor(mask, bit.lshift(1, n)); end
                    end
                end
            end
        end
    end
    if mask ~= 0 then
        pcall(function()
            local g = ffi.cast('NEOSWAP_XSTATE*', e.state_modified).Gamepad;
            g.wButtons = bit.band(g.wButtons, bit.bnot(mask));
        end);
    end
end

return pad;
