-- theme.lua : the YunaUI look (the same palette and controls as NeoCrafty, NeoMOG and NeoPoints)
-- Dark violet panel, lavender accents, pink-to-violet neon, pill switches and choices, glowing bars.
local imgui  = require('imgui');
local config = require('configs.config');

local theme = {};

local C = {
    text   = { 0.910, 0.922, 0.957, 1.00 },
    muted  = { 0.545, 0.576, 0.667, 1.00 },
    acc    = { 0.74, 0.66, 0.95, 1.00 },                             -- soft lavender
    pbg    = { 0.068, 0.066, 0.088, 1.00 },                          -- near-black with a hint of violet
    pframe = { 0.165, 0.158, 0.205, 1.00 },
    hp     = { 1.000, 0.36, 0.62, 1 }, hp2 = { 0.86, 0.24, 0.86, 1 },  -- pink to magenta
    mp     = { 0.40, 0.55, 1.00, 1 },  mp2 = { 0.62, 0.40, 1.00, 1 },  -- blue to violet
    gold   = { 1.00, 0.90, 0.58, 1 },
    good   = { 0.45, 0.90, 0.55, 1 },
    warn   = { 1.00, 0.82, 0.35, 1 },
    bad    = { 1.00, 0.42, 0.50, 1 },
    rall   = ImDrawFlags_RoundCornersAll or ImDrawCornerFlags_All or 15,
};
theme.C     = C;
theme.NEON  = { 0.86, 0.24, 0.86, 1 };
theme.NEON2 = { 1.00, 0.42, 0.72, 1 };
theme.ROW_W = 340;                                                   -- the settings panel's width
theme.bg    = 1;                                                     -- background opacity for custom-drawn fills

-- The element colours (same as PUPHQ's maneuver dots)
theme.EL = {
    Dark    = { 0.34, 0.26, 0.62, 1 },
    Light   = { 1.00, 0.98, 0.84, 1 },
    Earth   = { 0.82, 0.64, 0.28, 1 },
    Wind    = { 0.45, 0.90, 0.55, 1 },
    Fire    = { 1.00, 0.34, 0.26, 1 },
    Ice     = { 0.55, 0.88, 1.00, 1 },
    Thunder = { 0.80, 0.50, 1.00, 1 },
    Lightning = { 0.80, 0.50, 1.00, 1 },
    Water   = { 0.35, 0.55, 1.00, 1 },
};

local NEON, NEON2 = theme.NEON, theme.NEON2;
local chevron;                                                        -- (defined with the NeoCrafty additions)

-- Ashita's imgui.Text / TextColored read '%' as a format code, so text with a % in it is escaped
local function safe(s) return (tostring(s or ''):gsub('%%', '%%%%')); end

local function u32(c) return imgui.GetColorU32({ c[1], c[2], c[3], c[4] or 1 }); end
local function frac(v) return v - math.floor(v); end
local function tw(s) return (imgui.CalcTextSize(s or '')); end
theme.u32, theme.tw, theme.safe = u32, tw, safe;

-- A background colour, faded by the opacity setting
function theme.bgc(r, g, b, a) return u32({ r, g, b, (a or 1) * theme.bg }); end

local OUTLINE = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } };
function theme.outlined(dl, x, y, s, col)
    local oc = u32({ 0, 0, 0, 0.85 * (col[4] or 1) });
    for _, o in ipairs(OUTLINE) do dl:AddText({ x + o[1], y + o[2] }, oc, s); end
    dl:AddText({ x, y }, u32(col), s);
end

-- Tooltips: a dark violet card with a thin violet edge and a pink-to-violet line along the top
function theme.tip(t)
    t = tostring(t or '');
    if not (imgui.BeginTooltip and imgui.EndTooltip) then imgui.SetTooltip(t); return; end
    imgui.PushStyleVar(ImGuiStyleVar_Alpha, 1);                       -- (a faded window's tooltip stays readable)
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 6);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 7, 3 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 1);
    imgui.PushStyleColor(ImGuiCol_PopupBg, { 0.045, 0.040, 0.065, 0.96 });
    imgui.PushStyleColor(ImGuiCol_Border, { 0.62, 0.40, 1.00, 0.55 });
    imgui.PushStyleColor(ImGuiCol_Text, { 0.93, 0.92, 0.98, 1 });
    if imgui.BeginTooltip() ~= false then
        imgui.Text(safe(t));
        pcall(function()
            local dl = imgui.GetWindowDrawList();
            local wx, wy = imgui.GetWindowPos();
            local ww = imgui.GetWindowSize();
            if type(wx) == 'table' then wx, wy = wx.x or wx[1], wx.y or wx[2]; end
            if type(ww) == 'table' then ww = ww.x or ww[1]; end
            local p1, p2 = u32({ 1.0, 0.36, 0.62, 0.9 }), u32({ 0.62, 0.40, 1.0, 0.9 });
            dl:AddRectFilledMultiColor({ wx + 6, wy + 1 }, { wx + ww - 6, wy + 2 }, p1, p2, p2, p1);
        end);
        imgui.EndTooltip();
    end
    imgui.PopStyleColor(3);
    imgui.PopStyleVar(4);
end

-- bg: background opacity (0.2 to 1). alpha: fade everything (text too), or nil. pad: window padding.
function theme.push(bg, alpha, pad)
    bg = bg or 1;
    local cols = {
        { ImGuiCol_WindowBg, { C.pbg[1], C.pbg[2], C.pbg[3], 0.92 * bg } }, { ImGuiCol_ChildBg, { 0, 0, 0, 0 } },
        { ImGuiCol_PopupBg, { C.pbg[1], C.pbg[2], C.pbg[3], 0.98 } },
        { ImGuiCol_Border, { 1, 1, 1, 0.08 * bg } }, { ImGuiCol_Text, C.text }, { ImGuiCol_TextDisabled, C.muted },
        { ImGuiCol_FrameBg, { C.pframe[1], C.pframe[2], C.pframe[3], 0.70 } }, { ImGuiCol_FrameBgHovered, { 0.22, 0.21, 0.27, 1 } },
        { ImGuiCol_FrameBgActive, { 0.22, 0.21, 0.27, 1 } },
        { ImGuiCol_Button, { 1, 1, 1, 0.035 } }, { ImGuiCol_ButtonHovered, { 1, 1, 1, 0.08 } }, { ImGuiCol_ButtonActive, { 1, 1, 1, 0.12 } },
        { ImGuiCol_Separator, { 1, 1, 1, 0.07 } },
        { ImGuiCol_ScrollbarBg, { 0, 0, 0, 0 } }, { ImGuiCol_ScrollbarGrab, { 0.62, 0.40, 1.00, 0.30 } },
        { ImGuiCol_ScrollbarGrabHovered, { 0.62, 0.40, 1.00, 0.50 } }, { ImGuiCol_ScrollbarGrabActive, { 1.00, 0.42, 0.72, 0.60 } },
        { ImGuiCol_TextSelectedBg, { 0.62, 0.40, 1.00, 0.35 } },
        { ImGuiCol_ResizeGrip, { 0.62, 0.40, 1.00, 0.18 } }, { ImGuiCol_ResizeGripHovered, { 0.62, 0.40, 1.00, 0.45 } },
        { ImGuiCol_ResizeGripActive, { 1.00, 0.42, 0.72, 0.70 } },
    };
    local nc, nv = 0, 0;                                             -- (any name this ImGui doesn't have is skipped)
    for _, c in ipairs(cols) do if c[1] ~= nil then imgui.PushStyleColor(c[1], c[2]); nc = nc + 1; end end
    local vars = {
        { ImGuiStyleVar_WindowRounding, 12 }, { ImGuiStyleVar_FrameRounding, 8 },
        { ImGuiStyleVar_WindowPadding, pad or { 20, 16 } }, { ImGuiStyleVar_FramePadding, { 10, 6 } },
        { ImGuiStyleVar_ItemSpacing, { 8, 8 } }, { ImGuiStyleVar_WindowBorderSize, 1 }, { ImGuiStyleVar_FrameBorderSize, 0 },
        { ImGuiStyleVar_ScrollbarSize, 8 }, { ImGuiStyleVar_ScrollbarRounding, 4 },
    };
    if alpha ~= nil then vars[#vars + 1] = { ImGuiStyleVar_Alpha, alpha }; end
    for _, v in ipairs(vars) do if v[1] ~= nil then imgui.PushStyleVar(v[1], v[2]); nv = nv + 1; end end
    theme.bg = (alpha ~= nil) and 1 or bg;
    return nc, nv;
end

function theme.pop(nc, nv)
    imgui.PopStyleColor(nc);
    imgui.PopStyleVar(nv);
    theme.bg = 1;
end

-- Text with letter spacing (section names, column headers, buttons)
function theme.spaced(dl, x, y, str, col, gap)
    local cx = x;
    for i = 1, #str do
        local ch = str:sub(i, i);
        dl:AddText({ cx, y }, col, ch);
        cx = cx + tw(ch) + gap;
    end
    return cx - x - gap;
end
function theme.spaced_w(str, gap)
    local w = 0;
    for i = 1, #str do w = w + tw(str:sub(i, i)) + gap; end
    return w - gap;
end

-- A thin living bar: glowing edge, colours flowing along inside it, a sheen that sweeps along now and then
function theme.glow_bar(dl, x, y, w, h, v, c1, c2, seed)
    v = math.max(0, math.min(1, v or 0));
    seed = seed or 0;
    local now = os.clock();
    dl:AddRectFilled({ x, y }, { x + w, y + h }, theme.bgc(0.05, 0.04, 0.07, 0.70), h / 2);
    dl:AddRect({ x, y }, { x + w, y + h }, u32({ 1, 1, 1, 0.06 }), h / 2, C.rall, 1);
    if v <= 0 then return; end
    local fw = w * v;
    local pulse = 0.5 + 0.5 * math.sin(now * 2.2 + seed);
    for k = 1, 3 do
        dl:AddRectFilled({ x - k, y - k }, { x + fw + k, y + h + k }, u32({ c2[1], c2[2], c2[3], (0.11 - k * 0.025) * (0.75 + 0.5 * pulse) }), h / 2 + k);
    end
    dl:AddRectFilled({ x, y }, { x + fw, y + h }, u32({ c2[1], c2[2], c2[3], 0.85 }), h / 2);
    local ph = now * 0.35 + seed * 0.21;
    local r_ = math.min(h / 2, fw / 2);
    local function colx(px)
        local f = (px - x) / w;
        local u = 0.5 + 0.5 * math.sin((f * 1.6 - ph) * math.pi * 2);
        return u32({ c1[1] + (c2[1] - c1[1]) * u, c1[2] + (c2[2] - c1[2]) * u, c1[3] + (c2[3] - c1[3]) * u, 1 });
    end
    local segs = math.max(2, math.floor(w / 20));
    for k = 0, segs - 1 do
        local x1, x2 = math.max(x + r_, x + w * k / segs), math.min(x + fw - r_, x + w * (k + 1) / segs);
        if x2 > x1 then
            local a, b = colx(x1), colx(x2);
            pcall(function() dl:AddRectFilledMultiColor({ x1, y }, { x2, y + h }, a, b, b, a); end);
        end
    end
    local sp = frac(now * 0.32 + seed * 0.137);
    local hx, hw = x - 20 + sp * (fw + 40), 20;
    local function band(x1, x2, a1, a2)
        local cx1, cx2 = math.max(x + r_, x1), math.min(x + fw - r_, x2);
        if cx2 <= cx1 then return; end
        local f1, f2 = (cx1 - x1) / (x2 - x1), (cx2 - x1) / (x2 - x1);
        local b1, b2 = a1 + (a2 - a1) * f1, a1 + (a2 - a1) * f2;
        pcall(function() dl:AddRectFilledMultiColor({ cx1, y }, { cx2, y + h }, u32({ 1, 1, 1, b1 }), u32({ 1, 1, 1, b2 }), u32({ 1, 1, 1, b2 }), u32({ 1, 1, 1, b1 })); end);
    end
    band(hx - hw, hx, 0, 0.5);
    band(hx, hx + hw, 0.5, 0);
end

-- The pill switch
function theme.switch(id, on)
    local x, y = imgui.GetCursorScreenPos();
    local w, h = 52, 26;
    local clicked = imgui.InvisibleButton(id, { w, h });
    local hov = imgui.IsItemHovered();
    local dl = imgui.GetWindowDrawList();
    dl:AddRectFilled({ x, y }, { x + w, y + h }, u32(on and { NEON[1] * 0.42, NEON[2] * 0.42, NEON[3] * 0.42, 1 } or (hov and { 0.14, 0.13, 0.18, 1 } or { 0.10, 0.095, 0.13, 1 })), h / 2);
    dl:AddCircleFilled({ on and (x + w - h / 2) or (x + h / 2), y + h / 2 }, h / 2 - 4, u32(on and { 1, 1, 1, 1 } or { 0.55, 0.53, 0.62, 1 }), 24);
    return clicked;
end

-- A setting on one line: its name on the left, a switch on the right
function theme.row_switch(id, label, key, hint)
    local W = theme.ROW_W;
    local x0 = imgui.GetCursorPosX();
    imgui.AlignTextToFramePadding();
    imgui.TextColored(C.text, safe(label));
    if hint and imgui.IsItemHovered() then theme.tip(hint); end
    imgui.SameLine(x0 + W - 52);
    if theme.switch(id, config.get(key) == true) then
        config.set(key, not (config.get(key) == true));
    end
    if hint and imgui.IsItemHovered() then theme.tip(hint); end
end

-- A slider on one line: the name, a violet track, the value at the end. Double click puts it back to normal.
function theme.row_slider(id, label, key, lo, hi, step, fmt, hint)
    local W = theme.ROW_W;
    local cfg = config.raw();
    local function show(v) if type(fmt) == 'function' then return fmt(v); end return string.format(fmt, v); end
    local v = tonumber(cfg[key]) or lo;
    local x0 = imgui.GetCursorPosX();
    imgui.AlignTextToFramePadding();
    imgui.TextColored(C.text, safe(label));
    if hint and imgui.IsItemHovered() then theme.tip(hint); end
    local lw = tw(label);
    local text = show(v);
    local vw = tw(text);
    local tl = math.max(lw + 24, W * 0.34);
    local tr = W - math.max(vw, 44) - 22;
    imgui.SameLine(x0 + tl);
    local x, y = imgui.GetCursorScreenPos();
    local w, h = math.max(40, tr - tl), imgui.GetFrameHeight();
    imgui.InvisibleButton(id, { w, h });
    local act, hov = imgui.IsItemActive(), imgui.IsItemHovered();
    if act then
        local mx = imgui.GetMousePos();
        local f = math.max(0, math.min(1, (mx - x) / w));
        local nv = lo + math.floor((f * (hi - lo)) / step + 0.5) * step;
        if math.abs(nv - v) > step * 0.01 then cfg[key] = nv; v = nv; text = show(v); end
    end
    if imgui.IsItemDeactivated() then config.save(); end
    if hov and imgui.IsMouseDoubleClicked(0) and config.defaults[key] ~= nil then
        cfg[key] = config.defaults[key]; v = cfg[key]; text = show(v); config.save();
    end
    if hint and hov and not act then theme.tip(hint .. '\n(double click: back to default)'); end
    local dl = imgui.GetWindowDrawList();
    local f = math.max(0, math.min(1, (v - lo) / (hi - lo)));
    local cy = y + h / 2;
    local th = 6;
    dl:AddRectFilled({ x, cy - th / 2 }, { x + w, cy + th / 2 }, u32({ 0.20, 0.19, 0.25, 1 }), th / 2);
    local ok_ = pcall(function()
        dl:AddRectFilledMultiColor({ x, cy - th / 2 }, { x + w * f, cy + th / 2 }, u32(NEON), u32(NEON2), u32(NEON2), u32(NEON));
    end);
    if not ok_ then dl:AddRectFilled({ x, cy - th / 2 }, { x + w * f, cy + th / 2 }, u32(NEON), th / 2); end
    dl:AddCircleFilled({ x + w * f, cy }, (act or hov) and 13 or 11, u32({ NEON[1], NEON[2], NEON[3], 0.30 }), 24);
    dl:AddCircleFilled({ x + w * f, cy }, 8, u32({ 1, 1, 1, 1 }), 24);
    imgui.SameLine(x0 + W - tw(text));
    imgui.TextColored(C.text, safe(text));
end

-- A choice: the name on the left, a dark pill on the right with the current one and a small arrow
function theme.row_pick(id, label, key, opts, hint)
    local W = theme.ROW_W;
    local x0 = imgui.GetCursorPosX();
    imgui.AlignTextToFramePadding();
    imgui.TextColored(C.text, safe(label));
    if hint and imgui.IsItemHovered() then theme.tip(hint); end
    local cur = 1;
    for k, o in ipairs(opts) do if o[1] == config.get(key) then cur = k; end end
    local bw, bh = math.floor(W * 0.55), imgui.GetFrameHeight();
    imgui.SameLine(x0 + W - bw);
    local bx, by = imgui.GetCursorScreenPos();
    local clicked = imgui.InvisibleButton(id, { bw, bh });
    local hov = imgui.IsItemHovered();
    local dl = imgui.GetWindowDrawList();
    dl:AddRectFilled({ bx, by }, { bx + bw, by + bh }, u32(hov and { 0.15, 0.14, 0.19, 1 } or { 0.10, 0.09, 0.13, 1 }), bh / 2);
    dl:AddRect({ bx, by }, { bx + bw, by + bh }, u32(hov and { NEON2[1], NEON2[2], NEON2[3], 0.45 } or { 1, 1, 1, 0.10 }), bh / 2, C.rall, 1);
    local name = opts[cur] and opts[cur][2] or '-';
    local lw, lh = imgui.CalcTextSize(name);
    dl:AddText({ bx + (bw - lw) / 2, by + (bh - lh) / 2 }, u32({ 0.93, 0.92, 0.98, 1 }), name);
    local ax, ay, r = bx + bw - 22, by + bh / 2, 4.5;
    local ac = u32({ 0.85, 0.83, 0.95, hov and 1 or 0.75 });
    dl:AddLine({ ax - r, ay - r * 0.5 }, { ax, ay + r * 0.5 }, ac, 1.5);
    dl:AddLine({ ax, ay + r * 0.5 }, { ax + r, ay - r * 0.5 }, ac, 1.5);
    if clicked then imgui.OpenPopup(id .. '_list'); end
    local pv = 0;
    for _, v in ipairs({ { ImGuiStyleVar_WindowPadding, { 12, 10 } }, { ImGuiStyleVar_ItemSpacing, { 6, 6 } },
                         { ImGuiStyleVar_PopupRounding, 8 }, { ImGuiStyleVar_PopupBorderSize, 1 } }) do
        if v[1] ~= nil then imgui.PushStyleVar(v[1], v[2]); pv = pv + 1; end
    end
    imgui.PushStyleColor(ImGuiCol_PopupBg, { 0.055, 0.050, 0.075, 0.98 });
    imgui.PushStyleColor(ImGuiCol_Border, { 1, 1, 1, 0.10 });
    imgui.PushStyleColor(ImGuiCol_Header, { 1, 1, 1, 0.12 });
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, { 1, 1, 1, 0.08 });
    imgui.PushStyleColor(ImGuiCol_HeaderActive, { 1, 1, 1, 0.16 });
    if imgui.BeginPopup(id .. '_list') then
        for k, o in ipairs(opts) do
            if imgui.Selectable('  ' .. o[2] .. '##' .. id .. k, k == cur, 0, { bw, 0 }) then
                config.set(key, o[1]);
            end
        end
        imgui.EndPopup();
    end
    imgui.PopStyleColor(5);
    imgui.PopStyleVar(pv);
end

-- A section's name: spaced capitals, a faint line on to the edge
function theme.section(label, width, right_w)
    width = width or theme.ROW_W;
    imgui.Spacing();
    local dl = imgui.GetWindowDrawList();
    local x0, y0 = imgui.GetCursorScreenPos();
    local lh = imgui.GetTextLineHeight();
    local w = theme.spaced(dl, x0, y0, label:upper(), u32({ 0.93, 0.90, 1.00, 1 }), 2.5);
    local xe = x0 + width - ((right_w or 0) > 0 and (right_w + 10) or 0);
    if xe > x0 + w + 18 then dl:AddLine({ x0 + w + 18, y0 + lh / 2 }, { xe, y0 + lh / 2 }, u32({ 1, 1, 1, 0.08 }), 1); end
    imgui.Dummy({ width, lh + 2 });
    return x0, y0, lh;
end

-- A rounded button: violet-edged (the main one) or dark (quiet), its name in spaced capitals
function theme.accent_button(label, quiet, wid)
    local w = wid or theme.ROW_W;
    local h = math.floor(imgui.GetFrameHeight() * 1.2);
    local x, y = imgui.GetCursorScreenPos();
    local clicked = imgui.InvisibleButton(label, { w, h });
    local hov, act = imgui.IsItemHovered(), imgui.IsItemActive();
    local dl = imgui.GetWindowDrawList();
    local rr = math.min(h * 0.45, 14);
    local fill = { 0.10, 0.09, 0.13, 1 };
    if hov or act then fill = act and { 0.18, 0.17, 0.23, 1 } or { 0.15, 0.14, 0.19, 1 }; end
    dl:AddRectFilled({ x, y }, { x + w, y + h }, u32(fill), rr);
    local ec = u32(quiet and { 1, 1, 1, hov and 0.25 or 0.14 } or { NEON2[1], NEON2[2], NEON2[3], hov and 1 or 0.8 });
    dl:AddRect({ x, y }, { x + w, y + h }, ec, rr, C.rall, quiet and 1 or 1.6);
    local name = label:gsub('##.*$', ''):upper();
    local lw = theme.spaced_w(name, 3);
    local lh = imgui.GetTextLineHeight();
    theme.spaced(dl, x + (w - lw) / 2, y + (h - lh) / 2, name, u32({ 0.93, 0.91, 0.98, 1 }), 3);
    return clicked;
end

-- Pills: a row of choices in one dark capsule (the chosen one lit violet). opts = { { value, label, hint }, ... }
local PILL_PAD = 9;
function theme.pill_h() return imgui.GetTextLineHeight() + 8; end
function theme.segmented_w(opts)
    local w = 4;
    for _, o in ipairs(opts) do w = w + tw(o[2]) + PILL_PAD * 2; end
    return w;
end
function theme.segmented(id, opts, cur)
    local x, y = imgui.GetCursorScreenPos();
    local lh = imgui.GetTextLineHeight();
    local h = theme.pill_h();
    local w = theme.segmented_w(opts);
    local dl = imgui.GetWindowDrawList();
    dl:AddRectFilled({ x, y }, { x + w, y + h }, theme.bgc(0.10, 0.09, 0.13, 1), h / 2);
    dl:AddRect({ x, y }, { x + w, y + h }, u32({ 1, 1, 1, 0.10 }), h / 2, C.rall, 1);
    local cx, picked = x + 2, nil;
    for i, o in ipairs(opts) do
        local sw = tw(o[2]) + PILL_PAD * 2;
        imgui.SetCursorScreenPos({ cx, y + 2 });
        if imgui.InvisibleButton(id .. '_' .. i, { sw, h - 4 }) then picked = o[1]; end
        local hov = imgui.IsItemHovered();
        local on = (o[1] == cur);
        local r = (h - 4) / 2;
        if on then
            dl:AddRectFilled({ cx, y + 2 }, { cx + sw, y + h - 2 }, u32({ NEON[1] * 0.42, NEON[2] * 0.42, NEON[3] * 0.42, 1 }), r);
            dl:AddRect({ cx, y + 2 }, { cx + sw, y + h - 2 }, u32({ NEON2[1], NEON2[2], NEON2[3], 0.85 }), r, C.rall, 1);
        elseif hov then
            dl:AddRectFilled({ cx, y + 2 }, { cx + sw, y + h - 2 }, u32({ 1, 1, 1, 0.07 }), r);
        end
        dl:AddText({ cx + PILL_PAD, y + (h - lh) / 2 }, u32(on and { 1, 1, 1, 1 } or (hov and C.text or C.muted)), o[2]);
        if hov and o[3] then theme.tip(o[3]); end
        cx = cx + sw;
    end
    imgui.SetCursorScreenPos({ x, y });
    imgui.Dummy({ w, h });
    return picked;
end

-- A single pill button (lit = violet edge)
function theme.pill_w(label) return tw(label) + PILL_PAD * 2; end
function theme.pill(id, label, lit, x, y)
    if x ~= nil then imgui.SetCursorScreenPos({ x, y }); end
    x, y = imgui.GetCursorScreenPos();
    local lh = imgui.GetTextLineHeight();
    local h, w = theme.pill_h(), theme.pill_w(label);
    local clicked = imgui.InvisibleButton(id, { w, h });
    local hov = imgui.IsItemHovered();
    local dl = imgui.GetWindowDrawList();
    dl:AddRectFilled({ x, y }, { x + w, y + h }, u32(lit and { NEON[1] * 0.42, NEON[2] * 0.42, NEON[3] * 0.42, 1 } or (hov and { 0.15, 0.14, 0.19, 1 } or { 0.10, 0.09, 0.13, theme.bg })), h / 2);
    dl:AddRect({ x, y }, { x + w, y + h }, u32(lit and { NEON2[1], NEON2[2], NEON2[3], hov and 1 or 0.8 } or { 1, 1, 1, hov and 0.25 or 0.12 }), h / 2, C.rall, 1);
    dl:AddText({ x + PILL_PAD, y + (h - lh) / 2 }, u32((lit or hov) and { 1, 1, 1, 1 } or C.muted), label);
    return clicked, hov;
end

-- A small round button: kind 'min' (a dash), 'close' (a cross), 'gear' (settings), 'expand' (a square),
-- 'back' (a left chevron), 'refresh' (a circular arrow), 'up' / 'down' (chevrons)
function theme.icon_button(id, x, y, kind, d)
    d = d or 18;
    imgui.SetCursorScreenPos({ x, y });
    local clicked = imgui.InvisibleButton(id, { d, d });
    local hov = imgui.IsItemHovered();
    local dl = imgui.GetWindowDrawList();
    local cx, cy = x + d / 2, y + d / 2;
    dl:AddCircleFilled({ cx, cy }, d / 2, u32(hov and { 0.15, 0.14, 0.19, 1 } or { 0.10, 0.09, 0.13, theme.bg }), 24);
    dl:AddCircle({ cx, cy }, d / 2, u32(hov and { NEON2[1], NEON2[2], NEON2[3], 0.8 } or { 1, 1, 1, 0.12 }), 24, 1);
    local ic = u32({ 0.93, 0.91, 0.98, hov and 1 or 0.75 });
    local s = d / 18;
    if kind == 'min' then
        dl:AddLine({ cx - 4 * s, cy }, { cx + 4 * s, cy }, ic, 1.6);
    elseif kind == 'expand' then
        dl:AddRect({ cx - 3.5 * s, cy - 3.5 * s }, { cx + 3.5 * s, cy + 3.5 * s }, ic, 1.5, C.rall, 1.5);
    elseif kind == 'gear' then
        dl:AddCircle({ cx, cy }, 2.6 * s, ic, 12, 1.5);
        for k = 0, 5 do
            local a = k * math.pi / 3;
            dl:AddLine({ cx + math.cos(a) * 3.8 * s, cy + math.sin(a) * 3.8 * s }, { cx + math.cos(a) * 5.6 * s, cy + math.sin(a) * 5.6 * s }, ic, 1.8);
        end
    elseif kind == 'up' or kind == 'down' then
        chevron(dl, cx, cy, 3.5 * s, kind == 'up', ic, 1.6);
    elseif kind == 'back' then
        dl:AddLine({ cx + 1.5 * s, cy - 4 * s }, { cx - 2.5 * s, cy }, ic, 1.7);
        dl:AddLine({ cx - 2.5 * s, cy }, { cx + 1.5 * s, cy + 4 * s }, ic, 1.7);
    elseif kind == 'refresh' then
        local r = 4.2 * s;
        local a0, a1, segs = math.pi * 0.35, math.pi * 1.95, 12;
        local px, py = cx + math.cos(a0) * r, cy + math.sin(a0) * r;
        for k = 1, segs do
            local a = a0 + (a1 - a0) * k / segs;
            local nx, ny = cx + math.cos(a) * r, cy + math.sin(a) * r;
            dl:AddLine({ px, py }, { nx, ny }, ic, 1.5);
            px, py = nx, ny;
        end
        dl:AddLine({ px, py }, { px - 3 * s, py - 0.5 * s }, ic, 1.5);
        dl:AddLine({ px, py }, { px + 0.5 * s, py + 3 * s }, ic, 1.5);
    else
        dl:AddLine({ cx - 3.5 * s, cy - 3.5 * s }, { cx + 3.5 * s, cy + 3.5 * s }, ic, 1.6);
        dl:AddLine({ cx - 3.5 * s, cy + 3.5 * s }, { cx + 3.5 * s, cy - 3.5 * s }, ic, 1.6);
    end
    return clicked, hov;
end

-- The title: the first part white, the rest flowing between pink and violet. Returns its width and height.
function theme.title_size(text, scale)
    imgui.SetWindowFontScale(scale or 1);
    local w, h = imgui.CalcTextSize(text);
    imgui.SetWindowFontScale(1);
    return w, h;
end
function theme.title(dl, x0, y0, text, white_n, scale)
    imgui.SetWindowFontScale(scale or 1);
    local t = os.clock();
    for i = 1, #text do
        local ch = text:sub(i, i);
        local cx = x0 + tw(text:sub(1, i - 1));
        local col = C.text;
        if i > white_n then
            local u = 0.5 + 0.5 * math.sin(t * 1.2 - i * 0.45);
            col = { C.hp[1] + (C.mp2[1] - C.hp[1]) * u, C.hp[2] + (C.mp2[2] - C.hp[2]) * u, C.hp[3] + (C.mp2[3] - C.hp[3]) * u, 1 };
        end
        dl:AddText({ cx, y0 }, u32(col), ch);
    end
    local w, h = imgui.CalcTextSize(text);
    imgui.SetWindowFontScale(1);
    return w, h;
end

-- Remember where a window was dragged to
function theme.remember_pos(kx, ky)
    local cfg = config.raw();
    local wx, wy = imgui.GetWindowPos();
    if type(wx) == 'number' and (math.abs(wx - (tonumber(cfg[kx]) or 0)) > 0.5 or math.abs(wy - (tonumber(cfg[ky]) or 0)) > 0.5) then
        cfg[kx], cfg[ky] = wx, wy;
        if not imgui.IsMouseDown(0) then config.save(); end
    end
end

-- The main window: resizable (from the edges and the corner grip), everything else as WIN_FLAGS
theme.WIN_FLAGS_RESIZE = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse,
    ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoSavedSettings);

-- The space left in the window (x, y), whatever shape this ImGui returns it in
function theme.avail()
    local ax, ay = imgui.GetContentRegionAvail();
    if type(ax) == 'table' then ax, ay = ax.x or ax[1], ax.y or ax[2]; end
    return tonumber(ax) or 400, tonumber(ay) or 300;
end

theme.WIN_FLAGS = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_AlwaysAutoResize,
    ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoFocusOnAppearing,
    ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoSavedSettings);

----------------------------------------------------------------------------------------------------
-- NeoCrafty additions
----------------------------------------------------------------------------------------------------

-- A tooltip with free content: begin_tip(), draw anything, end_tip(). Same card as theme.tip.
function theme.begin_tip(wrap)
    if not (imgui.BeginTooltip and imgui.EndTooltip) then return false; end
    imgui.PushStyleVar(ImGuiStyleVar_Alpha, 1);
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 8);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 10, 8 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 1);
    imgui.PushStyleColor(ImGuiCol_PopupBg, { 0.045, 0.040, 0.065, 0.97 });
    imgui.PushStyleColor(ImGuiCol_Border, { 0.62, 0.40, 1.00, 0.55 });
    imgui.PushStyleColor(ImGuiCol_Text, { 0.93, 0.92, 0.98, 1 });
    if imgui.BeginTooltip() == false then
        imgui.PopStyleColor(3); imgui.PopStyleVar(4);
        return false;
    end
    if wrap then imgui.PushTextWrapPos(wrap); end
    theme._tip_wrap = wrap ~= nil;
    return true;
end

function theme.end_tip()
    if theme._tip_wrap then imgui.PopTextWrapPos(); end
    pcall(function()
        local dl = imgui.GetWindowDrawList();
        local wx, wy = imgui.GetWindowPos();
        local ww = imgui.GetWindowSize();
        if type(wx) == 'table' then wx, wy = wx.x or wx[1], wx.y or wx[2]; end
        if type(ww) == 'table' then ww = ww.x or ww[1]; end
        local p1, p2 = u32({ 1.0, 0.36, 0.62, 0.9 }), u32({ 0.62, 0.40, 1.0, 0.9 });
        dl:AddRectFilledMultiColor({ wx + 8, wy + 1 }, { wx + ww - 8, wy + 2 }, p1, p2, p2, p1);
    end);
    imgui.EndTooltip();
    imgui.PopStyleColor(3);
    imgui.PopStyleVar(4);
end

function chevron(dl, cx, cy, r, up, col, th)
    if up then
        dl:AddLine({ cx - r, cy + r * 0.5 }, { cx, cy - r * 0.5 }, col, th or 1.5);
        dl:AddLine({ cx, cy - r * 0.5 }, { cx + r, cy + r * 0.5 }, col, th or 1.5);
    else
        dl:AddLine({ cx - r, cy - r * 0.5 }, { cx, cy + r * 0.5 }, col, th or 1.5);
        dl:AddLine({ cx, cy + r * 0.5 }, { cx + r, cy - r * 0.5 }, col, th or 1.5);
    end
end
theme.chevron = chevron;

-- A rounded button that can be lit (violet), quiet, or disabled. Returns clicked, hovered.
-- opts: { w =, h =, lit =, disabled =, col = text colour, spaced = true for spaced capitals }
function theme.button(id, label, opts)
    opts = opts or {};
    local lh = imgui.GetTextLineHeight();
    local name = opts.spaced and label:upper() or label;
    local lw = opts.spaced and theme.spaced_w(name, 2) or tw(name);
    local w = opts.w or (lw + 24);
    local h = opts.h or theme.pill_h();
    local x, y = imgui.GetCursorScreenPos();
    local clicked = imgui.InvisibleButton(id, { w, h });
    local hov, act = imgui.IsItemHovered(), imgui.IsItemActive();
    local dl = imgui.GetWindowDrawList();
    local rr = math.min(h / 2, 12);
    local dis = opts.disabled == true;
    local fill;
    if dis then fill = { 0.08, 0.075, 0.10, theme.bg };
    elseif opts.lit then fill = act and { NEON[1] * 0.55, NEON[2] * 0.55, NEON[3] * 0.55, 1 } or (hov and { NEON[1] * 0.50, NEON[2] * 0.50, NEON[3] * 0.50, 1 } or { NEON[1] * 0.40, NEON[2] * 0.40, NEON[3] * 0.40, 1 });
    else fill = act and { 0.18, 0.17, 0.23, 1 } or (hov and { 0.15, 0.14, 0.19, 1 } or { 0.10, 0.09, 0.13, theme.bg }); end
    dl:AddRectFilled({ x, y }, { x + w, y + h }, u32(fill), rr);
    local edge;
    if dis then edge = { 1, 1, 1, 0.05 };
    elseif opts.lit then edge = { NEON2[1], NEON2[2], NEON2[3], hov and 1 or 0.8 };
    else edge = { 1, 1, 1, hov and 0.25 or 0.12 }; end
    dl:AddRect({ x, y }, { x + w, y + h }, u32(edge), rr, C.rall, opts.lit and 1.4 or 1);
    local tc = dis and { 0.40, 0.39, 0.46, 1 } or (opts.col or ((opts.lit or hov) and { 1, 1, 1, 1 } or C.text));
    if opts.spaced then
        theme.spaced(dl, x + (w - lw) / 2, y + (h - lh) / 2, name, u32(tc), 2);
    else
        dl:AddText({ x + (w - lw) / 2, y + (h - lh) / 2 }, u32(tc), name);
    end
    return clicked and not dis, hov;
end

-- The number field: one cell per digit with an arrow above and below it. The arrows step that place
-- (ones, tens, hundreds) and repeat when held. Click the number to type it. Returns value, changed.
local dig = {};
local DIG_ARROW = 9;
function theme.digits_size(hi)
    local n = #tostring(math.max(1, math.floor(hi)));
    local cw = tw('0') + 12;
    return n * cw + 4, imgui.GetTextLineHeight() + DIG_ARROW * 2 + 6;
end

-- cap (optional): a lower ceiling than hi, e.g. what your materials allow. The field keeps hi's width;
-- trying to go past the ceiling turns the number red and gives it a little shake.
local WIGGLE_T = 0.5;
function theme.digits(id, value, lo, hi, cap)
    lo, hi = math.floor(lo or 0), math.max(math.floor(hi or 999), math.floor(lo or 0));
    local top = hi;                                                   -- (the width: digits for hi)
    if cap ~= nil then hi = math.max(lo, math.min(hi, math.floor(cap))); end
    local function clamp(v) return math.max(lo, math.min(hi, math.floor(tonumber(v) or lo))); end
    value = clamp(value);
    local n = #tostring(math.max(1, top));
    local lh = imgui.GetTextLineHeight();
    local cw = tw('0') + 12;
    local w, h = theme.digits_size(top);
    local x, y = imgui.GetCursorScreenPos();
    local dl = imgui.GetWindowDrawList();
    local st = dig[id];
    if st == nil then st = { buf = { '' } }; dig[id] = st; end
    local now = os.clock();
    local newv, changed = value, false;
    -- the "can't go higher" shake: an offset that dies away, and a red tint
    local wig = st.wig and (now - st.wig) < WIGGLE_T and (1 - (now - st.wig) / WIGGLE_T) or 0;
    local dx = wig > 0 and math.sin((now - st.wig) * 48) * 3.5 * wig or 0;

    dl:AddRectFilled({ x, y }, { x + w, y + h }, theme.bgc(0.07, 0.065, 0.095, 1), 8);
    local edge = st.editing and { NEON2[1], NEON2[2], NEON2[3], 0.8 } or { 1, 1, 1, 0.10 };
    if wig > 0 then edge = { C.bad[1], C.bad[2], C.bad[3], 0.35 + 0.6 * wig }; end
    dl:AddRect({ x, y }, { x + w, y + h }, u32(edge), 8, C.rall, 1);

    if st.editing then
        local pv = 0;
        if ImGuiStyleVar_FramePadding ~= nil then imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 6, (h - lh) / 2 }); pv = pv + 1; end
        imgui.PushStyleColor(ImGuiCol_FrameBg, { 0, 0, 0, 0 });
        imgui.PushStyleColor(ImGuiCol_FrameBgHovered, { 0, 0, 0, 0 });
        imgui.PushStyleColor(ImGuiCol_FrameBgActive, { 0, 0, 0, 0 });
        imgui.SetCursorScreenPos({ x, y });
        imgui.PushItemWidth(w);
        if st.focus then imgui.SetKeyboardFocusHere(0); st.focus = false; end
        local flags = bit.bor(ImGuiInputTextFlags_CharsDecimal or 0, ImGuiInputTextFlags_EnterReturnsTrue or 0, ImGuiInputTextFlags_AutoSelectAll or 0);
        local enter = imgui.InputText('##' .. id .. '_edit', st.buf, n + 1, flags);
        local active = imgui.IsItemActive();
        imgui.PopItemWidth();
        imgui.PopStyleColor(3);
        if pv > 0 then imgui.PopStyleVar(pv); end
        if active then st.armed = true; end
        if enter or (st.armed and not active) or (not st.armed and now - st.t0 > 0.6) then
            local typed = tonumber(st.buf[1]);
            if typed ~= nil then
                newv = clamp(typed); changed = newv ~= value;
                if typed > hi then st.wig = now; end                  -- (typed past the ceiling)
            end
            st.editing, st.armed = false, false;
        end
        imgui.SetCursorScreenPos({ x, y });
        imgui.Dummy({ w, h });
        return newv, changed;
    end

    local held = false;
    for k = 1, n do
        local place = n - k;
        local step = 10 ^ place;
        local cx = x + 2 + (k - 1) * cw;
        local ccx = cx + cw / 2;
        if k > 1 then dl:AddLine({ cx, y + 5 }, { cx, y + h - 5 }, u32({ 1, 1, 1, 0.06 }), 1); end

        -- up
        imgui.SetCursorScreenPos({ cx, y + 1 });
        imgui.InvisibleButton('##' .. id .. '_u' .. k, { cw, DIG_ARROW + 2 });
        local hu, au = imgui.IsItemHovered(), imgui.IsItemActive();
        -- digit
        imgui.SetCursorScreenPos({ cx, y + DIG_ARROW + 3 });
        local dclick = imgui.InvisibleButton('##' .. id .. '_d' .. k, { cw, lh });
        local hd = imgui.IsItemHovered();
        -- down
        imgui.SetCursorScreenPos({ cx, y + DIG_ARROW + 3 + lh });
        imgui.InvisibleButton('##' .. id .. '_n' .. k, { cw, DIG_ARROW + 2 });
        local hn, an = imgui.IsItemHovered(), imgui.IsItemActive();

        local up_ok, dn_ok = newv < hi, newv > lo;
        for _, a in ipairs({ { au, 1 }, { an, -1 } }) do
            if a[1] then
                held = true;
                local key = k * 2 + (a[2] > 0 and 0 or 1);
                local fire = false;
                if st.hold == nil or st.hold.key ~= key then
                    st.hold = { key = key, next = now + 0.40 };
                    fire = true;
                elseif now >= st.hold.next then
                    st.hold.next = now + 0.07;
                    fire = true;
                end
                if fire then
                    local want = newv + a[2] * step;
                    local nv2 = clamp(want);
                    if nv2 ~= newv then newv = nv2; changed = true; end
                    if a[2] > 0 and want > hi then st.wig = now; end      -- (pushed past the ceiling)
                end
            end
        end

        if hu or hn or hd then dl:AddRectFilled({ cx + 1, y + 2 }, { cx + cw - 1, y + h - 2 }, u32({ 1, 1, 1, 0.04 }), 5); end
        chevron(dl, ccx, y + 1 + (DIG_ARROW + 2) / 2, 3.5, true, u32(up_ok and (hu and NEON2 or { 0.85, 0.83, 0.95, 0.55 }) or { 1, 1, 1, 0.12 }), 1.5);
        chevron(dl, ccx, y + DIG_ARROW + 3 + lh + (DIG_ARROW + 2) / 2, 3.5, false, u32(dn_ok and (hn and NEON2 or { 0.85, 0.83, 0.95, 0.55 }) or { 1, 1, 1, 0.12 }), 1.5);
        local d = tostring(math.floor(newv / step) % 10);
        local lead = place > 0 and newv < step;
        local dcol = lead and { 1, 1, 1, 0.22 } or (hd and { 1, 1, 1, 1 } or C.text);
        if wig > 0 and not lead then                                  -- (red, fading back)
            dcol = { dcol[1] + (C.bad[1] - dcol[1]) * math.min(1, wig * 1.6), dcol[2] + (C.bad[2] - dcol[2]) * math.min(1, wig * 1.6),
                     dcol[3] + (C.bad[3] - dcol[3]) * math.min(1, wig * 1.6), 1 };
        end
        dl:AddText({ ccx - tw(d) / 2 + dx, y + DIG_ARROW + 3 }, u32(dcol), d);
        if hd then theme.tip(hi < top and string.format('Click to type a number (%d to %d; %d is all you have materials for)', lo, hi, hi)
            or ('Click to type a number (' .. lo .. ' to ' .. hi .. ')')); end
        if dclick then
            st.editing, st.armed, st.focus, st.t0 = true, false, true, now;
            st.buf[1] = tostring(newv);
        end
    end
    if not held then st.hold = nil; end
    imgui.SetCursorScreenPos({ x, y });
    imgui.Dummy({ w, h });
    return newv, changed;
end

-- A text box in the panel style, with a faint hint while empty. clear = true: a small (x) inside its right end
-- empties it (shown while there's text). Returns active, cleared.
function theme.input(id, buf, size, w, hint, clear)
    local lh = imgui.GetTextLineHeight();
    local h = theme.pill_h() + 4;
    local x, y = imgui.GetCursorScreenPos();
    local dl = imgui.GetWindowDrawList();
    local has_text = (buf[1] or '') ~= '';
    local xw = (clear and has_text) and 26 or 0;                     -- (room kept for the x)
    if xw > 0 then dl:AddRectFilled({ x + w - xw - h / 2, y }, { x + w, y + h }, u32({ 0.10, 0.09, 0.13, theme.bg }), h / 2); end
    local pv = 0;
    if ImGuiStyleVar_FramePadding ~= nil then imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 12, (h - lh) / 2 }); pv = pv + 1; end
    if ImGuiStyleVar_FrameRounding ~= nil then imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, h / 2); pv = pv + 1; end
    imgui.PushStyleColor(ImGuiCol_FrameBg, { 0.10, 0.09, 0.13, theme.bg });
    imgui.PushStyleColor(ImGuiCol_FrameBgHovered, { 0.13, 0.12, 0.17, 1 });
    imgui.PushStyleColor(ImGuiCol_FrameBgActive, { 0.13, 0.12, 0.17, 1 });
    imgui.PushItemWidth(w - xw);
    imgui.InputText(id, buf, size, ImGuiInputTextFlags_None or 0);
    local active, hov = imgui.IsItemActive(), imgui.IsItemHovered();
    imgui.PopItemWidth();
    imgui.PopStyleColor(3);
    if pv > 0 then imgui.PopStyleVar(pv); end
    local cleared = false;
    if xw > 0 then
        local d = 16;
        local cx, cy = x + w - xw / 2 - 3, y + h / 2;
        imgui.SetCursorScreenPos({ cx - d / 2 - 3, y });
        if imgui.InvisibleButton(id .. '_clr', { d + 6, h }) then buf[1] = ''; cleared = true; end
        local xh = imgui.IsItemHovered();
        dl:AddCircleFilled({ cx, cy }, d / 2, u32(xh and { NEON[1] * 0.45, NEON[2] * 0.45, NEON[3] * 0.45, 1 } or { 1, 1, 1, 0.08 }), 20);
        local ic = u32({ 1, 1, 1, xh and 1 or 0.6 });
        dl:AddLine({ cx - 3, cy - 3 }, { cx + 3, cy + 3 }, ic, 1.5);
        dl:AddLine({ cx - 3, cy + 3 }, { cx + 3, cy - 3 }, ic, 1.5);
        if xh then theme.tip('Clear'); end
        hov = hov or xh;
    end
    dl:AddRect({ x, y }, { x + w, y + h }, u32(active and { NEON2[1], NEON2[2], NEON2[3], 0.7 } or { 1, 1, 1, hov and 0.18 or 0.10 }), h / 2, C.rall, 1);
    if (buf[1] or '') == '' and hint and not active then
        dl:AddText({ x + 12, y + (h - lh) / 2 }, u32({ C.muted[1], C.muted[2], C.muted[3], 0.7 }), hint);
    end
    imgui.SetCursorScreenPos({ x, y + h });
    imgui.Dummy({ w, 0 });
    return active, cleared;
end

-- A compact dropdown. opts = { { value, label }, ... }. Returns the picked value or nil.
-- ctl (optional): the controller driving it - { open_req, active, hi, pick_req, close_req }. open_req opens the list,
-- hi is the highlighted row (D-pad), pick_req picks it, close_req closes it. active stays true while it's open.
function theme.pick(id, opts, cur, w, ctl)
    local bh = theme.pill_h();
    local x, y = imgui.GetCursorScreenPos();
    local clicked = imgui.InvisibleButton(id, { w, bh });
    local hov = imgui.IsItemHovered();
    local dl = imgui.GetWindowDrawList();
    local k = 1;
    for i, o in ipairs(opts) do if o[1] == cur then k = i; end end
    local on = opts[1] ~= nil and opts[k][1] ~= opts[1][1];
    dl:AddRectFilled({ x, y }, { x + w, y + bh }, u32(on and { NEON[1] * 0.30, NEON[2] * 0.30, NEON[3] * 0.30, 1 } or (hov and { 0.15, 0.14, 0.19, 1 } or { 0.10, 0.09, 0.13, theme.bg })), bh / 2);
    dl:AddRect({ x, y }, { x + w, y + bh }, u32(on and { NEON2[1], NEON2[2], NEON2[3], 0.7 } or (hov and { NEON2[1], NEON2[2], NEON2[3], 0.45 } or { 1, 1, 1, 0.10 })), bh / 2, C.rall, 1);
    local name = opts[k] and opts[k][2] or '-';
    local lh = imgui.GetTextLineHeight();
    dl:AddText({ x + 10, y + (bh - lh) / 2 }, u32(on and { 1, 1, 1, 1 } or C.text), theme.fit(name, w - 30));   -- (clear of the arrow)
    chevron(dl, x + w - 13, y + bh / 2, 3.5, false, u32({ 0.85, 0.83, 0.95, hov and 1 or 0.7 }), 1.5);
    if clicked then imgui.OpenPopup(id .. '_list'); if ctl then ctl.active = false; end end
    if ctl and ctl.open_req then
        ctl.open_req = false;
        ctl.active, ctl.hi, ctl.moved = true, k, true;
        imgui.OpenPopup(id .. '_list');
    end
    local picked = nil;
    local pv = 0;
    for _, v in ipairs({ { ImGuiStyleVar_WindowPadding, { 8, 8 } }, { ImGuiStyleVar_ItemSpacing, { 6, 4 } },
                         { ImGuiStyleVar_PopupRounding, 8 }, { ImGuiStyleVar_PopupBorderSize, 1 } }) do
        if v[1] ~= nil then imgui.PushStyleVar(v[1], v[2]); pv = pv + 1; end
    end
    imgui.PushStyleColor(ImGuiCol_PopupBg, { 0.055, 0.050, 0.075, 0.98 });
    imgui.PushStyleColor(ImGuiCol_Border, { 1, 1, 1, 0.10 });
    imgui.PushStyleColor(ImGuiCol_Header, { NEON[1] * 0.42, NEON[2] * 0.42, NEON[3] * 0.42, 1 });
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, { 1, 1, 1, 0.08 });
    imgui.PushStyleColor(ImGuiCol_HeaderActive, { 1, 1, 1, 0.16 });
    if imgui.BeginPopup(id .. '_list') then
        local lw_ = math.max(w - 16, 60);                              -- (the list is as wide as its longest name)
        for _, o in ipairs(opts) do lw_ = math.max(lw_, tw(' ' .. o[2]) + 16); end
        local pad_on = ctl ~= nil and ctl.active;
        if pad_on then ctl.hi = math.max(1, math.min(#opts, ctl.hi or k)); end
        for i, o in ipairs(opts) do
            local hl = pad_on and i == ctl.hi;
            local sx, sy = imgui.GetCursorScreenPos();
            if imgui.Selectable(' ' .. o[2] .. '##' .. id .. i, (pad_on and hl) or (not pad_on and i == k), 0, { lw_, 0 }) then picked = o[1]; end
            if hl then                                                 -- (the controller's row: a neon edge, kept in view)
                local ex = sx + lw_;
                imgui.GetWindowDrawList():AddRect({ sx - 2, sy - 1 }, { ex + 2, sy + imgui.GetTextLineHeight() + 1 }, u32({ NEON2[1], NEON2[2], NEON2[3], 0.9 }), 5, C.rall, 1.5);
                if ctl.moved then imgui.SetScrollHereY(0.5); ctl.moved = false; end
            end
        end
        if pad_on and ctl.pick_req then
            picked = opts[ctl.hi] and opts[ctl.hi][1] or nil;
            imgui.CloseCurrentPopup();
        elseif pad_on and ctl.close_req then
            imgui.CloseCurrentPopup();
        end
        if picked ~= nil and ctl then ctl.active = false; end
        if ctl then ctl.pick_req, ctl.close_req = false, false; end
        imgui.EndPopup();
    elseif ctl and ctl.active then
        ctl.active, ctl.pick_req, ctl.close_req = false, false, false;   -- (closed: by a click outside it, or by the pad)
    end
    imgui.PopStyleColor(5);
    imgui.PopStyleVar(pv);
    return picked;
end

-- A small rounded tag (craft levels, RARE/EX, DESYNTH). Returns its width.
function theme.chip_w(text) return tw(text) + 10; end
function theme.chip(dl, x, y, text, col, fill_a)
    local lh = imgui.GetTextLineHeight();
    local w, h = tw(text) + 10, lh + 2;
    dl:AddRectFilled({ x, y }, { x + w, y + h }, u32({ col[1], col[2], col[3], (fill_a or 0.14) * theme.bg + 0.02 }), h / 2);
    dl:AddRect({ x, y }, { x + w, y + h }, u32({ col[1], col[2], col[3], 0.45 }), h / 2, C.rall, 1);
    dl:AddText({ x + 5, y + 1 }, u32(col), text);
    return w;
end

-- Cut a string to fit a width, with "..."
function theme.fit(s, w)
    s = tostring(s or '');
    if tw(s) <= w then return s; end
    while #s > 1 and tw(s .. '...') > w do s = s:sub(1, -2); end
    return s .. '...';
end

-- Break text into lines that fit a width (at spaces; a word longer than the width is split)
function theme.wrap(s, w)
    s = tostring(s or '');
    w = math.max(10, w);
    local lines, line = {}, '';
    local function push_word(word)
        while tw(word) > w do                                        -- (a word too long for any line)
            local k = #word;
            while k > 1 and tw(word:sub(1, k)) > w do k = k - 1; end
            if line ~= '' then lines[#lines + 1] = line; line = ''; end
            lines[#lines + 1] = word:sub(1, k);
            word = word:sub(k + 1);
        end
        local try = line == '' and word or (line .. ' ' .. word);
        if tw(try) <= w then line = try;
        else
            if line ~= '' then lines[#lines + 1] = line; end
            line = word;
        end
    end
    for word in s:gmatch('%S+') do push_word(word); end
    if line ~= '' or #lines == 0 then lines[#lines + 1] = line; end
    return lines;
end

-- Draw wrapped text; returns how tall it was
function theme.wrapped(dl, x, y, s, w, col)
    local lh = imgui.GetTextLineHeight();
    local lines = theme.wrap(s, w);
    for i, l in ipairs(lines) do dl:AddText({ x, y + (i - 1) * lh }, col, l); end
    return #lines * lh, lines;
end

-- A scrolling area with no background of its own
function theme.begin_list(id, w, h)
    imgui.PushStyleColor(ImGuiCol_ChildBg, { 0, 0, 0, 0 });
    local pv = 0;
    if ImGuiStyleVar_ItemSpacing ~= nil then imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 6, 3 }); pv = 1; end
    imgui.BeginChild(id, { w, h }, false);
    return pv;
end
function theme.end_list(pv)
    imgui.EndChild();
    if pv and pv > 0 then imgui.PopStyleVar(pv); end
    imgui.PopStyleColor(1);
end

-- A small checkbox with a label. Returns clicked, hovered (the caller flips its own value).
function theme.checkbox(id, label, on, x, y)
    if x ~= nil then imgui.SetCursorScreenPos({ x, y }); end
    x, y = imgui.GetCursorScreenPos();
    local lh = imgui.GetTextLineHeight();
    local bs = lh;
    local w = bs + 6 + tw(label);
    local clicked = imgui.InvisibleButton(id, { w, bs });
    local hov = imgui.IsItemHovered();
    local dl = imgui.GetWindowDrawList();
    dl:AddRectFilled({ x, y }, { x + bs, y + bs }, u32(on and { NEON[1] * 0.42, NEON[2] * 0.42, NEON[3] * 0.42, 1 } or (hov and { 0.15, 0.14, 0.19, 1 } or { 0.10, 0.09, 0.13, theme.bg })), 4);
    dl:AddRect({ x, y }, { x + bs, y + bs }, u32(on and { NEON2[1], NEON2[2], NEON2[3], 0.9 } or { 1, 1, 1, hov and 0.30 or 0.15 }), 4, C.rall, 1);
    if on then
        local c = u32({ 1, 1, 1, 1 });
        dl:AddLine({ x + bs * 0.22, y + bs * 0.52 }, { x + bs * 0.42, y + bs * 0.72 }, c, 2);
        dl:AddLine({ x + bs * 0.42, y + bs * 0.72 }, { x + bs * 0.78, y + bs * 0.28 }, c, 2);
    end
    dl:AddText({ x + bs + 6, y }, u32((on or hov) and C.text or C.muted), label);
    return clicked, hov;
end

return theme;
