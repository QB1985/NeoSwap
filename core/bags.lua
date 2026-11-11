-- bags.lua : the gear you own, read from the client's memory (as NeoMOG reads it).
--
-- Bag numbers are the game's: 0 Inventory, 1 Mog Safe, 2 Storage, 4 Mog Locker, 5 Mog Satchel, 6 Mog Sack,
-- 7 Mog Case, 8 Mog Wardrobe, 9 Mog Safe 2, 10-16 Mog Wardrobe 2-8. A bag you don't have reads as size 0.
local items = require('core.items');
local augments = require('core.augments');

local bags = {};

bags.NAME = {
    [0] = 'Inventory', [1] = 'Mog Safe', [2] = 'Storage', [4] = 'Mog Locker', [5] = 'Satchel', [6] = 'Sack',
    [7] = 'Case', [8] = 'Wardrobe', [9] = 'Mog Safe 2', [10] = 'Wardrobe 2', [11] = 'Wardrobe 3', [12] = 'Wardrobe 4',
    [13] = 'Wardrobe 5', [14] = 'Wardrobe 6', [15] = 'Wardrobe 7', [16] = 'Wardrobe 8',
};
bags.ALL = { 0, 8, 10, 11, 12, 13, 14, 15, 16, 5, 6, 7, 1, 9, 2, 4 };
-- bags you can equip from (the Wardrobes first, as LuAshitacast looks, then the Inventory)
bags.EQUIP_ORDER = { 8, 10, 11, 12, 13, 14, 15, 16, 0 };
bags.EQUIP_BAGS = { [0] = true, [8] = true, [10] = true, [11] = true, [12] = true, [13] = true, [14] = true, [15] = true, [16] = true };

----------------------------------------------------------------------------------------------------
-- Equipment slots (the game's numbering 0-15: the bit in an item's Slots, and GetEquippedItem's index)
----------------------------------------------------------------------------------------------------
bags.SLOT_NAME = { [0] = 'Main', 'Sub', 'Range', 'Ammo', 'Head', 'Body', 'Hands', 'Legs', 'Feet', 'Neck', 'Waist',
                   'Ear 1', 'Ear 2', 'Ring 1', 'Ring 2', 'Back' };
bags.SLOT_CMD  = { [0] = 'main', 'sub', 'range', 'ammo', 'head', 'body', 'hands', 'legs', 'feet', 'neck', 'waist',
                   'ear1', 'ear2', 'ring1', 'ring2', 'back' };
-- the in-game equipment grid, row by row
bags.SLOT_GRID = { 0, 1, 2, 3,  4, 9, 11, 12,  5, 6, 13, 14,  15, 10, 7, 8 };
-- the slots a lockstyle can hold (Main to Feet)
bags.STYLE_SLOTS = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true };

function bags.slot_from_word(w)
    w = tostring(w or ''):lower():gsub('%s', '');
    local alias = { ear = 'ear1', ring = 'ring1', lear = 'ear1', rear = 'ear2', lring = 'ring1', rring = 'ring2',
                    earring1 = 'ear1', earring2 = 'ear2', ranged = 'range', weapon = 'main', shield = 'sub' };
    w = alias[w] or w;
    for s = 0, 15 do if bags.SLOT_CMD[s] == w then return s; end end
    return nil;
end

----------------------------------------------------------------------------------------------------
-- The snapshot: every item in every bag, and [id] = { count, where = { bag = n } }
----------------------------------------------------------------------------------------------------
local snap = { list = {}, owned = {}, size = {}, at = -10 };
local dirty = true;

function bags.invalidate() dirty = true; end

local function read_all()
    local s = { list = {}, owned = {}, size = {}, at = os.clock() };
    pcall(function()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        for _, b in ipairs(bags.ALL) do
            local max = tonumber(inv:GetContainerCountMax(b)) or 0;
            s.size[b] = math.max(0, (b == 0) and (max - 1) or max);
            for slot = 1, max do
                local ci = inv:GetContainerItem(b, slot);
                if ci ~= nil and ci.Id ~= nil and ci.Id > 0 and ci.Id ~= 0xFFFF then
                    -- everything counts as owned (custom gear with blank data included); the gear lists show equipment
                    local o = s.owned[ci.Id];
                    if o == nil then o = { count = 0, where = {} }; s.owned[ci.Id] = o; end
                    o.count = o.count + 1;
                    o.where[b] = (o.where[b] or 0) + 1;
                    if items.is_equipment(ci.Id) then
                        local e = { id = ci.Id, bag = b, slot = slot, flags = tonumber(ci.Flags) or 0 };
                        e.aug = augments.of(ci);
                        e.sig = augments.sig(e.aug);
                        s.list[#s.list + 1] = e;
                    end
                end
            end
        end
    end);
    return s;
end

-- The latest snapshot (read again when the server changed something, and at least every 3 seconds)
function bags.get(force)
    local now = os.clock();
    if force or (dirty and now - snap.at > 0.15) or now - snap.at > 3.0 then
        snap = read_all();
        dirty = false;
    end
    return snap;
end

function bags.has(b) return (bags.get().size[b] or 0) > 0; end

-- How many of a piece you own, and how many of those sit where you can put them on
function bags.owned(id)
    local o = bags.get().owned[id];
    if o == nil then return 0, 0; end
    local n = 0;
    for b, c in pairs(o.where) do if bags.EQUIP_BAGS[b] then n = n + c; end end
    return o.count, n;
end

-- How many copies have the augments a set's entry asks for: total, and in your Inventory / Wardrobes
function bags.owned_with(g)
    if g == nil or g.id == nil then return 0, 0; end
    if (g.augs == nil or #g.augs == 0) and g.path == nil and g.rank == nil then return bags.owned(g.id); end
    if not items.is_equipment(g.id) then return bags.owned(g.id); end
    local n, reach = 0, 0;
    pcall(function()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        for _, e in ipairs(bags.get().list) do
            if e.id == g.id then
                local ci = inv:GetContainerItem(e.bag, e.slot);
                if ci and ci.Id == g.id and augments.matches(ci, g) then
                    n = n + 1;
                    if bags.EQUIP_BAGS[e.bag] then reach = reach + 1; end
                end
            end
        end
    end);
    return n, reach;
end

-- The augments of what's worn in a slot (an entry for a set), or nil
function bags.worn_augments(s)
    local w = bags.equipped(s);
    if w == nil then return nil; end
    local r = nil;
    pcall(function() r = augments.entry(AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(w.bag, w.slot)); end);
    return r;
end

-- Where a piece is, as words ("Wardrobe 2", "Mog Safe and Inventory")
function bags.where(id)
    local o = bags.get().owned[id];
    if o == nil then return nil; end
    local t = {};
    for _, b in ipairs(bags.ALL) do
        local c = o.where[b];
        if c then t[#t + 1] = (bags.NAME[b] or ('Bag ' .. b)) .. (c > 1 and (' x' .. c) or ''); end
    end
    return table.concat(t, ', ');
end

-- What's worn in a slot: { id, bag, slot } or nil
function bags.equipped(s)
    local r = nil;
    pcall(function()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        local eq = inv:GetEquippedItem(s);
        if eq == nil then return; end
        local idx = tonumber(eq.Index) or 0;
        if bit.band(idx, 0xFF) == 0 then return; end
        local b, sl = bit.rshift(bit.band(idx, 0xFF00), 8), bit.band(idx, 0xFF);
        local ci = inv:GetContainerItem(b, sl);
        if ci ~= nil and ci.Id ~= nil and ci.Id > 0 and ci.Id ~= 0xFFFF then r = { id = ci.Id, bag = b, slot = sl }; end
    end);
    return r;
end

return bags;
