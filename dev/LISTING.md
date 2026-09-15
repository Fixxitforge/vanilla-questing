# The CurseForge listing

**This file is the source. The page is the copy.**

The listing lives at
[curseforge.com/wow/addons/vanilla-questing](https://www.curseforge.com/wow/addons/vanilla-questing)
and is edited by hand in the CurseForge dashboard — there is no API for page content. **Edit this file, then paste the Page body.**

Checked against the published page on 2026-09-15. What follows is what the page should say.

---

**Summary field:**

Turn off the quest helper and immerse yourself in the World of Warcraft.

---

**Page body:**

![Vanilla Questing banner image](https://media.forgecdn.net/attachments/1943/79/vanilla-questing-banner_smaller-png.png)

# Questing the way it used to be

Nowadays, the in-game quest helper almost plays the game for you. Markers on the map, progress in hover tooltips, and QoL improvements so you can rush through the game without hustle.

**Vanilla Questing reverses that.** We restore the original game experience: you read the quest text, work out where to go, and explore the World of Warcraft. The world stops being a checklist and goes back to being… well… a world.

Nothing is added: the addon only takes away things that the original game never had. Every option is on by default, and you have the power to customise your own flavor of vanilla.

![before/after quest tracker](https://media.forgecdn.net/attachments/1940/187/vq-tracker-minimap-png.png)

# What it removes

### 🗺️ Map and minimap

*   **Map quest markers**: also removes the blue objective areas, the Track Quest checkbox and the quest list inside the full-screen map
*   **Minimap quest objective markers**\*: also removes the blue objective areas
*   **Boss portraits**: removed across the world map

### 📜 Quests

*   **Instant Quest Text**: quest text appears slowly
*   **Quest log character frames**: quests no longer reveal who you're looking for

### 🎯 Quest Tracker

*   **Automatic Quest Tracking**: no longer tracks quests when accepted
*   **Clickable titles**: no click-to-open-map, no right-click menu, just plain text
*   **Quest item buttons**: you instead can find the items in your bag

### 🔍 UI & Graphics

*   **Tooltip quest progress**: hovering a mob no longer tells you which quest it belongs to or how many you still need
*   **Quest item highlights in your bags**: no more yellow frames on quest items or `!` on items that start a quest
*   **Loot sparkles on quest objects**: loot sparkles reserved only on lootable corpses
*   **Outline Mode**: removes the yellow outline on quest objects

### 🧪 Experimental

*   **"Complete Quest" popups**: removes the popups that allow you to complete quests faster _(untested feature)_

You have full control, disable as much or as little as you like.

# Options

Type `/vq` for the options panel, or find **Vanilla Questing** in the game's own AddOns settings.

*   `/vq on` / `/vq off` — everything at once, or just one option: `/vq off hideMapQuestHelper`
*   `/vq status` — what every option is set to, or just one
*   `/vq reset` — back to defaults
*   `/vq help` — the command list

`/vanillaquesting` works as a substitute to `/vq`.

![Options menu](https://media.forgecdn.net/attachments/1943/78/vq-options-jpg.jpg)

# Install

*   Extract the zip into `World of Warcraft\_classic_\Interface\AddOns\`
*   Restart the game or `/reload`

# Uninstall

*   Run `/vq off` to restore the modern settings
*   Delete the `VanillaQuesting` folder from `World of Warcraft\_classic_\Interface\AddOns\`

# Compatibility

Built and tested against **Mists of Pandaria Classic**, 5.5.4 (build 69585), interface `50504`. _(Open issue: Support for other versions is in the research pipeline.)_

# Known limitations

**\* Quest objective markers on the minimap:** does not remove the `!` and `?` from the minimap. _(Open issue: we are looking for a solution.)_

**\* Loot sparkles on quest objects**: are also removed from gathering nodes, such as herbs and mining veins. The game renders both from the same variable, so there is no way to remove one without the other.

# Bugs and requests

Found a bug, or want to request a feature? Bug reports and feature requests are genuinely welcome. **[Open an issue on GitHub](https://github.com/Fixxitforge/vanilla-questing/issues/new)**

# ❤️ Support the project

If this addon is making your adventures more enjoyable, you can support the development. It helps pay for the time spent tinkering and keeping the gears turning. **[Support the project on Ko-fi](https://ko-fi.com/fixxit)**
