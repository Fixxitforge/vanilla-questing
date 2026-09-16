-- luacheck configuration for Vanilla Questing.
--
-- Added for issue #37, from the Questie audit: luacheck would have caught the
-- duplicate `local applyingPreset` in Options.lua (#22) as a shadowed variable,
-- for free, where it took a human reading an audit to find.
--
-- It sits beside `luac -p` and `lint_forward_refs.py` in dev/tests/run.sh and
-- can fail the run. It does NOT replace either: luacheck reads one file at a
-- time and knows nothing about a call to a `local function` declared further
-- down, which is the trap this project has hit four times.

std = "lua51"   -- the client's Lua version, and the one the suite runs under

-- The three settings below allow things this codebase does on purpose. Each is
-- named individually rather than switching off a whole category: the value of
-- this check is that it still fails on the things it was added for.

-- `local ADDON_NAME, ns = ...` is the WoW namespace idiom, and the first
-- return is genuinely unused in most files. Writing `local _, ns = ...` would
-- lose the name that tells the reader what the value is.
-- Descriptions and limitation strings are single long literals. Wrapping a
-- user-visible string across lines to satisfy a linter trades a real thing --
-- being able to read the string as it ships -- for a cosmetic one.
max_line_length = 200

-- Unused `self` on a method that does not need it is not a defect. Every
-- module here defines `function M:Enable()` whether or not it uses the
-- receiver, and the alternative -- writing some as `M.Enable = function()` and
-- some with a colon -- would be worse.
self = false

-- Globals this AddOn WRITES.
globals = {
	"VanillaQuestingDB",         -- SavedVariables, declared in the .toc
	"SLASH_VANILLAQUESTING1", "SLASH_VANILLAQUESTING2",
	"SlashCmdList",              -- written into, not replaced
	"StaticPopupDialogs",        -- one dialog added
	"UIParent",                  -- the harness stubs it; the AddOn only reads
	-- Hung on the frame by name because Templates.xml names it in OnLoad.
	-- [G27] proved an AddOn's own template renders in Blizzard's settings
	-- list, and this is the function that template calls.
	"VanillaQuesting_DescriptionOnLoad",
}

-- Empty `if` branches are allowed, and there are three.
--
-- Each is a branch that deliberately does nothing, with a comment saying why:
-- "a mirror is never bulk-set, in either direction", and so on. The
-- alternatives are worse -- inverting the condition buries the case being
-- excluded, and an `and not m.mirrorOnly` chain hides it completely. A named
-- empty branch is the clearest way to say "this case is handled by doing
-- nothing, on purpose".
ignore = { "211/ADDON_NAME", "542" }

-- Globals this AddOn READS, and nothing more.
--
-- Deliberately an ALLOWLIST rather than `std = "+wow"` or a blanket ignore of
-- undefined-variable warnings. The point of this check is that a misspelled
-- API name fails the lint -- and on a client where "the usual assumptions do
-- not hold", a name that looks right and is not is the exact mistake worth
-- catching. Every entry below is one this project has confirmed exists on
-- 5.5.4.69585, by probe or by reading Blizzard's own source.
--
-- Adding a name here without that evidence defeats the check.
read_globals = {
	-- Namespaced API. Cross-checked against the client's own generated
	-- documentation in dev/knowledge/api-index.txt.
	"C_AddOns", "C_CVar", "C_Minimap", "C_Console",

	-- Console variables
	"GetCVar", "SetCVar", "GetCVarInfo", "ConsoleGetAllCommands",

	-- Frames and FrameXML. Not in api-index.txt -- that file documents the
	-- C_* surface only -- so these rest on recon: [G1]/[G2] for the minimap,
	-- [G14]/[G15] for the tracker, [G35] for the tracking button.
	"CreateFrame", "UIParent", "GameTooltip", "Minimap",
	"MiniMapTracking", "MiniMapTrackingButton", "MinimapCluster",
	"WatchFrame", "WatchFrameLines", "WatchFrame_Update",
	"WatchFrameAutoQuest_ClearPopUp",
	"WATCHFRAME_LINKBUTTONS", "WATCHFRAME_MAXQUESTS", "WATCHFRAME_QUESTLINES",
	"WorldMapFrame", "QuestMapFrame_UpdateAll",
	"ContainerFrame_Update",
	"HideUIPanel", "ShowUIPanel", "StaticPopup_Show", "ReloadUI",
	"InCombatLockdown", "hooksecurefunc",

	-- Settings API. Signature settled by readback in [G13c]; the initializer
	-- globals enumerated in [G23].
	"Settings", "SettingsPanel",
	"CreateSettingsListSectionHeaderInitializer", "SettingsListSectionHeaderMixin",

	-- Quest log and tracking
	"GetNumQuestLogEntries", "GetQuestLogTitle", "GetNumQuestWatches",
	"GetNumTrackingTypes", "GetTrackingInfo",
	"GetNumAutoQuestPopUps", "GetAutoQuestPopUp", "RemoveAutoQuestPopUp",

	-- Strings and colour codes Blizzard defines. The palette prefers these
	-- over literals; see the fallbacks in Core.lua.
	"MINIMAP_TRACKING_QUEST_POIS",
	"NORMAL_FONT_COLOR_CODE", "HIGHLIGHT_FONT_COLOR_CODE",
	"GRAY_FONT_COLOR_CODE", "FONT_COLOR_CODE_CLOSE",
	-- Added after checking Blizzard's own 5.5.4.69585 source drop, where
	-- Blizzard_Communities/GuildRewards.lua:33 uses it. The allowlist caught
	-- it on the first run, which is what it is for -- on this client a name
	-- that looks right and is not is exactly the mistake worth catching.
	"YELLOW_FONT_COLOR_CODE",
	-- The client's own name for itself, for the preset that turns everything
	-- off (#55). Documented in the client's own generated API
	-- (ExpansionDocumentation.lua), and Blizzard indexes EXPANSION_NAME<n>
	-- the same way in Blizzard_Collections/Blizzard_ToyBox.lua:138.
	-- EXPANSION_NAME<n> itself is reached through _G, so it needs no entry.
	"GetClientDisplayExpansionLevel",
	"YES", "NO", "CANCEL", "ChatFontNormal",

	-- Miscellaneous client globals
	"GetAddOnMetadata", "GetBuildInfo", "DEFAULT_CHAT_FRAME", "wipe", "date",
}

-- The test harness and the suite are a different animal: the harness DEFINES
-- the globals a WoW client would provide, and the suite reads them. Listing
-- them would be listing the whole stub, and it changes whenever the model
-- grows -- so the undefined/non-standard-global family is off here, and only
-- there.
--
-- Everything else stays on, which is the point: shadowed and unused locals are
-- as much a hazard in a test as in the AddOn, and switching the whole file off
-- would have kept `ClassicQuestingMoPDB = nil` -- a line that had done nothing
-- since the SavedVariables rename, in a test that was passing for a reason it
-- did not state.
files["dev/tests/*.lua"] = {
	-- The undefined-global family is off here, and only here.
	--
	-- The harness IS a stub of the globals a WoW client provides -- it assigns
	-- most of them through `_G.x = ...`, which luacheck cannot see as a
	-- definition -- and the suite reads them. Listing them would mean listing
	-- the whole stub and re-listing it whenever the model grows.
	--
	-- `allow_defined_top` was tried first, because it would have kept the
	-- check meaningful; it resolves only globals assigned as bare top-level
	-- names, which is not how the harness writes them.
	--
	-- What that costs: `ClassicQuestingMoPDB = nil` -- the SavedVariables name
	-- from before the rename, set inside a branch, reading nothing and doing
	-- nothing for eleven versions -- was found by this family before it was
	-- switched off. So run.sh carries a separate grep for retired names, which
	-- is a better tool for that class anyway: it covers every file, not just
	-- the Lua ones.
	ignore_unused_args = false,
	-- Unused locals in a 2,700-line suite are noise rather than defects -- a
	-- captured `before` that a later check stopped using says nothing about
	-- whether the thing under test works. Shadowing and
	-- assigned-but-never-read stay on, because those are how a check quietly
	-- stops testing what it says it tests.
	-- 12x as well as 11x: the harness STUBS the WoW API, so it assigns the
	-- very globals the main config declares read-only. That is the file's
	-- entire purpose, and it is the one place in the repo where writing to
	-- `WorldMapFrame` or `HideUIPanel` is correct.
	ignore = { "111", "112", "113", "121", "122", "21", "542" },
}

-- The probe is dev-only and throwaway. It gets the same checks, but it owns
-- some globals of its own.
files["dev/UnmarkedRecon/*.lua"] = {
	globals = {
		"UnmarkedReconDB", "UnmarkedReconProbeVars",
		"SLASH_UNRECON1", "SlashCmdList",
		-- Hung on the frame by name because the XML template calls them.
		"UnmarkedRecon_DescriptionOnLoad", "UnmarkedRecon_TrackDump",
	},
}
