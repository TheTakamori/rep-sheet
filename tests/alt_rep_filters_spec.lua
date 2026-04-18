local support = require("support")
local A = support.assert

local ALT_REP_FILES = support.with_files({
	"Core/AltsIndex.lua",
	"Core/AltsFilters.lua",
	"Core/AltRepFilters.lua",
})

local function seed_alt_with_mixed_reps(ns)
	ns.SaveCharacterSnapshot(support.make_snapshot(ns, {
		characterKey = "Alpha::Multi",
		name = "Multi",
		realm = "Alpha",
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
				name = "Council of Dornogal",
				expansionKey = "tww",
				standingId = 8,
				currentValue = 1000,
				maxValue = 2500,
			}),
			["300"] = support.make_reputation(ns, {
				factionID = 300,
				name = "Argent Crusade",
				expansionKey = "wrath",
				standingId = 4,
				currentValue = 0,
				maxValue = 3000,
			}),
			["400"] = support.make_reputation(ns, {
				factionID = 400,
				name = "Everlook",
				expansionKey = "classic",
				standingId = 5,
				currentValue = 1500,
				maxValue = 3000,
			}),
		},
	}))
end

return function(runner, root)
	runner:test("GetFilteredAltReputationEntries returns all entries with the default filters", function()
		local ctx = support.new_context(root, { files = ALT_REP_FILES })
		local ns = ctx.ns
		ns.InitDB()
		seed_alt_with_mixed_reps(ns)

		local entries, total = ns.GetFilteredAltReputationEntries("Alpha::Multi")
		A.equal(total, 4)
		A.equal(#entries, 4)

		local names = {}
		for index = 1, #entries do
			names[index] = entries[index].name
		end
		A.same(names, { "Argent Crusade", "Booty Bay", "Council of Dornogal", "Everlook" })
	end)

	runner:test("Expansion filter limits the alt's reputations to that expansion", function()
		local ctx = support.new_context(root, { files = ALT_REP_FILES })
		local ns = ctx.ns
		ns.InitDB()
		seed_alt_with_mixed_reps(ns)

		ns.SetAltRepFilterValue("expansionKey", "classic")
		local entries, total = ns.GetFilteredAltReputationEntries("Alpha::Multi")
		A.equal(total, 4)
		A.equal(#entries, 2)
		A.equal(entries[1].name, "Booty Bay")
		A.equal(entries[2].name, "Everlook")

		ns.SetAltRepFilterValue("expansionKey", "tww")
		entries = ns.GetFilteredAltReputationEntries("Alpha::Multi")
		A.equal(#entries, 1)
		A.equal(entries[1].name, "Council of Dornogal")

		ns.SetAltRepFilterValue("expansionKey", ns.ALL_EXPANSIONS_KEY)
		entries = ns.GetFilteredAltReputationEntries("Alpha::Multi")
		A.equal(#entries, 4)
	end)

	runner:test("Sort by Level (Highest) orders the alt's reputations by overall progress descending", function()
		local ctx = support.new_context(root, { files = ALT_REP_FILES })
		local ns = ctx.ns
		ns.InitDB()
		seed_alt_with_mixed_reps(ns)

		ns.SetAltRepFilterValue("sortKey", ns.ALT_REP_SORT_KEY.LEVEL_DESC)
		local entries = ns.GetFilteredAltReputationEntries("Alpha::Multi")
		A.equal(#entries, 4)

		for index = 1, #entries - 1 do
			local current = ns.SafeNumber(entries[index].overallFraction, 0)
			local nextValue = ns.SafeNumber(entries[index + 1].overallFraction, 0)
			A.truthy(
				current >= nextValue,
				string.format("entries[%d] overallFraction (%s) must be >= entries[%d] (%s)", index, tostring(current), index + 1, tostring(nextValue))
			)
		end
	end)

	runner:test("Sort by Name keeps entries alphabetical regardless of expansion", function()
		local ctx = support.new_context(root, { files = ALT_REP_FILES })
		local ns = ctx.ns
		ns.InitDB()
		seed_alt_with_mixed_reps(ns)

		ns.SetAltRepFilterValue("sortKey", ns.ALT_REP_SORT_KEY.NAME)
		local entries = ns.GetFilteredAltReputationEntries("Alpha::Multi")
		local names = {}
		for index = 1, #entries do
			names[index] = entries[index].name
		end
		A.same(names, { "Argent Crusade", "Booty Bay", "Council of Dornogal", "Everlook" })
	end)

	runner:test("Filter and sort persist independently across alt selections", function()
		local ctx = support.new_context(root, { files = ALT_REP_FILES })
		local ns = ctx.ns
		ns.InitDB()
		seed_alt_with_mixed_reps(ns)

		ns.SaveCharacterSnapshot(support.make_snapshot(ns, {
			characterKey = "Bravo::Other",
			name = "Other",
			realm = "Bravo",
			reputations = {
				["500"] = support.make_reputation(ns, {
					factionID = 500,
					name = "Booty Bay",
					expansionKey = "classic",
					standingId = 5,
					currentValue = 1500,
					maxValue = 3000,
				}),
				["600"] = support.make_reputation(ns, {
					factionID = 600,
					name = "Council of Dornogal",
					expansionKey = "tww",
					standingId = 8,
					currentValue = 1000,
					maxValue = 2500,
				}),
			},
		}))

		ns.SetAltRepFilterValue("expansionKey", "classic")
		ns.SetAltRepFilterValue("sortKey", ns.ALT_REP_SORT_KEY.NAME)

		local multiEntries = ns.GetFilteredAltReputationEntries("Alpha::Multi")
		A.equal(#multiEntries, 2)

		local otherEntries = ns.GetFilteredAltReputationEntries("Bravo::Other")
		A.equal(#otherEntries, 1)
		A.equal(otherEntries[1].name, "Booty Bay")

		A.equal(ns.GetAltRepFilterValue("expansionKey"), "classic", "filter persists across alt switches")
	end)
end
