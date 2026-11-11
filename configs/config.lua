-- config.lua : NeoSwap window and engine settings (saved per character by Ashita's settings module).
-- Your gear sets are kept apart from these, in config\addons\neoswap\<Name>_<id>\sets.lua (core/store.lua).
local default_settings = T{
    -- windows
    show_gui        = true;
    show_config_gui = false;
    win_x           = 140;
    win_y           = 110;
    win_w           = 1180;
    win_h           = 740;
    cfg_x           = 1000;
    cfg_y           = 140;
    cfg_tab         = 'general';  -- 'general', 'timing', 'controller', 'commands'
    minimized       = false;      -- shown as the small NSWP bubble
    mini_x          = 60;
    mini_y          = 360;

    -- look
    opacity         = 1.0;        -- 0.2 to 1.0
    fade_text       = false;      -- false: only the background fades

    -- what the window shows
    view_job        = 0;          -- the job picked in the rail (0: follow your main job)
    follow_job      = true;       -- the rail jumps to your job when you change job

    -- on-screen command buttons (ui/buttons.lua)
    buttons_shown   = true;       -- show them
    buttons_locked  = false;      -- true: they can't be dragged

    -- the engine
    engine_on       = true;       -- swap gear (off: NeoSwap only edits sets)
    debug           = false;      -- print every swap in chat
    swap_in_town    = true;       -- (reserved)
    unload_lac      = false;      -- unload LuAshitacast when NeoSwap loads (they would both swap)

    -- the controller (as NeoMOG)
    pad_enabled     = false;
    pad_block       = true;       -- while NeoSwap has the controller, the game doesn't get its buttons
    pad = T{
        -- toggle is a combo (every button held together). The rest: any of the listed buttons.
        -- x<n> = XInput button bit n (0 up, 1 down, 2 left, 3 right, 4 Start, 5 Back, 8 LB, 9 RB, 12 A, 13 B, 14 X, 15 Y)
        -- d<n> = DirectInput button (48 + n); pu / pd / pl / pr = a DirectInput D-pad (POV)
        toggle   = T{};
        up       = T{ 'x0', 'pu' };
        down     = T{ 'x1', 'pd' };
        left     = T{ 'x2', 'pl' };
        right    = T{ 'x3', 'pr' };
        ok       = T{ 'x12', 'd49' };
        back     = T{ 'x13', 'd50' };
        alt      = T{ 'x14', 'd48' };
        tab_prev = T{ 'x8', 'd52' };
        tab_next = T{ 'x9', 'd53' };
    };

    -- timing (seconds) - the same defaults as LuAshitacast
    fast_cast       = 0;          -- your Fast Cast %, shortens how long a spell's midcast set is held
    snapshot        = 0;          -- your Snapshot %, the same for ranged attacks
    spell_offset    = 1.0;
    ws_delay        = 3.0;
    ja_delay        = 2.5;
    ranged_base     = 10.0;
    ranged_offset   = 0.5;
    item_base       = 8.0;
    item_offset     = 1.0;
    pet_delay       = 4.0;
};

local settings = require('settings');
local config_data = settings.load(default_settings);

settings.register('settings', 'neoswap_settings_update', function (s)
    if (s ~= nil) then
        config_data = s;
    end
    settings.save();
end);

local config = { defaults = default_settings };

function config.get(key)
    local v = config_data[key];
    if v == nil then return default_settings[key]; end
    return v;
end

function config.num(key)
    return tonumber(config.get(key)) or tonumber(default_settings[key]) or 0;
end

function config.set(key, value)
    config_data[key] = value;
    settings.save();
end

function config.toggle(key)
    local v = config.get(key);
    if type(v) == 'boolean' then
        config_data[key] = not v;
        settings.save();
        return config_data[key];
    end
    return nil;
end

function config.save()
    settings.save();
end

function config.raw()
    return config_data;
end

-- A table setting that is always there (created from the defaults if a saved file lacks it)
function config.tbl(key)
    local v = config_data[key];
    if type(v) ~= 'table' then
        v = T{};
        local d = default_settings[key];
        if type(d) == 'table' then for k, x in pairs(d) do v[k] = x; end end
        config_data[key] = v;
    end
    return v;
end

return config;
