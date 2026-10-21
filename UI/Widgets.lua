local _, ns = ...
local L = ns.L

local W = {}
ns.W = W

local FLAT = "Interface\\Buttons\\WHITE8X8"
W.FLAT = FLAT

W.C = {
  bg     = { 0.075, 0.062, 0.05, 1 },
  bg2    = { 0.047, 0.04, 0.031, 1 },
  panel  = { 0.13, 0.105, 0.08, 1 },
  edge   = { 0.42, 0.33, 0.19, 1 },
  line   = { 0.23, 0.18, 0.11, 1 },
  gold   = { 1, 0.82, 0 },
  ink    = { 0.91, 0.88, 0.82 },
  muted  = { 0.6, 0.56, 0.49 },
  up     = { 0.25, 0.82, 0.42 },
  down   = { 1, 0.35, 0.29 },
}

function W.Box(parent, bg, edge)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
  local b, e = bg or W.C.bg2, edge or W.C.line
  f:SetBackdropColor(b[1], b[2], b[3], b[4] or 1)
  f:SetBackdropBorderColor(e[1], e[2], e[3], e[4] or 1)
  return f
end

function W.Font(parent, size, color, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(STANDARD_TEXT_FONT, size or 12, "")
  local c = color or W.C.ink
  fs:SetTextColor(c[1], c[2], c[3])
  fs:SetJustifyH(justify or "LEFT")
  fs:SetWordWrap(false)
  return fs
end

-- Localized labels are re-applied when the language changes.
local labels, relayouts = {}, {}

local function applyLabel(e)
  local text = L[e.key]
  if e.args then text = text:format(unpack(e.args)) end
  e.target:SetText(text)
end

function W.Label(target, key, ...)
  local e = { target = target, key = key, args = select("#", ...) > 0 and { ... } or nil }
  labels[#labels + 1] = e
  applyLabel(e)
  return target
end

function W.OnRelabel(fn)
  relayouts[#relayouts + 1] = fn
end

function W.RelabelAll()
  for _, e in ipairs(labels) do applyLabel(e) end
  for _, fn in ipairs(relayouts) do fn() end
end

function W.Line(parent)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetTexture(FLAT)
  t:SetVertexColor(W.C.line[1], W.C.line[2], W.C.line[3], 1)
  t:SetHeight(1)
  return t
end

function W.Button(parent, key, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width or 110, 22)
  if key then W.Label(b, key) end
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

-- Small header + value box used in summary rows.
function W.Stat(parent, key, width)
  local box = W.Box(parent)
  box:SetSize(width or 170, 38)
  box.label = W.Font(box, 10, W.C.muted)
  box.label:SetPoint("TOPLEFT", 8, -6)
  W.Label(box.label, key)
  box.value = W.Font(box, 13, W.C.ink)
  box.value:SetPoint("BOTTOMLEFT", 8, 6)
  box.value:SetPoint("RIGHT", -6, 0)
  function box:Set(text, color)
    self.value:SetText(text or "-")
    local c = color or W.C.ink
    self.value:SetTextColor(c[1], c[2], c[3])
  end
  return box
end

-- Row of toggle buttons. items = { { value = x, key = "LOCALE_KEY" } or { value = x, text = "..." } }
function W.Chips(parent, onSelect, style)
  local g = CreateFrame("Frame", nil, parent)
  g.buttons, g.items = {}, {}
  local height = style == "tab" and 24 or 20

  local function styleButton(b, on)
    local c = on and W.C.gold or W.C.muted
    b.text:SetTextColor(c[1], c[2], c[3])
    local bg = on and W.C.panel or W.C.bg2
    b:SetBackdropColor(bg[1], bg[2], bg[3], 1)
    local e = on and W.C.edge or W.C.line
    b:SetBackdropBorderColor(e[1], e[2], e[3], 1)
  end

  function g:Layout()
    local x = 0
    for i, b in ipairs(self.buttons) do
      if i <= #self.items then
        b:SetWidth(math.max(b.text:GetStringWidth() + 20, 40))
        b:ClearAllPoints()
        b:SetPoint("LEFT", self, "LEFT", x, 0)
        x = x + b:GetWidth() + 3
      end
    end
    self:SetSize(math.max(x - 3, 1), height)
  end

  function g:SetItems(items)
    self.items = items
    for i, it in ipairs(items) do
      local b = self.buttons[i]
      if not b then
        b = CreateFrame("Button", nil, self, "BackdropTemplate")
        b:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
        b:SetHeight(height)
        b.text = W.Font(b, style == "tab" and 12 or 11, W.C.muted, "CENTER")
        b.text:SetPoint("CENTER")
        b:SetScript("OnClick", function(btn) g:Select(btn.value, true) end)
        self.buttons[i] = b
      end
      b.value = it.value
      b.text:SetText(it.key and L[it.key] or it.text)
      b.key = it.key
      b:Show()
    end
    for i = #items + 1, #self.buttons do self.buttons[i]:Hide() end
    self:Layout()
    self:Select(self.value)
  end

  function g:Select(value, fire)
    self.value = value
    for i, b in ipairs(self.buttons) do
      if i <= #self.items then styleButton(b, b.value == value) end
    end
    if fire and onSelect then onSelect(value) end
  end

  W.OnRelabel(function()
    for i, b in ipairs(g.buttons) do
      if i <= #g.items and b.key then b.text:SetText(L[b.key]) end
    end
    g:Layout()
  end)
  return g
end

function W.Edit(parent, width, onChange)
  local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  e:SetSize(width or 50, 20)
  e:SetAutoFocus(false)
  e:SetJustifyH("RIGHT")
  e:SetScript("OnEnterPressed", e.ClearFocus)
  e:SetScript("OnEscapePressed", e.ClearFocus)
  e:SetScript("OnTextChanged", function(self, userInput)
    if userInput and onChange then onChange(self:GetText()) end
  end)
  return e
end

-- Money field: gold, silver and copper boxes with coin icons. Values are in copper.
local COINS = {
  { "Interface\\MoneyFrame\\UI-GoldIcon", 10000, 46 },
  { "Interface\\MoneyFrame\\UI-SilverIcon", 100, 26 },
  { "Interface\\MoneyFrame\\UI-CopperIcon", 1, 26 },
}

function W.Money(parent, onChange)
  local f = CreateFrame("Frame", nil, parent)
  f.boxes = {}
  local x = 0
  local function changed()
    if onChange then onChange(f:GetValue()) end
  end
  for i, coin in ipairs(COINS) do
    local e = W.Edit(f, coin[3], changed)
    e:SetPoint("LEFT", f, "LEFT", x + 6, 0)
    e:SetMaxLetters(i == 1 and 7 or 2)
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(13, 13)
    icon:SetPoint("LEFT", e, "RIGHT", 2, 0)
    icon:SetTexture(coin[1])
    f.boxes[i] = e
    x = x + coin[3] + 24
  end
  f:SetSize(x, 20)

  function f:GetValue()
    local total = 0
    for i, coin in ipairs(COINS) do
      total = total + (tonumber(self.boxes[i]:GetText()) or 0) * coin[2]
    end
    return math.max(0, math.floor(total))
  end

  function f:SetValue(copper)
    copper = math.max(0, math.floor(copper or 0))
    local parts = { math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100 }
    for i, e in ipairs(self.boxes) do e:SetText(tostring(parts[i])) end
  end

  function f:HasFocus()
    for _, e in ipairs(self.boxes) do
      if e:HasFocus() then return true end
    end
    return false
  end

  return f
end

function W.Check(parent, key, onClick)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(22, 22)
  c.label = W.Font(c, 12, W.C.ink)
  c.label:SetPoint("LEFT", c, "RIGHT", 2, 0)
  W.Label(c.label, key)
  c:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
  return c
end

function W.Bar(parent, width, height, color)
  local bar = W.Box(parent, { 0.04, 0.035, 0.03, 1 }, { 0.17, 0.14, 0.09, 1 })
  bar:SetSize(width, height)
  local fill = bar:CreateTexture(nil, "ARTWORK")
  fill:SetTexture(FLAT)
  fill:SetPoint("TOPLEFT", 1, -1)
  fill:SetPoint("BOTTOMLEFT", 1, 1)
  local c = color or W.C.gold
  fill:SetVertexColor(c[1], c[2], c[3], 1)
  function bar:SetValue(frac)
    frac = math.max(0, math.min(1, frac or 0))
    fill:SetWidth(math.max(0.001, (self:GetWidth() - 2) * frac))
    fill:SetShown(frac > 0)
  end
  return bar
end

-- Status pill as colored text.
local PILLS = {
  sell = { "up", "PILL_SELL" }, hold = { "gold", "PILL_HOLD" }, farm = { "blue", "PILL_FARM" },
  normal = { "flat", "PILL_NORMAL" }, vendor = { "ink", "PILL_VENDOR" }, buy = { "up", "PILL_BUY" },
  mixed = { "gold", "PILL_MIXED" }, unknown = { "muted", "PILL_UNKNOWN" }, done = { "muted", "PILL_DONE" },
  current = { "gold", "PILL_CURRENT" }, train = { "purple", "PILL_TRAIN" }, book = { "purple", "PILL_BOOK" },
  quest = { "purple", "PILL_QUEST" }, cheapest = { "up", "PILL_CHEAPEST" }, posted = { "up", "PILL_POSTED" },
  active = { "blue", "PILL_ACTIVE" }, sold = { "up", "PILL_SOLD" }, expired = { "down", "PILL_EXPIRED" },
  ended = { "muted", "PILL_ENDED" }, bought = { "gold", "PILL_BOUGHT" },
}

function W.Pill(kind)
  local p = PILLS[kind]
  if not p then return "" end
  return ns.Color(p[1], L[p[2]]:upper())
end

-- Sorts rows in place by value(row). Numbers and text compare naturally, missing values
-- go last, and ties keep their previous order.
function W.SortRows(rows, value, asc)
  local index = {}
  for i, r in ipairs(rows) do index[r] = i end
  table.sort(rows, function(a, b)
    local va, vb = value(a), value(b)
    if va == nil or vb == nil then
      if va == vb then return index[a] < index[b] end
      return vb == nil
    end
    if type(va) ~= type(vb) then va, vb = tostring(va), tostring(vb) end
    if type(va) == "string" then va, vb = va:lower(), vb:lower() end
    if va == vb then return index[a] < index[b] end
    if asc then return va < vb end
    return va > vb
  end)
end

-- Clickable column title; the sorted column shows ^ (ascending) or v (descending).
function W.SortHeader(parent, key, width, justify, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width, 18)
  b.text = W.Font(b, 10, W.C.muted, justify)
  b.text:SetAllPoints()
  b.key = key
  W.Label(b.text, key)
  b:SetScript("OnClick", onClick)
  b:SetScript("OnEnter", function(self) self.text:SetTextColor(W.C.ink[1], W.C.ink[2], W.C.ink[3]) end)
  b:SetScript("OnLeave", function(self) self:SetArrow(self.dir) end)
  function b:SetArrow(dir)
    self.dir = dir
    local c = dir and W.C.gold or W.C.muted
    self.text:SetTextColor(c[1], c[2], c[3])
    self.text:SetText(L[self.key] .. (dir == "asc" and " ^" or (dir == "desc" and " v" or "")))
  end
  return b
end

-- Sorting state for lists built by hand: click a title once to sort (text A-Z, numbers
-- high to low), again to reverse. textCols = { [col] = true } for text columns.
function W.Sorter(onChange, textCols)
  local s = { headers = {}, textCols = textCols or {} }
  function s:Add(button, col)
    button.col = col
    self.headers[#self.headers + 1] = button
    button:SetScript("OnClick", function() s:Toggle(col) end)
  end
  function s:Toggle(col)
    if self.col == col then
      self.asc = not self.asc
    else
      self.col, self.asc = col, self.textCols[col] == true
    end
    self:Paint()
    onChange()
  end
  function s:Paint()
    for _, h in ipairs(self.headers) do
      h:SetArrow(h.col == self.col and (self.asc and "asc" or "desc") or nil)
    end
  end
  return s
end

-- Scrolling table. cols = { { width = n, justify = "LEFT", header = "KEY", wrap = bool, bar = bool, size = n } }
-- Data rows: { cells = { ... }, sort = { value per column }, icon = texture, iconCol = n,
--   link = itemLink, itemID = id, tip = { lines }, extra = { lines after the item tooltip },
--   onClick = fn, check = bool, onCheck = fn,
--   tone = "current"|"done"|"mile"|"top", colors = { [col] = color } }
-- Rows with `sort` values can be sorted by clicking the column titles.
function W.List(parent, cols, rowHeight)
  local list = CreateFrame("Frame", nil, parent)
  list.cols, list.rowHeight, list.rows = cols, rowHeight or 20, {}

  list.header = CreateFrame("Frame", nil, list)
  list.header:SetPoint("TOPLEFT")
  list.header:SetPoint("TOPRIGHT")
  list.header:SetHeight(18)
  list.headers = {}
  local x = 4
  for i, c in ipairs(cols) do
    c.x = x
    if c.header and c.header ~= "" then
      local h = W.SortHeader(list.header, c.header, c.width, c.justify, function() list:SortBy(i) end)
      h:SetPoint("LEFT", list.header, "LEFT", x, 0)
      list.headers[i] = h
    end
    x = x + c.width + 6
  end

  function list:SortBy(col)
    local first = self.lastData and self.lastData[1]
    if not (first and first.sort) then return end
    if self.sortCol == col then
      self.sortAsc = not self.sortAsc
    else
      self.sortCol, self.sortAsc = col, type(first.sort[col]) == "string"
    end
    self:SetData(self.lastData, self.lastEmpty)
  end
  local line = W.Line(list.header)
  line:SetPoint("BOTTOMLEFT")
  line:SetPoint("BOTTOMRIGHT")

  local sf = CreateFrame("ScrollFrame", nil, list, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 0, -20)
  sf:SetPoint("BOTTOMRIGHT", -24, 0)
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(1, 1)
  sf:SetScrollChild(child)
  sf:SetScript("OnSizeChanged", function(_, w) child:SetWidth(w) end)
  list.scroll, list.child = sf, child

  list.empty = W.Font(list, 12, W.C.muted, "CENTER")
  list.empty:SetPoint("TOPLEFT", 10, -40)
  list.empty:SetPoint("TOPRIGHT", -10, -40)
  list.empty:SetWordWrap(true)

  local function makeRow(i)
    local r = CreateFrame("Button", nil, child)
    r:SetHeight(list.rowHeight)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * list.rowHeight)
    r:SetPoint("RIGHT", child, "RIGHT")
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetTexture(FLAT)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture(FLAT)
    hl:SetVertexColor(1, 1, 1, 0.05)
    r.cells, r.bars = {}, {}
    for c, col in ipairs(cols) do
      if col.bar then
        local b = W.Bar(r, col.width, 8)
        b:SetPoint("LEFT", r, "LEFT", col.x, 0)
        r.bars[c] = b
      end
      local fs = W.Font(r, col.size or 12, W.C.ink, col.justify)
      fs:SetWidth(col.width)
      if col.wrap then
        fs:SetWordWrap(true)
        fs:SetJustifyV("TOP")
        fs:SetHeight(list.rowHeight - 4)
        fs:SetPoint("TOPLEFT", r, "TOPLEFT", col.x, -3)
      else
        fs:SetPoint("LEFT", r, "LEFT", col.x, 0)
      end
      r.cells[c] = fs
    end
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(16, 16)
    r.swatch = r:CreateTexture(nil, "ARTWORK")
    r.swatch:SetSize(14, 14)
    r.swatch:SetTexture(FLAT)
    r:SetScript("OnEnter", function(self)
      local d = self.data
      if not d then return end
      if d.link or d.itemID then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(d.link or ("item:" .. d.itemID))
        if d.extra then
          GameTooltip:AddLine(" ")
          for _, line2 in ipairs(d.extra) do GameTooltip:AddLine(line2, 1, 1, 1, true) end
        end
        GameTooltip:Show()
      elseif d.tip then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        for i2, line2 in ipairs(d.tip) do
          if i2 == 1 then GameTooltip:SetText(line2) else GameTooltip:AddLine(line2, 1, 1, 1, true) end
        end
        GameTooltip:Show()
      end
    end)
    r:SetScript("OnLeave", GameTooltip_Hide)
    r:SetScript("OnClick", function(self)
      if self.data and self.data.onClick then self.data.onClick(self.data) end
    end)
    r:SetScript("OnDoubleClick", function(self)
      if self.data and self.data.onDoubleClick then self.data.onDoubleClick(self.data) end
    end)
    return r
  end

  local TONES = {
    current = { 1, 0.82, 0, 0.08 }, top = { 1, 0.82, 0, 0.06 }, mile = { 0.64, 0.21, 0.93, 0.08 },
  }

  function list:SetData(data, emptyText)
    self.lastData, self.lastEmpty = data, emptyText
    if self.sortCol and data[1] and data[1].sort then
      local sorted = {}
      for i, d in ipairs(data) do sorted[i] = d end
      local col = self.sortCol
      W.SortRows(sorted, function(d) return d.sort and d.sort[col] end, self.sortAsc)
      data = sorted
    end
    for i, h in pairs(self.headers) do
      h:SetArrow(i == self.sortCol and (self.sortAsc and "asc" or "desc") or nil)
    end
    for i, d in ipairs(data) do
      local r = self.rows[i] or makeRow(i)
      self.rows[i] = r
      r.data = d
      for c, fs in ipairs(r.cells) do
        local col = self.cols[c]
        if col.bar then
          r.bars[c]:SetValue(d.cells[c])
          fs:SetText("")
        else
          fs:SetText(d.cells[c] or "")
        end
        local color = (d.colors and d.colors[c]) or (d.tone == "done" and W.C.muted) or W.C.ink
        fs:SetTextColor(color[1], color[2], color[3])
      end
      local ic = d.iconCol or 1
      local col = self.cols[ic]
      local fs = r.cells[ic]
      local anchor, yoff = col.wrap and "TOPLEFT" or "LEFT", col.wrap and -3 or 0
      -- Optional checkbox before the icon: d.check = true/false, d.onCheck(d, checked).
      local x0 = col.x
      if d.check ~= nil then
        if not r.check then
          r.check = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
          r.check:SetSize(20, 20)
          r.check:SetScript("OnClick", function(self)
            local rd = self:GetParent().data
            if rd and rd.onCheck then rd.onCheck(rd, self:GetChecked() and true or false) end
          end)
        end
        r.check:ClearAllPoints()
        r.check:SetPoint(anchor, r, anchor, col.x - 2, yoff)
        r.check:SetChecked(d.check)
        r.check:Show()
        x0 = col.x + 20
      elseif r.check then
        r.check:Hide()
      end
      local used = x0 - col.x
      if d.icon then
        r.icon:SetTexture(d.icon)
        r.icon:ClearAllPoints()
        r.icon:SetPoint(anchor, r, anchor, x0, yoff)
        r.icon:SetDesaturated(d.tone == "done")
        r.icon:Show()
        fs:ClearAllPoints()
        fs:SetPoint(anchor, r, anchor, x0 + 20, yoff)
        fs:SetWidth(col.width - used - 20)
      else
        r.icon:Hide()
        fs:ClearAllPoints()
        fs:SetPoint(anchor, r, anchor, x0, yoff)
        fs:SetWidth(col.width - used)
      end
      -- Optional color square before the text of another column (category colors).
      if d.swatch then
        local sc = self.cols[d.swatchCol]
        r.swatch:SetVertexColor(d.swatch[1], d.swatch[2], d.swatch[3], 1)
        r.swatch:ClearAllPoints()
        r.swatch:SetPoint("LEFT", r, "LEFT", sc.x, 0)
        r.swatch:Show()
        local sfs = r.cells[d.swatchCol]
        sfs:ClearAllPoints()
        sfs:SetPoint("LEFT", r, "LEFT", sc.x + 20, 0)
        sfs:SetWidth(sc.width - 20)
      else
        r.swatch:Hide()
      end
      local tone = TONES[d.tone]
      if tone then
        r.bg:SetVertexColor(tone[1], tone[2], tone[3], tone[4])
      else
        r.bg:SetVertexColor(1, 1, 1, i % 2 == 0 and 0.02 or 0)
      end
      r:Show()
    end
    for i = #data + 1, #self.rows do self.rows[i]:Hide() end
    child:SetHeight(math.max(1, #data * self.rowHeight))
    self.empty:SetText(#data == 0 and (emptyText or "") or "")
  end

  return list
end
