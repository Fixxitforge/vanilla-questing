# The CurseForge listing

**This file is the source. The page is the copy.**

The listing lives at
[curseforge.com/wow/addons/vanilla-questing](https://www.curseforge.com/wow/addons/vanilla-questing)
and is edited by hand in the CurseForge dashboard — there is no API for page content. That is the
argument for keeping the text here rather than against it: with the words only on the page, the
page went a whole release without anyone noticing it still advertised an option that no longer
exists and a limitation that had been withdrawn. **Edit this file, then paste it.**

The listing is the cleanest of the three registers: what it means for the player, with the
technical reasoning left out. `README.md` carries a little more detail; `dev/SPEC.md` carries all
of it. Different depth, never different facts.

CurseForge's own rules shaped the layout: donation links go at the bottom, civil in size, and never
advertise paywalled features; off-platform links go at the bottom too; and the summary says what
the project does, not who made it. The licence field must read **MIT**, matching `LICENSE`.

Checked against the published page on 2026-09-15. What follows is what the page should say.

---

## Summary field

Turn off the quest helper and experience questing as in the original game.

## Page body

### Questing, the way it used to be

Modern World of Warcraft finishes your quests for you. Markers on the map, arrows on the minimap,
progress in every tooltip — you can complete a quest without ever reading it.

Vanilla Questing turns that layer off. You read the quest text, work out where to go, and find it.
Nothing is added: no quest database, no route planner, no arrows of its own. It only takes away
what the original game never had.

You choose how far it goes. Every option is separate, and everything is on by default.

### What it removes

**Map and minimap**

- Quest markers, the blue objective areas, the Track Quest checkbox and the quest list inside the
  full-screen map
- Quest markers on the minimap
- The boss portraits on zone maps

**Quests**

- Instant quest text — quest text types itself out again, a line at a time
- The framed questgiver portrait beside quest text, in the offer window and the quest log

**Quest tracker**

- Automatic tracking of newly accepted quests
- Clickable quest titles — no click-to-open-map, no right-click menu. Classic's tracker was text
  you read. Tracked achievements go plain text too, and there is a separate option to keep those
  clickable
- The quest item use buttons beside tracked quests

**UI & Graphics**

- Quest progress in tooltips — mousing over a creature no longer tells you which quest it belongs
  to or how many you still need
- The yellow highlight on quest items in your bags, and the `!` on items that start a quest
- The loot sparkles on quest objects
- The outline around quest objects

**Experimental**

Left alone by the Vanilla (Default) preset. Turn them on yourself.

- The Complete Quest popups

### Options

Type `/vq` for the options panel, or find **Vanilla Questing** in the game's own AddOns settings.
Two presets — **Vanilla (Default)** and **Modern** — set everything at once, and every option can
be changed on its own.

From chat:

- `/vq on` / `/vq off` — everything at once, or one option: `/vq off hideMapQuestHelper`
- `/vq status` — what every option is set to, or just one
- `/vq reset` — back to defaults
- `/vq help` — the command list

`/vanillaquesting` works anywhere `/vq` does, if another AddOn has claimed the short form.

### Known limitations

**Removing the loot sparkles on quest objects also removes them from gathering nodes.** Herbs,
mining veins and the rest lose theirs too: the game draws both from one switch, so there is no way
to take the sparkle off a quest object and leave it on a mining vein. Neither had one in the
original game, which is why the option ships on.

### Install

Extract the zip into `World of Warcraft\_classic_\Interface\AddOns\`, so you end up with
`Interface\AddOns\VanillaQuesting\VanillaQuesting.toc`. Restart the game or `/reload`.

### Uninstall

Run `/vq off` first. Several of the things this AddOn changes are the game's own settings rather
than its own, and `/vq off` hands them back. Then delete the `VanillaQuesting` folder.

### Compatibility

Built and tested against **Mists of Pandaria Classic**, 5.5.4 (build 69585), interface 50504.
Other clients are being looked at.

### Bugs and requests

Open an issue on GitHub: https://github.com/Fixxitforge/vanilla-questing/issues

---

## What changed, and why, 2026-09-15

The published page still carried all of this when it was read on 2026-09-15:

1. **A withdrawn limitation.** *"Quest objects show either an outline or loot sparkles, never
   neither"* — untrue since `ShowQuestObjectHighlightEffect` was found. Replaced by the
   gathering-node entry, which is the only live limitation there is.
2. **An option that no longer exists.** *"Replaces loot sparkles on quest objects with outlines"*,
   listed under Experimental. That was Outline Mode, which is now **No Outline Mode** — it removes
   outlines, is not experimental, and sits under UI & Graphics.
3. **Three options missing from the feature list:** Remove Loot Sparkles, No Outline Mode and
   Plain Text Achievements.
4. **No mention of the options panel, the presets, or `/vq`** anywhere except the uninstall note —
   the AddOn read as all-or-nothing when in fact every option is separate.
5. **The old Known limitations section named the achievement tracker.** That limitation was fixed
   in v1.0.1 and is a sub-option now.
