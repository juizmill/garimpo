local _, ns = ...
local L, W = ns.L, ns.W

ns:RegisterView("config", function(parent)
  local f = CreateFrame("Frame", nil, parent)
  local S = function() return ns.db.settings end

  local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 0, 0)
  sf:SetPoint("BOTTOMRIGHT", -24, 30)
  local c = CreateFrame("Frame", nil, sf)
  c:SetSize(580, 640)
  sf:SetScrollChild(c)

  local y = 0
  local function header(key)
    local h = W.Font(c, 13, W.C.gold)
    h:SetPoint("TOPLEFT", 0, y - 4)
    W.Label(h, key)
    local line = W.Line(c)
    line:SetPoint("TOPLEFT", 0, y - 22)
    line:SetPoint("TOPRIGHT", 0, y - 22)
    y = y - 30
  end
  local function label(key, x)
    local fs = W.Font(c, 12, W.C.ink)
    fs:SetPoint("TOPLEFT", x or 0, y - 4)
    W.Label(fs, key)
    return fs
  end
  local function hint(key)
    local fs = W.Font(c, 11, W.C.muted)
    fs:SetPoint("TOPLEFT", 0, y)
    fs:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    fs:SetWordWrap(true)
    W.Label(fs, key)
    y = y - 20
    return fs
  end
  local function check(key, get, set)
    local cb = W.Check(c, key, function(on)
      set(on)
      ns:RefreshCurrent()
    end)
    cb:SetPoint("TOPLEFT", -2, y)
    cb.get = get
    y = y - 26
    return cb
  end
  local function number(key, width, suffix, get, set, x)
    local fs = label(key, x)
    local e = W.Edit(c, width or 50, function(text)
      local v = tonumber(text)
      if v then set(v) end
    end)
    e:SetPoint("LEFT", fs, "RIGHT", 12, 0)
    local s = W.Font(c, 12, W.C.muted)
    s:SetPoint("LEFT", e, "RIGHT", 4, 0)
    s:SetText(suffix or "")
    e.get = get
    return e
  end

  local checks, edits, chips = {}, {}, {}

  -- General
  header("CFG_GENERAL")
  label("CFG_LANGUAGE")
  local lang = W.Chips(c, function(v)
    S().language = v
    ns:ApplyLanguage()
  end)
  lang:SetPoint("TOPLEFT", 160, y)
  lang:SetItems({
    { value = "auto", key = "LANG_AUTO" }, { value = "ptBR", text = "Português" }, { value = "enUS", text = "English" },
  })
  lang.get = function() return S().language end
  chips[#chips + 1] = lang
  y = y - 28
  checks[#checks + 1] = check("CFG_TOOLTIP", function() return S().tooltip end, function(on) S().tooltip = on end)
  checks[#checks + 1] = check("CFG_MINIMAP", function() return not S().minimap.hide end, function(on)
    S().minimap.hide = not on
    ns:UpdateMinimapButton()
  end)
  checks[#checks + 1] = check("CFG_ARROW", function() return S().waypoint.arrow end, function(on)
    S().waypoint.arrow = on
    if not on then ns:ClearWaypoint() end
  end)
  checks[#checks + 1] = check("CFG_NATIVE_WAYPOINT", function() return S().waypoint.native end,
    function(on) S().waypoint.native = on end)
  y = y - 6

  -- Auction House
  header("CFG_AH")
  edits[#edits + 1] = number("CFG_DEFAULT_MARGIN", 50, "%", function() return S().defaultMargin end,
    function(v) S().defaultMargin = math.max(-90, v) end)
  y = y - 26
  hint("CFG_MARGIN_HINT")
  label("CFG_CATEGORY_MARGIN")
  y = y - 22
  hint("CFG_CATEGORY_HINT")
  for i, cat in ipairs(ns.Categories) do
    local col = (i - 1) % 2
    local fs = W.Font(c, 12, W.C.ink)
    fs:SetPoint("TOPLEFT", col * 290, y - 4)
    fs:SetWidth(150)
    fs.cat = cat
    W.OnRelabel(function() fs:SetText(ns.T(cat.name)) end)
    fs:SetText(ns.T(cat.name))
    local e = W.Edit(c, 50, function(text)
      local v = tonumber(text)
      S().categoryMargin[cat.key] = v and math.max(-90, v) or nil
    end)
    e:SetPoint("TOPLEFT", col * 290 + 160, y)
    e.get = function() return S().categoryMargin[cat.key] end
    e.allowEmpty = true
    edits[#edits + 1] = e
    local pct = W.Font(c, 12, W.C.muted)
    pct:SetPoint("LEFT", e, "RIGHT", 4, 0)
    pct:SetText("%")
    if col == 1 or i == #ns.Categories then y = y - 26 end
  end
  y = y - 4
  label("CFG_DURATION")
  local duration = W.Chips(c, function(v) S().duration = v end)
  duration:SetPoint("TOPLEFT", 160, y)
  duration:SetItems({ { value = 1, text = "12h" }, { value = 2, text = "24h" }, { value = 3, text = "48h" } })
  duration.get = function() return S().duration end
  chips[#chips + 1] = duration
  y = y - 28
  edits[#edits + 1] = number("CFG_BID", 50, "%", function() return S().bidPercent end,
    function(v) S().bidPercent = math.max(1, math.min(100, v)) end)
  y = y - 28
  checks[#checks + 1] = check("CFG_OPEN_WITH_AH", function() return S().openWithAH end, function(on) S().openWithAH = on end)
  checks[#checks + 1] = check("CFG_SHOW_HOLD", function() return S().showHold end, function(on) S().showHold = on end)
  checks[#checks + 1] = check("CFG_SALE_SOUND", function() return S().sale.sound end, function(on) S().sale.sound = on end)
  label("CFG_SALE_KIND")
  local kind = W.Chips(c, function(v) S().sale.kind = v end)
  kind:SetPoint("TOPLEFT", 160, y)
  kind:SetItems({ { value = "register", key = "SOUND_REGISTER" }, { value = "coins", key = "SOUND_COINS" } })
  kind.get = function() return S().sale.kind end
  chips[#chips + 1] = kind
  local test = W.Button(c, "SOUND_TEST", 90, function() ns:PlaySaleSound(true) end)
  test:SetPoint("LEFT", kind, "RIGHT", 10, 0)
  y = y - 30

  -- Professions
  header("CFG_PROFESSIONS")
  edits[#edits + 1] = number("CFG_BUDGET", 60, "g", function() return S().prof.budget end,
    function(v) S().prof.budget = math.max(0, v) end)
  y = y - 26
  hint("CFG_BUDGET_HINT")
  label("CFG_TARGET")
  local target = W.Chips(c, function(v)
    S().prof.target = v
    ns:RefreshCurrent()
  end)
  target:SetPoint("TOPLEFT", 160, y)
  target:SetItems({ { value = "trainer", key = "TARGET_TRAINER" }, { value = "max", key = "TARGET_MAX" } })
  target.get = function() return S().prof.target end
  chips[#chips + 1] = target
  y = y - 28
  checks[#checks + 1] = check("CFG_USE_BANK", function() return S().prof.useBank end, function(on) S().prof.useBank = on end)
  checks[#checks + 1] = check("CFG_CRAFT", function() return S().prof.craft end, function(on) S().prof.craft = on end)
  checks[#checks + 1] = check("CFG_HIDE_DONE", function() return S().prof.hideDone end, function(on) S().prof.hideDone = on end)
  checks[#checks + 1] = check("CFG_SHOW_UNLEARNED", function() return S().prof.showUnlearned end,
    function(on) S().prof.showUnlearned = on end)
  y = y - 6

  -- Data
  header("CFG_DATA")
  local resetFarm = W.Button(c, "CFG_RESET_FARM", 200, function()
    wipe(ns.db.farm)
    ns.Print(L.FARM_RESET_DONE)
  end)
  resetFarm:SetPoint("TOPLEFT", 0, y)
  y = y - 28
  hint("CFG_RESET_FARM_HINT")
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
  end

  return f
end)
