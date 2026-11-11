-- buttons.lua : on-screen buttons for your own commands. A command with "Button on screen" on gets a small pill
-- you can put anywhere: click it to run the command (click again while it runs to stop it), drag it to move it.
-- Your job's command buttons show while you're on that job; a custom entry's show on every job.
-- Where each one sits is kept with the command (cmd.button = { on, x, y, label }).
local imgui    = require('imgui');
local theme    = require('ui.theme');
local config   = require('configs.config');
local store    = require('core.store');
local commands = require('core.commands');
local jobs     = require('core.jobs');
local icon_pick = require('ui.icon_pick');
local C, u32, tw = theme.C, theme.u32, theme.tw;
local NEON, NEON2 = theme.NEON, theme.NEON2;

local buttons = {};

local drag = nil;          -- { key, sx, sy, wx, wy, moved }
local DRAG_START = 5;      -- pixels before a press becomes a move

local FLAGS = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_AlwaysAutoResize,
    ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse, ImGuiWindowFlags_NoCollapse,
    ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoSavedSettings,
    ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoBackground);

local function xy(a, b) if type(a) == 'table' then return a.x or a[1], a.y or a[2]; end return a, b; end

-- The commands that have a button right now: { owner, cmd }
function buttons.list()
    local out = {};
    local cur = jobs.ABBR[jobs.main()];
    local function add(owner)
        for _, c in ipairs(commands.list(owner)) do
            if c.button and c.button.on then out[#out + 1] = { owner = owner, cmd = c }; end
        end
    end
    if cur then add(cur); end
    for _, e in ipairs(store.entries()) do add(e.key); end
    return out;
end

function buttons.label(cmd)
    local l = cmd.button and tostring(cmd.button.label or '') or '';
    if l == '' then l = tostring(cmd.name or 'Command'); end
    return l;
end

-- A new button goes just under the NeoSwap window, beside the ones already out
function buttons.turn_on(cmd)
    cmd.button = cmd.button or {};
    cmd.button.on = true;
    if cmd.button.x == nil then
        local n = #buttons.list();
        -- just under the NeoSwap window, where you'll see it
        local wx, wy = tonumber(config.get('win_x')) or 140, tonumber(config.get('win_y')) or 110;
        local wh = tonumber(config.get('win_h')) or 740;
        cmd.button.x = math.floor(wx + 20 + (n % 6) * 130);
        cmd.button.y = math.floor(wy + wh + 12 + math.floor(n / 6) * 40);
    end
    store.touch();
end

local function one(b)
    local cmd, owner = b.cmd, b.owner;
    local key = owner .. '_' .. tostring(cmd.id);
    local label = buttons.label(cmd);
    local running = commands.running() == cmd;
    local as_icon = cmd.button.style == 'icon';
    local h = as_icon and 44 or (imgui.GetTextLineHeight() + 14);
    local w = as_icon and 44 or math.max(h + 6, tw(label) + 28);

    imgui.SetNextWindowPos({ tonumber(cmd.button.x) or 200, tonumber(cmd.button.y) or 200 }, ImGuiCond_Always);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0);
    if imgui.Begin('##nsbtn_' .. key, { true }, FLAGS) then
      local ok, e = pcall(function()
        local x, y = imgui.GetCursorScreenPos();
        imgui.InvisibleButton('##nsbtn_hit_' .. key, { w, h });
        local hov, active = imgui.IsItemHovered(), imgui.IsItemActive();
        local locked = config.get('buttons_locked') == true;

        -- press / drag / release
        if active and (drag == nil or drag.key ~= key) then
            local mx, my = xy(imgui.GetMousePos());
            drag = { key = key, sx = mx, sy = my, wx = tonumber(cmd.button.x) or x, wy = tonumber(cmd.button.y) or y, moved = false };
        end
        if drag and drag.key == key then
            local mx, my = xy(imgui.GetMousePos());
            if active then
                if not locked and not drag.moved and (math.abs(mx - drag.sx) > DRAG_START or math.abs(my - drag.sy) > DRAG_START) then drag.moved = true; end
                if drag.moved then
                    cmd.button.x = math.floor(drag.wx + mx - drag.sx);
                    cmd.button.y = math.floor(drag.wy + my - drag.sy);
                end
            else
                if drag.moved then store.touch();
                elseif hov then
                    if running then commands.stop();
                    else commands.start(owner, cmd); end
                end
                drag = nil;
            end
        end

        -- the pill
        local dl = imgui.GetWindowDrawList();
        local lit = running or (active and not (drag and drag.moved));
        local bg = lit and { NEON[1] * 0.45, NEON[2] * 0.45, NEON[3] * 0.45, 0.95 }
            or (hov and { 0.16, 0.15, 0.21, 0.95 } or { C.pbg[1], C.pbg[2], C.pbg[3], 0.88 });
        local r = as_icon and 9 or h / 2;
        dl:AddRectFilled({ x, y }, { x + w, y + h }, u32(bg), r);
        local edge = running and NEON2 or NEON;
        if as_icon then
            icon_pick.draw(dl, cmd.button.icon, x + 6, y + 6, 32, 1, cmd.name);
            if lit then dl:AddRectFilled({ x, y }, { x + w, y + h }, u32({ NEON[1], NEON[2], NEON[3], 0.18 }), r); end
        else
            local tx = x + (w - tw(label)) / 2;
            dl:AddText({ tx, y + (h - imgui.GetTextLineHeight()) / 2 }, u32({ 1, 1, 1, 1 }), label);
        end
        dl:AddRect({ x, y }, { x + w, y + h }, u32({ edge[1], edge[2], edge[3], (hov or running) and 0.95 or 0.55 }), r, C.rall, 1.5);
        if running then
            local t = os.clock() * 4;
            dl:AddCircleFilled(as_icon and { x + w - 7, y + 7 } or { x + 9, y + h / 2 }, 2.5 + math.sin(t) * 0.8, u32(NEON2), 12);
        end
        if hov and not (drag and drag.moved) then
            local a = tostring(cmd.alias or '');
            theme.tip((cmd.name or '') .. (a ~= '' and ('  (' .. a .. ')') or '') .. '\n\n' ..
                (running and 'Click: stop it' or 'Click: run it') ..
                (locked and '\n(Buttons are locked: /nswap buttons unlock to move them)' or '\nDrag: move it'));
        end
      end);
      if not ok and not buttons._err then buttons._err = true; print('[NeoSwap] button error: ' .. tostring(e)); end
    end
    imgui.End();
    imgui.PopStyleVar(2);
end

function buttons.draw()
    if config.get('buttons_shown') == false then return; end
    local list = buttons.list();
    if #list == 0 then return; end
    local nc, nv = theme.push(1, nil, { 0, 0 });
    for _, b in ipairs(list) do
        one(b);
    end
    theme.pop(nc, nv);
end

return buttons;
