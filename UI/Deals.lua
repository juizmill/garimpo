local _, ns = ...
local L, W = ns.L, ns.W

local ROW_H, SUB_H, TOTAL_H = 24, 20, 30
local MAX_LISTINGS = 10   -- auctions shown under an open deal
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

-- How many units to buy of a commodity deal: the row's box, or the default from Settings
-- limited to what your gold pays for.
function ns.DealBuyQty(d)
  if d.buyQty then return math.max(1, math.floor(d.buyQty)) end
  local default = ns.db.settings.deals.buyQty or 10
  local afford = math.floor(GetMoney() / math.max(d.l.unit, 1))
  return math.max(1, math.min(default, afford))
end

-- Status of the scanner as one line of text. generalOnly: only the scans of the whole
-- Auction House; item-by-item searches keep showing the last full scan.
function ns.ScanStatus(generalOnly)
  local s = ns.scan
  if s.state == "waiting" then return L.SCAN_WAITING end
  if s.state == "processing" then return L.SCAN_PROGRESS:format(ns.Num(s.done), ns.Num(s.total)) end
  if s.state == "searching" and not generalOnly then return L.SEARCH_PROGRESS:format(s.done, s.total) end
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
  if st == "failed" then return L.RELOAD end
  if st == "gone" or d.needsLocate then return L.FIND_NEXT end
  if st == "ready" or d.l.auctionID or d.l.commodity then return L.BUY end
  return L.LOCATE
end

-- Units of a commodity other players have for sale, from the last search; nil when the
-- listings didn't come from a search (the count is unknown then).
function ns.UnitsForSale(id)
  local total, known = 0, false
  for _, l in ipairs(ns.listings[id] or {}) do
    if l.commodity then known = true end
    if not l.mine then total = total + l.count end
  end
  return known and total or nil
end

-- Items (not commodities) are bought one whole auction at a time.
function ns.DealIsSingle(d)
  return d.l.auctionID ~= nil and not d.l.commodity
end

-- Profit of what this row would buy now: per-unit profit times the units bought, plus the
-- other auctions checked under it.
local function rowProfit(d)
  local units = ns.DealIsSingle(d) and d.l.count or ns.DealBuyQty(d)
  return (d.ref * ns.SaleKeep() - d.l.unit) * units + (d.extraProfit or 0)
end

-- Cost of the cheapest `qty` units of other players' listings: what the game charges for
-- a commodity.
local function cheapestCost(list, qty)
  local sum, n = 0, 0
  for _, l in ipairs(list) do
    if not l.mine and n < qty then
      local take = math.min(l.count, qty - n)
      sum, n = sum + l.unit * take, n + take
    end
  end
  return sum
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

local function makeRow(parent, view)
  local r = CreateFrame("Frame", nil, parent)
  r:SetHeight(ROW_H)
  r.bg = r:CreateTexture(nil, "BACKGROUND")
  r.bg:SetAllPoints()
  r.bg:SetTexture(W.FLAT)

  r.buy = W.Button(r, nil, BUY_W, function()
    if r.deal then view:Buy(r.deal) end
  end, "primary")
  r.buy:SetHeight(20)
  r.buy:SetPoint("RIGHT", -2, 0)
  -- Shown while a purchase waits for the confirming click (or a queue runs): gives it up.
  r.cancel = W.Close(r, function()
    if r.deal then view:CancelBuy(r.deal) end
  end)
  r.cancel:SetPoint("RIGHT", -(2), 0)
  r.cancel:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L.CANCEL_BUY)
    GameTooltip:Show()
  end)
  r.cancel:HookScript("OnLeave", GameTooltip_Hide)
  r.cancel:Hide()
  -- Units to buy (commodities); items are bought one auction at a time.
  r.buyQty = W.Edit(r, 36, function(text)
    local v = tonumber(text)
    if r.deal and v and v > 0 then
      r.deal.buyQty = math.floor(v)
      ns:CancelBuy(r.deal)   -- a pending quote is for the old quantity: quote again
      view:Refresh()   -- the purchase total under an open deal follows the box
    end
  end)
  r.buyQty:SetMaxLetters(4)
  for _, k in ipairs(ORDER) do
    if k ~= "buyQty" then r[k] = W.Font(r, 12, W.C.ink, "RIGHT") end
  end
  layoutRow(r, offsets())

  -- + / - : opens the other auctions of the item under the row.
  r.arrow = W.Font(r, 13, W.C.gold, "CENTER")
  r.arrow:SetPoint("LEFT", 2, 0)
  r.arrow:SetWidth(12)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(18, 18)
  r.icon:SetPoint("LEFT", 16, 0)
  r.name = W.Font(r, 12, W.C.ink)
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
  r.name:SetPoint("RIGHT", r.qty, "LEFT", -6, 0)

  local hover = CreateFrame("Button", nil, r)
  hover:SetPoint("TOPLEFT")
  hover:SetPoint("BOTTOMLEFT")
  hover:SetPoint("RIGHT", r.qty, "LEFT", -6, 0)
  hover:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  hover:SetScript("OnEnter", function(self)
    if not r.deal then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. r.deal.id)
    GameTooltip:AddLine(" ")
    if not r.deal.good then GameTooltip:AddLine(L.BELOW_MARGIN, 1, 0.82, 0, true) end
    GameTooltip:AddLine(L.SHOPPING_CLICK_OPEN, 0.6, 0.56, 0.49)
    GameTooltip:AddLine(L.RIGHT_CLICK_SEARCH, 0.6, 0.56, 0.49)
    GameTooltip:Show()
  end)
  hover:SetScript("OnLeave", GameTooltip_Hide)
  -- Left click opens the other auctions; right click shows the item in the game's window.
  hover:SetScript("OnClick", function(_, button)
    if not r.deal then return end
    if button == "RightButton" then
      ns.ShowInAuctionHouse(r.deal.id)
    else
      view:ToggleOpen(r.deal.id)
    end
  end)
  return r
end

-- One line under an open deal: another auction of the item, the column titles, or a
-- message. Uses the deal columns: listed, pay/unit, return and profit.
local function layoutSub(s, o)
  for _, k in ipairs({ "qty", "unit", "discount", "profit" }) do
    s[k]:ClearAllPoints()
    s[k]:SetPoint("RIGHT", -o[k], 0)
    s[k]:SetWidth(colWidth(k))
  end
  s.pickQty:ClearAllPoints()
  s.pickQty:SetPoint("RIGHT", -(o.buyQty + 2), 0)
  s.pickQty:SetWidth(colWidth("buyQty") - 4)
  s.seller:SetPoint("RIGHT", s, "RIGHT", -(o.name + 6), 0)
end

-- Checking an auction adds it to the deal's purchase; the box sets how many units
-- (commodities; an item auction is bought whole).
local function makeSub(parent, view)
  local s = CreateFrame("Frame", nil, parent)
  s:SetHeight(SUB_H)
  s.bg = s:CreateTexture(nil, "BACKGROUND")
  s.bg:SetAllPoints()
  s.bg:SetTexture(W.FLAT)
  -- Gold line above the purchase total.
  s.topLine = s:CreateTexture(nil, "ARTWORK")
  s.topLine:SetTexture(W.FLAT)
  s.topLine:SetVertexColor(W.C.edge[1], W.C.edge[2], W.C.edge[3], 1)
  s.topLine:SetPoint("TOPLEFT")
  s.topLine:SetPoint("TOPRIGHT")
  s.topLine:SetHeight(1)
  s.check = W.CheckBox(s, function(on)
    if s.listing then view:SetPick(s.listing, on and (s.pickValue or s.listing.count) or nil) end
  end)
  s.check:SetPoint("LEFT", 20, 0)
  s.seller = W.Font(s, 11, W.C.muted)
  s.seller:SetPoint("LEFT", 40, 0)
  for _, k in ipairs({ "qty", "unit", "discount", "profit" }) do s[k] = W.Font(s, 11, W.C.ink, "RIGHT") end
  s.pickQty = W.Edit(s, 36, function(text)
    local v = tonumber(text)
    if s.listing and v and v > 0 then
      s.pickValue = math.min(math.floor(v), s.listing.count)
      view:SetPick(s.listing, s.pickValue)
    end
  end)
  s.pickQty:SetHeight(18)
  s.pickQty:SetMaxLetters(4)
  layoutSub(s, offsets())
  return s
end

-- The Deals tab of the Auction House panel. The caller anchors the returned frame.
function ns.BuildDealsView(parent)
  local f = CreateFrame("Frame", nil, parent)
  local open = {}       -- [itemID] = true: its auctions are shown under it
  local searched = {}   -- [itemID] = true: searched when opened, for sellers and auction IDs
  local auctionDeals = setmetatable({}, { __mode = "k" })   -- listing -> buy state of that auction
  local picks = setmetatable({}, { __mode = "k" })          -- listing -> units checked to buy

  local count = W.Stat(f, "STAT_DEALS", 200)
  count:SetPoint("TOPLEFT", 0, 0)
  local profit = W.Stat(f, "STAT_DEAL_PROFIT", 200)
  profit:SetPoint("LEFT", count, "RIGHT", 8, 0)
  -- Your gold limits what the deals offer; the scan status is at the top of the panel.
  local gold = W.Stat(f, "STAT_GOLD", 200)
  gold:SetPoint("LEFT", profit, "RIGHT", 8, 0)

  -- Reads the whole Auction House, then checks the best deals one by one: real prices and
  -- quantities, and auction IDs so each one buys with a single click.
  local quick = W.Button(f, "CHECK_DEALS", 130, function()
    ns:CheckDeals(function() f:Refresh() end)
  end, "primary")
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

  local sf = W.Scroll(f)
  sf:SetPoint("TOPLEFT", 0, -94)
  sf:SetPoint("BOTTOMRIGHT", -24, 44)   -- room for the two-line footer
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(560, 1)
  sf:SetScrollChild(child)
  sf:SetScript("OnSizeChanged", function(_, w) child:SetWidth(w) end)
  local rows, subs = {}, {}

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
    for _, s in ipairs(subs) do layoutSub(s, o) end
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

  -- While "Check deals" runs, the old list goes away and this shows the progress.
  local loading = CreateFrame("Frame", nil, f)
  loading:SetPoint("TOPLEFT", 0, -110)
  loading:SetPoint("TOPRIGHT", 0, -110)
  loading:SetHeight(90)
  loading:Hide()
  local spinner = W.Spinner(loading, 36)
  spinner:SetPoint("TOP", 0, 0)
  local loadingTitle = W.Font(loading, 13, W.C.gold, "CENTER")
  loadingTitle:SetPoint("TOP", spinner, "BOTTOM", 0, -12)
  W.Label(loadingTitle, "CHECKING_DEALS")
  local loadingStatus = W.Font(loading, 11, W.C.muted, "CENTER")
  loadingStatus:SetPoint("TOP", loadingTitle, "BOTTOM", 0, -4)
  W.FadeIn(loading, 0.2)

  local foot = W.Font(f, 11, W.C.muted)
  foot:SetPoint("BOTTOMLEFT", 0, 6)
  foot:SetPoint("RIGHT", 0, 0)
  foot:SetWordWrap(true)
  W.Label(foot, "DEALS_FOOT")

  -- Listings from a full scan have no sellers or auction IDs: opening a deal searches
  -- its item once to bring them.
  local function hasSearchData(id)
    for _, l in ipairs(ns.listings[id] or {}) do
      if l.auctionID or l.commodity then return true end
    end
    return false
  end

  function f:ToggleOpen(id)
    open[id] = not open[id] or nil
    if open[id] and not searched[id] and not hasSearchData(id) and ns.ahOpen and ns.scan.state == "idle" then
      searched[id] = true
      ns:QuickSearch({ id }, function() f:Refresh() end)
    end
    self:Refresh()
  end

  function f:SetPick(l, qty)
    picks[l] = qty
    self:Refresh()
  end

  -- Other auctions checked under a deal: { l = listing, qty = units }.
  local function extrasOf(d)
    local out = {}
    for _, l in ipairs(ns.listings[d.id] or {}) do
      if picks[l] and not l.mine and l ~= d.l then
        out[#out + 1] = { l = l, qty = l.commodity and math.min(picks[l], l.count) or l.count }
      end
    end
    return out
  end

  local function clearPicks(id)
    for _, l in ipairs(ns.listings[id] or {}) do picks[l] = nil end
  end

  -- Buy state of one checked item auction, bought in turn after the deal's own.
  local function auctionDeal(d, l)
    local ad = auctionDeals[l]
    if not ad then
      ad = { id = d.id, l = l, ref = d.ref, anyPrice = true }
      ad.onBought = function() ad.done = true; picks[l] = nil end
      auctionDeals[l] = ad
    end
    return ad
  end

  -- The game allows one purchase per click. A commodity buys the deal's units plus the
  -- checked ones in one purchase (cheapest units first). Item auctions go in a queue:
  -- each click buys the next one.
  function f:Buy(d)
    if d.l.commodity or (d.extraN or 0) == 0 then
      ns:BuyDeal(d)
      return
    end
    if not d.queue then
      d.done = nil
      d.queue = { d }
      for _, e in ipairs(extrasOf(d)) do
        local ad = auctionDeal(d, e.l)
        ad.done = nil
        d.queue[#d.queue + 1] = ad
      end
    end
    for i, q in ipairs(d.queue) do
      -- A checked auction that is gone is skipped; the deal's own looks for another.
      if i > 1 and not q.done and (q.state == "gone" or q.needsLocate) then q.done = true end
      if not q.done then
        ns:BuyDeal(q)
        return
      end
    end
    d.queue = nil
  end

  -- Gives up the purchase waiting for confirmation and the rest of the queue.
  function f:CancelBuy(d)
    for _, q in ipairs(d.queue or {}) do ns:CancelBuy(q) end
    d.queue = nil
    ns:CancelBuy(d)
  end

  local function queueHead(d)
    if not d.queue then return nil end
    for i, q in ipairs(d.queue) do
      if not q.done then return q, i end
    end
    d.queue = nil
    return nil
  end

  local nSubs
  local function sub(y)
    nSubs = nSubs + 1
    local s = subs[nSubs] or makeSub(child, f)
    subs[nSubs] = s
    s:ClearAllPoints()
    s:SetPoint("TOPLEFT", 0, -y)
    s:SetPoint("RIGHT", child, "RIGHT")
    s.listing = nil
    s.check:Hide()
    s.pickQty:Hide()
    s.seller:SetPoint("RIGHT", s, "RIGHT", -(offsets().name + 6), 0)
    s:SetHeight(SUB_H)
    s.topLine:Hide()
    s.seller:SetFont(STANDARD_TEXT_FONT, 11, "")
    s.profit:SetFont(STANDARD_TEXT_FONT, 11, "")
    s.bg:SetVertexColor(0, 0, 0, 0.25)
    for _, k in ipairs({ "seller", "qty", "unit", "discount", "profit" }) do
      s[k]:SetText("")
      local c = k == "seller" and W.C.muted or W.C.ink
      s[k]:SetTextColor(c[1], c[2], c[3])
    end
    s:Show()
    return s
  end

  -- The item's auctions under an open deal, cheapest first; returns the new y.
  local function addAuctions(d, y)
    local list = ns.listings[d.id] or {}
    if ns.scan.state == "searching" and not hasSearchData(d.id) then
      sub(y).seller:SetText(L.SHOPPING_SEARCHING)
      return y + SUB_H
    end
    if #list == 0 then
      sub(y).seller:SetText(L.SHOPPING_NO_LISTINGS)
      return y + SUB_H
    end
    local h = sub(y)
    h.seller:SetText(L.COL_SELLER)
    for k, key in pairs({ qty = "COL_LISTED", unit = "COL_PAY_UNIT", discount = "COL_DISCOUNT", profit = "COL_PROFIT_EST" }) do
      h[k]:SetText(L[key])
      h[k]:SetTextColor(W.C.muted[1], W.C.muted[2], W.C.muted[3])
    end
    y = y + SUB_H
    local keep, maxPrice = ns.SaleKeep(), ns.MaxBuyPrice(d.ref)
    for i, l in ipairs(list) do
      if i > MAX_LISTINGS then
        sub(y).seller:SetText(L.SHOPPING_MORE:format(#list - MAX_LISTINGS))
        y = y + SUB_H
        break
      end
      local s = sub(y)
      s.seller:SetText(l.mine and ns.Color("gold", L.SHOPPING_YOURS) or (l.seller or "-"))
      s.qty:SetText(ns.Num(l.count))
      s.unit:SetText(ns.Money(l.unit))
      local _, roi = ns.DealProfit(l.unit, 1, d.ref)
      local tint = l.unit <= maxPrice and W.C.gold or (roi > 0 and W.C.muted or W.C.down)
      s.discount:SetTextColor(tint[1], tint[2], tint[3])
      s.discount:SetText(math.floor(roi * 100 + 0.5) .. "%")
      local p = (d.ref * keep - l.unit) * l.count
      s.profit:SetTextColor(W.C.up[1], W.C.up[2], W.C.up[3])
      s.profit:SetText(p > 0 and ns.Money(p) or ns.Color("muted", "-"))
      -- The auction this deal's row buys.
      if l == d.l then s.bg:SetVertexColor(1, 0.82, 0, 0.07) end
      if l.mine then
        for _, k in ipairs({ "qty", "unit", "discount", "profit" }) do
          s[k]:SetTextColor(W.C.muted[1], W.C.muted[2], W.C.muted[3])
        end
      elseif l == d.l then
        s.seller:SetText(ns.Color("gold", L.DEAL_MAIN) .. "  " .. (l.seller or ""))
      elseif l.commodity or l.auctionID then
        -- Item auctions without an ID (full scan) can't be bought in turn; open searches them.
        s.listing = l
        s.check:SetChecked(picks[l] ~= nil)
        s.check:Show()
        s.pickValue = picks[l] or s.pickValue
        if not s.pickQty:HasFocus() then
          s.pickQty:SetText(tostring(l.commodity and math.min(picks[l] or l.count, l.count) or l.count))
        end
        s.pickQty:SetEnabled(l.commodity == true)
        s.pickQty:Show()
        if picks[l] then s.bg:SetVertexColor(0.25, 0.82, 0.42, 0.06) end
      end
      y = y + SUB_H
    end
    -- What the deal's button buys: its own auction plus the checked ones. Bigger and
    -- highlighted, and it follows every quantity box.
    do
      local qty, cost
      if d.l.commodity then
        qty = ns.DealBuyQty(d) + d.extraQty
        cost = cheapestCost(list, qty)
      else
        qty, cost = d.l.count, d.l.unit * d.l.count
        for _, e in ipairs(extrasOf(d)) do
          qty, cost = qty + e.qty, cost + e.l.unit * e.qty
        end
      end
      local s = sub(y)
      s:SetHeight(TOTAL_H)
      s.topLine:Show()
      s.bg:SetVertexColor(1, 0.82, 0, 0.13)
      s.seller:SetFont(STANDARD_TEXT_FONT, 14, "")
      s.profit:SetFont(STANDARD_TEXT_FONT, 14, "")
      s.seller:SetText(ns.Color("gold", L.DEAL_PICK_TOTAL:format(ns.Num(qty), ns.Money(cost)))
        .. (d.l.commodity and (d.extraN or 0) > 0 and ns.Color("muted", "  " .. L.DEAL_PICK_CHEAPEST) or ""))
      s.seller:SetPoint("RIGHT", s, "RIGHT", -(offsets().profit + colWidth("profit") + 6), 0)
      local p = rowProfit(d)
      s.profit:SetTextColor(W.C.up[1], W.C.up[2], W.C.up[3])
      s.profit:SetText(p > 0 and ns.Money(p) or ns.Color("muted", "-"))
      y = y + TOTAL_H
    end
    return y
  end

  function f:Refresh()
    local checking = ns.checkingDeals == true
    local deals = ns.dealsReady and ns.deals or {}
    loading:SetShown(checking)
    if checking then loadingStatus:SetText(ns.ScanStatus()) end
    local keep = ns.SaleKeep()
    for _, d in ipairs(deals) do
      d.extraQty, d.extraProfit, d.extraN = 0, 0, 0
      for _, e in ipairs(extrasOf(d)) do
        d.extraQty = d.extraQty + e.qty
        d.extraProfit = d.extraProfit + (d.ref * keep - e.l.unit) * e.qty
        d.extraN = d.extraN + 1
      end
      -- After a purchase the checked auctions are done (commodities buy them all at once).
      d.onBought = function()
        d.done = true
        if d.l.commodity then clearPicks(d.id) end
      end
    end
    local list = {}
    for _, d in ipairs(checking and {} or deals) do
      if d.roi and d.roi > 0 then list[#list + 1] = d end
    end
    if sorter.col then W.SortRows(list, sortValue[sorter.col], sorter.asc) end

    local good, total = 0, 0
    for _, d in ipairs(deals) do
      if d.good then
        good = good + 1
        total = total + math.max(rowProfit(d), 0)
      end
    end
    -- Empty until a scan or "Check deals" of this visit has finished calculating.
    if checking or not ns.dealsReady then
      count:Set("")
      profit:Set("")
    else
      count:Set(good .. ns.Color("muted", "  / " .. #deals))
      profit:Set(ns.Money(total), W.C.up)
    end
    gold:Set(ns.Money(GetMoney()))

    local o = offsets()
    local y = 0
    nSubs = 0
    for i, d in ipairs(list) do
      local r = rows[i]
      if not r then
        r = makeRow(child, self)
        rows[i] = r
        layoutRow(r, o)
      end
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 0, -y)
      r:SetPoint("RIGHT", child, "RIGHT")
      r.bg:SetVertexColor(1, 1, 1, i % 2 == 0 and 0.02 or 0)
      y = y + ROW_H
      r.deal = d
      r.arrow:SetText(open[d.id] and "-" or "+")
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
      -- Item auctions checked under the deal: "Buy (3)", then "Buy 2/3" while the queue runs.
      local head, step = queueHead(d)
      local busy = head or d
      if head and not (head.state == "locating" or head.state == "quote" or head.state == "buying"
        or head.state == "confirm") then
        r.buy:SetText(L.BUY_STEP:format(step, #d.queue))
      elseif head then
        r.buy:SetText(ns.DealButtonText(head))
      elseif not d.l.commodity and d.extraN > 0 then
        r.buy:SetText(L.BUY_N:format(d.extraN + 1))
      else
        r.buy:SetText(ns.DealButtonText(d))
      end
      -- Only busy while the game is answering; after a purchase it can buy again.
      -- More units than are for sale: the game wouldn't answer the quote, so the button
      -- waits (and the number turns red) until the quantity fits again.
      local forSale = d.l.commodity and ns.UnitsForSale(d.id)
      local tooMany = forSale and ns.DealBuyQty(d) + (d.extraQty or 0) > forSale
      local c = tooMany and W.C.down or W.C.ink
      r.buyQty:SetTextColor(c[1], c[2], c[3])
      r.buy:SetEnabled(ns.ahOpen == true and not tooMany and busy.state ~= "locating" and busy.state ~= "buying"
        and busy.state ~= "quote")
      -- While a purchase is pending the button makes room for the cancel button, and the
      -- quantity stays visible but locked.
      local pending = busy.state == "confirm" or d.queue ~= nil
      r.cancel:SetShown(pending)
      r.buy:SetWidth(pending and BUY_W - 22 or BUY_W)
      r.buy:SetPoint("RIGHT", pending and -24 or -2, 0)
      if pending then r.buyQty:SetEnabled(false) end
      r:Show()
      if open[d.id] then y = addAuctions(d, y) end
    end
    for i = #list + 1, #rows do rows[i]:Hide() end
    for i = nSubs + 1, #subs do subs[i]:Hide() end
    child:SetHeight(math.max(1, y))

    local msg = ""
    if #list == 0 and not checking then
      if not ns.dealsReady then msg = L.DEALS_START
      elseif not ns.HasPrices() then msg = L.NO_PRICES
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
