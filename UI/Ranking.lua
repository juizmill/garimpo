local _, ns = ...
local L, W = ns.L, ns.W

local function adviceText(advice)
  return advice and W.Pill(advice) or ns.Color("muted", "-")
end

local function ageText(days)
  if not days then return ns.Color("muted", "-") end
  if days == 0 then return L.TODAY end
  return L.DAYS_AGO:format(days)
end

local function buildDetail(parent, onBack)
  local f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints()

  local back = W.Button(f, "BACK", 90, onBack)
  back:SetPoint("TOPLEFT", 0, 0)
  f.title = W.Font(f, 15, W.C.gold)
  f.title:SetPoint("LEFT", back, "RIGHT", 10, 0)

  f.mark = W.Button(f, "MARK_ON_MAP", 140, function()
    local t = f.markTarget
    if t then ns:SetWaypoint(t.map, t.items, t.title) end
  end)
  f.mark:SetPoint("TOPRIGHT", 0, 0)

  f.info = W.Font(f, 12, W.C.muted)
  f.info:SetPoint("TOPLEFT", 0, -32)
  f.info:SetPoint("RIGHT", 0, 0)
  f.info:SetWordWrap(true)

  f.list = W.List(f, {
    { width = 180, header = "COL_ITEM" },
    { width = 80, justify = "RIGHT", header = "COL_PRICE" },
    { width = 60, justify = "RIGHT", header = "COL_VS_AVG" },
    { width = 56, justify = "RIGHT", header = "COL_24H" },
    { width = 70, justify = "RIGHT", header = "COL_SEEN" },
    { width = 90, header = "COL_ADVICE" },
  }, 22)
  f.list:SetPoint("TOPLEFT", 0, -64)
  f.list:SetPoint("BOTTOMRIGHT", 0, 30)

  local legend = W.Font(f, 11, W.C.muted)
  legend:SetPoint("BOTTOMLEFT", 0, 6)
  legend:SetPoint("RIGHT", 0, 0)
  legend:SetWordWrap(true)
  W.Label(legend, "ADVICE_LEGEND")

  function f:Show2(row)
    self.row = row
    self:Show()
    self:Refresh()
  end

  function f:Refresh()
    local row = self.row
    if not row then return end
    local cat = row.cat
    self.title:SetText(ns.T(cat.name))
    local info = ""
    self.markTarget = nil
    if cat.tiers and row.tier then
      local tier = cat.tiers[row.tier]
      local items = {}
      for _, it in ipairs(tier.items) do items[#items + 1] = it[1] end
      self.markTarget = { map = ns:FirstZone(tier.zones), items = items, title = ns.T(cat.name) }
      local zones = {}
      for _, id in ipairs(tier.zones) do zones[#zones + 1] = ns.ZoneName(id) end
      info = L.BEST_SPOT:format(table.concat(zones, ", "))
      if cat.gather then
        info = info .. "  " .. L.REQUIRES:format(ns.ProfName(cat.gather), tier.skill)
      elseif tier.level then
        info = info .. "  " .. L.REQUIRES_LEVEL:format(tier.level)
      end
    elseif cat.dynamic then
      info = L.TRANSMOG_INFO
    else
      info = L.ENCHANT_INFO
    end
    if row.measured then info = info .. "  " .. L.MEASURED_NOTE end
    self.info:SetText(info)
    self.mark:SetEnabled(self.markTarget ~= nil)

    local data = {}
    for _, r in ipairs(ns:CategoryItems(cat)) do
      data[#data + 1] = {
        itemID = r.id, icon = ns.ItemIcon(r.id),
        cells = {
          "|cff" .. ns.ItemQualityHex(r.id) .. ns.ItemName(r.id) .. "|r",
          ns.Money(r.price),
          ns.Pct(r.diff),
          ns.Pct(r.change),
          ageText(r.age),
          adviceText(r.advice),
        },
        tone = r.id == row.item and "top" or nil,
      }
    end
    self.list:SetData(data, L.NO_PRICES)
  end

  f:Hide()
  return f
end

ns:RegisterView("ranking", function(parent)
  local f = CreateFrame("Frame", nil, parent)
  local home = CreateFrame("Frame", nil, f)
  home:SetAllPoints()

  local gold = W.Stat(home, "STAT_GOLD", 200)
  gold:SetPoint("TOPLEFT", 0, 0)
  local session = W.Stat(home, "STAT_SESSION", 200)
  session:SetPoint("LEFT", gold, "RIGHT", 8, 0)
  local rate = W.Stat(home, "STAT_RATE", 200)
  rate:SetPoint("LEFT", session, "RIGHT", 8, 0)

  local list = W.List(home, {
    { width = 14, justify = "RIGHT" },
    { width = 130, header = "COL_CATEGORY" },
    { width = 96, header = "COL_PROFIT", bar = true },
    { width = 70, justify = "RIGHT", header = "COL_GPH" },
    { width = 54, justify = "RIGHT", header = "COL_24H" },
    { width = 160, header = "COL_BEST_ITEM" },
  }, 24)
  list:SetPoint("TOPLEFT", 0, -48)
  list:SetPoint("BOTTOMRIGHT", 0, 30)

  local footer = W.Font(home, 11, W.C.muted)
  footer:SetPoint("BOTTOMLEFT", 0, 6)
  footer:SetPoint("RIGHT", -130, 0)
  footer:SetWordWrap(true)

  local refresh = W.Button(home, "REFRESH", 120, function()
    ns:SnapshotPrices()
    f:Refresh()
  end)
  refresh:SetPoint("BOTTOMRIGHT", 0, 0)

  local detail = buildDetail(f, function()
    f.detail:Hide()
    home:Show()
    f:Refresh()
  end)
  f.detail = detail

  function f:Refresh()
    if detail:IsShown() then
      detail:Refresh()
      return
    end
    gold:Set(ns.Money(GetMoney(), true))
    local gain = ns:SessionGain()
    local hours = ns:SessionHours()
    session:Set((gain >= 0 and "+" or "") .. ns.Money(gain) .. "  " .. ns.Color("muted", "(" .. ns.Duration(hours * 60) .. ")"),
      gain >= 0 and W.C.up or W.C.down)
    local rateText, rateValue = ns.SessionRate()
    rate:Set(rateText, rateValue > 0 and W.C.up or (rateValue < 0 and W.C.down or W.C.ink))

    local rows = ns:RankCategories()
    local max = 0
    for _, r in ipairs(rows) do max = math.max(max, r.gph or 0) end
    local data = {}
    for i, r in ipairs(rows) do
      local cat = r.cat
      local name = ns.T(cat.name)
      if r.locked then name = name .. ns.Color("muted", " *") end
      local tip = { name, r.measured and L.TIP_MEASURED or L.TIP_ESTIMATED }
      if r.locked then tip[#tip + 1] = L.TIP_LOCKED end
      tip[#tip + 1] = ns.Color("gold", L.TIP_CLICK_DETAIL)
      data[#data + 1] = {
        cells = {
          tostring(i),
          name,
          max > 0 and (r.gph or 0) / max or 0,
          r.gph and (ns.Gold(r.gph) .. (r.measured and ns.Color("gold", "*") or "")) or ns.Color("muted", "-"),
          ns.Pct(r.change),
          r.item and ("|cff" .. ns.ItemQualityHex(r.item) .. ns.ItemName(r.item) .. "|r") or ns.Color("muted", "-"),
        },
        icon = r.item and ns.ItemIcon(r.item) or nil,
        iconCol = 6,
        swatch = cat.color,
        swatchCol = 2,
        tone = i == 1 and r.gph and "top" or nil,
        colors = { [1] = W.C.muted },
        tip = tip,
        onClick = function()
          home:Hide()
          detail:Show2(r)
        end,
      }
    end
    list:SetData(data, L.NO_PRICES)

    local last = ns.db.lastPriceUpdate
    if not ns.HasAuctionator() then
      footer:SetText(ns.Color("down", L.NO_AUCTIONATOR))
    elseif last and last > 0 then
      footer:SetText(L.LAST_UPDATE:format(ns.Duration((time() - last) / 60)) .. "  " .. L.RANKING_FOOT)
    else
      footer:SetText(L.NO_PRICES)
    end
  end

  return f
end)
