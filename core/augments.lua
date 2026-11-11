-- augments.lua : the augments on a piece of gear, read from its hidden item data.
-- The decoding and the augment tables are LuAshitacast's (data.lua GetAugment, constants.lua; by Thorny, GPL-3.0).
--   augments.of(item)  -> { type, path, rank, list = { 'STR+3', 'Accuracy+5', ... } } or nil (no augments)
--   augments.matches(item, want) -> does this copy have every augment (and the path / rank) a set asks for
local augments = {};
local A = {};

A.AugmentPaths = {
    [1] = 'A',
    [2] = 'B',
    [3] = 'C',
    [4] = 'D'
};

A.BasicAugments = {
    [1] = { Stat='HP', Offset=1},
    [2] = { Stat='HP', Offset=33},
    [3] = { Stat='HP', Offset=65},
    [4] = { Stat='HP', Offset=97},
    [5] = { Stat='HP', Offset=1, Multiplier=-1},
    [6] = { Stat='HP', Offset=33, Multiplier=-1},
    [7] = { Stat='HP', Offset=65, Multiplier=-1},
    [8] = { Stat='HP', Offset=97, Multiplier=-1},
    [9] = { Stat='MP', Offset=1},
    [10] = { Stat='MP', Offset=33},
    [11] = { Stat='MP', Offset=65},
    [12] = { Stat='MP', Offset=97},
    [13] = { Stat='MP', Offset=1, Multiplier=-1},
    [14] = { Stat='MP', Offset=33, Multiplier=-1},
    [15] = { Stat='MP', Offset=65, Multiplier=-1},
    [16] = { Stat='MP', Offset=97, Multiplier=-1},
    [17] = { Multi=true, [1] = { Stat='HP', Offset=1}, [2] = { Stat='MP', Offset=1} };
    [18] = { Multi=true, [1] = { Stat='HP', Offset=33}, [2] = { Stat='MP', Offset=33} };
    [19] = { Multi=true, [1] = { Stat='HP', Offset=1}, [2] = { Stat='MP', Offset=1, Multiplier=-1} };
    [20] = { Multi=true, [1] = { Stat='HP', Offset=33}, [2] = { Stat='MP', Offset=33, Multiplier=-1} };
    [21] = { Multi=true, [1] = { Stat='HP', Offset=1, Multiplier=-1}, [2] = { Stat='MP', Offset=1} };
    [22] = { Multi=true, [1] = { Stat='HP', Offset=33, Multiplier=-1}, [2] = { Stat='MP', Offset=33} };
    [23] = { Stat='Accuracy', Offset=1},
    [24] = { Stat='Accuracy', Offset=1, Multiplier=-1},
    [25] = { Stat='Attack', Offset=1},
    [26] = { Stat='Attack', Offset=1, Multiplier=-1},
    [27] = { Stat='Rng.Acc.', Offset=1},
    [28] = { Stat='Rng.Acc.', Offset=1, Multiplier=-1},
    [29] = { Stat='Rng.Atk.', Offset=1},
    [30] = { Stat='Rng.Atk.', Offset=1, Multiplier=-1},
    [31] = { Stat='Evasion', Offset=1},
    [32] = { Stat='Evasion', Offset=1, Multiplier=-1},
    [33] = { Stat='DEF', Offset=1},
    [34] = { Stat='DEF', Offset=1, Multiplier=-1},
    [35] = { Stat='Mag. Acc.', Offset=1},
    [36] = { Stat='Mag. Acc.', Offset=1, Multiplier=-1},
    [37] = { Stat='Mag. Evasion', Offset=1},
    [38] = { Stat='Mag. Evasion', Offset=1, Multiplier=-1},
    [39] = { Stat='Enmity', Offset=1},
    [40] = { Stat='Enmity', Offset=1, Multiplier=-1},
    [41] = { Stat='Crit.hit rate', Offset=1},
    [42] = { Stat='Enemy crit. hit rate ', Offset=1, Multiplier=-1},
    [43] = { Stat='"Charm"', Offset=1},
    [44] = { Multi=true, [1] = { Stat='"Store TP"', Offset=1}, [2] = { Stat='"Subtle Blow"', Offset=1} };
    [45] = { Stat='DMG:', Offset=1},
    [46] = { Stat='DMG:', Offset=1, Multiplier=-1},
    [47] = { Stat='Delay:', Offset=1, Percent=true},
    [48] = { Stat='Delay:', Offset=1, Multiplier=-1, Percent=true},
    [49] = { Stat='Haste', Offset=1},
    [50] = { Stat='"Slow"', Offset=1},
    [51] = { Stat='HP recovered while healing ', Offset=1},
    [52] = { Stat='MP recovered while healing ', Offset=1},
    [53] = { Stat='Spell interruption rate down ', Offset=1, Multiplier=-1, Percent=true},
    [54] = { Stat='Phys. dmg. taken ', Offset=1, Multiplier=-1, Percent=true},
    [55] = { Stat='Magic dmg. taken ', Offset=1, Multiplier=-1, Percent=true},
    [56] = { Stat='Breath dmg. taken ', Offset=1, Multiplier=-1, Percent=true},
    [57] = { Stat='Magic crit. hit rate ', Offset=1},
    [58] = { Stat='"Mag.Def.Bns."', Offset=1, Multiplier=-1},
    [59] = { Stat='Latent effect: "Regain"', Offset=1},
    [60] = { Stat='Latent effect: "Refresh"', Offset=1},
    [61] = { Stat='Occ. inc. resist. to stat. ailments ', Offset=1},
    [62] = { Stat='Accuracy', Offset=33},
    [63] = { Stat='Rng.Acc.', Offset=33},
    [64] = { Stat='Mag. Acc.', Offset=33},
    [65] = { Stat='Attack', Offset=33},
    [66] = { Stat='Rng.Atk.', Offset=33},
    [67] = { Stat='All Songs', Offset=1},
    [68] = { Multi=true, [1] = { Stat='Accuracy', Offset=1}, [2] = { Stat='Attack', Offset=1} };
    [69] = { Multi=true, [1] = { Stat='Rng.Acc.', Offset=1}, [2] = { Stat='Rng.Atk.', Offset=1} };
    [70] = { Multi=true, [1] = { Stat='Mag. Acc.', Offset=1}, [2] = { Stat='"Mag. Atk. Bns."', Offset=1} };
    [71] = { Stat='Damage taken', Offset=1, Multiplier=-1, Percent=true},
    [74] = { Stat='Cap. Point', Offset=1, Percent=true},
    [75] = { Stat='Cap. Point', Offset=33, Percent=true},
    [76] = { Stat='DMG:', Offset=33},
    [77] = { Stat='Delay:', Offset=33, Multiplier=-1, Percent=true},
    [78] = { Stat='HP', Offset=1, Multiplier=2},
    [79] = { Stat='HP', Offset=1, Multiplier=3},
    [80] = { Multi=true, [1] = { Stat='Mag. Acc.', Offset=1}, [2] = { Stat='Magic Damage', Offset=1} };
    [81] = { Multi=true, [1] = { Stat='Evasion', Offset=1}, [2] = { Stat='Mag. Evasion', Offset=1} };
    [82] = { Stat='MP', Offset=1, Multiplier=2},
    [83] = { Stat='MP', Offset=1, Multiplier=3},
    [96] = { Multi=true, [1] = { Stat='Pet: Accuracy', Offset=1}, [2] = { Stat='Pet: Rng. Acc.', Offset=1} };
    [97] = { Multi=true, [1] = { Stat='Pet: Attack', Offset=1}, [2] = { Stat='Pet: Rng.Atk.', Offset=1} };
    [98] = { Stat='Pet: Evasion', Offset=1},
    [99] = { Stat='Pet: DEF', Offset=1},
    [100] = { Stat='Pet: Mag. Acc.', Offset=1},
    [101] = { Stat='Pet: "Mag. Atk. Bns."', Offset=1},
    [102] = { Stat='Pet: Crit.hit rate ', Offset=1},
    [103] = { Stat='Pet: Enemy crit. hit rate ', Offset=1, Multiplier=-1},
    [104] = { Stat='Pet: Enmity', Offset=1},
    [105] = { Stat='Pet: Enmity', Offset=1, Multiplier=-1},
    [106] = { Multi=true, [1] = { Stat='Pet: Accuracy', Offset=1}, [2] = { Stat='Pet: Rng. Acc.', Offset=1} };
    [107] = { Multi=true, [1] = { Stat='Pet: Attack', Offset=1}, [2] = { Stat='Pet: Rng.Atk.', Offset=1} };
    [108] = { Multi=true, [1] = { Stat='Pet: Mag. Acc.', Offset=1}, [2] = { Stat='Pet: "Mag. Atk. Bns."', Offset=1} };
    [109] = { Multi=true, [1] = { Stat='Pet: "Dbl.Atk."', Offset=1}, [2] = { Stat='Pet: Crit.hit rate ', Offset=1} };
    [110] = { Stat='Pet: "Regen"', Offset=1},
    [111] = { Stat='Pet: Haste', Offset=1},
    [112] = { Stat='Pet: Damage taken ', Offset=1, Multiplier=-1, Percent=true},
    [113] = { Stat='Pet: Rng.Acc.', Offset=1},
    [114] = { Stat='Pet: Rng.Atk.', Offset=1},
    [115] = { Stat='Pet: "Store TP"', Offset=1},
    [116] = { Stat='Pet: "Subtle Blow"', Offset=1},
    [117] = { Stat='Pet: Mag. Evasion', Offset=1},
    [118] = { Stat='Pet: Phys. dmg. taken ', Offset=1, Multiplier=-1, Percent=true},
    [119] = { Stat='Pet: "Mag.Def.Bns."', Offset=1},
    [120] = { Stat='Avatar: "Mag. Atk. Bns."', Offset=1},
    [121] = { Stat='Pet: Breath', Offset=1},
    [122] = { Stat='Pet: TP Bonus', Offset=1, Multiplier=20},
    [123] = { Stat='Pet: "Dbl. Atk."', Offset=1},
    [124] = { Multi=true, [1] = { Stat='Pet: Acc.', Offset=1}, [2] = { Stat='Pet: R.Acc.', Offset=1}, [3] = { Stat='Pet: Atk.', Offset=1}, [4] = { Stat='Pet: R.Atk.', Offset=1} };
    [125] = { Multi=true, [1] = { Stat='Pet: M.Acc.', Offset=1}, [2] = { Stat='Pet: M.Dmg.', Offset=1} };
    [126] = { Stat='Pet: Magic Damage', Offset=1},
    [127] = { Stat='Pet: Magic dmg. taken ', Offset=1, Multiplier=-1, Percent=true},
    [128] = { Stat='Pet:'},
    [133] = { Stat='"Mag. Atk. Bns."', Offset=1},
    [134] = { Stat='"Mag.Def.Bns."', Offset=1},
    [135] = { Stat='Avatar:'},
    [137] = { Stat='"Regen"', Offset=1},
    [138] = { Stat='"Refresh"', Offset=1},
    [139] = { Stat='"Rapid Shot"', Offset=1},
    [140] = { Stat='"Fast Cast"', Offset=1},
    [141] = { Stat='"Conserve MP"', Offset=1},
    [142] = { Stat='"Store TP"', Offset=1},
    [143] = { Stat='"Dbl.Atk."', Offset=1},
    [144] = { Stat='"Triple Atk."', Offset=1},
    [145] = { Stat='"Counter"', Offset=1},
    [146] = { Stat='"Dual Wield"', Offset=1},
    [147] = { Stat='"Treasure Hunter"', Offset=1},
    [148] = { Stat='"Gilfinder"', Offset=1},
    [151] = { Stat='"Martial Arts"', Offset=1},
    [153] = { Stat='"Shield Mastery"', Offset=1},
    [176] = { Stat='"Resist Sleep"', Offset=1},
    [177] = { Stat='"Resist Poison"', Offset=1},
    [178] = { Stat='"Resist Paralyze"', Offset=1},
    [179] = { Stat='"Resist Blind"', Offset=1},
    [180] = { Stat='"Resist Silence"', Offset=1},
    [181] = { Stat='"Resist Petrify"', Offset=1},
    [182] = { Stat='"Resist Virus"', Offset=1},
    [183] = { Stat='"Resist Curse"', Offset=1},
    [184] = { Stat='"Resist Stun"', Offset=1},
    [185] = { Stat='"Resist Bind"', Offset=1},
    [186] = { Stat='"Resist Gravity"', Offset=1},
    [187] = { Stat='"Resist Slow"', Offset=1},
    [188] = { Stat='"Resist Charm"', Offset=1},
    [194] = { Stat='"Kick Attacks"', Offset=1},
    [195] = { Stat='"Subtle Blow"', Offset=1},
    [198] = { Stat='"Zanshin"', Offset=1},
    [211] = { Stat='"Snapshot"', Offset=1},
    [212] = { Stat='"Recycle"', Offset=1},
    [215] = { Stat='"Ninja tool expertise"', Offset=1},
    [233] = { Stat='"Blood Boon"', Offset=1},
    [237] = { Stat='"Occult Acumen"', Offset=1},
    [257] = { Stat='Hand-to-Hand skill ', Offset=1},
    [258] = { Stat='Dagger skill ', Offset=1},
    [259] = { Stat='Sword skill ', Offset=1},
    [260] = { Stat='Great Sword skill ', Offset=1},
    [261] = { Stat='Axe skill ', Offset=1},
    [262] = { Stat='Great Axe skill ', Offset=1},
    [263] = { Stat='Scythe skill ', Offset=1},
    [264] = { Stat='Polearm skill ', Offset=1},
    [265] = { Stat='Katana skill ', Offset=1},
    [266] = { Stat='Great Katana skill ', Offset=1},
    [267] = { Stat='Club skill ', Offset=1},
    [268] = { Stat='Staff skill ', Offset=1},
    [278] = { Stat='Melee skill ', Offset=1},
    [279] = { Stat='Ranged skill ', Offset=1},
    [280] = { Stat='Magic skill ', Offset=1},
    [281] = { Stat='Archery skill ', Offset=1},
    [282] = { Stat='Marksmanship skill ', Offset=1},
    [283] = { Stat='Throwing skill ', Offset=1},
    [286] = { Stat='Shield skill ', Offset=1},
    [288] = { Stat='Divine magic skill ', Offset=1},
    [289] = { Stat='Healing magic skill ', Offset=1},
    [290] = { Stat='Enha.mag. skill ', Offset=1},
    [291] = { Stat='Enfb.mag. skill ', Offset=1},
    [292] = { Stat='Elem. magic skill ', Offset=1},
    [293] = { Stat='Dark magic skill ', Offset=1},
    [294] = { Stat='Summoning magic skill ', Offset=1},
    [295] = { Stat='Ninjutsu skill ', Offset=1},
    [296] = { Stat='Singing skill ', Offset=1},
    [297] = { Stat='String instrument skill ', Offset=1},
    [298] = { Stat='Wind instrument skill ', Offset=1},
    [299] = { Stat='Blue Magic skill ', Offset=1},
    [300] = { Stat='Geomancy Skill ', Offset=1},
    [301] = { Stat='Handbell Skill ', Offset=1},
    [320] = { Stat='"Blood Pact" ability delay ', Offset=1, Multiplier=-1},
    [321] = { Stat='"Avatar perpetuation cost" ', Offset=1, Multiplier=-1},
    [322] = { Stat='Song spellcasting time ', Offset=1, Multiplier=-1, Percent=true},
    [323] = { Stat='"Cure" spellcasting time ', Offset=1, Multiplier=-1, Percent=true},
    [324] = { Stat='"Call Beast" ability delay ', Offset=1, Multiplier=-1},
    [325] = { Stat='"Quick Draw" ability delay ', Offset=1, Multiplier=-1},
    [326] = { Stat='Weapon Skill Acc.', Offset=1},
    [327] = { Stat='Weapon skill damage ', Offset=1, Percent=true},
    [328] = { Stat='Crit. hit damage ', Offset=1, Percent=true},
    [329] = { Stat='"Cure" potency ', Offset=1, Percent=true},
    [330] = { Stat='"Waltz" potency ', Offset=1, Percent=true},
    [331] = { Stat='"Waltz" ability delay ', Offset=1, Multiplier=-1},
    [332] = { Stat='Sklchn.dmg.', Offset=1, Percent=true},
    [333] = { Stat='"Conserve TP"', Offset=1},
    [334] = { Stat='Magic burst dmg.', Offset=1, Percent=true},
    [335] = { Stat='Mag. crit. hit dmg. ', Offset=1, Percent=true},
    [336] = { Stat='"Sic" and "Ready" ability delay ', Offset=1, Multiplier=-1},
    [337] = { Stat='Song recast delay ', Offset=1, Multiplier=-1},
    [338] = { Stat='"Barrage"', Offset=1},
    [339] = { Stat='"Elemental Siphon"', Offset=1, Multiplier=5},
    [340] = { Stat='"Phantom Roll" ability delay ', Offset=1, Multiplier=-1},
    [341] = { Stat='"Repair" potency ', Offset=1, Percent=true},
    [342] = { Stat='"Waltz" TP cost ', Offset=1, Multiplier=-1},
    [343] = { Stat='"Drain" and "Aspir" potency ', Offset=1},
    [350] = { Stat='Occ. maximizes magic accuracy ', Offset=1, Percent=true},
    [351] = { Stat='Occ. quickens spellcasting ', Offset=1, Percent=true},
    [352] = { Stat='Occ. grants dmg. bonus based on TP ', Offset=1, Percent=true},
    [353] = { Stat='TP Bonus ', Offset=1, Multiplier=50},
    [354] = { Stat='Quadruple Attack ', Offset=1},
    [356] = { Stat='Potency of "Cure" effect received', Offset=1, Percent=true},
    [360] = { Stat='Save TP ', Offset=1, Multiplier=10},
    [362] = { Stat='Magic Damage ', Offset=1},
    [363] = { Stat='Chance of successful block ', Offset=1},
    [366] = { Stat='Blood Pact ab. del. II ', Offset=1, Multiplier=-1},
    [368] = { Stat='Phalanx ', Offset=1},
    [369] = { Stat='Blood Pact Dmg.', Offset=1},
    [370] = { Stat='"Rev. Flourish"', Offset=1},
    [371] = { Stat='"Regen" potency', Offset=1},
    [372] = { Stat='"Embolden"', Offset=1},
    [512] = { Stat='STR', Offset=1},
    [513] = { Stat='DEX', Offset=1},
    [514] = { Stat='VIT', Offset=1},
    [515] = { Stat='AGI', Offset=1},
    [516] = { Stat='INT', Offset=1},
    [517] = { Stat='MND', Offset=1},
    [518] = { Stat='CHR', Offset=1},
    [519] = { Stat='STR', Offset=1, Multiplier=-1},
    [520] = { Stat='DEX', Offset=1, Multiplier=-1},
    [521] = { Stat='VIT', Offset=1, Multiplier=-1},
    [522] = { Stat='AGI', Offset=1, Multiplier=-1},
    [523] = { Stat='INT', Offset=1, Multiplier=-1},
    [524] = { Stat='MND', Offset=1, Multiplier=-1},
    [525] = { Stat='CHR', Offset=1, Multiplier=-1},
    [526] = { Multi=true, [1] = { Stat='STR', Offset=1}, [2] = { Stat='DEX', Offset=1, Multiplier=0}, [3] = { Stat='VIT', Offset=1, Multiplier=0} };
    [527] = { Multi=true, [1] = { Stat='STR', Offset=1}, [2] = { Stat='DEX', Offset=1, Multiplier=0}, [3] = { Stat='AGI', Offset=1, Multiplier=0} };
    [528] = { Multi=true, [1] = { Stat='STR', Offset=1}, [2] = { Stat='VIT', Offset=1, Multiplier=0}, [3] = { Stat='AGI', Offset=1, Multiplier=0} };
    [529] = { Multi=true, [1] = { Stat='STR', Offset=1, Multiplier=0}, [2] = { Stat='DEX', Offset=1}, [3] = { Stat='VIT', Offset=1, Multiplier=0} };
    [530] = { Multi=true, [1] = { Stat='STR', Offset=1, Multiplier=0}, [2] = { Stat='DEX', Offset=1}, [3] = { Stat='AGI', Offset=1, Multiplier=0} };
    [531] = { Multi=true, [1] = { Stat='DEX', Offset=1}, [2] = { Stat='VIT', Offset=1, Multiplier=0}, [3] = { Stat='AGI', Offset=1, Multiplier=0} };
    [532] = { Multi=true, [1] = { Stat='STR', Offset=1, Multiplier=0}, [2] = { Stat='DEX', Offset=1, Multiplier=0}, [3] = { Stat='VIT', Offset=1} };
    [533] = { Multi=true, [1] = { Stat='STR', Offset=1, Multiplier=0}, [2] = { Stat='VIT', Offset=1}, [3] = { Stat='AGI', Offset=1, Multiplier=0} };
    [534] = { Multi=true, [1] = { Stat='DEX', Offset=1, Multiplier=0}, [2] = { Stat='VIT', Offset=1}, [3] = { Stat='AGI', Offset=1, Multiplier=0} };
    [535] = { Multi=true, [1] = { Stat='STR', Offset=1, Multiplier=0}, [2] = { Stat='DEX', Offset=1, Multiplier=0}, [3] = { Stat='AGI', Offset=1} };
    [536] = { Multi=true, [1] = { Stat='STR', Offset=1, Multiplier=0}, [2] = { Stat='VIT', Offset=1, Multiplier=0}, [3] = { Stat='AGI', Offset=1} };
    [537] = { Multi=true, [1] = { Stat='DEX', Offset=1, Multiplier=0}, [2] = { Stat='VIT', Offset=1, Multiplier=0}, [3] = { Stat='AGI', Offset=1} };
    [538] = { Multi=true, [1] = { Stat='AGI', Offset=1}, [2] = { Stat='INT', Offset=1, Multiplier=0}, [3] = { Stat='MND', Offset=1, Multiplier=0} };
    [539] = { Multi=true, [1] = { Stat='AGI', Offset=1}, [2] = { Stat='INT', Offset=1, Multiplier=0}, [3] = { Stat='CHR', Offset=1, Multiplier=0} };
    [540] = { Multi=true, [1] = { Stat='AGI', Offset=1}, [2] = { Stat='MND', Offset=1, Multiplier=0}, [3] = { Stat='CHR', Offset=1, Multiplier=0} };
    [541] = { Multi=true, [1] = { Stat='AGI', Offset=1, Multiplier=0}, [2] = { Stat='INT', Offset=1}, [3] = { Stat='MND', Offset=1, Multiplier=0} };
    [542] = { Multi=true, [1] = { Stat='AGI', Offset=1, Multiplier=0}, [2] = { Stat='INT', Offset=1}, [3] = { Stat='CHR', Offset=1, Multiplier=0} };
    [543] = { Multi=true, [1] = { Stat='INT', Offset=1}, [2] = { Stat='MND', Offset=1, Multiplier=0}, [3] = { Stat='CHR', Offset=1, Multiplier=0} };
    [544] = { Multi=true, [1] = { Stat='AGI', Offset=1, Multiplier=0}, [2] = { Stat='INT', Offset=1, Multiplier=0}, [3] = { Stat='MND', Offset=1} };
    [545] = { Multi=true, [1] = { Stat='AGI', Offset=1, Multiplier=0}, [2] = { Stat='MND', Offset=1}, [3] = { Stat='CHR', Offset=1, Multiplier=0} };
    [546] = { Multi=true, [1] = { Stat='INT', Offset=1, Multiplier=0}, [2] = { Stat='MND', Offset=1}, [3] = { Stat='CHR', Offset=1, Multiplier=0} };
    [547] = { Multi=true, [1] = { Stat='AGI', Offset=1, Multiplier=0}, [2] = { Stat='INT', Offset=1, Multiplier=0}, [3] = { Stat='CHR', Offset=1} };
    [548] = { Multi=true, [1] = { Stat='AGI', Offset=1, Multiplier=0}, [2] = { Stat='MND', Offset=1, Multiplier=0}, [3] = { Stat='CHR', Offset=1} };
    [549] = { Multi=true, [1] = { Stat='INT', Offset=1, Multiplier=0}, [2] = { Stat='MND', Offset=1, Multiplier=0}, [3] = { Stat='CHR', Offset=1} };
    [550] = { Multi=true, [1] = { Stat='STR', Offset=1}, [2] = { Stat='DEX', Offset=1} };
    [551] = { Multi=true, [1] = { Stat='STR', Offset=1}, [2] = { Stat='VIT', Offset=1} };
    [552] = { Multi=true, [1] = { Stat='STR', Offset=1}, [2] = { Stat='AGI', Offset=1} };
    [553] = { Multi=true, [1] = { Stat='DEX', Offset=1}, [2] = { Stat='AGI', Offset=1} };
    [554] = { Multi=true, [1] = { Stat='INT', Offset=1}, [2] = { Stat='MND', Offset=1} };
    [555] = { Multi=true, [1] = { Stat='MND', Offset=1}, [2] = { Stat='CHR', Offset=1} };
    [556] = { Multi=true, [1] = { Stat='INT', Offset=1}, [2] = { Stat='MND', Offset=1}, [3] = { Stat='CHR', Offset=1} };
    [557] = { Multi=true, [1] = { Stat='STR', Offset=1}, [2] = { Stat='CHR', Offset=1} };
    [558] = { Multi=true, [1] = { Stat='STR', Offset=1}, [2] = { Stat='INT', Offset=1} };
    [559] = { Multi=true, [1] = { Stat='STR', Offset=1}, [2] = { Stat='MND', Offset=1} };
    [740] = { Stat='DMG:', Offset=1},
    [741] = { Stat='DMG:', Offset=33},
    [742] = { Stat='DMG:', Offset=65},
    [743] = { Stat='DMG:', Offset=97},
    [744] = { Stat='DMG:', Offset=1, Multiplier=-1},
    [745] = { Stat='DMG:', Offset=33, Multiplier=-1},
    [746] = { Stat='DMG:', Offset=1},
    [747] = { Stat='DMG:', Offset=33},
    [748] = { Stat='DMG:', Offset=65},
    [749] = { Stat='DMG:', Offset=97},
    [750] = { Stat='DMG:', Offset=1, Multiplier=-1},
    [751] = { Stat='DMG:', Offset=33, Multiplier=-1},
    [752] = { Stat='Delay:', Offset=1},
    [753] = { Stat='Delay:', Offset=33},
    [754] = { Stat='Delay:', Offset=65},
    [755] = { Stat='Delay:', Offset=97},
    [756] = { Stat='Delay:', Offset=1, Multiplier=-1},
    [757] = { Stat='Delay:', Offset=33, Multiplier=-1},
    [758] = { Stat='Delay:', Offset=65, Multiplier=-1},
    [759] = { Stat='Delay:', Offset=97, Multiplier=-1},
    [760] = { Stat='Delay:', Offset=1},
    [761] = { Stat='Delay:', Offset=33},
    [762] = { Stat='Delay:', Offset=65},
    [763] = { Stat='Delay:', Offset=97},
    [764] = { Stat='Delay:', Offset=1, Multiplier=-1},
    [765] = { Stat='Delay:', Offset=33, Multiplier=-1},
    [766] = { Stat='Delay:', Offset=65, Multiplier=-1},
    [767] = { Stat='Delay:', Offset=97, Multiplier=-1},
    [768] = { Stat='Fire resistance', Offset=1},
    [769] = { Stat='Ice resistance', Offset=1},
    [770] = { Stat='Wind resistance', Offset=1},
    [771] = { Stat='Earth resistance', Offset=1},
    [772] = { Stat='Lightning resistance', Offset=1},
    [773] = { Stat='Water resistance', Offset=1},
    [774] = { Stat='Light resistance', Offset=1},
    [775] = { Stat='Dark resistance', Offset=1},
    [776] = { Stat='Fire resistance', Offset=1, Multiplier=-1},
    [777] = { Stat='Ice resistance', Offset=1, Multiplier=-1},
    [778] = { Stat='Wind resistance', Offset=1, Multiplier=-1},
    [779] = { Stat='Earth resistance', Offset=1, Multiplier=-1},
    [780] = { Stat='Lightning resistance', Offset=1, Multiplier=-1},
    [781] = { Stat='Water resistance', Offset=1, Multiplier=-1},
    [782] = { Stat='Light resistance', Offset=1, Multiplier=-1},
    [783] = { Stat='Dark resistance', Offset=1, Multiplier=-1},
    [784] = { Multi=true, [1] = { Stat='Fire resistance', Offset=1}, [2] = { Stat='Water resistance', Offset=1, Multiplier=-1} };
    [785] = { Multi=true, [1] = { Stat='Fire resistance', Offset=1, Multiplier=-1}, [2] = { Stat='Ice resistance', Offset=1} };
    [786] = { Multi=true, [1] = { Stat='Ice resistance', Offset=1, Multiplier=-1}, [2] = { Stat='Wind resistance', Offset=1} };
    [787] = { Multi=true, [1] = { Stat='Wind resistance', Offset=1, Multiplier=-1}, [2] = { Stat='Earth resistance', Offset=1} };
    [788] = { Multi=true, [1] = { Stat='Earth resistance', Offset=1, Multiplier=-1}, [2] = { Stat='Lightning resistance', Offset=1} };
    [789] = { Multi=true, [1] = { Stat='Lightning resistance', Offset=1, Multiplier=-1}, [2] = { Stat='Water resistance', Offset=1} };
    [790] = { Multi=true, [1] = { Stat='Light resistance', Offset=1}, [2] = { Stat='Dark resistance', Offset=1, Multiplier=-1} };
    [791] = { Multi=true, [1] = { Stat='Light resistance', Offset=1, Multiplier=-1}, [2] = { Stat='Dark resistance', Offset=1} };
    [792] = { Multi=true, [1] = { Stat='Fire resistance', Offset=1}, [2] = { Stat='Wind resistance', Offset=1}, [3] = { Stat='Lightning resistance', Offset=1}, [4] = { Stat='Light resistance', Offset=1} };
    [793] = { Multi=true, [1] = { Stat='Ice resistance', Offset=1}, [2] = { Stat='Earth resistance', Offset=1}, [3] = { Stat='Water resistance', Offset=1}, [4] = { Stat='Dark resistance', Offset=1} };
    [794] = { Multi=true, [1] = { Stat='Fire resistance', Offset=1}, [2] = { Stat='Ice resistance', Offset=1, Multiplier=-1}, [3] = { Stat='Wind resistance', Offset=1}, [4] = { Stat='Earth resistance', Offset=1, Multiplier=-1}, [5] = { Stat='Lightning resistance', Offset=1}, [6] = { Stat='Water resistance', Offset=1, Multiplier=-1}, [7] = { Stat='Light resistance', Offset=1}, [8] = { Stat='Dark resistance', Offset=1, Multiplier=-1} };
    [795] = { Multi=true, [1] = { Stat='Fire resistance', Offset=1, Multiplier=-1}, [2] = { Stat='Ice resistance', Offset=1}, [3] = { Stat='Wind resistance', Offset=1, Multiplier=-1}, [4] = { Stat='Earth resistance', Offset=1}, [5] = { Stat='Lightning resistance', Offset=1, Multiplier=-1}, [6] = { Stat='Water resistance', Offset=1}, [7] = { Stat='Light resistance', Offset=1, Multiplier=-1}, [8] = { Stat='Dark resistance', Offset=1} };
    [796] = { Multi=true, [1] = { Stat='Fire resistance', Offset=1}, [2] = { Stat='Ice resistance', Offset=1}, [3] = { Stat='Wind resistance', Offset=1}, [4] = { Stat='Earth resistance', Offset=1}, [5] = { Stat='Lightning resistance', Offset=1}, [6] = { Stat='Water resistance', Offset=1}, [7] = { Stat='Light resistance', Offset=1}, [8] = { Stat='Dark resistance', Offset=1} };
    [797] = { Multi=true, [1] = { Stat='Fire resistance', Offset=1, Multiplier=-1}, [2] = { Stat='Ice resistance', Offset=1, Multiplier=-1}, [3] = { Stat='Wind resistance', Offset=1, Multiplier=-1}, [4] = { Stat='Earth resistance', Offset=1, Multiplier=-1}, [5] = { Stat='Lightning resistance', Offset=1, Multiplier=-1}, [6] = { Stat='Water resistance', Offset=1, Multiplier=-1}, [7] = { Stat='Light resistance', Offset=1, Multiplier=-1}, [8] = { Stat='Dark resistance', Offset=1, Multiplier=-1} };
    [832] = { Stat='Add.eff.:Fire Dmg.', Offset=5},
    [833] = { Stat='Add.eff.:Ice Dmg.', Offset=5},
    [834] = { Stat='Add.eff.:Wind Dmg.', Offset=5},
    [835] = { Stat='Add.eff.:Earth Dmg.', Offset=5},
    [836] = { Stat='Add.eff.:Lightning Dmg.', Offset=5},
    [837] = { Stat='Add.eff.:Water Dmg.', Offset=5},
    [838] = { Stat='Add.eff.:Light Dmg.', Offset=5},
    [839] = { Stat='Add.eff.:Dark Dmg.', Offset=5},
    [840] = { Stat='Add.eff.:Disease', Offset=1},
    [841] = { Stat='Add.eff.:Paralysis', Offset=1},
    [842] = { Stat='Add.eff.:Silence', Offset=1},
    [843] = { Stat='Add.eff.:Slow', Offset=1},
    [844] = { Stat='Add.eff.:Stun', Offset=1},
    [845] = { Stat='Add.eff.:Poison', Offset=1},
    [846] = { Stat='Add.eff.:Flash', Offset=1},
    [847] = { Stat='Add.eff.:Blindness', Offset=1},
    [848] = { Stat='Add.eff.:Weakens def.', Offset=1},
    [849] = { Stat='Add.eff.:Sleep', Offset=1},
    [850] = { Stat='Add.eff.:Weakens atk.', Offset=1},
    [851] = { Stat='Add.eff.:Impairs evasion', Offset=1},
    [852] = { Stat='Add.eff.:Lowers acc.', Offset=1},
    [853] = { Stat='Add.eff.:Lowers mag.eva.', Offset=1},
    [854] = { Stat='Add.eff.:Lowers mag.atk.', Offset=1},
    [855] = { Stat='Add.eff.:Lowers mag.def.', Offset=1},
    [856] = { Stat='Add.eff.:Lowers mag.acc.', Offset=1},
    [896] = { Stat='Sword enhancement spell damage ', Offset=1},
    [897] = { Stat='Enhances "Souleater" effect ', Offset=1, Percent=true},
    [928] = { Stat='Fire Affinity '},
    [929] = { Stat='Ice Affinity '},
    [930] = { Stat='Wind Affinity '},
    [931] = { Stat='Earth Affinity '},
    [932] = { Stat='Lightning Affinity '},
    [933] = { Stat='Water Affinity '},
    [934] = { Stat='Light Affinity '},
    [935] = { Stat='Dark Affinity '},
    [936] = { Stat='Fire Affinity: Magic Accuracy'},
    [937] = { Stat='Ice Affinity: Magic Accuracy'},
    [938] = { Stat='Wind Affinity: Magic Accuracy'},
    [939] = { Stat='Earth Affinity: Magic Accuracy'},
    [940] = { Stat='Lightning Affinity: Magic Accuracy'},
    [941] = { Stat='Water Affinity: Magic Accuracy'},
    [942] = { Stat='Light Affinity: Magic Accuracy'},
    [943] = { Stat='Dark Affinity: Magic Accuracy'},
    [944] = { Stat='Fire Affinity: Magic Damage'},
    [945] = { Stat='Ice Affinity: Magic Damage'},
    [946] = { Stat='Wind Affinity: Magic Damage'},
    [947] = { Stat='Earth Affinity: Magic Damage'},
    [948] = { Stat='Lightning Affinity: Magic Damage'},
    [949] = { Stat='Water Affinity: Magic Damage'},
    [950] = { Stat='Light Affinity: Magic Damage'},
    [951] = { Stat='Dark Affinity: Magic Damage'},
    [952] = { Stat='Fire Affinity: Avatar perp. cost'},
    [953] = { Stat='Ice Affinity: Avatar perp. cost'},
    [954] = { Stat='Wind Affinity: Avatar perp. cost'},
    [955] = { Stat='Earth Affinity: Avatar perp. cost'},
    [956] = { Stat='Lightning Affinity: Avatar perp. cost'},
    [957] = { Stat='Water Affinity: Avatar perp. cost'},
    [958] = { Stat='Light Affinity: Avatar perp. cost'},
    [959] = { Stat='Dark Affinity: Avatar perp. cost'},
    [960] = { Multi=true, [1] = { Stat='Fire Affinity: Magic Accuracy'}, [2] = { Stat='Fire Affinity: Recast time', Offset=1, Multiplier=-2, Percent=true} };
    [961] = { Multi=true, [1] = { Stat='Ice Affinity: Magic Accuracy'}, [2] = { Stat='Ice Affinity: Recast time', Offset=1, Multiplier=-2, Percent=true} };
    [962] = { Multi=true, [1] = { Stat='Wind Affinity: Magic Accuracy'}, [2] = { Stat='Wind Affinity: Recast time', Offset=1, Multiplier=-2, Percent=true} };
    [963] = { Multi=true, [1] = { Stat='Earth Affinity: Magic Accuracy'}, [2] = { Stat='Earth Affinity: Recast time', Offset=1, Multiplier=-2, Percent=true} };
    [964] = { Multi=true, [1] = { Stat='Lightning Affinity: Magic Accuracy'}, [2] = { Stat='Lightning Affinity: Recast time', Offset=1, Multiplier=-2, Percent=true} };
    [965] = { Multi=true, [1] = { Stat='Water Affinity: Magic Accuracy'}, [2] = { Stat='Water Affinity: Recast time', Offset=1, Multiplier=-2, Percent=true} };
    [966] = { Multi=true, [1] = { Stat='Light Affinity: Magic Accuracy'}, [2] = { Stat='Light Affinity: Recast time', Offset=1, Multiplier=-2, Percent=true} };
    [967] = { Multi=true, [1] = { Stat='Dark Affinity: Magic Accuracy'}, [2] = { Stat='Dark Affinity: Recast time', Offset=1, Multiplier=-2, Percent=true} };
    [968] = { Multi=true, [1] = { Stat='Fire Affinity: Magic Damage'}, [2] = { Stat='Fire Affinity: Casting time', Offset=1, Multiplier=-2, Percent=true} };
    [969] = { Multi=true, [1] = { Stat='Ice Affinity: Magic Damage'}, [2] = { Stat='Ice Affinity: Casting time', Offset=1, Multiplier=-2, Percent=true} };
    [970] = { Multi=true, [1] = { Stat='Wind Affinity: Magic Damage'}, [2] = { Stat='Wind Affinity: Casting time', Offset=1, Multiplier=-2, Percent=true} };
    [971] = { Multi=true, [1] = { Stat='Earth Affinity: Magic Damage'}, [2] = { Stat='Earth Affinity: Casting time', Offset=1, Multiplier=-2, Percent=true} };
    [972] = { Multi=true, [1] = { Stat='Lightning Affinity: Magic Damage'}, [2] = { Stat='Lightning Affinity: Casting time', Offset=1, Multiplier=-2, Percent=true} };
    [973] = { Multi=true, [1] = { Stat='Water Affinity: Magic Damage'}, [2] = { Stat='Water Affinity: Casting time', Offset=1, Multiplier=-2, Percent=true} };
    [974] = { Multi=true, [1] = { Stat='Light Affinity: Magic Damage'}, [2] = { Stat='Light Affinity: Casting time', Offset=1, Multiplier=-2, Percent=true} };
    [975] = { Multi=true, [1] = { Stat='Dark Affinity: Magic Damage'}, [2] = { Stat='Dark Affinity: Casting time', Offset=1, Multiplier=-2, Percent=true} };
    [976] = { Stat='Fire Affin.: "Blood Pact" delay ', Offset=1},
    [977] = { Stat='Ice Affin.: "Blood Pact" delay ', Offset=1},
    [978] = { Stat='Wind Affin.: "Blood Pact" delay ', Offset=1},
    [979] = { Stat='Earth Affin.: "Blood Pact" delay ', Offset=1},
    [980] = { Stat='Lightning Affin.: "Blood Pact" delay ', Offset=1},
    [981] = { Stat='Water Affin.: "Blood Pact" delay ', Offset=1},
    [982] = { Stat='Light Affin.: "Blood Pact" delay ', Offset=1},
    [983] = { Stat='Dark Affin.: "Blood Pact" delay ', Offset=1},
    [984] = { Stat='Fire Affinity: Recast time', Offset=1, Multiplier=-2, Percent=true},
    [985] = { Stat='Ice Affinity: Recast time', Offset=1, Multiplier=-2, Percent=true},
    [986] = { Stat='Wind Affinity: Recast time', Offset=1, Multiplier=-2, Percent=true},
    [987] = { Stat='Earth Affinity: Recast time', Offset=1, Multiplier=-2, Percent=true},
    [988] = { Stat='Lightning Affinity: Recast time', Offset=1, Multiplier=-2, Percent=true},
    [989] = { Stat='Water Affinity: Recast time', Offset=1, Multiplier=-2, Percent=true},
    [990] = { Stat='Light Affinity: Recast time', Offset=1, Multiplier=-2, Percent=true},
    [991] = { Stat='Dark Affinity: Recast time', Offset=1, Multiplier=-2, Percent=true},
    [992] = { Stat='Fire Affinity: Casting time', Offset=1, Multiplier=-2, Percent=true},
    [993] = { Stat='Ice Affinity: Casting time', Offset=1, Multiplier=-2, Percent=true},
    [994] = { Stat='Wind Affinity: Casting time', Offset=1, Multiplier=-2, Percent=true},
    [995] = { Stat='Earth Affinity: Casting time', Offset=1, Multiplier=-2, Percent=true},
    [996] = { Stat='Lightning Affinity: Casting time', Offset=1, Multiplier=-2, Percent=true},
    [997] = { Stat='Water Affinity: Casting time', Offset=1, Multiplier=-2, Percent=true},
    [998] = { Stat='Light Affinity: Casting time', Offset=1, Multiplier=-2, Percent=true},
    [999] = { Stat='Dark Affinity: Casting time', Offset=1, Multiplier=-2, Percent=true},
    [1000] = { Multi=true, [1] = { Stat='Fire Affinity: Magic Accuracy'}, [2] = { Stat='Fire Affinity: Casting time', Offset=1, Multiplier=-6, Percent=true} };
    [1001] = { Multi=true, [1] = { Stat='Ice Affinity: Magic Accuracy'}, [2] = { Stat='Ice Affinity: Casting time', Offset=1, Multiplier=-6, Percent=true} };
    [1002] = { Multi=true, [1] = { Stat='Wind Affinity: Magic Accuracy'}, [2] = { Stat='Wind Affinity: Casting time', Offset=1, Multiplier=-6, Percent=true} };
    [1003] = { Multi=true, [1] = { Stat='Earth Affinity: Magic Accuracy'}, [2] = { Stat='Earth Affinity: Casting time', Offset=1, Multiplier=-6, Percent=true} };
    [1004] = { Multi=true, [1] = { Stat='Lightning Affinity: Magic Accuracy'}, [2] = { Stat='Lightning Affinity: Casting time', Offset=1, Multiplier=-6, Percent=true} };
    [1005] = { Multi=true, [1] = { Stat='Water Affinity: Magic Accuracy'}, [2] = { Stat='Water Affinity: Casting time', Offset=1, Multiplier=-6, Percent=true} };
    [1006] = { Multi=true, [1] = { Stat='Light Affinity: Magic Accuracy'}, [2] = { Stat='Light Affinity: Casting time', Offset=1, Multiplier=-6, Percent=true} };
    [1007] = { Multi=true, [1] = { Stat='Dark Affinity: Magic Accuracy'}, [2] = { Stat='Dark Affinity: Casting time', Offset=1, Multiplier=-6, Percent=true} };
    [1008] = { Multi=true, [1] = { Stat='Fire Affinity: Magic Damage'}, [2] = { Stat='Fire Affinity: Recast time', Offset=1, Multiplier=-6, Percent=true} };
    [1009] = { Multi=true, [1] = { Stat='Ice Affinity: Magic Damage'}, [2] = { Stat='Ice Affinity: Recast time', Offset=1, Multiplier=-6, Percent=true} };
    [1010] = { Multi=true, [1] = { Stat='Wind Affinity: Magic Damage'}, [2] = { Stat='Wind Affinity: Recast time', Offset=1, Multiplier=-6, Percent=true} };
    [1011] = { Multi=true, [1] = { Stat='Earth Affinity: Magic Damage'}, [2] = { Stat='Earth Affinity: Recast time', Offset=1, Multiplier=-6, Percent=true} };
    [1012] = { Multi=true, [1] = { Stat='Lightning Affinity: Magic Damage'}, [2] = { Stat='Lightning Affinity: Recast time', Offset=1, Multiplier=-6, Percent=true} };
    [1013] = { Multi=true, [1] = { Stat='Water Affinity: Magic Damage'}, [2] = { Stat='Water Affinity: Recast time', Offset=1, Multiplier=-6, Percent=true} };
    [1014] = { Multi=true, [1] = { Stat='Light Affinity: Magic Damage'}, [2] = { Stat='Light Affinity: Recast time', Offset=1, Multiplier=-6, Percent=true} };
    [1015] = { Multi=true, [1] = { Stat='Dark Affinity: Magic Damage'}, [2] = { Stat='Dark Affinity: Recast time', Offset=1, Multiplier=-6, Percent=true} };
    [1024] = { Stat='Backhand Blow:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1025] = { Stat='Spinning Attack:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1026] = { Stat='Howling Fist:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1027] = { Stat='Dragon Kick:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1028] = { Stat='Viper Bite:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1029] = { Stat='Shadowstitch:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1030] = { Stat='Cyclone:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1031] = { Stat='Evisceration:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1032] = { Stat='Burning Blade:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1033] = { Stat='Shining Blade:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1034] = { Stat='Circle Blade:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1035] = { Stat='Savage Blade:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1036] = { Stat='Freezebite:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1037] = { Stat='Shockwave:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1038] = { Stat='Ground Strike:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1039] = { Stat='Sickle Moon:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1040] = { Stat='Gale Axe:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1041] = { Stat='Spinning Axe:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1042] = { Stat='Calamity:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1043] = { Stat='Decimation:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1044] = { Stat='Iron Tempest:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1045] = { Stat='Sturmwind:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1046] = { Stat='Keen Edge:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1047] = { Stat='Steel Cyclone:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1048] = { Stat='Nightmare Scythe:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1049] = { Stat='Spinning Scythe:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1050] = { Stat='Vorpal Scythe:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1051] = { Stat='Spiral Hell:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1052] = { Stat='Leg Sweep:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1053] = { Stat='Skewer:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1054] = { Stat='Vorpal Thrust:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1055] = { Stat='Impulse Drive:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1056] = { Stat='Blade: To:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1057] = { Stat='Blade: Chi:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1058] = { Stat='Blade: Ten:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1059] = { Stat='Blade: Ku:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1060] = { Stat='Tachi: Goten:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1061] = { Stat='Tachi: Jinpu:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1062] = { Stat='Tachi: Koki:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1063] = { Stat='Tachi: Kasha:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1064] = { Stat='Brainshaker:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1065] = { Stat='Skullbreaker:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1066] = { Stat='Judgment:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1067] = { Stat='Black Halo:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1068] = { Stat='Rock Crusher:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1069] = { Stat='Shell Crusher:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1070] = { Stat='Full Swing:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1071] = { Stat='Retribution:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1072] = { Stat='Dulling Arrow:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1073] = { Stat='Blast Arrow:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1074] = { Stat='Arching Arrow:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1075] = { Stat='Empyreal Arrow:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1076] = { Stat='Hot Shot:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1077] = { Stat='Split Shot:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1078] = { Stat='Sniper Shot:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1079] = { Stat='Detonator:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1080] = { Stat='Weapon Skill:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1152] = { Stat='DEF', Offset=1, Multiplier=10},
    [1153] = { Stat='Evasion', Offset=1, Multiplier=3},
    [1154] = { Stat='Mag. Evasion', Offset=1, Multiplier=3},
    [1155] = { Stat='Phys. dmg. taken ', Offset=1, Multiplier=-2, Percent=true},
    [1156] = { Stat='Magic dmg. taken ', Offset=1, Multiplier=-2, Percent=true},
    [1157] = { Stat='Spell interruption rate down', Offset=1, Multiplier=-2, Percent=true},
    [1158] = { Stat='Occ. inc. resist. to stat. ailments', Offset=1, Multiplier=2},
    [1248] = { Stat='Enh. Mag. eff. dur. ', Offset=1},
    [1249] = { Stat='Helix eff. dur. ', Offset=1},
    [1250] = { Stat='Indi. eff. dur. ', Offset=1},
    [1264] = { Stat='Meditate eff. dur. ', Offset=1},
    [1280] = { Stat='Enhances "Mighty Strikes" effect', Multiplier=0},
    [1281] = { Stat='Enhances "Hundred Fists" effect', Multiplier=0},
    [1282] = { Stat='Enhances "Benediction" effect', Multiplier=0},
    [1283] = { Stat='Enhances "Manafont" effect', Multiplier=0},
    [1284] = { Stat='Enhances "Chainspell" effect', Multiplier=0},
    [1285] = { Stat='Enhances "Perfect Dodge" effect', Multiplier=0},
    [1286] = { Stat='Enhances "Invincible" effect', Multiplier=0},
    [1287] = { Stat='Enhances "Blood Weapon" effect', Multiplier=0},
    [1288] = { Stat='Enhances "Familiar" effect', Multiplier=0},
    [1289] = { Stat='Enhances "Soul Voice" effect', Multiplier=0},
    [1290] = { Stat='Enhances "Eagle Eye Shot" effect', Multiplier=0},
    [1291] = { Stat='Enhances "Meikyo Shisui" effect', Multiplier=0},
    [1292] = { Stat='Enhances "Mijin Gakure" effect', Multiplier=0},
    [1293] = { Stat='Enhances "Spirit Surge" effect', Multiplier=0},
    [1294] = { Stat='Enhances "Astral Flow" effect', Multiplier=0},
    [1295] = { Stat='Enhances "Azure Lore" effect', Multiplier=0},
    [1296] = { Stat='Enhances "Wild Card" effect', Multiplier=0},
    [1297] = { Stat='Enhances "Overdrive" effect', Multiplier=0},
    [1298] = { Stat='Enhances "Trance" effect', Multiplier=0},
    [1299] = { Stat='Enhances "Tabula Rasa" effect', Multiplier=0},
    [1300] = { Stat='Enhances "Bolster" effect', Multiplier=0},
    [1301] = { Stat='Enhances "Elemental Sforzo" effect', Multiplier=0},
    [1328] = { Stat='Enhances "Savagery" effect', Multiplier=0},
    [1329] = { Stat='Enhances "Aggressive Aim" effect', Multiplier=0},
    [1330] = { Stat='Enhances "Warrior\"s Charge" effect', Multiplier=0},
    [1331] = { Stat='Enhances "Tomahawk" effect', Multiplier=0},
    [1334] = { Stat='Enhances "Penance" effect', Multiplier=0},
    [1335] = { Stat='Enhances "Formless Strikes" effect', Multiplier=0},
    [1336] = { Stat='Enhances "Invigorate" effect', Multiplier=0},
    [1337] = { Stat='Enhances "Mantra" effect', Multiplier=0},
    [1340] = { Stat='Enhances "Afflatus Solace" effect', Multiplier=0},
    [1341] = { Stat='Enhances "Martyr" effect', Multiplier=0},
    [1342] = { Stat='Enhances "Afflatus Misery" effect', Multiplier=0},
    [1343] = { Stat='Enhances "Devotion" effect', Multiplier=0},
    [1346] = { Stat='Increases Ancient Magic damage and magic burst damage', Multiplier=0},
    [1347] = { Stat='Increases Elemental Magic accuracy', Multiplier=0},
    [1348] = { Stat='Increases Elemental Magic debuff time and potency', Multiplier=0},
    [1349] = { Stat='Increases Aspir absorption amount', Multiplier=0},
    [1352] = { Stat='Enfeebling Magic duration', Multiplier=0},
    [1353] = { Stat='Magic Accuracy', Multiplier=0},
    [1354] = { Stat='Enhancing Magic duration', Multiplier=0},
    [1355] = { Stat='Enspell Damage', Multiplier=0},
    [1356] = { Stat='Accuracy', Multiplier=0},
    [1357] = { Stat='Immunobreak Chance', Multiplier=0},
    [1358] = { Stat='Enhances "Aura Steal" effect', Multiplier=0},
    [1359] = { Stat='Enhances "Ambush" effect', Multiplier=0},
    [1360] = { Stat='Enhances "Feint" effect', Multiplier=0},
    [1361] = { Stat='Enhances "Assassin\"s Charge" effect', Multiplier=0},
    [1364] = { Stat='Enhances "Iron Will" effect', Multiplier=0},
    [1365] = { Stat='Enhances "Fealty" effect', Multiplier=0},
    [1366] = { Stat='Enhances "Chivalry" effect', Multiplier=0},
    [1367] = { Stat='Enhances "Guardian" effect', Multiplier=0},
    [1370] = { Stat='Enhances "Dark Seal" effect', Multiplier=0},
    [1371] = { Stat='Enhances "Diabolic Eye" effect', Multiplier=0},
    [1372] = { Stat='Enhances "Muted Soul" effect', Multiplier=0},
    [1373] = { Stat='Enhances "Desperate Blows" effect', Multiplier=0},
    [1376] = { Stat='Enhances "Killer Instinct" effect', Multiplier=0},
    [1377] = { Stat='Enhances "Feral Howl" effect', Multiplier=0},
    [1378] = { Stat='Enhances "Beast Affinity" effect', Multiplier=0},
    [1379] = { Stat='Enhances "Beast Healer" effect', Multiplier=0},
    [1382] = { Stat='Enhances "Con Anima" effect', Multiplier=0},
    [1383] = { Stat='Enhances "Troubadour" effect', Multiplier=0},
    [1384] = { Stat='Enhances "Con Brio" effect', Multiplier=0},
    [1385] = { Stat='Enhances "Nightingale" effect', Multiplier=0},
    [1388] = { Stat='Enhances "Recycle" effect', Multiplier=0},
    [1389] = { Stat='Enhances "Snapshot" effect', Multiplier=0},
    [1390] = { Stat='Enhances "Flashy Shot" effect', Multiplier=0},
    [1391] = { Stat='Enhances "Stealth Shot" effect', Multiplier=0},
    [1394] = { Stat='Enhances "Shikikoyo" effect', Multiplier=0},
    [1395] = { Stat='Enhances "Overwhelm" effect', Multiplier=0},
    [1396] = { Stat='Enhances "Blade Bash" effect', Multiplier=0},
    [1397] = { Stat='Enhances "Ikishoten" effect', Multiplier=0},
    [1400] = { Stat='Enhances "Yonin" and "Innin" effect', Multiplier=0},
    [1401] = { Stat='Enhances "Sange" effect', Multiplier=0},
    [1402] = { Stat='Enh. "Ninja Tool Expertise" effect', Multiplier=0},
    [1403] = { Stat='Enh. Ninj. Mag. Acc/Cast Time Red.', Multiplier=0},
    [1406] = { Stat='Enhances "Deep Breathing" effect', Multiplier=0},
    [1407] = { Stat='Enhances "Angon" effect', Multiplier=0},
    [1408] = { Stat='Enhances "Strafe" effect', Multiplier=0},
    [1409] = { Stat='Enhances "Empathy" effect', Multiplier=0},
    [1412] = { Stat='Reduces Sp. "Blood Pact" MP cost', Multiplier=0},
    [1413] = { Stat='Inc. Sp. "Blood Pact" magic burst dmg.', Multiplier=0},
    [1414] = { Stat='Increases Sp. "Blood Pact" accuracy', Multiplier=0},
    [1415] = { Stat='Inc. Sp. "Blood Pact" magic crit. dmg.', Multiplier=0},
    [1418] = { Stat='Enhances "Convergence" effect', Multiplier=0},
    [1419] = { Stat='Enhances "Enchainment" effect', Multiplier=0},
    [1420] = { Stat='Enhances "Assimilation" effect', Multiplier=0},
    [1421] = { Stat='Enhances "Diffusion" effect', Multiplier=0},
    [1424] = { Stat='Enhances "Winning Streak" effect', Multiplier=0},
    [1425] = { Stat='Enhances "Loaded Deck" effect', Multiplier=0},
    [1426] = { Stat='Enhances "Fold" effect', Multiplier=0},
    [1427] = { Stat='Enhances "Snake Eye" effect', Multiplier=0},
    [1430] = { Stat='Enhances "Optimization" effect', Multiplier=0},
    [1431] = { Stat='Enhances "Fine-Tuning" effect', Multiplier=0},
    [1432] = { Stat='Enhances "Ventriloquy" effect', Multiplier=0},
    [1433] = { Stat='Enhances "Role Reversal" effect', Multiplier=0},
    [1436] = { Stat='Enhances "No Foot Rise" effect', Multiplier=0},
    [1437] = { Stat='Enhances "Fan Dance" effect', Multiplier=0},
    [1438] = { Stat='Enhances "Saber Dance" effect', Multiplier=0},
    [1439] = { Stat='Enhances "Closed Position" effect', Multiplier=0},
    [1442] = { Stat='Enh. "Altruism" and "Focalization"', Multiplier=0},
    [1443] = { Stat='Enhances "Enlightenment" effect', Multiplier=0},
    [1444] = { Stat='Enh. "Tranquility" and "Equanimity"', Multiplier=0},
    [1445] = { Stat='Enhances "Stormsurge" effect', Multiplier=0},
    [1448] = { Stat='Enhances "Mending Halation" effect', Multiplier=0},
    [1449] = { Stat='Enhances "Radial Arcana" effect', Multiplier=0},
    [1450] = { Stat='Enhances "Curative Recantation" effect', Multiplier=0},
    [1451] = { Stat='Enhances "Primeval Zeal" effect', Multiplier=0},
    [1454] = { Stat='Enhances "Battuta" effect', Multiplier=0},
    [1455] = { Stat='Enhances "Rayke" effect', Multiplier=0},
    [1456] = { Stat='Enhances "Inspire" effect', Multiplier=0},
    [1457] = { Stat='Enhances "Sleight of Sword" effect', Multiplier=0},
    [1472] = { Stat='Parrying rate', Offset=1, Percent=true},
    [1536] = { Stat='Backhand Blow:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1537] = { Stat='Spinning Attack:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1538] = { Stat='Howling Fist:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1539] = { Stat='Dragon Kick:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1540] = { Stat='Viper Bite:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1541] = { Stat='Shadowstitch:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1542] = { Stat='Cyclone:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1543] = { Stat='Evisceration:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1544] = { Stat='Burning Blade:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1545] = { Stat='Shining Blade:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1546] = { Stat='Circle Blade:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1547] = { Stat='Savage Blade:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1548] = { Stat='Freezebite:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1549] = { Stat='Shockwave:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1550] = { Stat='Ground Strike:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1551] = { Stat='Sickle Moon:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1552] = { Stat='Gale Axe:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1553] = { Stat='Spinning Axe:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1554] = { Stat='Calamity:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1555] = { Stat='Decimation:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1556] = { Stat='Iron Tempest:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1557] = { Stat='Sturmwind:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1558] = { Stat='Keen Edge:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1559] = { Stat='Steel Cyclone:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1560] = { Stat='Nightmare Scythe:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1561] = { Stat='Spinning Scythe:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1562] = { Stat='Vorpal Scythe:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1563] = { Stat='Spiral Hell:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1564] = { Stat='Leg Sweep:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1565] = { Stat='Skewer:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1566] = { Stat='Vorpal Thrust:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1567] = { Stat='Impulse Drive:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1568] = { Stat='Blade: To:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1569] = { Stat='Blade: Chi:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1570] = { Stat='Blade: Ten:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1571] = { Stat='Blade: Ku:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1572] = { Stat='Tachi: Goten:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1573] = { Stat='Tachi: Jinpu:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1574] = { Stat='Tachi: Koki:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1575] = { Stat='Tachi: Kasha:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1576] = { Stat='Brainshaker:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1577] = { Stat='Skullbreaker:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1578] = { Stat='Judgment:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1579] = { Stat='Black Halo:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1580] = { Stat='Rock Crusher:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1581] = { Stat='Shell Crusher:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1582] = { Stat='Full Swing:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1583] = { Stat='Retribution:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1584] = { Stat='Dulling Arrow:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1585] = { Stat='Blast Arrow:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1586] = { Stat='Arching Arrow:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1587] = { Stat='Empyreal Arrow:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1588] = { Stat='Hot Shot:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1589] = { Stat='Split Shot:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1590] = { Stat='Sniper Shot:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1591] = { Stat='Detonator:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1592] = { Stat='Weapon Skill:DMG:', Offset=1, Multiplier=5, Percent=true},
    [1792] = { Stat='Pet: STR', Offset=1},
    [1793] = { Stat='Pet: DEX', Offset=1},
    [1794] = { Stat='Pet: VIT', Offset=1},
    [1795] = { Stat='Pet: AGI', Offset=1},
    [1796] = { Stat='Pet: INT', Offset=1},
    [1797] = { Stat='Pet: MND', Offset=1},
    [1798] = { Stat='Pet: CHR', Offset=1},
    [1799] = { Stat='Pet: STR', Offset=1, Multiplier=-1},
    [1800] = { Stat='Pet: DEX', Offset=1, Multiplier=-1},
    [1801] = { Stat='Pet: VIT', Offset=1, Multiplier=-1},
    [1802] = { Stat='Pet: AGI', Offset=1, Multiplier=-1},
    [1803] = { Stat='Pet: INT', Offset=1, Multiplier=-1},
    [1804] = { Stat='Pet: MND', Offset=1, Multiplier=-1},
    [1805] = { Stat='Pet: CHR', Offset=1, Multiplier=-1},
    [1806] = { Multi=true, [1] = { Stat='Pet: STR', Offset=1}, [2] = { Stat='Pet: DEX', Offset=1}, [3] = { Stat='Pet: VIT', Offset=1} };
    [1807] = { Stat='Pet:', Multiplier=0},
    [1808] = { Stat='Pet:', Multiplier=0},
    [1809] = { Stat='Pet:', Multiplier=0},
    [1810] = { Stat='Pet:', Multiplier=0},
    [1811] = { Stat='Pet:', Multiplier=0},
    [1812] = { Stat='Pet:', Multiplier=0},
    [1813] = { Stat='Pet:', Multiplier=0},
    [1814] = { Stat='Pet:', Multiplier=0},
    [1815] = { Stat='Pet:', Multiplier=0},
    [1816] = { Stat='Pet:', Multiplier=0},
    [1817] = { Stat='Pet:', Multiplier=0},
    [1818] = { Stat='Pet:', Multiplier=0},
    [1819] = { Stat='Pet:', Multiplier=0},
    [1820] = { Stat='Pet:', Multiplier=0},
    [1821] = { Stat='Pet:', Multiplier=0},
    [1822] = { Stat='Pet:', Multiplier=0},
    [1823] = { Stat='Pet:', Multiplier=0},
    [2047] = { Stat='???'},
};
A.DelveAugments = {
    [1] = { Stat='----------------'},
    [2] = { Stat='HP', Offset=1},
    [3] = { Stat='HP', Offset=256},
    [4] = { Stat='MP', Offset=1},
    [5] = { Stat='MP', Offset=256},
    [8] = { Stat='Attack', Offset=1},
    [9] = { Stat='Attack', Offset=256},
    [10] = { Stat='Rng.Atk.', Offset=1},
    [11] = { Stat='Rng.Atk.', Offset=256},
    [12] = { Stat='Accuracy', Offset=1},
    [13] = { Stat='Accuracy', Offset=256},
    [14] = { Stat='Rng.Acc.', Offset=1},
    [15] = { Stat='Rng.Acc.', Offset=256},
    [16] = { Stat='DEF', Offset=1},
    [17] = { Stat='DEF', Offset=256},
    [18] = { Stat='Evasion', Offset=1},
    [19] = { Stat='Evasion', Offset=256},
    [20] = { Stat='"Mag. Atk. Bns."', Offset=1},
    [21] = { Stat='"Mag. Atk. Bns."', Offset=256},
    [22] = { Stat='"Mag.Def.Bns."', Offset=1},
    [23] = { Stat='"Mag.Def.Bns."', Offset=256},
    [24] = { Stat='Mag. Acc.', Offset=1},
    [25] = { Stat='Mag. Acc.', Offset=256},
    [26] = { Stat='Mag. Evasion', Offset=1},
    [27] = { Stat='Mag. Evasion', Offset=256},
    [28] = { Stat='DMG:', Offset=1},
    [29] = { Stat='DMG:', Offset=256},
    [114] = { Stat='Weapon skill damage ', Offset=1, Percent=true},
    [115] = { Stat='Magic damage', Offset=1},
    [116] = { Stat='Blood Pact Dmg.', Offset=1 },
    [117] = { Stat='"Avatar perpetuation cost"', Offset=1},
    [118] = { Stat='"Blood Pact" ability delay', Offset=1},
    [119] = { Stat='Haste', Offset=1, Percent=true},
    [120] = { Stat='Enmity', Offset=1},
    [121] = { Stat='Enmity', Offset=1, Multiplier=-1},
    [122] = { Stat='Crit. hit rate', Offset=1, Percent=true},
    [123] = { Stat='"Cure" spellcasting time ', Offset=1, Multiplier=-1, Percent=true},
    [124] = { Stat='"Cure" potency ', Offset=1, Percent=true},
    [125] = { Stat='"Refresh"', Offset=1},
    [126] = { Stat='Spell interruption rate down ', Offset=1, Percent=true},
    [127] = { Stat='Potency of "Cure" effect received ', Offset=1, Percent=true},
    [128] = { Stat='Pet: "Mag. Atk. Bns."', Offset=1},
    [129] = { Stat='Pet: Mag. Acc.', Offset=1},
    [130] = { Stat='Pet: Attack', Offset=1},
    [131] = { Stat='Pet: Accuracy', Offset=1},
    [132] = { Stat='Pet: Enmity', Offset=1},
    [133] = { Stat='Pet: Enmity', Offset=1},
    [134] = { Stat='Pet: HP', Offset=1},
    [135] = { Stat='Pet: MP', Offset=1},
    [136] = { Stat='Pet: STR', Offset=1},
    [137] = { Stat='Pet: DEX', Offset=1},
    [138] = { Stat='Pet: VIT', Offset=1},
    [139] = { Stat='Pet: AGI', Offset=1},
    [140] = { Stat='Pet: INT', Offset=1},
    [141] = { Stat='Pet: MND', Offset=1},
    [142] = { Stat='Pet: CHR', Offset=1},
    [152] = { Stat='Pet: "Dbl. Atk."', Offset=1},
    [153] = { Stat='Pet: Damage taken ', Offset=1, Multiplier=-1, Percent=true},
    [154] = { Stat='Pet: "Regen"', Offset=1},
    [155] = { Stat='Pet: Haste', Offset=1, Percent=true},
    [156] = { Stat='Automaton: "Cure" potency ', Offset=1, Percent=true},
    [157] = { Stat='Automaton: "Fast Cast"', Offset=1},
    [171] = { Stat='"Dual Wield"', Offset=1},
    [172] = { Stat='Damage Taken ', Offset=1, Multiplier=-1, Percent=true},
    [173] = { Stat='All songs ', Offset=1},
    [177] = { Stat='"Conserve MP"', Offset=1},
    [178] = { Stat='"Counter"', Offset=1},
    [179] = { Stat='"Triple Atk."', Offset=1},
    [180] = { Stat='"Fast Cast"', Offset=1},
    [181] = { Stat='"Blood Boon"', Offset=1},
    [182] = { Stat='"Subtle Blow"', Offset=1},
    [183] = { Stat='"Rapid Shot"', Offset=1},
    [184] = { Stat='"Recycle"', Offset=1},
    [185] = { Stat='"Store TP"', Offset=1},
    [186] = { Stat='"Dbl.Atk."', Offset=1},
    [187] = { Stat='"Snapshot"', Offset=1},
    [188] = { Stat='Phys. dmg. taken ', Offset=1, Multiplier=-1},
    [189] = { Stat='Magic dmg. taken ', Offset=1, Multiplier=-1},
    [190] = { Stat='Breath dmg. taken ', Offset=1, Multiplier=-1},
    [191] = { Stat='STR', Offset=1},
    [192] = { Stat='DEX', Offset=1},
    [193] = { Stat='VIT', Offset=1},
    [194] = { Stat='AGI', Offset=1},
    [195] = { Stat='INT', Offset=1},
    [196] = { Stat='MND', Offset=1},
    [197] = { Stat='CHR', Offset=1},
    [198] = { Stat='none'},
    [199] = { Stat='none'},
    [200] = { Stat='none'},
    [201] = { Stat='none'},
    [202] = { Stat='none'},
    [203] = { Stat='none'},
    [204] = { Stat='none'},
    [205] = { Stat='none'},
    [206] = { Multi=true, [1] = { Stat='STR', Offset=1}, [2] = { Stat='DEX', Offset=1}, [3] = { Stat='VIT', Offset=1}, [4] = { Stat='AGI', Offset=1}, [5] = { Stat='INT', Offset=1}, [6] = { Stat='MND', Offset=1}, [7] = { Stat='CHR', Offset=1} };
    [207] = { Stat='none'},
    [208] = { Stat='Hand-to-Hand skill ', Offset=1},
    [209] = { Stat='Dagger skill ', Offset=1},
    [210] = { Stat='Sword skill ', Offset=1},
    [211] = { Stat='Great Sword skill ', Offset=1},
    [212] = { Stat='Axe skill ', Offset=1},
    [213] = { Stat='Great Axe skill ', Offset=1},
    [214] = { Stat='Scythe skill ', Offset=1},
    [215] = { Stat='Polearm skill ', Offset=1},
    [216] = { Stat='Katana skill ', Offset=1},
    [217] = { Stat='Great Katana skill ', Offset=1},
    [218] = { Stat='Club skill ', Offset=1},
    [219] = { Stat='Staff skill ', Offset=1},
    [220] = { Stat='269'},
    [221] = { Stat='270'},
    [222] = { Stat='271'},
    [223] = { Stat='272'},
    [224] = { Stat='273'},
    [225] = { Stat='274'},
    [226] = { Stat='275'},
    [227] = { Stat='276'},
    [228] = { Stat='277'},
    [229] = { Stat='Melee skill ', Offset=1},
    [230] = { Stat='Ranged skill ', Offset=1},
    [231] = { Stat='Magic skill ', Offset=1},
    [232] = { Stat='Archery skill ', Offset=1},
    [233] = { Stat='Marksmanship skill ', Offset=1},
    [234] = { Stat='Throwing skill ', Offset=1},
    [235] = { Stat='284'},
    [236] = { Stat='285'},
    [237] = { Stat='Shield skill ', Offset=1},
    [238] = { Stat='287'},
    [239] = { Stat='Divine magic skill ', Offset=1},
    [240] = { Stat='Healing magic skill ', Offset=1},
    [241] = { Stat='Enha.mag. skill ', Offset=1},
    [242] = { Stat='Enfb.mag. skill ', Offset=1},
    [243] = { Stat='Elem. magic skill ', Offset=1},
    [244] = { Stat='Dark magic skill ', Offset=1},
    [245] = { Stat='Summoning magic skill ', Offset=1},
    [246] = { Stat='Ninjutsu skill ', Offset=1},
    [247] = { Stat='Singing skill ', Offset=1},
    [248] = { Stat='String instrument skill ', Offset=1},
    [249] = { Stat='Wind instrument skill ', Offset=1},
    [250] = { Stat='Blue Magic skill ', Offset=1},
    [251] = { Stat='Geomancy Skill ', Offset=1},
    [252] = { Stat='Handbell Skill', Offset=1},
    [253] = { Stat='302'},
    [254] = { Stat='303'},
};


----------------------------------------------------------------------------------------------------
-- Decoding (LuAshitacast's GetAugment)
----------------------------------------------------------------------------------------------------
local function single(value, r)
    if r.Offset ~= nil then value = value + r.Offset; end
    if r.Multiplier ~= nil then value = value * r.Multiplier; end
    return { Stat = r.Stat, Value = value, Percent = r.Percent == true };
end

local function resource(id, value, tbl)
    local r = tbl[id];
    if r == nil then return nil; end
    local out = {};
    if r.Multi == true then for _, s in ipairs(r) do out[#out + 1] = single(value, s); end
    else out[1] = single(value, r); end
    return out;
end

local function to_list(augs)
    local list = {};
    for _, v in pairs(augs) do
        local s = tostring(v.Stat or ''):gsub('%s+$', '');
        if s ~= '' and s ~= '???' and not s:match('^%-+$') and not s:match('^%d+$') then
            if v.Value > 0 then s = s .. '+' .. v.Value;
            elseif v.Value < 0 then s = s .. v.Value; end
            if v.Percent then s = s .. '%'; end
            list[#list + 1] = s;
        end
    end
    table.sort(list);
    return list;
end

local function decode(extra)
    if type(extra) ~= 'string' or #extra < 2 then return nil; end
    local t = struct.unpack('B', extra, 1);
    if t ~= 2 and t ~= 3 then return nil; end
    local flag = struct.unpack('B', extra, 2);
    local bytes = extra:totable();
    local function bits(off, n) return ashita.bits.unpack_be(bytes, off, n); end

    if bit.band(flag, 0x20) ~= 0 then                                  -- Delve
        local augs = {};
        for i = 0, 3 do
            local r = resource(bits(16 * i + 48, 8), bits(16 * i + 56, 8), A.DelveAugments);
            for _, s in ipairs(r or {}) do
                if augs[s.Stat] == nil then augs[s.Stat] = s; else augs[s.Stat].Value = augs[s.Stat].Value + s.Value; end
            end
        end
        return { type = 'Delve', path = A.AugmentPaths[bits(16, 2) + 1], rank = bits(18, 4), list = to_list(augs) };
    end
    if flag == 131 then                                                -- Dynamis
        return { type = 'Dynamis', path = A.AugmentPaths[bits(32, 2) + 1], rank = bits(50, 5), list = {} };
    end
    if bit.band(flag, 0x08) ~= 0 or bit.band(flag, 0x80) ~= 0 then return nil; end   -- (shields, Evolith)
    local res = { type = 'Oseem', list = {} };
    local max = 5;
    if bit.band(flag, 0x40) ~= 0 then                                  -- Magian
        res.type = 'Magian';
        res.trial = bits(80, 15);
        max = 4;
    end
    local augs = {};
    for i = 1, max do
        local r = resource(bits(16 * i, 11), bits(16 * i + 11, 5), A.BasicAugments);
        for _, s in ipairs(r or {}) do
            if augs[s.Stat] == nil then augs[s.Stat] = s; else augs[s.Stat].Value = augs[s.Stat].Value + s.Value; end
        end
    end
    res.list = to_list(augs);
    if #res.list == 0 and res.trial == nil then return nil; end
    return res;
end

local cache = {};
-- An inventory item (from GetContainerItem): its augments, or nil
function augments.of(item)
    if item == nil or item.Extra == nil then return nil; end
    local ok, extra = pcall(function() return item.Extra; end);
    if not ok or type(extra) ~= 'string' then return nil; end
    local c = cache[extra];
    if c == nil then
        local ok2, r = pcall(decode, extra);
        c = (ok2 and r) or false;
        cache[extra] = c;
    end
    return c or nil;
end

-- A short key for a set of augments ('' for none)
function augments.sig(a)
    if a == nil then return ''; end
    local s = table.concat(a.list or {}, ', ');
    if a.path then s = 'Path ' .. a.path .. (s ~= '' and (', ' .. s) or ''); end
    if a.rank and a.rank > 0 then s = s .. (s ~= '' and ', ' or '') .. 'Rank ' .. a.rank; end
    return s;
end

-- The text to show: "Path A, STR+3, Accuracy+5"
function augments.text(a) return augments.sig(a); end

-- want: a set's gear entry { augs = { strings }, path, rank }. A piece with no wishes matches anything.
function augments.matches(item, want)
    if want == nil or ((want.augs == nil or #want.augs == 0) and want.path == nil and want.rank == nil) then return true; end
    local a = augments.of(item);
    if a == nil then return false; end
    if want.path ~= nil and a.path ~= want.path then return false; end
    if want.rank ~= nil and a.rank ~= want.rank then return false; end
    local have = {};
    for _, s in ipairs(a.list or {}) do have[s:lower()] = true; end
    for _, s in ipairs(want.augs or {}) do if not have[tostring(s):lower()] then return false; end end
    return true;
end

-- What a gear entry should remember of a copy's augments (nil when it has none)
function augments.entry(item)
    local a = augments.of(item);
    if a == nil then return nil; end
    local e = { augs = {} };
    for _, s in ipairs(a.list or {}) do e.augs[#e.augs + 1] = s; end
    e.path = a.path;
    if a.rank and a.rank > 0 then e.rank = a.rank; end
    return e;
end

-- The words for a set's gear entry
function augments.want_text(g)
    if g == nil then return ''; end
    local t = {};
    if g.path then t[#t + 1] = 'Path ' .. g.path; end
    for _, s in ipairs(g.augs or {}) do t[#t + 1] = s; end
    if g.rank then t[#t + 1] = 'Rank ' .. g.rank; end
    return table.concat(t, ', ');
end

return augments;
