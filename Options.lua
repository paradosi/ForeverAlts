---- Options — the Settings panel (Esc > Options > AddOns > Forever Alts)
--
-- Proxy settings read and write ForeverAltsDB.settings directly and take effect
-- at once. Setting names are prefixed FALTS_ because the registry is shared.

local _, ns = ...

local category

function ns.OpenOptions()
    if category then Settings.OpenToCategory(category:GetID()) end
end

local function Create()
    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory("Forever Alts")
    local s = ns.settings

    local function Checkbox(key, label, tooltip)
        local setting = Settings.RegisterProxySetting(category, "FALTS_" .. key, "boolean", label, ns.defaults[key],
            function() return s[key] end,
            function(value) s[key] = value; ns.RefreshUI() end)
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Item tooltips"))
    Checkbox("tooltip", "Show counts on item tooltips",
        "Every character holding the item, with how many are in their bags, bank and gear, plus the account bank.")
    Checkbox("tooltipSelf", "Include the character you're playing",
        "Off: the tooltip lists only your other characters.")
    -- Forever has no realms (GetRealmName() is ""; names are unique across the region),
    -- so the option only appears where there is a realm to choose
    if GetRealmName() ~= "" then
        Checkbox("allRealms", "Include characters on other realms",
            "Off: only characters on the realm you're playing on are counted.")
    end
    Checkbox("tooltipCraft", "Show who can make the item",
        "A \"Made by\" line naming the characters who know the recipe. Recipes are recorded when you open a profession window.")

    Settings.RegisterAddOnCategory(category)
end

ns:On("PLAYER_LOGIN", Create)
