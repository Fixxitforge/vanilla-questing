# Reference AddOns

Six AddOns worth reading, and what each one is actually good for. Read as evidence of *how other
people solved the problem on a real client*, which is the one thing a wiki cannot give you.

Nothing here is a dependency and nothing here is copied. This project stays a single AddOn with no
libraries.

Three of the five are on GitHub and can be cloned:

```sh
git clone --depth 1 https://github.com/bloerwald/MapCleaner
git clone --depth 1 https://github.com/Stanzilla/AdvancedInterfaceOptions
git clone --depth 1 https://github.com/ItsJustMeChris/idTip-Community-Fork
git clone --depth 1 https://github.com/seblindfors/Immersion
```

The two scrolling-quest-text AddOns are CurseForge-only. `www.curseforge.com` answers
`403 cf-mitigated: challenge`, but `api.cfwidget.com` mirrors the project metadata and the zips
come straight off `mediafilez.forgecdn.net`:

```sh
curl -s https://api.cfwidget.com/wow/addons/scrolling-quest-text        # metadata + file id
curl -sLO https://mediafilez.forgecdn.net/files/3053/541/QuestText.1.3.0.zip
```

Both have been read.

---

## Advanced Interface Options — the most useful of the five

`Stanzilla/AdvancedInterfaceOptions`. Puts back the interface options Blizzard removed, by exposing
the CVars behind them. Its whole reason to exist is the class of problem this AddOn is in.

**It ships for our client.** One `.toc`, ten flavours:

```
## Interface: 120105, 120100, 120001, 50504, 40402, 30405, 20506, 11509
# WOW_INTERFACE_TARGETS: mainline-beta, mainline-test, mainline, mists-test, mists, cata, wrath, tbc-test, tbc, vanilla
```

`50504` is this AddOn's target exactly. So **a multi-value `## Interface:` line is real and is
shipping** — which is the mechanism issue #5 and issue #21 are about, in production, in a CurseForge
package, with the packager directive (`WOW_INTERFACE_TARGETS`) that goes with it.

### What to take from it

**`ConsoleGetAllCommands` — enumerate every CVar the client has.**

```lua
addon.GetAllCommands = ConsoleGetAllCommands or C_Console and C_Console.GetAllCommands
```

This is the answer to "what else is in here". Every probe so far has asked about a CVar we already
suspected; this asks the client for the list. Two names, because it was renamed in 10.2.0 — which
one 5.5.4 has is a probe, and it is one line.

**A list of CVars that cannot be written in combat.** `cvars.lua` opens with
`addon.combatProtected`, about forty entries, all of them nameplate and colourblind variables.
Nothing quest-, map- or tracker-related is on it. That does not clear our own combat problem —
what fails for us is the map panel, not the CVar write — but it does say the write itself was never
the protected part.

AIO's own position is blunter than ours: `addon:SetCVar` returns without writing if
`InCombatLockdown()`, for everything, protected or not.

**An honest reading of the tooltip CVars, which are not there.** AIO's catalogue lists
`showQuestTrackingTooltips` ("Displays quest tracking information in unit and object tooltips") and
`minimapShowQuestBlobs`, both of which would be shortcuts for modules this AddOn hand-writes.
Neither appears anywhere in the 5.5.4 interface source. AIO's catalogue is retail-shaped and
entries in it are *candidates*, not facts about our client — the AddOn checks each at runtime before
offering it. So should we.

**Its `Outline` entry is commented out** with `-- don't know what this does aside from make you
flash when it's set`. On this one thing this project knows more than AIO does.

### One thing not to copy

```lua
function addon:CVarExists(cvar)
  return not not select(2, pcall(function() return addon.GetCVarInfo(cvar) end))
end
```

This is only correct if `GetCVarInfo` *returns nil* for an unknown name. If it *raises*, `pcall`
hands back `false, "error text"`, `select(2, ...)` picks the error string, and the function answers
`true` for every CVar that does not exist. Which way 5.5.4 behaves is unprobed. The construct hides
the difference either way; `GetCVarInfo` has a documented return list, so read it.

---

## MapCleaner — the retail map, and how to take things off it

`bloerwald/MapCleaner`. Retail only (`## Interface: 110002, 120000`). One 900-line Lua file. Lets a
player filter individual POIs, vignettes and quests off the world map by ID.

This is the closest thing to a map of the retail port, because retail's map is not 5.x's map. There
is no `questPOI` to switch off: the map is assembled from **data providers**, each owning a pin
template, and removing something means taking its pins away as they appear.

### The mechanism

```lua
hooksecurefunc(WorldMapFrame, "AcquirePin", function(worldMapFrame, pinTemplate, ...)
    if pinTemplatesToIgnore[pinTemplate] then return end
    self.shallDoTemplateUpdate[pinTemplate] = (self.shallDoTemplateUpdate[pinTemplate] or 0) + 1
    self:DoTemplateUpdatesInNextFrameOrWhenOutOfCombat()
end)
```

then, a frame later, `WorldMapFrame:EnumeratePinsByTemplate(t)` and `WorldMapFrame:RemovePin(pin)`.

The pin templates it knows about are the retail inventory of quest clutter:
`QuestPinTemplate`, `QuestOfferPinTemplate`, `QuestHubPinTemplate`, `BonusObjectivePinTemplate`,
`ThreatObjectivePinTemplate`, `AreaPOIPinTemplate`, `AreaPOIEventPinTemplate`,
`VignettePinTemplate`, `MapLinkPinTemplate`.

The matching data providers, all present in `Blizzard_SharedMapDataProviders` on **our** client too:
`QuestDataProvider`, `QuestBlobDataProvider`, `StorylineQuestDataProvider`, `WorldQuestDataProvider`,
`BonusObjectiveDataProvider`, `AreaPOIDataProvider`, `VignetteDataProvider`,
`DungeonEntranceDataProvider`, `MapLinkDataProvider`.

### Its recorded failures, which are the valuable part

- A whole block of `RefreshAllData` hooking is commented out, with
  `--- does not refresh on unhide`. Hooking the provider refresh was tried and abandoned in favour
  of hooking pin acquisition.
- `-- filtervignette + refresh does not re-add vignettes` — removal is not symmetrical. Taking a
  pin away is easy; putting it back needs `WorldMapFrame:RefreshAll()`.
- `-- DungeonEntranceDataProviderMixin DOES NOT seem to control dungeon entrances` — worth knowing
  before starting issue #9 on retail.
- `-- removes during iteration. bad?` — its own author is unsure. Ours would want to collect first.

### Two idioms to keep

```lua
if InCombatLockdown() then
    EventUtil.RegisterOnceFrameEventAndCallback("PLAYER_REGEN_ENABLED", function() self:DoTemplateUpdates() end)
else
    C_Timer.After(0, function() self:DoTemplateUpdates() end)
end
```

`EventUtil` **exists on 5.5.4** (`Blizzard_SharedXML/EventUtil.lua`) with
`RegisterOnceFrameEventAndCallback`, `ContinueOnAddOnLoaded`, `ContinueOnVariablesLoaded`,
`ContinueOnPlayerLogin`, `ContinueAfterAllEvents`. One-shot registration that unregisters itself is
a thing the client already provides.

And what **not** to copy: MapCleaner replaces the global `MapUtil_ShouldShowTask` outright rather
than hooking it. That is last-writer-wins against every other AddOn, and it is a taint risk.

---

## idTip (Community Fork) — tooltips, and multi-client layout

`ItsJustMeChris/idTip-Community-Fork`. Adds IDs to every tooltip in the game. Interesting here for
two unrelated reasons.

### Tooltip line handling

It reads lines back out of the tooltip by global name:

```lua
for i = 1, 15 do
    frame = _G[tooltip:GetName() .. "TextLeft" .. i]
    if frame then text = frame:GetText() end
    if text and string.find(text, line) then return end   -- already added
end
```

Two lessons, opposite in sign:

- **Idempotence from the frame, not from a flag.** It never keeps "did I touch this tooltip"; it
  looks at the rendered text. `Tooltip.lua` keeps `__vqPinned`, and issue #19 is precisely that the
  flag is never cleared. State re-derived from the frame cannot go stale.
- **The hard-coded `1, 15` is a bug to avoid.** `GameTooltip:NumLines()` exists; a fixed ceiling
  silently misses line 16.

It also documents a hazard we have not hit yet:

```lua
-- Try to avoid C stack overflow from hookscript, only do it once
if not hooked[tooltip] then
    hooked[tooltip] = true
    tooltip:HookScript("OnHide", function() ALL_IDS = {} end)
end
```

Repeated `HookScript` on the same frame stacks up. Guard per-frame.

Note what it does *not* have to solve: it **adds** lines and calls `tooltip:Show()`, and growing a
tooltip works that way. Shrinking one does not — which is the whole story of this project's
six-attempt tooltip stutter, and why the fix had to live in `OnSizeChanged`. Do not read idTip's
`Show()` as evidence that `Show()` is enough.

### Multi-client layout, the other way round

Where AIO ships one `.toc` for ten flavours, idTip ships **one `.toc` per flavour**
(`idTip_CommunityFork.toc`, `_Vanilla`, `_TBC`, `_Wrath`, `_Beta`) with a shared core and a
`clients/` directory split by expansion, selected at runtime:

```lua
function Helpers.GetGameVersion()
    local _, _, _, version = GetBuildInfo()   -- the interface number, e.g. 50504
    return version
end
function Helpers.IsClassic()  return Helpers.GetGameVersion() < 90000 end
```

Two models for issue #5, then: AIO's one-package-many-interfaces and idTip's one-package-per-client.
AIO's is the one that matches "one AddOn, one listing".

`GetBuildInfo()`'s fourth return as a flavour test is worth noting but it is crude —
`IsPTR()` there is `== 100000`. The documented modern test is `WOW_PROJECT_ID` against the
`WOW_PROJECT_*` constants; **which of those constants 5.5.4 defines has not been checked** and
should not be assumed.

---

## Immersion — how to be one AddOn on five clients

`seblindfors/Immersion`. Replaces the quest and gossip frames with a cinematic dialogue view. Very
little of what it *does* is relevant here — it is additive where this AddOn is subtractive. What is
relevant is how it survives being installed on five different clients at once, which is issue #5's
whole problem.

### One package, five interface numbers

```
## Interface: 11509, 20506, 38010, 50500, 120100
```

Era, TBC, a Wrath-era build, **Mists**, retail. That is the second shipping example of the
multi-value `.toc` line, after Advanced Interface Options, and between them the mechanism is not in
doubt.

One detail worth a second look: it declares **`50500`** while the live client is **`50504`**.
Whether the client treats that as current or flags the AddOn out of date is not something the
`.toc` can answer, and it matters for #21 — if a same-expansion interface number is close enough,
the 5.5.5 bump is less urgent than it looks. Worth one glance at the AddOn list in game.

### The pattern to steal: one API table, not branches everywhere

`Interface.lua` defines `ImmersionAPI` and routes every version-sensitive call through it:

```lua
function API:GetQuestText(...)
    return GetQuestText and GetQuestText(...)
end
```

The `Func and Func(...)` shim means a client missing the function returns nil instead of erroring,
and the call sites never learn which client they are on. **This AddOn already writes defensively
this way in places** — `type(WatchFrame_Update) == "function"` before every call — but scattered
through the modules rather than collected. Collecting it is what makes a second client tractable,
and it is the concrete shape issue #5 is missing.

### Two version tests, and why the second one is the better idea

```lua
local IS_RETAIL = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or nil;

local IS_WOW10 = (function()
    local version = select(4, GetBuildInfo())
    if version >= 30401 or ( version >= 11404 and version <= 20506 ) then
        return true
    end
end)();
```

`WOW_PROJECT_ID` against `WOW_PROJECT_MAINLINE` is the documented test, and note that it **degrades
safely**: if either constant is nil on an older client the comparison is simply false, which is the
right answer anyway. That is not proof the constants exist on 5.5.4 — an unprobed nil and a real
false look identical here — but it does mean using it costs nothing.

`IS_WOW10` is the more interesting one, and it is deliberately **not** a version test. It asks
whether the modern API is present, and the answer is discontinuous: 3.4.1 and up, *or* the 1.14.4
to 2.5.6 range, because Blizzard backported the modern API to Era and TBC but not to the Wrath
builds in between.

**A capability is not a version.** Anywhere this project is tempted to write "on Mists, do X",
the question underneath is almost always "is this present", and that one has an answer that keeps
working on a client nobody has thought about yet.

For the record, 50504 clears `>= 30401`, so this client is "WoW10" by that test — consistent with
what probing found independently: the modern Settings API, `MenuUtil`, and frame pools are all here.

### The compat registry, which belongs to a different issue

`Compat.lua` is not about client versions at all. It is a table keyed by **other AddOn names**, each
with a function that patches up the clash:

```lua
L.compat = {
    ['ConsolePort']      = function(self) ... end;
    ['Blitz']            = function(self) ... end;
    ['NomiCakes']        = function(self) ... end;
    ['!KalielsTracker']  = function(self) ... end;
}
```

`Display/Onload.lua` drives it on `ADDON_LOADED`, and the bookkeeping is the good part:

```lua
for addOn, func in pairs(L.compat) do
    if select(4, C_AddOns.GetAddOnInfo(addOn)) then   -- loadable at any point?
        if C_AddOns.IsAddOnLoaded(addOn) then
            func(self)
            L.compat[addOn] = nil
        end
    else                                              -- never going to load
        L.compat[addOn] = nil
    end
end
```

Entries are pruned as they fire or are ruled out, the table is dropped when empty, and the event is
unregistered after that. It handles both orders — the other AddOn loading before or after.

This is the shape issue #15 wants. The ask there was for a report that says which other AddOns are
installed and might clash, and `C_AddOns.GetAddOnInfo` / `IsAddOnLoaded` / `GetAddOnMetadata` are
how you get it. All three are in **Blizzard's own 5.5.4 documentation** and marked `ETMX` in
`api-compat.txt` — present on every flavour, which is as confirmed as an API gets here.

`!KalielsTracker` is worth noting for its own sake: a tracker AddOn that fights back, with an
override on `SetAlpha` to stop it re-showing itself. If a bug report ever arrives about the tracker
reappearing, that is the neighbourhood.

## Classic Quest Text, and Vanilla Scrolling Quest Text — read

Both are CurseForge-only. `www.curseforge.com` answers `403 cf-mitigated: challenge`, but
`api.cfwidget.com` mirrors the project metadata and the zips come straight off
`mediafilez.forgecdn.net`, so both sources have now been read.

They are the same author (Ikechi) solving the same problem on two clients a decade apart, which
makes them an unusually clean measurement of what the retail port costs.

### Classic Quest Text — and a lever this AddOn is not pulling

<https://www.curseforge.com/wow/addons/scrolling-quest-text> — `## Interface: 80300`, 11,104
downloads, last updated at 8.3.0, so abandoned since 2020. 565 lines.

> "The control of fading speed and gradient length is available via standard globals
> (`QUEST_DESCRIPTION_GRADIENT_CPS` and `QUEST_DESCRIPTION_GRADIENT_LENGTH`)."

**Both globals are live on 5.5.4.** `Blizzard_UIPanels_Game/Classic/QuestFrame.lua`, which the
`.toc` lists with **no `AllowLoadGameType` at all** and therefore loads on every flavour:

```lua
QUEST_DESCRIPTION_GRADIENT_LENGTH = 30;
QUEST_DESCRIPTION_GRADIENT_CPS    = 40;
```

and the fade itself, in the same file:

```lua
function QuestFrameDetailPanel_OnUpdate(self, elapsed)
    if ( self.fading ) then
        self.fadingProgress = self.fadingProgress + (elapsed * QUEST_DESCRIPTION_GRADIENT_CPS);
        PlaySound(SOUNDKIT.IG_WRITE_QUEST);
        if ( not QuestInfoDescriptionText:SetAlphaGradient(self.fadingProgress, QUEST_DESCRIPTION_GRADIENT_LENGTH) ) then
```

`TBC/QuestFrame.lua` — the other copy 5.5.x loads — does not redefine any of it, so these are the
real ones.

Which means the typewriter this AddOn switches on with `noInstantQuestText` has a **speed knob that
is a plain global assignment**, and the AddOn does not offer it. Classic Quest Text does exactly
that, from saved settings:

```lua
QUEST_DESCRIPTION_GRADIENT_CPS    = glob_sqt.cps
QUEST_DESCRIPTION_GRADIENT_LENGTH = glob_sqt.len
```

Raised as an issue. Whether it belongs in a subtractive AddOn is a real question — 40 CPS is what
Vanilla did, and "Vanilla, but faster" is a different product — but it is a lever, it is free, and
it was not known about.

The other thing it has is a **skip**: click anywhere in the quest window and the text completes.
Blizzard's own code disables `QuestFrameAcceptButton` until the fade finishes, so a player who
wants to accept is made to wait. Worth knowing before anyone calls the slow text a feature.

### Vanilla Scrolling Quest Text — what the port actually costs

<https://www.curseforge.com/wow/addons/vanilla-scrolling-quest-text> — `## Interface: 120005`,
retail (Midnight), 211 downloads, first published March 2026. 230 lines.

Same author, same feature, **completely different implementation**, and that is the finding:

```lua
local solid = string.sub(full_text, 1, math.max(0, charCount - 3))
local step3 = string.sub(full_text, math.max(1, charCount - 2), math.max(0, charCount - 2))
...
QuestInfoDescriptionText:SetText( ... )
```

No `SetAlphaGradient`. It rebuilds the string character by character on an `OnUpdate` and fakes the
gradient with per-character colour codes on the last three characters.

So the retail version of `noInstantQuestText` is not a CVar, and not a global either — it is a
text-substring animation with a speed slider, a hold-to-speed-up modifier, and an option for
whether the Accept button greys out. 230 lines to replace one line of ours.

**That is the single clearest measurement of the port in this directory**, and it is one option out
of twelve.
