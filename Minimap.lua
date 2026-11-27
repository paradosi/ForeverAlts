---- Minimap — the round button on the minimap's edge
--
-- Drawn like LibDBIcon's (the same textures and geometry, as in FloLib's
-- FloLib_CreateMinimapButton) so it sits with other addons' buttons, but
-- without the library: Forever Alts ships none. Left-click toggles the window,
-- right-click opens the settings, drag moves it around the edge. Its place is
-- settings.minimapAngle (degrees), settings.minimap shows or hides it.

local _, ns = ...
local T = ns.T
local C = T.C

local button

local function Place()
    local angle = math.rad(ns.settings.minimapAngle or 200)
    local x, y = math.cos(angle), math.sin(angle)
    local w = Minimap:GetWidth() / 2 + 5
    local h = Minimap:GetHeight() / 2 + 5
    -- GetMinimapShape is not Blizzard's: minimap addons (FarmMode Forever's
    -- square shape among them) define it. A square map: ride the box's edge.
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape ~= "ROUND" then
        local d = math.max(math.abs(x), math.abs(y))
        x, y = x / d, y / d
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x * w, y * h)
end

local function OnUpdate()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    ns.settings.minimapAngle = math.floor(math.deg(math.atan2(py / scale - my, px / scale - mx)) % 360 + 0.5)
    Place()
end

function ns.UpdateMinimapButton()
    if not button then return end
    if ns.settings.minimap then
        Place()
        button:Show()
    else
        button:Hide()
    end
end

local function Create()
    button = CreateFrame("Button", "ForeverAltsMinimapButton", Minimap)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetSize(31, 31)
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture(136477)  -- Interface\Minimap\UI-Minimap-ZoomButton-Highlight

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture(136430)  -- Interface\Minimap\MiniMap-TrackingBorder
    overlay:SetPoint("TOPLEFT")
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetTexture(136467)  -- Interface\Minimap\UI-Minimap-Background
    background:SetPoint("TOPLEFT", 7, -5)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetTexture("Interface\\AddOns\\ForeverAlts\\media\\textures\\logo_64")
    icon:SetPoint("TOPLEFT", 7, -6)

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            ns.OpenOptions()
        else
            ns.ToggleUI()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        GameTooltip:Hide()
        self:SetScript("OnUpdate", OnUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Forever Alts", C.accent[1], C.accent[2], C.accent[3])
        GameTooltip:AddLine("Left-click: open or close the window", 1, 1, 1)
        GameTooltip:AddLine("Right-click: settings", 1, 1, 1)
        GameTooltip:AddLine("Drag: move this button", C.muted[1], C.muted[2], C.muted[3])
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    ns.UpdateMinimapButton()
end

ns:On("PLAYER_LOGIN", Create)
