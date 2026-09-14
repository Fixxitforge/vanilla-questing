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
	if key == "Version" then return "0.31" end
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

check("/unrecon copy runs", pcall(SlashCmdList["UNRECON"], "copy"))
check("/unrecon print runs", pcall(SlashCmdList["UNRECON"], "print"))

print("\n--- smoke: " .. pass .. " passed, " .. fail .. " failed ---")
if fail > 0 then os.exit(1) end
