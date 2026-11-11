-- items.lua : item names, icons, tooltips and descriptions (the icon / tooltip code is NeoCrafty's, via NeoMOG)
local ffi   = require('ffi');
local d3d   = require('d3d8');
local imgui = require('imgui');
local theme = require('ui.theme');
local C, u32 = theme.C, theme.u32;

local items = {};

local d3d8dev = d3d.get_device();
local FLAG_RARE = 0x8000;
local FLAG_EX   = 0x4000;
items.FLAG_RARE, items.FLAG_EX = FLAG_RARE, FLAG_EX;

ffi.cdef[[
    int MultiByteToWideChar(uint32_t CodePage, uint32_t dwFlags, const char* lpMultiByteStr, int cbMultiByte, wchar_t* lpWideCharStr, int cchWideChar);
    int WideCharToMultiByte(uint32_t CodePage, uint32_t dwFlags, const wchar_t* lpWideCharStr, int cchWideChar, char* lpMultiByteStr, int cbMultiByte, const char* lpDefaultChar, int* lpUsedDefaultChar);
]];

----------------------------------------------------------------------------------------------------
-- Resources
----------------------------------------------------------------------------------------------------
function items.res(id)
    if id == nil or id == 0 then return nil; end
    return AshitaCore:GetResourceManager():GetItemById(id);
end

function items.name(id)
    local r = items.res(id);
    if r == nil or r.Name == nil or r.Name[1] == nil then return tostring(id); end
    return r.Name[1];
end

function items.stack(id)
    local r = items.res(id);
    if r == nil then return 1; end
    return math.max(1, tonumber(r.StackSize) or 1);
end

function items.is_rare(id)
    local r = items.res(id);
    return r ~= nil and bit.band(r.Flags or 0, FLAG_RARE) ~= 0;
end

function items.is_ex(id)
    local r = items.res(id);
    return r ~= nil and bit.band(r.Flags or 0, FLAG_EX) ~= 0;
end

----------------------------------------------------------------------------------------------------
-- Icons (game item icons, kept in a small LRU cache)
----------------------------------------------------------------------------------------------------
local tex_cache, tex_handle, tex_lru = {}, {}, {};
local TEX_MAX = 384;

local function release(tex)
    if tex == nil or tex == false then return; end
    pcall(function() ffi.gc(tex, nil); tex:Release(); end);
end

local function load_icon(id)
    if tex_cache[id] ~= nil then return tex_cache[id]; end
    local r = items.res(id);
    if r == nil or r.ImageSize == 0 then tex_cache[id] = false; return false; end
    if #tex_lru >= TEX_MAX then
        local old = table.remove(tex_lru, 1);
        release(tex_cache[old]);
        tex_cache[old], tex_handle[old] = nil, nil;
    end
    local ptr = ffi.new('IDirect3DTexture8*[1]');
    if ffi.C.D3DXCreateTextureFromFileInMemoryEx(d3d8dev, r.Bitmap, r.ImageSize, 0xFFFFFFFF, 0xFFFFFFFF, 1, 0,
        ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT, 0xFF000000, nil, nil, ptr) ~= ffi.C.S_OK then
        tex_cache[id] = false;
        return false;
    end
    local tex = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', ptr[0]));
    tex_cache[id] = tex;
    tex_handle[id] = tonumber(ffi.cast('uint32_t', tex));
    tex_lru[#tex_lru + 1] = id;
    return tex;
end

-- An icon at the cursor (advances the cursor like any item)
function items.icon(id, size)
    local tex = load_icon(id);
    if tex and tex_handle[id] then imgui.Image(tex_handle[id], { size, size }); return true; end
    local cx, cy = imgui.GetCursorScreenPos();
    items.draw_icon(imgui.GetWindowDrawList(), id, cx, cy, size);
    imgui.Dummy({ size, size });
    return false;
end

-- An icon drawn at a screen position, without moving the cursor
function items.draw_icon(dl, id, x, y, size)
    local tex = load_icon(id);
    if not (tex and tex_handle[id]) then
        -- no icon in the game's data (custom server gear): a tile with the piece's first letter
        dl:AddRectFilled({ x, y }, { x + size, y + size }, u32({ 1, 1, 1, 0.08 }), 4);
        dl:AddRect({ x, y }, { x + size, y + size }, u32({ 1, 1, 1, 0.18 }), 4);
        local n = items.name(id) or '';
        local l = n:match('%a') or '?';
        local tw, th = imgui.CalcTextSize(l);
        if type(tw) == 'table' then tw, th = tw.x or tw[1], tw.y or tw[2]; end
        dl:AddText({ x + (size - (tw or 0)) / 2, y + (size - (th or 0)) / 2 }, u32({ 1, 1, 1, 0.55 }), l:upper());
        return false;
    end
    local ok = pcall(function() dl:AddImage(tex_handle[id], { x, y }, { x + size, y + size }); end);
    if not ok then
        local cx, cy = imgui.GetCursorScreenPos();
        imgui.SetCursorScreenPos({ x, y });
        imgui.Image(tex_handle[id], { size, size });
        imgui.SetCursorScreenPos({ cx, cy });
    end
    return true;
end

function items.unload()
    for _, t in pairs(tex_cache) do release(t); end
    tex_cache, tex_handle, tex_lru = {}, {}, {};
end

----------------------------------------------------------------------------------------------------
-- Descriptions (Shift-JIS, with the element glyphs turned into coloured dots)
----------------------------------------------------------------------------------------------------
local ELEMENT_COLORS = {
    [0x1F] = { 1.00, 0.45, 0.25, 1 }, [0x20] = { 0.55, 0.85, 1.00, 1 }, [0x21] = { 0.55, 1.00, 0.55, 1 },
    [0x22] = { 0.90, 0.75, 0.45, 1 }, [0x23] = { 1.00, 0.90, 0.30, 1 }, [0x24] = { 0.45, 0.60, 1.00, 1 },
    [0x25] = { 1.00, 1.00, 0.85, 1 }, [0x26] = { 0.75, 0.45, 1.00, 1 },
};
local MARK = 0x01;
local sjis_buf  = ffi.new('char[4096]');
local sjis_wbuf = ffi.new('wchar_t[4096]');

local function mark_elements(s)
    if s:find('\xEF', 1, true) == nil then return s; end
    local out, i, n = {}, 1, #s;
    while i <= n do
        local b = s:byte(i);
        if b == 0xEF and i < n and ELEMENT_COLORS[s:byte(i + 1)] ~= nil then
            out[#out + 1] = string.char(MARK, s:byte(i + 1));
            i = i + 2;
        else
            out[#out + 1] = s:sub(i, i);
            i = i + 1;
        end
    end
    return table.concat(out);
end

local function sjis_to_utf8(s)
    if s == nil then return nil; end
    s = mark_elements(s);
    if #s >= 4000 then s = s:sub(1, 4000); end
    ffi.copy(sjis_buf, s);
    ffi.C.MultiByteToWideChar(932, 0, sjis_buf, -1, sjis_wbuf, 4096);
    ffi.C.WideCharToMultiByte(65001, 0, sjis_wbuf, -1, sjis_buf, 4096, nil, nil);
    return ffi.string(sjis_buf);
end

local function draw_description(desc, col, wrap_w)
    local line_w, started = 0, false;
    local function before(w)
        if started and line_w + w > wrap_w then line_w = 0;
        elseif started then imgui.SameLine(0, 0); end
    end
    local i, n = 1, #desc;
    while i <= n do
        local b = desc:byte(i);
        if b == 0x0A then
            if not started then imgui.Text(''); end
            line_w, started = 0, false;
            i = i + 1;
        elseif b == MARK and i < n then
            local ec = ELEMENT_COLORS[desc:byte(i + 1)];
            if ec then
                before(10);
                local sx, sy = imgui.GetCursorScreenPos();
                local lh = imgui.GetTextLineHeight();
                imgui.GetWindowDrawList():AddCircleFilled({ sx + 5, sy + lh / 2 }, 3, u32(ec), 12);
                imgui.Dummy({ 10, lh });
                line_w, started = line_w + 10, true;
            end
            i = i + 2;
        else
            local s = i;
            while i <= n do
                local bb = desc:byte(i);
                if bb == 0x0A or bb == MARK then break; end
                i = i + 1;
            end
            -- split long runs into words so they wrap
            for word in desc:sub(s, i - 1):gmatch('%S+%s*') do
                local w = imgui.CalcTextSize(word);
                before(w);
                imgui.TextColored(col, (word:gsub('%%', '%%%%')));
                line_w, started = line_w + w, true;
            end
        end
    end
end

----------------------------------------------------------------------------------------------------
-- The item tooltip: icon, name, tags, description, then any extra lines { { text, colour }, ... }
----------------------------------------------------------------------------------------------------
local JOBS = { 'WAR','MNK','WHM','BLM','RDM','THF','PLD','DRK','BST','BRD','RNG','SAM','NIN','DRG','SMN','BLU','COR','PUP','DNC','SCH','GEO','RUN' };

local function job_list(jobs)
    if jobs == nil or jobs == 0 then return nil; end
    if bit.band(jobs, 0x7FFFFE) == 0x7FFFFE then return 'All Jobs'; end
    local t = {};
    for i = 1, 22 do if bit.band(jobs, bit.lshift(1, i)) ~= 0 then t[#t + 1] = JOBS[i]; end end
    return table.concat(t, '/');
end

function items.tooltip(id, name, extra)
    local r = items.res(id);
    name = name or items.name(id);
    if not theme.begin_tip(380) then return; end
    items.icon(id, 32);
    imgui.SameLine(0, 8);
    imgui.BeginGroup();
    imgui.TextColored(C.text, theme.safe(name));
    local tags = {};
    if r and bit.band(r.Flags or 0, FLAG_RARE) ~= 0 then tags[#tags + 1] = { 'RARE', C.gold }; end
    if r and bit.band(r.Flags or 0, FLAG_EX) ~= 0 then tags[#tags + 1] = { 'EX', C.acc }; end
    if r and (r.StackSize or 1) > 1 then tags[#tags + 1] = { 'Stack ' .. r.StackSize, C.muted }; end
    for k, t in ipairs(tags) do
        if k > 1 then imgui.SameLine(0, 8); end
        imgui.TextColored(t[2], theme.safe(t[1]));
    end
    imgui.EndGroup();
    if r then
        local desc = r.Description and r.Description[1] and sjis_to_utf8(r.Description[1]) or nil;
        if desc and #desc > 0 then
            imgui.Spacing();
            draw_description(desc, { 0.80, 0.80, 0.88, 1 }, 360);
        end
        if (r.Level or 0) > 0 or (r.Jobs or 0) > 0 then
            local s = ((r.Level or 0) > 0 and ('Lv' .. r.Level .. ' ') or '') .. (job_list(r.Jobs) or '');
            imgui.TextColored(C.acc, theme.safe(s));
        end
    end
    if extra and #extra > 0 then
        imgui.Spacing();
        for _, l in ipairs(extra) do imgui.TextColored(l[2] or C.muted, theme.safe(l[1])); end
    end
    theme.end_tip();
end

-- The description as plain text (element marks dropped), for reading gear effects
local desc_cache = {};
function items.description(id)
    local d = desc_cache[id];
    if d ~= nil then return d; end
    d = '';
    local r = items.res(id);
    if r and r.Description and r.Description[1] then
        local ok, t = pcall(sjis_to_utf8, r.Description[1]);
        if ok and t then d = t:gsub('\1.', ' '); end
    end
    desc_cache[id] = d;
    return d;
end

-- Find an item by name: the short name or the full (log) name, any case.
-- "a pair of ...", "a set of ..." and the like are ignored. Returns the id or nil.
local name_index = nil;
local function norm(n)
    n = tostring(n or ''):lower();
    n = n:gsub('^an? ', ''):gsub('^pairs? of ', ''):gsub('^sets? of ', ''):gsub('^suits? of ', ''):gsub('^pieces? of ', '')
         :gsub('^chunks? of ', ''):gsub('^bottles? of ', ''):gsub('^slices? of ', ''):gsub('^sprigs? of ', ''):gsub('^handfuls? of ', '')
         :gsub('^squares? of ', ''):gsub('^bolts? of ', ''):gsub('^spools? of ', ''):gsub('^pinch of ', ''):gsub('^jars? of ', '')
         :gsub('^flasks? of ', ''):gsub('^lumps? of ', ''):gsub('^bags? of ', ''):gsub('^loa?ve?s? of ', ''):gsub('^bowls? of ', '')
         :gsub('^pots? of ', ''):gsub('^cups? of ', ''):gsub('^vials? of ', ''):gsub('^clumps? of ', ''):gsub('^strips? of ', '');
    n = n:gsub('%s+', ' '):gsub('^ ', ''):gsub(' $', '');
    return n;
end
items.norm_name = norm;

function items.find_by_name(name)
    if name_index == nil then
        name_index = {};
        local rm = AshitaCore:GetResourceManager();
        for id = 1, 65535 do
            local r = rm:GetItemById(id);
            if r ~= nil then
                local short = r.Name and r.Name[1];
                if short and #short > 1 then
                    local k = norm(short);
                    if name_index[k] == nil then name_index[k] = id; end
                end
                local okl, long = pcall(function() return r.LogNameSingular[1]; end);
                if okl and long and #long > 1 then
                    local k = norm(long);
                    if name_index[k] == nil then name_index[k] = id; end
                end
            end
        end
    end
    return name_index[norm(name)];
end

-- Items whose name has `text`: { { id, name } }, names starting with it first
function items.search(text, max)
    items.find_by_name('');
    text = norm(text);
    local out, seen = {}, {};
    if #text < 2 then return out; end
    for k, id in pairs(name_index) do
        if not seen[id] and k:find(text, 1, true) then
            seen[id] = true;
            out[#out + 1] = { id = id, name = items.name(id), starts = k:sub(1, #text) == text };
        end
    end
    table.sort(out, function(a, b)
        if a.starts ~= b.starts then return a.starts; end
        return a.name < b.name;
    end);
    while #out > (max or 24) do table.remove(out); end
    return out;
end

----------------------------------------------------------------------------------------------------
-- The full name ("pair of kingdom gauntlets" -> "Kingdom Gauntlets"), for searches and the wiki
----------------------------------------------------------------------------------------------------
local long_cache = {};
function items.long_name(id)
    local v = long_cache[id];
    if v ~= nil then return v; end
    v = items.name(id);
    local r = items.res(id);
    local ok, l = pcall(function() return r and r.LogNameSingular and r.LogNameSingular[1]; end);
    if ok and type(l) == 'string' and #l > 1 then
        l = norm(l);
        l = l:gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b; end);
        l = l:gsub(' Of ', ' of '):gsub(' The ', ' the '):gsub(' And ', ' and ');
        v = l;
    end
    long_cache[id] = v;
    return v;
end

----------------------------------------------------------------------------------------------------
-- Equipment: which slots a piece goes in, who can wear it, and every piece in the game (for planning)
----------------------------------------------------------------------------------------------------
-- Weapon skill types that take both hands (the Sub slot can then hold only a grip)
local TWO_HANDED = { [1] = true, [4] = true, [6] = true, [7] = true, [8] = true, [10] = true, [12] = true };

-- Custom server pieces with blank slot data (data/custom_items.lua): [lower-case name] = { slots }
local CUSTOM = require('data.custom_items');
local function custom_by_name(r)
    local n = r and r.Name and r.Name[1];
    return n and CUSTOM[n:lower()] or nil;
end

-- A listed custom piece (data/custom_items.lua): its slots. Goes by name, whatever the game's data says now, since
-- the server's item data for these can change (blank one day, half-filled the next).
function items.custom(id)
    return custom_by_name(items.res(id));
end

-- Gear only /equip can put on: blank slot data, a listed custom piece, or a piece the game's data doesn't mark as
-- wearable. (An equip packet for these is ignored, so they'd never go on.)
function items.blank(id)
    local r = items.res(id);
    if r == nil then return false; end
    if (tonumber(r.Slots) or 0) == 0 then return true; end
    if custom_by_name(r) then return true; end
    return bit.band(tonumber(r.Flags) or 0, 0x800) == 0;
end

function items.slots(id)
    local r = items.res(id);
    local sl = r and (tonumber(r.Slots) or 0) or 0;
    local c = r and custom_by_name(r);
    if c then for _, s in ipairs(c) do sl = bit.bor(sl, bit.lshift(1, s)); end end
    return sl;
end

-- Slots a piece covers besides its own ("Cannot equip headgear" on a cloak, and the like), read from its
-- description: { [slot] = true } or nil. Slots: 4 head, 5 body, 6 hands, 7 legs, 8 feet.
local BLOCK_WORDS = {
    { 'head', 4 }, { 'body', 5 }, { 'hand', 6 }, { 'glove', 6 }, { 'leg', 7 }, { 'feet', 8 }, { 'foot', 8 },
};
local block_cache = {};
function items.blocks(id)
    if id == nil then return nil; end
    local v = block_cache[id];
    if v ~= nil then return v or nil; end
    v = false;
    local d = (items.description(id) or ''):lower():gsub('%s+', ' ');
    for clause in d:gmatch('cannot equip ([^%.%(\n]+)') do
        for _, w in ipairs(BLOCK_WORDS) do
            if clause:find(w[1], 1, true) then v = v or {}; v[w[2]] = true; end
        end
    end
    if v and (items.slots(id) or 0) ~= 0 then                       -- (never its own slot)
        for sl in pairs(v) do if items.fits(id, sl) then v[sl] = nil; end end
        if next(v) == nil then v = false; end
    end
    block_cache[id] = v;
    return v or nil;
end

-- For a set's gear (slots 0-15, entries with .id): { [slot] = id of the piece that covers it }
function items.blocked_in(gear)
    local out = nil;
    if gear == nil then return nil; end
    for s = 0, 15 do
        local g = gear[s];
        local b = g and g.id and not g.remove and items.blocks(g.id);
        if b then for sl in pairs(b) do out = out or {}; out[sl] = g.id; end end
    end
    return out;
end

function items.fits(id, s) return bit.band(items.slots(id), bit.lshift(1, s)) ~= 0; end

function items.level(id)
    local r = items.res(id);
    return r and (tonumber(r.Level) or 0) or 0;
end

function items.job_ok(id, job)
    local r = items.res(id);
    if r == nil then return false; end
    if items.custom(id) then return true; end                        -- (blank data: anyone, as far as we know)
    return bit.band(tonumber(r.Jobs) or 0, bit.lshift(1, job or 0)) ~= 0;
end

function items.two_handed(id)
    local r = items.res(id);
    return r ~= nil and TWO_HANDED[tonumber(r.Skill) or 0] == true;
end

-- A grip: goes in Sub, no weapon skill, no shield size
function items.is_grip(id)
    local r = items.res(id);
    if r == nil then return false; end
    local shield = 0;
    pcall(function() shield = tonumber(r.ShieldSize) or 0; end);
    return (tonumber(r.Skill) or 0) == 0 and shield == 0 and bit.band(tonumber(r.Slots) or 0, 2) ~= 0;
end

function items.is_equipment(id)
    return items.slots(id) ~= 0;
end

-- Every piece of equipment in the game: { id, name, lname, slots, jobs, level }. Built once, when first asked.
local all_gear = nil;
function items.all_gear()
    if all_gear ~= nil then return all_gear; end
    all_gear = {};
    local rm = AshitaCore:GetResourceManager();
    local seen = {};
    for id = 1, 65535 do
        local r = rm:GetItemById(id);
        if r ~= nil and (tonumber(r.Slots) or 0) ~= 0 then
            local n = r.Name and r.Name[1];
            if n and #n > 1 and n ~= '.' then
                local key = n:lower() .. ':' .. tostring(r.Slots);
                if not seen[key] then
                    seen[key] = true;
                    all_gear[#all_gear + 1] = { id = id, name = n, lname = n:lower(), slots = tonumber(r.Slots) or 0,
                                                jobs = tonumber(r.Jobs) or 0, level = tonumber(r.Level) or 0 };
                end
            end
        end
    end
    return all_gear;
end

return items;
