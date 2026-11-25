---- Lockouts — which raids each character is saved to, how far in, and until when
--
-- Stored per character as c.lockouts = { instance name -> { id, reset, done, total,
-- raid, bosses = { { name, killed } } } }, where reset is a time() value: a lockout
-- whose reset has passed is simply over, so the views skip it without a login.
-- Every instance ever seen is remembered account-wide in db.instances (name ->
-- { total, raid, players }) so its column stays after the weekly reset.

local _, ns = ...

local function Plain(v)
    if v ~= nil and (not canaccessvalue or canaccessvalue(v)) then return v end
end

local function ReadLockouts()
    local me = ns.me
    if not me then return end
    local list = {}
    for i = 1, GetNumSavedInstances() or 0 do
        local name, lockoutID, reset, _, locked, extended, _, isRaid, maxPlayers, _, numEncounters, progress =
            GetSavedInstanceInfo(i)
        name = Plain(name)
        if name and (locked or extended) and reset and reset > 0 then
            local bosses = {}
            for e = 1, numEncounters or 0 do
                local boss, _, killed = GetSavedInstanceEncounterInfo(i, e)
                boss = Plain(boss)
                if boss then bosses[#bosses + 1] = { name = boss, killed = killed and true or false } end
            end
            list[name] = {
                id = Plain(lockoutID), reset = time() + reset,
                done = progress or 0, total = numEncounters or 0,
                raid = isRaid and true or false, bosses = bosses,
            }
            local known = ns.db.instances[name] or {}
            known.total = numEncounters or known.total
            known.raid = isRaid and true or false
            known.players = maxPlayers or known.players
            ns.db.instances[name] = known
        end
    end
    me.lockouts, me.lockoutsSeen = list, time()
    if ns.RefreshUI then ns.RefreshUI() end
end

-- The saved-instance list arrives from the server after RequestRaidInfo; read it
-- only on UPDATE_INSTANCE_INFO, never straight after asking
ns:On("UPDATE_INSTANCE_INFO", function() ns:Debounce("locks", 0.5, ReadLockouts) end)

local function Ask() RequestRaidInfo() end
ns:On("PLAYER_LOGIN", function() C_Timer.After(3, Ask) end)
-- A boss kill saves you (or moves your progress): ask again once the server has it
ns:On("BOSS_KILL", function() C_Timer.After(2, Ask) end)
ns:On("ENCOUNTER_END", function(_, _, _, _, success)
    if success == 1 or success == true then C_Timer.After(2, Ask) end
end)

-- A character's lockouts still running, as a list sorted by name
function ns.Lockouts(c)
    local list, now = {}, time()
    for name, l in pairs(c.lockouts or {}) do
        if l.reset and l.reset > now then
            l.name = name
            list[#list + 1] = l
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- The lockout c holds for an instance, if it's still running
function ns.Lockout(c, name)
    local l = c.lockouts and c.lockouts[name]
    if l and l.reset and l.reset > time() then return l end
end
