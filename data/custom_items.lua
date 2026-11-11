-- custom_items.lua : CatsEyeXI pieces whose slot / job data is blank in the game's item table. The game won't
-- let an addon equip them by packet, so NeoSwap sends /equip for them, and the set editor offers them in these
-- slots. (The same lists your profiles carry.) Any other piece with blank data that a set uses is put on with
-- /equip too; listing it here also makes it show up in the slot's gear list. Add more as: ['lower-case name'] = { slot numbers }.
--   slots: 0 main, 1 sub, 2 range, 3 ammo, 4 head, 5 body, 6 hands, 7 legs, 8 feet, 9 neck, 10 waist,
--          11 / 12 ears, 13 / 14 rings, 15 back
return {
    -- Crystal Warrior Incursion armor (bg-wiki: CatsEyeXI Content / Crystal Warrior Incursions)
    ['renegade beret']     = { 4 },
    ['renegade doublet']   = { 5 },
    ['renegade gloves']    = { 6 },
    ['renegade brais']     = { 7 },
    ['renegade gaiters']   = { 8 },
    ["prelate's chapeau"]  = { 4 },
    ["prelate's saio"]     = { 5 },
    ["prelate's cuffs"]    = { 6 },
    ["prelate's slops"]    = { 7 },
    ["prelate's pigaches"] = { 8 },
    ['bulwark salade']     = { 4 },
    ['bulwark haubert']    = { 5 },
    ['bulwark moufles']    = { 6 },
    ['bulwark brayettes']  = { 7 },
    ['bulwark sollerets']  = { 8 },
    ['brawler crown']      = { 4 },
    ['brawler tunic']      = { 5 },
    ['brawler mitts']      = { 6 },
    ['brawler slacks']     = { 7 },
    ['brawler pumps']      = { 8 },
    ['drifter cap']     = { 4 },
    ['drifter jupon']   = { 5 },
    ['drifter bracers'] = { 6 },
    ['drifter hose']    = { 7 },
    ['drifter boots']   = { 8 },
    ['phantom tiara']    = { 4 },
    ['phantom harness']  = { 5 },
    ['phantom mittens']  = { 6 },
    ['phantom tights']   = { 7 },
    ['phantom leggings'] = { 8 },
    ['thermal ring']    = { 13, 14 },
};
