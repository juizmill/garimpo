local _, ns = ...
local L, W = ns.L, ns.W

local GATHER_CATEGORY = { mining = "ore", herbalism = "herbs", skinning = "leather", fishing = "fishing" }
local MUTED = "9a8f7c"

local function reagentText(reagents, n)
  local parts = {}
  for _, rg in ipairs(reagents) do
    parts[#parts + 1] = (rg[2] * n) .. " " .. ns.ItemName(rg[1])
  end
  return table.concat(parts, " · ")
end

local function optionName(option)
  local parts = {}
  for _, c in ipairs(option.crafts) do parts[#parts + 1] = ns.T(c.name) end
  return table.concat(parts, " + ")
end

local function optionIcon(option)
  local c = option.crafts[1]
  return c.icon and ns.ItemIcon(c.icon) or ns.ItemIcon(c.reagents[1][1])
end

local function whoText(who)
  if not who then return nil end
  local w = who[ns.PlayerFaction()] or who.H or who.A
  return w[1] .. " (" .. ns.ZoneName(w[2]) .. ")"
end

local function mileTitle(s)
  if s.mile == "train" then return L.TRAINER_RANK:format(ns.T(s.title)) end
  if s.mile == "book" then return L.BOOK:format(ns.T(s.title)) end
  return L.QUEST:format(ns.T(s.title))
end

local function mileSub(s)
  local parts = {}
  local who = whoText(s.who)
  parts[#parts + 1] = who or L.ANY_TRAINER
  if s.req then parts[#parts + 1] = L.REQ_SKILL:format(s.req) end
  if s.level then parts[#parts + 1] = L.REQ_LEVEL:format(s.level) end
  local line = table.concat(parts, " · ")
  if s.note then line = line .. "\n" .. ns.T(s.note) end
  return line
end

local function zonesText(zones, limit)
  local faction = ns.PlayerFaction()
  local parts = {}
  for _, z in ipairs(zones or {}) do
    if z[3] == "B" or z[3] == faction then
      parts[#parts + 1] = ns.ZoneName(z[1])
      if limit and #parts >= limit then break end
    end
  end
  return table.concat(parts, ", ")
end

local function itemsText(items)
  local parts = {}
  for _, id in ipairs(items or {}) do parts[#parts + 1] = ns.ItemName(id) end
  return table.concat(parts, ", ")
end

-- Route subview --------------------------------------------------------------

local function buildRoute(parent, view)
  local f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints()

  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(20, 20)
  f.icon:SetPoint("TOPLEFT", 0, 0)
  f.name = W.Font(f, 14, W.C.ink)
  f.name:SetPoint("LEFT", f.icon, "RIGHT", 6, 0)
  f.name:SetWidth(150)
  f.bar = W.Bar(f, 320, 10, { 0.31, 0.64, 0.88 })
  f.bar:SetPoint("LEFT", f.icon, "RIGHT", 160, 0)
  f.skill = W.Font(f, 13, W.C.ink, "RIGHT")
  f.skill:SetPoint("TOPRIGHT", 0, -3)

  local now = W.Box(f, { 0.14, 0.12, 0.03, 0.9 }, { 0.48, 0.4, 0.07, 1 })
  now:SetPoint("TOPLEFT", 0, -28)
  now:SetPoint("TOPRIGHT", 0, -28)
  now:SetHeight(50)
  local nowLabel = W.Font(now, 10, W.C.gold)
  nowLabel:SetPoint("TOPLEFT", 10, -6)
  W.Label(nowLabel, "LEVELING_NOW")
  f.nowIcon = now:CreateTexture(nil, "ARTWORK")
  f.nowIcon:SetSize(16, 16)
  f.nowIcon:SetPoint("TOPLEFT", 10, -19)
  f.nowMain = W.Font(now, 13, W.C.ink)
  f.nowMain:SetPoint("LEFT", f.nowIcon, "RIGHT", 6, 0)
  f.nowMain:SetPoint("RIGHT", now, "RIGHT", -10, 0)
  f.nowSub = W.Font(now, 11, W.C.muted)
  f.nowSub:SetPoint("BOTTOMLEFT", 10, 5)
  f.nowSub:SetPoint("RIGHT", now, "RIGHT", -10, 0)
  -- When a trainer, book or quest is due, double-clicking the box points the arrow there.
  local nowButton = CreateFrame("Button", nil, now)
  nowButton:SetAllPoints()
  nowButton:SetScript("OnDoubleClick", function()
    if f.dueStep then ns:MarkTrainer(f.dueStep, f.key) end
  end)
  nowButton:SetScript("OnEnter", function(self)
    if not f.dueStep then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(L.DOUBLE_CLICK_TRAINER, 1, 0.82, 0, 1, true)
    GameTooltip:Show()
  end)
  nowButton:SetScript("OnLeave", GameTooltip_Hide)

  f.stat1 = W.Stat(f, "STAT_TO_TARGET", 200)
  f.stat1:SetPoint("TOPLEFT", 0, -84)
  f.stat2 = W.Stat(f, "STAT_BUY_ALL", 200)
  f.stat2:SetPoint("LEFT", f.stat1, "RIGHT", 8, 0)
  f.stat3 = W.Stat(f, "STAT_YOUR_PLAN", 200)
  f.stat3:SetPoint("LEFT", f.stat2, "RIGHT", 8, 0)

  f.list = W.List(f, {
    { width = 56, header = "COL_SKILL" },
    { width = 330, header = "COL_RECIPE", wrap = true },
    { width = 80, justify = "RIGHT", header = "COL_COST" },
    { width = 90, header = "" },
  }, 36)
  f.list:SetPoint("TOPLEFT", 0, -128)
  f.list:SetPoint("BOTTOMRIGHT", 0, 30)

  f.credit = CreateFrame("Button", nil, f)
  f.credit:SetPoint("BOTTOMLEFT", 0, 4)
  f.credit:SetSize(380, 18)
  f.creditText = W.Font(f.credit, 11, W.C.muted)
  f.creditText:SetAllPoints()
  f.credit:SetScript("OnClick", function()
    if f.guide then ns.Print(L.GUIDE_LINK:format(f.guide)) end
  end)
  f.credit:SetScript("OnEnter", function(self)
    if not f.guide then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(f.guide)
    GameTooltip:AddLine(L.CREDIT_TIP, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  f.credit:SetScript("OnLeave", GameTooltip_Hide)

  f.planButton = W.Button(f, "BUY_OR_FARM", 140, function() view:ShowPlan() end)
  f.planButton:SetPoint("BOTTOMRIGHT", 0, 0)

  f.noRoute = W.Font(f, 13, W.C.muted, "CENTER")
  f.noRoute:SetPoint("TOPLEFT", 20, -140)
  f.noRoute:SetPoint("TOPRIGHT", -20, -140)
  f.noRoute:SetWordWrap(true)

  function f:Refresh(key)
    local info = ns.ProfessionInfo[key]
    local route = ns.Routes[key]
    local skill = ns.skills and ns.skills[key]
    self.icon:SetTexture(info.icon)
    self.name:SetText(ns.ProfName(key))
    self.skill:SetText(skill and (skill.rank .. " / " .. skill.max) or L.NOT_LEARNED)
    self.bar:SetValue(skill and skill.rank / math.max(skill.max, 1) or 0)
    self.guide = route and route.guide or info.guide

    if not route then
      self.list:Hide()
      self.planButton:Hide()
      self.noRoute:SetText(L.NO_ROUTE:format(ns.ProfName(key)))
      self.noRoute:Show()
      self.nowMain:SetText("-")
      self.nowSub:SetText("")
      self.nowIcon:Hide()
      self.stat1:Set(nil); self.stat2:Set(nil); self.stat3:Set(nil)
      self.creditText:SetText(self.guide and ns.Color(MUTED, L.CREDIT_GUIDE) or "")
      return
    end
    self.noRoute:Hide()
    self.list:Show()
    self.planButton:SetShown(not route.gather)

    local rows, rank, due = ns:EvaluateRoute(key)
    local target = ns:RouteTarget(key, rank)
    local hideDone = ns.db.settings.prof.hideDone
    local data, current, nextRow = {}, nil, nil
    for i, r in ipairs(rows) do
      local s = r.step
      if r.status == "current" then current = r end
      if current and r ~= current and not nextRow and not s.mile then nextRow = r end
      if not (hideDone and r.status == "done") then
        local tones = { mile = "mile", due = "current", current = "current", done = "done" }
        local d = { cells = {}, tone = tones[r.status] }
        if s.mile then
          d.cells[1] = tostring(s.at)
          d.cells[2] = mileTitle(s) .. "\n|cff" .. MUTED .. mileSub(s) .. "|r"
          d.cells[3] = ""
          if r.status == "done" then d.cells[4] = W.Pill("done")
          elseif r.status == "due" then d.cells[4] = ns.Color("gold", L.DUE_NOW:upper())
          else d.cells[4] = W.Pill(s.mile) end
          d.tip = { mileTitle(s), mileSub(s), ns.Color("gold", L.DOUBLE_CLICK_TRAINER) }
          d.onDoubleClick = function() ns:MarkTrainer(s, key) end
        elseif s.options then
          local o = r.option
          local frac = r.frac > 0 and r.frac or 1
          local lines = {}
          for _, c in ipairs(o.crafts) do
            local n = math.ceil(c.count * frac)
            lines[#lines + 1] = ns.Color(MUTED, n .. "×") .. " " .. ns.T(c.name)
          end
          local sub = {}
          for _, c in ipairs(o.crafts) do sub[#sub + 1] = reagentText(c.reagents, math.ceil(c.count * frac)) end
          local text = table.concat(lines, " + ") .. "\n|cff" .. MUTED .. table.concat(sub, " · ")
          if r.untested then text = text .. " · " .. L.UNTESTED end
          text = text .. "|r"
          d.cells[1] = s.from .. "-" .. s.to
          d.cells[2] = text
          d.cells[3] = r.status ~= "done" and ns.Money(r.cost) or ""
          d.icon, d.iconCol = optionIcon(o), 2
          local cheapest = #s.options > 1 and r.cost ~= nil
          if r.status == "done" then d.cells[4] = W.Pill("done")
          elseif r.status == "current" then d.cells[4] = W.Pill("current")
          elseif cheapest then d.cells[4] = W.Pill("cheapest")
          else d.cells[4] = "" end
          -- Tooltip lists every option with its cost.
          if #s.options > 1 then
            d.tip = { L.OPTIONS_TITLE }
            for oi, opt in ipairs(s.options) do
              local cost = r.costs and r.costs[oi]
              d.tip[#d.tip + 1] = (opt == o and "> " or "   ") .. optionName(opt) .. ": " .. (cost and ns.Money(cost) or L.NO_PRICE)
            end
          end
        else
          d.cells[1] = s.from .. "-" .. s.to
          local text = zonesText(s.zones, 4)
          local sub = itemsText(s.items)
          if s.note then sub = sub .. " · " .. ns.T(s.note) end
          if r.untested then sub = sub .. " · " .. L.UNTESTED end
          d.cells[2] = text .. "\n|cff" .. MUTED .. sub .. "|r"
          local best = 0
          for _, id in ipairs(s.items or {}) do best = math.max(best, ns.Market(id) or 0) end
          d.cells[3] = best > 0 and ns.Money(best) or ""
          d.icon, d.iconCol = s.items and ns.ItemIcon(s.items[1]) or nil, 2
          d.cells[4] = r.status == "done" and W.Pill("done") or (r.status == "current" and W.Pill("current") or "")
          local zone = ns:FirstZone(s.zones)
          d.tip = { ns.ZoneName(zone), itemsText(s.items), ns.Color("gold", L.CLICK_TO_MARK) }
          d.onClick = function() ns:SetWaypoint(zone, s.items, itemsText({ s.items[1] })) end
        end
        data[#data + 1] = d
      end
    end
    self.list:SetData(data)

    -- Leveling now. A due trainer, book or quest comes first: without it the skill is capped.
    local skillMax = ns:SkillMax(key)
    self.key, self.dueStep = key, nil
    if due and (not current or rank >= skillMax - 5) then
      self.dueStep = due.step
      local s = due.step
      self.nowIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
      self.nowIcon:Show()
      self.nowMain:SetText(ns.Color("gold", L.GO_NOW:format(mileTitle(s))))
      self.nowSub:SetText(L.CAPPED:format(rank, skillMax) .. " · " .. (whoText(s.who) or L.ANY_TRAINER))
    elseif current then
      local s = current.step
      if s.options then
        local o = current.option
        local c = o.crafts[1]
        self.nowIcon:SetTexture(optionIcon(o))
        self.nowMain:SetText(ns.Color(MUTED, math.ceil(c.count * current.frac) .. "×") .. " " .. optionName(o))
        local sub = L.NOW_RANGE:format(math.max(rank, s.from), s.to) .. " · " .. L.CRAFTS_LEFT:format(current.left or 0)
        if nextRow and nextRow.option then sub = sub .. " · " .. L.THEN:format(optionName(nextRow.option)) end
        self.nowSub:SetText(sub)
      else
        self.nowIcon:SetTexture(s.items and ns.ItemIcon(s.items[1]) or info.icon)
        self.nowMain:SetText(itemsText(s.items) .. " · " .. zonesText(s.zones, 1))
        local sub = L.NOW_RANGE:format(math.max(rank, s.from), s.to)
        if nextRow and nextRow.step.items then sub = sub .. " · " .. L.THEN:format(itemsText({ nextRow.step.items[1] })) end
        self.nowSub:SetText(sub)
      end
      self.nowIcon:Show()
    else
      self.nowIcon:Hide()
      self.nowMain:SetText(L.ROUTE_DONE)
      self.nowSub:SetText("")
    end

    -- Summary
    self.stat1.label:SetText(L.STAT_TO_TARGET:format(target))
    self.stat1:Set(L.POINTS:format(math.max(target - rank, 0)))
    if route.gather then
      self.stat2.label:SetText(L.STAT_NEXT_MILESTONE)
      local mileText
      for _, r in ipairs(rows) do
        if r.step.mile and (r.status == "mile" or r.status == "due") then mileText = mileTitle(r.step) .. " · " .. r.step.at; break end
      end
      self.stat2:Set(mileText or "-")
      self.stat3.label:SetText(L.STAT_GATHER_GPH)
      local cat = ns.CategoryByKey[GATHER_CATEGORY[key]]
      local gph
      if cat then
        for _, tier in ipairs(cat.tiers) do
          if rank >= (tier.skill or 1) then gph = ns:EvalTier(tier) end
        end
      end
      self.stat3:Set(gph and gph > 0 and (ns.Gold(gph) .. "/h") or nil, W.C.up)
    else
      self.stat2.label:SetText(L.STAT_BUY_ALL)
      self.stat3.label:SetText(L.STAT_YOUR_PLAN)
      local list = ns:ProfessionNeeds(key)
      local plan = ns:Plan(list, ns.db.settings.prof.budgetCopper)
      self.stat2:Set(ns.Money(plan.allBuy))
      self.stat3:Set(ns.Money(plan.gold) .. ns.Color(MUTED, " + " .. ns.Duration(plan.minutes)))
    end

    if self.guide then
      self.creditText:SetText(ns.Color(MUTED, L.CREDIT))
    else
      self.creditText:SetText(ns.Color(MUTED, L.CREDIT_STANDARD))
    end
  end

  return f
end

-- Buy or farm subview ----------------------------------------------------------

local function buildPlan(parent, view)
  local f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints()

  local back = W.Button(f, "BACK", 90, function() view:ShowRoute() end)
  back:SetPoint("TOPLEFT", 0, 0)
  f.title = W.Font(f, 14, W.C.gold)
  f.title:SetPoint("LEFT", back, "RIGHT", 10, 0)

  f.stat1 = W.Stat(f, "STAT_GOLD", 200)
  f.stat1:SetPoint("TOPLEFT", 0, -30)
  f.stat2 = W.Stat(f, "STAT_PLAN_SPEND", 200)
  f.stat2:SetPoint("LEFT", f.stat1, "RIGHT", 8, 0)
  f.stat3 = W.Stat(f, "STAT_PLAN_FARM", 200)
  f.stat3:SetPoint("LEFT", f.stat2, "RIGHT", 8, 0)

  local budgetLabel = W.Font(f, 12, W.C.ink)
  budgetLabel:SetPoint("TOPLEFT", 0, -82)
  W.Label(budgetLabel, "BUDGET")
  f.budget = W.Money(f, function(copper)
    f.budgetValue = copper
    f:Refresh()
  end)
  f.budget:SetPoint("LEFT", budgetLabel, "RIGHT", 4, 0)

  f.extremes = W.Chips(f, function(v)
    f.budgetValue = v == "all" and math.ceil(f.allBuy or 0) or 0
    f.budget:SetValue(f.budgetValue)
    f:Refresh()
  end)
  f.extremes:SetPoint("TOPRIGHT", 0, -80)
  f.extremes:SetItems({ { value = "none", key = "FARM_ALL" }, { value = "all", key = "BUY_ALL" } })

  f.list = W.List(f, {
    { width = 190, header = "COL_REAGENT" },
    { width = 50, justify = "RIGHT", header = "COL_NEEDED" },
    { width = 80, justify = "RIGHT", header = "COL_UNIT_PRICE" },
    { width = 56, justify = "RIGHT", header = "COL_BUY" },
    { width = 56, justify = "RIGHT", header = "COL_FARM" },
    { width = 80, header = "COL_DECISION" },
  }, 22)
  f.list:SetPoint("TOPLEFT", 0, -108)
  f.list:SetPoint("BOTTOMRIGHT", 0, 30)

  f.compare = W.Font(f, 11, W.C.muted)
  f.compare:SetPoint("BOTTOMLEFT", 0, 6)
  f.compare:SetPoint("RIGHT", -170, 0)
  f.compare:SetWordWrap(true)

  f.search = W.Button(f, "CREATE_AH_LIST", 160, function() f:CreateList() end, "primary")
  f.search:SetPoint("BOTTOMRIGHT", 0, 0)

  -- Checked reagents go to the shopping list. Until you change a box, the ones the plan
  -- buys are checked. Vendor items are not sold at the Auction House.
  local function canPick(e) return not e.vendor and type(e.id) == "number" end
  local function picked(e)
    if f.picked[e.id] ~= nil then return f.picked[e.id] end
    return e.buy > 0
  end

  function f:Open(key)
    self.key = key
    self.picked = {}
    self.budgetValue = ns.db.settings.prof.budgetCopper
    self.budget:SetValue(self.budgetValue)
    self:Refresh()
  end

  function f:Refresh()
    local key = self.key
    if not key then return end
    local list, target = ns:ProfessionNeeds(key)
    local plan = ns:Plan(list, self.budgetValue)
    self.list_ = list
    self.allBuy = plan.allBuy
    self.title:SetText(L.PLAN_TITLE:format(ns.ProfName(key), target))
    self.stat1:Set(ns.Money(GetMoney()))
    self.stat2:Set(ns.Money(plan.gold))
    self.stat3:Set(plan.minutes > 0 and ns.Duration(plan.minutes) or L.NONE)
    local data, any = {}, false
    for _, e in ipairs(list) do
      local check
      if canPick(e) then
        check = picked(e)
        any = any or check
      end
      local unit = e.unit and ns.Money(e.unit) or ns.Color("muted", "-")
      if e.method == "make" then unit = unit .. ns.Color(MUTED, "*") end
      data[#data + 1] = {
        itemID = e.id, icon = ns.ItemIcon(e.id),
        cells = {
          ns.ItemName(e.id), ns.Num(e.miss), unit,
          e.buy > 0 and ns.Num(e.buy) or "-", e.farm > 0 and ns.Num(e.farm) or "-",
          W.Pill(e.decision),
        },
        sort = { ns.ItemName(e.id), e.miss, e.unit, e.buy, e.farm, e.decision },
        onClick = function() view:ShowReagent(e) end,
        check = check,
        onCheck = function(_, on)
          self.picked[e.id] = on
          self:Refresh()
        end,
      }
    end
    self.list:SetData(data, L.NOTHING_NEEDED)
    self.compare:SetText(L.COMPARE:format(ns.PlainMoney(plan.allBuy), ns.Duration(plan.allFarm)) .. "  " .. L.MAKE_NOTE)
    self.search:SetEnabled(any)
  end

  -- Puts the checked reagents on the Auction House shopping list. With the Auction House
  -- open it also searches them and opens the panel's Professions tab.
  function f:CreateList()
    local items, ids = {}, {}
    for _, e in ipairs(self.list_ or {}) do
      if canPick(e) and picked(e) then
        items[#items + 1] = { id = e.id, qty = e.buy > 0 and e.buy or e.miss }
        ids[#ids + 1] = e.id
      end
    end
    if #items == 0 then return end
    ns:AddToShopping(items)
    if not ns.ahOpen then
      ns.Print(L.SHOPPING_ADDED:format(#items))
      return
    end
    ns:ShowAuctionTab("shopping")
    if ns.scan.state == "idle" then
      ns:QuickSearch(ids, function() ns:Fire("SHOPPING") end)
    end
  end

  return f
end

-- Reagent subview ----------------------------------------------------------------

local function buildReagent(parent, view)
  local f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints()

  local back = W.Button(f, "BACK", 90, function() view:ShowPlan(true) end)
  back:SetPoint("TOPLEFT", 0, 0)
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(24, 24)
  f.icon:SetPoint("LEFT", back, "RIGHT", 10, 0)
  f.title = W.Font(f, 15, W.C.ink)
  f.title:SetPoint("LEFT", f.icon, "RIGHT", 6, 0)

  f.info = W.Font(f, 12, W.C.muted)
  f.info:SetPoint("TOPLEFT", 0, -32)
  f.info:SetPoint("RIGHT", 0, 0)
  f.info:SetWordWrap(true)

  local h1 = W.Font(f, 13, W.C.gold)
  h1:SetPoint("TOPLEFT", 0, -60)
  W.Label(h1, "BUY_OR_MAKE")
  f.options = W.List(f, {
    { width = 290, header = "COL_OPTION" },
    { width = 100, justify = "RIGHT", header = "COL_COST" },
    { width = 70, justify = "RIGHT", header = "COL_TIME" },
    { width = 90, header = "" },
  }, 22)
  f.options:SetPoint("TOPLEFT", 0, -78)
  f.options:SetPoint("TOPRIGHT", 0, -78)
  f.options:SetHeight(92)

  local h2 = W.Font(f, 13, W.C.gold)
  h2:SetPoint("TOPLEFT", 0, -180)
  W.Label(h2, "WHERE_TO_FARM")
  f.h2 = h2

  f.vendors = W.List(f, {
    { width = 210, header = "COL_VENDOR" },
    { width = 170, header = "COL_ZONE" },
    { width = 70, justify = "RIGHT", header = "COL_COORDS" },
    { width = 70, justify = "RIGHT", header = "COL_DISTANCE" },
  }, 22)
  f.vendors:SetPoint("TOPLEFT", 0, -198)
  f.vendors:SetPoint("BOTTOMRIGHT", 0, 30)
  f.vendors:Hide()
  f.zones = W.List(f, {
    { width = 240, header = "COL_ZONE" },
    { width = 70, justify = "RIGHT", header = "COL_LEVEL" },
    { width = 90, header = "COL_FACTION" },
    { width = 110, justify = "RIGHT", header = "COL_SPOTS" },
  }, 22)
  f.zones:SetPoint("TOPLEFT", 0, -198)
  f.zones:SetPoint("BOTTOMRIGHT", 0, 30)

  f.credit = W.Font(f, 11, W.C.muted)
  f.credit:SetPoint("BOTTOMLEFT", 0, 6)
  W.Label(f.credit, "CREDIT_ZONES")

  function f:Open(e)
    self.entry = e
    self:Refresh()
  end

  function f:Refresh()
    local e = self.entry
    if not e then return end
    self.icon:SetTexture(ns.ItemIcon(e.id))
    self.title:SetText(ns.ItemName(e.id))
    local r = ns.Reagents[e.id]
    local info = L.MISSING:format(e.miss)
    if r and r.make then
      local parts = {}
      for _, input in ipairs(r.make.inputs) do parts[#parts + 1] = input[2] .. " " .. ns.ItemName(input[1]) end
      info = info .. " · " .. L.MADE_FROM:format(table.concat(parts, " + "), r.make.yield)
      if r.make.skill then
        local ok = ns:CanMake(r.make)
        local req = L.REQUIRES:format(ns.ProfName(r.make.skill[1]), r.make.skill[2])
        info = info .. " (" .. (ok and ns.Color("up", req) or ns.Color("down", req)) .. ")"
      end
    end
    self.info:SetText(info)

    local data = {}
    local buy = ns.Price(e.id)
    local vendor = r and r.vendor and ns.VendorBuyPrice(e.id)
    local make = ns:MakeCost(e.id)
    local farmMin = ns:FarmMinutes(e.id)
    local best = math.huge
    for _, v in ipairs({ vendor or math.huge, buy or math.huge, (make and r.make and ns:CanMake(r.make)) and make or math.huge }) do
      best = math.min(best, v)
    end
    if vendor then
      data[#data + 1] = { cells = { L.OPT_VENDOR, ns.Money(vendor * e.miss), "-", W.Pill("cheapest") }, tone = "top" }
    end
    data[#data + 1] = { cells = { L.OPT_BUY, buy and ns.Money(buy * e.miss) or L.NO_PRICE, "-", buy == best and W.Pill("cheapest") or "" },
      tone = buy == best and "top" or nil }
    if r and r.make then
      local canMake = ns:CanMake(r.make)
      data[#data + 1] = {
        cells = { L.OPT_MAKE .. (canMake and "" or ns.Color("down", " (" .. L.CANT_MAKE .. ")")),
          make and ns.Money(make * e.miss) or L.NO_PRICE, "-", (canMake and make == best) and W.Pill("cheapest") or "" },
        tone = (canMake and make == best) and "top" or nil,
      }
    end
    if farmMin then
      data[#data + 1] = { cells = { L.OPT_FARM, ns.Money(0), ns.Duration(farmMin * e.miss), "" } }
    end
    self.options:SetData(data)

    -- Vendor items: where to buy, nearest vendor of your faction first.
    self.credit:SetText((r and r.vendor) and L.CREDIT_VENDORS or L.CREDIT_ZONES)
    if r and r.vendor then
      self.h2:SetText(L.WHERE_TO_BUY)
      self.zones:Hide()
      self.vendors:Show()
      local rows = {}
      for i, v in ipairs(ns:VendorSpots(e.id)) do
        local zone = ns.ZoneName(v.map)
        rows[#rows + 1] = {
          cells = { v.name, zone, string.format("%.0f, %.0f", v.x * 100, v.y * 100),
            v.dist and L.YARDS:format(ns.Num(v.dist)) or ns.Color("muted", L.FAR_AWAY) },
          sort = { v.name, zone, nil, v.dist },
          tone = i == 1 and "top" or nil,
          colors = not v.dist and { W.C.muted, W.C.muted, W.C.muted } or nil,
          tip = { v.name, zone .. string.format("  %.1f, %.1f", v.x * 100, v.y * 100), ns.Color("gold", L.CLICK_TO_MARK) },
          onClick = function() ns:SetWaypoint(v.map, nil, v.name, v.x, v.y) end,
        }
      end
      self.vendors:SetData(rows, L.NO_VENDORS)
      return
    end
    self.h2:SetText(L.WHERE_TO_FARM)
    self.vendors:Hide()
    self.zones:Show()

    local zones = {}
    local faction = ns.PlayerFaction()
    local list = ns:FarmZones(e.id) or {}
    -- Your faction first, then your continent; otherwise keep the data order.
    local here = ns.PlayerContinent()
    local ordered = {}
    for i, z in ipairs(list) do
      local score = ((z[3] == "B" or z[3] == faction) and 2 or 0) + ((here and ns.ContinentOf(z[1]) == here) and 1 or 0)
      ordered[#ordered + 1] = { z = z, score = score, i = i }
    end
    table.sort(ordered, function(a, b)
      if a.score ~= b.score then return a.score > b.score end
      return a.i < b.i
    end)
    for i, o in ipairs(ordered) do ordered[i] = o.z end
    local raw = ns:RawItems(e.id)
    local title = ns.ItemName(e.id)
    for i, z in ipairs(ordered) do
      local fac = z[3] == "B" and L.FACTION_BOTH or (z[3] == "H" and L.FACTION_HORDE or L.FACTION_ALLIANCE)
      local spots = #ns:SpotsIn(z[1], raw)
      local node = ns:NodeEntry(z[1], raw)
      local nodes = node and node[3] or 0
      local tip = { ns.ZoneName(z[1]) }
      if nodes > 0 then tip[#tip + 1] = L.NODES_TIP:format(nodes) end
      tip[#tip + 1] = spots > 0 and L.SPOTS_TIP:format(spots) or L.NO_SPOTS_TIP
      tip[#tip + 1] = ns.Color("gold", L.CLICK_TO_MARK)
      zones[#zones + 1] = {
        cells = { ns.ZoneName(z[1]), z[2], fac, nodes > 0 and ns.Num(nodes) or (spots > 0 and ns.Num(spots) or ns.Color("muted", "-")) },
        sort = { ns.ZoneName(z[1]), tonumber(z[2]:match("%d+")), fac, nodes > 0 and nodes or spots },
        tone = i == 1 and "top" or nil,
        colors = (z[3] ~= "B" and z[3] ~= faction) and { W.C.muted, W.C.muted, W.C.muted } or nil,
        tip = tip,
        onClick = function() ns:SetWaypoint(z[1], raw, title) end,
      }
    end
    self.zones:SetData(zones, L.NO_ZONES)
  end

  return f
end

-- View -----------------------------------------------------------------------------

ns:RegisterView("professions", function(parent)
  local f = CreateFrame("Frame", nil, parent)

  local primaryLabel = W.Font(f, 10, W.C.muted)
  primaryLabel:SetPoint("TOPLEFT", 0, -5)
  primaryLabel:SetWidth(80)
  W.Label(primaryLabel, "PRIMARY")
  local secondaryLabel = W.Font(f, 10, W.C.muted)
  secondaryLabel:SetPoint("TOPLEFT", 0, -29)
  secondaryLabel:SetWidth(80)
  W.Label(secondaryLabel, "SECONDARY")

  local function select(key)
    f.selected = key
    f.primary:Select(key)
    f.secondary:Select(key)
    f:ShowRoute()
  end
  f.primary = W.Chips(f, select)
  f.primary:SetPoint("TOPLEFT", 84, 0)
  f.secondary = W.Chips(f, select)
  f.secondary:SetPoint("TOPLEFT", 84, -24)

  f.empty = W.Font(f, 13, W.C.muted, "CENTER")
  f.empty:SetPoint("TOPLEFT", 20, -120)
  f.empty:SetPoint("TOPRIGHT", -20, -120)
  f.empty:SetWordWrap(true)
  W.Label(f.empty, "NO_PROFESSIONS")

  local body = CreateFrame("Frame", nil, f)
  body:SetPoint("TOPLEFT", 0, -54)
  body:SetPoint("BOTTOMRIGHT")

  f.route = buildRoute(body, f)
  f.plan = buildPlan(body, f)
  f.reagent = buildReagent(body, f)
  f.plan:Hide()
  f.reagent:Hide()
  f.mode = "route"

  function f:ShowRoute()
    self.mode = "route"
    self.plan:Hide()
    self.reagent:Hide()
    self.route:Show()
    self:Refresh()
  end

  function f:ShowPlan(keepBudget)
    self.mode = "plan"
    self.route:Hide()
    self.reagent:Hide()
    self.plan:Show()
    if keepBudget and self.plan.key == self.selected then self.plan:Refresh() else self.plan:Open(self.selected) end
  end

  function f:ShowReagent(entry)
    self.mode = "reagent"
    self.route:Hide()
    self.plan:Hide()
    self.reagent:Show()
    self.reagent:Open(entry)
  end

  function f:Refresh()
    pcall(ns.ReadSkills, ns)
    local primary, secondary = ns:ProfessionList()
    local items1, items2 = {}, {}
    for _, k in ipairs(primary) do items1[#items1 + 1] = { value = k, text = ns.ProfName(k) } end
    for _, k in ipairs(secondary) do items2[#items2 + 1] = { value = k, text = ns.ProfName(k) } end
    f.primary:SetItems(items1)
    f.secondary:SetItems(items2)
    if #items1 + #items2 == 0 then
      f.empty:Show()
      body:Hide()
      return
    end
    f.empty:Hide()
    body:Show()
    local valid = false
    for _, k in ipairs(primary) do if k == self.selected then valid = true end end
    for _, k in ipairs(secondary) do if k == self.selected then valid = true end end
    if not valid then
      self.selected = nil
      for _, k in ipairs(primary) do if not self.selected and ns.Routes[k] then self.selected = k end end
      self.selected = self.selected or primary[1] or secondary[1]
      self.mode = "route"
      self.plan:Hide()
      self.reagent:Hide()
      self.route:Show()
    end
    f.primary:Select(self.selected)
    f.secondary:Select(self.selected)
    if self.mode == "route" then self.route:Refresh(self.selected)
    elseif self.mode == "plan" then self.plan:Refresh()
    else self.reagent:Refresh() end
  end

  return f
end)
