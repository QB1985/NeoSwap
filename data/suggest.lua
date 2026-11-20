-- suggest.lua : what's worth stacking in a set, by what it's for (the "Use it for" tooltips).
-- General guidance for the level-75 era game CatsEyeXI is built on; a server's own changes may differ.
local M = {};

M.KIND = {
    idle    = 'Defense, HP, Physical / Magic damage taken -, Evasion, Magic defense; Refresh and Regen to recover; Movement speed.',
    engaged = 'Haste, Accuracy, Attack, Store TP, Double / Triple Attack, Critical hit rate, Dual Wield (for two weapons), Subtle Blow. Swap in damage taken - pieces for a safer set.',
    resting = 'HP / MP recovered while healing, Refresh, Regen - and anything that adds Max MP only while you rest, not before.',
    chocobo = 'Chocobo riding time (Chocobo gloves, etc.), Movement speed.',
    ws      = 'The weapon skill\'s own stats (hover one below), Attack, Accuracy, weapon skill damage. Critical hit rate / DEX for critical weapon skills; INT or MND and Magic Attack Bonus for elemental ones. Hover a weapon skill for its stats.',
    ja      = 'The ability\'s own bonus ("Boost" +, "Jump" +, "Steal" +, "Provoke" / Enmity +, "Chakra" +, Avatar perpetuation for Blood Pacts...). Hover an ability for ideas.',
    precast = 'Fast Cast, "casting time -" for that kind of magic (Cure / Elemental casting time -), Spell interruption rate -. Kept short: it comes off when the spell starts.',
    midcast = 'What the spell is made better by: its magic skill, INT (black magic) or MND (white magic), Magic Accuracy, Magic Attack Bonus, Cure potency, Enmity -. Pick a magic skill below to see more.',
    preshot = 'Snapshot, "Rapid Shot" - for a faster ranged attack.',
    midshot = 'Ranged Accuracy, Ranged Attack, AGI, Store TP, "Recycle", "Barrage" +.',
    item    = 'Whatever helps the item: "Holy Water" + for Holy Water, food duration, Movement speed for a Warp ring\'s wait...',
    pet     = 'Pet: Attack, Accuracy, Magic Attack Bonus, Blood Pact damage, Blood Pact ability delay -, Summoning magic skill - whatever the pet move uses.',
    manual  = 'Anything: this set only goes on when a command or /nswap set puts it on.',
};

M.SKILL = {
    ['Healing Magic']    = 'Cure potency, MND, Healing magic skill, Enmity -, Cure casting time - (precast).',
    ['Enhancing Magic']  = 'Enhancing magic skill (Stoneskin, Bar-spells, En-spells), MND (Stoneskin), Enhancing magic duration.',
    ['Enfeebling Magic'] = 'Magic Accuracy, Enfeebling magic skill, MND (Slow, Paralyze, Silence) or INT (Blind, Gravity, Poison).',
    ['Elemental Magic']  = 'INT, Magic Attack Bonus, Magic Accuracy, Elemental magic skill, Magic damage; elemental staves and obis by element.',
    ['Divine Magic']     = 'MND, Divine magic skill, Magic Attack Bonus (Banish, Holy), Magic Accuracy (Flash, Repose).',
    ['Dark Magic']       = 'Dark magic skill, INT, Magic Accuracy; "Drain" / "Aspir" potency for Drain and Aspir.',
    ['Summoning Magic']  = 'Summoning magic skill, Avatar perpetuation cost -, Blood Pact ability delay -.',
    ['Ninjutsu']         = 'Ninjutsu skill, INT and Magic Attack Bonus (elemental ninjutsu), Magic Accuracy (Kurayami, Hojo); Haste and Fast Cast for Utsusemi.',
    ['Singing']          = 'CHR, Singing skill, the instrument\'s skill (String / Wind), Song duration / effect +.',
    ['Blue Magic']       = 'Physical spells: the spell\'s stat (STR, DEX, VIT, AGI...), Accuracy, Attack. Magical spells: INT, Magic Attack Bonus. Blue magic skill.',
    ['Geomancy']         = 'Geomancy skill, Handbell skill, Indicolure / Geocolure potency and duration.',
};

-- Weapon skills: their stats, and whether they're elemental (magic) or mostly critical hits
local W = {};
local function ws(list, stats, kind) for _, n in ipairs(list) do W[n:lower()] = { stats = stats, kind = kind }; end end
-- hand-to-hand
ws({ 'Combo', 'Backhand Blow', 'Raging Fists', 'Dragon Kick' }, 'STR, DEX');
ws({ 'Shoulder Tackle', 'One Inch Punch', 'Final Heaven' }, 'VIT');
ws({ 'Spinning Attack' }, 'STR');
ws({ 'Howling Fist', 'Asuran Fists', 'Ascetic\'s Fury', 'Stringing Pummel' }, 'STR, VIT');
-- dagger
ws({ 'Wasp Sting', 'Viper Bite', 'Mandalic Stab' }, 'DEX');
ws({ 'Evisceration' }, 'DEX', 'crit');
ws({ 'Gust Slash', 'Cyclone' }, 'DEX, INT', 'magic');
ws({ 'Shadowstitch' }, 'CHR');
ws({ 'Energy Steal', 'Energy Drain' }, 'MND', 'magic');
ws({ 'Dancing Edge', 'Mordant Rime' }, 'DEX, CHR');
ws({ 'Shark Bite' }, 'DEX, AGI');
ws({ 'Mercy Stroke' }, 'STR');
ws({ 'Aeolian Edge' }, 'DEX, INT', 'magic');
-- sword
ws({ 'Fast Blade' }, 'STR, DEX');
ws({ 'Burning Blade', 'Red Lotus Blade' }, 'STR, INT', 'magic');
ws({ 'Shining Blade', 'Seraph Blade' }, 'STR, MND', 'magic');
ws({ 'Flat Blade', 'Circle Blade', 'Vorpal Blade' }, 'STR');
ws({ 'Swift Blade', 'Savage Blade', 'Knights of Round', 'Death Blossom' }, 'STR, MND');
ws({ 'Spirits Within' }, 'none (it uses your HP and TP)');
ws({ 'Sanguine Blade' }, 'MND, STR', 'magic');
ws({ 'Expiacion' }, 'STR, INT');
-- great sword
ws({ 'Hard Slash', 'Crescent Moon' }, 'STR');
ws({ 'Power Slash', 'Scourge' }, 'STR, VIT');
ws({ 'Frostbite', 'Freezebite' }, 'STR, INT', 'magic');
ws({ 'Shockwave' }, 'STR, MND');
ws({ 'Sickle Moon' }, 'STR, AGI');
ws({ 'Spinning Slash', 'Ground Strike' }, 'STR, INT');
ws({ 'Herculean Slash' }, 'VIT', 'magic');
-- axe
ws({ 'Raging Axe', 'Smash Axe', 'Gale Axe', 'Avalanche Axe', 'Spinning Axe', 'Mistral Axe', 'Decimation' }, 'STR');
ws({ 'Rampage' }, 'STR', 'crit');
ws({ 'Calamity' }, 'STR, VIT');
ws({ 'Onslaught' }, 'DEX');
ws({ 'Primal Rend' }, 'CHR, DEX', 'magic');
-- great axe
ws({ 'Shield Break', 'Armor Break', 'Weapon Break', 'Full Break', 'Steel Cyclone' }, 'STR, VIT');
ws({ 'Iron Tempest', 'Sturmwind', 'Raging Rush', 'Metatron Torment', 'King\'s Justice' }, 'STR');
ws({ 'Keen Edge' }, 'STR', 'crit');
-- scythe
ws({ 'Slice', 'Spinning Scythe', 'Vorpal Scythe' }, 'STR');
ws({ 'Dark Harvest', 'Shadow of Death', 'Infernal Scythe' }, 'STR, INT', 'magic');
ws({ 'Nightmare Scythe', 'Guillotine', 'Cross Reaper' }, 'STR, MND');
ws({ 'Spiral Hell', 'Insurgency' }, 'STR, INT');
ws({ 'Catastrophe' }, 'STR, AGI');
-- polearm
ws({ 'Double Thrust', 'Leg Sweep', 'Skewer', 'Wheeling Thrust', 'Impulse Drive', 'Drakesbane' }, 'STR');
ws({ 'Thunder Thrust', 'Raiden Thrust' }, 'STR, INT', 'magic');
ws({ 'Penta Thrust' }, 'STR, DEX');
ws({ 'Vorpal Thrust' }, 'STR, AGI');
ws({ 'Geirskogul' }, 'DEX');
-- katana
ws({ 'Blade: Rin', 'Blade: Jin', 'Blade: Ten', 'Blade: Ku' }, 'STR, DEX');
ws({ 'Blade: Retsu', 'Blade: Metsu' }, 'DEX');
ws({ 'Blade: Teki', 'Blade: To', 'Blade: Chi', 'Blade: Ei' }, 'STR, INT', 'magic');
ws({ 'Blade: Kamu' }, 'STR, INT');
-- great katana
ws({ 'Tachi: Enpi', 'Tachi: Hobaku', 'Tachi: Kagero', 'Tachi: Jinpu', 'Tachi: Yukikaze', 'Tachi: Gekko', 'Tachi: Kasha',
     'Tachi: Kaiten', 'Tachi: Rana' }, 'STR');
ws({ 'Tachi: Goten' }, 'STR', 'magic');
ws({ 'Tachi: Koki' }, 'STR, MND', 'magic');
-- club
ws({ 'Shining Strike', 'Seraph Strike' }, 'STR, MND', 'magic');
ws({ 'Brainshaker', 'Skullbreaker', 'True Strike' }, 'STR');
ws({ 'Judgment', 'Black Halo', 'Randgrith', 'Mystic Boon' }, 'STR, MND');
ws({ 'Hexa Strike' }, 'STR, MND', 'crit');
ws({ 'Starlight', 'Moonlight' }, 'none (restores MP by your Club skill)');
-- staff
ws({ 'Heavy Swing', 'Shell Crusher', 'Full Swing' }, 'STR');
ws({ 'Rock Crusher', 'Earth Crusher' }, 'STR, INT', 'magic');
ws({ 'Starburst', 'Sunburst' }, 'STR, MND', 'magic');
ws({ 'Spirit Taker' }, 'INT, MND');
ws({ 'Retribution' }, 'STR, MND');
ws({ 'Gate of Tartarus', 'Vidohunir', 'Cataclysm' }, 'INT', 'magic');
ws({ 'Garland of Bliss', 'Omniscience' }, 'MND', 'magic');
-- archery
ws({ 'Flaming Arrow' }, 'STR, AGI', 'magic');
ws({ 'Piercing Arrow', 'Dulling Arrow', 'Sidewinder', 'Blast Arrow', 'Arching Arrow', 'Empyreal Arrow', 'Namas Arrow',
     'Refulgent Arrow' }, 'STR, AGI', 'ranged');
-- marksmanship
ws({ 'Hot Shot' }, 'AGI', 'magic');
ws({ 'Split Shot', 'Sniper Shot', 'Slug Shot', 'Blast Shot', 'Heavy Shot', 'Detonator' }, 'AGI', 'ranged');
ws({ 'Coronach' }, 'DEX, AGI', 'ranged');
ws({ 'Leaden Salute', 'Trueflight', 'Wildfire' }, 'AGI', 'magic');
M.WS = W;

-- Some job abilities with gear made for them
M.JA = {
    ['jump'] = 'VIT, Attack, Accuracy, "Jump" + (Drachen armor).',
    ['high jump'] = 'VIT, Attack, Accuracy, "High Jump" +.',
    ['spirit jump'] = 'VIT, Attack, Accuracy.',
    ['steal'] = '"Steal" + (Rogue\'s armor, Thief\'s Knife...).',
    ['mug'] = 'DEX, AGI, "Mug" +.',
    ['sneak attack'] = 'DEX, Critical hit damage - and then your weapon skill.',
    ['trick attack'] = 'AGI, Critical hit damage.',
    ['provoke'] = 'Enmity +.',
    ['boost'] = '"Boost" + (Temple gloves).',
    ['chakra'] = 'VIT, MND, "Chakra" + (Temple / Melee armor).',
    ['chi blast'] = 'MND.',
    ['focus'] = '"Focus" +.',
    ['dodge'] = '"Dodge" +.',
    ['counterstance'] = '"Counter" +, VIT.',
    ['warcry'] = '"Warcry" duration +.',
    ['berserk'] = '"Berserk" duration +.',
    ['meditate'] = '"Meditate" + (Myochin kabuto).',
    ['third eye'] = '"Third Eye" +.',
    ['shield bash'] = '"Shield Bash" +, Enmity +, Shield skill.',
    ['sentinel'] = 'Enmity +, "Sentinel" duration +.',
    ['cover'] = '"Cover" duration +.',
    ['holy circle'] = 'Enmity +.',
    ['arcane circle'] = '"Arcane Circle" +.',
    ['weapon bash'] = '"Weapon Bash" +.',
    ['souleater'] = '"Souleater" +.',
    ['charm'] = 'CHR, "Charm" + (Beast armor).',
    ['reward'] = 'MND, "Reward" +.',
    ['call beast'] = '"Call Beast" ability delay -.',
    ['sharpshot'] = 'Ranged Accuracy.',
    ['barrage'] = '"Barrage" +, Ranged Accuracy, Ranged Attack.',
    ['scavenge'] = '"Scavenge" +.',
    ['elemental siphon'] = 'Summoning magic skill, "Elemental Siphon" +.',
    ['convert'] = 'Max HP / MP balance (HP- MP+ pieces raise what Convert gives).',
    ['chainspell'] = 'Fast Cast for the spells that follow.',
    ['nightingale'] = '"Nightingale" +.',
    ['troubadour'] = '"Troubadour" +.',
    ['wild card'] = '"Wild Card" +.',
    ['phantom roll'] = '"Phantom Roll" + (Phantom roll effect, duration).',
    ['quick draw'] = 'AGI, Magic Attack Bonus, Magic Accuracy.',
    ['waltz'] = 'CHR, VIT, "Waltz" potency +.',
    ['curing waltz'] = 'CHR, VIT, "Waltz" potency +.',
    ['steps'] = 'Accuracy, "Steps" +.',
    ['violent flourish'] = 'Accuracy, CHR, Magic Accuracy.',
    ['animated flourish'] = 'Enmity +.',
    ['repair'] = '"Repair" +, Oil.',
    ['maneuvers'] = '"Maneuver" +.',
};

-- A tooltip line for a weapon skill: its stats and what else helps
function M.ws_text(name)
    local e = W[tostring(name or ''):lower()];
    if e == nil then return nil; end
    local t = 'Stats: ' .. e.stats .. '.';
    if e.kind == 'magic' then t = t .. '\nElemental: Magic Attack Bonus, Magic Accuracy, the stats above (and obi / gorget by element).';
    elseif e.kind == 'crit' then t = t .. '\nCritical hits: Critical hit rate, DEX, Accuracy, Attack.';
    elseif e.kind == 'ranged' then t = t .. '\nRanged: Ranged Attack, Ranged Accuracy, weapon skill damage.';
    else t = t .. '\nAlso: Attack, Accuracy, weapon skill damage.'; end
    return t;
end

-- The stats a list of weapon skill names use, merged ("STR, DEX, VIT"), or nil
function M.ws_stats(names)
    local seen, out = {}, {};
    for _, n in ipairs(names or {}) do
        local e = W[tostring(n):lower()];
        if e then
            for st in e.stats:gmatch('%u%u%u') do
                if not seen[st] then seen[st] = true; out[#out + 1] = st; end
            end
        end
    end
    return #out > 0 and table.concat(out, ', ') or nil;
end

function M.ja_text(name)
    return M.JA[tostring(name or ''):lower()];
end

return M;
