---- Reputation — every character's standing with every faction they've met
--
-- Stored per character as c.reps = { factionID -> { r = reaction 1-8, cur, max } },
-- where cur and max are progress through the current standing (max is 0 at the cap).
-- Faction names and their place in the reputation list are account-wide, in
-- db.factions (factionID -> { name, group, order }) and db.groups (header -> order).

local _, ns = ...

-- Reaction 1-8: the standing names, and colours in the wowdb palette
ns.STANDINGS = {
    { "Hated",      { 0.886, 0.369, 0.369 } },
    { "Hostile",    { 0.886, 0.369, 0.369 } },
    { "Unfriendly", { 0.953, 0.663, 0.510 } },
    { "Neutral",    { 0.890, 0.808, 0.420 } },
    { "Friendly",   { 0.533, 0.812, 0.490 } },
    { "Honored",    { 0.412, 0.788, 0.718 } },
    { "Revered",    { 0.471, 0.663, 0.937 } },
    { "Exalted",    { 0.890, 0.714, 0.392 } },
}

function ns.StandingName(r)
    return _G["FACTION_STANDING_LABEL" .. (r or 4)] or (ns.STANDINGS[r or 4] or ns.STANDINGS[4])[1]
end

function ns.StandingColor(r)
    return (ns.STANDINGS[r or 4] or ns.STANDINGS[4])[2]
end

-- One number that orders standings: reaction first, then progress through it
function ns.RepScore(rep)
    return (rep.r or 0) * 100000 + (rep.cur or 0)
end

local scanning, quietUntil = false, 0
local INACTIVE = _G.FACTION_INACTIVE or "Inactive"

local function Plain(v)
    if v ~= nil and (not canaccessvalue or canaccessvalue(v)) then return v end
end

-- Read every faction row. The list hides the factions under a collapsed header, so a
-- full read opens each collapsed header first and closes them again afterwards,
-- leaving the reputation panel as the player left it. While that panel is on screen
-- the headers are left alone and only the rows in view are read and merged in.
local function Read(reps, full)
    local db = ns.db
    local group
    for i = 1, C_Reputation.GetNumFactions() do
        local f = C_Reputation.GetFactionDataByIndex(i)
        local name = f and Plain(f.name)
        if name then
            if f.isHeader and not f.isChild then
                group = name
                if full then db.groups[name] = db.groups[name] or i end
            end
            local id = Plain(f.factionID)
            if id and id > 0 and (not f.isHeader or f.isHeaderWithRep) then
                local lo, hi = f.currentReactionThreshold or 0, f.nextReactionThreshold or 0
                reps[id] = { r = f.reaction, cur = (f.currentStanding or 0) - lo, max = math.max(0, hi - lo) }
                local known = db.factions[id]
                if not known then known = {}; db.factions[id] = known end
                known.name = name
                -- A faction the player moved to Inactive keeps the group it really belongs to
                if not known.group or (group and group ~= INACTIVE) then
                    known.group, known.order = group, i
                end
            end
        end
    end
end

local function ScanReps()
    local me = ns.me
    if not me or scanning then return end
    scanning = true
    local panel = _G.ReputationFrame
    local full = not (panel and panel:IsShown())

    local opened = {}
    if full then
        local i = 1
        while i <= C_Reputation.GetNumFactions() do
            local f = C_Reputation.GetFactionDataByIndex(i)
            if f and f.isHeader and f.isCollapsed then
                opened[f.name] = true
                C_Reputation.ExpandFactionHeader(i)
            end
            i = i + 1
        end
    end

    local reps = full and {} or (me.reps or {})
    local ok, err = pcall(Read, reps, full)

    if full then
        -- From the bottom up, so closing one header doesn't move the ones above it
        for i = C_Reputation.GetNumFactions(), 1, -1 do
            local f = C_Reputation.GetFactionDataByIndex(i)
            if f and f.isHeader and opened[f.name] and not f.isCollapsed then
                C_Reputation.CollapseFactionHeader(i)
            end
        end
    end
    scanning = false
    -- Opening and closing headers fires UPDATE_FACTION; don't answer our own echo
    quietUntil = GetTime() + 1
    if not ok then error(err, 0) end

    -- An empty read is a list not loaded yet, never "lost every faction"
    if next(reps) == nil then return end
    me.reps, me.repsSeen = reps, time()
    if ns.RefreshUI then ns.RefreshUI() end
end

ns:On("PLAYER_LOGIN", function() C_Timer.After(2, ScanReps) end)

ns:On("UPDATE_FACTION", function()
    if not ns.me or scanning or GetTime() < quietUntil then return end
    ns:Debounce("reps", 2, ScanReps)
end)
