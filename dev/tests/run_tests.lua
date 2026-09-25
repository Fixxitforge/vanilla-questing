local scenario = ...
local h = assert(loadfile("addon_harness.lua"))
h(scenario)

local pass, fail = 0, 0

-- The description line under the Experimental heading. Held here as a literal
-- on purpose: change the wording in the AddOn and this goes red, which is the
-- reminder that the panel and the docs are part of the same change.
local EXPERIMENTAL_NOTE_TEXT = "These are not enabled by the Vanilla preset."
local function check(label, cond, detail)
	if cond then pass = pass + 1; print("  [ok]   " .. label)
	else fail = fail + 1; print("  [FAIL] " .. label .. (detail and ("  -> " .. tostring(detail)) or "")) end
end

print("=== scenario: " .. scenario .. " ===")

-- boot the addon the way the client does
local ok, err = pcall(fire, "ADDON_LOADED", "VanillaQuesting")
check("ADDON_LOADED without error", ok, err)
-- The client's saved CVars arrive after ADDON_LOADED, not before it.
ok, err = pcall(__loadVariables)
check("VARIABLES_LOADED without error", ok, err)
ok, err = pcall(fire, "PLAYER_ENTERING_WORLD")
check("PLAYER_ENTERING_WORLD without error", ok, err)
ok, err = pcall(fire, "PLAYER_LOGIN")
check("PLAYER_LOGIN without error", ok, err)

check("no runaway event recursion (depth " .. maxEventDepth() .. ")", maxEventDepth() < 10, maxEventDepth())

-- #36: the world map does not open by itself on a login that writes questPOI.
--
-- Nobody asked for anything here, so the cycle is skipped -- and until v1.1.0-7
-- that left the map standing open, because Blizzard's own CVAR_UPDATE handler
-- opens it and has no path that closes it again. `questPOI` is stored PER
-- CHARACTER, so this is the first login of every character after installing,
-- not only a clean install.
--
-- Asserted on the boot sequence itself rather than in a block of its own:
-- this scenario starts with questPOI at the client default of 1, so the login
-- pass writes it, which is exactly the case in question.
if scenario == "normal" or scenario == "no_settings" or scenario == "settings_refuses" then
	check("the client opened the map on our login write", _G.__blizzMapOpens > 0,
		_G.__blizzMapOpens)
	check("and the AddOn shut it again, so login ends with the map closed",
		not WorldMapFrame:IsShown())
end

-- #13: a clean install is not a change the player made.
--
-- The AddOn writes its own CVars on the first pass, every write raises
-- CVAR_UPDATE, and the two-way mirror then walks every rule -- including ones
-- never touched -- comparing a long-standing player value against a setting a
-- few milliseconds old. An option that ships OFF beside a control that ships
-- ON mismatches every time, and said so in chat on a first ever login.
if scenario == "normal" or scenario == "outline_off"
	or scenario == "outline_late_off" then
	-- No Outline Mode ships ON and enforces, whatever the client had. It was a
	-- MIRROR until ShowQuestObjectHighlightEffect gave this AddOn a reason to
	-- have an opinion about outlines -- and a mirror adopted the client value
	-- instead of applying a saved one, which is what these scenarios were
	-- built to check.
	--
	-- They still earn their place: `outline_off` starts with Outline already
	-- at 0, which is where the AddOn wants it, so nothing is written and there
	-- must still be nothing to say. That is the #13 shape -- a clean install
	-- is not a change the player made -- and it is independent of who owns the
	-- variable.
	check("the option ships on whatever the client had",
		VanillaQuestingDB.settings.noOutlineMode == true,
		tostring(VanillaQuestingDB.settings.noOutlineMode) ..
		" for Outline " .. tostring(cvars.Outline))
	check("and the variable ends up at 0 either way",
		cvars.Outline == "0", cvars.Outline)

	local noisy = {}
	for _, m in ipairs(chatlog) do
		local t = tostring(m)
		if t:find("was changed in Blizzard's options", 1, true)
			or t:find("was disabled automatically", 1, true) then
			noisy[#noisy + 1] = t
		end
	end
	check("the first application announces nothing", #noisy == 0,
		table.concat(noisy, " | "))

	check("and the flag is down once it is over", ns.firstRun == false,
		tostring(ns.firstRun))
end

if scenario == "vars_late_on" then
	-- The options that ship ON must still be applied, and nothing may be said.
	check("Instant Quest Text still enforced", cvars.instantQuestText == "0",
		cvars.instantQuestText)
	check("Automatic Quest Tracking still enforced", cvars.autoQuestWatch == "0",
		cvars.autoQuestWatch)
	check("noInstantQuestText stayed on", VanillaQuestingDB.settings.noInstantQuestText == true,
		tostring(VanillaQuestingDB.settings.noInstantQuestText))
	check("noAutoQuestTracking stayed on", VanillaQuestingDB.settings.noAutoQuestTracking == true,
		tostring(VanillaQuestingDB.settings.noAutoQuestTracking))
	check("noOutlineMode enforced from Outline 2",
		VanillaQuestingDB.settings.noOutlineMode == true and cvars.Outline == "0",
		tostring(VanillaQuestingDB.settings.noOutlineMode) .. "/" .. tostring(cvars.Outline))

	local noisy = {}
	for _, m in ipairs(chatlog) do
		local t = tostring(m)
		if t:find("was changed in Blizzard's options", 1, true)
			or t:find("was disabled automatically", 1, true) then
			noisy[#noisy + 1] = t
		end
	end
	check("and the login says nothing at all", #noisy == 0, table.concat(noisy, " | "))

	-- The mirror still has to work afterwards, or the fix is just a mute.
	cvars.instantQuestText = "1"
	pcall(fire, "CVAR_UPDATE", "instantQuestText", "1")
	check("the mirror still yields to a real player change",
		VanillaQuestingDB.settings.noInstantQuestText == false,
		tostring(VanillaQuestingDB.settings.noInstantQuestText))
	local said = false
	for _, m in ipairs(chatlog) do
		if tostring(m):find("was changed in Blizzard's options", 1, true) then said = true end
	end
	check("and says so", said)
end

if scenario == "normal" then
	check("questPOI driven to 0", cvars.questPOI == "0", cvars.questPOI)
	check("quest POI tracking turned off", tracking[4].active == false, tracking[4].active)
	check("original questPOI remembered", VanillaQuestingDB.state.questPOI == "1")
	check("original tracking state remembered", VanillaQuestingDB.state.minimapMarkersTracking == true)

	-- The player flips the tracking entry back on via Blizzard's dropdown.
	-- SHARED: the dropdown is their control, so the entry stays where they put
	-- it and the option follows. This used to re-assert.
	tracking[4].active = true
	ok, err = pcall(fire, "MINIMAP_UPDATE_TRACKING")
	check("the dropdown is left where the player put it",
		ok and tracking[4].active == true, err or tracking[4].active)
	check("and the option follows it off",
		ns.db.settings.hideMinimapQuestHelper == false,
		tostring(ns.db.settings.hideMinimapQuestHelper))
	-- Put it back, so the checks after this start from the option being on.
	tracking[4].active = false
	pcall(fire, "MINIMAP_UPDATE_TRACKING")
	check("and unticking it turns the option back on",
		ns.db.settings.hideMinimapQuestHelper == true,
		tostring(ns.db.settings.hideMinimapQuestHelper))

	-- something else changes a CVar
	cvars.questPOI = "1"
	ok, err = pcall(fire, "CVAR_UPDATE", "questPOI", "1")
	check("re-assert after CVAR_UPDATE", ok and cvars.questPOI == "0", err or cvars.questPOI)

	-- turning the features off restores what the player had
	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "off")
	check("/vq off runs", ok, err)
	check("questPOI restored to 1", cvars.questPOI == "1", cvars.questPOI)
	check("tracking restored to on", tracking[4].active == true, tracking[4].active)

	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "on")
	check("/vq on runs", ok, err)
	check("questPOI back to 0", cvars.questPOI == "0", cvars.questPOI)

	ok, err = pcall(ns.ResetDefaults, ns, true)
	check("a reset runs", ok, err)
	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "")
	check("/vq status runs", ok, err)
	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "off hideMinimapQuestHelper")
	check("/vq off <setting> runs", ok, err)
	check("only that setting changed", VanillaQuestingDB.settings.hideMinimapQuestHelper == false
		and VanillaQuestingDB.settings.hideMapQuestHelper == true)
	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "off bogusSetting")
	check("unknown setting handled", ok, err)

	-- opt-in CVars must NOT be applied by default
	ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls
	-- Shipped defaults are now the Full Classic experience, so these apply.
	check("autoQuestWatch applied by default", cvars.autoQuestWatch == "0", cvars.autoQuestWatch)
	check("showBosses applied by default", cvars.showBosses == "0", cvars.showBosses)
	-- The names /vq prints are module keys; they must be valid handles.
	pcall(SlashCmdList["VANILLAQUESTING"], "on hideBossPortraits")
	check("module key accepted as handle", cvars.showBosses == "0", cvars.showBosses)
	pcall(SlashCmdList["VANILLAQUESTING"], "off hideBossPortraits")
	check("module key toggles back off", cvars.showBosses == "1", cvars.showBosses)
	pcall(SlashCmdList["VANILLAQUESTING"], "on noAutoQuestTracking")
	check("noAutoQuestTracking key accepted", cvars.autoQuestWatch == "0", cvars.autoQuestWatch)
	pcall(SlashCmdList["VANILLAQUESTING"], "off noAutoQuestTracking")
	pcall(SlashCmdList["VANILLAQUESTING"], "off MAPCREATUREPORTRAITS")
	check("module key is case-insensitive", VanillaQuestingDB.settings.hideBossPortraits == false)
	pcall(SlashCmdList["VANILLAQUESTING"], "on hideBossPortraits")
	check("showBosses applied when opted in", cvars.showBosses == "0", cvars.showBosses)
	pcall(SlashCmdList["VANILLAQUESTING"], "on noAutoQuestTracking")
	check("autoQuestWatch applied when opted in", cvars.autoQuestWatch == "0", cvars.autoQuestWatch)
	pcall(SlashCmdList["VANILLAQUESTING"], "off hideBossPortraits")
	check("showBosses restored on opt-out", cvars.showBosses == "1", cvars.showBosses)

	-- tooltip: the hook must add lines only while the setting is on
	ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls
	for i = #tooltipLines, 1, -1 do tooltipLines[i] = nil end
	ok, err = pcall(hoverTrackingButton)
	check("tooltip hook runs", ok, err)
	local joined = table.concat(tooltipLines, " | ")
	check("tooltip explains the behaviour", joined:find("Track Quest POIs", 1, true) ~= nil, joined)
	check("tooltip has the addon name as a header", joined:find("Vanilla Questing", 1, true) ~= nil, joined)
	check("tooltip names the AddOn as the manager",
		joined:find("is managed by", 1, true) ~= nil and joined:find(ns.title, 1, true) ~= nil, joined)
	check("tooltip names the tracking entry it manages",
		joined:find("Track Quest POIs", 1, true) ~= nil, joined)

	-- v2 migration: a v1 database must carry its values across to the new names
	do
		local fresh = { dbVersion = 1, settings = {
			worldMapQuestPOI = false, minimapQuestPOI = true,
			autoQuestWatch = true, showBosses = true }, state = {} }
		VanillaQuestingDB = fresh
		ns.db = nil
		pcall(fire, "PLAYER_ENTERING_WORLD")
		local st = VanillaQuestingDB.settings
		check("v1->v2 migrated hideMapQuestHelper", st.hideMapQuestHelper == false, tostring(st.hideMapQuestHelper))
		check("v1->v2 migrated noAutoQuestTracking", st.noAutoQuestTracking == true, tostring(st.noAutoQuestTracking))
		check("v1->v2 migrated hideBossPortraits", st.hideBossPortraits == true, tostring(st.hideBossPortraits))
		check("v1 keys removed", st.showBosses == nil and st.worldMapQuestPOI == nil)
		check("dbVersion bumped", VanillaQuestingDB.dbVersion == 4, VanillaQuestingDB.dbVersion)
		VanillaQuestingDB.dbVersion = 1
		VanillaQuestingDB.state.minimapQuestPOITracking = true
		VanillaQuestingDB.state.minimapMarkersTracking = nil
		ns.db = nil
		pcall(fire, "PLAYER_ENTERING_WORLD")
		check("v1 state key migrated", VanillaQuestingDB.state.minimapMarkersTracking == true)
		check("v1 state key removed", VanillaQuestingDB.state.minimapQuestPOITracking == nil)
		ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls
	end

	-- #51: the migration blocks run in ascending order.
	--
	-- They did not. `< 2`, then `< 4`, then `< 3` -- harmless, because the two
	-- out-of-order blocks touch nothing in common, and a trap for the first
	-- migration that depends on an earlier one having run, which is the normal
	-- thing for a migration to do. No scenario can catch that: every one of
	-- them ends at the same database whichever order the blocks ran in. So it
	-- is read off the source, which is the only place the ordering exists.
	do
		local f = io.open("../../VanillaQuesting/Core.lua")
		local src = f and f:read("*a") or ""
		if f then f:close() end
		local seen, ascending = nil, true
		for n in src:gmatch("db%.dbVersion < (%d+)") do
			n = tonumber(n)
			if seen and n <= seen then ascending = false end
			seen = n
		end
		check("initDB's migration blocks are in ascending order", ascending and seen ~= nil,
			tostring(seen))
	end

	-- #34: what one option prints when it moves.
	--
	-- "noOutlineMode off. Outlines on quest objects restored." was two
	-- clauses and a sentence of effect text for a thing the player had just
	-- typed. It is a status row now, in the shape /vq status uses.
	do
		ns:Set("hideBossPortraits", true)
		local b = #chatlog
		pcall(SlashCmdList["VANILLAQUESTING"], "off hideBossPortraits")
		local line = tostring(chatlog[#chatlog])
		check("one option prints one line", #chatlog - b == 1, #chatlog - b)
		check("and it is a transition, not a sentence",
			line:find("->", 1, true) ~= nil
			and line:find("hideBossPortraits", 1, true) ~= nil, line)
		check("with no effect text left in it",
			line:find("Boss portraits", 1, true) == nil, line)
		check("the states carry their own colours",
			line:find(ns.color.on, 1, true) ~= nil
			and line:find(ns.color.off, 1, true) ~= nil, line)

		-- A command that changes nothing still answers. The player typed it;
		-- silence reads as a failure, and "off -> off" is the real answer.
		b = #chatlog
		pcall(SlashCmdList["VANILLAQUESTING"], "off hideBossPortraits")
		check("a command that moves nothing still prints", #chatlog - b == 1,
			#chatlog - b)
		check("and says so honestly",
			tostring(chatlog[#chatlog]):find("off", 1, true) ~= nil
			and select(2, tostring(chatlog[#chatlog]):gsub("off", "")) == 2,
			tostring(chatlog[#chatlog]))
		ns:Set("hideBossPortraits", true)
	end

	-- #34, settled: a bulk command reports what ACTUALLY moved.
	--
	-- Both other shapes were tried in play and rejected -- one line saying
	-- "All vanilla options on" says nothing about the game, and the whole
	-- status list says everything, most of which did not change. The length
	-- of the answer now matches the size of what happened.
	do
		pcall(SlashCmdList["VANILLAQUESTING"], "on")
		local b = #chatlog
		pcall(SlashCmdList["VANILLAQUESTING"], "off")
		local lines = table.concat(chatlog, "\n", b + 1)
		check("a bulk command prints a line per option it moved",
			#chatlog - b > 5, #chatlog - b)
		check("and every one of them is a transition",
			select(2, lines:gsub("%-%>", "")) == #chatlog - b, lines)
		check("not the status list", lines:find("Status", 1, true) == nil, lines)

		-- Nothing moved: the command still answers, because silence reads as
		-- a command that failed.
		b = #chatlog
		pcall(SlashCmdList["VANILLAQUESTING"], "off")
		check("a bulk command that moves nothing says so in one line",
			#chatlog - b == 1, #chatlog - b)
		check("and does not pretend anything changed",
			tostring(chatlog[#chatlog]):find("Nothing to change", 1, true) ~= nil,
			tostring(chatlog[#chatlog]))
		-- In the error colour, not grey: it is the AddOn declining to do
		-- something, which is the same class as every other refusal.
		check("in the same colour as every other refusal",
			tostring(chatlog[#chatlog]):find(ns.color.error, 1, true) ~= nil,
			tostring(chatlog[#chatlog]))

		-- /vq reset is retired. The panel's Defaults button still resets.
		b = #chatlog
		pcall(SlashCmdList["VANILLAQUESTING"], "reset")
		check("/vq reset is retired",
			table.concat(chatlog, "\n", b + 1):find("Unknown command", 1, true) ~= nil,
			table.concat(chatlog, "\n", b + 1))
		check("but ResetDefaults is still there for the Defaults button",
			type(ns.ResetDefaults) == "function")

		-- The trial commands are gone with the decision.
		b = #chatlog
		pcall(SlashCmdList["VANILLAQUESTING"], "offstatus")
		check("the /vq offstatus trial command is retired",
			table.concat(chatlog, "\n", b + 1):find("Unknown command", 1, true) ~= nil,
			table.concat(chatlog, "\n", b + 1))
		ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls
	end

	-- old names still resolve as handles
	pcall(SlashCmdList["VANILLAQUESTING"], "on showBosses")
	check("old v1 name still accepted", VanillaQuestingDB.settings.hideBossPortraits == true)
	pcall(SlashCmdList["VANILLAQUESTING"], "off showBosses")

	-- experimental features must never be swept on by a bare "/vq on"
	--
	-- Checked on noCompleteQuestPopup, not outlineMode. outlineMode is a
	-- mirror: it has no default at all, and on this harness's client Outline
	-- reads 2, so after a reset it is legitimately ON. Using it as the stand-in
	-- for "experimental" would test the mirror instead of the rule.
	ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls
	check("experimental off by default",
		VanillaQuestingDB.settings.noCompleteQuestPopup == false)
	pcall(SlashCmdList["VANILLAQUESTING"], "on")
	check("/vq on leaves experimental alone",
		VanillaQuestingDB.settings.noCompleteQuestPopup == false)

	-- Outline is an ordinary SHARED option now, so reset defaults it like any
	-- other and the variable follows.
	--
	-- It was a MIRROR for four versions: no default, never enforcing, reset
	-- re-reading the client rather than writing to it. That ended when
	-- ShowQuestObjectHighlightEffect gave this AddOn a reason to have an
	-- opinion about outlines -- there is no longer anything to want them ON
	-- for. The mirror machinery is kept in the code deliberately; nothing
	-- uses it.
	--
	-- Note the polarity flip. The old option was on when outlines showed; this
	-- one is on when they are removed, like every other option here.
	cvars.Outline = "3"
	ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls
	check("No Outline Mode ships on", VanillaQuestingDB.settings.noOutlineMode == true,
		tostring(VanillaQuestingDB.settings.noOutlineMode))
	check("and a reset drives the variable to 0", cvars.Outline == "0", cvars.Outline)

	cvars.Outline = "2"
	ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls
	check("/vq on still enables the normal ones", VanillaQuestingDB.settings.hideBossPortraits == true)

	-- On by name, off by name, and the off value is Blizzard's own default of
	-- 2 rather than whatever the player happened to have. Read back by
	-- GetCVarDefault in probe v0.33 [G32] rather than assumed.
	pcall(SlashCmdList["VANILLAQUESTING"], "off noOutlineMode")
	check("switching it off hands back Blizzard's default of 2",
		cvars.Outline == "2", cvars.Outline)
	pcall(SlashCmdList["VANILLAQUESTING"], "on noOutlineMode")
	check("and switching it on removes outlines again", cvars.Outline == "0", cvars.Outline)

	-- 1 and 3 are outline settings too, and the option is against all of them.
	-- The old rule carried an `onValues` table treating 1/2/3 alike because it
	-- reported whether outlines showed; this one asks a single question, so a
	-- plain value == wanted test is the right one.
	for _, v in ipairs({ "1", "2", "3" }) do
		pcall(SlashCmdList["VANILLAQUESTING"], "off noOutlineMode")
		cvars.Outline = v
		VanillaQuestingDB.state.Outline = nil
		pcall(SlashCmdList["VANILLAQUESTING"], "on noOutlineMode")
		check("Outline " .. v .. " is removed when the option goes on",
			cvars.Outline == "0", cvars.Outline)
	end
	ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls

	-- The sparkles themselves, which is why the outline option could change
	-- shape at all. Probe v0.33 [G34] found the variable by reading the
	-- client's own help text, and it was confirmed in game.
	check("the sparkle option ships on", VanillaQuestingDB.settings.noQuestSparkles == true,
		tostring(VanillaQuestingDB.settings.noQuestSparkles))
	check("and drives its variable", cvars.ShowQuestObjectHighlightEffect == "0",
		tostring(cvars.ShowQuestObjectHighlightEffect))
	pcall(SlashCmdList["VANILLAQUESTING"], "off noQuestSparkles")
	check("switching it off hands back the client's default of 1",
		cvars.ShowQuestObjectHighlightEffect == "1",
		tostring(cvars.ShowQuestObjectHighlightEffect))
	ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls

	-- The case that worried us: a player who has NEVER switched Outline Mode
	-- on must never have their Outline touched, including by a bulk /vq off.
	-- Ownership is what `state` records, and there is none here.
	pcall(SlashCmdList["VANILLAQUESTING"], "off outlineMode")
	cvars.Outline = "3"
	VanillaQuestingDB.state.Outline = nil
	pcall(SlashCmdList["VANILLAQUESTING"], "off")
	check("an option never switched on does not touch its variable",
		cvars.Outline == "3", cvars.Outline)
	ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls

	-- And the general rule, on an ordinary option. questPOI has two values, so
	-- "what the player had" and "not on" are the same thing -- which is why
	-- every rule but Outline needs no exception.
	cvars.questPOI = "1"
	VanillaQuestingDB.state.questPOI = nil
	pcall(SlashCmdList["VANILLAQUESTING"], "on hideMapQuestHelper")
	check("an ordinary option drives its variable", cvars.questPOI == "0", cvars.questPOI)
	pcall(SlashCmdList["VANILLAQUESTING"], "off hideMapQuestHelper")
	check("and hands back exactly what the player had", cvars.questPOI == "1",
		cvars.questPOI)

	-- The case that made the option inert, reported from play.
	--
	-- A player who has already run `/console questPOI 0` has the markers
	-- hidden by their own hand. Switching the option on correctly changes
	-- nothing -- it is already where the AddOn wants it -- and switching it
	-- off used to restore the 0 it had recorded, so the markers never came
	-- back while chat said "World map quest helper restored".
	--
	-- The line is whether Blizzard shows a control. questPOI and showBosses
	-- have none, so the option IS the control and its off state has to mean
	-- something. instantQuestText, autoQuestWatch and Outline all have one,
	-- and for those the mirror corrects any disagreement on its own -- our
	-- option cannot sit "off" while the variable is where we want it, because
	-- the mirror flips it back on and says so.
	cvars.questPOI = "0"
	VanillaQuestingDB.state.questPOI = nil
	pcall(SlashCmdList["VANILLAQUESTING"], "on hideMapQuestHelper")
	check("an owned option that is already where we want it writes nothing",
		cvars.questPOI == "0", cvars.questPOI)
	pcall(SlashCmdList["VANILLAQUESTING"], "off hideMapQuestHelper")
	check("but switching it off still brings the markers back",
		cvars.questPOI == "1", cvars.questPOI)

	cvars.showBosses = "0"
	VanillaQuestingDB.state.showBosses = nil
	pcall(SlashCmdList["VANILLAQUESTING"], "on hideBossPortraits")
	pcall(SlashCmdList["VANILLAQUESTING"], "off hideBossPortraits")
	check("same for the other owned option", cvars.showBosses == "1",
		cvars.showBosses)

	-- Every CVar rule, mirrored or not. The distinction between "hand back
	-- what was recorded" and "write the off value" looked vacuous for the
	-- two-valued rules, and enumerating it showed otherwise: a player who
	-- already had the variable at `wanted` gets that recorded as their value,
	-- and handing it back leaves the option off with its effect still running.
	--
	-- The mirror cannot rescue it. Nothing is written, so no CVAR_UPDATE
	-- fires, so the two-way sync never runs -- the disagreement just sits
	-- there, exactly as it did for questPOI.
	for _, t in ipairs({
		{ cvar = "instantQuestText", key = "noInstantQuestText" },
		{ cvar = "autoQuestWatch",   key = "noAutoQuestTracking" },
	}) do
		cvars[t.cvar] = "0"                       -- already where the AddOn wants it
		VanillaQuestingDB.state[t.cvar] = nil
		pcall(SlashCmdList["VANILLAQUESTING"], "on " .. t.key)
		check("no write needed for " .. t.key .. ", it is already there",
			cvars[t.cvar] == "0", cvars[t.cvar])
		pcall(SlashCmdList["VANILLAQUESTING"], "off " .. t.key)
		check("but switching " .. t.key .. " off still means off",
			cvars[t.cvar] == "1", cvars[t.cvar])
	end
	ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls

	-- The remembered value has to be forgotten when the option is handed back,
	-- or it is never replaced. Reported in play against the minimap; the CVar
	-- modules had it too, which is why it is tested here as well as there.
	--
	-- The sequence that catches it: own it, hand it back, let the player set
	-- something new, then own and hand back again. A test that never has the
	-- player change anything in between cannot tell the two versions apart.
	cvars.Outline = "0"
	VanillaQuestingDB.state.Outline = nil
	pcall(SlashCmdList["VANILLAQUESTING"], "on outlineMode")
	pcall(SlashCmdList["VANILLAQUESTING"], "off outlineMode")
	check("handing a CVar back forgets what it was",
		VanillaQuestingDB.state.Outline == nil, tostring(VanillaQuestingDB.state.Outline))
	cvars.Outline = "3"
	pcall(SlashCmdList["VANILLAQUESTING"], "on outlineMode")
	check("a value set between cycles is left alone while the option is on",
		cvars.Outline == "3", cvars.Outline)

	ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls
	-- ---- the tracking button's tooltip ----
	--
	-- Two bugs here, and the second was a too-narrow reading of the first.
	--
	-- Reported: the whole "Tracking" tooltip vanished once the option stood
	-- down. An early return at the top of the hook meant Show() never ran, and
	-- on this client that Show() is what puts Blizzard's own tooltip on
	-- screen. Unreachable for eleven versions -- until the option became
	-- shared, ticking Track Quest POIs was overruled within the frame, so
	-- nobody hovered that button with the option off.
	--
	-- Then gating only the AddLine calls was wrong too. The note is wanted
	-- MOST when the option is off: that is when the entry is behaving in a way
	-- the AddOn did not cause and the player is trying to work out why. A note
	-- that disappears exactly when the question arises is worse than none.
	local function hoverAndCount()
		for i = #tooltipLines, 1, -1 do tooltipLines[i] = nil end
		pcall(hoverTrackingButton)
		local ours = 0
		for _, t in ipairs(tooltipLines) do
			if tostring(t):find("Vanilla Questing", 1, true) then ours = ours + 1 end
		end
		return ours
	end

	pcall(SlashCmdList["VANILLAQUESTING"], "off hideMinimapQuestHelper")
	check("the AddOn's line is there with the option OFF", hoverAndCount() == 1,
		table.concat(tooltipLines, " | "))
	check("and Blizzard's own tooltip is still there",
		tooltipLines[1] == "Tracking", tostring(tooltipLines[1]))
	check("and it is shown", _G.__tooltipShown == true, tostring(_G.__tooltipShown))

	pcall(SlashCmdList["VANILLAQUESTING"], "on hideMinimapQuestHelper")
	check("and with the option ON", hoverAndCount() == 1,
		table.concat(tooltipLines, " | "))
	check("Blizzard's header survives that too", tooltipLines[1] == "Tracking",
		tostring(tooltipLines[1]))

	-- ---- the two-way mirror: SHARED, not owned ----
	--
	-- The dropdown is the player's own control for this entry, so ticking
	-- Track Quest POIs is the player using their interface, not something to
	-- be overruled. Every version up to v1.0.1 forced it back off and printed
	-- an accusation; it now follows, exactly as instantQuestText does.
	local function mirrorLines()
		local n = 0
		for _, m in ipairs(chatlog) do
			local t = tostring(m)
			if t:find("was changed in Blizzard's options", 1, true)
				and t:find("hideMinimapQuestHelper", 1, true) then n = n + 1 end
		end
		return n
	end
	local function enforcementLines()
		local n = 0
		for _, m in ipairs(chatlog) do
			if tostring(m):find("was disabled automatically", 1, true) then n = n + 1 end
		end
		return n
	end

	local said = mirrorLines()
	tracking[4].active = true
	pcall(fire, "MINIMAP_UPDATE_TRACKING")
	check("the player ticking the entry is NOT overruled",
		tracking[4].active == true, tostring(tracking[4].active))
	check("the option follows them off",
		ns.db.settings.hideMinimapQuestHelper == false,
		tostring(ns.db.settings.hideMinimapQuestHelper))
	check("and says so", mirrorLines() == said + 1, mirrorLines() - said)
	check("and the entry is handed back as it goes",
		ns.db.state.minimapMarkersTracking == nil,
		tostring(ns.db.state.minimapMarkersTracking))

	-- The other direction. One yield must not deafen it -- the bug the CVar
	-- mirror had in v0.14.0, which is worth not repeating here.
	said = mirrorLines()
	tracking[4].active = false
	pcall(fire, "MINIMAP_UPDATE_TRACKING")
	check("unticking it turns the option back on",
		ns.db.settings.hideMinimapQuestHelper == true,
		tostring(ns.db.settings.hideMinimapQuestHelper))
	check("and says so too", mirrorLines() == said + 1, mirrorLines() - said)
	check("and adopting on claims the entry",
		ns.db.state.minimapMarkersTracking ~= nil,
		tostring(ns.db.state.minimapMarkersTracking))

	for round = 1, 3 do
		tracking[4].active = true
		pcall(fire, "MINIMAP_UPDATE_TRACKING")
		check("round " .. round .. ": follows the player off",
			ns.db.settings.hideMinimapQuestHelper == false)
		tracking[4].active = false
		pcall(fire, "MINIMAP_UPDATE_TRACKING")
		check("round " .. round .. ": follows the player back on",
			ns.db.settings.hideMinimapQuestHelper == true)
	end

	-- Adopt on, then switch the option off: the entry must come back. Same
	-- shape as the CVar regression, which reached the client because nothing
	-- covered it.
	tracking[4].active = false
	pcall(fire, "MINIMAP_UPDATE_TRACKING")
	pcall(SlashCmdList["VANILLAQUESTING"], "off hideMinimapQuestHelper")
	check("one untick after adopting on is enough to hand the entry back",
		tracking[4].active == true, tostring(tracking[4].active))

	check("and the old enforcement line is gone for good",
		enforcementLines() == 0, enforcementLines())

	ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls

	-- #27: switching the option off restores what the player had, including
	-- OFF. Until v1.0.1 this turned Track Quest POIs back ON regardless, which
	-- was the one place in the AddOn that restored a Blizzard default rather
	-- than the value it found.
	--
	-- The harness starts with the entry ON, so the old behaviour and the new
	-- one agree there and no check could tell them apart. This starts from the
	-- other side, which is the only side that distinguishes them.
	pcall(SlashCmdList["VANILLAQUESTING"], "off hideMinimapQuestHelper")
	ns.db.state.minimapMarkersTracking = nil
	tracking[4].active = false
	pcall(SlashCmdList["VANILLAQUESTING"], "on hideMinimapQuestHelper")
	check("an entry that was already off is marked as ours to hand back",
		ns.db.state.minimapMarkersTracking == false,
		tostring(ns.db.state.minimapMarkersTracking))
	pcall(SlashCmdList["VANILLAQUESTING"], "off hideMinimapQuestHelper")
	check("switching the option off brings the markers back, whatever it found",
		tracking[4].active == true, tostring(tracking[4].active))

	-- Shared, but Disable still hands the entry back. The AddOn turned it off,
	-- so the AddOn turns it on again on the way out -- that is a restore, not
	-- enforcement, and it is what `/vq off` has always done here.
	--
	-- Fourth position on this. v0.18.0 forced it on, #27 argued for the
	-- remembered value and that shipped, the audit made it owned and forced it
	-- on again, and routing it as shared is what the taxonomy actually implies:
	-- the dropdown is a control, so the option shares it rather than winning.
	tracking[4].active = true
	pcall(SlashCmdList["VANILLAQUESTING"], "on hideMinimapQuestHelper")
	check("the AddOn hides it while the option is on", tracking[4].active == false,
		tostring(tracking[4].active))
	pcall(SlashCmdList["VANILLAQUESTING"], "off hideMinimapQuestHelper")
	check("and hands them back when it is switched off", tracking[4].active == true,
		tostring(tracking[4].active))

	-- But an option that was never switched on owns nothing, so a bulk /vq off
	-- must not reach in and turn the entry on for someone who had it off.
	pcall(SlashCmdList["VANILLAQUESTING"], "off hideMinimapQuestHelper")
	tracking[4].active = false
	ns.db.state.minimapMarkersTracking = nil
	pcall(SlashCmdList["VANILLAQUESTING"], "off")
	check("an entry this AddOn never held is left alone",
		tracking[4].active == false, tostring(tracking[4].active))
	ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls
	advanceTime(20)

elseif scenario == "cvar_refused" then
	-- questHelper-style: the write is accepted and ignored
	check("questPOI unchanged", cvars.questPOI == "1", cvars.questPOI)
	local warns = 0
	for _, m in ipairs(chatlog) do if tostring(m):find("would not change") then warns = warns + 1 end end
	check("warned exactly once about the refusal", warns == 1, warns)
	-- repeated events must not re-warn or loop
	for i = 1, 5 do pcall(fire, "CVAR_UPDATE", "questPOI", "1") end
	warns = 0
	for _, m in ipairs(chatlog) do if tostring(m):find("would not change") then warns = warns + 1 end end
	check("still only one warning after 5 more events", warns == 1, warns)
	check("minimap side still worked", tracking[4].active == false, tracking[4].active)

	-- ---- #18: a refusal must not be permanent, and must not block the restore
	--
	-- `refused` latched on the first failure and was never cleared, so one
	-- transient failure killed that option for the session -- and `Disable`
	-- returned on the same flag, which meant the AddOn could make a change it
	-- had then made itself unable to undo. That is the serious half: this
	-- AddOn writes settings that belong to the game and survive deleting the
	-- folder.

	-- The documented refusal, which is a different thing from questHelper's
	-- silent one: SetCVar returns false rather than accepting the write and
	-- ignoring it.
	cvars.showBosses = "1"
	VanillaQuestingDB.state.showBosses = nil
	rejectCVar("showBosses")
	local b4 = #chatlog
	ns:Set("hideBossPortraits", true)
	check("a refusal reported by SetCVar is believed",
		cvars.showBosses == "1", cvars.showBosses)
	local said = false
	for i = b4 + 1, #chatlog do
		if tostring(chatlog[i]):find("was refused", 1, true) then said = true end
	end
	check("and is said once, naming the variable", said)

	-- Refused once, then permitted: the restore has to go through.
	cvars.questPOI = "1"
	VanillaQuestingDB.state.questPOI = nil
	allowCVar("questPOI")
	pcall(fire, "PLAYER_ENTERING_WORLD")
	ns:Set("hideMapQuestHelper", true)
	check("a variable that works again is driven", cvars.questPOI == "0", cvars.questPOI)
	-- The refusal has to be LATCHED before Disable is asked to see past it.
	-- This used to lock, switch off and switch on again -- but the locked
	-- restore left questPOI at 0, so switching on found it already there,
	-- wrote nothing and latched nothing. The check below then passed with
	-- Disable gated on `refused` or not; breaking the fix left it green.
	lockCVar("questPOI")
	ns:Set("hideMapQuestHelper", false)    -- the restore is silently ignored
	cvars.questPOI = "1"                   -- and the variable moves anyway
	ns:Set("hideMapQuestHelper", true)     -- the write is ignored: latched
	check("the refusal really latched",
		tostring(ns.modules.hideMapQuestHelper:Status()):find("write refused", 1, true) ~= nil,
		ns.modules.hideMapQuestHelper:Status())
	allowCVar("questPOI")
	cvars.questPOI = "0"
	VanillaQuestingDB.state.questPOI = "1"
	ns:Set("hideMapQuestHelper", false)
	check("and Disable restores even with a refusal latched",
		cvars.questPOI == "1", cvars.questPOI)

	-- Refused permanently: Disable tries, fails, and says nothing new. A
	-- failed restore costs nothing beyond what has already happened.
	pcall(fire, "PLAYER_ENTERING_WORLD")
	cvars.showBosses = "1"
	VanillaQuestingDB.state.showBosses = nil
	allowCVar("showBosses")
	ns:Set("hideBossPortraits", true)
	check("driven while it works", cvars.showBosses == "0", cvars.showBosses)
	rejectCVar("showBosses")
	b4 = #chatlog
	local okd = pcall(ns.Set, ns, "hideBossPortraits", false)
	check("a permanently refused restore runs without error", okd)
	check("and stays quiet about it", #chatlog == b4, #chatlog - b4)
	check("and the ownership marker is gone either way",
		VanillaQuestingDB.state.showBosses == nil,
		tostring(VanillaQuestingDB.state.showBosses))
	allowCVar("showBosses")

	-- One retry per session, and a loading screen is the natural boundary.
	pcall(fire, "PLAYER_ENTERING_WORLD")
	cvars.showBosses = "1"
	VanillaQuestingDB.state.showBosses = nil
	lockCVar("showBosses")
	ns:Set("hideBossPortraits", true)
	check("a silently ignored write latches", cvars.showBosses == "1", cvars.showBosses)
	allowCVar("showBosses")
	ns:Set("hideBossPortraits", false)
	ns:Set("hideBossPortraits", true)
	check("and stays latched within the session", cvars.showBosses == "1", cvars.showBosses)
	pcall(fire, "PLAYER_ENTERING_WORLD")
	ns:Set("hideBossPortraits", false)
	ns:Set("hideBossPortraits", true)
	check("but a loading screen gives it another chance",
		cvars.showBosses == "0", cvars.showBosses)

elseif scenario == "tracking_slow" then
	-- The client finally gets round to the write, after the whole login.
	pcall(__settleTracking)
	-- A client that applies the write a moment late, which is what the API
	-- actually promises: SetTracking returns nothing and the change is
	-- announced by MINIMAP_UPDATE_TRACKING.
	--
	-- The AddOn used to read back on the very next line and latch `refused` on
	-- the answer, so a slow client became a permanent refusal -- markers left
	-- showing, and an accusation in chat about a setting that worked.
	check("a slow write still lands", tracking[4].active == false,
		tostring(tracking[4].active))
	local warns = 0
	for _, m in ipairs(chatlog) do
		if tostring(m):find("would not turn off") then warns = warns + 1 end
	end
	check("and is never called refused", warns == 0, warns)

	-- And it does not tell the player they changed something. A slow client
	-- means the mirror runs while the first write is still in flight, and an
	-- entry that is still showing then is OUR write not having landed -- not
	-- the player ticking it. Getting this wrong printed a line on a clean
	-- install, where nobody had touched anything.
	local function mirrorLines()
		local n = 0
		for _, m in ipairs(chatlog) do
			local t = tostring(m)
			if t:find("was changed in Blizzard's options", 1, true)
				and t:find("hideMinimapQuestHelper", 1, true) then n = n + 1 end
		end
		return n
	end
	check("and says nothing about the player having changed it", mirrorLines() == 0,
		mirrorLines())
	check("and the option is still on", ns.db.settings.hideMinimapQuestHelper == true,
		tostring(ns.db.settings.hideMinimapQuestHelper))

	-- The mirror still has to work once the AddOn has seen the entry off,
	-- because that is the only moment "you ticked it" is a true description.
	-- Otherwise this is a mute rather than a gate.
	tracking[4].active = true
	pcall(fire, "MINIMAP_UPDATE_TRACKING")
	check("but does follow the player when they really do change it",
		mirrorLines() == 1 and ns.db.settings.hideMinimapQuestHelper == false,
		mirrorLines() .. "/" .. tostring(ns.db.settings.hideMinimapQuestHelper))
	check("and leaves the entry where they put it",
		tracking[4].active == true, tostring(tracking[4].active))

elseif scenario == "tracking_refused" then
	check("tracking unchanged", tracking[4].active == true)
	-- One disagreement is not evidence any more, so drive enough passes for
	-- the AddOn to be sure before asking whether it warned.
	for i = 1, 5 do pcall(fire, "MINIMAP_UPDATE_TRACKING") end
	local warns = 0
	for _, m in ipairs(chatlog) do if tostring(m):find("would not turn off") then warns = warns + 1 end end
	check("warned exactly once once it is sure", warns == 1, warns)
	for i = 1, 5 do pcall(fire, "MINIMAP_UPDATE_TRACKING") end
	warns = 0
	for _, m in ipairs(chatlog) do if tostring(m):find("would not turn off") then warns = warns + 1 end end
	check("still one warning after 5 more events", warns == 1, warns)
	check("world map side still worked", cvars.questPOI == "0", cvars.questPOI)

elseif scenario == "no_cminimap" then
	check("world map side still worked", cvars.questPOI == "0", cvars.questPOI)
	local warned = false
	for _, m in ipairs(chatlog) do if tostring(m):find("C_Minimap tracking API missing") then warned = true end end
	check("warned about missing C_Minimap", warned)
	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "")
	check("/vq status survives missing API", ok, err)

elseif scenario == "no_entry" then
	check("world map side still worked", cvars.questPOI == "0", cvars.questPOI)
	local warned = false
	for _, m in ipairs(chatlog) do if tostring(m):find("no 'Track Quest POIs' entry") then warned = true end end
	check("warned about missing entry", warned)

elseif scenario == "no_cvar" then
	check("minimap side still worked", tracking[4].active == false, tracking[4].active)
	local warned = false
	for _, m in ipairs(chatlog) do if tostring(m):find("does not exist on this client") then warned = true end end
	check("warned about missing CVar", warned)
end

-- ---- options panel ----
if scenario == "normal" or scenario == "no_settings" or scenario == "settings_refuses" then
	ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls
	local panel = _G.VanillaQuestingOptions
	check("panel frame built at login", panel ~= nil)

	_G.__openedCategory = nil
	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "")
	check("bare /vq runs", ok, err)

	if scenario == "normal" then
		check("opened Blizzard settings category", _G.__openedCategory ~= nil, tostring(_G.__openedCategory))
		check("did not fall back to a window", panel:IsShown() == false)
	else
		check("fell back to a standalone window", panel:IsShown() == true)
		local warned = false
		for _, m in ipairs(chatlog) do
			if tostring(m):find("could not add the panel", 1, true) then warned = true end
		end
		check("warned once about registration", warned)
	end

	-- checkbox state must mirror the saved settings, both ways
	ok, err = pcall(ns.RefreshOptions)
	check("RefreshOptions runs", ok, err)

	local frames = _G.frames
	local checks = {}
	-- rawget: the stub's catch-all __index makes every frame *look* like it has
	-- an OnClick, so only real, set scripts count.
	for i = 1, #frames do
		if rawget(frames[i], "script_OnClick") and rawget(frames[i], "__checked") ~= nil then
			checks[#checks+1] = frames[i]
		end
	end
	check("found checkbox rows", #checks >= 5, #checks)

	-- pair checkboxes with their module keys, in panel order
	local rowsForTest = {}
	do
		local ordered = {}
		for i = 1, #ns.modules do ordered[#ordered+1] = ns.modules[i] end
		table.sort(ordered, function(a,b) return (a.order or 999) < (b.order or 999) end)
		for i = 1, math.min(#ordered, #checks) do
			rowsForTest[i] = { key = ordered[i].key, cb = checks[i] }
		end
	end

	-- flip the first row off via its OnClick and confirm the setting moved
	local first = checks[1]
	if first then
		local before = VanillaQuestingDB.settings.hideMapQuestHelper
		-- Read the remembered value BEFORE the click. Handing a CVar back
		-- forgets it, so asking afterwards asks a question whose answer the
		-- click just erased -- and the test then expects Blizzard's default
		-- rather than the value the AddOn correctly restored.
		local remembered = VanillaQuestingDB.state.questPOI
		first:SetChecked(not before)
		ok, err = pcall(rawget(first, "script_OnClick"), first)
		check("checkbox click runs", ok, err)
		check("checkbox click changed the setting",
			VanillaQuestingDB.settings.hideMapQuestHelper == (not before),
			tostring(VanillaQuestingDB.settings.hideMapQuestHelper))
		-- Disabling restores the value the addon remembered, which is not
		-- necessarily "1": if the saved DB was replaced mid-run the addon
		-- re-captures whatever was current, which is correct behaviour.
		local expected = before and remembered or "0"
		check("world map CVar followed the click", cvars.questPOI == expected,
			cvars.questPOI .. " expected " .. tostring(expected))
		ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls
	end

	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "status")
	check("/vq status still works", ok, err)

	-- ---- preset selector ----
	ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls
	local presetText
	for i = 1, #frames do
		local f = frames[i]
		if rawget(f, "script_OnClick") and rawget(f, "__text") == ">" then presetText = f end
	end
	check("found the preset right arrow", presetText ~= nil)

	-- defaults (tier 1 on, rest off) must read as Custom, not a preset
	ok, err = pcall(ns.RefreshOptions)
	check("refresh after reset", ok, err)
	-- Whatever is showing a preset name right now, so the next check can ask
	-- what it says once everything is off.
	local presetShown = {}
	for _, t in ipairs(_G.fontstrings) do
		if rawget(t, "__text") == "Vanilla" then presetShown[#presetShown + 1] = t end
	end

    -- everything off -> Disabled
	for i = 1, #ns.modules do VanillaQuestingDB.settings[ns.modules[i].key] = false end
	pcall(ns.ApplyAll, ns)
	pcall(ns.RefreshOptions)
	local panelFrame = _G.VanillaQuestingOptions
	-- It used to be `check(..., true)`: a guard with nothing to fail on.
	local reads = {}
	for _, t in ipairs(presetShown) do reads[#reads + 1] = tostring(rawget(t, "__text")) end
	check("all off reads as the everything-off preset, not Custom",
		table.concat(reads, ","):find("Disabled", 1, true) ~= nil, table.concat(reads, ","))

	-- stepping from Disabled must turn the non-experimental ones on only
	if presetText then
		ok, err = pcall(rawget(presetText, "script_OnClick"), presetText)
		check("clicking the preset label runs", ok, err)
		check("preset arrow runs", ok, err)
		local on, expOn = 0, 0
		for i = 1, #ns.modules do
			local m = ns.modules[i]
			if VanillaQuestingDB.settings[m.key] then
				on = on + 1
				if m.experimental then expOn = expOn + 1 end
			end
		end
		-- Counted from ns.modules, not written in: adding a Tier 2 option
		-- should not make this test wrong.
		local expectNormal = 0
		for i = 1, #ns.modules do
			if not ns.modules[i].experimental then expectNormal = expectNormal + 1 end
		end
		check("Full Classic turned the normal options on", on == expectNormal, on)
		check("Full Classic left experimental off", expOn == 0, expOn)
		ok, err = pcall(rawget(presetText, "script_OnClick"), presetText)
		check("clicking the preset label runs", ok, err)
		local anyOn = false
		for i = 1, #ns.modules do
			if VanillaQuestingDB.settings[ns.modules[i].key] then anyOn = true end
		end
		check("stepping again turned everything off", anyOn == false)
	end

	-- ---- tooltips ----
	local hovered = nil
	for i = 1, #frames do
		if rawget(frames[i], "script_OnEnter") and rawget(frames[i], "__checked") ~= nil then
			hovered = frames[i]; break
		end
	end
	check("a checkbox has a tooltip handler", hovered ~= nil)
	if hovered then
		_G.__tooltipLines = {}
		ok, err = pcall(rawget(hovered, "script_OnEnter"), hovered)
		check("tooltip OnEnter runs", ok, err)
		check("tooltip has a title and body", #_G.__tooltipLines >= 2, #_G.__tooltipLines)
		local joined = table.concat(_G.__tooltipLines, " | ")
		-- The slash handle lives in the tooltip, set apart by colour since tooltip
	-- lines cannot be resized.
	check("tooltip carries no slash handle",
		joined:find("/hideMapQuestHelper", 1, true) == nil
		and joined:find("/hideMinimapQuestHelper", 1, true) == nil, joined)
		ok, err = pcall(rawget(hovered, "script_OnLeave"), hovered)
		check("tooltip OnLeave runs", ok, err)
	end

	-- ---- the fallback's tooltips say what the native panel's say ----
	--
	-- The two panels build their tooltip bodies separately, and they have
	-- drifted apart twice: the limitation went missing from this one once,
	-- and the experimental note before that. Nothing asserted it: removing
	-- the limitation or the experimental note from this panel's body left
	-- the whole suite green. Every option is hovered and its body compared,
	-- words and line breaks, with `ns.TooltipBodyFor` -- the native builder.
	do
		local function words(t)
			return (tostring(t):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
				:gsub("|n", "\n"))
		end
		local compared, differ = 0, nil
		local seen = {}
		for i = 1, #frames do
			local f = frames[i]
			local enter = rawget(f, "script_OnEnter")
			if enter and rawget(f, "__checked") ~= nil then
				_G.__tooltipLines = {}
				pcall(enter, f)
				local title, body = _G.__tooltipLines[1], _G.__tooltipLines[2]
				for j = 1, #ns.modules do
					local m = ns.modules[j]
					if (m.title or m.key) == title and not seen[m.key] then
						seen[m.key] = true
						compared = compared + 1
						if words(body) ~= words(ns.TooltipBodyFor(m)) then
							differ = m.key .. ": " .. words(body)
						end
						if m.limitation and not tostring(body):find(
							ns.color.limitation .. m.limitation, 1, true) then
							differ = m.key .. ": limitation not in its colour"
						end
					end
				end
			end
		end
		check("every option's fallback tooltip was hovered",
			compared == #ns.modules, compared .. " of " .. #ns.modules)
		check("and says what the native panel's says", differ == nil, tostring(differ))
	end

	-- ---- Defaults asks once, not twice ----
	ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls
	local defBtn
	for i = 1, #frames do
		if rawget(frames[i], "__text") == "Defaults" then defBtn = frames[i] end
	end
	check("Defaults button exists", defBtn ~= nil)
	if defBtn and rowsForTest[1] then
		-- move a map option away from its default so a reload is required
		pcall(rawget(rowsForTest[1].cb, "script_OnClick"), rowsForTest[1].cb)
		pcall(_G.popupAccept)   -- the reload prompt from that toggle
		pcall(SlashCmdList["VANILLAQUESTING"], "off hideMapQuestHelper")

		_G.__popup = nil
		local r0 = _G.__reloads
		ok, err = pcall(rawget(defBtn, "script_OnClick"), defBtn)
		check("Defaults runs", ok, err)
		check("Defaults asks once", _G.__popup == "VANILLAQUESTING_DEFAULTS", tostring(_G.__popup))
		local d = _G.StaticPopupDialogs["VANILLAQUESTING_DEFAULTS"]
		check("its text mentions the reload",
			d and tostring(d.text):find("Note: The UI will reload", 1, true) ~= nil, d and d.text)
		-- popupAccept does not change __popup, so if a SECOND dialog opened the
		-- name would have moved on. It must still read as the Defaults one.
		pcall(_G.popupAccept)
		check("no second confirmation",
			_G.__popup == "VANILLAQUESTING_DEFAULTS", tostring(_G.__popup))
		check("Defaults reloaded once", _G.__reloads == r0 + 1, _G.__reloads - r0)
		check("Defaults restored the settings",
			VanillaQuestingDB.settings.hideMapQuestHelper == true)
	end

	-- with nothing to reload, the question must not mention one
	ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls
	if defBtn then
		pcall(rawget(defBtn, "script_OnClick"), defBtn)
		local d = _G.StaticPopupDialogs["VANILLAQUESTING_DEFAULTS"]
		check("no reload mentioned when nothing needs it",
			d and tostring(d.text):find("reload", 1, true) == nil, d and d.text)
		local r1 = _G.__reloads
		pcall(_G.popupAccept)
		check("and it does not reload", _G.__reloads == r1, _G.__reloads - r1)
	end

	-- ---- a CVar change redraws the frames that read it ----
	--
	-- Reported from play: with the world map pane open, /vq off
	-- hideMapQuestHelper updated the map and left the quest tracker showing
	-- its old POI numbers until a reload. The variable was correct and the UI
	-- was not, which no check that reads the variable back can ever catch.
	do
		ns:ResetDefaults(true)
		-- The player's own pre-AddOn value, stated explicitly. It is recorded
		-- once, on the first Enable, and earlier blocks in this scenario leave
		-- it wherever they left it -- and if it already matches the live value
		-- there is nothing for a toggle to move, so the redraw never fires and
		-- the check measures the setup rather than the code.
		ns.db.state.questPOI = "1"
		SetCVar("questPOI", "0")

		-- ---- the AddOn does not redraw Blizzard's frames itself ----
		--
		-- `refreshQuestUI` used to call `WatchFrame_Update()` and
		-- `QuestMapFrame_UpdateAll()`. Both are gone. Calling a Blizzard
		-- function from AddOn Lua runs it in OUR execution context, and
		-- `WatchFrame_Update` writes the global TABLE WATCHFRAME_NUM_POPUPS --
		-- which makes the taint permanent for the session and spreads it to
		-- code this AddOn never touches.
		--
		-- Gating those calls on `ns.byRequest` was tried first. It cleared the
		-- taint from login and left it on the first slash command: a smaller
		-- surface and the same permanent damage. The second taint log is what
		-- showed that, and it is why the calls had to go rather than move.
		--
		-- Nothing is lost. Blizzard's own CVAR_UPDATE handler does exactly
		-- these calls for questPOI, in its own context, untainted --
		-- Blizzard_UIPanels_Game/Wrath/QuestMapFrame.lua:253 in the 5.5.4
		-- drop. This AddOn was duplicating it and paying in taint.
		_G.openWorldMap()
		local q0 = _G.__questPaneUpdates
		local w0 = _G.__watchUpdates
		pcall(SlashCmdList["VANILLAQUESTING"], "off hideMapQuestHelper")
		check("a user-initiated change does not redraw the quest pane itself",
			_G.__questPaneUpdates == q0, _G.__questPaneUpdates .. " vs " .. q0)
		check("and does not call WatchFrame_Update either",
			_G.__watchUpdates == w0, _G.__watchUpdates .. " vs " .. w0)

		-- What it DOES do is cycle the map, which is the only thing that makes
		-- the on-screen quest helper pick a questPOI change up. That is
		-- asserted by sequence below rather than by a counter.

		-- Cycling the map. Asking the tracker to redraw was NOT enough: in
		-- play the on-screen quest helper only picks a questPOI change up when
		-- the map pane closes and opens again -- and the map has to end up
		-- CLOSED, which is what the sequence is asserted on rather than a
		-- count of cycles.
		local function ops() return table.concat(_G.__mapOps, ",") end

		ns.db.state.questPOI = "1"
		SetCVar("questPOI", "0")
		_G.openWorldMap()
		_G.__maximizeWorldMap()
		_G.__clearMapOps()
		pcall(SlashCmdList["VANILLAQUESTING"], "off hideMapQuestHelper")
		-- #44: the round trip is what refreshes the helper; where it LEAVES the
		-- map is a separate question, and the answer is "where it found it".
		-- A player who had the map open asked for an option to change, not for
		-- their map to be taken away.
		check("an open map is closed and reopened", ops() == "hide,show", ops())
		check("and is left open, because that is how it was found",
			WorldMapFrame:IsShown())

		-- A shut map is opened by the CLIENT and shut again by us, and that is
		-- the whole of it (#46, answered in game 2026-09-16).
		--
		-- `blizz-open` first, and it is not ours: writing questPOI makes the
		-- client open the map from its own CVAR_UPDATE handler, synchronously.
		-- That open is what refreshes the on-screen helper -- measured in play
		-- with the cycle switched off, both directions -- so the AddOn's own
		-- close-open-close was re-implementing it, and hiding it at the same
		-- time.
		--
		-- Two operations where there were four, and the map still ends CLOSED,
		-- which is the assertion that matters.
		SetCVar("questPOI", "1")
		_G.closeWorldMap()
		_G.__clearMapOps()
		pcall(SlashCmdList["VANILLAQUESTING"], "on hideMapQuestHelper")
		check("a shut map is opened by the client and shut again by us",
			ops() == "blizz-open,hide", ops())
		check("and a map that was shut is left shut", not WorldMapFrame:IsShown())

		-- #46, settled in game and the switch removed with it.
		--
		-- `/vq mapcycle` shipped for one round so both halves of the question
		-- could be asked in one session. They were: with the map SHUT the
		-- client refreshes the helper on its own, with the map OPEN only a
		-- close and an open does. So the cycle runs for the open case and the
		-- switch is gone -- a second way for the AddOn to behave, that nothing
		-- exercises, is worse than no switch at all.
		--
		-- Off first, so the "on" below is a real transition: an option already
		-- where it is asked to go writes nothing, raises no CVAR_UPDATE, and
		-- would prove nothing about the map.
		pcall(SlashCmdList["VANILLAQUESTING"], "off hideMapQuestHelper")
		ns.db.state.questPOI = "1"
		cvars.questPOI = "1"
		_G.openWorldMap()
		_G.__clearMapOps()
		pcall(SlashCmdList["VANILLAQUESTING"], "on hideMapQuestHelper")
		check("an open map is closed and reopened", ops() == "hide,show", ops())
		check("and left open", WorldMapFrame:IsShown())
		-- An option the map does not read must not touch it at all.
		ns.db.state.questPOI = "1"
		_G.openWorldMap()
		_G.__clearMapOps()
		pcall(SlashCmdList["VANILLAQUESTING"], "off hideTooltipsQuestProgress")
		check("an unrelated option does not touch the map", ops() == "", ops())
		check("and leaves it open", WorldMapFrame:IsShown())

		-- Not in combat. The world map is protected during a fight: cycling
		-- it throws "Interface action failed because of an AddOn" and does
		-- nothing. Deferring it to the end of the fight threw the same error,
		-- so the guard is the whole of the handling -- the player opens the
		-- map themselves, which is what they would do anyway.
		ns.db.state.questPOI = "1"
		SetCVar("questPOI", "0")
		_G.openWorldMap()
		_G.__inCombat = true
		_G.__clearMapOps()
		pcall(SlashCmdList["VANILLAQUESTING"], "off hideMapQuestHelper")
		check("the map is left alone in combat", ops() == "", ops())
		check("and is still open, not half-cycled", WorldMapFrame:IsShown())

		-- #24: in combat the command is refused, so nothing is written.
		--
		-- Hide World Map Quest Helper is the one option that cannot take
		-- effect without the UI being rebuilt, and writing its variable is
		-- what makes the CLIENT try to open the world map -- which it may not
		-- do mid-fight. This is the whole of #11's remedy: not writing
		-- `questPOI` in combat at all.
		ns.db.state.questPOI = "1"
		cvars.questPOI = "1"
		ns.db.settings.hideMapQuestHelper = false
		_G.closeWorldMap()
		_G.__clearMapOps()
		local blocked0 = _G.__blizzMapBlocked
		local before24 = #chatlog
		pcall(SlashCmdList["VANILLAQUESTING"], "on hideMapQuestHelper")
		check("the reload-needing option is refused in combat",
			cvars.questPOI == "1", cvars.questPOI)
		check("and the setting does not move either",
			ns.db.settings.hideMapQuestHelper == false,
			tostring(ns.db.settings.hideMapQuestHelper))
		check("so the client is never asked to open the map",
			_G.__blizzMapBlocked == blocked0, _G.__blizzMapBlocked)
		check("and the AddOn does not touch it either", ops() == "", ops())
		local said24
		for i = before24 + 1, #chatlog do
			if tostring(chatlog[i]):find("during combat", 1, true) then said24 = chatlog[i] end
		end
		check("and the player is told why", said24 ~= nil, said24)

		-- Bulk commands go the same way, whatever they would have moved.
		-- Set explicitly first: an option that is already where `/vq off`
		-- would leave it proves nothing about the command being refused.
		ns.db.settings.hideTooltipsQuestProgress = true
		local before24b = #chatlog
		pcall(SlashCmdList["VANILLAQUESTING"], "off")
		check("/vq off is blocked in combat too",
			ns.db.settings.hideTooltipsQuestProgress == true,
			tostring(ns.db.settings.hideTooltipsQuestProgress))
		local saidBulk
		for i = before24b + 1, #chatlog do
			if tostring(chatlog[i]):find("Command blocked", 1, true) then saidBulk = chatlog[i] end
		end
		check("and says which class of thing is blocked", saidBulk ~= nil, saidBulk)

		-- An option that needs no reload still works in combat: it takes
		-- effect the moment it is written, and nothing in the client has to
		-- be rebuilt to show it.
		pcall(SlashCmdList["VANILLAQUESTING"], "off hideTooltipsQuestProgress")
		check("an option that needs no reload is still allowed in combat",
			ns.db.settings.hideTooltipsQuestProgress == false,
			tostring(ns.db.settings.hideTooltipsQuestProgress))
		pcall(SlashCmdList["VANILLAQUESTING"], "on hideTooltipsQuestProgress")

		-- #11, and the client's half of it, on the path that can still write
		-- in combat: the re-assert. Something else moves `questPOI` mid-fight,
		-- the AddOn puts it back, and Blizzard's own CVAR_UPDATE handler tries
		-- to open the map -- `ShowUIPanel` refuses, because
		-- `CheckProtectedFunctionsAllowed` is `InCombatLockdown() and not
		-- issecure()` and our SetCVar is what made that execution insecure.
		-- The client prints "Interface action failed because of an AddOn" and
		-- nothing moves. That error is NOT this AddOn's cycle, which returned
		-- at the combat guard long before.
		--
		-- Kept because refusing the COMMAND does not reach this path, and a
		-- model of the client that only the blocked path exercised would stop
		-- measuring anything the moment the command stopped writing.
		ns.db.settings.hideMapQuestHelper = true
		ns.db.state.questPOI = "1"
		cvars.questPOI = "1"
		_G.closeWorldMap()
		_G.__clearMapOps()
		blocked0 = _G.__blizzMapBlocked
		pcall(fire, "CVAR_UPDATE", "questPOI", "1")
		check("a re-assert in combat still reaches the client's own open",
			_G.__blizzMapBlocked > blocked0, _G.__blizzMapBlocked)
		check("and the AddOn does not touch the map either way", ops() == "", ops())
		check("and a shut map stays shut", not WorldMapFrame:IsShown())
		_G.__inCombat = false

		-- ---- taint: nothing calls WatchFrame_Update at login ----
		--
		-- From the taint log on 5.5.4.69585, VanillaQuesting the only AddOn:
		--
		--   Tainted value written to global WATCHFRAME_NUM_POPUPS by
		--   VanillaQuesting -- WatchFrame.lua:478
		--     pcall() / Tracker.lua:148 / applyModule() / ApplyAll()
		--
		-- CALLING a Blizzard function from AddOn Lua runs it in our execution
		-- context, so everything it writes is marked as ours. WATCHFRAME_NUM_POPUPS
		-- is a global TABLE, so the taint is permanent for the session, and the
		-- same log shows it spreading to WorldStateFrame's timers and
		-- QuestMapFrame -- none of which this AddOn touches.
		--
		-- Hooking is not the problem and never was: `hooksecurefunc` post-hooks
		-- do not taint. Calling is.
		_G.__watchUpdates = 0
		pcall(fire, "PLAYER_ENTERING_WORLD")
		check("a loading screen calls WatchFrame_Update zero times",
			_G.__watchUpdates == 0, _G.__watchUpdates)

		ns:ResetDefaults(true)
		_G.__watchUpdates = 0
		pcall(fire, "VARIABLES_LOADED")
		check("and so does VARIABLES_LOADED", _G.__watchUpdates == 0, _G.__watchUpdates)

		-- The tracker options still apply on that pass -- the point is that
		-- they do it by walking the buttons themselves, not by asking
		-- Blizzard to rebuild.
		check("and the tracker options are still applied",
			WATCHFRAME_LINKBUTTONS[1]:IsMouseEnabled() == false,
			tostring(WATCHFRAME_LINKBUTTONS[1]:IsMouseEnabled()))

		-- ---- #17: a loading screen is not someone asking for a refresh ----
		--
		-- The cycle goes through HideUIPanel / ShowUIPanel, which taints
		-- Blizzard's UI panel manager. The combat guard above prevents the
		-- immediate error and does nothing about the taint, which surfaces
		-- later as an unrelated blocked action with nothing pointing back
		-- here.
		--
		-- And it was not only reached from a deliberate toggle:
		--
		--   PLAYER_ENTERING_WORLD -> ApplyAll -> Enable -> writeCVar
		--                         -> refreshQuestUI -> cycleWorldMap
		--
		-- Any loading screen where questPOI had drifted took that path, out of
		-- combat, with no guard in the way -- including the very first login
		-- after installing.
		-- Staged by writing the table directly, not through SetCVar: SetCVar
		-- raises CVAR_UPDATE, the mirror re-asserts on the spot, and the drift
		-- is gone before the loading screen arrives.
		pcall(SlashCmdList["VANILLAQUESTING"], "on hideMapQuestHelper")
		ns.db.state.questPOI = "1"
		cvars.questPOI = "1"              -- drifted back
		_G.closeWorldMap()
		_G.__clearMapOps()
		pcall(fire, "PLAYER_ENTERING_WORLD")
		check("a loading screen re-asserts the variable", cvars.questPOI == "0",
			cvars.questPOI)
		-- One `hide`, not a cycle. The client opened the map because we wrote;
		-- putting it back is the whole of the handling, and it is not a
		-- refresh -- there is no `show` in that sequence (#36).
		check("and does NOT cycle the map to do it",
			ops() == "blizz-open,hide", ops())
		check("and the map does not stay open behind the loading screen",
			not WorldMapFrame:IsShown())

		-- And the other half of the same rule: a map that was ALREADY open is
		-- not ours to shut. The player, or another AddOn's write, put it
		-- there. Only an open that our own write caused is undone.
		pcall(SlashCmdList["VANILLAQUESTING"], "on hideMapQuestHelper")
		ns.db.state.questPOI = "1"
		cvars.questPOI = "1"
		_G.openWorldMap()
		_G.__maximizeWorldMap()
		_G.__clearMapOps()
		pcall(fire, "PLAYER_ENTERING_WORLD")
		check("a loading screen still re-asserts", cvars.questPOI == "0", cvars.questPOI)
		check("and a map that was already open is left open",
			WorldMapFrame:IsShown() and ops() == "", ops())
		_G.closeWorldMap()

		-- The CVAR_UPDATE re-assert, which is the path another AddOn takes.
		-- Their write is what the client answers with an open map; ours is a
		-- write to a map that is open by then, so it is left alone. #44 is
		-- where that gets revisited.
		ns.db.state.questPOI = "1"
		_G.closeWorldMap()
		_G.__clearMapOps()
		SetCVar("questPOI", "1")          -- somebody else moves it
		check("a foreign write is re-asserted", cvars.questPOI == "0", cvars.questPOI)
		check("and the AddOn adds no map operations of its own", ops() == "blizz-open", ops())
		_G.closeWorldMap()

		-- The same write, asked for by a person, with the map SHUT. No cycle
		-- any more (#46, answered in game): the client opens the map from its
		-- own handler and refreshes the helper while doing it, and all the
		-- AddOn has to do is shut what our write opened. The close is not half
		-- a cycle -- it is the second half of the CLIENT's open.
		pcall(SlashCmdList["VANILLAQUESTING"], "off hideMapQuestHelper")
		ns.db.state.questPOI = "1"
		cvars.questPOI = "1"
		_G.closeWorldMap()
		_G.__clearMapOps()
		pcall(SlashCmdList["VANILLAQUESTING"], "on hideMapQuestHelper")
		check("a slash command with the map shut does not cycle",
			ops() == "blizz-open,hide", ops())
		check("and ends closed", not WorldMapFrame:IsShown())

		-- And the bulk commands are the player too.
		pcall(SlashCmdList["VANILLAQUESTING"], "off hideMapQuestHelper")
		ns.db.state.questPOI = "1"
		cvars.questPOI = "1"
		_G.closeWorldMap()
		_G.__clearMapOps()
		pcall(SlashCmdList["VANILLAQUESTING"], "on")
		check("as is /vq on", ops() == "blizz-open,hide", ops())
		check("and it ends closed as well", not WorldMapFrame:IsShown())
		ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls
		_G.closeWorldMap()

		ns:ResetDefaults(true)
	end

	-- ---- slash output ----
	local before3 = #chatlog
	pcall(SlashCmdList["VANILLAQUESTING"], "status")
	local statusText = table.concat(chatlog, "\n", before3 + 1)
	check("status is titled", statusText:find("- Status", 1, true) ~= nil, statusText)
	check("status hides the live CVar readout",
		statusText:find("questPOI", 1, true) == nil, statusText)
	-- The name is the same yellow either way; only the "(experimental)" note
	-- after it is orange. The panel cannot colour its names ([G23b]), so
	-- colouring them here would make the two surfaces disagree.
	do
		local expLine, normalLine
		for i = before3 + 1, #chatlog do
			local t = tostring(chatlog[i])
			if t:find("noCompleteQuestPopup", 1, true) then expLine = t end
			if t:find("hideMapQuestHelper", 1, true) then normalLine = t end
		end
		check("every option name is the same yellow, experimental or not",
			expLine and expLine:find("|cffffd100noCompleteQuestPopup", 1, true) ~= nil, tostring(expLine))
		check("and the experimental one carries the (experimental) note in orange",
			expLine and expLine:find("|cffff8019(experimental)", 1, true) ~= nil, tostring(expLine))
		check("a normal option has no orange at all",
			normalLine and normalLine:find("|cffff8019", 1, true) == nil, tostring(normalLine))
	end
	-- /vq status must list options in the same order the panel shows them
	do
		local ordered = ns:SortedModules()
		local seen, pos = {}, 0
		for i = before3 + 1, #chatlog do
			local t = tostring(chatlog[i])
			for j = 1, #ordered do
				if t:find(ordered[j].key, 1, true) then seen[#seen + 1] = j end
			end
		end
		local ascending = true
		for i = 2, #seen do
			if seen[i] < seen[i - 1] then ascending = false end
		end
		check("status is in panel order", ascending and #seen >= 5, #seen)
	end

	-- Regression guard. A slash toggle used to print "needs a UI reload".
	-- Tested in game: it does not -- the map is correct the next time it
	-- opens -- so the line was advice for a problem the player never has.
	ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls
	local b4 = #chatlog
	pcall(SlashCmdList["VANILLAQUESTING"], "off hideMapQuestHelper")
	local told = false
	for i = b4 + 1, #chatlog do
		if tostring(chatlog[i]):lower():find("reload", 1, true) then told = true end
	end
	check("slash toggle does NOT tell the player to reload", not told)
	b4 = #chatlog
	pcall(SlashCmdList["VANILLAQUESTING"], "on outlineMode")
	told = false
	for i = b4 + 1, #chatlog do
		if tostring(chatlog[i]):find("needs a UI reload", 1, true) then told = true end
	end
	check("a non-map slash toggle stays quiet", told == false)
	ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls

	before3 = #chatlog
	pcall(SlashCmdList["VANILLAQUESTING"], "help")
	local helpText = table.concat(chatlog, "\n", before3 + 1)
	check("help is titled", helpText:find("- List of commands", 1, true) ~= nil, helpText)

	-- ---- defaults button must not print to chat ----
	ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls
	local before = #chatlog
	ok, err = pcall(ns.ResetDefaults, ns, true)
	check("silent reset runs", ok, err)
	check("silent reset printed nothing", #chatlog == before, #chatlog - before)
	ok, err = pcall(ns.ResetDefaults, ns)
	check("loud reset runs", ok, err)
	check("loud reset still prints for /vq reset", #chatlog > before)

	-- ---- reload confirmation at the moment of change ----
	ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls
	local noApplyButton = true
	for i = 1, #frames do
		if rawget(frames[i], "__text") == "Apply" then noApplyButton = false end
	end
	check("no Apply button (it could be ignored)", noApplyButton)

	-- toggling a map option must ask, and Cancel must put it back
	local mapRow
	for i = 1, #checks do
		if rawget(checks[i], "script_OnClick") then mapRow = checks[i] break end
	end
	if mapRow then
		local wasOn = VanillaQuestingDB.settings.hideMapQuestHelper
		_G.__popup = nil
		ok, err = pcall(rawget(mapRow, "script_OnClick"), mapRow)
		check("toggling a map option runs", ok, err)
		check("it asks about reloading", _G.__popup == "VANILLAQUESTING_RELOAD", tostring(_G.__popup))
		check("the setting changed while the prompt is up",
			VanillaQuestingDB.settings.hideMapQuestHelper == (not wasOn))
		ok, err = pcall(_G.popupCancel)
		check("Cancel runs", ok, err)
		check("Cancel put the setting back",
			VanillaQuestingDB.settings.hideMapQuestHelper == wasOn,
			tostring(VanillaQuestingDB.settings.hideMapQuestHelper))
		check("Cancel restored the CVar too", cvars.questPOI == (wasOn and "0" or "1"), cvars.questPOI)

		local r0 = _G.__reloads
		pcall(rawget(mapRow, "script_OnClick"), mapRow)
		ok, err = pcall(_G.popupAccept)
		check("Reload runs", ok, err)
		check("Reload reloads the UI", _G.__reloads > r0, _G.__reloads - r0)
		ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls

		-- #24, second pass: the panel keeps working in combat.
		--
		-- Build 1 refused here and the author rejected it in play. A panel that
		-- is already open should keep working, and the line that survives is
		-- about who initiated it: a slash command is typed blind and is
		-- refused, a button is a deliberate click on a frame being read.
		--
		-- Getting TO the panel is the part that is guarded, below.
		local wasCombat = VanillaQuestingDB.settings.hideMapQuestHelper
		local r2 = _G.__reloads
		_G.__popup = nil
		_G.__inCombat = true
		pcall(rawget(mapRow, "script_OnClick"), mapRow)
		check("in combat the panel still asks about reloading",
			_G.__popup == "VANILLAQUESTING_RELOAD", tostring(_G.__popup))
		check("and the change is not taken away",
			VanillaQuestingDB.settings.hideMapQuestHelper == (not wasCombat),
			tostring(VanillaQuestingDB.settings.hideMapQuestHelper))
		pcall(_G.popupAccept)
		check("and Reload still reloads", _G.__reloads > r2, _G.__reloads - r2)

		-- But `/vq` cannot open it. Settings.OpenToCategory ends in
		-- ShowUIPanel, which refuses a tainted caller in combat -- and pcall
		-- does not catch that, because Blizzard prints the message and returns
		-- normally. Reported from play: the error on screen, no panel.
		local beforeOpen = #chatlog
		local opened = ns:OpenOptions()
		check("/vq does not try to open the panel in combat", opened == false,
			tostring(opened))
		local saidOpen
		for i = beforeOpen + 1, #chatlog do
			if tostring(chatlog[i]):find("cannot open the options panel", 1, true) then
				saidOpen = chatlog[i]
			end
		end
		check("and says so rather than letting the client throw",
			saidOpen ~= nil, saidOpen)
		-- It says `/vq` cannot open it, not that the panel cannot be opened:
		-- Blizzard's own Esc menu opens it in combat, being a secure path, and
		-- an AddOn that says otherwise is lying to be brief.
		-- It says `/vq` cannot open it, NOT that the panel cannot be opened:
		-- Blizzard's own Esc menu opens it in combat, being a secure path.
		check("and does not claim the panel itself is unreachable",
			saidOpen ~= nil
			and tostring(saidOpen):find("/vq cannot open", 1, true) ~= nil
			and tostring(saidOpen):find("panel cannot be opened", 1, true) == nil,
			saidOpen)
		-- One colour across the whole message, not a warning that fades into
		-- the ordinary yellow half way through. Two escapes in the line: the
		-- chat prefix has its own, and the message has one.
		check("the whole refusal is one colour",
			saidOpen ~= nil and select(2, tostring(saidOpen):gsub("|c", "")) == 2,
			saidOpen)

		_G.__inCombat = false
		ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls
	end

	-- a non-map option must NOT ask
	local expRow
	for i = 1, #rowsForTest do
		if rowsForTest[i].key == "outlineMode" then expRow = rowsForTest[i].cb end
	end
	if expRow then
		_G.__popup = nil
		pcall(rawget(expRow, "script_OnClick"), expRow)
		check("a non-map option does not ask", _G.__popup == nil, tostring(_G.__popup))
		ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls
	end

	-- ---- unknown commands ----
	_G.__openedCategory = nil
	panel:Hide()
	local before2 = #chatlog
	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "wibble")
	check("unknown command runs", ok, err)
	local complained = false
	for i = before2 + 1, #chatlog do
		if tostring(chatlog[i]):find("Unknown command", 1, true) then complained = true end
	end
	check("unknown command complains", complained)
	-- The trial of two refusal colours is over (#58): one colour, the
	-- client's, asserted on the lines themselves below.
	do
		local unknownLine
		for i = before2 + 1, #chatlog do
			local t = tostring(chatlog[i])
			if t:find("Unknown command", 1, true) then unknownLine = t end
		end
		-- **One error colour, the game's own, on every line end to end.**
		--
		-- Two were shipped for a round and compared in play: the AddOn's
		-- salmon for "you typed something wrong", the client's yellow for
		-- "the AddOn will not do that". The salmon lost on evidence only the
		-- game could give -- it sits close to the Experimental orange, and
		-- **in-game emotes render orange**, so an error could vanish into the
		-- chat around it.
		--
		-- Read off the LINES, not off the palette. Comparing two palette
		-- entries passes whatever the printers actually used, which is the
		-- shape of guard this project has been caught by before.
		check("an unrecognised command is one colour end to end",
			unknownLine ~= nil
			and unknownLine:find(ns.color.error, 1, true) ~= nil
			and select(2, unknownLine:gsub("|c", "")) == 2,
			unknownLine)

		_G.__inCombat = true
		local b = #chatlog
		pcall(SlashCmdList["VANILLAQUESTING"], "off")
		_G.__inCombat = false
		local blockedLine
		for i = b + 1, #chatlog do
			local t = tostring(chatlog[i])
			if t:find("Command blocked", 1, true) then blockedLine = t end
		end
		check("a blocked command uses the same one",
			blockedLine ~= nil and blockedLine:find(ns.color.error, 1, true) ~= nil
			and select(2, blockedLine:gsub("|c", "")) == 2,
			blockedLine)
		check("and no line anywhere still uses the retired salmon",
			table.concat(chatlog, "\n"):find("|cffff9955", 1, true) == nil)
	end
	-- It ended `or true`, and could not fail. Both ways the panel can open --
	-- Blizzard's category, or the AddOn's own window -- are asked about now.
	check("unknown command did not open the panel",
		_G.__openedCategory == nil and not panel:IsShown(),
		tostring(_G.__openedCategory) .. " / shown=" .. tostring(panel:IsShown()))

	-- Refreshing map data providers wipes fog-of-war state, so the addon must
	-- never call it. Regression guard.
	check("never refreshes map data providers", _G.__mapRefreshes == 0, _G.__mapRefreshes)
	check("does not hook the world map", _G.__mapOnShow == nil)

	-- /vq help must not error
	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "help")
	check("/vq help runs", ok, err)
	local helpSeen = false
	for _, m in ipairs(chatlog) do
		if tostring(m):find("/vq status", 1, true) then helpSeen = true end
	end
	check("/vq help lists commands", helpSeen)

	-- ---- changing one option applies one option ----
	--
	-- `ns:Set` called `ns:ApplyAll`, re-applying all thirteen modules to move
	-- one checkbox. Reported from play as the panel lagging on every click,
	-- with shared and mirrored options worst -- and the report carried its own
	-- diagnosis: no lag when the BLIZZARD control was moved, because that path
	-- goes through the mirror and never calls ApplyAll.
	--
	-- Counted rather than timed. A timing test would be flaky here and would
	-- not say what got slower; the number of modules applied is the thing that
	-- actually changed, and it is exact.
	do
		ns:ResetDefaults(true)
		local calls = {}
		local saved = {}
		for i = 1, #ns.modules do
			local m = ns.modules[i]
			saved[i] = { m = m, Enable = m.Enable, Disable = m.Disable }
			local key = m.key
			if type(m.Enable) == "function" then
				local real = m.Enable
				m.Enable = function(self) calls[key] = (calls[key] or 0) + 1 return real(self) end
			end
			if type(m.Disable) == "function" then
				local real = m.Disable
				m.Disable = function(self) calls[key] = (calls[key] or 0) + 1 return real(self) end
			end
		end
		local function touched()
			local n, names = 0, {}
			for k in pairs(calls) do n = n + 1 names[#names + 1] = k end
			table.sort(names)
			return n, table.concat(names, ",")
		end
		local function clear() for k in pairs(calls) do calls[k] = nil end end

		clear()
		ns:Set("hideBossPortraits", false)
		local n, names = touched()
		check("one option applies one module", n == 1 and names == "hideBossPortraits",
			n .. ": " .. names)

		-- ...but a parent takes its children with it, or a sub-option is left
		-- running under a parent that has just been switched off.
		clear()
		ns:Set("trackerPlainText", false)
		n, names = touched()
		check("a parent applies its sub-options too",
			calls.trackerPlainText == 1 and calls.trackerPlainTextAchievements == 1,
			n .. ": " .. names)
		check("and nothing else", n == 2, n .. ": " .. names)

		-- A bulk command still applies everything, because everything moved.
		clear()
		pcall(SlashCmdList["VANILLAQUESTING"], "off")
		n = touched()
		check("a bulk command still applies every module", n == #ns.modules,
			n .. " of " .. #ns.modules)

		clear()
		ns:ResetDefaults(true)
		n = touched()
		check("and so does Defaults", n == #ns.modules, n .. " of " .. #ns.modules)

		for i = 1, #saved do
			saved[i].m.Enable = saved[i].Enable
			saved[i].m.Disable = saved[i].Disable
		end
		ns:ResetDefaults(true)
	end

	-- ---- the experimental note is not shown on a mirror ----
	--
	-- Kept although nothing is a mirror today, on purpose, and paired with the
	-- machinery kept in CVars.lua for the same reason: the argument took six
	-- rounds to get right and the next mirror should not have to re-derive it.
	--
	-- The rule: "untested and potentially unstable" is a claim about what this
	-- AddOn is doing to the game, and a mirror does nothing to the game -- it
	-- reports a Blizzard setting. So the note is suppressed for mirrors and
	-- shown for every other experimental option.
	--
	-- With no mirror to point at, this asserts the RULE rather than a row:
	-- every experimental option carries the note, and would stop carrying it
	-- the moment it became a mirror.
	do
		local experiments, mirrors = 0, 0
		for i = 1, #ns.modules do
			local m = ns.modules[i]
			if m.experimental then experiments = experiments + 1 end
			if m.mirrorOnly then mirrors = mirrors + 1 end
		end
		check("there is at least one experimental option to reason about",
			experiments > 0, experiments)
		check("and nothing is a mirror today", mirrors == 0, mirrors)

		-- The suppression itself, proved by making a module a mirror for the
		-- length of one call. Reaching into the module is deliberate: there is
		-- no rule to point at, and a rule nobody can exercise is a rule that
		-- has quietly stopped working.
		local exp
		for i = 1, #ns.modules do
			if ns.modules[i].experimental then exp = ns.modules[i] break end
		end
		if exp and type(ns.TooltipBodyFor) == "function" then
			local withNote = ns.TooltipBodyFor(exp)
			exp.mirrorOnly = true
			local asMirror = ns.TooltipBodyFor(exp)
			exp.mirrorOnly = nil
			check("an experimental option carries the untested warning",
				withNote and withNote:find("untested and potentially unstable", 1, true) ~= nil,
				tostring(withNote))
			check("and loses it the moment it becomes a mirror",
				asMirror and asMirror:find("untested and potentially unstable", 1, true) == nil,
				tostring(asMirror))
		end
	end

	-- ---- the help text itself ----
	--
	-- Held as literals on purpose, the same way EXPERIMENTAL_NOTE_TEXT is:
	-- change the wording in the AddOn and this goes red, which is the reminder
	-- that the README table is part of the same change.
	--
	-- The bracket form is what the player sees. `/vq on` and `/vq on <option>`
	-- used to be two separate lines, which made one command look like two and
	-- pushed the list to seven rows for five commands.
	before3 = #chatlog
	pcall(SlashCmdList["VANILLAQUESTING"], "help")
	helpText = table.concat(chatlog, "\n", before3 + 1)
	for _, want in ipairs({
		"/vq on [option]",
		"Enable all vanilla options, or one [option]",
		"/vq off [option]",
		"Disable all options, or one [option]",
		"/vq status [option]",
		"List status of all options, or one [option]",
	}) do
		check("help says " .. want, helpText:find(want, 1, true) ~= nil, helpText)
	end
	for _, gone in ipairs({ "/vq on <option>", "/vq off <option>",
		"Turn one option on", "Turn one option off",
		-- Retired: it did what /vq on does, and the word invited the reading
		-- that it was a second way to switch the AddOn off.
		"/vq reset", "Restore default options",
		"List every option and its current state" }) do
		check("help no longer says " .. gone, helpText:find(gone, 1, true) == nil)
	end

	-- ---- /vq status <option> ----
	ns:ResetDefaults(true)
	before3 = #chatlog
	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "status hideBossPortraits")
	check("/vq status <option> runs", ok, err)
	local oneText = table.concat(chatlog, "\n", before3 + 1)
	-- #34: one line, no header and no label. A title, a version and a subtitle
	-- above a single row was four times as much chat as the answer; a
	-- "Status:" in front of it was tried in the same pass and dropped for the
	-- same reason, once it was on screen. The row IS the answer.
	check("it is a bare row, with no heading and no label",
		oneText:find("Status", 1, true) == nil, oneText)
	check("and prints the option asked for",
		oneText:find("hideBossPortraits", 1, true) ~= nil, oneText)
	-- ONE line now. A single-option lookup that prints the whole list is the
	-- bug this is here to catch, and the header going was the point of #34.
	check("and nothing else", #chatlog - before3 == 1, #chatlog - before3)

	-- The same handle as /vq on|off: display key, saved-setting name and the
	-- old v1 names, case-insensitively.
	for _, alias in ipairs({ "showBosses", "HIDEBOSSPORTRAITS" }) do
		before3 = #chatlog
		pcall(SlashCmdList["VANILLAQUESTING"], "status " .. alias)
		check("/vq status accepts " .. alias,
			table.concat(chatlog, "\n", before3 + 1):find("hideBossPortraits", 1, true) ~= nil)
	end

	-- And it reports what the option is doing, not what it is set to.
	ns:Set("hideBossPortraits", false)
	before3 = #chatlog
	pcall(SlashCmdList["VANILLAQUESTING"], "status hideBossPortraits")
	check("a switched-off option reads off",
		table.concat(chatlog, "\n", before3 + 1):find("off", 1, true) ~= nil)
	ns:Set("hideBossPortraits", true)

	-- A sub-option under a parent that is off is doing nothing, whichever way
	-- it is asked for.
	ns:Set("trackerPlainText", false)
	before3 = #chatlog
	pcall(SlashCmdList["VANILLAQUESTING"], "status trackerPlainTextAchievements")
	check("a sub-option under an off parent reads off",
		ns:IsActive("trackerPlainTextAchievements") == false and
		table.concat(chatlog, "\n", before3 + 1):find("off", 1, true) ~= nil)

	before3 = #chatlog
	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "status wibble")
	check("/vq status with a bad name runs", ok, err)
	check("and complains rather than listing everything",
		table.concat(chatlog, "\n", before3 + 1):find("Unknown option", 1, true) ~= nil)

	ns:ResetDefaults(true)
end

-- There was an `os.exit(1)` here on any failure so far. It stopped every
-- check below it from running and the summary line from printing, so one
-- failure in the first half hid whatever the second half would have said.
-- The exit status at the foot of the file carries the verdict; a check that
-- falls over because an earlier one failed is caught by run.sh as a scenario
-- that did not reach its summary.

if scenario == "native" or scenario == "no_tooltipfunc" or scenario == "no_template" then
	-- The whole point of the native path: these are Blizzard's controls, so
	-- the tests are about the contract with Blizzard, not about our pixels.
	check("native path taken", ns.optionsNative == true)
	local created = _G.__nativeControls or {}
	local boxes, drops = {}, {}
	for _, c in ipairs(created) do
		if c.kind == "checkbox" then boxes[#boxes + 1] = c
		elseif c.kind == "dropdown" then drops[#drops + 1] = c end
	end
	check("one dropdown created", #drops == 1, #drops)
	check("one checkbox per module", #boxes == #ns.modules, #boxes .. " vs " .. #ns.modules)
	check("dropdown comes first", created[1] and created[1].kind == "dropdown",
		created[1] and created[1].kind)

	-- Ordering: the plain options in ns:SortedModules() order, then the
	-- experiments in the same order, so the heading has something to head.
	local sorted = ns:SortedModules()
	local want = {}
	for _, m in ipairs(sorted) do if not m.experimental then want[#want + 1] = m.key end end
	for _, m in ipairs(sorted) do if m.experimental then want[#want + 1] = m.key end end
	local got = {}
	for _, c in ipairs(boxes) do
		got[#got + 1] = c.setting:GetVariable():gsub("VanillaQuesting_", "")
	end
	check("checkboxes follow ns:SortedModules(), experiments last",
		table.concat(got, ",") == table.concat(want, ","), table.concat(got, ","))

	-- Argument order. If RegisterAddOnSetting were called with name and
	-- variable swapped the client would accept it silently, so assert it.
	local first = boxes[1] and boxes[1].setting
	local firstModule = ns.modules[got[1]]
	if first then
		check("setting name is the label, not the variable",
			first:GetName() == firstModule.title, first:GetName())
		check("setting type is boolean", first:GetVariableType() == "boolean", first:GetVariableType())
		check("setting default matches ns.defaults",
			first:GetDefaultValue() == (ns.defaults[got[1]] and true or false))
		check("setting reads the live DB value",
			first:GetValue() == ns.db.settings[got[1]])
	end

	-- Two headings: Experimental in orange, and the version as a grey footer.
	-- The experimental note is NOT a heading here -- drawing it with the
	-- heading element looked like a second heading, so in this panel it rides
	-- on the Experimental heading's tooltip until [G23] finds a real
	-- description element. The canvas panel draws it properly.
	local headers = _G.__headers or {}
	-- One per category, plus the version footer.
	local groups = {}
	for i = 1, #ns.modules do groups[ns.modules[i].group or "?"] = true end
	local nGroups = 0
	for _ in pairs(groups) do nGroups = nGroups + 1 end
	check("a heading for every category, plus the version footer",
		#headers == nGroups + 1, #headers .. " for " .. nGroups .. " categories")
	check("the experimental note is not drawn as a heading",
		table.concat(headers, "\1"):find(EXPERIMENTAL_NOTE_TEXT, 1, true) == nil,
		table.concat(headers, " | "))
	local expHeader, verHeader
	-- `head`, not `h`: `h` at the top of this file is the harness loader.
	for _, head in ipairs(headers) do
		if head:find("Experimental", 1, true) then expHeader = head else verHeader = head end
	end

	-- The note is a DESCRIPTION ROW, drawn with the template the AddOn ships
	-- in Templates.xml, because Blizzard has no element for it. Where that
	-- template is missing the text falls back to the heading's tooltip, and
	-- the two must never both happen or the player reads it twice.
	local rows = table.concat(_G.__descriptionRows or {}, "\1")
	local headTip = _G.__headerTooltips and _G.__headerTooltips["Experimental"]
	if scenario == "no_template" then
		check("without the template there is no description row",
			rows:find(EXPERIMENTAL_NOTE_TEXT, 1, true) == nil, rows)
		check("and the note falls back to the heading's tooltip",
			headTip and headTip:find(EXPERIMENTAL_NOTE_TEXT, 1, true) ~= nil,
			tostring(headTip))
	else
		check("the note is a description row under the heading",
			rows:find(EXPERIMENTAL_NOTE_TEXT, 1, true) ~= nil, rows)
		-- Yellow, not the heading's orange. Reported from play: orange under
		-- an orange heading reads as a second heading, or as a warning about
		-- the options rather than a sentence describing them. The mark stays
		-- on the heading and on the option names, where it means something.
		check("it is the ordinary yellow, not the experimental orange",
			rows:find("|cffffd100", 1, true) ~= nil
			and rows:find("|cffff8019", 1, true) == nil, rows)
		check("and the heading has no tooltip, so it is not said twice",
			headTip == nil, tostring(headTip))
	end

	-- It is a description, not an instruction. The sentence telling the player
	-- to switch them on themselves was removed; this guards it staying gone,
	-- wherever the note ends up.
	check("the experimental note does not tell the player what to do",
		(rows .. "\1" .. tostring(headTip)):find("yourself", 1, true) == nil,
		rows .. " | " .. tostring(headTip))

	-- The option NAME carries the colour, and the tooltip's TITLE must not.
	-- v1.0.0 coloured the registered setting name, and the orange came through
	-- in both -- this client draws the label and the tooltip's first line from
	-- the same string.
	do
		local expBox, normalBox
		for _, b in ipairs(boxes) do
			local key = b.setting:GetVariable():gsub("VanillaQuesting_", "")
			if ns.modules[key] and ns.modules[key].experimental then
				expBox = expBox or b
			else
				normalBox = normalBox or b
			end
		end

		-- An experimental option's name IS coloured here, and its tooltip
		-- title comes out orange with it. Both are deliberate.
		--
		-- [G23] settled the mechanism: the checkbox label and the tooltip
		-- title both come from `data.name`, and there is no SetTooltipFunc to
		-- take the tooltip over with. Orange in both or neither.
		--
		-- v1.0.0 chose neither, on the grounds that an orange tooltip title
		-- would look like a defect while a plain label was only a preference
		-- unmet. Reversed: the thing that is experimental is the option, the
		-- list is what gets scanned, and a mark present in the canvas panel
		-- but absent from the native one means the two panels disagree about
		-- what an experimental option looks like.
		check("an experimental option's registered name is orange",
			expBox and expBox.setting:GetName():find("|cffff8019", 1, true) ~= nil,
			expBox and expBox.setting:GetName() or "none")
		check("and a normal option's is not coloured at all",
			normalBox and normalBox.setting:GetName():find("|cff", 1, true) == nil,
			normalBox and normalBox.setting:GetName() or "none")

		local expTip = expBox and _G.__renderCheckboxTooltip(expBox)
		local title = expTip and expTip[1]
		check("so the tooltip title carries the same orange",
			title and tostring(title.text):find("|cffff8019", 1, true) ~= nil,
			title and tostring(title.text) or "no title")

		-- The two panels have to agree. The canvas one colours the label by
		-- SetTextColor rather than an escape, so this asserts the intent
		-- reaches both rather than comparing the mechanisms.
		check("the option name is marked in this panel as well as the canvas one",
			(expBox and expBox.data.name:find("|cffff8019", 1, true) ~= nil)
				and (normalBox and normalBox.data.name:find("|cff", 1, true) == nil),
			(expBox and expBox.data.name or "none") .. " / "
				.. (normalBox and normalBox.data.name or "none"))
	end
	check("the Experimental heading is orange",
		expHeader and expHeader:find("|cffff8019", 1, true) ~= nil, tostring(expHeader))
	check("the version heading is grey",
		verHeader and verHeader:find("|cff808080", 1, true) ~= nil, tostring(verHeader))
	check("the version heading carries the .toc version",
		verHeader and verHeader:find("v" .. ns.version, 1, true) ~= nil, tostring(verHeader))
	check("the version footer is last",
		created[#created] and created[#created].kind == "header"
			and created[#created].text:find("|cff808080", 1, true) ~= nil)

	-- The header must come between the plain options and the experiments.
	local sawExpHeader, plainAfterHeader = false, false
	for _, c in ipairs(created) do
		if c.kind == "header" and c.text:find("Experimental", 1, true) then sawExpHeader = true
		elseif c.kind == "checkbox" and sawExpHeader then
			local key = c.setting:GetVariable():gsub("VanillaQuesting_", "")
			if not ns.modules[key].experimental then plainAfterHeader = true end
		end
	end
	check("only experimental options sit below the heading", not plainAfterHeader)

	-- Tooltips. Bodies are yellow, as the canvas panel drew them; the
	-- experimental warning is orange; the slash handle is grey. Painting the
	-- body white was a regression and this is the guard against repeating it.
	-- `sawWhiteBody` was collected here and never asserted -- a guard that was
	-- not guarding, found by luacheck (#37) as a variable never accessed. It
	-- is gone rather than given an assertion: white inside a body is
	-- deliberate now (one description names a Blizzard control in white), so
	-- there is nothing left to forbid. What must not happen is a body that is
	-- white INSTEAD of yellow, and `sawYellow` is what says that.
	local sawOrange, sawGrey, sawYellow = false, false, false
	local sawPresetWording = false
	for _, c in ipairs(boxes) do
		if c.tooltip:find("|cffff8019", 1, true) then sawOrange = true end
		if c.tooltip:find("untested and potentially unstable", 1, true) then
			sawPresetWording = true
		end
		if c.tooltip:find("|cff808080", 1, true) then sawGrey = true end
		if c.tooltip:find("|cffffd100", 1, true) then sawYellow = true end
	end
	check("option tooltip bodies are yellow", sawYellow)
	-- White inside a body is now deliberate: one description names a Blizzard
	-- control and paints it white. What must not happen is a body that is
	-- white INSTEAD of yellow.
	local notYellowFirst
	for _, c in ipairs(boxes) do
		if c.tooltip:sub(1, 10) ~= "|cffffd100" then
			notYellowFirst = c.setting:GetVariable()
		end
	end
	check("option tooltip bodies still open in yellow", notYellowFirst == nil,
		tostring(notYellowFirst))
	check("the experimental tooltip paints orange", sawOrange)
	check("the experimental note warns it is untested", sawPresetWording)

	-- The limitation line, which is a different thing from the experimental
	-- warning and is the one that carries a real cost.
	local tips = {}
	for _, c in ipairs(boxes) do
		tips[c.setting:GetVariable():gsub("VanillaQuesting_", "")] = c.tooltip
	end
	-- #54: the minimap entry takes the pins and the blue areas off and leaves
	-- the questgiver marks, which are engine-drawn and have no lever at all.
	-- A player reading "Hide Minimap Quest Helper" would expect otherwise.
	check("the minimap option says the ! and ? stay",
		tips.hideMinimapQuestHelper and
		tips.hideMinimapQuestHelper:find("! and ?", 1, true) ~= nil,
		tips.hideMinimapQuestHelper)
	check("the sparkle option states what else it removes",
		tips.noQuestSparkles and
		tips.noQuestSparkles:find("gathering nodes", 1, true) ~= nil,
		tips.noQuestSparkles)
	-- The prefix is part of the string, not something the panel adds, and this
	-- option shipped once without it. Asserted on every option that has a
	-- limitation rather than on this one, so the next author cannot drop it
	-- somewhere else.
	for i = 1, #ns.modules do
		local m = ns.modules[i]
		if type(m.limitation) == "string" then
			check(m.key .. "'s limitation is labelled as one",
				m.limitation:find("^Known limitation: ") ~= nil, m.limitation)
		end
	end
	check("and does not claim to be experimental",
		tips.noQuestSparkles and
		tips.noQuestSparkles:find("untested and potentially unstable", 1, true) == nil,
		tips.noQuestSparkles)
	-- No Outline Mode lost its limitation with its old shape: the old text
	-- explained that outlines and sparkles were an either/or and that outlines
	-- did not render here. Neither is a cost of an option that REMOVES
	-- outlines, and the sparkles have their own switch now.
	check("No Outline Mode carries no limitation any more",
		tips.noOutlineMode and
		tips.noOutlineMode:find("Known limitation", 1, true) == nil,
		tips.noOutlineMode)
	check("nor the experimental warning", tips.noOutlineMode and
		tips.noOutlineMode:find("untested and potentially unstable", 1, true) == nil,
		tips.noOutlineMode)
	-- It read `sawGrey or true`, which cannot fail. Grey was the slash handle
	-- at the foot of each tooltip; the handle was removed, so what is left to
	-- guard is that the grey does not come back with it.
	check("no option tooltip carries the retired grey handle colour", not sawGrey)
	local noSlash = true
	for _, c in ipairs(boxes) do
		local key = c.setting:GetVariable():gsub("VanillaQuesting_", "")
		if c.tooltip:find("/" .. key, 1, true) then noSlash = false end
	end
	check("no option tooltip carries a slash handle", noSlash)

	if drops[1] then
		local tip = drops[1].tooltip
		check("preset tooltip opens with a line break", tip:sub(1, 2) == "|n", tip:sub(1, 6))
		check("preset tooltip headings are white", tip:find("|cffffffff", 1, true) ~= nil)
		check("preset tooltip bodies are yellow", tip:find("|cffffd100", 1, true) ~= nil)
		-- "(Default)" is gone from the vanilla label (#55): the dropdown opens
		-- on it anyway, and the word said nothing the panel did not.
		check("preset tooltip puts the colon inside the white run",
			tip:find("|cffffffffVanilla:|r", 1, true) ~= nil, tip)
		check("and the vanilla label no longer says Default",
			tip:find("(Default)", 1, true) == nil, tip)
		-- "when neither preset matches your options", not "when you change any
		-- option below": Custom is a description of a state, and the old
		-- wording described one way of reaching it.
		check("preset tooltip says Custom describes a state, not an action",
			tip:find("neither preset matches your options", 1, true) ~= nil, tip)
		-- Enables/Disables, describing what the preset does rather than
		-- instructing the reader to do it.
		check("the tooltip describes rather than instructs",
			tip:find("Enables all options", 1, true) ~= nil
			and tip:find("Disables all options", 1, true) ~= nil, tip)
		-- The count only appears when an experiment is on, so the tooltip
		-- says what it would mean to a player who has never switched one on.
		check("and explains the experimental count, in orange",
			tip:find("|cffff8019Number of experimental options", 1, true) ~= nil, tip)
		-- Each preset says what it does about the experiments, because that
		-- is the one thing the two differ on that the labels cannot show.
		check("and each preset says where the experiments stand",
			tip:find("except experimental.", 1, true) ~= nil
			and tip:find("including experimental.", 1, true) ~= nil, tip)
		-- Vanilla, the client, then Custom -- which is last because it is the
		-- one that cannot be chosen.
		check("the tooltip orders them vanilla, client, custom",
			tip:find("Vanilla", 1, true) < tip:find("Disables all", 1, true)
			and tip:find("Disables all", 1, true) < tip:find("Custom", 1, true), tip)

		-- #55: "custom" is not a way to GET to Custom. It is listed only when
		-- it is the value being shown, because a label the AddOn does not
		-- supply is a label it cannot put the experimental count on (#43) --
		-- which is exactly what happened on the build that removed it
		-- outright.
		-- #43, the half that reached play as a bug: the count was on Vanilla
		-- and missing on Custom, because removing "custom" from the entries
		-- meant the label was no longer the AddOn's to write.
		do
			local function labelFor(presetId)
				local opts = _G.__rebuildPresetOptions and _G.__rebuildPresetOptions() or nil
				if not opts then return nil end
				for _, o in ipairs(opts) do
					if o.value == presetId then return o.label or o.text end
				end
			end
			-- Every vanilla option on, one experiment on -> Vanilla (1 ...)
			ns:ResetDefaults(true)
			ns:Set("noCompleteQuestPopup", true)
			check("the vanilla preset carries the experimental count",
				(labelFor("classic") or ""):find("1 experimental on", 1, true) ~= nil,
				labelFor("classic"))
			-- **Only the selected one.** Blizzard's dropdown draws the closed
			-- control from the selected entry's label, so that is where the
			-- count has to go -- and every other row stays plain, which is
			-- what the list should read.
			check("and no other row carries it",
				(labelFor("disabled") or ""):find("experimental on", 1, true) == nil,
				labelFor("disabled"))
			-- Now move a normal option, so the state is Custom.
			ns:Set("hideBossPortraits", false)
			check("and so does custom, which is the case that reached play",
				(labelFor("custom") or ""):find("1 experimental on", 1, true) ~= nil,
				labelFor("custom"))
			check("while vanilla, no longer selected, goes plain again",
				(labelFor("classic") or ""):find("experimental on", 1, true) == nil,
				labelFor("classic"))
			check("custom is listed only while it is the value being shown",
				labelFor("custom") ~= nil, "missing while in custom")
			ns:Set("noCompleteQuestPopup", false)
			ns:ResetDefaults(true)
			check("and is gone again once a preset matches",
				labelFor("custom") == nil, labelFor("custom"))
		end

		check("the dropdown offers two presets while a preset is matched",
			#drops[1].options == 2, #drops[1].options)
		check("and they are vanilla then the client",
			table.concat({ drops[1].options[1].value,
				drops[1].options[2].value }, ",") == "classic,disabled",
			table.concat({ drops[1].options[1].value,
				drops[1].options[2].value }, ","))
	end

	-- Apply. A map option carries the Apply and Revertable flags, so ticking
	-- it parks the value; only Apply writes it through.
	local mapKey = "hideMapQuestHelper"
	local mapSetting
	for _, c in ipairs(boxes) do
		if c.setting:GetVariable() == "VanillaQuesting_" .. mapKey then mapSetting = c.setting end
	end
	if mapSetting then
		check("a map option asks for the Apply button",
			mapSetting:HasCommitFlag(Settings.CommitFlag.Apply))
		check("a map option is revertable",
			mapSetting:HasCommitFlag(Settings.CommitFlag.Revertable))

		local was = ns.db.settings[mapKey]
		_G.__popup = nil
		local r0 = _G.__reloads
		ok, err = pcall(mapSetting.SetValue, mapSetting, not was)
		check("ticking it does not error", ok, err)
		check("ticking raises no dialog", _G.__popup == nil, tostring(_G.__popup))
		check("the value is parked, not written", ns.db.settings[mapKey] == was)
		check("nothing reloaded on the tick", _G.__reloads == r0)

		-- The preset must see the parked value. Without this the dropdown
		-- reads the pre-click state until Apply is pressed.
		check("a parked change is visible to the preset",
			ns.EffectiveSetting(mapKey) == (not was))

		pcall(ns.RefreshOptions)
		check("a refresh does not discard the pending change", mapSetting:IsModified())

		_G.__popup = nil
		pcall(_G.pressApply)
		check("Apply writes the value through", ns.db.settings[mapKey] == (not was))
		-- Pressing Apply IS the confirmation. Asking again was wrong twice
		-- over: it double-questions one decision, and Blizzard already asks
		-- its own question on Cancel.
		check("Apply never asks", _G.__popup == nil, tostring(_G.__popup))
		check("Apply rebuilds straight away", _G.__reloads == r0 + 1, _G.__reloads - r0)

		-- #24, second pass: Apply keeps working in combat.
		--
		-- Build 1 put the value back and refused. Rejected in play: Apply is
		-- Blizzard's own button on a panel the player is reading, and it has
		-- to do what it says. Whether the client permits the reload from
		-- there is a question only the game answers.
		local wasC = ns.db.settings[mapKey]
		local rc = _G.__reloads
		_G.__inCombat = true
		pcall(mapSetting.SetValue, mapSetting, not wasC)
		pcall(_G.pressApply)
		check("Apply in combat writes the value through",
			ns.db.settings[mapKey] == (not wasC), tostring(ns.db.settings[mapKey]))
		check("and rebuilds, like it does out of combat",
			_G.__reloads == rc + 1, _G.__reloads - rc)
		_G.__inCombat = false
		ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls
	end

	-- An option that needs no rebuild takes effect at once and never asks.
	local instant
	for _, c in ipairs(boxes) do
		local key = c.setting:GetVariable():gsub("VanillaQuesting_", "")
		if not ns.modules[key].needsApply then instant = c.setting end
	end
	if instant then
		check("an instant option does not ask for Apply",
			not instant:HasCommitFlag(Settings.CommitFlag.Apply))
		local r0 = _G.__reloads
		_G.__popup = nil
		local key = instant:GetVariable():gsub("VanillaQuesting_", "")
		pcall(instant.SetValue, instant, not ns.db.settings[key])
		check("an instant option writes straight through",
			instant:GetValue() == ns.db.settings[key])
		check("an instant option never reloads", _G.__reloads == r0)
		check("an instant option raises no dialog", _G.__popup == nil)
	end

	-- The preset reads the settings, never a stored label. Turning every
	-- option off by hand used to leave the control stuck on "Custom".
	pcall(_G.pressApply)
	if _G.popupAccept then pcall(_G.popupAccept) end
	for i = 1, #ns.modules do ns.db.settings[ns.modules[i].key] = false end
	pcall(ns.RefreshOptions)
	check("all-off reads as Disabled, not Custom",
		drops[1] and drops[1].setting:GetValue() == "disabled",
		drops[1] and drops[1].setting:GetValue())

	for i = 1, #ns.modules do
		local m = ns.modules[i]
		ns.db.settings[m.key] = not m.experimental
	end
	pcall(ns.RefreshOptions)
	check("the Classic set reads as Full Classic experience",
		drops[1] and drops[1].setting:GetValue() == "classic",
		drops[1] and drops[1].setting:GetValue())

	-- Choosing a preset must go THROUGH the controls, or Blizzard never
	-- learns anything changed and the Apply button stays dark.
	if drops[1] then
		_G.__popup = nil
		ok, err = pcall(drops[1].setting.SetValue, drops[1].setting, "disabled")
		check("choosing Disabled does not error", ok, err)
		check("a preset parks its reload-needing options for Apply",
			mapSetting and mapSetting:IsModified())
		check("a preset still reads as Disabled while parked",
			drops[1].setting:GetValue() == "disabled", drops[1].setting:GetValue())
		-- The preset is not stored at all any more; it is read back off the
		-- settings, which is the only place it cannot go stale.
		check("the preset is not stored in saved variables",
			VanillaQuestingDB.preset == nil, tostring(VanillaQuestingDB.preset))

		pcall(_G.pressApply)
		if _G.popupAccept then pcall(_G.popupAccept) end
		local allOff = true
		for i = 1, #ns.modules do
			if ns.db.settings[ns.modules[i].key] then allOff = false end
		end
		check("Apply finishes the preset off", allOff)
	end

	-- Refreshing writes values into the controls, which would re-enter the
	-- changed-callback if the suppress flag were missing.
	local depth0 = maxEventDepth()
	ok, err = pcall(ns.RefreshOptions)
	check("refresh does not error", ok, err)
	check("refresh does not re-enter the callbacks", maxEventDepth() == depth0)

	-- Defaults. Blizzard resets our settings without parking them for Apply,
	-- so the AddOn lights the button itself and catches the commit -- otherwise
	-- a reload-needing option resets with nothing on screen saying the panel
	-- is not finished.
	if mapSetting then
		-- Move a reload-needing option, THEN open the panel: the baseline is
		-- what the player is looking at when they arrive, so a Defaults reset
		-- back to the shipped value is a real change from here.
		ns:Set(mapKey, not (ns.defaults[mapKey] and true or false))
		_G.__openSettingsPanel()
		local r0 = _G.__reloads
		-- Watch the button through a hook rather than replacing the method:
		-- replacing it would unhook the AddOn's own listener, which is the
		-- thing under test.
		_G.__applyEnabled = nil
		_G.__hookApply(function(_, on) _G.__applyEnabled = on end)

		-- What Blizzard's Defaults does: write each value through, no parking.
		--
		-- The value is in place BEFORE the callback fires, which is what
		-- SetValueToDefault does. Setting it to the opposite first and
		-- restoring it afterwards -- the previous shape of this loop -- meant
		-- the first reload-needing option saw its own value still matching the
		-- baseline, and the check only passed because a second one came later
		-- in the order and saw the first one's restored value. It was testing
		-- the option list, not the rebuild.
		for _, c in ipairs(boxes) do
			local key = c.setting:GetVariable():gsub("VanillaQuesting_", "")
			ns.db.settings[key] = ns.defaults[key] and true or false
			pcall(c.setting.__cb, c.setting, ns.defaults[key])
		end
		check("a Defaults-style reset rebuilds straight away",
			_G.__reloads == r0 + 1, _G.__reloads - r0)
		check("without lighting the Apply button itself", _G.__applyEnabled ~= true,
			tostring(_G.__applyEnabled))
	end

	-- ---- the freeze, as a test ----
	--
	-- v0.12.0 locked the client solid the moment ANY options panel opened.
	-- suppress was a boolean, and the Apply-button hook re-enters RefreshNative;
	-- when the inner call finished it cleared the flag while the outer loop was
	-- still writing, so every remaining SetValue fired its callback, which
	-- refreshed again, without bound. The harness had no SettingsPanel and so
	-- could not see any of it -- 345 checks passed on a build that froze the
	-- game. These are the checks that would have caught it.
	_G.__applyCalls = 0
	ok, err = pcall(_G.__openSettingsPanel)
	check("opening the settings panel does not hang", ok, err)
	check("opening it does not storm the Apply button", _G.__applyCalls < 50, _G.__applyCalls)

	_G.__applyCalls = 0
	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "")
	check("/vq does not hang", ok, err)

	-- Directly: a refresh triggered from inside the Apply hook must not leave
	-- the outer refresh writing with its guard cleared.
	_G.__applyCalls = 0
	ok, err = pcall(function()
		SettingsPanel:SetApplyButtonEnabled(true)
		ns.RefreshOptions()
		SettingsPanel:SetApplyButtonEnabled(false)
	end)
	check("nested refresh and Apply signalling terminates", ok, err)
	check("and does not storm", _G.__applyCalls < 50, _G.__applyCalls)

	-- Every route into the panel, hammered.
	_G.__applyCalls = 0
	ok, err = pcall(function()
		for _ = 1, 5 do
			_G.__openSettingsPanel()
			ns.RefreshOptions()
			pcall(SlashCmdList["VANILLAQUESTING"], "on")
			pcall(SlashCmdList["VANILLAQUESTING"], "off")
			ns:ResetDefaults(true)   -- /vq reset is retired; this is what Defaults calls
		end
	end)
	check("repeated opening and slash use terminates", ok, err)
end

if scenario == "native_halfway" then
	check("half-registration falls back rather than half-working",
		ns.optionsNative ~= true)
	check("the canvas panel is there instead", ns.OpenOptions ~= nil)
	ok, err = pcall(ns.OpenOptions, ns)
	check("options still open", ok, err)

	-- #7: no live status readout on a row.
	--
	-- Every row carried one, in grey on the right: the tracking index, what
	-- the CVar read, whether a write had been refused. Useful while building
	-- the thing and meaningless to a player -- and this is the panel a player
	-- only ever sees when the native registration has failed, which is the
	-- worst moment to show them diagnostics.
	--
	-- Asserted through what the readout SAID rather than by counting frames:
	-- the minimap module's Status() is the one with words of its own, so its
	-- text appearing anywhere in the panel means the readout is back.
	pcall(ns.RefreshOptions)
	local readout
	for _, fs in ipairs(_G.fontstrings) do
		local t = fs.GetText and fs:GetText()
		if type(t) == "string" and t:find("tracking entry", 1, true) then
			readout = t
		end
	end
	check("no row carries a live status readout", readout == nil, readout)
end

if scenario == "normal" or scenario == "no_button_type" then
	-- ---- The objective tracker ----
	--
	-- Nothing here hides the tracker. Classic has one; you shift-click a quest
	-- in the log and it appears. What gets removed is what MoP bolted on.
	check("tracker click-to-track module exists", ns.modules.trackerPlainText ~= nil)
	check("tracker item-button module exists", ns.modules.hideTrackerItemButtons ~= nil)
	check("turn-in pop-ups are experimental",
		ns.modules.noCompleteQuestPopup and ns.modules.noCompleteQuestPopup.experimental == true)
	check("no module hides the tracker outright", ns.modules.trackerHide == nil)

	ns:ResetDefaults(true)
	check("click-to-track is on by default", ns.db.settings.trackerPlainText == true)
	check("item buttons are hidden by default", ns.db.settings.hideTrackerItemButtons == true)
	check("turn-in pop-ups are off by default", ns.db.settings.noCompleteQuestPopup == false)

	-- Quest titles stop being clickable -- and ACHIEVEMENT lines do not.
	--
	-- Two separate facts on purpose. "Every button is dead" was the old check,
	-- and it passed for the whole of v1.0.0 while the AddOn was killing
	-- achievement clicks too, because nothing ever asked which button was
	-- which. A check that cannot tell the bug from the fix is not a check.
	local function mouseState()
		local quest, achievement
		for _, b in ipairs(WATCHFRAME_LINKBUTTONS) do
			if b.__name == "link1" then quest = b:IsMouseEnabled() end
			if b.__name == "link2" then achievement = b:IsMouseEnabled() end
		end
		return quest, achievement
	end

	WatchFrame_Update()
	local questLive, achievementLive = mouseState()
	check("tracker quest titles are not clickable", questLive == false)
	check("achievement lines follow the sub-option, which ships on",
		achievementLive == false)

	-- The sub-option is the whole point of reading the tag: turning it off has
	-- to leave achievement lines alone while quest lines stay silenced. On a
	-- client whose pool carries no tag there is nothing to be selective with,
	-- and everything stays disabled -- an option that removes nothing being
	-- worse than one with a stated cost.
	ns:Set("trackerPlainTextAchievements", false)
	WatchFrame_Update()
	local q2, a2 = mouseState()
	check("quest titles stay silenced with the sub-option off", q2 == false)
	if scenario == "no_button_type" then
		check("untagged pool: the sub-option cannot spare achievements", a2 == false)
	else
		check("turning the sub-option off gives achievement clicks back", a2 == true)
	end
	ns:Set("trackerPlainTextAchievements", true)
	WatchFrame_Update()

	-- A sub-option whose parent is off is doing nothing, and every readout has
	-- to say so. Reported in play: the panel kept the tick, /vq status said
	-- "on", and the tracker was plainly clickable -- the readout arguing with
	-- the game.
	check("a sub-option is active while its parent is on",
		ns:IsActive("trackerPlainTextAchievements") == true)

	-- #45: the child follows its parent's switch, in both directions.
	--
	-- This asserted the opposite for four versions -- "its saved value
	-- survives the parent going off" -- which was Blizzard's greyed-child
	-- behaviour and was deliberate. Reported from play as the wrong call: the
	-- child ships on, the common case is a player switching the whole feature
	-- back on and expecting all of it, and a box holding a value that is
	-- doing nothing reads as "on" to everyone who looks at it.
	ns.db.settings.trackerPlainTextAchievements = false
	ns:Set("trackerPlainText", true)
	check("switching the parent on switches the child on with it",
		ns.db.settings.trackerPlainTextAchievements == true)

	-- Set again rather than relying on the line above having worked: with the
	-- cascade removed, a child left off by the first half would satisfy the
	-- second half for the wrong reason, and a check that cannot fail is not a
	-- check.
	ns.db.settings.trackerPlainTextAchievements = true
	ns:Set("trackerPlainText", false)
	check("and switching the parent off takes the child off too",
		ns.db.settings.trackerPlainTextAchievements == false)
	check("so it is not active", ns:IsActive("trackerPlainTextAchievements") == false)

	-- Setting the child alone still moves only the child: the cascade is a
	-- consequence of the PARENT moving, not a rule that the two are one
	-- option.
	ns.db.settings.trackerPlainTextAchievements = true
	ns:Set("trackerPlainTextAchievements", false)
	check("the child on its own does not drag the parent anywhere",
		ns.db.settings.trackerPlainText == false)
	ns.db.settings.trackerPlainTextAchievements = true

	local b5 = #chatlog
	pcall(SlashCmdList["VANILLAQUESTING"], "status")
	local childLine
	for i = b5 + 1, #chatlog do
		local line = tostring(chatlog[i])
		if line:find("trackerPlainTextAchievements", 1, true) then childLine = line end
	end
	check("/vq status reports the sub-option as off while the parent is",
		childLine ~= nil and childLine:find("off", 1, true) ~= nil, tostring(childLine))

	ns:Set("trackerPlainText", true)
	check("and active again once the parent is back",
		ns:IsActive("trackerPlainTextAchievements") == true)
	-- Alpha and mouse, not Hide(). #16: these are the quest-item USE buttons,
	-- the part of the tracker most likely to be secure, and alpha is not a
	-- protected operation -- so the combat question stops existing rather than
	-- resting on a measurement that could change on any patch.
	check("quest item buttons are made invisible",
		WatchFrameItem1:GetAlpha() == 0, WatchFrameItem1:GetAlpha())
	check("and unclickable with it", WatchFrameItem1:IsMouseEnabled() == false)
	check("but not hidden -- the frame is left alone", WatchFrameItem1:IsShown() == true)

	-- The tracker rebuilds constantly and puts its buttons back each time. A
	-- one-shot fix at login would pass a naive test and fail in play.
	WatchFrame_Update()
	WatchFrame_Update()
	local questStill, achievementStill = mouseState()
	check("still not clickable after further rebuilds", questStill == false)
	check("achievement lines still follow the sub-option after rebuilds",
		achievementStill == false)
	check("item buttons stay invisible after further rebuilds",
		WatchFrameItem1:GetAlpha() == 0, WatchFrameItem1:GetAlpha())

	-- And turning it off hands the buttons back exactly as they were, without
	-- driving WatchFrame_Update -- the same rule as the bags (#20). The
	-- previous alpha is recorded ONCE: a later pass reads back the 0 this
	-- AddOn set, so re-recording would make "what it was before" mean 0 for
	-- ever after.
	do
		local before = WatchFrameItem1:GetAlpha()
		ns:Set("hideTrackerItemButtons", false)
		check("switching it off restores the alpha",
			WatchFrameItem1:GetAlpha() == 1, WatchFrameItem1:GetAlpha())
		check("and the mouse with it", WatchFrameItem1:IsMouseEnabled() == true)
		check("and it was 0 while the option was on", before == 0, before)

		ns:Set("hideTrackerItemButtons", true)
		WatchFrame_Update()
		WatchFrame_Update()
		ns:Set("hideTrackerItemButtons", false)
		check("and an on/off cycle across rebuilds still restores 1",
			WatchFrameItem1:GetAlpha() == 1, WatchFrameItem1:GetAlpha())
		ns:Set("hideTrackerItemButtons", true)
	end

	-- Turning it off must hand the clicks back: a subtractive AddOn leaves no
	-- trace when disabled.
	ns:Set("trackerPlainText", false)
	local handedBack = true
	for _, b in ipairs(WATCHFRAME_LINKBUTTONS) do
		if not b:IsMouseEnabled() then handedBack = false end
	end
	check("turning it off gives the clicks back", handedBack)

	ns:Set("hideTrackerItemButtons", false)
	WatchFrame_Update()
	check("turning it off shows the item buttons again", WatchFrameItem1:IsShown() == true)

	-- Turn-in pop-ups. The one unverified assumption in Tracker.lua is that
	-- GetAutoQuestPopUp's first return is the id RemoveAutoQuestPopUp wants,
	-- which is exactly why the option is experimental.
	_G.__setPopups({ 111, 222 })
	ns:Set("noCompleteQuestPopup", false)
	WatchFrame_Update()
	check("pop-ups are left alone while the option is off", GetNumAutoQuestPopUps() == 2)

	ns:Set("noCompleteQuestPopup", true)
	WatchFrame_Update()
	check("turning it on clears the queued pop-ups", GetNumAutoQuestPopUps() == 0)

	-- /vq status must cover the new modules without being told about them.
	local b4 = #chatlog
	pcall(SlashCmdList["VANILLAQUESTING"], "status")
	-- Counted per KEY, not per substring match. "trackerPlainText" is a
	-- prefix of "trackerPlainTextAchievements", so a naive count of hits
	-- scores the sub-option's line twice and the check moves whenever an
	-- option is named after another one.
	local seen, missing = {}, {}
	for i = b4 + 1, #chatlog do
		local line = tostring(chatlog[i])
		for _, k in ipairs({ "trackerPlainText", "trackerPlainTextAchievements",
			"hideTrackerItemButtons", "noCompleteQuestPopup" }) do
			if line:find(k, 1, true) then seen[k] = true end
		end
	end
	for _, k in ipairs({ "trackerPlainText", "trackerPlainTextAchievements",
		"hideTrackerItemButtons", "noCompleteQuestPopup" }) do
		if not seen[k] then missing[#missing + 1] = k end
	end
	check("/vq status lists the tracker options", #missing == 0,
		table.concat(missing, ", "))

	ns:ResetDefaults(true)
end

if scenario == "normal" then
	-- ---- Instant Quest Text ----
	--
	-- The variable is not a guess: [G19] read `instantQuestText` off Blizzard's
	-- own registered control by walking the settings registry. Classic-correct
	-- is OFF, so the AddOn drives it to 0.
	check("quest text module exists", ns.modules.noInstantQuestText ~= nil)
	-- Self-contained: an earlier block replaces the whole saved-variables
	-- table, so the remembered pre-AddOn value has to be re-established here
	-- rather than assumed to survive from login.
	ns:Set("noInstantQuestText", false)
	VanillaQuestingDB.state.instantQuestText = nil
	cvars.instantQuestText = "1"

	ns:Set("noInstantQuestText", true)
	check("Instant Quest Text is turned off", cvars.instantQuestText == "0",
		tostring(cvars.instantQuestText))
	check("the player's original value was remembered first",
		VanillaQuestingDB.state.instantQuestText == "1",
		tostring(VanillaQuestingDB.state.instantQuestText))
	ns:Set("noInstantQuestText", false)
	check("turning it off restores what the player had", cvars.instantQuestText == "1",
		tostring(cvars.instantQuestText))
	ns:Set("noInstantQuestText", true)

	-- ---- Bag quest highlight ----
	check("bag highlight module exists", ns.modules.noBagItemHighlight ~= nil)
	check("it is on by default", ns.db.settings.noBagItemHighlight == true)
	-- Intended behaviour, not a warning: the description explains it plainly
	-- and there is no orange limitation line.
	check("the description covers the exclamation mark",
		ns.modules.noBagItemHighlight.desc:find("exclamation mark", 1, true) ~= nil)
	check("it is not flagged as a limitation",
		ns.modules.noBagItemHighlight.limitation == nil)

	ContainerFrame_Update(ContainerFrame1)
	local allHidden = true
	for _, t in ipairs(_G.__bagTextures) do if t:IsShown() then allHidden = false end end
	check("quest highlights are hidden on a bag redraw", allHidden)

	-- Bags redraw on every item move; a one-shot hide would fail in play.
	ContainerFrame_Update(ContainerFrame1)
	ContainerFrame_Update(ContainerFrame1)
	local stillHidden = true
	for _, t in ipairs(_G.__bagTextures) do if t:IsShown() then stillHidden = false end end
	check("still hidden after further redraws", stillHidden)

	-- #20: turning it off must NOT call ContainerFrame_Update.
	--
	-- Hooking it is fine and is what Enable does; CALLING it runs Blizzard's
	-- container code on a path AddOn Lua is already on, and bag buttons are
	-- taint-sensitive. The comment in Bags.lua stated the right principle --
	-- let the game redraw and decide -- and then made the redraw happen.
	local redraws = _G.__bagRedraws
	ns:Set("noBagItemHighlight", false)
	check("turning it off does not drive Blizzard's container code",
		_G.__bagRedraws == redraws, _G.__bagRedraws - redraws)

	-- ...and yet the highlights come back AT ONCE, with the bags open.
	--
	-- Reported in play, and the asymmetry is the whole point: switching the
	-- option on removed them immediately, switching it off did nothing until
	-- an item moved. An option that acts at once in one direction and not the
	-- other reads as broken, whatever the reasoning behind it.
	--
	-- `scrub` hides only textures the game had SHOWN, so it knows exactly what
	-- it took. Putting those back is one Show() per Hide(), on a texture --
	-- not a redraw, and not Blizzard's container code.
	local anyBack = false
	for _, t in ipairs(_G.__bagTextures) do if t:IsShown() then anyBack = true end end
	check("the highlights come back immediately, bags open", anyBack)

	-- And nothing is invented. Slot 2 holds no quest item, so the game never
	-- draws its highlight and neither may the restore. Recording every texture
	-- rather than only the ones the game had shown would put one there, and
	-- that is the trap this has to avoid.
	--
	-- Asserted against the GAME's answer, not against a snapshot taken after a
	-- previous restore: a snapshot inherits whatever the last restore got
	-- wrong, and this check passed against the broken version for exactly that
	-- reason before it was written this way.
	local invented = {}
	for i, t in ipairs(_G.__bagTextures) do
		if t:IsShown() ~= (i ~= 2) then invented[#invented + 1] = i end
	end
	check("and no slot the game never highlighted gains one",
		#invented == 0, table.concat(invented, ","))

	ns:Set("noBagItemHighlight", true)
	ns:Set("noBagItemHighlight", false)
	invented = {}
	for i, t in ipairs(_G.__bagTextures) do
		if t:IsShown() ~= (i ~= 2) then invented[#invented + 1] = i end
	end
	check("and an off/on/off cycle leaves the same slots lit",
		#invented == 0, table.concat(invented, ","))

	-- And the AddOn stays out of the way afterwards: a later redraw leaves the
	-- game's own answer alone. Which is not "everything shown" -- slot 2 holds
	-- no quest item and the game hides its texture on every pass.
	ContainerFrame_Update(ContainerFrame1)
	local stayBack = true
	for i, t in ipairs(_G.__bagTextures) do
		if t:IsShown() ~= (i ~= 2) then stayBack = false end
	end
	check("and a later redraw is the game's answer, untouched", stayBack)

	ns:ResetDefaults(true)
end

if scenario == "native" or scenario == "no_tooltipfunc" or scenario == "no_template" then
	-- ---- Blizzard's own controls get told who is driving them ----
	--
	-- A player who finds Blizzard's "Instant Quest Text" checkbox has no way
	-- of knowing why it keeps moving unless it says so.
	local created2 = _G.__nativeControls or {}
	local boxes = {}
	for _, c in ipairs(created2) do
		if c.kind == "checkbox" then boxes[#boxes + 1] = c end
	end

	local inits = _G.__blizzInits or {}
	local byVar = {}
	for _, init in ipairs(inits) do byVar[init:GetSetting():GetVariable()] = init end

	check("an existing Blizzard tooltip is appended to, not replaced",
		byVar.instantQuestText
			and byVar.instantQuestText.data.tooltip:find("Quest text appears instantly.", 1, true) ~= nil
			and byVar.instantQuestText.data.tooltip:find("Managed by", 1, true) ~= nil,
		byVar.instantQuestText and byVar.instantQuestText.data.tooltip)
	check("a Blizzard option with no tooltip gets one",
		byVar.autoQuestWatch and byVar.autoQuestWatch.data.tooltip
			and byVar.autoQuestWatch.data.tooltip:find("Managed by", 1, true) ~= nil,
		byVar.autoQuestWatch and tostring(byVar.autoQuestWatch.data.tooltip))
	check("the annotation is the note and nothing else",
		byVar.autoQuestWatch
			and byVar.autoQuestWatch.data.tooltip:find("/noAutoQuestTracking", 1, true) == nil,
		byVar.autoQuestWatch and byVar.autoQuestWatch.data.tooltip)
	check("Outline Mode is annotated too",
		byVar.Outline and byVar.Outline.data.tooltip:find("Managed by", 1, true) ~= nil)
	check("an unrelated Blizzard option is left alone",
		byVar.somethingElse and byVar.somethingElse.data.tooltip == "Nothing to do with quests.",
		byVar.somethingElse and byVar.somethingElse.data.tooltip)

	-- Running twice must not stack the note.
	local before = byVar.instantQuestText.data.tooltip
	pcall(ns.AnnotateBlizzardOptions)
	pcall(ns.AnnotateBlizzardOptions)
	check("annotating repeatedly does not stack", byVar.instantQuestText.data.tooltip == before)

	-- ---- closing the panel ----
	--
	-- Nothing is ever held over a close now, so closing must be silent: no
	-- rebuild, no dialog. Two earlier designs left state behind here.
	local mapKey2 = "hideMapQuestHelper"
	local mapSetting2
	for _, c in ipairs(boxes) do
		if c.setting:GetVariable() == "VanillaQuesting_" .. mapKey2 then mapSetting2 = c.setting end
	end
	if mapSetting2 then
		_G.__openSettingsPanel()
		local r0 = _G.__reloads
		_G.__popup = nil
		ns.db.settings[mapKey2] = not (ns.db.settings[mapKey2] and true or false)
		pcall(mapSetting2.__cb, mapSetting2, ns.db.settings[mapKey2])

		-- Blizzard's Defaults button reloads the UI itself when a setting it
		-- reset needs one, so a Defaults-driven change rebuilds immediately.
		-- No Apply to light, no dialog: two earlier attempts at this were
		-- built on a guess about what that button does.
		check("a Defaults-style reset rebuilds at once", _G.__reloads == r0 + 1,
			_G.__reloads - r0)
		check("and asks nothing of its own", _G.__popup == nil, tostring(_G.__popup))

		-- Closing afterwards must not rebuild again.
		local r1 = _G.__reloads
		_G.__popup = nil
		_G.__closeSettingsPanel()
		check("closing afterwards does not rebuild again", _G.__reloads == r1, _G.__reloads - r1)
		check("and raises no dialog", _G.__popup == nil, tostring(_G.__popup))
	end

	-- ---- Defaults that changes nothing reload-worthy ----
	if mapSetting2 then
		_G.__openSettingsPanel()
		local r0 = _G.__reloads
		-- Reset every setting to what it already is: nothing has moved.
		for _, c in ipairs(boxes) do
			local key = c.setting:GetVariable():gsub("VanillaQuesting_", "")
			pcall(c.setting.__cb, c.setting, ns.db.settings[key])
		end
		pcall(SettingsPanel.CommitSettings, SettingsPanel)
		check("a reset that moves nothing does not rebuild", _G.__reloads == r0, _G.__reloads - r0)

		-- Pressing Defaults twice rebuilds once: the second press moves
		-- nothing, so there is nothing to rebuild for.
		_G.__openSettingsPanel()
		local r1 = _G.__reloads
		local was = ns.db.settings[mapKey2] and true or false
		ns.db.settings[mapKey2] = not was
		pcall(mapSetting2.__cb, mapSetting2, not was)
		check("the first Defaults press rebuilds", _G.__reloads == r1 + 1, _G.__reloads - r1)

		pcall(mapSetting2.__cb, mapSetting2, not was)
		check("a second press that moves nothing does not rebuild again",
			_G.__reloads == r1 + 1, _G.__reloads - r1)
		_G.__closeSettingsPanel()
	end
end

if scenario == "normal" then
	-- ---- yielding to Blizzard's own control ----
	--
	-- questPOI has no Blizzard control, so a change behind the player's back
	-- gets put back. instantQuestText HAS one, so a change is the player using
	-- their own interface and the AddOn stands down instead of fighting it.
	ns:ResetDefaults(true)

	cvars.questPOI = "1"
	fire("CVAR_UPDATE")
	check("a CVar with no Blizzard control is re-asserted", cvars.questPOI == "0", cvars.questPOI)
	check("and its option stays on", ns.db.settings.hideMapQuestHelper == true)

	local b4 = #chatlog
	cvars.instantQuestText = "1"
	fire("CVAR_UPDATE")
	check("a CVar the player owns is left where they put it",
		cvars.instantQuestText == "1", cvars.instantQuestText)
	check("and the matching option turns itself off",
		ns.db.settings.noInstantQuestText == false, tostring(ns.db.settings.noInstantQuestText))
	local told = false
	for i = b4 + 1, #chatlog do
		if tostring(chatlog[i]):find("Instant Quest Text", 1, true) then told = true end
	end
	check("and it says so rather than changing silently", told)
	check("the new value becomes what gets restored later",
		VanillaQuestingDB.state.instantQuestText == "1",
		tostring(VanillaQuestingDB.state.instantQuestText))

	-- The other direction. v0.14.0 only handled option-on -> variable-moved,
	-- so putting a Blizzard control BACK to the Classic value did nothing,
	-- and after one yield the option was off and never woke up again.
	b4 = #chatlog
	cvars.instantQuestText = "0"
	fire("CVAR_UPDATE")
	check("putting the Blizzard control back turns the option back on",
		ns.db.settings.noInstantQuestText == true, tostring(ns.db.settings.noInstantQuestText))
	told = false
	for i = b4 + 1, #chatlog do
		if tostring(chatlog[i]):find("is now", 1, true)
			and tostring(chatlog[i]):find("on", 1, true) then told = true end
	end
	check("and says so too", told)

	-- Repeatedly, in both directions: one yield must not deafen it.
	for round = 1, 3 do
		cvars.instantQuestText = "1"
		fire("CVAR_UPDATE")
		check("round " .. round .. ": follows the player off",
			ns.db.settings.noInstantQuestText == false)
		cvars.instantQuestText = "0"
		fire("CVAR_UPDATE")
		check("round " .. round .. ": follows the player back on",
			ns.db.settings.noInstantQuestText == true)
	end

	-- Outline is SHARED now, so it mirrors exactly as the other two do:
	-- whichever way the player moves Blizzard's control, the option follows.
	-- The polarity is the flip -- Outline 0 means the option is ON.
	ns:ResetDefaults(true)
	check("No Outline Mode ships on", ns.db.settings.noOutlineMode == true)
	cvars.Outline = "2"
	fire("CVAR_UPDATE")
	check("the player restoring outlines turns the option off",
		ns.db.settings.noOutlineMode == false,
		tostring(ns.db.settings.noOutlineMode))
	check("and the variable is left where they put it", cvars.Outline == "2", cvars.Outline)
	cvars.Outline = "0"
	fire("CVAR_UPDATE")
	check("and taking them away again turns it back on",
		ns.db.settings.noOutlineMode == true)

	-- 1 and 3 are outline settings too, and the option is against all of them.
	for _, v in ipairs({ "1", "2", "3" }) do
		cvars.Outline = v
		fire("CVAR_UPDATE")
		check("Outline = " .. v .. " unticks the option",
			ns.db.settings.noOutlineMode == false, tostring(ns.db.settings.noOutlineMode))
		cvars.Outline = "0"
		fire("CVAR_UPDATE")
		check("and 0 ticks it again", ns.db.settings.noOutlineMode == true)
	end

	ns:ResetDefaults(true)
end

if scenario == "normal" then
	-- One preset cannot mean two things depending on whether it was picked in
	-- the panel or typed. "/vq on" used to leave experimental options where
	-- they were while the panel's preset set them false.
	-- A preset that undoes a deliberate choice is worse than one that ignores
	-- it, so Full Classic leaves the experiments where the player put them.
	ns:Set("outlineMode", true)
	pcall(SlashCmdList["VANILLAQUESTING"], "on")
	check("/vq on leaves an experimental option switched on",
		ns.db.settings.outlineMode == true,
		tostring(ns.db.settings.outlineMode))
	local normalOn = true
	for i = 1, #ns.modules do
		local m = ns.modules[i]
		if not m.experimental and not ns.db.settings[m.key] then normalOn = false end
	end
	check("and still turns every normal option on", normalOn)

	-- Disabled means nothing is on, experiments included.
	--
	-- The exception this block used to carry is gone with the mirror: a mirror
	-- reported a Blizzard setting rather than removing anything, so neither
	-- bulk command had anything to say about it. No Outline Mode removes
	-- something, so `/vq off` takes it like any other option -- and handing
	-- Outline back to Blizzard's default of 2 is exactly what someone on their
	-- way to uninstalling wants.
	--
	-- The mirror carve-out is still asserted below, because the machinery is
	-- kept and an exemption nothing exercises is an exemption that has quietly
	-- stopped working.
	pcall(SlashCmdList["VANILLAQUESTING"], "off")
	local anyOn = false
	for i = 1, #ns.modules do
		if ns.db.settings[ns.modules[i].key] then anyOn = true end
	end
	check("/vq off takes the experiments too", not anyOn)
	check("and Outline goes back to Blizzard's default", cvars.Outline == "2", cvars.Outline)
	check("and the sparkles come back", cvars.ShowQuestObjectHighlightEffect == "1",
		tostring(cvars.ShowQuestObjectHighlightEffect))
	ns:ResetDefaults(true)

	-- The mirror carve-out, exercised by making one module a mirror for the
	-- length of a bulk command. Nothing is a mirror today; this asserts the
	-- rule the machinery implements rather than a row that happens to use it.
	do
		local m = ns.modules["noCompleteQuestPopup"]
		if m then
			ns:ResetDefaults(true)
			ns.db.settings.noCompleteQuestPopup = true
			m.mirrorOnly = true
			pcall(SlashCmdList["VANILLAQUESTING"], "off")
			check("a mirror is exempt from /vq off",
				ns.db.settings.noCompleteQuestPopup == true,
				tostring(ns.db.settings.noCompleteQuestPopup))
			ns.db.settings.noCompleteQuestPopup = false
			pcall(SlashCmdList["VANILLAQUESTING"], "on")
			check("and from /vq on",
				ns.db.settings.noCompleteQuestPopup == false,
				tostring(ns.db.settings.noCompleteQuestPopup))
			m.mirrorOnly = nil
			ns:ResetDefaults(true)
		end
	end

	-- The option asks for 0 from every outline setting, and hands back 2.
	ns:Set("noOutlineMode", false)
	VanillaQuestingDB.state.Outline = nil
	cvars.Outline = "3"
	ns:Set("noOutlineMode", true)
	check("turning the option on removes an Outline of 3", cvars.Outline == "0", cvars.Outline)
	ns:Set("noOutlineMode", false)
	check("and switching it off hands back Blizzard's default, not the 3",
		cvars.Outline == "2", cvars.Outline)
	ns:ResetDefaults(true)

	-- ---- adopting an option on must claim the variable ----
	--
	-- Reported from the client: Outline disabled, player moves Blizzard's
	-- Outline Mode to 1/2/3, then unticks the VQ option -- and Blizzard's
	-- setting stays where it was. Ticking and unticking a second time fixed
	-- it, which is the tell: the first untick had nothing to hand back.
	--
	-- The mirror adopts an option ON by writing ns.db.settings directly, so
	-- Enable never runs and never marks the variable as ours. Disable then
	-- finds no ownership and returns before writing anything -- an option
	-- that reads off with its effect still running.
	--
	-- This shipped, was fixed, and was then lost again to a revert, because
	-- no scenario covered adopt-on-then-switch-off. It does now.
	for _, case in ipairs({
		-- The polarity flipped when this stopped being a mirror: ON is now
		-- Outline 0, and the off value is Blizzard's default of 2.
		{ key = "noOutlineMode",      cvar = "Outline",          on = "0", off = "2" },
		{ key = "noInstantQuestText", cvar = "instantQuestText", on = "0", off = "1" },
		{ key = "noAutoQuestTracking", cvar = "autoQuestWatch",  on = "0", off = "1" },
	}) do
		local label = case.key .. " at " .. case.cvar .. " " .. case.on
		ns:ResetDefaults(true)
		ns:Set(case.key, false)
		VanillaQuestingDB.state[case.cvar] = nil
		cvars[case.cvar] = case.off
		fire("CVAR_UPDATE")

		-- the player moves Blizzard's own control
		cvars[case.cvar] = case.on
		fire("CVAR_UPDATE")
		check(label .. ": the option adopts on",
			ns.db.settings[case.key] == true, tostring(ns.db.settings[case.key]))
		check(label .. ": and adopting marks the variable as ours",
			VanillaQuestingDB.state[case.cvar] ~= nil,
			tostring(VanillaQuestingDB.state[case.cvar]))

		-- ...and then unticks the VQ option, once
		ns:Set(case.key, false)
		check(label .. ": one untick is enough to switch it off",
			cvars[case.cvar] == case.off, cvars[case.cvar])
		check(label .. ": and the variable is handed back",
			VanillaQuestingDB.state[case.cvar] == nil,
			tostring(VanillaQuestingDB.state[case.cvar]))
	end

	ns:ResetDefaults(true)
end

if scenario == "native" or scenario == "no_tooltipfunc" or scenario == "no_template" then
	-- ---- experimental options and the preset ----
	--
	-- Switching one on used to drop the preset to Custom, and picking Full
	-- Classic switched it back off -- a preset undoing a deliberate choice.
	local drops3, boxes3 = {}, {}
	for _, c in ipairs(_G.__nativeControls or {}) do
		if c.kind == "dropdown" then drops3[#drops3 + 1] = c
		elseif c.kind == "checkbox" then boxes3[#boxes3 + 1] = c end
	end

	ns:ResetDefaults(true)
	for i = 1, #ns.modules do
		local m = ns.modules[i]
		if not m.experimental then ns.db.settings[m.key] = true end
	end
	ns.RefreshOptions()
	check("preset reads classic with experiments off",
		drops3[1].setting:GetValue() == "classic", drops3[1].setting:GetValue())

	ns.db.settings.outlineMode = true
	ns.RefreshOptions()
	check("switching an experiment on keeps it Full Classic",
		drops3[1].setting:GetValue() == "classic", drops3[1].setting:GetValue())

	-- And picking Full Classic must not switch it back off. Start from a
	-- known state: chaining preset changes made a later SetValue a no-op,
	-- because the dropdown was already on the value being written.
	ns:ResetDefaults(true)
	ns.db.settings.outlineMode = true
	ns.RefreshOptions()
	pcall(drops3[1].setting.SetValue, drops3[1].setting, "classic")
	pcall(_G.pressApply)
	check("picking Full Classic leaves the experiment on",
		ns.db.settings.outlineMode == true,
		tostring(ns.db.settings.outlineMode))

	-- Disabled still takes everything.
	ns:ResetDefaults(true)
	ns.db.settings.outlineMode = true
	ns.RefreshOptions()
	pcall(drops3[1].setting.SetValue, drops3[1].setting, "disabled")
	pcall(_G.pressApply)
	local anyOn, mirrorsUntouched = false, true
	for i = 1, #ns.modules do
		local m = ns.modules[i]
		if m.mirrorOnly then
			-- A preset has no view about a mirror. It reports a Blizzard
			-- setting rather than removing anything, and "Disabled" reaching
			-- out to change someone's graphics options is the same mistake
			-- /vq off was making, through a different door.
			if ns.db.settings[m.key] ~= true then mirrorsUntouched = false end
		elseif ns.db.settings[m.key] then
			anyOn = true
		end
	end
	check("Disabled turns the experiments off with everything else", not anyOn)
	check("but leaves a mirror exactly where the client has it", mirrorsUntouched,
		"Outline = " .. tostring(cvars.Outline))

	-- The wording has to match the behaviour.
	local expTip
	for _, c in ipairs(boxes3) do
		local key = c.setting:GetVariable():gsub("VanillaQuesting_", "")
		if ns.modules[key].experimental then expTip = c.tooltip end
	end
	check("the experimental note warns it is untested",
		expTip and expTip:find("untested and potentially unstable", 1, true) ~= nil,
		tostring(expTip))

	ns:ResetDefaults(true)
end

if scenario == "normal" then
	-- ---- the questgiver portrait ----
	--
	-- The framed character box beside quest text, in the offer window and in
	-- the quest log. It comes back every time a quest is opened, so a one-shot
	-- hide at login would pass a naive test and fail in play.
	check("portrait module exists", ns.modules.hideCharacterFrame ~= nil)
	ns:ResetDefaults(true)
	check("it is on by default", ns.db.settings.hideCharacterFrame == true)

	QuestFrame_ShowQuestPortrait()
	check("the portrait is hidden when a quest is offered", QuestNPCModel:IsShown() == false)
	QuestFrame_ShowQuestPortrait()
	QuestFrame_ShowQuestPortrait()
	check("and stays hidden on later quests", QuestNPCModel:IsShown() == false)
	check("Status names the frame it found",
		ns.modules.hideCharacterFrame:Status():find("QuestNPCModel", 1, true) ~= nil,
		ns.modules.hideCharacterFrame:Status())

	ns:Set("hideCharacterFrame", false)
	QuestFrame_ShowQuestPortrait()
	check("turning it off shows the portrait again", QuestNPCModel:IsShown() == true)
	ns:Set("hideCharacterFrame", true)

	-- ---- quest progress in tooltips ----
	--
	-- The rule under test is the one from six captured tooltips (G12): line 1
	-- is never touched; a gold line whose text matches an ACTIVE QUEST is the
	-- header; the objective lines under it follow.
	check("tooltip module exists", ns.modules.hideTooltipsQuestProgress ~= nil)
	check("it is on by default", ns.db.settings.hideTooltipsQuestProgress == true)

	local GOLD = { r = 1.00, g = 0.82, b = 0.00 }
	local WHITE = { r = 1, g = 1, b = 1 }

	local function line(text, c) return { text = text, r = c.r, g = c.g, b = c.b } end

	-- Sample 1: the quest block sits at lines 3 and 4.
	_G.__setTooltip({
		line("Stonetusk Boar", { r = 0.90, g = 0.70, b = 0.00 }),
		line("Level 6 Beast", WHITE),
		line("Pie for Billy", GOLD),
		line(" - Tender Boar Meat: 0/4", WHITE),
	})
	_G.__showTooltip()
	local out = _G.__tooltipText()
	check("the unit name survives", out[1] == "Stonetusk Boar", tostring(out[1]))
	-- No frame tick before this check, deliberately. The client sizes the
	-- frame last, after every hook, and whatever height it is carrying when
	-- the frame ends is what the player sees. Correcting it a frame later is
	-- the box growing and then shrinking -- the stutter, not a fix for it.
	check("a fresh tooltip is the right height before the frame ends",
		math.abs(GameTooltip.__height - (4 + 2 * 12 + 2 + 4)) < 1, GameTooltip.__height)
	-- Two of four lines went. A correctly fitted tooltip ends one padding
	-- below the last surviving line, so it should be the height a two-line
	-- tooltip would have had -- and it must STAY that way after Show() has
	-- re-laid it out, which is what defeated the two previous attempts.
	check("the tooltip ends just under its last surviving line",
		math.abs(GameTooltip.__height - (4 + 2 * 12 + 2 + 4)) < 1, GameTooltip.__height)

	-- Show() again, as the client does on any refresh. The fit must survive.
	_G.__tooltipRelayout()
	_G.__retargetTooltip()
	check("and the fit survives a re-layout",
		math.abs(GameTooltip.__height - (4 + 2 * 12 + 2 + 4)) < 1, GameTooltip.__height)
	check("the level line survives", out[2] == "Level 6 Beast", tostring(out[2]))
	check("the quest title goes", out[3] == "", tostring(out[3]))
	check("the objective goes", out[4] == "", tostring(out[4]))

	-- Sample 2: a gathering node's NAME is the same gold as a quest title.
	-- This is the case that a colour-only rule eats by mistake.
	_G.__setTooltip({
		line("Silverleaf", GOLD),
		line("Herbalism", { r = 1, g = 1, b = 0 }),
	})
	_G.__showTooltip()
	out = _G.__tooltipText()
	check("a gold node name on line 1 is never touched", out[1] == "Silverleaf", tostring(out[1]))
	check("and its profession line survives", out[2] == "Herbalism", tostring(out[2]))

	-- Moving straight from one creature to the next never fires OnShow again.
	-- v0.16.0 hooked only OnShow, so in play it removed nothing at all.
	_G.__setTooltip({
		line("Another Boar", { r = 0.90, g = 0.70, b = 0.00 }),
		line("Pie for Billy", GOLD),
		line(" - Tender Boar Meat: 1/4", WHITE),
	})
	_G.__retargetTooltip()
	out = _G.__tooltipText()
	check("a retargeted tooltip is scrubbed without a fresh OnShow",
		out[2] == "" and out[3] == "",
		tostring(out[2]) .. " / " .. tostring(out[3]))

	-- Sample 3: the same quest, one line further down. A fixed index fails here.
	_G.__setTooltip({
		line("Stonetusk Boar", { r = 0.90, g = 0.70, b = 0.00 }),
		line("Level 5 Corpse", WHITE),
		line("Skinnable", { r = 1, g = 1, b = 0 }),
		line("Pie for Billy", GOLD),
		line(" - Tender Boar Meat: 0/4", WHITE),
	})
	_G.__showTooltip()
	out = _G.__tooltipText()
	check("Skinnable survives", out[3] == "Skinnable", tostring(out[3]))
	check("the quest title goes wherever it sits", out[4] == "", tostring(out[4]))
	check("as does its objective", out[5] == "", tostring(out[5]))

	-- A gold line that is NOT in the quest log must survive even below line 1.
	_G.__setTooltip({
		line("Some Mob", WHITE),
		line("Not A Quest I Have", GOLD),
		line(" - Something: 0/1", WHITE),
	})
	_G.__showTooltip()
	out = _G.__tooltipText()
	check("a gold line that is not an active quest survives",
		out[2] == "Not A Quest I Have", tostring(out[2]))
	check("and so does the line under it", out[3] == " - Something: 0/1", tostring(out[3]))

	-- A quest-log HEADER is a zone name, not a quest, and must not match.
	_G.__setQuestLog({
		{ title = "Elwynn Forest", isHeader = true },
		{ title = "Pie for Billy", isHeader = false },
	})
	_G.__setTooltip({
		line("Some Mob", WHITE),
		line("Elwynn Forest", GOLD),
	})
	_G.__showTooltip()
	out = _G.__tooltipText()
	check("a quest log zone header is not treated as a quest",
		out[2] == "Elwynn Forest", tostring(out[2]))

	-- Turned off, the tooltip is Blizzard's again.
	ns:Set("hideTooltipsQuestProgress", false)
	_G.__setTooltip({
		line("Stonetusk Boar", { r = 0.90, g = 0.70, b = 0.00 }),
		line("Pie for Billy", GOLD),
		line(" - Tender Boar Meat: 0/4", WHITE),
	})
	_G.__showTooltip()
	out = _G.__tooltipText()
	check("turning it off leaves the quest block alone",
		out[2] == "Pie for Billy" and out[3] == " - Tender Boar Meat: 0/4",
		tostring(out[2]) .. " / " .. tostring(out[3]))

	ns:ResetDefaults(true)

	-- ---- one palette ----
	--
	-- Every colour in the AddOn comes from ns.color, and the yellows and
	-- whites come from the GAME's own codes where it defines them.
	check("the palette prefers Blizzard's own yellow",
		ns.color.body == NORMAL_FONT_COLOR_CODE, ns.color.body)
	check("and Blizzard's own white", ns.color.title == HIGHLIGHT_FONT_COLOR_CODE)
	check("and Blizzard's own grey", ns.color.muted == GRAY_FONT_COLOR_CODE)
	check("there is exactly one orange",
		ns.color.experimental == "|cffff8019", ns.color.experimental)
end

if scenario == "native" or scenario == "no_tooltipfunc" or scenario == "no_template" then
	-- ---- every module reaches the panel, in a stable order ----
	--
	-- Two orders collided (20/20 and 50/50) and table.sort is unstable in
	-- Lua 5.1, so those pairs could swap places between one login and the
	-- next. Unique orders are what make the panel and /vq status agree with
	-- themselves session to session.
	local seenOrder, dupe = {}, nil
	for i = 1, #ns.modules do
		local o = ns.modules[i].order
		check("module " .. ns.modules[i].key .. " declares an order", o ~= nil)
		if o and seenOrder[o] then dupe = o .. " (" .. seenOrder[o] .. " and " .. ns.modules[i].key .. ")" end
		if o then seenOrder[o] = ns.modules[i].key end
	end
	check("no two modules share an order", dupe == nil, tostring(dupe))

	-- And every registered module has a checkbox, so a feature cannot ship
	-- without reaching the options panel.
	local inPanel = {}
	for _, c in ipairs(_G.__nativeControls or {}) do
		if c.kind == "checkbox" then
			inPanel[c.setting:GetVariable():gsub("VanillaQuesting_", "")] = true
		end
	end
	local missing = {}
	for i = 1, #ns.modules do
		if not inPanel[ns.modules[i].key] then missing[#missing + 1] = ns.modules[i].key end
	end
	check("every module has a checkbox in the panel", #missing == 0, table.concat(missing, ", "))
end

if scenario == "normal" then
	-- Every module appears in /vq status, so a feature cannot ship without
	-- being discoverable from chat either.
	local b4 = #chatlog
	pcall(SlashCmdList["VANILLAQUESTING"], "status")
	local text = table.concat(chatlog, "\n", b4 + 1, #chatlog)
	local absent = {}
	for i = 1, #ns.modules do
		if not text:find(ns.modules[i].key, 1, true) then absent[#absent + 1] = ns.modules[i].key end
	end
	check("every module appears in /vq status", #absent == 0, table.concat(absent, ", "))

	-- And help says where the option names come from.
	b4 = #chatlog
	pcall(SlashCmdList["VANILLAQUESTING"], "help")
	text = table.concat(chatlog, "\n", b4 + 1, #chatlog)
	check("/vq help points at where option names are listed",
		text:find("/vq status", 1, true) ~= nil)
end

if scenario == "normal" then
	-- ---- a tooltip re-used after another one ----
	--
	-- Hover something harmless, then a quest creature, without the tooltip
	-- hiding in between. The fit has to be right on the second one too: the
	-- frame arrives carrying whatever height the first left on it.
	ns:ResetDefaults(true)
	local GOLD2 = { r = 1.00, g = 0.82, b = 0.00 }
	local WHITE2 = { r = 1, g = 1, b = 1 }
	local function ln(t, c) return { text = t, r = c.r, g = c.g, b = c.b } end

	-- A herb node first. Nothing to remove, so nothing should be resized.
	_G.__setTooltip({ ln("Silverleaf", GOLD2), ln("Herbalism", { r = 1, g = 1, b = 0 }) })
	_G.__showTooltip()
	local herbHeight = GameTooltip.__height
	check("a tooltip with nothing to remove is left alone",
		math.abs(herbHeight - (4 + 2 * 12 + 2 + 4)) < 1, herbHeight)

	-- Now a four-line quest creature, arriving on the same frame.
	_G.__setTooltip({
		ln("Stonetusk Boar", { r = 0.90, g = 0.70, b = 0.00 }),
		ln("Level 6 Beast", WHITE2),
		ln("Pie for Billy", GOLD2),
		ln(" - Tender Boar Meat: 0/4", WHITE2),
	})
	_G.__retargetTooltip()
	local out2 = _G.__tooltipText()
	check("the re-used tooltip is still scrubbed", out2[3] == "" and out2[4] == "",
		tostring(out2[3]) .. " / " .. tostring(out2[4]))
	-- The stutter guard, and again no frame tick. Every earlier fix got the
	-- final height right and was still visibly wrong, because the client's
	-- resize was the last thing in the frame and the correction came after it.
	check("and the re-used tooltip is fitted before the frame ends",
		math.abs(GameTooltip.__height - (4 + 2 * 12 + 2 + 4)) < 1, GameTooltip.__height)
	-- And the deferred backstop, one frame on, changes nothing.
	_G.__countResizes()
	_G.__nextFrame()
	check("and the deferred pass has nothing left to correct",
		GameTooltip.__resizes == 0, tostring(GameTooltip.__resizes))

	-- And back to something clean: it must not stay cramped.
	_G.__setTooltip({
		ln("Innkeeper Allison", { r = 0.90, g = 0.70, b = 0.00 }),
		ln("Level 30 Humanoid", WHITE2),
		ln("Innkeeper", { r = 1, g = 1, b = 0 }),
	})
	_G.__retargetTooltip()
	local out3 = _G.__tooltipText()
	check("a clean tooltip after a scrubbed one keeps all its lines",
		out3[2] == "Level 30 Humanoid" and out3[3] == "Innkeeper",
		tostring(out3[2]) .. " / " .. tostring(out3[3]))
	check("and is not left cramped by the previous fit",
		math.abs(GameTooltip.__height - (4 + 3 * 12 + 2 * 2 + 4)) < 1, GameTooltip.__height)

	ns:ResetDefaults(true)

	-- ---- turning the minimap option off re-enables Blizzard's tracking ----
	--
	-- Track Quest POIs is on by default in the game, so switching this option
	-- off should hand back the default rather than whatever the entry happened
	-- to be when the AddOn was installed.
	-- `ClassicQuestingMoPDB = nil` stood here: the SavedVariables name from
	-- before the rename to VanillaQuestingDB. It set a global nothing reads,
	-- so it did nothing at all, and the test had been passing for a different
	-- reason than it claimed ever since. Found by luacheck (#37) as a
	-- non-standard global, which is precisely the argument for having it.
	--
	-- What was meant: start with this AddOn owning nothing, so the restore is
	-- the AddOn handing back rather than replaying a remembered value.
	tracking[4].active = false
	VanillaQuestingDB.state.minimapMarkersTracking = nil
	ns:Set("hideMinimapQuestHelper", true)
	check("the option turns tracking off", tracking[4].active == false)
	ns:Set("hideMinimapQuestHelper", false)
	check("turning it off turns Track Quest POIs back on", tracking[4].active == true,
		tostring(tracking[4].active))
	ns:ResetDefaults(true)
end

if scenario == "native" or scenario == "no_tooltipfunc" or scenario == "no_template" then
	-- Every category gets a heading, and the options under it all belong to it.
	local headings, current, wrong = {}, nil, nil
	for _, c in ipairs(_G.__nativeControls or {}) do
		if c.kind == "header" then
			current = (c.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
			headings[#headings + 1] = current
		elseif c.kind == "checkbox" then
			local key = c.setting:GetVariable():gsub("VanillaQuesting_", "")
			if ns.modules[key].group ~= current then
				wrong = key .. " sits under " .. tostring(current)
					.. " but belongs to " .. tostring(ns.modules[key].group)
			end
		end
	end
	check("every option sits under its own category heading", wrong == nil, tostring(wrong))
	check("the categories are the five agreed",
		table.concat(headings, ", "):find("Map and minimap, Quests, Quest Tracker, UI & Graphics, Experimental", 1, true) ~= nil,
		table.concat(headings, ", "))
end

print(string.format("--- %s: %d passed, %d failed ---", scenario, pass, fail))
os.exit(fail == 0 and 0 or 1)