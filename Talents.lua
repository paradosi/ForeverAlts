---- Talents — each character's talent build, enough to redraw its trees
--
-- Forever's talent window is Retail's trait system wearing the three Vanilla trees:
-- one trait tree per class, its nodes split into three groups (the trees), with dual
-- spec as two configs. Stored per character as
--   c.talents = { active = spec group, seen, specs = { [group] = {
--       trees = { { name, icon, spent } },  -- in the game's order
--       nodes = { { x, y, t = tree, s = spellID, i = icon, r = rank, m = max, e = { node index } } },
--       unspent, code } } }
-- x and y are the game's own layout positions; the view turns them into a grid.

local _, ns = ...

local function Plain(v)
    if v ~= nil and (not canaccessvalue or canaccessvalue(v)) then return v end
end

-- The trees of one config, or nil when it can't be read (a low-level character has none)
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

    local nodes, index = {}, {}
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
        local n = C_Traits.GetNodeInfo(configID, nodeID)
        if n and n.isVisible and n.ID and n.ID > 0 then
            local tree
            for _, g in ipairs(n.groupIDs or {}) do tree = tree or treeOf[g] end
            local entryID = (n.activeEntry and n.activeEntry.entryID) or (n.entryIDs and n.entryIDs[1])
            local entry = entryID and C_Traits.GetEntryInfo(configID, entryID)
            local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
            local spell = def and (def.spellID or def.overriddenSpellID)
            if tree and spell then
                local node = {
                    x = n.posX, y = n.posY, t = tree, s = spell,
                    i = (def.overrideIcon and def.overrideIcon > 0 and def.overrideIcon) or C_Spell.GetSpellTexture(spell),
                    r = n.currentRank or n.ranksPurchased or 0, m = n.maxRanks or 1,
                    out = n.visibleEdges,
                }
                nodes[#nodes + 1] = node
                index[nodeID] = #nodes
            end
        end
    end
    if #nodes == 0 then return nil end
    -- Prerequisite arrows, as indexes into the saved node list
    for _, node in ipairs(nodes) do
        local e = {}
        for _, edge in ipairs(node.out or {}) do
            if index[edge.targetNode] then e[#e + 1] = index[edge.targetNode] end
        end
        node.out = nil
        if #e > 0 then node.e = e end
    end

    local unspent = 0
    for _, cur in ipairs(C_Traits.GetTreeCurrencyInfo(configID, treeID, false) or {}) do
        unspent = unspent + (cur.quantity or 0)
    end
    local ok, code = pcall(C_Traits.GenerateImportString, configID)
    return { trees = trees, nodes = nodes, unspent = unspent, code = ok and Plain(code) or nil }
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
    -- Nothing readable (talents not loaded yet): keep what was recorded
    if not next(specs) then return end
    me.talents = { active = active, specs = specs, seen = time() }
    if ns.RefreshUI then ns.RefreshUI() end
end

local function Soon() ns:Debounce("talents", 1, ScanTalents) end
ns:On("PLAYER_LOGIN", function() C_Timer.After(3, ScanTalents) end)
ns:On("TRAIT_CONFIG_UPDATED", Soon)
ns:On("PLAYER_TALENT_UPDATE", Soon)
ns:On("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", Soon)
ns:On("CHARACTER_POINTS_CHANGED", Soon)
ns:On("PLAYER_LEVEL_UP", Soon)

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
