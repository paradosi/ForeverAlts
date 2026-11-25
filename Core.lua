---- Core — saved data, the character key, shared helpers and the event bus

local addonName, ns = ...

ns.name = addonName

-- Settings, all account-wide. A new key here reaches old saves at load.
ns.defaults = {
    tooltip      = true,   -- item counts per character on item tooltips
    tooltipCraft = true,   -- "Made by" line on items an alt can craft
    allRealms    = true,   -- count characters on every realm, not just this one
    tooltipSelf  = true,   -- include the character you are playing in the counts
    sameFaction  = false,  -- tooltips count only characters of your faction
    sameRuleset  = false,  -- tooltips count only characters on your ruleset
    mailWarn     = true,   -- at login, name characters whose mail is about to expire
    sortKey      = "level",
    sortDesc     = true,
}

local db

---- Event bus: any file can listen with ns:On(event, fn); fn gets (...) of the event

local events = CreateFrame("Frame")
local handlers = {}

function ns:On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        events:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end

events:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event]) do fn(...) end
end)

-- Coalesce bursts (BAG_UPDATE fires per bag, TRADE_SKILL_LIST_UPDATE several times)
local pending = {}
function ns:Debounce(key, delay, fn)
    if pending[key] then return end
    pending[key] = true
    C_Timer.After(delay, function()
        pending[key] = nil
        fn()
    end)
end

---- Who am I. Forever names are "First Last": UnitName returns the two halves
---- separately, so the key joins them or two alts sharing a first name collide.

function ns.PlayerName()
    local first, last = UnitName("player")
    if not first or (canaccessvalue and not canaccessvalue(first)) then return nil end
    if last and (not canaccessvalue or canaccessvalue(last)) and last ~= "" then
        return first .. " " .. last
    end
    return first
end

function ns.CharKey(name, realm)
    return realm .. "|" .. name
end

-- Every stored character, as a list of tables carrying their own .key
function ns:Characters(realmOnly)
    local list = {}
    local realm = GetRealmName()
    for key, c in pairs(db.chars) do
        if not realmOnly or c.realm == realm then
            c.key = key
            table.insert(list, c)
        end
    end
    return list
end

function ns:Forget(key)
    if key == ns.meKey then
        ns.Say("that's the character you're playing; it will be recorded again at once.")
        return
    end
    local c = db.chars[key]
    db.chars[key] = nil
    ns.craftIndex = nil
    if c then ns.Say("forgot " .. c.name .. " (" .. c.realm .. ").") end
    if ns.RefreshUI then ns.RefreshUI() end
end

---- Formatting

function ns.Say(msg)
    print("|cffe3b664Forever Alts|r: " .. msg)
end

local function Commas(n)
    local s = tostring(math.floor(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end
ns.Commas = Commas

-- 12,345g 06s 07c, coloured like coins. short drops silver and copper above 100 gold.
function ns.Money(copper, short)
    copper = copper or 0
    local g = math.floor(copper / 10000)
    local s = math.floor(copper / 100) % 100
    local c = copper % 100
    local G, S, C = "|cffe3b664g|r", "|cffc2c8das|r", "|cffd9905fc|r"
    if g > 0 then
        if short and g >= 100 then return Commas(g) .. G end
        return string.format("%s%s %02d%s %02d%s", Commas(g), G, s, S, c, C)
    elseif s > 0 then
        return string.format("%d%s %02d%s", s, S, c, C)
    end
    return c .. C
end

-- 3d 04h, 5h 12m, 9m
function ns.Duration(sec)
    if not sec then return "—" end
    sec = math.floor(sec)
    local d, h, m = math.floor(sec / 86400), math.floor(sec / 3600) % 24, math.floor(sec / 60) % 60
    if d > 0 then return string.format("%dd %02dh", d, h) end
    if h > 0 then return string.format("%dh %02dm", h, m) end
    return m .. "m"
end

function ns.Ago(t)
    if not t then return "never" end
    local sec = time() - t
    if sec < 120 then return "now" end
    if sec < 3600 then return math.floor(sec / 60) .. "m ago" end
    if sec < 86400 then return math.floor(sec / 3600) .. "h ago" end
    return math.floor(sec / 86400) .. "d ago"
end

function ns.ClassHex(classFile)
    local c = classFile and C_ClassColor.GetClassColor(classFile)
    return c and c:GenerateHexColor() or "ffc2c8da"
end

function ns.ColorName(c)
    return "|c" .. ns.ClassHex(c.class) .. c.name .. "|r"
end

---- Live values for characters that aren't logged in

-- Played time keeps counting for the character you're on: the stored total plus
-- the time since it was taken. Alts' totals are as they logged out.
function ns.Played(c)
    if not c.played then return nil end
    if c == ns.me and c.playedAt then
        return c.played + (GetTime() - c.playedAt)
    end
    return c.played
end

-- Rested XP grows while you're offline: 5% of a level per 8 hours in an inn or city,
-- a quarter of that anywhere else, up to a level and a half. As a fraction of a level.
function ns.Rested(c)
    if not c.xpMax or c.xpMax == 0 or (c.maxLevel and c.level >= c.maxLevel) then return nil end
    local rested = c.rested or 0
    if c ~= ns.me and c.lastSeen then
        local rate = c.xpMax * 0.05 / (8 * 3600)
        if not c.resting then rate = rate / 4 end
        rested = rested + rate * math.max(0, time() - c.lastSeen)
    end
    return math.min(rested, c.xpMax * 1.5) / c.xpMax
end

---- Load

ns:On("ADDON_LOADED", function(name)
    if name ~= addonName then return end
    ForeverAltsDB = ForeverAltsDB or {}
    db = ForeverAltsDB
    db.version = 1
    db.settings = db.settings or {}
    for k, v in pairs(ns.defaults) do
        if db.settings[k] == nil then db.settings[k] = v end
    end
    db.chars   = db.chars or {}     -- "Realm|First Last" -> character
    db.items   = db.items or {}     -- itemID -> { name, quality, icon, link }: for search
    db.recipes = db.recipes or {}   -- recipeID -> { name, icon, item }
    db.warband = db.warband or {}   -- the account bank, shared by every character: { items, seen }
    db.factions = db.factions or {} -- factionID -> { name, group, order }
    db.groups  = db.groups or {}    -- reputation header -> its place in the list
    db.instances = db.instances or {} -- instance name -> { total, raid, players }: lockout columns
    -- Before 2026-11-25 an empty gear slot was saved as item 0 (Forever answers 0, not nil)
    for _, c in pairs(db.chars) do
        for _, t in pairs({ c.bags or false, c.bank or false, c.equipped or false, c.mail and c.mail.items or false }) do
            if t then t[0] = nil end
        end
    end
    db.items[0] = nil
    ns.db, ns.settings = db, db.settings
    if ns.OnLoad then ns.OnLoad() end
end)

---- Slash command and the addon compartment

function ForeverAlts_OnCompartmentClick()
    ns.ToggleUI()
end

SLASH_FOREVERALTS1 = "/alts"
SLASH_FOREVERALTS2 = "/foreveralts"
SlashCmdList.FOREVERALTS = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "" then
        ns.ToggleUI()
    elseif cmd == "items" or cmd == "search" or cmd == "find" then
        ns.ShowUI("items", rest)
    elseif cmd == "profs" or cmd == "professions" then
        ns.ShowUI("profs", rest)
    elseif cmd == "reps" or cmd == "rep" or cmd == "reputation" then
        ns.ShowUI("reps", rest)
    elseif cmd == "locks" or cmd == "lockouts" or cmd == "raids" then
        ns.ShowUI("locks")
    elseif cmd == "talents" or cmd == "talent" or cmd == "spec" then
        ns.ShowTalents(nil, "class")
    elseif cmd == "legacy" then
        ns.ShowTalents(nil, "legacy")
    elseif cmd == "options" or cmd == "config" then
        ns.OpenOptions()
    elseif cmd == "reset" then
        db.point, db.size = nil, nil
        if ns.ResetPosition then ns.ResetPosition() end
        ns.Say("window back to its usual size, in the middle.")
    else
        ns.Say("/alts opens the window · /alts items <name> searches every character's items · "
            .. "/alts profs <recipe> finds who can craft it · /alts reps <faction> · /alts locks · /alts talents · /alts legacy · /alts options · /alts reset (window size and position)")
    end
end
