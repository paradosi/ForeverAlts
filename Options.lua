---- Options — the settings panel (Esc > Options > AddOns > Forever Alts)
--
-- The wowdb.dev look, the same as the window and the other Forever addons: the
-- panel and its controls come from Widgets.lua (shared byte-identical with
-- ForeverQuestItemBar, its source). Every control writes ForeverAltsDB.settings
-- and takes effect at once; the panel re-reads them each time it is shown, so
-- /alts scale and the like show up there.

local addonName, ns = ...
local T, W = ns.T, ns.W
local C = T.C

-- Both come from the TOC, so `wowdev bump` keeps the version current here.
ns.VERSION = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"
ns.WEBSITE = C_AddOns.GetAddOnMetadata(addonName, "X-Website")

local COL_W = W.COL_W
local category

function ns.OpenOptions()
    if category then Settings.OpenToCategory(category:GetID()) end
end

function ns.ShowSupportLink()
    if ns.WEBSITE then W.CopyDialog("Help and bug reports", ns.WEBSITE) end
end

local function Create()
    local s = ns.settings
    local panel, host, fit = W.Panel({
        name = "ForeverAltsOptions",
        title = "Forever Alts",
        logo = "Interface\\AddOns\\ForeverAlts\\media\\textures\\logo_64",
        version = ns.VERSION,
        sub = "every character at a glance  ·  changes apply live",
    })

    local function ColumnTop(x)
        local f = CreateFrame("Frame", nil, host)
        f:SetSize(1, 1)
        f:SetPoint("TOPLEFT", host, "TOPLEFT", x, -8)
        return f
    end
    local left, right = ColumnTop(18), ColumnTop(18 + COL_W + 40)

    -- A tick bound to one setting; ns.RefreshUI redraws whatever shows it
    local checks = {}
    local function Check(anchor, yOff, key, label)
        local c = W.Check(host, anchor, yOff, label)
        c.onChange = function(v)
            s[key] = v
            ns.RefreshUI()
        end
        checks[key] = c
        return c
    end

    ---- Left column: the window, mail

    local winSec = W.Section(host, left, 0, "Window")
    local scale = W.Slider(host, winSec, -14, "Window scale", ns.SCALE_MIN, ns.SCALE_MAX, 5, 5, "%")
    scale.onChange = function(v)
        s.scale = v
        ns.ApplyScale()
    end
    local scaleNote = W.Note(host, scale, -4,
        "text, icons and spacing together, so nothing gets cut off  ·  /alts reset goes back to 100%")
    local open = W.Button(host, "Open Forever Alts", COL_W)
    open:SetPoint("TOPLEFT", scaleNote, "BOTTOMLEFT", 0, -12)
    open:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        ns.ShowUI()
    end)

    local mini = Check(open, -14, "minimap", "Show the minimap button")
    mini.onChange = function(v)
        s.minimap = v
        ns.UpdateMinimapButton()
    end
    local miniNote = W.Note(host, mini, -4, "left-click: the window  ·  right-click: this  ·  drag to move it")

    local mailSec = W.Section(host, miniNote, -18, "Mail")
    local mailWarn = Check(mailSec, -10, "mailWarn", "Warn about mail about to expire")
    local mailNote = W.Note(host, mailWarn, -4,
        "at login, a chat line names any character whose items or gold in the mail run out within 3 days")

    local talSec = W.Section(host, mailNote, -18, "Talents")
    local remind = Check(talSec, -10, "planRemind", "Remind me of my talent plan")
    local remindNote = W.Note(host, remind, -4,
        "with points to spend, a chat line names the next talent in your class's plan (/alts plan)")
    local glow = Check(remindNote, -10, "planGlow", "Show the plan in the talent window")
    local glowNote = W.Note(host, glow, -4, "the next planned talent gets a running gold border")

    ---- Right column: item tooltips

    local tipSec = W.Section(host, right, 0, "Item tooltips")
    local tip = Check(tipSec, -10, "tooltip", "Show counts on item tooltips")
    local tipNote = W.Note(host, tip, -4,
        "every character holding it, with how many in bags, bank and gear, plus the account bank")
    local last = Check(tipNote, -10, "tooltipSelf", "Include the character you're playing")
    -- Forever has no realms (GetRealmName() is ""; names are unique across the
    -- region), so the option only appears where there is a realm to choose
    if GetRealmName() ~= "" then
        last = Check(last, -6, "allRealms", "Include characters on other realms")
    end
    last = Check(last, -6, "sameFaction", "Only characters of your faction")
    local ruleset = Check(last, -6, "sameRuleset", "Only characters on your ruleset")
    local rulesetNote = W.Note(host, ruleset, -4,
        "Normal, PvP, Roleplay or RP-PvP; a character counts until its next login records it")
    local craft = Check(rulesetNote, -10, "tooltipCraft", "Show who can make the item")
    local craftNote = W.Note(host, craft, -4, "a Made by line; recipes are recorded when you open a profession window")

    ---- Footer: help, and the slash commands

    -- Under whichever column ends lower: placed in OnShow, once text is measured
    local foot = T.Line(host, C.divider)
    foot:SetWidth(COL_W * 2 + 40)
    local function PlaceFoot()
        local l, r = glowNote:GetBottom(), craftNote:GetBottom()
        foot:ClearAllPoints()
        foot:SetPoint("TOP", (l and r and r < l) and craftNote or glowNote, "BOTTOM", 0, -20)
        foot:SetPoint("LEFT", host, "LEFT", 18, 0)
    end
    PlaceFoot()

    local help = W.Button(host, "Help and bug reports", 180)
    help:SetPoint("TOPLEFT", foot, "BOTTOMLEFT", 0, -12)
    help:SetScript("OnClick", ns.ShowSupportLink)
    help:SetShown(ns.WEBSITE ~= nil)

    local hint = T.Text(host, T.mono, 11, C.muted)
    hint:SetPoint("LEFT", help, "RIGHT", 16, 0)
    hint:SetText("/alts opens the window  ·  /alts options opens this")

    panel:SetScript("OnShow", function()
        scale:SetValue(s.scale)
        for key, c in pairs(checks) do c:SetChecked(s[key]) end
        PlaceFoot()
        fit(help)
    end)

    ns.optionControls = { scale = scale, checks = checks, help = help, open = open }  -- for tests/smoke.lua

    category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
end

ns:On("PLAYER_LOGIN", Create)
