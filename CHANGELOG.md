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
- **Legacy trees**: the Talents tab's LEGACY button shows each character's Legacy System trees (Professions,
  Adventure, Progression), with Legacy points to spend and Legacy renown. `/alts legacy` opens it.
- Fixed: talent trees were drawn tiny and squashed, with a stray talent beside or below a tree (Forever's talent
  positions have small slips in them, and a few hidden talents sit far off the tree; the grid now snaps to the
  slips and leaves the hidden ones out).
- **Talent planner**: PLAN on the Talents tab. Click talents to plan a build with the game's rules (51 points,
  5 per tier, prerequisites), from the character's current talents or from scratch. Planned points are blue,
  talents you can take next are outlined, and the tooltip says why one is closed. `/alts plan`.
  Keep several named plans per class, and copy a plan as text to share it or paste one in.
  A plan is also a level order: hover LEVEL ORDER for it, the next talent is outlined, and when you have
  points to spend a chat line names the next one (can be turned off in Options).
- The Talents tab picks its character from a dropdown in the window's own style (name, level and class) instead of a row of names.
- **Armory** tab: a character's gear on a paperdoll (slots, item names and levels, weapons), their stats, and the
  live model for the character you're on (alts show their race and class crest). `/alts armory`.
- Items tab: a character dropdown. Pick someone to see their bags, bank, mail and gear as icon grids (quality borders,
  stack counts, item tooltips, Shift-click to link), each section saying when it was recorded or what to open to record
  it. *ALL CHARACTERS* is the search across everyone, as before.
- wowdb.dev's running glow: a line of gold light runs around a box's border on hover, on every button, tab,
  search box and talent. The open tab keeps glowing. The next talent in a plan glows all the time, brighter and
  thicker, **in the game's own talent window too** (Options → Talents → Show the plan in the talent window).
- The window is a little wider to fit the new column.
- Fixed: in a narrow window the footer ran into the version number. It now ends with "…"; hover it for the whole line.
- New options: item tooltips can count only characters of your faction, or only those on your ruleset.
  The *Made by* line follows them too.
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
