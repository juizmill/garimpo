local _, ns = ...
local L, W = ns.L, ns.W

local ROW_H = 24
local GAP, BUY_W = 6, 100
-- Columns from right to left after the Buy button. The item name takes the rest.
-- Widths can be changed by dragging the handle at each title's left edge.
local ORDER = { "buyQty", "profit", "discount", "market", "unit", "qty" }
local DEFAULT_W = { buyQty = 40, profit = 84, discount = 56, market = 80, unit = 80, qty = 44 }
local MIN_COL, MAX_COL, MIN_NAME = 30, 220, 120
local HEADERS = {
  qty = "COL_LISTED", unit = "COL_PAY_UNIT", market = "COL_WORTH_UNIT",
  discount = "COL_DISCOUNT", profit = "COL_PROFIT_EST", buyQty = "COL_BUY_QTY",
}

local function colWidth(key)
  return ns.db.dealCols[key] or DEFAULT_W[key]
end

-- Distance of each column's right edge from the row's right edge; `name` is where the
-- item name column ends.
local function offsets()
  local o, x = {}, 2 + BUY_W + GAP
  for _, k in ipairs(ORDER) do
    o[k] = x
    x = x + colWidth(k) + GAP
  end
  o.name = x
  return o
end

-- Shows the item in the game's own Auction House window (exact-name search), to check
-- quantities and prices there.
function ns.ShowInAuctionHouse(id)
  local name = ns.ItemInfo(id)
  local ah = AuctionHouseFrame
  if not (name and ah and ah:IsShown()) then return end
  if ah.SetDisplayMode and AuctionHouseFrameDisplayMode then
    pcall(ah.SetDisplayMode, ah, AuctionHouseFrameDisplayMode.Buy)
  end
  local bar = ah.SearchBar
  if not (bar and bar.SearchBox) then return end
  bar.SearchBox:SetText('"' .. name .. '"')
  if bar.StartSearch then
    pcall(bar.StartSearch, bar)
  elseif bar.SearchButton then
    bar.SearchButton:Click()
  end
end

-- How many units to buy of a commodity deal: the row's box, or the default from Settings
-- limited to what your gold pays for.
function ns.DealBuyQty(d)
  if d.buyQty then return math.max(1, math.floor(d.buyQty)) end
  local default = ns.db.settings.deals.buyQty or 10
  local afford = math.floor(GetMoney() / math.max(d.l.unit, 1))
  return math.max(1, math.min(default, afford))
end

-- Status of the scanner as one line of text.
function ns.ScanStatus()
  local s = ns.scan
  if s.state == "waiting" then return L.SCAN_WAITING end
  if s.state == "processing" then return L.SCAN_PROGRESS:format(ns.Num(s.done), ns.Num(s.total)) end
  if s.state == "searching" then return L.SEARCH_PROGRESS:format(s.done, s.total) end
  if s.state == "browsing" then return L.SCAN_BROWSING:format(ns.Num(s.done)) end
  local last = ns.db.lastFullScan or 0
  if last > 0 then
    return L.LAST_SCAN:format(ns.Duration((time() - last) / 60), ns.Num(ns.db.lastScanItems or 0))
  end
  return L.NO_SCAN_YET
end

function ns.DealButtonText(d)
  local st = d.state
  if st == "locating" or st == "quote" or st == "buying" then return "..." end
  if st == "confirm" then return L.CONFIRM_PRICE:format(ns.PlainMoney(d.quote or 0)) end
  if st == "gone" or d.needsLocate then return L.FIND_NEXT end
  if st == "ready" or d.l.auctionID or d.l.commodity then return L.BUY end
  return L.LOCATE
end

-- Items (not commodities) are bought one whole auction at a time.
function ns.DealIsSingle(d)
  return d.l.auctionID ~= nil and not d.l.commodity
end

-- Profit of what this row would buy now: per-unit profit times the units bought.
local function rowProfit(d)
  local units = ns.DealIsSingle(d) and d.l.count or ns.DealBuyQty(d)
  return (d.ref * ns.SaleKeep() - d.l.unit) * units
end

local function layoutRow(r, o)
  r.buyQty:ClearAllPoints()
  r.buyQty:SetPoint("RIGHT", -(o.buyQty + 2), 0)
  r.buyQty:SetWidth(colWidth("buyQty") - 4)
  for _, k in ipairs(ORDER) do
    local fs = r[k]
    if k ~= "buyQty" then
      fs:ClearAllPoints()
      fs:SetPoint("RIGHT", -o[k], 0)
      fs:SetWidth(colWidth(k))
    end
  end
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

  r.buy = W.Button(r, nil, BUY_W, function()
    if r.deal then ns:BuyDeal(r.deal) end
  end)
  r.buy:SetHeight(20)
  r.buy:SetPoint("RIGHT", -2, 0)
  -- Units to buy (commodities); items are bought one auction at a time.
  r.buyQty = W.Edit(r, 36, function(text)
    local v = tonumber(text)
    if r.deal and v and v > 0 then
      r.deal.buyQty = math.floor(v)
      if r.deal.state == "confirm" then r.deal.state = nil end   -- price must be quoted again
    end
  end)
  r.buyQty:SetMaxLetters(4)
  for _, k in ipairs(ORDER) do
    if k ~= "buyQty" then r[k] = W.Font(r, 12, W.C.ink, "RIGHT") end
  end
  layoutRow(r, offsets())

  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(18, 18)
  r.icon:SetPoint("LEFT", 4, 0)
  r.name = W.Font(r, 12, W.C.ink)
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
  r.name:SetPoint("RIGHT", r.qty, "LEFT", -6, 0)

  local hover = CreateFrame("Button", nil, r)
  hover:SetPoint("TOPLEFT")
  hover:SetPoint("BOTTOMLEFT")
  hover:SetPoint("RIGHT", r.qty, "LEFT", -6, 0)
  hover:RegisterForClicks("LeftButtonUp")
  hover:SetScript("OnEnter", function(self)
    if not r.deal then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. r.deal.id)
    GameTooltip:AddLine(" ")
    if not r.deal.good then GameTooltip:AddLine(L.BELOW_MARGIN, 1, 0.82, 0, true) end
    GameTooltip:AddLine(L.DOUBLE_CLICK_SEARCH, 0.6, 0.56, 0.49)
    GameTooltip:Show()
  end)
  hover:SetScript("OnLeave", GameTooltip_Hide)
  hover:SetScript("OnDoubleClick", function()
    if r.deal then ns.ShowInAuctionHouse(r.deal.id) end
  end)
  return r
end

-- The Deals tab of the Auction House panel. The caller anchors the returned frame.
function ns.BuildDealsView(parent)
  local f = CreateFrame("Frame", nil, parent)

  local count = W.Stat(f, "STAT_DEALS", 200)
  count:SetPoint("TOPLEFT", 0, 0)
  local profit = W.Stat(f, "STAT_DEAL_PROFIT", 200)
  profit:SetPoint("LEFT", count, "RIGHT", 8, 0)
  -- Your gold limits what the deals offer; the scan status is at the top of the panel.
  local gold = W.Stat(f, "STAT_GOLD", 200)
  gold:SetPoint("LEFT", profit, "RIGHT", 8, 0)

  -- Re-checks only the items on the deals list: real prices and quantities, and auction IDs
  -- so each one buys with a single click.
  local quick = W.Button(f, "CHECK_DEALS", 130, function()
    local ids, seen = {}, {}
    for _, d in ipairs(ns.deals) do
      if not seen[d.id] then
        seen[d.id] = true
        ids[#ids + 1] = d.id
      end
    end
    if #ids == 0 then
      ns.Print(ns:NoDealsReason())
      return
    end
    ns:QuickSearch(ids, function() f:Refresh() end)
  end)
  quick:SetPoint("TOPRIGHT", 0, -46)

  local hdr = CreateFrame("Frame", nil, f)
  hdr:SetPoint("TOPLEFT", 0, -76)
  hdr:SetPoint("TOPRIGHT", -24, -76)
  hdr:SetHeight(16)

  -- Clickable titles sort the list; by default deals come by profit, highest first.
  local sorter = W.Sorter(function() f:Refresh() end, { name = true })
  local itemHeader = W.SortHeader(hdr, "COL_ITEM", 160, "LEFT")
  itemHeader:SetPoint("LEFT", 4, 0)
  sorter:Add(itemHeader, "name")
  local headers = {}
  for _, k in ipairs(ORDER) do
    if k == "buyQty" then
      local fs = W.Font(hdr, 10, W.C.muted, "CENTER")
      W.Label(fs, HEADERS[k])
      headers[k] = fs
    else
      local h = W.SortHeader(hdr, HEADERS[k], DEFAULT_W[k], "RIGHT")
      sorter:Add(h, k)
      headers[k] = h
    end
  end
  local sortValue = {
    name = function(d) return ns.ItemName(d.id) end,
    qty = function(d) return d.l.count end,
    unit = function(d) return d.l.unit end,
    market = function(d) return d.ref end,
    discount = function(d) return d.roi end,
    profit = rowProfit,
  }
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

  -- Column layout, shared by the titles and every row.
  local handles = {}
  local function layout()
    local o = offsets()
    for _, k in ipairs(ORDER) do
      local h = headers[k]
      h:ClearAllPoints()
      h:SetPoint("RIGHT", hdr, "RIGHT", -(o[k] + (k == "buyQty" and 2 or 0)), 0)
      h:SetWidth(colWidth(k) - (k == "buyQty" and 4 or 0))
      local handle = handles[k]
      if handle then
        handle:ClearAllPoints()
        handle:SetPoint("CENTER", hdr, "RIGHT", -(o[k] + colWidth(k) + GAP / 2), 0)
      end
    end
    for _, r in ipairs(rows) do layoutRow(r, o) end
  end

  -- Drag handles: drag left to widen the column, right to narrow it. Double-click resets.
  for _, k in ipairs(ORDER) do
    local handle = CreateFrame("Button", nil, hdr)
    handle:SetSize(8, 16)
    handle:SetFrameLevel(hdr:GetFrameLevel() + 5)
    local bar = handle:CreateTexture(nil, "OVERLAY")
    bar:SetTexture(W.FLAT)
    bar:SetSize(1, 12)
    bar:SetPoint("CENTER")
    bar:SetVertexColor(W.C.line[1], W.C.line[2], W.C.line[3], 1)
    handle:SetScript("OnEnter", function(self)
      bar:SetVertexColor(1, 0.82, 0, 1)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(L.RESIZE_COLUMN, 1, 1, 1, 1, true)   -- r, g, b, alpha, wrap
      GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function()
      if not handle.drag then bar:SetVertexColor(W.C.line[1], W.C.line[2], W.C.line[3], 1) end
      GameTooltip:Hide()
    end)
    handle:SetScript("OnMouseDown", function(self)
      self.drag = { x = GetCursorPosition() / self:GetEffectiveScale(), w = colWidth(k) }
      self:SetScript("OnUpdate", function()
        local x = GetCursorPosition() / self:GetEffectiveScale()
        local o = offsets()
        -- Room left for the item name with the other columns as they are.
        local others = o.name - colWidth(k)
        local maxByName = math.max(MIN_COL, f:GetWidth() - 24 - others - MIN_NAME)
        local w = math.floor(self.drag.w + (self.drag.x - x) + 0.5)
        w = math.max(MIN_COL, math.min(MAX_COL, maxByName, w))
        if w ~= colWidth(k) then
          ns.db.dealCols[k] = w
          layout()
        end
      end)
    end)
    handle:SetScript("OnMouseUp", function(self)
      self.drag = nil
      self:SetScript("OnUpdate", nil)
      bar:SetVertexColor(W.C.line[1], W.C.line[2], W.C.line[3], 1)
    end)
    handle:SetScript("OnDoubleClick", function()
      ns.db.dealCols[k] = nil
      layout()
    end)
    handles[k] = handle
  end
  layout()

  local empty = W.Font(f, 12, W.C.muted, "CENTER")
  empty:SetPoint("TOPLEFT", 20, -130)
  empty:SetPoint("TOPRIGHT", -20, -130)
  empty:SetWordWrap(true)

  local foot = W.Font(f, 11, W.C.muted)
  foot:SetPoint("BOTTOMLEFT", 0, 6)
  foot:SetPoint("RIGHT", 0, 0)
  foot:SetWordWrap(true)
  W.Label(foot, "DEALS_FOOT")

  function f:Refresh()
    local list = {}
    for _, d in ipairs(ns.deals) do
      if d.roi and d.roi > 0 then list[#list + 1] = d end
    end
    if sorter.col then W.SortRows(list, sortValue[sorter.col], sorter.asc) end

    local good, total = 0, 0
    for _, d in ipairs(ns.deals) do
      if d.good then
        good = good + 1
        total = total + math.max(rowProfit(d), 0)
      end
    end
    count:Set(good .. ns.Color("muted", "  / " .. #ns.deals))
    profit:Set(ns.Money(total), W.C.up)
    gold:Set(ns.Money(GetMoney()))

    local o = offsets()
    for i, d in ipairs(list) do
      local r = rows[i]
      if not r then
        r = makeRow(child, i)
        rows[i] = r
        layoutRow(r, o)
      end
      r.deal = d
      r.icon:SetTexture(ns.ItemIcon(d.id))
      r.icon:SetDesaturated(d.state == "gone")
      local boughtText = d.boughtCount and ns.Color("up", "  +" .. d.boughtCount) or ""
      r.name:SetText("|cff" .. ns.ItemQualityHex(d.id) .. ns.ItemName(d.id) .. "|r" .. boughtText)
      r.qty:SetText(ns.Num(d.l.count))
      r.unit:SetText(ns.Money(d.l.unit))
      r.market:SetText(ns.Money(d.ref))
      -- Deals below your margin fill the list in a muted color.
      local tint = d.good and W.C.gold or W.C.muted
      r.discount:SetTextColor(tint[1], tint[2], tint[3])
      r.discount:SetText(math.floor(d.roi * 100 + 0.5) .. "%")
      local profitNow = rowProfit(d)
      local pTint = d.good and W.C.up or W.C.muted
      r.profit:SetTextColor(pTint[1], pTint[2], pTint[3])
      r.profit:SetText(profitNow > 0 and ns.Money(profitNow) or "-")
      local single = ns.DealIsSingle(d)
      if not r.buyQty:HasFocus() then
        r.buyQty:SetText(tostring(single and d.l.count or ns.DealBuyQty(d)))
      end
      r.buyQty:SetEnabled(not single)
      r.buy:SetText(ns.DealButtonText(d))
      -- Only busy while the game is answering; after a purchase it can buy again.
      r.buy:SetEnabled(ns.ahOpen == true and d.state ~= "locating" and d.state ~= "buying" and d.state ~= "quote")
      r:Show()
    end
    for i = #list + 1, #rows do rows[i]:Hide() end
    child:SetHeight(math.max(1, #list * ROW_H))

    local msg = ""
    if #list == 0 then
      if not ns.HasPrices() then msg = L.NO_PRICES
      else msg = ns:NoDealsReason() end
    end
    empty:SetText(msg)

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
