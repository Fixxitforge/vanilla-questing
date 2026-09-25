-- Every line Vanilla Questing can put in front of a player, in one place.
--
--     cd dev/tests && lua5.1 strings.lua > /tmp/strings.txt
--
-- Written for the one review the stub cannot do: reading the AddOn's own
-- wording, all of it at once, away from the code it is spread across. The
-- lines are DRIVEN, not transcribed -- the slash commands run, both panels are
-- built and hovered, the buttons are clicked and the dialogs they raise are
-- read back -- so a wording this file shows is a wording that ships. The one
-- exception is the warnings, which only appear on a client that is missing
-- something: those are read out of the source, and say so.
--
-- It was not always true. The dialog texts and the Defaults button's label
-- and tooltip were typed in here as literals, and the literal copy had
-- already lost one of the dialogs' variants ("Note: The UI will reload.")
-- and every button label. Nothing below is typed in any more.
--
-- It loads the test harness, so it has to run from this directory. It writes
-- to stdout and touches nothing.

local h = assert(loadfile("addon_harness.lua"))

-- The harness has no expansion globals, and without them the preset falls back
-- to "Disabled" -- a name the player never sees on a real client.
_G.EXPANSION_NAME4 = "Mists of Pandaria"
_G.GetClientDisplayExpansionLevel = function() return 4 end

local out = {}
local function emit(s) out[#out+1] = s end
local function head(t) emit("") emit("== " .. t .. " " .. string.rep("=", 60 - #t)) end
local function note(s) emit("  " .. s) end

-- The colour a line carries matters as much as its words, so name it rather
-- than print the escape. Several palette entries share a code on purpose
-- (`brand` and `limitation` are both the blue), so the name here is the
-- colour, not the palette key.
local COLOUR = {}
local WORD = {
	body = "normal yellow", highlight = "normal yellow", title = "white",
	muted = "grey", brand = "blue", limitation = "blue",
	experimental = "orange", error = "system yellow",
	on = "green", off = "red",
}

local function colours(s)
	-- The chat prefix is on every chat line and is always blue: naming it
	-- every time would drown the colour that is actually being asked about.
	s = tostring(s):gsub("^|c%x%x%x%x%x%x%x%x%[[^%]]*%]|r ", "")
	local seen, names = {}, {}
	for code in s:gmatch("|c%x%x%x%x%x%x%x%x") do
		local n = COLOUR[code] or code
		if not seen[n] then seen[n] = true names[#names+1] = n end
	end
	return table.concat(names, ", ")
end

local function plain(s)
	-- Both line breaks: the native panel writes |n, the fallback writes \n.
	return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
		:gsub("|n", "\n"):gsub("\n", "\n                             "))
end

local function line(s)
	local c = colours(s)
	emit(string.format("  %-28s %s", "[" .. (c == "" and "-" or c) .. "]", plain(s)))
end

local function boot(scenario)
	h(scenario)
	-- The harness echoes every chat line to stdout as it happens, which is
	-- where this script's own output goes. Keep the record, drop the echo --
	-- and do it before the AddOn loads, because loading is itself a moment it
	-- can have something to say.
	DEFAULT_CHAT_FRAME.AddMessage = function(_, m) chatlog[#chatlog + 1] = m end
	fire("ADDON_LOADED", "VanillaQuesting"); __loadVariables()
	fire("PLAYER_ENTERING_WORLD"); fire("PLAYER_LOGIN")
	for k, word in pairs(WORD) do COLOUR[ns.color[k]] = word end
end

-- Everything the AddOn printed since the mark, which is how a command is
-- reported rather than guessed at.
local mark = 0
local function since() for i = mark + 1, #chatlog do line(chatlog[i]) end end
local function say(cmd)
	mark = #chatlog
	emit("")
	emit("  /vq " .. cmd)
	pcall(SlashCmdList["VANILLAQUESTING"], cmd)
	since()
end

---------------------------------------------------------------------
-- The client whose settings panel the AddOn can use: chat, and the
-- options it registers there.
---------------------------------------------------------------------

boot("native")

head("CHAT: one option")
ns:ResetDefaults(true)
say("off hideBossPortraits")
say("off hideBossPortraits")
say("on hideBossPortraits")
say("status hideBossPortraits")

head("CHAT: everything")
say("off")
say("off")
say("on")

head("CHAT: the whole status list")
say("status")

head("CHAT: help")
say("help")

head("CHAT: mistakes")
say("wibble")
say("on wibble")
say("status wibble")

head("CHAT: in combat")
_G.__inCombat = true
say("off")
say("off hideMapQuestHelper")
mark = #chatlog
ns:OpenOptions()
since()
_G.__inCombat = false

head("CHAT: a Blizzard setting moved")
note("The same sentence for every option that mirrors one of Blizzard's,")
note("including the minimap tracking button.")
emit("")
mark = #chatlog
ns:Set("noInstantQuestText", true)
SetCVar("instantQuestText", "1")
SetCVar("instantQuestText", "0")
since()

head("THE MINIMAP TRACKING BUTTON: what it adds to the tooltip")
note("Always shown, whether the option is on or off. Tracking is Blizzard's own.")
emit("")
for i = #tooltipLines, 1, -1 do tooltipLines[i] = nil end
hoverTrackingButton()
for _, t in ipairs(tooltipLines) do line(t) end

-- Read, not run. Each of these appears only where a client is missing
-- something the AddOn expected, and no scenario reaches all of them.
head("CHAT: when something goes wrong")
note("All system yellow. Read out of the source, because these only appear on")
note("a client that is missing something. <angle brackets> are filled in as it happens.")
emit("")
local SUB = {
	["rule.cvar"] = "<cvar>", ["rule.label"] = "<option>",
	["tostring(value)"] = "<value>", ["tostring(now)"] = "<current>",
	["wanted"] = "<name>", ["tostring(err)"] = "<reason>",
	["tostring(m.key)"] = "<option>",
	['(on and "enable" or "disable")'] = "enable/disable",
}
for _, name in ipairs({ "Core", "CVars", "Minimap", "QuestFrame", "Tooltip",
                        "Tracker", "Bags", "Options" }) do
	local f = assert(io.open("../../VanillaQuesting/" .. name .. ".lua"))
	local src = f:read("*a")
	f:close()
	local at = 1
	while true do
		local s, e = src:find("ns:Warn(", at, true)
		if not s then break end
		at = e + 1
		-- The definition of Warn is not a call to it.
		if src:sub(s - 9, s - 1) ~= "function " then
			local depth, i = 1, e + 1
			while depth > 0 do
				local c = src:sub(i, i)
				if c == "(" then depth = depth + 1 elseif c == ")" then depth = depth - 1 end
				i = i + 1
			end
			local arg = src:sub(e + 1, i - 2):match("^[^,]*,(.*)$")
			local text = ""
			for part in (arg .. " .. "):gmatch("(.-)%s*%.%.%s*") do
				part = part:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s*\n%s*", " ")
				if part:sub(1, 1) == '"' then
					text = text .. part:sub(2, -2)
				elseif part ~= "" then
					text = text .. (SUB[part] or ("<" .. part .. ">"))
				end
			end
			emit(string.format("  %-28s [%s] %s", "[system yellow]", ns.title, text))
		end
	end
end

head("OPTIONS PANEL: section headings")
for _, t in ipairs(_G.__headers or {}) do line(t) end

head("OPTIONS PANEL: description rows")
for _, t in ipairs(_G.__descriptionRows or {}) do line(t) end

head("OPTIONS PANEL: every checkbox, label then tooltip")
for _, c in ipairs(_G.__nativeControls or {}) do
	if c.kind == "checkbox" then
		emit("")
		for _, l in ipairs(_G.__renderCheckboxTooltip(c)) do line(l.text) end
	end
end

head("OPTIONS PANEL: the preset dropdown")
ns:ResetDefaults(true)
emit("")
note("every option on, no experiments")
for _, o in ipairs(_G.__rebuildPresetOptions()) do line(o.label) end
ns:Set("noCompleteQuestPopup", true)
emit("")
note("every option on, one experiment on")
for _, o in ipairs(_G.__rebuildPresetOptions()) do line(o.label) end
ns:Set("hideBossPortraits", false)
emit("")
note("neither preset matches")
for _, o in ipairs(_G.__rebuildPresetOptions()) do line(o.label) end
ns:ResetDefaults(true)
emit("")
note("its tooltip")
for _, c in ipairs(_G.__nativeControls or {}) do
	if c.kind == "dropdown" and c.tooltip then line(c.tooltip) end
end

---------------------------------------------------------------------
-- The client whose settings panel it cannot use: the AddOn draws its
-- own window, and says so.
---------------------------------------------------------------------

boot("no_settings")

head("CHAT: when the client's own panel cannot be used")
mark = 0
since()

head("FALLBACK PANEL: what the AddOn draws itself")
emit("")
ns:OpenOptions()
for _, t in ipairs(_G.fontstrings) do
	if type(t.__text) == "string" and t.__text ~= "" then line(t.__text) end
end

-- Hover something and print what the tooltip got, title first.
local function hover(f)
	_G.__tooltipLines = {}
	pcall(rawget(f, "script_OnEnter"), f)
	for _, t in ipairs(_G.__tooltipLines) do line(t) end
end

head("FALLBACK PANEL: every checkbox's tooltip, title then body")
note("Built by this panel's own code, not the native panel's -- the two have")
note("drifted apart before, so these are hovered rather than assumed. A body")
note("marked [-] is yellow all the same: this panel passes the colour to")
note("AddLine as numbers rather than as an escape in the text.")
local boxes, seen = {}, {}
for i = 1, #frames do
	local f = frames[i]
	if rawget(f, "script_OnEnter") and rawget(f, "__checked") ~= nil and not seen[f] then
		seen[f] = true
		boxes[#boxes + 1] = f
		emit("")
		hover(f)
	end
end

local function button(text)
	for i = 1, #frames do
		if rawget(frames[i], "__text") == text and rawget(frames[i], "script_OnClick") then
			return frames[i]
		end
	end
end

head("FALLBACK PANEL: the preset control's tooltip")
emit("")
local arrow = button(">")
if arrow then hover(arrow) end

head("FALLBACK PANEL: the Defaults button")
emit("")
local defaults = button("Defaults")
if defaults then
	note("its label")
	line(rawget(defaults, "__text"))
	note("hovered")
	hover(defaults)
end

-- Whatever dialog is up, as the player would read it: the question, then the
-- two buttons.
local function dialog()
	local d = _G.__popup and StaticPopupDialogs[_G.__popup]
	if not d then note("(no dialog)") return end
	line(d.text)
	line("[" .. tostring(d.button1) .. "]  [" .. tostring(d.button2) .. "]")
end

head("THE DIALOGS")
note("These belong to the fallback panel. Blizzard's own panel asks through")
note("its own Apply button instead.")

ns:ResetDefaults(true)
ns.RefreshOptions()
emit("")
note("ticking the one option that needs a reload")
local mapBox
for _, f in ipairs(boxes) do
	_G.__tooltipLines = {}
	pcall(rawget(f, "script_OnEnter"), f)
	if _G.__tooltipLines[1] == ns.modules.hideMapQuestHelper.title then mapBox = f end
end
_G.__popup = nil
if mapBox then pcall(rawget(mapBox, "script_OnClick"), mapBox) end
dialog()
popupCancel()

emit("")
note("a preset that moves it along with others")
_G.__popup = nil
if arrow then pcall(rawget(arrow, "script_OnClick"), arrow) end
dialog()
popupCancel()

emit("")
note("Defaults, with nothing that needs a reload")
ns:ResetDefaults(true)
ns.RefreshOptions()
_G.__popup = nil
if defaults then pcall(rawget(defaults, "script_OnClick"), defaults) end
dialog()
popupCancel()

emit("")
note("Defaults, with the reload option moved")
ns:Set("hideMapQuestHelper", false)
_G.__popup = nil
if defaults then pcall(rawget(defaults, "script_OnClick"), defaults) end
dialog()
popupCancel()

---------------------------------------------------------------------

print(ns.title .. " " .. tostring(ns.version) .. " - every line the player can see")
print("Generated by dev/tests/strings.lua from the AddOn itself, not transcribed.")
print("[colour] names the colours inside the line; the escapes are stripped.")
print("The [" .. ns.title .. "] chat prefix is always blue and is not listed.")
for _, s in ipairs(out) do print((s:gsub("[ \t]+$", ""))) end
