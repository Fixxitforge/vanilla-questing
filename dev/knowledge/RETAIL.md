# Retail: what a port would have to remove

Nobody on this project has played retail. Everything here is second-hand, and the source of each
claim is named so it can be checked rather than inherited. **None of it is verified.** It exists so
that when the retail port starts (issue #5) it starts from a list instead of a blank page.

Verification is cheap now: the same mirror that holds this client's source holds retail's.

```sh
dev/knowledge/fetch_client_source.sh live /tmp/wow-ui-live
```

## Reported by a player, unverified

Passed to this project as suggestions from someone who plays retail. Quoted so the wording is not
laundered into a fact:

> "Have you considered using the Zone Map instead of the minimap? It doesn't show all the things
> that the minimap or World map does. Enable it with Shift+M"

A different feature from anything this AddOn touches — not a removal but an alternative surface.
Worth knowing; not obviously ours to switch on for someone.

> "Turn off outline mode, will enable the sparkles. If you turn off Particle Density in Graphics
> options, it will remove the sparkles. I can't find any other way to disable them. There is no
> CVAR or other way to do it in lua."

**This matches what this project found on 5.5.4 independently**, which is the strongest signal in
the whole page: outline and sparkle are alternatives in the engine, and `particleDensity` takes the
sparkle away along with the particles on lootable corpses. Two clients, ten years apart, same
answer. It raises the confidence that the Outline Mode limitation is a property of the engine rather
than of this expansion.

> "You can disable the yellow circles around quest mobs, with `/console ShowQuestUnitCircles 0`"

**`ShowQuestUnitCircles` is also on 5.5.4** — it is in this client's own settings code
(`Blizzard_SettingsDefinitions_Frame/Nameplates.lua:373`), driven from the nameplate options. So
this is not a retail-only lever; it is a lever this AddOn does not currently pull on either client.
See `CLIENT-SOURCE.md`.

> "Afraid, I can't find a way to easily disable the quest information on tooltips. Blizzard removed
> the CVAR to do so in Shadowlands. It's quite a big task, to go in and edit the tooltip manually.
> I've tried that before, and getting it aligned probably was a bitch."

The CVar meant is almost certainly `showQuestTrackingTooltips`, which Advanced Interface Options
still carries in its catalogue and which does not appear anywhere in the 5.5.4 interface source.

The second half of that quote is the interesting half: **editing the tooltip by hand and keeping it
aligned is exactly the module this AddOn already ships**, and the alignment problem they gave up on
is the one that took six attempts and landed in `OnSizeChanged`. On retail the tooltip is built
through `C_TooltipInfo` and `TooltipDataProcessor` rather than by appending lines, so the technique
will not port — but the problem is known-solved once, which is more than the person who tried had.

## The two threads, as evidence of demand

### "Please allow to turn off the quest helper" — read

<https://eu.forums.blizzard.com/en/wow/t/please-allow-to-turn-off-the-quest-helper/529991>

Four posts, 202 views, opened 21 August 2024, **automatically closed 30 days after the last reply**.
Small, and shut. Its value is not its size.

The opening post asks for this AddOn, feature by feature, without knowing it exists:

> "an enforced built-in quest helper that puts markers on the **map**, **mini-map** and **tooltips
> of NPCs**, which directly guide a player to particular quest-related places and NPCs, indicating
> whom to fight and where. I find such a game-design decision to undermine immersive exploration
> and joy of discovery."

Three surfaces named, and all three are options this AddOn already ships. Then:

> "I tried finding addons that could remove quest-related points of interest, however, found
> nothing — only reddit threads where people look for such an addon. There was the 'World Map
> point of interest removal' addon, but it was last updated in 2016 and API changed dramatically
> since then, so it doesn't work. Moreover, **it didn't affect the mini-map and NPCs tooltips**."

Someone looked for this, could not find it, and named the two gaps in the nearest thing they found
— both of which this AddOn covers. That is the strongest demand signal in this file.

No official reply. No CVars or workarounds named beyond "you can turn off the quest arrow".

**And a real objection, from the one reply:**

> "in recent expansions, there is no other way to find them. In Classic, where you had to go was
> spelt out in the quest instructions, but in later expansions … you will be told to go kill The
> Big Bull of Bilbo with no directions for how to find him. … It wouldn't need just turning off
> the map symbols; the devs would have to go back to putting directions in the quest text."

This is the retail port's central design problem and it should be written into the listing rather
than discovered by a player. On 5.5.4 the quest text still tells you where to go, so removing the
helper leaves a playable game. **On retail it may not.** Whatever ships there needs to say plainly
that some modern quests cannot be completed without the markers, and that the options are
individually switchable for exactly that reason.

### The mmo-champion thread — still unread

<https://www.mmo-champion.com/threads/2644576-Should-the-game-remove-quest-assistance-area-maps-and-focus-more-on-exploration>

Cloudflare returns `403` with `cf-mitigated: challenge` to everything this environment can send.
Not summarised here, because it has not been read.

### Marketing, with a correction

**The Blizzard thread is closed to new replies** — Discourse shut it automatically in September
2024. The plan recorded on issue #5 to post in both threads when the retail port ships does not
work for this one. What is available instead: the EU and US forums take new topics, the poster
above asked for recommendations and would be worth a courteous reply if a live thread ever
surfaces, and the reddit threads they mention are the actual place people were looking.

Same tone as everywhere else: what it does, that it is free, one link. Not a pitch.

## What is known to be structurally different

From reading MapCleaner (retail) beside this client's source — see `REFERENCE-ADDONS.md`:

| | 5.5.4 | retail |
| --- | --- | --- |
| Map quest pins | `questPOI` + `questHelper` CVars gate Blizzard's own code | no such gate; pins come from data providers and must be removed per-pin |
| Quest tracker | `WatchFrame`, `WATCHFRAME_LINKBUTTONS` | `ObjectiveTrackerFrame` and its modules |
| Tooltip quest lines | appended lines, removable by editing the tooltip | built through `C_TooltipInfo` / `TooltipDataProcessor` |
| Typewriter quest text | `instantQuestText` off, and the client types it | gone from the client; AddOns re-implement it in Lua |
| Minimap quest markers | `C_Minimap` tracking entry | unverified |
| Quest unit circles | `ShowQuestUnitCircles` | `ShowQuestUnitCircles` |
| Quest log API | `GetQuestLogTitle`, `GetNumQuestLogEntries`, `AddQuestWatch` | **all three gone**; `C_QuestLog.*` instead |
| Opening the map from code | — | `C_Map.OpenWorldMap`, tagged `nocombat` |

Four of the twelve options are a rewrite rather than a port, on this reading. That is the number
issue #5 should be sized against.

The last two rows are from `api-compat.txt`, which is generated from the wiki's cross-flavour
table. The quest log row is the one to note: **the global quest log functions this AddOn calls
throughout do not exist on retail at all.** That is not a per-option cost like the four above; it
is a floor under the whole port.

`C_Map.OpenWorldMap` carrying `nocombat` is worth reading twice, because it is a trap in both
directions. It looks like an explanation for this project's world-map-in-combat bug — and it
cannot be, because the function is retail-only and absent from 5.5.4. It does mean the retail port
inherits a combat restriction on the map, from a different mechanism, before it starts.
