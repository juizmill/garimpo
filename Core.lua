local ADDON, ns = ...
local L = ns.L

ns.callerID = "Garimpo"

local DEFAULTS = {
  settings = {
    language = "auto",
    tooltip = true,
    minimap = { hide = false, angle = 215 },
    waypoint = { arrow = true, native = true },
    sale = { sound = true, kind = "register" },   -- kind: "register" or "coins"
    scan = { auto = true },                       -- full scan when the Auction House opens
    -- spread: wanted profit over the price paid, after the Auction House cut (ahCut %).
    deals = { spread = 20, ahCut = 5, minProfitCopper = 10000, requireHistory = true, gear = false, buyQty = 10 },
    defaultMargin = 0,
    cutFloor = 20,         -- undercuts more than this % below market value are ignored
    categoryMargin = {},
    duration = 2,          -- 1 = 12h, 2 = 24h, 3 = 48h
    bidPercent = 95,
    openWithAH = true,
    showHold = false,
    prof = {
      budgetCopper = 200000,   -- 20g
      useBank = true,
      craft = true,
      target = "trainer",  -- "trainer" or "max"
      hideDone = false,
      showUnlearned = false,
    },
  },
  prices = {},             -- [itemID] = { [day] = market value in copper }
  market = {},             -- [itemID] = { p = lowest, m = market value, q = quantity, t = time }
  ignored = {},            -- [itemID] = true: hidden from the Post tab (kept when settings are reset)
  dealCols = {},           -- column widths of the Deals list chosen by dragging
  lastFullScan = 0,
  farm = {},               -- [categoryKey] = { value = copper, seconds = n }
  nodes = {},              -- [uiMapID] = { [itemID] = { { x, y }, ... } } where the player gathered
}

local CHAR_DEFAULTS = {
  gold = {},               -- [day] = copper
  bank = {},               -- [itemID] = count
  bankTime = 0,
  auctions = {},           -- posted auctions, newest first (active, and sold until collected)
  sales = {},              -- { t = time, total = copper } for the last 30 days
  purchases = {},          -- { t, itemID, name, qty, total } bought at the AH, last 30 days
  lastAuctionSync = 0,
  goldToday = { day = 0, points = {} },
}

local function fill(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      fill(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

function ns:ResetSettings()
  local keep = self.db.settings.minimap
  self.db.settings = {}
  fill(self.db.settings, DEFAULTS.settings)
  self.db.settings.minimap = keep
end

-- Message bus: game events and internal messages share it.
local listeners = {}

function ns:On(msg, fn)
  listeners[msg] = listeners[msg] or {}
  table.insert(listeners[msg], fn)
end

function ns:Fire(msg, ...)
  local list = listeners[msg]
  if not list then return end
  for _, fn in ipairs(list) do fn(...) end
end

local pending = {}

-- Runs fn once after delay, no matter how many times it is requested meanwhile.
function ns:Throttle(key, delay, fn)
  if pending[key] then return end
  pending[key] = true
  C_Timer.After(delay, function()
    pending[key] = nil
    fn()
  end)
end

-- Days and numbers

function ns.Today()
  local d = date("*t")
  return math.floor(time({ year = d.year, month = d.month, day = d.day, hour = 12 }) / 86400)
end

function ns.DayLabel(day)
  return date(L.DATE_SHORT, day * 86400 + 43200)
end

function ns.Num(n)
  local s = tostring(math.floor((n or 0) + 0.5))
  local neg = s:sub(1, 1) == "-"
  if neg then s = s:sub(2) end
  local sep = ns.lang == "ptBR" and "." or ","
  s = s:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
  if s:sub(1, 1) == sep then s = s:sub(2) end
  return (neg and "-" or "") .. s
end

local ICON_G = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:1:0|t"
local ICON_S = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:1:0|t"
local ICON_C = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:1:0|t"

-- Money with coin icons. Hides copper above 1g and silver above 1000g unless full is set.
function ns.Money(copper, full)
  if not copper then return "-" end
  copper = math.floor(copper + 0.5)
  local neg = copper < 0
  if neg then copper = -copper end
  local g, s, c = math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100
  local parts = {}
  if g > 0 then parts[#parts + 1] = ns.Num(g) .. ICON_G end
  if s > 0 and (full or g < 1000) then parts[#parts + 1] = s .. ICON_S end
  if c > 0 and (full or g == 0) then parts[#parts + 1] = c .. ICON_C end
  if #parts == 0 then parts[1] = "0" .. ICON_C end
  return (neg and "-" or "") .. table.concat(parts, " ")
end

-- Whole gold only, for summaries.
function ns.Gold(copper)
  if not copper then return "-" end
  local g = copper >= 0 and math.floor(copper / 10000) or -math.floor(-copper / 10000)
  return ns.Num(g) .. ICON_G
end

-- Gold per hour of the session: full value (gold, silver, copper), "+" when positive.
function ns.SessionRate()
  local rate = ns:SessionGain() / ns:SessionHours()
  return (rate > 0 and "+" or "") .. ns.Money(rate) .. "/h", rate
end

-- Money as plain text for chat: "12g 30s".
function ns.PlainMoney(copper)
  copper = math.floor((copper or 0) + 0.5)
  local g, s, c = math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100
  local parts = {}
  if g > 0 then parts[#parts + 1] = ns.Num(g) .. "g" end
  if s > 0 then parts[#parts + 1] = s .. "s" end
  if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
  return table.concat(parts, " ")
end

ns.HEX = {
  gold = "ffd100", ink = "e8e0d0", muted = "9a8f7c", up = "3fd16b", down = "ff5a4a",
  flat = "c9b98f", blue = "6cc5ff", purple = "c9a2ff",
}

function ns.Color(hex, text)
  return "|cff" .. (ns.HEX[hex] or hex) .. text .. "|r"
end

-- Signed percentage, colored green/red.
function ns.Pct(frac)
  if not frac then return ns.Color("muted", "-") end
  local p = math.floor(frac * 100 + (frac >= 0 and 0.5 or -0.5))
  if p > 0 then return ns.Color("up", "+" .. p .. "%") end
  if p < 0 then return ns.Color("down", "-" .. -p .. "%") end
  return ns.Color("flat", "0%")
end

function ns.Duration(minutes)
  minutes = math.floor((minutes or 0) + 0.5)
  local h, m = math.floor(minutes / 60), minutes % 60
  if h > 0 then return string.format("%dh%02d", h, m) end
  return m .. " min"
end

-- Text from data tables that carry both languages: { en = "...", pt = "..." }.
function ns.T(t)
  if type(t) ~= "table" then return t end
  return (ns.lang == "ptBR" and t.pt) or t.en
end

function ns.ProfName(key)
  local info = ns.ProfessionInfo[key]
  return ns.lang == "ptBR" and info.names[2] or info.names[1]
end

function ns.ZoneName(mapID)
  local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  return info and info.name or ("#" .. mapID)
end

function ns.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(ns.Color("gold", "Garimpo") .. ": " .. msg)
end

-- Items and prices
-- Forever runs on the modern engine, where the item functions live in C_Item.

ns.ItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
ns.ItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local itemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon

-- Some reagents (e.g. Forever's Mote of Magic) have no known item ID; the data
-- names them with a string key in ns.Reagents instead.
function ns.ItemName(id)
  if type(id) == "string" then
    local r = ns.Reagents[id]
    return r and ns.T(r.name) or id
  end
  local name = ns.ItemInfo(id)
  if not name and C_Item and C_Item.RequestLoadItemDataByID then
    C_Item.RequestLoadItemDataByID(id)
  end
  return name or ("item:" .. id)
end

function ns.ItemIcon(id)
  if type(id) == "string" then
    local r = ns.Reagents[id]
    return r and r.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
  end
  return itemIcon(id) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function ns.ItemQualityHex(id)
  if type(id) == "string" then return "ffffff" end
  local _, _, quality = ns.ItemInfo(id)
  local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
  return c and c.hex and c.hex:sub(5) or "ffffff"
end

-- Prices come from Garimpo's own Auction House scans (Scanner.lua), stored in
-- db.market[itemID] = { p = lowest unit buyout, m = market value, q = quantity listed, t = scan time }.

function ns.HasPrices()
  return ns.db ~= nil and next(ns.db.market) ~= nil
end

-- Lowest unit buyout seen in the last scan: what you pay now, and what posting at 0% matches.
function ns.Price(id)
  local e = type(id) == "number" and ns.db and ns.db.market[id]
  return e and e.p or nil
end

-- Market value: average of the cheapest 15% of the quantity listed. Used for values and trends.
function ns.Market(id)
  local e = type(id) == "number" and ns.db and ns.db.market[id]
  return e and (e.m or e.p) or nil
end

function ns.Quantity(id)
  local e = type(id) == "number" and ns.db and ns.db.market[id]
  return e and e.q or nil
end

-- Days since the item was last seen on the Auction House, or nil.
function ns.PriceAge(id)
  local e = type(id) == "number" and ns.db and ns.db.market[id]
  if not (e and e.t) then return nil end
  return math.floor((time() - e.t) / 86400)
end

-- Vendor price from the Wowhead data; otherwise about four times what merchants pay.
function ns.VendorBuyPrice(id)
  if type(id) == "string" then
    local r = ns.Reagents[id]
    return r and r.price
  end
  local v = ns.Vendors and ns.Vendors[id]
  if v and v.price and v.price > 0 then return v.price end
  local sell = select(11, ns.ItemInfo(id))
  if sell and sell > 0 then return sell * 4 end
  return nil
end

-- Gold history

-- Daily close for history, and today's points { time, copper } for the chart.
local function recordGold()
  if not ns.char then return end
  local today, money, now = ns.Today(), GetMoney(), time()
  ns.char.gold[today] = money
  local t = ns.char.goldToday
  if t.day ~= today then
    t.day, t.points = today, {}
  end
  local pts = t.points
  local last = pts[#pts]
  -- Same amount within 10 minutes adds nothing to the line.
  if last and last[2] == money and now - last[1] < 600 then return end
  pts[#pts + 1] = { now, money }
  -- Keep the day light: thin the older half when it grows past 600 points.
  if #pts > 600 then
    local thinned = {}
    for i, p in ipairs(pts) do
      if i > 300 or i % 2 == 1 then thinned[#thinned + 1] = p end
    end
    t.points = thinned
  end
end

local function prune(t, keepDays)
  local cutoff = ns.Today() - keepDays
  for day in pairs(t) do
    if day < cutoff then t[day] = nil end
  end
end

function ns:SessionGain()
  return GetMoney() - (self.session and self.session.money or GetMoney())
end

function ns:SessionHours()
  return math.max((GetTime() - (self.session and self.session.start or GetTime())) / 3600, 1 / 60)
end

-- Events

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, ...) ns:Fire(event, ...) end)
for _, event in ipairs({
  "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LOGOUT", "PLAYER_MONEY",
  "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED",
  "LOOT_READY", "LOOT_SLOT_CLEARED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
  "MERCHANT_SHOW", "MERCHANT_CLOSED", "SKILL_LINES_CHANGED", "GET_ITEM_INFO_RECEIVED",
  "CHAT_MSG_SYSTEM", "OWNED_AUCTIONS_UPDATED", "AUCTION_HOUSE_AUCTION_CREATED",
  "REPLICATE_ITEM_LIST_UPDATE", "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED",
  "COMMODITY_PRICE_UPDATED", "COMMODITY_PURCHASE_SUCCEEDED", "COMMODITY_PURCHASE_FAILED",
  "AUCTION_HOUSE_PURCHASE_COMPLETED", "AUCTION_HOUSE_SHOW_ERROR", "MAIL_INBOX_UPDATE",
  "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "AUCTION_CANCELED",
}) do
  -- Some events only exist on one engine; registering an unknown one raises an error.
  pcall(frame.RegisterEvent, frame, event)
end

ns:On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  GarimpoDB = GarimpoDB or {}
  GarimpoCharDB = GarimpoCharDB or {}
  fill(GarimpoDB, DEFAULTS)
  fill(GarimpoCharDB, CHAR_DEFAULTS)
  ns.db, ns.char = GarimpoDB, GarimpoCharDB
  -- 0.2.0 kept these two in whole gold; they are in copper now.
  local s = ns.db.settings
  if s.deals.minProfit then s.deals.minProfitCopper, s.deals.minProfit = math.floor(s.deals.minProfit * 10000), nil end
  if s.prof.budget then s.prof.budgetCopper, s.prof.budget = math.floor(s.prof.budget * 10000), nil end
  s.deals.discount = nil   -- replaced by the spread in 0.2.2
  ns:SetLanguage(ns.db.settings.language)
  prune(ns.char.gold, 400)
  ns:Fire("INIT")
end)

ns:On("PLAYER_LOGIN", function()
  ns.session = { start = GetTime(), money = GetMoney() }
  recordGold()
  -- A failure reading skills must not stop the rest of the start-up.
  local ok, err = pcall(ns.ReadSkills, ns)
  if not ok then
    ns.skills = ns.skills or {}
    geterrorhandler()(err)
  end
  C_Timer.NewTicker(300, recordGold)
  ns:Fire("READY")
end)

ns:On("PLAYER_MONEY", function()
  recordGold()
  ns:Fire("MONEY")
end)

ns:On("PLAYER_LOGOUT", recordGold)

ns:On("SKILL_LINES_CHANGED", function()
  ns:Throttle("skills", 1, function()
    ns:ReadSkills()
    ns:Fire("SKILLS")
  end)
end)

ns:On("GET_ITEM_INFO_RECEIVED", function()
  ns:Throttle("items", 0.5, function() ns:Fire("ITEMS") end)
end)

ns:On("BAG_UPDATE_DELAYED", function()
  if ns.bankOpen then ns:CacheBank() end
  ns:Throttle("bags", 0.3, function() ns:Fire("BAGS") end)
end)

ns:On("BANKFRAME_OPENED", function()
  ns.bankOpen = true
  ns:CacheBank()
end)

ns:On("BANKFRAME_CLOSED", function() ns.bankOpen = false end)

ns:On("PLAYERBANKSLOTS_CHANGED", function()
  if ns.bankOpen then ns:CacheBank() end
end)

ns:On("MERCHANT_SHOW", function() ns.merchantOpen = true; ns:Fire("BAGS") end)
ns:On("MERCHANT_CLOSED", function() ns.merchantOpen = false; ns:Fire("BAGS") end)

-- Slash commands

SLASH_GARIMPO1 = "/garimpo"
SLASH_GARIMPO2 = "/gar"
SlashCmdList.GARIMPO = function(msg)
  msg = strtrim((msg or ""):lower())
  if msg == "config" then
    ns:ShowMain("config")
  elseif msg == "reset" then
    ns:ResetWindow()
  elseif msg == "som" or msg == "sound" then
    ns:PlaySaleSound(true)
  else
    ns:ToggleMain()
  end
end
