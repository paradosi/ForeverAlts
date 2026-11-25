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
    -- Like the game: runs after the current handler, and SetScript later replaces both
    HookScript = function(self, k, fn)
        local before = self.scripts[k]
        self.scripts[k] = function(...)
            if before then before(...) end
            fn(...)
        end
    end,
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
function CreateFrame(kind, name, parent)
    local f = NewWidget(kind)
    f.parent = parent or false
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
function UnitRace() return "Human", "Human", 1 end
function UnitSex() return 3 end
function UnitStat(_, i) return 0, ({ 40, 30, 50, 60, 55 })[i] end
function UnitArmor() return 100, 420 end
function UnitHealthMax() return 900 end
function UnitPowerMax() return 1500 end
function UnitPowerType() return 0, "MANA" end
function UnitAttackPower() return 50, 0, 0 end
function UnitRangedAttackPower() return 20, 0, 0 end
function UnitResistance(_, school) return 0, school == 4 and 15 or 0 end
function GetCritChance() return 5.1 end
function GetRangedCritChance() return 4.2 end
function GetSpellCritChance() return 7.25 end
function GetDodgeChance() return 3.5 end
function GetParryChance() return 0 end
function GetBlockChance() return 0 end
function GetSpellBonusDamage() return 34 end
function GetSpellBonusHealing() return 30 end
function GetGuildInfo() return "Night Watch", "Officer" end
function InCombatLockdown() return false end
function GetRaceAtlas(race, sex, hi) return (hi and "raceicon128-" or "raceicon-") .. race .. "-" .. sex end
function GetClassAtlas(class) return "classicon-" .. class end
CLASS_ICON_TCOORDS = { MAGE = { 0.25, 0.5, 0, 0.25 }, WARRIOR = { 0, 0.25, 0, 0.25 } }
C_Texture = { GetAtlasInfo = function(name) return { name = name } end }
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
    GetDetailedItemLevelInfo = function() return 12 end,
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
-- The character dropdown lists everyone with talents and switches the trees
do
    -- A second character with talents, so there is someone to switch to
    local borin = ForeverAltsDB.chars["Dreamscythe|Borin Stonefist"]
    borin.talents = ns.me.talents
    SlashCmdList.FOREVERALTS("talents")
    local talentsView
    for _, f in ipairs(allFrames) do if rawget(f, "charDrop") then talentsView = f end end
    local drop = talentsView.charDrop
    drop.scripts.OnClick(drop)
    local rows = {}
    for _, r in ipairs(drop.list.rows) do if r.shown and r.ch then rows[#rows + 1] = r end end
    check(drop.list.shown and #rows == 2, "dropdown: opens with a row per character with talents (" .. #rows .. ")")
    check(rows[1].parent == drop.list, "dropdown: rows belong to the list, drawn above it")
    local other
    for _, r in ipairs(rows) do if r.ch.key ~= talentsView.pick then other = r end end
    local name = other.ch.name
    other.scripts.OnClick(other)
    check(not drop.list.shown and talentsView.pick == other.ch.key and drop.label.text:find(name, 1, true) ~= nil,
        "dropdown: picking a character closes the list and shows them")
    borin.talents = nil
    talentsView.pick = false
end
-- The open tab keeps its glow; another tab glows only while hovered
do
    local chars, items
    for _, f in ipairs(allFrames) do
        if rawget(f, "text") and f.text.text == "CHARACTERS" then chars = f end
        if rawget(f, "text") and f.text.text == "ITEMS" then items = f end
    end
    SlashCmdList.FOREVERALTS("")
    if not ForeverAltsFrame.shown then SlashCmdList.FOREVERALTS("") end
    items.IsMouseOver = function() return false end
    items.scripts.OnClick(items)
    check(items.hoverGlow and items.hoverGlow.on, "tabs: the open tab glows")
    items.scripts.OnLeave(items)
    check(items.hoverGlow.on, "tabs: and keeps glowing when the pointer leaves")
    chars.IsMouseOver = function() return false end
    chars.scripts.OnClick(chars)
    check(not items.hoverGlow.on and chars.hoverGlow.on, "tabs: the glow moves with the open tab")
end

-- The running glow: fades in, keeps every segment on the box's edge, fades out and hides
do
    local box = CreateFrame("Frame")
    local g = ns.T.Glow(box)
    g.GetWidth = function() return 100 end
    g.GetHeight = function() return 40 end
    local placed = {}
    for _, t in ipairs(g.segs) do
        t.SetPoint = function(_, p, _, _, x, y) placed[t] = { p = p, x = x or 0, y = y or 0 } end
        t.SetSize = function(_, w, h) placed[t].w, placed[t].h = w, h end
    end
    g:SetActive(true)
    local ok = true
    for _ = 1, 50 do
        g.scripts.OnUpdate(g, 0.037)
        for _, q in pairs(placed) do
            local x, y = math.abs(q.x), math.abs(q.y)
            if x + q.w > 100.01 or y + q.h > 40.01 or q.w <= 0 or q.h <= 0 then ok = false end
        end
    end
    check(g.alpha == 1 and ok, "glow: fades in and stays on the border")
    g:SetActive(false)
    for _ = 1, 20 do if g.shown then g.scripts.OnUpdate(g, 0.05) end end
    check(g.alpha == 0 and not g.shown, "glow: fades out and hides")
end

C_Spell.GetSpellName = C_Spell.GetSpellName or function(id) return "Spell " .. id end
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
local book = ForeverAltsDB.plans.MAGE
check(book.list and book.active == "Plan 1", "plans: an old single plan becomes \"Plan 1\"")
local p1 = book.list["Plan 1"]
check(#p1.order == 6 and p1.order[6] == 3020, "plan: points kept in the order they were added")

-- Named plans: copy one out, paste it back as a second plan, rename, delete
local text = ns.ExportPlan("MAGE", p1)
check(text == "FA1;MAGE;1;3010=5,3020=1;3010.3010.3010.3010.3010.3020", "plans: copied as one line (" .. text .. ")")
local ok, got = ns.ImportPlan(text)
check(ok and got.class == "MAGE" and got.plan.scratch and got.plan.ranks[3010] == 5 and #got.plan.order == 6, "plans: pasted back the same")
check(not ns.ImportPlan("hello"), "plans: rubbish is refused")
check(ns.AddPlan(book, ns.NewPlanName(book, "Pasted"), got.plan) == nil and book.active == "Pasted 1", "plans: pasted plan added and chosen")
check(ns.RenamePlan(book, "Pasted 1", "Plan 1") ~= nil, "plans: rename refuses a name in use")
ns.RenamePlan(book, "Pasted 1", "Fire raid")
check(book.list["Fire raid"] and book.active == "Fire raid", "plans: renamed")
SlashCmdList.FOREVERALTS("plan")
check(foot():find("0/6/0", 1, true) ~= nil, "plans: the tab draws the chosen plan")
ns.DeletePlan(book, "Fire raid")
check(book.active == "Plan 1" and not book.list["Fire raid"], "plans: deleted, back to the other")
ns.DeletePlan(book, "Plan 1")
check(book.active == "Plan 1" and next(book.list["Plan 1"].ranks) == nil, "plans: deleting the last leaves an empty one")

-- Level order: Aelin has 7 points learned (3010 at 5, 3020 at 2); the plan adds a third 3020, then two 3030
local spec = ns.ActiveSpec(ns.me)
local lp = { scratch = false, ranks = { [3020] = 3, [3030] = 2 }, order = { 3020, 3030, 3030 } }
local steps = ns.PlanSteps(lp, spec)
check(#steps == 3 and steps[1].level == 17 and steps[1].rank == 3 and steps[3].level == 19 and steps[3].rank == 2,
    "order: from current, planned points follow the learned ones")
check(ns.NextStep(lp, spec).key == 3020, "order: next step is the first not yet learned")
local sp = { scratch = true, ranks = { [3010] = 2 }, order = { 3010, 3010 } }
check(ns.PlanSteps(sp, spec)[1].level == 10, "order: from scratch starts at level 10")
-- The reminder names the next talent once, when there are points to spend
book.list["Plan 1"] = lp
local unspent = spec.unspent
spec.unspent = 2
local told, RealSay = {}, ns.Say
ns.Say = function(msg) told[#told + 1] = msg end
ns.RemindPlan(); ns.RemindPlan()
ns.Say = RealSay
spec.unspent = unspent
check(#told == 1 and told[1]:find("next talent in \"Plan 1\"", 1, true) and told[1]:find("rank 3", 1, true), "order: reminder said once")
SlashCmdList.FOREVERALTS("plan")
check(foot():find("next: ", 1, true) ~= nil, "order: footer names the next talent")

-- Every text button glows on hover; LEVEL ORDER keeps its list and gets the glow too;
-- the talents use the brighter, thicker style
do
    local view
    for _, f in ipairs(allFrames) do if rawget(f, "planActions") then view = f end end
    local order, new = view.planActions.order, view.planActions.new
    new.IsMouseOver = function() return false end
    new.scripts.OnEnter(new)
    check(new.hoverGlow and new.hoverGlow.on, "buttons: + NEW glows on hover")
    new.scripts.OnLeave(new)
    check(not new.hoverGlow.on, "buttons: and stops when the pointer leaves")
    local shown = false
    local RealShow = GameTooltip.Show
    GameTooltip.Show = function() shown = true end
    order.scripts.OnEnter(order)
    GameTooltip.Show = RealShow
    check(shown and order.hoverGlow and order.hoverGlow.on, "buttons: LEVEL ORDER shows its list and glows")
    check(view.nextGlow and view.nextGlow.thick == 2.25 and view.nextGlow.len > 0.2, "talents: the next talent's glow is the bright, thicker one")
end

-- The game's talent window: the next planned talent's button gets the glow
do
    local buttons = {}
    for _, id in ipairs({ 3010, 3020, 3030 }) do
        local b = CreateFrame("Button")
        b.GetSpellID = function() return id end
        buttons[#buttons + 1] = b
    end
    local tf = CreateFrame("Frame")
    tf.IsVisible = function() return true end
    tf.EnumerateAllTalentButtons = function()
        local i = 0
        return function() i = i + 1; return buttons[i] end
    end
    PlayerSpellsFrame = { TalentsFrame = tf }
    local target
    local Real = ns.T.Glow
    ns.T.Glow = function(owner, parent)
        local g = Real(owner, parent)
        local SetTarget = g.SetTarget
        g.SetTarget = function(self, f) target = f; SetTarget(self, f) end
        return g
    end
    ns.GameTalentGlow()
    ns.T.Glow = Real
    check(target == buttons[2], "game window: the next talent (3020) glows")
    ns.settings.planGlow = false
    target = nil
    ns.GameTalentGlow()
    check(target == nil, "game window: off in options, no glow")
    ns.settings.planGlow = true
    PlayerSpellsFrame = nil
end
SlashCmdList.FOREVERALTS("locks")
check(ForeverAltsFrame.footer.text:find("1 of 2 characters saved", 1, true) ~= nil, "lockouts: tab renders the grid")
now = now + 5 * 86400
ns.ShowUI("locks")
check(ForeverAltsFrame.footer.text:find("0 of 2 characters saved", 1, true) ~= nil, "lockouts: a lockout past its reset is over")
now = now - 5 * 86400
-- The right-click menu: our own, at the pointer; its rows glow and act
do
    GetCursorPosition = GetCursorPosition or function() return 500, 400 end
    local row = { item = ForeverAltsDB.chars["Dreamscythe|Borin Stonefist"] }
    ns.CharacterMenu(row)
    local menuFrame
    for _, f in ipairs(allFrames) do if rawget(f, "closeArmed") ~= nil then menuFrame = f end end
    local texts = {}
    for _, r in ipairs(menuFrame.rows) do if r.shown then texts[#texts + 1] = r.text.text end end
    check(menuFrame.shown and texts[2] == "Browse items" and texts[#texts] == "Forget this character",
        "menu: shows the character's actions (" .. #texts .. ")")
    local browse
    for _, r in ipairs(menuFrame.rows) do if r.shown and r.text.text == "Browse items" then browse = r end end
    browse.IsMouseOver = function() return false end
    browse.scripts.OnEnter(browse)
    check(browse.hoverGlow and browse.hoverGlow.on, "menu: a row glows on hover")
    browse.scripts.OnClick(browse)
    check(not menuFrame.shown and ForeverAltsFrame.footer.text:find("Borin Stonefist", 1, true) ~= nil,
        "menu: a click acts (Borin's items) and closes it")
    ns.ShowUI("items", "", false)
    ns.ShowUI("chars")
end

-- Reputation: one character from the dropdown gets the game-window list with exact numbers
do
    ns.ShowUI("reps", "", ns.meKey)
    local view
    for _, f in ipairs(allFrames) do if rawget(f, "one") and rawget(f, "drop") then view = f end end
    view.one.scripts.OnSizeChanged(view.one, 800, 400)
    local honored
    for _, r in ipairs(view.one.rows) do if r.shown and r.num.text == "4,000 / 12,000" then honored = r end end
    check(view.one.shown and not view.list.shown and honored and honored.standing.text == "Honored",
        "reputation: one character shows standing and exact numbers")
    check(ForeverAltsFrame.footer.text:find("Exalted", 1, true) ~= nil, "reputation: the footer counts standings")
    ns.ShowUI("reps", "", false)
    check(view.list.shown and not view.one.shown and view.drop.label.text:find("ALL", 1, true) ~= nil,
        "reputation: all characters goes back to the comparison")
end

-- Items: one character from the dropdown shows a grid by place; the search filters it
do
    ns.ShowUI("items", "", "Dreamscythe|Borin Stonefist")
    local view
    for _, f in ipairs(allFrames) do if rawget(f, "grid") and rawget(f, "drop") then view = f end end
    local rows = view.grid.data
    local heads = {}
    for _, r in ipairs(rows) do if r.head then heads[#heads + 1] = r.head end end
    check(view.grid.shown and not view.list.shown and table.concat(heads, ",") == "BAGS,BANK,MAIL,EQUIPPED",
        "items grid: a section per place (" .. table.concat(heads, ",") .. ")")
    local bank
    for _, r in ipairs(rows) do if r.head == "BANK" then bank = r end end
    check(bank.missing and bank.info:find("open a bank on Borin Stonefist", 1, true) ~= nil, "items grid: an unvisited bank says how to record it")
    check(rows[2].icons and rows[2].icons[1].id == 2589 and rows[2].icons[1].n == 7, "items grid: bags hold Borin's 7 of item 2589")
    check(view.drop.label.text:find("Borin Stonefist", 1, true) ~= nil, "items grid: the dropdown shows who")
    view.search:SetText("zzz")
    view.search.scripts.OnTextChanged(view.search)
    check(#view.grid.data == 0 and view.hint.shown, "items grid: a search with no match says so")
    view.search:SetText("")
    view.search.scripts.OnTextChanged(view.search)
    -- ALL CHARACTERS goes back to the search across everyone
    view.drop.scripts.OnClick(view.drop)
    local all
    for _, r in ipairs(view.drop.list.rows) do if r.shown and r.entry and r.entry.key == false then all = r end end
    all.scripts.OnClick(all)
    check(view.list.shown and not view.grid.shown, "items grid: ALL CHARACTERS returns to the search")
end
-- Armory: the character you're on gets the live model and its stats; an alt gets the crest
do
    check(me.stats and me.stats[3] == 50 and me.stats.armor == 420 and me.stats.res[4] == 15 and me.guild == "Night Watch"
        and me.sex == 3 and me.raceFile == "Human", "armory: stats, guild, race and sex recorded at login")
    ns.ShowArmory()
    local view
    for _, f in ipairs(allFrames) do if rawget(f, "weapons") then view = f end end
    local chest
    for _, b in ipairs(view.slots) do if b.slot == 5 then chest = b end end
    check(chest.itemID == 6097 and chest.name.text:find("Acolyte's Shirt", 1, true) and chest.sub.text:find("ilvl 12", 1, true),
        "armory: the chest slot shows the saved item, name and item level")
    check(view.model.shown and not view.crest.shown, "armory: your own character gets the live model")
    local text = {}
    for _, l in ipairs(view.stats.lines) do if l.label.shown then text[#text + 1] = l.label.text .. "=" .. l.value.text end end
    text = table.concat(text, ";")
    check(text:find("Stamina=50", 1, true) and text:find("Mana=1,500", 1, true) and not view.stats.hint.shown and text:find("Frost resist=15", 1, true)
        and text:find("Spell crit=7.25%", 1, true), "armory: the stats panel lists them")
    ns.ShowArmory("Dreamscythe|Borin Stonefist")
    check(not view.render.shown, "armory: no picture without the data addon")
    check(not view.model.shown and view.classCrest.shown and view.stats.hint.shown and view.stats.hint.text:find("log in on Borin", 1, true)
        and not view.stats.lines[1].label.shown,
        "armory: an alt gets the crest, and a hint where stats are missing")
    ForeverAltsRenders = { ["borin stonefist"] = { file = "borin-stonefist", updated = now - 7200 } }
    ns.ShowArmory("Dreamscythe|Borin Stonefist")
    check(view.render.shown and not view.classCrest.shown and not view.crest.shown
        and view.modelHint.text:find("Armory picture, 2h ago", 1, true), "armory: an alt's Armory picture replaces the crest")
    ForeverAltsRenders = nil
end
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
