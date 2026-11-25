---- Talents — each character's talent build, enough to redraw its trees
--
-- Forever's talent window is Retail's trait system wearing the three Vanilla trees:
-- one trait tree per class, its nodes split into three groups (the trees), with dual
-- spec as two configs. Stored per character as
--   c.talents = { active = spec group, seen, specs = { [group] = {
--       trees = { { name, icon, spent } },  -- in the game's order
--       nodes = { { x, y, t = tree, s = spellID, i = icon, r = rank, m = max, e = { node index } } },
--       unspent, code } } }
-- and the Legacy System's trees, in the same shape, as c.legacy (with renown, cap, seen).
-- x and y are the game's own layout positions; the view turns them into a grid.

local _, ns = ...

local function Plain(v)
    if v ~= nil and (not canaccessvalue or canaccessvalue(v)) then return v end
end

-- Every visible talent of one trait tree, with its rank and outgoing arrows. treeOf(node)
-- names which of the drawn trees a node belongs to (nil leaves it out).
local function ReadNodes(configID, treeID, treeOf)
    local nodes, index = {}, {}
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
        local n = C_Traits.GetNodeInfo(configID, nodeID)
        local tree = n and n.isVisible and n.ID and n.ID > 0 and treeOf(n)
        if tree then
            local entryID = (n.activeEntry and n.activeEntry.entryID) or (n.entryIDs and n.entryIDs[1])
            local entry = entryID and C_Traits.GetEntryInfo(configID, entryID)
            local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
            local spell = def and (def.spellID or def.overriddenSpellID)
            local icon = def and def.overrideIcon and def.overrideIcon > 0 and def.overrideIcon
            if spell or icon then
                nodes[#nodes + 1] = {
                    x = n.posX, y = n.posY, t = tree, s = spell,
                    i = icon or C_Spell.GetSpellTexture(spell),
                    n = def and Plain(def.overrideName) or nil,
                    r = n.currentRank or n.ranksPurchased or 0, m = n.maxRanks or 1,
                    out = n.visibleEdges,
                }
                index[nodeID] = #nodes
            end
        end
    end
    -- Prerequisite arrows, as indexes into the saved node list
    for _, node in ipairs(nodes) do
        local e = {}
        for _, edge in ipairs(node.out or {}) do
            if index[edge.targetNode] then e[#e + 1] = index[edge.targetNode] end
        end
        node.out = nil
        if #e > 0 then node.e = e end
    end
    return nodes
end

-- The class trees of one spec's config, or nil when it can't be read (a low-level character has none)
local function ReadConfig(configID)
    local info = configID and C_Traits.GetConfigInfo(configID)
    local treeID = info and info.treeIDs and info.treeIDs[1]
    if not treeID then return nil end

    local groups = C_Traits.GetGroupDisplayInfoByTreeID(treeID) or {}
    if #groups == 0 then return nil end
    table.sort(groups, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
    local trees, treeOf, ids = {}, {}, {}
    for i, g in ipairs(groups) do
        trees[i] = { name = Plain(g.displayName) or "", icon = g.icon, spent = 0 }
        treeOf[g.groupID] = i
        ids[i] = g.groupID
    end
    for _, gi in ipairs(C_Traits.GetGroupCurrencyInfo(configID, ids) or {}) do
        local i, cur = treeOf[gi.traitNodeGroupID], gi.currencyInfos and gi.currencyInfos[1]
        if i and cur then trees[i].spent = cur.spent or 0 end
    end

    local nodes = ReadNodes(configID, treeID, function(n)
        for _, g in ipairs(n.groupIDs or {}) do if treeOf[g] then return treeOf[g] end end
    end)
    if #nodes == 0 then return nil end

    local unspent = 0
    for _, cur in ipairs(C_Traits.GetTreeCurrencyInfo(configID, treeID, false) or {}) do
        unspent = unspent + (cur.quantity or 0)
    end
    local ok, code = pcall(C_Traits.GenerateImportString, configID)
    return { trees = trees, nodes = nodes, unspent = unspent, code = ok and Plain(code) or nil }
end

---- The Legacy System: Forever's own three trees (Professions, Adventure, Progression),
---- bought with Legacy points from Legacy challenges, opened by the Legacy renown track.
---- The IDs are Blizzard's Constants.LegacyConsts, with their values as a fallback.

local LC = (Constants and Constants.LegacyConsts) or {}
local LEGACY_FACTION = LC.LEGACY_REWARD_TRACK_FACTION_ID or 2802
local LEGACY_TREES = {
    { id = LC.LEGACY_TREE_PROFESSIONS_ID or 1187, name = _G.LEGACY_TREE_PROFESSIONS or "Professions", atlas = "UI-Legacy-Tree-Professions" },
    { id = LC.LEGACY_TREE_ADVENTURE_ID or 1188,   name = _G.LEGACY_TREE_ADVENTURE or "Adventure",     atlas = "UI-Legacy-Tree-Adventure" },
    { id = LC.LEGACY_TREE_PROGRESSION_ID or 1189, name = _G.LEGACY_TREE_PROGRESSION or "Progression", atlas = "UI-Legacy-Tree-Progression" },
}

local function ReadLegacy()
    local renown = C_MajorFactions and C_MajorFactions.GetCurrentRenownLevel(LEGACY_FACTION) or 0
    if not renown or renown <= 0 then return nil end  -- the Legacy System isn't open to this character yet
    local trees, nodes, available, cap = {}, {}, nil, nil
    for i, lt in ipairs(LEGACY_TREES) do
        local configID = C_Traits.GetConfigIDByTreeID(lt.id)
        trees[i] = { name = lt.name, atlas = lt.atlas, spent = 0 }
        if configID then
            local cur = (C_Traits.GetTreeCurrencyInfo(configID, lt.id, false) or {})[1]
            if cur then
                trees[i].spent = cur.spentInTree or cur.spent or 0
                available, cap = cur.quantity, cur.maxQuantity
            end
            for _, node in ipairs(ReadNodes(configID, lt.id, function() return i end)) do
                -- Arrows index the whole list: shift them past the trees already read
                if node.e then for k, target in ipairs(node.e) do node.e[k] = target + #nodes end end
                nodes[#nodes + 1] = node
            end
        end
    end
    if #nodes == 0 then return nil end
    return { trees = trees, nodes = nodes, unspent = available or 0, cap = cap, renown = renown, legacy = true }
end

local function ScanTalents()
    local me = ns.me
    if not me then return end
    local active = C_SpecializationInfo.GetActiveSpecGroup() or 1
    local specs = {}
    for group = 1, math.max(1, GetNumSpecGroups() or 1) do
        local configID = C_SpecializationInfo.GetCombatConfigIDForSpecGroup(group)
        if group == active then configID = C_ClassTalents.GetActiveConfigID() or configID end
        specs[group] = ReadConfig(configID)
    end
    local legacy = ReadLegacy()
    if legacy then legacy.seen = time(); me.legacy = legacy end
    -- Nothing readable (talents not loaded yet): keep what was recorded
    if next(specs) then me.talents = { active = active, specs = specs, seen = time() } end
    if ns.RefreshUI then ns.RefreshUI() end
    if ns.RemindPlan then ns.RemindPlan() end
    if ns.GameTalentGlow then ns.GameTalentGlow() end
end

local function Soon() ns:Debounce("talents", 1, ScanTalents) end
ns:On("PLAYER_LOGIN", function() C_Timer.After(3, ScanTalents) end)
ns:On("TRAIT_CONFIG_UPDATED", Soon)
ns:On("PLAYER_TALENT_UPDATE", Soon)
ns:On("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", Soon)
ns:On("CHARACTER_POINTS_CHANGED", Soon)
ns:On("PLAYER_LEVEL_UP", Soon)
ns:On("MAJOR_FACTION_RENOWN_LEVEL_CHANGED", Soon)

-- The spec a character is in, or nil
function ns.ActiveSpec(c)
    local t = c.talents
    return t and t.specs and (t.specs[t.active] or t.specs[1])
end

-- "Fire 0/21/5", the tree with the most points named; nil when nothing is spent
function ns.SpecSummary(spec)
    if not spec then return nil end
    local points, top, most = {}, nil, 0
    for i, tree in ipairs(spec.trees) do
        points[i] = tree.spent or 0
        if points[i] > most then top, most = tree.name, points[i] end
    end
    return table.concat(points, "/"), top
end

---- Talent plans, per class: db.plans[class] = { active = name, list = { name -> plan } },
---- a plan being { scratch, ranks = { spellID -> rank }, order = { spellID, … } }.
---- (Before named plans, db.plans[class] was one plan: it becomes "Plan 1".)

function ns.PlanBook(class)
    local plans = ns.db.plans
    local book = plans[class]
    if not book or book.ranks then
        book = { active = "Plan 1", list = { ["Plan 1"] = book or { scratch = false, ranks = {}, order = {} } } }
        plans[class] = book
    end
    if not book.list[book.active] then
        book.active = next(book.list)
        if not book.active then
            book.active = "Plan 1"
            book.list[book.active] = { scratch = false, ranks = {}, order = {} }
        end
    end
    return book
end

function ns.NewPlanName(book, base)
    base = base or "Plan"
    local n = 1
    while book.list[base .. " " .. n] do n = n + 1 end
    return base .. " " .. n
end

local function Trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- Each returns a message when it can't be done
function ns.AddPlan(book, name, plan)
    name = Trim(name)
    if name == "" then return "A plan needs a name." end
    if book.list[name] then return "There's already a plan called \"" .. name .. "\"." end
    book.list[name], book.active = plan, name
end

function ns.RenamePlan(book, old, new)
    new = Trim(new)
    if new == old then return end
    if new == "" then return "A plan needs a name." end
    if book.list[new] then return "There's already a plan called \"" .. new .. "\"." end
    book.list[new], book.list[old] = book.list[old], nil
    if book.active == old then book.active = new end
end

function ns.DeletePlan(book, name)
    book.list[name] = nil
    local names = {}
    for n in pairs(book.list) do names[#names + 1] = n end
    table.sort(names)
    book.active = names[1]
    if not book.active then
        book.active = "Plan 1"
        book.list[book.active] = { scratch = false, ranks = {}, order = {} }
    end
end

-- A plan as one line of text: FA1;CLASS;scratch;key=rank,…;key.key.… (the order points were added)
function ns.ExportPlan(class, plan)
    local ranks, keys = {}, {}
    for k in pairs(plan.ranks) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    for _, k in ipairs(keys) do ranks[#ranks + 1] = k .. "=" .. (plan.ranks[tonumber(k) or k] or plan.ranks[k]) end
    local order = {}
    for i, k in ipairs(plan.order) do order[i] = tostring(k) end
    return table.concat({ "FA1", class, plan.scratch and "1" or "0", table.concat(ranks, ","), table.concat(order, ".") }, ";")
end

-- Back from text: true, { class, plan } or false, why
function ns.ImportPlan(text)
    local version, class, scratch, ranks, order = Trim(text):match("^(FA%d);(%u+);([01]);([^;]*);?([^;]*)$")
    if version ~= "FA1" then return false, "That isn't a Forever Alts plan (they start with FA1;)." end
    if not LOCALIZED_CLASS_NAMES_MALE or not LOCALIZED_CLASS_NAMES_MALE[class] then
        return false, "That plan is for an unknown class (" .. class .. ")."
    end
    local plan = { scratch = scratch == "1", ranks = {}, order = {} }
    for k, r in ranks:gmatch("([^,=]+)=(%d+)") do
        r = tonumber(r)
        if r > 0 and r <= 5 then plan.ranks[tonumber(k) or k] = r end
    end
    for k in order:gmatch("[^%.]+") do plan.order[#plan.order + 1] = tonumber(k) or k end
    return true, { class = class, plan = plan }
end

---- Level order. A plan's order lists each point as it was added, so it is also the order to
---- learn them in. Planned from current, the plan's points come after the ones already learned;
---- from scratch, after a respec. Talent points come one per level from level 10.

local FIRST_TALENT_LEVEL = 10

local function Learned(spec)
    local ranks, total = {}, 0
    for _, node in ipairs(spec and spec.nodes or {}) do
        if node.s and (node.r or 0) > 0 then
            ranks[node.s] = node.r
            total = total + node.r
        end
    end
    return ranks, total
end

-- { { key, rank, level } } for every point in the plan's order; spec gives the learned ranks
function ns.PlanSteps(plan, spec)
    local learned, total = Learned(spec)
    local base = plan.scratch and 0 or total
    local steps, rank = {}, {}
    for _, key in ipairs(plan.order) do
        rank[key] = (rank[key] or (plan.scratch and 0 or (learned[key] or 0))) + 1
        steps[#steps + 1] = { key = key, rank = rank[key], level = FIRST_TALENT_LEVEL + base + #steps }
    end
    return steps
end

-- The first planned point this character hasn't learned, or nil
function ns.NextStep(plan, spec)
    local learned = Learned(spec)
    for _, step in ipairs(ns.PlanSteps(plan, spec)) do
        if (learned[step.key] or 0) < step.rank then return step end
    end
end

function ns.StepName(step)
    return (type(step.key) == "number" and C_Spell.GetSpellName(step.key)) or tostring(step.key)
end

-- When the character has points to spend, name the next talent of its class's active plan.
-- Said once per talent, so spending points elsewhere or a rescan doesn't repeat it.
local reminded
function ns.RemindPlan()
    local me = ns.me
    local spec = me and ns.ActiveSpec(me)
    local book = me and me.class and ns.db.plans[me.class]
    if not (ns.settings.planRemind and spec and (spec.unspent or 0) > 0 and book and book.list) then return end
    local plan = book.list[book.active]
    local step = plan and ns.NextStep(plan, spec)
    if not step then return end
    local id = book.active .. "|" .. tostring(step.key) .. "|" .. step.rank
    if id == reminded then return end
    reminded = id
    local link = type(step.key) == "number" and C_Spell.GetSpellLink and C_Spell.GetSpellLink(step.key)
    ns.Say("next talent in \"" .. book.active .. "\": " .. (link or ns.StepName(step)) .. " rank " .. step.rank
        .. " (" .. spec.unspent .. " point" .. (spec.unspent == 1 and "" or "s") .. " to spend).")
end

---- The plan in the game's talent window: the next talent to learn wears the same running
---- gold glow as in the planner. Our own frame, laid over Blizzard's button: nothing of
---- theirs is changed (their search highlight would taint the window), only read.

local gameGlow

function ns.GameTalentGlow()
    local tf = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    local function Off() if gameGlow then gameGlow:SetActive(false) end end
    if not (tf and tf:IsVisible() and ns.settings.planGlow and tf.EnumerateAllTalentButtons) then return Off() end
    local me = ns.me
    local spec = me and ns.ActiveSpec(me)
    local book = me and me.class and ns.db.plans[me.class]
    local plan = spec and book and book.list and book.list[book.active]
    local step = plan and ns.NextStep(plan, spec)
    if not step then return Off() end
    local target
    for button in tf:EnumerateAllTalentButtons() do
        local id = button:IsShown() and button.GetSpellID and button:GetSpellID()
        if id and (not canaccessvalue or canaccessvalue(id)) and id == step.key then target = button; break end
    end
    if not target then return Off() end
    gameGlow = gameGlow or ns.T.Glow(target, tf)
    gameGlow.thick = 2
    gameGlow:SetTarget(target)
    gameGlow:SetActive(true)
end

local function GlowSoon() C_Timer.After(0.2, ns.GameTalentGlow) end
local hooked = false
local function HookTalentWindow()
    local tf = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if hooked or not tf then return end
    hooked = true
    tf:HookScript("OnShow", GlowSoon)
    tf:HookScript("OnHide", function() if gameGlow then gameGlow:SetActive(false) end end)
end
ns:On("ADDON_LOADED", function(name)
    if name == "Blizzard_PlayerSpells" then HookTalentWindow() end
end)
ns:On("PLAYER_LOGIN", HookTalentWindow)  -- in case it loaded before us
-- After a point is spent (or the talent window redraws its buttons), place it again
ns:On("TRAIT_CONFIG_UPDATED", function() C_Timer.After(1.3, ns.GameTalentGlow) end)
ns:On("TRAIT_NODE_CHANGED", GlowSoon)
