local _, ns = ...
local L, W = ns.L, ns.W

local panel
local ROW_H = 26
local MIN_W, MIN_H = 720, 470   -- room for the Deals tab columns
-- Distance of each column's right edge from the row's right edge.
local COL = { price = 68, pct = 152, margin = 164, ah = 212, qty = 288 }
local overrides = {}   -- [itemID] = margin typed in the panel this session

local function marginFor(id)
  if overrides[id] then return overrides[id] end
  local cat = ns:CategoryOf(id)
  local m = cat and ns.db.settings.categoryMargin[cat]
  return m or ns.db.settings.defaultMargin
end

-- Margin applies to the lowest price on the Auction House (0% = match the cheapest).
local function lowest(e)
  return ns.Price(e.id) or e.unit
end

local function priceFor(e)
  return math.max(1, math.floor(lowest(e) * (1 + marginFor(e.id) / 100) + 0.5))
end

local function entries()
  local rows = ns:BagReport(false)
  local showHold, ignored = ns.db.settings.showHold, ns.db.ignored
  local out = {}
  for _, e in ipairs(rows) do
    if e.unit and e.quality and e.quality > 0 and not ignored[e.id] and (showHold or e.advice ~= "hold")
      and #ns:FindSlots(e.id) > 0 then
      out[#out + 1] = e
    end
  end
  return out
end

local function setIgnored(id, on)
  ns.db.ignored[id] = on or nil
  if panel then panel:Refresh() end
end

-- Right-click menu on a row of the Post tab.
local function rowMenu(owner, id)
  if MenuUtil and MenuUtil.CreateContextMenu then
    MenuUtil.CreateContextMenu(owner, function(_, root)
      root:CreateTitle(ns.ItemName(id))
      root:CreateButton(L.IGNORE_ITEM, function() setIgnored(id, true) end)
    end)
  else
    setIgnored(id, true)
  end
end

-- Modern Auction House (Forever's engine). Prices go in whole silver.
local function postModern(e, slot)
  local loc = ItemLocation:CreateFromBagAndSlot(slot.bag, slot.slot)
  if not (C_Item.DoesItemExist and C_Item.DoesItemExist(loc)) then return nil end
  local unit = math.max(100, math.floor(priceFor(e) / 100 + 0.5) * 100)
  local duration = ns.db.settings.duration
  local status = C_AuctionHouse.GetItemCommodityStatus(loc)
  if status == Enum.ItemCommodityStatus.Commodity then
    C_AuctionHouse.PostCommodity(loc, duration, slot.count, unit)
  elseif status == Enum.ItemCommodityStatus.Item then
    local bid = math.floor(unit * ns.db.settings.bidPercent / 100 / 100) * 100
    if bid < 100 or bid >= unit then bid = nil end
    C_AuctionHouse.PostItem(loc, duration, slot.count, bid, unit)
  else
    return nil
  end
  return slot.count, unit * slot.count
end

-- Posts one stack of the item. Must run from a click (the game requires a hardware event).
local function postEntry(e)
  if not ns.ahOpen then return end
  local slot = ns:FindSlots(e.id)[1]
  if not slot then return end
  if C_AuctionHouse and C_AuctionHouse.PostCommodity then
    local count, total = postModern(e, slot)
    if count then
      ns.Print(L.POSTED:format(count, ns.ItemName(e.id), ns.PlainMoney(total)))
    else
      ns.Print(L.POST_FAILED)
    end
    return
  end
  if GetAuctionSellItemInfo() then
    ClickAuctionSellItemButton()
    ClearCursor()
  end
  C_Container.PickupContainerItem(slot.bag, slot.slot)
  ClickAuctionSellItemButton()
  ClearCursor()
  local name, _, count = GetAuctionSellItemInfo()
  if not name then
    ns.Print(L.POST_FAILED)
    return
  end
  local buyout = priceFor(e) * count
  local bid = math.max(1, math.floor(buyout * ns.db.settings.bidPercent / 100))
  PostAuction(bid, buyout, ns.db.settings.duration, count, 1)
  ns.Print(L.POSTED:format(count, name, ns.PlainMoney(buyout)))
end

-- Key binding (Bindings.xml): the main button of the open tab. Cancel tab: cancel the
-- next auction; any other tab: the "Post next" button at the bottom of the Post tab.
function GarimpoPanelKey()
  if not ns.ahOpen then ns.Print(L.SCAN_NEED_AH); return end
  if panel and panel:IsShown() and panel.tab == "cancel" then
    GarimpoCancelNext()
  elseif panel and panel.nextEntry then
    postEntry(panel.nextEntry)
  else
    ns.Print(L.ALL_POSTED)
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

  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(18, 18)
  r.icon:SetPoint("LEFT", 4, 0)
  -- Columns are anchored from the right, so the item name takes any extra width
  -- when the panel is stretched.
  r.post = W.Button(r, "POST", 56, function() if r.entry then postEntry(r.entry) end end, "primary")
  r.post:SetHeight(20)
  r.post:SetPoint("RIGHT", -4, 0)
  r.price = W.Font(r, 12, W.C.gold, "RIGHT")
  r.price:SetPoint("RIGHT", -(COL.price), 0)
  r.price:SetWidth(76)
  local pct = W.Font(r, 12, W.C.muted)
  pct:SetPoint("RIGHT", -(COL.pct), 0)
  pct:SetText("%")
  r.margin = W.Edit(r, 38, function(text)
    local v = tonumber(text)
    if r.entry then
      overrides[r.entry.id] = v and math.max(-90, v) or nil
      r.price:SetText(ns.Money(priceFor(r.entry)))
      r.margin.edited = true
      panel:UpdateNext()
    end
  end)
  r.margin:SetPoint("RIGHT", -(COL.margin), 0)
  r.ah = W.Font(r, 12, W.C.ink, "RIGHT")
  r.ah:SetPoint("RIGHT", -(COL.ah), 0)
  r.ah:SetWidth(70)
  r.qty = W.Font(r, 12, W.C.ink, "RIGHT")
  r.qty:SetPoint("RIGHT", -(COL.qty), 0)
  r.qty:SetWidth(36)
  r.name = W.Font(r, 12, W.C.ink)
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
  r.name:SetPoint("RIGHT", r.qty, "LEFT", -6, 0)

  local hover = CreateFrame("Frame", nil, r)
  hover:SetPoint("TOPLEFT")
  hover:SetPoint("BOTTOMLEFT")
  hover:SetPoint("RIGHT", r.qty, "LEFT", -6, 0)
  hover:SetScript("OnEnter", function(self)
    if not r.entry then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetHyperlink("item:" .. r.entry.id)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.RIGHT_CLICK_IGNORE, 0.6, 0.56, 0.49)
    GameTooltip:Show()
  end)
  hover:SetScript("OnLeave", GameTooltip_Hide)
  hover:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" and r.entry then rowMenu(self, r.entry.id) end
  end)
  return r
end

local function create()
  panel = CreateFrame("Frame", "GarimpoAuctionPanel", UIParent, "BackdropTemplate")
  panel:SetSize(MIN_W, MIN_H)
  panel:SetBackdrop({ bgFile = W.FLAT, edgeFile = W.FLAT, edgeSize = 2 })
  panel:SetBackdropColor(unpack(W.C.bg))
  panel:SetBackdropBorderColor(unpack(W.C.edge))
  panel:SetFrameStrata("HIGH")
  panel:SetToplevel(true)
  panel:SetClampedToScreen(true)
  panel:EnableMouse(true)
  panel:SetMovable(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", panel.StartMoving)
  panel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint()
    ns.char.ahPanel = { point, rel, x, y }
  end)

  local icon = panel:CreateTexture(nil, "ARTWORK")
  icon:SetSize(18, 18)
  icon:SetPoint("TOPLEFT", 10, -9)
  icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
  local title = W.Font(panel, 14, W.C.gold)
  title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
  W.Label(title, "AH_PANEL_TITLE")
  local close = W.Close(panel)
  close:SetPoint("TOPRIGHT", -5, -6)
  W.Window(panel, 31)
  W.IconFrame(icon)
  W.FadeIn(panel)

  panel.scanButton = W.Button(panel, "FULL_SCAN", 130, function() ns:FullScan() end)
  panel.scanButton:SetHeight(20)
  panel.scanButton:SetPoint("TOPRIGHT", -32, -8)
  panel.scanStatus = W.Font(panel, 10, W.C.muted, "RIGHT")
  panel.scanStatus:SetPoint("RIGHT", panel.scanButton, "LEFT", -8, 0)
  panel.scanStatus:SetPoint("LEFT", title, "RIGHT", 10, 0)

  -- Tabs: posting your items, deals to buy, the professions shopping list, cancelling, ignored items.
  panel.tabs = W.Chips(panel, function(v) panel:SelectTab(v) end, "tab")
  panel.tabs:SetPoint("TOPLEFT", 10, -34)
  panel.tabs:SetItems({
    { value = "post", key = "AH_TAB_POST" }, { value = "deals", key = "TAB_DEALS" },
    { value = "shopping", key = "AH_TAB_PROFESSION" }, { value = "cancel", key = "AH_TAB_CANCEL" }, { value = "ignored", key = "AH_TAB_IGNORED" },
  })

  -- Cancel your auctions by name and quantity, or the undercut ones.
  panel.cancel = ns.BuildCancelView(panel)
  panel.cancel:SetPoint("TOPLEFT", 10, -64)
  panel.cancel:SetPoint("BOTTOMRIGHT", -10, 22)
  panel.cancel:Hide()

  -- Ignored items: click one to show it again in the Post tab.
  panel.ignored = W.List(panel, { { width = 400, header = "COL_ITEM" } }, 22)
  panel.ignored:SetPoint("TOPLEFT", 10, -64)
  panel.ignored:SetPoint("BOTTOMRIGHT", -10, 22)
  panel.ignored:Hide()
  function panel.ignored:Refresh()
    local data = {}
    for id in pairs(ns.db.ignored) do
      data[#data + 1] = {
        icon = ns.ItemIcon(id),
        cells = { "|cff" .. ns.ItemQualityHex(id) .. ns.ItemName(id) .. "|r" },
        sort = { ns.ItemName(id) },
        tip = { ns.ItemName(id), ns.Color("gold", L.CLICK_UNIGNORE) },
        onClick = function() setIgnored(id, false) end,
      }
    end
    table.sort(data, function(a, b) return a.sort[1] < b.sort[1] end)
    self:SetData(data, L.IGNORED_EMPTY)
  end

  local post = CreateFrame("Frame", nil, panel)
  post:SetPoint("TOPLEFT", 0, -64)
  post:SetPoint("BOTTOMRIGHT")
  panel.post = post

  panel.deals = ns.BuildDealsView(panel)
  panel.deals:SetPoint("TOPLEFT", 10, -64)
  panel.deals:SetPoint("BOTTOMRIGHT", -10, 22)
  panel.deals:Hide()

  panel.shopping = ns.BuildShoppingView(panel)
  panel.shopping:SetPoint("TOPLEFT", 10, -64)
  panel.shopping:SetPoint("BOTTOMRIGHT", -10, 22)
  panel.shopping:Hide()

  for _, view in ipairs({ post, panel.deals, panel.shopping, panel.cancel, panel.ignored }) do
    W.FadeIn(view, 0.12)
  end

  function panel:SelectTab(tab)
    self.tab = tab
    self.tabs:Select(tab)
    self.post:SetShown(tab == "post")
    self.deals:SetShown(tab == "deals")
    self.shopping:SetShown(tab == "shopping")
    self.ignored:SetShown(tab == "ignored")
    self.cancel:SetShown(tab == "cancel")
    if tab == "cancel" then ns:QueryOwned() end
    self:Refresh()
  end

  local hdr = CreateFrame("Frame", nil, post)
  hdr:SetPoint("TOPLEFT", 10, 0)
  hdr:SetPoint("TOPRIGHT", -34, 0)
  hdr:SetHeight(16)
  -- Clickable titles sort the list.
  panel.sorter = W.Sorter(function() panel:Refresh() end, { name = true })
  local itemHeader = W.SortHeader(hdr, "COL_ITEM", 160, "LEFT")
  itemHeader:SetPoint("LEFT", 4, 0)
  panel.sorter:Add(itemHeader, "name")
  local function col(key, sortKey, right, w)
    local h = W.SortHeader(hdr, key, w, "RIGHT")
    h:SetPoint("RIGHT", -right, 0)
    if sortKey then panel.sorter:Add(h, sortKey) end
  end
  col("COL_QTY", "count", COL.qty, 36)
  col("COL_AH", "lowest", COL.ah, 70)
  col("COL_MARGIN", nil, COL.margin - 12, 60)
  col("COL_YOUR_PRICE", "price", COL.price, 76)
  local line = W.Line(hdr)
  line:SetPoint("BOTTOMLEFT")
  line:SetPoint("BOTTOMRIGHT")

  local sf = W.Scroll(post)
  sf:SetPoint("TOPLEFT", 10, -18)
  sf:SetPoint("BOTTOMRIGHT", -34, 104)
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(MIN_W - 44, 1)
  sf:SetScrollChild(child)
  sf:SetScript("OnSizeChanged", function(_, w) child:SetWidth(w) end)
  panel.child, panel.rows = child, {}

  -- Stretch from the bottom-right corner; never smaller than the starting size.
  panel:SetResizable(true)
  if panel.SetResizeBounds then
    panel:SetResizeBounds(MIN_W, MIN_H, 1200, 1000)
  elseif panel.SetMinResize then
    panel:SetMinResize(MIN_W, MIN_H)
  end
  local grip = CreateFrame("Button", nil, panel)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -2, 2)
  grip:SetFrameLevel(panel:GetFrameLevel() + 10)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:SetScript("OnMouseDown", function() panel:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function()
    panel:StopMovingOrSizing()
    ns.char.ahPanelSize = { panel:GetWidth(), panel:GetHeight() }
    local point, _, rel, x, y = panel:GetPoint()
    ns.char.ahPanel = { point, rel, x, y }
  end)
  local size = ns.char.ahPanelSize
  if size and size[1] then
    panel:SetSize(math.max(size[1], MIN_W), math.max(size[2], MIN_H))
  end

  panel.empty = W.Font(post, 12, W.C.muted, "CENTER")
  panel.empty:SetPoint("TOPLEFT", 20, -54)
  panel.empty:SetPoint("TOPRIGHT", -20, -54)
  panel.empty:SetWordWrap(true)

  panel.info = W.Font(post, 11, W.C.muted)
  panel.info:SetPoint("BOTTOMLEFT", 10, 80)
  panel.info:SetPoint("RIGHT", -10, 0)

  panel.hold = W.Check(post, "SHOW_HOLD_ITEMS", function(on)
    ns.db.settings.showHold = on
    panel:Refresh()
  end)
  panel.hold:SetPoint("BOTTOMLEFT", 8, 54)

  panel.next = W.Button(post, nil, nil, nil, "primary")
  panel.next.text:SetFont(STANDARD_TEXT_FONT, 13, "")
  panel.next:SetPoint("BOTTOMLEFT", 10, 10)
  panel.next:SetPoint("BOTTOMRIGHT", -10, 10)
  panel.next:SetHeight(38)
  panel.next:SetScript("OnClick", function()
    if panel.nextEntry then postEntry(panel.nextEntry) end
  end)

  function panel:UpdateNext()
    local e = self.list and self.list[1]
    self.nextEntry = e
    if e then
      local slot = ns:FindSlots(e.id)[1]
      local count = slot and slot.count or 1
      self.next:SetText(L.POST_NEXT:format(ns.ItemName(e.id), count, ns.PlainMoney(priceFor(e) * count)))
      self.next:Enable()
    else
      self.next:SetText(L.ALL_POSTED)
      self.next:Disable()
    end
  end

  local sortValue = {
    name = function(e) return ns.ItemName(e.id) end,
    count = function(e) return e.count end,
    lowest = function(e) return lowest(e) end,
    price = function(e) return priceFor(e) end,
  }

  function panel:Refresh()
    self.list = entries()
    local s = self.sorter
    if s.col then W.SortRows(self.list, sortValue[s.col], s.asc) end
    for i, e in ipairs(self.list) do
      local r = self.rows[i] or makeRow(self.child, i)
      self.rows[i] = r
      if r.entry ~= e then r.margin.edited = false end
      r.entry = e
      r.icon:SetTexture(ns.ItemIcon(e.id))
      r.name:SetText("|cff" .. ns.ItemQualityHex(e.id) .. ns.ItemName(e.id) .. "|r")
      r.qty:SetText(ns.Num(e.count))
      r.ah:SetText(ns.Money(lowest(e)))
      if not r.margin:HasFocus() then r.margin:SetText(tostring(marginFor(e.id))) end
      r.margin:SetTextColor(overrides[e.id] and 1 or 0.91, overrides[e.id] and 0.82 or 0.88, overrides[e.id] and 0 or 0.82)
      r.price:SetText(ns.Money(priceFor(e)))
      r:Show()
    end
    for i = #self.list + 1, #self.rows do self.rows[i]:Hide() end
    self.child:SetHeight(math.max(1, #self.list * ROW_H))
    self.empty:SetText(#self.list == 0 and (ns.HasPrices() and L.AH_NOTHING or L.NO_PRICES) or "")
    self.scanStatus:SetText(ns.ScanStatus())
    local wait = ns:FullScanWait()
    self.scanButton:SetEnabled(ns.CanScan() and ns.scan.state == "idle" and wait == 0)
    self.scanButton:SetText(wait > 0 and L.FULL_SCAN_IN:format(ns.Duration(wait / 60 + 0.5)) or L.FULL_SCAN)
    local durations = { "12h", "24h", "48h" }
    self.info:SetText(L.AH_INFO:format(ns.db.settings.defaultMargin, durations[ns.db.settings.duration] or "24h",
      ns.db.settings.bidPercent))
    self.hold:SetChecked(ns.db.settings.showHold)
    self:UpdateNext()
    if self.deals:IsShown() then self.deals:Refresh() end
    if self.shopping:IsShown() then self.shopping:Refresh() end
    if self.ignored:IsShown() then self.ignored:Refresh() end
    if self.cancel:IsShown() then self.cancel:Refresh() end
  end

  panel.tab = "post"
  panel.tabs:Select("post")
  panel:Hide()
  return panel
end

-- Opens the panel on a tab, e.g. "shopping" from "Create AH list" in Professions.
function ns:ShowAuctionTab(tab)
  if not ns.ahOpen then ns.Print(L.SCAN_NEED_AH); return end
  ns:ShowAuctionPanel(true)
  panel:SelectTab(tab)
end

function ns:RefreshAuctionPanel()
  if panel and panel:IsShown() then panel:Refresh() end
end

function ns:RefreshDeals()
  if not (panel and panel:IsShown()) then return end
  if panel.deals:IsShown() then panel.deals:Refresh() end
  if panel.shopping:IsShown() then panel.shopping:Refresh() end
end

ns:On("SHOPPING", function()
  if panel and panel:IsShown() and panel.shopping:IsShown() then panel.shopping:Refresh() end
end)

function ns:ShowAuctionPanel(force)
  if not ns.ahOpen then return end
  if not force and not ns.db.settings.openWithAH then return end
  panel = panel or create()
  panel:ClearAllPoints()
  -- Where the player last dragged it; otherwise next to the Auction House window.
  local saved = ns.char.ahPanel
  local ah = AuctionHouseFrame or AuctionFrame
  if saved and saved[1] then
    panel:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
  elseif ah and ah:IsShown() then
    panel:SetPoint("TOPLEFT", ah, "TOPRIGHT", 4, -12)
  else
    panel:SetPoint("CENTER", 300, 0)
  end
  panel:Show()
  panel:Refresh()
end

ns:On("AUCTION_HOUSE_SHOW", function()
  ns.ahOpen = true
  ns:ShowAuctionPanel(false)
  ns:Fire("BAGS")
end)

ns:On("AUCTION_HOUSE_CLOSED", function()
  ns.ahOpen = false
  if panel then panel:Hide() end
  ns:Fire("BAGS")
end)

ns:On("BAGS", function()
  if panel and panel:IsShown() then panel:Refresh() end
end)

ns:On("PRICES", function()
  if panel and panel:IsShown() then panel:Refresh() end
end)

ns:On("SCAN", function()
  if panel and panel:IsShown() then
    ns:Throttle("panel-scan", 0.3, function() panel:Refresh() end)
  end
end)
