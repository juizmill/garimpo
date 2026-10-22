local _, ns = ...
local L, W = ns.L, ns.W

-- Posted auctions. Every post (Garimpo, another auction addon or the game's own UI) is
-- recorded through hooks; the owned-auctions list syncs them while the Auction House is
-- open, and the "sold"/"expired" chat messages update them anywhere.
-- The list only keeps what still matters: active auctions, and sold ones until their gold
-- is taken from the mailbox. Expired and cancelled auctions leave the list right away.
-- Sales are also kept in a small log for the "sold in 7 days" total.

local REGISTER = "Interface\\AddOns\\Garimpo\\Media\\CashRegister.mp3"
local HOURS = { 12, 24, 48 }
local KEEP = 300

local function records() return ns.char.auctions end

local function add(rec)
  local list = records()
  table.insert(list, 1, rec)
  while #list > KEEP do table.remove(list) end
  ns:Fire("AUCTIONS")
end

local function remove(rec)
  local list = records()
  for i, r in ipairs(list) do
    if r == rec then table.remove(list, i); return end
  end
end

local function logSale(rec)
  local log = ns.char.sales
  log[#log + 1] = { t = time(), total = rec.total or 0, itemID = rec.itemID, name = rec.name, qty = rec.qty }
  local cutoff = time() - 30 * 86400
  while log[1] and log[1].t < cutoff do table.remove(log, 1) end
end

local warnedSound = false

function ns:PlaySaleSound(force)
  local s = self.db.settings.sale
  if not force and not s.sound then return end
  if s.kind == "register" then
    if PlaySoundFile(REGISTER, "Master") then return end
    -- The game refused the file; say so once and fall back to the game's coins.
    if force or not warnedSound then
      warnedSound = true
      ns.Print(L.SOUND_FAILED)
    end
  end
  PlaySound(SOUNDKIT and SOUNDKIT.LOOT_WINDOW_COIN_SOUND or 120, "Master")
end

local function markSold(rec)
  if rec.status == "sold" then return end
  rec.status, rec.endedAt = "sold", time()
  logSale(rec)
  ns:PlaySaleSound()
  ns.Print(L.SOLD_MSG:format(rec.qty or 1, rec.name or "?", ns.PlainMoney(rec.total or 0)))
  ns:Fire("AUCTIONS")
end

-- Expired or cancelled: nothing to collect but the item, which comes back by mail.
local function finish(rec)
  remove(rec)
  ns:Fire("AUCTIONS")
end

local function recordPost(itemID, durationIndex, qty, total)
  if not itemID then return end
  local now = time()
  add({
    itemID = itemID, name = ns.ItemName(itemID), qty = qty or 1, total = total,
    postedAt = now, expiresAt = now + (HOURS[durationIndex] or 24) * 3600, status = "active",
  })
end

-- Hooks on every way of posting.
if C_AuctionHouse and C_AuctionHouse.PostItem then
  local function itemAt(loc)
    return loc and C_Item.GetItemID and C_Item.GetItemID(loc)
  end
  hooksecurefunc(C_AuctionHouse, "PostItem", function(loc, duration, qty, bid, buyout)
    recordPost(itemAt(loc), duration, qty, (buyout or bid or 0) * (qty or 1))
  end)
  hooksecurefunc(C_AuctionHouse, "PostCommodity", function(loc, duration, qty, unitPrice)
    recordPost(itemAt(loc), duration, qty, (unitPrice or 0) * (qty or 1))
  end)
elseif PostAuction then
  hooksecurefunc("PostAuction", function(_, buyout, runTime, stackSize, numStacks)
    local _, _, _, _, _, _, _, _, _, itemID = GetAuctionSellItemInfo()
    for _ = 1, numStacks or 1 do recordPost(itemID, runTime, stackSize, buyout) end
  end)
end

-- Purchases. Every buyout (Garimpo's deals or the game's own UI) is recorded when the
-- game confirms it, in a 30-day log for the "Purchases" list.
local function logPurchase(itemID, qty, total)
  if not (itemID and ns.char) then return end
  local log = ns.char.purchases
  log[#log + 1] = { t = time(), itemID = itemID, name = ns.ItemName(itemID), qty = qty or 1, total = total }
  local cutoff = time() - 30 * 86400
  while log[1] and log[1].t < cutoff do table.remove(log, 1) end
  ns:Fire("AUCTIONS")
end

if C_AuctionHouse and C_AuctionHouse.PlaceBid then
  local AH = C_AuctionHouse
  local bids, commodity = {}, nil

  -- The item of an auction: from Garimpo's last search, or from the game.
  local function auctionItem(auctionID)
    for itemID, list in pairs(ns.listings or {}) do
      for _, l in ipairs(list) do
        if l.auctionID == auctionID then return itemID, l.count end
      end
    end
    if AH.GetAuctionInfoByID then
      local ok, info = pcall(AH.GetAuctionInfoByID, auctionID)
      if ok and info and info.itemKey then return info.itemKey.itemID, info.quantity end
    end
  end

  hooksecurefunc(AH, "PlaceBid", function(auctionID, amount)
    local itemID, qty = auctionItem(auctionID)
    if itemID then bids[auctionID] = { itemID = itemID, qty = qty, total = amount } end
  end)
  -- Only buyouts complete right away; plain bids never reach this event.
  ns:On("AUCTION_HOUSE_PURCHASE_COMPLETED", function(auctionID)
    local b = bids[auctionID]
    if b then
      bids[auctionID] = nil
      logPurchase(b.itemID, b.qty, b.total)
    end
  end)

  if AH.StartCommoditiesPurchase then
    hooksecurefunc(AH, "StartCommoditiesPurchase", function(itemID, qty)
      commodity = { itemID = itemID, qty = qty }
    end)
    ns:On("COMMODITY_PRICE_UPDATED", function(_, total)
      if commodity then commodity.total = total end
    end)
    hooksecurefunc(AH, "ConfirmCommoditiesPurchase", function(itemID, qty)
      if commodity and commodity.itemID == itemID then commodity.qty = qty end
    end)
    ns:On("COMMODITY_PURCHASE_SUCCEEDED", function()
      if commodity then logPurchase(commodity.itemID, commodity.qty, commodity.total) end
      commodity = nil
    end)
    ns:On("COMMODITY_PURCHASE_FAILED", function() commodity = nil end)
  end
end

-- Sync with the owned-auctions list (modern Auction House only).
local function sync()
  if not (C_AuctionHouse and C_AuctionHouse.GetNumOwnedAuctions) then return end
  local list, now, seen = records(), time(), {}
  for i = 1, C_AuctionHouse.GetNumOwnedAuctions() do
    local info = C_AuctionHouse.GetOwnedAuctionInfo(i)
    if info and info.auctionID then
      seen[info.auctionID] = true
      local itemID = info.itemKey and info.itemKey.itemID
      local rec
      for _, r in ipairs(list) do
        if r.auctionID == info.auctionID then rec = r; break end
      end
      -- A post recorded by the hooks has no auction number yet; take the oldest one of the
      -- same item (the game may merge commodity posts, so the quantity can differ).
      if not rec then
        for i2 = #list, 1, -1 do
          local r = list[i2]
          if not r.auctionID and r.status == "active" and r.itemID == itemID then
            rec = r
            rec.auctionID = info.auctionID
            break
          end
        end
      end
      if not rec then
        rec = { auctionID = info.auctionID, itemID = itemID, postedAt = now, status = "active" }
        add(rec)
      end
      -- The game's list is the truth for quantity, price and time left.
      local qty = info.quantity or 1
      rec.qty = qty
      rec.total = (info.buyoutAmount or info.bidAmount or 0) * qty
      if itemID then
        local name = ns.ItemName(itemID)
        if not (rec.name and name:find("^item:")) then rec.name = name end
      end
      if info.timeLeftSeconds then rec.expiresAt = now + info.timeLeftSeconds end
      if Enum.AuctionStatus and info.status == Enum.AuctionStatus.Sold then markSold(rec) end
    end
  end
  -- Active records the game doesn't list (expired, cancelled, or posts that never got an
  -- auction number) are gone.
  for i = #list, 1, -1 do
    local r = list[i]
    if r.status == "active" and not (r.auctionID and seen[r.auctionID]) then table.remove(list, i) end
  end
  ns.char.lastAuctionSync = now
  ns:Fire("AUCTIONS")
end

local function queryOwned()
  if C_AuctionHouse and C_AuctionHouse.QueryOwnedAuctions then
    pcall(C_AuctionHouse.QueryOwnedAuctions, {})
  end
end

ns:On("AUCTION_HOUSE_SHOW", function() C_Timer.After(0.5, queryOwned) end)
ns:On("OWNED_AUCTIONS_UPDATED", sync)
ns:On("AUCTION_HOUSE_AUCTION_CREATED", function() C_Timer.After(1, queryOwned) end)

-- Global strings like "A buyer has been found for your auction of %s." as patterns.
local function toPattern(fmt)
  if not fmt then return nil end
  local p = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
  p = p:gsub("%%%%s", "(.+)")
  return "^" .. p .. "$"
end

local PATTERNS
local function patterns()
  PATTERNS = PATTERNS or {
    { toPattern(ERR_AUCTION_SOLD_S), "sold" },
    { toPattern(ERR_AUCTION_EXPIRED_S), "expired" },
    { toPattern(ERR_AUCTION_REMOVED_S), "ended" },
  }
  return PATTERNS
end

-- The oldest record of an item with the given status.
local function oldest(name, status)
  local list = records()
  for i = #list, 1, -1 do
    local r = list[i]
    if r.status == status and r.name == name then return r end
  end
end

ns:On("CHAT_MSG_SYSTEM", function(msg)
  if not msg or not ns.char then return end
  for _, p in ipairs(patterns()) do
    local name = p[1] and msg:match(p[1])
    if name then
      local match = oldest(name, "active")
      if p[2] == "sold" then
        -- A sale of an auction Garimpo didn't know still shows up, without the value.
        if not match then
          match = { name = name, qty = 1, postedAt = time(), status = "active" }
          add(match)
        end
        markSold(match)
      elseif match then
        finish(match)
      end
      return
    end
  end
end)

-- Mailbox: a sold auction leaves the list once its "Auction successful" mail is gone,
-- i.e. its gold was taken.
local soldSubject
ns:On("MAIL_INBOX_UPDATE", function()
  if not ns.char then return end
  soldSubject = soldSubject or toPattern(AUCTION_SOLD_MAIL_SUBJECT)
  if not soldSubject then return end
  local inMail = {}
  for i = 1, GetInboxNumItems() do
    local _, _, _, subject, money = GetInboxHeaderInfo(i)
    local name = subject and subject:match(soldSubject)
    if name and money and money > 0 then inMail[name] = (inMail[name] or 0) + 1 end
  end
  local list, changed = records(), false
  -- Count sold records per item, oldest first; keep as many as there are mails.
  local kept = {}
  for i = #list, 1, -1 do
    local r = list[i]
    if r.status == "sold" then
      local n = inMail[r.name] or 0
      kept[r.name] = (kept[r.name] or 0) + 1
      if r.inMail and kept[r.name] > n then
        table.remove(list, i)
        changed = true
      elseif kept[r.name] <= n then
        r.inMail = true
      end
    end
  end
  if changed then ns:Fire("AUCTIONS") end
end)

-- Auctions whose time ran out while we couldn't see them, and leftovers from older
-- versions that kept expired records.
local function expireOld()
  if not ns.char then return end
  local list, now, changed = records(), time(), false
  for i = #list, 1, -1 do
    local r = list[i]
    if r.status == "expired" or r.status == "ended"
      or (r.status == "active" and r.expiresAt and now > r.expiresAt + 300) then
      table.remove(list, i)
      changed = true
    end
  end
  if changed then ns:Fire("AUCTIONS") end
end

ns:On("READY", function()
  expireOld()
  C_Timer.NewTicker(60, expireOld)
end)

-- Cancelling ---------------------------------------------------------------------------
-- A click builds a plan and sends as many cancels as the game accepts (the deposit is lost):
--   selected: the auctions ticked in the Cancel tab
--   undercut: every auction with a cheaper listing from someone else, which needs a fresh
--             search of your items first.

local cancel = { plan = nil, key = nil, undercutReady = false, selected = {} }

local function ownedAuctions()
  local out = {}
  if not (C_AuctionHouse and C_AuctionHouse.GetNumOwnedAuctions) then return out end
  for i = 1, C_AuctionHouse.GetNumOwnedAuctions() do
    local info = C_AuctionHouse.GetOwnedAuctionInfo(i)
    local itemID = info and info.itemKey and info.itemKey.itemID
    local active = info and (not Enum.AuctionStatus or info.status ~= Enum.AuctionStatus.Sold)
    if itemID and active then
      local qty = info.quantity or 1
      out[#out + 1] = { auctionID = info.auctionID, itemID = itemID, name = ns.ItemName(itemID),
        qty = qty, unit = info.buyoutAmount or info.bidAmount or 0 }
    end
  end
  return out
end

-- Lowest unit price from another player, from the last search of the item. Only search
-- results tell whose auction is whose (they carry the auction number and the "yours"
-- flag); the full scan only has the lowest price, which may be your own, so it isn't used.
local function lowestOther(itemID, mineIDs)
  for _, l in ipairs(ns.listings[itemID] or {}) do
    local theirs = not l.mine and not (mineIDs and mineIDs[l.auctionID])
    -- A commodity row with your units can also hold other players' at the same price.
    if l.mine and l.otherQty and l.otherQty > 0 then theirs = true end
    if l.auctionID and theirs then return l.unit, l.seller end
  end
  return nil
end

-- How another player's cheaper price compares with yours:
--   "cut"  = undercut, worth cancelling and posting again
--   "low"  = more than the Config limit below market value (a dump); reposting would lose
--            money, so it doesn't count as undercut
--   "lowest" = nobody sells cheaper; nil = no search data yet.
-- Market value is the 7-day average when there is history, else today's.
local function cutState(a, other)
  if not other then return nil end
  if other >= a.unit then return "lowest" end
  local ref = ns:Reference(a.itemID) or ns.Market(a.itemID)
  local floorPct = ns.db.settings.cutFloor or 20
  if ref and ref > 0 and other < ref * (1 - floorPct / 100) then return "low", ref end
  return "cut"
end

local function ownedIDs(owned)
  local ids = {}
  for _, a in ipairs(owned) do ids[a.auctionID] = true end
  return ids
end

local function buildPlan(undercut)
  local list, owned = {}, ownedAuctions()
  local mine = ownedIDs(owned)
  for _, a in ipairs(owned) do
    local pick
    if undercut then
      pick = cutState(a, lowestOther(a.itemID, mine)) == "cut"
    else
      pick = cancel.selected[a.auctionID]
    end
    if pick then list[#list + 1] = a end
  end
  return list
end

-- Chat note for each item undercut far below market value, which "Cancel undercut" skips.
local function reportLow()
  local owned = ownedAuctions()
  local mine, seen = ownedIDs(owned), {}
  for _, a in ipairs(owned) do
    local other, seller = lowestOther(a.itemID, mine)
    local state, ref = cutState(a, other)
    if state == "low" and not seen[a.itemID] then
      seen[a.itemID] = true
      local pct = math.floor((1 - other / ref) * 100 + 0.5)
      ns.Print(L.CUT_TOO_LOW_MSG:format(a.name, seller or "?", ns.PlainMoney(other), pct, ns.PlainMoney(ref)))
    end
  end
end

local function selectedCount()
  local n = 0
  for _ in pairs(cancel.selected) do n = n + 1 end
  return n
end

-- Called from a click (button or key binding). The game allows one cancel per click (a
-- second one in the same click is blocked), so each click sends the next one of the plan.
-- The ones the server confirms leave the plan; one not confirmed is sent again later.
function ns:CancelNext(undercut)
  if not ns.ahOpen then ns.Print(L.SCAN_NEED_AH); return end
  local key = undercut and "undercut" or "selected"
  if cancel.key ~= key or not cancel.plan then
    cancel.plan, cancel.key = buildPlan(undercut), key
    if #cancel.plan == 0 then
      cancel.plan = nil
      ns.Print(undercut and L.CANCEL_NONE_UNDERCUT or L.CANCEL_NONE_SELECTED)
      ns:Fire("AUCTIONS")
      return
    end
  end
  local now = GetTime()
  for _, a in ipairs(cancel.plan) do
    -- Give the server a moment to confirm before sending the same cancel again.
    if not a.sentAt or now - a.sentAt > 2 then
      C_AuctionHouse.CancelAuction(a.auctionID)
      a.sentAt = now
      break
    end
  end
  ns:Fire("AUCTIONS")
end

-- The server confirmed a cancel: take it out of the plan.
local function confirmed(auctionID)
  cancel.selected[auctionID] = nil
  if not cancel.plan then return end
  for i, a in ipairs(cancel.plan) do
    if a.auctionID == auctionID then
      ns.Print(L.CANCELED:format(a.qty, a.name))
      table.remove(cancel.plan, i)
      break
    end
  end
  if #cancel.plan == 0 then cancel.plan = nil end
end

-- Key binding (Bindings.xml): repeats the last cancel button pressed in the Cancel tab.
function GarimpoCancelNext()
  ns:CancelNext((cancel.undercut and cancel.undercutReady) and true or false)
end

ns:On("INIT", function()
  BINDING_HEADER_GARIMPO = "Garimpo"
  BINDING_NAME_GARIMPO_CANCEL = L.BINDING_PANEL
end)

function ns:CancelRemaining()
  return cancel.plan and #cancel.plan or 0
end

function ns:ResetCancel()
  cancel.plan, cancel.key, cancel.undercutReady, cancel.selected = nil, nil, false, {}
end

-- "Check undercut": searches your items so the cheapest price from others is current.
function ns:CheckUndercut(done)
  if not ns.ahOpen then ns.Print(L.SCAN_NEED_AH); return end
  local ids, seen = {}, {}
  for _, a in ipairs(ownedAuctions()) do
    if not seen[a.itemID] then seen[a.itemID] = true; ids[#ids + 1] = a.itemID end
  end
  if #ids == 0 then ns.Print(L.CANCEL_NONE); return end
  self:QuickSearch(ids, function()
    cancel.undercutReady = true
    cancel.plan, cancel.key = nil, nil
    reportLow()
    if done then done() end
    ns:Fire("AUCTIONS")
  end)
end

function ns:UndercutReady()
  return cancel.undercutReady
end

-- A cancelled auction leaves the list; refresh the owned auctions.
ns:On("AUCTION_CANCELED", function(auctionID)
  confirmed(auctionID)
  local list = records()
  for i, r in ipairs(list) do
    if r.auctionID == auctionID then table.remove(list, i); break end
  end
  C_Timer.After(0.5, queryOwned)
  ns:Fire("AUCTIONS")
end)

ns:On("AUCTION_HOUSE_CLOSED", function() ns:ResetCancel() end)

function ns:QueryOwned()
  queryOwned()
end

-- The Cancel tab of the Auction House panel: the cancel row and your active auctions,
-- with the cheapest price from others. The caller anchors the returned frame.
function ns.BuildCancelView(parent)
  local f = CreateFrame("Frame", nil, parent)

  -- Ticking or unticking an auction starts a new plan for the Cancel button.
  local function tick(auctionID, on)
    cancel.selected[auctionID] = on or nil
    if cancel.key == "selected" then cancel.plan, cancel.key = nil, nil end
    f:Refresh()
  end

  local all = W.Check(f, "CANCEL_SELECT_ALL", function(on)
    cancel.selected = {}
    if on then
      for _, a in ipairs(ownedAuctions()) do cancel.selected[a.auctionID] = true end
    end
    if cancel.key == "selected" then cancel.plan, cancel.key = nil, nil end
    f:Refresh()
  end)
  all:SetPoint("TOPLEFT", 0, -1)

  local undercutBtn = W.Button(f, nil, 150, function()
    if ns:UndercutReady() then
      cancel.undercut = true
      ns:CancelNext(true)
    else
      ns:CheckUndercut()
    end
  end)
  undercutBtn:SetPoint("TOPRIGHT", 0, 0)
  local cancelBtn = W.Button(f, nil, 150, function()
    cancel.undercut = false
    ns:CancelNext(false)
  end)
  cancelBtn:SetPoint("RIGHT", undercutBtn, "LEFT", -6, 0)
  for btn, tip in pairs({ [cancelBtn] = "CANCEL_TIP", [undercutBtn] = "UNDERCUT_TIP" }) do
    btn:SetStyle("danger")
    btn:HookScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(L[tip], 1, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    btn:HookScript("OnLeave", GameTooltip_Hide)
  end

  local list = W.List(f, {
    { width = 190, header = "COL_ITEM" },
    { width = 46, justify = "RIGHT", header = "COL_QTY" },
    { width = 90, justify = "RIGHT", header = "COL_YOUR_UNIT" },
    { width = 100, justify = "RIGHT", header = "COL_LOWEST_OTHER" },
    { width = 84, header = "COL_STATUS" },
    { width = 100, header = "COL_CUT_BY" },
  }, 22)
  list:SetPoint("TOPLEFT", 0, -30)
  list:SetPoint("BOTTOMRIGHT", 0, 24)

  local foot = W.Font(f, 11, W.C.muted)
  foot:SetPoint("BOTTOMLEFT", 0, 4)
  foot:SetPoint("RIGHT", 0, 0)
  foot:SetWordWrap(true)
  W.Label(foot, "CANCEL_FOOT")

  function f:Refresh()
    local data, owned, present = {}, ownedAuctions(), {}
    for _, a in ipairs(owned) do present[a.auctionID] = true end
    local mine = ownedIDs(owned)
    -- Forget ticks of auctions that are gone (sold, expired, cancelled elsewhere).
    for id in pairs(cancel.selected) do
      if not present[id] then cancel.selected[id] = nil end
    end
    for _, a in ipairs(owned) do
      local other, seller = lowestOther(a.itemID, mine)
      local state, ref = cutState(a, other)
      local cut, low = state == "cut", state == "low"
      local by = (cut or low) and (seller or "?") or nil
      local status = cut and ns.Color("down", L.UNDERCUT)
        or low and ns.Color("gold", L.CUT_TOO_LOW)
        or state == "lowest" and ns.Color("up", L.LOWEST)
        or ns.Color("muted", "-")
      local extra
      if low then
        local pct = math.floor((1 - other / ref) * 100 + 0.5)
        extra = { ns.Color("gold", L.CUT_TOO_LOW_TIP:format(pct, ns.PlainMoney(ref))) }
      end
      local id = a.auctionID
      data[#data + 1] = {
        itemID = a.itemID, icon = ns.ItemIcon(a.itemID), extra = extra,
        check = cancel.selected[id] == true,
        onCheck = function(_, on) tick(id, on) end,
        cells = {
          "|cff" .. ns.ItemQualityHex(a.itemID) .. a.name .. "|r",
          ns.Num(a.qty),
          ns.Money(a.unit),
          other and ns.Money(other) or ns.Color("muted", "-"),
          status,
          by and ns.Color(cut and "down" or "muted", by) or ns.Color("muted", "-"),
        },
        sort = { a.name, a.qty, a.unit, other, cut and 2 or (low and 1 or 0), by },
        tone = cut and "current" or nil,
        onClick = function() tick(id, not cancel.selected[id]) end,
      }
    end
    list:SetData(data, ns.ahOpen and L.CANCEL_EMPTY or L.SCAN_NEED_AH)

    local nSel = selectedCount()
    all:SetChecked(#owned > 0 and nSel == #owned)
    local left = ns:CancelRemaining()
    if left > 0 and cancel.key == "selected" then
      cancelBtn:SetText(L.CANCEL_LEFT:format(left))
    else
      cancelBtn:SetText(L.CANCEL_SELECTED:format(nSel))
    end
    if left > 0 and cancel.key == "undercut" then
      undercutBtn:SetText(L.UNDERCUT_LEFT:format(left))
    else
      undercutBtn:SetText(ns:UndercutReady() and L.UNDERCUT_CANCEL or L.UNDERCUT_CHECK)
    end
    local ready = ns.ahOpen == true and ns.scan.state == "idle"
    cancelBtn:SetEnabled(ready and (nSel > 0 or (left > 0 and cancel.key == "selected")))
    undercutBtn:SetEnabled(ready)
  end

  return f
end

-- View ---------------------------------------------------------------------------------

ns:RegisterView("auctions", function(parent)
  local f = CreateFrame("Frame", nil, parent)

  local active = W.Stat(f, "STAT_ACTIVE", 200)
  active:SetPoint("TOPLEFT", 0, 0)
  local mail = W.Stat(f, "STAT_IN_MAIL", 200)
  mail:SetPoint("LEFT", active, "RIGHT", 8, 0)
  local sold = W.Stat(f, "STAT_SOLD_7D", 200)
  sold:SetPoint("LEFT", mail, "RIGHT", 8, 0)

  -- Todos: sold auctions waiting in the mailbox, then the active ones.
  -- Vendidos: the sales log (30 days), kept after the gold is taken.
  -- Compras: what you bought at the Auction House (30 days).
  f.filter = "all"
  local filter = W.Chips(f, function(v)
    f.filter = v
    f:Refresh()
  end)
  filter:SetPoint("TOPLEFT", 0, -46)
  filter:SetItems({
    { value = "all", key = "FILTER_ALL" }, { value = "sold", key = "FILTER_SOLD" },
    { value = "bought", key = "FILTER_BOUGHT" },
  })
  filter:Select("all")

  local list = W.List(f, {
    { width = 180, header = "COL_ITEM" },
    { width = 40, justify = "RIGHT", header = "COL_QTY" },
    { width = 86, justify = "RIGHT", header = "COL_TOTAL" },
    { width = 64, justify = "RIGHT", header = "COL_POSTED" },
    { width = 84, justify = "RIGHT", header = "COL_TIME_LEFT" },
    { width = 76, header = "COL_STATUS" },
  }, 22)
  list:SetPoint("TOPLEFT", 0, -72)
  list:SetPoint("BOTTOMRIGHT", 0, 30)

  local foot = W.Font(f, 11, W.C.muted)
  foot:SetPoint("BOTTOMLEFT", 0, 6)
  foot:SetPoint("RIGHT", 0, 0)
  foot:SetWordWrap(true)

  local function ago(ts)
    return ns.Duration((time() - ts) / 60)
  end

  function f:Refresh()
    expireOld()
    local now = time()
    local nActive, vActive, nMail, vMail = 0, 0, 0, 0
    local rows = {}
    for _, r in ipairs(records()) do
      if r.status == "active" then nActive, vActive = nActive + 1, vActive + (r.total or 0) end
      if r.status == "sold" then nMail, vMail = nMail + 1, vMail + (r.total or 0) end
      rows[#rows + 1] = r
    end
    -- Sold first, most recent sale on top; then active, the one ending soonest first.
    table.sort(rows, function(a, b)
      if a.status ~= b.status then return a.status == "sold" end
      if a.status == "sold" then return (a.endedAt or 0) > (b.endedAt or 0) end
      return (a.expiresAt or math.huge) < (b.expiresAt or math.huge)
    end)

    local data = {}
    for _, r in ipairs(rows) do
      -- Names saved before the item was in the cache read "item:123"; fix them now.
      if type(r.itemID) == "number" and (not r.name or r.name:find("^item:")) then
        r.name = ns.ItemName(r.itemID)
      end
      local isSold = r.status == "sold"
      local left = r.expiresAt and math.max(r.expiresAt - now, 0) or nil
      data[#data + 1] = {
        itemID = type(r.itemID) == "number" and r.itemID or nil,
        icon = r.itemID and ns.ItemIcon(r.itemID) or nil,
        cells = {
          r.itemID and ("|cff" .. ns.ItemQualityHex(r.itemID) .. r.name .. "|r") or (r.name or "?"),
          ns.Num(r.qty or 1),
          r.total and ns.Money(r.total) or ns.Color("muted", "-"),
          r.postedAt and L.AGO:format(ago(r.postedAt)) or "-",
          isSold and ns.Color("up", r.endedAt and L.AGO:format(ago(r.endedAt)) or "-")
            or (left and ns.Duration(left / 60) or "-"),
          W.Pill(isSold and "sold" or "active"),
        },
        sort = { r.name, r.qty, r.total, r.postedAt, isSold and -(r.endedAt or 0) or left, r.status },
        tone = isSold and "top" or nil,
      }
    end

    local vSold, weekAgo = 0, now - 7 * 86400
    for _, s in ipairs(ns.char.sales) do
      if s.t >= weekAgo then vSold = vSold + s.total end
    end
    active:Set(nActive .. "  " .. ns.Color("muted", "(" .. ns.Money(vActive) .. ")"))
    mail:Set(ns.Money(vMail) .. "  " .. ns.Color("muted", "(" .. nMail .. ")"), W.C.up)
    sold:Set(ns.Money(vSold), W.C.up)
    if self.filter == "sold" or self.filter == "bought" then
      local bought = self.filter == "bought"
      data = {}
      local log = bought and ns.char.purchases or ns.char.sales
      for i = #log, 1, -1 do
        local s = log[i]
        local id = type(s.itemID) == "number" and s.itemID or nil
        local name = id and ns.ItemName(id) or s.name or "?"
        data[#data + 1] = {
          itemID = id, icon = id and ns.ItemIcon(id) or nil,
          cells = {
            id and ("|cff" .. ns.ItemQualityHex(id) .. name .. "|r") or name,
            s.qty and ns.Num(s.qty) or "-",
            s.total and s.total > 0 and ns.Money(s.total) or ns.Color("muted", "-"),
            "-",
            ns.Color(bought and "gold" or "up", L.AGO:format(ago(s.t))),
            W.Pill(bought and "bought" or "sold"),
          },
          sort = { name, s.qty, s.total, nil, -s.t, self.filter },
        }
      end
      list:SetData(data, bought and L.PURCHASES_EMPTY or L.SALES_EMPTY)
    else
      list:SetData(data, L.AUCTIONS_EMPTY)
    end
    local last = ns.char.lastAuctionSync
    foot:SetText(last and last > 0 and L.AUCTIONS_SYNCED:format(ago(last)) or L.AUCTIONS_SYNC_HINT)
  end

  return f
end)

ns:On("AUCTIONS", function()
  ns:Throttle("auctions", 0.3, function()
    ns:RefreshCurrent()
    if ns.RefreshAuctionPanel then ns:RefreshAuctionPanel() end
  end)
end)
