-- store.lua : your sets, kept per character in config\addons\neoswap\<Name>_<id>\sets.lua
--
-- data = {
--   version   = 1,
--   next_id   = n,
--   modes     = { [name] = true/false },           -- your own switches (PDT, TH, ...) that sets can wait on
--   lockstyle = { [slot 0-8] = { id, name } },     -- the global lockstyle
--   jobs = { WAR = {
--       macro     = { on, book, page },
--       lockstyle = { mode = 'off' | 'global' | 'job', set = { [slot] = { id, name } } },
--       sets      = { { id, name, prio, gear = { [slot 0-15] = { id, name } | { remove = true } },
--                       when = { kind, names = {..}, skills = {..}, cond = { { t, v, n, neg }, .. } } }, ... },
--   } },
-- }
local chat = require('chat');

local store = { data = nil, owner = nil, path = nil, dirty_at = nil };

local function new_data() return { version = 1, next_id = 1, modes = {}, lockstyle = {}, jobs = {} }; end

----------------------------------------------------------------------------------------------------
-- Writing a Lua table to a file (keys sorted, so the file reads well and diffs cleanly)
----------------------------------------------------------------------------------------------------
local function ser(v, ind, out)
    local tv = type(v);
    if tv == 'string' then out[#out + 1] = string.format('%q', v);
    elseif tv == 'number' then out[#out + 1] = (v == math.floor(v)) and string.format('%d', v) or tostring(v);
    elseif tv == 'boolean' then out[#out + 1] = tostring(v);
    elseif tv == 'table' then
        local keys = {};
        for k in pairs(v) do if type(k) == 'string' or type(k) == 'number' then keys[#keys + 1] = k; end end
        if #keys == 0 then out[#out + 1] = '{}'; return; end
        table.sort(keys, function(a, b)
            if type(a) == type(b) then return a < b; end
            return type(a) == 'number';
        end);
        local n = #v;
        local seq = n == #keys and v[0] == nil;                       -- (a plain list)
        out[#out + 1] = '{\n';
        local pad = string.rep('    ', ind + 1);
        for _, k in ipairs(keys) do
            out[#out + 1] = pad;
            if not seq then
                if type(k) == 'string' and k:match('^[%a_][%w_]*$') then out[#out + 1] = k .. ' = ';
                elseif type(k) == 'string' then out[#out + 1] = '[' .. string.format('%q', k) .. '] = ';
                else out[#out + 1] = '[' .. tostring(k) .. '] = '; end
            end
            ser(v[k], ind + 1, out);
            out[#out + 1] = ',\n';
        end
        out[#out + 1] = string.rep('    ', ind) .. '}';
    else
        out[#out + 1] = 'nil';
    end
end

local function dir_of(path) return path:match('^(.*)[\\/][^\\/]*$'); end

local function make_dirs(path)
    local acc = '';
    for part in path:gmatch('[^\\/]+') do
        acc = (acc == '') and part or (acc .. '\\' .. part);
        if not acc:match(':$') then pcall(function() ashita.fs.create_directory(acc .. '\\'); end); end
    end
end

----------------------------------------------------------------------------------------------------
-- Loading and saving
----------------------------------------------------------------------------------------------------
function store.base_dir()
    return string.format('%sconfig\\addons\\neoswap\\', AshitaCore:GetInstallPath());
end

-- Load the sets of a character (name, server id). Returns true if the file was read.
function store.load(name, id)
    store.owner = { name = name, id = id };
    store.path = string.format('%s%s_%u\\sets.lua', store.base_dir(), name, id);
    store.data = new_data();
    if not ashita.fs.exists(store.path) then return false; end
    local f, err = loadfile(store.path);
    if not f then
        print(chat.header('NeoSwap') .. chat.error('Could not read your sets: ' .. tostring(err)));
        -- keep the broken file aside so it isn't overwritten
        pcall(function() os.rename(store.path, store.path .. '.broken'); end);
        return false;
    end
    local ok, d = pcall(f);
    if ok and type(d) == 'table' then
        store.data = d;
        store.data.jobs = store.data.jobs or {};
        store.data.modes = store.data.modes or {};
        store.data.lockstyle = store.data.lockstyle or {};
        store.data.next_id = tonumber(store.data.next_id) or 1;
        for _, j in pairs(store.data.jobs) do
            j.sets = j.sets or {};
            for _, s in ipairs(j.sets) do
                if s.id == nil or s.id >= store.data.next_id then
                    s.id = s.id or store.data.next_id;
                    store.data.next_id = math.max(store.data.next_id, s.id + 1);
                end
            end
        end
        return true;
    end
    return false;
end

function store.save_now()
    if store.data == nil or store.path == nil then return false; end
    make_dirs(dir_of(store.path));
    local out = { '-- NeoSwap sets for ', store.owner and store.owner.name or '?', '. Written by NeoSwap; edit in game with /nswap.\n', 'return ' };
    ser(store.data, 0, out);
    out[#out + 1] = ';\n';
    local tmp = store.path .. '.tmp';
    local f = io.open(tmp, 'w');
    if f == nil then
        print(chat.header('NeoSwap') .. chat.error('Could not save your sets to ' .. store.path));
        return false;
    end
    f:write(table.concat(out));
    f:close();
    pcall(function() os.remove(store.path .. '.bak'); end);
    pcall(function() os.rename(store.path, store.path .. '.bak'); end);
    local ok = os.rename(tmp, store.path);
    if not ok then                                                    -- (rename refused: write it directly)
        local f2 = io.open(store.path, 'w');
        if f2 then f2:write(table.concat(out)); f2:close(); end
        pcall(function() os.remove(tmp); end);
    end
    store.dirty_at = nil;
    return true;
end

-- Something changed: saved a moment later (so typing a name doesn't write the file at every key)
function store.touch()
    store.dirty_at = os.clock();
    store.gen = (store.gen or 0) + 1;
end

function store.tick()
    if store.dirty_at ~= nil and os.clock() - store.dirty_at > 1.0 then store.save_now(); end
end

function store.ready() return store.data ~= nil; end

----------------------------------------------------------------------------------------------------
-- Jobs and sets
----------------------------------------------------------------------------------------------------
function store.job(abbr, create)
    if store.data == nil or abbr == nil then return nil; end
    local j = store.data.jobs[abbr];
    if j == nil and create then
        j = { macro = { on = false, book = 1, page = 1 }, lockstyle = { mode = 'global', set = {} }, sets = {} };
        store.data.jobs[abbr] = j;
    end
    return j;
end

function store.sets(abbr)
    local j = store.job(abbr);
    return j and j.sets or {};
end

function store.find(abbr, id)
    for i, s in ipairs(store.sets(abbr)) do if s.id == id then return s, i; end end
    return nil;
end

function store.find_by_name(abbr, name)
    name = tostring(name or ''):lower();
    for i, s in ipairs(store.sets(abbr)) do if tostring(s.name or ''):lower() == name then return s, i; end end
    return nil;
end

function store.new_set(abbr, kind, name)
    local j = store.job(abbr, true);
    local s = { id = store.data.next_id, name = name or 'New set', prio = 0, gear = {},
                when = { kind = kind or 'idle', names = {}, skills = {}, cond = {} } };
    store.data.next_id = store.data.next_id + 1;
    j.sets[#j.sets + 1] = s;
    store.touch();
    return s;
end

local function deep_copy(v)
    if type(v) ~= 'table' then return v; end
    local t = {};
    for k, x in pairs(v) do t[k] = deep_copy(x); end
    return t;
end
store.copy = deep_copy;

function store.duplicate(abbr, id)
    local s, i = store.find(abbr, id);
    if s == nil then return nil; end
    local c = deep_copy(s);
    c.id = store.data.next_id;
    store.data.next_id = store.data.next_id + 1;
    c.name = (s.name or 'Set') .. ' (copy)';
    table.insert(store.job(abbr).sets, i + 1, c);
    store.touch();
    return c;
end

function store.remove(abbr, id)
    local _, i = store.find(abbr, id);
    if i then table.remove(store.job(abbr).sets, i); store.touch(); end
end

-- Move a set up (-1) or down (+1) among the sets of the same kind
function store.move(abbr, id, d)
    local list = store.sets(abbr);
    local s, i = store.find(abbr, id);
    if s == nil then return; end
    local k = i + d;
    while k >= 1 and k <= #list and list[k].when.kind ~= s.when.kind do k = k + d; end
    if k < 1 or k > #list then return; end
    list[i], list[k] = list[k], list[i];
    store.touch();
end

function store.copy_set_to_job(abbr, id, to_abbr)
    local s = store.find(abbr, id);
    if s == nil then return nil; end
    local c = deep_copy(s);
    c.id = store.data.next_id;
    store.data.next_id = store.data.next_id + 1;
    local j = store.job(to_abbr, true);
    j.sets[#j.sets + 1] = c;
    store.touch();
    return c;
end

function store.count(abbr) return #store.sets(abbr); end

----------------------------------------------------------------------------------------------------
-- Custom entries in the jobs list (HELM, Fishing, Crafting...): sets that aren't a job's. Their sets are kept like a
-- job's, under store.data.jobs[key] (key 'E<n>'). While an entry is active, its sets go on over your job's.
--   store.data.entries = { { key, name, icon = { item = id } | { job = 'WAR' }, active } }
----------------------------------------------------------------------------------------------------
function store.entries()
    if store.data == nil then return {}; end
    store.data.entries = store.data.entries or {};
    return store.data.entries;
end

function store.is_entry(key) return type(key) == 'string' and key:match('^E%d+$') ~= nil; end

function store.entry(key)
    for i, e in ipairs(store.entries()) do if e.key == key then return e, i; end end
    return nil;
end

function store.entry_by_name(name)
    name = tostring(name or ''):lower();
    for _, e in ipairs(store.entries()) do if tostring(e.name or ''):lower() == name then return e; end end
    return nil;
end

function store.new_entry(name, icon)
    local e = { key = 'E' .. store.data.next_id, name = name or 'New entry', icon = icon, active = false };
    store.data.next_id = store.data.next_id + 1;
    local list = store.entries();
    list[#list + 1] = e;
    store.job(e.key, true);
    store.touch();
    return e;
end

function store.remove_entry(key)
    local _, i = store.entry(key);
    if i then table.remove(store.entries(), i); store.data.jobs[key] = nil; store.touch(); end
end

-- The sets of every active entry (in list order)
function store.active_entry_keys()
    local t = {};
    for _, e in ipairs(store.entries()) do if e.active then t[#t + 1] = e.key; end end
    return t;
end

----------------------------------------------------------------------------------------------------
-- Modes
----------------------------------------------------------------------------------------------------
function store.mode(name) return store.data ~= nil and store.data.modes[tostring(name or ''):lower()] == true; end
function store.set_mode(name, on)
    if store.data == nil then return; end
    store.data.modes[tostring(name or ''):lower()] = on and true or false;
    store.touch();
end

return store;
