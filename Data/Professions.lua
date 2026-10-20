local _, ns = ...

-- Profession routes for WoW Forever.
-- Crafting routes (Blacksmithing, First Aid, Cooking, Fishing) follow the wow-professions.com
-- Forever guides; credit is shown in the addon next to each route.
-- Gathering routes (Mining, Herbalism, Skinning) use the classic node and mob ranges, since
-- the site has no Forever guide for them.
-- Portuguese recipe names are translations; reagent names always come from the game.

local GUIDE = "https://www.wow-professions.com/forever/"

ns.ProfessionInfo = {
  blacksmithing  = { kind = "primary",   names = { "Blacksmithing", "Ferraria" },          icon = "Interface\\Icons\\Trade_BlackSmithing" },
  mining         = { kind = "primary",   names = { "Mining", "Mineração" },                icon = "Interface\\Icons\\Trade_Mining" },
  herbalism      = { kind = "primary",   names = { "Herbalism", "Herborismo" },            icon = "Interface\\Icons\\Spell_Nature_NatureTouchGrow" },
  skinning       = { kind = "primary",   names = { "Skinning", "Esfolamento" },            icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
  alchemy        = { kind = "primary",   names = { "Alchemy", "Alquimia" },                icon = "Interface\\Icons\\Trade_Alchemy",        guide = GUIDE .. "alchemy-leveling-guide" },
  enchanting     = { kind = "primary",   names = { "Enchanting", "Encantamento" },         icon = "Interface\\Icons\\Trade_Engraving",      guide = GUIDE .. "enchanting-leveling-guide" },
  engineering    = { kind = "primary",   names = { "Engineering", "Engenharia" },          icon = "Interface\\Icons\\Trade_Engineering",    guide = GUIDE .. "engineering-leveling-guide" },
  leatherworking = { kind = "primary",   names = { "Leatherworking", "Couraria" },         icon = "Interface\\Icons\\INV_Misc_ArmorKit_17", guide = GUIDE .. "leatherworking-leveling-guide" },
  tailoring      = { kind = "primary",   names = { "Tailoring", "Alfaiataria" },           icon = "Interface\\Icons\\Trade_Tailoring",      guide = GUIDE .. "tailoring-leveling-guide" },
  firstaid       = { kind = "secondary", names = { "First Aid", "Primeiros Socorros" },    icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
  cooking        = { kind = "secondary", names = { "Cooking", "Culinária" },               icon = "Interface\\Icons\\INV_Misc_Food_15" },
  fishing        = { kind = "secondary", names = { "Fishing", "Pesca" },                   icon = "Interface\\Icons\\Trade_Fishing" },
}

ns.ProfessionOrder = {
  "blacksmithing", "mining", "herbalism", "skinning", "alchemy", "enchanting",
  "engineering", "leatherworking", "tailoring", "firstaid", "cooking", "fishing",
}

-- Skill line IDs returned by GetProfessionInfo.
local SKILL_LINES = {
  blacksmithing = 164, mining = 186, herbalism = 182, skinning = 393, alchemy = 171, enchanting = 333,
  engineering = 202, leatherworking = 165, tailoring = 197, firstaid = 129, cooking = 185, fishing = 356,
}

ns.ProfessionByName = {}
ns.ProfessionBySkillLine = {}
for key, info in pairs(ns.ProfessionInfo) do
  for _, name in ipairs(info.names) do
    ns.ProfessionByName[name:lower()] = key
  end
  ns.ProfessionBySkillLine[SKILL_LINES[key]] = key
end

-- Zone lists: { uiMapID, "level range", faction } with faction "A", "H" or "B" (both).
local Z = {
  copper   = { { 1411, "1-10", "H" }, { 1412, "1-10", "H" }, { 1429, "1-10", "A" }, { 1426, "1-10", "A" }, { 1436, "10-20", "A" } },
  tin      = { { 1413, "10-25", "H" }, { 1442, "15-27", "H" }, { 1433, "15-25", "A" }, { 1437, "20-30", "A" }, { 1424, "20-30", "B" } },
  iron     = { { 1417, "30-40", "B" }, { 1441, "25-35", "B" }, { 1443, "30-40", "B" }, { 1434, "30-45", "B" } },
  mithril  = { { 1418, "35-45", "B" }, { 1427, "43-50", "B" }, { 1425, "40-50", "B" }, { 1446, "40-50", "B" } },
  thorium  = { { 1449, "48-55", "B" }, { 1451, "55-60", "B" }, { 1428, "50-58", "B" }, { 1452, "55-60", "B" } },
  herbStart = { { 1411, "1-10", "H" }, { 1412, "1-10", "H" }, { 1429, "1-10", "A" }, { 1438, "1-10", "A" } },
  herb50   = { { 1413, "10-25", "H" }, { 1421, "10-20", "H" }, { 1439, "10-20", "A" }, { 1436, "10-20", "A" } },
  herb100  = { { 1442, "15-27", "H" }, { 1440, "18-30", "B" }, { 1437, "20-30", "A" }, { 1424, "20-30", "B" } },
  herb150  = { { 1417, "30-40", "B" }, { 1434, "30-45", "B" }, { 1445, "35-45", "B" }, { 1443, "30-40", "B" } },
  herb205  = { { 1444, "40-50", "B" }, { 1446, "40-50", "B" }, { 1425, "40-50", "B" }, { 1427, "43-50", "B" } },
  herb250  = { { 1449, "48-55", "B" }, { 1448, "48-55", "B" }, { 1422, "51-58", "B" }, { 1452, "55-60", "B" } },
  skin1    = { { 1411, "1-10", "H" }, { 1412, "1-10", "H" }, { 1429, "1-10", "A" }, { 1436, "10-20", "A" }, { 1413, "10-25", "H" } },
  skin75   = { { 1413, "10-25", "H" }, { 1442, "15-27", "H" }, { 1437, "20-30", "A" }, { 1424, "20-30", "B" } },
  skin150  = { { 1417, "30-40", "B" }, { 1434, "30-45", "B" }, { 1443, "30-40", "B" }, { 1445, "35-45", "B" } },
  skin225  = { { 1444, "40-50", "B" }, { 1446, "40-50", "B" }, { 1449, "48-55", "B" }, { 1452, "55-60", "B" } },
  linen    = { { 1436, "10-20", "A" }, { 1413, "10-25", "H" }, { 1421, "10-20", "H" } },
  wool     = { { 1424, "20-30", "B" }, { 1431, "18-30", "A" }, { 1433, "15-25", "A" }, { 1442, "15-27", "H" } },
  silk     = { { 1417, "30-40", "B" }, { 1434, "30-45", "B" }, { 1443, "30-40", "B" }, { 1445, "35-45", "B" } },
  mageweave = { { 1446, "40-50", "B" }, { 1425, "40-50", "B" }, { 1444, "40-50", "B" } },
  runecloth = { { 1448, "48-55", "B" }, { 1422, "51-58", "B" }, { 1452, "55-60", "B" } },
  fishStart = { { 1411, "1-10", "H" }, { 1412, "1-10", "H" }, { 1420, "1-10", "H" }, { 1429, "1-10", "A" }, { 1426, "1-10", "A" }, { 1438, "1-10", "A" } },
  fish75   = { { 1454, "-", "H" }, { 1458, "-", "H" }, { 1453, "-", "A" }, { 1455, "-", "A" }, { 1413, "10-25", "H" }, { 1439, "10-20", "A" }, { 1432, "10-20", "A" }, { 1421, "10-20", "H" } },
  fish150  = { { 1445, "35-45", "B" }, { 1416, "30-40", "B" }, { 1417, "30-40", "B" }, { 1443, "30-40", "B" }, { 1434, "30-45", "B" }, { 1435, "35-45", "B" } },
  fish225  = { { 1448, "48-55", "B" }, { 1444, "40-50", "B" }, { 1425, "40-50", "B" }, { 1446, "40-50", "B" }, { 1449, "48-55", "B" }, { 1422, "51-58", "B" } },
}
ns.Zones = Z

-- Reagents: how to get them.
--   vendor = true             sold by merchants
--   farm = minutes per unit   rough farming time; zones = where
--   make = { inputs = { { itemID, qty } }, yield = n, skill = { profession, rank } }
local R = {}
ns.Reagents = R

local function farm(minutes, zones) return { farm = minutes, zones = zones } end
local function make(inputs, yield, profession, rank, extra)
  local r = extra or {}
  r.make = { inputs = inputs, yield = yield or 1, skill = profession and { profession, rank } or nil }
  return r
end
local VENDOR = { vendor = true }

-- Ore, stone and bars
R[2770] = farm(0.7, Z.copper)    -- Copper Ore
R[2771] = farm(0.8, Z.tin)       -- Tin Ore
R[2775] = farm(10, Z.tin)        -- Silver Ore
R[2772] = farm(0.8, Z.iron)      -- Iron Ore
R[3858] = farm(0.8, Z.mithril)   -- Mithril Ore
R[2835] = farm(1.5, Z.copper)    -- Rough Stone
R[2836] = farm(1.5, Z.tin)       -- Coarse Stone
R[2838] = farm(1.5, Z.iron)      -- Heavy Stone
R[7912] = farm(1.5, Z.mithril)   -- Solid Stone
R[3857] = VENDOR                 -- Coal
R[2840] = make({ { 2770, 1 } }, 1, "mining", 1)                   -- Copper Bar
R[3576] = make({ { 2771, 1 } }, 1, "mining", 65)                  -- Tin Bar
R[2842] = make({ { 2775, 1 } }, 1, "mining", 75)                  -- Silver Bar
R[2841] = make({ { 2840, 1 }, { 3576, 1 } }, 2, "mining", 65)     -- Bronze Bar
R[3575] = make({ { 2772, 1 } }, 1, "mining", 125)                 -- Iron Bar
R[3859] = make({ { 3575, 1 }, { 3857, 1 } }, 1, "mining", 165)    -- Steel Bar
R[3860] = make({ { 3858, 1 } }, 1, "mining", 175)                 -- Mithril Bar
R[3470] = make({ { 2835, 2 } }, 1, "blacksmithing", 25)           -- Rough Grinding Stone
R[3478] = make({ { 2836, 2 } }, 1, "blacksmithing", 50)           -- Coarse Grinding Stone
R[3486] = make({ { 2838, 3 } }, 1, "blacksmithing", 100)          -- Heavy Grinding Stone
R[7966] = make({ { 7912, 4 } }, 1, "blacksmithing", 175)          -- Solid Grinding Stone
R[2880] = VENDOR                 -- Weak Flux
R[3466] = VENDOR                 -- Strong Flux
R[2605] = VENDOR                 -- Green Dye
R[2319] = farm(1.2, Z.skin75)    -- Medium Leather

-- Cloth and herbs
R[2589] = farm(0.5, Z.linen)
R[2592] = farm(0.6, Z.wool)
R[4306] = farm(0.6, Z.silk)
R[4338] = farm(0.7, Z.mageweave)
R[14047] = farm(0.7, Z.runecloth)
R[2447] = farm(1.5, Z.herbStart) -- Peacebloom
R[8838] = farm(2.5, Z.herb205)   -- Sungrass
R[13464] = farm(3, Z.herb250)    -- Golden Sansam
R[3371] = VENDOR                 -- Empty Vial
R[8925] = VENDOR                 -- Crystal Vial

-- Tailoring
R[2996] = make({ { 2589, 2 } }, 1, "tailoring", 1)      -- Bolt of Linen Cloth
R[2997] = make({ { 2592, 3 } }, 1, "tailoring", 50)     -- Bolt of Woolen Cloth
R[4305] = make({ { 4306, 4 } }, 1, "tailoring", 100)    -- Bolt of Silk Cloth
R[4339] = make({ { 4338, 5 } }, 1, "tailoring", 140)    -- Bolt of Mageweave
R[2320] = VENDOR                 -- Coarse Thread
R[2321] = VENDOR                 -- Fine Thread
R[4291] = VENDOR                 -- Silken Thread
R[8343] = VENDOR                 -- Heavy Silken Thread
R[2604] = VENDOR                 -- Red Dye

-- Enchanting. A Greater Magic Essence splits into 3 Lesser.
R[10938] = make({ { 10939, 1 } }, 3)                    -- Lesser Magic Essence
R["mote"] = { vendor = true, name = { en = "Mote of Magic", pt = "Partícula de Magia" },
  icon = "Interface\\Icons\\INV_Enchant_DustStrange" }
R[6217] = VENDOR                 -- Copper Rod
R[17034] = VENDOR                -- Maple Seed
R[17035] = VENDOR                -- Stranglethorn Seed
R[3372] = VENDOR                 -- Leaded Vial

-- Cooking
R[159] = VENDOR                  -- Refreshing Spring Water
R[1179] = VENDOR                 -- Ice Cold Milk
R[2678] = VENDOR                 -- Mild Spices
R[2692] = VENDOR                 -- Hot Spices
R[3713] = VENDOR                 -- Soothing Spices
for _, id in ipairs({ 2672, 769, 6889, 3173, 5503, 2673, 2674, 2677, 2675, 3685, 5504, 3731,
  12184, 3712, 12207, 12208, 7974 }) do
  R[id] = farm(1)                -- meats, eggs and clams: no zone list yet
end
R[6291] = farm(0.4, Z.fishStart)
R[6303] = farm(0.4, Z.fishStart)
R[6289] = farm(0.4, Z.fish75)
R[6361] = farm(0.4, Z.fish75)
R[6308] = farm(0.5, Z.fish150)
R[8365] = farm(0.5, Z.fish150)
R[4603] = farm(0.5, Z.fish225)
R[13758] = farm(0.5, Z.fish225)
R[13759] = farm(0.5, Z.fish225)
R[13760] = farm(0.5, Z.fish225)

-- Route builders

local function craft(en, pt, icon, count, reagents, faction)
  return { name = { en = en, pt = pt }, icon = icon, count = count, reagents = reagents, faction = faction }
end

-- A craft whose product is kept and used by later steps (bolts, grinding stones).
local function keep(en, pt, itemID, count, reagents)
  local c = craft(en, pt, itemID, count, reagents)
  c.makes = itemID
  return c
end

local function opt(...)
  return { crafts = { ... } }
end

local function step(from, to, ...)
  return { from = from, to = to, options = { ... } }
end

local function gather(from, to, zones, items, noteEn, notePt)
  return { from = from, to = to, zones = zones, items = items, note = noteEn and { en = noteEn, pt = notePt } or nil }
end

-- cap: the skill cap each rank unlocks.
local RANK = {
  journeyman = { en = "Journeyman", pt = "Artesão", cap = 150 },
  expert     = { en = "Expert", pt = "Especialista", cap = 225 },
  artisan    = { en = "Artisan", pt = "Artífice", cap = 300 },
}

-- kind: "train", "book" or "quest". who: { H = { npc, uiMapID }, A = { ... } }
-- Books and quests unlock the next cap after `at`.
local function mile(kind, at, title, req, level, who, noteEn, notePt)
  local cap = title.cap or (at < 150 and 150 or (at < 225 and 225 or 300))
  return { mile = kind, at = at, title = title, req = req, level = level, who = who, cap = cap,
    note = noteEn and { en = noteEn, pt = notePt } or nil }
end

ns.Routes = {}

ns.Routes.blacksmithing = {
  guide = GUIDE .. "blacksmithing-leveling-guide",
  tested = 225,
  steps = {
    step(1, 25, opt(craft("Rough Sharpening Stone", "Pedra de Afiar Bruta", 2862, 30, { { 2835, 1 } }))),
    step(25, 50, opt(keep("Rough Grinding Stone", "Pedra de Amolar Bruta", 3470, 30, { { 2835, 2 } }))),
    step(50, 67, opt(keep("Coarse Grinding Stone", "Pedra de Amolar Grosseira", 3478, 36, { { 2836, 2 } }))),
    step(67, 75, opt(craft("Runed Copper Gauntlets", "Manoplas de Cobre Rúnicas", nil, 8, { { 2840, 8 }, { 3470, 2 } }))),
    mile("train", 75, RANK.journeyman, 50, 10),
    step(75, 80,
      opt(craft("Runed Copper Belt", "Cinto de Cobre Rúnico", nil, 5, { { 2840, 10 } })),
      opt(craft("Silver Rod", "Haste de Prata", nil, 5, { { 2842, 1 }, { 3470, 2 } }))),
    step(80, 95, opt(craft("Rough Bronze Leggings", "Perneiras de Bronze Brutas", nil, 15, { { 2841, 6 } }))),
    step(95, 100, opt(craft("Patterned Bronze Bracers", "Braçadeiras de Bronze Padronizadas", 2868, 5, { { 2841, 5 }, { 3478, 2 } }))),
    step(100, 112, opt(keep("Heavy Grinding Stone", "Pedra de Amolar Pesada", 3486, 20, { { 2838, 3 } }))),
    step(112, 125, opt(craft("Patterned Bronze Bracers", "Braçadeiras de Bronze Padronizadas", 2868, 13, { { 2841, 5 }, { 3478, 2 } }))),
    step(125, 140, opt(craft("Bronze Shortsword", "Espada Curta de Bronze", nil, 24, { { 2841, 5 }, { 2880, 4 }, { 2319, 2 } }))),
    step(140, 150, opt(craft("Bronze Warhammer", "Martelo de Guerra de Bronze", nil, 10, { { 2841, 8 }, { 3466, 1 }, { 2319, 1 } }))),
    mile("train", 150, RANK.expert, 125, 20, { H = { "Saru Steelfury", 1454 }, A = { "Bengus Deepforge", 1455 } }),
    step(150, 165, opt(craft("Bronze Warhammer", "Martelo de Guerra de Bronze", nil, 19, { { 2841, 8 }, { 3466, 1 }, { 2319, 1 } }))),
    step(165, 175, opt(craft("Green Iron Bracers", "Braçadeiras de Ferro Verde", nil, 15, { { 3575, 6 }, { 2605, 1 } }))),
    step(175, 185, opt(craft("Golden Scale Bracers", "Braçadeiras de Escamas Douradas", nil, 10, { { 3859, 5 }, { 3486, 2 } }))),
    step(185, 215,
      opt(craft("Mithril Plate Pants", "Calças de Placas de Mithril", nil, 36, { { 3860, 12 } })),
      opt(craft("Steel Breastplate", "Peitoral de Aço", nil, 15, { { 3859, 16 }, { 3486, 3 } }),
          craft("Steel Plate Helm", "Elmo de Placas de Aço", nil, 17, { { 3859, 14 }, { 7966, 1 } }))),
    step(215, 225, opt(craft("Heavy Mithril Breastplate", "Peitoral de Mithril Pesado", nil, 10, { { 3860, 16 } }))),
    mile("train", 225, RANK.artisan, 200, 35, { H = { "Brikk Keencraft", 1434 }, A = { "Brikk Keencraft", 1434 } }),
  },
}

ns.Routes.tailoring = {
  guide = GUIDE .. "tailoring-leveling-guide",
  tested = 225,
  steps = {
    step(1, 30, opt(keep("Bolt of Linen Cloth", "Rolo de Tecido de Linho", 2996, 30, { { 2589, 2 } }))),
    step(30, 55, opt(craft("Linen Belt", "Cinto de Linho", nil, 28, { { 2996, 1 }, { 2320, 1 } }))),
    mile("train", 55, RANK.journeyman, 50, 10, { H = { "Magar", 1454 }, A = { "Sellandus", 1453 } },
      "Learn it before 75; past 75 you get no points without it.",
      "Aprenda antes do 75; depois do 75 você não ganha pontos sem ele."),
    step(55, 80, opt(keep("Bolt of Woolen Cloth", "Rolo de Tecido de Lã", 2997, 45, { { 2592, 3 } }))),
    step(80, 95, opt(craft("Woolen Cape", "Capa de Lã", nil, 22, { { 2997, 1 }, { 2321, 1 } }))),
    step(95, 100, opt(craft("Double-stitched Woolen Shoulders", "Ombreiras de Lã com Costura Dupla", nil, 5, { { 2997, 3 }, { 2321, 2 } }))),
    step(100, 120,
      opt(keep("Bolt of Silk Cloth", "Rolo de Tecido de Seda", 4305, 54, { { 4306, 4 } })),
      opt(craft("Double-stitched Woolen Shoulders", "Ombreiras de Lã com Costura Dupla", nil, 23, { { 2997, 3 }, { 2321, 2 } }))),
    step(120, 125, opt(craft("Gloves of Meditation", "Luvas da Meditação", nil, 5, { { 2997, 4 }, { 2321, 3 }, { 3383, 1 } }))),
    mile("train", 125, RANK.expert, 125, 20, { H = { "Josef Gregorian", 1458 }, A = { "Georgio Bolero", 1453 } }),
    step(125, 140, opt(craft("Gloves of Meditation", "Luvas da Meditação", nil, 24, { { 2997, 4 }, { 2321, 3 }, { 3383, 1 } }))),
    step(140, 150,
      opt(keep("Bolt of Mageweave", "Rolo de Magitrama", 4339, 23, { { 4338, 5 } })),
      opt(craft("Red Swashbuckler's Shirt", "Camisa Vermelha de Espadachim", nil, 10, { { 4305, 3 }, { 2604, 2 }, { 4291, 1 } }))),
    step(150, 170, opt(craft("Crimson Silk Vest", "Colete de Seda Carmesim", nil, 20, { { 4305, 4 }, { 2604, 2 }, { 2321, 2 } }))),
    step(170, 190, opt(craft("Crimson Silk Pantaloons", "Pantalonas de Seda Carmesim", nil, 26, { { 4305, 4 }, { 2604, 2 }, { 4291, 2 } }))),
    step(190, 215, opt(craft("Black Mageweave Gloves", "Luvas de Magitrama Preta", nil, 38, { { 4339, 2 }, { 8343, 2 } }))),
    step(215, 225, opt(craft("Mageweave Bag", "Bolsa de Magitrama", nil, 26, { { 4339, 4 }, { 4291, 2 } }))),
    mile("train", 225, RANK.artisan, 200, 35, { H = { "Daryl Stack", 1424 }, A = { "Timothy Worthington", 1445 } },
      "The guide doesn't cover 225-300 on Forever yet.", "O guia ainda não cobre 225-300 no Forever."),
  },
}

local function enchant(en, pt, count, reagents)
  return craft(en, pt, nil, count, reagents)
end

ns.Routes.enchanting = {
  guide = GUIDE .. "enchanting-leveling-guide",
  tested = 225,
  steps = {
    step(1, 2, opt(craft("Runed Copper Rod", "Vara de Cobre Rúnica", 6218, 1, { { 6217, 1 }, { "mote", 1 } }))),
    step(2, 20, opt(enchant("Enchant Bracer - Inferior Stamina", "Encantar Braçadeiras - Vigor Inferior", 18, { { "mote", 1 } }))),
    step(20, 70,
      opt(enchant("Enchant Bracer - Minor Deflect", "Encantar Braçadeiras - Deflexão Menor", 50, { { 10938, 1 } })),
      opt(enchant("Enchant Chest - Inferior Stamina", "Encantar Torso - Vigor Inferior", 50, { { 10940, 1 } }))),
    mile("train", 70, RANK.journeyman, 50, 10, { H = { "Godan", 1454 }, A = { "Lucan Cordell", 1453 } },
      "Learn it before 75.", "Aprenda antes do 75."),
    step(70, 100,
      opt(enchant("Enchant Chest - Minor Absorption", "Encantar Torso - Absorção Menor", 33, { { 10938, 1 } })),
      opt(enchant("Enchant Bracer - Minor Stamina", "Encantar Braçadeiras - Vigor Menor", 30, { { 10940, 2 } }))),
    step(100, 109,
      opt(enchant("Enchant Chest - Minor Absorption", "Encantar Torso - Absorção Menor", 18, { { 10938, 1 } })),
      opt(enchant("Enchant Cloak - Minor Protection", "Encantar Manto - Proteção Menor", 9, { { 10940, 2 } }))),
    step(109, 110, opt(craft("Runed Silver Rod", "Vara de Prata Rúnica", 6339, 1, { { 6338, 1 }, { 10940, 3 }, { 10938, 4 }, { 1210, 1 } }))),
    step(110, 130,
      opt(enchant("Enchant 2H Weapon - Lesser Intellect", "Encantar Arma de Duas Mãos - Intelecto Menor", 20, { { 10938, 4 } })),
      opt(enchant("Enchant Cloak - Minor Protection", "Encantar Manto - Proteção Menor", 32, { { 10940, 2 } }))),
    step(130, 150,
      opt(enchant("Enchant 2H Weapon - Lesser Intellect", "Encantar Arma de Duas Mãos - Intelecto Menor", 32, { { 10938, 4 } })),
      opt(enchant("Enchant Boots - Minor Stamina", "Encantar Botas - Vigor Menor", 20, { { 10940, 4 } })),
      opt(enchant("Enchant Bracer - Lesser Stamina", "Encantar Braçadeiras - Vigor Inferior", 20, { { 11083, 1 } }))),
    mile("train", 150, RANK.expert, 125, 20, { H = { "Hgarth", 1442 }, A = { "Kitta Firewind", 1429 } }),
    step(150, 151, opt(craft("Runed Golden Rod", "Vara de Ouro Rúnica", 11130, 1, { { 11128, 1 }, { 5500, 1 }, { 11082, 1 }, { 11083, 1 } }))),
    step(151, 165, opt(enchant("Minor Mana Oil", "Óleo de Mana Menor", 16, { { 11083, 1 }, { 17034, 2 }, { 3372, 1 } }))),
    step(165, 185, opt(enchant("Enchant Boots - Lesser Agility", "Encantar Botas - Agilidade Inferior", 22, { { 11083, 1 } }))),
    step(185, 200, opt(enchant("Enchant Bracer - Strength", "Encantar Braçadeiras - Força", 15, { { 11137, 1 } }))),
    step(200, 201, opt(craft("Runed Truesilver Rod", "Vara de Veraprata Rúnica", 11145, 1, { { 11144, 1 }, { 7971, 1 }, { 11135, 1 }, { 11137, 1 } }))),
    step(201, 220, opt(enchant("Lesser Wizard Oil", "Óleo de Mago Menor", 25, { { 11137, 1 }, { 17035, 2 }, { 3372, 1 } }))),
    step(220, 225, opt(enchant("Enchant Cloak - Greater Defense", "Encantar Manto - Defesa Maior", 5, { { 11137, 1 } }))),
    mile("train", 225, RANK.artisan, 200, 35, { H = { "Annora", 1418 }, A = { "Annora", 1418 } },
      "Inside Uldaman; she only appears after clearing her area. Learn everything from her.",
      "Dentro de Uldaman; ela só aparece depois de limpar a área. Aprenda tudo com ela."),
    step(225, 230, opt(enchant("Enchant Gloves - Agility", "Encantar Luvas - Agilidade", 5, { { 11137, 1 } }))),
    step(230, 235, opt(enchant("Enchant Boots - Stamina", "Encantar Botas - Vigor", 5, { { 11137, 2 } }))),
    step(235, 250, opt(enchant("Enchant Chest - Superior Stamina", "Encantar Torso - Vigor Superior", 20, { { 11137, 3 } }))),
    step(250, 265,
      opt(enchant("Lesser Mana Oil", "Óleo de Mana Inferior", 20, { { 11176, 1 }, { 8831, 1 }, { 8925, 1 } })),
      opt(enchant("Enchant Bracer - Greater Strength", "Encantar Braçadeiras - Força Maior", 20, { { 11176, 1 }, { 11174, 2 } }))),
    step(265, 294, opt(enchant("Enchant Shield - Greater Stamina", "Encantar Escudo - Vigor Maior", 32, { { 11176, 6 } }))),
    step(294, 295, opt(craft("Runed Arcanite Rod", "Vara de Arcanita Rúnica", 16207, 1,
      { { 16206, 1 }, { 13926, 1 }, { 16204, 10 }, { 16203, 4 }, { 14343, 4 }, { 14344, 2 } }))),
    step(295, 300, opt(enchant("Enchant Cloak - Superior Defense", "Encantar Manto - Defesa Superior", 5, { { 16204, 8 } }))),
  },
}

ns.Routes.firstaid = {
  guide = GUIDE .. "first-aid-leveling-guide",
  tested = 225,
  steps = {
    step(1, 40, opt(craft("Linen Bandage", "Atadura de Linho", 1251, 50, { { 2589, 1 } }))),
    step(40, 75, opt(craft("Heavy Linen Bandage", "Atadura de Linho Grossa", 2581, 40, { { 2589, 2 } }))),
    mile("train", 75, RANK.journeyman, 50),
    step(75, 80, opt(craft("Heavy Linen Bandage", "Atadura de Linho Grossa", 2581, 12, { { 2589, 2 } }))),
    step(80, 115, opt(craft("Wool Bandage", "Atadura de Lã", 3530, 50, { { 2592, 1 } }))),
    step(115, 150, opt(craft("Heavy Wool Bandage", "Atadura de Lã Grossa", 3531, 50, { { 2592, 2 } }))),
    mile("book", 150, { en = "Expert First Aid - Under Wraps", pt = "Primeiros Socorros Especialista" }, 125, nil,
      { A = { "Deneb Walker", 1417 }, H = { "Balai Lok'Wein", 1445 } },
      "Learn Silk Bandage from your trainer first. The manuals are also on the Auction House.",
      "Aprenda Atadura de Seda com o treinador antes. Os manuais também aparecem no Leilão."),
    step(150, 180, opt(craft("Silk Bandage", "Atadura de Seda", 6450, 42, { { 4306, 1 } }))),
    step(180, 210, opt(craft("Heavy Silk Bandage", "Atadura de Seda Grossa", 6451, 46, { { 4306, 2 } }))),
    step(210, 225,
      opt(craft("Mageweave Bandage", "Atadura de Magitrama", 8544, 17, { { 4338, 1 } })),
      opt(craft("Heavy Silk Bandage", "Atadura de Seda Grossa", 6451, 42, { { 4306, 2 } }))),
    mile("quest", 225, { en = "Triage", pt = "Triagem" }, 225, 35,
      { H = { "Doctor Gregory Victor", 1417 }, A = { "Doctor Gustaf VanHowzen", 1445 } },
      "Save 15 patients. Turn the quest in as soon as you reach 15.",
      "Salve 15 pacientes. Entregue a missão assim que chegar a 15."),
    step(225, 240, opt(craft("Superior Healing Potion", "Poção de Cura Superior", 3928, 16, { { 8838, 1 }, { 3713, 1 }, { 8925, 1 } }))),
    step(240, 260, opt(craft("Heavy Mageweave Bandage", "Atadura de Magitrama Grossa", 8545, 30, { { 4338, 2 } }))),
    step(260, 275, opt(craft("Runecloth Bandage", "Atadura de Tecido Rúnico", 14529, 20, { { 14047, 1 } }))),
    step(275, 300, opt(craft("Major Healing Potion", "Poção de Cura Grande", 13446, 30, { { 13464, 1 }, { 3713, 3 }, { 8925, 1 } }))),
  },
}

ns.Routes.cooking = {
  guide = GUIDE .. "cooking-leveling-guide",
  tested = 225,
  steps = {
    step(1, 50,
      opt(craft("Charred Wolf Meat", "Carne de Lobo Tostada", nil, 55, { { 2672, 1 } })),
      opt(craft("Roasted Boar Meat", "Carne de Javali Assada", nil, 55, { { 769, 1 } })),
      opt(craft("Herb Baked Egg", "Ovo Assado com Ervas", nil, 55, { { 6889, 1 }, { 2678, 1 } })),
      opt(craft("Brilliant Smallfish", "Peixinho Brilhante", nil, 55, { { 6291, 1 } })),
      opt(craft("Slitherskin Mackerel", "Cavala Escorregadia", nil, 55, { { 6303, 1 } }))),
    mile("train", 50, RANK.journeyman, 50, nil, nil,
      "Learn Journeyman before 50. Without it you stop gaining points at 75.",
      "Aprenda Artesão antes do 50. Sem ele você para de ganhar pontos no 75."),
    step(50, 100,
      opt(craft("Coyote Steak", "Bife de Coiote", nil, 55, { { 2673, 1 } })),
      opt(craft("Boiled Clams", "Mariscos Cozidos", nil, 55, { { 5503, 1 }, { 159, 1 } })),
      opt(craft("Smoked Bear Meat", "Carne de Urso Defumada", nil, 70, { { 3173, 1 } })),
      opt(craft("Longjaw Mud Snapper", "Pargo-do-lodo Mandíbula-longa", nil, 55, { { 6289, 1 } })),
      opt(craft("Rainbow Fin Albacore", "Albacora Barbatana-arco-íris", nil, 55, { { 6361, 1 } }))),
    step(100, 130,
      opt(craft("Dry Pork Ribs", "Costelas de Porco Secas", nil, 35, { { 2677, 1 }, { 2678, 1 } })),
      opt(craft("Crab Cake", "Bolinho de Caranguejo", nil, 40, { { 2674, 1 }, { 2678, 1 } })),
      opt(craft("Bristle Whisker Catfish", "Peixe-gato Bigode-cerdoso", nil, 30, { { 6308, 1 } })),
      opt(craft("Cooked Crab Claw", "Garra de Caranguejo Cozida", nil, 35, { { 2675, 1 }, { 2678, 1 } }, "A"))),
    step(130, 150,
      opt(craft("Hot Lion Chops", "Costeletas de Leão Picantes", nil, 25, { { 3731, 1 }, { 2692, 1 } })),
      opt(craft("Curiously Tasty Omelet", "Omelete Curiosamente Saborosa", nil, 20, { { 3685, 1 }, { 2692, 1 } })),
      opt(craft("Goblin Deviled Clams", "Mariscos Apimentados Goblin", nil, 25, { { 5504, 1 }, { 2692, 1 } })),
      opt(craft("Bristle Whisker Catfish", "Peixe-gato Bigode-cerdoso", nil, 25, { { 6308, 1 } }))),
    mile("book", 150, { en = "Expert Cookbook", pt = "Livro de Culinária Especialista" }, 125, nil,
      { H = { "Wulan", 1443 }, A = { "Shandrina", 1440 } }),
    step(150, 175,
      opt(craft("Hot Lion Chops", "Costeletas de Leão Picantes", nil, 25, { { 3731, 1 }, { 2692, 1 } })),
      opt(craft("Curiously Tasty Omelet", "Omelete Curiosamente Saborosa", nil, 25, { { 3685, 1 }, { 2692, 1 } }))),
    step(175, 225,
      opt(craft("Mithril Headed Trout", "Truta Cabeça-de-mithril", nil, 50, { { 8365, 1 } })),
      opt(craft("Roast Raptor", "Raptor Assado", nil, 50, { { 12184, 1 }, { 2692, 1 } })),
      opt(craft("Soothing Turtle Bisque", "Sopa de Tartaruga Calmante", nil, 50, { { 3712, 1 }, { 3713, 1 } }))),
    mile("quest", 225, { en = "Clamlette Surprise", pt = "Surpresa de Marisco" }, 225, 35,
      { H = { "Dirge Quikcleave", 1446 }, A = { "Dirge Quikcleave", 1446 } },
      "Bring 12 Giant Egg, 10 Zesty Clam Meat and 20 Alterac Swiss.",
      "Leve 12 Ovo Gigante, 10 Carne de Marisco Picante e 20 Queijo Suíço de Alterac."),
    step(225, 275,
      opt(craft("Spotted Yellowtail", "Rabo-amarelo Pintado", nil, 65, { { 4603, 1 } })),
      opt(craft("Filet of Redgill", "Filé de Guelra-rubra", nil, 65, { { 13758, 1 } })),
      opt(craft("Undermine Clam Chowder", "Sopa de Mariscos da Tramoia", nil, 65, { { 7974, 2 }, { 2692, 1 }, { 1179, 1 } })),
      opt(craft("Monster Omelet", "Omelete Monstruosa", nil, 65, { { 12207, 1 }, { 3713, 2 } })),
      opt(craft("Tender Wolf Steak", "Bife de Lobo Macio", nil, 65, { { 12208, 1 }, { 3713, 1 } }))),
    step(275, 300,
      opt(craft("Poached Sunscale Salmon", "Salmão Escama-solar Escalfado", nil, 35, { { 13760, 1 } })),
      opt(craft("Nightfin Soup", "Sopa de Barbatana-noturna", nil, 35, { { 13759, 1 }, { 159, 1 } }))),
  },
}

ns.Routes.fishing = {
  guide = GUIDE .. "fishing-leveling-guide",
  tested = 225,
  gather = true,
  steps = {
    gather(1, 75, Z.fishStart, { 6291, 6303 }, "Use Shiny Bauble.", "Use Isca Brilhante."),
    mile("train", 75, RANK.journeyman, 50, 10),
    gather(75, 150, Z.fish75, { 6289, 6361 }, "Buy Nightcrawlers if fish keep escaping.", "Compre Minhocas se o peixe escapar."),
    mile("book", 150, { en = "The Bass and You", pt = "O Robalo e Você" }, 125, 20,
      { H = { "Old Man Heming", 1434 }, A = { "Old Man Heming", 1434 } },
      "Also sold on the Auction House. Buy Bright Baubles from Heming.",
      "Também vendido no Leilão. Compre Iscas Reluzentes com o Heming."),
    gather(150, 225, Z.fish150, { 6308, 8365, 6358 }, "Use Bright Baubles. Fish caught here feed Cooking 175-225.",
      "Use Isca Reluzente. Os peixes daqui servem para Culinária 175-225."),
    mile("quest", 225, { en = "Nat Pagle, Angler Extreme", pt = "Nat Pagle, Pescador Radical" }, 225, 35,
      { H = { "Nat Pagle", 1445 }, A = { "Nat Pagle", 1445 } },
      "One quest fish each from Feralas, Swamp of Sorrows, Desolace and Stranglethorn Vale.",
      "Um peixe de missão em Feralas, Pântano das Mágoas, Desolação e Selva do Espinhaço."),
    gather(225, 300, Z.fish225, { 4603, 13759, 13760, 13422 }, "Use Bright Baubles.", "Use Isca Reluzente."),
  },
}

local GATHER_MILES = {
  mile("train", 75, RANK.journeyman, 50, 10),
  mile("train", 150, RANK.expert, 125, 20),
  mile("train", 225, RANK.artisan, 200, 35),
}

local function withMiles(steps)
  local out = {}
  for _, s in ipairs(steps) do out[#out + 1] = s end
  for _, m in ipairs(GATHER_MILES) do out[#out + 1] = m end
  table.sort(out, function(a, b)
    local ka, kb = a.at or a.from, b.at or b.from
    if ka == kb then return a.mile ~= nil and b.mile == nil end
    return ka < kb
  end)
  return out
end

ns.Routes.mining = {
  gather = true,
  steps = withMiles({
    gather(1, 65, Z.copper, { 2770, 2835 }),
    gather(65, 125, Z.tin, { 2771, 2775, 2836 }),
    gather(125, 175, Z.iron, { 2772, 2776, 2838 }, "At 165 you can smelt Steel Bars.", "Com 165 você já funde Barra de Aço."),
    gather(175, 245, Z.mithril, { 3858, 7911, 7912 }),
    gather(245, 300, Z.thorium, { 10620, 12363, 12365 }),
  }),
}

ns.Routes.herbalism = {
  gather = true,
  steps = withMiles({
    gather(1, 50, Z.herbStart, { 2447, 765, 2449 }),
    gather(50, 100, Z.herb50, { 785, 2450 }),
    gather(100, 150, Z.herb100, { 2453, 3820, 3355 }),
    gather(150, 205, Z.herb150, { 3356, 3357, 3818, 3821 }),
    gather(205, 250, Z.herb205, { 8838, 8831, 4625 }),
    gather(250, 300, Z.herb250, { 13464, 13463, 13465, 13467 }),
  }),
}

ns.Routes.skinning = {
  gather = true,
  steps = withMiles({
    gather(1, 75, Z.skin1, { 2318, 2934 }, "Skin beasts up to your skill divided by 5.", "Esfole feras de nível até o seu skill dividido por 5."),
    gather(75, 150, Z.skin75, { 2319, 4232 }),
    gather(150, 225, Z.skin150, { 4234, 4304 }),
    gather(225, 300, Z.skin225, { 4304, 8170 }),
  }),
}
