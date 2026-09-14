-- Vanilla Questing -- Minimap
--
-- One lever does both jobs: the "Track Quest POIs" entry in
-- the minimap tracking list controls the numbered quest pins AND the blue
-- quest objective area. Confirmed in game; see SPEC.md conclusions G1/G2.
--
-- The Minimap:SetQuestBlob* widget methods the original spec assumed do not
-- exist on this client -- the full 205-method dump has no blob methods at
-- all. The blob is engine-drawn and switched through tracking instead.

local ADDON_NAME, ns = ...

local C = ns.color

local M = ns:RegisterModule("hideMinimapQuestHelper", {})
M.onText = "Minimap quest markers and the blue quest areas removed."
M.offText = "Minimap quest helper restored."
M.group = "Map and minimap"
M.title = "Hide Minimap Quest Helper"
M.order = 20
M.desc = "Switches the " .. C.title .. "Track Quest POIs" .. C.close .. " tracking off, removing both the quest markers and the blue objective areas from the minimap."
-- SHARED, not owned. The player has a control of their own for this -- the
-- minimap tracking dropdown -- so the two agree with each other rather than
-- one of them winning. Named here for the same reason a CVar rule names its
-- `blizzOption`: the mirror's chat line has to say which control moved.
--
-- Not `blizzVariable`, which is for annotating a row in Blizzard's settings
-- panel. This one lives in a dropdown on the minimap and there is no row.
M.blizzOption = "Track Quest POIs"

-- One name: module key, saved-settings key and typed handle are all the same.
ns:RegisterDefaults({
	hideMinimapQuestHelper = true,
})

local applying = false
local refused = false

local tooltipHooked = false

local function api()
	local C = C_Minimap
	if type(C) ~= "table"
		or type(C.GetNumTrackingTypes) ~= "function"
		or type(C.GetTrackingInfo) ~= "function"
		or type(C.SetTracking) ~= "function" then
		return nil
	end
	return C
end

-- Resolve the entry by NAME, never by a hardcoded index.
--
-- The indices are not stable: they shift with class and profession. On the
-- recon character "Track Quest POIs" sat at 17, but index 1 was "Find Herbs",
-- which only exists because that character is a herbalist. Hardcoding 17
-- would appear to work there and silently toggle some unrelated tracking
-- type on the next character.
local function findEntry()
	local C = api()
	if not C then
		ns:Warn("mm:api", "C_Minimap tracking API missing; minimap markers are untouched.")
		return nil
	end

	local wanted = MINIMAP_TRACKING_QUEST_POIS
	if type(wanted) ~= "string" then
		ns:Warn("mm:name", "MINIMAP_TRACKING_QUEST_POIS missing; minimap markers are untouched.")
		return nil
	end

	local ok, count = pcall(C.GetNumTrackingTypes)
	if not ok or type(count) ~= "number" then
		ns:Warn("mm:count", "could not read the tracking list; minimap markers are untouched.")
		return nil
	end

	for i = 1, count do
		local gotInfo, info = pcall(C.GetTrackingInfo, i)
		if gotInfo and type(info) == "table" and info.name == wanted then
			return i, info
		end
	end

	ns:Warn("mm:notfound",
		"no '" .. wanted .. "' entry in the tracking list; minimap markers are untouched.")
	return nil
end

local function setTracking(index, enabled)
	local C = api()
	if not C then return false end
	applying = true
	local ok = pcall(C.SetTracking, index, enabled)
	applying = false
	return ok
end

-- How many passes may disagree before the write is called refused. Three is
-- not a magic number: it is "more than a frame or two", which is all the race
-- needs, while still standing down on a client that truly ignores the call
-- rather than retrying forever.
local VERIFY_ATTEMPTS = 3
local failedVerifies = 0

-- Have we ever actually seen the entry off?
--
-- `C_Minimap.SetTracking` returns nothing, and the change is announced by
-- MINIMAP_UPDATE_TRACKING -- the same event the mirror runs on. So an early
-- pass can be answering from before this AddOn's own write landed, and an
-- entry that is still showing looks exactly like the player having just
-- ticked it.
--
-- This is what separates them. Until the entry has been seen off at least
-- once, an active entry is the state we are still waiting to change, not the
-- player changing it back. Latching on a single reading turned a slow client
-- into a permanent refusal once already: the AddOn stood down, printed an
-- accusation in chat, and left the markers showing on a setting that would
-- have worked.
local confirmedOff = false

-- Ask once.
--
-- Called from Enable only. This AddOn asks for the entry the way it asks for
-- `instantQuestText` -- once, on the way in -- and the mirror below handles
-- whatever the player does afterwards. There is no re-assert loop any more
-- and no read-back here: the event says whether it landed.
local function applyOff(index, info)
	if applying or refused then return end
	if not ns.db or not ns.db.settings[M.key] then return end

	-- Enable has already found the entry. Finding it again means seventeen
	-- more pcall'd API calls for an answer we were handed, and this runs on
	-- every options-panel click.
	if not index then index, info = findEntry() end
	if not index then return end
	if not info.active then
		-- Already off: nothing to do, no event to cause, and proof that any
		-- earlier disagreement was the client being slow rather than refusing.
		failedVerifies = 0
		confirmedOff = true
		return
	end

	if not setTracking(index, false) then
		refused = true
		ns:Warn("mm:set", "could not change quest POI tracking; minimap markers are untouched.")
		return
	end

	-- Read back, but only ever to CONFIRM.
	--
	-- On a client that applies the write immediately this is where we learn
	-- the entry is off, and the mirror needs that before it can tell "the
	-- player ticked it" from "our write has not landed". On a slow client the
	-- read is stale, we simply learn nothing here, and MINIMAP_UPDATE_TRACKING
	-- tells us a moment later.
	--
	-- What this must never do is latch a failure. Reading back on the next
	-- line and believing a negative is exactly the bug that turned a slow
	-- client into a permanent refusal; counting disagreements is the mirror's
	-- job, where there is an event to count them against.
	local C = api()
	local gotAfter, after = pcall(C.GetTrackingInfo, index)
	if gotAfter and type(after) == "table" and not after.active then
		confirmedOff = true
	end
end

-- The two-way mirror, and the whole of what makes this option SHARED.
--
-- v1.0.1 and everything before it OWNED the entry: the player ticking Track
-- Quest POIs in the dropdown was overruled, and told so in chat. That is the
-- right shape for an option whose effect has no other control -- `questPOI`,
-- `showBosses` -- and the wrong one here, because the dropdown IS a control
-- and forcing a Blizzard control to stay where this AddOn wants it is the one
-- thing the ours/shared/mirror split exists to stop.
--
-- So it now behaves exactly as Instant Quest Text and Automatic Quest
-- Tracking do: whichever way the player moves it, the option follows and says
-- so. Nothing is forced back.
--
-- What does NOT change: `/vq off` still leaves Track Quest POIs ticked. That
-- is Disable handing the entry back, not enforcement.
local function mirror()
	if applying or not ns.db then return end
	if refused then return end

	-- Nothing before the first ApplyAll, for the same reason CVAR_UPDATE is
	-- gated: the client announces tracking state as it builds the list, and
	-- that is the game reporting what the player already had rather than the
	-- player changing anything.
	if not ns.applied then return end

	local index, info = findEntry()
	if not index then return end

	local shouldBeOn = not info.active
	local on = ns.db.settings[M.key] and true or false

	if shouldBeOn then confirmedOff = true end
	if shouldBeOn == on then
		failedVerifies = 0
		return
	end

	if not shouldBeOn and not confirmedOff then
		-- The entry is showing while the option says it should not be, and we
		-- have never seen it off -- so this is our own write still in flight,
		-- or one that is being ignored. Several passes tell those apart.
		failedVerifies = failedVerifies + 1
		if failedVerifies >= VERIFY_ATTEMPTS then
			refused = true
			ns:Warn("mm:refused",
				"quest POI tracking would not turn off; minimap markers are untouched.")
		end
		return
	end

	ns.db.settings[M.key] = shouldBeOn

	if shouldBeOn then
		-- Adopted rather than applied: the player turned the entry off
		-- themselves, so this AddOn wrote nothing. It still has to mark the
		-- entry as ours, or switching the option off afterwards finds no
		-- ownership and hands back nothing -- the same bug the CVar mirror
		-- had, for the same reason. The mirror writes `settings` directly,
		-- so Enable never runs to mark it.
		if ns.db.state.minimapMarkersTracking == nil then
			ns.db.state.minimapMarkersTracking = false
		end
	else
		-- Handed back. The player owns the entry again, so the marker goes
		-- and the next Enable is the one that reclaims it. Leaving it behind
		-- would let a later Disable turn tracking on under a player who had
		-- deliberately left it on.
		ns.db.state.minimapMarkersTracking = nil
		confirmedOff = false
		failedVerifies = 0
	end

	ns:Print(C.highlight .. M.blizzOption .. C.close ..
		" was changed in Blizzard's options, so " .. C.highlight ..
		M.key .. C.close .. " is now " ..
		(shouldBeOn and (C.on .. "on" .. C.close) or (C.off .. "off" .. C.close)) .. ".")

	if ns.RefreshOptions then ns.RefreshOptions() end
end

-- Adding a line to the tracking button's tooltip is the polite way to
-- explain the behaviour: it is a script hook on an ordinary UI button, it
-- adds no quest data, and it touches none of Blizzard's menu logic, so it
-- stays clear of the taint risk in safety rule 2. If the button is not
-- where we expect, we simply do without it -- the chat notice below is the
-- guaranteed path.
local function attachTooltip()
	if tooltipHooked then return end
	local btn = MiniMapTrackingButton or MiniMapTracking
	if not btn or type(btn.HookScript) ~= "function" then
		ns:Warn("mm:tooltip", "tracking button not found; using chat notices instead of a tooltip.")
		return
	end

	local ok = pcall(function()
		btn:HookScript("OnEnter", function(self)
			if not GameTooltip or type(GameTooltip.AddLine) ~= "function" then return end
			if GameTooltip.GetOwner and GameTooltip:GetOwner() ~= self then return end

			-- The line is ALWAYS added, whatever the option is set to.
			--
			-- Two bugs lived here, and the second was mine for reading the
			-- first one too narrowly. The original report was that the whole
			-- "Tracking" tooltip vanished when the option stood down: an early
			-- return at the top of this hook meant Show() never ran, and on
			-- this client that Show() is what puts Blizzard's own tooltip on
			-- screen. The AddOn had quietly become load-bearing for a frame it
			-- only meant to annotate.
			--
			-- Fixing that by gating only the AddLine calls was still wrong. A
			-- player hovering this entry wants to know that Vanilla Questing
			-- has a hand in it -- and they want it MOST when the option is
			-- off, because that is when the entry is behaving in a way the
			-- AddOn did not cause and they are trying to work out why. A note
			-- that disappears exactly when the question arises is worse than
			-- no note.
			--
			-- So: no condition. The block below runs on every hover, and
			-- Show() after it.
			--
			-- Blank spacer, then the AddOn name as its own header line so the
			-- block reads as ours rather than as part of Blizzard's tooltip. A
			-- tooltip header cannot be made larger: AddLine has no per-line
			-- font, and the big header font applies only to the tooltip's own
			-- first line. So separate the block by colour instead, using the
			-- AddOn's chat blue, which stands clear of Blizzard's white body
			-- text and yellow highlights.
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(C.title .. "Track Quest POIs" .. C.close .. " " ..
				C.brand .. "is managed by " .. ns.title .. "." .. C.close)
			GameTooltip:Show()
		end)
	end)
	tooltipHooked = ok
end

function M:Enable()
	local index, info = findEntry()
	if not index then return end

	-- Marks that this AddOn is the one holding the entry down, so a bulk
	-- `/vq off` on an option that was never switched on changes nothing. What
	-- it holds is not read: see Disable.
	if ns.db.state.minimapMarkersTracking == nil then
		ns.db.state.minimapMarkersTracking = info.active and true or false
	end

	applyOff(index, info)
	attachTooltip()
end

-- Switching this option OFF turns Track Quest POIs back ON.
--
-- This is Disable handing the entry back, not enforcement, and it is the one
-- part of the owned behaviour that survives being SHARED: the AddOn turned
-- the entry off, so the AddOn turns it on again on the way out. `/vq off`
-- leaves the dropdown ticked, which is what it did before and what people
-- type on their way to uninstalling.
--
-- Only when the marker is set. An option that was never switched on holds
-- nothing, so a bulk `/vq off` moves nothing -- and neither does a Disable
-- that follows the mirror having already handed the entry back.
--
-- The case this gives up on: a player who had turned Track Quest POIs off by
-- hand BEFORE installing gets it back on when they switch the option off.
-- Deliberate, and much smaller than it was -- now that the mirror follows the
-- dropdown, they can simply untick it again and the option follows them.
--
-- Fourth position on this question, and the one the taxonomy actually
-- implies. v0.18.0 forced it on; #27 argued for the remembered value and that
-- shipped; the audit made it owned and forced it on again; and forcing a
-- Blizzard control to stay where this AddOn wants it is precisely what
-- "shared" exists to stop. The dropdown is a control. This option shares it.
--
-- No chat line here. The mirror says everything that needs saying, and
-- announcing that a setting is where the player expects it is noise.
function M:Disable()
	confirmedOff = false
	local index, info = findEntry()
	if not index then return end

	-- Only when this AddOn was the one holding it down.
	if not ns.db or ns.db.state.minimapMarkersTracking == nil then return end
	ns.db.state.minimapMarkersTracking = nil

	if not info.active then
		failedVerifies = 0
		setTracking(index, true)
	end
end

function M:Status()
	local index, info = findEntry()
	if not index then return "tracking entry not found" end
	if refused then return "tracking entry #" .. index .. " (write refused)" end
	return "tracking entry #" .. index .. ", quest POIs " ..
		(info.active and (C.off .. "showing" .. C.close) or "hidden")
end

-- The dropdown is the player's control and stays fully functional. Ticking
-- "Track Quest POIs" fires this, and the option follows rather than fighting
-- it -- which needs nothing from Blizzard's menu code and so stays clear of
-- the taint risk in safety rule 2, exactly as the old re-assert did.
ns:RegisterEvent("MINIMAP_UPDATE_TRACKING", mirror)
