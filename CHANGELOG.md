# Changelog

## v0.1.0

- First version, for WoW Forever.
- **Characters**: every character you log in on, with level and XP, location, gold, played time,
  rested XP (it keeps growing while they're logged out), item level, free bag slots and when you last
  played them. Click a column to sort. Totals for gold and played time along the bottom.
- **Items**: search every character's bags, bank and gear at once. Click a character to browse what they carry.
- **Professions**: each character's skill levels, and a search for who knows a recipe.
- **Tooltips**: how many of an item each character has (bags, bank, worn), the account bank, a total,
  and which of your characters can make it.
- **Mail**: items and gold in each character's mailbox count in tooltips, search and a new MAIL column,
  which turns orange when a letter has less than a week left. Mail you send to your own characters
  counts straight away. At login, a chat line warns about mail that runs out within 3 days.
- **Reputation**: a new tab listing every faction your characters have met, grouped as in the game's
  reputation panel, with each character's standing and the best one's progress bar. Search by faction name;
  hover for exact numbers. Recorded at login and whenever reputation changes.
- **Lockouts**: a new tab with every raid your characters are saved to: bosses down, when each raid resets,
  and the bosses still up when you hover a character. Lockouts end on their own at the reset. Recorded at
  login and after each boss kill. The Characters tooltip lists what a character is saved to.
- **Talents**: a new tab drawing each character's three talent trees, with ranks, prerequisite arrows and
  spell tooltips, both specs with dual spec, and *Copy loadout code* for the game's Import. A TALENTS column on
  the Characters tab shows points per tree and any unspent. Right-click a character for *Show talents*.
- The window is a little wider to fit the new column.
- Clicking a character filters both Items and Reputation to them, until you clear the *ONLY …* chip.
  Right-click a character for *Show reputation*.
- Click a profession on the Professions tab to list that character's recipes, with who else knows each one.
  Hover a recipe for what it makes (or the enchant it casts).
- Herbalism, Skinning and Fishing say *gathering* on the Professions tab instead of asking you to record recipes they don't have.
- Fixed: an "item 0" showed up in Items (an empty gear slot); it's removed from saved data too.
- Fixed: the Items search box's placeholder ran out of the box.
- Tooltips say just "bags" when everything is in one place, and split it out ("bags 10, bank 2") only when it isn't.
- Fixed: gold, XP and rested were saved as 0 when you logged out.
- Fixed: played time is now asked for on a character's first login (it errored).
- The window is resizable: drag the bottom-right corner. Wider windows give the Location column more room.
- `/alts`, the addon compartment button, and options under Esc → Options → AddOns.
