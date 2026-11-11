-- nav.lua : where the controller is in the window (NeoMOG's)
--   zones, left to right: rail (the jobs), list (sets or commands), grid (the equipment slots), picker (a slot's gear)
local imgui = require('imgui');
local pad   = require('core.pad');
local theme = require('ui.theme');
local u32 = theme.u32;

local nav = { zone = 'rail', rail = 1, row = 1, eq = 1, prow = 1, moved = false, pick = false };

-- Show the controller's highlight: the pad is on, the window open, and the pad used in the last 30 seconds
-- (or the keyboard's Esc was used in the last 30 seconds: it moves the same cursor)
nav.kb_at = -100;
function nav.shown()
    local open = pad.is_open ~= nil and pad.is_open();
    if not open then return false; end
    if pad.enabled() and os.clock() - pad.last_input < 30 then return true; end
    return os.clock() - nav.kb_at < 30;
end

function nav.is(zone) return nav.shown() and nav.zone == zone; end

-- The mouse hasn't moved since the last button: the controller's highlight gets the tooltip, not the mouse
local mx0, my0, at = nil, nil, -1;
function nav.mouse_quiet()
    local mx, my = imgui.GetMousePos();
    if type(mx) == 'table' then mx, my = mx.x or mx[1], mx.y or mx[2]; end
    if pad.last_input ~= at then at, mx0, my0 = pad.last_input, mx, my; end
    return mx == mx0 and my == my0;
end

-- Put the next tooltip beside a highlighted thing (x1..x2, from y): to its right, or its left near the screen edge
function nav.tip_beside(x1, y1, x2)
    local dw = 1920;
    pcall(function()
        local io = imgui.GetIO();
        local d = io.DisplaySize;
        dw = (type(d) == 'table' and (d.x or d[1])) or dw;
    end);
    local x = x2 + 12;
    if x + 410 > dw then x = x1 - 422; end
    imgui.SetNextWindowPos({ math.max(0, x), y1 }, ImGuiCond_Always);
end

-- A breathing neon outline round something the controller is on
function nav.ring(dl, x1, y1, x2, y2, r)
    local p = 0.5 + 0.5 * math.sin(os.clock() * 5);
    local c = theme.NEON2;
    dl:AddRect({ x1 - 2, y1 - 2 }, { x2 + 2, y2 + 2 }, u32({ c[1], c[2], c[3], 0.55 + 0.45 * p }), (r or 6) + 2, theme.C.rall, 2);
    dl:AddRect({ x1 - 4, y1 - 4 }, { x2 + 4, y2 + 4 }, u32({ c[1], c[2], c[3], 0.12 + 0.12 * p }), (r or 6) + 4, theme.C.rall, 2);
end

function nav.circle(dl, cx, cy, r)
    local p = 0.5 + 0.5 * math.sin(os.clock() * 5);
    local c = theme.NEON2;
    dl:AddCircle({ cx, cy }, r + 3, u32({ c[1], c[2], c[3], 0.55 + 0.45 * p }), 40, 2);
    dl:AddCircle({ cx, cy }, r + 6, u32({ c[1], c[2], c[3], 0.12 + 0.12 * p }), 40, 2);
end

return nav;
