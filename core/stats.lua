-- stats.lua : the bonuses on a piece of gear, read from its description ("DEF:20 HP+15 STR+3 \"Refresh\"+1"),
-- and the totals for a whole set. Bonuses that only count sometimes (Latent effect, Set:, Night:, Avatar: ...)
-- are kept apart: pet bonuses get their own lines (Pet: Accuracy), the rest is listed as conditional.
local items = require('core.items');

local stats = {};

-- Short names the game uses, to one name each
local ALIAS = {
    ['acc'] = 'Accuracy', ['accuracy'] = 'Accuracy',
    ['atk'] = 'Attack', ['attack'] = 'Attack',
    ['rng acc'] = 'Ranged Accuracy', ['rng. acc'] = 'Ranged Accuracy', ['ranged accuracy'] = 'Ranged Accuracy', ['r.acc'] = 'Ranged Accuracy',
    ['rng atk'] = 'Ranged Attack', ['rng. atk'] = 'Ranged Attack', ['ranged attack'] = 'Ranged Attack', ['r.atk'] = 'Ranged Attack',
    ['mag acc'] = 'Magic Accuracy', ['mag. acc'] = 'Magic Accuracy', ['magic accuracy'] = 'Magic Accuracy', ['m.acc'] = 'Magic Accuracy',
    ['mag atk bns'] = 'Magic Attack Bonus', ['mag. atk. bns'] = 'Magic Attack Bonus', ['magic attack bonus'] = 'Magic Attack Bonus',
    ['m.atk.bns'] = 'Magic Attack Bonus', ['mab'] = 'Magic Attack Bonus',
    ['mag def bns'] = 'Magic Defense Bonus', ['mag. def. bns'] = 'Magic Defense Bonus', ['magic def. bonus'] = 'Magic Defense Bonus',
    ['magic defense bonus'] = 'Magic Defense Bonus', ['m.def.bns'] = 'Magic Defense Bonus',
    ['mag eva'] = 'Magic Evasion', ['mag. evasion'] = 'Magic Evasion', ['magic evasion'] = 'Magic Evasion',
    ['eva'] = 'Evasion', ['evasion'] = 'Evasion',
    ['def'] = 'DEF', ['defense'] = 'DEF',
    ['hp'] = 'HP', ['mp'] = 'MP', ['str'] = 'STR', ['dex'] = 'DEX', ['vit'] = 'VIT', ['agi'] = 'AGI', ['int'] = 'INT',
    ['mnd'] = 'MND', ['chr'] = 'CHR',
    ['haste'] = 'Haste', ['enmity'] = 'Enmity', ['refresh'] = 'Refresh', ['regen'] = 'Regen', ['regain'] = 'Regain',
    ['store tp'] = 'Store TP', ['double attack'] = 'Double Attack', ['triple attack'] = 'Triple Attack',
    ['dual wield'] = 'Dual Wield', ['fast cast'] = 'Fast Cast', ['conserve mp'] = 'Conserve MP',
    ['cure potency'] = 'Cure potency', ['critical hit rate'] = 'Critical hit rate', ['crit. hit rate'] = 'Critical hit rate',
    ['subtle blow'] = 'Subtle Blow', ['snapshot'] = 'Snapshot', ['rapid shot'] = 'Rapid Shot',
    ['spell interruption rate down'] = 'Spell interruption down', ['spell interruption rate'] = 'Spell interruption down',
    ['physical damage taken'] = 'Physical damage taken', ['magic damage taken'] = 'Magic damage taken',
    ['damage taken'] = 'Damage taken', ['breath damage taken'] = 'Breath damage taken',
    ['movement speed'] = 'Movement speed', ['blood pact delay'] = 'Blood Pact delay', ['blood pact ability delay'] = 'Blood Pact delay',
    ['avatar perpetuation cost'] = 'Avatar perpetuation cost',
    ['hp recovered while healing'] = 'HP while healing', ['mp recovered while healing'] = 'MP while healing',
};

-- The order the summary shows them in (anything else follows, by name)
local ORDER = { 'HP', 'MP', 'STR', 'DEX', 'VIT', 'AGI', 'INT', 'MND', 'CHR', 'DEF', 'Accuracy', 'Attack',
                'Ranged Accuracy', 'Ranged Attack', 'Evasion', 'Magic Accuracy', 'Magic Attack Bonus', 'Magic Defense Bonus',
                'Magic Evasion', 'Haste', 'Store TP', 'Double Attack', 'Triple Attack', 'Critical hit rate', 'Dual Wield',
                'Subtle Blow', 'Fast Cast', 'Cure potency', 'Conserve MP', 'Refresh', 'Regen', 'Regain', 'Enmity',
                'Damage taken', 'Physical damage taken', 'Magic damage taken', 'Breath damage taken', 'Movement speed',
                'Snapshot', 'Rapid Shot', 'Spell interruption down', 'HP while healing', 'MP while healing',
                'Blood Pact delay', 'Avatar perpetuation cost' };
local RANK = {};
for i, k in ipairs(ORDER) do RANK[k] = i; end

function stats.rank(name) return RANK[name] or 999; end

-- One copy's bonuses: the piece's own plus its augments ({ [key] = value }, keys as in of_item: 'Haste %', 'Pet: Accuracy')
local copy_cache = {};
function stats.of_copy(id, augs)
    local k = tostring(id) .. '#' .. table.concat(augs or {}, '|');
    local c = copy_cache[k];
    if c then return c; end
    c = {};
    for key, v in pairs(stats.of_item(id).bonuses) do c[key] = (c[key] or 0) + v; end
    for key, v in pairs(stats.of_augs(augs)) do c[key] = (c[key] or 0) + v; end
    copy_cache[k] = c;
    return c;
end

-- A bonus key as words: 'Haste %' -> 'Haste %', 'Pet: Accuracy' -> 'Pet: Accuracy'
function stats.key_label(key) return key; end

-- Short labels for the compact summary under each set
stats.SHORT = { ['Accuracy'] = 'Acc', ['Attack'] = 'Atk', ['Ranged Accuracy'] = 'R.Acc', ['Ranged Attack'] = 'R.Atk',
                ['Evasion'] = 'Eva', ['Magic Accuracy'] = 'M.Acc', ['Magic Attack Bonus'] = 'MAB', ['Magic Defense Bonus'] = 'MDB',
                ['Magic Evasion'] = 'M.Eva', ['Critical hit rate'] = 'Crit', ['Double Attack'] = 'DA', ['Triple Attack'] = 'TA',
                ['Store TP'] = 'STP', ['Damage taken'] = 'DT', ['Physical damage taken'] = 'PDT', ['Magic damage taken'] = 'MDT',
                ['Breath damage taken'] = 'BDT', ['Spell interruption down'] = 'SIRD', ['Cure potency'] = 'Cure',
                ['Movement speed'] = 'Move', ['HP while healing'] = 'HP heal', ['MP while healing'] = 'MP heal',
                ['Blood Pact delay'] = 'BP delay', ['Avatar perpetuation cost'] = 'Perp.', ['Conserve MP'] = 'Conserve',
                ['Spell interruption'] = 'SIRD' };

-- Words that start a part of the text that only counts sometimes
local PET_WORDS = { 'pet:', 'avatar:', 'wyvern:', 'automaton:', 'luopan:' };
local COND_WORDS = { 'latent effect', 'set:', 'night:', 'daytime:', 'dusk to dawn', 'weather:', 'day:', 'unity ranking',
                     'dynamis', 'in assault', 'in salvage', 'besieged', 'campaign', 'aftermath', 'additional effect',
                     'enchantment:', 'occasionally', 'when ', 'while ', 'vs. ', 'against ', 'converts ', 'reives:',
                     'in areas outside', 'in nyzul', 'in limbus', 'in einherjar', 'level sync', 'under ' };

local function norm_name(n)
    n = n:gsub('"', ''):gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ');
    n = n:gsub('^[,;/%.]+%s*', ''):gsub('%s*[:]$', '');
    local key = n:lower():gsub('%.$', '');
    if ALIAS[key] then return ALIAS[key]; end
    key = key:gsub('%.', ''):gsub('%s+', ' ');
    if ALIAS[key] then return ALIAS[key]; end
    -- a phrase: keep the game's words, first letter capital
    if #n > 34 then return nil; end                                   -- (a sentence, not a stat)
    return (n:gsub('^%l', string.upper));
end

local function lower_has(s, words)
    for _, w in ipairs(words) do
        local i = s:find(w, 1, true);
        if i then return i, w; end
    end
    return nil;
end

-- Read one line of a description into bonuses. bucket: '' (counts always), 'Pet: ', or nil (conditional)
local function read_line(line, out, cond_out, item_name)
    local low = line:lower();
    -- where a conditional or pet part starts on this line
    local function word_start(i)                                      -- ("Firesday:" starts at F, not at day:)
        if i == nil then return nil; end
        while i > 1 and line:sub(i - 1, i - 1):match('%a') do i = i - 1; end
        return i;
    end
    local pi = word_start(lower_has(low, PET_WORDS));
    local ci = word_start(lower_has(low, COND_WORDS));
    local function add(name, val, pct, prefix)
        local key = (prefix or '') .. name .. (pct and ' %' or '');
        out[key] = (out[key] or 0) + val;
    end
    local function scan(seg, prefix)
        -- DEF:20 / DMG:30 / Delay:240 (colon values)
        for k, v in seg:gmatch('(%a+):%s*(%d+)') do
            local kl = k:lower();
            if kl == 'def' then add('DEF', tonumber(v), false, prefix); end
        end
        -- Name+N / Name-N / Name+N%
        local s = seg:gsub('(%a+):%s*%d+', ' ');
        for name, sign, num, pct in s:gmatch('([^%+%-%d]-)%s*([%+%-])(%d+)(%%?)') do
            local n = name:gsub('.*:', '');                           -- (after any label)
            n = norm_name(n);
            if n and #n > 0 and not n:match('^%d') and not n:lower():match('^lv') then
                local val = tonumber(num) * (sign == '-' and -1 or 1);
                add(n, val, pct == '%', prefix);
            end
        end
    end
    local cut = math.min(pi or 99999, ci or 99999);
    if cut > 1 then scan(line:sub(1, (cut == 99999) and #line or (cut - 1)), ''); end
    if pi and (ci == nil or pi < ci) then
        local seg = line:sub(pi):gsub('^[^:]*:', '');
        local stop = lower_has(seg:lower(), COND_WORDS);
        if stop then
            cond_out[#cond_out + 1] = { item = item_name, text = (seg:sub(stop):gsub('^%s+', '')) };
            seg = seg:sub(1, stop - 1);
        end
        scan(seg, 'Pet: ');
    elseif ci then
        local t = line:sub(ci):gsub('^%s+', ''):gsub('%s+$', '');
        if #t > 0 then cond_out[#cond_out + 1] = { item = item_name, text = t }; end
    end
end

-- One piece: { bonuses = { [name] = n }, conditional = { { item, text } } } (cached)
local cache = {};
function stats.of_item(id)
    local c = cache[id];
    if c then return c; end
    c = { bonuses = {}, conditional = {} };
    local desc = items.description(id) or '';
    local name = items.name(id);
    local latent = false;
    for line in (desc .. '\n'):gmatch('([^\n]*)\n') do
        local low = line:lower();
        -- "Latent effect:" or "Set:" on a line of its own: the lines after it are conditional too
        if low:match('^%s*latent effect') or low:match('^%s*set:') or low:match('^%s*unity ranking') or low:match('^%s*dynamis') then
            latent = true;
        end
        if latent then
            local t = line:gsub('^%s+', ''):gsub('%s+$', '');
            if #t > 0 then c.conditional[#c.conditional + 1] = { item = name, text = t }; end
        else
            read_line(line, c.bonuses, c.conditional, name);
        end
    end
    cache[id] = c;
    return c;
end

-- A list of augments ({ 'STR+3', 'Accuracy+5' }): their bonuses (cached)
local aug_cache = {};
function stats.of_augs(list)
    if list == nil or #list == 0 then return {}; end
    local key = table.concat(list, '|');
    local c = aug_cache[key];
    if c then return c; end
    c = {};
    local cond = {};
    for _, a in ipairs(list) do read_line(tostring(a), c, cond, ''); end
    aug_cache[key] = c;
    return c;
end

-- A set's totals: sorted { { name, value, pct, pet } }, and the conditional lines
function stats.of_set(gear)
    local sum, cond = {}, {};
    local covered = items.blocked_in(gear) or {};                    -- (a cloak's Head piece doesn't count)
    for s = 0, 15 do
        local g = gear and gear[s];
        if g and g.id and not g.remove and not covered[s] then
            local st = stats.of_item(g.id);
            for k, v in pairs(st.bonuses) do sum[k] = (sum[k] or 0) + v; end
            for _, l in ipairs(st.conditional) do cond[#cond + 1] = l; end
            for k, v in pairs(stats.of_augs(g.augs)) do sum[k] = (sum[k] or 0) + v; end
        end
    end
    local list = {};
    for k, v in pairs(sum) do
        if v ~= 0 then
            local pct = k:sub(-2) == ' %';
            local base = pct and k:sub(1, -3) or k;
            local pet = base:sub(1, 5) == 'Pet: ';
            local core = pet and base:sub(6) or base;
            list[#list + 1] = { name = core, value = v, pct = pct, pet = pet, rank = RANK[core] or 999 };
        end
    end
    table.sort(list, function(a, b)
        if a.pet ~= b.pet then return not a.pet; end
        if a.rank ~= b.rank then return a.rank < b.rank; end
        if a.name ~= b.name then return a.name < b.name; end
        return (a.pct and 1 or 0) < (b.pct and 1 or 0);
    end);
    return list, cond;
end

function stats.label(e, short)
    local n = e.name;
    if short then n = stats.SHORT[n] or n; end
    if e.pet then n = (short and 'Pet ' or 'Pet: ') .. n; end
    local v = (e.value > 0 and '+' or '') .. tostring(e.value) .. (e.pct and '%' or '');
    if n == 'DEF' then return 'DEF ' .. tostring(e.value); end
    return n .. v;
end

function stats.clear() cache = {}; end

return stats;
