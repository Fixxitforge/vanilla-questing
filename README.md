![Vanilla Questing banner image](https://media.forgecdn.net/attachments/1943/79/vanilla-questing-banner_smaller-png.png)

# Vanilla Questing

*Turn off the quest helper and experience questing as in the original game. Read the quest, explore, and immerse yourself in the World of Warcraft. You have full control, disable as much or as little as you like: no map/minimap markers, no progress in tooltips, instant quest text, vanilla quest tracker, and much more.*

A World of Warcraft AddOn that turns off the quest helper, so questing feels like the original
game again: you read the quest text and go exploring, instead of following a marker.

Built and tested against **Mists of Pandaria Classic** (5.5.4). Support for other client versions
is in the pipeline.

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
| `/vq reset` | Restore default options |
| `/vq help` | List the commands |

`/vanillaquesting` works anywhere `/vq` does, if something else has claimed the short form.

`[option]` is one of the names below — `/vq status` lists them in game:

`hideMapQuestHelper` · `hideMinimapQuestHelper` · `hideBossPortraits` · `noInstantQuestText` ·
`hideCharacterFrame` · `noAutoQuestTracking` · `trackerPlainText` ·
`trackerPlainTextAchievements` · `hideTrackerItemButtons` · `hideTooltipsQuestProgress` ·
`noBagItemHighlight` · `noQuestSparkles` · `noOutlineMode` · `noCompleteQuestPopup`

## What it removes

You have full control, disable as much or as little as you like.

**Map and minimap**

- Removed the quest markers, blue objective areas, the Track Quest checkbox and the quest list
  inside the full-screen map
- Removed the quest markers on the minimap
- Hides the boss markers on zone maps

**Quests**

- No Instant Quest Text, quest text types out a word at a time
- Removed the framed questgiver portrait beside quest text, in the offer window and the quest log

**Quest tracker**

- No automatic tracking of newly accepted quests
- No clickable quest titles — no click-to-open-map, no right-click menu. Classic's tracker was text
  you read. Tracked achievements go plain text too; untick **Plain Text Achievements**
  under it to keep those clickable
- No quest item use buttons beside tracked quests.

**UI & Graphics**

- Quest progress appended to tooltips — mousing a creature no longer tells you which quest it
  belongs to or how many you still need
- The yellow highlight on quest items in your bags, and the `!` on items that start a
  quest — one option, since Blizzard draws both with the same texture
- The loot sparkles on quest objects. This also removes them from gathering nodes such as herbs and
  mining veins — see Known limitations
- The outline around quest objects, where a client draws one

**Experimental**

These are never switched on by the **Vanilla (Default)** preset. Turn them on yourself.

- Removes the Complete Quest popups

## Known limitations

### Removing the loot sparkles on quest objects also removes them from gathering nodes

Removing the loot sparkles on quest objects also removes them from gathering nodes such as herbs
and mining veins. The game draws both from one switch, so there is no way to take the loot sparkle
off a quest object and leave it on a mining vein. Neither quest objects or nodes had loot sparkles
in the original game, so this is the accepted behaviour for Vanilla Questing.

## Compatibility

Built and tested against interface **50504**, client 5.5.4 build 69585.

## Bugs and requests

**[Open an issue](https://github.com/Fixxitforge/vanilla-questing/issues)** — bug reports are genuinely
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

1. Run **`/vq off`** to restore the game's settings.
2. Delete the `VanillaQuesting` folder from `World of Warcraft\_classic_\Interface\AddOns\`.

## Licence

**[MIT](LICENSE)**

## ☕ Support the project

If it is making your adventures better, you can support development with a coffee:
**[Ko-fi](https://ko-fi.com/fixxit)**

## Create a release

Releases → Draft a new release → Create new tag: `vX.X.X` → Publish.

The workflow in `.github/workflows/` builds the zip and fills in the title and notes from the changelog.
