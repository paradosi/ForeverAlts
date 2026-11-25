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

local function BuildItems(view)
    view.search = T.SearchBox(view, "Search bags, bank, gear and mail", function(text)
        view.query = text
        view:Refresh()
    end)
    view.search:SetPoint("TOPLEFT", 0, 0)
    view.search:SetWidth(360)

    -- "Only Name ×": the character filter set from the Characters view
    view.only = OnlyChip(view)

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
        local onlyChar = self.only:Update()

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
    view.charDrop, view.specButtons, view.panels = false, {}, {}

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
        local placed = {}
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
                if plan and self.nextKey and node.s == self.nextKey then col, open = C.primary, false end
                T.Fill(b.edge, open and OPEN or col)
                b.rank:SetText(r .. "/" .. node.m)
                local rc = on and col or C.muted
                b.rank:SetTextColor(rc[1], rc[2], rc[3])
                b:Show()
                placed[idx] = b
            end
        end
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
        acts.order:SetScript("OnClick", nil)
        acts.order:SetScript("OnEnter", function(b)
            local steps = self.steps or {}
            GameTooltip:SetOwner(b, "ANCHOR_BOTTOMLEFT")
            GameTooltip:AddLine("Level order: " .. book.active, 1, 1, 1)
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
        acts.order:SetScript("OnLeave", GameTooltip_Hide)
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

        -- The character picker: a dropdown showing who's drawn, listing everyone recorded
        local drop = self.charDrop
        if not drop then
            drop = CreateFrame("Button", nil, self)
            drop:SetSize(260, 24)
            drop:SetPoint("TOPLEFT", 0, 0)
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
            drop.chars = {}

            -- The list drops from the box, in the window's own look: a row per character,
            -- the shown one marked in gold. A click anywhere else, or Esc, closes it.
            local ROW, MAXROWS = 24, 12
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

            local function Pick(ch)
                list:Hide()
                self.pick, self.group = ch.key, false
                box:Hide()
                self:Refresh()
            end
            function list.Fill(l)
                local all = drop.chars
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
                        r.ch = false
                        r:SetScript("OnEnter", function(b) b.hover:Show() end)
                        r:SetScript("OnLeave", function(b) b.hover:Hide() end)
                        r:SetScript("OnClick", function(b) if b.ch then Pick(b.ch) end end)
                        l.rows[i] = r
                    end
                    local ch = all[i + l.offset]
                    r.ch = ch
                    r.name:SetText(ns.ColorName(ch) .. (ch == ns.me and "  |cff969db3· you|r" or ""))
                    r.info:SetText((ch.level or "?") .. " " .. (LOCALIZED_CLASS_NAMES_MALE[ch.class] or ch.class or ""))
                    local on = ch.key == l.owner.pick
                    r.mark:SetShown(on)
                    local col = on and C.accent or C.muted
                    r.info:SetTextColor(col[1], col[2], col[3])
                    r:Show()
                end
                for i = shown + 1, #l.rows do l.rows[i]:Hide(); l.rows[i].ch = false end
            end
            list.owner = self
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
            view:HookScript("OnHide", function() list:Hide() end)
            self.charDrop = drop
        end
        drop.chars = chars
        drop:SetShown(c and true or false)
        if c then
            local class = LOCALIZED_CLASS_NAMES_MALE[c.class] or c.class or ""
            drop.label:SetText(ns.ColorName(c) .. "  |cff969db3" .. (c.level or "?") .. " " .. class .. "|r")
            local w = drop.label:GetStringWidth()
            drop:SetWidth(math.max(200, math.min(320, (w and w > 0 and w or 180) + 44)))
        end

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

local TABS_DEF = {
    { key = "chars", label = "CHARACTERS",  build = BuildCharacters },
    { key = "items", label = "ITEMS",       build = BuildItems },
    { key = "profs", label = "PROFESSIONS", build = BuildProfessions },
    { key = "reps",  label = "REPUTATION",  build = BuildReputation },
    { key = "locks", label = "LOCKOUTS",    build = BuildLockouts },
    { key = "talents", label = "TALENTS",   build = BuildTalents },
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

function ns.ToggleUI()
    if frame and frame:IsShown() then frame:Hide() else ns.ShowUI() end
end

function ns.RefreshUI()
    if not frame or not frame:IsShown() or not current then return end
    ns:Debounce("ui", 0.2, function()
        if frame:IsShown() then views[current]:Refresh() end
    end)
end
