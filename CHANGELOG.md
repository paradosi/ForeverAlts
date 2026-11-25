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
- Tooltips say just "bags" when everything is in one place, and split it out ("bags 10, bank 2") only when it isn't.
- Fixed: gold, XP and rested were saved as 0 when you logged out.
- Fixed: played time is now asked for on a character's first login (it errored).
- The window is resizable: drag the bottom-right corner. Wider windows give the Location column more room.
- `/alts`, the addon compartment button, and options under Esc → Options → AddOns.
