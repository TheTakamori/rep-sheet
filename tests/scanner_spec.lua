local support = require("support")
local A = support.assert

local SCANNER_FILES = support.with_files({
	"Core/ScannerStandardHelpers.lua",
	"Core/ScannerStandardMetadata.lua",
	"Core/ScannerStandard.lua",
	"Core/ScannerMajor.lua",
	"Core/ScannerSpecial.lua",
	"Core/ScanPipeline.lua",
})

return function(runner, root)
	runner:test("ScannerStandardHelpers read faction rows from C_Reputation and legacy fallback APIs", function()
		local ctx = support.new_context(root, { files = SCANNER_FILES })
		local ns = ctx.ns
		local helpers = ns.ScannerStandardHelpers

		ctx.env.C_Reputation.GetFactionDataByIndex = function(index)
			A.equal(index, 1)
			return {
				id = 72,
				name = "Stormpike Guard",
				description = "Classic test",
				reaction = 5,
				earnedValue = 4500,
				barMin = 3000,
				barMax = 9000,
				isHeader = false,
				isCollapsed = false,
				hasRep = true,
				isChild = true,
				isWatched = true,
				atWarWith = false,
				canToggleAtWar = true,
				isWarband = true,
				expansion = ctx.env.LE_EXPANSION_CLASSIC,
				majorFactionID = 2600,
			}
		end

		local row = helpers.getFactionDataByIndex(1)
		A.equal(row.factionID, 72)
		A.equal(row.name, "Stormpike Guard")
		A.equal(row.currentStanding, 4500)
		A.equal(row.currentReactionThreshold, 3000)
		A.equal(row.nextReactionThreshold, 9000)
		A.truthy(row.isAccountWide)
		A.equal(row.majorFactionID, 2600)

		ctx.env.C_Reputation.GetFactionDataByIndex = nil
		ctx.env.GetFactionInfo = function(index)
			A.equal(index, 2)
			return "Booty Bay", "Classic fallback", 6, 3000, 9000, 6000, false, true, false, false, true, false, true, 47
		end

		row = helpers.getFactionDataByIndex(2)
		A.equal(row.factionID, 47)
		A.equal(row.name, "Booty Bay")
		A.equal(row.standingId, 6)
		A.equal(row.currentStanding, 6000)
		A.falsy(row.isAccountWide)
		A.truthy(row.isChild)
	end)

	runner:test("ScannerStandard metadata helpers preserve only the intended faction sources", function()
		local ctx = support.new_context(root, { files = SCANNER_FILES })
		local ns = ctx.ns
		ns.InitDB()

		ns.SaveCharacterSnapshot(support.make_snapshot(ns, {
			characterKey = "TestRealm::Tester",
			name = "Tester",
			realm = "TestRealm",
			lastScanAt = 300,
			reputations = {
				["100"] = support.make_reputation(ns, {
					factionID = 100,
					name = "Booty Bay",
					expansionKey = "classic",
					headerPath = { "Classic / Vanilla", "Steamwheedle Cartel" },
				}),
				["300"] = support.make_reputation(ns, {
					factionID = 300,
					name = "Council of Dornogal",
					expansionKey = "tww",
					repType = ns.REP_TYPE.MAJOR,
					majorFactionID = 300,
					renownLevel = 5,
					renownMaxLevel = 10,
				}),
			},
		}))
		ns.SaveCharacterSnapshot(support.make_snapshot(ns, {
			characterKey = "Beta::Alt",
			name = "Alt",
			realm = "Beta",
			lastScanAt = 200,
			reputations = {
				["100"] = support.make_reputation(ns, {
					factionID = 100,
					name = "Booty Bay",
					expansionKey = "classic",
					isAccountWide = true,
				}),
				["200"] = support.make_reputation(ns, {
					factionID = 200,
					name = "The Cartels of Undermine",
					expansionKey = "tww",
					isAccountWide = true,
				}),
			},
		}))

		local ids, meta = ns.ScannerStandardHelpers.getCharacterFactionMetadata("TestRealm::Tester")
		A.same(ids, { 100, 300 })
		A.same(meta[100].headerPath, { "Classic / Vanilla", "Steamwheedle Cartel" })

		local known_ids, known_meta, counts = ns.ScannerStandardHelpers.getKnownStandardFactionMetadata("TestRealm::Tester")
		A.same(known_ids, { 100, 200 })
		A.equal(known_meta[100].sourceKind, "currentCharacter")
		A.equal(known_meta[200].sourceKind, "accountWideOther")
		A.equal(counts.currentCharacter, 1)
		A.equal(counts.accountWideOther, 1)
	end)

	runner:test("Header expansion helpers track mutated headers and restore them in reverse order", function()
		local ctx = support.new_context(root, { files = SCANNER_FILES })
		local ns = ctx.ns
		local helpers = ns.ScannerStandardHelpers
		local headers = {
			{ name = "Classic / Vanilla", isHeader = true, isCollapsed = true },
			{ name = "Steamwheedle Cartel", isHeader = true, isCollapsed = true },
		}

		ctx.env.C_Reputation.GetNumFactions = function()
			return #headers
		end
		ctx.env.C_Reputation.GetFactionDataByIndex = function(index)
			return headers[index]
		end
		ctx.env.C_Reputation.ExpandFactionHeader = function(index)
			headers[index].isCollapsed = false
		end
		ctx.env.C_Reputation.CollapseFactionHeader = function(index)
			headers[index].isCollapsed = true
		end

		local collapsed = helpers.expandAllHeaders()
		A.same(collapsed, { "Classic / Vanilla", "Steamwheedle Cartel" })
		A.falsy(headers[1].isCollapsed)
		A.falsy(headers[2].isCollapsed)
		A.equal(ns.PlayerStateEnsure().suppressedUpdateFactionEvents, 2)

		helpers.restoreCollapsedHeaders(collapsed)
		A.truthy(headers[1].isCollapsed)
		A.truthy(headers[2].isCollapsed)
		A.equal(ns.PlayerStateEnsure().suppressedUpdateFactionEvents, 4)
	end)

	runner:test("Header mutation suppression starts before Blizzard header APIs run", function()
		local ctx = support.new_context(root, { files = SCANNER_FILES })
		local ns = ctx.ns
		local helpers = ns.ScannerStandardHelpers
		local headers = {
			{ name = "Classic / Vanilla", isHeader = true, isCollapsed = true },
		}

		ctx.env.C_Reputation.GetNumFactions = function()
			return #headers
		end
		ctx.env.C_Reputation.GetFactionDataByIndex = function(index)
			return headers[index]
		end
		ctx.env.C_Reputation.ExpandFactionHeader = function(index)
			A.truthy(ns.PlayerStateEnsure().suppressedUpdateFactionUntil > ns.SafeTime())
			headers[index].isCollapsed = false
		end
		ctx.env.C_Reputation.CollapseFactionHeader = function(index)
			A.truthy(ns.PlayerStateEnsure().suppressedUpdateFactionUntil > ns.SafeTime())
			headers[index].isCollapsed = true
		end

		local collapsed = helpers.expandAllHeaders()
		A.same(collapsed, { "Classic / Vanilla" })
		helpers.restoreCollapsedHeaders(collapsed)
		A.equal(ns.PlayerStateEnsure().suppressedUpdateFactionEvents, 2)
	end)

	runner:test("GetStandardScanRowByFactionID rejects invalid rows and carries known metadata", function()
		local ctx = support.new_context(root, { files = SCANNER_FILES })
		local ns = ctx.ns

		ns.ScannerStandardHelpers.getFactionDataByFactionID = function()
			return {
				factionID = 99,
				name = "Header",
				isHeader = true,
				hasRep = true,
			}
		end
		A.equal(ns.GetStandardScanRowByFactionID(99, nil), nil)

		ns.ScannerStandardHelpers.getFactionDataByFactionID = function(faction_id)
			A.equal(faction_id, 72)
			return {
				factionID = 72,
				name = "Stormpike Guard",
				description = "Known row",
				standingId = 6,
				currentStanding = 5000,
				currentReactionThreshold = 3000,
				nextReactionThreshold = 9000,
				isHeader = false,
				hasRep = true,
				isChild = true,
			}
		end

		local row = ns.GetStandardScanRowByFactionID(72, {
			headerPath = { "Classic / Vanilla", "Alliance Vanguard" },
			expansionKey = "classic",
		})
		A.equal(row.factionKey, "72")
		A.same(row.headerPath, { "Classic / Vanilla", "Alliance Vanguard" })
		A.equal(row.expansionKey, "classic")
		A.truthy(row.isChild)
	end)

	runner:test("ScanStandardReputations builds header ancestry and appends known fallback rows", function()
		local ctx = support.new_context(root, { files = SCANNER_FILES })
		local ns = ctx.ns
		local helpers = ns.ScannerStandardHelpers
		local restored_headers = nil
		local rows_by_index = {
			[1] = { name = "Dragonflight", isHeader = true },
			[2] = { name = "Valdrakken Accord", isHeader = true },
			[3] = { name = "Aiding the Accord", isHeader = true, isChild = true },
			[4] = {
				factionID = 2511,
				name = "Iskaara Tuskarr",
				standingId = 5,
				currentStanding = 4500,
				currentReactionThreshold = 3000,
				nextReactionThreshold = 9000,
				isChild = true,
			},
		}

		helpers.expandAllHeaders = function()
			return { "Dragonflight" }
		end
		helpers.restoreCollapsedHeaders = function(collapsed)
			restored_headers = collapsed
		end
		helpers.getNumFactions = function()
			return 4
		end
		helpers.getFactionDataByIndex = function(index)
			return rows_by_index[index]
		end
		helpers.getKnownStandardFactionMetadata = function()
			return { 999 }, {
				[999] = {
					name = "Dream Wardens",
					expansionKey = "df",
					headerPath = { "Dragonflight", "Emerald Dream" },
				},
			}, {
				currentCharacter = 1,
				accountWideOther = 0,
			}
		end
		helpers.getFactionDataByFactionID = function(faction_id)
			A.equal(faction_id, 999)
			return {
				factionID = faction_id,
				name = "Dream Wardens",
				standingId = 4,
				currentStanding = 1200,
				currentReactionThreshold = 0,
				nextReactionThreshold = 3000,
				hasRep = true,
			}
		end

		local rows, scan_context = ns.ScanStandardReputations()
		A.equal(#rows, 2)
		A.same(rows[1].headerPath, { "Dragonflight", "Valdrakken Accord", "Aiding the Accord" })
		A.same(rows[2].headerPath, { "Dragonflight", "Emerald Dream" })
		A.same(restored_headers, { "Dragonflight" })
		A.same(scan_context.headerAncestorsByName[ns.NormalizeSearchText("Valdrakken Accord")], { "Dragonflight" })
		A.equal(ns.PlayerStateEnsure().lastStandardScanCount, 2)
	end)

	runner:test("ScanStandardReputations keeps sibling child headers from chaining into each other", function()
		local ctx = support.new_context(root, { files = SCANNER_FILES })
		local ns = ctx.ns
		local helpers = ns.ScannerStandardHelpers
		local rows_by_index = {
			[1] = { name = "Dragonflight", isHeader = true },
			[2] = { name = "Valdrakken Accord", isHeader = true },
			[3] = { name = "Child A", isHeader = true, isChild = true },
			[4] = { name = "Child B", isHeader = true, isChild = true },
			[5] = {
				factionID = 2510,
				name = "Valdrakken Accord",
				standingId = 6,
				currentStanding = 6000,
				currentReactionThreshold = 3000,
				nextReactionThreshold = 9000,
				isChild = true,
			},
		}

		helpers.expandAllHeaders = function()
			return {}
		end
		helpers.restoreCollapsedHeaders = function()
		end
		helpers.getNumFactions = function()
			return 5
		end
		helpers.getFactionDataByIndex = function(index)
			return rows_by_index[index]
		end
		helpers.getKnownStandardFactionMetadata = function()
			return {}, {}, {
				currentCharacter = 0,
				accountWideOther = 0,
			}
		end

		local rows = ns.ScanStandardReputations()
		A.equal(#rows, 1)
		A.same(rows[1].headerPath, { "Dragonflight", "Valdrakken Accord", "Child B" })
	end)

	runner:test("Major faction scans use standard-row visibility data and include standalone factions", function()
		local ctx = support.new_context(root, { files = SCANNER_FILES })
		local ns = ctx.ns

		ctx.env.C_MajorFactions.GetMajorFactionIDs = function()
			return { 2590, 2600 }
		end
		ctx.env.C_MajorFactions.GetMajorFactionData = function(faction_id)
			if faction_id == 2590 then
				return {
					name = "Council of Dornogal",
					description = "Major test",
					expansionID = ctx.env.LE_EXPANSION_WAR_WITHIN,
					isWarband = true,
				}
			end
			if faction_id == 2600 then
				return {
					name = "The Cartels of Undermine",
					description = "Standalone major",
					expansionID = ctx.env.LE_EXPANSION_WAR_WITHIN,
					isWarband = true,
				}
			end
			return nil
		end

		local direct = ns.GetMajorFactionScanRowByFactionID(2590, {
			factionKey = "visible-2590",
			factionID = 5000,
			name = "Council of Dornogal",
			standingId = 8,
			currentStanding = 2000,
			bottomValue = 0,
			topValue = 2500,
			headerPath = { "The War Within" },
		}, nil)
		A.equal(direct.factionKey, "visible-2590")
		A.equal(direct.factionID, 5000)
		A.equal(direct.majorFactionID, 2590)
		A.same(direct.headerPath, { "The War Within" })
		A.truthy(direct.isAccountWide)

		local rows = ns.ScanMajorReputations({
			{
				factionKey = "2590",
				factionID = 2590,
				name = "Council of Dornogal",
				majorFactionID = 2590,
				headerPath = { "The War Within" },
			},
		}, {
			headerAncestorsByName = {
				[ns.NormalizeSearchText("The Cartels of Undermine")] = { "The War Within", "Undermine" },
			},
		})
		A.equal(#rows, 2)
		A.equal(rows[1].majorFactionID, 2590)
		A.equal(rows[2].majorFactionID, 2600)
		A.same(rows[2].headerPath, { "The War Within", "Undermine" })
		A.equal(ns.PlayerStateEnsure().lastMajorScanCount, 2)
	end)

	runner:test("MergeScannedReputationRows enriches standard rows and appends standalone majors", function()
		local ctx = support.new_context(root, { files = SCANNER_FILES })
		local ns = ctx.ns

		local rows = ns.MergeScannedReputationRows({
			{
				factionKey = "2590",
				factionID = 2590,
				name = "Council of Dornogal",
				description = "",
				headerPath = { "Old Header" },
				isAccountWide = false,
			},
		}, {
			{
				factionKey = "2590",
				factionID = 2590,
				description = "Merged description",
				headerPath = { "The War Within" },
				expansionID = ctx.env.LE_EXPANSION_WAR_WITHIN,
				majorFactionID = 2590,
				isAccountWide = true,
				rawMajorData = { renownLevel = 5 },
			},
			{
				factionKey = "2600",
				factionID = 2600,
				name = "The Cartels of Undermine",
				headerPath = { "The War Within", "Undermine" },
				majorFactionID = 2600,
			},
		})

		A.equal(#rows, 2)
		A.equal(rows[1].description, "Merged description")
		A.same(rows[1].headerPath, { "The War Within" })
		A.truthy(rows[1].isAccountWide)
		A.equal(rows[1].majorFactionID, 2590)
		A.equal(rows[2].factionKey, "2600")
	end)

	runner:test("Special reputation scan merges neighborhood, friendship, paragon, and major data", function()
		local ctx = support.new_context(root, { files = SCANNER_FILES })
		local ns = ctx.ns

		ctx.env.C_MajorFactions.GetMajorFactionData = function(faction_id)
			if faction_id == 2590 then
				return {
					name = "Council of Dornogal",
					renownLevel = 5,
					maxRenownLevel = 10,
					renownReputationEarned = 1200,
					renownLevelThreshold = 2500,
					isWarband = true,
				}
			end
			return nil
		end
		ctx.env.GetFriendshipReputation = function(faction_id)
			if faction_id == 2590 then
				return 1, 1500, 3000, "Council", "Friendly", nil, "Buddy", 1000, 3000
			end
			return nil
		end
		ctx.env.GetFriendshipReputationRanks = function(faction_id)
			if faction_id == 2590 then
				return 2, 6
			end
			return nil
		end
		ctx.env.C_Reputation.GetFactionParagonInfo = function(faction_id)
			if faction_id == 2590 then
				return 2500, 1000, 1234, true, false
			end
			return nil
		end

		local out, summary = ns.AppendSpecialReputationData({
			{
				factionKey = "2590",
				factionID = 2590,
				name = "Council of Dornogal",
				majorFactionID = 2590,
				isAccountWide = true,
			},
			{
				factionKey = "500",
				factionID = 500,
				name = "Neighborhood Initiative",
				isAccountWide = true,
			},
		}, {}, nil)

		A.equal(out["2590"].repType, ns.REP_TYPE.MAJOR)
		A.equal(out["2590"].renownLevel, 5)
		A.equal(out["2590"].renownMaxLevel, 10)
		A.equal(out["2590"].currentValue, 1200)
		A.equal(out["2590"].maxValue, 2500)
		A.truthy(out["2590"].hasParagon)
		A.equal(out["2590"].paragonValue, 1500)
		A.equal(out["2590"].friendCurrentRank, 2)
		A.equal(out["500"].repType, ns.REP_TYPE.NEIGHBORHOOD)
		A.truthy(out["500"].isAccountWide)
		A.same(summary, {
			major = 1,
			friendship = 1,
			paragon = 1,
			neighborhood = 1,
		})

		local special = ns.ScanSpecialReputationData({
			{
				factionKey = "500",
				factionID = 500,
				name = "Neighborhood Initiative",
				isAccountWide = true,
			},
		})
		A.equal(special["500"].repType, ns.REP_TYPE.NEIGHBORHOOD)
		A.same(ns.PlayerStateEnsure().lastSpecialScanSummary, {
			major = 0,
			friendship = 0,
			paragon = 0,
			neighborhood = 1,
		})
	end)

	runner:test("ScanCurrentCharacter runs the full scan-normalize-save pipeline", function()
		local ctx = support.new_context(root, { files = SCANNER_FILES })
		local ns = ctx.ns
		local calls = {}

		ns.ScanStandardReputations = function()
			calls[#calls + 1] = "standard"
			return { { factionKey = "1" } }, { headerAncestorsByName = {} }
		end
		ns.ScanMajorReputations = function(standard_rows, scan_context)
			calls[#calls + 1] = "major"
			A.equal(#standard_rows, 1)
			A.truthy(scan_context.headerAncestorsByName)
			return { { factionKey = "2" } }
		end
		ns.MergeScannedReputationRows = function(standard_rows, major_rows)
			calls[#calls + 1] = "merge"
			A.equal(#standard_rows, 1)
			A.equal(#major_rows, 1)
			return {
				{ factionKey = "1", name = "One" },
				{ factionKey = "2", name = "Two" },
			}
		end
		ns.ScanSpecialReputationData = function(scan_rows)
			calls[#calls + 1] = "special"
			A.equal(#scan_rows, 2)
			return {
				["2"] = { repType = ns.REP_TYPE.MAJOR },
			}
		end
		ns.NormalizeCurrentCharacterSnapshot = function(reason, scan_rows, special_map)
			calls[#calls + 1] = "normalize"
			A.equal(reason, "Manual")
			A.equal(#scan_rows, 2)
			A.equal(special_map["2"].repType, ns.REP_TYPE.MAJOR)
			return {
				characterKey = "TestRealm::Tester",
				name = "Tester",
				realm = "TestRealm",
				reputationCount = 2,
			}
		end
		ns.SaveCharacterSnapshot = function(snapshot)
			calls[#calls + 1] = "save"
			A.equal(snapshot.reputationCount, 2)
		end

		local snapshot = ns.ScanCurrentCharacter("Manual")
		A.equal(snapshot.reputationCount, 2)
		A.same(calls, { "standard", "major", "merge", "special", "normalize", "save" })
	end)

	runner:test("Known and targeted refresh entry points fall back or resolve targeted rows as needed", function()
		local ctx = support.new_context(root, { files = SCANNER_FILES })
		local ns = ctx.ns
		local calls = {}

		ns.ScanCurrentCharacter = function(reason)
			calls[#calls + 1] = "full:" .. tostring(reason)
			return { reputationCount = 9 }
		end
		ns.ScannerStandardHelpers.getCharacterFactionMetadata = function()
			return {}, {}
		end

		local result = ns.RefreshCurrentCharacterKnownReputations("Known")
		A.equal(result.reputationCount, 9)
		A.same(calls, { "full:Known" })

		calls = {}
		ns.ScannerStandardHelpers.getCharacterFactionMetadata = function()
			return {}, {
				[2590] = {
					name = "Council of Dornogal",
					expansionKey = "tww",
					headerPath = { "The War Within" },
					majorFactionID = 2590,
					standingId = 8,
					currentStanding = 2500,
					bottomValue = 0,
					topValue = 2500,
					isAccountWide = true,
				},
			}
		end
		ns.GetStandardScanRowByFactionID = function()
			return nil
		end
		ns.GetMajorFactionScanRowByFactionID = function(major_faction_id, meta)
			A.equal(major_faction_id, 2590)
			return {
				factionKey = tostring(meta.factionID),
				factionID = meta.factionID,
				name = meta.name,
				majorFactionID = major_faction_id,
				headerPath = support.copy_array(meta.headerPath),
			}
		end
		ns.ScanSpecialReputationData = function(scan_rows)
			A.equal(#scan_rows, 1)
			return {}
		end
		ns.NormalizeCurrentCharacterSnapshot = function(reason, scan_rows)
			A.equal(reason, "Targeted")
			A.equal(#scan_rows, 1)
			A.equal(scan_rows[1].majorFactionID, 2590)
			return {
				characterKey = "TestRealm::Tester",
				name = "Tester",
				realm = "TestRealm",
				reputationCount = 1,
			}
		end
		ns.SaveCharacterSnapshot = function(snapshot)
			calls[#calls + 1] = "save:" .. tostring(snapshot.reputationCount)
		end

		result = ns.RefreshCurrentCharacterByFactionIDs("Targeted", { 2590, 2590, 0 })
		A.equal(result.reputationCount, 1)
		A.same(calls, { "save:1" })
	end)

	runner:test("Refresh entry points cover empty targeted IDs and unresolved known rows", function()
		local ctx = support.new_context(root, { files = SCANNER_FILES })
		local ns = ctx.ns
		local calls = {}

		ns.RefreshCurrentCharacterKnownReputations = function(reason)
			calls[#calls + 1] = "known:" .. tostring(reason)
			return { reputationCount = 5 }
		end
		local result = ns.RefreshCurrentCharacterByFactionIDs("EmptyTargeted", {})
		A.equal(result.reputationCount, 5)
		A.same(calls, { "known:EmptyTargeted" })

		ctx = support.new_context(root, { files = SCANNER_FILES })
		ns = ctx.ns
		calls = {}
		ns.ScannerStandardHelpers.getCharacterFactionMetadata = function()
			return { 7 }, {
				[7] = { name = "Unresolved" },
			}
		end
		ns.GetStandardScanRowByFactionID = function()
			return nil
		end
		ns.GetMajorFactionScanRowByFactionID = function()
			return nil
		end
		ns.ScanCurrentCharacter = function(reason)
			calls[#calls + 1] = "full:" .. tostring(reason)
			return { reputationCount = 8 }
		end

		result = ns.RefreshCurrentCharacterKnownReputations("KnownFallback")
		A.equal(result.reputationCount, 8)
		A.same(calls, { "full:KnownFallback" })
	end)

	runner:test("Async known refresh falls back immediately when async scheduling is unavailable or empty", function()
		local ctx = support.new_context(root, { files = SCANNER_FILES })
		local ns = ctx.ns

		ctx.env.C_Timer = nil
		A.falsy(ns.StartAsyncKnownReputationRefresh("Any", 1, function() end))

		ctx = support.new_context(root, { files = SCANNER_FILES })
		ns = ctx.ns
		ns.ScannerStandardHelpers.getCharacterFactionMetadata = function()
			return {}, {}
		end
		ns.ScanCurrentCharacter = function(reason)
			A.equal(reason, "Fallback")
			return { reputationCount = 4 }
		end

		local completed = nil
		A.truthy(ns.StartAsyncKnownReputationRefresh("Fallback", 10, function(ok, payload)
			completed = { ok = ok, payload = payload }
		end))
		A.truthy(completed.ok)
		A.equal(completed.payload.reputationCount, 4)
	end)

	runner:test("Async known refresh batches target resolution, special enrichment, and final save", function()
		local ctx = support.new_context(root, { files = SCANNER_FILES })
		local ns = ctx.ns
		local resolved_ids = {}
		local special_batch_sizes = {}
		local completed = {}

		ns.KNOWN_REFRESH_RESOLVE_BATCH_SIZE = 2
		ns.KNOWN_REFRESH_SPECIAL_BATCH_SIZE = 1
		ns.PlayerStateEnsure().activeScanToken = 77
		ns.ScannerStandardHelpers.getCharacterFactionMetadata = function()
			return { 1, 2, 3 }, {
				[1] = { name = "One" },
				[2] = { name = "Two" },
				[3] = { name = "Three" },
			}
		end
		ns.GetStandardScanRowByFactionID = function(faction_id)
			resolved_ids[#resolved_ids + 1] = faction_id
			return {
				factionKey = tostring(faction_id),
				factionID = faction_id,
				name = "Faction " .. tostring(faction_id),
			}
		end
		ns.AppendSpecialReputationData = function(batch_rows, out, summary)
			special_batch_sizes[#special_batch_sizes + 1] = #batch_rows
			summary = summary or {
				major = 0,
				friendship = 0,
				paragon = 0,
				neighborhood = 0,
			}
			for index = 1, #batch_rows do
				out[batch_rows[index].factionKey] = { hasParagon = true }
				summary.paragon = summary.paragon + 1
			end
			return out, summary
		end
		ns.LogSpecialReputationSummary = function(summary)
			completed.summary = summary
		end
		ns.NormalizeCurrentCharacterSnapshot = function(reason, scan_rows, special_map)
			completed.normalize = {
				reason = reason,
				rowCount = #scan_rows,
				specialCount = ns.CountTable(special_map),
			}
			return {
				characterKey = "TestRealm::Tester",
				name = "Tester",
				realm = "TestRealm",
				reputationCount = #scan_rows,
			}
		end
		ns.SaveCharacterSnapshot = function(snapshot)
			completed.saved = snapshot
		end

		local on_complete = nil
		A.truthy(ns.StartAsyncKnownReputationRefresh("Batch", 77, function(ok, payload)
			on_complete = { ok = ok, payload = payload }
		end))

		ctx.run_all_timers()

		A.same(resolved_ids, { 1, 2, 3 })
		A.same(special_batch_sizes, { 1, 1, 1 })
		A.equal(completed.normalize.reason, "Batch")
		A.equal(completed.normalize.rowCount, 3)
		A.equal(completed.normalize.specialCount, 3)
		A.same(completed.summary, {
			major = 0,
			friendship = 0,
			paragon = 3,
			neighborhood = 0,
		})
		A.truthy(on_complete.ok)
		A.equal(on_complete.payload.reputationCount, 3)
	end)

	runner:test("Async known refresh falls back to a full scan when no target rows resolve", function()
		local ctx = support.new_context(root, { files = SCANNER_FILES })
		local ns = ctx.ns
		ns.PlayerStateEnsure().activeScanToken = 44

		ns.ScannerStandardHelpers.getCharacterFactionMetadata = function()
			return { 99 }, {
				[99] = { name = "Missing" },
			}
		end
		ns.GetStandardScanRowByFactionID = function()
			return nil
		end
		ns.GetMajorFactionScanRowByFactionID = function()
			return nil
		end
		ns.ScanCurrentCharacter = function(reason)
			A.equal(reason, "AsyncFallback")
			return { reputationCount = 6 }
		end

		local result = nil
		A.truthy(ns.StartAsyncKnownReputationRefresh("AsyncFallback", 44, function(ok, payload)
			result = { ok = ok, payload = payload }
		end))

		ctx.run_all_timers()
		A.truthy(result.ok)
		A.equal(result.payload.reputationCount, 6)
	end)
end
