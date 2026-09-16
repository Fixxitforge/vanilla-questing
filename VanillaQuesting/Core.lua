-- Vanilla Questing -- Core
--
-- AddOn table, saved variables, event dispatch, slash command.
-- Modules register themselves here and are driven from the saved settings.

local ADDON_NAME, ns = ...

-- What the player sees, everywhere. The folder and the CurseForge listing
-- keep the (MoP) suffix so the right build can be identified for download;
-- inside the game it is just the AddOn's name.
ns.title = "Vanilla Questing"

---------------------------------------------------------------------
-- Identity
---------------------------------------------------------------------

-- The .toc is the single source of truth for the version. Never hardcode
-- one here: the recon probe shipped a build announcing 0.4 in chat while
-- its .toc still said 0.3, because the number lived in two places.
local function addonVersion()
	local getter = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	if type(getter) ~= "function" then return "?" end
	local ok, v = pcall(getter, ADDON_NAME, "Version")
	return (ok and v) or "?"
end

ns.version = addonVersion()

---------------------------------------------------------------------
-- Output
---------------------------------------------------------------------

-- One palette, one definition.
--
-- The yellows and whites are the GAME's own colour codes where the client
-- offers them, not values typed in here: NORMAL_FONT_COLOR_CODE is what
-- Blizzard's own tooltips and option labels use, so taking it from the client
-- means this AddOn cannot drift away from the interface it is trying to sit
-- inside. The literals are fallbacks for a client that does not define them,
-- and they are the same values those globals hold.
ns.color = {
	-- Blizzard's own
	body        = NORMAL_FONT_COLOR_CODE    or "|cffffd100",  -- the standard yellow
	highlight   = NORMAL_FONT_COLOR_CODE    or "|cffffd100",
	title       = HIGHLIGHT_FONT_COLOR_CODE or "|cffffffff",
	muted       = GRAY_FONT_COLOR_CODE      or "|cff808080",
	close       = FONT_COLOR_CODE_CLOSE     or "|r",

	-- This AddOn's own.
	--
	-- `brand` is the chat blue, and it carries the informational things: the
	-- chat prefix, the tracking-button note, and **known limitations**.
	--
	-- `experimental` is the orange, and it carries the ones that are a
	-- caution: the Experimental heading and its description, the option names
	-- under it, and the "untested and potentially unstable" note.
	--
	-- Limitations used to be orange too, and the two were competing. A known
	-- limitation is not a warning -- it is a fact about what the option does,
	-- stated where the player decides -- and painting it the same colour as
	-- "this might break your game" overstates it and dilutes the real warning
	-- at the same time. One orange, one blue, and each means one thing.
	brand        = "|cff66ccff",
	experimental = "|cffff8019",
	-- A named alias rather than reusing `brand` at the call sites, so the two
	-- can be pulled apart later without hunting for which blue meant what.
	limitation   = "|cff66ccff",
	warning      = "|cffff9955",
	-- The game's own system-notice yellow, for a command the AddOn refuses
	-- outright. Under trial: "Command blocked:" takes it, "Unknown option"
	-- and "Unknown command" keep the salmon above, and the two are compared
	-- in game before either becomes the rule.
	--
	-- `YELLOW_FONT_COLOR_CODE` is a real global on this build -- Blizzard's
	-- own `Blizzard_Communities/GuildRewards.lua:33` uses it, checked against
	-- the 5.5.4.69585 source drop rather than remembered. What is NOT verified
	-- is the value behind it: the colour globals are defined engine-side and
	-- appear nowhere in the Lua, so the literal below is a guess that only
	-- matters on a client where the global is missing, which this one is not.
	blocked      = YELLOW_FONT_COLOR_CODE   or "|cffffff00",
	on           = "|cff55ff55",
	off          = "|cffff5555",
}

local C = ns.color

local PREFIX = C.brand .. "[" .. ns.title .. "]" .. C.close .. " "

-- In combat, and existence-checked like everything else the client owns.
--
-- One helper rather than a local per file: `CVars.lua` has had its own since
-- the map cycle needed one, and a second copy of the same three lines is how
-- two answers to "are we in combat" come to disagree.
function ns:InCombat()
	if type(InCombatLockdown) ~= "function" then return false end
	local ok, yes = pcall(InCombatLockdown)
	return ok and yes and true or false
end

-- What the player is told when something is refused because of combat (#24).
--
-- Every wording lives here so the slash commands and both options panels
-- cannot come to word it differently -- the same reason `statusLine` renders
-- the whole list and a single option.
--
-- **The whole line is one colour.** It is an error, not a sentence with an
-- error in it, and half a line in warning orange beside half a line in the
-- ordinary yellow reads as a note rather than a refusal.
--
-- Refused, not deferred and not half-applied. Only one option needs the UI
-- rebuilt -- Hide World Map Quest Helper -- and the rebuild is what makes the
-- change visible, so applying it in a fight would write the console variable
-- and show the player nothing. Worse, writing `questPOI` is what makes the
-- CLIENT try to open the world map, which it may not do in combat: that is
-- the "Interface action failed because of an AddOn" in #11, thrown by
-- Blizzard's own handler on our behalf.
--
-- This covers the SLASH commands and opening the panel. The options panel
-- itself is deliberately not refused -- see `promptReload` in Options.lua.
function ns:RefuseInCombat(what)
	local msg
	if what == "panel" then
		-- "/vq cannot open", not "the panel cannot be opened". Blizzard's own
		-- Esc menu opens it in combat perfectly well -- it is a secure path
		-- and this one is not. The first wording said the panel could not be
		-- opened, which is a smaller sentence and a false one, and a player
		-- who then opens it from the game menu has been told a lie by an
		-- AddOn that was trying to be helpful.
		msg = "/vq cannot open the options panel during combat. " ..
			"Use the game menu instead."
	elseif what then
		-- No reason given. The reason offered first was "it requires a UI
		-- reload", which is not true: what it requires is the world map
		-- cycling, and the reload is how the panel gets there. A player does
		-- not need either fact, and a wrong one is worse than none.
		msg = tostring(what) .. " cannot be changed during combat."
	else
		msg = "some settings cannot be changed during combat."
	end
	ns:Print(C.blocked .. "Command blocked: " .. msg .. C.close)
end

-- True if this option cannot take effect without the UI being rebuilt, and so
-- cannot be changed in combat.
function ns:BlockedByCombat(key)
	local m = key and ns.modules and ns.modules[key]
	return (m and m.needsApply and ns:InCombat()) and true or false
end

function ns:Print(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
	end
end

-- Safety rule 5: when something expected is missing, say so once and skip
-- the feature. Keyed so a per-frame or per-event failure cannot spam chat.
local warned = {}
function ns:Warn(key, msg)
	if warned[key] then return end
	warned[key] = true
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. C.warning .. tostring(msg) .. C.close)
	end
end

---------------------------------------------------------------------
-- Event dispatch
---------------------------------------------------------------------

local dispatcher = CreateFrame("Frame")
local handlers = {}

function ns:RegisterEvent(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		dispatcher:RegisterEvent(event)
	end
	local list = handlers[event]
	list[#list + 1] = fn
end

dispatcher:SetScript("OnEvent", function(_, event, ...)
	local list = handlers[event]
	if not list then return end
	for i = 1, #list do
		-- One module throwing must not stop the others, and must not take
		-- the user's UI with it.
		local ok, err = pcall(list[i], event, ...)
		if not ok then
			ns:Warn("evt:" .. event .. ":" .. i,
				"error handling " .. event .. ": " .. tostring(err))
		end
	end
end)

---------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------

-- A module is a table with Enable(), Disable(), and a `setting` key naming
-- the saved variable that drives it.
--
-- Optional Status() returns one diagnostic line -- which tracking index was
-- found, what the CVar reads, whether a write was refused. **It has no caller
-- today.** The canvas panel drew it on every row until #7, and `/vq status`
-- deliberately never has: it reports what the option is doing, and a live CVar
-- readout is for developer eyes. The methods are kept for #15, the report path
-- that wants exactly this and has nowhere to get it from otherwise.
ns.modules = {}

-- One ordering, used by the options panel and by /vq status alike, so the two
-- cannot drift apart.
function ns:SortedModules()
	local list = {}
	for i = 1, #ns.modules do list[#list + 1] = ns.modules[i] end
	table.sort(list, function(a, b) return (a.order or 999) < (b.order or 999) end)
	return list
end

function ns:RegisterModule(key, module)
	module.key = key
	ns.modules[#ns.modules + 1] = module
	ns.modules[key] = module
	return module
end

---------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------

-- Account-wide (see the .toc): someone who wants this wants it everywhere.
local DB_VERSION = 4

-- v1 gave every feature two names: a display key ("hideBossPortraits") and
-- a saved-setting name mirroring the CVar ("showBosses"). That was a mistake.
-- It made the name /vq printed different from the name /vq accepted, and it
-- made "showBosses turned on" mean the portraits were hidden. v2 uses one
-- name per feature, describing what the AddOn does rather than what Blizzard
-- calls the underlying switch.
local RENAMED_IN_V2 = {
	worldMapQuestPOI = "hideMapQuestHelper",
	minimapQuestPOI  = "hideMinimapQuestHelper",
	autoQuestWatch   = "noAutoQuestTracking",
	showBosses       = "hideBossPortraits",
}

-- Modules add their own defaults at file scope, before ADDON_LOADED fires.
ns.defaults = {}

function ns:RegisterDefaults(tbl)
	for k, v in pairs(tbl) do
		ns.defaults[k] = v
	end
end

local function initDB()
	-- A clean install: no saved variables at all, so nothing here is a change
	-- the player made. Read before the table is created, because creating it
	-- is what destroys the evidence.
	--
	-- Session-only. It is deliberately not saved: "have we run before" is
	-- answered by the saved variables existing, and a second flag saying the
	-- same thing is a second thing that can disagree.
	ns.firstRun = (VanillaQuestingDB == nil)

	VanillaQuestingDB = VanillaQuestingDB or {}
	local db = VanillaQuestingDB

	db.settings = db.settings or {}
	-- Pre-AddOn values live here so Disable() can put the game back exactly
	-- as it found it. Subtractive AddOns should leave no trace when off.
	db.state = db.state or {}

	if db.dbVersion == nil then
		db.dbVersion = DB_VERSION
	elseif db.dbVersion < DB_VERSION then
		if db.dbVersion < 2 then
			for old, new in pairs(RENAMED_IN_V2) do
				if db.settings[old] ~= nil and db.settings[new] == nil then
					db.settings[new] = db.settings[old]
				end
				db.settings[old] = nil
			end
			-- The remembered pre-AddOn tracking state moves with the rename;
			-- losing it would leave Disable unable to restore what the player
			-- actually had.
			if db.state.minimapQuestPOITracking ~= nil and db.state.minimapMarkersTracking == nil then
				db.state.minimapMarkersTracking = db.state.minimapQuestPOITracking
			end
			db.state.minimapQuestPOITracking = nil
		end
		if db.dbVersion < 3 then
			-- The preset was stored as well as derived, and the stored copy
			-- went unread from v0.11.0 onwards -- the panel has computed it
			-- from the options ever since. Clear the orphan rather than leave
			-- a key in everyone's saved variables that nothing consults.
			db.preset = nil
		end
		if db.dbVersion < 4 then
			-- `outlineMode` became `noOutlineMode`, and the polarity flipped
			-- with it: the old option was ON when outlines were showing, the
			-- new one is ON when they are removed.
			--
			-- The old value is NOT carried across, in either direction. It was
			-- a MIRROR -- a reading of what Blizzard's Outline Mode happened
			-- to be, not a choice the player expressed -- so inverting it into
			-- a preference would be inventing an opinion on their behalf. The
			-- new option takes its default like any other new option.
			--
			-- The ownership marker goes too. It recorded that the AddOn was
			-- holding `Outline` for the old polarity; the first Enable of the
			-- new rule records it again for this one.
			db.settings.outlineMode = nil
			db.state.Outline = nil
		end
		db.dbVersion = DB_VERSION
	end

	for k, v in pairs(ns.defaults) do
		if db.settings[k] == nil then
			db.settings[k] = v
		end
	end

	ns.db = db
end

---------------------------------------------------------------------
-- Applying settings
---------------------------------------------------------------------

-- One module, applied. The single place Enable/Disable are called from, so
-- the whole-list pass and the one-option pass cannot come to disagree about
-- what applying means.
--
-- Reads `ns.db.settings`, not `ns:IsActive`. A sub-option under a parent that
-- is off still gets Enable called on it; whether that does anything is the
-- module's own business (Tracker checks its parent), and changing it here
-- would change behaviour rather than cost.
local function applyModule(m)
	local on = ns.db.settings[m.key]
	local fn = on and m.Enable or m.Disable
	if type(fn) ~= "function" then return end
	local ok, err = pcall(fn, m)
	if not ok then
		ns:Warn("apply:" .. tostring(m.key),
			"could not " .. (on and "enable" or "disable") .. " " ..
			tostring(m.key) .. ": " .. tostring(err))
	end
end

-- Changing one option applies one option.
--
-- `ns:Set` called `ns:ApplyAll`, which walks all thirteen modules and
-- re-applies every one of them to move a single checkbox. That was cheap when
-- the modules were cheap. They are not any more: the minimap module rescans a
-- seventeen-entry tracking list, the tracker modules walk every line and
-- button in the frame, and each CVar rule that has something to restore writes
-- and then refreshes the quest UI behind it.
--
-- Reported from play as the options panel lagging on every click, with the
-- shared and mirrored options lagging longest -- and the diagnosis was in the
-- report itself: *"lag not present when the Blizzard option is set"*. Changing
-- Blizzard's control goes through the mirror, which writes one setting and
-- refreshes. Changing ours went through all thirteen.
--
-- A bulk command still applies everything, because everything moved.
function ns:Apply(key)
	if not ns.db then return end

	-- Always by request: the only callers are `ns:Set` -- which is the slash
	-- commands and the canvas panel -- and the native panel's own
	-- value-changed callback. Every one of those is a person having just
	-- clicked or typed something. See `ns.byRequest` below.
	local was = ns.byRequest
	ns.byRequest = true

	-- Before the first full pass there is nothing to be targeted about, and
	-- ApplyAll is what raises `ns.applied` and lowers `ns.firstRun`. Skipping
	-- it here would leave the mirror disarmed for the session.
	if not ns.applied then
		ns:ApplyAll(true)
		ns.byRequest = was
		return
	end

	-- A parent's switch moves its children with it (#45).
	--
	-- It used to move only the EFFECT: the child kept its saved value while
	-- the parent was off and got it back untouched, which is what Blizzard's
	-- greyed sub-options do. Reported from play as the wrong call, and it is:
	-- the child ships on, almost nobody turns it off deliberately, and a
	-- player switching the whole feature back on expects all of it -- while
	-- the one who did turn it off has a tick to put back, in front of them,
	-- which costs one click.
	--
	-- Both directions. Off with the parent as well as on, so the box says
	-- what is happening rather than holding a value that is doing nothing.
	local cascade = ns.db.settings[key]

	for i = 1, #ns.modules do
		local m = ns.modules[i]
		if m.key == key then
			applyModule(m)
		else
			-- A sub-option has to follow its parent. Walked rather than
			-- checked one level deep: nothing is nested two deep today, and a
			-- rule that only works at depth one is a trap for whoever nests
			-- something tomorrow.
			local p, depth = m.parent, 0
			while p and depth < 10 do
				if p == key then
					ns.db.settings[m.key] = cascade and true or false
					applyModule(m)
					break
				end
				local pm = ns.modules[p]
				p = pm and pm.parent or nil
				depth = depth + 1
			end
		end
	end

	ns.byRequest = was
end

-- `byRequest` -- did a person just ask for this?
--
-- It decides one thing: whether an option that needs the world map cycled to
-- show its effect gets that cycle. Opening and closing the map is visible,
-- and it goes through `HideUIPanel` / `ShowUIPanel`, which TAINTS Blizzard's
-- UI panel manager -- a taint that surfaces later as an unrelated blocked
-- action with nothing pointing back here (#17).
--
-- Worth doing when the player has just ticked a box and is waiting to see the
-- result. Not worth doing on a loading screen, which is where it was also
-- happening:
--
--   PLAYER_ENTERING_WORLD -> ApplyAll -> Enable -> writeCVar
--                         -> refreshQuestUI -> cycleWorldMap
--
-- Any zone change where `questPOI` had drifted took that path, out of combat,
-- with no guard in the way. The map opened and closed on a loading screen for
-- no reason the player asked for, and the panel manager was tainted from that
-- point on. **A loading screen is not someone asking for a refresh.**
--
-- Passed explicitly at every call site rather than inferred. A reader seeing
-- `ns:ApplyAll(true)` can check the claim; a reader seeing a flag set three
-- functions away cannot.
function ns:ApplyAll(byRequest)
	local wasByRequest = ns.byRequest
	ns.byRequest = byRequest and true or false
	if not ns.db then return end

	-- Once per session, before touching anything: read the client for the
	-- options that only mirror it.
	--
	-- On a clean install this is what stops the AddOn announcing a mismatch it
	-- did not cause. On every later login it is what keeps a mirror honest --
	-- a saved value applied at login would be the AddOn telling Blizzard what
	-- its own setting is, which is backwards for an option whose entire job is
	-- to report that setting.
	--
	-- The AddOn writes its own CVars during this first pass, and every write
	-- raises CVAR_UPDATE. The two-way mirror then walks EVERY rule, including
	-- ones never touched, and compares the player's long-standing value
	-- against a setting a few milliseconds old. For an option that ships off
	-- beside a Blizzard control that ships on, that comparison always
	-- mismatches, and the mirror announced it as though the player had just
	-- done it -- on their first ever login, having changed nothing.
	--
	-- Silencing the message was the obvious fix and the wrong one: the mirror
	-- would still believe a change had happened, and the option would still
	-- read the opposite of the control it shadows. Adopting removes the
	-- mismatch instead, so there is nothing to report and nothing to be wrong
	-- about. `applying` cannot help here either -- it is down by the time an
	-- event arrives a frame later.
	if not ns.applied then
		for i = 1, #ns.modules do
			local m = ns.modules[i]
			if type(m.SyncFromClient) == "function" then pcall(m.SyncFromClient, m) end
		end
	end

	for i = 1, #ns.modules do
		applyModule(ns.modules[i])
	end

	-- Down once the first pass is over. Everything after this really is the
	-- player doing something, and deserves to be reported as such.
	ns.firstRun = false

	-- And the two-way mirror is armed only from here.
	--
	-- The client raises CVAR_UPDATE for its own saved variables as it loads
	-- them. Those events are the game telling us what the player already had,
	-- not the player reaching into Blizzard's options -- but they are
	-- indistinguishable from the outside, and the mirror believed them. On a
	-- login with Instant Quest Text on, the arrival of that saved value was
	-- read as the player having just switched it on, so the AddOn stood down
	-- from an option it had not yet applied and said so in chat.
	--
	-- This is the other half of not applying at ADDON_LOADED. Applying early
	-- read defaults; applying late left the mirror awake through the storm.
	-- It has to be both: apply once the values are real, and ignore everything
	-- until that has happened.
	ns.applied = true

	ns.byRequest = wasByRequest
end

-- Toggling takes effect immediately; no /reload.
-- What an option is actually DOING, as opposed to what it is set to.
--
-- A sub-option whose parent is off changes nothing, so reporting it as "on"
-- claims something the player can watch not happening. The saved value is
-- left alone -- the panel greys the child rather than unticking it, which is
-- Blizzard's own behaviour and keeps the choice for when the parent comes
-- back -- so "set to" and "in effect" are genuinely two different things and
-- every player-facing readout wants the second one.
--
-- Walks the chain rather than checking one level: nothing is nested two deep
-- today, and a rule that only works at depth one is a trap for whoever nests
-- something tomorrow.
function ns:IsActive(key)
	if not ns.db or not ns.db.settings[key] then return false end
	local m = ns.modules and ns.modules[key]
	if m and m.parent then return ns:IsActive(m.parent) end
	return true
end

function ns:Set(key, value)
	if not ns.db then return end
	ns.db.settings[key] = value
	ns:Apply(key)
end

-- No reload notice here. Tested in game: after a slash toggle the next time
-- the world map opens it is already correct, so telling the player to /reload
-- would be advice for a problem they do not have.

-- silent: the options panel resets in place and the player can see the result,
-- so it does not need a chat line.
function ns:ResetDefaults(silent)
	if not ns.db then return end
	wipe(ns.db.settings)
	for k, v in pairs(ns.defaults) do
		ns.db.settings[k] = v
	end

	-- A mirror has no default to restore to. Its value is whatever the client
	-- says, so Defaults re-reads rather than writing one -- otherwise resetting
	-- this AddOn would reach out and change a Blizzard graphics setting.
	for i = 1, #ns.modules do
		local m = ns.modules[i]
		if m.mirrorOnly and type(m.SyncFromClient) == "function" then
			pcall(m.SyncFromClient, m)
		end
	end

	-- By request: /vq reset, or Blizzard's Defaults button.
	ns:ApplyAll(true)
	if not silent then
		ns:Print("Restored default options.")
	end
end

---------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------

-- Have the player's own CVar values arrived yet?
--
-- They have not at ADDON_LOADED. The client loads its saved console variables
-- later, and until it does GetCVar answers with the DEFAULT rather than with
-- what the player has. Blizzard's own code asks this same question through
-- EventUtil.AreVariablesLoaded, which reads the same flag.
local function variablesLoaded()
	return type(UIParent) == "table" and UIParent.variablesLoaded and true or false
end

-- ADDON_LOADED sets the database up and stops there.
--
-- Applying here reads CVars that are not the player's yet, and this AddOn
-- does two things with that reading it cannot afford to get wrong: it records
-- the pre-AddOn value so the option can be handed back, and on a clean
-- install it adopts an option from the control it shadows. Both were being
-- decided against a default.
--
-- The symptom that found it: a clean install with Outline switched off got
-- "Outline Mode was changed in Blizzard's options" in chat, and only that
-- value did it. Adoption read the default 2, set the option on, and the real
-- 0 arriving moments later looked exactly like the player reaching into
-- Blizzard's options -- which is what the mirror is for. Outline 1, 2 and 3
-- were all silent because they agree with the default about being "on".
--
-- The recording bug is the quieter one and the worse one: remembering
-- Blizzard's default as "what the player had" means handing back the wrong
-- value forever, for every CVar option, on every client where the two differ.
ns:RegisterEvent("ADDON_LOADED", function(_, loaded)
	if loaded ~= ADDON_NAME then return end
	initDB()
	-- Unless they are already here, which is the case if this AddOn is ever
	-- loaded on demand rather than at startup.
	if variablesLoaded() then ns:ApplyAll() end
end)

ns:RegisterEvent("VARIABLES_LOADED", function()
	if not ns.db then initDB() end
	ns:ApplyAll()
end)

-- Re-assert on every world entry: login, /reload, zone change and loading
-- screens are all places a setting can quietly drift back.
ns:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	if not ns.db then initDB() end
	ns:ApplyAll()
end)

---------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------

-- One option, as the status list prints it. `indent` is what makes a
-- sub-option sit under its parent in the full list; asked for by name it is
-- the only line on screen, so there is nothing to sit under.
local function statusLine(m, indent)
	-- What it is doing, not what it is set to. A sub-option under a parent
	-- that is off is doing nothing, and saying "on" next to a tracker that
	-- is plainly still clickable is the readout arguing with the game.
	local on = ns:IsActive(m.key)
	-- The live CVar readout is for developer eyes; the player wants to
	-- know what is on.
	-- Every option name in the same yellow, experimental or not. The
	-- "(experimental)" note after it carries the mark on its own, and the
	-- panel cannot colour its names at all (see [G23b]) -- so colouring
	-- them here made the two disagree about what an option looks like.
	ns:Print("  " .. (on and (C.on .. "on " .. C.close) or (C.off .. "off " .. C.close)) ..
		"  " .. (indent and m.parent and "   " or "") ..
		C.highlight .. tostring(m.key) .. C.close ..
		(m.experimental and (" " .. C.experimental .. "(experimental)" .. C.close) or ""))
end

-- No argument lists everything; a key prints that one option. Same line, same
-- wording, same colours either way -- two readouts that could disagree about
-- what "on" means would be worse than no single-option lookup at all.
local function status(only)
	if only then
		ns:Print(ns.title .. " v" .. tostring(ns.version) .. " - Status of one option")
		statusLine(ns.modules[only])
		return
	end
	ns:Print(ns.title .. " v" .. tostring(ns.version) .. " - Status and list of options")
	local ordered = ns:SortedModules()
	for i = 1, #ordered do
		-- A sub-option is indented, so the list reads the way the panel looks.
		statusLine(ordered[i], true)
	end
end

SLASH_VANILLAQUESTING1 = "/vq"
SLASH_VANILLAQUESTING2 = "/vanillaquesting"

-- Accept whatever /vq actually printed. Modules have a display key
-- ("hideBossPortraits") and a saved-setting name ("showBosses"), and the
-- status list shows the key -- so the key must be a valid handle for
-- /vq on|off. Taking only the setting name made every name on screen an
-- "Unknown setting". Both work now, case-insensitively.
local function resolveSetting(arg)
	if not arg or arg == "" or not ns.db then return nil end
	if ns.db.settings[arg] ~= nil then return arg end

	local lower = arg:lower()
	for k in pairs(ns.db.settings) do
		if k:lower() == lower then return k end
	end
	-- Old v1 names still work, so muscle memory and older notes keep working.
	for old, new in pairs(RENAMED_IN_V2) do
		if old:lower() == lower then return new end
	end
	return nil
end

SlashCmdList["VANILLAQUESTING"] = function(msg)
	msg = msg or ""
	local cmd = msg:match("^%s*(%S*)") or ""
	cmd = cmd:lower()
	local arg = msg:match("^%s*%S*%s+(%S+)") or ""

	-- Bulk commands are refused outright in combat (#24).
	--
	-- `/vq on`, `/vq off` and `/vq reset` all move Hide World Map Quest
	-- Helper, which cannot take effect without the UI being rebuilt -- and
	-- writing its variable is what makes the client try to open the world map,
	-- which it may not do mid-fight. Unconditionally, rather than only when
	-- that option would actually move: a command that sometimes works in
	-- combat and sometimes does not is worse to explain than one that never
	-- does, and this is a rule the player has to hold in their head while
	-- something is hitting them.
	if ns:InCombat() and (cmd == "reset"
		or ((cmd == "on" or cmd == "off") and arg == "")) then
		ns:RefuseInCombat(nil)
		return
	end

	if cmd == "reset" then
		ns:ResetDefaults()

	elseif cmd == "on" or cmd == "off" then
		local want = (cmd == "on")
		if arg == "" then
			-- "/vq on" means Vanilla (Default), not the experiments.
			-- Experimental features are only ever turned on by name.
			--
			-- Left exactly as the player set them, in both directions of the
			-- earlier confusion. v0.14.3 made "/vq on" turn them off, to
			-- match the panel's preset; the panel was the one that was wrong.
			-- A preset that undoes a deliberate choice is worse than a preset
			-- that ignores it.
			--
			-- "/vq off" still takes them, because Disabled means nothing is on.
			for k in pairs(ns.defaults) do
				local m = ns.modules[k]
				-- A mirror is never bulk-set, in either direction. It reports
				-- a Blizzard setting rather than removing anything, so "turn
				-- everything on" and "turn everything off" both have nothing
				-- to say about it -- and `/vq off` is the command people type
				-- on their way to uninstalling, which is the worst possible
				-- moment to change someone's graphics options.
				if m and m.mirrorOnly then
					-- leave it alone
				elseif want and m and m.experimental then
					-- leave it alone
				else
					ns.db.settings[k] = want
				end
			end
			-- By request: the player typed /vq on or /vq off.
			ns:ApplyAll(true)
			ns:Print(want and "Enabled all vanilla options."
				or "Disabled all options.")
		else
			local key = resolveSetting(arg)
			if key and ns:BlockedByCombat(key) then
				-- One option by name, and it is the one that needs a reload.
				-- Everything else is allowed in combat, because it takes
				-- effect the moment it is written.
				ns:RefuseInCombat(key)
			elseif key then
				ns:Set(key, want)
				local m = ns.modules[key]
				-- "showBosses turned on" read as though the portraits were
				-- being shown. Say what actually happened instead.
				-- Report what the AddOn is now doing. Setting a sub-option
				-- while its parent is off changes the saved value and nothing
				-- else, so "off" is the honest answer -- and it is the whole
				-- answer. A second line explaining which parent it waits on
				-- was tried and read as a lecture: the panel already shows the
				-- child greyed under the parent it belongs to.
				local live = ns:IsActive(key)
				local effect = m and (live and m.onText or m.offText)
				ns:Print(C.highlight .. key .. C.close .. " " ..
					(live and (C.on .. "on" .. C.close) or (C.off .. "off" .. C.close)) ..
					"." .. (effect and (" " .. effect) or ""))
			else
				ns:Print(C.warning .. "Unknown option '" .. arg .. "'." .. C.close ..
					" Try " .. C.highlight .. "/vq help" .. C.close .. " for list of commands.")
			end
		end

	elseif cmd == "help" then
		ns:Print(ns.title .. " v" .. tostring(ns.version) .. " - List of commands")
		-- The game font is not monospaced, so padding to a column would still
		-- come out ragged. A fixed separator makes every gap identical instead.
		-- `command`, not `cmd`: the enclosing handler already has a `cmd`
		-- holding what the player typed, and one name for two things inside
		-- forty lines is how the next reader gets it wrong.
		local function line(command, what)
			ns:Print("  " .. C.highlight .. command .. C.close .. "  -  " .. what)
		end
		line("/vq", "Open the options panel")
		line("/vq on [option]", "Enable all vanilla options, or one [option]")
		line("/vq off [option]", "Disable all options, or one [option]")
		line("/vq status [option]", "List status of all options, or one [option]")
		line("/vq reset", "Restore default options")

	elseif cmd == "status" then
		if arg == "" then
			status()
		else
			local key = resolveSetting(arg)
			-- resolveSetting answers from the saved settings, which is the
			-- right handle for /vq on|off. Printing a status line needs the
			-- module behind it, so a key with no module is still unknown here.
			if key and ns.modules[key] then
				status(key)
			else
				ns:Print(C.warning .. "Unknown option \'" .. arg .. "\'." .. C.close ..
					" Try " .. C.highlight .. "/vq help" .. C.close .. " for list of commands.")
			end
		end

	elseif cmd == "" then
		-- Only a bare /vq opens the panel. An unrecognised word is a mistake,
		-- and silently opening the panel would hide that.
		if type(ns.OpenOptions) == "function" then
			ns:OpenOptions()
		else
			status()
			ns:Print(C.warning .. "Options panel unavailable." .. C.close .. " Use " ..
				C.highlight .. "/vq on|off <option>" .. C.close .. ".")
		end

	else
		ns:Print(C.warning .. "Unknown command '" .. cmd .. "'." .. C.close ..
			" Try " .. C.highlight .. "/vq help" .. C.close .. " for list of commands.")
	end
end
