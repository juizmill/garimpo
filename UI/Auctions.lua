local _, ns = ...
local L, W = ns.L, ns.W

-- Posted auctions: every post (Garimpo, Auctionator or the game's own UI) is recorded
-- through hooks; the owned-auctions list syncs them while the Auction House is open,
-- and the "sold"/"expired" chat messages update them anywhere.

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
  ns:PlaySaleSound()
  ns.Print(L.SOLD_MSG:format(rec.qty or 1, rec.name or "?", ns.PlainMoney(rec.total or 0)))
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
      if not rec then
        for _, r in ipairs(list) do
          if not r.auctionID and r.status == "active" and r.itemID == itemID and r.qty == info.quantity then
            rec = r
            rec.auctionID = info.auctionID
            break
          end
        end
      end
      if not rec then
        rec = { auctionID = info.auctionID, itemID = itemID, name = itemID and ns.ItemName(itemID) or "?",
          qty = info.quantity or 1, total = (info.buyoutAmount or info.bidAmount or 0) * (info.quantity or 1),
          postedAt = now, status = "active" }
        add(rec)
      end
      if info.timeLeftSeconds then rec.expiresAt = now + info.timeLeftSeconds end
      if Enum.AuctionStatus and info.status == Enum.AuctionStatus.Sold then markSold(rec) end
    end
  end
  -- Auctions we tracked that the game no longer lists have ended.
  for _, r in ipairs(list) do
    if r.status == "active" and r.auctionID and not seen[r.auctionID] then
      r.status = (r.expiresAt and now >= r.expiresAt - 60) and "expired" or "ended"
      r.endedAt = now
    end
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

-- Chat messages: "A buyer has been found for your auction of %s." and friends.
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

ns:On("CHAT_MSG_SYSTEM", function(msg)
  if not msg or not ns.char then return end
  for _, p in ipairs(patterns()) do
    local name = p[1] and msg:match(p[1])
    if name then
      -- The oldest active auction of that item is the one that ended.
      local list, match = records(), nil
      for i = #list, 1, -1 do
        local r = list[i]
        if r.status == "active" and r.name == name then match = r; break end
      end
      if p[2] == "sold" then
        if match then markSold(match)
        else
          ns:PlaySaleSound()
          ns:Fire("AUCTIONS")
        end
      elseif match then
        match.status, match.endedAt = p[2], time()
        ns:Fire("AUCTIONS")
      end
      return
    end
  end
end)

-- Auctions whose time ran out while we couldn't see them.
local function expireOld()
  if not ns.char then return end
  local now, changed = time(), false
  for _, r in ipairs(records()) do
    if r.status == "active" and r.expiresAt and now > r.expiresAt + 300 then
      r.status, r.endedAt, changed = "expired", r.expiresAt, true
    end
  end
  if changed then ns:Fire("AUCTIONS") end
end

ns:On("READY", function()
  expireOld()
  C_Timer.NewTicker(60, expireOld)
end)

-- View ---------------------------------------------------------------------------------

local STATUS_PILL = { active = "active", sold = "sold", expired = "expired", ended = "ended" }

ns:RegisterView("auctions", function(parent)
  local f = CreateFrame("Frame", nil, parent)

  local active = W.Stat(f, "STAT_ACTIVE", 200)
  active:SetPoint("TOPLEFT", 0, 0)
  local sold = W.Stat(f, "STAT_SOLD_7D", 200)
  sold:SetPoint("LEFT", active, "RIGHT", 8, 0)
  local expired = W.Stat(f, "STAT_EXPIRED_7D", 200)
  expired:SetPoint("LEFT", sold, "RIGHT", 8, 0)

  f.filter = "all"
  local filter = W.Chips(f, function(v)
    f.filter = v
    f:Refresh()
  end)
  filter:SetPoint("TOPLEFT", 0, -46)
  filter:SetItems({
    { value = "all", key = "FILTER_ALL" }, { value = "active", key = "FILTER_ACTIVE" },
    { value = "sold", key = "FILTER_SOLD" }, { value = "expired", key = "FILTER_ENDED" },
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
  foot:SetPoint("RIGHT", -170, 0)
  foot:SetWordWrap(true)

  local clear = W.Button(f, "CLEAR_FINISHED", 160, function()
    local keep = {}
    for _, r in ipairs(records()) do
      if r.status == "active" then keep[#keep + 1] = r end
    end
    ns.char.auctions = keep
    f:Refresh()
  end)
  clear:SetPoint("BOTTOMRIGHT", 0, 0)

  local function ago(ts)
    return ns.Duration((time() - ts) / 60)
  end

  function f:Refresh()
    expireOld()
    local now, weekAgo = time(), time() - 7 * 86400
    local nActive, vActive, vSold, nSold, nExpired = 0, 0, 0, 0, 0
    local data = {}
    for _, r in ipairs(records()) do
      if r.status == "active" then nActive, vActive = nActive + 1, vActive + (r.total or 0) end
      if r.status == "sold" and (r.endedAt or 0) >= weekAgo then nSold, vSold = nSold + 1, vSold + (r.total or 0) end
      if r.status == "expired" and (r.endedAt or 0) >= weekAgo then nExpired = nExpired + 1 end
      local show = self.filter == "all" or r.status == self.filter
        or (self.filter == "expired" and r.status == "ended")
      if show then
        local timeText
        if r.status == "active" then
          timeText = r.expiresAt and ns.Duration(math.max(r.expiresAt - now, 0) / 60) or "-"
        else
          timeText = r.endedAt and ns.Color("muted", L.AGO:format(ago(r.endedAt))) or "-"
        end
        data[#data + 1] = {
          itemID = type(r.itemID) == "number" and r.itemID or nil,
          icon = r.itemID and ns.ItemIcon(r.itemID) or nil,
          cells = {
            r.itemID and ("|cff" .. ns.ItemQualityHex(r.itemID) .. (r.name or ns.ItemName(r.itemID)) .. "|r") or (r.name or "?"),
            ns.Num(r.qty or 1),
            ns.Money(r.total),
            r.postedAt and L.AGO:format(ago(r.postedAt)) or "-",
            timeText,
            W.Pill(STATUS_PILL[r.status] or "ended"),
          },
          tone = r.status == "sold" and "top" or (r.status ~= "active" and "done" or nil),
        }
      end
    end
    active:Set(nActive .. "  " .. ns.Color("muted", "(" .. ns.Money(vActive) .. ")"))
    sold:Set(ns.Money(vSold) .. "  " .. ns.Color("muted", "(" .. nSold .. ")"), W.C.up)
    expired:Set(tostring(nExpired))
    list:SetData(data, L.AUCTIONS_EMPTY)
    local last = ns.char.lastAuctionSync
    foot:SetText(last and last > 0 and L.AUCTIONS_SYNCED:format(ago(last)) or L.AUCTIONS_SYNC_HINT)
  end

  return f
end)

ns:On("AUCTIONS", function()
  ns:Throttle("auctions", 0.3, function() ns:RefreshCurrent() end)
end)
