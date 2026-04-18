local support = {}

local DEFAULT_FILES = {
	"Core/Constants.lua",
	"Core/Namespaces.lua",
	"Core/Utils.lua",
	"Core/ReputationUtils.lua",
	"Data/Expansions.lua",
	"Data/FactionExpansionMap.lua",
	"Core/ExpansionUtils.lua",
	"Core/DebugLog.lua",
	"Core/State.lua",
	"Core/CharacterStore.lua",
	"Core/NormalizerHelpers.lua",
	"Core/NormalizerEntryMath.lua",
	"Core/Normalizer.lua",
	"Core/FactionTree.lua",
	"Core/Index.lua",
	"Core/FactionFilters.lua",
	"Core/FactionTreeView.lua",
	"Core/ReputationEventHints.lua",
	"Core/LiveUpdateController.lua",
	"Core/ScanScheduler.lua",
	"Core/Bootstrap.lua",
}

support.DEFAULT_FILES = {}
for index = 1, #DEFAULT_FILES do
	support.DEFAULT_FILES[index] = DEFAULT_FILES[index]
end

local function join_path(...)
	return table.concat({ ... }, "/")
end

local function sorted_keys(tbl)
	local keys = {}
	for key in pairs(tbl or {}) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

local function is_array(tbl)
	if type(tbl) ~= "table" then
		return false
	end
	local count = 0
	for key in pairs(tbl) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			return false
		end
		count = count + 1
	end
	for index = 1, count do
		if tbl[index] == nil then
			return false
		end
	end
	return true
end

local function pretty(value, seen)
	local value_type = type(value)
	if value_type == "string" then
		return string.format("%q", value)
	end
	if value_type ~= "table" then
		return tostring(value)
	end

	seen = seen or {}
	if seen[value] then
		return "<cycle>"
	end
	seen[value] = true

	local parts = {}
	if is_array(value) then
		for index = 1, #value do
			parts[#parts + 1] = pretty(value[index], seen)
		end
	else
		for _, key in ipairs(sorted_keys(value)) do
			parts[#parts + 1] = string.format("[%s]=%s", pretty(key, seen), pretty(value[key], seen))
		end
	end

	seen[value] = nil
	return "{" .. table.concat(parts, ", ") .. "}"
end

local function deep_equal(a, b, seen)
	if a == b then
		return true
	end
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return false
	end

	seen = seen or {}
	if seen[a] ~= nil then
		return seen[a] == b
	end
	seen[a] = b

	local checked = {}
	for key, value in pairs(a) do
		if not deep_equal(value, b[key], seen) then
			return false
		end
		checked[key] = true
	end
	for key in pairs(b) do
		if not checked[key] then
			return false
		end
	end
	return true
end

local assertions = {}

function assertions.equal(actual, expected, message)
	if actual == expected then
		return
	end
	error(string.format(
		"%sExpected %s, got %s",
		message and (message .. "\n") or "",
		pretty(expected),
		pretty(actual)
	), 2)
end

function assertions.same(actual, expected, message)
	if deep_equal(actual, expected) then
		return
	end
	error(string.format(
		"%sExpected %s, got %s",
		message and (message .. "\n") or "",
		pretty(expected),
		pretty(actual)
	), 2)
end

function assertions.truthy(value, message)
	if value then
		return
	end
	error(message or "Expected a truthy value.", 2)
end

function assertions.falsy(value, message)
	if not value then
		return
	end
	error(message or "Expected a falsy value.", 2)
end

function assertions.contains(text, needle, message)
	text = tostring(text or "")
	needle = tostring(needle or "")
	if text:find(needle, 1, true) then
		return
	end
	error(string.format(
		"%sExpected %s to contain %s",
		message and (message .. "\n") or "",
		pretty(text),
		pretty(needle)
	), 2)
end

function assertions.near(actual, expected, tolerance, message)
	tolerance = tolerance or 1e-6
	if math.abs(actual - expected) <= tolerance then
		return
	end
	error(string.format(
		"%sExpected %s to be within %s of %s",
		message and (message .. "\n") or "",
		pretty(actual),
		pretty(tolerance),
		pretty(expected)
	), 2)
end

support.assert = assertions

function support.copy_array(values)
	local out = {}
	for index = 1, #(values or {}) do
		out[index] = values[index]
	end
	return out
end

function support.with_files(extra_files)
	local files = support.copy_array(support.DEFAULT_FILES)
	for index = 1, #(extra_files or {}) do
		files[#files + 1] = extra_files[index]
	end
	return files
end

local function merge_overrides(target, overrides)
	for key, value in pairs(overrides or {}) do
		target[key] = value
	end
	return target
end

function support.make_reputation(ns, overrides)
	local rep = {
		factionID = 0,
		name = "Example Faction",
		description = "",
		expansionKey = ns.ALL_EXPANSIONS_KEY,
		repType = ns.REP_TYPE.STANDARD,
		standingId = 4,
		currentValue = 0,
		maxValue = 3000,
		currentStanding = 0,
		bottomValue = 0,
		topValue = 3000,
		isAccountWide = false,
		isWatched = false,
		atWar = false,
		canToggleAtWar = false,
		isChild = false,
		headerPath = {},
		hasParagon = false,
		paragonValue = 0,
		paragonThreshold = 0,
		paragonRewardPending = false,
		majorFactionID = 0,
		renownLevel = 0,
		renownMaxLevel = 0,
		friendCurrentRank = 0,
		friendMaxRank = 0,
		friendTextLevel = "",
	}
	merge_overrides(rep, overrides)

	if rep.factionKey == nil and ns.SafeNumber(rep.factionID, 0) > 0 then
		rep.factionKey = tostring(rep.factionID)
	end

	if ns.NormalizerHelpers and ns.NormalizerHelpers.ApplyRuntimeReputationFields then
		ns.NormalizerHelpers.ApplyRuntimeReputationFields(rep)
	end

	return rep
end

function support.make_snapshot(ns, overrides)
	local snapshot = {
		characterKey = "TestRealm::Tester",
		name = "Tester",
		realm = "TestRealm",
		className = "Mage",
		classFile = "MAGE",
		classID = 8,
		raceName = "Human",
		raceFile = "Human",
		raceID = 1,
		factionName = "Alliance",
		level = 80,
		guid = "Player-1-0000000000",
		lastKnownZone = "Stormwind",
		lastScanAt = ns.SafeTime and ns.SafeTime() or 0,
		lastScanReason = ns.SCAN_REASON and ns.SCAN_REASON.MANUAL_REFRESH or "Manual refresh",
		reputations = {},
		scanNotes = {},
	}
	merge_overrides(snapshot, overrides)

	if snapshot.reputationCount == nil and ns.CountTable then
		snapshot.reputationCount = ns.CountTable(snapshot.reputations)
	end

	return snapshot
end

local function sort_timers(env)
	table.sort(env.__timers, function(a, b)
		if a.at ~= b.at then
			return a.at < b.at
		end
		return a.id < b.id
	end)
end

local function create_test_env()
	local env = {}
	setmetatable(env, { __index = _G })

	local function nop()
	end

	local function set_shown(frame, shown)
		local was_shown = frame.__shown == true
		shown = shown == true
		frame.__shown = shown
		if shown == was_shown then
			return
		end
		local script_name = shown and "OnShow" or "OnHide"
		local handler = frame.__scripts[script_name]
		if type(handler) == "function" then
			handler(frame)
		end
	end

	local function create_font_string()
		local font_string = {
			__text = "",
		}

		function font_string:SetPoint(...)
			self.__point = { ... }
		end

		function font_string:SetText(text)
			self.__text = tostring(text or "")
		end

		function font_string:GetText()
			return self.__text
		end

		function font_string:SetTextColor(...)
			self.__text_color = { ... }
		end

		font_string.SetJustifyH = nop
		font_string.SetJustifyV = nop
		font_string.SetWordWrap = nop
		font_string.SetNonSpaceWrap = nop
		font_string.SetMaxLines = nop
		font_string.SetWidth = nop

		return font_string
	end

	local function create_texture()
		local texture = {}

		function texture:SetAllPoints(...)
			self.__all_points = { ... }
		end

		function texture:SetColorTexture(...)
			self.__color = { ... }
		end

		texture.SetHorizTile = nop
		texture.SetTexture = nop

		return texture
	end

	local function create_frame_object(frame_name, parent, template)
		local frame = {
			__events = {},
			__scripts = {},
			__shown = false,
			__enabled = true,
			__text = "",
			__checked = false,
			__name = frame_name,
			__template = template,
			__parent = parent,
		}

		function frame:RegisterEvent(event_name)
			self.__events[event_name] = true
		end

		function frame:UnregisterEvent(event_name)
			self.__events[event_name] = nil
		end

		function frame:SetScript(script_name, handler)
			self.__scripts[script_name] = handler
		end

		function frame:GetScript(script_name)
			return self.__scripts[script_name]
		end

		function frame:IsShown()
			return self.__shown
		end

		function frame:SetShown(shown)
			set_shown(self, shown)
		end

		function frame:Show()
			set_shown(self, true)
		end

		function frame:Hide()
			set_shown(self, false)
		end

		function frame:SetEnabled(enabled)
			self.__enabled = enabled == true
		end

		function frame:IsEnabled()
			return self.__enabled ~= false
		end

		function frame:Enable()
			self.__enabled = true
		end

		function frame:Disable()
			self.__enabled = false
		end

		function frame:SetChecked(checked)
			self.__checked = checked == true
		end

		function frame:GetChecked()
			return self.__checked == true
		end

		function frame:SetText(text)
			self.__text = tostring(text or "")
		end

		function frame:GetText()
			return self.__text
		end

		function frame:SetStatusBarTexture()
			self.__status_bar_texture = create_texture()
		end

		function frame:GetStatusBarTexture()
			self.__status_bar_texture = self.__status_bar_texture or create_texture()
			return self.__status_bar_texture
		end

		function frame:SetScrollChild(child)
			self.__scroll_child = child
		end

		function frame:SetParent(next_parent)
			self.__parent = next_parent
		end

		function frame:GetParent()
			return self.__parent
		end

		function frame:GetName()
			return self.__name
		end

		function frame:CreateFontString()
			local child = create_font_string()
			self.__font_strings = self.__font_strings or {}
			self.__font_strings[#self.__font_strings + 1] = child
			return child
		end

		function frame:CreateTexture()
			local child = create_texture()
			self.__textures = self.__textures or {}
			self.__textures[#self.__textures + 1] = child
			return child
		end

		frame.SetPoint = nop
		frame.SetSize = nop
		frame.SetWidth = nop
		frame.SetHeight = nop
		frame.SetFrameStrata = nop
		frame.SetBackdrop = nop
		frame.SetBackdropColor = nop
		frame.SetBackdropBorderColor = nop
		frame.EnableMouse = nop
		frame.EnableMouseWheel = nop
		frame.SetMovable = nop
		frame.RegisterForDrag = nop
		frame.StartMoving = nop
		frame.StopMovingOrSizing = nop
		frame.SetAlpha = nop
		frame.SetAutoFocus = nop
		frame.SetNumeric = nop
		frame.SetMinMaxValues = nop
		frame.SetStatusBarColor = nop
		frame.SetJustifyH = nop
		frame.SetJustifyV = nop
		frame.ClearFocus = nop
		frame.SetValue = nop
		frame.SetHitRectInsets = nop

		return frame
	end

	env._G = env
	env.RepSheet = {}
	env.RepSheetDB = {}
	env.SlashCmdList = {}
	env.C_Reputation = {}
	env.C_MajorFactions = {}
	env.UIParent = {}
	env.UISpecialFrames = {}
	env.__chat_messages = {}
	env.DEFAULT_CHAT_FRAME = {
		AddMessage = function(_, message)
			env.__chat_messages[#env.__chat_messages + 1] = tostring(message)
		end,
	}
	env.RAID_CLASS_COLORS = {
		MAGE = { r = 0.25, g = 0.78, b = 0.92 },
		PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
		ROGUE = { r = 1.0, g = 0.96, b = 0.41 },
	}

	env.__frames = {}
	env.__timers = {}
	env.__next_timer_id = 0
	env.__settings_categories = {}
	env.__opened_settings_category = nil
	env.__now = 1700000000
	env.__inCombat = false
	env.__player = {
		name = "Tester",
		realm = "TestRealm",
		localizedClass = "Mage",
		classFile = "MAGE",
		classID = 8,
		raceName = "Human",
		raceFile = "Human",
		raceID = 1,
		factionName = "Alliance",
		level = 80,
		guid = "Player-1-0000000000",
		zone = "Stormwind",
		professions = nil,
	}

	env.LE_EXPANSION_CLASSIC = 0
	env.LE_EXPANSION_BURNING_CRUSADE = 1
	env.LE_EXPANSION_WRATH_OF_THE_LICH_KING = 2
	env.LE_EXPANSION_CATACLYSM = 3
	env.LE_EXPANSION_MISTS_OF_PANDARIA = 4
	env.LE_EXPANSION_WARLORDS_OF_DRAENOR = 5
	env.LE_EXPANSION_LEGION = 6
	env.LE_EXPANSION_BATTLE_FOR_AZEROTH = 7
	env.LE_EXPANSION_SHADOWLANDS = 8
	env.LE_EXPANSION_DRAGONFLIGHT = 9
	env.LE_EXPANSION_WAR_WITHIN = 10
	env.LE_EXPANSION_MIDNIGHT = 11

	env.wipe = function(tbl)
		for key in pairs(tbl or {}) do
			tbl[key] = nil
		end
		return tbl
	end

	env.time = function()
		return math.floor(env.__now)
	end

	env.GetTime = function()
		return env.__now
	end

	env.GetTimePreciseSec = function()
		return env.__now
	end

	env.date = function(format_string, timestamp)
		return os.date(format_string, math.floor(timestamp or env.__now))
	end

	env.InCombatLockdown = function()
		return env.__inCombat == true
	end

	env.UnitFullName = function(unit)
		if unit == "player" then
			return env.__player.name, env.__player.realm
		end
		return nil, nil
	end

	env.UnitName = function(unit)
		if unit == "player" then
			return env.__player.name
		end
		return nil
	end

	env.GetRealmName = function()
		return env.__player.realm
	end

	env.UnitClass = function(unit)
		if unit == "player" then
			return env.__player.localizedClass, env.__player.classFile, env.__player.classID
		end
		return nil, nil, nil
	end

	env.UnitRace = function(unit)
		if unit == "player" then
			return env.__player.raceName, env.__player.raceFile, env.__player.raceID
		end
		return nil, nil, nil
	end

	env.UnitFactionGroup = function(unit)
		if unit == "player" then
			return env.__player.factionName
		end
		return nil
	end

	env.UnitLevel = function(unit)
		if unit == "player" then
			return env.__player.level
		end
		return 0
	end

	env.UnitGUID = function(unit)
		if unit == "player" then
			return env.__player.guid
		end
		return nil
	end

	env.GetRealZoneText = function()
		return env.__player.zone
	end

	env.GetProfessions = function()
		local data = env.__player.professions
		if type(data) ~= "table" then
			return nil, nil
		end
		return data.prof1Index, data.prof2Index
	end

	env.GetProfessionInfo = function(index)
		local data = env.__player.professions
		if type(data) ~= "table" or type(data.byIndex) ~= "table" then
			return nil
		end
		local info = data.byIndex[index]
		if type(info) ~= "table" then
			return nil
		end
		return info.name, info.icon, info.skillLevel, info.maxSkillLevel
	end

	env.C_AddOns = {
		GetAddOnMetadata = function(addon_name, metadata_key)
			if addon_name == "RepSheet" and metadata_key == "Version" then
				return "test-version"
			end
			return nil
		end,
	}

	env.GetAddOnMetadata = function(addon_name, metadata_key)
		return env.C_AddOns.GetAddOnMetadata(addon_name, metadata_key)
	end

	env.Settings = {
		RegisterCanvasLayoutCategory = function(frame, name)
			local category = {
				frame = frame,
				name = name,
				id = #env.__settings_categories + 1,
			}

			function category:GetID()
				return self.id
			end

			env.__settings_categories[#env.__settings_categories + 1] = category
			return category
		end,
		RegisterAddOnCategory = function(category)
			env.__registered_addon_category = category
		end,
		OpenToCategory = function(category)
			env.__opened_settings_category = category
		end,
	}

	env.CreateFrame = function(_, frame_name, parent, template)
		local frame = create_frame_object(frame_name, parent, template)
		env.__frames[#env.__frames + 1] = frame
		return frame
	end

	env.C_Timer = {
		After = function(delay, callback)
			env.__next_timer_id = env.__next_timer_id + 1
			env.__timers[#env.__timers + 1] = {
				id = env.__next_timer_id,
				at = env.__now + tonumber(delay or 0),
				callback = callback,
			}
			sort_timers(env)
		end,
	}

	return env
end

local function load_files(env, root, files)
	for _, relative_path in ipairs(files or DEFAULT_FILES) do
		local file_path = join_path(root, relative_path)
		local chunk, load_error = loadfile(file_path, "t", env)
		if not chunk then
			error(string.format("Failed to load %s: %s", relative_path, tostring(load_error)))
		end
		local ok, runtime_error = pcall(chunk)
		if not ok then
			error(string.format("Error while executing %s: %s", relative_path, tostring(runtime_error)))
		end
	end
end

function support.new_context(root, options)
	options = options or {}

	local env = create_test_env()
	if type(options.configure_env) == "function" then
		options.configure_env(env)
	end

	load_files(env, root, options.files)

	local context = {
		env = env,
		ns = env.RepSheet,
	}

	function context.run_due_timers()
		local iterations = 0
		while true do
			sort_timers(env)
			local next_timer = env.__timers[1]
			if not next_timer or next_timer.at > env.__now then
				break
			end

			table.remove(env.__timers, 1)
			next_timer.callback()
			iterations = iterations + 1
			if iterations > 1000 then
				error("Timer safety limit exceeded.")
			end
		end
	end

	function context.advance(seconds)
		env.__now = env.__now + tonumber(seconds or 0)
		context.run_due_timers()
	end

	function context.run_all_timers(limit)
		local remaining = limit or 1000
		while #env.__timers > 0 do
			if remaining <= 0 then
				error("Timer safety limit exceeded.")
			end
			sort_timers(env)
			env.__now = math.max(env.__now, env.__timers[1].at)
			context.run_due_timers()
			remaining = remaining - 1
		end
	end

	function context.trigger_event(event_name, ...)
		for index = 1, #env.__frames do
			local frame = env.__frames[index]
			local handler = frame.__scripts.OnEvent
			if frame.__events[event_name] and type(handler) == "function" then
				handler(frame, event_name, ...)
			end
		end
	end

	function context.set_combat(in_combat)
		env.__inCombat = in_combat == true
	end

	return context
end

function support.new_runner(options)
	options = options or {}
	local coverage = options.coverage
	local runner = {
		tests = {},
	}

	function runner:test(name, callback)
		self.tests[#self.tests + 1] = {
			name = name,
			callback = callback,
		}
	end

	function runner:run()
		local failures = 0
		for index = 1, #self.tests do
			local test = self.tests[index]
			if coverage and coverage.before_test then
				coverage:before_test(test.name)
			end
			local ok, err = xpcall(test.callback, debug.traceback)
			if coverage and coverage.after_test then
				coverage:after_test(test.name, ok)
			end
			if ok then
				print(string.format("ok %d - %s", index, test.name))
			else
				failures = failures + 1
				print(string.format("not ok %d - %s", index, test.name))
				print(err)
			end
		end

		print(string.format("%d tests, %d failures", #self.tests, failures))
		if coverage and coverage.report then
			coverage:report()
		end
		return failures == 0 and 0 or 1
	end

	return runner
end

return support
