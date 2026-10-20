local _, ns = ...
local L, W = ns.L, ns.W

local function addLines(tooltip, id)
  if not ns.db or not ns.db.settings.tooltip then return end
  local cur, avg, change = ns:PriceStats(id)
  if not cur and not avg then return end
  tooltip:AddLine(" ")
  tooltip:AddLine("Garimpo", 1, 0.82, 0)
  local lowest, qty = ns.Price(id), ns.Quantity(id)
  if lowest then tooltip:AddDoubleLine(L.TT_LOWEST, ns.Money(lowest), 0.91, 0.88, 0.82, 1, 1, 1) end
  tooltip:AddDoubleLine(L.TT_AH, ns.Money(cur), 0.91, 0.88, 0.82, 1, 1, 1)
  if avg then tooltip:AddDoubleLine(L.TT_AVG7, ns.Money(avg), 0.91, 0.88, 0.82, 1, 1, 1) end
  if qty then
    local age = ns.PriceAge(id)
    tooltip:AddDoubleLine(L.TT_QTY, ns.Num(qty) .. (age and age > 0 and ns.Color("muted", "  (" .. L.DAYS_AGO:format(age) .. ")") or ""),
      0.91, 0.88, 0.82, 1, 1, 1)
  end
  local advice = ns:Advice(id)
  if change or advice then
    tooltip:AddDoubleLine(L.TT_TREND, ns.Pct(change) .. (advice and ("  " .. W.Pill(advice)) or ""), 0.91, 0.88, 0.82, 1, 1, 1)
  end
  local cat = ns:CategoryOf(id)
  if cat then
    tooltip:AddDoubleLine(L.TT_CATEGORY, ns.T(ns.CategoryByKey[cat].name), 0.91, 0.88, 0.82, 1, 1, 1)
  end
  tooltip:Show()
end

local function onItem(tooltip)
  local _, link = tooltip:GetItem()
  if not link then return end
  local id = ns.ItemInfoInstant(link)
  if id then addLines(tooltip, id) end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
    if tooltip == GameTooltip or tooltip == ItemRefTooltip then onItem(tooltip) end
  end)
else
  GameTooltip:HookScript("OnTooltipSetItem", onItem)
  ItemRefTooltip:HookScript("OnTooltipSetItem", onItem)
end
