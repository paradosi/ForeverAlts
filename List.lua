---- List — a virtual list: a fixed set of rows reused as you scroll, so ten thousand
---- items cost the same as ten. Mouse wheel scrolls; the thumb on the right drags.

local _, ns = ...
local T = ns.T
local C = T.C

-- build(row) makes a row's widgets once; update(row, item, index) fills them
function ns.CreateList(parent, rowHeight, build, update)
    local list = CreateFrame("Frame", nil, parent)
    list.rows, list.data, list.offset = {}, {}, 0
    list:EnableMouseWheel(true)

    local track = list:CreateTexture(nil, "BACKGROUND")
    T.Fill(track, C.divider)
    track:SetPoint("TOPRIGHT", 0, 0); track:SetPoint("BOTTOMRIGHT", 0, 0); track:SetWidth(3)
    local thumb = CreateFrame("Frame", nil, list)
    thumb:SetWidth(3)
    local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
    T.Fill(thumbTex, { C.accent[1], C.accent[2], C.accent[3], 0.55 })
    thumbTex:SetAllPoints()
    thumb:EnableMouse(true)

    list.count = 0  -- rows that fit the current height; list.rows may hold more, hidden
    local function Visible() return list.count end
    local function MaxOffset() return math.max(0, #list.data - Visible()) end

    local function PlaceThumb()
        local total, shown = #list.data, Visible()
        local h = list:GetHeight()
        if total <= shown or h <= 0 then thumb:Hide(); track:Hide(); return end
        thumb:Show(); track:Show()
        local size = math.max(20, h * shown / total)
        local y = (h - size) * list.offset / MaxOffset()
        thumb:SetHeight(size)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, -y)
    end

    function list:Render()
        for i, row in ipairs(self.rows) do
            local index = self.offset + i
            local item = i <= self.count and self.data[index]
            if item then
                row.item = item
                update(row, item, index)
                row:Show()
            else
                row.item = nil
                row:Hide()
            end
        end
        PlaceThumb()
    end

    function list:SetData(data, keepOffset)
        self.data = data or {}
        if not keepOffset then self.offset = 0 end
        self.offset = math.min(self.offset, MaxOffset())
        self:Render()
    end

    function list:Scroll(delta)
        local new = math.max(0, math.min(MaxOffset(), self.offset + delta))
        if new ~= self.offset then self.offset = new; self:Render() end
    end

    list:SetScript("OnMouseWheel", function(self, delta)
        self:Scroll(-delta * (IsShiftKeyDown() and Visible() or 3))
    end)

    -- Dragging the thumb maps cursor height to offset
    thumb:SetScript("OnMouseDown", function()
        thumb.dragging = true
    end)
    thumb:SetScript("OnMouseUp", function() thumb.dragging = false end)
    thumb:SetScript("OnUpdate", function()
        if not thumb.dragging then return end
        if not IsMouseButtonDown("LeftButton") then thumb.dragging = false; return end
        local _, cy = GetCursorPosition()
        cy = cy / list:GetEffectiveScale()
        local top, h = list:GetTop(), list:GetHeight()
        local f = math.max(0, math.min(1, (top - cy) / h))
        local new = math.floor(f * MaxOffset() + 0.5)
        if new ~= list.offset then list.offset = new; list:Render() end
    end)

    -- Rows fill the height the list is given. Resizing the window changes the
    -- height: extra rows are made once and kept (hidden) if it shrinks again.
    list:SetScript("OnSizeChanged", function(self, _, h)
        local want = math.max(0, math.floor(h / rowHeight))
        for i = #self.rows + 1, want do
            local row = CreateFrame("Button", nil, self)
            row:SetHeight(rowHeight)
            row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
            row:SetPoint("TOPRIGHT", -8, -(i - 1) * rowHeight)
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            local hl = row:CreateTexture(nil, "BACKGROUND")
            T.Fill(hl, C.raised)
            hl:SetAllPoints()
            row:SetHighlightTexture(hl)
            local line = T.Line(row, C.divider)
            line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")
            build(row)
            self.rows[i] = row
            if self.layoutRow then self.layoutRow(row) end
        end
        self.count = want
        self:SetData(self.data, true)
    end)

    return list
end
