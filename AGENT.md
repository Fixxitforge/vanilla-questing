# AGENT.md — read this first, every run

Notes to myself about this repository: where things live, what has to move together, and the
rules that have been paid for with a bug. **This file is part of the work.** When a rule changes,
or a new place appears that has to be kept in step with another, it is updated in the same pass
as the change itself.

---

## What this is

**Vanilla Questing** — a World of Warcraft AddOn for **Mists of Pandaria Classic**, 5.5.4 (build
69585), interface `50504`. It turns off MoP's quest-helper layer so questing feels like the
original game.

**Everything it does is subtractive.** It hides or switches off Blizzard UI, and never adds quest
data of its own.

### Putting settings back is an internal design rule, not a claim

The AddOn changes settings that belong to the **game**, not to itself — `questPOI`, `showBosses`,
`autoQuestWatch`, `instantQuestText`, `Outline`, and the minimap's Track Quest POIs tracking.
Those survive deleting the folder. So before touching one, the AddOn records what the player had,
and switching the option off writes **their** value back.

**Never advertise this.** No "leaves no trace" anywhere public. It is something that should
simply always work, silently, and a player should never have to think about it — a promise on a
page invites them to check, which is the opposite of the point.

**It is not fully true today**, which is the other reason not to say it. Two paths keep a change
([#18](https://github.com/Fixxitforge/vanilla-questing/issues/18),
[#19](https://github.com/Fixxitforge/vanilla-questing/issues/19)) and one restores Blizzard's default
instead of the player's value ([#27](https://github.com/Fixxitforge/vanilla-questing/issues/27)).
Treat all three as real bugs on their own merits — the design rule is the argument, not a public
commitment.

**The claim stops at `/vq off`, and it stops there permanently.** Not "once the bugs are fixed" —
there is no fix. `#32` walked the rest of the path and it does not close:

- The remembered values live in SavedVariables, inside the folder. Deleting the folder deletes the
  record of what to restore in the same action.
- A logout-time restore would cover the tidy case, and does not cover the others. Unticking the
  AddOn on the character select screen means it never loads and never restores — and that is a
  far commoner thing to do than deleting a folder.
- A crash, a force-quit, or deleting the folder mid-session are all outside anything an AddOn can
  hook.

So the README says what is true and no more: **`/vq off` hands the game's own settings back while
the AddOn is still loaded to do it**, then delete the folder. It never promises that deleting the
folder alone restores anything, and there is no future in which it starts to.

The design rule above is unchanged. Putting settings back is still the job, and #18 and #27 are
still real bugs. What changed is that the end of the road has been walked, and it has a wall at
the end of it.

---

## The one rule that matters most

**I cannot run this.** There is no client here. The AddOn is tested off-client against a stub
harness, and the harness only catches what it models — which has now failed five times in a row
on exactly the things a stub cannot know: the client's timing, its layout order, its resize
order.

So:

- **Every change ships with a numbered in-game checklist** in the reply. That is the only real
  test there is.
- **And with the build attached.** Whenever the reply asks for an in-game test, the files go with
  it — a zip of `VanillaQuesting/` for a fresh install, or just the changed `.lua`/`.xml` files
  when that is quicker to drop in. Asking someone to test a build and making them assemble it
  first is asking twice.
- **An issue that can only be confirmed in game is not mine to close.** See the rule under
  "Backlog and bugs" below. It has been broken once and it cost a wrong fix shipped with a tick
  beside it.
- **Never guess an API name from training data.** This is old content on a new engine and the
  usual assumptions do not hold. The recon log wins over the spec, the spec wins over memory, and
  a contradiction between them gets flagged, not quietly resolved.
- When a fix depends on *when* it runs, **prove the moment before tuning the value.**
- When a report from the game contradicts the model, **the model is wrong.** Fix the harness
  first, watch it go red, then fix the code.

---

## Where everything lives

### Shipped

```
VanillaQuesting/
  VanillaQuesting.toc   <- the ONLY place the version number exists
                           (MAJOR.MINOR.PATCH-BUILD while testing; the -BUILD goes at release)
  Templates.xml         the description row for the settings list; Blizzard has none
  Core.lua              addon table, palette, events, saved variables, slash commands
  CVars.lua             table-driven console-variable rules (RULES)
  Minimap.lua           minimap quest markers, via C_Minimap tracking
  QuestFrame.lua        the questgiver portrait frame
  Tooltip.lua           quest progress appended to tooltips
  Tracker.lua           WatchFrame: plain text, item buttons, turn-in popups
  Bags.lua              the quest highlight on bag items
  Options.lua           settings panel; loaded last because it walks every module
```

### Not shipped

```
AGENT.md                this file
CHANGELOG.md            short, per-version, user-facing. The release workflow reads it.
.github/workflows/release.yml   builds the zip and publishes on a version tag
.github/workflows/tests.yml     runs dev/tests/run.sh on every push and pull request.
                        Checks out the FULL history: lint_hygiene.py reads `git log --all`
                        and a shallow clone silently checks one commit.
README.md               the public front page
dev/README.md           what the probe is, why old logs are kept, how to run the tests
dev/SPEC.md             the living record: work list, architecture, rules, version history,
                        recon conclusions. Long. Structured as
                        core -> Version history -> Recon results.
dev/LISTING.md          the CurseForge listing's text. The FILE is the source, the page is
                        the copy -- see "The CurseForge page" below.
dev/UnmarkedRecon/      the probe AddOn. Dev-only, never folded into Vanilla Questing.
                        Recon.lua + Templates.xml. Sections G1..G27; the ACTIVE
                        table switches them on and off.
dev/logs/recon-log-*.txt  raw probe output. Every conclusion in dev/SPEC.md is evidence from one.
                        Kept, never pruned: a later run switches settled sections off, so an
                        earlier log is often the only remaining record of an answer.
dev/BLIP-TEXTURE-WORKFLOW.md   how the minimap blip atlas would be replaced
dev/knowledge/          the notebook behind the spec: Blizzard's own interface source for
                        this build, the client's generated API index, the wiki's
                        compatibility and protection tags, and CLIENT-BEHAVIOUR.md --
                        the things only the game could answer. Two answers to "what does
                        this client do" are allowed, the source or a log; memory is not
                        a third.
dev/audits/             external reviews, kept verbatim. Each finding is verified
                        against the code before it becomes an issue -- an audit is
                        evidence, not a verdict.
dev/tests/              the off-client suite. ./run.sh runs, in this order:
                        lint_forward_refs.py, lint_hygiene.py, luacheck,
                        luac -p on every Lua file
                        including the probe, XML well-formedness on every XML file,
                        a probe smoke test -- and then every scenario in its
                        SCENARIOS list. The count is whatever the run prints at the
                        end; it is not written down here, because it has been wrong
                        in three places at once.
```

---

## What has to move together

Change one of these and the others are part of the same change, not a follow-up.

| If I change… | …then also |
| --- | --- |
| **The version** | `VanillaQuesting.toc` **only** — everything reads it back through `GetAddOnMetadata`, the test harness included. Then a `## <version>` section in `CHANGELOG.md`, and the tag (see Releasing). |
| **An option's description or limitation** | `README.md` if it is user-facing behaviour, the native tooltip *and* the canvas fallback tooltip — they have drifted apart twice. |
| **A module** | Give it a unique `order`; add it to the panel and to `/vq status` (all three are guarded by tests). Update `dev/SPEC.md`'s work list. |
| **Anything about what the AddOn can't do** | All **three** Known limitations sections: `README.md`, `dev/SPEC.md`, and `dev/LISTING.md` (the CurseForge listing). See below — they are written at different depths on purpose, but they must never disagree about the facts. |
| **A feature, or a command** | `dev/LISTING.md`, in the same pass — that is the CurseForge listing, and it is a public promise that goes stale silently. |

**One command is deliberately not on any of those pages: `/vq mapcycle`.** It is #46's test
switch, not a feature — it exists so a single build can be asked both halves of a question that
needs a client to answer, and it is removed when the question is answered. Not in `/vq help`, not
in `README.md`, not on the listing. Written down here because the row above would otherwise read
as an omission to be fixed.
| **A rule I learn the hard way** | This file. |

### Backlog and bugs do **not** live in a file

They are [GitHub Issues](https://github.com/Fixxitforge/vanilla-questing/issues). `dev/SPEC.md` points at
the tracker and does not list them — a copy goes stale the first time an issue is closed
elsewhere.

**Every issue I open gets:** a label and a body that says what the behaviour is, why it matters,
and what has already been ruled out. **No assignee.**

**And it is opened in my name, never the author's.** The tracker is a record of who found what.
An issue filed under his account is a claim he never made, and nothing in the thread lets him
tell it apart from one he wrote himself. This is already how it works — the credential these
sessions carry posts as the agent account — so the rule is written down for the day that changes:
if the only token to hand would file under the author's name, stop and say so rather than opening
it anyway. The same goes for comments and for closing something.

**What that actually looks like on the page, checked 2026-09-16, and it is not what the rule
above assumes.** An issue or a comment posted through this session's credential renders as
**"Fixxitforge — with Claude"**, not as an account of my own. The author's name is on it. The
agent is named beside it, which is better than nothing and is the whole of what the platform
offers; there is no arrangement of this token that posts as me alone.

So the rule stands where it can and is replaced where it cannot:

- **Every issue, comment, reopen and close I write ends with the footer**, verbatim, without
  exception. It is not decoration — with "— with Claude" being the only other mark, the footer is
  the part a reader can see in the body text, in a quote, and in an email notification:

  ```

  ---
  _Generated by [Claude Code](https://claude.ai/code)_
  ```

- **And the first line says what I did**, not what "we" did. "Shipped in `abc1234`", "Checked
  against the code", "Deferred by decision" — a reader who skips the footer still learns from the
  wording that a person did not sit down and type it.

Nothing here makes the tracker mine. It makes the authorship legible, which was the point of the
rule, and it stops a future session spending a round trying to configure away something that
cannot be configured.

### An issue that can only be confirmed in game is NOT mine to close

**Hard rule, paid for.** `#24`, `#45` and `#54` were closed on a green suite and a written
argument. Two of them turned out to be right; `#24` did not, and the panel behaviour it shipped
was wrong in play — which nothing here could have known, because **there is no client here.**

So, before closing:

> **Can this issue's fix be wrong in a way only the game would show?**

If yes — anything that touches a frame, a CVar write, a protected call, timing, layout, what the
player sees or what chat says — **it is not mine to close.** I say what shipped on the issue, say
plainly that it is unverified, hand over a build, and **the author closes it, or tells me to.**
An issue stays open through as many rounds as that takes.

If no — a lint rule, a CI workflow, a migration order, a documentation file, a test guard, a
comment — the suite is the whole of the verification and I close it as before.

**The cost is asymmetric, which is why the rule is one-sided.** An issue left open for a round is
a line in a list. An issue closed on an argument is a bug with a tick beside it, and the next
person to read the tracker believes it.

**Never write a closing keyword in a commit message.** `closes #12`, `fixes #12`, `resolved #12`
— GitHub acts on any of them when the commit reaches the default branch, and it credits the
close to whoever owns the push credential, which is the author. That is the one thing I do that
does not land under my own name, and no setting changes it: everything else goes through the API
as the agent account, and commits carry my own author and committer, but a push is attributed to
whoever pushed. So the fix is to never arm it. Refer to an issue by number all you like — write
"for #12", "the #12 case" — and close it through the API afterwards, where the right name lands
on the decision.

It is not hypothetical, and the negation does not save you. A message here read *"Not claiming
this closes #11"*, which is the opposite of what GitHub understood: it matched the two words,
ignored the sentence around them, closed the issue and put the author's name on a decision
nobody had made — for a bug that is still open and still unconfirmed in game.
`dev/tests/lint_hygiene.py` fails the suite on the adjacency now.

### The three Known limitations sections

They exist deliberately, at three depths, and all three are updated whenever any one of them is —
or whenever a new limitation is found.

| Where | Register |
| --- | --- |
| **CurseForge** (`dev/LISTING.md`) | The cleanest. What it means for the player, with the technical reasoning left out. |
| **`README.md`** | A little more detail, a little more technical. Names the CVar or the frame where that helps someone reading the code. |
| **`dev/SPEC.md`** | Fully technical. The measurement, the probe section, what was tried and rejected. |

Different depth, never different facts. If the listing says a thing is impossible and the spec
says it is merely unshipped, one of them is lying to somebody.

**The CurseForge page is edited by hand — but its text lives here, in `dev/LISTING.md`.**
There is no API for page content, so nothing can push to it. That used to be the reason for keeping
no copy in the repository, and it was backwards: with the words only on the page, the listing went a
whole release advertising an option that no longer exists and a limitation that had been withdrawn,
and nothing here could see it.

**`dev/LISTING.md` is the source. The page is the copy.** Change the listing by changing that file,
in the same pass as whatever made it wrong, and say in the reply that the page needs pasting. The
file also records what the published page last said and when it was read, so the next drift is a
diff rather than a memory.

**I cannot create releases or push tags** — this session's GitHub token is refused for both.
Milestones, issues and comments do work. What
I can do is get everything ready and say precisely what is left to run. The author tags, or uses
the **Releases → Draft a new release** page on GitHub, which creates the tag itself.

---

## Conventions

- **Versioning.** `MAJOR.MINOR.PATCH`. The `.toc` is the single source of truth — a version
  string hardcoded in Lua is how the probe once shipped announcing 0.4 while its `.toc` said 0.3.

  **Between releases the `.toc` carries a build suffix: `MAJOR.MINOR.PATCH-N`**, `N` starting at 1
  and going up by one every time a build is handed over for testing. It exists so a tester can see
  at a glance which build they actually have — several rounds have been spent on a symptom that
  turned out to be the previous zip still installed, and `/vq status` and the AddOn list both show
  this string.

  **The suffix is dropped in the commit that releases**, so `1.1.0-7` becomes `1.1.0` and the tag
  matches. The release workflow refuses to build a `.toc` with a suffix and says why, rather than
  letting the tag-mismatch check report it as a tagging error.
- **Branch: `main`, always.** Commit and push straight to `main` — not a feature branch, not a
  working branch, not one named after the agent that happened to be running. Anything that lands
  on a side branch has to be merged by hand before it can be tagged, and a release candidate
  sitting one merge away from `main` is a release candidate nobody can tag.

  **This rule outranks the session harness.** Some runners open with a standing instruction to
  develop on a generated branch and push there. That instruction is about the tool, not about
  this repository, and it loses to this line: land on `main` and delete the branch. If a branch
  has already been pushed, merge it to `main` and delete it locally and on the remote in the same
  pass — do not leave it behind as a record of how the work happened to be done.
- **No pull requests.** The work is tracked in the issue it belongs to, not in a PR. Push to
  `main` as soon as the change is done and the suite is green, and say on the issue what shipped.
  A PR here would be a review of one person's work by the same person, with an extra click.
- **"AddOn"**, not "addon", in every user-visible string and in comments.
- **One name per feature.** The module key is the saved-settings key is the name the player
  types. The CVar name stays an implementation detail inside `CVars.lua`.
- **Report the effect, not the switch.** `/vq on X` says what changed, never the CVar transition.
- **Colours come from `ns.color` in `Core.lua`.** Nowhere else. The yellows and whites are the
  game's own globals so the AddOn cannot drift from the interface it sits inside.
- **The changelog is for players, not for me.** `CHANGELOG.md` is public — it is the release
  notes the workflow publishes — so it carries entries and nothing else. No preamble explaining
  how to write it, no notes-to-self about how it is kept: those live here. Entries say what
  shipped, in the player's terms. **They do not link issues** — an issue can be reopened after a
  release, and then the changelog is claiming something the tracker contradicts. The long form —
  what a change cost to find, and why it was made that way — is the version history in
  `dev/SPEC.md`.
- **Commit messages** say what changed and what it cost to find. No model identifiers anywhere in
  the repository.

---

## Lua traps this project has actually hit

1. **Forward references.** A `local` declared halfway down a file resolves as a **nil global** in
   everything above it. Four times now: three silent failures inside `pcall`s in the AddOn, and
   once in the probe, where it stopped `/unrecon` running at all. `luac -p` accepts it and every
   scenario passes over it. **File-level locals go at the top of the file**, and
   `dev/tests/lint_forward_refs.py` (run first by `run.sh`) now catches it.
2. **`table.sort` is not stable in 5.1.** Two modules sharing an `order` could swap between
   logins. Every module has a unique order, and a test guards it.
3. **A guard flag raised too early.** An early `return` past the reset leaves the guard stuck on,
   which silently switches the feature off. Raise it around the part that needs it, not at the
   top of the function.
4. **Re-entrancy through Blizzard's own callbacks.** Writing a setting can signal the panel, which
   refreshes, which writes. One boolean was not enough — it took a depth counter. That bug froze
   the client on *any* options panel opening, with 345 green checks.
5. **A measurement on a parent frame is not a measurement on its children.** One probe result on
   `WatchFrame` was written up as "safe to touch, in combat included" and then relied on for its
   item buttons, which were never tested. A guess that cites a log is worse than an obvious guess.
6. **`pcall` hides a missing method as easily as a failing one.** Existence-check first when the
   difference matters. It also hides a function that was never defined: a whole helper once went
   missing from `Options.lua` and the only symptom was the native panel quietly falling back.
7. **An edit script that fails an assert part-way leaves the file untouched.** One did, I moved
   on, and half a feature was missing for two rounds of debugging. **One edit per script**, and
   re-read the file when an assert fires.
8. **A test that reads back what was just written proves nothing about the screen.** Every CVar
   check here read the variable back, and all of them passed while the UI sat stale. Count the
   redraw, not the value.
9. **A conditional diagnostic fires exactly when you do not need it.** A probe's template census
   was gated behind "found nothing", one false-positive match satisfied the gate, and the useful
   half never printed. Dumps are cheap; print them unconditionally.
10. **An enumeration is only a negative for the thing it enumerates.** Listing the ways to *build*
   an element is not listing the elements that *exist*. Where the game visibly does something, "I
   found no API for it" is a statement about my search, not about the client. Go at it from the
   live UI instead — that is how `instantQuestText` was found, twice over.
11. **The safety rules are not a checklist to reason around.** Safety rule 1 says never touch a
   protected frame in combat; I decided the world map was an exception on an assumption I had not
   probed, and it threw in play — twice, because the second attempt only moved when it ran. When a
   rule and a guess disagree, the rule wins.
12. **A cosmetic win is never worth a visible defect.** Where a nicety and a correctness
   requirement are drawn from the same thing, take the correct one and drop the nicety — do not
   ship both half-working. The AddOn takes the orange label only when it can also keep the tooltip
   title white.
13. **A guard that cannot fail is not a guard.** Break the fix and watch the check go red before
   believing it. One tracker assertion passed whether or not the fix existed, because another
   code path was already calling the same function.
14. **A stub that models only our half models nothing — including events we RAISE.** The rule used
   to be about frames this AddOn hooks. It is wider: `SetCVar` raises `CVAR_UPDATE`, and on the
   client Blizzard's own frames have been listening since before we loaded. The suite had nobody
   listening, so it could not ask what the client does in response to our own write, and 1047
   checks passed on a build that left the world map standing open. Where the AddOn pokes the
   client, the stub has to include the client's answer.
15. **A count written into prose goes stale.** "Ten scenarios" in this file, "twelve" in
   `dev/README.md`, seventeen in `run.sh`. Let the run print the number; do not repeat it.

---

## Client facts worth not re-deriving

- **`WatchFrame`**, not `ObjectiveTrackerFrame`. `WATCHFRAME_LINKBUTTONS`, `WatchFrameItem<N>`,
  `WatchFrameAutoQuest_*`. **`WatchFrame` itself** is `IsProtected() == false`; its **children are
  unprobed**, and `WatchFrameItem<N>` are item *use* buttons, so assume secure until measured
  (issue #16).
- **`QuestModelScene`** is the questgiver portrait frame. `QuestNPCModel` is only a region prefix.
- **`Settings.RegisterVerticalLayoutCategory` returns `category, layout`** — two values.
- **`CreateSettingsListSectionHeaderInitializer(name[, tooltip])`** is a plain global; the second
  argument **does** land in `data.tooltip` (`[G23]`), and `GetTemplate()` is
  `SettingsListSectionHeaderTemplate`.
- **No Blizzard settings element takes a paragraph** (`[G23]`, `[G25]`, `[G26]`) — but
  **`Settings.CreateElementInitializer` renders a template the AddOn ships itself**, confirmed in
  game by `[G27]`. That is `Templates.xml`, and it is how the Experimental note is drawn. A
  FontString with a fixed width and **no height** is what makes it wrap instead of ellipsising.
- **`--` is illegal inside an XML comment** and takes the whole file down with it, which the
  client then reports as a missing template three steps later. `run.sh` parses every XML file now.
- **An initializer this client ACCEPTS is not one it can RENDER.** Three templates built without
  error, added without error, and drew no frame. Building it proves nothing; only looking does.
- **Three wrong answers on one question came from reasoning about lists instead of rendering
  something.** When the question is "can this be drawn", draw it.
- **A checkbox's label and its tooltip title both come from `data.name`, and there is no
  `SetTooltipFunc`** (`[G23b]`). One string, one colour — so an option's name cannot be coloured
  in the native panel without colouring its tooltip title too. Settled; do not retry.
- **`HideUIPanel` / `ShowUIPanel` / `ToggleWorldMap` have never been probed.** Existence-check
  them; `Frame:Hide`/`Show` are the certain fallback.
- **The world map is protected in combat.** Cycling it mid-fight throws "Interface action failed
  because of an AddOn" and does nothing — and deferring to `PLAYER_REGEN_ENABLED` throws the same
  error, so there is no way round it. Guard with `InCombatLockdown` and move on; this is settled
  and not worth revisiting.
- **`Outline` is not a boolean.** 1, 2 and 3 all mean on; only 0 is off. `2` is Blizzard's default.
- **`C_Console.GetAllCommands` is absent**, so CVars cannot be enumerated. Blizzard's settings
  registry (`SettingsPanel.categoryLayouts` → `initializers` → `init:GetSetting()`) is the
  discovery route, and it is how `instantQuestText` was found.
- **A tooltip's height is set by the client *after* every hook in the frame.** The only correction
  that is not a frame late is inside `OnSizeChanged`.
- **Nothing tells a frame that a CVar it reads has changed.** It keeps what it last drew — and the
  answer is **not** to call the redraw yourself. `WatchFrame_Update` and `QuestMapFrame_UpdateAll`
  exist, and calling either from AddOn Lua runs Blizzard's code in our context:
  `WatchFrame_Update` writes the global **table** `WATCHFRAME_NUM_POPUPS`, which makes the taint
  permanent for the session and spreads it to code this AddOn never touches. Three such calls were
  removed in v1.1.0 and none may come back. Hooking with `hooksecurefunc` is fine; calling is not.
- **Writing `questPOI` makes the CLIENT open the world map**, and nothing in the client closes it
  again. `Blizzard_UIPanels_Game/Wrath/QuestMapFrame.lua:253` handles `CVAR_UPDATE` for it and ends
  in `HandleUserActionToggleQuestLog`, which — despite the name —
  (`Blizzard_WorldMap/Wrath/QuestLogOwnerMixin.lua:37`) has **no closed branch**: every path ends at
  `SetDisplayState` with an OPEN state, and that calls `ShowUIPanel`. It toggles the quest-log side
  panel, not the map. `refreshQuestUI` undoes an open that our own write caused; see SPEC.
- **`CVAR_UPDATE` is dispatched inside `SetCVar`**, not queued for the next frame. The `applying`
  re-entry guard depends on it, and so does reading the map's state before a write.
- **`ShowUIPanel` and `HideUIPanel` refuse in combat when the caller is tainted**, and print
  "Interface action failed because of an AddOn" —
  `Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua:811`,
  `InCombatLockdown() and not issecure()`. Our `SetCVar` is enough to make Blizzard's own handler
  insecure, so **that error can come from Blizzard's code on our behalf**, not only from ours (#11).
- **`questPOI` and `showBosses` are stored per CHARACTER**, the other three CVars per account
  ([G32]). A "clean install" question is usually a "first login of this character" question.

---

## Releasing

`.github/workflows/release.yml` does it. Push a tag and it runs the tests, builds
`VanillaQuesting-<version>.zip` with a top-level `VanillaQuesting/` folder (so it extracts
straight into `Interface\AddOns\`), takes the release notes from that version's section of
`CHANGELOG.md`, and publishes.

```
git tag -a v1.2.3 -m "v1.2.3" && git push origin v1.2.3
```

The job **fails on purpose** if the tag and the `.toc` disagree about the version. That is the
check, not an inconvenience.

The tag is cut from `main`, so everything in the release has to BE on `main` first — see the
branch rule above. "Prepare the repo for release" means: the suffix dropped from the `.toc`, the
`CHANGELOG.md` section for that version finished, `dev/LISTING.md` current, the suite green, and
all of it pushed to `main`. Then the tag is one command.

---

## Running the tests

```
cd dev/tests && ./run.sh        failures and the totals
cd dev/tests && ./run.sh -v     every check, passing ones included
```

**It is quiet unless something fails.** A passing run is one line. A failing one prints the
failures and nothing else, so they are not buried under thirty green lines — which is the same
reason the static-failure notice is repeated at the bottom.

Needs `lua5.1` and `luacheck` (`apt-get install lua-check`). The run prints the number of checks
and the number of scenarios; **do not write either down anywhere**, here or in `dev/README.md` —
both were stated as a number, both went stale, and at the last audit this file said ten,
`dev/README.md` said twelve and `run.sh` ran seventeen.

**And it runs in CI now**, on every push and every pull request
(`.github/workflows/tests.yml`), not only when a tag is being built. Between v1.0.0 and v1.1.0
fifty commits landed on `main` with no automated check at all.

Every scenario exists because something escaped. A new guard belongs with the bug that earned it,
and it should be checked by breaking the fix and watching it go red — a guard that has never
failed has never been shown to measure anything.
