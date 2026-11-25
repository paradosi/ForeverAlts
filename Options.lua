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

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Window"))
    do
        local setting = Settings.RegisterProxySetting(category, "FALTS_scale", Settings.VarType.Number, "Window scale",
            ns.defaults.scale,
            function() return s.scale end,
            function(value) s.scale = value; ns.ApplyScale() end)
        local options = Settings.CreateSliderOptions(ns.SCALE_MIN, ns.SCALE_MAX, 5)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value) return value .. "%" end)
        Settings.CreateSlider(category, setting, options,
            "Makes the whole Forever Alts window larger or smaller: text, icons and spacing together, so nothing gets cut off. "
            .. "Also /alts scale 120. /alts reset goes back to 100%.")
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
    Checkbox("sameFaction", "Only characters of your faction",
        "Counts and the Made by line list only characters of the faction you're playing (Horde or Alliance).")
    Checkbox("sameRuleset", "Only characters on your ruleset",
        "Counts and the Made by line list only characters on the ruleset you're playing (Normal, PvP, Roleplay or Roleplay PvP). "
        .. "A character's ruleset is recorded the next time you log in on it; until then it is always counted.")
    Checkbox("tooltipCraft", "Show who can make the item",
        "A \"Made by\" line naming the characters who know the recipe. Recipes are recorded when you open a profession window.")

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Mail"))
    Checkbox("mailWarn", "Warn about mail about to expire",
        "At login, a chat line names any character with items or gold in the mail that runs out within 3 days.")

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Talents"))
    Checkbox("planRemind", "Remind me of my talent plan",
        "When you have talent points to spend, a chat line names the next talent in your class's chosen plan (/alts plan).")
    Checkbox("planGlow", "Show the plan in the talent window",
        "The next talent to learn in your class's chosen plan has a running gold border in the game's talent window.")

    Settings.RegisterAddOnCategory(category)
end

ns:On("PLAYER_LOGIN", Create)
