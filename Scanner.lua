local _, ns = ...
local L = ns.L

-- Garimpo's own Auction House scanner (modern Auction House, as used by Forever).
--   Full scan: C_AuctionHouse.ReplicateItems, allowed once every 15 minutes.
--   Quick search: one item at a time with SendSearchQuery; also gives auction IDs to buy.
-- Each scan stores per item the lowest price, the market value and the quantity listed,
-- and one market value per day as price history. Listings stay in memory for the deals.

local AH = C_AuctionHouse
local CHUNK = 500           -- listings processed per frame
local FULL_COOLDOWN = 900   -- seconds between full scans (game limit)

-- What you keep from a sale after the Auction House cut (5% by default, 15% at neutral houses).
function ns.SaleKeep()
  return 1 - (ns.db.settings.deals.ahCut or 5) / 100
end

-- Profit of buying `count` at `unit` and reselling at `ref`, and the return over the price paid.
function ns.DealProfit(unit, count, ref)
  local net = ref * ns.SaleKeep()
  return (net - unit) * count, (net - unit) / unit
end

-- Highest unit price that still gives the wanted spread when resold at `ref`.
function ns.MaxBuyPrice(ref)
  return ref * ns.SaleKeep() / (1 + ns.db.settings.deals.spread / 100)
end

ns.scan = { state = "idle", done = 0, total = 0 }
ns.listings = {}            -- [itemID] = sorted listings { unit, count, mine, auctionID, commodity, itemKey }
ns.deals = {}
ns.dealsReady = false       -- the Deals tab shows ns.deals only after a scan in this visit

local function setState(state, done, total)
  ns.scan.state, ns.scan.done, ns.scan.total = state, done or 0, total or 0
  ns:Fire("SCAN")
end

-- The full scan works in one of two ways:
--   "replicate": C_AuctionHouse.ReplicateItems reads every auction; the game allows it once
--     every 15 minutes.
--   "browse": a blank Auction House search lists every item for sale with its lowest price
--     and quantity. Used when replicate isn't available or comes back empty; no cooldown.
local function hasReplicate() return AH ~= nil and AH.ReplicateItems ~= nil end
local function hasBrowse() return AH ~= nil and AH.SendBrowseQuery ~= nil end

-- Browse mode is remembered for a day after replicate failed, then replicate is tried again.
local function useBrowse()
  if not hasReplicate() then return true end
  return ns.db.scanMode == "browse" and time() - (ns.db.scanModeAt or 0) < 86400
end

function ns.CanScan()
  return ns.ahOpen and (hasReplicate() or hasBrowse())
end

function ns:FullScanWait()
  if useBrowse() then return 0 end
  return math.max(0, FULL_COOLDOWN - (time() - (self.db.lastFullScan or 0)))
end

-- Market value: average unit price of the cheapest 15% of the quantity listed.
local function marketOf(list)
  local total = 0
  for _, l in ipairs(list) do total = total + l.count end
  local want = math.max(1, math.ceil(total * 0.15))
  local sum, n = 0, 0
  for _, l in ipairs(list) do
    local take = math.min(l.count, want - n)
    sum, n = sum + l.unit * take, n + take
    if n >= want then break end
  end
  return sum / math.max(n, 1), total
end

function ns:StoreListings(itemID, list)
  if #list == 0 then return end
  table.sort(list, function(a, b) return a.unit < b.unit end)
  self.listings[itemID] = list
  local others = {}
  for _, l in ipairs(list) do
    if not l.mine then others[#others + 1] = l end
  end
  local base = #others > 0 and others or list
  local m, q = marketOf(base)
  local e = self.db.market[itemID] or {}
  self.db.market[itemID] = e
  e.p, e.m, e.q, e.t = base[1].unit, m, list.totalQty or q, time()
  local day = ns.Today()
  self.db.prices[itemID] = self.db.prices[itemID] or {}
  self.db.prices[itemID][day] = m
end

-- Full scan ------------------------------------------------------------------------------

local function finishFull(byItem, count, mode)
  wipe(ns.listings)
  for id, list in pairs(byItem) do ns:StoreListings(id, list) end
  -- Items that were on the Auction House before and are gone now.
  for id, e in pairs(ns.db.market) do
    if not byItem[id] then e.q = 0 end
  end
  local items = 0
  for _ in pairs(byItem) do items = items + 1 end
  ns.db.lastFullScan = time()
  ns.db.lastScanItems, ns.db.lastScanMode = items, mode
  ns:PruneHistory()
  setState("idle")
  ns.dealsReady = true
  ns:FindDeals()
  ns:Fire("PRICES")
  if mode == "browse" then
    ns.Print(L.SCAN_DONE_BROWSE:format(ns.Num(items), #ns.deals))
  else
    ns.Print(L.SCAN_DONE:format(ns.Num(count), ns.Num(items), #ns.deals))
  end
  local after = ns.afterFull
  ns.afterFull = nil
  if after then after() end
end

-- Browse scan ---------------------------------------------------------------------------
-- One row per item: lowest price and total quantity. The quantity at the lowest price is
-- unknown, so deals from it count one unit until "Locate" finds the real auction.

local function finishBrowse()
  if ns.scan.state ~= "browsing" then return end
  local byItem, results = {}, AH.GetBrowseResults() or {}
  for _, r in ipairs(results) do
    local id = r.itemKey and r.itemKey.itemID
    if id and r.minPrice and r.minPrice > 0 then
      byItem[id] = { { unit = r.minPrice, count = 1, mine = false }, totalQty = r.totalQuantity }
    end
  end
  finishFull(byItem, #results, "browse")
end

local function onBrowseResults()
  if ns.scan.state ~= "browsing" then return end
  setState("browsing", #(AH.GetBrowseResults() or {}), 0)
  if AH.HasFullBrowseResults() then
    finishBrowse()
  else
    C_Timer.After(0.3, function()
      if ns.scan.state == "browsing" then pcall(AH.RequestMoreBrowseResults) end
    end)
  end
end

ns:On("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", onBrowseResults)
ns:On("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", onBrowseResults)

local function startBrowse()
  if not hasBrowse() then
    setState("idle")
    ns.Print(L.SCAN_UNSUPPORTED)
    return
  end
  setState("browsing", 0, 0)
  local query = {
    searchString = "",
    sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } },
    filters = {},
    itemClassFilters = {},
  }
  if not pcall(AH.SendBrowseQuery, query) then
    setState("idle")
    ns.Print(L.SCAN_UNSUPPORTED)
    return
  end
  -- If the results stop growing for 20 seconds, keep what arrived.
  local lastDone, stalls = -1, 0
  local function watch()
    if ns.scan.state ~= "browsing" then return end
    if ns.scan.done == lastDone then
      stalls = stalls + 1
      if stalls >= 4 then finishBrowse(); return end
    else
      lastDone, stalls = ns.scan.done, 0
    end
    C_Timer.After(5, watch)
  end
  C_Timer.After(5, watch)
end

-- Replicate couldn't be used: remember it for a day and scan by browsing instead.
local function fallbackToBrowse()
  ns.db.scanMode, ns.db.scanModeAt = "browse", time()
  ns.Print(L.SCAN_FALLBACK)
  startBrowse()
end

local function processReplicate()
  local total = AH.GetNumReplicateItems()
  if not total or total == 0 then
    fallbackToBrowse()
    return
  end
  ns.db.scanMode = "replicate"
  local me = UnitName("player")
  local byItem, i = {}, 0
  setState("processing", 0, total)
  local function step()
    if ns.scan.state ~= "processing" then return end
    local last = math.min(i + CHUNK, total)
    for index = i, last - 1 do
      local _, _, count, _, _, _, _, _, _, buyout, _, _, _, owner, _, _, itemID = AH.GetReplicateItemInfo(index)
      if itemID and buyout and buyout > 0 and count and count > 0 then
        local list = byItem[itemID]
        if not list then list = {}; byItem[itemID] = list end
        list[#list + 1] = { unit = buyout / count, count = count, mine = owner ~= nil and owner == me }
      end
    end
    i = last
    setState("processing", i, total)
    if i < total then C_Timer.After(0, step) else finishFull(byItem, total, "replicate") end
  end
  step()
end

function ns:FullScan()
  if not ns.ahOpen then ns.Print(L.SCAN_NEED_AH); return end
  if self.scan.state ~= "idle" then return end
  if useBrowse() then
    startBrowse()
    return
  end
  local wait = self:FullScanWait()
  if wait > 0 then
    ns.Print(L.SCAN_WAIT:format(ns.Duration(wait / 60 + 0.5)))
    return
  end
  setState("waiting")
  if not pcall(AH.ReplicateItems) then
    fallbackToBrowse()
    return
  end
  -- No answer within 45 seconds: the client doesn't deliver it, browse instead.
  C_Timer.After(45, function()
    if ns.scan.state == "waiting" then fallbackToBrowse() end
  end)
end

-- "Check deals": reads the whole Auction House (the full scan, or a browse scan while the
-- full scan is cooling down), finds the best deals in it, then searches those items one
-- by one for real prices, quantities and auction IDs. ns.checkingDeals is true meanwhile.
function ns:CheckDeals(done)
  if not ns.ahOpen then ns.Print(L.SCAN_NEED_AH); return end
  if self.scan.state ~= "idle" then return end
  self.checkingDeals = true
  self.afterFull = function()
    local ids, seen = {}, {}
    for _, d in ipairs(self.deals) do
      if not seen[d.id] then
        seen[d.id] = true
        ids[#ids + 1] = d.id
      end
    end
    local function finish()
      self.checkingDeals = false
      self:Fire("DEALS")
      if done then done() end
    end
    if #ids == 0 then finish() else self:QuickSearch(ids, finish) end
  end
  self:Fire("DEALS")
  if not useBrowse() and self:FullScanWait() == 0 then
    self:FullScan()
  else
    startBrowse()
  end
  -- The scan couldn't start.
  if self.scan.state == "idle" then
    self.checkingDeals, self.afterFull = false, nil
    self:Fire("DEALS")
  end
end

ns:On("AUCTION_HOUSE_CLOSED", function()
  ns.checkingDeals, ns.afterFull = false, nil
end)

-- Each visit to the Auction House starts with an empty Deals tab: deals from an earlier
-- visit may be gone, so they only show again after a scan.
ns:On("AUCTION_HOUSE_SHOW", function()
  wipe(ns.deals)
  ns.dealsReady, ns.dealStats = false, nil
end)

ns:On("REPLICATE_ITEM_LIST_UPDATE", function()
  if ns.scan.state == "waiting" then processReplicate() end
end)

-- Quick search ---------------------------------------------------------------------------

local queue, current, currentDone, onFinished = {}, nil, nil, nil

local function finishQuick()
  current = nil
  setState("idle")
  ns:PruneHistory()
  ns:FindDeals()
  ns:Fire("PRICES")
  if onFinished then
    local fn = onFinished
    onFinished = nil
    fn()
  end
end

local nextSearch

local function advance()
  current = nil
  setState("searching", ns.scan.done + 1, ns.scan.total)
  C_Timer.After(0.25, nextSearch)
end

nextSearch = function()
  if not ns.ahOpen then queue = {}; finishQuick(); return end
  if AH.IsThrottledMessageSystemReady and not AH.IsThrottledMessageSystemReady() then
    C_Timer.After(0.3, nextSearch)
    return
  end
  current = table.remove(queue, 1)
  if not current then finishQuick(); return end
  local id = current
  local sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
  pcall(AH.SendSearchQuery, AH.MakeItemKey(id), sorts, true)
  currentDone = false
  -- No results event for items nobody is selling: move on after a moment.
  C_Timer.After(3, function()
    if current == id and not currentDone then advance() end
  end)
end

-- ids: list of itemIDs. done: optional callback when the whole list is searched.
function ns:QuickSearch(ids, done)
  if not ns.ahOpen then ns.Print(L.SCAN_NEED_AH); return end
  if not (AH and AH.SendSearchQuery) then ns.Print(L.SCAN_UNSUPPORTED); return end
  if self.scan.state ~= "idle" then return end
  queue = {}
  for _, id in ipairs(ids) do
    if type(id) == "number" then queue[#queue + 1] = id end
  end
  onFinished = done
  setState("searching", 0, #queue)
  nextSearch()
end

-- First seller of a search row that isn't you ("owners" lists the sellers' names).
local function sellerOf(r)
  local owners = r.owners
  if type(owners) ~= "table" then return nil end
  local me = UnitName("player")
  for _, name in ipairs(owners) do
    if name ~= me and name ~= "player" then return name end
  end
  return nil
end

ns:On("COMMODITY_SEARCH_RESULTS_UPDATED", function(itemID)
  if itemID ~= current or currentDone then return end
  currentDone = true
  local list = {}
  for i = 1, AH.GetNumCommoditySearchResults(itemID) do
    local r = AH.GetCommoditySearchResultInfo(itemID, i)
    if r and r.unitPrice and r.quantity then
      -- A price row can hold your units and other players' together; otherQty counts theirs.
      local own = r.numOwnerItems or 0
      list[#list + 1] = { unit = r.unitPrice, count = r.quantity, mine = r.containsOwnerItem or own > 0,
        otherQty = r.numOwnerItems and (r.quantity - own) or nil, seller = sellerOf(r),
        auctionID = r.auctionID, commodity = true }
    end
  end
  ns:StoreListings(itemID, list)
  advance()
end)

ns:On("ITEM_SEARCH_RESULTS_UPDATED", function(itemKey)
  if not itemKey or itemKey.itemID ~= current or currentDone then return end
  currentDone = true
  local list = {}
  for i = 1, AH.GetNumItemSearchResults(itemKey) do
    local r = AH.GetItemSearchResultInfo(itemKey, i)
    if r and r.buyoutAmount and r.buyoutAmount > 0 then
      local qty = r.quantity or 1
      list[#list + 1] = { unit = r.buyoutAmount, count = qty, mine = r.containsOwnerItem,
        seller = sellerOf(r), auctionID = r.auctionID, itemKey = itemKey }
    end
  end
  ns:StoreListings(itemKey.itemID, list)
  advance()
end)

-- A full scan is "fresh" for 30 minutes: deals come from it, and opening the Auction House
-- only scans again after that.
local FRESH = 1800

function ns:ScanAge()
  local t = self.db.lastFullScan or 0
  return t > 0 and (time() - t) or nil
end

function ns:ScanIsFresh()
  local age = self:ScanAge()
  return age ~= nil and age <= FRESH
end

-- After /reload or logging in, the auctions of the last scan are no longer in memory.
-- If that scan is fresh, rebuild the deals from the lowest price it saved for each item.
function ns:RestoreListings()
  if next(self.listings) or not self:ScanIsFresh() then return end
  local since = self.db.lastFullScan - 60
  for id, e in pairs(self.db.market) do
    if e.p and e.t and e.t >= since and (e.q or 1) > 0 then
      self.listings[id] = { { unit = e.p, count = 1, mine = false } }
    end
  end
  self:FindDeals()
end

ns:On("READY", function()
  C_Timer.After(3, function() ns:RestoreListings() end)
end)

ns:On("AUCTION_HOUSE_SHOW", function()
  ns:RestoreListings()
  if ns.db.settings.scan.auto and ns.CanScan() and ns:FullScanWait() == 0 and not ns:ScanIsFresh() then
    C_Timer.After(1, function() ns:FullScan() end)
  end
end)

ns:On("AUCTION_HOUSE_CLOSED", function()
  if ns.scan.state ~= "idle" and ns.scan.state ~= "processing" then
    queue = {}
    setState("idle")
  end
end)

-- Deals ---------------------------------------------------------------------------------

-- What an item is worth for a deal: its average over the previous days (one past day is
-- enough), or today's market value when history isn't required.
-- Days of price history the deals average: 7 for reagents and other crafting materials,
-- whose prices move fast, 15 for everything else.
local REAGENT_CLASSES = { [5] = true, [7] = true }   -- Reagent, Trade Goods
function ns:ReferenceDays(id)
  if ns.Reagents[id] then return 7 end
  local classID = select(6, ns.ItemInfoInstant(id))
  return REAGENT_CLASSES[classID] and 7 or 15
end

-- Value the deals compare against: the average market value of the last 7 or 15 days.
function ns:Reference(id)
  local cur, avg, _, _, days = self:PriceStats(id, self:ReferenceDays(id))
  if avg and days >= 1 then return avg end
  if not self.db.settings.deals.requireHistory then return cur end
  return nil
end

local function isGear(id)
  local _, _, _, equipLoc = ns.ItemInfoInstant(id)
  return equipLoc ~= nil and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"
end

local function dealKey(id, l)
  return id .. ":" .. math.floor(l.unit) .. ":" .. l.count
end

local MAX_DEALS = 50
local PER_ITEM = 1   -- one row per item: its best deal (the others open under it)

-- The 50 best deals you can pay for now. First the ones that reach your margin (spread and
-- minimum profit), by profit; if there are fewer than 50, the list is completed with the
-- next best returns below your margin (marked `good = false`).
function ns:FindDeals()
  local cfg = self.db.settings.deals
  local money = GetMoney()
  local keep = ns.SaleKeep()
  -- Keep the purchase state of deals that are still listed.
  local previous = {}
  for _, d in ipairs(self.deals) do
    if d.state then previous[dealKey(d.id, d.l)] = d.state end
  end
  local good, extra = {}, {}
  -- How many scanned items could be compared at all (they need a reference price).
  local stats = { items = 0, priced = 0 }
  for id, list in pairs(self.listings) do
    if cfg.gear or not isGear(id) then
      stats.items = stats.items + 1
      local ref = self:Reference(id)
      if ref and ref > 0 then
        stats.priced = stats.priced + 1
        local maxPrice, net, n = ns.MaxBuyPrice(ref), ref * keep, 0
        for _, l in ipairs(list) do
          if l.unit >= net or n >= PER_ITEM then break end   -- sorted by price: no return past here
          if not l.mine and l.unit <= money then
            local profit, roi = ns.DealProfit(l.unit, l.count, ref)
            local d = { id = id, l = l, ref = ref, roi = roi, profit = profit, state = previous[dealKey(id, l)] }
            if l.unit <= maxPrice and profit >= cfg.minProfitCopper then
              d.good = true
              good[#good + 1] = d
            else
              extra[#extra + 1] = d
            end
            n = n + 1
          end
        end
      end
    end
  end
  table.sort(good, function(a, b) return a.profit > b.profit end)
  table.sort(extra, function(a, b) return a.roi > b.roi end)
  local deals = {}
  for _, d in ipairs(good) do
    if #deals >= MAX_DEALS then break end
    deals[#deals + 1] = d
  end
  for _, d in ipairs(extra) do
    if #deals >= MAX_DEALS then break end
    deals[#deals + 1] = d
  end
  self.deals = deals
  self.dealStats = stats
  self:Fire("DEALS")
end

-- Why there are no deals, as text: no scan, an old scan, no price history yet, or simply
-- nothing within your criteria.
function ns:NoDealsReason()
  if not self:ScanIsFresh() then return L.DEALS_STALE end
  local stats = self.dealStats
  if stats and stats.items > 0 and stats.priced == 0 then return L.NO_HISTORY_YET end
  return L.NO_DEALS_IN_SCAN:format(ns.Duration((self:ScanAge() or 0) / 60)) .. " " .. L.DEALS_EMPTY_TIP
end

-- What you can afford changes with your gold.
ns:On("MONEY", function()
  if next(ns.listings) then ns:Throttle("deals-money", 2, function() ns:FindDeals() end) end
end)

-- Buying ---------------------------------------------------------------------------------
-- The game requires a click for every purchase. Listings from a full scan have no auction
-- ID, so the first click finds the auction and the second one buys it. Commodities show
-- the final price first (it can change) and buy on the confirming click.

local pendingCommodity
local inFlight = {}   -- deals (or search rows) being bought

-- Finds an auction to buy: the cheapest one that is still a deal (at or below the price
-- seen, or below the highest price that gives the wanted spread). Used for full-scan
-- listings, which have no auction ID, and to buy again after a purchase. The search
-- rebuilds the deal list, so the matching new deal is marked ready for the buying click.
local function locate(d)
  d.state = "locating"
  ns:Fire("DEALS")
  local id = d.id
  -- Shopping list rows (d.anyPrice) take the cheapest auction at any price.
  local limit = d.anyPrice and math.huge or math.max(d.l.unit * 1.001, d.ref and ns.MaxBuyPrice(d.ref) or 0)
  ns:QuickSearch({ id }, function()
    local found
    for _, l in ipairs(ns.listings[id] or {}) do
      if not l.mine and l.unit <= limit then
        found = l
        break
      end
    end
    d.l = found or d.l
    d.state = found and "ready" or "gone"
    for _, nd in ipairs(ns.deals) do
      if found and nd.id == id and nd.l == found then nd.state = "ready" end
    end
    if not found then ns.Print(L.DEAL_GONE:format(ns.ItemName(id))) end
    ns:Fire("DEALS")
  end)
end

-- Estimated cost of `qty` units of a commodity: the cheapest listings of other players,
-- the rest at the row's price.
local function commodityCost(d, qty)
  local sum, n = 0, 0
  for _, l in ipairs(ns.listings[d.id] or {}) do
    if not l.mine and n < qty then
      local take = math.min(l.count, qty - n)
      sum, n = sum + l.unit * take, n + take
    end
  end
  return sum + math.max(0, qty - n) * d.l.unit
end

-- Checked before asking the game, so a purchase you can't pay for never starts.
local function enoughGold(cost)
  local money = GetMoney()
  if cost <= money then return true end
  ns.W.Alert(L.NOT_ENOUGH_GOLD_TITLE, L.NOT_ENOUGH_GOLD:format(ns.Money(cost), ns.Money(money)))
  return false
end

-- The game may refuse a purchase without a failure event: after 10 seconds the button
-- stops waiting and offers "Reload".
local function watchBuying(d)
  C_Timer.After(10, function()
    if d.state == "buying" then
      if pendingCommodity == d then pendingCommodity = nil end
      d.state = "failed"
      ns.Print(L.BUY_FAILED)
      ns:Fire("DEALS")
    end
  end)
end

-- Called from a click on a deal's button.
function ns:BuyDeal(d)
  if not ns.ahOpen then ns.Print(L.SCAN_NEED_AH); return end
  if d.state == "locating" or d.state == "buying" or d.state == "quote" then return end
  local l = d.l
  -- The purchase failed: "Reload" searches only this item again (real price, quantity and
  -- auction ID) and the button goes back to "Buy".
  if d.state == "failed" then
    d.needsLocate = nil
    locate(d)
    return
  end
  -- An item auction already bought (or gone): look for the next one that is still a deal.
  if not l.commodity and (d.state == "gone" or d.needsLocate) then
    d.needsLocate = nil
    locate(d)
    return
  end
  if l.commodity then
    -- Commodities: the quantity from the row's box; the quote covers the cheapest units.
    if d.state == "confirm" then
      if not enoughGold(d.quote or 0) then
        ns:CancelBuy(d)
        return
      end
      AH.ConfirmCommoditiesPurchase(d.id, d.qtyQuoted)
      d.state = "buying"
      watchBuying(d)
    else
      -- extraQty: units of other auctions checked under the deal (Deals tab).
      local qty = ns.DealBuyQty(d) + (d.extraQty or 0)
      if not enoughGold(commodityCost(d, qty)) then
        ns:Fire("DEALS")
        return
      end
      d.qtyQuoted = qty
      pendingCommodity = d
      AH.StartCommoditiesPurchase(d.id, d.qtyQuoted)
      d.state = "quote"
      -- No answer (e.g. more units than are for sale): never leave the button stuck.
      C_Timer.After(5, function()
        if d.state == "quote" then
          if pendingCommodity == d then pendingCommodity = nil end
          d.state = "failed"
          ns.Print(L.BUY_FAILED)
          ns:Fire("DEALS")
        end
      end)
    end
  elseif l.auctionID then
    if not enoughGold(l.unit * l.count) then return end
    AH.PlaceBid(l.auctionID, l.unit * l.count)
    d.state = "buying"
    inFlight[#inFlight + 1] = d
    watchBuying(d)
  else
    locate(d)
    return
  end
  ns:Fire("DEALS")
end

-- Gives up a purchase that is waiting for the confirming click (a commodity quote): the
-- game drops the quote and the button goes back to "Buy".
function ns:CancelBuy(d)
  if d.state == "confirm" or d.state == "quote" then
    if pendingCommodity == d then pendingCommodity = nil end
    if AH.CancelCommoditiesPurchase then pcall(AH.CancelCommoditiesPurchase) end
    d.state, d.quote, d.qtyQuoted = nil, nil, nil
  end
  ns:Fire("DEALS")
end

ns:On("COMMODITY_PRICE_UPDATED", function(_, totalPrice)
  local d = pendingCommodity
  if d and d.state == "quote" then
    d.quote, d.state = totalPrice, "confirm"
    ns:Fire("DEALS")
  end
end)

-- After a purchase the row stays usable: commodities quote again on the next click; an
-- item auction is gone, so the next click looks for another one.
-- After a purchase the lowest price is the cheapest auction that is left, not the one just
-- bought (nobody else selling: the market value).
local function refreshLowest(id)
  local e = ns.db.market[id]
  if not e then return end
  for _, l in ipairs(ns.listings[id] or {}) do
    if not l.mine and l.count > 0 then
      e.p = l.unit
      return
    end
  end
  e.p = e.m or e.p
end

-- A commodity purchase takes the cheapest units first.
local function consumeCheapest(id, qty)
  local list = ns.listings[id]
  if not list then return end
  for _, l in ipairs(list) do
    if qty <= 0 then break end
    if not l.mine then
      local take = math.min(l.count, qty)
      l.count, qty = l.count - take, qty - take
    end
  end
  for i = #list, 1, -1 do
    if list[i].count <= 0 then table.remove(list, i) end
  end
end

local function bought(d)
  local qty = d.qtyQuoted or d.l.count
  ns.Print(L.BOUGHT:format(qty, ns.ItemName(d.id), ns.PlainMoney(d.quote or d.l.unit * qty)))
  d.boughtCount = (d.boughtCount or 0) + qty
  if d.onBought then d.onBought(qty) end
  d.state, d.quote, d.qtyQuoted = nil, nil, nil
  if not d.l.commodity then
    local list = ns.listings[d.id]
    for i, l in ipairs(list or {}) do
      if l == d.l then table.remove(list, i); break end
    end
    d.needsLocate = true
  else
    consumeCheapest(d.id, qty)
  end
  refreshLowest(d.id)
  ns:Fire("DEALS")
  ns:Fire("PRICES")
end

ns:On("COMMODITY_PURCHASE_SUCCEEDED", function()
  local d = pendingCommodity
  if d and d.state == "buying" then bought(d) end
  pendingCommodity = nil
end)

ns:On("COMMODITY_PURCHASE_FAILED", function()
  local d = pendingCommodity
  if d then d.state = "failed" end   -- the button becomes "Reload" for this item
  pendingCommodity = nil
  ns.Print(L.BUY_FAILED)
  ns:Fire("DEALS")
end)

ns:On("AUCTION_HOUSE_PURCHASE_COMPLETED", function(auctionID)
  for i, d in ipairs(inFlight) do
    if d.l.auctionID == auctionID then
      table.remove(inFlight, i)
      bought(d)
      return
    end
  end
end)

-- Errors such as "not enough money" arrive here, for items and commodities alike.
ns:On("AUCTION_HOUSE_SHOW_ERROR", function()
  local failed = false
  for _, d in ipairs(inFlight) do
    if d.state == "buying" then d.state, failed = "failed", true end
  end
  wipe(inFlight)
  local d = pendingCommodity
  if d and (d.state == "quote" or d.state == "buying" or d.state == "confirm") then
    d.state, d.quote, failed = "failed", nil, true
    pendingCommodity = nil
  end
  if failed then ns.Print(L.BUY_FAILED) end
  ns:Fire("DEALS")
end)
