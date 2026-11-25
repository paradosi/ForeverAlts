---- Tooltip — who has this item, and which alts can make it

local _, ns = ...

-- Every place one character holds an item: bags, bank, worn, mail
function ns.Holdings(c, itemID)
    local bags = c.bags and c.bags[itemID] or 0
    local bank = c.bank and c.bank[itemID] or 0
    local worn = c.equipped and c.equipped[itemID] or 0
    local mail = c.mail and c.mail.items and c.mail.items[itemID] or 0
    return bags + bank + worn + mail, bags, bank, worn, mail
end

function ns.WarbandCount(itemID)
    local items = ns.db.warband.items
    return items and items[itemID] or 0
end

-- itemID -> { { char, profession }, … }, rebuilt after any recipe scan or forget
function ns.CraftIndex()
    if ns.craftIndex then return ns.craftIndex end
    local index = {}
    for key, c in pairs(ns.db.chars) do
        for prof, known in pairs(c.recipes or {}) do
            for _, item in pairs(known) do
                if item ~= 0 then
                    index[item] = index[item] or {}
                    table.insert(index[item], { key = key, char = c, prof = prof })
                end
            end
        end
    end
    ns.craftIndex = index
    return index
end

local GREY, GOLD = { 0.588, 0.616, 0.702 }, { 0.890, 0.714, 0.392 }

-- "bags" when it's all in one place; "bags 10, bank 2" when it's split
local function Where(bags, bank, worn, mail)
    local parts = {}
    if bags > 0 then table.insert(parts, { "bags", bags }) end
    if bank > 0 then table.insert(parts, { "bank", bank }) end
    if worn > 0 then table.insert(parts, { "worn", worn }) end
    if mail > 0 then table.insert(parts, { "mail", mail }) end
    if #parts == 1 then return parts[1][1] end
    for i, p in ipairs(parts) do parts[i] = p[1] .. " " .. p[2] end
    return table.concat(parts, ", ")
end

local function AddCounts(tooltip, itemID)
    local s = ns.settings
    local realm = GetRealmName()
    local rows, total = {}, 0
    for key, c in pairs(ns.db.chars) do
        if (s.allRealms or c.realm == realm) and (s.tooltipSelf or key ~= ns.meKey) then
            local n, bags, bank, worn, mail = ns.Holdings(c, itemID)
            if n > 0 then
                table.insert(rows, { c = c, n = n, where = Where(bags, bank, worn, mail) })
                total = total + n
            end
        end
    end
    local warband = ns.WarbandCount(itemID)
    if #rows == 0 and warband == 0 then return end

    table.sort(rows, function(a, b) return a.n > b.n end)
    tooltip:AddLine(" ")
    for _, r in ipairs(rows) do
        local name = ns.ColorName(r.c)
        if s.allRealms and r.c.realm ~= realm then name = name .. " |cff969db3(" .. r.c.realm .. ")|r" end
        tooltip:AddDoubleLine(name, r.n .. "  |cff969db3" .. r.where .. "|r", 1, 1, 1, 1, 1, 1)
    end
    if warband > 0 then
        tooltip:AddDoubleLine("Account bank", tostring(warband), GOLD[1], GOLD[2], GOLD[3], 1, 1, 1)
        total = total + warband
    end
    if #rows + (warband > 0 and 1 or 0) > 1 then
        tooltip:AddDoubleLine("Total", tostring(total), GREY[1], GREY[2], GREY[3], GOLD[1], GOLD[2], GOLD[3])
    end
end

local function AddCrafters(tooltip, itemID)
    local crafters = ns.CraftIndex()[itemID]
    if not crafters then return end
    local names = {}
    for _, e in ipairs(crafters) do table.insert(names, ns.ColorName(e.char)) end
    tooltip:AddLine("Made by " .. table.concat(names, ", ") .. " |cff969db3(" .. crafters[1].prof .. ")|r",
        GOLD[1], GOLD[2], GOLD[3], true)
end

local function OnItemTooltip(tooltip, data)
    if not ns.db or not data or not data.id then return end
    if canaccessvalue and not canaccessvalue(data.id) then return end
    if ns.settings.tooltip then AddCounts(tooltip, data.id) end
    if ns.settings.tooltipCraft then AddCrafters(tooltip, data.id) end
end

ns:On("PLAYER_LOGIN", function()
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
end)
