-- luacheck: ignore
-- (this file stubs the WoW API by assigning its globals; nothing here ships)
-- Headless smoke test: loads every file in TOC order against a stubbed WoW API,
-- logs a character in, opens the bank and a profession, then builds and drives all
-- three views. Catches nil calls and typos that the static gate can't.
--
--   cd ForeverAlts && lua5.1 tests/smoke.lua

local failures = 0
local function check(cond, msg)
    if not cond then failures = failures + 1; print("FAIL " .. msg) else print("ok   " .. msg) end
end

---- A permissive widget: any method exists; a few return what layout code needs

local Widget = {}
SIZED = {}  -- frames that lay out on resize (the lists): the test sizes them by hand
local function NewWidget(kind)
    local w = { kind = kind, scripts = {}, events = {}, shown = true, points = {}, text = "", w = 100, h = 100 }
    return setmetatable(w, Widget)
end
local methods = {
    SetScript = function(self, k, fn)
        self.scripts[k] = fn
        if k == "OnSizeChanged" then table.insert(SIZED, self) end
    end,
    GetScript = function(self, k) return self.scripts[k] end,
    Show = function(self) self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end,
    Hide = function(self) self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end,
    SetShown = function(self, on) if on then self:Show() else self:Hide() end end,
    IsShown = function(self) return self.shown end,
    SetText = function(self, t)
        self.text = t
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, true) end
    end,
    GetText = function(self) return self.text end,
    GetStringWidth = function() return 60 end,
    SetSize = function(self, w, h) self.w, self.h = w, h end,
    SetWidth = function(self, w) self.w = w end,
    SetHeight = function(self, h)
        self.h = h
        if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self, self.w, h) end
    end,
    GetHeight = function(self) return self.h end,
    GetWidth = function(self) return self.w end,
    GetTop = function() return 500 end,
    GetFrameLevel = function() return 1 end,
    GetNormalTexture = function() return NewWidget("Texture") end,
    GetEffectiveScale = function() return 1 end,
    GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
    CreateTexture = function() return NewWidget("Texture") end,
    CreateFontString = function() return NewWidget("FontString") end,
    CreateMaskTexture = function() return NewWidget("MaskTexture") end,
    CreateLine = function() return NewWidget("Line") end,
    RegisterEvent = function(self, e) self.events[e] = true end,
}
Widget.__index = function(_, k) return methods[k] or function() end end

local allFrames = {}
function CreateFrame(kind, name)
    local f = NewWidget(kind)
    table.insert(allFrames, f)
    if name then _G[name] = f end
    return f
end
UIParent = NewWidget("Frame")
GameTooltip = NewWidget("GameTooltip")
UISpecialFrames, StaticPopupDialogs, SlashCmdList = {}, {}, {}

---- The API, as one Forever character sees it

local now, clock = 1800000000, 1000
function time() return now end
function GetTime() return clock end
function date() return "" end
function print(...) io.write("     | ", table.concat({ ... }, " "), "\n") end
local timers = {}
C_Timer = { After = function(_, fn) table.insert(timers, fn) end }
local function RunTimers() while #timers > 0 do table.remove(timers, 1)() end end

function canaccessvalue() return true end
function UnitName() return "Aelin", "Galathynius" end
function GetRealmName() return "Dreamscythe" end
function UnitClass() return "Mage", "MAGE" end
function UnitRace() return "Human" end
function UnitFactionGroup() return "Alliance" end
function UnitGUID() return "Player-4372-0A1B2C3D" end
function GetRealmID() return 4372 end
function UnitLevel() return 37 end
function UnitXP() return 4000 end
function UnitXPMax() return 10000 end
function GetXPExhaustion() return 2500 end
function IsResting() return true end
function GetMoney() return 1234567 end
function GetRealZoneText() return "Stranglethorn Vale" end
function GetAverageItemLevel() return 34.2, 33.6 end
function GetMaxLevelForPlayerExpansion() return 60 end
local played
function RequestTimePlayed() played = true end
function IsShiftKeyDown() return false end
function IsMouseButtonDown() return false end
function GetCursorPosition() return 0, 0 end
function PlaySound() end
SOUNDKIT = {}
function GameTooltip_Hide() end
function HandleModifiedItemClick() end
LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Mage" }
function CreateColor() return {} end

Enum = {
    BagIndex = { Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4, ReagentBag = 5 },
    BankType = { Character = 0, Account = 2 },
    TooltipDataType = { Item = 0 },
    PlayerInteractionType = { Banker = 8 },
}

-- Bags: 2x Linen Cloth (2589) x20 in the backpack; the bank tab (bag 6) holds 15 more
-- and a Runecloth (14047); the account tab (bag 15) holds 5 Linen
local containers = {
    [0] = { { itemID = 2589, stackCount = 20, hyperlink = "|cffffffff|Hitem:2589::|h[Linen Cloth]|h|r", quality = 1, iconFileID = 1 },
            { itemID = 2589, stackCount = 20, hyperlink = "|cffffffff|Hitem:2589::|h[Linen Cloth]|h|r", quality = 1, iconFileID = 1 } },
    [6] = { { itemID = 2589, stackCount = 15, hyperlink = "|cffffffff|Hitem:2589::|h[Linen Cloth]|h|r", quality = 1, iconFileID = 1 },
            { itemID = 14047, stackCount = 3, hyperlink = "|cffffffff|Hitem:14047::|h[Runecloth]|h|r", quality = 1, iconFileID = 2 } },
    [15] = { { itemID = 2589, stackCount = 5, hyperlink = "|cffffffff|Hitem:2589::|h[Linen Cloth]|h|r", quality = 1, iconFileID = 1 } },
}
local bankOpen = false
C_Container = {
    GetContainerNumSlots = function(bag) return containers[bag] and 16 or 0 end,
    GetContainerNumFreeSlots = function(bag) return containers[bag] and 14 or 0 end,
    GetContainerItemInfo = function(bag, slot) return containers[bag] and containers[bag][slot] end,
}
C_Bank = {
    CanViewBank = function() return bankOpen end,
    FetchPurchasedBankTabData = function(t) return t == 0 and { { ID = 6 } } or { { ID = 15 } } end,
}
function GetInventoryItemID(_, slot) return slot == 5 and 6097 or 0 end  -- Forever: 0 for an empty slot
function GetInventoryItemLink(_, slot) return slot == 5 and "|Hitem:6097::|h[Acolyte's Shirt]|h" or nil end
function GetInventoryItemCount() return 1 end
function GetProfessions() return 1, 2 end
function GetProfessionInfo(i)
    if i == 1 then return "Tailoring", 136249, 150, 225, 0, 0, 197 end
    return "Cooking", 133971, 75, 150, 0, 0, 185
end
C_TradeSkillUI = {
    IsTradeSkillLinked = function() return false end,
    IsTradeSkillGuild = function() return false end,
    IsNPCCrafting = function() return false end,
    GetBaseProfessionInfo = function() return { professionName = "Tailoring" } end,
    GetAllRecipeIDs = function() return { 2387, 2393 } end,
    GetRecipeInfo = function(id)
        return { learned = id == 2387, name = id == 2387 and "Bolt of Linen Cloth" or "White Linen Shirt", icon = 1 }
    end,
    GetRecipeSchematic = function(id) return { outputItemID = id == 2387 and 2996 or 2576 } end,
}
C_Item = {
    GetItemNameByID = function(id) return ({ [2996] = "Bolt of Linen Cloth" })[id] end,
    GetItemQualityByID = function() return 1 end,
    GetItemIconByID = function() return 1 end,
    GetItemQualityColor = function() return 1, 1, 1, "ffffffff" end,
}
C_ClassColor = { GetClassColor = function() return { GenerateHexColor = function() return "ff3fc7eb" end } end }
C_AddOns = { GetAddOnMetadata = function() return "0.1.0" end }
local tooltipCalls = {}
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) tooltipCalls[#tooltipCalls + 1] = fn end }
MenuUtil = { CreateContextMenu = function() end }
function StaticPopup_Show() end
local category = { GetID = function() return 1 end }
Settings = {
    RegisterVerticalLayoutCategory = function() return category, { AddInitializer = function() end } end,
    RegisterProxySetting = function() return {} end,
    CreateCheckbox = function() end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function() end,
}
function CreateSettingsListSectionHeaderInitializer() end

-- Mail: two letters, one with 4 Runecloth and 2 days left, one with 50 silver and 20 days;
-- plus a plain text letter. 53 letters on the server, 3 shown.
local inbox = {
    { money = 0, days = 2, item = { id = 14047, count = 4 } },
    { money = 5000, days = 20 },
    { money = 0, days = 29 },
}
-- Reputation: "Alliance" open with Stormwind (Honored, 3000/12000); "Other" collapsed,
-- hiding the Nightclaw Druids (Exalted)
local factionList = {
    { name = "Alliance", factionID = 469, isHeader = true, isCollapsed = false },
    { name = "Stormwind", factionID = 72, reaction = 6, currentReactionThreshold = 9000, nextReactionThreshold = 21000, currentStanding = 12000 },
    { name = "Other", factionID = 169, isHeader = true, isCollapsed = true },
}
local hidden = { { name = "Nightclaw Druids", factionID = 2758, reaction = 8, currentReactionThreshold = 42000, nextReactionThreshold = 42000, currentStanding = 42999 } }
local expands, collapses = 0, 0
C_Reputation = {
    GetNumFactions = function() return #factionList end,
    GetFactionDataByIndex = function(i) return factionList[i] end,
    ExpandFactionHeader = function(i)
        expands = expands + 1
        factionList[i].isCollapsed = false
        for k, f in ipairs(hidden) do table.insert(factionList, i + k, f) end
    end,
    CollapseFactionHeader = function(i)
        collapses = collapses + 1
        factionList[i].isCollapsed = true
        for _ = 1, #hidden do table.remove(factionList, i + 1) end
    end,
}
-- Lockouts: Molten Core, 3 of 10 bosses down, resets in 4 days; an Onyxia lockout
-- the server still lists but no longer holds (locked false)
local askedRaids = 0
function RequestRaidInfo() askedRaids = askedRaids + 1 end
local saved = {
    { "Molten Core", 7001, 4 * 86400, 9, true, false, 0, true, 40, "40 Player", 10, 3 },
    { "Onyxia's Lair", 7002, 0, 9, false, false, 0, true, 40, "40 Player", 1, 1 },
}
function GetNumSavedInstances() return #saved end
function GetSavedInstanceInfo(i) return unpack(saved[i]) end
function GetSavedInstanceEncounterInfo(i, e)
    if i == 1 then return "Boss " .. e, 0, e <= 3 end
end
-- Talents: one spec, a Mage tree of three groups; 7 points in Fire (5/5 Improved
-- Fireball leading to 2/3 Ignite), Arcane's talent untouched, 2 points unspent
local talentNodes = {
    [101] = { ID = 101, posX = 1000, posY = 1000, isVisible = true, groupIDs = { 12 }, entryIDs = { 201 }, currentRank = 5, maxRanks = 5,
              visibleEdges = { { targetNode = 102 } } },
    [102] = { ID = 102, posX = 1000, posY = 1600, isVisible = true, groupIDs = { 12 }, entryIDs = { 202 }, currentRank = 2, maxRanks = 3, visibleEdges = {} },
    [104] = { ID = 104, posX = 16000, posY = 10000, isVisible = true, groupIDs = { 12 }, entryIDs = { 204 }, currentRank = 0, maxRanks = 5, visibleEdges = {} },
    [103] = { ID = 103, posX = 1600, posY = 1000, isVisible = true, groupIDs = { 11 }, entryIDs = { 203 }, currentRank = 0, maxRanks = 5, visibleEdges = {} },
}
-- The Legacy System: renown 3; Professions has one talent (1/1), Adventure two
-- (2/2 leading to 1/3), Progression none
talentNodes[301] = { ID = 301, posX = 500, posY = 500, isVisible = true, entryIDs = { 401 }, currentRank = 1, maxRanks = 1, visibleEdges = {} }
talentNodes[302] = { ID = 302, posX = 500, posY = 500, isVisible = true, entryIDs = { 402 }, currentRank = 2, maxRanks = 2,
                     visibleEdges = { { targetNode = 303 } } }
talentNodes[303] = { ID = 303, posX = 500, posY = 900, isVisible = true, entryIDs = { 403 }, currentRank = 1, maxRanks = 3, visibleEdges = {} }
C_MajorFactions = { GetCurrentRenownLevel = function(id) return id == 2802 and 3 or 0 end }
C_ClassTalents = { GetActiveConfigID = function() return 77 end }
C_SpecializationInfo = {
    GetActiveSpecGroup = function() return 1 end,
    GetCombatConfigIDForSpecGroup = function() return 77 end,
}
function GetNumSpecGroups() return 1 end
C_Traits = {
    GetConfigInfo = function(id) return id == 77 and { treeIDs = { 500 } } or nil end,
    GetGroupDisplayInfoByTreeID = function()
        return { { groupID = 13, orderIndex = 3, displayName = "Frost", icon = 3 }, { groupID = 11, orderIndex = 1, displayName = "Arcane", icon = 1 },
                 { groupID = 12, orderIndex = 2, displayName = "Fire", icon = 2 } }
    end,
    GetGroupCurrencyInfo = function() return { { traitNodeGroupID = 12, currencyInfos = { { spent = 7 } } } } end,
    GetTreeNodes = function(tree)
        if tree == 1187 then return { 301 } elseif tree == 1188 then return { 302, 303 } elseif tree == 1189 then return {} end
        return { 101, 102, 103, 104 }
    end,
    GetConfigIDByTreeID = function(tree) return tree + 10000 end,
    GetNodeInfo = function(_, id) return talentNodes[id] end,
    GetEntryInfo = function(_, e) return { definitionID = e + 100 } end,
    GetDefinitionInfo = function(d) return { spellID = d * 10 } end,
    GetTreeCurrencyInfo = function(_, tree)
        if tree == 1188 then return { { quantity = 4, maxQuantity = 40, spentInTree = 3, spent = 6 } } end
        if tree == 1187 then return { { quantity = 4, maxQuantity = 40, spentInTree = 1, spent = 6 } } end
        if tree == 1189 then return { { quantity = 4, maxQuantity = 40, spentInTree = 0, spent = 6 } } end
        return { { quantity = 2 } }
    end,
    GenerateImportString = function() return "BAAAAAAAAtalentcode" end,
}
C_Spell = C_Spell or {}
C_Spell.GetSpellTexture = function() return 99 end
local hooks = {}
function hooksecurefunc(name, fn) hooks[name] = fn end
function GetInboxNumItems() return #inbox, 53 end
function GetInboxHeaderInfo(i)
    local m = inbox[i]
    return nil, nil, "Sender", "Subject", m.money, 0, m.days, m.item and 1 or nil
end
function GetInboxItem(i, a)
    local it = inbox[i].item
    if it and a == 1 then return "Runecloth", it.id, 2, it.count, 1, true end
end
function GetInboxItemLink(i, a) if inbox[i].item and a == 1 then return "|Hitem:14047::|h[Runecloth]|h" end end
local sendSlots = { [1] = { id = 2589, count = 10 } }
function GetSendMailItem(a) local s = sendSlots[a]; if s then return "Linen Cloth", s.id, 1, s.count, 1 end end
function GetSendMailMoney() return 0 end

---- Load in TOC order

local ns = {}
local function Fire(event, ...)
    for _, f in ipairs(allFrames) do
        if f.events and f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end
for line in io.lines("ForeverAlts.toc") do
    if line:match("%.lua$") then
        local chunk = assert(loadfile(line))
        chunk("ForeverAlts", ns)
    end
end

-- An alt from an earlier session: logged out 16 hours ago in an inn
ForeverAltsDB = { chars = { ["Dreamscythe|Borin Stonefist"] = {
    name = "Borin Stonefist", realm = "Dreamscythe", class = "WARRIOR", level = 22, xp = 0, xpMax = 8000,
    rested = 0, resting = true, lastSeen = now - 16 * 3600, money = 5000, played = 7200,
    bags = { [2589] = 7 }, recipes = { Tailoring = { [2387] = 2996 } }, maxLevel = 60,
} } }

Fire("ADDON_LOADED", "ForeverAlts")
Fire("PLAYER_LOGIN")
RunTimers()

local db = ForeverAltsDB
local me = db.chars["Dreamscythe|Aelin Galathynius"]
check(me ~= nil, "character filed under its full First Last name")
check(me.level == 37 and me.money == 1234567 and me.ilvl == 34, "summary recorded")
check(me.bags[2589] == 40, "bags counted: 40 Linen Cloth")
check(me.equipped[6097] == 1, "gear counted")
check(me.equipped[0] == nil, "an empty gear slot is not item 0")
check(#me.profs == 2 and me.profs[1].name == "Tailoring", "professions recorded")
check(played, "played time requested on first login")
Fire("TIME_PLAYED_MSG", 90000, 3600)

bankOpen = true
Fire("BANKFRAME_OPENED")
RunTimers()
check(me.bank and me.bank[2589] == 15 and me.bank[14047] == 3, "bank tabs counted")
check(db.warband.items and db.warband.items[2589] == 5, "account bank counted once, shared")
Fire("BANKFRAME_CLOSED")
bankOpen = false

Fire("TRADE_SKILL_SHOW")
RunTimers()
check(me.recipes.Tailoring[2387] == 2996 and me.recipes.Tailoring[2393] == nil, "only learned recipes recorded")

local reps = me.reps
check(reps and reps[72] and reps[72].r == 6 and reps[72].cur == 3000 and reps[72].max == 12000, "reputation: progress through Honored")
check(reps[2758] and reps[2758].r == 8 and reps[2758].max == 0, "reputation: faction under a collapsed header read")
check(expands == 1 and collapses == 1 and #factionList == 3 and factionList[3].isCollapsed, "reputation: collapsed header closed again")
check(db.factions[2758].group == "Other" and db.groups.Alliance == 1, "reputation: faction groups recorded")
Fire("UPDATE_FACTION")
RunTimers()
check(expands == 1, "reputation: our own header toggling doesn't rescan")
clock = clock + 5
factionList[2].currentStanding = 13000
Fire("UPDATE_FACTION")
RunTimers()
check(me.reps[72].cur == 4000 and expands == 2, "reputation: a rep gain rescans")

-- Lockouts: asked for at login, read only once the server answers
check(askedRaids == 1 and me.lockouts == nil, "lockouts: asked for, not read before the answer")
Fire("UPDATE_INSTANCE_INFO")
RunTimers()
local mc = me.lockouts and me.lockouts["Molten Core"]
check(mc and mc.done == 3 and mc.total == 10 and mc.reset == now + 4 * 86400, "lockouts: Molten Core 3/10, reset time")
check(mc and #mc.bosses == 10 and mc.bosses[3].killed and not mc.bosses[4].killed, "lockouts: bosses killed and alive")
check(me.lockouts["Onyxia's Lair"] == nil and #ns.Lockouts(me) == 1, "lockouts: a lapsed lockout is not recorded")
check(db.instances["Molten Core"].total == 10, "lockouts: instance remembered for its column")
Fire("BOSS_KILL", 663, "Lucifron")
RunTimers()
check(askedRaids == 2, "lockouts: a boss kill asks again")

-- Talents: the trees in the game's order, points per tree, ranks and arrows
local spec = me.talents and me.talents.specs[1]
check(spec and spec.trees[1].name == "Arcane" and spec.trees[2].spent == 7 and spec.trees[3].spent == 0, "talents: trees in order, points spent")
check(spec and #spec.nodes == 4 and spec.unspent == 2 and spec.code == "BAAAAAAAAtalentcode", "talents: nodes, unspent points, loadout code")
local fireball
for _, n in ipairs(spec and spec.nodes or {}) do if n.s == 3010 then fireball = n end end
check(fireball and fireball.t == 2 and fireball.r == 5 and fireball.e and spec.nodes[fireball.e[1]].s == 3020, "talents: rank and prerequisite arrow")
check(ns.SpecSummary(spec) == "0/7/0" and select(2, ns.SpecSummary(spec)) == "Fire", "talents: summary names the top tree")

-- Legacy: three trees in one list, the arrow kept inside its own tree
local lg = me.legacy
check(lg and lg.renown == 3 and lg.unspent == 4 and #lg.trees == 3 and lg.trees[2].spent == 3, "legacy: renown, points to spend, points per tree")
check(lg and #lg.nodes == 3 and lg.nodes[1].t == 1 and lg.nodes[2].t == 2 and lg.nodes[2].e and lg.nodes[2].e[1] == 3, "legacy: talents in their trees, arrow shifted")

-- Mail: nothing is read until the server answers, then the inbox is counted
Fire("MAIL_SHOW")
check(me.mail == nil, "mail not recorded before the inbox arrives")
Fire("MAIL_INBOX_UPDATE")
RunTimers()
check(me.mail and me.mail.items[14047] == 4 and me.mail.money == 5000, "mail items and gold counted")
check(me.mail.letters == 2 and me.mail.hidden == 50, "letters with items or gold, and the unseen rest")
check(me.mail.expires == now + 2 * 86400, "soonest expiry is the 2-day letter")
Fire("MAIL_CLOSED")

-- Sending 10 Linen to Borin by first name counts it in his mail at once
hooks.SendMail("borin", "", "")
Fire("MAIL_SEND_SUCCESS")
local borinMail = db.chars["Dreamscythe|Borin Stonefist"].mail
check(borinMail and borinMail.items[2589] == 10 and borinMail.letters == 1, "mail sent to an alt counted on arrival")
hooks.SendMail("Stranger Person", "", "")
Fire("MAIL_SEND_SUCCESS")
check(borinMail.letters == 1, "mail to someone else is ignored")

-- Rested: 16h in an inn = 10% of a level on top of 0
local borin = db.chars["Dreamscythe|Borin Stonefist"]
check(math.abs(ns.Rested(borin) - 0.10) < 0.001, "offline rested XP grows 5% per 8h resting")
clock = clock + 600
check(ns.Played(me) == 90605, "played time keeps counting this session")
check(ns.Money(1234567) == "123|cffe3b664g|r 45|cffc2c8das|r 67|cffd9905fc|r", "money formatting")
check(ns.Commas(1234567) == "1,234,567" and ns.Commas(123456) == "123,456", "thousands separators")

-- Tooltip: Linen held by both characters plus the account bank
local lines = {}
local tip = { AddLine = function(_, t) lines[#lines + 1] = t end,
              AddDoubleLine = function(_, l, r) lines[#lines + 1] = l .. " = " .. r end }
for _, fn in ipairs(tooltipCalls) do fn(tip, { id = 2589 }) end
local text = table.concat(lines, "\n")
check(text:find("Aelin Galathynius|r = 55") ~= nil, "tooltip: this character 55 (40 bags + 15 bank)")
check(text:find("Aelin Galathynius|r = 55  |cff969db3bags 40, bank 15|r", 1, true) ~= nil, "tooltip: split shows each place")
check(text:find("Borin Stonefist|r = 17  |cff969db3bags 7, mail 10|r", 1, true) ~= nil, "tooltip: alt's bags and mail")
lines = {}
for _, fn in ipairs(tooltipCalls) do fn(tip, { id = 14047 }) end
check(table.concat(lines, "\n"):find("= 7  |cff969db3bank 3, mail 4|r", 1, true) ~= nil, "tooltip: mail counted for this character")
check(text:find("Account bank = 5") ~= nil and text:find("Total = 77") ~= nil, "tooltip: account bank and total")
lines = {}
for _, fn in ipairs(tooltipCalls) do fn(tip, { id = 2996 }) end
check(table.concat(lines):find("Made by") ~= nil, "tooltip: Made by line for a crafted item")
check(me.server == 4372 and me.realmID == 4372, "ruleset: home server read from the GUID")

-- Only your faction / ruleset: Borin is Horde on another server
local function TipText(id)
    lines = {}
    for _, fn in ipairs(tooltipCalls) do fn(tip, { id = id }) end
    return table.concat(lines, "\n")
end
check(TipText(2589):find("Borin", 1, true) ~= nil, "filters off: Borin counted although his faction is unknown")
borin.faction, borin.server = "Horde", 9999
db.settings.sameFaction = true
check(TipText(2589):find("Borin", 1, true) == nil and TipText(2589):find("Aelin", 1, true) ~= nil, "same faction: the Horde alt is left out")
check(TipText(2996):find("Made by", 1, true) ~= nil and TipText(2996):find("Borin", 1, true) == nil, "same faction: Made by leaves him out too")
db.settings.sameFaction = false
db.settings.sameRuleset = true
check(TipText(2589):find("Borin", 1, true) == nil, "same ruleset: an alt on another server is left out")
borin.server = nil
check(TipText(2589):find("Borin", 1, true) ~= nil, "same ruleset: an alt not yet recorded still counts")
db.settings.sameRuleset = false

-- UI: every view, with and without a search
SlashCmdList.FOREVERALTS("")
check(ForeverAltsFrame and ForeverAltsFrame:IsShown(), "window opens")
SlashCmdList.FOREVERALTS("items linen")
SlashCmdList.FOREVERALTS("items")
SlashCmdList.FOREVERALTS("profs bolt")
SlashCmdList.FOREVERALTS("profs")
SlashCmdList.FOREVERALTS("reps")
SlashCmdList.FOREVERALTS("reps storm")
-- Give each list a height so its rows are built, then render every view with data
local function SizeLists() for _, f in ipairs(SIZED) do f.scripts.OnSizeChanged(f, 800, 300) end end
SizeLists()
local rendered = 0
for _, f in ipairs(SIZED) do rendered = rendered + #(rawget(f, "rows") or {}) end
check(rendered > 0, "list rows built: " .. rendered)
-- Resizing: shrink every list to 3 rows, then grow it back; nothing may error
for _, f in ipairs(SIZED) do f.scripts.OnSizeChanged(f, 1400, 80) end
for _, f in ipairs(SIZED) do f.scripts.OnSizeChanged(f, 1400, 600) end
check(true, "lists survive shrinking and growing")
ns.ShowUI("chars")
SlashCmdList.FOREVERALTS("items linen")
SlashCmdList.FOREVERALTS("profs bolt")
SlashCmdList.FOREVERALTS("profs")
SlashCmdList.FOREVERALTS("reps")
SlashCmdList.FOREVERALTS("reps night")
ns.ShowUI("reps", "", "Dreamscythe|Borin Stonefist")
check(ForeverAltsFrame and true, "reputation filtered to a character with none recorded")
ns.ShowUI("reps", "", false)
-- Clicking a profession row lists that character's recipes; the chip goes back
SlashCmdList.FOREVERALTS("profs")
SizeLists()
local profRow
for _, f in ipairs(SIZED) do
    for _, r in ipairs(rawget(f, "rows") or {}) do
        local it = rawget(r, "item")
        if it and it.p and it.p.name == "Tailoring" and it.c.name == "Aelin Galathynius" then profRow = r end
    end
end
check(profRow ~= nil, "professions: a Tailoring row to click")
if profRow then profRow.scripts.OnClick(profRow, "LeftButton") end
check(ForeverAltsFrame.footer.text:find("1 Tailoring recipe on Aelin Galathynius", 1, true) ~= nil, "professions: click lists the recipes")
SlashCmdList.FOREVERALTS("talents")
check(ForeverAltsFrame.footer.text:find("Aelin Galathynius   ·   Fire 0/7/0", 1, true) ~= nil, "talents: tab draws the active spec")
local drawn = 0
for _, f in ipairs(allFrames) do if rawget(f, "node") then drawn = drawn + 1 end end
check(drawn == 3, "talents: every talent placed, the off-canvas one left out (" .. drawn .. ")")
ns.ShowTalents("Dreamscythe|Borin Stonefist")
check(ForeverAltsFrame.footer.text:find("Aelin", 1, true) ~= nil, "talents: a character without talents falls back")
SlashCmdList.FOREVERALTS("legacy")
check(ForeverAltsFrame.footer.text:find("Legacy Professions 1, Adventure 3, Progression 0", 1, true) ~= nil
    and ForeverAltsFrame.footer.text:find("4 Legacy points to spend", 1, true) ~= nil, "legacy: tab draws the Legacy trees")
SlashCmdList.FOREVERALTS("talents")
check(ForeverAltsFrame.footer.text:find("Fire 0/7/0", 1, true) ~= nil, "legacy: CLASS goes back to the class trees")

-- The planner: click talents on Aelin's trees (Improved Fireball 5/5 -> Ignite 2/3 in Fire,
-- an Arcane talent at 0/5)
SlashCmdList.FOREVERALTS("plan")
local function Talent(spell)
    for _, f in ipairs(allFrames) do
        local n = rawget(f, "node")
        if n and n.s == spell and f.shown then return f end
    end
end
local function Click(spell, button, shift)
    IsShiftKeyDown = function() return shift or false end
    local b = Talent(spell)
    b.scripts.OnClick(b, button or "LeftButton")
    IsShiftKeyDown = function() return false end
end
local foot = function() return ForeverAltsFrame.footer.text end
check(foot():find("Mage plan   ·   0/7/0", 1, true) and foot():find("7 learned + 0 planned = 7 of 51", 1, true), "plan: starts from the current build")
Click(3020)
check(foot():find("0/8/0", 1, true) and foot():find("1 planned", 1, true), "plan: a click adds a point")
Click(3020)
check(foot():find("Already at full rank", 1, true) ~= nil, "plan: full rank refused")
Click(3020, "RightButton"); Click(3020, "RightButton")
check(foot():find("Already learned", 1, true) ~= nil and foot():find("0/7/0", 1, true), "plan: learned points stay unless from scratch")
Click(3030, nil, true)
check(foot():find("5/7/0", 1, true) ~= nil, "plan: shift-click fills every rank")
-- From scratch, the rules: a tier needs 5 points above it, an arrow needs its source full
ForeverAltsDB.plans.MAGE = { scratch = true, ranks = {}, order = {} }
SlashCmdList.FOREVERALTS("plan")
Click(3020)
check(foot():find("Needs 5 points in Fire", 1, true) ~= nil, "plan: tier gate")
Click(3010, nil, true); Click(3020)
check(foot():find("0/6/0", 1, true) ~= nil, "plan: the tier opens after 5 points")
Click(3010, "RightButton")
check(foot():find("Other planned talents need this one", 1, true) ~= nil, "plan: can't pull a point others depend on")
check(#ForeverAltsDB.plans.MAGE.order == 6 and ForeverAltsDB.plans.MAGE.order[6] == 3020, "plan: points kept in the order they were added")
SlashCmdList.FOREVERALTS("locks")
check(ForeverAltsFrame.footer.text:find("1 of 2 characters saved", 1, true) ~= nil, "lockouts: tab renders the grid")
now = now + 5 * 86400
ns.ShowUI("locks")
check(ForeverAltsFrame.footer.text:find("0 of 2 characters saved", 1, true) ~= nil, "lockouts: a lockout past its reset is over")
now = now - 5 * 86400
ns.ShowUI("items", "", "Dreamscythe|Borin Stonefist")
ns.ShowUI("chars")
RunTimers()
check(true, "all views rendered without errors")

-- Logout carries played time forward. Forever reads 0 gold and 0 XP by then:
-- the logout must not overwrite what the live events recorded.
GetMoney = function() return 0 end
UnitXP = function() return 0 end
GetXPExhaustion = function() return nil end
Fire("PLAYER_LOGOUT")
check(me.money == 1234567 and me.xp == 4000 and me.rested == 2500, "logout keeps gold, XP and rested")
check(me.played == 90605, "played time saved at logout")

-- The login warning names the character whose mail runs out in 2 days
local said = {}
local Say = ns.Say
ns.Say = function(msg) said[#said + 1] = msg end
Fire("PLAYER_LOGIN")
RunTimers()
ns.Say = Say
check(#said == 1 and said[1]:find("Aelin Galathynius") and said[1]:find("expiring in 2d"), "login warns about expiring mail")

ns:Forget("Dreamscythe|Borin Stonefist")
check(db.chars["Dreamscythe|Borin Stonefist"] == nil, "forget removes a character")

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
