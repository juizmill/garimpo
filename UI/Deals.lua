local _, ns = ...
local L, W = ns.L, ns.W

local ROW_H = 24
-- Distance of each column's right edge from the row's right edge (item name takes the rest).
local COL = { profit = 108, discount = 194, market = 250, unit = 336, qty = 422 }

-- Status of the scanner as one line of text.
function ns.ScanStatus()
  local s = ns.scan
  if s.state == "waiting" then return L.SCAN_WAITING end
  if s.state == "processing" then return L.SCAN_PROGRESS:format(ns.Num(s.done), ns.Num(s.total)) end
  if s.state == "searching" then return L.SEARCH_PROGRESS:format(s.done, s.total) end
  local last = ns.db.lastFullScan or 0
  if last > 0 then return L.LAST_SCAN:format(ns.Duration((time() - last) / 60)) end
  return L.NO_SCAN_YET
end

local function buttonText(d)
  local st = d.state
  if st == "locating" or st == "quote" or st == "buying" then return "..." end
  if st == "confirm" then return L.CONFIRM_PRICE:format(ns.PlainMoney(d.quote or 0)) end
  if st == "bought" then return L.BOUGHT_SHORT end
  if st == "gone" then return L.GONE end
  if st == "ready" or d.l.auctionID or d.l.commodity then return L.BUY end
  return L.LOCATE
end

local function makeRow(parent, i)
  local r = CreateFrame("Frame", nil, parent)
  r:SetHeight(ROW_H)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
  r:SetPoint("RIGHT", parent, "RIGHT")
  r.bg = r:CreateTexture(nil, "BACKGROUND")
  r.bg:SetAllPoints()
  r.bg:SetTexture(W.FLAT)
  r.bg:SetVertexColor(1, 1, 1, i % 2 == 0 and 0.02 or 0)

  r.buy = W.Button(r, nil, 100, function()
    if r.deal then ns:BuyDeal(r.deal) end
  end)
  r.buy:SetHeight(20)
  r.buy:SetPoint("RIGHT", -2, 0)
  local function cell(key, width, color)
    local fs = W.Font(r, 12, color or W.C.ink, "RIGHT")
    fs:SetPoint("RIGHT", -COL[key], 0)
    fs:SetWidth(width)
    r[key] = fs
  end
  cell("profit", 80, W.C.up)
  cell("discount", 50, W.C.gold)
  cell("market", 80)
  cell("unit", 80)
  cell("qty", 40)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(18, 18)
  r.icon:SetPoint("LEFT", 4, 0)
  r.name = W.Font(r, 12, W.C.ink)
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
  r.name:SetPoint("RIGHT", r.qty, "LEFT", -6, 0)

  local hover = CreateFrame("Frame", nil, r)
  hover:SetPoint("TOPLEFT")
  hover:SetPoint("BOTTOMLEFT")
  hover:SetPoint("RIGHT", r.qty, "LEFT", -6, 0)
  hover:SetScript("OnEnter", function(self)
    if not r.deal then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. r.deal.id)
    GameTooltip:Show()
  end)
  hover:SetScript("OnLeave", GameTooltip_Hide)
  return r
end

-- The Deals tab of the Auction House panel. The caller anchors the returned frame.
function ns.BuildDealsView(parent)
  local f = CreateFrame("Frame", nil, parent)
  f.mode = "deals"
  local searchCache = setmetatable({}, { __mode = "k" })   -- listing -> row deal, for buy states

  local count = W.Stat(f, "STAT_DEALS", 200)
  count:SetPoint("TOPLEFT", 0, 0)
  local profit = W.Stat(f, "STAT_DEAL_PROFIT", 200)
  profit:SetPoint("LEFT", count, "RIGHT", 8, 0)
  local status = W.Stat(f, "STAT_SCAN", 200)
  status:SetPoint("LEFT", profit, "RIGHT", 8, 0)

  local mode = W.Chips(f, function(v)
    f.mode = v
    f:Refresh()
  end)
  mode:SetPoint("TOPLEFT", 0, -48)
  mode:SetItems({ { value = "deals", key = "MODE_DEALS" }, { value = "search", key = "MODE_SEARCH" } })
  mode:Select("deals")

  local quick = W.Button(f, "QUICK_SEARCH", 130, function()
    ns:QuickSearch(ns:TrackedItems(), function()
      f.mode = "search"
      mode:Select("search")
      f:Refresh()
    end)
  end)
  quick:SetPoint("TOPRIGHT", 0, -46)
  local full = W.Button(f, "FULL_SCAN", 150, function() ns:FullScan() end)
  full:SetPoint("RIGHT", quick, "LEFT", -6, 0)

  local hdr = CreateFrame("Frame", nil, f)
  hdr:SetPoint("TOPLEFT", 0, -76)
  hdr:SetPoint("TOPRIGHT", -24, -76)
  hdr:SetHeight(16)
  local itemHeader = W.Font(hdr, 10, W.C.muted)
  itemHeader:SetPoint("LEFT", 4, 0)
  W.Label(itemHeader, "COL_ITEM")
  for key, header in pairs({ qty = "COL_QTY", unit = "COL_UNIT_PRICE", market = "COL_MARKET",
    discount = "COL_DISCOUNT", profit = "COL_PROFIT_EST" }) do
    local fs = W.Font(hdr, 10, W.C.muted, "RIGHT")
    fs:SetPoint("RIGHT", -COL[key], 0)
    fs:SetWidth(80)
    W.Label(fs, header)
  end
  local line = W.Line(hdr)
  line:SetPoint("BOTTOMLEFT")
  line:SetPoint("BOTTOMRIGHT")

  local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 0, -94)
  sf:SetPoint("BOTTOMRIGHT", -24, 30)
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(560, 1)
  sf:SetScrollChild(child)
  sf:SetScript("OnSizeChanged", function(_, w) child:SetWidth(w) end)
  local rows = {}

  local empty = W.Font(f, 12, W.C.muted, "CENTER")
  empty:SetPoint("TOPLEFT", 20, -130)
  empty:SetPoint("TOPRIGHT", -20, -130)
  empty:SetWordWrap(true)

  local foot = W.Font(f, 11, W.C.muted)
  foot:SetPoint("BOTTOMLEFT", 0, 6)
  foot:SetPoint("RIGHT", 0, 0)
  foot:SetWordWrap(true)
  W.Label(foot, "DEALS_FOOT")

  -- Rows for the search mode: the cheapest listing of each searched item.
  local function searchRows()
    local list = {}
    for _, id in ipairs(ns.searchResults) do
      for _, l in ipairs(ns.listings[id] or {}) do
        if not l.mine then
          local d = searchCache[l]
          if not d then
            local ref = ns:Reference(id) or ns.Market(id) or l.unit
            local p, roi = ns.DealProfit(l.unit, l.count, ref)
            d = { id = id, l = l, ref = ref, roi = roi, profit = p }
            searchCache[l] = d
          end
          list[#list + 1] = d
          break
        end
      end
    end
    return list
  end

  function f:Refresh()
    if ns.dealsMode then
      self.mode = ns.dealsMode
      mode:Select(self.mode)
      ns.dealsMode = nil
    end
    local list = self.mode == "search" and searchRows() or ns.deals
    local total = 0
    for _, d in ipairs(ns.deals) do
      if d.state ~= "bought" and d.state ~= "gone" then total = total + math.max(d.profit, 0) end
    end
    count:Set(tostring(#ns.deals))
    profit:Set(ns.Money(total), W.C.up)
    status:Set(ns.ScanStatus())

    for i, d in ipairs(list) do
      local r = rows[i] or makeRow(child, i)
      rows[i] = r
      r.deal = d
      r.icon:SetTexture(ns.ItemIcon(d.id))
      r.icon:SetDesaturated(d.state == "bought" or d.state == "gone")
      r.name:SetText("|cff" .. ns.ItemQualityHex(d.id) .. ns.ItemName(d.id) .. "|r")
      r.qty:SetText(ns.Num(d.l.count))
      r.unit:SetText(ns.Money(d.l.unit))
      r.market:SetText(ns.Money(d.ref))
      r.discount:SetText(d.roi > 0 and (math.floor(d.roi * 100 + 0.5) .. "%") or ns.Color("muted", "-"))
      r.profit:SetText(d.profit > 0 and ns.Money(d.profit) or ns.Color("muted", "-"))
      r.buy:SetText(buttonText(d))
      r.buy:SetEnabled(ns.ahOpen == true and d.state ~= "bought" and d.state ~= "gone"
        and d.state ~= "locating" and d.state ~= "buying" and d.state ~= "quote")
      r:Show()
    end
    for i = #list + 1, #rows do rows[i]:Hide() end
    child:SetHeight(math.max(1, #list * ROW_H))

    local msg = ""
    if #list == 0 then
      if not ns.HasPrices() then msg = L.NO_PRICES
      elseif self.mode == "search" then msg = L.SEARCH_EMPTY
      else msg = L.DEALS_EMPTY end
    end
    empty:SetText(msg)

    local wait = ns:FullScanWait()
    full:SetEnabled(ns.CanScan() and ns.scan.state == "idle" and wait == 0)
    full:SetText(wait > 0 and L.FULL_SCAN_IN:format(ns.Duration(wait / 60 + 0.5)) or L.FULL_SCAN)
    quick:SetEnabled(ns.ahOpen == true and ns.scan.state == "idle")
  end

  return f
end

for _, msg in ipairs({ "DEALS", "SCAN", "PRICES" }) do
  ns:On(msg, function()
    ns:Throttle("deals-refresh", 0.2, function() ns:RefreshDeals() end)
  end)
end

-- Refresh the cooldown text on the scan button while the tab is open.
C_Timer.NewTicker(20, function() ns:RefreshDeals() end)
