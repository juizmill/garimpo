local _, ns = ...
local L, W = ns.L, ns.W

local ROW_H, SUB_H = 24, 20
local MAX_LISTINGS = 10   -- auctions shown under an open item
-- Distance of each column's right edge from the row's right edge.
local COL = { remove = 2, buy = 30, buyQty = 136, total = 182, unit = 272, listed = 358, need = 414 }

-- Listings of other players, cheapest first.
local function others(id)
  local out = {}
  for _, l in ipairs(ns.listings[id] or {}) do
    if not l.mine then out[#out + 1] = l end
  end
  return out
end

-- Cost of buying qty units from the cheapest listings, and how many are listed.
local function costOf(id, qty)
  local list = others(id)
  local listed, sum, n = 0, 0, 0
  for _, l in ipairs(list) do
    listed = listed + l.count
    if n < qty then
      local take = math.min(l.count, qty - n)
      sum, n = sum + l.unit * take, n + take
    end
  end
  if #list == 0 then
    local p = ns.Price(id)
    return p and p * qty or nil, nil
  end
  return sum, listed
end

local function busy(d)
  return d.state == "locating" or d.state == "quote" or d.state == "buying" or d.state == "confirm"
end

local function canClick(d)
  return ns.ahOpen == true and not (d.state == "locating" or d.state == "buying" or d.state == "quote")
end

local function makeRow(parent, view)
  local r = CreateFrame("Frame", nil, parent)
  r:SetHeight(ROW_H)
  r.bg = r:CreateTexture(nil, "BACKGROUND")
  r.bg:SetAllPoints()
  r.bg:SetTexture(W.FLAT)

  r.check = W.CheckBox(r, function(on)
    if r.entry then view:SetChecked(r.entry.id, on) end
  end)
  r.check:SetPoint("LEFT", 2, 0)
  -- + / - : opens the item's auctions under the row.
  r.arrow = W.Font(r, 13, W.C.gold, "CENTER")
  r.arrow:SetPoint("LEFT", 20, 0)
  r.arrow:SetWidth(12)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(18, 18)
  r.icon:SetPoint("LEFT", 34, 0)

  r.remove = W.Close(r, function()
    if r.entry then ns:RemoveFromShopping({ [r.entry.id] = true }) end
  end)
  r.remove:SetPoint("RIGHT", -COL.remove, 0)
  r.remove:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L.SHOPPING_REMOVE)
    GameTooltip:Show()
  end)
  r.remove:HookScript("OnLeave", GameTooltip_Hide)
  r.buy = W.Button(r, nil, 100, function()
    if not r.deal then return end
    -- Locating opens the row to show what the search finds.
    if not r.deal.l.commodity and not r.deal.l.auctionID or r.deal.needsLocate or r.deal.state == "gone" then
      view:SetOpen(r.entry.id, true)
    end
    ns:BuyDeal(r.deal)
  end, "primary")
  r.buy:SetHeight(20)
  r.buy:SetPoint("RIGHT", -COL.buy, 0)
  -- Units to buy (commodities); items are bought one auction at a time.
  r.buyQty = W.Edit(r, 36, function(text)
    local v = tonumber(text)
    if r.deal and v and v > 0 then
      r.deal.buyQty, r.deal.qtyEdited = math.floor(v), true
      if r.deal.state == "confirm" then r.deal.state = nil end   -- price must be quoted again
    end
  end)
  r.buyQty:SetMaxLetters(4)
  r.buyQty:SetPoint("RIGHT", -(COL.buyQty + 2), 0)
  for _, k in ipairs({ "total", "unit", "listed", "need" }) do
    r[k] = W.Font(r, 12, W.C.ink, "RIGHT")
    r[k]:SetPoint("RIGHT", -COL[k], 0)
    r[k]:SetWidth(k == "total" and 84 or (k == "unit" and 80 or 50))
  end
  r.name = W.Font(r, 12, W.C.ink)
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
  r.name:SetPoint("RIGHT", r.need, "LEFT", -6, 0)

  local hover = CreateFrame("Button", nil, r)
  hover:SetPoint("TOPLEFT", r.arrow, "TOPLEFT", 0, 4)
  hover:SetPoint("BOTTOM")
  hover:SetPoint("RIGHT", r.need, "LEFT", -6, 0)
  hover:SetScript("OnEnter", function(self)
    if not r.entry then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. r.entry.id)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.SHOPPING_CLICK_OPEN, 0.6, 0.56, 0.49)
    GameTooltip:AddLine(L.DOUBLE_CLICK_SEARCH, 0.6, 0.56, 0.49)
    GameTooltip:Show()
  end)
  hover:SetScript("OnLeave", GameTooltip_Hide)
  hover:SetScript("OnClick", function()
    if r.entry then view:SetOpen(r.entry.id) end
  end)
  hover:SetScript("OnDoubleClick", function()
    if r.entry then ns.ShowInAuctionHouse(r.entry.id) end
  end)
  return r
end

-- One line under an open item: an auction (seller, price, quantity, total), the column
-- titles, or a message.
local function makeSub(parent)
  local s = CreateFrame("Frame", nil, parent)
  s:SetHeight(SUB_H)
  s.bg = s:CreateTexture(nil, "BACKGROUND")
  s.bg:SetAllPoints()
  s.bg:SetTexture(W.FLAT)
  s.bg:SetVertexColor(0, 0, 0, 0.25)
  s.seller = W.Font(s, 11, W.C.muted)
  s.seller:SetPoint("LEFT", 56, 0)
  s.seller:SetPoint("RIGHT", s, "RIGHT", -(COL.listed + 56), 0)
  for _, k in ipairs({ "total", "unit", "listed" }) do
    s[k] = W.Font(s, 11, W.C.ink, "RIGHT")
    s[k]:SetPoint("RIGHT", -COL[k], 0)
    s[k]:SetWidth(k == "total" and 84 or (k == "unit" and 80 or 50))
  end
  s.buy = W.Button(s, nil, 100, function()
    if s.deal then ns:BuyDeal(s.deal) end
  end, "primary")
  s.buy:SetHeight(18)
  s.buy:SetPoint("RIGHT", -COL.buy, 0)
  return s
end

-- The Professions tab of the Auction House panel: the shopping list made in
-- Professions > Buy or farm. The caller anchors the returned frame.
function ns.BuildShoppingView(parent)
  local f = CreateFrame("Frame", nil, parent)
  local checked = {}   -- [itemID] = true
  local open = {}      -- [itemID] = true: its auctions are shown under it
  local deals = {}     -- [itemID] = buy state for ns:BuyDeal
  local auctionDeals = setmetatable({}, { __mode = "k" })   -- listing -> buy state of that auction

  local all = W.Check(f, "CANCEL_SELECT_ALL", function(on)
    for _, e in ipairs(ns.char.shopping) do checked[e.id] = on or nil end
    f:Refresh()
  end)
  all:SetPoint("TOPLEFT", 0, -2)

  local remove = W.Button(f, "SHOPPING_REMOVE_CHECKED", 140, function()
    local gone = {}
    for id in pairs(checked) do gone[id] = true end
    wipe(checked)
    ns:RemoveFromShopping(gone)
  end, "danger")
  remove:SetPoint("TOPRIGHT", 0, 0)
  -- Searches every item on the list: real prices and quantities, and auction IDs so each
  -- one buys with a single click.
  local search = W.Button(f, "SEARCH_AH", 130, function()
    local ids = {}
    for _, e in ipairs(ns.char.shopping) do ids[#ids + 1] = e.id end
    if #ids > 0 then ns:QuickSearch(ids, function() f:Refresh() end) end
  end)
  search:SetPoint("RIGHT", remove, "LEFT", -6, 0)

  local hdr = CreateFrame("Frame", nil, f)
  hdr:SetPoint("TOPLEFT", 0, -30)
  hdr:SetPoint("TOPRIGHT", -24, -30)
  hdr:SetHeight(16)
  local itemHeader = W.Font(hdr, 10, W.C.muted)
  itemHeader:SetPoint("LEFT", 56, 0)
  W.Label(itemHeader, "COL_ITEM")
  local titles = { need = "COL_NEEDED", listed = "COL_LISTED", unit = "COL_PAY_UNIT", total = "COL_TOTAL", buyQty = "COL_BUY_QTY" }
  for k, key in pairs(titles) do
    local fs = W.Font(hdr, 10, W.C.muted, k == "buyQty" and "CENTER" or "RIGHT")
    fs:SetPoint("RIGHT", -COL[k], 0)
    fs:SetWidth(k == "total" and 84 or (k == "unit" and 80 or (k == "buyQty" and 40 or 50)))
    W.Label(fs, key)
  end
  local line = W.Line(hdr)
  line:SetPoint("BOTTOMLEFT")
  line:SetPoint("BOTTOMRIGHT")

  local sf = W.Scroll(f)
  sf:SetPoint("TOPLEFT", 0, -48)
  sf:SetPoint("BOTTOMRIGHT", -24, 30)
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(560, 1)
  sf:SetScrollChild(child)
  sf:SetScript("OnSizeChanged", function(_, w) child:SetWidth(w) end)
  local rows, subs = {}, {}

  local empty = W.Font(f, 12, W.C.muted, "CENTER")
  empty:SetPoint("TOPLEFT", 20, -84)
  empty:SetPoint("TOPRIGHT", -20, -84)
  empty:SetWordWrap(true)
  W.Label(empty, "SHOPPING_EMPTY")

  local foot = W.Font(f, 11, W.C.muted)
  foot:SetPoint("BOTTOMLEFT", 0, 6)
  foot:SetPoint("RIGHT", 0, 0)
  foot:SetWordWrap(true)

  function f:SetChecked(id, on)
    checked[id] = on or nil
    self:Refresh()
  end

  -- on: true opens, nil toggles.
  function f:SetOpen(id, on)
    if on == nil then on = not open[id] end
    open[id] = on or nil
    self:Refresh()
  end

  -- Buy state of an item, following the cheapest listing of the last search.
  local function dealFor(e)
    local d = deals[e.id]
    if not d then
      d = { id = e.id, anyPrice = true, onBought = function(qty) ns:ShoppingBought(e.id, qty) end }
      deals[e.id] = d
    end
    if not busy(d) then
      local l = others(e.id)[1]
      if l and l ~= d.l then
        d.l, d.needsLocate = l, nil
        if d.state == "gone" then d.state = nil end
      elseif not d.l then
        d.l = { unit = ns.Price(e.id) or 0, count = 0 }
      end
    end
    d.ref = d.l.unit
    if not d.qtyEdited then d.buyQty = e.qty end
    return d
  end

  -- Buy state of one auction under an open item (items only; commodities are bought by
  -- quantity on the item's row).
  local function auctionDeal(e, l)
    local d = auctionDeals[l]
    if not d then
      d = { id = e.id, l = l, ref = l.unit, anyPrice = true, onBought = function(qty) ns:ShoppingBought(e.id, qty) end }
      auctionDeals[l] = d
    end
    return d
  end

  local nSubs
  local function sub(y)
    nSubs = nSubs + 1
    local s = subs[nSubs] or makeSub(child)
    subs[nSubs] = s
    s:ClearAllPoints()
    s:SetPoint("TOPLEFT", 0, -y)
    s:SetPoint("RIGHT", child, "RIGHT")
    s.deal = nil
    s.buy:Hide()
    for _, k in ipairs({ "seller", "unit", "listed", "total" }) do
      s[k]:SetText("")
      s[k]:SetTextColor(W.C.ink[1], W.C.ink[2], W.C.ink[3])
    end
    s.seller:SetTextColor(W.C.muted[1], W.C.muted[2], W.C.muted[3])
    s:Show()
    return s
  end

  -- Lines under an open item; returns the new y.
  local function addAuctions(e, d, y)
    local list = ns.listings[e.id] or {}
    if d.state == "locating" or (#list == 0 and ns.scan.state == "searching") then
      sub(y).seller:SetText(L.SHOPPING_SEARCHING)
      return y + SUB_H
    end
    if #list == 0 then
      sub(y).seller:SetText(L.SHOPPING_NO_LISTINGS)
      return y + SUB_H
    end
    local h = sub(y)
    h.seller:SetText(L.COL_SELLER)
    h.unit:SetText(L.COL_PAY_UNIT)
    h.listed:SetText(L.COL_QTY)
    h.total:SetText(L.COL_TOTAL)
    for _, k in ipairs({ "unit", "listed", "total" }) do h[k]:SetTextColor(W.C.muted[1], W.C.muted[2], W.C.muted[3]) end
    y = y + SUB_H
    for i, l in ipairs(list) do
      if i > MAX_LISTINGS then
        sub(y).seller:SetText(L.SHOPPING_MORE:format(#list - MAX_LISTINGS))
        return y + SUB_H
      end
      local s = sub(y)
      s.seller:SetText(l.mine and ns.Color("gold", L.SHOPPING_YOURS) or (l.seller or "-"))
      s.unit:SetText(ns.Money(l.unit))
      s.listed:SetText(ns.Num(l.count))
      s.total:SetText(ns.Money(l.unit * l.count))
      if l.mine then
        local m = W.C.muted
        for _, k in ipairs({ "unit", "listed", "total" }) do s[k]:SetTextColor(m[1], m[2], m[3]) end
      elseif l.auctionID and not l.commodity then
        local ad = auctionDeal(e, l)
        s.deal = ad
        s.buy:SetText(ns.DealButtonText(ad))
        s.buy:SetEnabled(canClick(ad) and ad.state ~= "gone" and not ad.needsLocate)
        s.buy:Show()
      end
      y = y + SUB_H
    end
    return y
  end

  function f:Refresh()
    local list = ns.char.shopping
    local allOn, nChecked, sum, y = #list > 0, 0, 0, 0
    nSubs = 0
    for i, e in ipairs(list) do
      local r = rows[i] or makeRow(child, self)
      rows[i] = r
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 0, -y)
      r:SetPoint("RIGHT", child, "RIGHT")
      r.bg:SetVertexColor(1, 1, 1, i % 2 == 0 and 0.02 or 0)
      y = y + ROW_H
      local d = dealFor(e)
      r.entry, r.deal = e, d
      r.check:SetChecked(checked[e.id] == true)
      if checked[e.id] then nChecked = nChecked + 1 else allOn = false end
      r.arrow:SetText(open[e.id] and "-" or "+")
      r.icon:SetTexture(ns.ItemIcon(e.id))
      local bought = d.boughtCount and ns.Color("up", "  +" .. d.boughtCount) or ""
      r.name:SetText("|cff" .. ns.ItemQualityHex(e.id) .. ns.ItemName(e.id) .. "|r" .. bought)
      r.need:SetText(ns.Num(e.qty))
      local total, listed = costOf(e.id, e.qty)
      r.listed:SetText(listed and ns.Num(listed) or ns.Color("muted", "-"))
      r.unit:SetText(d.l.unit > 0 and ns.Money(d.l.unit) or ns.Color("muted", "-"))
      r.total:SetText(total and ns.Money(total) or ns.Color("muted", "-"))
      sum = sum + (total or 0)
      local single = ns.DealIsSingle(d)
      if not r.buyQty:HasFocus() then
        r.buyQty:SetText(tostring(single and d.l.count or ns.DealBuyQty(d)))
      end
      r.buyQty:SetEnabled(not single)
      r.buy:SetText(ns.DealButtonText(d))
      r.buy:SetEnabled(canClick(d))
      r:Show()
      if open[e.id] then y = addAuctions(e, d, y) end
    end
    for i = #list + 1, #rows do rows[i]:Hide() end
    for i = nSubs + 1, #subs do subs[i]:Hide() end
    child:SetHeight(math.max(1, y))
    empty:SetShown(#list == 0)
    all:SetChecked(allOn)
    remove:SetEnabled(nChecked > 0)
    search:SetEnabled(#list > 0 and ns.ahOpen == true and ns.scan.state == "idle")
    foot:SetText(#list > 0 and L.SHOPPING_FOOT:format(ns.Money(sum)) or "")
  end

  return f
end
