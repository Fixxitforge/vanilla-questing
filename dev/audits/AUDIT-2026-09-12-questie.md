# Questie — comparison brief, 2026-09-12

**Repository:** https://github.com/Questie/Questie
**Version inspected:** v11.37.1, `Questie-Mists.toc`, `## Interface: 50503, 50504`

## Purpose of this document

**Not** to make the two AddOns work together. That may be worth doing later and there
is a section at the end recording what would be involved, but it is not the job now.

The job is that Questie is a mature AddOn — years old, many contributors, multi-client
— that solves several problems we have open right now, on the same client build. Read
it for those solutions.

Read it critically. Questie is roughly a hundred times our size and carries a quest
database. Most of its architecture is wrong for us. The point is the handful of places
where it has already paid a cost we are about to pay.

---

## How to audit it yourself

The full clone is large. This is enough:

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/Questie/Questie.git
cd Questie
git sparse-checkout set Modules
```

The files that matter for us, in order:

| File | Why |
|---|---|
| `Modules/QuestieCompat.lua` | the compatibility layer — the single most useful file here |
| `Modules/Expansions.lua` | client detection, 20 lines, complete |
| `build.py` | how one source tree ships as five flavors |
| `Modules/Tooltips/TooltipLayout.lua` | tooltip measurement done properly |
| `Modules/QuestieInit.lua` | load ordering, and the WatchFrame hide |
| `Modules/EventHandler/EventHandler.lua` | the `questPOI` login quirk |
| `AGENTS.md` | their agent instructions, worth comparing to ours |

---

## 0. A bug of ours that Questie happens to document

`Modules/EventHandler/EventHandler.lua:74–75`:

> We need to manually hide the map, because having `questPOI` set to `0` will open it
> on login, thanks to Blizzard.

We set `questPOI` to `0` and have no handling for this. Nothing in `SPEC.md` mentions
it. It may well be behind some of the world-map trouble recorded in `CVars.lua`.

- [ ] Log in with `hideMapQuestHelper` on and watch whether the world map opens by
      itself. If it does, handle it — and note that our `doCycleWorldMap` already
      leaves the map closed, so the fix may be as small as making sure that path runs
      at login rather than being skipped because the CVar was already correct.
- [ ] Record the finding in `SPEC.md` either way. A negative result is worth writing
      down once someone has spent the time.

This is ours to fix regardless of whether anyone ever runs both AddOns.

---

## 1. The compatibility layer — for issue #5

`Modules/QuestieCompat.lua` and `Modules/Expansions.lua`.

`Expansions.lua` is the whole client-detection problem in 20 lines: a lookup keyed by
`WOW_PROJECT_ID`, with named constants for each client and a sane default.

```lua
Expansions.Current = expansionOrderLookup[WOW_PROJECT_ID or 2]
Expansions.MoP     = expansionOrderLookup[WOW_PROJECT_MISTS_CLASSIC or 19]
```

Call sites then read `if Expansions.Current >= Expansions.Wotlk then`, which is a
version *range* test rather than a per-client branch — that is the part worth copying.
`Modules/Tutorial/Tutorial.lua:10` is a live example.

`QuestieCompat.lua` does two distinct jobs, and the split is the lesson:

1. **Resolve names that moved.** `local WatchFrame = QuestWatchFrame or WatchFrame`
   (line 17) — one line, resolved once, at the top of a single file. Every other
   module uses the local.
2. **Polyfill things that are missing.** Where an older client lacks `C_Seasons`, it
   defines a stub that returns sensible values, with a comment saying which patch
   added the real one.

Both are confined to one file. Nothing elsewhere in Questie asks what client it is on
unless the behaviour genuinely differs.

**For us:** issue #5 is cross-expansion support. Our `SPEC.md` already records
per-client name differences (`WatchFrame` vs `QuestWatchFrame` vs
`ObjectiveTrackerFrame`) scattered through the G-sections. The moment we support a
second client, those want to be a `Compat.lua` resolved at load, not `if` branches in
`Tracker.lua`.

- [ ] Before writing any second-client code, create `Compat.lua` with the name
      resolution and a client-detection table modelled on `Expansions.lua`.
- [ ] Keep the rule Questie keeps: modules never test the client directly.

## 2. Shipping one AddOn to many clients — also issue #5

`build.py:44` lists one TOC per flavor; `build.py:118–140` generates the CurseForge
flavor manifest from the interface numbers read back out of those TOC files
(`build.py:232`), so the packaging metadata cannot drift from the TOCs.

Questie ships `Questie.toc`, `Questie-Classic.toc`, `Questie-BCC.toc`,
`Questie-WOTLKC.toc`, `Questie-Cata.toc`, `Questie-Mists.toc` — one source tree, one
CurseForge listing, five flavors.

Note also that `Questie-Mists.toc` declares **two** interface numbers:
`## Interface: 50503, 50504`. That answers the 5.5.5 concern from the first audit —
the field takes a list.

- [ ] When #5 comes up, copy this shape rather than inventing one: per-flavor TOC
      files, and a release script that derives the flavor manifest from them.
- [ ] Independently of #5: consider whether our single TOC should already list more
      than one interface number.

## 3. `SetAlpha(0)` as a substitute for `Hide()` — audit finding 1 / issue #16

`Modules/QuestieCompat.lua:281–297`. `HideWatchFrame` uses `SetAlpha(0)` on some
realms and `Hide()` otherwise; `ShowWatchFrame` reverses it.

**Be precise about what this does and does not prove.** Their reason is a realm-specific
rendering quirk, not frame protection. It is not evidence about
`WatchFrameItem<N>:IsProtected()`. What it does show is that alpha is a workable
substitute for `Hide()` on this frame family in production, at scale, for years.

That is the fix already proposed for finding 1, now with a precedent. It does not
remove the need to probe.

- [ ] Probe `WatchFrameItem1` as issue #16 says. Do not treat this as a shortcut past
      the measurement — that substitution is the exact error the first audit found.
- [ ] Then switch to alpha regardless of the answer, since it makes the combat
      question moot.

## 4. Measuring a tooltip instead of pinning it — audit finding 5

`Modules/Tooltips/TooltipLayout.lua:213–233` creates a hidden `GameTooltip`,
`QuestieTooltipLayoutGapMeasureTooltip`, purely to measure text with the game's own
renderer — including the width of colour and texture escape sequences, which is
exactly where naive string measurement goes wrong.

We took a different route: let the tooltip size itself, then call `SetHeight` to pin
it. Finding 5 is a direct consequence — once pinned, we own the height forever and
`Disable()` has nothing that gives it back.

- [ ] Read `TooltipLayout.lua` in full before fixing finding 5. A measure-then-set
      approach may remove the pin problem instead of patching it.
- [ ] If we keep pinning, the `Disable()` restore is still required.

## 5. Test tooling

`AGENTS.md` documents `busted -p ".test.lua" .` plus `luacheck`. There are 51
`*.test.lua` files sitting **next to** the modules they test (`Modules/Phasing.lua` /
`Modules/Phasing.test.lua`), and `setupTests.lua` stubs the WoW globals at the top.

Ours are twelve scenarios in `dev/tests/`, driven by a shell script, plus a
hand-written forward-reference linter. That has served us well and the scenario
approach catches things unit tests would not. But:

- `luacheck` would have caught the duplicate `local applyingPreset` in `Options.lua`
  (audit pass 2, finding 3a) without us writing a linter for it.
- Colocated unit tests are easier to keep in step with the module than a central
  scenario file.

- [ ] Add `luacheck` to `dev/tests/run.sh` as a static check alongside `luac -p`.
      Tune the config rather than silencing whole categories.
- [ ] Consider `busted` for new module-level tests. Keep the scenarios — they test
      different things.

## 6. Two corroborations, worth recording

- Questie hooks with `HookScript` and `hooksecurefunc` throughout
  (`Modules/Tooltips/Tooltip.lua:458–509`). No Blizzard global is overwritten. Our
  safety rule 2 matches production practice in the largest Classic quest AddOn there
  is.
- Their TOC carries `## Notes-esES`, `## Notes-frFR`, `## Notes-ruRU` and the rest,
  and strings go through an `l10n()` lookup. We have `STRINGS.md` and no
  localisation. Not urgent at one download, but the decision to match a Blizzard
  control **by name** rather than index (`MINIMAP_TRACKING_QUEST_POIS`) is the piece
  that would have broken first, and we already got that right.

---

## Known collision points — record, do not fix yet

For a future compatibility issue. All verified against v11.37.1.

| Where | What happens |
|---|---|
| `questPOI` | `QuestieOptionsIcons.lua:1410–1451` writes this CVar. Setting `1` ("Blizzard style objectives") is reverted by our `CVAR_UPDATE` re-assert, silently. **The only true fight.** |
| `instantQuestText` | `QuestieOptionsGeneral.lua:234–244` writes it. Our rule has a `blizzOption`, so we mirror and yield — correct behaviour, but the chat message blames "Blizzard's options" when it was Questie. |
| `WatchFrame` | `QuestieInit.lua:426–427` hides it at login. Our three tracker options then run against a hidden frame: no error, no effect, and `/vq status` still reports them on. |
| `GameTooltip` | `Tooltip.lua:458–509` hooks `OnTooltipSetUnit`, `OnTooltipSetItem`, `OnShow` — three of our four — and adds lines again on `OnUpdate`, after our pass and after our height pin. Our matcher reads `GetTextColor()` and Questie embeds colour as `\|cff` escapes, so we probably do not blank their lines; the height interaction is untested. |

Net effect for a user running both: most of our options are neutralised, because
Questie re-adds the same information through a different door. That is a
philosophical mismatch, not a bug in either AddOn.

- [ ] Raise an issue recording the above. Scope it as "decide what to do", not "make
      it work". The cheapest useful version is detecting Questie at load and printing
      a one-time note naming the options it supersedes.
- [ ] The `questPOI` revert is worth special-casing sooner than the rest. Silently
      reverting another AddOn's setting generates bug reports on *their* tracker.

---

## What not to copy

- **Ace3 and the library stack.** Questie needs a config framework and an event
  system. We have twelve boolean options and one event frame.
- **`QuestieLoader` module registry.** Our `ns` table plus load order in the TOC is
  the right size for this AddOn.
- **The database, the map layer, the nameplate and DBM integrations.** Not our
  problem domain — the opposite of it.

The reason to keep this AddOn small is the same reason it works: it removes things and
adds nothing. Every dependency taken on is a thing that can break when the client
changes.
