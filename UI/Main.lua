local _, ns = ...
local L, W = ns.L, ns.W

ns.views = {}
ns.viewOrder = {}

local TABS = {
  { value = "ranking", key = "TAB_RANKING" },
  { value = "bags", key = "TAB_BAGS" },
  { value = "auctions", key = "TAB_AUCTIONS" },
  { value = "chart", key = "TAB_CHART" },
  { value = "professions", key = "TAB_PROFESSIONS" },
  { value = "config", key = "TAB_CONFIG" },
}

local main

-- builder(parent) returns a frame; the frame may define Refresh().
function ns:RegisterView(name, builder)
  ns.views[name] = { build = builder }
end

local function create()
  main = CreateFrame("Frame", "GarimpoMainFrame", UIParent, "BackdropTemplate")
  main:SetSize(640, 520)
  main:SetPoint("CENTER")
  main:SetBackdrop({ bgFile = W.FLAT, edgeFile = W.FLAT, edgeSize = 2 })
  main:SetBackdropColor(unpack(W.C.bg))
  main:SetBackdropBorderColor(unpack(W.C.edge))
  main:SetFrameStrata("HIGH")
  main:SetToplevel(true)   -- comes to the front when clicked, above the Auction House panel
  main:SetClampedToScreen(true)
  main:SetMovable(true)
  main:EnableMouse(true)
  main:RegisterForDrag("LeftButton")
  main:SetScript("OnDragStart", main.StartMoving)
  main:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint()
    ns.char.window = { point, rel, x, y }
  end)
  tinsert(UISpecialFrames, "GarimpoMainFrame")

  local pos = ns.char.window
  if pos and pos[1] then
    main:ClearAllPoints()
    main:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  end

  local icon = main:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetPoint("TOPLEFT", 12, -9)
  icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
  local title = W.Font(main, 16, W.C.gold)
  title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
  title:SetText("Garimpo")
  main.subtitle = W.Font(main, 12, W.C.muted)
  main.subtitle:SetPoint("LEFT", title, "RIGHT", 8, 0)

  local close = W.Close(main)
  close:SetPoint("TOPRIGHT", -6, -7)
  W.Window(main, 34)
  W.IconFrame(icon)
  W.FadeIn(main)

  main.tabs = W.Chips(main, function(v) ns:ShowView(v) end, "tab")
  main.tabs:SetPoint("TOPLEFT", 12, -38)
  main.tabs:SetItems(TABS)

  local line = W.Line(main)
  line:SetPoint("TOPLEFT", 12, -62)
  line:SetPoint("TOPRIGHT", -12, -62)

  main.content = CreateFrame("Frame", nil, main)
  main.content:SetPoint("TOPLEFT", 12, -70)
  main.content:SetPoint("BOTTOMRIGHT", -12, 12)
  main:Hide()
  return main
end

function ns:SetSubtitle(text)
  if main then main.subtitle:SetText(text or "") end
end

function ns:ShowView(name)
  main = main or create()
  for n, v in pairs(ns.views) do
    if v.frame and n ~= name then v.frame:Hide() end
  end
  local v = ns.views[name]
  if not v.frame then
    v.frame = v.build(main.content)
    v.frame:SetAllPoints(main.content)
    W.FadeIn(v.frame, 0.12)
  end
  main.current = name
  main.tabs:Select(name)
  ns:SetSubtitle("")
  v.frame:Show()
  if v.frame.Refresh then v.frame:Refresh() end
end

function ns:ShowMain(view)
  main = main or create()
  main:Show()
  main:Raise()
  ns:ShowView(view or main.current or "ranking")
end

function ns:ToggleMain()
  if main and main:IsShown() then
    main:Hide()
  else
    ns:ShowMain()
  end
end

function ns:ResetWindow()
  ns.char.window = {}
  ns.char.ahPanel = nil
  ns.char.ahPanelSize = nil
  if main then
    main:ClearAllPoints()
    main:SetPoint("CENTER")
  end
end

function ns:RefreshCurrent()
  if not (main and main:IsShown() and main.current) then return end
  local v = ns.views[main.current]
  if v.frame and v.frame.Refresh then v.frame:Refresh() end
end

local function refreshSoon()
  ns:Throttle("refresh", 0.3, function() ns:RefreshCurrent() end)
end

for _, msg in ipairs({ "PRICES", "BAGS", "MONEY", "SKILLS", "ITEMS" }) do
  ns:On(msg, refreshSoon)
end

function ns:ApplyLanguage()
  ns:SetLanguage(ns.db.settings.language)
  W.RelabelAll()
  ns:Fire("LANGUAGE")
  ns:RefreshCurrent()
end
