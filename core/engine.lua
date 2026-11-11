-- engine.lua : the gear swapper. It works the way LuAshitacast does (and much of it is LuAshitacast's code,
-- by Thorny, GPL-3.0): the game's action packets (spells, weapon skills, abilities, ranged attacks, items) are
-- held back, the set for that action is put on, then the action is sent. Between actions the Idle / Engaged /
-- Resting sets are kept on. Which sets go on comes from your NeoSwap sets (core/rules.lua) instead of a profile.
local ffi    = require('ffi');
local chat   = require('chat');
local config = require('configs.config');
local store  = require('core.store');
local rules  = require('core.rules');
local game   = require('core.game');
local items  = require('core.items');
local bags   = require('core.bags');
local jobs   = require('core.jobs');
local augments = require('core.augments');
local tiers  = require('core.tiers');

pcall(function() ffi.cdef[[ int32_t memcmp(const void* buff1, const void* buff2, size_t count); ]]; end);

local engine = {
    action = nil,          -- what you're doing: { type, name, skill, element, completion, packet, target, block, resend }
    pet_action = nil,      -- what your pet is doing
    disabled = {},         -- [slot 1-16] = true: NeoSwap leaves it alone (/nswap disable, Equip now)
    encumbrance = {},      -- [slot 1-16] = true: the game has locked the slot
    injecting = false,
    last = nil,            -- what the last swap put on, for the window: { at, event, sets = { names } }
    other_caster = false,  -- another addon (LuAshitacast) seems to be re-sending actions too
    pos_x = nil, pos_y = nil, moving = false,
    zone_timer = 0,
    chunk_ok = true,
    _missing = {},
    _custom_sent = {},
    _covered = {},
    lockstyle_on = false,
};
for i = 1, 16 do engine.disabled[i] = false; engine.encumbrance[i] = false; end

local ACTION_DONE = { [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [14] = true, [15] = true };
local PET_DONE = { [4] = true, [11] = true, [13] = true };
local ABILITY_TYPES = { [10] = 'Rune Enchantment', [102] = 'Ready', [173] = 'Blood Pact: Rage', [174] = 'Blood Pact: Ward',
                        [193] = 'Corsair Roll', [195] = 'Quick Draw' };

local inv_mgr = AshitaCore:GetMemoryManager():GetInventory();
local res_mgr = AshitaCore:GetResourceManager();

local function say(msg) print(chat.header('NeoSwap') .. chat.message(msg)); end
local function dbg(msg) if config.get('debug') then print(chat.header('NeoSwap') .. chat.color1(6, msg)); end end

local function clean(s) if type(s) ~= 'string' then return nil; end return (s:gsub('%z.*$', '')); end

----------------------------------------------------------------------------------------------------
-- Is the engine working now?
----------------------------------------------------------------------------------------------------
function engine.job_abbr() return jobs.ABBR[jobs.main()]; end

function engine.active()
    if not config.get('engine_on') or not store.ready() then return false; end
    local abbr = engine.job_abbr();
    if abbr == nil then return false; end
    if #store.sets(abbr) > 0 then return true; end
    for _, k in ipairs(store.active_entry_keys()) do if #store.sets(k) > 0 then return true; end end
    return false;
end

-- The set lists in play: your job's, then each active custom entry's (they go on over the job's)
local function groups_for(abbr)
    local g = { store.sets(abbr) };
    for _, k in ipairs(store.active_entry_keys()) do g[#g + 1] = store.sets(k); end
    return g;
end

----------------------------------------------------------------------------------------------------
-- Equipping (LuAshitacast's equip.lua, matching pieces by item id)
----------------------------------------------------------------------------------------------------
local internal = {};                                                  -- [slot 1-16] = { container, item, timer }: what we just sent
local cur_job, cur_level = 0, 0;

local function update_job()
    pcall(function()
        local p = AshitaCore:GetMemoryManager():GetPlayer();
        cur_job = p:GetMainJob();
        cur_level = p:GetMainJobLevel();
    end);
end

-- What's in a slot (1-16), counting what we sent a moment ago
local function current(slot)
    local e = internal[slot];
    if e ~= nil and os.clock() < e.timer then return e; end
    internal[slot] = nil;
    local r = { container = 0, item = nil };
    local eq = inv_mgr:GetEquippedItem(slot - 1);
    local idx = eq and bit.band(eq.Index, 0x00FF) or 0;
    if idx ~= 0 then
        r.container = bit.rshift(bit.band(eq.Index, 0xFF00), 8);
        r.item = inv_mgr:GetContainerItem(r.container, idx);
        if r.item == nil or r.item.Id == 0 or r.item.Count == 0 then r.item = nil; end
    end
    return r;
end
engine.current = current;

local function can_wear(res)
    if res == nil then return false; end
    if bit.band(res.Flags, 0x800) == 0 then return false; end
    if cur_level < res.Level then return false; end
    if bit.band(res.Jobs, bit.lshift(1, cur_job)) == 0 then return false; end
    return true;
end

local function bag_ok(b)
    local ok, max = pcall(function() return inv_mgr:GetContainerCountMax(b); end);
    return ok and (tonumber(max) or 0) > 0;
end

-- want: [slot 1-16] = { id = n } or { remove = true }. style: 'set' (one packet), 'single' (one per slot), 'auto'.
local function equip_set(want, style)
    update_job();

    -- pieces that cover other slots (a cloak: "Cannot equip headgear"): what ends up worn decides, so a covered
    -- slot is left alone instead of fighting the cloak forever
    local covered = {};
    for slot = 1, 16 do
        local w = want[slot];
        local id = nil;
        if w ~= nil and w.id ~= nil and not engine.disabled[slot] and not engine.encumbrance[slot] then id = w.id;
        elseif w == nil or not w.remove or engine.disabled[slot] or engine.encumbrance[slot] then
            local c = current(slot);
            id = c.item and c.item.Id or nil;
        end
        local b = id and items.blocks(id);
        if b then for sl in pairs(b) do covered[sl + 1] = id; end end
    end
    if next(covered) ~= nil then
        local w2 = {};
        for slot = 1, 16 do
            if covered[slot] and want[slot] ~= nil and want[slot].id ~= nil then
                if config.get('debug') and (engine._covered[slot] or 0) ~= want[slot].id then
                    dbg(bags.SLOT_NAME[slot - 1] .. ': ' .. items.name(want[slot].id) .. ' left off - ' .. items.name(covered[slot]) .. ' covers it.');
                end
                engine._covered[slot] = want[slot].id;
            else
                w2[slot] = want[slot];
                engine._covered[slot] = nil;
            end
        end
        want = w2;
    else
        engine._covered = {};
    end

    local plan = {};                                                  -- [slot] = { index, container } to send
    local reserved = {};                                              -- [container:index] = true: worn and staying
    local worn = {};                                                  -- [slot] = { container, index }

    -- what's on now, and what can stay
    local all_ok = true;
    for slot = 1, 16 do
        local c = current(slot);
        local w = want[slot];
        if c.item ~= nil then
            worn[slot] = { container = c.container, index = c.item.Index };
            local stays = false;
            if w ~= nil and w.id ~= nil and c.item.Id == w.id and augments.matches(c.item, w) then stays = true; end
            if engine.disabled[slot] or engine.encumbrance[slot] then stays = true; end
            if stays then reserved[c.container .. ':' .. c.item.Index] = true; end
            if w ~= nil and not stays then all_ok = false; end
        else
            if w ~= nil and w.id ~= nil and not engine.disabled[slot] and not engine.encumbrance[slot] then all_ok = false; end
        end
    end
    if all_ok then return 0; end

    -- find each piece (Wardrobes first, then the Inventory)
    local taken = {};
    for slot = 1, 16 do
        local w = want[slot];
        if w ~= nil and not engine.disabled[slot] and not engine.encumbrance[slot] then
            local c = current(slot);
            if w.remove then
                if c.item ~= nil then plan[slot] = { index = 0, container = c.container }; end
            elseif w.id ~= nil and not (c.item ~= nil and c.item.Id == w.id and augments.matches(c.item, w)) and items.blank(w.id) then
                -- a custom server piece (blank slot data): the game's own /equip does it
                local now = os.clock();
                local _, reach = bags.owned(w.id);
                if reach > 0 and now - (engine._custom_sent[slot] or 0) > 2 then
                    engine._custom_sent[slot] = now;
                    AshitaCore:GetChatManager():QueueCommand(1, '/equip ' .. bags.SLOT_CMD[slot - 1] .. ' "' .. items.name(w.id) .. '"');
                    dbg(bags.SLOT_NAME[slot - 1] .. ': ' .. items.name(w.id) .. ' (/equip)');
                elseif reach == 0 and config.get('debug') and (engine._missing[w.id] or 0) < now then
                    engine._missing[w.id] = now + 30;
                    dbg('Can\'t put on ' .. items.name(w.id) .. ': not in your Inventory / Wardrobes.');
                end
            elseif w.id ~= nil and not (c.item ~= nil and c.item.Id == w.id and augments.matches(c.item, w)) then
                local found = nil;
                local res = res_mgr:GetItemById(w.id);
                if can_wear(res) and bit.band(res.Slots, bit.lshift(1, slot - 1)) ~= 0 then
                    for _, b in ipairs(bags.EQUIP_ORDER) do
                        if bag_ok(b) then
                            local max = math.min(80, inv_mgr:GetContainerCountMax(b));
                            for i = 1, max do
                                local it = inv_mgr:GetContainerItem(b, i);
                                if it ~= nil and it.Id == w.id and it.Count > 0 and it.Flags ~= 19 and augments.matches(it, w) then
                                    local k = b .. ':' .. it.Index;
                                    if not reserved[k] and not taken[k] then found = { index = it.Index, container = b, key = k }; break; end
                                end
                            end
                            if found then break; end
                        end
                    end
                end
                if found then taken[found.key] = true; plan[slot] = found;
                elseif config.get('debug') then
                    local k = w.id .. ':' .. slot;
                    if (engine._missing[k] or 0) < os.clock() then
                        engine._missing[k] = os.clock() + 30;
                        dbg('Can\'t put on ' .. (w.name or items.name(w.id)) .. ' (' .. bags.SLOT_NAME[slot - 1] .. '): not in your Inventory / Wardrobes, or not wearable now.');
                    end
                end
            end
        end
    end

    local list = {};
    -- a slot covered by what's on now (Head under a cloak) goes after the piece that frees it
    local worn_cover = {};
    for slot = 1, 16 do
        local c = current(slot);
        local b = c.item and items.blocks(c.item.Id);
        if b then for sl in pairs(b) do worn_cover[sl] = true; end end
    end
    for pass = 1, 2 do
        for slot = 1, 16 do
            if plan[slot] and ((pass == 1) ~= (worn_cover[slot - 1] == true)) then
                list[#list + 1] = { slot = slot - 1, index = plan[slot].index, container = plan[slot].container };
            end
        end
    end
    if #list == 0 then return 0; end

    -- take off anything we're about to move into another slot
    for _, e in ipairs(list) do
        for slot, wv in pairs(worn) do
            if e.index ~= 0 and wv.index == e.index and wv.container == e.container and slot - 1 ~= e.slot
                and not reserved[wv.container .. ':' .. wv.index] then
                AshitaCore:GetPacketManager():AddOutgoingPacket(0x50, { 0x00, 0x00, 0x00, 0x00, 0, slot - 1, wv.container, 0x00 });
                internal[slot] = { container = 0, item = nil, timer = os.clock() + 0.2 };
            end
        end
    end

    local function note(e)
        local entry = { container = 0, item = nil, timer = os.clock() + 0.2 };
        if e.index ~= 0 then entry.container = e.container; entry.item = inv_mgr:GetContainerItem(e.container, e.index); end
        internal[e.slot + 1] = entry;
        if config.get('debug') then
            if e.index == 0 then dbg('Taking off ' .. bags.SLOT_NAME[e.slot]);
            elseif entry.item then dbg(bags.SLOT_NAME[e.slot] .. ': ' .. items.name(entry.item.Id)); end
        end
    end

    if style == 'set' or (style ~= 'single' and #list >= 9) then
        local packet = {};
        for i = 1, 72 do packet[i] = 0x00; end
        for n, e in ipairs(list) do
            packet[5] = n;
            local off = 4 + n * 4 + 1;
            packet[off], packet[off + 1], packet[off + 2] = e.index, e.slot, e.container;
            note(e);
        end
        AshitaCore:GetPacketManager():AddOutgoingPacket(0x51, packet);
    else
        for _, e in ipairs(list) do
            AshitaCore:GetPacketManager():AddOutgoingPacket(0x50, { 0x00, 0x00, 0x00, 0x00, e.index, e.slot, e.container, 0x00 });
            note(e);
        end
    end
    return #list;
end

-- A set's gear (slots 0-15) as the engine wants it (slots 1-16)
local function to_want(gear)
    local w = {};
    for s = 0, 15 do
        local g = gear[s];
        if g ~= nil then
            if g.remove then w[s + 1] = { remove = true };
            elseif g.id then w[s + 1] = { id = g.id, name = g.name, augs = g.augs, path = g.path, rank = g.rank }; end
        end
    end
    return w;
end

----------------------------------------------------------------------------------------------------
-- The moment: which sets apply now
----------------------------------------------------------------------------------------------------
local function make_ctx()
    local memo = {};
    local function once(k, f) return function() if memo[k] == nil then memo[k] = { f() }; end return memo[k][1]; end; end
    return {
        status  = once('status', game.status),
        vitals  = once('vitals', game.vitals),
        buffs   = once('buffs', game.buffs),
        sub     = once('sub', function() return jobs.ABBR[jobs.sub()]; end),
        vana    = once('vana', game.vana),
        weather = once('weather', game.weather_element),
        pet     = once('pet', game.pet),
        zone    = once('zone', game.zone_name),
        level   = once('level', jobs.main_level),
        moving  = function() return engine.moving; end,
        mode    = function(n) return store.mode(n); end,
        action  = engine.action,
        pet_action = engine.pet_action,
    };
end
engine.make_ctx = make_ctx;

local function run(event, style)
    local abbr = engine.job_abbr();
    if abbr == nil then return; end
    local groups = groups_for(abbr);
    local any = false;
    for _, g in ipairs(groups) do if #g > 0 then any = true; end end
    if not any then return; end
    local ctx = make_ctx();
    local kinds;
    if event == 'default' then
        local st = ctx.status();
        if st == 'Dead' or st == 'Zoning' then return; end
        kinds = rules.kinds_for('default', st);
        if engine.pet_action ~= nil then kinds.pet = true; end
    else
        kinds = rules.kinds_for(event);
        if event == 'item' and (rules.mounting_until or 0) > os.clock() then kinds.chocobo = true; end
    end
    local hits = {};
    for _, g in ipairs(groups) do for _, h in ipairs(rules.pick(g, kinds, ctx)) do hits[#hits + 1] = h; end end
    if #hits == 0 then return; end
    local gear = rules.layer(hits, ctx.level());
    local n = equip_set(to_want(gear), style);
    if n > 0 or event ~= 'default' then
        local names = {};
        for _, h in ipairs(hits) do names[#names + 1] = h.set.name; end
        engine.last = { at = os.clock(), event = event, sets = names, action = engine.action and engine.action.name };
    end
end

-- Which sets would be on right now (for the window): the list of set ids
function engine.preview()
    local abbr = engine.job_abbr();
    if abbr == nil then return {}; end
    local ctx = make_ctx();
    local kinds = rules.kinds_for('default', ctx.status());
    local t = {};
    for _, g in ipairs(groups_for(abbr)) do
        for _, h in ipairs(rules.pick(g, kinds, ctx)) do t[h.set.id] = true; end
    end
    return t;
end

-- Put a set on now (Equip now / /nswap set). hold: lock the slots it uses until /nswap unlock.
function engine.wear(set, hold)
    if set == nil then return 0; end
    local was = {};
    for i = 1, 16 do was[i] = engine.disabled[i]; engine.disabled[i] = false; end
    local eff = tiers.effective(set, jobs.main_level());
    local n = equip_set(to_want(eff), 'auto');
    for i = 1, 16 do engine.disabled[i] = was[i]; end
    if hold then
        for s = 0, 15 do
            local g = eff[s];
            if g and (g.id or g.remove) then engine.disabled[s + 1] = true; end
        end
    end
    engine.last = { at = os.clock(), event = 'manual', sets = { set.name } };
    return n;
end

function engine.unlock_all() for i = 1, 16 do engine.disabled[i] = false; end end
function engine.locked_slots()
    local t = {};
    for i = 1, 16 do if engine.disabled[i] then t[#t + 1] = bags.SLOT_NAME[i - 1]; end end
    return t;
end

----------------------------------------------------------------------------------------------------
-- Actions (LuAshitacast's packethandlers.lua)
----------------------------------------------------------------------------------------------------
local function inject(id, data)
    engine.injecting = true;
    AshitaCore:GetPacketManager():AddOutgoingPacket(id, data);
    engine.injecting = false;
end

local recent = {};                                                    -- what we sent lately (to spot another addon re-sending it)
local function remember(packet)
    local s = table.concat(packet, ',');
    recent[#recent + 1] = { s = s, t = os.clock() };
    if #recent > 8 then table.remove(recent, 1); end
end
-- An injected action we sent a moment ago: let it through. Seen twice: someone else re-sends ours too.
local function seen_lately(packet)
    local s = table.concat(packet, ',');
    for _, r in ipairs(recent) do
        if r.s == s and os.clock() - r.t < 2.0 then
            r.hits = (r.hits or 0) + 1;
            if r.hits >= 2 then engine.other_caster = true; end
            return true;
        end
    end
    return false;
end

local function spell_done_time(res)
    local base = (res and res.CastTime or 0) * 0.25;
    base = base * (100 - config.num('fast_cast')) / 100;
    return os.clock() + base + config.num('spell_offset');
end

local function handle_action(packet, resend)
    local category = struct.unpack('H', packet, 0x0A + 1);
    local id = struct.unpack('H', packet, 0x0C + 1);
    local target = struct.unpack('H', packet, 0x08 + 1);
    local a = { block = false, resend = resend, packet = packet:totable(), target = target };
    if category == 0x03 then
        a.type = 'Spell';
        local r = res_mgr:GetSpellById(id);
        a.name = r and clean(r.Name[1]) or nil;
        a.skill = r and game.SKILLS[r.Skill] or nil;
        a.element = r and game.SPELL_ELEMENT[(r.Element or 15) + 1] or nil;
        a.completion = spell_done_time(r);
        engine.action = a;
        run('precast', 'set');
    elseif category == 0x07 then
        a.type = 'Weaponskill';
        local r = res_mgr:GetAbilityById(id);
        a.name = r and clean(r.Name[1]) or nil;
        a.completion = os.clock() + config.num('ws_delay');
        engine.action = a;
        run('ws', 'auto');
    elseif category == 0x09 then
        a.type = 'Ability';
        local r = res_mgr:GetAbilityById(id + 0x200);
        a.name = r and clean(r.Name[1]) or nil;
        a.ability_type = r and ABILITY_TYPES[r.RecastTimerId] or nil;
        a.completion = os.clock() + config.num('ja_delay');
        engine.action = a;
        run('ja', 'auto');
    elseif category == 0x10 then
        a.type = 'Ranged';
        a.name = 'Ranged';
        a.completion = os.clock() + config.num('ranged_base') * (100 - config.num('snapshot')) / 100 + config.num('ranged_offset');
        engine.action = a;
        run('preshot', 'set');
    else
        return;
    end

    if engine.action == nil or engine.action.block then engine.action = nil; return; end
    remember(engine.action.packet);
    inject(0x1A, engine.action.packet);

    if engine.action.type == 'Spell' then
        run('midcast', 'single');
    elseif engine.action.type == 'Ranged' then
        run('midshot', 'single');
    end
end

local function handle_item(packet, resend)
    local idx = struct.unpack('B', packet, 0x0E + 1);
    local container = struct.unpack('B', packet, 0x10 + 1);
    local target = struct.unpack('H', packet, 0x0C + 1);
    local it = inv_mgr:GetContainerItem(container, idx);
    local a = { block = false, resend = resend, packet = packet:totable(), target = target, type = 'Item' };
    if it == nil or it.Id == 0 or it.Count == 0 then
        a.completion = os.clock() + config.num('item_base') + config.num('item_offset');
    else
        local r = res_mgr:GetItemById(it.Id);
        a.name = r and clean(r.Name[1]) or nil;
        a.completion = os.clock() + ((r and r.CastTime or 0) * 0.25) + config.num('item_offset');
    end
    engine.action = a;
    -- a Chocobo Whistle: your Chocobo riding sets go on as you call it, and stay while it comes
    if a.name and a.name:lower():find('chocobo whistle', 1, true) then rules.mounting_until = os.clock() + 15; end
    run('item', 'auto');
    if engine.action == nil or engine.action.block then engine.action = nil; return; end
    remember(engine.action.packet);
    inject(0x37, engine.action.packet);
end

-- Resends: the client sends an action again when it hears nothing back; only the first is acted on
local dup_buf = ffi.new('uint8_t[?]', 512);
local function is_duplicate(chunk, offset, size)
    local ptr = ffi.cast('uint8_t*', chunk) + offset;
    if ffi.C.memcmp(dup_buf, ptr, size) == 0 then return true; end
    ffi.copy(dup_buf, ptr, math.min(size, 512));
    return false;
end

local function on_chunk(e)
    local now = os.clock();
    if engine.action ~= nil and engine.action.completion < now then dbg('Action over (time).'); engine.action = nil; end
    if engine.pet_action ~= nil and engine.pet_action.completion < now then engine.pet_action = nil; end

    local nx, ny = engine.pos_x, engine.pos_y;
    local offset = 0;
    while offset < e.chunk_size do
        local id   = ashita.bits.unpack_be(e.chunk_data_raw, offset, 0, 9);
        local size = ashita.bits.unpack_be(e.chunk_data_raw, offset, 9, 7) * 4;
        if size == 0 then break; end
        if id == 0x1A then
            local again = is_duplicate(e.chunk_data_raw, offset, size);
            if not again or AshitaCore:GetPluginManager():Get('Sequencer') ~= nil then
                handle_action(struct.unpack('c' .. size, e.chunk_data, offset + 1), again);
            end
        elseif id == 0x15 then
            nx = struct.unpack('f', e.chunk_data, offset + 0x04 + 1);
            ny = struct.unpack('f', e.chunk_data, offset + 0x0C + 1);
        elseif id == 0x37 then
            local again = is_duplicate(e.chunk_data_raw, offset, size);
            if not again or AshitaCore:GetPluginManager():Get('Sequencer') ~= nil then
                handle_item(struct.unpack('c' .. size, e.chunk_data, offset + 1), again);
            end
        end
        offset = offset + size;
    end

    engine.moving = (engine.pos_x ~= nil) and (nx ~= engine.pos_x or ny ~= engine.pos_y);
    engine.pos_x, engine.pos_y = nx, ny;

    if engine.action == nil then run('default', 'auto'); end
end

local HANDLED = { [0x03] = true, [0x07] = true, [0x09] = true, [0x10] = true };

function engine.on_packet_out(e)
    -- the lockstyle: kept through a zone change (the game's own reset is turned into "keep it")
    if e.id == 0x53 and e.injected == false then
        local t = struct.unpack('B', e.data, 0x05 + 1);
        if t == 0 then
            if os.clock() < engine.zone_timer and engine.lockstyle_on then
                ashita.bits.pack_be(e.data_modified_raw, 1, 5, 0, 8);
            else
                engine.lockstyle_on = false;
            end
        elseif t == 3 then
            engine.lockstyle_on = false;
        end
        return;
    end

    if not engine.active() then return; end

    -- actions another addon sends: handled the same way
    if e.injected == true then
        if engine.injecting then return; end
        if e.id == 0x1A then
            local category = struct.unpack('H', e.data, 0x0A + 1);
            if HANDLED[category] then
                local p = struct.unpack('c' .. e.size, e.data, 1);
                if seen_lately(p:totable()) then return; end
                handle_action(p, false);
                e.blocked = true;
            end
        elseif e.id == 0x37 then
            local p = struct.unpack('c' .. e.size, e.data, 1);
            if seen_lately(p:totable()) then return; end
            handle_item(p, false);
            e.blocked = true;
        end
        return;
    end

    -- the first packet of a new chunk: actions, then the idle / engaged set
    if ffi.C.memcmp(e.data_raw, e.chunk_data_raw, e.size) == 0 then
        engine.chunk_ok = false;
        local ok, er = pcall(on_chunk, e);
        engine.chunk_ok = ok;
        if not ok then
            engine.action = nil;
            print(chat.header('NeoSwap') .. chat.error('Swap error (the action is sent as it was): ' .. tostring(er)));
        end
    end

    -- the game's own action packets are held back; on_chunk sent them again after the swap.
    -- (if that went wrong, they go out untouched)
    if not engine.chunk_ok then return; end
    if e.id == 0x1A then
        local category = struct.unpack('H', e.data, 0x0A + 1);
        if HANDLED[category] then e.blocked = true; return; end
    end
    if e.id == 0x37 then e.blocked = true; return; end
end

-- Incoming: actions finishing, your pet's actions, slots the game locks, zoning
function engine.on_packet_in(e)
    if e.id == 0x00A then
        engine.zone_timer = os.clock() + 10;
        rules.mounting_until = nil;
        engine.action, engine.pet_action = nil, nil;
        return;
    end
    if e.id == 0x01B then
        pcall(function()
            for i = 1, 16 do engine.encumbrance[i] = (ashita.bits.unpack_be(e.data_raw, 0x60, i - 1, 1) == 1); end
        end);
        return;
    end
    if e.id ~= 0x028 then return; end
    local user = struct.unpack('L', e.data, 0x05 + 1);
    local atype = ashita.bits.unpack_be(e.data_raw, 10, 2, 4);
    local me = 0;
    pcall(function() me = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0); end);
    if user == me then
        if ACTION_DONE[atype] then
            engine.action = nil;
        elseif (atype == 8 or atype == 12) and ashita.bits.unpack_be(e.data_raw, 10, 6, 16) == 28787 then
            engine.action = nil;                                      -- (interrupted)
        end
        return;
    end

    local pet = game.pet();
    if pet == nil or user ~= pet.id then return; end
    if PET_DONE[atype] then engine.pet_action = nil; return; end
    if (atype == 8 or atype == 12) and ashita.bits.unpack_be(e.data_raw, 10, 6, 16) == 28787 then engine.pet_action = nil; return; end
    if atype == 7 or atype == 8 then
        local aid = ashita.bits.unpack_be(e.data_raw, 0, 213, 17);
        if aid == 0 then return; end
        local pa = { id = aid };
        if atype == 7 then
            pa.completion = os.clock() + config.num('pet_delay');
            local msg = ashita.bits.unpack_be(e.data_raw, 28, 6, 10);
            if msg == 43 then
                pa.name = clean(res_mgr:GetString('monsters.abilities', aid - 256));
            else
                local r = res_mgr:GetAbilityById(aid + 512);
                pa.name = r and clean(r.Name[1]) or nil;
                pa.type = r and ABILITY_TYPES[r.RecastTimerId] or nil;
            end
        else
            local r = res_mgr:GetSpellById(aid);
            pa.name = r and clean(r.Name[1]) or nil;
            pa.completion = os.clock() + ((r and r.CastTime or 0) * 0.25) + config.num('spell_offset');
        end
        engine.pet_action = pa;
    end
end

----------------------------------------------------------------------------------------------------
-- Lockstyle (LuAshitacast's LockStyle): set = { [slot 0-8] = { id } }
----------------------------------------------------------------------------------------------------
function engine.lockstyle(set)
    local packet = {};
    for i = 1, 136 do packet[i] = 0x00; end
    packet[0x05 + 1] = 3;
    packet[0x06 + 1] = 1;
    local count = 0;
    for s = 0, 8 do
        local g = set and set[s];
        if g and g.id then
            local done = false;
            for container = 0, 16 do
                if container ~= 3 and bag_ok(container) then
                    local max = math.min(80, inv_mgr:GetContainerCountMax(container));
                    for i = 1, max do
                        local it = inv_mgr:GetContainerItem(container, i);
                        if it ~= nil and it.Id == g.id and it.Count > 0 then
                            local off = 8 + count * 8 + 1;
                            packet[off] = i;
                            packet[off + 1] = s;
                            packet[off + 2] = container;
                            packet[off + 4] = bit.band(it.Id, 0xFF);
                            packet[off + 5] = bit.rshift(it.Id, 8);
                            count = count + 1;
                            packet[4 + 1] = count;
                            done = true;
                            break;
                        end
                    end
                end
                if done then break; end
            end
        end
    end
    if count > 0 then
        engine.lockstyle_on = true;
        AshitaCore:GetPacketManager():AddOutgoingPacket(0x53, packet);
    end
    return count;
end

-- The lockstyle a job uses: its own, the global one, or none
function engine.style_for(abbr)
    local j = store.job(abbr);
    local mode = j and j.lockstyle and j.lockstyle.mode or 'global';
    if mode == 'off' then return nil, 'off'; end
    if mode == 'job' then return j.lockstyle.set or {}, 'job'; end
    local g = store.data and store.data.lockstyle or {};
    local any = false;
    for s = 0, 8 do if g[s] and g[s].id then any = true; end end
    return any and g or nil, 'global';
end

function engine.apply_lockstyle(quiet)
    local abbr = engine.job_abbr();
    if abbr == nil then return 0; end
    local set, mode = engine.style_for(abbr);
    if set == nil then
        if not quiet and mode == 'off' then say('Lockstyle is off for ' .. abbr .. '.'); end
        return 0;
    end
    local n = engine.lockstyle(set);
    if not quiet then say(n > 0 and ('Lockstyle set (' .. n .. ' pieces).') or 'Lockstyle: none of its pieces were found in your bags.'); end
    return n;
end

function engine.apply_macros()
    local abbr = engine.job_abbr();
    local j = abbr and store.job(abbr);
    if j == nil or j.macro == nil or not j.macro.on then return false; end
    local book, page = tonumber(j.macro.book) or 1, tonumber(j.macro.page) or 1;
    AshitaCore:GetChatManager():QueueCommand(1, '/macro book ' .. book);
    engine.later(0.6, function() AshitaCore:GetChatManager():QueueCommand(1, '/macro set ' .. page); end);
    return true;
end

----------------------------------------------------------------------------------------------------
-- A small timer list (job change: macros and lockstyle a moment after)
----------------------------------------------------------------------------------------------------
local timers = {};
function engine.later(secs, fn) timers[#timers + 1] = { at = os.clock() + secs, fn = fn }; end

local last_job = nil;
function engine.tick()
    local now = os.clock();
    for i = #timers, 1, -1 do
        if now >= timers[i].at then
            local t = table.remove(timers, i);
            pcall(t.fn);
        end
    end
    -- your job changed (or you just logged in): the job's macros, then its lockstyle
    local j = jobs.main();
    if j ~= 0 and j ~= last_job then
        local first = last_job == nil;
        last_job = j;
        engine.action, engine.pet_action = nil, nil;
        engine.later(first and 1.0 or 2.0, function() engine.apply_macros(); end);
        engine.later(first and 2.5 or 3.5, function() engine.apply_lockstyle(true); end);
        if engine.on_job_change then pcall(engine.on_job_change, j); end
    end
end

return engine;
