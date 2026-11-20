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
local SNAP_RANGE = 18;     -- how close (pixels) a dragged button has to come to another to snap to it
local SNAP_GAP   = 4;      -- the gap left between snapped buttons
local rects = {};          -- where each button was last drawn: [key] = { x, y, w, h, frame }
local frame = 0;           -- (a button drawn this frame or the one before counts; the first one drawn needs the last frame's)

-- The best place to snap a w x h button at (x, y) to, next to one of the others: { x, y, target, side } or nil.
-- Beside one (left / right): lined up by top, centre or bottom. Above / below one: lined up by left, centre or right.
local function find_snap(key, x, y, w, h)
    if config.get('buttons_snap') == false then return nil; end
    local best, best_d = nil, nil;
    local function try(nx, ny, tk, side)
        local d = math.abs(nx - x) + math.abs(ny - y);
        if math.abs(nx - x) <= SNAP_RANGE and math.abs(ny - y) <= SNAP_RANGE and (best_d == nil or d < best_d) then
            best, best_d = { x = math.floor(nx + 0.5), y = math.floor(ny + 0.5), target = tk, side = side }, d;
        end
    end
    for k, o in pairs(rects) do
        if k ~= key and (o.frame or -9) >= frame - 1 then
            local rows = { o.y, o.y + (o.h - h) / 2, o.y + o.h - h };            -- tops, centres, bottoms lined up
            local cols = { o.x, o.x + (o.w - w) / 2, o.x + o.w - w };            -- lefts, centres, rights lined up
            for _, ny in ipairs(rows) do
                try(o.x + o.w + SNAP_GAP, ny, k, 'right');
                try(o.x - w - SNAP_GAP, ny, k, 'left');
            end
            for _, nx in ipairs(cols) do
                try(nx, o.y + o.h + SNAP_GAP, k, 'below');
                try(nx, o.y - h - SNAP_GAP, k, 'above');
            end
        end
    end
    return best;
end

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
        rects[key] = { x = x, y = y, w = w, h = h, frame = frame };
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
                    drag.snap = find_snap(key, cmd.button.x, cmd.button.y, w, h);
                    drag.w, drag.h = w, h;
                end
            else
                if drag.moved then
                    if drag.snap then cmd.button.x, cmd.button.y = drag.snap.x, drag.snap.y; end   -- (let go on a snap: line it up)
                    store.touch();
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

-- While a button is dragged near another: where it'll snap to (a dashed outline) and the edge it'll sit against.
-- Drawn in a window of its own over both, which takes no clicks.
local OVERLAY_FLAGS = bit.bor(FLAGS, ImGuiWindowFlags_NoInputs);
local function draw_snap()
    local sn = drag and drag.moved and drag.snap;
    local o = sn and rects[sn.target];
    if not (sn and o) then return; end
    local w, h = drag.w or 40, drag.h or 30;
    local x1, y1 = math.min(sn.x, o.x) - 6, math.min(sn.y, o.y) - 6;
    local x2, y2 = math.max(sn.x + w, o.x + o.w) + 6, math.max(sn.y + h, o.y + o.h) + 6;
    imgui.SetNextWindowPos({ x1, y1 }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ x2 - x1, y2 - y1 }, ImGuiCond_Always);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0);
    if imgui.Begin('##nsbtn_snap', { true }, bit.band(OVERLAY_FLAGS, bit.bnot(ImGuiWindowFlags_AlwaysAutoResize))) then
        local dl = imgui.GetWindowDrawList();
        local col = u32({ NEON2[1], NEON2[2], NEON2[3], 0.9 });
        -- the spot, dashed
        local function dash(ax, ay, bx, by)
            local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2);
            local n = math.max(1, math.floor(len / 6));
            for i = 0, n - 1, 2 do
                local t1, t2 = i / n, math.min(1, (i + 1) / n);
                dl:AddLine({ ax + (bx - ax) * t1, ay + (by - ay) * t1 }, { ax + (bx - ax) * t2, ay + (by - ay) * t2 }, col, 1.5);
            end
        end
        dl:AddRectFilled({ sn.x, sn.y }, { sn.x + w, sn.y + h }, u32({ NEON2[1], NEON2[2], NEON2[3], 0.12 }), 6);
        dash(sn.x, sn.y, sn.x + w, sn.y); dash(sn.x + w, sn.y, sn.x + w, sn.y + h);
        dash(sn.x + w, sn.y + h, sn.x, sn.y + h); dash(sn.x, sn.y + h, sn.x, sn.y);
        -- the other button's edge it'll sit against
        local ec = u32({ NEON2[1], NEON2[2], NEON2[3], 1 });
        if sn.side == 'right' then dl:AddLine({ o.x + o.w + 1, o.y + 2 }, { o.x + o.w + 1, o.y + o.h - 2 }, ec, 3);
        elseif sn.side == 'left' then dl:AddLine({ o.x - 1, o.y + 2 }, { o.x - 1, o.y + o.h - 2 }, ec, 3);
        elseif sn.side == 'below' then dl:AddLine({ o.x + 2, o.y + o.h + 1 }, { o.x + o.w - 2, o.y + o.h + 1 }, ec, 3);
        else dl:AddLine({ o.x + 2, o.y - 1 }, { o.x + o.w - 2, o.y - 1 }, ec, 3); end
    end
    imgui.End();
    imgui.PopStyleVar(2);
end

function buttons.draw()
    if config.get('buttons_shown') == false then return; end
    local list = buttons.list();
    if #list == 0 then return; end
    frame = frame + 1;                                                   -- (only the buttons out now count for snapping)
    local nc, nv = theme.push(1, nil, { 0, 0 });
    for _, b in ipairs(list) do
        one(b);
    end
    pcall(draw_snap);
    theme.pop(nc, nv);
end

return buttons;
