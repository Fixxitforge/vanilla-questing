# dev

Everything here is development material. **None of it ships with the AddOn.**

## `UnmarkedRecon/`

A throwaway probe AddOn, kept deliberately separate from Vanilla Questing so nothing
investigative can leak into the shipped code. It reports what this client actually has, rather
than what an AddOn author might expect it to have.

Its design rule is *discover, don't guess*: where an early pass asked "does the name I expect
exist?", it now enumerates what is really there — method tables, provider objects, tracking
types, registered settings — so a negative result means "not present" rather than "I guessed the
wrong name".

Sections are tagged `[G1]`..`[G27]` and map onto the conclusions in `SPEC.md`. An `ACTIVE`
table at the top of `Recon.lua` decides which ones print; settled sections are switched off but
kept in full, one flag away from running again.

`Templates.xml` carries any frame template a probe section needs to render; `[G27]` is the
first to use one.

```
/unrecon              run it, summary to chat and the full report to SavedVariables
/unrecon print        dump the whole report to chat
/unrecon copy         a selectable box to copy out of
```

Then `/reload` to flush SavedVariables to disk and read
`_classic_\WTF\Account\<ACCOUNT>\SavedVariables\UnmarkedRecon.lua`.

## `knowledge/`

Reference material, and the one part of `dev/` that is not about this AddOn: what the client
exposes, how other people solved the same problems, and what a port to another client faces.

The find that started it is **Blizzard's own interface source for this exact build**. The `classic`
branch of `Gethe/wow-ui-source` reads `5.5.4.69585` in `version.txt` — this client, to the
revision — and it ships the client's generated API documentation with it. `fetch_client_source.sh`
clones it; `build_api_index.lua` turns the documentation into two committed index files so
"does this exist on 5.5.4" is answerable with no network and no client.

It does **not** replace `UnmarkedRecon/`. The source says what exists and what Blizzard's code does
with it; only the game says whether a call is protected, whether a write takes, and whether the
result looks right. Read the source first and probe what the source cannot answer — the one thing
that stays banned is asserting behaviour from memory.

Start at [`knowledge/CLIENT-SOURCE.md`](knowledge/CLIENT-SOURCE.md).

## `logs/`

`recon-log-*.txt` is probe output; `taint-*.log` is the client's own taint log.

**On 5.5.4.69585 `/console taintLog 1` produces no file. `taintLog 2` does.** Three issues sat on
"needs a taint log" for a week because of that one line. The log is written on logout, to
`World of Warcraft/_classic_/Logs/taint.log`.

## `logs/recon-log-*.txt`

The raw output of past probe runs, kept because **every conclusion in `SPEC.md` is evidence from
one of these**, and this client is old content on a new engine where the usual assumptions do not
hold. They are the reason a claim in the spec can be checked instead of trusted.

Named by probe version and run date. Superseded logs are kept rather than pruned: a later run
switches settled sections off, so the earlier file is the only remaining record of that answer.

## `tests/`

The off-client test suite. The AddOn cannot be run here, so `addon_harness.lua` stands up a stub
WoW environment — frames, CVars, events, the tracking API, the Settings API, bag and tracker
frames — and `run_tests.lua` drives the real AddOn files against it.

```sh
cd dev/tests && ./run.sh
```

Needs `lua5.1`, the client's own Lua version, and `luacheck` (`apt-get install lua-check`) for the
static pass — the suite runs without it and says so, but CI installs it, so the same forward-reference and scoping rules
apply here as in game — a trap this project has hit twice.

Every scenario in `run.sh`'s `SCENARIOS` list, including the ones that matter for a subtractive
AddOn: a client with no Settings API, one that refuses a CVar write, one with no `C_Minimap`, and
one where registration half succeeds and the panel must fall back rather than half-work. The run
prints how many there are and how many checks they make; the number is deliberately not written
down here, because it was written down in three places and disagreed with itself in all three.

**The static checks run before any scenario**, because each catches something the others cannot.
`run.sh` also parses every XML file and runs `recon_smoke.lua`, which is why a broken probe or an
illegal `--` inside an XML comment fails the suite rather than reaching the client:

| | catches |
| --- | --- |
| `lint_forward_refs.py` | a call to a `local function` declared further down, which resolves as a nil global. Written here because nothing off the shelf does it, and this project has hit it four times |
| `luac -p` | syntax, including in the probe, which no scenario loads |
| `luacheck` | unused and shadowed locals, undefined globals, assignments nobody reads |
| `lint_provenance.py` | a link to a repository this project has no business pointing at, a coding-session link, a model identifier, or a commit author nobody recognises. Every check is an allowlist — it states what may appear, so it never has to write down what may not |

`luacheck` reads one file at a time and knows nothing about the forward-reference trap, so it
replaces neither of the others. Its WoW globals are an explicit **allowlist** in `.luacheckrc`
rather than a blanket ignore: on a client where the usual assumptions do not hold, a name that
looks right and is not is exactly the mistake worth catching, and `std = "+wow"` would wave it
through.

It earned its place on the first run: `C` standing for both the colour table and `C_Minimap` in one
file, a `nativeCategory` assigned and never read, a `sawWhiteBody` guard collected and never
asserted, and `ClassicQuestingMoPDB = nil` — the SavedVariables name from before the rename, doing
nothing inside a test that was passing for a reason it did not state.

**The suite models the client, so a gap in the model is a gap in the testing.** It once passed
412 checks on a build that froze the game, because it had no `SettingsPanel` and so never called
the hook the freeze recursed through. When a bug gets through, the harness gets the fix too.

**Order is part of the model, and getting it backwards is worse than leaving it out.** Twice now a
scenario has passed whether or not the fix was present, because the harness ran the client's steps
in a sequence the client does not use:

- The tooltip resize ran the client's own sizing *before* the Show hooks. Five passes of green
  tests preceded five reports from the game.
- `VARIABLES_LOADED` was raised *before* the `CVAR_UPDATE` events the client sends while loading
  those variables. That order lets the AddOn apply first, so every value agrees by the time the
  events arrive, and the scenario is green with the bug in place.

A new scenario is not finished until it has been run against the broken code and seen to fail.

**A stub that models only our half models nothing — including the events we RAISE.** `SetCVar`
raises `CVAR_UPDATE`, and until 1.1.0-7 nobody in this harness listened to it but the AddOn. On the
client, `QuestMapFrame` has been listening since before we loaded, and its `questPOI` branch opens
the world map. So the suite could not ask what the map does in response to our own write, and 1047
checks passed on a build that left it open. The harness now registers Blizzard's handler, modelled
from Blizzard's own source, before the AddOn loads.

The older half of the same rule, which is where it started: `hoverTrackingButton` called the AddOn's
`OnEnter` hooks and nothing else — no Blizzard `OnEnter`, no owner, no header line, and `Show()`
was an empty function. So the frame the AddOn is a *guest* on did not exist in the model, and the
question "what does the frame look like when our hook does nothing" could not be asked. It took a
report from the game: with the option off, the hook returned at the top, never called `Show()`,
and Blizzard's entire "Tracking" tooltip vanished.

The model now runs Blizzard's `OnEnter` first and tracks whether the tooltip is shown. **Where the
AddOn hooks someone else's frame, the stub has to include their half**, or every test is a test of
the guest talking to itself.

**And one more, which is not about the harness: `pcall` of a `nil` does not throw.** It returns
`false` and `"attempt to call a nil value"`. A probe section that reached for a function this
client does not have therefore ran to completion and printed the error message where a value
belonged — no section failed, the report existed, the run looked fine, and the wrong answer came
back from the client looking like data. `recon_smoke.lua` greps the report for Lua error text for
exactly this reason.

## Where bugs live

**GitHub Issues**, not a file in the repository. `BUGS.md` existed briefly and was the wrong
place: a bug is a conversation with a state, and a markdown file has neither.

## `BLIP-TEXTURE-WORKFLOW.md`

The manual texture-edit workflow for the questgiver `!` blips, including the UV-to-pixel formula
and a warning about `Minimap:SetToDefaults()`, which destroys the minimap frame.
