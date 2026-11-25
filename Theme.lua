---- Theme — wowdb.dev's look: navy surfaces, hairline borders, a gold accent,
---- Oswald for labels and JetBrains Mono for numbers (both SIL OFL, media/fonts)

local addonName, ns = ...

local FONTS = "Interface\\AddOns\\" .. addonName .. "\\media\\fonts\\"

local T = {
    display      = FONTS .. "Oswald-Regular.ttf",
    displayLight = FONTS .. "Oswald-Light.ttf",
    mono         = FONTS .. "JetBrainsMono-Regular.ttf",
    monoMedium   = FONTS .. "JetBrainsMono-Medium.ttf",
}
ns.T = T

-- wowdb's tokens (apps/web/app/globals.css)
local C = {
    bg        = { 0.086, 0.106, 0.161, 0.97 },  -- --bg #161b29
    deep      = { 0.063, 0.075, 0.114, 1 },     -- --bg-deep #10131d
    raised    = { 1, 1, 1, 0.035 },             -- a row under the cursor, a field
    border    = { 1, 1, 1, 0.10 },              -- --border
    divider   = { 1, 1, 1, 0.06 },              -- --divider
    primary   = { 0.961, 0.969, 0.988 },        -- --text-primary #f5f7fc
    secondary = { 0.761, 0.784, 0.855 },        -- --text-secondary #c2c8da
    muted     = { 0.588, 0.616, 0.702 },        -- --text-muted #969db3
    accent    = { 0.890, 0.714, 0.392 },        -- --accent #e3b664
    accentHi  = { 0.953, 0.835, 0.584 },        -- --accent-hi #f3d595
    chip      = { 0.890, 0.714, 0.392, 0.16 },  -- --chip-accent
    track     = { 0.890, 0.714, 0.392, 0.18 },  -- an empty bar: faint gold
    place     = { 0.953, 0.663, 0.510 },        -- --place #f3a982
}
T.C = C
T.PAD = 14

function T.Fill(tex, c) tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end

function T.Text(parent, font, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font, size, "")
    fs:SetTextColor(color[1], color[2], color[3])
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

function T.Line(parent, c, layer)
    local t = parent:CreateTexture(nil, layer or "BORDER")
    T.Fill(t, c)
    t:SetHeight(1)
    return t
end

-- 1px inset border on all four sides (box-shadow: inset 0 0 0 1px var(--border))
function T.Border(frame, c)
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", false }, { "BOTTOMLEFT", "BOTTOMRIGHT", false },
                            { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true } }) do
        local t = frame:CreateTexture(nil, "BORDER")
        T.Fill(t, c or C.border)
        t:SetPoint(side[1]); t:SetPoint(side[2])
        if side[3] then t:SetWidth(1) else t:SetHeight(1) end
    end
end

-- --gold-line: transparent → gold → transparent, across the frame at y
function T.GoldLine(parent, y)
    local a, b = parent:CreateTexture(nil, "BORDER"), parent:CreateTexture(nil, "BORDER")
    for _, t in ipairs({ a, b }) do t:SetColorTexture(1, 1, 1, 1); t:SetHeight(1) end
    a:SetPoint("TOPLEFT", 0, y); a:SetPoint("TOPRIGHT", parent, "TOP", 0, y)
    b:SetPoint("TOPLEFT", parent, "TOP", 0, y); b:SetPoint("TOPRIGHT", 0, y)
    local r, g, bl = C.accentHi[1], C.accentHi[2], C.accentHi[3]
    a:SetGradient("HORIZONTAL", CreateColor(r, g, bl, 0), CreateColor(r, g, bl, 0.8))
    b:SetGradient("HORIZONTAL", CreateColor(r, g, bl, 0.8), CreateColor(r, g, bl, 0))
end

-- A round dot (the brand mark, the "you are here" marker)
function T.Dot(parent, size, c)
    local dot = parent:CreateTexture(nil, "ARTWORK")
    T.Fill(dot, c or C.accent)
    dot:SetSize(size, size)
    local mask = parent:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(dot)
    dot:AddMaskTexture(mask)
    return dot
end

-- A gold chip: small uppercase label on a faint gold fill
function T.Chip(parent)
    local text = T.Text(parent, T.display, 9, C.accent)
    local bg = parent:CreateTexture(nil, "ARTWORK")
    T.Fill(bg, C.chip)
    bg:SetPoint("TOPLEFT", text, "TOPLEFT", -7, 4)
    bg:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", 7, -4)
    return text
end

-- An icon with a hairline edge, cropped of Blizzard's built-in border
function T.Icon(parent, size)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size, size)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local edge = parent:CreateTexture(nil, "BORDER")
    T.Fill(edge, C.border)
    edge:SetPoint("TOPLEFT", icon, -1, 1); edge:SetPoint("BOTTOMRIGHT", icon, 1, -1)
    icon.edge = edge
    return icon
end

-- A flat text button: muted until hovered, gold when selected
function T.TextButton(parent, label, size)
    local b = CreateFrame("Button", nil, parent)
    b.text = T.Text(b, T.display, size or 11, C.muted)
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    b:SetSize(b.text:GetStringWidth() + 16, 24)
    b.SetSelected = function(self, on)
        self.selected = on
        local c = on and C.accent or C.muted
        self.text:SetTextColor(c[1], c[2], c[3])
        if self.underline then self.underline:SetShown(on) end
    end
    b:SetScript("OnEnter", function(self)
        if not self.selected then self.text:SetTextColor(C.primary[1], C.primary[2], C.primary[3]) end
    end)
    b:SetScript("OnLeave", function(self) self:SetSelected(self.selected) end)
    return b
end

-- A search field: mono text on a raised fill, placeholder until typed in
function T.SearchBox(parent, placeholder, onChange)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetAutoFocus(false)
    box:SetFont(T.mono, 11, "")
    box:SetTextColor(C.primary[1], C.primary[2], C.primary[3])
    box:SetTextInsets(24, 8, 0, 0)
    box:SetHeight(24)
    local bg = box:CreateTexture(nil, "BACKGROUND"); T.Fill(bg, C.raised); bg:SetAllPoints()
    T.Border(box)
    local glass = T.Text(box, T.display, 11, C.muted)
    glass:SetPoint("LEFT", 9, 0)
    glass:SetText("/")
    local hint = T.Text(box, T.mono, 11, C.muted)
    hint:SetPoint("LEFT", 24, 0)
    hint:SetText(placeholder)
    box:SetScript("OnEscapePressed", function(self)
        if self:GetText() ~= "" then self:SetText("") else self:ClearFocus() end
    end)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    box:SetScript("OnTextChanged", function(self)
        hint:SetShown(self:GetText() == "")
        onChange(self:GetText())
    end)
    box:SetScript("OnEditFocusGained", function() glass:SetTextColor(C.accent[1], C.accent[2], C.accent[3]) end)
    box:SetScript("OnEditFocusLost", function() glass:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    return box
end

-- A thin bar: faint gold track, gold fill; :SetValue(fraction)
function T.Bar(parent, width, height)
    local track = parent:CreateTexture(nil, "ARTWORK")
    T.Fill(track, C.track)
    track:SetSize(width, height or 3)
    local fill = parent:CreateTexture(nil, "ARTWORK", nil, 1)
    T.Fill(fill, C.accent)
    fill:SetHeight(height or 3)
    fill:SetPoint("LEFT", track, "LEFT")
    track.SetValue = function(_, f)
        f = math.max(0, math.min(1, f or 0))
        fill:SetShown(f > 0)
        fill:SetWidth(math.max(1, width * f))
    end
    track.SetShownAll = function(self, on) self:SetShown(on); fill:SetShown(on) end
    return track
end
