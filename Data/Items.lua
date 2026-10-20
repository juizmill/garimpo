local _, ns = ...

-- Item categories shown in the Ranking.
-- tiers: farming spots by skill (gathering professions) or character level (cloth).
-- Each tier lists { itemID, estimated units per hour }. Estimates are replaced by the
-- player's own measured gold per hour once enough looting has been recorded.
-- zones are uiMapIDs; the game provides the localized names.

ns.Categories = {
  {
    key = "ore", name = { en = "Ore", pt = "Minérios" }, gather = "mining", color = { 0.49, 0.54, 0.6 },
    tiers = {
      { skill = 1,   zones = { 1411, 1429, 1426, 1436 }, items = { { 2770, 60 }, { 2835, 20 } } },
      { skill = 65,  zones = { 1413, 1433, 1437, 1424 }, items = { { 2771, 50 }, { 2836, 20 }, { 2775, 3 } } },
      { skill = 125, zones = { 1417, 1441, 1443, 1434 }, items = { { 2772, 50 }, { 2838, 20 }, { 2776, 4 } } },
      { skill = 175, zones = { 1418, 1427, 1425, 1446 }, items = { { 3858, 55 }, { 7912, 20 }, { 7911, 4 } } },
      { skill = 245, zones = { 1449, 1451, 1428, 1452 }, items = { { 10620, 60 }, { 12365, 25 }, { 12363, 1 } } },
    },
  },
  {
    key = "herbs", name = { en = "Herbs", pt = "Ervas" }, gather = "herbalism", color = { 0.44, 0.69, 0.29 },
    tiers = {
      { skill = 1,   zones = { 1411, 1429, 1412, 1438 }, items = { { 2447, 30 }, { 765, 30 }, { 2449, 15 } } },
      { skill = 50,  zones = { 1413, 1439, 1421, 1436 }, items = { { 785, 25 }, { 2450, 25 } } },
      { skill = 100, zones = { 1424, 1437, 1442, 1440 }, items = { { 2453, 25 }, { 3820, 15 }, { 3355, 15 } } },
      { skill = 150, zones = { 1417, 1434, 1445, 1443 }, items = { { 3356, 25 }, { 3357, 15 }, { 3818, 15 }, { 3821, 15 } } },
      { skill = 205, zones = { 1444, 1446, 1425, 1427 }, items = { { 8838, 25 }, { 8831, 10 }, { 4625, 10 }, { 3358, 10 } } },
      { skill = 250, zones = { 1449, 1448, 1422, 1452 }, items = { { 13464, 15 }, { 13463, 15 }, { 13465, 10 }, { 13466, 10 }, { 13467, 10 }, { 13468, 0.5 } } },
    },
  },
  {
    key = "transmog", name = { en = "Transmog", pt = "Transmog" }, color = { 0.64, 0.35, 0.82 },
    dynamic = true, -- Bind-on-Equip gear (uncommon or better); measured from your own loot
  },
  {
    key = "cloth", name = { en = "Cloth", pt = "Tecidos" }, color = { 0.85, 0.78, 0.6 },
    tiers = {
      { level = 10, zones = { 1436, 1413, 1421 }, items = { { 2589, 40 } } },
      { level = 18, zones = { 1424, 1431, 1433, 1442 }, items = { { 2592, 40 } } },
      { level = 30, zones = { 1417, 1434, 1443, 1445 }, items = { { 4306, 45 } } },
      { level = 40, zones = { 1446, 1425, 1444 }, items = { { 4338, 45 } } },
      { level = 50, zones = { 1448, 1422, 1452 }, items = { { 14047, 50 }, { 14256, 1 } } },
    },
  },
  {
    key = "leather", name = { en = "Leather", pt = "Couro" }, gather = "skinning", color = { 0.6, 0.42, 0.24 },
    tiers = {
      { skill = 1,   zones = { 1411, 1412, 1429, 1413 }, items = { { 2318, 60 }, { 783, 5 }, { 2934, 30 } } },
      { skill = 75,  zones = { 1413, 1424, 1442, 1437 }, items = { { 2319, 50 }, { 4232, 5 } } },
      { skill = 150, zones = { 1417, 1434, 1443, 1445 }, items = { { 4234, 50 }, { 4235, 5 } } },
      { skill = 200, zones = { 1444, 1446, 1425, 1418 }, items = { { 4304, 50 }, { 8169, 4 } } },
      { skill = 250, zones = { 1449, 1452, 1428, 1448 }, items = { { 8170, 50 }, { 8171, 4 } } },
    },
  },
  {
    key = "enchanting", name = { en = "Enchanting", pt = "Encantamento" }, color = { 0.48, 0.72, 0.88 },
    -- Disenchanting materials have no farming spot; the Ranking uses your measured loot.
    items = { 10940, 11083, 11137, 11176, 16204, 10938, 10939, 10998, 11082, 11134, 11135, 11174, 11175,
      16202, 16203, 10978, 11084, 11138, 11139, 11177, 11178, 14343, 14344 },
  },
  {
    key = "fishing", name = { en = "Fishing", pt = "Pesca" }, gather = "fishing", color = { 0.35, 0.65, 0.63 },
    tiers = {
      { skill = 1,   zones = { 1411, 1429, 1412, 1420 }, items = { { 6291, 40 }, { 6303, 40 } } },
      { skill = 75,  zones = { 1413, 1439, 1432, 1421 }, items = { { 6289, 35 }, { 6361, 35 } } },
      { skill = 150, zones = { 1445, 1417, 1443, 1434 }, items = { { 6308, 30 }, { 6358, 15 }, { 6359, 10 }, { 8365, 30 } } },
      { skill = 225, zones = { 1444, 1446, 1425, 1449 }, items = { { 4603, 30 }, { 13422, 10 }, { 13755, 20 }, { 13759, 20 }, { 13760, 20 }, { 13758, 20 } } },
    },
  },
}

ns.CategoryByKey = {}
for _, cat in ipairs(ns.Categories) do
  ns.CategoryByKey[cat.key] = cat
end
