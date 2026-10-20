local _, ns = ...
local L, W = ns.L, ns.W

-- Navigation: a waypoint per farming zone, an on-screen arrow and world map pins.
-- The game doesn't expose where nodes are, so Garimpo records the spots where the
-- player gathers farmable items and points to the busiest recorded spot.

local ARROW = "Interface\\AddOns\\Garimpo\\Media\\Arrow"
local SKIP_CATEGORY = { transmog = true, enchanting = true }
local arrow
local pins, pinCount = {}, 0

local function playerSpot()
  local map = C_Map.GetBestMapForUnit("player")
  if not map then return nil end
  local pos = C_Map.GetPlayerMapPosition(map, "player")
  if not pos then return nil end
  local x, y = pos:GetXY()
  if x == 0 and y == 0 then return nil end
  return map, x, y
end

local function worldPos(map, x, y)
  if not (C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
  local continent, pos = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(x, y))
  if not pos then return nil end
  local a, b = pos:GetXY()
  return continent, a, b
end

-- Recording ------------------------------------------------------------------------

function ns:RecordNode(id)
  local cat = self:CategoryOf(id)
  local r = ns.Reagents[id]
  if not ((cat and not SKIP_CATEGORY[cat]) or (r and r.farm)) then return end
  local map, x, y = playerSpot()
  if not map then return end
  local byMap = self.db.nodes[map] or {}
  self.db.nodes[map] = byMap
  local list = byMap[id] or {}
  byMap[id] = list
  for _, p in ipairs(list) do
    if math.abs(p[1] - x) < 0.004 and math.abs(p[2] - y) < 0.004 then return end
  end
  if #list >= 300 then table.remove(list, 1) end
  list[#list + 1] = { math.floor(x * 1000 + 0.5) / 1000, math.floor(y * 1000 + 0.5) / 1000 }
end

-- Raw farmable items behind a reagent (Bronze Bar -> Copper Ore, Tin Ore).
function ns:RawItems(id, out, depth)
  out = out or {}
  local r = ns.Reagents[id]
  if r and r.make and (depth or 0) < 3 then
    for _, input in ipairs(r.make.inputs) do self:RawItems(input[1], out, (depth or 0) + 1) end
  elseif type(id) == "number" then
    out[#out + 1] = id
  end
  return out
end

function ns:SpotsIn(map, items)
  local pts = {}
  local byMap = self.db.nodes[map]
  if byMap then
    for _, id in ipairs(items or {}) do
      for _, p in ipairs(byMap[id] or {}) do pts[#pts + 1] = p end
    end
  end
  return pts
end

-- Stones and crystals come from the same veins as the ore.
local NODE_ALIAS = { [2835] = 2770, [2836] = 2771, [2838] = 2772, [7912] = 3858, [12365] = 10620, [12363] = 10620 }

-- Wowhead spawn data for the given items in a map: the entry with the most nodes.
function ns:NodeEntry(map, items)
  if not ns.NodeData then return nil end
  local best
  for _, id in ipairs(items or {}) do
    local data = ns.NodeData[NODE_ALIAS[id] or id]
    local e = data and data[map]
    if e and (not best or e[3] > best[3]) then best = e end
  end
  return best
end

-- Where to send the player in a zone. Returns x, y (0-1) and the source:
-- "own" (5+ of your gathering spots), "data" (Wowhead hotspot) or "center".
function ns:BestSpot(map, items)
  local pts = self:SpotsIn(map, items)
  if #pts >= 5 then
    local best, bestN = pts[1], -1
    for _, a in ipairs(pts) do
      local n = 0
      for _, b in ipairs(pts) do
        if (a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 < 0.0025 then n = n + 1 end
      end
      if n > bestN then best, bestN = a, n end
    end
    return best[1], best[2], "own"
  end
  local e = self:NodeEntry(map, items)
  if e then return e[1] / 100, e[2] / 100, "data" end
  if #pts > 0 then return pts[1][1], pts[1][2], "own" end
  return 0.5, 0.5, "center"
end

-- Continent of a map (cities and zones walk up to their continent).
function ns.ContinentOf(map)
  local info = map and C_Map.GetMapInfo(map)
  local continentType = Enum.UIMapType and Enum.UIMapType.Continent or 2
  while info and info.mapType and info.mapType > continentType and info.parentMapID and info.parentMapID > 0 do
    info = C_Map.GetMapInfo(info.parentMapID)
  end
  if info then return info.mapID, info.name end
  return nil
end

function ns.PlayerContinent()
  return ns.ContinentOf(C_Map.GetBestMapForUnit("player"))
end

-- Best zone to send the player to: their faction and their continent first.
-- Accepts { mapID, level, faction } entries or plain mapIDs.
function ns:FirstZone(zones)
  local faction, here = ns.PlayerFaction(), ns.PlayerContinent()
  local bestScore, best = -1, nil
  for _, z in ipairs(zones or {}) do
    local map = type(z) == "table" and z[1] or z
    local okFaction = type(z) ~= "table" or z[3] == "B" or z[3] == faction
    local score = (okFaction and 2 or 0) + ((here and ns.ContinentOf(map) == here) and 1 or 0)
    if score > bestScore then bestScore, best = score, map end
  end
  return best
end

-- Yards from the player to a map point, or nil when it is on another continent.
function ns:DistanceTo(map, x, y)
  local pmap, px, py = playerSpot()
  if not pmap then return nil end
  local c1, ax, ay = worldPos(pmap, px, py)
  local c2, bx, by = worldPos(map, x, y)
  if not (c1 and c2) or c1 ~= c2 then return nil end
  return math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
end

-- Vendors of an item that serve the player's faction, nearest first.
function ns:VendorSpots(id)
  local v = ns.Vendors and ns.Vendors[id]
  if not v then return {} end
  local horde = ns.PlayerFaction() == "H"
  local list = {}
  for _, s in ipairs(v.spots) do
    if (horde and s[5]) or (not horde and s[4]) then
      local x, y = s[2] / 100, s[3] / 100
      list[#list + 1] = { map = s[1], x = x, y = y, name = s[6], dist = self:DistanceTo(s[1], x, y) }
    end
  end
  table.sort(list, function(a, b)
    if a.dist and b.dist then return a.dist < b.dist end
    if a.dist or b.dist then return a.dist ~= nil end
    return ns.ZoneName(a.map) < ns.ZoneName(b.map)
  end)
  return list
end

-- Waypoint ---------------------------------------------------------------------------

local function openMap(map)
  if InCombatLockdown() or not WorldMapFrame then return end
  if OpenWorldMap then
    pcall(OpenWorldMap, map)
  else
    if not WorldMapFrame:IsShown() then pcall(ShowUIPanel, WorldMapFrame) end
    pcall(WorldMapFrame.SetMapID, WorldMapFrame, map)
  end
end

local function setNative(map, x, y)
  if not ns.db.settings.waypoint.native then return end
  if not (C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then return end
  pcall(function()
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x, y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
      C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
  end)
end

-- x and y given: an exact point (a vendor). Otherwise the best recorded farming spot.
function ns:SetWaypoint(map, items, title, x, y)
  if not map then return end
  local source
  if x and y then source = "vendor" else x, y, source = self:BestSpot(map, items) end
  self.waypoint = { map = map, x = x, y = y, title = title, items = items, source = source }
  ns.char.waypoint = self.waypoint   -- kept across /reload and logins until removed
  setNative(map, x, y)
  local zone = ns.ZoneName(map)
  if source == "vendor" then
    ns.Print(L.WAYPOINT_VENDOR:format(title or zone, zone, x * 100, y * 100))
  elseif source == "own" then
    ns.Print(L.WAYPOINT_SET:format(title or zone, zone, x * 100, y * 100))
  elseif source == "data" then
    ns.Print(L.WAYPOINT_DATA:format(title or zone, zone, x * 100, y * 100))
  else
    ns.Print(L.WAYPOINT_APPROX:format(title or zone, zone))
  end
  self:ShowArrow()
  openMap(map)
  self:RefreshMapPins()
end

function ns:ClearWaypoint()
  self.waypoint = nil
  ns.char.waypoint = nil
  if arrow then arrow:Hide() end
  if C_Map.ClearUserWaypoint and ns.db.settings.waypoint.native then pcall(C_Map.ClearUserWaypoint) end
  self:RefreshMapPins()
end

-- Arrow ------------------------------------------------------------------------------

local function updateArrow(self, elapsed)
  self.t = (self.t or 0) + elapsed
  if self.t < 0.05 then return end
  self.t = 0
  local wp = ns.waypoint
  if not wp then self:Hide(); return end
  local pmap, px, py = playerSpot()
  local facing = GetPlayerFacing and GetPlayerFacing()
  local c1, ax, ay
  if pmap then c1, ax, ay = worldPos(pmap, px, py) end
  local c2, bx, by = worldPos(wp.map, wp.x, wp.y)
  if not (c1 and c2 and facing) or c1 ~= c2 then
    -- Can't point across continents: show the arrow greyed out and where to go.
    self.tex:SetRotation(0)
    self.tex:SetDesaturated(true)
    self.tex:SetAlpha(0.4)
    self.tex:Show()
    local _, continent = ns.ContinentOf(wp.map)
    self.dist:SetText(L.ARROW_FAR:format(continent or ns.ZoneName(wp.map)))
    return
  end
  self.tex:SetDesaturated(false)
  self.tex:SetAlpha(1)
  -- Split the world offset into east and south using the player's map axes,
  -- so the result doesn't depend on how world coordinates are oriented.
  local _, ox, oy = worldPos(pmap, 0, 0)
  local _, ex, ey = worldPos(pmap, 1, 0)
  local _, sx, sy = worldPos(pmap, 0, 1)
  local dx, dy = bx - ax, by - ay
  local evx, evy, svx, svy = ex - ox, ey - oy, sx - ox, sy - oy
  local elen, slen = math.sqrt(evx * evx + evy * evy), math.sqrt(svx * svx + svy * svy)
  if elen == 0 or slen == 0 then return end
  local east = (dx * evx + dy * evy) / elen
  local south = (dx * svx + dy * svy) / slen
  local dist = math.sqrt(dx * dx + dy * dy)
  -- Arriving doesn't remove the arrow; only the right-click menu does.
  if dist < 15 then
    if not wp.arrived then
      wp.arrived = true
      ns.Print(L.ARROW_ARRIVED:format(wp.title or ns.ZoneName(wp.map)))
    end
  elseif dist > 40 then
    wp.arrived = nil
  end
  -- Facing is 0 at north and grows counter-clockwise, like this angle.
  local bearing = math.atan2(-east, -south)
  self.tex:SetRotation(bearing - facing)
  self.tex:Show()
  self.dist:SetText(wp.arrived and ns.Color("up", L.ARROW_HERE) or L.YARDS:format(ns.Num(dist)))
end

local function arrowMenu(owner)
  if MenuUtil and MenuUtil.CreateContextMenu then
    MenuUtil.CreateContextMenu(owner, function(_, root)
      root:CreateTitle("Garimpo")
      root:CreateButton(L.REMOVE_ARROW, function() ns:ClearWaypoint() end)
    end)
  else
    ns:ClearWaypoint()
  end
end

function ns:ShowArrow()
  if not ns.db.settings.waypoint.arrow then return end
  if not arrow then
    arrow = CreateFrame("Button", "GarimpoArrow", UIParent)
    arrow:SetSize(150, 104)
    arrow:SetFrameStrata("HIGH")
    arrow:SetClampedToScreen(true)
    arrow:SetMovable(true)
    arrow:EnableMouse(true)
    arrow:RegisterForDrag("LeftButton")
    arrow:RegisterForClicks("RightButtonUp")
    arrow:SetScript("OnDragStart", arrow.StartMoving)
    arrow:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local point, _, rel, x, y = self:GetPoint()
      ns.char.arrowPos = { point, rel, x, y }
    end)
    arrow:SetScript("OnClick", function(self) arrowMenu(self) end)
    arrow:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:SetText("Garimpo", 1, 0.82, 0)
      local wp = ns.waypoint
      if wp then
        GameTooltip:AddLine(ns.ZoneName(wp.map) .. string.format(" %.1f, %.1f", wp.x * 100, wp.y * 100), 1, 1, 1)
        local notes = { vendor = L.ARROW_VENDOR, own = L.ARROW_EXACT, data = L.ARROW_DATA }
        local note = notes[wp.source] or (wp.exact and L.ARROW_EXACT) or L.ARROW_APPROX
        GameTooltip:AddLine(note, 0.6, 0.56, 0.49, true)
      end
      GameTooltip:AddLine(L.ARROW_HINT, 0.6, 0.56, 0.49, true)
      GameTooltip:Show()
    end)
    arrow:SetScript("OnLeave", GameTooltip_Hide)
    arrow.tex = arrow:CreateTexture(nil, "ARTWORK")
    arrow.tex:SetSize(56, 56)
    arrow.tex:SetPoint("TOP", 0, 0)
    arrow.tex:SetTexture(ARROW)
    arrow.title = W.Font(arrow, 12, W.C.gold, "CENTER")
    arrow.title:SetPoint("TOP", arrow.tex, "BOTTOM", 0, -2)
    arrow.title:SetWidth(150)
    arrow.dist = W.Font(arrow, 12, W.C.ink, "CENTER")
    arrow.dist:SetPoint("TOP", arrow.title, "BOTTOM", 0, -2)
    arrow.dist:SetWidth(200)
    arrow.dist:SetWordWrap(true)
    arrow:SetScript("OnUpdate", updateArrow)
  end
  local pos = ns.char.arrowPos
  arrow:ClearAllPoints()
  if pos and pos[1] then
    arrow:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  else
    arrow:SetPoint("TOP", UIParent, "TOP", 0, -140)
  end
  local wp = self.waypoint
  arrow.title:SetText(wp and (wp.title or ns.ZoneName(wp.map)) or "")
  arrow.dist:SetText("")
  arrow:Show()
end

-- World map pins ---------------------------------------------------------------------

local function canvas()
  return WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end

-- kind: "target" (coin), "own" (gold square) or "data" (small pale square).
local function takePin(parent, kind)
  pinCount = pinCount + 1
  local pin = pins[pinCount]
  if not pin then
    pin = CreateFrame("Frame", nil, parent)
    pin.tex = pin:CreateTexture(nil, "OVERLAY")
    pin.tex:SetAllPoints()
    pins[pinCount] = pin
  end
  pin:SetParent(parent)
  pin:SetFrameLevel(parent:GetFrameLevel() + 2000)
  local size = (kind == "target" and 22 or (kind == "own" and 9 or 7)) / math.max(parent:GetScale(), 0.01)
  pin:SetSize(size, size)
  if kind == "target" then
    pin.tex:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    pin.tex:SetVertexColor(1, 1, 1, 1)
  elseif kind == "own" then
    pin.tex:SetTexture(W.FLAT)
    pin.tex:SetVertexColor(1, 0.82, 0, 0.85)
  else
    pin.tex:SetTexture(W.FLAT)
    pin.tex:SetVertexColor(0.85, 0.9, 1, 0.55)
  end
  pin:Show()
  return pin
end

function ns:RefreshMapPins()
  for i = 1, #pins do pins[i]:Hide() end
  pinCount = 0
  local wp = self.waypoint
  local c = canvas()
  if not (wp and c and WorldMapFrame:IsShown()) then return end
  if WorldMapFrame:GetMapID() ~= wp.map then return end
  local w, h = c:GetSize()
  -- Wowhead spawn points (already thinned to a few dozen per zone).
  local e = self:NodeEntry(wp.map, wp.items)
  if e then
    local flat = e[4]
    for i = 1, #flat - 1, 2 do
      local pin = takePin(c, "data")
      pin:ClearAllPoints()
      pin:SetPoint("CENTER", c, "TOPLEFT", flat[i] / 100 * w, -flat[i + 1] / 100 * h)
    end
  end
  for _, p in ipairs(self:SpotsIn(wp.map, wp.items)) do
    local pin = takePin(c, "own")
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", c, "TOPLEFT", p[1] * w, -p[2] * h)
  end
  local target = takePin(c, "target")
  target:ClearAllPoints()
  target:SetPoint("CENTER", c, "TOPLEFT", wp.x * w, -wp.y * h)
end

ns:On("READY", function()
  -- Bring back the arrow saved before /reload or logout.
  local saved = ns.char.waypoint
  if saved and saved.map then
    ns.waypoint = saved
    saved.arrived = nil
    setNative(saved.map, saved.x, saved.y)
    ns:ShowArrow()
  end
  if WorldMapFrame then
    WorldMapFrame:HookScript("OnShow", function() ns:RefreshMapPins() end)
    if WorldMapFrame.OnMapChanged then
      hooksecurefunc(WorldMapFrame, "OnMapChanged", function() ns:RefreshMapPins() end)
    end
  end
end)
