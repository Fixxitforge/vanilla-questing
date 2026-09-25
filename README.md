![Vanilla Questing banner image](https://media.forgecdn.net/attachments/1951/201/vanilla-questing-banner_smaller-png.png)

# Vanilla Questing

*Turn off the quest helper and experience questing as in the original game. Read the quest, explore, and immerse yourself in the World of Warcraft. You have full control, disable as much or as little as you like: no map/minimap markers, no progress in tooltips, instant quest text, vanilla quest tracker, and much more.*

A World of Warcraft AddOn that turns off the quest helper, so questing feels like the original
game again: you read the quest text and go exploring, instead of following a marker.

Nothing is added: it only takes away things the original game never had. Every option is on by
default and every one of them can be switched off on its own.

Built and tested against **Mists of Pandaria Classic**, 5.5.4 (build 69585), interface `50504`.
Support for other client versions is in the research pipeline.

## Install

**[Download the latest release](https://github.com/Fixxitforge/vanilla-questing/releases/latest)**, or
get it from CurseForge.

Extract the zip into:

```
World of Warcraft\_classic_\Interface\AddOns\
```

You should end up with `Interface\AddOns\VanillaQuesting\VanillaQuesting.toc`. Restart the game
or `/reload`, then type `/vq` to open the options.

## Commands

| Command | What it does |
| --- | --- |
| `/vq` | Open the options panel |
| `/vq on [option]` | Enable all vanilla options, or one `[option]` |
| `/vq off [option]` | Disable all options, or one `[option]` |
| `/vq status [option]` | List status of all options, or one `[option]` |
| `/vq help` | List the commands |

There is no `/vq reset`: `/vq on` restores the defaults, because the defaults **are** every vanilla
option on. The **Defaults** button in the options panel does the same thing.

`/vanillaquesting` works anywhere `/vq` does, if something else has claimed the short form.

`[option]` is one of the names below — `/vq status` lists them in game:

`hideMapQuestHelper` · `hideMinimapQuestHelper` · `hideBossPortraits` · `noInstantQuestText` ·
`hideCharacterFrame` · `noAutoQuestTracking` · `trackerPlainText` ·
`trackerPlainTextAchievements` · `hideTrackerItemButtons` · `hideTooltipsQuestProgress` ·
`noBagItemHighlight` · `noQuestSparkles` · `noOutlineMode` · `noCompleteQuestPopup`

## What it removes

Each of these is its own option, on by default, and each can be switched off on its own. The name
in brackets is what you type after `/vq on` or `/vq off`.

### 🗺️ Map and minimap

- **Map quest markers** (`hideMapQuestHelper`): also removes the blue objective areas, the Track
  Quest checkbox and the quest list inside the full-screen map. Driven by the `questPOI` console
  variable, which is why it is the one option that asks for a UI reload
- **Minimap quest objective markers**\* (`hideMinimapQuestHelper`): also removes the blue objective
  areas. This is the *Track Quest POIs* entry in the minimap's own tracking dropdown, so the two
  follow each other in both directions
- **Boss portraits** (`hideBossPortraits`): removed across the world map

### 📜 Quests

- **Instant Quest Text** (`noInstantQuestText`): quest text appears slowly, with the quill
- **Quest log character frames** (`hideCharacterFrame`): quests no longer reveal who you're looking
  for, in the offer window and in the quest log

### 🎯 Quest Tracker

- **Automatic Quest Tracking** (`noAutoQuestTracking`): no longer tracks quests when accepted, and
  no longer adds one to the tracker for five minutes when you make progress on it — the game does
  both from the one `autoQuestWatch` setting
- **Clickable titles** (`trackerPlainText`): no click-to-open-map, no right-click menu, just plain
  text. Tracked achievements go plain text with it — untick **Plain Text Achievements**
  (`trackerPlainTextAchievements`) underneath to keep those clickable
- **Quest item buttons** (`hideTrackerItemButtons`): you instead can find the items in your bag

### 🔍 UI & Graphics

- **Tooltip quest progress** (`hideTooltipsQuestProgress`): hovering a mob no longer tells you which
  quest it belongs to or how many you still need
- **Quest item highlights in your bags** (`noBagItemHighlight`): no more yellow frames on quest
  items or `!` on items that start a quest. One option, because the game draws both with the same
  texture
- **Loot sparkles on quest objects**\* (`noQuestSparkles`): loot sparkles reserved only on lootable
  corpses
- **Outline Mode** (`noOutlineMode`): removes the yellow outline on quest objects

### 🧪 Experimental

Never switched on by the **Vanilla** preset. Turn them on yourself.

- **"Complete Quest" popups** (`noCompleteQuestPopup`): removes the popups that allow you to
  complete quests faster *(untested feature)*

\* See [Known limitations](#known-limitations).

## Known limitations

**Disabling or deleting the AddOn does not put the game's settings back.** The options here drive
the game's **own** settings — they live in the game's configuration, not in this AddOn's, and they
survive it. **`/vq off` hands them back**, and it has to run while the AddOn is still loaded to do
it. Unticking Vanilla Questing in the AddOn list, or deleting the folder, leaves them exactly where
the AddOn left them: there is no hook that runs when an AddOn is disabled or removed, so nothing of
ours gets the chance. Run `/vq off` first — see [Uninstall](#uninstall).

**\* Quest objective markers on the minimap:** does not remove the `!` and `?` from the minimap.
The game draws those itself — there is no frame to hide and no setting to switch, and the one
lever the client offers swaps the whole minimap icon sheet, vendors and herbs with it. Removing
them means shipping edited artwork, which is
[being looked at](https://github.com/Fixxitforge/vanilla-questing/issues/3).

**\* Loot sparkles on quest objects**: are also removed from gathering nodes, such as herbs and
mining veins. The game renders both from the same variable, so there is no way to remove one
without the other. Neither had loot sparkles in the original game, so this is the accepted
behaviour for Vanilla Questing.

**Automatic Quest Tracking takes one original-game behaviour with it.** The game uses one setting,
`autoQuestWatch`, for two things:

- **tracking a quest the moment you accept it** — which the original game did **not** do, and which
  is the behaviour this option is for;
- **tracking a quest for a few minutes when you pick up a quest object** — which the original game
  **did** do.

Switching the option off removes both, because there is one switch. Separating them would mean the
AddOn reaching into the quest log to undo tracking the game had just applied, which it does not do.

## Bugs and requests

**[Open an issue](https://github.com/Fixxitforge/vanilla-questing/issues/new)** — bug reports are genuinely
welcome, and most of the fixes in v1.0.0 came from someone saying "that still looks wrong".

### Check these first

Cheapest answers first. Most reports are answered by one of the top three.

1. Is `VanillaQuesting.toc` directly inside `Interface\AddOns\VanillaQuesting\`? A folder nested
   one level too deep is the commonest install fault, and the symptom is "nothing happens".
2. Is it ticked in the AddOn list on the character select screen?
3. Does `/vq` open the options? If not, it is not loading at all and nothing else matters.
4. Does it survive a `/reload`?
5. Does it still happen with every other AddOn disabled?
6. Does `/vq off` make it stop?

### Then tell us

- What you did, what you expected, and what happened instead.
- The output of `/vq status`, which lists every option and its state.
- Your AddOn version and client build.
- Whether any other AddOns were running — and which, if you found a clash at step 5.

A screenshot settles most things.

## Uninstall

1. Run **`/vq off`** to restore the modern settings.
2. Delete the `VanillaQuesting` folder from `World of Warcraft\_classic_\Interface\AddOns\`.

Run `/vq off` first and while the AddOn is still loaded: it is what hands the game's own settings
back. Deleting the folder on its own leaves them where the AddOn had them.

## Licence

**[MIT](LICENSE)**

## ☕ Support the project

If it is making your adventures better, you can support development with a coffee:
**[Ko-fi](https://ko-fi.com/fixxit)**

## Create a release

1. Releases → Draft a new release → Create new tag: `vX.X.X` → Publish.

The workflow in `.github/workflows/` builds the zip and fills in the title and notes from the changelog.

2. Upload to CurseForge → Copy and paste changelog, without the install instructions.
3. Copy and paste dev/LISTING.md to CurseForge.
