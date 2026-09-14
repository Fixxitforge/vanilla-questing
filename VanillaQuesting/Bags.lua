-- Vanilla Questing -- Bags
--
-- MoP puts a yellow highlight on quest items sitting in your bags. Classic did
-- not: a quest item looked like any other item, and knowing which was which
-- was part of reading the quest.
--
-- Probe v0.19 [G18] settled how to reach it. There is NO console variable --
-- every plausible name came back absent -- but every bag slot carries a
-- texture named ContainerFrame<N>Item<M>IconQuestTexture, 468 of them on this
-- client, and hiding it takes the highlight with it.
--
-- One coupling worth knowing: that single texture draws both the yellow border
-- on a quest item and the "!" on an item that STARTS a quest. Blizzard swaps
-- the texture on the same object rather than using two, so they cannot be
-- separated. Both go, which is the Classic result anyway.

local ADDON_NAME, ns = ...

local M = ns:RegisterModule("noBagItemHighlight", {})
M.title = "No Quest Item Highlight In Bags"
M.desc  = "Quest items in your bags stop being outlined in yellow, and items that start a quest lose their exclamation mark."
M.onText  = "Bag quest item highlight removed."
M.offText = "Bag quest item highlight restored."
M.group = "UI & Graphics"
M.order = 100

ns:RegisterDefaults({ noBagItemHighlight = true })

-- Bags redraw constantly, and each redraw puts the highlight back, so this
-- runs off a post-hook rather than once at login.
local hooked = false

-- What this AddOn actually took away, per container frame.
--
-- `scrub` is a POST-hook on ContainerFrame_Update, so by the time it runs the
-- game has already decided which slots should show a highlight. A texture that
-- is shown at that moment is one the game wants shown -- so hiding only those,
-- and remembering exactly them, makes the record an accurate list of what was
-- removed rather than a list of textures that happen to exist.
--
-- Rebuilt on every pass rather than accumulated. If a quest item is moved out
-- of a slot, the next redraw hides that texture itself, this pass does not
-- record it, and the stale entry goes with the old table. Accumulating would
-- mean putting a highlight back on a slot that no longer earns one.
local hidden = {}

-- The frame is passed in, so its own slots can be walked rather than sweeping
-- all 468 textures on every bag update.
local function scrub(frame)
	if not ns.db or not ns.db.settings.noBagItemHighlight then return end

	local name
	if type(frame) == "table" and type(frame.GetName) == "function" then
		local ok, n = pcall(frame.GetName, frame)
		name = ok and n or nil
	end
	if not name then return end

	local set = {}
	hidden[name] = set

	-- 36 is the largest bag this client draws; stopping at the first missing
	-- slot would cut short on a frame whose buttons are not contiguous.
	for i = 1, 36 do
		local tex = _G[name .. "Item" .. i .. "IconQuestTexture"]
		if tex and type(tex.Hide) == "function" then
			-- Only what is actually showing. Hiding an already-hidden texture
			-- is a no-op, but RECORDING it is not: it would be restored later
			-- as a highlight the game never drew.
			local read, shown = pcall(tex.IsShown, tex)
			if read and shown then
				set[tex] = true
				pcall(tex.Hide, tex)
			end
		end
	end
end

local function ensureHook()
	if hooked then return end
	if type(hooksecurefunc) ~= "function" or type(ContainerFrame_Update) ~= "function" then
		ns:Warn("bags:missing",
			"ContainerFrame_Update is not present on this client; skipping the bag quest highlight.")
		return
	end
	hooked = true
	hooksecurefunc("ContainerFrame_Update", scrub)
end

-- Every container frame currently on screen, so a change takes effect on bags
-- that are already open rather than waiting for the next redraw.
local function eachOpenContainer(fn)
	for i = 1, 13 do
		local f = _G["ContainerFrame" .. i]
		if f and type(f.IsShown) == "function" then
			local ok, shown = pcall(f.IsShown, f)
			if ok and shown then fn(f) end
		end
	end
end

function M:Enable()
	ensureHook()
	eachOpenContainer(scrub)
end

-- Put back exactly what was taken, and nothing else.
--
-- Two versions of this were wrong in opposite directions.
--
-- It used to CALL `ContainerFrame_Update` on every open container. Hooking it
-- is fine and is what Enable does; calling it runs Blizzard's container code
-- on a path AddOn Lua is already on, and bag buttons are taint-sensitive
-- (#20). So that went.
--
-- What replaced it was nothing at all -- on the reasoning that which slots
-- SHOULD show a highlight is the game's business, and the next redraw would
-- sort it out. True, and it left the option asymmetric in a way a player can
-- see: switching it ON removed the highlights immediately, with the bags open,
-- and switching it OFF did nothing until they moved an item or reopened a bag.
-- **An option that acts at once in one direction and not the other reads as
-- broken**, whatever the reasoning behind it.
--
-- The fix is neither. `scrub` already knows precisely which textures it hid,
-- because it only hides the ones the game had shown. Showing those again is
-- not a redraw and not a decision about what belongs there -- it is undoing
-- one `Hide()` with one `Show()`, on a texture, which is not a protected
-- object and carries none of the taint risk that calling Blizzard's update
-- function does.
--
-- If the game has changed its mind in the meantime, its own next redraw is
-- still the thing that decides. This only removes the AddOn's hand.
function M:Disable()
	for name, set in pairs(hidden) do
		for tex in pairs(set) do
			if type(tex.Show) == "function" then pcall(tex.Show, tex) end
		end
		hidden[name] = nil
	end
end

function M:Status()
	if type(ContainerFrame_Update) ~= "function" then return "ContainerFrame_Update missing" end
	local n = 0
	eachOpenContainer(function() n = n + 1 end)
	return n .. " bag frame(s) open"
end
