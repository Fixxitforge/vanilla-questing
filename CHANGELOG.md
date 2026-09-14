# Changelog

What changed in each version. Newest first.

Entries say what shipped. They do not link issues: an issue can be reopened after a release, and
then the changelog is claiming something the tracker contradicts. The long form — what a change
cost to find, and why it was made that way — is the version history in [`dev/SPEC.md`](dev/SPEC.md).

## 1.1.0

- The world map no longer opens and closes by itself on a loading screen. It still refreshes when
  you change a map option yourself.
- The quest item buttons beside tracked quests are now made invisible rather than hidden, which
  keeps the AddOn clear of the game's protected-action rules in combat.
- A console variable that refuses one write is given another chance at the next loading screen,
  instead of that option staying dead for the rest of the session.
- Switching an option off now always tries to put its setting back, even if a write failed earlier.
- Turning off the bag item highlight puts the highlights back at once, with your bags open, instead
  of waiting for the next time the game redrew them.
- **New: Remove loot sparkles on quest objectives.** The sparkle on a quest object is gone. It also
  removes the sparkle on profession nodes — herbs, mining veins — which is what both looked like in
  the original game.
- **Outline Mode is now No Outline Mode**, and it removes outlines rather than turning them on. It
  sits under UI & Graphics with the other graphics options, is on by default, and is no longer
  experimental. Switching it off restores Blizzard's own setting.
- The **UI** group is now **UI & Graphics**.
- A clean install no longer announces anything in chat on first login. The AddOn was reading the
  game's console variables before the client had loaded them, and mistook its own first pass for
  the player changing something.
- **Plain Text Achievements**, a new sub-option under Plain Text Tracker, takes the links out of
  tracked achievement lines as well as quests.
- Ticking *Track Quest POIs* in the minimap tracking dropdown is no longer overruled. The minimap
  option follows it instead, the way the Instant Quest Text and Automatic Quest Tracking options
  follow Blizzard's checkboxes. Turning the option off still puts *Track Quest POIs* back.
- Switching an option off now always switches its effect off, including when the option had
  turned itself on to follow a change made in Blizzard's own options.
- Hide Boss Portraits no longer asks for a UI reload.
- `/vq status <option>` reports one option instead of the whole list, and the command list is five
  lines rather than seven.
- The minimap tracking button's tooltip no longer disappears when the option is switched off.
- Changing one option in the options panel no longer re-applies every option. The panel lagged on
  every click, worst on the options that also drive one of Blizzard's own settings.
- Outline Mode's tooltip no longer warns that it is untested and potentially unstable. It reports
  Blizzard's own setting rather than changing anything, so the warning was not true of it. Its
  known limitation stays, and it is still an experimental option in every other respect.

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
