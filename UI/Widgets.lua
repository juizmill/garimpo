local _, ns = ...
local L = ns.L

local W = {}
ns.W = W

local FLAT = "Interface\\Buttons\\WHITE8X8"
W.FLAT = FLAT

-- Palette of the interface mockups: aged gold edges on dark brown.
W.C = {
  bg     = { 0.09, 0.075, 0.059, 1 },     -- window inside
  bg2    = { 0.047, 0.039, 0.031, 1 },    -- boxes, inputs
  panel  = { 0.129, 0.106, 0.078, 1 },    -- active tab, header rows
  edge   = { 0.42, 0.333, 0.188, 1 },     -- aged gold border
  line   = { 0.227, 0.18, 0.11, 1 },      -- dividers
  row    = { 0.133, 0.106, 0.071, 1 },    -- line under each table row
  gold   = { 1, 0.82, 0 },
  ink    = { 0.91, 0.88, 0.82 },
  muted  = { 0.6, 0.56, 0.49 },
  up     = { 0.25, 0.82, 0.42 },
  down   = { 1, 0.35, 0.29 },
}

function W.Box(parent, bg, edge)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
  local b, e = bg or W.C.bg2, edge or { 0.184, 0.149, 0.094, 1 }
  f:SetBackdropColor(b[1], b[2], b[3], b[4] or 1)
  f:SetBackdropBorderColor(e[1], e[2], e[3], e[4] or 1)
  return f
end

function W.Font(parent, size, color, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(STANDARD_TEXT_FONT, size or 12, "")
  fs:SetShadowColor(0, 0, 0, 0.9)
  fs:SetShadowOffset(1, -1)
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

-- Colors move toward their target over a few frames instead of jumping.
local function mix(a, b, t)
  return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
end

-- Moves frame[field] toward goal (0..1), calling paint(frame) on each step.
local function animate(frame, field, goal, paint, speed)
  frame[field .. "Goal"] = goal
  frame:SetScript("OnUpdate", function(self, elapsed)
    local cur, g = self[field] or 0, self[field .. "Goal"]
    local step = elapsed * (speed or 10)
    cur = cur < g and math.min(g, cur + step) or math.max(g, cur - step)
    self[field] = cur
    paint(self)
    if cur == g then self:SetScript("OnUpdate", nil) end
  end)
end
W.Animate = animate

-- Gradient on a texture from color `from` (bottom or left) to `to` (top or right),
-- { r, g, b, a } each; new and old client APIs.
function W.Gradient(tex, orientation, from, to)
  tex:SetTexture(FLAT)
  local a1, a2 = from[4] or 1, to[4] or 1
  if CreateColor and pcall(tex.SetGradient, tex, orientation,
    CreateColor(from[1], from[2], from[3], a1), CreateColor(to[1], to[2], to[3], a2)) then return end
  if tex.SetGradientAlpha then
    tex:SetGradientAlpha(orientation, from[1], from[2], from[3], a1, to[1], to[2], to[3], a2)
  end
end

local function mixColor(a, b, t)
  local r, g, bl = mix(a, b, t)
  return { r, g, bl, 1 }
end

local BUTTON_STYLES = {
  normal = {
    top = { 0.227, 0.188, 0.141 }, bottom = { 0.129, 0.102, 0.071 },
    topHover = { 0.31, 0.255, 0.18 }, bottomHover = { 0.18, 0.14, 0.094 },
    text = { 1, 0.82, 0 }, textHover = { 1, 0.9, 0.45 },
  },
  primary = {
    top = { 0.545, 0.102, 0.063 }, bottom = { 0.302, 0.043, 0.024 },
    topHover = { 0.67, 0.15, 0.09 }, bottomHover = { 0.4, 0.06, 0.035 },
    text = { 1, 0.82, 0 }, textHover = { 1, 0.93, 0.6 },
  },
  danger = {
    top = { 0.227, 0.188, 0.141 }, bottom = { 0.129, 0.102, 0.071 },
    topHover = { 0.545, 0.102, 0.063 }, bottomHover = { 0.302, 0.043, 0.024 },
    text = { 1, 0.82, 0 }, textHover = { 1, 0.93, 0.6 },
  },
}

local function paintButton(b)
  local st = BUTTON_STYLES[b.style] or BUTTON_STYLES.normal
  if not b:IsEnabled() then
    W.Gradient(b.fill, "VERTICAL", { 0.07, 0.06, 0.045 }, { 0.11, 0.09, 0.07 })
    b.text:SetTextColor(W.C.muted[1], W.C.muted[2], W.C.muted[3], 0.6)
    b.shine:SetAlpha(0.05)
    return
  end
  local t = b.hover or 0
  W.Gradient(b.fill, "VERTICAL", mixColor(st.bottom, st.bottomHover, t), mixColor(st.top, st.topHover, t))
  local r, g, bl = mix(st.text, st.textHover, t)
  b.text:SetTextColor(r, g, bl, 1)
  b.shine:SetAlpha(0.2)
end

-- Button of the mockups: gradient with gold text and a black edge. style: "normal"
-- (brown, default), "primary" (red, the main action of a screen) or "danger" (brown,
-- turns red on hover). Callers that add tooltips use HookScript so the hover effect
-- keeps working.
function W.Button(parent, key, width, onClick, style)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(width or 110, 22)
  b:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
  b:SetBackdropColor(0, 0, 0, 1)
  b:SetBackdropBorderColor(0, 0, 0, 1)
  b.style = style or "normal"
  b.fill = b:CreateTexture(nil, "BACKGROUND", nil, 1)
  b.fill:SetPoint("TOPLEFT", 1, -1)
  b.fill:SetPoint("BOTTOMRIGHT", -1, 1)
  -- Thin light line along the top edge.
  b.shine = b:CreateTexture(nil, "ARTWORK")
  b.shine:SetTexture(FLAT)
  b.shine:SetVertexColor(1, 1, 1, 1)
  b.shine:SetPoint("TOPLEFT", 1, -1)
  b.shine:SetPoint("TOPRIGHT", -1, -1)
  b.shine:SetHeight(1)
  b.text = W.Font(b, 12, W.C.gold, "CENTER")
  b.text:SetPoint("LEFT", 4, 0)
  b.text:SetPoint("RIGHT", -4, 0)
  b:SetFontString(b.text)
  b:SetPushedTextOffset(0, -1)
  if key then W.Label(b, key) end
  if onClick then b:SetScript("OnClick", onClick) end
  b:SetScript("OnEnter", function(self) animate(self, "hover", 1, paintButton, 8) end)
  b:SetScript("OnLeave", function(self) animate(self, "hover", 0, paintButton, 5) end)
  b:SetScript("OnEnable", paintButton)
  b:SetScript("OnDisable", paintButton)
  function b:SetStyle(name)
    self.style = name
    paintButton(self)
  end
  paintButton(b)
  return b
end

-- Close button of the mockups: small red square with a light x.
function W.Close(parent, onClick)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(18, 18)
  b:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
  local lines = {}
  for i, angle in ipairs({ math.pi / 4, -math.pi / 4 }) do
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetTexture(FLAT)
    t:SetSize(10, 1.5)
    t:SetPoint("CENTER")
    t:SetRotation(angle)
    lines[i] = t
  end
  local function paint(self)
    local h = self.hover or 0
    self:SetBackdropColor(mix({ 0.36, 0.063, 0.063 }, { 0.6, 0.1, 0.08 }, h))
    self:SetBackdropBorderColor(mix({ 0.64, 0.2, 0.2 }, { 1, 0.4, 0.35 }, h))
    for _, t in ipairs(lines) do t:SetVertexColor(1, 0.87, 0.87, 1) end
  end
  b:SetScript("OnEnter", function(self) animate(self, "hover", 1, paint, 8) end)
  b:SetScript("OnLeave", function(self) animate(self, "hover", 0, paint, 5) end)
  b:SetScript("OnClick", onClick or function() parent:Hide() end)
  paint(b)
  return b
end

-- Fades the frame in each time it is shown.
function W.FadeIn(frame, duration)
  local ag = frame:CreateAnimationGroup()
  local a = ag:CreateAnimation("Alpha")
  a:SetFromAlpha(0)
  a:SetToAlpha(1)
  a:SetDuration(duration or 0.15)
  if a.SetSmoothing then a:SetSmoothing("OUT") end
  frame:HookScript("OnShow", function() ag:Stop(); ag:Play() end)
  return ag
end

-- Window look of the mockups: dark inside with a slightly lighter top, 2px aged gold
-- border, and a title bar of `height` pixels with a black line under it.
function W.Window(frame, height)
  frame:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 2 })
  frame:SetBackdropColor(W.C.bg[1], W.C.bg[2], W.C.bg[3], 1)
  frame:SetBackdropBorderColor(W.C.edge[1], W.C.edge[2], W.C.edge[3], 1)
  local glow = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
  glow:SetPoint("TOPLEFT", 2, -2)
  glow:SetPoint("BOTTOMRIGHT", -2, 2)
  W.Gradient(glow, "VERTICAL", W.C.bg, { 0.11, 0.09, 0.07, 1 })
  local bar = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
  bar:SetPoint("TOPLEFT", 2, -2)
  bar:SetPoint("TOPRIGHT", -2, -2)
  bar:SetHeight(height - 2)
  W.Gradient(bar, "VERTICAL", { 0.102, 0.082, 0.055, 1 }, { 0.18, 0.145, 0.086, 1 })
  local line = frame:CreateTexture(nil, "BACKGROUND", nil, 3)
  line:SetTexture(FLAT)
  line:SetVertexColor(0, 0, 0, 1)
  line:SetPoint("TOPLEFT", bar, "BOTTOMLEFT")
  line:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT")
  line:SetHeight(1)
  -- Thin black line outside the gold border.
  local shadow = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  shadow:SetPoint("TOPLEFT", -1, 1)
  shadow:SetPoint("BOTTOMRIGHT", 1, -1)
  shadow:SetBackdrop({ edgeFile = FLAT, edgeSize = 1 })
  shadow:SetBackdropBorderColor(0, 0, 0, 1)
end

-- Gold-edged frame around a window's title icon.
function W.IconFrame(icon)
  local parent = icon:GetParent()
  local t = parent:CreateTexture(nil, "BORDER")
  t:SetTexture(FLAT)
  t:SetVertexColor(W.C.edge[1], W.C.edge[2], W.C.edge[3], 1)
  t:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
  t:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  return t
end

-- Small header + value box used in summary rows.
function W.Stat(parent, key, width)
  local box = W.Box(parent)
  box:SetSize(width or 170, 38)
  box.label = W.Font(box, 10, W.C.muted)
  box.label:SetPoint("TOPLEFT", 8, -6)
  W.Label(box.label, key)
  box.value = W.Font(box, 14, W.C.ink)
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

  -- Off: dark with a muted label; hover: lighter label and gold edge; on: gold label.
  local OFF = { 0.071, 0.059, 0.043 }
  local function styleButton(b)
    local on = b.value == g.value
    local hover = on and 1 or (b.hover or 0)
    b.text:SetTextColor(mix(W.C.muted, on and W.C.gold or W.C.ink, hover))
    b:SetBackdropColor(mix(OFF, W.C.panel, on and 1 or 0))
    b:SetBackdropBorderColor(mix(W.C.line, W.C.edge, style == "tab" and (on and 0.4 or 0) or hover))
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
        b:SetScript("OnEnter", function(btn) animate(btn, "hover", 1, styleButton, 8) end)
        b:SetScript("OnLeave", function(btn) animate(btn, "hover", 0, styleButton, 5) end)
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
      if i <= #self.items then styleButton(b) end
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

local function paintEdit(e)
  local enabled = e:IsEnabled()
  local edge = e:HasFocus() and W.C.gold or (e.hover and W.C.edge or W.C.line)
  e:SetBackdropColor(W.C.bg2[1], W.C.bg2[2], W.C.bg2[3], 1)
  e:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
  e:SetAlpha(enabled and 1 or 0.5)
end

function W.Edit(parent, width, onChange)
  local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  e:SetSize(width or 50, 20)
  e:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
  e:SetFont(STANDARD_TEXT_FONT, 12, "")
  e:SetTextColor(W.C.ink[1], W.C.ink[2], W.C.ink[3])
  e:SetTextInsets(5, 5, 0, 0)
  e:SetAutoFocus(false)
  e:SetJustifyH("RIGHT")
  e:SetScript("OnEnterPressed", e.ClearFocus)
  e:SetScript("OnEscapePressed", e.ClearFocus)
  e:SetScript("OnTextChanged", function(self, userInput)
    if userInput and onChange then onChange(self:GetText()) end
  end)
  e:SetScript("OnEditFocusGained", function(self) self:HighlightText(); paintEdit(self) end)
  e:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0); paintEdit(self) end)
  e:SetScript("OnEnter", function(self) self.hover = true; paintEdit(self) end)
  e:SetScript("OnLeave", function(self) self.hover = nil; paintEdit(self) end)
  local setEnabled = e.SetEnabled
  function e:SetEnabled(on)
    setEnabled(self, on)
    paintEdit(self)
  end
  paintEdit(e)
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

local function paintCheck(c)
  local edge = c.hover and W.C.gold or W.C.edge
  c:SetBackdropColor(W.C.bg2[1], W.C.bg2[2], W.C.bg2[3], 1)
  c:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
end

-- Checkbox of the mockups: a small square that fills with gold. onClick(checked) runs on
-- the player's click.
function W.CheckBox(parent, onClick)
  local c = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
  c:SetSize(14, 14)
  c:SetHitRectInsets(-4, -4, -4, -4)
  c:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
  local fill = c:CreateTexture(nil, "ARTWORK")
  fill:SetTexture(FLAT)
  fill:SetVertexColor(1, 0.82, 0, 1)
  fill:SetPoint("TOPLEFT", 3, -3)
  fill:SetPoint("BOTTOMRIGHT", -3, 3)
  c:SetCheckedTexture(fill)
  c:SetScript("OnEnter", function(self) self.hover = true; paintCheck(self) end)
  c:SetScript("OnLeave", function(self) self.hover = nil; paintCheck(self) end)
  c:SetScript("OnClick", function(self)
    if onClick then onClick(self:GetChecked() and true or false) end
  end)
  paintCheck(c)
  return c
end

-- Checkbox with a label; clicking the label toggles it too.
function W.Check(parent, key, onClick)
  local c = W.CheckBox(parent, onClick)
  c.label = W.Font(c, 12, W.C.ink)
  c.label:SetPoint("LEFT", c, "RIGHT", 6, 0)
  W.Label(c.label, key)
  local function fitHit()
    c:SetHitRectInsets(-3, -(c.label:GetStringWidth() + 9), -3, -3)
  end
  fitHit()
  W.OnRelabel(fitHit)
  return c
end

-- Scroll frame with a slim bar and smooth mouse-wheel scrolling. Anchor it like the
-- game's scroll frame: the bar sits in the 24 pixels to its right.
function W.Scroll(parent)
  local sf = CreateFrame("ScrollFrame", nil, parent)
  sf:EnableMouseWheel(true)
  local bar = CreateFrame("Slider", nil, sf)
  bar:SetPoint("TOPLEFT", sf, "TOPRIGHT", 9, 0)
  bar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 9, 0)
  bar:SetWidth(7)
  bar:SetOrientation("VERTICAL")
  bar:SetMinMaxValues(0, 0)
  bar:SetValue(0)
  local track = bar:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints()
  track:SetTexture(FLAT)
  track:SetVertexColor(W.C.bg2[1], W.C.bg2[2], W.C.bg2[3], 1)
  local thumb = bar:CreateTexture(nil, "ARTWORK")
  thumb:SetTexture(FLAT)
  thumb:SetSize(7, 30)
  bar:SetThumbTexture(thumb)
  local function paintThumb(self)
    local r, g, b = mix(W.C.edge, { 0.85, 0.68, 0.2 }, self.hover or 0)
    thumb:SetVertexColor(r, g, b, 1)
  end
  bar:SetScript("OnEnter", function(self) animate(self, "hover", 1, paintThumb, 8) end)
  bar:SetScript("OnLeave", function(self) animate(self, "hover", 0, paintThumb, 5) end)
  paintThumb(bar)
  bar:Hide()
  sf.bar = bar

  local syncing = false
  bar:SetScript("OnValueChanged", function(_, v)
    if syncing then return end
    sf.target = nil
    sf:SetScript("OnUpdate", nil)
    sf:SetVerticalScroll(v)
  end)
  sf:SetScript("OnVerticalScroll", function(_, offset)
    syncing = true
    bar:SetValue(offset)
    syncing = false
  end)
  sf:SetScript("OnScrollRangeChanged", function(self, _, yrange)
    yrange = math.max(0, yrange or self:GetVerticalScrollRange())
    bar:SetMinMaxValues(0, yrange)
    local h = self:GetHeight()
    thumb:SetHeight(math.max(24, h > 0 and h * h / (h + yrange) or 24))
    bar:SetShown(yrange > 0.5)
    if self.target and self.target > yrange then self.target = yrange end
    if self:GetVerticalScroll() > yrange then self:SetVerticalScroll(yrange) end
  end)
  local function glide(self, elapsed)
    local cur, goal = self:GetVerticalScroll(), self.target or 0
    local nv = cur + (goal - cur) * math.min(1, elapsed * 14)
    if math.abs(goal - nv) < 0.5 then
      nv = goal
      self.target = nil
      self:SetScript("OnUpdate", nil)
    end
    self:SetVerticalScroll(nv)
  end
  sf:SetScript("OnMouseWheel", function(self, delta)
    local range = self:GetVerticalScrollRange()
    if range <= 0 then return end
    local goal = (self.target or self:GetVerticalScroll()) - delta * 60
    self.target = math.max(0, math.min(range, goal))
    self:SetScript("OnUpdate", glide)
  end)
  return sf
end

function W.Bar(parent, width, height, color)
  local bar = W.Box(parent, { 0.043, 0.035, 0.027, 1 }, { 0.173, 0.141, 0.086, 1 })
  bar:SetSize(width, height)
  local fill = bar:CreateTexture(nil, "ARTWORK")
  fill:SetTexture(FLAT)
  fill:SetPoint("TOPLEFT", 1, -1)
  fill:SetPoint("BOTTOMLEFT", 1, 1)
  local c = color or W.C.gold
  local dark = color and { c[1] * 0.35, c[2] * 0.35, c[3] * 0.35, 1 } or { 0.54, 0.416, 0.07, 1 }
  W.Gradient(fill, "HORIZONTAL", dark, { c[1], c[2], c[3], 1 })
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

  local sf = W.Scroll(list)
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
    local sep = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    sep:SetTexture(FLAT)
    sep:SetVertexColor(W.C.row[1], W.C.row[2], W.C.row[3], 1)
    sep:SetPoint("BOTTOMLEFT")
    sep:SetPoint("BOTTOMRIGHT")
    sep:SetHeight(1)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture(FLAT)
    hl:SetVertexColor(1, 0.82, 0, 0.06)
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
          r.check = W.CheckBox(r)
          r.check:HookScript("OnClick", function(self)
            local rd = self:GetParent().data
            if rd and rd.onCheck then rd.onCheck(rd, self:GetChecked() and true or false) end
          end)
        end
        r.check:ClearAllPoints()
        r.check:SetPoint(anchor, r, anchor, col.x, col.wrap and -5 or 0)
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
