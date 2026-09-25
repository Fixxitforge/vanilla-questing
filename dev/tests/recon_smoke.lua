-- Run the probe off-client, once, and fail if it produces nothing.
--
-- The probe has now cost two wasted round trips: v0.29 shipped with every
-- section switched off, and v0.31 shipped with sections that called GetCVar
-- bare on names that do not exist -- which ERRORS on this client rather than
-- returning nil. Both looked identical from the player's side: "/unrecon copy
-- does nothing".
--
-- This is not a test of what the probe FINDS. It cannot be: the answers live
-- in the client. It is a test that the probe RUNS, which is the only part of
-- it that can be checked from here, and is exactly what failed twice.
--
--   lua5.1 recon_smoke.lua
local pass, fail = 0, 0
local function check(label, cond, detail)
	if cond then pass = pass + 1; print("  [ok]   " .. label)
	else fail = fail + 1; print("  [FAIL] " .. label .. (detail and ("  -> " .. tostring(detail)) or "")) end
end

print("=== recon smoke ===")

local h = assert(loadfile("addon_harness.lua"))
h("normal")

-- The probe is not the AddOn and does not load through RegisterModule, so it
-- needs the few globals the harness does not already provide.
_G.GetAddOnMetadata = function(_, key)
	if key == "Version" then return "0.35" end
end
_G.GetBuildInfo = function() return "5.5.4", "69585", "2026-09-14", 50504 end
_G.date = os.date
_G.wipe = _G.wipe or function(t) for k in pairs(t) do t[k] = nil end return t end

-- THE POINT OF THIS FILE.
--
-- GetCVar errors on an unknown name. Every probe section asking "does this
-- exist?" hits that on its first miss, and an unguarded call takes the whole
-- run with it. Modelled here exactly as the client behaves, so a section that
-- forgets the pcall fails HERE rather than in a round trip.
local knownCVars = {
	questPOI = "1", autoQuestWatch = "1", instantQuestText = "1",
	showBosses = "1", Outline = "2", questHelper = "1",
	-- Two of G34's nine, so the describe/write path runs for real rather than
	-- skipping every name. The other seven are absent on purpose: a section
	-- has to survive asking about something that is not there, which is the
	-- entire failure mode this file exists for.
	ShowQuestObjectHighlightEffect = "1", ShowQuestUnitCircles = "1",
}
_G.GetCVar = function(name)
	if knownCVars[name] == nil then
		error("Unknown cvar '" .. tostring(name) .. "'", 2)
	end
	return knownCVars[name]
end
-- NOT a global on this client. The v0.32 run printed "attempt to call a nil
-- value" in every flag column before anyone noticed the column was the pcall
-- error rather than a value. Modelled absent here so a section that reaches
-- for the bare name fails at home.
_G.GetCVarInfo = nil
local function cvarInfo(name)
	if knownCVars[name] == nil then
		error("Unknown cvar '" .. tostring(name) .. "'", 2)
	end
	return knownCVars[name], "1", false, false, false, false, false
end
-- Returns success:bool. Confirmed by the v0.32 run through the global
-- wrapper, which is a DIFFERENT function reference from C_CVar.SetCVar and
-- passes the value through anyway.
_G.SetCVar = function(name, value)
	if knownCVars[name] == nil then
		error("Unknown cvar '" .. tostring(name) .. "'", 2)
	end
	knownCVars[name] = tostring(value)
	return true
end
_G.C_CVar = {
	GetCVar = _G.GetCVar,
	SetCVar = function(...) return _G.SetCVar(...) end,
	GetCVarInfo = cvarInfo,
	GetCVarDefault = function() return "1" end,
}

-- ConsoleGetAllCommands is the name this client has; C_Console is absent.
-- Entries are tables carrying a help string, which is what G34 reads.
_G.ConsoleGetAllCommands = function()
	local out = {}
	for name in pairs(knownCVars) do
		out[#out + 1] = {
			command = name, category = 4, commandType = 0,
			help = "Stores whether to show quest tracking things",
			scriptContents = "", scriptParameters = "",
		}
	end
	return out
end
_G.C_Console = nil

local printed = {}
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) printed[#printed + 1] = msg end }

-- Everything the harness built before the probe loads, Vanilla Questing's
-- event frame among them. G36 below has to switch those off.
local framesBeforeProbe = #frames

local ok, err = pcall(function()
	local f = assert(loadfile("../UnmarkedRecon/Recon.lua"))
	f("UnmarkedRecon", {})
end)
check("Recon.lua loads", ok, err)
if not ok then print("\n--- smoke: " .. pass .. " passed, " .. fail .. " failed ---") os.exit(1) end

check("it registers a slash command", type(SlashCmdList) == "table"
	and type(SlashCmdList["UNRECON"]) == "function")

-- ADDON_LOADED, the way the client sends it.
pcall(fire, "ADDON_LOADED", "UnmarkedRecon")
pcall(fire, "PLAYER_ENTERING_WORLD")

local ranOK, runErr = pcall(SlashCmdList["UNRECON"], "")
check("/unrecon runs without error", ranOK, runErr)

local report = UnmarkedReconDB and UnmarkedReconDB.report
check("it produced a report", type(report) == "string" and #report > 0,
	type(report) == "string" and #report or type(report))

if type(report) == "string" then
	-- A section that threw leaves its error in the report rather than taking
	-- the run down. That is the guard working -- and it is still a failure
	-- here, because the fix belongs in the section, not in the guard.
	local failed = {}
	for line in report:gmatch("[^\n]+") do
		if line:find("SECTION FAILED", 1, true) then failed[#failed + 1] = line end
	end
	check("no section threw", #failed == 0, table.concat(failed, " | "))

	-- The stronger check, and the one that would have caught v0.32.
	--
	-- `pcall(f)` where f is NIL does not throw. It returns false and the
	-- string "attempt to call a nil value" -- so a section that reaches for a
	-- function this client does not have runs to completion, produces a
	-- report, and prints the error message where a value should be. Nothing
	-- above notices: no section failed, the report exists, the run looks fine.
	--
	-- v0.32's [G32] came back with that message in every flag column, and the
	-- whole point of the section -- are any of our CVars locked? -- went
	-- unanswered for a round trip. A Lua error message is never an answer.
	local leaked = {}
	for line in report:gmatch("[^\n]+") do
		if line:find("attempt to call", 1, true)
			or line:find("attempt to index", 1, true)
			or line:find("attempt to compare", 1, true) then
			leaked[#leaked + 1] = line
		end
	end
	check("no Lua error text printed as data", #leaked == 0,
		table.concat(leaked, " | "))

	-- v0.29's mistake: every section switched off, nothing to run, round trip
	-- wasted. A report with no section headers at all is that.
	local heads = 0
	for line in report:gmatch("[^\n]+") do
		if line:find("^== ") then heads = heads + 1 end
	end
	check("at least one section is switched on", heads > 0, heads)
	print("  (" .. heads .. " sections, " .. #report .. " bytes)")
end

-- ---- [G36]: the logout probe, walked end to end ----
--
-- Its answer is in the client. What is checked here is that a trip RUNS: it
-- arms, it writes at PLAYER_LOGOUT, it judges at the next login, and it puts
-- the player's values back -- because a probe that moves a setting and then
-- fails to restore it costs the tester more than a probe that produces nothing.
do
	local function trips() return #((UnmarkedReconDB.logoutProbe or {}).trips or {}) end
	local function lastTrip()
		local t = UnmarkedReconDB.logoutProbe.trips
		return t[#t]
	end
	-- The harness loads Vanilla Questing, and VQ re-applies its options on
	-- every world entry -- which rewrote showBosses under this test and made
	-- a trip read SURVIVED for VQ's reasons rather than the client's. That is
	-- the exact contamination G36 refuses to arm against in game, so it is
	-- modelled away here: the frames that existed before the probe loaded
	-- stop hearing events.
	for i = 1, framesBeforeProbe do frames[i].events = {} end
	knownCVars.showBosses, knownCVars.instantQuestText = "1", "0"

	-- Vanilla Questing loaded: it must refuse, because VQ re-applies at login.
	_G.C_AddOns = { IsAddOnLoaded = function(n) return n == "VanillaQuesting" end,
		GetAddOnMetadata = _G.C_AddOns and _G.C_AddOns.GetAddOnMetadata }
	pcall(SlashCmdList["UNRECON"], "logout arm refused")
	check("G36 will not arm beside Vanilla Questing",
		(UnmarkedReconDB.logoutProbe or {}).armed == nil)
	_G.C_AddOns.IsAddOnLoaded = function() return false end

	-- A trip whose write survives.
	check("G36 arms", pcall(SlashCmdList["UNRECON"], "logout arm Exit"))
	check("and keeps the label's case",
		UnmarkedReconDB.logoutProbe.armed and UnmarkedReconDB.logoutProbe.armed.label == "Exit",
		UnmarkedReconDB.logoutProbe.armed and UnmarkedReconDB.logoutProbe.armed.label)
	pcall(fire, "PLAYER_LOGOUT")
	check("PLAYER_LOGOUT flips both variables",
		knownCVars.showBosses == "0" and knownCVars.instantQuestText == "1",
		knownCVars.showBosses .. " " .. knownCVars.instantQuestText)
	pcall(fire, "ADDON_LOADED", "UnmarkedRecon")
	pcall(fire, "VARIABLES_LOADED")
	pcall(fire, "PLAYER_ENTERING_WORLD", false, false)
	check("a loading screen does not close a trip", trips() == 0, trips())
	pcall(fire, "PLAYER_ENTERING_WORLD", true, false)
	check("the login after it records a trip", trips() == 1, trips())
	check("and calls it survived",
		trips() == 1 and tostring(lastTrip().vars.showBosses.verdict):find("^SURVIVED") ~= nil,
		trips() == 1 and lastTrip().vars.showBosses.verdict)
	check("and puts both values back",
		knownCVars.showBosses == "1" and knownCVars.instantQuestText == "0",
		knownCVars.showBosses .. " " .. knownCVars.instantQuestText)

	-- A trip whose write is lost: the client comes back with the old value.
	pcall(SlashCmdList["UNRECON"], "logout arm lost")
	pcall(fire, "PLAYER_LOGOUT")
	knownCVars.showBosses, knownCVars.instantQuestText = "1", "0"
	pcall(fire, "PLAYER_ENTERING_WORLD", true, false)
	check("a write that did not persist is called lost",
		trips() == 2 and tostring(lastTrip().vars.instantQuestText.verdict):find("^LOST") ~= nil,
		trips() == 2 and lastTrip().vars.instantQuestText.verdict)

	-- A reload that never ran PLAYER_LOGOUT is recorded as that, and moves nothing.
	pcall(SlashCmdList["UNRECON"], "logout arm reload")
	pcall(fire, "PLAYER_ENTERING_WORLD", false, true)
	check("no PLAYER_LOGOUT is recorded as a finding",
		trips() == 3 and tostring(lastTrip().note):find("did not run", 1, true) ~= nil,
		trips() == 3 and lastTrip().note)
	check("and nothing was moved",
		knownCVars.showBosses == "1" and knownCVars.instantQuestText == "0",
		knownCVars.showBosses .. " " .. knownCVars.instantQuestText)

	check("/unrecon logout prints the record", pcall(SlashCmdList["UNRECON"], "logout"))
	pcall(SlashCmdList["UNRECON"], "")
	local rep = UnmarkedReconDB.report or ""
	check("the report carries G36 and its trips",
		rep:find("[G36]", 1, true) ~= nil and rep:find("Trip 3", 1, true) ~= nil)
	check("and no Lua error text in it",
		rep:find("attempt to", 1, true) == nil)
	check("/unrecon logout clear empties it",
		pcall(SlashCmdList["UNRECON"], "logout clear") and trips() == 0, trips())
end

check("/unrecon copy runs", pcall(SlashCmdList["UNRECON"], "copy"))
check("/unrecon print runs", pcall(SlashCmdList["UNRECON"], "print"))

print("\n--- smoke: " .. pass .. " passed, " .. fail .. " failed ---")
if fail > 0 then os.exit(1) end
