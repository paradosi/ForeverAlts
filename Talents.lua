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
