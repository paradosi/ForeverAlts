---- UI — the window: Characters, Items, Professions, Reputation, Lockouts and Talents views

local _, ns = ...
local T = ns.T
local C = T.C
local PAD = T.PAD

local W, H = 1040, 540           -- default size
local MIN_W, MIN_H = 1024, 400    -- every Characters column still fits at MIN_W
local MAX_W, MAX_H = 1800, 1200
local HEAD, TABS, FOOT = 40, 34, 32
local frame
local views, current = {}, nil

local MUTED = "|cff969db3"
local GOLD = "|cffe3b664"

local function Hex(c) return string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255) end

local function SetFooter(text) frame.footer:SetText(text or "") end

---- Characters ---------------------------------------------------------------

-- Columns: label, width, justify, text(c), sort value(c)
local COLUMNS = {
    { key = "name",   label = "CHARACTER", width = 200, justify = "LEFT",
      sort = function(c) return c.name end },
    { key = "level",  label = "LEVEL",     width = 70,  justify = "RIGHT",
      text = function(c)
          if not c.level then return "—" end
          if c.maxLevel and c.level >= c.maxLevel or not c.xpMax or c.xpMax == 0 then return tostring(c.level) end
          return c.level .. MUTED .. string.format(" %2d%%", math.floor(100 * (c.xp or 0) / c.xpMax)) .. "|r"
      end,
      sort = function(c) return (c.level or 0) + (c.xpMax and c.xpMax > 0 and (c.xp or 0) / c.xpMax or 0) end },
    { key = "zone",   label = "LOCATION",  width = 150, justify = "LEFT",
      text = function(c) return c.zone or "—" end,
      sort = function(c) return c.zone or "" end },
    { key = "money",  label = "GOLD",      width = 130, justify = "RIGHT",
      text = function(c) return ns.Money(c.money) end,
      sort = function(c) return c.money or 0 end },
    { key = "played", label = "PLAYED",    width = 80,  justify = "RIGHT",
      text = function(c) return ns.Duration(ns.Played(c)) end,
      sort = function(c) return ns.Played(c) or 0 end },
    { key = "rested", label = "RESTED",    width = 64,  justify = "RIGHT",
      text = function(c)
          local r = ns.Rested(c)
          if not r then return MUTED .. "—|r" end
          local pct = math.floor(r * 100 + 0.5)
          return (pct >= 150 and GOLD or "") .. pct .. "%" .. (pct >= 150 and "|r" or "")
      end,
      sort = function(c) return ns.Rested(c) or -1 end },
    { key = "ilvl",   label = "ILVL",      width = 46,  justify = "RIGHT",
      text = function(c) return c.ilvl and tostring(c.ilvl) or "—" end,
      sort = function(c) return c.ilvl or 0 end },
    { key = "bags",   label = "BAGS FREE", width = 70,  justify = "RIGHT",
      text = function(c)
          if not c.bagSlots then return "—" end
          local free = c.bagFree or 0
          return (free == 0 and Hex(C.place) or "") .. free .. "|r" .. MUTED .. " / " .. c.bagSlots .. "|r"
      end,
      sort = function(c) return c.bagFree or 0 end },
    { key = "talents", label = "TALENTS",  width = 80,  justify = "RIGHT",
      text = function(c)
          local spec = ns.ActiveSpec(c)
          if not spec then return MUTED .. "—|r" end
          local points = ns.SpecSummary(spec)
          if (spec.unspent or 0) > 0 then points = points .. Hex(C.place) .. " +" .. spec.unspent .. "|r" end
          return points
      end,
      sort = function(c)
          local spec, n = ns.ActiveSpec(c), 0
          for _, t in ipairs(spec and spec.trees or {}) do n = n + (t.spent or 0) end
          return spec and n or -1
      end },
    { key = "mail",   label = "MAIL",      width = 64,  justify = "RIGHT",
      text = function(c)
          local m = c.mail
          if not m then return MUTED .. "—|r" end
          if (m.letters or 0) == 0 then return MUTED .. "0|r" end
          local left = ns.MailLeft(c)
          if left and left < 7 * 86400 then
              return m.letters .. Hex(C.place) .. " " .. (left > 0 and (math.ceil(left / 86400) .. "d") or "!") .. "|r"
          end
          return tostring(m.letters)
      end,
      sort = function(c) return c.mail and c.mail.letters or -1 end },
    { key = "seen",   label = "SEEN",      width = 70,  justify = "RIGHT",
      text = function(c) return c == ns.me and GOLD .. "online|r" or ns.Ago(c.lastSeen) end,
      sort = function(c) return c == ns.me and math.huge or (c.lastSeen or 0) end },
}

local forgetDialog = {
    text = "Forget %s?\n\nForever Alts drops everything it recorded for this character. Log in on it to record it again.",
    button1 = "Forget",
    button2 = "Cancel",
    OnAccept = function(_, key) ns:Forget(key) end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

local function CharacterMenu(row)
    local c = row.item
    if not c then return end
    MenuUtil.CreateContextMenu(row, function(_, root)
        root:CreateTitle(c.realm ~= "" and (c.name .. " · " .. c.realm) or c.name)
        root:CreateButton("Browse items", function() ns.ShowUI("items", "", c.key) end)
        root:CreateButton("Show reputation", function() ns.ShowUI("reps", "", c.key) end)
        root:CreateButton("Show gear (Armory)", function() ns.ShowArmory(c.key) end)
        root:CreateButton("Show talents", function() ns.ShowTalents(c.key, "class") end)
        if c.legacy then root:CreateButton("Show Legacy trees", function() ns.ShowTalents(c.key, "legacy") end) end
        root:CreateButton("Forget this character", function()
            StaticPopupDialogs.FOREVERALTS_FORGET = forgetDialog
            StaticPopup_Show("FOREVERALTS_FORGET", c.name, nil, c.key)
        end)
    end)
end

-- Every column keeps its width except LOCATION, which takes what the window has spare
local FLEX, FLEX_MIN, GUTTER = "zone", 110, 8

local function LayoutRow(row)
    for i, col in ipairs(COLUMNS) do
        local cell, inset = row.cells[i], i == 1 and 12 or 6
        cell:ClearAllPoints()
        cell:SetPoint("LEFT", col.x + inset, 0)
        cell:SetWidth(col.w - inset - 6)
    end
    row.dot:ClearAllPoints()
    row.dot:SetPoint("LEFT", COLUMNS[1].x + 4, 0)
end

local function BuildCharacters(view)
    view.headers = {}
    for _, col in ipairs(COLUMNS) do
        local h = CreateFrame("Button", nil, view)
        h:SetHeight(20)
        h.text = T.Text(h, T.display, 10, C.muted, col.justify)
        h.text:SetPoint(col.justify, col.justify == "LEFT" and 6 or -6, 0)
        h.text:SetText(col.label)
        -- Oswald has no arrows, so the sort mark is set in JetBrains Mono
        h.arrow = T.Text(h, T.mono, 9, C.accent)
        if col.justify == "LEFT" then h.arrow:SetPoint("LEFT", h.text, "RIGHT", 3, 0)
        else h.arrow:SetPoint("RIGHT", h.text, "LEFT", -3, 0) end
        h:SetScript("OnClick", function()
            local s = ns.settings
            if s.sortKey == col.key then s.sortDesc = not s.sortDesc
            else s.sortKey, s.sortDesc = col.key, col.key ~= "name" and col.key ~= "zone" end
            view:Refresh()
        end)
        h.col = col
        view.headers[#view.headers + 1] = h
    end
    local line = T.Line(view, C.border)
    line:SetPoint("TOPLEFT", 0, -20); line:SetPoint("TOPRIGHT", 0, -20)

    view.list = ns.CreateList(view, 26, function(row)
        row.cells = {}
        for i, col in ipairs(COLUMNS) do
            row.cells[i] = T.Text(row, i == 1 and T.display or T.mono, i == 1 and 12 or 11, C.primary, col.justify)
        end
        row.dot = T.Dot(row, 5)
        row:SetScript("OnClick", function(self, button)
            if button == "RightButton" then CharacterMenu(self)
            elseif self.item then ns.ShowUI("items", "", self.item.key) end
        end)
        row:SetScript("OnEnter", function(self)
            local c = self.item
            if not c then return end
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT", 12, 0)
            GameTooltip:AddLine(ns.ColorName(c))
            local who = string.format("Level %s %s %s", c.level or "?", c.race or "",
                c.class and (LOCALIZED_CLASS_NAMES_MALE[c.class] or c.class) or "")
            if c.realm and c.realm ~= "" then who = who .. " · " .. c.realm end
            GameTooltip:AddLine(who, 0.761, 0.784, 0.855)
            if c.playedLevel then GameTooltip:AddDoubleLine("Played this level", ns.Duration(c.playedLevel), 0.588, 0.616, 0.702, 1, 1, 1) end
            for _, p in ipairs(c.profs or {}) do
                GameTooltip:AddDoubleLine(p.name, p.rank .. " / " .. p.max, 0.588, 0.616, 0.702, 1, 1, 1)
            end
            if c.bankSeen then GameTooltip:AddDoubleLine("Bank recorded", ns.Ago(c.bankSeen), 0.588, 0.616, 0.702, 1, 1, 1)
            else GameTooltip:AddLine("Bank not recorded yet: visit a banker on this character.", 0.953, 0.663, 0.510, true) end
            local m = c.mail
            if m then
                if m.seen then GameTooltip:AddDoubleLine("Mailbox recorded", ns.Ago(m.seen), 0.588, 0.616, 0.702, 1, 1, 1) end
                if (m.letters or 0) > 0 then
                    local what = m.letters .. " letter" .. (m.letters == 1 and "" or "s")
                    if (m.money or 0) > 0 then what = what .. ", " .. ns.Money(m.money) end
                    GameTooltip:AddDoubleLine("In the mail", what, 0.588, 0.616, 0.702, 1, 1, 1)
                    local left = ns.MailLeft(c)
                    if left then
                        local soon = left < 3 * 86400
                        GameTooltip:AddDoubleLine("First to expire", left > 0 and ("in " .. ns.Duration(left)) or "expired?",
                            0.588, 0.616, 0.702, soon and 0.953 or 1, soon and 0.663 or 1, soon and 0.510 or 1)
                    end
                end
                if (m.hidden or 0) > 0 then
                    GameTooltip:AddLine(m.hidden .. " more letters wait on the server: take some mail to see them.", 0.953, 0.663, 0.510, true)
                end
            else
                GameTooltip:AddLine("Mailbox not recorded yet: open a mailbox on this character.", 0.953, 0.663, 0.510, true)
            end
            local t = c.talents
            for group, spec in pairs(t and t.specs or {}) do
                local points, top = ns.SpecSummary(spec)
                local label = (t.specs[2] and (group == t.active and "Talents (active)" or "Talents (other spec)")) or "Talents"
                local unspent = (spec.unspent or 0) > 0 and ("  |cfff3a982+" .. spec.unspent .. " unspent|r") or ""
                GameTooltip:AddDoubleLine(label, (top and (top .. " ") or "") .. points .. unspent, 0.588, 0.616, 0.702, 1, 1, 1)
            end
            local lg = c.legacy
            if lg then
                GameTooltip:AddDoubleLine("Legacy", "renown " .. (lg.renown or "?") .. ", " .. (lg.unspent or 0) .. " points to spend",
                    0.588, 0.616, 0.702, 1, 1, 1)
            end
            if c.lockoutsSeen then
                local locks = ns.Lockouts(c)
                if #locks > 0 then
                    local names = {}
                    for _, l in ipairs(locks) do names[#names + 1] = l.name end
                    GameTooltip:AddDoubleLine("Saved to", table.concat(names, ", "), 0.588, 0.616, 0.702, 1, 1, 1)
                end
            end
            GameTooltip:AddLine("Click to browse items · Right-click for more", 0.890, 0.714, 0.392)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
    end, function(row, c)
        local multiRealm = view.multiRealm
        row.cells[1]:SetText(ns.ColorName(c) .. (multiRealm and (MUTED .. "  " .. c.realm .. "|r") or ""))
        for i = 2, #COLUMNS do row.cells[i]:SetText(COLUMNS[i].text(c)) end
        row.dot:SetShown(c == ns.me)
    end)
    view.list:SetPoint("TOPLEFT", 0, -24)
    view.list:SetPoint("BOTTOMRIGHT")
    view.list.layoutRow = LayoutRow

    -- Place the columns for the view's width: headers, then every row made so far
    function view:Layout(width)
        local fixed = 0
        for _, col in ipairs(COLUMNS) do if col.key ~= FLEX then fixed = fixed + col.width end end
        local x = 0
        for i, col in ipairs(COLUMNS) do
            col.x = x
            col.w = col.key == FLEX and math.max(FLEX_MIN, width - GUTTER - fixed) or col.width
            x = x + col.w
            local h = self.headers[i]
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", col.x, 0)
            h:SetWidth(col.w)
        end
        for _, row in ipairs(self.list.rows) do LayoutRow(row) end
    end
    view:Layout(W - PAD * 2)
    view:SetScript("OnSizeChanged", function(self, w) self:Layout(w) end)

    function view:Refresh()
        local s = ns.settings
        local chars = ns:Characters()
        local realms, gold, played = {}, 0, 0
        for _, c in ipairs(chars) do
            realms[c.realm] = true
            gold = gold + (c.money or 0)
            played = played + (ns.Played(c) or 0)
        end
        local nRealms = 0
        for _ in pairs(realms) do nRealms = nRealms + 1 end
        self.multiRealm = nRealms > 1

        local col
        for _, c in ipairs(COLUMNS) do if c.key == s.sortKey then col = c end end
        col = col or COLUMNS[2]
        table.sort(chars, function(a, b)
            local va, vb = col.sort(a), col.sort(b)
            if va == vb then return a.name < b.name end
            if s.sortDesc then return va > vb end
            return va < vb
        end)
        for _, h in ipairs(self.headers) do
            local on = h.col == col
            local c = on and C.accent or C.muted
            h.text:SetTextColor(c[1], c[2], c[3])
            h.arrow:SetText(on and (s.sortDesc and "↓" or "↑") or "")
        end
        self.list:SetData(chars, true)
        SetFooter(string.format("%d character%s%s   ·   %s   ·   %s played",
            #chars, #chars == 1 and "" or "s", nRealms > 1 and (" on " .. nRealms .. " realms") or "",
            ns.Money(gold), ns.Duration(played)))
    end
end

---- The character filter, shared by Items and Reputation -----------------------

-- Set by clicking a character on the Characters tab; cleared from the chip on either view
local filterKey

local function FilterChar()
    local c = filterKey and ns.db.chars[filterKey]
    if filterKey and not c then filterKey = nil end
    return c
end

-- "ONLY Name ×" beside a view's search box; click to show every character again
local function OnlyChip(view)
    local b = CreateFrame("Button", nil, view)
    b:SetHeight(24)
    b:SetPoint("LEFT", view.search, "RIGHT", 10, 0)
    b.text = T.Chip(b)
    b.text:SetPoint("LEFT", 8, 0)
    b:SetScript("OnClick", function() filterKey = nil; view:Refresh() end)
    function b:Update()
        local c = FilterChar()
        self:SetShown(c ~= nil)
        if c then
            self.text:SetText("ONLY " .. c.name:upper() .. "   ×")
            self:SetWidth(self.text:GetStringWidth() + 16)
        end
        return c
    end
    return b
end

---- The character dropdown: a box showing the choice, a list dropping from it in the window's
---- own look (a row per choice, the chosen one marked in gold). A click elsewhere or Esc closes it.
---- Choices are { key, c = character or nil, label, info }; onPick(choice) runs on a click.

local CLASS_NAME = function(c) return LOCALIZED_CLASS_NAMES_MALE[c.class] or c.class or "" end

-- Characters as choices: coloured name, then level and class
function ns.CharChoices(chars, allLabel, allInfo)
    local list = {}
    if allLabel then list[1] = { key = false, label = allLabel, info = allInfo or "" } end
    for _, c in ipairs(chars) do
        list[#list + 1] = {
            key = c.key, c = c,
            label = ns.ColorName(c) .. (c == ns.me and "  |cff969db3· you|r" or ""),
            info = (c.level or "?") .. " " .. CLASS_NAME(c),
        }
    end
    return list
end

function ns.CharDropdown(parent, onPick)
    local ROW, MAXROWS = 24, 12
    local drop = CreateFrame("Button", nil, parent)
    drop:SetSize(260, 24)
    local bg = drop:CreateTexture(nil, "BACKGROUND"); T.Fill(bg, C.raised); bg:SetAllPoints()
    T.Border(drop, C.border)
    drop.label = T.Text(drop, T.monoMedium, 11, C.primary)
    drop.label:SetPoint("LEFT", 10, 0)
    drop.label:SetPoint("RIGHT", -24, 0)
    drop.arrow = T.Text(drop, T.mono, 11, C.muted, "RIGHT")
    drop.arrow:SetPoint("RIGHT", -9, 0)
    drop.arrow:SetText("▾")
    drop:SetScript("OnEnter", function(b) b.arrow:SetTextColor(C.accent[1], C.accent[2], C.accent[3]) end)
    drop:SetScript("OnLeave", function(b) b.arrow:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    drop.hoverGlow = false
    T.HoverGlow(drop)
    drop.choices, drop.value = {}, false

    local list = CreateFrame("Frame", nil, drop)
    list:SetFrameStrata("DIALOG")
    list:SetPoint("TOPLEFT", drop, "BOTTOMLEFT", 0, -2)
    local lbg = list:CreateTexture(nil, "BACKGROUND"); T.Fill(lbg, C.deep); lbg:SetAllPoints()
    T.Border(list, C.accent)
    list:Hide()
    list:EnableMouse(true)
    list:EnableMouseWheel(true)
    list.rows, list.offset = {}, 0
    drop.list = list

    function list.Fill(l)
        local all = drop.choices
        local shown = math.min(#all, MAXROWS)
        l.offset = math.max(0, math.min(l.offset, #all - shown))
        l:SetSize(math.max(drop:GetWidth(), 240), shown * ROW + 4)
        for i = 1, shown do
            local r = l.rows[i]
            if not r then
                r = CreateFrame("Button", nil, l)
                r:SetHeight(ROW)
                r:SetPoint("TOPLEFT", 2, -2 - (i - 1) * ROW)
                r:SetPoint("TOPRIGHT", -2, -2 - (i - 1) * ROW)
                r.hover = r:CreateTexture(nil, "BACKGROUND"); T.Fill(r.hover, C.raised); r.hover:SetAllPoints(); r.hover:Hide()
                r.mark = r:CreateTexture(nil, "ARTWORK"); T.Fill(r.mark, C.accent)
                r.mark:SetPoint("TOPLEFT"); r.mark:SetPoint("BOTTOMLEFT"); r.mark:SetWidth(2)
                r.name = T.Text(r, T.monoMedium, 11, C.primary)
                r.name:SetPoint("LEFT", 10, 0)
                r.info = T.Text(r, T.mono, 10, C.muted, "RIGHT")
                r.info:SetPoint("RIGHT", -8, 0)
                r.name:SetPoint("RIGHT", r.info, "LEFT", -8, 0)
                r.ch, r.entry = false, false
                r:SetScript("OnEnter", function(b) b.hover:Show() end)
                r:SetScript("OnLeave", function(b) b.hover:Hide() end)
                r:SetScript("OnClick", function(b)
                    if not b.entry then return end
                    list:Hide()
                    drop:SetChoices(drop.choices, b.entry.key)
                    onPick(b.entry)
                end)
                l.rows[i] = r
            end
            local e = all[i + l.offset]
            r.entry, r.ch = e, e.c or false
            r.name:SetText(e.label)
            r.info:SetText(e.info or "")
            local on = e.key == drop.value
            r.mark:SetShown(on)
            local col = on and C.accent or C.muted
            r.info:SetTextColor(col[1], col[2], col[3])
            r:Show()
        end
        for i = shown + 1, #l.rows do l.rows[i]:Hide(); l.rows[i].ch, l.rows[i].entry = false, false end
    end
    list:SetScript("OnMouseWheel", function(l, delta) l.offset = l.offset - delta; l:Fill() end)
    list:SetScript("OnUpdate", function(l)
        if (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))
            and not l:IsMouseOver() and not drop:IsMouseOver() then l:Hide() end
    end)
    list:SetScript("OnKeyDown", function(l, key)
        if key == "ESCAPE" then l:SetPropagateKeyboardInput(false); l:Hide()
        else l:SetPropagateKeyboardInput(true) end
    end)
    list:SetScript("OnShow", function(l) l:EnableKeyboard(true) end)
    list:SetScript("OnHide", function(l) l:EnableKeyboard(false); drop.arrow:SetText("▾") end)
    drop:SetScript("OnClick", function(b)
        if list:IsShown() then list:Hide(); return end
        list.offset = 0
        list:Fill()
        list:Show()
        b.arrow:SetText("▴")
    end)
    parent:HookScript("OnHide", function() list:Hide() end)

    -- The choices, and which is chosen (its key; false is an "all" entry)
    function drop:SetChoices(choices, value)
        self.choices, self.value = choices, value or false
        local chosen
        for _, e in ipairs(choices) do if e.key == self.value then chosen = e end end
        chosen = chosen or choices[1]
        if not chosen then self.label:SetText(""); return end
        self.label:SetText(chosen.label .. (chosen.info ~= "" and ("  |cff969db3" .. chosen.info .. "|r") or ""))
        local w = self.label:GetStringWidth()
        self:SetWidth(math.max(200, math.min(320, (w and w > 0 and w or 180) + 44)))
        if list:IsShown() then list:Fill() end
    end
    return drop
end

---- Items ----------------------------------------------------------------------

local function ItemInfo(id)
    local known = ns.db.items[id]
    local name = known and known.name or C_Item.GetItemNameByID(id)
    local quality = known and known.quality or C_Item.GetItemQualityByID(id)
    local icon = known and known.icon or C_Item.GetItemIconByID(id)
    return name, quality, icon, known and known.link
end

local function QualityHex(q)
    local _, _, _, hex = C_Item.GetItemQualityColor(q or 1)
    return hex and ("|c" .. hex) or "|cffffffff"
end

-- Every item every character holds: id -> { total, list of { c, n } }, plus the account bank
local function Inventory(onlyKey)
    local all = {}
    local function Add(id, c, n)
        local e = all[id]
        if not e then e = { id = id, total = 0, by = {} }; all[id] = e end
        e.total = e.total + n
        table.insert(e.by, { c = c, n = n })
    end
    for key, c in pairs(ns.db.chars) do
        if not onlyKey or key == onlyKey then
            local seen = {}
            for _, t in ipairs({ c.bags or {}, c.bank or {}, c.equipped or {}, c.mail and c.mail.items or {} }) do
                for id in pairs(t) do seen[id] = true end
            end
            for id in pairs(seen) do Add(id, c, (ns.Holdings(c, id))) end
        end
    end
    if not onlyKey then
        for id, n in pairs(ns.db.warband.items or {}) do Add(id, { name = "Account bank", account = true }, n) end
    end
    return all
end

---- One character's inventory as a grid: a section per place (bags, bank, mail, gear), each a
---- heading saying how fresh it is, then rows of item icons sorted by quality and name.
---- The grid rides on the virtual list: each list row is a heading or a row of icons.

local CELL, ICON, MAXCOLS = 44, 38, 30

-- The link a character's gear slot was saved with, so a tooltip shows its suffix
local function GearLinks(c)
    local links = {}
    for _, v in pairs(c.gear or {}) do
        if type(v) == "string" then
            local id = tonumber(v:match("item:(%d+)"))
            if id then links[id] = v end
        end
    end
    return links
end

local function GridSections(c, query)
    local mail = c.mail
    local function Age(t) return (c == ns.me and "now") or ns.Ago(t) end
    local bagsInfo = c.bagSlots and ((c.bagSlots - (c.bagFree or 0)) .. " / " .. c.bagSlots .. " slots used") or ""
    if c.lastSeen or c == ns.me then bagsInfo = bagsInfo .. "   ·   " .. Age(c.lastSeen) end
    local mailInfo
    if mail and mail.seen then
        local parts = { (mail.letters or 0) .. " letter" .. (mail.letters == 1 and "" or "s") .. " with items or gold" }
        if (mail.money or 0) > 0 then parts[#parts + 1] = ns.Money(mail.money, true) end
        local left = ns.MailLeft(c)
        if left then parts[#parts + 1] = left > 0 and ("first expires in " .. ns.Duration(left)) or "may have expired" end
        parts[#parts + 1] = "recorded " .. ns.Ago(mail.seen)
        mailInfo = table.concat(parts, "   ·   ")
    end
    local sections = {
        { title = "BAGS", items = c.bags, info = bagsInfo },
        { title = "BANK", items = c.bank, info = c.bankSeen and ("recorded " .. ns.Ago(c.bankSeen)),
          missing = "Not recorded yet: open a bank on " .. c.name .. "." },
        { title = "MAIL", items = mail and mail.items, info = mailInfo,
          missing = "Not recorded yet: open a mailbox on " .. c.name .. "." },
        { title = "EQUIPPED", items = c.equipped, info = "" },
    }
    local gear = GearLinks(c)
    for _, sec in ipairs(sections) do
        local list = {}
        for id, n in pairs(sec.items or {}) do
            local name, quality, icon, link = ItemInfo(id)
            if query == "" or (name and name:lower():find(query, 1, true)) then
                list[#list + 1] = { id = id, n = n, name = name or "", quality = quality or 1, icon = icon, link = gear[id] or link }
            end
        end
        table.sort(list, function(a, b)
            if a.quality ~= b.quality then return a.quality > b.quality end
            if a.name ~= b.name then return a.name < b.name end
            return a.id < b.id
        end)
        sec.list = list
        if sec.title == "EQUIPPED" then sec.info = #list .. " item" .. (#list == 1 and "" or "s") end
    end
    return sections
end

-- The sections as list rows for a grid of cols columns
local function GridRows(sections, cols, query)
    local rows = {}
    for _, sec in ipairs(sections) do
        local recorded = sec.items ~= nil and sec.info ~= nil
        if query == "" or #sec.list > 0 then
            local info = sec.info
            if not recorded then info = sec.missing
            elseif #sec.list == 0 then info = (info ~= "" and (info .. "   ·   ") or "") .. "empty" end
            rows[#rows + 1] = { head = sec.title, info = info, count = #sec.list, missing = not recorded }
            for i = 1, #sec.list, cols do
                local icons = {}
                for k = i, math.min(i + cols - 1, #sec.list) do icons[#icons + 1] = sec.list[k] end
                rows[#rows + 1] = { icons = icons }
            end
        end
    end
    return rows
end

local function BuildItems(view)
    view.search = T.SearchBox(view, "Search bags, bank, gear and mail", function(text)
        view.query = text
        view:Refresh()
    end)
    view.search:SetWidth(360)

    -- Whose items: everyone (the search) or one character (their bags, bank, mail and gear)
    view.drop = ns.CharDropdown(view, function(entry)
        filterKey = entry.key or nil
        view:Refresh()
    end)
    view.drop:SetPoint("TOPLEFT", 0, 0)
    view.gridKey = false
    view.search:SetPoint("LEFT", view.drop, "RIGHT", 10, 0)

    -- One character: the grid
    view.grid = ns.CreateList(view, CELL, function(row)
        row.head = T.Text(row, T.display, 13, C.primary)
        row.head:SetPoint("BOTTOMLEFT", 4, 8)
        row.info = T.Text(row, T.mono, 10, C.muted)
        row.info:SetPoint("LEFT", row.head, "RIGHT", 12, 0)
        row.info:SetPoint("RIGHT", -12, 0)
        row.line = T.Line(row, C.divider)
        row.line:SetPoint("BOTTOMLEFT", 0, 2); row.line:SetPoint("BOTTOMRIGHT", -8, 2)
        row.cells = {}
        for i = 1, MAXCOLS do
            local b = CreateFrame("Button", nil, row)
            b:SetSize(ICON, ICON)
            b:SetPoint("LEFT", 4 + (i - 1) * CELL, 0)
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetPoint("TOPLEFT", 1, -1); b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
            b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            b.edges = {}
            for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", false }, { "BOTTOMLEFT", "BOTTOMRIGHT", false },
                                    { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true } }) do
                local t = b:CreateTexture(nil, "OVERLAY")
                t:SetPoint(side[1]); t:SetPoint(side[2])
                if side[3] then t:SetWidth(1) else t:SetHeight(1) end
                b.edges[#b.edges + 1] = t
            end
            b.count = T.Text(b, T.monoMedium, 11, C.primary, "RIGHT")
            b.count:SetPoint("BOTTOMRIGHT", -2, 2)
            b.count:SetShadowOffset(1, -1)
            b.entry = false
            b:SetScript("OnEnter", function(self)
                local e = self.entry
                if not e then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if e.link then GameTooltip:SetHyperlink(e.link) else GameTooltip:SetItemByID(e.id) end
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", GameTooltip_Hide)
            b:SetScript("OnClick", function(self)
                local e = self.entry
                if e and e.link then HandleModifiedItemClick(e.link) end
            end)
            b.hoverGlow = false
            T.HoverGlow(b)
            row.cells[i] = b
        end
    end, function(row, r)
        local isHead = r.head ~= nil
        row.head:SetShown(isHead); row.info:SetShown(isHead); row.line:SetShown(isHead)
        if isHead then
            row.head:SetText(r.head .. (r.count > 0 and ("  |cff969db3" .. r.count .. "|r") or ""))
            row.info:SetText(r.info or "")
            local c = r.missing and C.place or C.muted
            row.info:SetTextColor(c[1], c[2], c[3])
        end
        for i, b in ipairs(row.cells) do
            local e = not isHead and r.icons[i]
            b.entry = e or false
            if e then
                b.icon:SetTexture(e.icon or 134400)
                local q = e.quality or 1
                local col = C.border
                if q >= 2 then
                    local qr, qg, qb = C_Item.GetItemQualityColor(q)
                    if type(qr) == "number" then col = { qr, qg, qb, 0.9 } end
                end
                for _, t in ipairs(b.edges) do T.Fill(t, col) end
                b.count:SetText(e.n > 1 and ns.Commas(e.n) or "")
                b:Show()
            else
                b:Hide()
            end
        end
    end)
    view.grid:SetPoint("TOPLEFT", 0, -34)
    view.grid:SetPoint("BOTTOMRIGHT")
    view.grid:Hide()
    -- The number of columns follows the window's width
    view:SetScript("OnSizeChanged", function()
        if view:IsShown() and FilterChar() then view:Refresh() end
    end)

    view.hint = T.Text(view, T.mono, 11, C.muted, "CENTER")
    view.hint:SetPoint("TOPLEFT", PAD, -120)
    view.hint:SetPoint("TOPRIGHT", -PAD, -120)
    view.hint:SetWordWrap(true)

    view.list = ns.CreateList(view, 34, function(row)
        row.icon = T.Icon(row, 22)
        row.icon:SetPoint("LEFT", 6, 0)
        row.name = T.Text(row, T.display, 12, C.primary)
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, 1)
        row.name:SetPoint("RIGHT", -90, 0)
        row.by = T.Text(row, T.mono, 10, C.muted)
        row.by:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 10, -1)
        row.by:SetPoint("RIGHT", -90, 0)
        row.total = T.Text(row, T.monoMedium, 14, C.accent, "RIGHT")
        row.total:SetPoint("RIGHT", -10, 0)
        row:SetScript("OnEnter", function(self)
            if not self.item then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.item.id)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
        row:SetScript("OnClick", function(self)
            local _, _, _, link = ItemInfo(self.item.id)
            if link then HandleModifiedItemClick(link) end
        end)
    end, function(row, e)
        local name, quality, icon = ItemInfo(e.id)
        row.icon:SetTexture(icon or 134400)
        row.name:SetText(QualityHex(quality) .. (name or ("item " .. e.id)) .. "|r")
        local parts = {}
        for _, b in ipairs(e.by) do
            local who = b.c.account and (GOLD .. "Account bank|r") or ns.ColorName(b.c)
            table.insert(parts, who .. " " .. b.n)
        end
        row.by:SetText(table.concat(parts, MUTED .. "  ·  |r"))
        row.total:SetText(ns.Commas(e.total))
    end)
    view.list:SetPoint("TOPLEFT", 0, -34)
    view.list:SetPoint("BOTTOMRIGHT")

    function view:Refresh()
        local query = (self.query or ""):lower()
        local onlyChar = FilterChar()

        local chars = ns:Characters()
        table.sort(chars, function(a, b)
            if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
            return a.name < b.name
        end)
        self.drop:SetChoices(ns.CharChoices(chars, "ALL CHARACTERS", "search everyone"), onlyChar and onlyChar.key)

        self.grid:SetShown(onlyChar ~= nil)
        self.list:SetShown(onlyChar == nil)
        if onlyChar then
            local w = self.grid:GetWidth()
            if not w or w <= 0 then w = W - PAD * 2 end
            local cols = math.max(1, math.min(MAXCOLS, math.floor((w - 12) / CELL)))
            local sections = GridSections(onlyChar, query)
            local rows = GridRows(sections, cols, query)
            self.grid:SetData(rows, self.gridKey == onlyChar.key)
            self.gridKey = onlyChar.key
            local counts = {}
            for _, sec in ipairs(sections) do
                if #sec.list > 0 then counts[#counts + 1] = #sec.list .. " " .. sec.title:lower() end
            end
            self.hint:SetShown(query ~= "" and #rows == 0)
            self.hint:SetText("Nothing matches \"" .. (self.query or "") .. "\" on " .. onlyChar.name .. ".")
            SetFooter(onlyChar.name .. ":  " .. (#counts > 0 and table.concat(counts, " · ") or "nothing recorded")
                .. "   ·   Shift-click links an item in chat")
            return
        end
        self.gridKey = false

        if query == "" and not onlyChar then
            self.list:SetData({})
            self.hint:SetText("Type part of an item's name.\n\nBags and gear are recorded whenever you log in; "
                .. "the bank and mail when you open them, so visit a banker and a mailbox once on each character.")
            self.hint:Show()
            local n = 0
            for _ in pairs(Inventory()) do n = n + 1 end
            SetFooter(ns.Commas(n) .. " different items across your characters")
            return
        end

        local results = {}
        for id, e in pairs(Inventory(onlyChar and filterKey)) do
            local name = ItemInfo(id)
            if query == "" or (name and name:lower():find(query, 1, true)) then
                e.name = name or ""
                table.sort(e.by, function(a, b) return a.n > b.n end)
                table.insert(results, e)
            end
        end
        table.sort(results, function(a, b)
            if onlyChar or a.total == b.total then return a.name < b.name end
            return a.total > b.total
        end)
        self.hint:SetShown(#results == 0)
        self.hint:SetText("Nothing matches \"" .. (self.query or "") .. "\".")
        self.list:SetData(results)
        SetFooter(ns.Commas(#results) .. " item" .. (#results == 1 and "" or "s")
            .. (onlyChar and (" on " .. onlyChar.name) or "") .. "   ·   Shift-click links an item in chat")
    end
end

---- Professions --------------------------------------------------------------

-- Gathering professions have no recipes: Herbalism, Skinning, Fishing (skill line IDs).
-- Mining isn't here: its window holds the Smelting recipes.
local NO_RECIPES = { [182] = true, [393] = true, [356] = true }

local function BuildProfessions(view)
    view.search = T.SearchBox(view, "Who can make…", function(text)
        view.query = text
        view:Refresh()
    end)
    view.search:SetPoint("TOPLEFT", 0, 0)
    view.search:SetWidth(360)

    -- Clicking a character's profession lists its recipes; the chip goes back
    view.openProf = false  -- { key, prof } while one character's recipes are listed
    view.back = CreateFrame("Button", nil, view)
    view.back:SetHeight(24)
    view.back:SetPoint("LEFT", view.search, "RIGHT", 10, 0)
    view.back.text = T.Chip(view.back)
    view.back.text:SetPoint("LEFT", 8, 0)
    view.back:SetScript("OnClick", function()
        view.openProf = false
        view.search:SetText("")  -- refreshes
    end)

    view.hint = T.Text(view, T.mono, 11, C.muted, "CENTER")
    view.hint:SetPoint("TOPLEFT", PAD, -120)
    view.hint:SetPoint("TOPRIGHT", -PAD, -120)
    view.hint:SetWordWrap(true)

    local BAR = 160
    view.list = ns.CreateList(view, 30, function(row)
        row.who = T.Text(row, T.display, 12, C.primary)
        row.who:SetPoint("LEFT", 8, 0)
        row.who:SetWidth(190)
        row.icon = T.Icon(row, 18)
        row.icon:SetPoint("LEFT", 210, 0)
        row.what = T.Text(row, T.display, 12, C.primary)
        row.what:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.what:SetWidth(170)
        row.bar = T.Bar(row, BAR, 3)
        row.bar:SetPoint("LEFT", 420, -5)
        row.rank = T.Text(row, T.mono, 10, C.secondary)
        row.rank:SetPoint("BOTTOMLEFT", row.bar, "TOPLEFT", 0, 4)
        row.extra = T.Text(row, T.mono, 10, C.muted, "RIGHT")
        row.extra:SetPoint("RIGHT", -10, 0)
        row.extra:SetPoint("LEFT", 600, 0)
        row:SetScript("OnEnter", function(self)
            local e = self.item
            if not e then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if not e.recipe then
                local known = e.c.recipes and e.c.recipes[e.p.name]
                if not known then return end
                local n = 0
                for _ in pairs(known) do n = n + 1 end
                GameTooltip:SetText("Click to list " .. e.c.name .. "'s " .. n .. " " .. e.p.name .. " recipes", 1, 1, 1)
            elseif e.recipe.item then
                GameTooltip:SetItemByID(e.recipe.item)
            elseif e.id then
                -- Enchants make no item; a recipe ID is the spell that casts it
                GameTooltip:SetSpellByID(e.id)
            else
                GameTooltip:SetText(e.recipe.name or "?")
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
        row:SetScript("OnClick", function(self)
            local e = self.item
            if not e or e.recipe or not (e.c.recipes and e.c.recipes[e.p.name]) then return end
            view.openProf = { key = e.c.key, prof = e.p.name }
            view.search:SetText("")  -- refreshes
            GameTooltip_Hide()
        end)
    end, function(row, e)
        if e.recipe then
            -- A recipe match: what it makes, and who knows it
            row.who:SetText(e.recipe.name or "?")
            row.icon:SetTexture(e.recipe.icon or 134400)
            row.what:SetText(MUTED .. e.prof .. "|r")
            row.bar:SetShownAll(false)
            row.rank:SetText("")
            local names = {}
            for _, c in ipairs(e.knowers) do table.insert(names, ns.ColorName(c)) end
            row.extra:SetText(table.concat(names, ", "))
        else
            -- A character's profession and how far along it is
            row.who:SetText(ns.ColorName(e.c))
            row.icon:SetTexture(e.p.icon or 134400)
            row.what:SetText(e.p.name)
            row.bar:SetShownAll(true)
            row.bar:SetValue(e.p.max > 0 and e.p.rank / e.p.max or 0)
            row.rank:SetText(e.p.rank .. " / " .. e.p.max)
            local known = e.c.recipes and e.c.recipes[e.p.name]
            if known then
                local n = 0
                for _ in pairs(known) do n = n + 1 end
                row.extra:SetText(n .. " recipes  " .. ns.Ago(e.c.recipesSeen and e.c.recipesSeen[e.p.name]))
            elseif NO_RECIPES[e.p.skillLine] then
                row.extra:SetText("gathering")
            else
                row.extra:SetText(Hex(C.place) .. "open the profession window to record recipes|r")
            end
        end
    end)
    view.list:SetPoint("TOPLEFT", 0, -34)
    view.list:SetPoint("BOTTOMRIGHT")

    -- Every character who knows a recipe, for the "who else" column
    local function Knowers(id, prof)
        local list = {}
        for _, c in pairs(ns.db.chars) do
            if c.recipes and c.recipes[prof] and c.recipes[prof][id] then table.insert(list, c) end
        end
        table.sort(list, function(a, b) return a.name < b.name end)
        return list
    end

    function view:Refresh()
        local query = (self.query or ""):lower()
        local rows = {}
        local open = self.openProf and ns.db.chars[self.openProf.key]
        local known = open and open.recipes and open.recipes[self.openProf.prof]
        if not known then self.openProf = false end
        self.back:SetShown(known ~= nil)
        if known then
            -- One character's recipes in one profession
            self.back.text:SetText(open.name:upper() .. " · " .. self.openProf.prof:upper() .. "   ×")
            self.back:SetWidth(self.back.text:GetStringWidth() + 16)
            for id in pairs(known) do
                local r = ns.db.recipes[id]
                local name = r and r.name or ("recipe " .. id)
                if query == "" or name:lower():find(query, 1, true) then
                    table.insert(rows, { id = id, recipe = r or { name = name }, prof = self.openProf.prof,
                                         knowers = Knowers(id, self.openProf.prof) })
                end
            end
            table.sort(rows, function(a, b) return (a.recipe.name or "") < (b.recipe.name or "") end)
            self.hint:SetShown(#rows == 0)
            self.hint:SetText("No recipe matches \"" .. (self.query or "") .. "\".")
            self.list:SetData(rows)
            SetFooter(#rows .. " " .. self.openProf.prof .. " recipe" .. (#rows == 1 and "" or "s") .. " on " .. open.name
                .. "   ·   × on the chip goes back")
            return
        end
        if query == "" then
            local chars = ns:Characters()
            table.sort(chars, function(a, b) return a.name < b.name end)
            for _, c in ipairs(chars) do
                for _, p in ipairs(c.profs or {}) do table.insert(rows, { c = c, p = p }) end
            end
            self.hint:SetShown(#rows == 0)
            self.hint:SetText("No professions recorded yet. Log in on each character once.")
            self.list:SetData(rows)
            SetFooter(#rows .. " professions   ·   click one to list its recipes   ·   type to find who can make something")
            return
        end

        -- recipeID -> { recipe, prof, knowers }
        local found = {}
        for _, c in pairs(ns.db.chars) do
            for prof, known in pairs(c.recipes or {}) do
                for id in pairs(known) do
                    local r = ns.db.recipes[id]
                    if r and r.name and r.name:lower():find(query, 1, true) then
                        local e = found[id]
                        if not e then e = { id = id, recipe = r, prof = prof, knowers = {} }; found[id] = e end
                        table.insert(e.knowers, c)
                    end
                end
            end
        end
        for _, e in pairs(found) do table.insert(rows, e) end
        table.sort(rows, function(a, b) return a.recipe.name < b.recipe.name end)
        self.hint:SetShown(#rows == 0)
        self.hint:SetText("None of your characters knows a recipe matching \"" .. self.query .. "\".\n\n"
            .. "Recipes are recorded when you open a profession window.")
        self.list:SetData(rows)
        SetFooter(#rows .. " recipe" .. (#rows == 1 and "" or "s"))
    end
end

---- Reputation -----------------------------------------------------------------

local function Standing(rep, withNumbers)
    local c = ns.StandingColor(rep.r)
    local text = Hex(c) .. ns.StandingName(rep.r) .. "|r"
    if rep.max and rep.max > 0 then
        if withNumbers then
            text = text .. MUTED .. "  " .. ns.Commas(rep.cur) .. " / " .. ns.Commas(rep.max) .. "|r"
        else
            text = text .. MUTED .. " " .. math.floor(100 * rep.cur / rep.max) .. "%|r"
        end
    end
    return text
end

local function BuildReputation(view)
    view.search = T.SearchBox(view, "Search factions", function(text)
        view.query = text
        view:Refresh()
    end)
    view.search:SetPoint("TOPLEFT", 0, 0)
    view.search:SetWidth(360)
    view.only = OnlyChip(view)

    view.hint = T.Text(view, T.mono, 11, C.muted, "CENTER")
    view.hint:SetPoint("TOPLEFT", PAD, -120)
    view.hint:SetPoint("TOPRIGHT", -PAD, -120)
    view.hint:SetWordWrap(true)

    local BAR = 140
    view.list = ns.CreateList(view, 34, function(row)
        row.group = T.Text(row, T.display, 10, C.accent)
        row.group:SetPoint("BOTTOMLEFT", 6, 6)
        row.name = T.Text(row, T.display, 12, C.primary)
        row.name:SetPoint("TOPLEFT", 8, -4)
        row.name:SetPoint("RIGHT", -(BAR + 24), 0)
        row.by = T.Text(row, T.mono, 10, C.muted)
        row.by:SetPoint("BOTTOMLEFT", 8, 4)
        row.by:SetPoint("RIGHT", -(BAR + 24), 0)
        row.best = T.Text(row, T.display, 12, C.primary, "RIGHT")
        row.best:SetPoint("TOPRIGHT", -10, -4)
        row.bar = T.Bar(row, BAR, 3)
        row.bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -10, 8)
        row:SetScript("OnEnter", function(self)
            local e = self.item
            if not e or e.header then return end
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT", 12, 0)
            GameTooltip:AddLine(e.name)
            for _, b in ipairs(e.by) do
                GameTooltip:AddDoubleLine(ns.ColorName(b.c), Standing(b.rep, true), 1, 1, 1, 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
    end, function(row, e)
        local header = e.header ~= nil
        row.group:SetShown(header)
        row.name:SetShown(not header)
        row.by:SetShown(not header)
        row.best:SetShown(not header)
        row.bar:SetShownAll(not header)
        if header then
            row.group:SetText(e.header:upper())
            return
        end
        row.name:SetText(e.name)
        local parts = {}
        for _, b in ipairs(e.by) do table.insert(parts, ns.ColorName(b.c) .. " " .. Standing(b.rep)) end
        row.by:SetText(table.concat(parts, MUTED .. "  ·  |r"))
        local best = e.by[1].rep
        row.best:SetText(Hex(ns.StandingColor(best.r)) .. ns.StandingName(best.r) .. "|r")
        row.bar:SetFillColor(ns.StandingColor(best.r))
        row.bar:SetValue(best.max and best.max > 0 and best.cur / best.max or 1)
    end)
    view.list:SetPoint("TOPLEFT", 0, -34)
    view.list:SetPoint("BOTTOMRIGHT")

    function view:Refresh()
        local query = (self.query or ""):lower()
        local db = ns.db
        local onlyChar = self.only:Update()
        local found, recorded = {}, 0
        for _, c in ipairs(onlyChar and { onlyChar } or ns:Characters()) do
            if c.reps then recorded = recorded + 1 end
            for id, rep in pairs(c.reps or {}) do
                local f = db.factions[id]
                local name = f and f.name or ("faction " .. id)
                if query == "" or name:lower():find(query, 1, true) then
                    local e = found[id]
                    if not e then
                        e = { id = id, name = name, group = f and f.group or "", order = f and f.order or 9999, by = {} }
                        found[id] = e
                    end
                    table.insert(e.by, { c = c, rep = rep })
                end
            end
        end
        local list = {}
        for _, e in pairs(found) do
            table.sort(e.by, function(a, b)
                local sa, sb = ns.RepScore(a.rep), ns.RepScore(b.rep)
                if sa == sb then return a.c.name < b.c.name end
                return sa > sb
            end)
            table.insert(list, e)
        end
        local function GroupOrder(g) return db.groups[g] or 9999 end
        table.sort(list, function(a, b)
            if a.group ~= b.group then
                local ga, gb = GroupOrder(a.group), GroupOrder(b.group)
                if ga ~= gb then return ga < gb end
                return a.group < b.group
            end
            if a.order ~= b.order then return a.order < b.order end
            return a.name < b.name
        end)
        -- A header row above each group
        local rows, group = {}, nil
        for _, e in ipairs(list) do
            if e.group ~= group then
                group = e.group
                if group ~= "" then table.insert(rows, { header = group }) end
            end
            table.insert(rows, e)
        end
        self.hint:SetShown(#list == 0)
        if onlyChar and not onlyChar.reps then
            self.hint:SetText(onlyChar.name .. "'s reputations aren't recorded yet. Log in on them once.")
        elseif query == "" then
            self.hint:SetText("No reputations recorded yet. They're read when you log in on a character.")
        else
            self.hint:SetText("No faction matches \"" .. (self.query or "") .. "\".")
        end
        self.list:SetData(rows)
        local chars = onlyChar and 1 or #ns:Characters()
        SetFooter(#list .. " faction" .. (#list == 1 and "" or "s") .. "   ·   "
            .. (recorded < chars and ((chars - recorded) .. " character" .. (chars - recorded == 1 and "" or "s")
                .. " not recorded yet: log in on them") or "hover a faction for exact numbers"))
    end
end

---- Lockouts -------------------------------------------------------------------

-- A grid: characters down the side, every instance ever seen across the top. A cell
-- is the character's progress in that instance's current lockout, or a dash when free.

local LOCK_NAME_W, LOCK_COL_MIN = 200, 96
local KILLED, ALIVE = { 0.886, 0.369, 0.369 }, { 0.533, 0.812, 0.490 }

local function LockText(l)
    if not l then return MUTED .. "—|r" end
    if (l.total or 0) == 0 then return "saved" end
    local full = l.done >= l.total
    return (full and GOLD or "") .. l.done .. "/" .. l.total .. (full and "|r" or "")
end

local function BuildLockouts(view)
    view.heads, view.cols, view.width = {}, {}, W - PAD * 2

    local nameHead = T.Text(view, T.display, 10, C.muted)
    nameHead:SetPoint("TOPLEFT", 12, -12)
    nameHead:SetText("CHARACTER")
    local line = T.Line(view, C.border)
    line:SetPoint("TOPLEFT", 0, -34); line:SetPoint("TOPRIGHT", 0, -34)

    view.hint = T.Text(view, T.mono, 11, C.muted, "CENTER")
    view.hint:SetPoint("TOPLEFT", PAD, -120)
    view.hint:SetPoint("TOPRIGHT", -PAD, -120)
    view.hint:SetWordWrap(true)

    -- Column headers are made as instances appear: the name, and when it resets
    local function Head(i)
        local h = view.heads[i]
        if h then return h end
        h = CreateFrame("Button", nil, view)
        h:SetHeight(32)
        h.name = T.Text(h, T.display, 10, C.muted, "CENTER")
        h.name:SetPoint("TOPLEFT", 2, -3); h.name:SetPoint("TOPRIGHT", -2, -3)
        h.name:SetWordWrap(false)
        h.reset = T.Text(h, T.mono, 9, C.muted, "CENTER")
        h.reset:SetPoint("BOTTOMLEFT", 2, 3); h.reset:SetPoint("BOTTOMRIGHT", -2, 3)
        h:SetScript("OnEnter", function(self)
            local col = self.col
            if not col then return end
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(col.name)
            local info = ns.db.instances[col.name] or {}
            local what = {}
            if info.total and info.total > 0 then what[#what + 1] = info.total .. " bosses" end
            if info.players and info.players > 0 then what[#what + 1] = info.players .. " players" end
            if #what > 0 then GameTooltip:AddLine(table.concat(what, " · "), 0.588, 0.616, 0.702) end
            if col.reset then
                GameTooltip:AddDoubleLine("Resets in", ns.Duration(col.reset - time()), 0.588, 0.616, 0.702, 1, 1, 1)
            end
            GameTooltip:AddDoubleLine("Saved", col.saved .. " character" .. (col.saved == 1 and "" or "s"),
                0.588, 0.616, 0.702, 1, 1, 1)
            GameTooltip:Show()
        end)
        h:SetScript("OnLeave", GameTooltip_Hide)
        view.heads[i] = h
        return h
    end

    view.list = ns.CreateList(view, 26, function(row)
        row.name = T.Text(row, T.display, 12, C.primary)
        row.name:SetPoint("LEFT", 12, 0)
        row.name:SetWidth(LOCK_NAME_W - 18)
        row.cells = {}
        row:SetScript("OnEnter", function(self)
            local c = self.item
            if not c then return end
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT", 12, 0)
            GameTooltip:AddLine(ns.ColorName(c))
            if not c.lockoutsSeen then
                GameTooltip:AddLine("Lockouts not recorded yet: log in on this character.", 0.953, 0.663, 0.510, true)
            else
                local list = ns.Lockouts(c)
                if #list == 0 then GameTooltip:AddLine("Not saved to anything.", 0.588, 0.616, 0.702) end
                for _, l in ipairs(list) do
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddDoubleLine(l.name, LockText(l) .. MUTED .. "  resets in " .. ns.Duration(l.reset - time()) .. "|r",
                        0.890, 0.714, 0.392, 1, 1, 1)
                    for _, b in ipairs(l.bosses or {}) do
                        local col = b.killed and KILLED or ALIVE
                        GameTooltip:AddDoubleLine("   " .. b.name, b.killed and "defeated" or "available",
                            0.761, 0.784, 0.855, col[1], col[2], col[3])
                    end
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine("Recorded", ns.Ago(c.lockoutsSeen), 0.588, 0.616, 0.702, 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
    end, function(row, c)
        row.name:SetText(ns.ColorName(c) .. MUTED .. "  " .. (c.level or "?") .. "|r")
        for i, col in ipairs(view.cols) do
            local cell = row.cells[i]
            if not cell then
                cell = T.Text(row, T.mono, 11, C.primary, "CENTER")
                row.cells[i] = cell
            end
            cell:ClearAllPoints()
            cell:SetPoint("LEFT", col.x, 0)
            cell:SetWidth(col.w)
            cell:SetText(c.lockoutsSeen and LockText(ns.Lockout(c, col.name)) or (MUTED .. "?|r"))
            cell:Show()
        end
        for i = #view.cols + 1, #row.cells do row.cells[i]:Hide() end
    end)
    view.list:SetPoint("TOPLEFT", 0, -38)
    view.list:SetPoint("BOTTOMRIGHT")

    -- Share the width past the name column among the instances
    function view:Place()
        local n = #self.cols
        local w = n > 0 and math.max(LOCK_COL_MIN, math.floor((self.width - LOCK_NAME_W - 8) / n)) or 0
        for i, col in ipairs(self.cols) do
            col.x, col.w = LOCK_NAME_W + (i - 1) * w, w
            local h = Head(i)
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", col.x, 0)
            h:SetWidth(w)
            h.col = col
            h.name:SetText(col.name:upper())
            h.reset:SetText(col.reset and ("resets " .. ns.Duration(col.reset - time())) or "")
            h:Show()
        end
        for i = n + 1, #self.heads do self.heads[i]:Hide() end
        self.list:Render()
    end
    view:SetScript("OnSizeChanged", function(self, w) self.width = w; self:Place() end)

    function view:Refresh()
        local chars = ns:Characters()
        local names = {}
        for name in pairs(ns.db.instances) do names[name] = true end
        for _, c in ipairs(chars) do
            for name in pairs(c.lockouts or {}) do names[name] = true end
        end
        local cols, now = {}, time()
        for name in pairs(names) do
            local col = { name = name, saved = 0 }
            for _, c in ipairs(chars) do
                local l = ns.Lockout(c, name)
                if l then
                    col.saved = col.saved + 1
                    if not col.reset or l.reset < col.reset then col.reset = l.reset end
                end
            end
            cols[#cols + 1] = col
        end
        table.sort(cols, function(a, b) return a.name < b.name end)
        self.cols = cols

        local count, saved, recorded, soonest = {}, 0, 0, nil
        for _, c in ipairs(chars) do
            local list = ns.Lockouts(c)
            count[c] = #list
            if #list > 0 then saved = saved + 1 end
            if c.lockoutsSeen then recorded = recorded + 1 end
            for _, l in ipairs(list) do
                if l.reset > now and (not soonest or l.reset < soonest) then soonest = l.reset end
            end
        end
        table.sort(chars, function(a, b)
            if count[a] ~= count[b] then return count[a] > count[b] end
            if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
            return a.name < b.name
        end)

        self.hint:SetShown(#cols == 0)
        self.hint:SetText("No lockouts recorded yet. They're read when you log in on a character, and again after each boss kill.")
        self.list:SetData(#cols > 0 and chars or {}, true)
        self:Place()
        local foot = saved .. " of " .. #chars .. " character" .. (#chars == 1 and "" or "s") .. " saved"
        if soonest then foot = foot .. "   ·   next reset in " .. ns.Duration(soonest - now) end
        if recorded < #chars then
            foot = foot .. "   ·   " .. (#chars - recorded) .. " not recorded yet: log in on them"
        else
            foot = foot .. "   ·   hover a character for bosses"
        end
        SetFooter(foot)
    end
end

---- Talents --------------------------------------------------------------------

-- One character's three trees, redrawn from what was saved: each talent's icon at its
-- place in the grid, its rank, and arrows for prerequisites. A row of names along the
-- top picks the character; dual spec adds a pair of spec buttons. CLASS / LEGACY switches
-- between the class trees and the Legacy System's three trees (Forever's own).

local MAXED, PARTIAL = C.accent, { 0.533, 0.812, 0.490 }
local PLANNED, OPEN = { 0.471, 0.663, 0.937 }, { 0.890, 0.714, 0.392, 0.45 }

local function BuildTalents(view)
    view.pick, view.group, view.spec, view.mode = false, false, false, "class"
    view.charDrop, view.specButtons, view.panels, view.nextGlow = false, {}, {}, false

    -- Copy the loadout code: a field with the code selected, ready for Ctrl+C
    view.copy = T.TextButton(view, "COPY LOADOUT CODE", 10)
    view.copy:SetPoint("TOPRIGHT", 0, 0)
    local box = CreateFrame("EditBox", nil, view)
    view.codeBox = box
    box.code = false
    box:SetAutoFocus(false)
    box:SetFont(T.mono, 10, "")
    box:SetTextColor(C.primary[1], C.primary[2], C.primary[3])
    box:SetTextInsets(8, 8, 0, 0)
    box:SetHeight(24)
    box:SetPoint("TOPLEFT", 0, -30)
    box:SetPoint("TOPRIGHT", 0, -30)
    box:SetFrameLevel(view:GetFrameLevel() + 20)
    local cbg = box:CreateTexture(nil, "BACKGROUND"); T.Fill(cbg, C.deep); cbg:SetAllPoints()
    T.Border(box, C.accent)
    box:Hide()
    -- The box either shows text to copy (read-only: typing puts it back) or asks for some
    -- (a plan's name, a pasted plan): Enter hands it to box.onEnter, Esc cancels
    box.shown, box.onEnter = false, false
    box:SetScript("OnEscapePressed", function(self) self:Hide() end)
    box:SetScript("OnEnterPressed", function(self)
        local onEnter = self.onEnter
        self:Hide()
        if onEnter then onEnter(self:GetText()) end
    end)
    box:SetScript("OnTextChanged", function(self, user)
        if user and self.shown then self:SetText(self.shown); self:HighlightText() end
    end)
    box:SetScript("OnHide", function(self) self.shown, self.onEnter = false, false end)
    function view:ShowText(text, footer)
        box:Show()
        box.shown, box.onEnter = text, false
        box:SetText(text)
        box:SetFocus()
        box:HighlightText()
        SetFooter(footer)
    end
    function view:Ask(initial, footer, onEnter)
        box:Show()
        box.shown, box.onEnter = false, onEnter
        box:SetText(initial or "")
        box:SetFocus()
        box:HighlightText()
        SetFooter(footer)
    end
    view.copy:SetScript("OnClick", function()
        if box:IsShown() or not box.code then box:Hide(); return end
        view:ShowText(box.code, "Ctrl+C copies the code · paste it with Import in the game's talent window · Esc closes")
    end)

    view.hint = T.Text(view, T.mono, 11, C.muted, "CENTER")
    view.hint:SetPoint("TOPLEFT", PAD, -120)
    view.hint:SetPoint("TOPRIGHT", -PAD, -120)
    view.hint:SetWordWrap(true)

    -- CLASS / PLAN / LEGACY, at the right end of the top row
    view.modes = {}
    for i, m in ipairs({ { "legacy", "LEGACY" }, { "plan", "PLAN" }, { "class", "CLASS" } }) do
        local b = T.TextButton(view, m[2], 10)
        b:SetScript("OnClick", function() view.mode = m[1]; box:Hide(); view:Refresh() end)
        b:ClearAllPoints()
        if i == 1 then b:SetPoint("TOPRIGHT", 0, 0) else b:SetPoint("RIGHT", view.modes[i - 1], "LEFT", 0, 0) end
        view.modes[m[1]] = b
        view.modes[i] = b
    end
    local sep = T.Text(view, T.mono, 10, C.border)
    sep:SetPoint("RIGHT", view.modes[3], "LEFT", -2, 0)
    sep:SetText("|")
    view.copy:ClearAllPoints()
    view.copy:SetPoint("RIGHT", sep, "LEFT", -6, 0)
    view.sep = sep

    -- Plan controls: start from the character's build or from nothing, and clear
    view.clearPlan = T.TextButton(view, "CLEAR PLAN", 10)
    view.clearPlan:SetPoint("RIGHT", sep, "LEFT", -6, 0)
    view.scratch = T.TextButton(view, "FROM SCRATCH", 10)
    view.scratch:SetPoint("RIGHT", view.clearPlan, "LEFT", -2, 0)
    view.fromCurrent = T.TextButton(view, "FROM CURRENT", 10)
    view.fromCurrent:SetPoint("RIGHT", view.scratch, "LEFT", 0, 0)
    view.msg = false

    -- The plan bar, under the top row in PLAN mode: the class's plans, then what to do with them
    view.planTabs = {}
    view.planActions = {}
    for i, a in ipairs({ { "order", "LEVEL ORDER" }, { "paste", "PASTE" }, { "copy", "COPY" }, { "delete", "DELETE" }, { "rename", "RENAME" }, { "new", "+ NEW" } }) do
        local b = T.TextButton(view, a[2], 10)
        if i == 1 then b:SetPoint("TOPRIGHT", 0, -30) else b:SetPoint("RIGHT", view.planActions[i - 1], "LEFT", 0, 0) end
        view.planActions[i] = b
        view.planActions[a[1]] = b
    end
    view.planActions.order.hooked, view.planActions.order.book = false, false

    local function Panel(i)
        local p = view.panels[i]
        if p then return p end
        p = CreateFrame("Frame", nil, view)
        local bg = p:CreateTexture(nil, "BACKGROUND"); T.Fill(bg, C.raised); bg:SetAllPoints()
        T.Border(p, C.divider)
        p.icon = T.Icon(p, 18)
        p.icon:SetPoint("TOPLEFT", 10, -9)
        p.name = T.Text(p, T.display, 13, C.primary)
        p.name:SetPoint("LEFT", p.icon, "RIGHT", 8, 0)
        p.spent = T.Text(p, T.monoMedium, 13, C.accent, "RIGHT")
        p.spent:SetPoint("TOPRIGHT", -10, -10)
        p.nodes, p.lines, p.used, p.lineCount, p.left = {}, {}, 0, 0, 0
        view.panels[i] = p
        return p
    end

    local function Node(p, i)
        local b = p.nodes[i]
        if b then return b end
        b = CreateFrame("Button", nil, p)
        b.node = false
        b.edge = b:CreateTexture(nil, "BORDER")
        b.edge:SetAllPoints()
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.rank = T.Text(b, T.mono, 9, C.primary, "CENTER")
        b.rank:SetPoint("CENTER", b, "BOTTOMRIGHT", -2, 3)
        b.rankBg = b:CreateTexture(nil, "ARTWORK", nil, 2)
        T.Fill(b.rankBg, C.deep)
        b.rankBg:SetPoint("TOPLEFT", b.rank, -2, 1); b.rankBg:SetPoint("BOTTOMRIGHT", b.rank, 2, -1)
        b.index = 0
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", function(self, button)
            local plan = view.mode == "plan" and view.plan
            if not plan or not self.node then return end
            if button == "RightButton" then
                view.msg = plan:Remove(self.index, IsShiftKeyDown()) or false
            else
                view.msg = plan:Add(self.index, IsShiftKeyDown()) or false
            end
            view:Refresh()
            if self:IsMouseOver() then self:GetScript("OnEnter")(self) end
        end)
        b:SetScript("OnEnter", function(self)
            local n = self.node
            if not n then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if n.s then GameTooltip:SetSpellByID(n.s) else GameTooltip:AddLine(n.n or "?") end
            local plan = view.mode == "plan" and view.plan
            if plan then
                local r, owned = plan:Rank(self.index), plan:Floor(self.index)
                GameTooltip:AddLine("Planned rank " .. r .. " / " .. n.m .. (owned > 0 and ("  (" .. owned .. " learned)") or ""), 0.471, 0.663, 0.937)
                local levels = {}
                for _, step in ipairs(view.steps or {}) do
                    if step.key == n.s then levels[#levels + 1] = step.level end
                end
                if #levels > 0 then
                    GameTooltip:AddLine("Planned at level" .. (#levels > 1 and "s " or " ") .. table.concat(levels, ", "), 0.471, 0.663, 0.937, true)
                end
                local why = r < n.m and plan:WhyNot(self.index)
                if why then GameTooltip:AddLine(why, 0.953, 0.663, 0.510, true) end
                GameTooltip:AddLine("Click: add a point · Right-click: take one off · Shift: all ranks", 0.588, 0.616, 0.702, true)
            else
                GameTooltip:AddLine("Rank " .. n.r .. " / " .. n.m, 0.890, 0.714, 0.392)
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        b.hoverGlow = false
        T.HoverGlow(b, nil, T.TALENT_GLOW)
        p.nodes[i] = b
        return b
    end

    local function Arrow(p, i)
        local l = p.lines[i]
        if l then return l end
        l = p:CreateLine(nil, "BORDER")
        l:SetThickness(2)
        p.lines[i] = l
        return l
    end

    -- The game's positions to a grid. Forever's talent data has slips in it: a few
    -- positions are off by 10 (5740 among 5730s), so the grid step is the most common gap
    -- between neighbouring positions (not the smallest) and each position snaps to the
    -- nearest step. A few nodes sit ten times further out (102800 among 10280s): the game
    -- draws those off its canvas, out of sight, so they're left out here too (nil).
    -- Each tree is measured alone.
    local function Grid(nodes, key, tree)
        local vals = {}
        for _, node in ipairs(nodes) do if node.t == tree then vals[#vals + 1] = node[key] end end
        if #vals == 0 then return function() return 0 end end
        table.sort(vals)
        local median = vals[math.ceil(#vals / 2)]
        local function Out(v) return median > 0 and v > median * 5 end
        local list, seen = {}, {}
        for _, v in ipairs(vals) do
            if not Out(v) and not seen[v] then seen[v] = true; list[#list + 1] = v end
        end
        table.sort(list)
        local count, step, best = {}, nil, 0
        for i = 2, #list do
            local d = math.floor((list[i] - list[i - 1]) / 10 + 0.5) * 10
            if d >= 100 then
                count[d] = (count[d] or 0) + 1
                if count[d] > best or (count[d] == best and d < step) then step, best = d, count[d] end
            end
        end
        step = step or 1
        -- Neighbouring columns can be several steps apart (a gap in a tree): measure from the smallest
        local origin = list[1]
        return function(v)
            if Out(v) then return nil end
            return math.max(0, math.floor((v - origin) / step + 0.5))
        end
    end

    ---- The planner. A plan is per class, in ns.db.plans[class] = { scratch, ranks =
    ---- { spellID -> rank }, order = { spellID, … } (each point in the order it was added) }.
    ---- From current, the character's learned ranks are the floor; from scratch they're ignored.
    ---- The rules are Vanilla's: 51 points at level 60, a tier opens with 5 points per row
    ---- above it in that tree, and an arrow's talent needs the one it comes from at full rank.

    local PLAN_POINTS = 51

    local function NodeKey(node) return node.s or (node.x .. ":" .. node.y) end
    local function NodeName(node)
        return (node.s and C_Spell.GetSpellName(node.s)) or node.n or "that talent"
    end

    local function NewPlan(spec, saved, trees)
        local nodes = spec.nodes
        local need = {}  -- node index -> the indexes whose arrows lead into it
        for i, node in ipairs(nodes) do
            for _, target in ipairs(node.e or {}) do
                need[target] = need[target] or {}
                table.insert(need[target], i)
            end
        end
        local plan = { saved = saved, nodes = nodes }

        function plan:Floor(i) return saved.scratch and 0 or (nodes[i].r or 0) end
        function plan:Rank(i, over)
            if over and over[i] then return over[i] end
            return math.max(saved.ranks[NodeKey(nodes[i])] or 0, self:Floor(i))
        end
        local function Counts(over)
            local total, below = 0, {}
            for i, node in ipairs(nodes) do
                if not node.hidden then
                    local r = plan:Rank(i, over)
                    total = total + r
                    below[node.t] = below[node.t] or {}
                    below[node.t][node.row] = (below[node.t][node.row] or 0) + r
                end
            end
            return total, below
        end
        local function Below(below, t, row)
            local sum = 0
            for r2, n in pairs(below[t] or {}) do if r2 < row then sum = sum + n end end
            return sum
        end
        -- Why node i can't take another point (nil when it can)
        function plan:WhyNot(i, over)
            local node = nodes[i]
            local r = self:Rank(i, over)
            if r >= node.m then return "Already at full rank." end
            local total, below = Counts(over)
            if total >= PLAN_POINTS then return "No points left: " .. PLAN_POINTS .. " at level 60." end
            local want = node.row * 5
            if Below(below, node.t, node.row) < want then
                return "Needs " .. want .. " points in " .. ((trees[node.t] or {}).name or "this tree") .. "."
            end
            for _, from in ipairs(need[i] or {}) do
                if self:Rank(from, over) < nodes[from].m then
                    return "Needs " .. NodeName(nodes[from]) .. " at " .. nodes[from].m .. "/" .. nodes[from].m .. "."
                end
            end
        end
        -- Whether every point in the plan still stands (after a point is taken off)
        local function Holds(over)
            local _, below = Counts(over)
            for i, node in ipairs(nodes) do
                if not node.hidden and plan:Rank(i, over) > 0 then
                    if Below(below, node.t, node.row) < node.row * 5 then return false end
                    for _, from in ipairs(need[i] or {}) do
                        if plan:Rank(from, over) < nodes[from].m then return false end
                    end
                end
            end
            return true
        end
        function plan:Add(i, all)
            local why = self:WhyNot(i)
            if why then return why end
            local key = NodeKey(nodes[i])
            repeat
                saved.ranks[key] = self:Rank(i) + 1
                table.insert(saved.order, key)
            until not all or self:WhyNot(i)
        end
        function plan:Remove(i, all)
            local key = NodeKey(nodes[i])
            if self:Rank(i) <= self:Floor(i) then
                return self:Floor(i) > 0 and "Already learned: start the plan from scratch to change it." or nil
            end
            repeat
                local r = self:Rank(i) - 1
                if not Holds({ [i] = r }) then
                    return "Other planned talents need this one: take those off first."
                end
                saved.ranks[key] = r > 0 and r or nil
                for k = #saved.order, 1, -1 do
                    if saved.order[k] == key then table.remove(saved.order, k); break end
                end
            until not all or self:Rank(i) <= self:Floor(i)
        end
        function plan:Totals()
            local total, learned, per = 0, 0, {}
            for i, node in ipairs(nodes) do
                if not node.hidden then
                    local r = self:Rank(i)
                    total = total + r
                    learned = learned + math.min(r, self:Floor(i))
                    per[node.t] = (per[node.t] or 0) + r
                end
            end
            return total, learned, per
        end
        return plan
    end

    -- Lay one spec out across the view's width and height (a plan, if given, sets the ranks)
    function view:Draw(spec, plan)
        local top, gap, gridTop = plan and 62 or 34, 10, 36
        local width, height = self:GetWidth(), self:GetHeight()
        if not width or width <= 0 then width = W - PAD * 2 end
        if not height or height <= 0 then height = H - 140 end
        local trees, nodes = spec and spec.trees or {}, spec and spec.nodes or {}
        local n = #trees
        local panelW = n > 0 and math.floor((width - gap * (n - 1)) / n) or 0
        local panelH = height - top

        local colOf, rowOf = {}, {}
        for i = 1, n do colOf[i], rowOf[i] = Grid(nodes, "x", i), Grid(nodes, "y", i) end
        local cols, rows = {}, 1
        for _, node in ipairs(nodes) do
            node.col = colOf[node.t] and colOf[node.t](node.x)
            node.row = rowOf[node.t] and rowOf[node.t](node.y)
            node.hidden = not (node.col and node.row)
            node.col, node.row = node.col or 0, node.row or 0
            -- Only talents that are drawn size the grid: a hidden one can still be far out on one axis
            if not node.hidden then
                cols[node.t] = math.max(cols[node.t] or 1, node.col + 1)
                rows = math.max(rows, node.row + 1)
            end
        end
        local maxCols = 4
        for _, c in pairs(cols) do maxCols = math.max(maxCols, c) end
        -- As big as the panel allows, up to a cap so a huge window doesn't give huge icons
        local cell = math.floor(math.min((panelW - 16) / maxCols, (panelH - gridTop - 12) / rows, 104))
        local size = math.max(16, math.floor(cell * 0.78))
        local rankSize = math.max(9, math.min(13, math.floor(cell * 0.15)))
        -- Centred in the panel both ways
        local gridY = gridTop + math.max(0, math.floor((panelH - gridTop - 12 - rows * cell) / 2))

        for i = 1, math.max(n, #self.panels) do
            local p = i <= n and Panel(i) or self.panels[i]
            if i <= n then
                local tree = trees[i]
                p:ClearAllPoints()
                p:SetPoint("TOPLEFT", (i - 1) * (panelW + gap), -top)
                p:SetSize(panelW, panelH)
                if tree.atlas then p.icon:SetAtlas(tree.atlas) else p.icon:SetTexture(tree.icon) end
                p.name:SetText(tree.name)
                p.spent:SetText(tostring(tree.spent or 0))
                p.spent:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
                if plan then
                    local _, _, per = plan:Totals()
                    local planned = per[i] or 0
                    p.spent:SetText(tostring(planned))
                    local c = planned ~= (tree.spent or 0) and PLANNED or C.accent
                    p.spent:SetTextColor(c[1], c[2], c[3])
                end
                p.left = math.floor((panelW - (cols[i] or maxCols) * cell) / 2)
                p:Show()
            else
                p:Hide()
            end
            p.used, p.lineCount = 0, 0
        end
        local placed, nextShown = {}, false
        for idx, node in ipairs(nodes) do
            local p = node.t <= n and not node.hidden and self.panels[node.t]
            if p then
                p.used = p.used + 1
                local b = Node(p, p.used)
                b.node = node
                b.index = idx
                b:SetSize(size, size)
                b:ClearAllPoints()
                b:SetPoint("CENTER", p, "TOPLEFT", p.left + (node.col + 0.5) * cell, -(gridY + (node.row + 0.5) * cell))
                b.rank:SetFont(T.mono, rankSize, "")
                b.icon:SetTexture(node.i)
                local r = plan and plan:Rank(idx) or node.r
                local on = r > 0
                local col = (r >= node.m and MAXED) or (on and PARTIAL) or C.border
                -- Planned points beyond what's learned are blue; a talent that can take a point is outlined
                local open = plan and not on and not plan:WhyNot(idx)
                if plan and r > plan:Floor(idx) then col = PLANNED end
                b.icon:SetDesaturated(not on)
                b.icon:SetAlpha(on and 1 or (open and 0.8 or 0.45))
                -- The next talent to learn in the plan stands out in white
                if plan and self.nextKey and node.s == self.nextKey then
                    col, open = C.primary, false
                    self.nextGlow = self.nextGlow or T.Glow(b, self, nil, T.TALENT_GLOW)
                    self.nextGlow:SetTarget(b)
                    self.nextGlow:SetActive(true)
                    nextShown = true
                end
                T.Fill(b.edge, open and OPEN or col)
                b.rank:SetText(r .. "/" .. node.m)
                local rc = on and col or C.muted
                b.rank:SetTextColor(rc[1], rc[2], rc[3])
                b:Show()
                placed[idx] = b
            end
        end
        if self.nextGlow and not nextShown then self.nextGlow:SetActive(false) end
        -- Prerequisite arrows: gold once the talent they lead to has points
        for idx, node in ipairs(nodes) do
            local from = placed[idx]
            for _, target in ipairs(node.e or {}) do
                local to = placed[target]
                if from and to and nodes[target].t == node.t then
                    local p = self.panels[node.t]
                    p.lineCount = p.lineCount + 1
                    local l = Arrow(p, p.lineCount)
                    l:SetStartPoint("CENTER", from)
                    l:SetEndPoint("CENTER", to)
                    local lit = (plan and plan:Rank(target) or nodes[target].r) > 0
                    local c = lit and (plan and plan:Rank(target) > plan:Floor(target) and PLANNED or MAXED) or C.border
                    l:SetColorTexture(c[1], c[2], c[3], 0.9)
                    l:Show()
                end
            end
        end
        for _, p in ipairs(self.panels) do
            for i = p.used + 1, #p.nodes do p.nodes[i]:Hide(); p.nodes[i].node = false end
            for i = p.lineCount + 1, #p.lines do p.lines[i]:Hide() end
        end
    end
    view:SetScript("OnSizeChanged", function(self) if self.spec then self:Draw(self.spec) end end)

    -- The plan bar: one button per plan of the class, and NEW / RENAME / DELETE / COPY / PASTE
    function view:PlanBar(book, c)
        local names = {}
        if book then for name in pairs(book.list) do names[#names + 1] = name end end
        table.sort(names)
        local prev
        for i, name in ipairs(names) do
            local b = self.planTabs[i]
            if not b then
                b = T.TextButton(self, "", 11)
                self.planTabs[i] = b
            end
            b.text:SetText(name:upper())
            b:SetWidth(math.max(b.text:GetStringWidth(), #name * 6.8) + 20)
            b:ClearAllPoints()
            if prev then b:SetPoint("LEFT", prev, "RIGHT", 2, 0) else b:SetPoint("TOPLEFT", -8, -30) end
            b:SetSelected(name == book.active)
            b:SetScript("OnClick", function() book.active = name; self.msg = false; box:Hide(); self:Refresh() end)
            b:Show()
            prev = b
        end
        for i = #names + 1, #self.planTabs do self.planTabs[i]:Hide() end
        local acts = self.planActions
        for i = 1, #acts do acts[i]:SetShown(book ~= nil) end
        if not book then return end
        local class = c.class
        local function Ask(prompt, initial, fn) self:Ask(initial, prompt, function(text) fn(text); self:Refresh() end) end

        acts.new:SetScript("OnClick", function()
            Ask("Name the new plan, then Enter · Esc cancels", ns.NewPlanName(book), function(text)
                self.msg = ns.AddPlan(book, text, { scratch = false, ranks = {}, order = {} }) or false
            end)
        end)
        acts.rename:SetScript("OnClick", function()
            Ask("Rename \"" .. book.active .. "\", then Enter · Esc cancels", book.active, function(text)
                self.msg = ns.RenamePlan(book, book.active, text) or false
            end)
        end)
        acts.delete.armed = acts.delete.armed or false
        acts.delete.text:SetText(acts.delete.armed and "SURE?" or "DELETE")
        acts.delete:SetScript("OnClick", function(b)
            if not b.armed then
                b.armed = true
                b.text:SetText("SURE?")
                C_Timer.After(3, function() b.armed = false; b.text:SetText("DELETE") end)
                return
            end
            b.armed = false
            ns.DeletePlan(book, book.active)
            self.msg = false
            self:Refresh()
        end)
        acts.copy:SetScript("OnClick", function()
            self:ShowText(ns.ExportPlan(class, book.list[book.active]),
                "Ctrl+C copies the plan · paste it into PASTE on any account · Esc closes")
        end)
        -- The level order on hover: runs of the same talent as one line ("12-14  Improved Fireball 1-3")
        acts.order.book = book
        if not acts.order.hooked then
            acts.order.hooked = true
            acts.order:HookScript("OnEnter", function(b)
                local shown = b.book
                local steps = self.steps or {}
                GameTooltip:SetOwner(b, "ANCHOR_BOTTOMLEFT")
                GameTooltip:AddLine("Level order: " .. shown.active, 1, 1, 1)
                if #steps == 0 then
                    GameTooltip:AddLine("Nothing planned yet: click talents to add points, in the order you'll learn them.", 0.588, 0.616, 0.702, true)
                end
                local i = 1
                while i <= #steps do
                    local j = i
                    while steps[j + 1] and steps[j + 1].key == steps[i].key do j = j + 1 end
                    local a, z = steps[i], steps[j]
                    local levels = a.level == z.level and tostring(a.level) or (a.level .. "-" .. z.level)
                    local ranks = a.rank == z.rank and tostring(a.rank) or (a.rank .. "-" .. z.rank)
                    local isNext = false
                    for k = i, j do if self.nextKey == steps[k].key then isNext = true end end
                    local col = isNext and { 0.471, 0.663, 0.937 } or { 0.761, 0.784, 0.855 }
                    GameTooltip:AddDoubleLine(levels, ns.StepName(a) .. " " .. ranks, 0.890, 0.714, 0.392, col[1], col[2], col[3])
                    i = j + 1
                end
                GameTooltip:AddLine("Points are learned in the order you added them.", 0.588, 0.616, 0.702, true)
                GameTooltip:Show()
            end)
            acts.order:HookScript("OnLeave", GameTooltip_Hide)
        end
        acts.paste:SetScript("OnClick", function()
            Ask("Paste a plan (Ctrl+V), then Enter · Esc cancels", "", function(text)
                local ok, result = ns.ImportPlan(text)
                if not ok then self.msg = result; return end
                local into = ns.PlanBook(result.class)
                local name = ns.NewPlanName(into, "Pasted")
                ns.AddPlan(into, name, result.plan)
                if result.class ~= class then
                    self.msg = "Saved as \"" .. name .. "\" in the " .. (LOCALIZED_CLASS_NAMES_MALE[result.class] or result.class)
                        .. " plans: pick a character of that class to see it."
                    into.active = name
                else
                    self.msg = false
                end
            end)
        end)
    end

    function view:Refresh()
        local legacy, planning = self.mode == "legacy", self.mode == "plan"
        local function Has(c) if legacy then return c.legacy ~= nil end return c.talents ~= nil end
        self.modes.class:SetSelected(self.mode == "class")
        self.modes.plan:SetSelected(planning)
        self.modes.legacy:SetSelected(legacy)

        local chars, recorded = {}, 0
        for _, c in ipairs(ns:Characters()) do
            if Has(c) then chars[#chars + 1] = c; recorded = recorded + 1 end
        end
        table.sort(chars, function(a, b)
            if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
            return a.name < b.name
        end)
        local c = self.pick and ns.db.chars[self.pick]
        if not (c and Has(c)) then
            c = (ns.me and Has(ns.me) and ns.me) or chars[1]
            if c then self.pick = c.key end
            self.group = false
        end

        -- The character picker
        if not self.charDrop then
            self.charDrop = ns.CharDropdown(self, function(entry)
                self.pick, self.group = entry.key, false
                box:Hide()
                self:Refresh()
            end)
            self.charDrop:SetPoint("TOPLEFT", 0, 0)
        end
        self.charDrop:SetChoices(ns.CharChoices(chars), c and c.key)
        self.charDrop:SetShown(c and true or false)

        local t = c and not legacy and c.talents
        -- A plan is drawn on the active spec's trees
        local group = (not planning and self.group and t and t.specs[self.group]) and self.group or (t and t.active) or 1
        local spec
        if legacy then spec = c and c.legacy or false else spec = t and t.specs[group] or false end
        self.spec = spec

        -- Dual spec: a button per spec, beside the copy button
        local dual = t and t.specs[1] and t.specs[2] and true or false
        for g = 1, 2 do
            local b = self.specButtons[g]
            if not b then
                b = T.TextButton(self, g == 1 and "PRIMARY" or "SECONDARY", 10)
                b:SetScript("OnClick", function() self.group = g; box:Hide(); self:Refresh() end)
                self.specButtons[g] = b
            end
            b:SetShown(dual and not planning)
            b:SetSelected(g == group)
        end
        box.code = (not legacy and not planning and spec and spec.code) or false
        self.copy:SetShown(box.code and true or false)
        self.specButtons[2]:ClearAllPoints()
        self.specButtons[2]:SetPoint("RIGHT", box.code and self.copy or self.sep, "LEFT", -12, 0)
        self.specButtons[1]:ClearAllPoints()
        self.specButtons[1]:SetPoint("RIGHT", self.specButtons[2], "LEFT", 0, 0)

        self.hint:SetShown(not spec)
        if legacy and not c then
            self.hint:SetText("No Legacy trees recorded yet. They're read when you log in on a character with the Legacy System open "
                .. "(Legacy renown 1 or more), and whenever you change them.")
        elseif not c then
            self.hint:SetText("No talents recorded yet. They're read when you log in on a character, and whenever you change them.")
        elseif not spec then
            self.hint:SetText(c.name .. " has no talents to show yet.")
        end
        -- The class's plans (named, kept across sessions) and the one being edited
        local plan, book = false, nil
        if planning and spec and c.class then
            book = ns.PlanBook(c.class)
            plan = NewPlan(spec, book.list[book.active], spec.trees)
        end
        self.plan = plan
        self.steps = plan and ns.PlanSteps(plan.saved, spec) or false
        local nextStep = plan and ns.NextStep(plan.saved, spec)
        self.nextKey = nextStep and nextStep.key or false
        if plan and ns.GameTalentGlow then ns.GameTalentGlow() end
        for _, b in ipairs({ self.clearPlan, self.scratch, self.fromCurrent }) do b:SetShown(plan and true or false) end
        self:PlanBar(book, c)
        if box:IsShown() then
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", 0, plan and -58 or -30)
            box:SetPoint("TOPRIGHT", 0, plan and -58 or -30)
        end
        if plan then
            self.scratch:SetSelected(plan.saved.scratch)
            self.fromCurrent:SetSelected(not plan.saved.scratch)
            local saved = plan.saved
            self.scratch:SetScript("OnClick", function() saved.scratch = true; self.msg = false; self:Refresh() end)
            self.fromCurrent:SetScript("OnClick", function() saved.scratch = false; self.msg = false; self:Refresh() end)
            self.clearPlan:SetScript("OnClick", function()
                saved.ranks, saved.order = {}, {}
                self.msg = false
                self:Refresh()
            end)
        end

        self:Draw(spec, plan)
        -- Opening the window lays it out after this runs, so the first draw can be sized
        -- for a fallback height: draw again once the real size is known
        C_Timer.After(0, function()
            if self:IsShown() and self.spec == spec and spec then self:Draw(spec, self.plan) end
        end)
        if not box:IsShown() then
            local foot = {}
            if self.msg then foot[#foot + 1] = "|cfff3a982" .. self.msg .. "|r" end
            if c and spec and plan then
                local total, learned, per = plan:Totals()
                local points = {}
                for i = 1, #spec.trees do points[i] = per[i] or 0 end
                local class = LOCALIZED_CLASS_NAMES_MALE[c.class] or c.class
                foot[#foot + 1] = class .. " plan   ·   " .. table.concat(points, "/")
                foot[#foot + 1] = (plan.saved.scratch and "" or (learned .. " learned + ")) .. (total - learned) .. " planned = "
                    .. total .. " of " .. PLAN_POINTS
                if total > 0 then foot[#foot + 1] = "level " .. (total + 9) end
                local step = ns.NextStep(plan.saved, spec)
                if step then foot[#foot + 1] = "next: " .. ns.StepName(step) .. " " .. step.rank end
            elseif c and spec and legacy then
                local parts = {}
                for _, tree in ipairs(spec.trees) do parts[#parts + 1] = tree.name .. " " .. (tree.spent or 0) end
                foot[#foot + 1] = c.name .. "   ·   Legacy " .. table.concat(parts, ", ")
                foot[#foot + 1] = (spec.unspent or 0) .. " Legacy point" .. (spec.unspent == 1 and "" or "s") .. " to spend"
                if spec.renown then foot[#foot + 1] = "renown " .. spec.renown end
                foot[#foot + 1] = "recorded " .. ns.Ago(spec.seen)
            elseif c and spec then
                local points, top = ns.SpecSummary(spec)
                foot[#foot + 1] = c.name .. "   ·   " .. (top and (top .. " ") or "") .. points
                if (spec.unspent or 0) > 0 then foot[#foot + 1] = spec.unspent .. " unspent" end
                if dual then foot[#foot + 1] = (group == t.active and "active spec" or "other spec") end
                foot[#foot + 1] = "recorded " .. ns.Ago(t.seen)
            end
            local missing = #ns:Characters() - recorded
            if missing > 0 and not planning then
                foot[#foot + 1] = missing .. (legacy and " without Legacy trees recorded" or " not recorded yet: log in on them")
            end
            SetFooter(table.concat(foot, "   ·   "))
        end
    end
end

---- The window -----------------------------------------------------------------

---- Armory: one character's gear on a paperdoll, the way the Armory site lays it out.
---- Gear slots down both sides and weapons along the bottom; between them the live model
---- for the character you're on (addons can't rebuild another character's looks), or the
---- race and class crest for an alt; the character sheet's stats in a panel on the right.

local SLOT_ART = "Interface\\PaperDoll\\UI-PaperDoll-Slot-"
local LEFT_SLOTS = {
    { 1, "Head", "Head" }, { 2, "Neck", "Neck" }, { 3, "Shoulder", "Shoulders" }, { 15, "Chest", "Back" },
    { 5, "Chest", "Chest" }, { 4, "Shirt", "Shirt" }, { 19, "Tabard", "Tabard" }, { 9, "Wrists", "Wrists" },
}
local RIGHT_SLOTS = {
    { 10, "Hands", "Hands" }, { 6, "Waist", "Waist" }, { 7, "Legs", "Legs" }, { 8, "Feet", "Feet" },
    { 11, "Finger", "Ring" }, { 12, "Finger", "Ring" }, { 13, "Trinket", "Trinket" }, { 14, "Trinket", "Trinket" },
}
local WEAPON_SLOTS = { { 16, "MainHand", "Main hand" }, { 17, "SecondaryHand", "Off hand" }, { 18, "Ranged", "Ranged" }, { 0, "Ammo", "Ammo" } }
local SLOT_SIZE, SLOT_STEP, SIDE_W, STATS_W = 40, 46, 236, 214

local function BuildArmory(view)
    view.pick = false
    view.drop = ns.CharDropdown(view, function(entry)
        view.pick = entry.key
        view:Refresh()
    end)
    view.drop:SetPoint("TOPLEFT", 0, 0)
    view.summary = T.Text(view, T.mono, 11, C.secondary, "RIGHT")
    view.summary:SetPoint("TOPRIGHT", 0, -6)
    view.summary:SetPoint("LEFT", view.drop, "RIGHT", 20, 0)

    -- One gear slot: the icon (or the empty-slot art), the item's name and level beside it
    local function Slot(def, side)
        local b = CreateFrame("Button", nil, view)
        b:SetSize(SLOT_SIZE, SLOT_SIZE)
        b.slot, b.art, b.label, b.link = def[1], SLOT_ART .. def[2], def[3], false
        local bg = b:CreateTexture(nil, "BACKGROUND"); T.Fill(bg, C.deep); bg:SetAllPoints()
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 1, -1); b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        b.edges = {}
        for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", false }, { "BOTTOMLEFT", "BOTTOMRIGHT", false },
                             { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true } }) do
            local t = b:CreateTexture(nil, "OVERLAY")
            t:SetPoint(e[1]); t:SetPoint(e[2])
            if e[3] then t:SetWidth(1) else t:SetHeight(1) end
            b.edges[#b.edges + 1] = t
        end
        b.name, b.sub = false, false  -- the weapons have no labels: their tooltip says it
        if side then
            b.name = T.Text(view, T.display, 12, C.primary, side == "left" and "LEFT" or "RIGHT")
            b.sub = T.Text(view, T.mono, 10, C.muted, side == "left" and "LEFT" or "RIGHT")
            if side == "left" then
                b.name:SetPoint("TOPLEFT", b, "TOPRIGHT", 10, -3)
                b.sub:SetPoint("BOTTOMLEFT", b, "BOTTOMRIGHT", 10, 3)
            else
                b.name:SetPoint("TOPRIGHT", b, "TOPLEFT", -10, -3)
                b.sub:SetPoint("BOTTOMRIGHT", b, "BOTTOMLEFT", -10, 3)
            end
            b.name:SetWidth(SIDE_W - SLOT_SIZE - 14)
            b.sub:SetWidth(SIDE_W - SLOT_SIZE - 14)
        end
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.link then GameTooltip:SetHyperlink(self.link)
            elseif self.itemID then GameTooltip:SetItemByID(self.itemID)
            else GameTooltip:AddLine(self.label, 0.588, 0.616, 0.702) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        b:SetScript("OnClick", function(self) if self.link then HandleModifiedItemClick(self.link) end end)
        b.itemID = false
        b.hoverGlow = false
        T.HoverGlow(b)
        return b
    end

    view.slots = {}
    for i, def in ipairs(LEFT_SLOTS) do
        local b = Slot(def, "left")
        b:SetPoint("TOPLEFT", 0, -40 - (i - 1) * SLOT_STEP)
        view.slots[#view.slots + 1] = b
    end
    -- The stats panel on the far right, the right-hand slots just inside it
    view.stats = CreateFrame("Frame", nil, view)
    view.stats:SetPoint("TOPRIGHT", 0, -40)
    view.stats:SetPoint("BOTTOMRIGHT", 0, 0)
    view.stats:SetWidth(STATS_W)
    local sbg = view.stats:CreateTexture(nil, "BACKGROUND"); T.Fill(sbg, C.raised); sbg:SetAllPoints()
    T.Border(view.stats, C.divider)
    view.stats.lines = {}
    for i, def in ipairs(RIGHT_SLOTS) do
        local b = Slot(def, "right")
        b:SetPoint("TOPRIGHT", view.stats, "TOPLEFT", -16, -(i - 1) * SLOT_STEP)
        view.slots[#view.slots + 1] = b
    end

    -- The middle: name and title on top, the model or crest, the weapons below
    local mid = CreateFrame("Frame", nil, view)
    mid:SetPoint("TOPLEFT", SIDE_W + 8, -40)
    mid:SetPoint("BOTTOMRIGHT", view.stats, "BOTTOMLEFT", -(SIDE_W + 24), 0)
    view.mid = mid
    view.title = T.Text(mid, T.display, 20, C.primary, "CENTER")
    view.title:SetPoint("TOPLEFT", 0, -2)
    view.title:SetPoint("TOPRIGHT", 0, -2)
    view.line2 = T.Text(mid, T.mono, 11, C.secondary, "CENTER")
    view.line2:SetPoint("TOPLEFT", view.title, "BOTTOMLEFT", 0, -6)
    view.line2:SetPoint("TOPRIGHT", view.title, "BOTTOMRIGHT", 0, -6)
    view.line3 = T.Text(mid, T.mono, 11, C.accent, "CENTER")
    view.line3:SetPoint("TOPLEFT", view.line2, "BOTTOMLEFT", 0, -4)
    view.line3:SetPoint("TOPRIGHT", view.line2, "BOTTOMRIGHT", 0, -4)

    view.weapons = {}
    for i, def in ipairs(WEAPON_SLOTS) do
        local b = Slot(def)
        b:SetPoint("BOTTOM", mid, "BOTTOM", (i - 2.5) * SLOT_STEP, 6)
        view.weapons[i] = b
        view.slots[#view.slots + 1] = b
    end

    -- The live model: only ever the character you're logged in on
    local model = CreateFrame("PlayerModel", nil, mid)
    model:SetPoint("TOPLEFT", 0, -62)
    model:SetPoint("BOTTOMRIGHT", 0, SLOT_SIZE + 16)
    model:EnableMouse(true)
    model.facing, model.dragX, model.loaded = 0, false, false
    model:SetScript("OnMouseDown", function(self) self.dragX = (GetCursorPosition()) end)
    model:SetScript("OnMouseUp", function(self) self.dragX = false end)
    model:SetScript("OnUpdate", function(self)
        if not self.dragX then return end
        if not IsMouseButtonDown("LeftButton") then self.dragX = false; return end
        local x = GetCursorPosition()
        self.facing = self.facing + (x - self.dragX) * 0.012
        self.dragX = x
        self:SetFacing(self.facing)
    end)
    model:Hide()
    view.model = model
    view.modelHint = T.Text(mid, T.mono, 10, C.muted, "CENTER")
    view.modelHint:SetPoint("BOTTOM", model, "BOTTOM", 0, 4)

    -- An alt: their race crest, the class crest on its corner
    view.crest = mid:CreateTexture(nil, "ARTWORK")
    view.crest:SetSize(128, 128)
    view.crest:SetPoint("CENTER", model, "CENTER", 0, 10)
    -- An alt with an Armory picture (the ForeverAlts_Renders data addon, filled by tools/renders.py)
    view.render = mid:CreateTexture(nil, "ARTWORK")
    view.render:SetPoint("BOTTOM", model, "BOTTOM", 0, 18)
    view.render:Hide()
    view.classCrest = mid:CreateTexture(nil, "OVERLAY")
    view.classCrest:SetSize(44, 44)
    view.classCrest:SetPoint("CENTER", view.crest, "BOTTOMRIGHT", -14, 14)
    view:HookScript("OnHide", function() model:ClearModel(); model.loaded = false end)
    -- Gear or shape changed: load the model again next time it's drawn
    ns:On("UNIT_MODEL_CHANGED", function(unit) if unit == "player" then model.loaded = false end end)
    ns:On("PLAYER_EQUIPMENT_CHANGED", function() model.loaded = false end)

    view.stats.hint = T.Text(view.stats, T.mono, 10, C.place)
    view.stats.hint:SetPoint("TOPLEFT", 12, -10)
    view.stats.hint:SetPoint("TOPRIGHT", -12, -10)
    view.stats.hint:SetWordWrap(true)

    local function StatLine(i)
        local l = view.stats.lines[i]
        if l then return l end
        l = {}
        l.label = T.Text(view.stats, T.mono, 11, C.muted)
        l.value = T.Text(view.stats, T.monoMedium, 11, C.primary, "RIGHT")
        l.label:SetPoint("TOPLEFT", 12, -10 - (i - 1) * 17)
        l.value:SetPoint("TOPRIGHT", -12, -10 - (i - 1) * 17)
        view.stats.lines[i] = l
        return l
    end

    local function Pct(v) return v and string.format("%.2f%%", v) or "—" end
    local function N(v) return v and ns.Commas(v) or "—" end
    local POWER = { MANA = "Mana" }

    local function StatRows(c)
        local st = c.stats
        if not st then return nil end
        local rows = {
            { head = "ATTRIBUTES" },
            { "Strength", N(st[1]) }, { "Agility", N(st[2]) }, { "Stamina", N(st[3]) },
            { "Intellect", N(st[4]) }, { "Spirit", N(st[5]) },
            { head = "DEFENSE" },
            { "Health", N(st.hp) }, { "Armor", N(st.armor) },
            { "Dodge", Pct(st.dodge) }, { "Parry", Pct(st.parry) }, { "Block", Pct(st.block) },
            { head = "OFFENSE" },
            { "Attack power", N(st.ap) }, { "Melee crit", Pct(st.crit) },
            { "Ranged AP", N(st.rap) }, { "Ranged crit", Pct(st.rcrit) },
            { "Spell damage", N(st.spell) }, { "Healing", N(st.heal) }, { "Spell crit", Pct(st.scrit) },
        }
        -- Mana only: rage and energy always top out at 100
        if st.power and st.powerType == "MANA" then
            table.insert(rows, 9, { POWER[st.powerType], N(st.power) })
        end
        local res = {}
        for school, label in pairs({ [2] = "Fire", [3] = "Nature", [4] = "Frost", [5] = "Shadow", [6] = "Arcane" }) do
            if st.res and (st.res[school] or 0) > 0 then res[#res + 1] = { school, label .. " resist", N(st.res[school]) } end
        end
        table.sort(res, function(a, b) return a[1] < b[1] end)
        if #res > 0 then
            rows[#rows + 1] = { head = "RESISTANCE" }
            for _, r in ipairs(res) do rows[#rows + 1] = { r[2], r[3] } end
        end
        return rows
    end

    function view:Refresh()
        local chars = ns:Characters()
        table.sort(chars, function(a, b)
            if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
            return a.name < b.name
        end)
        local c = self.pick and ns.db.chars[self.pick]
        if not c then c = ns.me or chars[1]; self.pick = c and c.key or false end
        self.drop:SetChoices(ns.CharChoices(chars), self.pick)
        if not c then return end

        -- Gear
        local gear = c.gear or {}
        for _, b in ipairs(self.slots) do
            local v = gear[b.slot]
            local link = type(v) == "string" and v or nil
            local id = (type(v) == "number" and v) or (link and tonumber(link:match("item:(%d+)"))) or nil
            b.link, b.itemID = link or false, id or false
            local col = C.border
            if id then
                local name, quality, icon, known = ItemInfo(id)
                b.link = b.link or known or false
                b.icon:SetTexture(icon or 134400)
                b.icon:SetDesaturated(false); b.icon:SetAlpha(1)
                b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                local linkName = link and link:match("%[(.-)%]")
                name = (linkName and linkName ~= "" and linkName) or name or ("item " .. id)
                if (quality or 1) >= 2 then
                    local r, g, bl = C_Item.GetItemQualityColor(quality)
                    if type(r) == "number" then col = { r, g, bl, 0.9 } end
                end
                if b.name then
                    b.name:SetText(QualityHex(quality) .. name .. "|r")
                    local ilvl = b.link and C_Item.GetDetailedItemLevelInfo(b.link)
                    b.sub:SetText(b.label .. (type(ilvl) == "number" and ilvl > 0 and ("  ·  ilvl " .. ilvl) or ""))
                end
            else
                b.icon:SetTexture(b.art)
                b.icon:SetTexCoord(0, 1, 0, 1)
                b.icon:SetDesaturated(true); b.icon:SetAlpha(0.45)
                if b.name then b.name:SetText(MUTED .. b.label .. "|r"); b.sub:SetText("") end
            end
            for _, t in ipairs(b.edges) do T.Fill(t, col) end
        end

        -- Who
        self.title:SetText(ns.ColorName(c))
        local class = LOCALIZED_CLASS_NAMES_MALE[c.class] or c.class or ""
        self.line2:SetText("Level " .. (c.level or "?") .. "  " .. (c.race or "") .. " " .. class)
        self.line3:SetText(c.guild and ("<" .. c.guild .. ">" .. (c.guildRank and ("  " .. MUTED .. c.guildRank .. "|r") or "")) or "")

        local live = c == ns.me
        self.model:SetShown(live)
        if live and not self.model.loaded then
            self.model:SetUnit("player")
            self.model:SetPortraitZoom(0)
            self.model:SetFacing(self.model.facing)
            self.model.loaded = true
        end
        if live then
            self.modelHint:SetText("drag to turn")
        else
            self.modelHint:SetText("The model shows for the character you're logged in on")
        end
        -- An alt's Armory picture, when the data addon has one: it takes the crest's place
        local render = not live and ForeverAltsRenders and c.name and ForeverAltsRenders[c.name:lower()]
        self.render:SetShown(render and true or false)
        if render then
            local mw, mh = self.model:GetWidth(), self.model:GetHeight()
            local size = math.floor(math.min((mw and mw > 0) and mw or 280, ((mh and mh > 0) and mh or 280) - 18))
            self.render:SetSize(size, size)
            self.render:SetTexture("Interface\\AddOns\\ForeverAlts_Renders\\renders\\" .. render.file .. ".tga")
            self.modelHint:SetText("Armory picture, " .. ns.Ago(render.updated))
        end

        -- The race crest needs the race and the sex (its face is a man's or a woman's): both are
        -- saved at login, so an alt not logged in since gets the class crest alone, large
        local race = c.raceFile or (c.race and c.race:gsub("%s+", ""))
        local raceAtlas = race and c.sex and GetRaceAtlas(race:lower(), c.sex == 3 and "female" or "male", true)
        local hasRace = raceAtlas and C_Texture.GetAtlasInfo(raceAtlas) ~= nil
        self.crest:SetShown(not live and not render and hasRace)
        if hasRace then self.crest:SetAtlas(raceAtlas) end
        -- The class crest: Blizzard's round class icons, as their portrait frames use
        local coords = c.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[c.class]
        self.classCrest:SetShown(not live and not render and coords ~= nil)
        if coords then
            self.classCrest:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
            self.classCrest:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            self.classCrest:ClearAllPoints()
            if hasRace then
                self.classCrest:SetSize(48, 48)
                self.classCrest:SetPoint("CENTER", self.crest, "BOTTOMRIGHT", -12, 12)
            else
                self.classCrest:SetSize(128, 128)
                self.classCrest:SetPoint("CENTER", self.crest)
            end
        end

        -- Summary across the top
        local bits = {}
        if c.ilvl then bits[#bits + 1] = "item level " .. GOLD .. c.ilvl .. "|r" end
        bits[#bits + 1] = ns.Money(c.money or 0, true)
        local played = ns.Played(c)
        if played then bits[#bits + 1] = ns.Duration(played) .. " played" end
        local summary = ns.SpecSummary(ns.ActiveSpec(c))
        if summary then bits[#bits + 1] = "talents " .. summary end
        self.summary:SetText(table.concat(bits, MUTED .. "   ·   |r"))

        -- Stats
        local rows = StatRows(c)
        local used = 0
        if rows then
            for _, r in ipairs(rows) do
                used = used + 1
                local l = StatLine(used)
                if r.head then
                    l.label:SetText(r.head); l.label:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
                    l.label:SetFont(T.display, 11, ""); l.value:SetText("")
                else
                    l.label:SetText(r[1]); l.label:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
                    l.label:SetFont(T.mono, 11, ""); l.value:SetText(r[2])
                end
                l.label:Show(); l.value:Show()
            end
        end
        self.stats.hint:SetShown(not rows)
        self.stats.hint:SetText("Stats are recorded at login: log in on " .. c.name .. " once.")
        for i = used + 1, #self.stats.lines do self.stats.lines[i].label:Hide(); self.stats.lines[i].value:Hide() end

        SetFooter(c.name .. (c.stats and c.stats.seen and ("   ·   stats " .. (live and "live" or ("as of " .. ns.Ago(c.stats.seen)))) or "")
            .. (c.lastSeen and not live and ("   ·   gear as of " .. ns.Ago(c.lastSeen)) or "")
            .. "   ·   Shift-click links an item in chat")
    end
end

local TABS_DEF = {
    { key = "chars", label = "CHARACTERS",  build = BuildCharacters },
    { key = "items", label = "ITEMS",       build = BuildItems },
    { key = "profs", label = "PROFESSIONS", build = BuildProfessions },
    { key = "reps",  label = "REPUTATION",  build = BuildReputation },
    { key = "locks", label = "LOCKOUTS",    build = BuildLockouts },
    { key = "talents", label = "TALENTS",   build = BuildTalents },
    { key = "armory",  label = "ARMORY",    build = BuildArmory },
}

local function Select(key)
    current = key
    for _, t in ipairs(TABS_DEF) do
        local v = views[t.key]
        v:SetShown(t.key == key)
        v.tab:SetSelected(t.key == key)
    end
    views[key]:Refresh()
end

local function SavePosition()
    local point, _, relPoint, x, y = frame:GetPoint()
    ns.db.point = { point, relPoint, x, y }
end

function ns.ResetPosition()
    if not frame then return end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER")
    frame:SetSize(W, H)
end

local function Build()
    frame = CreateFrame("Frame", "ForeverAltsFrame", UIParent)
    local size = ns.db.size
    -- A size saved before a new column raised the minimum grows to fit it
    frame:SetSize(math.max(MIN_W, size and size[1] or W), math.max(MIN_H, size and size[2] or H))
    frame:SetResizable(true)
    frame:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    local p = ns.db.point
    if p then frame:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else frame:SetPoint("CENTER") end
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePosition() end)
    table.insert(UISpecialFrames, "ForeverAltsFrame")  -- Escape closes it

    local bg = frame:CreateTexture(nil, "BACKGROUND"); T.Fill(bg, C.bg); bg:SetAllPoints()
    local head = frame:CreateTexture(nil, "BACKGROUND", nil, 1); T.Fill(head, C.deep)
    head:SetPoint("TOPLEFT"); head:SetPoint("TOPRIGHT"); head:SetHeight(HEAD)
    local foot = frame:CreateTexture(nil, "BACKGROUND", nil, 1); T.Fill(foot, C.deep)
    foot:SetPoint("BOTTOMLEFT"); foot:SetPoint("BOTTOMRIGHT"); foot:SetHeight(FOOT)
    T.Border(frame)
    T.GoldLine(frame, -HEAD)
    local footLine = T.Line(frame, C.border)
    footLine:SetPoint("BOTTOMLEFT", 0, FOOT); footLine:SetPoint("BOTTOMRIGHT", 0, FOOT)

    -- Header: gold dot, name, a chip, the close button
    local dot = T.Dot(frame, 8)
    dot:SetPoint("LEFT", frame, "TOPLEFT", PAD, -HEAD / 2)
    local title = T.Text(frame, T.display, 15, C.primary)
    title:SetPoint("LEFT", dot, "RIGHT", 9, 0)
    title:SetText("Forever Alts")
    local chip = T.Chip(frame)
    chip:SetPoint("LEFT", title, "RIGHT", 14, 0)
    chip:SetText("WOW FOREVER")

    local close = CreateFrame("Button", nil, frame)
    close:SetSize(28, 28)
    close:SetPoint("RIGHT", frame, "TOPRIGHT", -8, -HEAD / 2)
    close.text = T.Text(close, T.displayLight, 20, C.muted, "CENTER")
    close.text:SetPoint("CENTER", 0, 1)
    close.text:SetText("×")
    close:SetScript("OnEnter", function(self) self.text:SetTextColor(C.primary[1], C.primary[2], C.primary[3]) end)
    close:SetScript("OnLeave", function(self) self.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    close:SetScript("OnClick", function() frame:Hide() end)
    close.hoverGlow = false
    T.HoverGlow(close, { 3, 3 })

    -- Tabs, with a gold underline on the selected one
    local tabLine = T.Line(frame, C.divider)
    tabLine:SetPoint("TOPLEFT", 0, -(HEAD + TABS)); tabLine:SetPoint("TOPRIGHT", 0, -(HEAD + TABS))
    local prev
    for _, t in ipairs(TABS_DEF) do
        local b = T.TextButton(frame, t.label, 11)
        b:SetHeight(TABS)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", PAD - 8, -HEAD) end
        b.underline = b:CreateTexture(nil, "ARTWORK")
        T.Fill(b.underline, C.accent)
        b.underline:SetHeight(2)
        b.underline:SetPoint("BOTTOMLEFT", 8, 0); b.underline:SetPoint("BOTTOMRIGHT", -8, 0)
        b:SetScript("OnClick", function() Select(t.key) end)
        b.glowInset = { 2, 7 }  -- a box around the label, clear of the underline
        -- The open tab keeps glowing; the others glow only under the pointer
        b.keepGlow = function(self) return self.selected end
        local SetSelected = b.SetSelected
        b.SetSelected = function(self, on)
            SetSelected(self, on)
            if on then
                self.hoverGlow = self.hoverGlow or T.Glow(self, nil, self.glowInset)
                self.hoverGlow:SetActive(true)
            elseif self.hoverGlow and not self:IsMouseOver() then
                self.hoverGlow:SetActive(false)
            end
        end

        local v = CreateFrame("Frame", nil, frame)
        v:SetPoint("TOPLEFT", PAD, -(HEAD + TABS + 12))
        v:SetPoint("BOTTOMRIGHT", -PAD, FOOT + 8)
        v.tab = b
        t.build(v)
        v:Hide()
        views[t.key] = v
        prev = b
    end

    -- Resize grip in the bottom-right corner: Blizzard's chat-window grabber, tinted gold
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(frame:GetFrameLevel() + 10)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:GetNormalTexture():SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.8)
    grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        ns.db.size = { math.floor(frame:GetWidth() + 0.5), math.floor(frame:GetHeight() + 0.5) }
        SavePosition()  -- sizing re-anchors the frame; keep where it ended up
    end)

    local version = T.Text(frame, T.mono, 10, C.muted, "RIGHT")
    version:SetPoint("RIGHT", frame, "BOTTOMRIGHT", -PAD - 14, FOOT / 2)
    version:SetText("v" .. (C_AddOns.GetAddOnMetadata(ns.name, "Version") or "?") .. "   /alts")
    -- The footer stops short of the version: a narrow window cuts it with "…", and
    -- hovering shows the whole line
    frame.footer = T.Text(frame, T.mono, 10, C.muted)
    frame.footer:SetPoint("LEFT", frame, "BOTTOMLEFT", PAD, FOOT / 2)
    frame.footer:SetPoint("RIGHT", version, "LEFT", -24, 0)
    local footHover = CreateFrame("Frame", nil, frame)
    footHover:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, FOOT)
    footHover:SetPoint("BOTTOMRIGHT", version, "BOTTOMLEFT", -24, -8)
    -- Hover only: clicks fall through, so the footer still drags the window
    if footHover.EnableMouseMotion then footHover:EnableMouseMotion(true) end
    footHover:SetScript("OnEnter", function(self)
        local fs = frame.footer
        if not (fs.IsTruncated and fs:IsTruncated()) then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(fs:GetText(), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    footHover:SetScript("OnLeave", GameTooltip_Hide)

    -- The fonts are surely loaded once the window is on screen: size the tabs to their labels
    local function FitTabs()
        for _, t in ipairs(TABS_DEF) do views[t.key].tab:Fit() end
    end
    frame:SetScript("OnShow", function()
        FitTabs()
        C_Timer.After(0, FitTabs)
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        if current then views[current]:Refresh() end
    end)
    frame:SetScript("OnHide", function() PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE) end)
    -- Played time, "seen" and reset countdowns tick while the window is open
    local elapsed = 0
    frame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed > 30 and (current == "chars" or current == "locks") then elapsed = 0; views[current]:Refresh() end
    end)
end

-- view: "chars" | "items" | "profs" | "reps" | "locks" | "talents"; query fills its search box; onlyKey (a character
-- key, or false to clear) filters Items and Reputation to one character, and stays set across tabs
function ns.ShowUI(view, query, onlyKey)
    if not ns.me then return end
    if not frame then Build() end
    frame:Show()
    view = view or current or "chars"
    local v = views[view]
    if onlyKey ~= nil then filterKey = onlyKey or nil end
    if v.search and query then
        v.search:SetText(query)  -- OnTextChanged refreshes
    end
    Select(view)
end

-- The Talents tab, showing one character (a key; nil keeps the current pick), on the
-- class trees or the Legacy trees (mode "class" | "legacy"; nil keeps the current one)
function ns.ShowTalents(key, mode)
    if not ns.me then return end
    if not frame then Build() end
    if key then views.talents.pick, views.talents.group = key, false end
    if mode then views.talents.mode = mode end
    ns.ShowUI("talents")
end

function ns.ShowArmory(key)
    if not ns.me then return end
    if not frame then Build() end
    if key then views.armory.pick = key end
    ns.ShowUI("armory")
end

function ns.ToggleUI()
    if frame and frame:IsShown() then frame:Hide() else ns.ShowUI() end
end

function ns.RefreshUI()
    if not frame or not frame:IsShown() or not current then return end
    ns:Debounce("ui", 0.2, function()
        if frame:IsShown() then views[current]:Refresh() end
    end)
end
