-- Vanilla Questing -- CVars
--
-- Every console variable this AddOn drives to a Classic-correct value.
-- Table-driven on purpose: adding another lever is one row, not another
-- module. Safety rule 4 -- a switch Blizzard maintains beats frame surgery.

local ADDON_NAME, ns = ...

local C = ns.color

-- `mirrorOnly` is kept although no rule sets it, deliberately.
--
-- A mirror is an option that has NO default, never enforces, and exists only
-- to report a Blizzard setting and let the player change it from here. It is
-- exempt from `/vq on`, `/vq off`, Defaults and both presets, because a
-- command meaning "stop removing things" has nothing to say about an option
-- that removes nothing.
--
-- `outlineMode` was the only one, for four versions, and it stopped being a
-- mirror once `ShowQuestObjectHighlightEffect` gave this AddOn a reason to
-- have an opinion about outlines. Deleting the machinery with it would mean
-- re-deriving the whole argument -- and it took six rounds to get right -- the
-- next time an option turns out to be something Blizzard owns and we only
-- report. The write-up is in SPEC.md under the options audit; this is the
-- code half of the same note.
--
-- Everything that reads it still works: `SyncFromClient` in this file, the
-- bulk loop and `ResetDefaults` in Core, and `derivedPreset`/`applyPreset` in
-- Options. Setting `mirrorOnly = true` on a rule is all it takes.
local RULES = {
	{
		-- Removes the numbered quest pins, the blue quest area
		-- highlights, the "Track Quest" checkbox and the quest log panel
		-- inside the fullscreen map. Verified in game.
		key     = "hideMapQuestHelper",
		cvar       = "questPOI",
		wanted     = "0",
		-- This AddOn OWNS this variable: nothing in Blizzard's interface shows
		-- it, so there is no control for the player to have an opinion through
		-- and no mirror to correct a disagreement. The option is the control,
		-- and a control that can be switched off without anything happening is
		-- not one.
		--
		-- Without this, a player who had already run `/console questPOI 0` got
		-- an inert option: on changed nothing (correctly -- it was already
		-- where the AddOn wanted it), and off restored the 0 it had recorded,
		-- so the markers never came back while chat said "World map quest
		-- helper restored". The AddOn was telling them something untrue.
		offValue   = "1",
		needsApply = true,
		-- The on-screen quest helper only picks this up when the map pane is
		-- closed and reopened -- reported from play, and not fixed by asking
		-- the tracker to redraw. See refreshQuestUI.
		cyclesMap  = true,
		default = true,
		label   = "world map quest helper",
		onText  = "World map quest markers, blue areas and quest list removed.",
		offText = "World map quest helper restored.",
		group   = "Map and minimap",
		order   = 10,
		title   = "Hide World Map Quest Helper",
		desc    = "Removes the quest markers, the blue objective areas, the Track Quest checkbox and the quest list in the world map.",
	},
	{
		-- Newly accepted quests stop auto-tracking.
		key     = "noAutoQuestTracking",
		cvar    = "autoQuestWatch",
		-- Blizzard shows this one as "Automatic Quest Tracking". Confirmed by
		-- [G19], which read the variable off Blizzard's own control.
		blizzOption = "Automatic Quest Tracking",
		wanted  = "0",
		-- Every CVar rule declares one. The distinction between "hand back
		-- what was recorded" and "write the off value" looked vacuous for the
		-- two-valued rules -- and it is not: a player who already had the
		-- variable at `wanted` gets it RECORDED as their value, and handing
		-- that back leaves the option off with its effect still running.
		--
		-- The mirror cannot catch it either. Nothing is written, so no
		-- CVAR_UPDATE fires, so the two-way sync never runs and the
		-- disagreement simply persists.
		offValue = "1",
		-- Ships ON. Vanilla (Default) is what people install this AddOn for,
		-- so a fresh install gives exactly that. An earlier pass argued the
		-- opposite four lines up -- that this is quality of life rather than
		-- clutter and should ship off. That decision was reversed; the
		-- argument for it is gone rather than left sitting next to the code
		-- that contradicts it.
		default = true,
		label   = "automatic tracking of new quests",
		onText  = "Newly accepted quests are no longer tracked automatically.",
		offText = "Newly accepted quests are tracked automatically.",
		group   = "Quest Tracker",
		order   = 60,
		title   = "No Automatic Quest Tracking",
		desc    = "Stops quests from instantly appearing in the quest tracker when accepted.",
	},
	{
		-- The variable is not a guess. Probe v0.19 [G19] walked the settings
		-- registry and read it off Blizzard's own control: the option labelled
		-- "Instant Quest Text" is backed by the boolean `instantQuestText`.
		-- Earlier passes failed because they searched the CONSOLE under the
		-- wrong name. C_Console.GetAllCommands is indeed absent -- but
		-- ConsoleGetAllCommands, the pre-10.2.0 name, is here and returns
		-- 1642 entries. Corrected by probe v0.32 [G28]; the note used to say
		-- the console could not be enumerated at all, which was wrong.
		--
		-- Classic-correct is OFF: quest text types out a line at a time rather
		-- than landing all at once, which is half of why reading it felt like
		-- reading rather than skipping.
		key     = "noInstantQuestText",
		cvar    = "instantQuestText",
		blizzOption = "Instant Quest Text",
		wanted  = "0",
		-- As above: an option that is off must leave the variable off.
		offValue = "1",
		default = true,
		label   = "instant quest text",
		onText  = "Quest text appears slowly.",
		offText = "Quest text appears instantly.",
		group   = "Quests",
		order   = 40,
		title   = "No Instant Quest Text",
		desc    = "Quest text appears slowly, accompanied by the sound of a quill writing.",
	},
	{
		-- The boss and creature portrait pins MoP puts on
		-- zone maps, which Classic never had. Confirmed working in game.
		-- Recon named the lever: provider 7 is EncounterJournalDataProvider
		-- carrying cvar=showBosses.
		key     = "hideBossPortraits",
		cvar       = "showBosses",
		wanted     = "0",
		-- Owned outright, like questPOI. Same reasoning, same need.
		offValue   = "1",
		-- No `needsApply`, deliberately, and this is the difference from
		-- hideMapQuestHelper.
		--
		-- `needsApply` means "this cannot take effect until the UI reloads",
		-- which puts the option behind Blizzard's Apply button and prompts for
		-- a reload. The boss pins are drawn by the world map's own data
		-- provider when the map opens -- and the map cannot be open while the
		-- options panel is, because both are UI panels and the settings panel
		-- takes the screen. So a player changing this in the panel has no map
		-- on screen to update, and the next time they open one it is built
		-- from the current value.
		--
		-- Changing it from chat with the map already open is the one case that
		-- can look stale, and it is the same accepted behaviour as every other
		-- map-dependent option: the pins are right the next time the map is
		-- opened.
		default = true,
		label   = "boss portraits",
		onText  = "Boss portraits removed from the world map.",
		offText = "Boss portraits restored.",
		group   = "Map and minimap",
		order   = 30,
		title   = "Hide Boss Portraits",
		desc    = "Hides the boss portraits on the world map.",
	},
	{
		-- The sparkles themselves, switched off at the source.
		--
		-- Probe v0.33 [G34] found this by reading the `help` column of
		-- ConsoleGetAllCommands rather than by guessing a name. The client's
		-- own words:
		--
		--   "Determines if quest objects in the world should be highlighted
		--    (e.g., sparkles, outline, etc.)."
		--
		-- Confirmed in game: it removes the glimmer outright. No outline, no
		-- sparkle -- which is what a quest object looked like in Vanilla, and
		-- what four versions of Outline Mode were trying to reach the long
		-- way round.
		--
		-- OURS. Nothing in Blizzard's options exposes it, and the
		-- settings-registry walk has never named it, so the option is the only
		-- control the player has for it here.
		key        = "noQuestSparkles",
		cvar       = "ShowQuestObjectHighlightEffect",
		wanted     = "0",
		-- The client's own default, read back by GetCVarDefault rather than
		-- assumed.
		offValue   = "1",
		default    = true,
		label      = "quest object sparkles",
		onText     = "Loot sparkles removed from quest objects.",
		offText    = "Loot sparkles on quest objects restored.",
		group      = "UI & Graphics",
		order      = 105,
		title      = "Remove Loot Sparkles",
		desc       = "Removes the sparkle effect on quest objects.",
		-- Stated because it is a real cost the player should read before
		-- choosing, not a defect. The client draws both effects from one
		-- switch: there is no separate variable for gathering nodes, so
		-- turning one off turns both off.
		--
		-- It is also Vanilla behaviour -- neither had a glimmer in the
		-- original game -- which is why it is an acceptable limitation rather
		-- than a reason not to ship the option.
		--
		-- The "Known limitation:" prefix is PART OF THE STRING, in every
		-- `limitation` field. The panel paints the line orange and puts it
		-- under the description; it does not add a label. This one shipped
		-- without the prefix once, which made a stated cost read as a second
		-- sentence of description.
		limitation = "Known limitation: also removes the loot sparkles on gathering nodes, such as herbs, mining veins, etc.",
	},
	{
		-- SHARED, the same shape as Instant Quest Text and Automatic Quest
		-- Tracking: Blizzard has a control for it, so the two agree with each
		-- other rather than one of them winning.
		--
		-- This rule was a MIRROR for four versions and is the reason the
		-- mirror machinery exists. What changed is that the AddOn now has an
		-- opinion: `ShowQuestObjectHighlightEffect` removes the glimmer
		-- outright, so there is no longer any reason to want outlines ON. The
		-- Vanilla-correct value is 0, and this option asks for it.
		--
		-- Note the polarity, which is the opposite of the old rule: ON means
		-- Outline 0. The option is named for what it removes, like every other
		-- option here.
		--
		-- `mirrorOnly` is deliberately NOT set. No rule uses it any more, and
		-- the machinery is kept on purpose -- see the note above RULES.
		key         = "noOutlineMode",
		cvar        = "Outline",
		blizzOption = "Outline Mode",
		wanted      = "0",
		-- 2 is Blizzard's own default, confirmed by GetCVarDefault in probe
		-- v0.33 [G32] rather than assumed. Switching the option off hands the
		-- player back the value the game would have had.
		--
		-- No `onValues` any more. The old rule treated 1, 2 and 3 all as "on"
		-- because it was reporting whether outlines were showing; this one
		-- asks a single question -- is Outline 0 -- so the plain
		-- `value == wanted` test is the right one.
		offValue    = "2",
		default     = true,
		label       = "outline mode",
		onText      = "Outlines removed from quest objects.",
		offText     = "Outlines on quest objects restored.",
		group       = "UI & Graphics",
		order       = 110,
		title       = "No Outline Mode",
		desc        = "Removes outline around quest objects.",
		-- No `limitation`. The old one explained that outlines and sparkles
		-- were an either/or and that outlines did not render here. Neither is
		-- a cost of THIS option: it removes outlines, and the sparkles have
		-- their own switch now.
	},
}

-- Guards re-entry: SetCVar itself fires CVAR_UPDATE.
local applying = false

-- questHelper on this client accepts a write and silently ignores it. Any
-- CVar can behave that way, so every write is read back and verified, and a
-- refused write stands down instead of retrying on every event forever.
--
-- Cleared on every PLAYER_ENTERING_WORLD, at the foot of this file. It used to
-- be set once and never cleared, so ONE transient failure killed that option
-- for the rest of the session -- and, worse, blocked the restore. A session
-- can be many hours; a loading screen is the natural moment to give a variable
-- another chance, and the verification below means a genuine refusal simply
-- latches again on the next write.
--
-- Note what this does NOT do: gate on GetCVarInfo's isLockedFromUser / isSecure
-- / isReadOnly. Probe v0.33 [G32] read all three for every variable this AddOn
-- drives and they are all false -- while questHelper [G29] refuses its write
-- reporting none of them. The flags are a cheap pre-check, not an oracle.
local refused = {}

-- Whether a CVar's current value counts as this rule being on. Most are a
-- plain match against `wanted`; a rule with several "on" values lists them.
local function ruleIsOn(rule, value)
	if value == nil then return false end
	if rule.onValues then return rule.onValues[value] and true or false end
	return value == rule.wanted
end

local function readCVar(name)
	local ok, v = pcall(GetCVar, name)
	if not ok then return nil end
	return v
end

-- Redraw the frames whose contents depend on a variable we just changed.
--
-- Changing questPOI with the world map pane open updated the map but left the
-- quest tracker showing its old POI numbers: nothing tells the tracker that a
-- variable it reads has moved, so it keeps whatever it last drew until some
-- other event makes it rebuild. A reload fixed it, which is not a fix.
--
-- Both of these are confirmed present on this client by the probe (v0.9 log)
-- rather than assumed. Existence-checked and pcall'd anyway, per safety rule
-- 5: a client without one of them loses the redraw, not the feature.
--
-- The map is only refreshed when it is actually on screen. The tracker is
-- refreshed unconditionally -- it is always visible, and WatchFrame_Update is
-- what every other part of this AddOn already calls to make it rebuild.
local function mapIsOpen()
	if type(WorldMapFrame) ~= "table" or type(WorldMapFrame.IsShown) ~= "function" then
		return false
	end
	local ok, shown = pcall(WorldMapFrame.IsShown, WorldMapFrame)
	return ok and shown and true or false
end

-- Take the world map through a close and an open, and leave it closed.
--
-- Asking the tracker to redraw was not enough: reported from play, the
-- on-screen quest helper only picks a questPOI change up when the map pane
-- closes and reopens. Whatever the map does on that round trip is not
-- reachable any other way that has been found, so this does the thing that
-- works rather than the thing that ought to.
--
-- The map ends CLOSED either way:
--
--   already open  ->  close, open, close
--   already shut  ->  open, close
--
-- So a shut map is opened for an instant. That is deliberate: the round trip
-- is what refreshes the helper, and half of one does not.
--
-- HideUIPanel and ShowUIPanel have never been probed on this client, so they
-- are existence-checked and the frame's own Hide and Show -- which every Frame
-- has -- are the fallback. The panel functions are preferred because they keep
-- the UI panel manager's idea of what is open in step with reality.
local function doCycleWorldMap()
	if type(WorldMapFrame) ~= "table" then return false end

	local hide = (type(HideUIPanel) == "function") and HideUIPanel or WorldMapFrame.Hide
	local show = (type(ShowUIPanel) == "function") and ShowUIPanel or WorldMapFrame.Show
	if type(hide) ~= "function" or type(show) ~= "function" then return false end

	local ok = true
	local function step(fn)
		local done = pcall(fn, WorldMapFrame)
		ok = ok and done
	end

	if mapIsOpen() then step(hide) end
	step(show)
	step(hide)
	return ok
end

-- Not in combat. Showing a UI panel from AddOn code during a fight throws
-- "Interface action failed because of an AddOn" and does nothing, so the guard
-- is the whole of the handling: the map is left alone and the player opens it
-- themselves if it looks stale. Deferring it to the end of the fight was tried
-- and threw the same error.
local function inCombat()
	if type(InCombatLockdown) ~= "function" then return false end
	local ok, yes = pcall(InCombatLockdown)
	return ok and yes and true or false
end

local function cycleWorldMap()
	if inCombat() then return false end
	return doCycleWorldMap()
end

local function refreshQuestUI(rule)
	if type(WatchFrame_Update) == "function" then
		pcall(WatchFrame_Update)
	end
	if type(QuestMapFrame_UpdateAll) == "function" and mapIsOpen() then
		pcall(QuestMapFrame_UpdateAll)
	end
	-- Only the rules the map and the tracker actually read. Cycling the map
	-- for a variable it does not look at would be a visible jolt for nothing,
	-- and this now fires whether or not the map is already open.
	if rule and rule.cyclesMap then cycleWorldMap() end
end

local function writeCVar(rule, value)
	if refused[rule.cvar] then return false end

	applying = true
	-- SetCVar returns `success:bool`, documented in the client's own generated
	-- API files and confirmed through the GLOBAL wrapper by probe v0.33 [G32]
	-- -- which is not the same function reference as C_CVar.SetCVar, and
	-- passes the value through anyway. This used to infer refusal from the
	-- read-back alone.
	local called, reported = pcall(SetCVar, rule.cvar, value)
	applying = false

	if not called then
		refused[rule.cvar] = true
		ns:Warn("cvar:set:" .. rule.cvar,
			"could not set " .. rule.cvar .. "; skipping " .. rule.label .. ".")
		return false
	end

	-- The read-back stays, and the boolean does not replace it.
	--
	-- `questHelper` [G29] returns true from SetCVar and does not move: the
	-- server owns it, and the client says so only by declining to change the
	-- value. So the boolean is necessary and not sufficient, and a write is
	-- only believed when both agree.
	if reported == false then
		refused[rule.cvar] = true
		ns:Warn("cvar:set:" .. rule.cvar,
			rule.cvar .. " was refused (asked for " .. tostring(value) ..
			"). Skipping " .. rule.label .. ".")
		return false
	end

	local now = readCVar(rule.cvar)
	if now ~= value then
		refused[rule.cvar] = true
		ns:Warn("cvar:refused:" .. rule.cvar,
			rule.cvar .. " would not change (asked for " .. tostring(value) ..
			", still " .. tostring(now) .. "). Skipping " .. rule.label .. ".")
		return false
	end
	refreshQuestUI(rule)
	return true
end

local function makeModule(rule)
	local M = ns:RegisterModule(rule.key, {})
	M.onText = rule.onText
	M.offText = rule.offText
	M.experimental = rule.experimental
	M.group = rule.group
	M.title = rule.title
	M.order = rule.order
	M.desc = rule.desc
	M.needsApply = rule.needsApply
	-- A cost the player should read before choosing, not after.
	M.limitation = rule.limitation
	-- The label Blizzard shows for the same thing, where it shows one at all.
	-- Used to annotate Blizzard's control and to decide who wins a conflict.
	M.blizzOption = rule.blizzOption
	-- Read by Core (bulk commands, reset) and by Options (preset derivation).
	M.mirrorOnly = rule.mirrorOnly
	M.blizzVariable = rule.blizzOption and rule.cvar or nil

	-- One name: the module key is the saved-settings key is the handle the
	-- player types. The CVar name stays an implementation detail in `rule`.
	ns:RegisterDefaults({ [rule.key] = rule.default })

	-- Clean install only. An option that SHIPS OFF beside a Blizzard control
	-- takes whatever the player already has instead of pretending to differ
	-- from it. No rule ships off today -- `outlineMode` was the one, and it
	-- ships on as `noOutlineMode` now -- so this path is dormant rather than
	-- dead. It is kept with the rest of the mirror machinery, and for the same
	-- reason: the mismatch it exists to prevent is what announced itself in
	-- chat on a first login, and rediscovering that would be expensive.
	--
	-- Options that ship ON are not adopted. A fresh install is supposed to
	-- give the Vanilla experience, and reading the player's existing settings
	-- instead of applying ours would quietly stop doing the thing the AddOn
	-- was installed for. They enforce, the variable moves to match, and the
	-- mirror finds them in agreement -- which is also silent, for the right
	-- reason.
	--
	-- Rules with no Blizzard control are not adopted either. Nothing in the
	-- interface claims to own those, so there is no control to agree with.
	function M:SyncFromClient()
		if not rule.mirrorOnly then return end
		if type(GetCVar) ~= "function" then return end
		local current = readCVar(rule.cvar)
		if current == nil then return end
		ns.db.settings[rule.key] = ruleIsOn(rule, current)
	end

	function M:Enable()
		if type(GetCVar) ~= "function" or type(SetCVar) ~= "function" then
			ns:Warn("cvar:missing", "GetCVar/SetCVar missing; skipping " .. rule.label .. ".")
			return
		end

		local current = readCVar(rule.cvar)
		if current == nil then
			ns:Warn("cvar:absent:" .. rule.cvar,
				rule.cvar .. " does not exist on this client; skipping " .. rule.label .. ".")
			return
		end

		-- Remember what the player had before we touched it, once, so Disable
		-- restores it rather than guessing at Blizzard's default.
		if ns.db.state[rule.cvar] == nil then
			ns.db.state[rule.cvar] = current
		end

		-- Already at a value that counts as on -- Outline 2 or 3, say -- is
		-- left where the player put it rather than dragged down to `wanted`.
		if not ruleIsOn(rule, current) then
			writeCVar(rule, rule.wanted)
		end
	end

	function M:Disable()
		local original = ns.db and ns.db.state[rule.cvar]
		if original == nil then return end

		-- Forget as we hand back -- the same rule as Minimap.lua, and the same
		-- bug if it is skipped. Enable only records when there is nothing
		-- recorded, so a value kept past the hand-back is one that can never be
		-- replaced: change the variable yourself while the option is off, turn
		-- the option on and then off again, and it goes back to what it was two
		-- decisions ago rather than to what you just chose.
		--
		-- Cleared ahead of the early returns below, not after them. A refused
		-- write and a value that never moved both mean this AddOn is no longer
		-- holding anything down, which is precisely when the memory should go.
		ns.db.state[rule.cvar] = nil

		-- Deliberately NOT gated on `refused`, which is what this used to do.
		--
		-- The AddOn may have written this variable successfully and hit a
		-- refusal later -- and returning here meant it had made a change it
		-- had then made itself unable to undo. A write that failed going in
		-- may well succeed coming out, and a failed restore costs nothing
		-- beyond what has already happened. There is no argument for refusing
		-- to try.
		--
		-- `writeCVar` is not used below for the same reason: it opens with the
		-- same early return.

		-- Only when it actually moves. ApplyAll re-applies every module on
		-- every change, so an unconditional restore here writes a value the
		-- variable already holds -- harmless in itself, but it used to drag
		-- refreshQuestUI along with it and cycle the world map every time any
		-- unrelated option was touched.
		-- `offValue` where a rule declares one, the remembered value
		-- otherwise. See the Outline rule for why exactly one rule does.
		--
		-- Note what is NOT done here: forcing `wanted` on the way IN. Enable
		-- still leaves a value that already counts as on exactly where the
		-- player put it, so someone who chose Outline 3 keeps 3 while the
		-- option is on. Forcing 2 there would mean re-writing a Blizzard
		-- control's value on every re-assert, which is fighting the player's
		-- UI -- safety rule 4, and not worth winning.
		--
		-- The cost is that 3 is not recoverable after an off/on cycle: off
		-- writes 0, and on then asks for `wanted`. Accepted deliberately.
		local target = rule.offValue or original
		if readCVar(rule.cvar) == target then return end

		applying = true
		pcall(SetCVar, rule.cvar, target)
		applying = false
		refreshQuestUI(rule)
	end

	function M:Status()
		local v = readCVar(rule.cvar)
		if v == nil then return rule.cvar .. " missing" end
		if refused[rule.cvar] then
			return rule.cvar .. " = " .. tostring(v) .. " (write refused)"
		end
		return rule.cvar .. " = " .. tostring(v)
	end

	return M
end

for i = 1, #RULES do
	makeModule(RULES[i])
end

-- Something changed a console variable. The first argument of CVAR_UPDATE has
-- not been consistent across client versions, so rather than match on it, just
-- re-check every value we own on any CVar change.
--
-- What happens next depends on whether Blizzard shows a control for it:
--
--   No Blizzard control -- questPOI, showBosses. Nothing in the interface
--   claims to own these, so the AddOn re-asserts. Something moved it behind
--   the player's back and putting it back is the whole job.
--
--   Blizzard HAS a control -- Instant Quest Text, Automatic Quest Tracking,
--   Outline Mode. Then the AddOn's option simply MIRRORS the variable, in both
--   directions. Safety rule 4: do not fight the player's UI.
--
-- v0.14.0 got the second case half right and it showed. It only handled "our
-- option is on and the variable moved away", so:
--
--   * Outline never responded at all -- that option ships OFF, so the branch
--     was unreachable.
--   * Automatic Quest Tracking yielded once and then went dead, because after
--     yielding the option was off and the branch was unreachable again.
--   * Turning a Blizzard control back to what this AddOn wants never turned
--     the matching option back on.
--
-- One direction is not a sync. Mirroring both ways is.
ns:RegisterEvent("CVAR_UPDATE", function()
	if applying or not ns.db then return end

	-- Nothing before the first ApplyAll. The client raises this event for its
	-- own saved variables as it loads them, and those are the game reporting
	-- what the player already had rather than the player changing anything.
	-- `applying` cannot tell the difference: it only covers this AddOn's own
	-- writes, synchronously.
	if not ns.applied then return end

	for i = 1, #RULES do
		local rule = RULES[i]
		if not refused[rule.cvar] then
			local now = readCVar(rule.cvar)
			local on = ns.db.settings[rule.key] and true or false

			if now == nil then
				-- nothing to compare against

			elseif rule.blizzOption then
				-- The player owns this one. Follow it, whichever way it went.
				local shouldBeOn = ruleIsOn(rule, now)
				if shouldBeOn ~= on then
					ns.db.settings[rule.key] = shouldBeOn

					if shouldBeOn then
						-- Adopted rather than applied: the player moved the
						-- variable themselves, so this AddOn wrote nothing.
						--
						-- It still has to mark the variable as ours, or
						-- switching the option off afterwards finds no
						-- ownership and does nothing at all -- an option that
						-- reads off with its effect still running. The mirror
						-- writes `settings` directly rather than through
						-- ApplyAll, so Enable never runs to mark it.
						--
						-- The comment here used to say there was nothing to
						-- remember "that has not been remembered already".
						-- That was true while Disable kept the marker; it
						-- stopped being true when Disable started clearing it
						-- as it hands the variable back.
						if ns.db.state[rule.cvar] == nil then
							ns.db.state[rule.cvar] = now
						end
						ns:Print(C.highlight .. rule.blizzOption .. C.close ..
							" was changed in Blizzard's options, so " .. C.highlight ..
							rule.key .. C.close .. " is now " .. C.on .. "on" .. C.close .. ".")
					else
						-- What the player has now IS what to restore later.
						ns.db.state[rule.cvar] = now
						ns:Print(C.highlight .. rule.blizzOption .. C.close ..
							" was changed in Blizzard's options, so " .. C.highlight ..
							rule.key .. C.close .. " is now " .. C.off .. "off" .. C.close .. ".")
					end

					if ns.RefreshOptions then ns.RefreshOptions() end
				end

			elseif on and not ruleIsOn(rule, now) then
				writeCVar(rule, rule.wanted)
			end
		end
	end
end)

-- One retry per session for a variable that would not take a write.
--
-- `refused` latches so a rule that is genuinely being ignored stops writing on
-- every event forever. It used to latch for the whole session, which turned a
-- single transient failure into an option that stayed dead until the player
-- reloaded -- and, until the fix in `Disable`, into a change the AddOn could
-- no longer undo.
--
-- A loading screen is the right moment to forget: it is rare, it is already a
-- natural boundary, and the verification in `writeCVar` means a real refusal
-- latches straight back on the next write. Nothing else is cleared -- the
-- ownership markers in `ns.db.state` are saved variables and survive on
-- purpose.
ns:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	for k in pairs(refused) do refused[k] = nil end
end)
