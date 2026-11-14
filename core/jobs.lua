-- jobs.lua : job names and your levels
local jobs = {};

jobs.ABBR = { 'WAR','MNK','WHM','BLM','RDM','THF','PLD','DRK','BST','BRD','RNG','SAM','NIN','DRG','SMN','BLU','COR','PUP','DNC','SCH','GEO','RUN' };
jobs.NAME = { 'Warrior','Monk','White Mage','Black Mage','Red Mage','Thief','Paladin','Dark Knight','Beastmaster','Bard',
              'Ranger','Samurai','Ninja','Dragoon','Summoner','Blue Mage','Corsair','Puppetmaster','Dancer','Scholar',
              'Geomancer','Rune Fencer' };
jobs.COUNT = #jobs.ABBR;

local function player() return AshitaCore:GetMemoryManager():GetPlayer(); end

function jobs.main()
    local ok, v = pcall(function() return player():GetMainJob(); end);
    return ok and tonumber(v) or 0;
end
function jobs.sub()
    local ok, v = pcall(function() return player():GetSubJob(); end);
    return ok and tonumber(v) or 0;
end
-- Manual level sync: { [abbr] = level } (store.data.sync, set by store.load). A synced job's sets are worn as at that
-- level (its tiers, level conditions, the picker's level filter...), whatever its real level is.
jobs.sync = {};
function jobs.synced(id)
    local a = jobs.ABBR[tonumber(id) or 0];
    local v = a and tonumber(jobs.sync[a]);
    return (v and v >= 1) and math.floor(v) or nil;
end
function jobs.real_level(id)
    local ok, v = pcall(function() return player():GetJobLevel(id); end);
    return ok and (tonumber(v) or 0) or 0;
end
function jobs.real_main_level()
    local ok, v = pcall(function() return player():GetMainJobLevel(); end);
    return ok and (tonumber(v) or 0) or 0;
end
function jobs.level(id)
    local real = jobs.real_level(id);
    local sv = jobs.synced(id);
    if sv and real > 0 then return math.min(sv, real); end
    return real;
end
function jobs.main_level()
    local real = jobs.real_main_level();
    local sv = jobs.synced(jobs.main());
    if sv and real > 0 then return math.min(sv, real); end
    return real;
end
function jobs.sub_level()
    local ok, v = pcall(function() return player():GetSubJobLevel(); end);
    return ok and (tonumber(v) or 0) or 0;
end

function jobs.id(abbr)
    abbr = tostring(abbr or ''):upper();
    for i, a in ipairs(jobs.ABBR) do if a == abbr then return i; end end
    return nil;
end

return jobs;
