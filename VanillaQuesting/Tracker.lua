-- Vanilla Questing -- Objective tracker
--
-- Classic HAS a tracker: you shift-click a quest in the log and it
-- appears. So nothing here hides it -- that would remove a Classic feature
-- rather than a MoP one. What Classic did not have is everything MoP bolted
-- onto the lines: clickable quest titles with a context menu behind them, and
-- a use button for quest items. Those are what this file removes.
--
-- Everything below is named in the v0.15 probe log ([G15]); nothing is
-- reached for on the strength of what a later client calls it. In particular
-- this client has WatchFrame, NOT ObjectiveTrackerFrame.
--
-- On protection, precisely: WatchFrame:IsProtected() came back explicitly
-- false, and so did WatchFrameItem1's when it was finally asked in probe v0.32
-- [G33]. The earlier version of this comment claimed the first measurement
-- covered the item buttons too -- it did not, and **a measurement on a parent
-- frame is not a measurement on its children** (#16). It happened to be right.
--
-- hideTrackerItemButtons does not depend on it either way: it uses alpha and
-- mouse state rather than Hide(), so the combat question stops existing
-- instead of resting on a reading that could change on any patch.
--
-- One thing that looked like work turned out not to be: "no auto-sort by
-- distance" has nothing to remove. The only sort constants this client
-- defines are WATCHFRAME_SORT_MANUAL (0), _DIFFICULTY_HIGH (1) and
-- _DIFFICULTY_LOW (2). There is no proximity sort, and WATCHFRAME_SORT_TYPE
-- already reads 0.

local ADDON_NAME, ns = ...

-- Re-applied after every tracker rebuild rather than once at login: the
-- tracker recycles its buttons, so a line that is a quest title now may be
-- something else after the next update.
local hooked = false
local function ensureHook()
	if hooked then return end
	if type(hooksecurefunc) ~= "function" or type(WatchFrame_Update) ~= "function" then
		return
	end
	hooked = true
	hooksecurefunc("WatchFrame_Update", function()
		if not ns.db then return end
		for i = 1, #ns.modules do
			local m = ns.modules[i]
			if m.trackerPass and ns.db.settings[m.key] then
				pcall(m.trackerPass, m)
			end
		end
	end)
end

---------------------------------------------------------------------
-- Click-to-track
---------------------------------------------------------------------
--
-- WATCHFRAME_LINKBUTTONS holds one Button per tracked quest title, each with
-- an OnClick -- left-click opens the map to the quest, right-click opens a
-- context menu with Abandon and Share on it. Classic's tracker was text and
-- nothing else.
--
-- The buttons are disabled rather than hidden: hiding them would leave the
-- title text unclickable but also disturb the layout the tracker built around
-- them. EnableMouse(false) takes the click without moving anything.
--
-- Only the QUEST ones. Blizzard tags every pooled button as it lays it out --
-- `linkButton.type = "QUEST"` or `"ACHIEVEMENT"` in Wrath/WatchFrame.lua, the
-- file 5.5.x loads -- and branches on that tag in six places of its own. Until
-- v1.0.1 this AddOn disabled the whole pool and the README called achievement
-- lines going dead an unavoidable limitation. It was not; the tag was simply
-- never read.
--
-- The tag is only meaningful after the redraw that sets it, and Blizzard
-- clears it on release, so a button with no type is one not currently in use.
-- If NOTHING in the pool carries a type, this is not that client: fall back to
-- the old behaviour rather than silently doing nothing, because an option that
-- removes nothing is worse than one with a stated cost.

do
	local M = ns:RegisterModule("trackerPlainText", {})
	M.title = "Plain Text Quest Tracker"
	M.desc  = "Quest titles in the tracker stop being clickable."
	M.onText  = "Tracker quest titles are now plain text."
	M.offText = "Tracker quest titles are clickable."
	M.group = "Quest Tracker"
	M.order = 70

	ns:RegisterDefaults({ trackerPlainText = true })

	-- Remembered so Disable can hand the clicks back rather than guessing
	-- that they were on. A subtractive AddOn leaves no trace when off.
	local touched = {}

	-- Does any button in the pool carry a type? Asked fresh on every pass
	-- rather than cached: the pool is empty before the first redraw, and a
	-- cached "no" taken then would disable achievements for the whole session.
	local function poolIsTagged(buttons)
		for i = 1, #buttons do
			local b = buttons[i]
			if type(b) == "table" and b.type ~= nil then return true end
		end
		return false
	end

	-- Which kinds of line this pass silences.
	--
	-- Quests always. Achievements only when the sub-option asks for them --
	-- and on a client whose pool carries no tag at all, everything, because
	-- there is no way to be selective and an option that removes nothing is
	-- worse than one with a stated cost.
	local function silences(b, tagged)
		if not tagged then return true end
		if b.type == "QUEST" then return true end
		if b.type == "ACHIEVEMENT" then
			return ns.db and ns.db.settings.trackerPlainTextAchievements and true or false
		end
		return false
	end

	function M:trackerPass()
		local buttons = WATCHFRAME_LINKBUTTONS
		if type(buttons) ~= "table" then return end
		local tagged = poolIsTagged(buttons)
		for i = 1, #buttons do
			local b = buttons[i]
			if type(b) == "table" and type(b.EnableMouse) == "function"
				and silences(b, tagged) then
				if touched[b] == nil and type(b.IsMouseEnabled) == "function" then
					local ok, was = pcall(b.IsMouseEnabled, b)
					touched[b] = ok and was or false
				end
				pcall(b.EnableMouse, b, false)
			end
		end
	end

	function M:Enable()
		ensureHook()
		if type(WatchFrame_Update) == "function" then pcall(WatchFrame_Update) end
	end

	function M:Disable()
		for b, was in pairs(touched) do
			if type(b) == "table" and type(b.EnableMouse) == "function" then
				pcall(b.EnableMouse, b, was and true or false)
			end
		end
		wipe(touched)
		if type(WatchFrame_Update) == "function" then pcall(WatchFrame_Update) end
	end

	function M:Status()
		local buttons = WATCHFRAME_LINKBUTTONS
		if type(buttons) ~= "table" then return "no tracker link buttons" end
		return #buttons .. " tracker link button(s)"
	end

	-----------------------------------------------------------------
	-- Sub-option: achievement lines too
	-----------------------------------------------------------------
	--
	-- The first sub-option this AddOn has. `M.parent` names the module it
	-- hangs off; Options.lua hands the child initializer to Blizzard's
	-- SetParentInitializer, which indents it, drops it to the small font and
	-- greys it out whenever the parent is off. The fallback panel and
	-- `/vq status` indent to match, so all three agree.
	--
	-- It exists because v1.0.0 could not tell a quest line from an achievement
	-- line and silenced both, and the README called that an unavoidable
	-- limitation. It was not -- but a tracker that is entirely text is what
	-- Classic had, so this ships ON and the limitation becomes a choice rather
	-- than disappearing. What changed is that turning it off now works.
	--
	-- Declared inside this block on purpose. It shares `touched`, which is
	-- what lets it hand the achievement clicks back without guessing that they
	-- were on.
	local C = ns:RegisterModule("trackerPlainTextAchievements", {})
	C.title   = "Plain Text Achievements"
	C.desc    = "Achievement titles in the tracker stop being clickable as well."
	C.onText  = "Tracker achievement titles are now plain text."
	C.offText = "Tracker achievement titles are clickable."
	C.group   = "Quest Tracker"
	C.order   = 71
	C.parent  = "trackerPlainText"

	ns:RegisterDefaults({ trackerPlainTextAchievements = true })

	function C:Enable()
		ensureHook()
		if type(WatchFrame_Update) == "function" then pcall(WatchFrame_Update) end
	end

	function C:Disable()
		-- Only the achievement buttons. The parent owns the quest ones and is
		-- very likely still on.
		for b, was in pairs(touched) do
			if type(b) == "table" and b.type == "ACHIEVEMENT"
				and type(b.EnableMouse) == "function" then
				pcall(b.EnableMouse, b, was and true or false)
				touched[b] = nil
			end
		end
		if type(WatchFrame_Update) == "function" then pcall(WatchFrame_Update) end
	end

	function C:Status()
		if not (ns.db and ns.db.settings.trackerPlainText) then
			return "parent option is off"
		end
		local buttons = WATCHFRAME_LINKBUTTONS
		if type(buttons) ~= "table" then return "no tracker link buttons" end
		local n = 0
		for i = 1, #buttons do
			local b = buttons[i]
			if type(b) == "table" and b.type == "ACHIEVEMENT" then n = n + 1 end
		end
		return n .. " achievement line(s) in the tracker"
	end
end

---------------------------------------------------------------------
-- Quest item buttons
---------------------------------------------------------------------
--
-- WatchFrameItem1..N, parented to WatchFrameLines, with WATCHFRAME_NUM_ITEMS
-- counting the live ones. Classic had no such thing: a quest item was used
-- from your bags.

do
	local M = ns:RegisterModule("hideTrackerItemButtons", {})
	M.title = "Hide Quest Item Buttons"
	M.desc  = "Removes the quest item buttons next to tracked quests."
	M.onText  = "Tracker quest item buttons removed."
	M.offText = "Tracker quest item buttons restored."
	M.group = "Quest Tracker"
	M.order = 80

	ns:RegisterDefaults({ hideTrackerItemButtons = true })

	-- What was taken, and what it was before. `[button] = { alpha, mouse }`.
	--
	-- `hiddenOnes` stood here: written on every pass, wiped in Disable, and
	-- never read. Removed with the Hide() it belonged to (#16).
	local taken = {}

	-- WATCHFRAME_MAXQUESTS is the ceiling on tracked quests and so on item
	-- buttons; reading it beats a number written in by hand.
	local function maxItems()
		local n = WATCHFRAME_MAXQUESTS
		if type(n) ~= "number" or n < 1 then return 10 end
		return n
	end

	-- Alpha and mouse, not Hide(). #16.
	--
	-- `WatchFrameItem<N>` are the quest-item USE buttons -- the part of the
	-- tracker most likely to be secure, because using an item is a protected
	-- action. The claim that it was safe to hide them was measured on
	-- `WatchFrame`, the PARENT, and generalised: **a measurement on a parent
	-- frame is not a measurement on its children.**
	--
	-- Probe v0.32 [G33] finally asked, and the answer was reassuring:
	-- `WatchFrameItem1:IsProtected()` is false, explicitly false, and
	-- `IsForbidden()` too. So this was a near miss rather than a live bug.
	--
	-- It changes anyway. Alpha is not a protected operation, so moving to it
	-- means the combat question **stops existing** rather than resting on a
	-- reading that could change on any patch -- and this runs from a
	-- `hooksecurefunc` on `WatchFrame_Update`, which fires in combat whenever
	-- objectives tick, inside a `pcall` that would swallow a blocked call
	-- without a word.
	function M:trackerPass()
		for i = 1, maxItems() do
			local b = _G["WatchFrameItem" .. i]
			if b and type(b.SetAlpha) == "function" then
				local shown = false
				if type(b.IsShown) == "function" then
					local ok, s = pcall(b.IsShown, b)
					shown = ok and s or false
				end
				if shown then
					-- Recorded once. A later pass reads back the alpha this
					-- AddOn set, so remembering it would make "what it was
					-- before" mean 0 for ever after.
					if taken[b] == nil then
						local gotA, alpha = pcall(b.GetAlpha, b)
						local gotM, mouse = true, true
						if type(b.IsMouseEnabled) == "function" then
							gotM, mouse = pcall(b.IsMouseEnabled, b)
						end
						taken[b] = {
							alpha = (gotA and alpha) or 1,
							mouse = (gotM and mouse) and true or false,
						}
					end
					pcall(b.SetAlpha, b, 0)
					if type(b.EnableMouse) == "function" then
						pcall(b.EnableMouse, b, false)
					end
				end
			end
		end
	end

	function M:Enable()
		ensureHook()
		-- Applied here directly rather than by calling WatchFrame_Update.
		-- Driving Blizzard's rebuild from AddOn code is the same shape as the
		-- bag bug in #20, and there is nothing to rebuild: the buttons are
		-- already on screen and this only changes how they are drawn.
		M:trackerPass()
	end

	function M:Disable()
		-- Put back exactly what was taken, which is all the restore needs to
		-- be. No WatchFrame_Update: the tracker has not been changed, only
		-- the alpha and mouse state of buttons it already drew.
		for b, was in pairs(taken) do
			if type(b) == "table" then
				if type(b.SetAlpha) == "function" then
					pcall(b.SetAlpha, b, was.alpha)
				end
				if type(b.EnableMouse) == "function" then
					pcall(b.EnableMouse, b, was.mouse)
				end
			end
		end
		wipe(taken)
	end

	function M:Status()
		local n = 0
		for i = 1, maxItems() do
			if _G["WatchFrameItem" .. i] then n = n + 1 end
		end
		return n .. " item button(s) exist"
	end
end

---------------------------------------------------------------------
-- Turn-in pop-ups  (experimental)
---------------------------------------------------------------------
--
-- The bubble that slides out of the tracker saying a quest is ready to hand
-- in. EXPERIMENTAL, and honestly so: [G15] named the whole mechanism --
-- GetNumAutoQuestPopUps, GetAutoQuestPopUp, RemoveAutoQuestPopUp and the
-- WatchFrameAutoQuest_* display family -- but could not read the DATA, because
-- GetNumAutoQuestPopUps() returns 0 unless a pop-up is on screen at that
-- moment, and one cannot be summoned on demand.
--
-- So the first return of GetAutoQuestPopUp is TAKEN to be the questID that
-- RemoveAutoQuestPopUp wants. That is the one unverified assumption in this
-- file, it is why the option is experimental, and if it is wrong the pcall
-- swallows it and the pop-ups simply keep appearing.

do
	local M = ns:RegisterModule("noCompleteQuestPopup", {})
	M.title = "No Complete Quest Popup"
	M.desc  = "Removes the popup that tells you a quest can be completed."
	M.onText  = "Complete quest popup removed."
	M.offText = "Complete quest popup restored."
	M.group = "Experimental"
	M.order = 120
	M.experimental = true

	ns:RegisterDefaults({ noCompleteQuestPopup = false })

	local removed = 0

	function M:trackerPass()
		if type(GetNumAutoQuestPopUps) ~= "function"
			or type(GetAutoQuestPopUp) ~= "function"
			or type(RemoveAutoQuestPopUp) ~= "function" then
			return
		end
		local okn, n = pcall(GetNumAutoQuestPopUps)
		if not okn or type(n) ~= "number" then return end
		-- Backwards: removing an entry renumbers the ones after it.
		for i = n, 1, -1 do
			local okg, id = pcall(GetAutoQuestPopUp, i)
			if okg and id ~= nil then
				if pcall(RemoveAutoQuestPopUp, id) then removed = removed + 1 end
			end
		end
		if removed > 0 and type(WatchFrameAutoQuest_ClearPopUp) == "function" then
			pcall(WatchFrameAutoQuest_ClearPopUp)
		end
	end

	function M:Enable()
		ensureHook()
	end

	function M:Disable()
		-- Nothing to put back: the pop-ups are queued by the game as quests
		-- complete, so leaving it alone is the restore.
	end

	function M:Status()
		if type(GetNumAutoQuestPopUps) ~= "function" then return "pop-up API missing" end
		if removed == 0 then return "no pop-up seen yet" end
		return removed .. " pop-up(s) removed"
	end
end
