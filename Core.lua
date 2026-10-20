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
    defaultMargin = 0,
    categoryMargin = {},
    duration = 2,          -- 1 = 12h, 2 = 24h, 3 = 48h
    bidPercent = 95,
    openWithAH = true,
    showHold = false,
    prof = {
      budget = 20,
      useBank = true,
      craft = true,
      target = "trainer",  -- "trainer" or "max"
      hideDone = false,
      showUnlearned = false,
    },
  },
  prices = {},             -- [itemID] = { [day] = copper }
  farm = {},               -- [categoryKey] = { value = copper, seconds = n }
  nodes = {},              -- [uiMapID] = { [itemID] = { { x, y }, ... } } where the player gathered
  lastPriceUpdate = 0,
}

local CHAR_DEFAULTS = {
  gold = {},               -- [day] = copper
  bank = {},               -- [itemID] = count
  bankTime = 0,
  auctions = {},           -- posted auctions, newest first
  lastAuctionSync = 0,
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

function ns.HasAuctionator()
  return Auctionator and Auctionator.API and Auctionator.API.v1 and true or false
end

-- Current Auction House price from Auctionator, or nil.
function ns.Price(id)
  if type(id) ~= "number" or not ns.HasAuctionator() then return nil end
  local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, ns.callerID, id)
  if ok and price and price > 0 then return price end
  return nil
end

-- Days since Auctionator last saw the item, or nil.
function ns.PriceAge(id)
  if type(id) ~= "number" or not ns.HasAuctionator() or not Auctionator.API.v1.GetAuctionAgeByItemID then return nil end
  local ok, age = pcall(Auctionator.API.v1.GetAuctionAgeByItemID, ns.callerID, id)
  if ok then return age end
  return nil
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

local function recordGold()
  if ns.char then ns.char.gold[ns.Today()] = GetMoney() end
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
  if ns.HasAuctionator() and Auctionator.API.v1.RegisterForDBUpdate then
    pcall(Auctionator.API.v1.RegisterForDBUpdate, ns.callerID, function()
      ns:Throttle("snapshot", 2, function()
        ns:SnapshotPrices()
        ns:Fire("PRICES")
      end)
    end)
  end
  C_Timer.After(5, function()
    ns:SnapshotPrices()
    ns:Fire("PRICES")
  end)
  C_Timer.NewTicker(3600, recordGold)
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
