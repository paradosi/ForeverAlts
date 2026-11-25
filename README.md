<img src="https://raw.githubusercontent.com/paradosi/ForeverAlts/main/media/art/logo_400.png" alt="Forever Alts logo" width="128" align="right">

# Forever Alts

**Every character at a glance, for WoW Forever.** Forever Alts records each character you log in on: gold,
level, played time, rested XP, bags, bank, gear, mail, professions, reputations, raid lockouts and talents. It shows them all in one window and puts
item counts on every tooltip. It does the job of Altoholic, with a cleaner look and nothing to configure.

> [!NOTE]
> Forever Alts is written for **WoW Forever** (Interface 16001) only. It uses Forever's Retail-12 API
> (bank tabs, `C_TradeSkillUI`, tooltip data processors) and will not load on Classic Era, TBC Anniversary or Retail.

## Features

- **Characters**: one row per character showing level (with progress through it), location, gold, played time,
  rested XP, item level, free bag slots, letters in the mail and when you last played it. Click any column heading to sort.
  The footer totals your gold and played time across every character.
- **Items**: one search box covers every character's bags, bank, gear and mail, plus the account bank. Each result shows
  who has how many. Pick a character from the dropdown (or click them on the Characters tab) for a grid of what they hold,
  a section each for bags, bank, mail and gear, sorted by quality: each heading says how fresh it is, or what to open
  to record it. The search box filters the grid.
- **Armory**: one character's gear on a paperdoll like the Armory site: slots down both sides with each item's name
  and item level, weapons along the bottom, and the character sheet's stats (attributes, defense, offense,
  resistances) in a panel. The character you're on is shown as a live model you can turn by dragging; addons can't
  rebuild another character's looks, so an alt shows their race and class crest. Stats are recorded at login and
  whenever they change. `/alts armory`, or right-click a character → *Show gear (Armory)*.
  Alts can also show **Blizzard's Armory picture** of them, if something puts it on disk: an addon can't download.
  `tools/renders.py` does that for the author (Battle.net API → 512px TGA → a `ForeverAlts_Renders` data addon copied
  to the game PC). Without it, alts show their crest. New pictures need a game restart.
- **Professions**: every character's professions with skill bars and how many recipes they know. Click one to list
  that character's recipes (search narrows the list). Type in the search box to find which of your characters can make something.
- **Reputation**: every faction any of your characters has met, grouped like the game's reputation panel, with each
  character's standing (coloured Hated to Exalted, with progress) and a bar for the best of them. Hover a faction
  for exact numbers. Pick one character in the dropdown to see their reputations the way the game's window does: standing, a
  wide bar and the exact numbers.
- **Lockouts**: a grid of your characters against every raid any of them has been saved to. Each cell shows how
  many bosses are down (gold for a full clear) and clears itself when the lockout resets; each column says when that
  raid resets. Hover a character for the bosses still up.
- **Talents**: each character's three talent trees, redrawn in the window with every talent's rank and the
  arrows between them; hover a talent for its spell. Dual spec shows both specs. *Copy loadout code* gives the
  build's code for the game's own Import, to copy a build to another character. The Characters tab has a
  TALENTS column (`0/21/30`, with unspent points in orange). **LEGACY** switches the tab to the Legacy System's three
  trees (Professions, Adventure, Progression) with Legacy points to spend and Legacy renown.
- **Talent planner**: **PLAN** on the Talents tab. Click a talent to add a point, right-click to take one off,
  Shift for every rank. Vanilla's rules hold (51 points, 5 points per tier, arrows need their source at full rank),
  and the tooltip says why a talent is closed. Learned points stay gold, planned ones are blue, and talents that can
  take a point are outlined. *From current* builds on the character's talents; *from scratch* plans a respec.
  Named plans per class (*+ New*, *Rename*, *Delete*), kept between sessions with the order you added points.
  *Copy* gives a plan as one line of text (`FA1;PRIEST;…`) to share; *Paste* takes one in.
  The order you add points is the order to learn them: hover *Level order* for the list by level, the next
  talent is outlined in white, and with points to spend a chat line names the next talent (Options → Talents).
  The next talent also glows in the game's own talent window: an overlay of ours, Blizzard's buttons are only read.
- **Tooltips**: every item tooltip lists the characters holding it (and where: bags, bank, worn or mail), the
  account bank, and a total. If one of your characters knows the recipe, it adds a *Made by* line.
- **Mail**: items and gold waiting in each mailbox count everywhere items do. The MAIL column turns orange when a
  letter has less than a week left, and at login a chat line names any character whose mail runs out within 3 days.
  Mail you send to your own characters counts the moment it goes.
- **Rested XP keeps counting** while a character is logged out, at the game's own rate: faster in an inn or city.
- **No setup.** Log in on each character once, and visit a banker and a mailbox once. That's it.

## Requirements

- WoW Forever.
- No libraries. Fonts (Oswald, JetBrains Mono, both SIL OFL) ship inside the addon.

## Installation

From CurseForge or Wago once published. Until then, by hand:

1. Download the latest zip from [GitHub Releases](https://github.com/paradosi/ForeverAlts/releases).
2. Extract it into `World of Warcraft\_forever_\Interface\AddOns\`, so the folder is `AddOns\ForeverAlts\`.
3. **Restart the game.** WoW only picks up a newly installed addon on a full restart; `/reload` isn't enough.

## Usage

Open the window with **`/alts`** or the addon compartment button (the puzzle-piece menu on the minimap).
Escape closes it, and you can drag it by any empty spot. **Drag the gold grip in the bottom-right
corner to resize it**: taller shows more rows, wider gives the Location column more room. Size and position are remembered.

### Filling it in

Forever Alts can only see the character you're playing, so each character has to be visited once:

| What | Recorded when |
|---|---|
| Level, gold, location, XP, rested, gear, bags | On login, and whenever they change |
| Played time | First login (it asks the server once, so `/played` prints in chat that one time); after that it counts by itself |
| Character bank | **When you open the bank.** Visit a banker once on each character |
| Account bank | When any character opens the bank |
| Mail | **When you open a mailbox**, and at once when you send mail to one of your characters |
| Profession skill levels | On login |
| Known recipes | **When you open that profession's window** |
| Reputations | On login, and whenever reputation changes |
| Raid lockouts | On login, and after every boss kill |
| Talents | On login, and whenever you change talents or spec |

> [!TIP]
> After installing, log in on each alt, open the bank and a mailbox, and open each profession window once. From then on
> everything stays current as you play.

### Worked examples

**"Which alt has my Runecloth?"** Type `/alts items runecloth`, or open the Items tab and type `rune`. Each matching
item shows a per-character breakdown such as *Aelin 40 · Borin 7 · Account bank 20*, with the total on the right.
Hovering a row shows the item's tooltip; Shift-click links it in chat.

**"Who can make Bolt of Linen Cloth?"** Type `/alts profs bolt`. Each matching recipe lists the characters who know it.
The same answer shows up on the item's own tooltip as *Made by Aelin (Tailoring)*.

**"What enchants does my enchanter know?"** Click their Enchanting row on the Professions tab. Every recipe is
listed with the other characters who know it; hover one to see the enchant. Click the chip beside the search box to go back.

**"What's on my banker alt?"** Pick them from the dropdown on the Items tab, or click their row on the Characters tab:
their bags, bank, mail and gear show as icon grids. *ALL CHARACTERS* goes back to the search across everyone. The choice
stays on when you switch to the Reputation tab, which then shows only their standings; *All characters* in the dropdown goes back to everyone. Right-clicking a character also offers *Show reputation*.

**"Who's fully rested?"** Click the *RESTED* heading to sort. 150% (shown in gold) is the cap.

### Commands

| Command | Does |
|---|---|
| `/alts` | Open or close the window (also `/foreveralts`) |
| `/alts items <text>` | Open the Items tab searching for `<text>` |
| `/alts profs <text>` | Open the Professions tab searching recipes for `<text>` |
| `/alts reps <text>` | Open the Reputation tab searching factions for `<text>` |
| `/alts talents` | Open the Talents tab (also `/alts spec`) |
| `/alts plan` | Open the talent planner |
| `/alts armory` | Open the Armory tab: gear, model and stats |
| `/alts legacy` | Open the Talents tab on the Legacy trees |
| `/alts locks` | Open the Lockouts tab (also `/alts lockouts`, `/alts raids`) |
| `/alts options` | Open the options panel |
| `/alts scale <80-150>` | Make the whole window larger or smaller, in steps of 5%; with no number, says the current scale |
| `/alts reset` | Put the window back to its usual size and 100% scale, in the middle of the screen |
| `/alts help` | List the commands |

To forget a character (deleted, or transferred away), right-click their row and choose **Forget this character**.

## Configuration

Esc → Options → AddOns → **Forever Alts**, or `/alts options`. All settings are account-wide.

| Setting | Default | Effect |
|---|---|---|
| Window scale | 100% | The whole window larger or smaller (80–150%): text, icons and spacing together, so nothing gets cut off |
| Show counts on item tooltips | On | The per-character lines on item tooltips |
| Include the character you're playing | On | Off lists only your other characters |
| Only characters of your faction | Off | Counts and *Made by* list only Horde, or only Alliance, as you're playing |
| Only characters on your ruleset | Off | Counts and *Made by* list only characters on your ruleset (Normal, PvP, Roleplay, Roleplay PvP). A character's ruleset is recorded at its next login; until then it's counted |
| Include characters on other realms | On | Off counts only characters on the current realm |
| Show who can make the item | On | The *Made by* line |
| Warn about mail about to expire | On | A chat line at login for each character whose mail runs out within 3 days |

Everything is saved in `WTF\Account\<account>\SavedVariables\ForeverAlts.lua` (`ForeverAltsDB`).

## Development

```sh
cd ~/projects/wowaddons
./check ForeverAlts             # syntax, luacheck, TOC lint, Forever API scan
./check ForeverAlts --package   # + build the release zip and inspect it
cd ForeverAlts && lua5.1 tests/smoke.lua   # headless run against a stubbed WoW API
```

The smoke test loads every file in TOC order, logs a character in, opens the bank and a profession window,
checks the tooltip lines and the rested and played arithmetic, and renders all four views. It catches nil
calls and typos the static gate can't. It is not a substitute for the game.

Releasing follows the shared pipeline: `wowdev bump ForeverAlts X.Y.Z -w`, update `CHANGELOG.md`,
`./check ForeverAlts --package`, commit, tag `vX.Y.Z`, push the tag.

## Project structure

| File | Holds |
|---|---|
| `ForeverAlts.toc` | Interface 16001, load order, saved variable, compartment hook |
| `Core.lua` | Saved data and defaults, the character key, the event bus, formatting, played and rested arithmetic, `/alts` |
| `Scan.lua` | Records the current character: summary, bags, gear, bank tabs, professions, recipes, played time |
| `Mail.lua` | The inbox, mail sent to your own characters, expiry and the login warning |
| `Reputation.lua` | Standings with every faction, the standing names and colours |
| `Lockouts.lua` | Saved raid instances: progress, bosses and reset time |
| `Talents.lua` | Each spec's trees, talents, ranks, prerequisites and loadout code |
| `Tooltip.lua` | Item tooltip lines (counts and *Made by*), the crafter index |
| `Theme.lua` | wowdb.dev's colour tokens and fonts, and the small widgets built from them |
| `List.lua` | A virtual scrolling list: a fixed set of rows reused as you scroll |
| `UI.lua` | The window and its six views |
| `Options.lua` | The Settings panel |
| `tests/smoke.lua` | Headless smoke test (not shipped) |
| `media/fonts` | Oswald and JetBrains Mono, with their OFL licences (shipped) |
| `media/textures/logo_64.tga` | The addon list icon (shipped) |
| `media/art` | Logo source SVG and renders (README only) |

## How it works

**One record per character**, keyed `Realm|First Last`. On Forever `GetRealmName()` returns an empty
string (names are unique across the whole region), so the realm part is empty and the realm is never shown. Forever names have a surname, and `UnitName("player")`
returns the first name and surname as two separate values. Keying on the first name alone would merge two
alts who share one, so the key joins them.

**Counts are stored by item ID**: `bags`, `bank` and `equipped` are each an `itemID → count` table. Tooltips and
search add them up on demand. Item names, qualities and icons are cached account-wide (`ForeverAltsDB.items`), taken
from the item links seen while scanning. Search can then find items that the game's own item cache hasn't loaded this session.

**The bank** on Forever is Retail's tab bank. The character bank is bag IDs 6–14 and the account bank is 15–23,
listed by `C_Bank.FetchPurchasedBankTabData`. They're readable only while the bank is open, so they're scanned
on `BANKFRAME_OPENED`, on every bag change while it's open, and once more on close. The account bank is stored
once (`ForeverAltsDB.warband`), not per character, because every character shares it.

**Mail** is read when a mailbox opens, but only after the server's first `MAIL_INBOX_UPDATE`: before that the inbox
reads empty, and recording it then would wipe the character's mail. Each character keeps `mail = { items, money,
letters, expires, hidden, seen }`. `letters` counts only mail holding items or gold, and `expires` is when the first of
those runs out. The server hands over at most 50 letters at a time; `hidden` is how many more wait, and the row tooltip
says so. Sending is caught with `hooksecurefunc("SendMail")`, which reads the attachments and gold before they leave,
and is credited to the recipient on `MAIL_SEND_SUCCESS` (dropped on `MAIL_FAILED`). The recipient matches a stored
character by full name, ignoring case and `-`, or by first name when only one of your characters has it.

**Reputations** come from `C_Reputation.GetFactionDataByIndex`, which only lists factions under open headers. So a
scan opens every collapsed header, reads the whole list, then closes those headers again from the bottom up, so closing
one doesn't shift the ones above. The reputation panel ends up exactly as you left it. That toggling fires
`UPDATE_FACTION`, so events in the second after a scan are ignored, or every scan would trigger the next. While the
reputation panel is open, the headers aren't touched: only the visible rows are read and merged in. Each character keeps
`reps = { factionID -> { r, cur, max } }`, the standing (1 Hated to 8 Exalted) and progress through it. Faction names
and their group are kept once for the account. A faction you moved to *Inactive* keeps its real group.

**Lockouts** come from `GetSavedInstanceInfo` and `GetSavedInstanceEncounterInfo`. The list arrives from the server
after `RequestRaidInfo()`, so it is asked for at login and two seconds after each `BOSS_KILL` or successful
`ENCOUNTER_END`, and read only on `UPDATE_INSTANCE_INFO`. Each lockout's reset is stored as a clock time, not a
countdown, so an alt's lockout ends on schedule without logging in on them. Every instance ever seen is kept for the
account, so its column stays after the weekly reset.

**Talents.** Forever's talent window is Retail's trait system (`C_Traits`, `C_ClassTalents`) showing the three
Vanilla trees: one trait tree per class whose nodes are split into three groups. For each spec group
(`C_SpecializationInfo.GetCombatConfigIDForSpecGroup`), Forever Alts saves the groups' names, icons and points
spent (`GetGroupCurrencyInfo`), and every visible node's position, spell, rank and outgoing edges. The view turns the
game's positions into a grid and scales it to the window. Forever's talent data has slips in it (a few positions off
by 10), so the grid step is the most common gap between neighbouring
positions and every position snaps to the nearest step. A few nodes sit ten times further out (102800 among 10280s):
the game draws those off its canvas, out of sight, so they're left out here too.
`C_Traits.GenerateImportString` gives the loadout code.

**The planner** keeps named plans per class in `db.plans[class] = { active, list = { name -> { scratch, ranks =
{ spellID -> rank }, order } } }`. A shared plan is `FA1;CLASS;scratch;spellID=rank,…;spellID.spellID…`.
It draws on the active spec's saved trees, so a class can be planned once a character of it has been recorded. The rules
are checked from the drawn grid: a talent in row *n* (from 0) needs 5·*n* points in rows above it in its tree, an arrow's
talent needs its source at full rank, and taking a point off is refused if any other planned point would stop holding.

**Legacy trees.** Forever's Legacy System (`Blizzard_LegacySystem`) is three more trait trees, IDs 1187 Professions,
1188 Adventure and 1189 Progression (`Constants.LegacyConsts`), each with its own config
(`C_Traits.GetConfigIDByTreeID`), paid for with one Legacy point currency. It opens at Legacy renown 1
(`C_MajorFactions.GetCurrentRenownLevel(2802)`); before that nothing is recorded. They're saved as `c.legacy` in the
same shape as a spec, so the same drawing code shows them.

**Recipes** come from `C_TradeSkillUI` when your own profession window opens. Linked professions, guild lists
and NPC crafting orders are ignored. Each learned recipe's output item comes from `GetRecipeSchematic`, which
is what the *Made by* line looks up. An empty recipe list never overwrites a recorded one, because the list can
arrive in pieces.

**Played time.** `RequestTimePlayed()` always prints in chat, so Forever Alts asks only once per character.
After that it carries the total forward with the session clock and saves it at logout. When you type
`/played` yourself, it takes the server's figure.

**Rested XP** for logged-out characters is the saved value plus 5% of a level per 8 hours if they logged out
resting (inn or city), a quarter of that otherwise, capped at 150%.

**Rulesets.** Forever has no realm names (`GetRealmName()` is empty), but a character's GUID still carries its home
server (`Player-<server>-<id>`), and that is what the *same ruleset* setting compares. `GetRealmID()` is saved beside
it as a cross-check.

**Secret values.** On Forever, identity APIs (`UnitName`, `UnitClass`, `UnitRace`) are allowed to return
secrets. The player's own normally aren't, but each value is checked with `canaccessvalue` before it's saved.
A secret written to saved variables would break every later comparison.

## Design decisions

- **No libraries.** No Ace3, no LibDataBroker, no LibDBIcon. The addon compartment replaces a minimap button,
  and the Settings API replaces AceConfig. The addon stays small, and there's nothing vendored to keep in sync.
- **wowdb.dev's look rather than Blizzard frame templates.** It matches the rest of the Forever addons
  (NightclawEars) and the website. Blizzard's templates change between client builds, and flat textures don't.
- **A hand-written virtual list rather than `ScrollBox`.** ScrollBox would work, but its templates bring
  Blizzard's scrollbar art with them. A 100-line list with a gold thumb fits the look and is easy to test headless.
- **Asking for `/played` once, not every login.** Altoholic-style suppression of the chat line means unregistering
  events on Blizzard's chat frames. With Forever's secret-value and taint rules, that's a risk to chat itself,
  so the addon makes one visible request per character instead.
- **Counts by item ID, not by link.** Random-suffix gear ("of the Bear") shares one item ID, so the tooltip count
  covers every suffix together. That's what you usually want when asking "how many do I have".
- **Mail is per character, not per letter.** Storing the totals and the soonest expiry is all the tooltip, search and
  warning need. A per-letter list would let the addon show each letter, but it would go stale the moment mail is taken
  on another client or returned.
- **Reputation reads the list rather than asking for each faction by ID.** `GetFactionDataByID` would avoid opening
  headers, but it needs a list of IDs to ask about, and the list is what says which factions a character has met.
- **Not in v0.1**: auctions, quests, currencies, lockouts, guild bank. Each is a self-contained
  scan plus a view, and can be added without changing the data already saved.

## Troubleshooting

**A character's bank shows nothing.** Banks can only be read while open. Visit a banker on that character once.
Hovering their row on the Characters tab shows when the bank was last recorded.

**Professions say "open the profession window to record recipes".** Open each profession's window once on that
character. Herbalism, Skinning and Fishing have no recipes, so they say *gathering* instead. Mining's window holds the
Smelting recipes, so open it too. Skill levels are recorded at login, but recipes aren't.

**`/played` printed in chat when I logged in.** That happens once per character, the first time Forever Alts sees
it, to learn the total.

**Items an alt took out of the mail still show as mail.** The mailbox is recorded when it's open. Open a mailbox on
that character again and it catches up.

**A character I deleted is still listed.** Right-click it → *Forget this character*.

**The window is off-screen, or sized oddly.** `/alts reset`.

## License

MIT, see [LICENSE](LICENSE). The bundled fonts are under the SIL Open Font License; see `media/fonts/OFL-*.txt`.
