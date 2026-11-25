---- Mail — what waits in each character's mailbox, and when it expires
--
-- The inbox is readable only while a mailbox is open, like the bank. Mail you send
-- to one of your own characters is counted at once, so the alt's tooltip line and
-- search results include it before they ever visit a mailbox.
--
-- Stored per character as c.mail = { items = { itemID -> count }, money, letters,
-- expires, hidden, seen }. letters counts only mail holding items or gold;
-- expires is the soonest of those to run out (a time() value).

local _, ns = ...

local DAY = 86400
local WARN_DAYS = 3        -- the login warning names mail this close to expiring
local SEND_DAYS = 30       -- how long newly sent mail lasts
local mailOpen, inboxRead = false, false

---- Reading the inbox

local function ScanInbox()
    local me = ns.me
    if not me or not mailOpen or not inboxRead then return end
    local shown, total = GetInboxNumItems()
    local items, money, letters, expires = {}, 0, 0, nil
    local maxAttach = ATTACHMENTS_MAX_RECEIVE or 16
    for i = 1, shown or 0 do
        local _, _, _, _, gold, _, daysLeft, hasItem = GetInboxHeaderInfo(i)
        local holds = false
        if gold and gold > 0 then money = money + gold; holds = true end
        if hasItem then
            for a = 1, maxAttach do
                local _, itemID, icon, count, quality = GetInboxItem(i, a)
                if itemID and itemID > 0 then
                    items[itemID] = (items[itemID] or 0) + (count or 1)
                    ns.Remember(itemID, GetInboxItemLink(i, a), quality, icon)
                    holds = true
                end
            end
        end
        if holds then
            letters = letters + 1
            local at = time() + math.floor((daysLeft or 0) * DAY)
            if not expires or at < expires then expires = at end
        end
    end
    me.mail = {
        items = items, money = money, letters = letters, expires = expires,
        -- The server hands over at most 50 letters at a time; the rest wait unseen
        hidden = math.max(0, (total or 0) - (shown or 0)),
        seen = time(),
    }
    if ns.RefreshUI then ns.RefreshUI() end
end

local function Opened()
    mailOpen, inboxRead = true, false
end
local function Closed()
    if not mailOpen then return end
    ScanInbox()
    mailOpen, inboxRead = false, false
end

-- The inbox is empty until the server's MAIL_INBOX_UPDATE; read only after one,
-- or an opened mailbox would record "no mail" for a moment
ns:On("MAIL_INBOX_UPDATE", function()
    if not mailOpen then return end
    inboxRead = true
    ns:Debounce("mail", 0.3, ScanInbox)
end)
ns:On("MAIL_SHOW", Opened)
ns:On("MAIL_CLOSED", Closed)
ns:On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(kind)
    if Enum.PlayerInteractionType.MailInfo and kind == Enum.PlayerInteractionType.MailInfo then Opened() end
end)
ns:On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(kind)
    if Enum.PlayerInteractionType.MailInfo and kind == Enum.PlayerInteractionType.MailInfo then Closed() end
end)

---- Mail sent to your own characters

-- "Para Dosi", "para dosi", "Para-Dosi" all name the same character
local function Normal(name)
    return (name or ""):lower():gsub("%-", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
end

-- The stored character a recipient names: full name, or a first name only one alt has
function ns.FindCharacter(recipient)
    local want = Normal(recipient)
    if want == "" then return nil end
    local byFirst, firstCount
    for key, c in pairs(ns.db.chars) do
        local name = Normal(c.name)
        if name == want then return key, c end
        if name:match("^(%S+)") == want then byFirst, firstCount = key, (firstCount or 0) + 1 end
    end
    if firstCount == 1 then return byFirst, ns.db.chars[byFirst] end
end

local pending  -- what the last SendMail carried, until the server says it went

hooksecurefunc("SendMail", function(recipient)
    local key = ns.FindCharacter(recipient)
    if not key or key == ns.meKey then pending = nil; return end
    local items = {}
    for a = 1, ATTACHMENTS_MAX_SEND or 12 do
        local _, itemID, _, count = GetSendMailItem(a)
        if itemID and itemID > 0 then items[itemID] = (items[itemID] or 0) + (count or 1) end
    end
    pending = { key = key, items = items, money = GetSendMailMoney() or 0 }
end)

ns:On("MAIL_SEND_SUCCESS", function()
    local p = pending
    pending = nil
    local c = p and ns.db.chars[p.key]
    if not c then return end
    local holds = p.money > 0 or next(p.items) ~= nil
    if not holds then return end
    local m = c.mail or { items = {}, money = 0, letters = 0, hidden = 0 }
    for id, n in pairs(p.items) do m.items[id] = (m.items[id] or 0) + n end
    m.money = (m.money or 0) + p.money
    m.letters = (m.letters or 0) + 1
    local at = time() + SEND_DAYS * DAY
    if not m.expires or at < m.expires then m.expires = at end
    c.mail = m
    if ns.RefreshUI then ns.RefreshUI() end
end)
ns:On("MAIL_FAILED", function() pending = nil end)

---- Expiry

-- Seconds until a character's first letter with items or gold runs out (negative once it has)
function ns.MailLeft(c)
    local m = c.mail
    if not m or not m.expires or (m.letters or 0) == 0 then return nil end
    return m.expires - time()
end

-- At login, name every character whose mail is about to run out
ns:On("PLAYER_LOGIN", function()
    C_Timer.After(6, function()
        if not ns.settings.mailWarn then return end
        for _, c in ipairs(ns:Characters()) do
            local left = ns.MailLeft(c)
            if left and left < WARN_DAYS * DAY then
                local n = c.mail.letters
                local what = n .. " letter" .. (n == 1 and "" or "s") .. " with items or gold"
                if left <= 0 then
                    ns.Say(ns.ColorName(c) .. "'s mail may have expired (" .. what .. "). Open a mailbox on them to check.")
                else
                    ns.Say(ns.ColorName(c) .. " has mail expiring in " .. ns.Duration(left) .. " (" .. what .. ").")
                end
            end
        end
    end)
end)
