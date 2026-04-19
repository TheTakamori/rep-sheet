---@diagnostic disable: undefined-global
local support = require("support")
local A = support.assert

local ALTS_FILES = support.with_files({
	"Core/AltsIndex.lua",
	"Core/AltsFilters.lua",
})

local function seed_three_alts(ns)
	local alts = {
		support.make_snapshot(ns, {
			characterKey = "Alpha::Alyssa",
			name = "Alyssa",
			realm = "Alpha",
			level = 90,
			className = "Mage",
			classFile = "MAGE",
			raceName = "Human",
			raceFile = "Human",
			factionName = "Alliance",
			lastScanAt = 100,
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
				["200"] = support.make_reputation(ns, {
					factionID = 200,
					name = "Everlook",
					expansionKey = "classic",
					standingId = 5,
					currentValue = 1500,
					maxValue = 3000,
				}),
			},
		}),
		support.make_snapshot(ns, {
			characterKey = "Bravo::Borka",
			name = "Borka",
			realm = "Bravo",
			level = 80,
			className = "Warrior",
			classFile = "WARRIOR",
			raceName = "Orc",
			raceFile = "Orc",
			factionName = "Horde",
			lastScanAt = 300,
			professions = {
				primary1 = { name = "Mining" },
				primary2 = { name = "Blacksmithing" },
			},
			reputations = {
				["100"] = support.make_reputation(ns, {
					factionID = 100,
					name = "Booty Bay",
					expansionKey = "classic",
					standingId = 5,
					currentValue = 1200,
					maxValue = 3000,
				}),
			},
		}),
		support.make_snapshot(ns, {
			characterKey = "Charlie::Cinder",
			name = "Cinder",
			realm = "Charlie",
			level = 70,
			className = "Rogue",
			classFile = "ROGUE",
			raceName = "Pandaren",
			raceFile = "Pandaren",
			factionName = "Neutral",
			lastScanAt = 200,
			professions = {
				primary1 = { name = "Mining" },
			},
			reputations = {},
		}),
	}
	for index = 1, #alts do
		ns.SaveCharacterSnapshot(alts[index])
	end
	return alts
end

return function(runner, root)
	runner:test("BuildAltsIndex builds one record per character with profession list and rep count", function()
		local ctx = support.new_context(root, { files = ALTS_FILES })
		local ns = ctx.ns
		ns.InitDB()
		seed_three_alts(ns)

		local index = ns.BuildAltsIndex()
		A.equal(index.totalAlts, 3)
		A.equal(#index.all, 3)

		local alyssa = index.byKey["Alpha::Alyssa"]
		A.truthy(alyssa)
		A.equal(alyssa.name, "Alyssa")
		A.equal(alyssa.level, 90)
		A.equal(alyssa.classFile, "MAGE")
		A.equal(alyssa.raceFile, "Human")
		A.equal(alyssa.factionName, "Alliance")
		A.equal(alyssa.reputationCount, 2)
		A.equal(alyssa.lastScanAt, 100)
		A.same(alyssa.professionList, { "Tailoring", "Enchanting" })

		local cinder = index.byKey["Charlie::Cinder"]
		A.equal(cinder.reputationCount, 0)
		A.same(cinder.professionList, { "Mining" })
	end)

	runner:test("GetAltFilterOptions aggregates classes/races/professions with ALL first", function()
		local ctx = support.new_context(root, { files = ALTS_FILES })
		local ns = ctx.ns
		ns.InitDB()
		seed_three_alts(ns)

		local options = ns.GetAltFilterOptions()
		A.equal(options.classes[1].key, ns.ALL_ALT_FILTER_KEY)
		A.equal(options.classes[1].label, ns.TEXT.ALTS_FILTER_ALL_CLASSES)
		A.equal(#options.classes, 4)

		A.equal(options.races[1].key, ns.ALL_ALT_FILTER_KEY)
		A.equal(#options.races, 4)

		A.equal(options.professions[1].key, ns.ALL_ALT_FILTER_KEY)
		A.equal(#options.professions, 5)
	end)

	runner:test("GetAltReputationEntries returns all faction entries belonging to the character", function()
		local ctx = support.new_context(root, { files = ALTS_FILES })
		local ns = ctx.ns
		ns.InitDB()
		seed_three_alts(ns)

		local entries = ns.GetAltReputationEntries("Alpha::Alyssa")
		A.equal(#entries, 2)
		local names = { entries[1].name, entries[2].name }
		table.sort(names)
		A.same(names, { "Booty Bay", "Everlook" })

		A.equal(#ns.GetAltReputationEntries("Charlie::Cinder"), 0)
		A.equal(#ns.GetAltReputationEntries(""), 0)
	end)

	runner:test("MarkIndexDirty invalidates the cached alts index", function()
		local ctx = support.new_context(root, { files = ALTS_FILES })
		local ns = ctx.ns
		ns.InitDB()
		seed_three_alts(ns)

		local first = ns.BuildAltsIndex()
		A.equal(first.totalAlts, 3)

		ns.SaveCharacterSnapshot(support.make_snapshot(ns, {
			characterKey = "Delta::Diona",
			name = "Diona",
			realm = "Delta",
			level = 60,
			className = "Priest",
			classFile = "PRIEST",
			raceName = "Human",
			raceFile = "Human",
			factionName = "Alliance",
			lastScanAt = 50,
			reputations = {},
		}))

		local second = ns.BuildAltsIndex()
		A.equal(second.totalAlts, 4)
		A.truthy(second.byKey["Delta::Diona"])
	end)

	runner:test("Filtered alt results respect search, faction, class, race, and profession filters", function()
		local ctx = support.new_context(root, { files = ALTS_FILES })
		local ns = ctx.ns
		ns.InitDB()
		seed_three_alts(ns)

		local results, total = ns.GetFilteredAltResults()
		A.equal(total, 3)
		A.equal(#results, 3)

		ns.SetAltFilterValue("factionGroup", ns.ALT_FACTION_FILTER.HORDE)
		results = ns.GetFilteredAltResults()
		A.equal(#results, 1)
		A.equal(results[1].characterKey, "Bravo::Borka")

		ns.SetAltFilterValue("factionGroup", ns.ALT_FACTION_FILTER.ALL)
		ns.SetAltFilterValue("classFile", "MAGE")
		results = ns.GetFilteredAltResults()
		A.equal(#results, 1)
		A.equal(results[1].characterKey, "Alpha::Alyssa")

		ns.SetAltFilterValue("classFile", ns.ALL_ALT_FILTER_KEY)
		ns.SetAltFilterValue("raceFile", "Pandaren")
		results = ns.GetFilteredAltResults()
		A.equal(#results, 1)
		A.equal(results[1].characterKey, "Charlie::Cinder")

		ns.SetAltFilterValue("raceFile", ns.ALL_ALT_FILTER_KEY)
		ns.SetAltFilterValue("professionName", "Mining")
		results = ns.GetFilteredAltResults()
		A.equal(#results, 2)
		local keys = { results[1].characterKey, results[2].characterKey }
		table.sort(keys)
		A.same(keys, { "Bravo::Borka", "Charlie::Cinder" })

		ns.SetAltFilterValue("professionName", ns.ALL_ALT_FILTER_KEY)
		ns.SetAltFilterValue("searchText", "ALY")
		results = ns.GetFilteredAltResults()
		A.equal(#results, 1)
		A.equal(results[1].characterKey, "Alpha::Alyssa")
	end)

	runner:test("ALT_SORT_KEY drives ordering through CompareRecordsCore", function()
		local ctx = support.new_context(root, { files = ALTS_FILES })
		local ns = ctx.ns
		ns.InitDB()
		seed_three_alts(ns)

		ns.SetAltFilterValue("sortKey", ns.ALT_SORT_KEY.NAME)
		local byName = ns.GetFilteredAltResults()
		A.equal(byName[1].characterKey, "Alpha::Alyssa")
		A.equal(byName[2].characterKey, "Bravo::Borka")
		A.equal(byName[3].characterKey, "Charlie::Cinder")

		ns.SetAltFilterValue("sortKey", ns.ALT_SORT_KEY.LEVEL_DESC)
		local byLevel = ns.GetFilteredAltResults()
		A.equal(byLevel[1].level, 90)
		A.equal(byLevel[2].level, 80)
		A.equal(byLevel[3].level, 70)

		ns.SetAltFilterValue("sortKey", ns.ALT_SORT_KEY.CLASS)
		local byClass = ns.GetFilteredAltResults()
		A.equal(byClass[1].className, "Mage")
		A.equal(byClass[2].className, "Rogue")
		A.equal(byClass[3].className, "Warrior")

		ns.SetAltFilterValue("sortKey", ns.ALT_SORT_KEY.LAST_SCAN_DESC)
		local byScan = ns.GetFilteredAltResults()
		A.equal(byScan[1].lastScanAt, 300)
		A.equal(byScan[2].lastScanAt, 200)
		A.equal(byScan[3].lastScanAt, 100)
	end)
end
