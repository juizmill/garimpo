local _, ns = ...
local L = ns.L

local ICON = "Interface\\Icons\\INV_Misc_Coin_01"
local button, dbicon, broker

local function topCategory()
  local rows = ns:RankCategories()
  return rows[1] and rows[1].gph and ns.T(rows[1].cat.name) or "-"
end

local function fillTooltip(tt)
  tt:AddLine("Garimpo", 1, 0.82, 0)
  tt:AddDoubleLine(L.STAT_GOLD, ns.Money(GetMoney(), true), 0.91, 0.88, 0.82, 1, 1, 1)
  tt:AddDoubleLine(L.STAT_RATE, (ns.SessionRate()), 0.91, 0.88, 0.82, 1, 1, 1)
  tt:AddDoubleLine(L.TOP_CATEGORY, topCategory(), 0.91, 0.88, 0.82, 1, 1, 1)
  tt:AddLine(" ")
  tt:AddLine(L.MINIMAP_HINT, 0.6, 0.56, 0.49)
end

local function onClick(_, mouse)
  if mouse == "RightButton" then ns:ShowMain("config") else ns:ToggleMain() end
end

-- Own button, used when no LibDBIcon is loaded.
local function place()
  local angle = math.rad(ns.db.settings.minimap.angle or 215)
  local r = (Minimap:GetWidth() / 2) + 5
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function createButton()
  button = CreateFrame("Button", "GarimpoMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local icon = button:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", 0, 1)
  icon:SetTexture(ICON)
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  button:SetScript("OnClick", onClick)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    fillTooltip(GameTooltip)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", GameTooltip_Hide)
  button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      ns.db.settings.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
      place()
    end)
  end)
  button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
end

function ns:UpdateMinimapButton()
  local hide = ns.db.settings.minimap.hide
  if dbicon then
    if hide then dbicon:Hide("Garimpo") else dbicon:Show("Garimpo") end
    return
  end
  if not button then createButton() end
  place()
  button:SetShown(not hide)
end

ns:On("READY", function()
  local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
  if ldb then
    broker = ldb:NewDataObject("Garimpo", {
      type = "data source",
      text = "Garimpo",
      icon = ICON,
      OnClick = onClick,
      OnTooltipShow = fillTooltip,
    })
    dbicon = LibStub("LibDBIcon-1.0", true)
    if dbicon and broker then
      -- LibDBIcon keeps its own position in minimap.minimapPos and reads minimap.hide.
      dbicon:Register("Garimpo", broker, ns.db.settings.minimap)
    else
      dbicon = nil
    end
  end
  ns:UpdateMinimapButton()

  if broker then
    local function update()
      broker.text = ns.Gold(GetMoney()) .. " | " .. (ns.SessionRate()) .. " | " .. topCategory()
    end
    update()
    C_Timer.NewTicker(30, update)
    ns:On("MONEY", update)
  end
end)
