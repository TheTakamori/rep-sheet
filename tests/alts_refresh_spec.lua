local support = require("support")
local A = support.assert

local ALTS_REFRESH_FILES = support.with_files({
	"Core/AltsIndex.lua",
	"Core/AltsFilters.lua",
	"Core/AltRepFilters.lua",
	"UI/UIConstants.lua",
	"UI/UIHelpers.lua",
	"UI/UIWidgets.lua",
	"UI/AltsListRow.lua",
	"UI/MainFrameAltsRefresh.lua",
})

local function seed_two_alts(ns)
	ns.SaveCharacterSnapshot(support.make_snapshot(ns, {
		characterKey = "Alpha::Alyssa",
		name = "Alyssa",
		realm = "Alpha",
		level = 90,
		className = "Mage",
		classFile = "MAGE",
		raceName = "Human",
		raceFile = "Human",
		factionName = "Alliance",
		professions = {
			primary1 = { name = "Tailoring" },
			primary2 = { name = "Enchanting" },
		},
		reputations = {
			["100"] = support.make_reputation(ns, {
				factionID = 100,
				name = "Booty Bay",
				expansionKey = "classic",
				standingId = 6,
				currentValue = 3000,
				maxValue = 6000,
			}),
		},
	}))
	ns.SaveCharacterSnapshot(support.make_snapshot(ns, {
		characterKey = "Bravo::Borka",
		name = "Borka",
		realm = "Bravo",
		level = 80,
		className = "Warrior",
		classFile = "WARRIOR",
		raceName = "Orc",
		raceFile = "Orc",
		factionName = "Horde",
		professions = {
			primary1 = { name = "Mining" },
		},
		reputations = {
			["200"] = support.make_reputation(ns, {
				factionID = 200,
				name = "Everlook",
				expansionKey = "classic",
				standingId = 5,
				currentValue = 1500,
				maxValue = 3000,
			}),
		},
	}))
end

local function fake_scroll(width, height)
	return {
		__width = width or 200,
		__height = height or 100,
		__scroll = 0,
		__range = 0,
		GetWidth = function(self) return self.__width end,
		GetHeight = function(self) return self.__height end,
		GetVerticalScroll = function(self) return self.__scroll end,
		GetVerticalScrollRange = function(self) return self.__range end,
		SetVerticalScroll = function(self, value) self.__scroll = value end,
	}
end

local function fake_scroll_child()
	return {
		__width = 0,
		__height = 0,
		SetWidth = function(self, value) self.__width = value end,
		SetHeight = function(self, value) self.__height = value end,
	}
end

local function fake_count_label()
	return {
		__text = nil,
		SetText = function(self, value) self.__text = value end,
	}
end

local function fake_alts_left_pane(searchSeen)
	return {
		listScroll = fake_scroll(),
		listScrollChild = fake_scroll_child(),
		countLabel = fake_count_label(),
		rowFrames = {},
		sortDrop = {},
		factionDrop = {},
		classDrop = {},
		raceDrop = {},
		professionDrop = {},
		SyncSearchBox = function(self, text)
			searchSeen[#searchSeen + 1] = text
		end,
	}
end

local function fake_alts_pane(setAltCalls)
	return {
		expansionDrop = {},
		sortDrop = {},
		SetAlt = function(self, record)
			setAltCalls[#setAltCalls + 1] = { record = record }
		end,
	}
end

return function(runner, root)
	runner:test("UI_RefreshAltsLeftPane and UI_RefreshAltsPane are no-ops on nil panes", function()
		local ctx = support.new_context(root, { files = ALTS_REFRESH_FILES })
		local ns = ctx.ns
		ns.InitDB()

		ns.UI_RefreshAltsLeftPane(nil)
		ns.UI_RefreshAltsPane(nil)
		ns.UI_RefreshAltsPane({})
		A.truthy(true)
	end)

	runner:test("UI_RefreshAltsLeftPane reports no alts when the database is empty", function()
		local ctx = support.new_context(root, { files = ALTS_REFRESH_FILES })
		local ns = ctx.ns
		ns.InitDB()

		local searches = {}
		local pane = fake_alts_left_pane(searches)

		local saved_create = ns.UI_CreateAltsListRow
		local saved_apply = ns.UI_ApplyAltsListRow
		local creates = 0
		ns.UI_CreateAltsListRow = function()
			creates = creates + 1
			return {
				ClearAllPoints = function() end,
				SetPoint = function() end,
				SetWidth = function() end,
			}
		end
		ns.UI_ApplyAltsListRow = function() end

		ns.UI_RefreshAltsLeftPane(pane)

		ns.UI_CreateAltsListRow = saved_create
		ns.UI_ApplyAltsListRow = saved_apply

		A.equal(creates, 0)
		A.equal(#pane.rowFrames, 0)
		A.equal(searches[1], "")
		A.truthy(pane.countLabel.__text and pane.countLabel.__text:find("No alts", 1, true))
	end)

	runner:test("UI_RefreshAltsLeftPane materializes a row per visible alt and reports counts", function()
		local ctx = support.new_context(root, { files = ALTS_REFRESH_FILES })
		local ns = ctx.ns
		ns.InitDB()
		seed_two_alts(ns)

		local searches = {}
		local pane = fake_alts_left_pane(searches)
		local applied = {}

		local saved_create = ns.UI_CreateAltsListRow
		local saved_apply = ns.UI_ApplyAltsListRow
		ns.UI_CreateAltsListRow = function(_, index)
			return {
				__index = index,
				ClearAllPoints = function() end,
				SetPoint = function() end,
				SetWidth = function() end,
			}
		end
		ns.UI_ApplyAltsListRow = function(row, record, selected)
			applied[#applied + 1] = { row = row, record = record, selected = selected == true }
		end

		ns.UI_RefreshAltsLeftPane(pane, { resetScroll = true })

		ns.UI_CreateAltsListRow = saved_create
		ns.UI_ApplyAltsListRow = saved_apply

		A.equal(#pane.rowFrames, 2)
		A.equal(#applied, 2)
		A.truthy(pane.countLabel.__text and pane.countLabel.__text:find("Alts: 2", 1, true))
		A.equal(pane.listScroll.__scroll, 0)
	end)

	runner:test("UI_RefreshAltsPane forwards the record matching the selected character key", function()
		local ctx = support.new_context(root, { files = ALTS_REFRESH_FILES })
		local ns = ctx.ns
		ns.InitDB()
		seed_two_alts(ns)

		ns.SetSelectedCharacterKey("Bravo::Borka")

		local setAltCalls = {}
		local pane = fake_alts_pane(setAltCalls)

		ns.UI_RefreshAltsPane(pane)

		A.equal(#setAltCalls, 1)
		A.equal(setAltCalls[1].record.characterKey, "Bravo::Borka")
		A.equal(setAltCalls[1].record.name, "Borka")
	end)

	runner:test("UI_RefreshAltsPane forwards nil when no alt is selected", function()
		local ctx = support.new_context(root, { files = ALTS_REFRESH_FILES })
		local ns = ctx.ns
		ns.InitDB()
		seed_two_alts(ns)

		local setAltCalls = {}
		local pane = fake_alts_pane(setAltCalls)

		ns.UI_RefreshAltsPane(pane)

		A.equal(#setAltCalls, 1)
		A.equal(setAltCalls[1].record, nil)
	end)
end
