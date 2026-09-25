# What only the game answered — 5.5.4.69585

The other files in this directory come from reading. This one comes from **running**, and it is
the half of [#6](https://github.com/Fixxitforge/vanilla-questing/issues/6) that Blizzard's source
drop did not obviate.

`CLIENT-SOURCE.md` sets out the rule: the source says so with a file and a line, or the game said
so with a probe and a log, and memory is not a third answer. Everything below is the second kind.
Each entry names its evidence — a probe section in `../SPEC.md`, a log in `../logs/`, or a report
from play with its date. **An entry with no evidence does not belong here**; that is the whole
point of the file.

Nothing here is a claim about WoW. It is a claim about **this build**, on the machine this AddOn
was tested on.

**Where two logs disagree, the newer one wins and the disagreement is written down.** It has
happened once already, over whether `/reload` restores a swapped blip texture (§6), and the
earlier answer was the comfortable one.

The raw logs stay exactly as they are in `../logs/`. A later probe run switches settled sections
off, so an earlier log is often the only remaining record of an answer — this file is an index
into them, not a replacement for them.

---

## 1. What exists here, and what does not

Straight out of `../logs/recon-log-*.txt`. Every line is a name the probe asked the live client
about; `--` means the global or method is **not on this client**, whatever any documentation says.

This is the half that reads like a list, and it is the half that stops a session inventing an API.
Four CVar names and three frame names were invented from memory before the probe existed, and each
one cost a round trip.

### The objective tracker is `WatchFrame`, and the retail names are all absent

```
OK   WatchFrame  [Frame]          --   ObjectiveTrackerFrame
OK   WatchFrame_Update            --   ObjectiveTracker_Update
OK   WatchFrame_Collapse          --   QuestWatchFrame
                                  --   AutoQuestPopUpTracker
                                  --   ObjectiveTrackerBlocksFrame
```

### The world map is the modern canvas, with the old frames gone

```
OK   WorldMapFrame  [Frame]       --   WorldMapBlobFrame
OK   QuestMapFrame  [Frame]       --   WorldMapPOIFrame
OK   QuestScrollFrame             --   WorldMapQuestShowObjectives
OK   QuestMapFrame_UpdateAll      --   WorldMapShowDropDown
OK   QuestMapFrame_ShowQuestDetails
OK   WorldMapTooltip  [GameTooltip]
```

`WorldMapFrame:RemoveDataProvider` exists, so it is the canvas. **352 methods** on the frame,
**44** global `*DataProvider*` tables, and **15** providers actually registered:

```
AreaLabel      AreaPOI        BattlefieldFlag   BonusObjective   DeathMap
DigSite        EncounterJournal   Gossip        GroupMembers     MapExploration
MapHighlight   QuestBlob      Quest             Scenario         Vehicle
```

Two of them carry a `cvar` field, which is how the CVar behind a pin was found rather than guessed:

```
provider  7  EncounterJournalDataProviderMixin   cvar=showBosses
provider  6  DigSiteDataProviderMixin            cvar=digSites
provider 13  QuestDataProviderMixin              GetPinTemplate=QuestPinTemplate
```

**`WorldMapFrame:RefreshAllDataProviders()` exists and must not be called.** It re-runs
`MapExplorationDataProvider`, which wipes fog-of-war: the map opens fully revealed until you leave
the zone and come back. Tried, shipped, reverted.

### Quest POI and supertracking

```
OK   QuestPOIGetIconInfo          --   QuestPOI_DisplayButton
OK   QuestPOI_GetButton           --   GetQuestPOILeaderboardInfo
OK   QuestPOIUpdateIcons          --   C_SuperTrack
OK   SetSuperTrackedQuestID
OK   GetSuperTrackedQuestID
```

Supertracking exists and is deliberately not used: with the map and minimap options on there is no
marker, no shaded area and no arrow left for it to drive.

### The minimap has no blob API at all

**205 methods** on `Minimap`, and the six blob methods the original spec assumed are **all
absent**:

```
--   Minimap:SetQuestBlobRingAlpha       --   Minimap:SetArchBlobRingAlpha
--   Minimap:SetQuestBlobInsideAlpha     --   Minimap:SetArchBlobInsideAlpha
--   Minimap:SetQuestBlobRingScalar
--   Minimap:SetQuestBlobInsideTexture
```

It is **not** data-provider driven the way the world map is — no `dataProviders`, no
`AddDataProvider`, no `RemoveDataProvider` — and **0 globals contain "blip"**. Three children
(`MiniMapMailFrame`, `MiniMapBattlefieldFrame`, `MinimapBackdrop`) and **0 regions**, so there is
nothing on the frame itself to hide.

`C_Minimap` has exactly five members, and none of them is a global:

```
C_Minimap.ClearAllTracking   C_Minimap.GetNumTrackingTypes   C_Minimap.GetPOITextureCoords
C_Minimap.GetTrackingInfo    C_Minimap.SetTracking
```

### The tracking list is indexed by nothing stable

18 entries on the character the probe ran on, and **index 1 was "Find Herbs"** — a *spell*, with a
`spellID`, present only because that character is a herbalist:

```
 1  name=Find Herbs        type=spell  spellID=2383  active=true
13  name=Low Level Quests  type=other  active=true
17  name=Track Quest POIs  type=other  texture=535616  active=false
18  name=Track Digsites    type=other  texture=535615  active=false
```

**So the index shifts with class and profession**, and resolving *Track Quest POIs* by name rather
than by number is not caution, it is the only thing that works. `subType` is `-1` for every entry
this AddOn cares about and `2` for the vendor rows, so it is no use as a key either ([G30]).

### Quest CVars: four of nine exist

```
OK   questPOI            OK   questHelper          --   autoQuestProgress
OK   autoQuestWatch      OK   trackQuestSorting    --   mapQuestDifficulty
                                                   --   showQuestTrackingTooltips
                                                   --   minimapTrackingShowAll
                                                   --   worldMapFilterAccountCompletedQuests
```

`showQuestTrackingTooltips` is the one that matters: it is the documented way to do what
`Tooltip.lua` does by hand, it is in another AddOn's catalogue, and **it is not on this client**.
That is why the tooltip module exists at all, and why it cost six attempts.

### The Settings API, and which names are real

`Settings` has **76** keys, `SettingsPanel` **263** methods and **91** keys. The old world is gone:

```
OK   Settings.RegisterVerticalLayoutCategory    --   InterfaceOptions_AddCategory
OK   Settings.RegisterCanvasLayoutCategory      --   InterfaceOptionsFramePanelContainer
OK   Settings.RegisterAddOnSetting              --   InterfaceOptionsFrame
OK   Settings.RegisterAddOnCategory             --   Settings.CreateCheckBox   (capital B)
OK   Settings.CreateCheckbox                    --   SettingsDropdownTemplate
OK   Settings.CreateElementInitializer          --   DropdownButtonTemplate
OK   Settings.IsCommitInProgress                --   SettingsSelectionDropdownTemplate
OK   SettingsPanel.categoryLayouts (17)         --   OptionsDropDownMenuTemplate
OK   SettingsPanel.settings (295)               --   InterfaceOptionsDropDownTemplate
OK   WowStyle1DropdownTemplate
OK   SettingsDropDownControlTemplate
```

`Settings.CreateCheckbox` versus `Settings.CreateCheckBox` is the whole reason this file exists.

Nine initializer-shaped globals, which `[G23]` enumerated and which turn out not to include a
paragraph:

```
CreateSettingsAddOnDisabledLabelInitializer   CreateSettingsCheckboxWithColorSwatchInitializer
CreateSettingsButtonInitializer               CreateSettingsExpandableSectionInitializer
CreateSettingsCheckboxDropdownInitializer     CreateSettingsListSearchCategoryInitializer
CreateSettingsCheckboxSliderInitializer       CreateSettingsListSectionHeaderInitializer
CreateSettingsCheckboxWithButtonInitializer
```

And the template census — every `frameTemplate` Blizzard's own registered layouts use, with counts
([G25], 625 initializers walked):

```
KeyBindingFrameBindingTemplate  299   SettingsCheckboxSliderControlTemplate     5
SettingsCheckboxControlTemplate 139   SettingButtonControlTemplate              2
SettingsDropdownControlTemplate  81   SettingsCheckboxDropdownControlTemplate   2
SettingsSliderControlTemplate    48   SettingsCheckboxWithButtonControlTemplate 2
SettingsListSectionHeaderTemplate 18  ...and eleven purpose-built widgets, one each
SettingsKeybindingSectionTemplate 17
```

**Not one generic text or description template in the list.** Every entry is a control, a heading,
or a widget built for one job — which is what sent the search to shipping our own template.

### The tooltip, and how a quest line is recognised

```
OK   GameTooltip  [GameTooltip]       OK   GetNumQuestLogEntries
OK   GameTooltipTextLeft1..8          OK   GetQuestLogTitle
OK   GameTooltip:NumLines             OK   GetQuestLogLeaderBoard
OK   GameTooltip:GetUnit              OK   C_QuestLog  [table]
OK   GameTooltip:ClearLines           --   GetQuestObjectiveInfo
OK   GameTooltip:HookScript
```

Observed live: **the quest name is its own line**, followed by one line per objective, e.g.
` - Riverpaw Gnoll Clue: 0/1`. **The line number varies**, so a matcher has to key off the text and
the colour rather than an index. Eight `GameTooltipTextLeft<N>` font strings existed at the moment
of the dump, and more are created on demand.

---

## 2. Protection and taint

### `taintLog 1` produces no file. `taintLog 2` does.

One line, and three issues sat on "needs a taint log" for a week without it. On this client the
taint log only works at verbosity 2.

> `/console taintLog 2`, then `/reload`, then reproduce, then read
> `Logs/taint.log` in the WoW folder.

### Calling a Blizzard function from AddOn Lua taints what that function writes

`../logs/taint-2026-09-14-v1.1.0.log`, VanillaQuesting the only AddOn loaded:

```
Tainted value written to global WATCHFRAME_NUM_POPUPS by VanillaQuesting
  - Blizzard_UIPanels_Game/Wrath/WatchFrame.lua:478
    pcall() / VanillaQuesting/Tracker.lua:148 / applyModule() / ApplyAll()
```

`Tracker.lua:148` was `pcall(WatchFrame_Update)`. Blizzard's function ran in **our** execution
context, so everything it wrote was marked as ours — and `WATCHFRAME_NUM_POPUPS` is a global
**table**, so one tainted value in it is permanent for the session.

The rest of that log is the spread: `WorldStateChallengeMode_HideTimer`,
`WorldStateProvingGrounds_HideTimer`, `QuestMapFrame.lua:183` — Blizzard's own code, reading a
global this AddOn has no interest in, and being tainted by it long after login.

**A gate is not a fix.** Confining the call to a deliberate `/vq on` was tried; the second log,
`taint-2026-09-15-v1.1.0-5.log`, shows login clean and the first command tainting instead. One
write is as permanent as a thousand. The call has to go.

### `hooksecurefunc` does not taint. Calling does.

The two appear three lines apart in the same file and are opposite things. A post-hook does not
taint the execution it runs after — that is what it is for.

### `HideUIPanel` and `ShowUIPanel` appear in **no** taint log

Three logs, including one taken specifically to find them. The world-map cycle was blamed for
tainting the panel manager across two issues and two shipped fixes, and it was never doing it.

**Reasoning about a mechanism is not evidence of which code triggers it.**

### A blocked action can be Blizzard's code, on our behalf

`ShowUIPanel` refuses in combat when the caller is tainted —
`Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua:811`, gated on
`CheckProtectedFunctionsAllowed`, which is `InCombatLockdown() and not issecure()`.

Our `SetCVar` is enough to make Blizzard's own `CVAR_UPDATE` handler insecure. So
*"Interface action failed because of an AddOn"* can be thrown by Blizzard's code running on a
stack we made insecure, with nothing in this AddOn's own call chain at fault.

### "No error message" is not evidence of "not blocked"

`Blizzard_UIParent/Mists/UIParent.lua:1893`:

```lua
local INTERFACE_ACTION_BLOCKED_SHOWN = false;
function DisplayInterfaceActionBlockedMessage()
	if ( not INTERFACE_ACTION_BLOCKED_SHOWN ) then ... INTERFACE_ACTION_BLOCKED_SHOWN = true; end
end
```

**The message prints at most once per UI session**, and nothing resets the flag short of a
`/reload`. A session that has seen it once, from any AddOn, is silent for the rest of its life. So
any reproduction of a blocked action starts with `/reload`.

### The world map is protected in combat, and deferring does not help

Cycling it mid-fight throws and does nothing. Deferring to `PLAYER_REGEN_ENABLED` throws the same
error — tried twice, the second time only moving *when* it ran. Settled; not worth revisiting.

### `WatchFrame` and its item buttons are **not** protected

`[G33]`, probe v0.32:

```
WatchFrame        [Frame]   IsProtected=false explicit=false forbidden=false
WatchFrameItem1   [Button]  IsProtected=false explicit=false forbidden=false
```

Asked four versions late. The parent had been measured and the claim was generalised to the
children, which are quest-item **use** buttons and the likeliest thing in the tracker to be
secure. It happened to be right. **A measurement on a parent frame is not a measurement on its
children**, and a guess that cites a log is worse than an obvious guess.

The module moved to `SetAlpha(0)` + `EnableMouse(false)` anyway, which makes the question stop
existing rather than resting on a reading that any patch could change.

### What a clean log looks like

`../logs/taint-2026-09-15-clean-v1.1.0-6.log`: fifteen lines, all of them

```
Execution tainted by VanillaQuesting while reading global SLASH_VANILLAQUESTING1
  - Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua:720
```

Blizzard's chat parser reading the slash-command globals every AddOn registers. Transient
execution taint that ends when the stack unwinds, no tainted global anywhere, and nothing to be
done about it.

---

## 3. What renders

The question was "can a line of description text be drawn in Blizzard's settings list", and it
took four probe sections because three perfectly true findings were not answers.

| | |
| --- | --- |
| `[G23]` | Nine `CreateSettings*` / `SettingsList*` constructor globals exist. **None draws a paragraph.** |
| `[G24]` | `CreateSettingsAddOnDisabledLabelInitializer` renders `SettingsAddOnDisabledLabelTemplate`, returns an **empty data table**, and ignores everything passed to it. It draws its own fixed message. |
| `[G25]` | The two paragraphs visible in Blizzard's own options are in **no initializer's data** — 0 hits across **625 initializers**. A census of every `frameTemplate` Blizzard uses returned 22, all controls, headings or purpose-built widgets. |
| `[G26]` | Five candidate templates built and were accepted by the layout. **Two rendered.** `SettingsLanguageRestartNeededTemplate` draws arbitrary text as a control's label — ellipsised, remainder on a tooltip. The other three drew nothing. |
| `[G27]` | **An AddOn's own template renders.** `Settings.CreateElementInitializer` takes any template name, and three rows of a template this project ships drew their sentences, wrapped, in Blizzard's list. |

Three rules came out of that, and they generalise past settings panels:

- **An initializer this client accepts is not one it can render.** Three templates built without
  error, were added without error, and produced no frame. Building proves nothing; only looking
  does.
- **An enumeration is only a negative for the thing it enumerates.** `[G23]` listed the ways to
  *build* an element and that was read as a list of elements that *exist*. Where the game visibly
  does something, "I found no API for it" is a statement about the search.
- **When the question is "can this be drawn", draw it.** Three wrong answers came from reasoning
  about lists.

Two details worth not re-deriving:

- A FontString with a **fixed width and no height** wraps instead of ellipsising. That is the
  whole reason this project ships an XML file.
- `GetExtent()` returned `nil` for all three rows and they rendered anyway, so **the settings list
  decides row height itself**. Do not expect the frame's own height to control the gap around it.

### Two more from the same API

- **A checkbox's label and its tooltip title both come from `data.name`, and there is no
  `SetTooltipFunc`** (`[G23b]`). One string, one colour: an option's name cannot be coloured in
  the native panel without colouring its tooltip title too. Settled; do not retry.
- **`CreateSettingsListSectionHeaderInitializer(name[, tooltip])`** is a plain global, and the
  second argument **does** land in `data.tooltip` (`[G17]`).
- **`Settings.RegisterAddOnSetting` validates nothing.** `[G13b]` asked which of five argument
  orders was accepted and got "all five". `[G13c]` asked where each argument *landed*, with
  sentinel values read back through `GetName` / `GetVariable` / `GetVariableType` /
  `GetDefaultValue`, and one shape scored 4/4. **When a call validates nothing, acceptance is not
  evidence — pass values you can recognise and read them back.**

---

## 4. What refuses, and what a successful write proves

### `questHelper` returns success and does not move

`[G29]`. It exists, reads `1`, is asked for `0`, and still reads `1` afterwards. It reports
`locked=false secure=false readOnly=false`. The server owns it, and the client says so only by
declining.

So `SetCVar`'s boolean is **necessary and not sufficient**: a write is believed only when the
return value and the read-back agree.

### The flags are a cheap pre-check, not an oracle

`[G32]`, for every variable this AddOn drives:

```
questPOI           locked=false secure=false readOnly=false   storedServerCharacter=true
autoQuestWatch     locked=false secure=false readOnly=false   storedServerAccount=true
instantQuestText   locked=false secure=false readOnly=false   storedServerAccount=true
showBosses         locked=false secure=false readOnly=false   storedServerCharacter=true
Outline            locked=false secure=false readOnly=false   storedServerAccount=true
```

`minimapShapeshiftTracking` came back `locked=true` in `[G34]`, so the flags do mean something.
`questHelper` refuses while reporting none of them, so they are not the whole story.

**`questPOI` and `showBosses` are stored per CHARACTER**, the other three per account. A "clean
install" question is usually a "first login of this character" question, and a value only reads
back as its default on a character that has never had it set.

### `SetCVar` returns `success:bool` through the **global** wrapper

`[G32]`. The global is not the same function reference as `C_CVar.SetCVar`; both pass the boolean
through. `GetCVarInfo` is **not** a global here — only `C_CVar.GetCVarInfo`.

### The console can be enumerated, and the entries carry help text

`[G28]`. `C_Console.GetAllCommands` is **absent**; the pre-10.2.0 name **`ConsoleGetAllCommands`
exists** and returns 1642 entries of

```
{ category, command, commandType, help, scriptContents, scriptParameters }
```

The `help` column is the part that was not expected and is worth more than the names. Searching it
rather than the names is how `ShowQuestObjectHighlightEffect` was found — a variable that appears
nowhere in Blizzard's options and whose own description is *"Determines if quest objects in the
world should be highlighted (e.g., sparkles, outline, etc.)"* (`[G34]`, confirmed in play).

`particleDensity` and `ffxGlow` have **zero mentions across Blizzard's entire interface source**
and are real. That is the standing proof that names here cannot be guessed, and that the registry
and the console are discovery tools the source cannot replace.

### Variables that do not exist here

`showQuestTrackingTooltips` and `minimapShowQuestBlobs` (`[G29]`), both of which are in Advanced
Interface Options' catalogue. An AddOn's catalogue is a claim about some client, not this one.

### `Outline` is not a boolean, and nothing renders at any value

`1`, `2` and `3` all mean on; only `0` is off, and `2` is Blizzard's default.

The finding underneath it is worth more, because four versions of an option rested on it
([G11], tested live):

> **`Outline` exists and writes correctly. Values 0/1/2/3 all take. Nothing renders at any value —
> and Blizzard's OWN options window does not change anything either.**

So the outline is a **client rendering fault on this build**, not a dead CVar and not something an
AddOn can reach. `graphicsOutlineMode` (added in 7.0.3, long after 5.4) and
`highlightOutlineQuality` are both absent here, so there is no second lever.

Two nearby variables were tested live and rejected as fixes for the sparkle:

- **`particleDensity 0`** does remove the glimmer — and also removes the particles on lootable
  bodies, which Classic had. Not a fix.
- **`ffxGlow 0`** changes things elsewhere and does not touch the particle glow at all.

All of which was correct, and none of it was the answer: `ShowQuestObjectHighlightEffect` removes
the highlight outright and was found by enumerating the console rather than by testing names
somebody had suggested. **"Every lever I know about fails" is not "no lever exists."**

---

## 5. Order, and when things happen

### `GetCVar` answers with the **default** until `VARIABLES_LOADED`

Found from play on the one value that made it visible: a clean install with Outline switched off
printed *"Outline Mode was changed in Blizzard's options"* in chat, because adoption read the
default `2` and the real `0` arrived moments later looking like the player. The quiet half was
worse — the pre-AddOn value recorded for every CVar option was Blizzard's default rather than the
player's setting.

Blizzard reads the same flag through `EventUtil.AreVariablesLoaded`, which is
`UIParent.variablesLoaded`.

### `CVAR_UPDATE` is dispatched **inside** `SetCVar`, not queued for the next frame

Load-bearing twice over: the re-entry guard in `CVars.lua` depends on it, and so does reading the
world map's state before a write. Confirmed by the order things happen in play — out of combat the
AddOn's cycle runs *after* Blizzard's open and the map ends closed; if the event were queued it
would end open.

### Writing `questPOI` makes the **client** open the world map

`Blizzard_UIPanels_Game/Wrath/QuestMapFrame.lua:253` handles it and ends in
`QuestMapFrame:GetParent():HandleUserActionToggleQuestLog()`. Despite the name, that function
(`Blizzard_WorldMap/Wrath/QuestLogOwnerMixin.lua:37`) has **no closed branch**: every path ends at
`SetDisplayState` with an OPEN state, and that calls `ShowUIPanel`. It toggles the quest-log side
panel; as far as the map goes it only ever opens it.

The handler is live from login — `Blizzard_UIPanels_Game_Classic.toc` carries `## LoadFirst: 1`
and no `## LoadOnDemand`, and `QuestMapFrame_OnLoad` registers `CVAR_UPDATE` unconditionally.

Confirmed in play, 2026-09-15: `/console questPOI 1` with the map shut **opens the map**.

### Nothing tells a frame that a CVar it reads has changed

It keeps what it last drew. The answer is **not** to call the redraw yourself — see §1. For
`questPOI` the client already runs its own handler, untainted, in its own context.

### The client sizes a tooltip **after** every hook in the frame

Five attempts to fit a trimmed tooltip's height were all a frame late, because there is no moment
inside the frame that comes after the client. `OnSizeChanged` is not a moment in the frame: it
fires **inside** the client's own resize, so a height set there is replaced between two draws and
never reaches the screen.

---

## 6. The minimap blips, and the one experiment that cannot be undone

The questgiver `!` and the turn-in `?` are engine-drawn: no frame, no global, no CVar (§1). The
only lever is `Minimap:SetBlipTexture(path)`, which swaps the whole icon sheet. Four things were
established in play, and three of them are traps.

### The lever does reach them — confirmed

`/unrecon blip 136458` (an unrelated texture) turned **every** minimap POI icon into a grey
square, **questgiver `!` and `?` included**. So the marks are on that sheet, and edited artwork
would remove them.

### Blanking the sheet works, and **survives `/reload`**

`SetBlipTexture(nil)` and `SetBlipTexture("")` removed every blip rather than restoring the
default — and the change **outlived a `/reload`**. Only a **full client restart** brought the real
icons back.

That is the correction worth having. An earlier log states the opposite —

> NOTE: there is a setter but NO getter for the blip texture, so a change cannot be read back or
> restored from Lua. **`/reload` restores it.**

— and it was wrong. The later run found `/reload` does nothing for it. **Two logs, one answer, and
the newer one wins**: an experiment on this is not free, and a tester who tries it is restarting
the client.

### `Minimap:SetToDefaults()` removes the entire minimap

Not the blips. The **frame**. It is gone until the client is restarted. **Never call it.** The
probe no longer contains it.

### Setter, no getter

`Minimap:SetBlipTexture` exists; `Minimap:GetBlipTexture` does not. So the default path —
`Interface\MINIMAP\ObjectIconsAtlas` — is the only way back, and it has to be hard-coded. It is
taken from an AddOn that restores it on logout, not from documentation.

### The documented grid is the wrong grid

`C_Minimap.GetPOITextureCoords` steps **0.0703125** across and **0.03515625** down. The widely
documented 8x2 / 256x64 `ObjectIcons` layout is the **old** sheet and does not describe this one —
replacement art must match the measured steps, not the documentation.

And the probe's own atlas viewer draws boxes that **do not line up with the art** at 256x256 or
512x512, so the coordinates and the texture disagree about the grid. Treat `GetPOITextureCoords`
as arithmetic, not as a map; `/unrecon cell <index>` renders one index large to settle what it
actually points at.

**What was deliberately stopped:** hunting for the index the engine uses for a questgiver. Nothing
exposes the mapping from blip to index, so no amount of probing answers it — the image does.

---

## 7. Where the harness was modelling the client backwards

Kept here rather than in `../tests/`, because each one is a fact about the client that a stub got
wrong — and the same shape will be got wrong again.

1. **The tooltip resize order.** The harness ran the client's resize *before* the `Show` hooks, so
   a fit there appeared to survive. Five passes of green tests preceded five reports from the game.
   With the order corrected, four checks go red at 62 pixels where 34 is right.
2. **Nobody was listening to the events we raise.** `SetCVar` raises `CVAR_UPDATE`, and on the
   client Blizzard's frames have been listening since before we loaded. The suite had no listener,
   so it could not ask what the client does in response to our own write — and **1047 checks
   passed on a build that left the world map standing open.** Where the AddOn pokes the client,
   the stub has to include the client's answer.
3. **A test that reads back what it just wrote proves nothing about the screen.** Every CVar check
   here read the variable back, and all of them passed while the UI sat stale. Count the redraw,
   not the value.
4. **A guard that cannot fail is not a guard.** One tracker assertion passed whether or not the fix
   existed, because another code path was already calling the same function. Break the fix and
   watch the check go red before believing it.

---

## 8. Still unprobed

Written down so nobody takes silence for an answer.

- **`HideUIPanel` / `ShowUIPanel` / `ToggleWorldMap` have never been probed.** They are
  existence-checked at every call site, with `Frame:Hide` / `Show` as the certain fallback.
- **Is `ReloadUI` callable in combat?** Unknown, and no longer load-bearing: as of v1.1.1 nothing
  in this AddOn reaches it during a fight.
- **Which blip index the engine uses for a questgiver.** `C_Minimap.GetPOITextureCoords(i)` maps an
  index to a rectangle and nothing exposes the mapping the other way, so no amount of probing
  answers it. The image settles it — see §6 and `../BLIP-TEXTURE-WORKFLOW.md`.
- **Whether `SettingsPanel.categoryLayouts` reaches canvas categories.** `[G25]` walked 625
  initializers in the vertical layouts and found none of Blizzard's own description paragraphs.
  Two readings survive: the text is baked into a purpose-built template (the census in §1 makes
  this the likely one), or those panels are canvas layouts the walk never saw. It stopped
  mattering once the AddOn shipped its own template, and it is the question to re-open if the
  panel ever needs to read a Blizzard setting that lives in a canvas category.
- **Whether a `SetCVar` made during `PLAYER_LOGOUT` persists** to the next login — after a
  `/reload`, a logout to character select, and a full exit. It decides whether the AddOn can put
  the game's settings back when it is disabled or deleted
  ([#32](https://github.com/Fixxitforge/vanilla-questing/issues/32),
  [#57](https://github.com/Fixxitforge/vanilla-questing/issues/57)). Blizzard's source registers
  the event only to write SavedVariables. Probe `[G36]` asks it.
- **Whether `PLAYER_LOGOUT` fires on a `/reload` at all.** Widely assumed, never measured here.
  `[G36]` records it as a side effect: a reload trip that finds nothing written says no.

Answered since this list was written, and moved out of it: whether the client's own quest-log
toggle already refreshes the on-screen quest helper
([#46](https://github.com/Fixxitforge/vanilla-questing/issues/46)). With the map shut it does, and
the AddOn's cycle is kept only for a map that is already open — see `../SPEC.md`, v1.1.1. The
`/vq mapcycle` switch that asked it is gone.
