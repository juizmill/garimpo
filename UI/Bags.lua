local _, ns = ...
local L, W = ns.L, ns.W

ns:RegisterView("bags", function(parent)
  local f = CreateFrame("Frame", nil, parent)

  local value = W.Stat(f, "STAT_BAG_VALUE", 200)
  value:SetPoint("TOPLEFT", 0, 0)
  local sell = W.Stat(f, "STAT_SELL_NOW", 200)
  sell:SetPoint("LEFT", value, "RIGHT", 8, 0)
  local junk = W.Stat(f, "STAT_JUNK", 200)
  junk:SetPoint("LEFT", sell, "RIGHT", 8, 0)

  f.includeBank = false
  local bank = W.Check(f, "INCLUDE_BANK", function(on)
    f.includeBank = on
    f:Refresh()
  end)
  bank:SetPoint("TOPLEFT", 0, -44)
  f.bankAge = W.Font(f, 11, W.C.muted)
  f.bankAge:SetPoint("LEFT", bank.label, "RIGHT", 8, 0)

  local list = W.List(f, {
    { width = 210, header = "COL_ITEM" },
    { width = 50, justify = "RIGHT", header = "COL_QTY" },
    { width = 100, justify = "RIGHT", header = "COL_TOTAL" },
    { width = 70, justify = "RIGHT", header = "COL_VS_AVG" },
    { width = 90, header = "COL_ACTION" },
  }, 22)
  list:SetPoint("TOPLEFT", 0, -72)
  list:SetPoint("BOTTOMRIGHT", 0, 30)

  local note = W.Font(f, 11, W.C.muted)
  note:SetPoint("BOTTOMLEFT", 0, 6)
  W.Label(note, "BOUND_NOTE")

  local post = W.Button(f, "OPEN_AH_PANEL", 150, function() ns:ShowAuctionPanel(true) end)
  post:SetPoint("BOTTOMRIGHT", 0, 0)
  local sellJunk = W.Button(f, "SELL_JUNK", 120, function()
    local n = ns:SellJunk()
    if n > 0 then ns.Print(L.SOLD_JUNK:format(n)) end
  end)
  sellJunk:SetPoint("RIGHT", post, "LEFT", -6, 0)

  function f:Refresh()
    local rows, totals = ns:BagReport(self.includeBank)
    value:Set(ns.Money(totals.value))
    sell:Set(ns.Money(totals.sell), W.C.up)
    junk:Set(ns.Money(totals.junk))
    if ns.char.bankTime > 0 then
      self.bankAge:SetText(L.BANK_SEEN:format(ns.Duration((time() - ns.char.bankTime) / 60)))
    else
      self.bankAge:SetText(L.BANK_NEVER)
    end
    local data = {}
    for _, e in ipairs(rows) do
      data[#data + 1] = {
        itemID = e.id, icon = ns.ItemIcon(e.id),
        cells = {
          "|cff" .. ns.ItemQualityHex(e.id) .. ns.ItemName(e.id) .. "|r",
          ns.Num(e.count),
          ns.Money(e.total or e.junk),
          e.diff and ns.Pct(e.diff) or ns.Color("muted", "-"),
          e.advice and W.Pill(e.advice) or ns.Color("muted", "-"),
        },
        sort = { ns.ItemName(e.id), e.count, e.total or e.junk, e.diff, e.advice },
      }
    end
    list:SetData(data, ns.HasPrices() and L.BAGS_EMPTY or L.NO_PRICES)
    sellJunk:SetEnabled(ns.merchantOpen and totals.junk > 0)
    post:SetEnabled(ns.ahOpen == true)
  end

  return f
end)
