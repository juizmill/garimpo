local _, ns = ...

-- Bags and bank

local function bagList()
  local t = {}
  for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do t[#t + 1] = bag end
  return t
end

-- The modern engine names every bank container in Enum.BagIndex.
local function bankList()
  local t, seen = {}, {}
  if Enum and Enum.BagIndex then
    for name, index in pairs(Enum.BagIndex) do
      if name:find("Bank") and not seen[index] then
        seen[index] = true
        t[#t + 1] = index
      end
    end
  end
  if #t == 0 then
    t[1] = BANK_CONTAINER or -1
    local first = (NUM_BAG_SLOTS or 4) + 1
    for bag = first, first + (NUM_BANKBAGSLOTS or 6) - 1 do t[#t + 1] = bag end
  end
  return t
end

local function eachSlot(bags, fn)
  for _, bag in ipairs(bags) do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID then fn(bag, slot, info) end
    end
  end
end

function ns:CacheBank()
  local bank = {}
  eachSlot(bankList(), function(_, _, info)
    bank[info.itemID] = (bank[info.itemID] or 0) + (info.stackCount or 1)
  end)
  self.char.bank = bank
  self.char.bankTime = time()
end

function ns:BagCounts(includeBank)
  local t = {}
  eachSlot(bagList(), function(_, _, info)
    t[info.itemID] = (t[info.itemID] or 0) + (info.stackCount or 1)
  end)
  if includeBank and self.char then
    for id, n in pairs(self.char.bank) do t[id] = (t[id] or 0) + n end
  end
  return t
end

-- Unbound stacks of an item in the bags, for posting.
function ns:FindSlots(itemID)
  local slots = {}
  eachSlot(bagList(), function(bag, slot, info)
    if info.itemID == itemID and not info.isBound and not info.isLocked then
      slots[#slots + 1] = { bag = bag, slot = slot, count = info.stackCount or 1 }
    end
  end)
  return slots
end

-- Prices and history

-- Items the Ranking, routes and bags care about; the quick search scans these.
function ns:TrackedItems()
  local t, list = {}, {}
  local function add(id)
    if type(id) == "number" and not t[id] then t[id] = true; list[#list + 1] = id end
  end
  for _, cat in ipairs(ns.Categories) do
    for _, tier in ipairs(cat.tiers or {}) do
      for _, it in ipairs(tier.items) do add(it[1]) end
    end
    for _, id in ipairs(cat.items or {}) do add(id) end
  end
  for id, r in pairs(ns.Reagents) do
    if not r.vendor then add(id) end
  end
  for id in pairs(self:BagCounts(true)) do add(id) end
  return list
end

-- Drops price history older than 35 days. Called after each scan.
function ns:PruneHistory()
  local cutoff = ns.Today() - 35
  for id, history in pairs(self.db.prices) do
    for d in pairs(history) do
      if d < cutoff then history[d] = nil end
    end
    if next(history) == nil then self.db.prices[id] = nil end
  end
end

-- Returns current market value, 7-day average, change since the last recorded day,
-- difference from the 7-day average (fractions) and how many past days are recorded.
function ns:PriceStats(id)
  local cur = ns.Market(id)
  local history = self.db and self.db.prices[id]
  local today = ns.Today()
  local sum, n, prevDay, prev = 0, 0, nil, nil
  if history then
    for d, p in pairs(history) do
      if d < today then
        if d >= today - 7 then sum, n = sum + p, n + 1 end
        if not prevDay or d > prevDay then prevDay, prev = d, p end
      end
    end
  end
  local avg = n > 0 and sum / n or nil
  local change = (cur and prev and prev > 0) and (cur - prev) / prev or nil
  local diff = (cur and avg and avg > 0) and (cur - avg) / avg or nil
  return cur, avg, change, diff, n
end

-- "sell" when the price is 10% above its 7-day average, "hold" when 10% below.
function ns:Advice(id)
  local cur, _, _, diff = self:PriceStats(id)
  if not cur then return nil end
  if diff and diff >= 0.10 then return "sell" end
  if diff and diff <= -0.10 then return "hold" end
  return "normal"
end

-- Categories

local itemCategory = {}
ns:On("INIT", function()
  for _, cat in ipairs(ns.Categories) do
    for _, tier in ipairs(cat.tiers or {}) do
      for _, it in ipairs(tier.items) do itemCategory[it[1]] = cat.key end
    end
    for _, id in ipairs(cat.items or {}) do itemCategory[id] = cat.key end
  end
end)

local function isTransmog(id)
  local _, _, quality, _, _, _, _, _, equipLoc, _, _, _, _, bindType = ns.ItemInfo(id)
  return quality and quality >= 2 and equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_BAG"
    and bindType == 2
end

function ns:CategoryOf(id)
  if itemCategory[id] then return itemCategory[id] end
  if isTransmog(id) then return "transmog" end
  return nil
end

-- Forever (modern engine) lists professions through GetProfessions; older
-- clients use the skill window API.
function ns:ReadSkills()
  local skills = {}
  local function add(name, skillLine, rank, maxRank)
    local key = (skillLine and ns.ProfessionBySkillLine[skillLine]) or (name and ns.ProfessionByName[name:lower()])
    if key and rank then skills[key] = { rank = rank, max = maxRank or rank } end
  end
  if GetProfessions and GetProfessionInfo then
    local slots = { GetProfessions() }
    for i = 1, 6 do
      local index = slots[i]
      if index then
        local name, _, rank, maxRank, _, _, skillLine = GetProfessionInfo(index)
        add(name, skillLine, rank, maxRank)
      end
    end
  end
  if GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() do
      local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
      if name and not isHeader then add(name, nil, rank, maxRank) end
    end
  end
  self.skills = skills
end

function ns:SkillRank(key)
  local s = self.skills and self.skills[key]
  return s and s.rank or nil
end

function ns:MeasuredGph(key)
  local f = self.db.farm[key]
  if f and f.seconds >= 900 then return f.value / f.seconds * 3600 end
  return nil
end

function ns:EvalTier(tier)
  local total, best, bestValue, weight, weighted = 0, nil, 0, 0, 0
  for _, it in ipairs(tier.items) do
    local cur, _, change = self:PriceStats(it[1])
    if cur then
      local v = cur * it[2]
      total = total + v
      if v > bestValue then best, bestValue = it[1], v end
      if change then weight, weighted = weight + v, weighted + v * change end
    end
  end
  return total, best, weight > 0 and weighted / weight or nil
end

function ns:TierAvailable(cat, tier)
  if cat.gather then
    local rank = self:SkillRank(cat.gather)
    return rank ~= nil and rank >= tier.skill
  end
  return UnitLevel("player") >= (tier.level or 1)
end

-- One row per category: estimated gold per hour, 24h change and best item.
function ns:RankCategories()
  local rows = {}
  for _, cat in ipairs(ns.Categories) do
    local row = { cat = cat }
    if cat.tiers then
      local avail, any
      for i, tier in ipairs(cat.tiers) do
        local gph, item, change = self:EvalTier(tier)
        local entry = { gph = gph, item = item, change = change, tier = i }
        if self:TierAvailable(cat, tier) and (not avail or gph > avail.gph) then avail = entry end
        if not any or gph > any.gph then any = entry end
      end
      local pick = avail or any
      row.gph, row.item, row.change, row.tier = pick.gph, pick.item, pick.change, pick.tier
      row.locked = avail == nil
    elseif cat.items then
      local bestValue, weight, weighted = 0, 0, 0
      for _, id in ipairs(cat.items) do
        local cur, _, change = self:PriceStats(id)
        if cur and cur > bestValue then row.item, bestValue = id, cur end
        if cur and change then weight, weighted = weight + cur, weighted + cur * change end
      end
      row.change = weight > 0 and weighted / weight or nil
    elseif cat.dynamic then
      local bestValue = 0
      for id in pairs(self:BagCounts(true)) do
        if isTransmog(id) then
          local p = ns.Market(id)
          if p and p > bestValue then row.item, bestValue = id, p end
        end
      end
    end
    local measured = self:MeasuredGph(cat.key)
    if measured then row.gph, row.measured = measured, true end
    if row.gph == 0 then row.gph = nil end
    rows[#rows + 1] = row
  end
  table.sort(rows, function(a, b) return (a.gph or -1) > (b.gph or -1) end)
  return rows
end

-- Items of one category for the detail view.
function ns:CategoryItems(cat)
  local ids, seen = {}, {}
  local function add(id) if not seen[id] then seen[id] = true; ids[#ids + 1] = id end end
  for _, tier in ipairs(cat.tiers or {}) do
    for _, it in ipairs(tier.items) do add(it[1]) end
  end
  for _, id in ipairs(cat.items or {}) do add(id) end
  if cat.dynamic then
    for id in pairs(self:BagCounts(true)) do
      if isTransmog(id) then add(id) end
    end
  end
  local rows = {}
  for _, id in ipairs(ids) do
    local cur, avg, change, diff = self:PriceStats(id)
    rows[#rows + 1] = { id = id, price = cur, avg = avg, change = change, diff = diff,
      age = ns.PriceAge(id), advice = self:Advice(id) }
  end
  table.sort(rows, function(a, b) return (a.price or 0) > (b.price or 0) end)
  return rows
end

-- Bags report: value of everything unbound, what to sell now and vendor trash.
function ns:BagReport(includeBank)
  local byId, list = {}, {}
  local function add(id, count, quality)
    local e = byId[id]
    if not e then
      e = { id = id, count = 0, quality = quality }
      byId[id] = e
      list[#list + 1] = e
    end
    e.count = e.count + count
  end
  eachSlot(bagList(), function(_, _, info)
    if not info.isBound then add(info.itemID, info.stackCount or 1, info.quality) end
  end)
  if includeBank then
    for id, n in pairs(self.char.bank) do add(id, n, select(3, ns.ItemInfo(id))) end
  end

  local totals = { value = 0, sell = 0, junk = 0 }
  local rows = {}
  for _, e in ipairs(list) do
    if e.quality == 0 then
      local sell = select(11, ns.ItemInfo(e.id)) or 0
      e.junk = sell * e.count
      e.advice = "vendor"
      totals.junk = totals.junk + e.junk
      if e.junk > 0 then rows[#rows + 1] = e end
    else
      local cur, _, _, diff = self:PriceStats(e.id)
      if cur then
        e.unit, e.total, e.diff = cur, cur * e.count, diff
        e.advice = self:Advice(e.id)
        totals.value = totals.value + e.total
        if e.advice == "sell" then totals.sell = totals.sell + e.total end
        rows[#rows + 1] = e
      end
    end
  end
  table.sort(rows, function(a, b) return (a.total or a.junk or 0) > (b.total or b.junk or 0) end)
  return rows, totals
end

function ns:SellJunk()
  if not self.merchantOpen then return 0 end
  local sold = 0
  eachSlot(bagList(), function(bag, slot, info)
    if info.quality == 0 and not info.hasNoValue then
      C_Container.UseContainerItem(bag, slot)
      sold = sold + 1
    end
  end)
  return sold
end

-- Loot tracking: measured gold per hour per category.

local lootCache, lastLoot = {}, {}

ns:On("LOOT_READY", function()
  wipe(lootCache)
  for i = 1, GetNumLootItems() do
    local link = GetLootSlotLink(i)
    if link then
      local _, _, qty = GetLootSlotInfo(i)
      lootCache[i] = { link = link, qty = qty or 1 }
    end
  end
end)

ns:On("LOOT_SLOT_CLEARED", function(slot)
  local e = lootCache[slot]
  if e then
    lootCache[slot] = nil
    ns:RecordLoot(e.link, e.qty)
  end
end)

-- Loot within 5 minutes of the previous one counts as continuous farming time;
-- the first loot of a streak counts as one minute.
function ns:RecordLoot(link, qty)
  local id = ns.ItemInfoInstant(link)
  if not id then return end
  self:RecordNode(id)
  local cat = self:CategoryOf(id)
  local price = cat and ns.Market(id)
  if not price then return end
  local now = time()
  local f = self.db.farm[cat] or { value = 0, seconds = 0 }
  self.db.farm[cat] = f
  local last = lastLoot[cat]
  f.seconds = f.seconds + ((last and now - last < 300) and (now - last) or 60)
  f.value = f.value + price * qty
  lastLoot[cat] = now
end

-- Professions

function ns:CanMake(make)
  if not make.skill then return true end
  local rank = self:SkillRank(make.skill[1])
  return rank ~= nil and rank >= make.skill[2]
end

-- Cheapest way to get one unit: buy it, or make it from cheaper inputs.
-- Returns cost and method ("buy", "make" or "vendor"), or nil when nothing is priced.
function ns:UnitCost(id, depth)
  depth = depth or 0
  local r = ns.Reagents[id]
  if r and r.vendor then
    local p = ns.VendorBuyPrice(id)
    return p, p and "vendor" or nil
  end
  local best, method = ns.Price(id), "buy"
  if r and r.make and depth < 3 and self.db.settings.prof.craft and self:CanMake(r.make) then
    local sum = 0
    for _, input in ipairs(r.make.inputs) do
      local c = self:UnitCost(input[1], depth + 1)
      if not c then sum = nil; break end
      sum = sum + c * input[2]
    end
    if sum then
      sum = sum / r.make.yield
      if not best or sum < best then best, method = sum, "make" end
    end
  end
  if not best then return nil end
  return best, method
end

-- Cost of making it from raw materials, ignoring whether the player can.
function ns:MakeCost(id)
  local r = ns.Reagents[id]
  if not r or not r.make then return nil end
  local sum = 0
  for _, input in ipairs(r.make.inputs) do
    local c = self:UnitCost(input[1], 1)
    if not c then return nil end
    sum = sum + c * input[2]
  end
  return sum / r.make.yield
end

function ns:FarmMinutes(id, depth)
  local r = ns.Reagents[id]
  if not r or r.vendor then return nil end
  if r.farm then return r.farm end
  if r.make and (depth or 0) < 3 then
    local sum = 0
    for _, input in ipairs(r.make.inputs) do
      local m = self:FarmMinutes(input[1], (depth or 0) + 1)
      if not m then return nil end
      sum = sum + m * input[2]
    end
    return sum / r.make.yield
  end
  return nil
end

function ns:FarmZones(id, depth)
  local r = ns.Reagents[id]
  if not r then return nil end
  if r.zones then return r.zones end
  if r.make and (depth or 0) < 3 then
    for _, input in ipairs(r.make.inputs) do
      local z = self:FarmZones(input[1], (depth or 0) + 1)
      if z then return z end
    end
  end
  return nil
end

local function playerFaction()
  return UnitFactionGroup("player") == "Horde" and "H" or "A"
end
ns.PlayerFaction = playerFaction

-- Share of a step between skill lo and hi.
function ns.StepFrac(s, lo, hi)
  local a, b = math.max(s.from, lo), math.min(s.to, hi)
  if b <= a then return 0 end
  return (b - a) / (s.to - s.from)
end

function ns:OptionCost(option, frac)
  local total, known = 0, true
  for _, c in ipairs(option.crafts) do
    local n = math.ceil(c.count * frac)
    for _, rg in ipairs(c.reagents) do
      local unit = self:UnitCost(rg[1])
      if unit then total = total + unit * rg[2] * n else known = false end
    end
  end
  return total, known
end

local function optionAllowed(option)
  local faction = playerFaction()
  for _, c in ipairs(option.crafts) do
    if c.faction and c.faction ~= faction then return false end
  end
  return true
end

-- Picks the cheapest fully priced option of a step; falls back to the first one.
function ns:ChooseOption(s, frac)
  local best, bestCost, bestKnown
  local costs = {}
  for i, o in ipairs(s.options) do
    if optionAllowed(o) then
      local cost, known = self:OptionCost(o, frac)
      costs[i] = known and cost or nil
      if not best or (known and (not bestKnown or cost < bestCost)) then
        best, bestCost, bestKnown = o, cost, known
      end
    end
  end
  return best, bestKnown and bestCost or nil, costs
end

function ns:RouteTarget(key, skill)
  local route = ns.Routes[key]
  if self.db.settings.prof.target == "trainer" then
    for _, s in ipairs(route.steps) do
      if s.mile and s.at > skill then return s.at end
    end
  end
  return 300
end

function ns:SkillMax(key)
  local s = self.skills and self.skills[key]
  return s and s.max or 0
end

-- A milestone is done once the skill cap it grants is reached, and due when
-- the player already has the skill it requires.
function ns:MilestoneStatus(s, skill, skillMax)
  if skillMax >= s.cap then return "done" end
  if skill >= (s.req or s.at) then return "due" end
  return "mile"
end

-- Rows for the route list, with status, chosen option and remaining cost.
-- Also returns the skill and the first milestone the player must do now.
function ns:EvaluateRoute(key)
  local route = ns.Routes[key]
  local skill = self:SkillRank(key) or 0
  local skillMax = self:SkillMax(key)
  local rows, currentSet, due = {}, false, nil
  for _, s in ipairs(route.steps) do
    local row = { step = s }
    if s.mile then
      row.status = self:MilestoneStatus(s, skill, skillMax)
      if row.status == "due" and not due then due = row end
    else
      local frac = ns.StepFrac(s, skill, s.to)
      if frac == 0 then
        row.status = "done"
      elseif not currentSet then
        row.status, currentSet = "current", true
      else
        row.status = "next"
      end
      row.frac = frac
      if s.options then
        local option, cost, costs = self:ChooseOption(s, frac > 0 and frac or 1)
        row.option, row.cost, row.costs = option, frac > 0 and cost or nil, costs
        if frac > 0 then
          row.left = 0
          for _, c in ipairs(option.crafts) do row.left = row.left + math.ceil(c.count * frac) end
        end
      end
    end
    row.untested = route.tested and (s.from or s.at) >= route.tested and not (s.mile and s.at == route.tested)
    rows[#rows + 1] = row
  end
  return rows, skill, due
end

-- Reagents still needed up to the route target, minus what the player owns.
function ns:ProfessionNeeds(key)
  local route = ns.Routes[key]
  local skill = self:SkillRank(key) or 0
  local target = self:RouteTarget(key, skill)
  -- Crafts that make intermediates (bolts, grinding stones) are credited
  -- against the later steps that use them.
  local need, made = {}, {}
  for _, s in ipairs(route.steps) do
    if s.options then
      local frac = ns.StepFrac(s, skill, target)
      if frac > 0 then
        local option = self:ChooseOption(s, frac)
        for _, c in ipairs(option.crafts) do
          local n = math.ceil(c.count * frac)
          for _, rg in ipairs(c.reagents) do need[rg[1]] = (need[rg[1]] or 0) + rg[2] * n end
          if c.makes then made[c.makes] = (made[c.makes] or 0) + n end
        end
      end
    end
  end
  for id, n in pairs(made) do
    if need[id] then
      need[id] = need[id] - n
      if need[id] <= 0 then need[id] = nil end
    end
  end
  local have = self:BagCounts(self.db.settings.prof.useBank)
  local list = {}
  for id, n in pairs(need) do
    local miss = n - (have[id] or 0)
    if miss > 0 then
      local unit, method = self:UnitCost(id)
      local r = ns.Reagents[id]
      list[#list + 1] = { id = id, need = n, have = have[id] or 0, miss = miss, unit = unit, method = method,
        vendor = r and r.vendor, farmMin = self:FarmMinutes(id) }
    end
  end
  table.sort(list, function(a, b) return (a.unit or 0) * a.miss > (b.unit or 0) * b.miss end)
  return list, target, skill
end

-- Splits each reagent into buy and farm within a gold budget. Vendor items and
-- items that cannot be farmed are always bought; the rest is bought in order of
-- farming minutes saved per copper.
function ns:Plan(list, budgetCopper)
  local rem = math.max(0, budgetCopper or 0)
  local candidates = {}
  for _, e in ipairs(list) do
    e.buy, e.farm = 0, 0
    if e.unit and (e.vendor or not e.farmMin) then
      e.buy = e.miss
      rem = rem - e.unit * e.miss
    elseif e.unit and e.farmMin then
      candidates[#candidates + 1] = e
    elseif e.farmMin then
      e.farm = e.miss
    end
  end
  table.sort(candidates, function(a, b) return a.farmMin / a.unit > b.farmMin / b.unit end)
  for _, e in ipairs(candidates) do
    local k = rem > 0 and math.min(e.miss, math.floor(rem / e.unit)) or 0
    e.buy, e.farm = k, e.miss - k
    rem = rem - k * e.unit
  end
  local gold, minutes, allBuy, allFarm = 0, 0, 0, 0
  for _, e in ipairs(list) do
    if e.unit then
      gold = gold + e.buy * e.unit
      allBuy = allBuy + e.miss * e.unit
    end
    if e.farmMin then
      minutes = minutes + e.farm * e.farmMin
      if not e.vendor then allFarm = allFarm + e.miss * e.farmMin end
    end
    if e.vendor then e.decision = "vendor"
    elseif not e.unit and not e.farmMin then e.decision = "unknown"
    elseif e.farm == 0 then e.decision = "buy"
    elseif e.buy == 0 then e.decision = "farm"
    else e.decision = "mixed" end
  end
  return { gold = gold, minutes = minutes, allBuy = allBuy, allFarm = allFarm }
end

-- Where to go for a route milestone: the named NPC (trainer, book vendor, quest giver)
-- when the data names one, otherwise the nearest trainer of the profession for your
-- faction. Returns { map, x, y, name } with x, y from 0 to 1, or nil.
function ns:TrainerSpot(s, profKey)
  local faction = ns.PlayerFaction()
  local function nearest(list)
    local best, bestDist
    for _, c in ipairs(list) do
      local d = self.DistanceTo and self:DistanceTo(c.map, c.x, c.y)
      if d and (not bestDist or d < bestDist) then best, bestDist = c, d end
    end
    return best or list[1]
  end
  local list = {}
  if s.who then
    local w = s.who[faction] or s.who.H or s.who.A
    local name, map = w[1], w[2]
    for _, p in ipairs(ns.NPCs and ns.NPCs[name] or {}) do
      list[#list + 1] = { map = p[1], x = p[2] / 100, y = p[3] / 100, name = name }
    end
    if #list == 0 then
      for _, t in ipairs(ns.Trainers and ns.Trainers[profKey] or {}) do
        if t[6] == name then list[#list + 1] = { map = t[1], x = t[2] / 100, y = t[3] / 100, name = name } end
      end
    end
    -- The zone named in the route data wins when the NPC appears in several places.
    for _, c in ipairs(list) do
      if c.map == map then return c end
    end
    if #list > 0 then return nearest(list) end
    -- No position known (e.g. inside a dungeon): the zone from the route data.
    return { map = map, x = 0.5, y = 0.5, name = name, approx = true }
  end
  local horde = faction == "H"
  for _, t in ipairs(ns.Trainers and ns.Trainers[profKey] or {}) do
    if (horde and t[5]) or (not horde and t[4]) then
      list[#list + 1] = { map = t[1], x = t[2] / 100, y = t[3] / 100, name = t[6] }
    end
  end
  if #list == 0 then return nil end
  return nearest(list)
end

-- Points the arrow at the milestone's NPC.
function ns:MarkTrainer(s, profKey)
  local c = self:TrainerSpot(s, profKey)
  if c and c.approx then
    self:SetWaypoint(c.map, nil, c.name, c.x, c.y)   -- zone center
    ns.Print(ns.L.TRAINER_APPROX:format(c.name, ns.ZoneName(c.map)))
  elseif c then
    self:SetWaypoint(c.map, nil, c.name, c.x, c.y)
  else
    ns.Print(ns.L.TRAINER_NOT_FOUND)
  end
end

-- The professions to show: learned ones, or every one with a route when enabled.
function ns:ProfessionList()
  local primary, secondary = {}, {}
  local showAll = self.db.settings.prof.showUnlearned
  for _, key in ipairs(ns.ProfessionOrder) do
    local info = ns.ProfessionInfo[key]
    if (self.skills and self.skills[key]) or (showAll and (ns.Routes[key] or info.guide)) then
      if info.kind == "primary" then primary[#primary + 1] = key else secondary[#secondary + 1] = key end
    end
  end
  return primary, secondary
end
