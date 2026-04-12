local support = require("support")
local A = support.assert

local function build_tree_snapshot(ns)
	return support.make_snapshot(ns, {
		characterKey = "Alpha::Tester",
		name = "Tester",
		realm = "Alpha",
		reputations = {
			["1000"] = support.make_reputation(ns, {
				factionID = 1000,
				name = "Steamwheedle Cartel",
				expansionKey = "classic",
				standingId = 6,
				currentValue = 3000,
				maxValue = 6000,
				headerPath = { "Classic / Vanilla" },
			}),
			["1001"] = support.make_reputation(ns, {
				factionID = 1001,
				name = "Booty Bay",
				expansionKey = "classic",
				standingId = 5,
				currentValue = 1500,
				maxValue = 3000,
				isChild = true,
				headerPath = { "Classic / Vanilla", "Steamwheedle Cartel" },
			}),
			["2000"] = support.make_reputation(ns, {
				factionID = 2000,
				name = "Dream Wardens",
				expansionKey = "df",
				standingId = 8,
				currentValue = 3000,
				maxValue = 3000,
				headerPath = { "Dragonflight" },
			}),
		},
	})
end

return function(runner, root)
	runner:test("CompareBucketsCore covers expansion, progress, closest, and name tie-break sorts", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		local compare = ns.FactionFilters.CompareBucketsCore

		A.truthy(compare(ns.SORT_KEY.EXPANSION, {
			expansionKey = "classic",
			sortName = "z",
			factionKey = "2",
		}, {
			expansionKey = "df",
			sortName = "a",
			factionKey = "1",
		}))

		A.truthy(compare(ns.SORT_KEY.BEST_PROGRESS, {
			bestOverallFraction = 0.9,
			maxedCount = 0,
			sortName = "a",
			factionKey = "1",
		}, {
			bestOverallFraction = 0.8,
			maxedCount = 99,
			sortName = "b",
			factionKey = "2",
		}))

		A.truthy(compare(ns.SORT_KEY.CLOSEST_TO_NEXT, {
			closestRemaining = 0.1,
			bestOverallFraction = 0.3,
			sortName = "a",
			factionKey = "1",
		}, {
			closestRemaining = 0.2,
			bestOverallFraction = 0.9,
			sortName = "b",
			factionKey = "2",
		}))

		A.truthy(compare(ns.SORT_KEY.NAME, {
			sortName = "",
			name = "Alpha",
			factionKey = "1",
		}, {
			sortName = "",
			name = "Alpha",
			factionKey = "2",
		}))
	end)

	runner:test("Filtered faction results honor expansion, search, status, and grouped ordering", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		ns.InitDB()
		ns.SaveCharacterSnapshot(build_tree_snapshot(ns))

		ns.SetFilterValue("expansionKey", "classic")
		local results = ns.GetFilteredFactionResults()
		A.equal(#results, 2)

		ns.SetFilterValue("searchText", "booty")
		results = ns.GetFilteredFactionResults()
		A.equal(#results, 2)
		A.equal(results[1].factionKey, "1000")
		A.equal(results[2].factionKey, "1001")

		ns.SetFilterValue("searchText", "")
		ns.SetFilterValue("expansionKey", ns.ALL_EXPANSIONS_KEY)
		ns.SetFilterValue("statusKey", ns.FILTER_STATUS.MAXED)
		results = ns.GetFilteredFactionResults()
		A.equal(#results, 1)
		A.equal(results[1].factionKey, "2000")

		ns.SetFilterValue("statusKey", ns.FILTER_STATUS.ALL)
		ns.SetFilterValue("expansionKey", ns.ALL_EXPANSIONS_KEY)
		ns.SetFilterValue("sortKey", ns.SORT_KEY.CLOSEST_TO_NEXT)
		results = ns.GetFilteredFactionResults()
		A.equal(results[1].factionKey, "2000")
		A.equal(results[2].factionKey, "1000")
		A.equal(results[3].factionKey, "1001")
	end)

	runner:test("Tree helpers expose parent chains, descendant checks, and cached visible rows", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		ns.InitDB()
		ns.SaveCharacterSnapshot(build_tree_snapshot(ns))

		local chain = ns.GetFactionParentChain("1001")
		A.equal(#chain, 1)
		A.equal(chain[1].factionKey, "1000")
		A.truthy(ns.IsFactionDescendantOf("1001", "1000"))
		A.falsy(ns.IsFactionDescendantOf("1000", "1001"))
		A.same(ns.GetFactionParentChain("missing"), {})

		local first_rows = ns.GetVisibleFactionRows()
		local second_rows = ns.GetVisibleFactionRows()
		A.equal(first_rows, second_rows)
	end)

	runner:test("NormalizeCurrentCharacterSnapshot leaves the stronger existing duplicate in place", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns

		local snapshot = ns.NormalizeCurrentCharacterSnapshot("Manual", {
			{
				factionID = 72,
				name = "Stormpike Guard",
				standingId = 7,
				currentStanding = 8000,
				bottomValue = 3000,
				topValue = 21000,
				headerPath = { "Classic / Vanilla" },
			},
			{
				factionID = 72,
				name = "Stormpike Guard",
				standingId = 5,
				currentStanding = 3500,
				bottomValue = 3000,
				topValue = 9000,
				headerPath = { "Classic / Vanilla" },
			},
		}, {})

		A.equal(snapshot.reputationCount, 1)
		A.equal(snapshot.reputations["72"].standingId, 7)
	end)

	runner:test("NormalizeCurrentCharacterSnapshot traces duplicate collisions for traced reputations", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		ns.LOCAL_DEV.ENABLE_DEBUG = true

		local snapshot = ns.NormalizeCurrentCharacterSnapshot("Collision", {
			{
				factionKey = "2590",
				factionID = 2590,
				name = "Council of Dornogal",
				standingId = 8,
				currentStanding = 2000,
				bottomValue = 0,
				topValue = 2500,
				headerPath = { "The War Within" },
			},
			{
				factionKey = "2590",
				factionID = 2590,
				name = "Council of Dornogal",
				standingId = 8,
				currentStanding = 1500,
				bottomValue = 0,
				topValue = 2500,
				headerPath = { "The War Within" },
			},
		}, {
			["2590"] = {
				repType = ns.REP_TYPE.MAJOR,
				majorFactionID = 2590,
				renownLevel = 5,
				renownMaxLevel = 10,
				currentValue = 1200,
				maxValue = 2500,
				isAccountWide = true,
			},
		})

		A.equal(snapshot.reputationCount, 1)
		A.contains(ns.GetLastDebugLine(), "SAVE collision")
	end)

	runner:test("Normalizer helpers cover friendship, neighborhood, name-key fallback, and backfill paths", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns

		local friendship = {
			name = "Wrathion",
			repType = ns.REP_TYPE.FRIENDSHIP,
			currentValue = 400,
			maxValue = 1000,
			friendCurrentRank = 2,
			friendMaxRank = 6,
		}
		ns.NormalizerHelpers.ApplyRuntimeReputationFields(friendship)
		A.equal(friendship.factionKey, "wrathion")
		A.equal(friendship.rankText, "Rank: 2/6")
		A.equal(friendship.repTypeLabel, ns.TEXT.FRIENDSHIP)

		local neighborhood = ns.NormalizerHelpers.normalizeFactionRow({
			factionID = 0,
			name = "Neighborhood Initiative",
			standingText = "Beloved",
			currentStanding = 100,
			bottomValue = 0,
			topValue = 1000,
		}, {
			repType = ns.REP_TYPE.NEIGHBORHOOD,
			isAccountWide = true,
		})
		A.equal(neighborhood.factionKey, "neighborhood initiative")
		A.equal(neighborhood.repTypeLabel, ns.TEXT.NEIGHBORHOOD)

		local character = {
			reputations = {
				unknown = {
					name = "Dream Wardens",
					factionID = 2574,
					expansionKey = "",
					standingId = 8,
					currentValue = 3000,
					maxValue = 3000,
				},
			},
		}
		ns.BackfillStoredCharacterReputations(character)
		A.equal(character.reputations.unknown.factionKey, "2574")
		A.equal(character.reputations.unknown.expansionKey, ns.ALL_EXPANSIONS_KEY)
		A.equal(character.reputations.unknown.expansionName, "All expansions")
	end)

	runner:test("scoreNormalizedRow and entry math cover major, friendship, paragon, and fallback branches", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		local helpers = ns.NormalizerHelpers

		A.near(helpers.scoreNormalizedRow({
			overallFraction = 0.5,
			isMaxed = true,
			repType = ns.REP_TYPE.MAJOR,
			hasParagon = true,
		}), 1.95, 1e-6)

		A.truthy(helpers.isEntryActuallyMaxed({
			repType = ns.REP_TYPE.FRIENDSHIP,
			friendCurrentRank = 6,
			friendMaxRank = 6,
			currentValue = 1000,
			maxValue = 1000,
		}))
		A.truthy(helpers.isEntryActuallyMaxed({
			repType = ns.REP_TYPE.STANDARD,
			standingId = 8,
			currentValue = 3000,
			maxValue = 3000,
		}))
		A.truthy(helpers.isEntryActuallyMaxed({
			hasParagon = true,
			currentValue = 1000,
			maxValue = 1000,
		}))
		A.near(helpers.deriveEntryOverallFraction({
			repType = ns.REP_TYPE.MAJOR,
			renownLevel = 5,
			renownMaxLevel = 10,
			currentValue = 1250,
			maxValue = 2500,
		}), 0.45, 1e-6)
		A.near(helpers.deriveEntryOverallFraction({
			repType = ns.REP_TYPE.OTHER,
			overallFraction = 0.42,
		}), 0.42, 1e-6)
	end)

	runner:test("Normalizer helpers cover empty-name rejection, header-derived expansion, and standard paragon text", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns

		A.equal(ns.NormalizerHelpers.normalizeFactionRow({ name = "   " }, {}), nil)

		local normalized = ns.NormalizerHelpers.normalizeFactionRow({
			factionID = 7000,
			name = "Paragon Example",
			standingId = 8,
			currentStanding = 3000,
			bottomValue = 0,
			topValue = 3000,
			headerPath = { "The War Within" },
		}, {
			hasParagon = true,
			paragonValue = 250,
			paragonThreshold = 1000,
		})

		A.equal(normalized.expansionKey, "tww")
		A.contains(normalized.progressText, "Paragon: 250/1000")
		A.equal(normalized.repTypeLabel, ns.TEXT.REPUTATION .. ns.TEXT.PARAGON_SUFFIX)
	end)

	runner:test("BuildFactionIndex prefers the best non-accountwide entry and the longest equal-timestamp header path", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		ns.InitDB()

		ns.SaveCharacterSnapshot(support.make_snapshot(ns, {
			characterKey = "Alpha::Aly",
			name = "Aly",
			realm = "Alpha",
			lastScanAt = 100,
			reputations = {
				["42"] = support.make_reputation(ns, {
					factionID = 42,
					name = "Booty Bay",
					expansionKey = "classic",
					standingId = 5,
					currentValue = 1500,
					maxValue = 3000,
					isChild = true,
					headerPath = { "Classic / Vanilla" },
				}),
			},
		}))
		ns.SaveCharacterSnapshot(support.make_snapshot(ns, {
			characterKey = "Beta::Zed",
			name = "Zed",
			realm = "Beta",
			lastScanAt = 100,
			reputations = {
				["42"] = support.make_reputation(ns, {
					factionID = 42,
					name = "Booty Bay",
					expansionKey = "classic",
					standingId = 6,
					currentValue = 3000,
					maxValue = 6000,
					isChild = true,
					headerPath = { "Classic / Vanilla", "Steamwheedle Cartel" },
				}),
			},
		}))

		local bucket = ns.GetFactionBucketByKey("42")
		A.equal(bucket.bestEntry.characterKey, "Beta::Zed")
		A.same(bucket.headerPath, { "Classic / Vanilla", "Steamwheedle Cartel" })
		A.truthy(bucket.isChild)
	end)

	runner:test("Reputation event hint helpers classify reasons and handle alternate combat templates", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns

		A.truthy(ns.IsGenericKnownReputationReason(ns.SCAN_REASON.UPDATE_FACTION))
		A.truthy(ns.IsTargetedReputationReason(ns.SCAN_REASON.CHAT_MSG_COMBAT_FACTION_CHANGE))
		A.truthy(ns.ShouldReplaceGenericRefreshWithTargeted(
			ns.SCAN_REASON.UPDATE_FACTION,
			ns.SCAN_REASON.CHAT_MSG_COMBAT_FACTION_CHANGE,
			"factions"
		))
		A.falsy(ns.ShouldReplaceGenericRefreshWithTargeted(
			ns.SCAN_REASON.QUEST_TURNED_IN,
			ns.SCAN_REASON.UPDATE_FACTION,
			"known"
		))

		ctx.env.FACTION_STANDING_INCREASED_BONUS = "Bonus with %s increased by %d%%."
		A.equal(
			ns.ExtractFactionNameFromCombatMessage("Bonus with The Cartels of Undermine increased by 100%."),
			"The Cartels of Undermine"
		)
	end)

	runner:test("OpenFactionInGameUI also covers global renown fallback and direct reputation toggle success", function()
		local ctx = support.new_context(root, {
			files = support.with_files({ "Core/OpenFactionUI.lua" }),
		})
		local ns = ctx.ns
		local calls = {}

		ctx.env.C_MajorFactions.OpenRenown = function()
			error("fail")
		end
		ctx.env.C_MajorFactions.OpenMajorFactionRenown = function()
			error("fail")
		end
		ctx.env.OpenMajorFactionRenown = function(faction_id)
			calls[#calls + 1] = "global:" .. tostring(faction_id)
		end
		ns.OpenFactionInGameUI({
			repType = ns.REP_TYPE.MAJOR,
			majorFactionID = 2590,
		})
		A.same(calls, { "global:2590" })

		calls = {}
		ctx.env.C_Reputation.ToggleReputationUI = function()
			calls[#calls + 1] = "toggle"
		end
		ns.OpenFactionInGameUI({
			repType = ns.REP_TYPE.STANDARD,
			factionID = 72,
		})
		A.same(calls, { "toggle" })
	end)
end
