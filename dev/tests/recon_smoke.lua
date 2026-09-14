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
}
_G.GetCVar = function(name)
	if knownCVars[name] == nil then
		error("Unknown cvar '" .. tostring(name) .. "'", 2)
	end
	return knownCVars[name]
end
_G.GetCVarInfo = function(name)
	if knownCVars[name] == nil then
		error("Unknown cvar '" .. tostring(name) .. "'", 2)
	end
	return knownCVars[name], "1", false, false, false, false, false
end
_G.SetCVar = function(name, value)
	if knownCVars[name] == nil then
		error("Unknown cvar '" .. tostring(name) .. "'", 2)
	end
	knownCVars[name] = tostring(value)
end
_G.C_CVar = {
	GetCVar = _G.GetCVar, SetCVar = _G.SetCVar, GetCVarInfo = _G.GetCVarInfo,
	GetCVarDefault = function() return "1" end,
}

-- Absent on this client as far as anyone knows, which is what G28 asks. Left
-- absent here on purpose: the section must survive not finding it.
_G.ConsoleGetAllCommands = nil
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
