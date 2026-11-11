-- icon_pick.lua : an icon (an item's icon or a job emblem) and the picker that chooses one. Used by custom entries in
-- the jobs list and by command buttons. An icon is { item = id } or { job = 'WHM' }.
local imgui  = require('imgui');
local theme  = require('ui.theme');
local when   = require('ui.when');
local items  = require('core.items');
local jobs   = require('core.jobs');
local store  = require('core.store');
local tex    = require('ui.tex');
local C, u32, tip, tw = theme.C, theme.u32, theme.tip, theme.tw;
local NEON = theme.NEON;

local pick = {};

-- Draw an icon; with none, a violet disc with the first letter of `name`
function pick.draw(dl, ic, x, y, size, a, name)
    if ic and ic.item then items.draw_icon(dl, ic.item, x, y, size); return true; end
    if ic and ic.job and tex.job(dl, ic.job, x, y, size, a or 1) then return true; end
    local cx, cy = x + size / 2, y + size / 2;
    dl:AddCircleFilled({ cx, cy }, size / 2, u32({ NEON[1] * 0.42, NEON[2] * 0.42, NEON[3] * 0.42, a or 1 }), 24);
    local t = tostring(name or '?'):sub(1, 1):upper();
    dl:AddText({ cx - tw(t) / 2, cy - imgui.GetTextLineHeight() / 2 }, u32({ 1, 1, 1, a or 1 }), t);
    return true;
end

local search = { '' };
local preset_cache = {};

function pick.reset_search() search[1] = ''; end

-- The popup (open it with imgui.OpenPopup(id)). `target.icon` is set to what's clicked.
-- sections: { { title = 'GATHERING & CRAFTING', list = { { label, item = 'Item name' }, ... } }, ... }
function pick.menu(id, target, sections)
    local pv = when.popup_style();
    if imgui.BeginPopup(id) then
        local dl = imgui.GetWindowDrawList();
        local function grid(list, kind)
            local cols, cs = 8, 36;
            local x0, y0 = imgui.GetCursorScreenPos();
            for i, ic in ipairs(list) do
                local col, row = (i - 1) % cols, math.floor((i - 1) / cols);
                local x, y = x0 + col * (cs + 4), y0 + row * (cs + 4);
                imgui.SetCursorScreenPos({ x, y });
                local c = imgui.InvisibleButton(id .. '_' .. kind .. i, { cs, cs });
                local hov = imgui.IsItemHovered();
                dl:AddRectFilled({ x, y }, { x + cs, y + cs }, u32(hov and { 0.18, 0.16, 0.24, 1 } or { 0.08, 0.075, 0.11, 1 }), 6);
                if ic.item then items.draw_icon(dl, ic.item, x + 2, y + 2, 32);
                elseif ic.job then tex.job(dl, ic.job, x + 3, y + 3, 30, 1); end
                if hov then tip(ic.label or ''); end
                if c then
                    target.icon = ic.item and { item = ic.item } or { job = ic.job };
                    store.touch();
                    imgui.CloseCurrentPopup();
                end
            end
            local rows = math.ceil(#list / cols);
            imgui.SetCursorScreenPos({ x0, y0 + rows * (cs + 4) });
            imgui.Dummy({ cols * (cs + 4), 2 });
        end
        local function head(t)
            local hx, hy = imgui.GetCursorScreenPos();
            theme.spaced(dl, hx, hy, t, u32(C.muted), 1.5);
            imgui.Dummy({ 10, imgui.GetTextLineHeight() + 2 });
        end
        for si, sec in ipairs(sections or {}) do
            local key = id .. si;
            local pre = preset_cache[key];
            if pre == nil then
                pre = {};
                for _, p in ipairs(sec.list) do
                    local iid = items.find_by_name(p.item);
                    if iid then pre[#pre + 1] = { item = iid, label = p.label .. '  (' .. items.name(iid) .. ')' }; end
                end
                if #pre > 0 then preset_cache[key] = pre; end
            end
            if #pre > 0 then head(sec.title); grid(pre, 'p' .. si); end
        end
        head('JOBS');
        local jl = {};
        for i, a in ipairs(jobs.ABBR) do jl[#jl + 1] = { job = a, label = jobs.NAME[i] }; end
        grid(jl, 'j');
        head('ANY ITEM');
        theme.input(id .. '_search', search, 48, 8 * 40 - 4, 'Search items (2+ letters)...', true);
        local found = {};
        for _, f in ipairs(items.search(search[1] or '', 16)) do found[#found + 1] = { item = f.id, label = f.name }; end
        if #found > 0 then grid(found, 's'); end
        imgui.EndPopup();
    end
    when.popup_pop(pv);
end

return pick;
