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
ns.searchResults = {}       -- itemIDs of the last quick search, in order

local function setState(state, done, total)
  ns.scan.state, ns.scan.done, ns.scan.total = state, done or 0, total or 0
  ns:Fire("SCAN")
end

function ns.CanScan()
  return ns.ahOpen and AH ~= nil and AH.ReplicateItems ~= nil
end

function ns:FullScanWait()
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
  e.p, e.m, e.q, e.t = base[1].unit, m, q, time()
  local day = ns.Today()
  self.db.prices[itemID] = self.db.prices[itemID] or {}
  self.db.prices[itemID][day] = m
end

-- Full scan ------------------------------------------------------------------------------

local function finishFull(byItem, count)
  wipe(ns.listings)
  for id, list in pairs(byItem) do ns:StoreListings(id, list) end
  -- Items that were on the Auction House before and are gone now.
  for id, e in pairs(ns.db.market) do
    if not byItem[id] then e.q = 0 end
  end
  ns.db.lastFullScan = time()
  ns:PruneHistory()
  local items = 0
  for _ in pairs(byItem) do items = items + 1 end
  setState("idle")
  ns:FindDeals()
  ns:Fire("PRICES")
  ns.Print(L.SCAN_DONE:format(ns.Num(count), ns.Num(items), #ns.deals))
end

local function processReplicate()
  local total = AH.GetNumReplicateItems()
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
    if i < total then C_Timer.After(0, step) else finishFull(byItem, total) end
  end
  step()
end

function ns:FullScan()
  if not ns.ahOpen then ns.Print(L.SCAN_NEED_AH); return end
  if not (AH and AH.ReplicateItems) then ns.Print(L.SCAN_UNSUPPORTED); return end
  if self.scan.state ~= "idle" then return end
  local wait = self:FullScanWait()
  if wait > 0 then
    ns.Print(L.SCAN_WAIT:format(ns.Duration(wait / 60 + 0.5)))
    return
  end
  setState("waiting")
  AH.ReplicateItems()
  C_Timer.After(90, function()
    if ns.scan.state == "waiting" then
      setState("idle")
      ns.Print(L.SCAN_TIMEOUT)
    end
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
  self.searchResults = { unpack(queue) }
  onFinished = done
  setState("searching", 0, #queue)
  nextSearch()
end

ns:On("COMMODITY_SEARCH_RESULTS_UPDATED", function(itemID)
  if itemID ~= current or currentDone then return end
  currentDone = true
  local list = {}
  for i = 1, AH.GetNumCommoditySearchResults(itemID) do
    local r = AH.GetCommoditySearchResultInfo(itemID, i)
    if r and r.unitPrice and r.quantity then
      list[#list + 1] = { unit = r.unitPrice, count = r.quantity, mine = r.containsOwnerItem,
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
        auctionID = r.auctionID, itemKey = itemKey }
    end
  end
  ns:StoreListings(itemKey.itemID, list)
  advance()
end)

ns:On("AUCTION_HOUSE_SHOW", function()
  if ns.db.settings.scan.auto and ns.CanScan() and ns:FullScanWait() == 0 then
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

-- What an item is worth for a deal: its 7-day average, or today's market value when
-- history isn't required.
function ns:Reference(id)
  local cur, avg, _, _, days = self:PriceStats(id)
  if avg and days >= 2 then return avg end
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

function ns:FindDeals()
  local cfg = self.db.settings.deals
  -- Keep the purchase state of deals that are still listed.
  local previous = {}
  for _, d in ipairs(self.deals) do
    if d.state then previous[dealKey(d.id, d.l)] = d.state end
  end
  local deals = {}
  for id, list in pairs(self.listings) do
    if cfg.gear or not isGear(id) then
      local ref = self:Reference(id)
      if ref and ref > 0 then
        local maxPrice = ns.MaxBuyPrice(ref)
        for _, l in ipairs(list) do
          if l.unit > maxPrice then break end   -- sorted by price: nothing cheaper follows
          if not l.mine then
            local profit, roi = ns.DealProfit(l.unit, l.count, ref)
            if profit >= cfg.minProfitCopper then
              deals[#deals + 1] = { id = id, l = l, ref = ref, roi = roi, profit = profit,
                state = previous[dealKey(id, l)] }
            end
          end
        end
      end
    end
  end
  table.sort(deals, function(a, b) return a.profit > b.profit end)
  while #deals > 200 do table.remove(deals) end
  self.deals = deals
  self:Fire("DEALS")
end

-- Buying ---------------------------------------------------------------------------------
-- The game requires a click for every purchase. Listings from a full scan have no auction
-- ID, so the first click finds the auction and the second one buys it. Commodities show
-- the final price first (it can change) and buy on the confirming click.

local pendingCommodity
local inFlight = {}   -- deals (or search rows) being bought

-- Finds the auction of a full-scan listing. The search rebuilds the deal list, so the
-- matching new deal (now with an auction ID) is marked ready for the buying click.
local function locate(d)
  d.state = "locating"
  ns:Fire("DEALS")
  local id, unit, count = d.id, d.l.unit, d.l.count
  ns:QuickSearch({ id }, function()
    local found
    for _, l in ipairs(ns.listings[id] or {}) do
      if not l.mine and l.unit <= unit * 1.001 and (l.commodity or l.count == count) then
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
  if d.state == "bought" or d.state == "gone" or d.state == "locating" or d.state == "buying" then return end
  local l = d.l
  if l.commodity then
    if d.state == "confirm" then
      AH.ConfirmCommoditiesPurchase(d.id, l.count)
      d.state = "buying"
    else
      pendingCommodity = d
      AH.StartCommoditiesPurchase(d.id, l.count)
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

local function bought(d)
  d.state = "bought"
  ns.Print(L.BOUGHT:format(d.l.count, ns.ItemName(d.id), ns.PlainMoney(d.quote or d.l.unit * d.l.count)))
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
