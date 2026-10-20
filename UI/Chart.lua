local _, ns = ...
local L, W = ns.L, ns.W

local PAD_L, PAD_R, PAD_T, PAD_B = 56, 12, 12, 20

local function niceScale(min, max)
  local span = max - min
  if span <= 0 then span = math.max(max * 0.1, 1) end
  local raw = span / 4
  local p = 10 ^ math.floor(math.log10(raw))
  local m = raw / p
  local step = (m <= 1 and 1 or m <= 2 and 2 or m <= 2.5 and 2.5 or m <= 5 and 5 or 10) * p
  local lo, hi = math.floor(min / step) * step, math.ceil(max / step) * step
  if hi <= lo then hi = lo + step end
  return lo, hi, step
end

-- Daily gold for the last `days` days; days without a record repeat the previous value.
local function series(days)
  local gold, today = ns.char.gold, ns.Today()
  local out, last = {}, nil
  for d = today - 400, today - days do
    if gold[d] then last = gold[d] end
  end
  for d = today - days + 1, today do
    if gold[d] then last = gold[d] end
    if last then out[#out + 1] = { day = d, value = last } end
  end
  return out
end

ns:RegisterView("chart", function(parent)
  local f = CreateFrame("Frame", nil, parent)
  f.range = 30

  local first = W.Stat(f, "STAT_PERIOD_START", 200)
  first:SetPoint("TOPLEFT", 0, 0)
  local now = W.Stat(f, "STAT_NOW", 200)
  now:SetPoint("LEFT", first, "RIGHT", 8, 0)
  local change = W.Stat(f, "STAT_CHANGE", 200)
  change:SetPoint("LEFT", now, "RIGHT", 8, 0)

  local title = W.Font(f, 12, W.C.gold)
  title:SetPoint("TOPLEFT", 0, -52)
  W.Label(title, "CHART_TITLE")

  local ranges = W.Chips(f, function(v)
    f.range = v
    f:Refresh()
  end)
  ranges:SetPoint("TOPRIGHT", 0, -48)
  ranges:SetItems({
    { value = 7, key = "RANGE_7" }, { value = 30, key = "RANGE_30" }, { value = 90, key = "RANGE_90" },
  })
  ranges:Select(30)
  W.OnRelabel(function()
    ranges:ClearAllPoints()
    ranges:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -48)
  end)

  local chart = W.Box(f)
  chart:SetPoint("TOPLEFT", 0, -76)
  chart:SetPoint("BOTTOMRIGHT", 0, 24)
  f.chart = chart

  local note = W.Font(f, 11, W.C.muted)
  note:SetPoint("BOTTOMLEFT", 0, 4)
  W.Label(note, "CHART_NOTE")

  local empty = W.Font(chart, 13, W.C.muted, "CENTER")
  empty:SetPoint("CENTER")
  W.Label(empty, "CHART_EMPTY")

  local pools = { lines = {}, grid = {}, labels = {}, fills = {} }
  local function take(kind, maker)
    pools[kind].used = (pools[kind].used or 0) + 1
    local obj = pools[kind][pools[kind].used]
    if not obj then
      obj = maker()
      pools[kind][pools[kind].used] = obj
    end
    obj:Show()
    return obj
  end
  local function reset()
    for _, pool in pairs(pools) do
      for i = 1, #pool do pool[i]:Hide() end
      pool.used = 0
    end
  end

  local cross = chart:CreateTexture(nil, "OVERLAY")
  cross:SetTexture(W.FLAT)
  cross:SetVertexColor(0.6, 0.56, 0.49, 0.8)
  cross:SetWidth(1)
  cross:Hide()
  local dot = chart:CreateTexture(nil, "OVERLAY")
  dot:SetTexture("Interface\\Buttons\\WHITE8X8")
  dot:SetVertexColor(1, 0.82, 0, 1)
  dot:SetSize(6, 6)
  dot:Hide()

  local points = {}

  function f:Refresh()
    reset()
    wipe(points)
    local data = series(self.range)
    first.label:SetText(L.STAT_DAYS_AGO:format(self.range))
    if #data < 2 then
      empty:Show()
      first:Set(data[1] and ns.Money(data[1].value) or nil)
      now:Set(ns.Money(GetMoney()))
      change:Set(nil)
      return
    end
    empty:Hide()

    local lo, hi = math.huge, -math.huge
    for _, p in ipairs(data) do
      lo, hi = math.min(lo, p.value / 10000), math.max(hi, p.value / 10000)
    end
    local smin, smax, step = niceScale(lo, hi)
    local w, h = chart:GetWidth() - PAD_L - PAD_R, chart:GetHeight() - PAD_T - PAD_B
    local function X(i) return PAD_L + (i - 1) * w / (#data - 1) end
    local function Y(v) return PAD_B + (v / 10000 - smin) * h / (smax - smin) end

    for v = smin, smax + step / 2, step do
      local y = PAD_B + (v - smin) * h / (smax - smin)
      local g = take("grid", function()
        local t = chart:CreateTexture(nil, "BACKGROUND", nil, 1)
        t:SetTexture(W.FLAT)
        t:SetVertexColor(W.C.line[1], W.C.line[2], W.C.line[3], 0.8)
        t:SetHeight(1)
        return t
      end)
      g:ClearAllPoints()
      g:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", PAD_L, y)
      g:SetPoint("BOTTOMRIGHT", chart, "BOTTOMRIGHT", -PAD_R, y)
      local lab = take("labels", function() return W.Font(chart, 10, W.C.muted, "RIGHT") end)
      lab:ClearAllPoints()
      lab:SetJustifyH("RIGHT")
      lab:SetPoint("RIGHT", chart, "BOTTOMLEFT", PAD_L - 6, y)
      lab:SetText(ns.Num(v))
    end

    local every = self.range <= 7 and 1 or (self.range <= 30 and 5 or 15)
    for i = #data, 1, -every do
      local lab = take("labels", function() return W.Font(chart, 10, W.C.muted, "CENTER") end)
      lab:ClearAllPoints()
      lab:SetJustifyH("CENTER")
      lab:SetPoint("TOP", chart, "BOTTOMLEFT", X(i), PAD_B - 4)
      lab:SetText(ns.DayLabel(data[i].day))
    end

    local colWidth = w / (#data - 1)
    for i, p in ipairs(data) do
      points[i] = { x = X(i), y = Y(p.value), day = p.day, value = p.value }
      local fill = take("fills", function()
        local t = chart:CreateTexture(nil, "BORDER")
        t:SetTexture(W.FLAT)
        t:SetVertexColor(1, 0.82, 0, 0.08)
        return t
      end)
      fill:ClearAllPoints()
      fill:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", X(i) - colWidth / 2, PAD_B)
      fill:SetSize(math.max(colWidth, 1), math.max(Y(p.value) - PAD_B, 0.001))
      if i > 1 then
        local line = take("lines", function()
          local l = chart:CreateLine(nil, "ARTWORK")
          l:SetThickness(2)
          l:SetColorTexture(1, 0.82, 0, 1)
          return l
        end)
        line:SetStartPoint("BOTTOMLEFT", chart, points[i - 1].x, points[i - 1].y)
        line:SetEndPoint("BOTTOMLEFT", chart, points[i].x, points[i].y)
      end
    end

    local a, b = data[1].value, data[#data].value
    first:Set(ns.Money(a))
    now:Set(ns.Money(b))
    local diff = b - a
    local pct = a > 0 and math.floor(diff / a * 100 + 0.5) or 0
    change:Set((diff >= 0 and "+" or "") .. ns.Money(diff) .. "  (" .. (diff >= 0 and "+" or "") .. pct .. "%)",
      diff >= 0 and W.C.up or W.C.down)
  end

  chart:SetScript("OnEnter", function(self) self.hover = true end)
  chart:SetScript("OnLeave", function(self)
    self.hover = false
    cross:Hide()
    dot:Hide()
    GameTooltip:Hide()
  end)
  chart:SetScript("OnUpdate", function(self)
    if not self.hover or #points < 2 then return end
    local x = GetCursorPosition() / self:GetEffectiveScale() - self:GetLeft()
    local best, bestDist = nil, math.huge
    for _, p in ipairs(points) do
      local d = math.abs(p.x - x)
      if d < bestDist then best, bestDist = p, d end
    end
    if not best then return end
    cross:ClearAllPoints()
    cross:SetPoint("BOTTOM", self, "BOTTOMLEFT", best.x, PAD_B)
    cross:SetHeight(self:GetHeight() - PAD_B - PAD_T)
    cross:Show()
    dot:ClearAllPoints()
    dot:SetPoint("CENTER", self, "BOTTOMLEFT", best.x, best.y)
    dot:Show()
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetText(ns.DayLabel(best.day))
    GameTooltip:AddLine(ns.Money(best.value), 1, 1, 1)
    GameTooltip:Show()
  end)
  chart:EnableMouse(true)

  return f
end)
