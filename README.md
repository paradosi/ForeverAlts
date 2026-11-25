<img src="https://raw.githubusercontent.com/paradosi/ForeverAlts/main/media/art/logo_400.png" alt="Forever Alts logo" width="128" align="right">

# Forever Alts

**Every character at a glance, for WoW Forever.** Forever Alts records each character you log in on: gold,
level, played time, rested XP, bags, bank, gear and professions. It shows them all in one window and puts
item counts on every tooltip. It does the job of Altoholic, with a cleaner look and nothing to configure.

> [!NOTE]
> Forever Alts is written for **WoW Forever** (Interface 16001) only. It uses Forever's Retail-12 API
> (bank tabs, `C_TradeSkillUI`, tooltip data processors) and will not load on Classic Era, TBC Anniversary or Retail.

## Features

- **Characters**: one row per character showing level (with progress through it), location, gold, played time,
  rested XP, item level, free bag slots and when you last played it. Click any column heading to sort.
  The footer totals your gold and played time across every character.
- **Items**: one search box covers every character's bags, bank and gear, plus the account bank. Each result shows
  who has how many. Click a character on the Characters tab to browse everything they carry.
- **Professions**: every character's professions with skill bars and how many recipes they know. Type in the search
  box to find which of your characters can make something.
- **Tooltips**: every item tooltip lists the characters holding it (split into bags, bank and worn), the account bank,
  and a total. If one of your characters knows the recipe, it adds a *Made by* line.
- **Rested XP keeps counting** while a character is logged out, at the game's own rate: faster in an inn or city.
- **No setup.** Log in on each character once and visit a banker once. That's it.

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
| Profession skill levels | On login |
| Known recipes | **When you open that profession's window** |

> [!TIP]
> After installing, log in on each alt, open the bank, and open each profession window once. From then on
> everything stays current as you play.

### Worked examples

**"Which alt has my Runecloth?"** Type `/alts items runecloth`, or open the Items tab and type `rune`. Each matching
item shows a per-character breakdown such as *Aelin 40 · Borin 7 · Account bank 20*, with the total on the right.
Hovering a row shows the item's tooltip; Shift-click links it in chat.

**"Who can make Bolt of Linen Cloth?"** Type `/alts profs bolt`. Each matching recipe lists the characters who know it.
The same answer shows up on the item's own tooltip as *Made by Aelin (Tailoring)*.

**"What's on my banker alt?"** Click their row on the Characters tab. The Items tab opens filtered to that character
and lists everything they hold. Click the *ONLY …* chip to clear the filter.

**"Who's fully rested?"** Click the *RESTED* heading to sort. 150% (shown in gold) is the cap.

### Commands

| Command | Does |
|---|---|
| `/alts` | Open or close the window (also `/foreveralts`) |
| `/alts items <text>` | Open the Items tab searching for `<text>` |
| `/alts profs <text>` | Open the Professions tab searching recipes for `<text>` |
| `/alts options` | Open the options panel |
| `/alts reset` | Put the window back to its usual size, in the middle of the screen |
| `/alts help` | List the commands |

To forget a character (deleted, or transferred away), right-click their row and choose **Forget this character**.

## Configuration

Esc → Options → AddOns → **Forever Alts**, or `/alts options`. All settings are account-wide.

| Setting | Default | Effect |
|---|---|---|
| Show counts on item tooltips | On | The per-character lines on item tooltips |
| Include the character you're playing | On | Off lists only your other characters |
| Include characters on other realms | On | Off counts only characters on the current realm |
| Show who can make the item | On | The *Made by* line |

Everything is saved in `WTF\Account\<account>\SavedVariables\ForeverAlts.lua` (`ForeverAltsDB`).

## Development

```sh
cd ~/projects/wowaddons
./check ForeverAlts             # syntax, luacheck, TOC lint, Forever API scan
./check ForeverAlts --package   # + build the release zip and inspect it
cd ForeverAlts && lua5.1 tests/smoke.lua   # headless run against a stubbed WoW API
```

The smoke test loads every file in TOC order, logs a character in, opens the bank and a profession window,
checks the tooltip lines and the rested and played arithmetic, and renders all three views. It catches nil
calls and typos the static gate can't. It is not a substitute for the game.

Releasing follows the shared pipeline: `wowdev bump ForeverAlts X.Y.Z -w`, update `CHANGELOG.md`,
`./check ForeverAlts --package`, commit, tag `vX.Y.Z`, push the tag.

## Project structure

| File | Holds |
|---|---|
| `ForeverAlts.toc` | Interface 16001, load order, saved variable, compartment hook |
| `Core.lua` | Saved data and defaults, the character key, the event bus, formatting, played and rested arithmetic, `/alts` |
| `Scan.lua` | Records the current character: summary, bags, gear, bank tabs, professions, recipes, played time |
| `Tooltip.lua` | Item tooltip lines (counts and *Made by*), the crafter index |
| `Theme.lua` | wowdb.dev's colour tokens and fonts, and the small widgets built from them |
| `List.lua` | A virtual scrolling list: a fixed set of rows reused as you scroll |
| `UI.lua` | The window and its three views |
| `Options.lua` | The Settings panel |
| `tests/smoke.lua` | Headless smoke test (not shipped) |
| `media/fonts` | Oswald and JetBrains Mono, with their OFL licences (shipped) |
| `media/textures/logo_64.tga` | The addon list icon (shipped) |
| `media/art` | Logo source SVG and renders (README only) |

## How it works

**One record per character**, keyed `Realm|First Last`. Forever names have a surname, and `UnitName("player")`
returns the first name and surname as two separate values. Keying on the first name alone would merge two
alts who share one, so the key joins them.

**Counts are stored by item ID**: `bags`, `bank` and `equipped` are each an `itemID → count` table. Tooltips and
search add them up on demand. Item names, qualities and icons are cached account-wide (`ForeverAltsDB.items`), taken
from the item links seen while scanning. Search can then find items that the game's own item cache hasn't loaded this session.

**The bank** on Forever is Retail's tab bank. The character bank is bag IDs 6–14 and the account bank is 15–23,
listed by `C_Bank.FetchPurchasedBankTabData`. They're readable only while the bank is open, so they're scanned
on `BANKFRAME_OPENED`, on every bag change while it's open, and once more on close. The account bank is stored
once (`ForeverAltsDB.warband`), not per character, because every character shares it.

**Recipes** come from `C_TradeSkillUI` when your own profession window opens. Linked professions, guild lists
and NPC crafting orders are ignored. Each learned recipe's output item comes from `GetRecipeSchematic`, which
is what the *Made by* line looks up. An empty recipe list never overwrites a recorded one, because the list can
arrive in pieces.

**Played time.** `RequestTimePlayed()` always prints in chat, so Forever Alts asks only once per character.
After that it carries the total forward with the session clock and saves it at logout. When you type
`/played` yourself, it takes the server's figure.

**Rested XP** for logged-out characters is the saved value plus 5% of a level per 8 hours if they logged out
resting (inn or city), a quarter of that otherwise, capped at 150%.

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
- **Not in v0.1**: mail, auctions, reputations, quests, currencies, lockouts, guild bank. Each is a self-contained
  scan plus a view, and can be added without changing the data already saved.

## Troubleshooting

**A character's bank shows nothing.** Banks can only be read while open. Visit a banker on that character once.
Hovering their row on the Characters tab shows when the bank was last recorded.

**Professions say "open the profession window to record recipes".** Open each profession's window once on that
character. Skill levels are recorded at login, but recipes aren't.

**`/played` printed in chat when I logged in.** That happens once per character, the first time Forever Alts sees
it, to learn the total.

**A character I deleted is still listed.** Right-click it → *Forget this character*.

**The window is off-screen, or sized oddly.** `/alts reset`.

## License

MIT, see [LICENSE](LICENSE). The bundled fonts are under the SIL Open Font License; see `media/fonts/OFL-*.txt`.
