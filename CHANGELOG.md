# Changelog

What changed in each version. Newest first.

Entries say what shipped. They do not link issues: an issue can be reopened after a release, and
then the changelog is claiming something the tracker contradicts. The long form — what a change
cost to find, and why it was made that way — is the version history in [`dev/SPEC.md`](dev/SPEC.md).

## 1.1.0

### New

- **Remove Loot Sparkles.** The sparkle on quest objects is gone. It also removes the sparkle on
  gathering nodes such as herbs and mining veins, because the game draws both from one switch —
  neither had one in the original game. Under **UI & Graphics**, on by default.
- **Plain Text Achievements**, a sub-option under Plain Text Quest Tracker. Tracked achievement
  lines go plain text along with quests. On by default; untick it to keep achievements clickable.
- **`/vq status <option>`** reports one option instead of the whole list.

### Changed

- **Outline Mode is now No Outline Mode**, and it removes outlines rather than turning them on. It
  sits under **UI & Graphics**, is on by default, and is no longer experimental. Switching it off
  restores Blizzard's own setting. Its old known limitation is gone: the sparkles have their own
  option now.
- **Ticking *Track Quest POIs* in the minimap dropdown is no longer overruled.** The minimap option
  follows it instead, the way the Instant Quest Text and Automatic Quest Tracking options follow
  Blizzard's own checkboxes. Turning the option off still puts *Track Quest POIs* back.
- The **UI** group is now **UI & Graphics**.
- The command list is five lines rather than seven: `/vq on [option]`, `/vq off [option]` and
  `/vq status [option]` are one command each, not two.
- Hide Boss Portraits no longer asks for a UI reload.
- The quest item buttons beside tracked quests are hidden by a safer route, which keeps the AddOn
  clear of the game's protected-action rules in combat.
- **The map is only taken through its close-and-open refresh when you change the option yourself.**
  When the AddOn puts the setting back after something else has moved it, the map is left as it
  was rather than cycling in front of you.
- **Outline Mode's saved setting is not carried across the rename to No Outline Mode.** The option
  it replaces meant the opposite, so the new one starts at its own default rather than inventing a
  preference from the old value.

### Fixed

- **A clean install no longer says anything in chat on first login.** The AddOn was reading the
  game's console variables before the client had loaded them, and mistook its own first pass for
  the player changing something.
- **The options panel no longer lags on every click.** Changing one option re-applied all of them.
- **The world map no longer opens by itself at login or on a loading screen.** The game opens it
  whenever the map quest helper setting is written, and the AddOn now shuts it again when it was
  the AddOn's own write that opened it. It still opens and closes once when you change a map
  option yourself — that round trip is what makes the on-screen quest helper pick the change up.
- **The AddOn no longer taints the game's quest tracker at login or when you change an option**,
  which could surface much later as *"Interface action failed because of an AddOn"* on something
  unrelated.
- Switching an option off now always switches its effect off — including when the option had turned
  itself on to follow a change made in Blizzard's options.
- Switching an option off now always tries to put its setting back, even if an earlier write
  failed. A setting the game refuses once is given another chance at the next loading screen
  instead of that option staying dead for the session.
- The minimap tracking button's tooltip no longer disappears when the option is off.

## 1.0.0

First release.

- Quest progress removed from tooltips now resizes the tooltip in the same frame, so it no longer
  grows and then shrinks.
- Outline Mode states its known limitation on the option itself.
- The canvas fallback panel now shows an option's known limitation, which only the native panel
  did.
- The note that the Vanilla preset leaves experimental options alone now sits under the
  Experimental heading as a line of description text, out of chat and the preset tooltip.
- Changing the world map quest helper from chat now refreshes the on-screen quest helper, instead
  of leaving it stale until a reload. The map is taken through a close and an open and left
  closed. It does not happen in combat.
- Restoring a setting no longer rewrites console variables that had not moved.

## 0.18.0

- Applied a full review of every player-visible string.
- Five option categories, in both panels.
- Turning off the minimap option now restores Blizzard's Track Quest POIs default.

## 0.17.0

- Fixed two pairs of options that could swap places in the panel between logins.
- Every option is guaranteed to appear in both the panel and `/vq status`.

## 0.16.1

- Fixed quest progress tooltips removing nothing when the tooltip was already on screen.

## 0.16.0

- Added: the framed questgiver portrait beside quest text.
- Added: quest progress appended to tooltips.
- One colour palette across the whole AddOn.

## 0.15.1

- Repository audit; the test suite moved into the repository.

## 0.14.3

- The Defaults button rebuilds the panel immediately.

## 0.14.1 – 0.14.2

- Blizzard's own checkboxes and this AddOn's options now follow each other in **both** directions,
  and chat says which way it went.

## 0.14.0

- Where an option overlaps a Blizzard setting, Blizzard's tooltip says so.
- Fixed the options panel closing by the wrong route.

## 0.13.0

- Added: Instant Quest Text.
- Added: the quest highlight on bag items.

## 0.12.1

- **Fixed a freeze** when opening any options panel.

## 0.12.0

- Added the tracker options: plain-text quest titles, and the quest item use buttons.

## 0.11.0

- Blizzard's own Apply button, and a section heading in the panel.

## 0.10.0

- The options panel is now built from Blizzard's own controls.

## 0.5.0 – 0.9.3

- Added the options panel, then reworked it to match Blizzard's.

## 0.4.0

- Added the experimental outline option.

## 0.3.0

- One name per feature, with a saved-variables migration.

## 0.2.0

- Opt-in CVar options; clearer tracking messages.

## 0.1.0

- Core, CVars and minimap quest markers.
