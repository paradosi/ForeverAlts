---- UI — the window: Characters, Items and Professions views

local _, ns = ...
local T = ns.T
local C = T.C
local PAD = T.PAD

local W, H = 900, 520
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
        root:CreateTitle(c.name .. " · " .. c.realm)
        root:CreateButton("Browse items", function() ns.ShowUI("items", "", c.key) end)
        root:CreateButton("Forget this character", function()
            StaticPopupDialogs.FOREVERALTS_FORGET = forgetDialog
            StaticPopup_Show("FOREVERALTS_FORGET", c.name, nil, c.key)
        end)
    end)
end

local function BuildCharacters(view)
    local x = 0
    view.headers = {}
    for _, col in ipairs(COLUMNS) do
        local h = CreateFrame("Button", nil, view)
        h:SetSize(col.width, 20)
        h:SetPoint("TOPLEFT", x, 0)
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
        col.x = x
        x = x + col.width
    end
    local line = T.Line(view, C.border)
    line:SetPoint("TOPLEFT", 0, -20); line:SetPoint("TOPRIGHT", 0, -20)

    view.list = ns.CreateList(view, 26, function(row)
        row.cells = {}
        for i, col in ipairs(COLUMNS) do
            local fs = T.Text(row, i == 1 and T.display or T.mono, i == 1 and 12 or 11, C.primary, col.justify)
            fs:SetPoint("LEFT", col.x + 6, 0)
            fs:SetWidth(col.width - 12)
            row.cells[i] = fs
        end
        row.dot = T.Dot(row, 5)
        row.dot:SetPoint("LEFT", COLUMNS[1].x + 4, 0)
        row.cells[1]:SetPoint("LEFT", COLUMNS[1].x + 12, 0)
        row:SetScript("OnClick", function(self, button)
            if button == "RightButton" then CharacterMenu(self)
            elseif self.item then ns.ShowUI("items", "", self.item.key) end
        end)
        row:SetScript("OnEnter", function(self)
            local c = self.item
            if not c then return end
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT", 12, 0)
            GameTooltip:AddLine(ns.ColorName(c))
            GameTooltip:AddLine(string.format("Level %s %s %s · %s", c.level or "?", c.race or "", c.class and (LOCALIZED_CLASS_NAMES_MALE[c.class] or c.class) or "", c.realm), 0.761, 0.784, 0.855)
            if c.playedLevel then GameTooltip:AddDoubleLine("Played this level", ns.Duration(c.playedLevel), 0.588, 0.616, 0.702, 1, 1, 1) end
            for _, p in ipairs(c.profs or {}) do
                GameTooltip:AddDoubleLine(p.name, p.rank .. " / " .. p.max, 0.588, 0.616, 0.702, 1, 1, 1)
            end
            if c.bankSeen then GameTooltip:AddDoubleLine("Bank recorded", ns.Ago(c.bankSeen), 0.588, 0.616, 0.702, 1, 1, 1)
            else GameTooltip:AddLine("Bank not recorded yet: visit a banker on this character.", 0.953, 0.663, 0.510, true) end
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
            for _, t in ipairs({ c.bags or {}, c.bank or {}, c.equipped or {} }) do
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

local function BuildItems(view)
    view.search = T.SearchBox(view, "Search every character's bags, bank and gear", function(text)
        view.query = text
        view:Refresh()
    end)
    view.search:SetPoint("TOPLEFT", 0, 0)
    view.search:SetWidth(360)

    -- "Only Name ×": the character filter set from the Characters view
    view.only = CreateFrame("Button", nil, view)
    view.only:SetHeight(24)
    view.only:SetPoint("LEFT", view.search, "RIGHT", 10, 0)
    view.only.text = T.Chip(view.only)
    view.only.text:SetPoint("LEFT", 8, 0)
    view.only:SetScript("OnClick", function() view.onlyKey = nil; view:Refresh() end)

    view.hint = T.Text(view, T.mono, 11, C.muted, "CENTER")
    view.hint:SetPoint("TOP", 0, -120)
    view.hint:SetWidth(W - PAD * 4)
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
        local onlyChar = self.onlyKey and ns.db.chars[self.onlyKey]
        if self.onlyKey and not onlyChar then self.onlyKey = nil end
        self.only:SetShown(onlyChar ~= nil)
        if onlyChar then
            self.only.text:SetText("ONLY " .. onlyChar.name:upper() .. "   ×")
            self.only:SetWidth(self.only.text:GetStringWidth() + 16)
        end

        if query == "" and not onlyChar then
            self.list:SetData({})
            self.hint:SetText("Type part of an item's name.\n\nBags and gear are recorded whenever you log in; "
                .. "the bank when you visit a banker, so open it once on each character.")
            self.hint:Show()
            local n = 0
            for _ in pairs(Inventory()) do n = n + 1 end
            SetFooter(ns.Commas(n) .. " different items across your characters")
            return
        end

        local results = {}
        for id, e in pairs(Inventory(self.onlyKey)) do
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

local function BuildProfessions(view)
    view.search = T.SearchBox(view, "Who can make…", function(text)
        view.query = text
        view:Refresh()
    end)
    view.search:SetPoint("TOPLEFT", 0, 0)
    view.search:SetWidth(360)

    view.hint = T.Text(view, T.mono, 11, C.muted, "CENTER")
    view.hint:SetPoint("TOP", 0, -120)
    view.hint:SetWidth(W - PAD * 4)
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
            if not e or not e.recipe then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if e.recipe.item then GameTooltip:SetItemByID(e.recipe.item)
            else GameTooltip:SetText(e.recipe.name or "?") end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
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
            else
                row.extra:SetText(Hex(C.place) .. "open the profession window to record recipes|r")
            end
        end
    end)
    view.list:SetPoint("TOPLEFT", 0, -34)
    view.list:SetPoint("BOTTOMRIGHT")

    function view:Refresh()
        local query = (self.query or ""):lower()
        local rows = {}
        if query == "" then
            local chars = ns:Characters()
            table.sort(chars, function(a, b) return a.name < b.name end)
            for _, c in ipairs(chars) do
                for _, p in ipairs(c.profs or {}) do table.insert(rows, { c = c, p = p }) end
            end
            self.hint:SetShown(#rows == 0)
            self.hint:SetText("No professions recorded yet. Log in on each character once.")
            self.list:SetData(rows)
            SetFooter(#rows .. " professions   ·   type to find who can make something")
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
                        if not e then e = { recipe = r, prof = prof, knowers = {} }; found[id] = e end
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

---- The window -----------------------------------------------------------------

local TABS_DEF = {
    { key = "chars", label = "CHARACTERS",  build = BuildCharacters },
    { key = "items", label = "ITEMS",       build = BuildItems },
    { key = "profs", label = "PROFESSIONS", build = BuildProfessions },
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
end

local function Build()
    frame = CreateFrame("Frame", "ForeverAltsFrame", UIParent)
    frame:SetSize(W, H)
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

        local v = CreateFrame("Frame", nil, frame)
        v:SetPoint("TOPLEFT", PAD, -(HEAD + TABS + 12))
        v:SetPoint("BOTTOMRIGHT", -PAD, FOOT + 8)
        v.tab = b
        t.build(v)
        v:Hide()
        views[t.key] = v
        prev = b
    end

    frame.footer = T.Text(frame, T.mono, 10, C.muted)
    frame.footer:SetPoint("LEFT", frame, "BOTTOMLEFT", PAD, FOOT / 2)
    local version = T.Text(frame, T.mono, 10, C.muted, "RIGHT")
    version:SetPoint("RIGHT", frame, "BOTTOMRIGHT", -PAD, FOOT / 2)
    version:SetText("v" .. (C_AddOns.GetAddOnMetadata(ns.name, "Version") or "?") .. "   /alts")

    frame:SetScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        if current then views[current]:Refresh() end
    end)
    frame:SetScript("OnHide", function() PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE) end)
    -- Played time and "seen" tick while the window is open
    local elapsed = 0
    frame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed > 30 and current == "chars" then elapsed = 0; views.chars:Refresh() end
    end)
end

-- view: "chars" | "items" | "profs"; query fills its search box; onlyKey filters items to one character
function ns.ShowUI(view, query, onlyKey)
    if not ns.me then return end
    if not frame then Build() end
    frame:Show()
    view = view or current or "chars"
    local v = views[view]
    if view == "items" then v.onlyKey = onlyKey end
    if v.search and query then
        v.search:SetText(query)  -- OnTextChanged refreshes
    end
    Select(view)
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
