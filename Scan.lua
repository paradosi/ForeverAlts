---- Scan — record the character you're playing: summary, bags, bank, gear, professions

local _, ns = ...

local me     -- this character's saved table (ns.me)
local bankOpen = false

-- Remember what an item is called, so search works for items no one has looked at
-- this session. The link carries the name; the client's item cache may not.
local function Remember(itemID, link, quality, icon)
    local items = ns.db.items
    local known = items[itemID]
    if known and known.name and known.name ~= "" and known.link then return end
    -- Forever writes links with empty brackets ("|h[]|h") for items not cached yet
    local name = link and link:match("%[(.-)%]")
    if not name or name == "" then name = C_Item.GetItemNameByID(itemID) end
    if not name or name == "" then return end
    items[itemID] = {
        name = name,
        quality = quality or C_Item.GetItemQualityByID(itemID),
        icon = icon or C_Item.GetItemIconByID(itemID),
        link = link,
    }
end
ns.Remember = Remember

-- Add one container's contents into counts (itemID -> count)
local function ReadContainer(bag, counts)
    local n = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, n do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and info.itemID and info.itemID > 0 then
            counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 1)
            Remember(info.itemID, info.hyperlink, info.quality, info.iconFileID)
        end
    end
    return n
end

---- Summary

local function ScanSummary()
    me.level    = UnitLevel("player")
    me.maxLevel = GetMaxLevelForPlayerExpansion()
    me.xp, me.xpMax = UnitXP("player"), UnitXPMax("player")
    me.rested   = GetXPExhaustion() or 0
    me.resting  = IsResting()
    me.money    = GetMoney()
    me.zone     = GetRealZoneText()
    local _, equipped = GetAverageItemLevel()
    me.ilvl     = equipped and math.floor(equipped + 0.5) or me.ilvl
    me.lastSeen = time()
end

---- Bags and gear

local BAGS = { Enum.BagIndex.Backpack, Enum.BagIndex.Bag_1, Enum.BagIndex.Bag_2,
               Enum.BagIndex.Bag_3, Enum.BagIndex.Bag_4, Enum.BagIndex.ReagentBag }

local function ScanBags()
    local counts, slots, free = {}, 0, 0
    for _, bag in ipairs(BAGS) do
        slots = slots + ReadContainer(bag, counts)
        free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
    end
    me.bags, me.bagSlots, me.bagFree = counts, slots, free
end

-- Slot 0 is the ranged ammo slot on Vanilla-content clients; 1-19 are gear
local function ScanGear()
    local gear, counts = {}, {}
    for slot = 0, 19 do
        local id = GetInventoryItemID("player", slot)
        -- Forever answers 0, not nil, for an empty slot (seen 2026-11-25: an "item 0" in search)
        if id and id > 0 then
            local link = GetInventoryItemLink("player", slot)
            gear[slot] = link or id
            counts[id] = (counts[id] or 0) + (slot == 0 and (GetInventoryItemCount("player", 0) or 1) or 1)
            Remember(id, link)
        end
    end
    me.gear, me.equipped = gear, counts
    local _, equipped = GetAverageItemLevel()
    if equipped then me.ilvl = math.floor(equipped + 0.5) end
end

---- Bank: the character bank tabs (bags 6-14), and the account bank tabs (15-23),
---- which every character shares. Readable only while the bank window is open.

local function ReadTabs(bankType)
    if not C_Bank.CanViewBank(bankType) then return nil end
    local tabs = C_Bank.FetchPurchasedBankTabData(bankType)
    if not tabs or #tabs == 0 then return nil end
    local counts = {}
    for _, tab in ipairs(tabs) do ReadContainer(tab.ID, counts) end
    return counts
end

local function ScanBank()
    if not bankOpen then return end
    local own = ReadTabs(Enum.BankType.Character)
    if own then me.bank, me.bankSeen = own, time() end
    local shared = ReadTabs(Enum.BankType.Account)
    if shared then ns.db.warband.items, ns.db.warband.seen = shared, time() end
end

---- Professions: skill levels always; known recipes when the profession window opens

local function ScanSkills()
    local profs = {}
    for _, index in ipairs({ GetProfessions() }) do
        local name, icon, rank, maxRank, _, _, skillLine = GetProfessionInfo(index)
        if name then
            table.insert(profs, { name = name, icon = icon, rank = rank, max = maxRank, skillLine = skillLine })
        end
    end
    me.profs = profs
end

local function ScanRecipes()
    -- Someone else's profession, a guild list or an NPC crafting order: not ours
    if C_TradeSkillUI.IsTradeSkillLinked() or C_TradeSkillUI.IsTradeSkillGuild()
        or C_TradeSkillUI.IsNPCCrafting() then return end
    local info = C_TradeSkillUI.GetBaseProfessionInfo()
    local prof = info and (info.parentProfessionName or info.professionName)
    if not prof or prof == "" then return end

    local known, n = {}, 0
    for _, id in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
        local r = C_TradeSkillUI.GetRecipeInfo(id)
        if r and r.learned then
            local s = C_TradeSkillUI.GetRecipeSchematic(id, false)
            local item = s and s.outputItemID
            known[id] = item or 0
            n = n + 1
            ns.db.recipes[id] = { name = r.name, icon = r.icon, item = item }
            if item then Remember(item, r.hyperlink and r.hyperlink:find("|Hitem:") and r.hyperlink or nil) end
        end
    end
    -- The list arrives in pieces; an empty read is a list not loaded yet, never "forgot everything"
    if n == 0 then return end
    me.recipes = me.recipes or {}
    me.recipes[prof] = known
    me.recipesSeen = me.recipesSeen or {}
    me.recipesSeen[prof] = time()
    ns.craftIndex = nil
    if ns.RefreshUI then ns.RefreshUI() end
end

---- Played time. RequestTimePlayed prints to chat, so it's asked for only once per
---- character (the first login with Forever Alts). After that the total is carried
---- forward with the session clock, and any /played you type corrects it.

ns:On("TIME_PLAYED_MSG", function(total, thisLevel)
    if not me then return end
    me.played, me.playedLevel, me.playedAt = total, thisLevel, GetTime()
end)

local function SavePlayed()
    if me and me.played then
        me.played = ns.Played(me)
        me.playedAt = GetTime()
    end
end

---- Wiring

local function Refresh()
    if ns.RefreshUI then ns.RefreshUI() end
end

ns:On("PLAYER_LOGIN", function()
    local name = ns.PlayerName()
    if not name then return end  -- a secret name: nothing sensible to file it under
    local realm = GetRealmName()
    local key = ns.CharKey(name, realm)
    local chars = ns.db.chars
    chars[key] = chars[key] or {}
    me = chars[key]
    ns.me, ns.meKey = me, key
    me.name, me.realm = name, realm
    -- Identity APIs can return secrets on Forever; the player's own normally don't,
    -- but a secret stored in saved variables would break every later comparison
    local function Plain(v) if v ~= nil and (not canaccessvalue or canaccessvalue(v)) then return v end end
    local _, class = UnitClass("player")
    me.class   = Plain(class) or me.class
    me.race    = Plain((UnitRace("player"))) or me.race
    local _, raceFile = UnitRace("player")
    me.raceFile = Plain(raceFile) or me.raceFile          -- "Orc", "Scourge": names the race crest
    me.sex     = Plain(UnitSex("player")) or me.sex       -- 2 male, 3 female
    me.faction = Plain((UnitFactionGroup("player"))) or me.faction
    -- The ruleset (Normal, PvP, Roleplay…). Forever has no realm names, but a character's
    -- GUID still carries its home server: "Player-<server>-<id>", the same for every
    -- character on one ruleset. GetRealmID() is kept beside it as a cross-check.
    local guid = Plain(UnitGUID("player"))
    me.server  = guid and tonumber(guid:match("^Player%-(%d+)%-")) or me.server
    me.realmID = Plain(GetRealmID()) or me.realmID
    if me.played then me.playedAt = GetTime() end

    ScanSummary()
    ScanBags()
    ScanGear()
    ns.ScanStats()
    ScanSkills()
    ns.craftIndex = nil

    -- Professions can be empty this early; ask again once the skill lines are in
    C_Timer.After(3, ScanSkills)
    if not me.played then
        -- C_Timer.After on Forever rejects a C function as the callback: wrap it
        C_Timer.After(4, function() RequestTimePlayed() end)
    end
end)

---- Stats for the Armory tab: what the character sheet shows, as of the last change.
---- Read out of combat only (in combat they're busy, and some may be secrets).

local function Num(v) if type(v) == "number" and (not canaccessvalue or canaccessvalue(v)) then return v end end

function ns.ScanStats()
    if not me then return end
    if InCombatLockdown() then ns:Debounce("statsAfterCombat", 2, ns.ScanStats); return end
    local st = {}
    for i = 1, 5 do
        local _, effective = UnitStat("player", i)
        st[i] = Num(effective)
    end
    local _, armor = UnitArmor("player")
    st.armor = Num(armor)
    st.hp, st.power = Num(UnitHealthMax("player")), Num(UnitPowerMax("player"))
    local _, powerToken = UnitPowerType("player")
    st.powerType = type(powerToken) == "string" and (not canaccessvalue or canaccessvalue(powerToken)) and powerToken or nil
    local base, pos, neg = UnitAttackPower("player")
    if Num(base) then st.ap = base + (Num(pos) or 0) + (Num(neg) or 0) end
    base, pos, neg = UnitRangedAttackPower("player")
    if Num(base) then st.rap = base + (Num(pos) or 0) + (Num(neg) or 0) end
    st.crit, st.rcrit = Num(GetCritChance()), Num(GetRangedCritChance())
    st.scrit = Num(GetSpellCritChance(2))          -- 2: fire, as good as any school in Vanilla
    st.dodge, st.parry, st.block = Num(GetDodgeChance()), Num(GetParryChance()), Num(GetBlockChance())
    st.spell, st.heal = Num(GetSpellBonusDamage(2)), Num(GetSpellBonusHealing())
    st.res = {}
    for school = 2, 6 do                           -- fire, nature, frost, shadow, arcane
        local _, total = UnitResistance("player", school)
        st.res[school] = Num(total)
    end
    st.seen = time()
    me.stats = st
    local guild, rank = GetGuildInfo("player")
    me.guild = type(guild) == "string" and (not canaccessvalue or canaccessvalue(guild)) and guild or nil
    me.guildRank = me.guild and type(rank) == "string" and rank or nil
end

local function StatsSoon() if me then ns:Debounce("stats", 1, ns.ScanStats) end end
ns:On("UNIT_STATS", function(unit) if unit == "player" then StatsSoon() end end)
ns:On("UNIT_ATTACK_POWER", function(unit) if unit == "player" then StatsSoon() end end)
ns:On("UNIT_RESISTANCES", function(unit) if unit == "player" then StatsSoon() end end)
ns:On("UNIT_MAXHEALTH", function(unit) if unit == "player" then StatsSoon() end end)
ns:On("PLAYER_GUILD_UPDATE", StatsSoon)

ns:On("PLAYER_MONEY", function() if me then me.money = GetMoney(); Refresh() end end)
ns:On("PLAYER_XP_UPDATE", function() if me then ScanSummary() end end)
ns:On("UPDATE_EXHAUSTION", function() if me then me.rested = GetXPExhaustion() or 0 end end)
ns:On("PLAYER_UPDATE_RESTING", function() if me then me.resting = IsResting() end end)
ns:On("PLAYER_LEVEL_UP", function() if me then C_Timer.After(1, ScanSummary) end end)
ns:On("ZONE_CHANGED_NEW_AREA", function() if me then me.zone = GetRealZoneText() end end)
ns:On("PLAYER_EQUIPMENT_CHANGED", function()
    if me then ns:Debounce("gear", 0.5, ScanGear); StatsSoon() end
end)
ns:On("SKILL_LINES_CHANGED", function() if me then ns:Debounce("skills", 1, ScanSkills) end end)

ns:On("BAG_UPDATE_DELAYED", function()
    if not me then return end
    ScanBags()
    ScanBank()
    Refresh()
end)

local function BankOpened()
    bankOpen = true
    -- The tabs' contents can trail the window by a frame or two
    C_Timer.After(0.3, function() ScanBank(); Refresh() end)
end
local function BankClosed()
    if not bankOpen then return end
    ScanBank()
    bankOpen = false
end
-- Retail's banker interaction fires both of these; either one is enough
ns:On("BANKFRAME_OPENED", BankOpened)
ns:On("BANKFRAME_CLOSED", BankClosed)
ns:On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(kind)
    if kind == Enum.PlayerInteractionType.Banker then BankOpened() end
end)
ns:On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(kind)
    if kind == Enum.PlayerInteractionType.Banker then BankClosed() end
end)
ns:On("BANK_TABS_CHANGED", function() C_Timer.After(0.3, ScanBank) end)

ns:On("TRADE_SKILL_LIST_UPDATE", function() if me then ns:Debounce("recipes", 0.5, ScanRecipes) end end)
ns:On("TRADE_SKILL_SHOW", function() if me then ns:Debounce("recipes", 0.5, ScanRecipes) end end)
ns:On("NEW_RECIPE_LEARNED", function() if me then ns:Debounce("recipes", 0.5, ScanRecipes) end end)

-- Only the clock at logout. By PLAYER_LOGOUT Forever has torn the character down:
-- GetMoney(), UnitXP() and GetXPExhaustion() all return 0 (seen 2026-11-25, every
-- character saved with 0 gold). Gold, XP and rested are kept current by their own
-- events above, so nothing needs reading here.
ns:On("PLAYER_LOGOUT", function()
    if not me then return end
    me.lastSeen = time()
    SavePlayed()
end)
