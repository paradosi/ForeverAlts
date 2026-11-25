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
function GetInventoryItemID(_, slot) return slot == 5 and 6097 or nil end
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

-- Rested: 16h in an inn = 10% of a level on top of 0
local borin = db.chars["Dreamscythe|Borin Stonefist"]
check(math.abs(ns.Rested(borin) - 0.10) < 0.001, "offline rested XP grows 5% per 8h resting")
clock = clock + 600
check(ns.Played(me) == 90600, "played time keeps counting this session")
check(ns.Money(1234567) == "123|cffe3b664g|r 45|cffc2c8das|r 67|cffd9905fc|r", "money formatting")
check(ns.Commas(1234567) == "1,234,567" and ns.Commas(123456) == "123,456", "thousands separators")

-- Tooltip: Linen held by both characters plus the account bank
local lines = {}
local tip = { AddLine = function(_, t) lines[#lines + 1] = t end,
              AddDoubleLine = function(_, l, r) lines[#lines + 1] = l .. " = " .. r end }
for _, fn in ipairs(tooltipCalls) do fn(tip, { id = 2589 }) end
local text = table.concat(lines, "\n")
check(text:find("Aelin Galathynius|r = 55") ~= nil, "tooltip: this character 55 (40 bags + 15 bank)")
check(text:find("Borin Stonefist|r = 7") ~= nil, "tooltip: alt 7")
check(text:find("Account bank = 5") ~= nil and text:find("Total = 67") ~= nil, "tooltip: account bank and total")
lines = {}
for _, fn in ipairs(tooltipCalls) do fn(tip, { id = 2996 }) end
check(table.concat(lines):find("Made by") ~= nil, "tooltip: Made by line for a crafted item")

-- UI: every view, with and without a search
SlashCmdList.FOREVERALTS("")
check(ForeverAltsFrame and ForeverAltsFrame:IsShown(), "window opens")
SlashCmdList.FOREVERALTS("items linen")
SlashCmdList.FOREVERALTS("items")
SlashCmdList.FOREVERALTS("profs bolt")
SlashCmdList.FOREVERALTS("profs")
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
ns.ShowUI("items", "", "Dreamscythe|Borin Stonefist")
ns.ShowUI("chars")
RunTimers()
check(true, "all views rendered without errors")

-- Logout carries played time forward
Fire("PLAYER_LOGOUT")
check(me.played == 90600, "played time saved at logout")

ns:Forget("Dreamscythe|Borin Stonefist")
check(db.chars["Dreamscythe|Borin Stonefist"] == nil, "forget removes a character")

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
