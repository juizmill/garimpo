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
  ns:FindDeals()
  ns:Fire("PRICES")
  if mode == "browse" then
    ns.Print(L.SCAN_DONE_BROWSE:format(ns.Num(items), #ns.deals))
  else
    ns.Print(L.SCAN_DONE:format(ns.Num(count), ns.Num(items), #ns.deals))
  end
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
function ns:Reference(id)
  local cur, avg, _, _, days = self:PriceStats(id)
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
local PER_ITEM = 3   -- so one item can't fill the whole list

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

-- Called from a click on a deal's button.
function ns:BuyDeal(d)
  if not ns.ahOpen then ns.Print(L.SCAN_NEED_AH); return end
  if d.state == "locating" or d.state == "buying" or d.state == "quote" then return end
  local l = d.l
  -- An item auction already bought (or gone): look for the next one that is still a deal.
  if not l.commodity and (d.state == "gone" or d.needsLocate) then
    d.needsLocate = nil
    locate(d)
    return
  end
  if l.commodity then
    -- Commodities: the quantity from the row's box; the quote covers the cheapest units.
    if d.state == "confirm" then
      AH.ConfirmCommoditiesPurchase(d.id, d.qtyQuoted)
      d.state = "buying"
    else
      d.qtyQuoted = ns.DealBuyQty(d)
      pendingCommodity = d
      AH.StartCommoditiesPurchase(d.id, d.qtyQuoted)
      d.state = "quote"
    end
  elseif l.auctionID then
    AH.PlaceBid(l.auctionID, l.unit * l.count)
    d.state = "buying"
    inFlight[#inFlight + 1] = d
  else
    locate(d)
    return
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
  end
  ns:Fire("DEALS")
end

ns:On("COMMODITY_PURCHASE_SUCCEEDED", function()
  local d = pendingCommodity
  if d and d.state == "buying" then bought(d) end
  pendingCommodity = nil
end)

ns:On("COMMODITY_PURCHASE_FAILED", function()
  local d = pendingCommodity
  if d then d.state = nil end
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

ns:On("AUCTION_HOUSE_SHOW_ERROR", function()
  for _, d in ipairs(inFlight) do
    if d.state == "buying" then d.state = "gone" end
  end
  wipe(inFlight)
  ns:Fire("DEALS")
end)
