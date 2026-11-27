---- Minimap — Forever Alts' button on the minimap's edge (MinimapButton.lua)
--
-- Left-click toggles the window, right-click opens the settings, drag moves it.
-- settings.minimap shows or hides it (the Settings tick, /alts minimap);
-- settings.minimapAngle is where it sits.

local _, ns = ...

local button

function ns.UpdateMinimapButton()
    if button then button:Update() end
end

ns:On("PLAYER_LOGIN", function()
    button = ns.MinimapButton({
        name = "ForeverAltsMinimapButton",
        icon = "Interface\\AddOns\\ForeverAlts\\media\\textures\\logo_64",
        title = "Forever Alts",
        lines = { "Left-click: open or close the window", "Right-click: settings" },
        db = ns.settings,
        onClick = function(mouseButton)
            if mouseButton == "RightButton" then ns.OpenOptions() else ns.ToggleUI() end
        end,
    })
end)
