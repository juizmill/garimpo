local _, ns = ...
local L, W = ns.L, ns.W

-- Settings in two columns: name on the left, control on the right. Explanations live in
-- a "(?)" tooltip on the name instead of text between the rows.
local LABEL_W, CTRL_X, ROW = 230, 240, 28

ns:RegisterView("config", function(parent)
  local f = CreateFrame("Frame", nil, parent)
  local S = function() return ns.db.settings end

  local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 0, 0)
  sf:SetPoint("BOTTOMRIGHT", -24, 30)
  local c = CreateFrame("Frame", nil, sf)
  c:SetSize(580, 800)
  sf:SetScrollChild(c)

  local y = 0
  local checks, edits, chips, moneys = {}, {}, {}, {}

  local function header(key)
    local h = W.Font(c, 13, W.C.gold)
    h:SetPoint("TOPLEFT", 0, y - 4)
    W.Label(h, key)
    local line = W.Line(c)
    line:SetPoint("TOPLEFT", 0, y - 22)
    line:SetPoint("TOPRIGHT", 0, y - 22)
    y = y - 30
  end

  local function tooltip(owner, titleKey, tipKey)
    owner:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(L[titleKey], 1, 0.82, 0)
      GameTooltip:AddLine(L[tipKey], 1, 1, 1, true)
      GameTooltip:Show()
    end)
    owner:SetScript("OnLeave", GameTooltip_Hide)
  end

  -- Name of a row, with "(?)" and a tooltip when tipKey is given.
  local function name(key, tipKey)
    local holder = CreateFrame("Frame", nil, c)
    holder:SetPoint("TOPLEFT", 0, y)
    holder:SetSize(LABEL_W, 22)
    local fs = W.Font(holder, 12, W.C.ink)
    fs:SetPoint("LEFT")
    W.Label(fs, key)
    if tipKey then
      local q = W.Font(holder, 11, W.C.muted)
      q:SetPoint("LEFT", fs, "RIGHT", 4, 0)
      q:SetText("(?)")
      holder:EnableMouse(true)
      tooltip(holder, key, tipKey)
    end
  end

  local function check(key, tipKey, get, set)
    local cb = W.Check(c, key, function(on)
      set(on)
      ns:RefreshCurrent()
    end)
    cb:SetPoint("TOPLEFT", -2, y)
    cb.get = get
    if tipKey then
      local q = W.Font(cb, 11, W.C.muted)
      q:SetPoint("LEFT", cb.label, "RIGHT", 4, 0)
      q:SetText("(?)")
      tooltip(cb, key, tipKey)
    end
    checks[#checks + 1] = cb
    y = y - 26
  end

  local function number(key, tipKey, suffix, get, set)
    name(key, tipKey)
    local e = W.Edit(c, 50, function(text)
      local v = tonumber(text)
      if v then set(v) end
    end)
    e:SetPoint("TOPLEFT", CTRL_X + 6, y)
    local s = W.Font(c, 12, W.C.muted)
    s:SetPoint("LEFT", e, "RIGHT", 4, 0)
    s:SetText(suffix)
    e.get = get
    edits[#edits + 1] = e
    y = y - ROW
  end

  local function money(key, tipKey, get, set)
    name(key, tipKey)
    local m = W.Money(c, set)
    m:SetPoint("TOPLEFT", CTRL_X, y)
    m.get = get
    moneys[#moneys + 1] = m
    y = y - ROW
  end

  local function choice(key, tipKey, items, get, set)
    name(key, tipKey)
    local g = W.Chips(c, set)
    g:SetPoint("TOPLEFT", CTRL_X, y)
    g:SetItems(items)
    g.get = get
    chips[#chips + 1] = g
    y = y - ROW
    return g
  end

  -- General ---------------------------------------------------------------------------
  header("CFG_GENERAL")
  choice("CFG_LANGUAGE", nil, {
    { value = "auto", key = "LANG_AUTO" }, { value = "ptBR", text = "Português" }, { value = "enUS", text = "English" },
  }, function() return S().language end, function(v)
    S().language = v
    ns:ApplyLanguage()
  end)
  check("CFG_TOOLTIP", nil, function() return S().tooltip end, function(on) S().tooltip = on end)
  check("CFG_MINIMAP", nil, function() return not S().minimap.hide end, function(on)
    S().minimap.hide = not on
    ns:UpdateMinimapButton()
  end)
  check("CFG_ARROW", nil, function() return S().waypoint.arrow end, function(on)
    S().waypoint.arrow = on
    if not on then ns:ClearWaypoint() end
  end)
  check("CFG_NATIVE_WAYPOINT", nil, function() return S().waypoint.native end,
    function(on) S().waypoint.native = on end)
  y = y - 8

  -- Auction House: posting, scanning and deals in one place ----------------------------
  header("CFG_AH")
  check("CFG_OPEN_WITH_AH", nil, function() return S().openWithAH end, function(on) S().openWithAH = on end)
  check("CFG_SCAN_AUTO", "CFG_SCAN_HINT", function() return S().scan.auto end, function(on) S().scan.auto = on end)
  choice("CFG_AH_CUT", "CFG_AH_CUT_HINT", {
    { value = 5, key = "AH_FACTION" }, { value = 15, key = "AH_NEUTRAL" },
  }, function() return S().deals.ahCut end, function(v)
    S().deals.ahCut = v
    f:UpdateExample()
    ns:FindDeals()
  end)

  -- Selling
  choice("CFG_DURATION", nil, { { value = 1, text = "12h" }, { value = 2, text = "24h" }, { value = 3, text = "48h" } },
    function() return S().duration end, function(v) S().duration = v end)
  number("CFG_DEFAULT_MARGIN", "CFG_MARGIN_HINT", "%", function() return S().defaultMargin end,
    function(v) S().defaultMargin = math.max(-90, v) end)
  number("CFG_BID", "CFG_BID_TIP", "%", function() return S().bidPercent end,
    function(v) S().bidPercent = math.max(1, math.min(100, v)) end)

  -- Buying (deals)
  number("CFG_DEAL_SPREAD", "CFG_SPREAD_HINT", "%", function() return S().deals.spread end, function(v)
    S().deals.spread = math.max(0, math.min(500, v))
    f:UpdateExample()
    ns:FindDeals()
  end)
  money("CFG_DEAL_PROFIT", "CFG_PROFIT_TIP", function() return S().deals.minProfitCopper end, function(v)
    S().deals.minProfitCopper = v
    f:UpdateExample()
    ns:FindDeals()
  end)
  -- One line that puts the numbers together.
  local example = W.Font(c, 11, W.C.gold)
  example:SetPoint("TOPLEFT", 0, y + 2)
  example:SetPoint("RIGHT", c, "RIGHT", 0, 0)
  example:SetWordWrap(true)
  y = y - 34
  function f:UpdateExample()
    local ref = 100000
    local keep = ref * ns.SaleKeep()
    example:SetText(L.CFG_DEAL_EXAMPLE:format(ns.PlainMoney(ns.MaxBuyPrice(ref)), ns.PlainMoney(keep),
      ns.PlainMoney(S().deals.minProfitCopper)))
  end

  check("CFG_DEAL_HISTORY", "CFG_DEAL_HISTORY_TIP", function() return S().deals.requireHistory end, function(on)
    S().deals.requireHistory = on
    ns:FindDeals()
  end)
  check("CFG_DEAL_GEAR", nil, function() return S().deals.gear end, function(on)
    S().deals.gear = on
    ns:FindDeals()
  end)
  check("CFG_SHOW_HOLD", nil, function() return S().showHold end, function(on) S().showHold = on end)

  -- Sale sound
  check("CFG_SALE_SOUND", nil, function() return S().sale.sound end, function(on) S().sale.sound = on end)
  local kind = choice("CFG_SALE_KIND", nil, { { value = "register", key = "SOUND_REGISTER" }, { value = "coins", key = "SOUND_COINS" } },
    function() return S().sale.kind end, function(v) S().sale.kind = v end)
  local test = W.Button(c, "SOUND_TEST", 80, function() ns:PlaySaleSound(true) end)
  test:SetHeight(20)
  test:SetPoint("LEFT", kind, "RIGHT", 8, 0)

  -- Markup per category, two per row
  name("CFG_CATEGORY_MARGIN", "CFG_CATEGORY_HINT")
  y = y - 24
  for i, cat in ipairs(ns.Categories) do
    local col = (i - 1) % 2
    local fs = W.Font(c, 12, W.C.muted)
    fs:SetPoint("TOPLEFT", 16 + col * 290, y - 4)
    fs:SetWidth(140)
    W.OnRelabel(function() fs:SetText(ns.T(cat.name)) end)
    fs:SetText(ns.T(cat.name))
    local e = W.Edit(c, 50, function(text)
      local v = tonumber(text)
      S().categoryMargin[cat.key] = v and math.max(-90, v) or nil
    end)
    e:SetPoint("TOPLEFT", 16 + col * 290 + 150, y)
    e.get = function() return S().categoryMargin[cat.key] end
    edits[#edits + 1] = e
    local pct = W.Font(c, 12, W.C.muted)
    pct:SetPoint("LEFT", e, "RIGHT", 4, 0)
    pct:SetText("%")
    if col == 1 or i == #ns.Categories then y = y - 26 end
  end
  y = y - 8

  -- Professions -------------------------------------------------------------------------
  header("CFG_PROFESSIONS")
  money("CFG_BUDGET", "CFG_BUDGET_HINT", function() return S().prof.budgetCopper end,
    function(v) S().prof.budgetCopper = v end)
  choice("CFG_TARGET", nil, { { value = "trainer", key = "TARGET_TRAINER" }, { value = "max", key = "TARGET_MAX" } },
    function() return S().prof.target end, function(v)
      S().prof.target = v
      ns:RefreshCurrent()
    end)
  check("CFG_USE_BANK", nil, function() return S().prof.useBank end, function(on) S().prof.useBank = on end)
  check("CFG_CRAFT", nil, function() return S().prof.craft end, function(on) S().prof.craft = on end)
  check("CFG_HIDE_DONE", nil, function() return S().prof.hideDone end, function(on) S().prof.hideDone = on end)
  check("CFG_SHOW_UNLEARNED", nil, function() return S().prof.showUnlearned end,
    function(on) S().prof.showUnlearned = on end)
  y = y - 8

  -- Data --------------------------------------------------------------------------------
  header("CFG_DATA")
  local resetFarm = W.Button(c, "CFG_RESET_FARM", 200, function()
    wipe(ns.db.farm)
    ns.Print(L.FARM_RESET_DONE)
  end)
  resetFarm:SetPoint("TOPLEFT", 0, y)
  tooltip(resetFarm, "CFG_RESET_FARM", "CFG_RESET_FARM_HINT")
  y = y - ROW
  c:SetHeight(-y + 10)

  local credit = W.Font(f, 11, W.C.muted)
  credit:SetPoint("BOTTOMLEFT", 0, 6)
  W.Label(credit, "CFG_FOOT")

  local restore = W.Button(f, "CFG_RESTORE", 150, function()
    ns:ResetSettings()
    ns:ApplyLanguage()
    ns:UpdateMinimapButton()
    f:Refresh()
  end)
  restore:SetPoint("BOTTOMRIGHT", 0, 0)

  function f:Refresh()
    for _, cb in ipairs(checks) do cb:SetChecked(cb.get() and true or false) end
    for _, e in ipairs(edits) do
      if not e:HasFocus() then
        local v = e.get()
        e:SetText(v ~= nil and tostring(v) or "")
      end
    end
    for _, g in ipairs(chips) do g:Select(g.get()) end
    for _, m in ipairs(moneys) do
      if not m:HasFocus() then m:SetValue(m.get()) end
    end
    self:UpdateExample()
  end

  return f
end)
