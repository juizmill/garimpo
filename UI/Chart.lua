local _, ns = ...
local L, W = ns.L, ns.W

-- Today's gold over time: one point each time the gold changes (and every 5 minutes),
-- plus "now", so the line follows what you earn and spend through the day.

local PAD_L, PAD_R, PAD_T, PAD_B = 60, 12, 12, 20

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

local function todayPoints()
  local t = ns.char.goldToday
  local pts = {}
  if t and t.day == ns.Today() then
    for _, p in ipairs(t.points) do pts[#pts + 1] = { t = p[1], v = p[2] } end
  end
  pts[#pts + 1] = { t = time(), v = GetMoney() }
  return pts
end

ns:RegisterView("chart", function(parent)
  local f = CreateFrame("Frame", nil, parent)

  local first = W.Stat(f, "STAT_DAY_START", 200)
  first:SetPoint("TOPLEFT", 0, 0)
  local now = W.Stat(f, "STAT_NOW", 200)
  now:SetPoint("LEFT", first, "RIGHT", 8, 0)
  local change = W.Stat(f, "STAT_CHANGE", 200)
  change:SetPoint("LEFT", now, "RIGHT", 8, 0)

  local title = W.Font(f, 12, W.C.gold)
  title:SetPoint("TOPLEFT", 0, -52)
  W.Label(title, "CHART_TITLE")

  local chart = W.Box(f)
  chart:SetPoint("TOPLEFT", 0, -72)
  chart:SetPoint("BOTTOMRIGHT", 0, 24)

  local note = W.Font(f, 11, W.C.muted)
  note:SetPoint("BOTTOMLEFT", 0, 4)
  W.Label(note, "CHART_NOTE")

  local pools = { lines = {}, grid = {}, labels = {} }
  local function take(kind, maker)
    local pool = pools[kind]
    pool.used = (pool.used or 0) + 1
    local obj = pool[pool.used]
    if not obj then
      obj = maker()
      pool[pool.used] = obj
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
  dot:SetTexture(W.FLAT)
  dot:SetVertexColor(1, 0.82, 0, 1)
  dot:SetSize(6, 6)
  dot:Hide()

  local points = {}

  function f:Refresh()
    reset()
    wipe(points)
    local data = todayPoints()
    local a, b = data[1].v, data[#data].v
    first:Set(ns.Money(a))
    now:Set(ns.Money(b))
    local diff = b - a
    change:Set((diff >= 0 and "+" or "") .. ns.Money(diff), diff > 0 and W.C.up or (diff < 0 and W.C.down or W.C.ink))

    local lo, hi = math.huge, -math.huge
    for _, p in ipairs(data) do
      lo, hi = math.min(lo, p.v / 10000), math.max(hi, p.v / 10000)
    end
    local smin, smax, step = niceScale(lo, hi)
    local t0, t1 = data[1].t, data[#data].t
    if t1 - t0 < 600 then t0 = t1 - 600 end
    local w, h = chart:GetWidth() - PAD_L - PAD_R, chart:GetHeight() - PAD_T - PAD_B
    local function X(t) return PAD_L + (t - t0) * w / (t1 - t0) end
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
      local lab = take("labels", function() return W.Font(chart, 10, W.C.muted) end)
      lab:ClearAllPoints()
      lab:SetJustifyH("RIGHT")
      lab:SetPoint("RIGHT", chart, "BOTTOMLEFT", PAD_L - 6, y)
      lab:SetText(ns.Num(v) .. "g")
    end

    -- Five time marks from the first point to now.
    for i = 0, 4 do
      local t = t0 + (t1 - t0) * i / 4
      local lab = take("labels", function() return W.Font(chart, 10, W.C.muted) end)
      lab:ClearAllPoints()
      lab:SetJustifyH("CENTER")
      lab:SetPoint("TOP", chart, "BOTTOMLEFT", X(t), PAD_B - 4)
      lab:SetText(date("%H:%M", t))
    end

    -- Steps: the gold stays level until the next change.
    for i, p in ipairs(data) do
      points[i] = { x = X(p.t), y = Y(p.v), t = p.t, v = p.v }
      if i > 1 then
        local prev = points[i - 1]
        local flat = take("lines", function()
          local l = chart:CreateLine(nil, "ARTWORK")
          l:SetThickness(2)
          l:SetColorTexture(1, 0.82, 0, 1)
          return l
        end)
        flat:SetStartPoint("BOTTOMLEFT", chart, prev.x, prev.y)
        flat:SetEndPoint("BOTTOMLEFT", chart, points[i].x, prev.y)
        if prev.y ~= points[i].y then
          local rise = take("lines", function()
            local l = chart:CreateLine(nil, "ARTWORK")
            l:SetThickness(2)
            l:SetColorTexture(1, 0.82, 0, 1)
            return l
          end)
          rise:SetStartPoint("BOTTOMLEFT", chart, points[i].x, prev.y)
          rise:SetEndPoint("BOTTOMLEFT", chart, points[i].x, points[i].y)
        end
      end
    end
  end

  chart:EnableMouse(true)
  chart:SetScript("OnEnter", function(self) self.hover = true end)
  chart:SetScript("OnLeave", function(self)
    self.hover = false
    cross:Hide()
    dot:Hide()
    GameTooltip:Hide()
  end)
  chart:SetScript("OnUpdate", function(self)
    if not self.hover or #points == 0 then return end
    local x = GetCursorPosition() / self:GetEffectiveScale() - self:GetLeft()
    -- The value in effect at the cursor: the last point at or before it.
    local best = points[1]
    for _, p in ipairs(points) do
      if p.x <= x then best = p end
    end
    cross:ClearAllPoints()
    cross:SetPoint("BOTTOM", self, "BOTTOMLEFT", best.x, PAD_B)
    cross:SetHeight(self:GetHeight() - PAD_B - PAD_T)
    cross:Show()
    dot:ClearAllPoints()
    dot:SetPoint("CENTER", self, "BOTTOMLEFT", best.x, best.y)
    dot:Show()
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetText(date("%H:%M", best.t))
    GameTooltip:AddLine(ns.Money(best.v, true), 1, 1, 1)
    GameTooltip:Show()
  end)

  -- Move "now" forward while the tab is open.
  C_Timer.NewTicker(60, function()
    if f:IsVisible() then f:Refresh() end
  end)

  return f
end)
