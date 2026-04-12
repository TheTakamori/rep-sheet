local support = require("support")
local A = support.assert

local function scan_result(name, count)
	return {
		characterKey = string.format("TestRealm::%s", name or "Tester"),
		name = name or "Tester",
		realm = "TestRealm",
		reputationCount = count or 1,
	}
end

local function build_parent_rep(ns)
	return support.make_reputation(ns, {
		factionID = 1000,
		name = "Steamwheedle Cartel",
		expansionKey = "classic",
		standingId = 6,
		currentValue = 3000,
		maxValue = 6000,
		headerPath = { "Classic / Vanilla" },
	})
end

local function build_child_rep(ns)
	return support.make_reputation(ns, {
		factionID = 1001,
		name = "Booty Bay",
		expansionKey = "classic",
		standingId = 5,
		currentValue = 1500,
		maxValue = 3000,
		isChild = true,
		headerPath = { "Classic / Vanilla", "Steamwheedle Cartel" },
	})
end

return function(runner, root)
	runner:test("SaveCharacterSnapshot preserves missing standard reputations from a stronger prior snapshot", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		ns.InitDB()

		local initial = support.make_snapshot(ns, {
			characterKey = "TestRealm::Alpha",
			name = "Alpha",
			lastScanAt = 100,
			lastScanReason = "Initial",
			reputations = {
				["100"] = support.make_reputation(ns, {
					factionID = 100,
					name = "Booty Bay",
					expansionKey = "classic",
					standingId = 6,
					currentValue = 3000,
					maxValue = 6000,
					isChild = true,
					headerPath = { "Classic / Vanilla", "Steamwheedle Cartel" },
				}),
				["200"] = support.make_reputation(ns, {
					factionID = 200,
					name = "Everlook",
					expansionKey = "classic",
					standingId = 5,
					currentValue = 1500,
					maxValue = 3000,
					isChild = true,
					headerPath = { "Classic / Vanilla", "Steamwheedle Cartel" },
				}),
				["300"] = support.make_reputation(ns, {
					factionID = 300,
					name = "Council of Dornogal",
					expansionKey = "tww",
					repType = ns.REP_TYPE.MAJOR,
					standingId = 8,
					currentValue = 1000,
					maxValue = 2500,
					majorFactionID = 300,
					renownLevel = 5,
					renownMaxLevel = 10,
					headerPath = { "The War Within" },
				}),
			},
		})
		ns.SaveCharacterSnapshot(initial)

		local partial = support.make_snapshot(ns, {
			characterKey = "TestRealm::Alpha",
			name = "Alpha",
			lastScanAt = 200,
			lastScanReason = "Known refresh",
			reputations = {
				["100"] = support.make_reputation(ns, {
					factionID = 100,
					name = "Booty Bay",
					expansionKey = "classic",
					standingId = 6,
					currentValue = 4500,
					maxValue = 6000,
					isChild = true,
					headerPath = { "Classic / Vanilla", "Steamwheedle Cartel" },
				}),
			},
		})
		ns.SaveCharacterSnapshot(partial)

		local stored = ns.GetCharacterByKey("TestRealm::Alpha")
		A.truthy(stored.reputations["100"])
		A.truthy(stored.reputations["200"])
		A.falsy(stored.reputations["300"])
		A.equal(stored.reputationCount, 2)
		A.equal(stored.bestKnownReputationCount, 3)
		A.equal(stored.bestKnownReputationReason, "Initial")
		A.contains(stored.scanNotes.partialMerge, "Preserved 1 missing reputations")
	end)

	runner:test("BuildFactionIndex keeps the newest account-wide representative entry", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		ns.InitDB()

		ns.SaveCharacterSnapshot(support.make_snapshot(ns, {
			characterKey = "TestRealm::Alpha",
			name = "Alpha",
			lastScanAt = 100,
			reputations = {
				["900"] = support.make_reputation(ns, {
					factionID = 900,
					name = "The Cartels of Undermine",
					expansionKey = "tww",
					standingId = 8,
					currentValue = 2500,
					maxValue = 3000,
					isAccountWide = true,
					headerPath = { "The War Within" },
				}),
			},
		}))

		ns.SaveCharacterSnapshot(support.make_snapshot(ns, {
			characterKey = "TestRealm::Beta",
			name = "Beta",
			lastScanAt = 200,
			reputations = {
				["900"] = support.make_reputation(ns, {
					factionID = 900,
					name = "The Cartels of Undermine",
					expansionKey = "tww",
					standingId = 8,
					currentValue = 1500,
					maxValue = 3000,
					isAccountWide = true,
					headerPath = { "The War Within" },
				}),
			},
		}))

		local bucket = ns.GetFactionBucketByKey("900")
		A.truthy(bucket.isAccountWide)
		A.equal(bucket.displayCount, 1)
		A.equal(#bucket.entries, 1)
		A.equal(bucket.bestEntry.characterKey, "TestRealm::Beta")
		A.equal(bucket.bestCharacterName, "Beta")
	end)

	runner:test("GetVisibleFactionRows reveals matching children beneath collapsed parents", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		ns.InitDB()

		ns.SaveCharacterSnapshot(support.make_snapshot(ns, {
			characterKey = "TestRealm::Alpha",
			name = "Alpha",
			reputations = {
				["1000"] = build_parent_rep(ns),
				["1001"] = build_child_rep(ns),
			},
		}))

		local child_bucket = ns.GetFactionBucketByKey("1001")
		A.equal(child_bucket.parentFactionKey, "1000")

		ns.SetFactionCollapsed("1000", true)
		local rows = ns.GetVisibleFactionRows()
		A.equal(#rows, 1)
		A.equal(rows[1].factionKey, "1000")
		A.truthy(rows[1].treeCollapsed)

		ns.SetFilterValue("searchText", "booty")
		rows = ns.GetVisibleFactionRows()
		A.equal(#rows, 2)
		A.equal(rows[1].factionKey, "1000")
		A.equal(rows[2].factionKey, "1001")
		A.falsy(rows[1].treeCollapsed)
		A.equal(rows[2].treeDepth, 1)
	end)

	runner:test("Favorites filter keeps matched descendants while visible rows keep ancestors", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		ns.InitDB()

		ns.SaveCharacterSnapshot(support.make_snapshot(ns, {
			characterKey = "TestRealm::Alpha",
			name = "Alpha",
			reputations = {
				["1000"] = build_parent_rep(ns),
				["1001"] = build_child_rep(ns),
			},
		}))

		ns.ToggleFavoriteFaction("1001")
		ns.SetFilterValue("statusKey", ns.FILTER_STATUS.FAVORITES)

		local results, total_characters = ns.GetFilteredFactionResults()
		A.equal(total_characters, 1)
		A.equal(#results, 1)
		A.equal(results[1].factionKey, "1001")

		local rows = ns.GetVisibleFactionRows()
		A.equal(#rows, 2)
		A.equal(rows[1].factionKey, "1000")
		A.equal(rows[2].factionKey, "1001")
	end)

	runner:test("Combat message resolution suppresses generic refreshes during targeted bursts", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns

		ctx.env.FACTION_STANDING_INCREASED = "Reputation with %s increased by %d."
		ns.ScannerStandardHelpers.getCharacterFactionMetadata = function()
			return { 2600, 2590 }, {
				[2600] = { name = "The Cartels of Undermine" },
				[2590] = { name = "Council of Dornogal" },
			}
		end

		local message = "Reputation with The Cartels of Undermine increased by 500."
		A.equal(ns.ExtractFactionNameFromCombatMessage(message), "The Cartels of Undermine")

		local faction_ids, faction_name = ns.ResolveFactionIDsFromCombatMessage(message)
		A.same(faction_ids, { 2600 })
		A.equal(faction_name, "The Cartels of Undermine")

		A.same(ns.NoteTargetedFactionRefresh({ 2600, 0, 2600 }), { 2600 })
		A.truthy(ns.ShouldSuppressGenericFactionRefresh(ns.SCAN_REASON.UPDATE_FACTION))

		ctx.advance(2.1)
		A.falsy(ns.ShouldSuppressGenericFactionRefresh(ns.SCAN_REASON.UPDATE_FACTION))
	end)

	runner:test("RequestReputationScan runs immediate full scans synchronously", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		local calls = {}

		ns.ScanCurrentCharacter = function(reason)
			calls[#calls + 1] = { kind = "full", reason = reason }
			return scan_result("Immediate", 4)
		end

		ns.RequestReputationScan(ns.SCAN_REASON.MANUAL_REFRESH, true)

		local state = ns.PlayerStateEnsure()
		A.equal(#calls, 1)
		A.equal(calls[1].reason, ns.SCAN_REASON.MANUAL_REFRESH)
		A.falsy(state.scanInProgress)
		A.equal(state.lastObservedReputationCount, 4)
		A.equal(state.lastSuccessfulScanReason, ns.SCAN_REASON.MANUAL_REFRESH)
	end)

	runner:test("RequestReputationScan merges delayed known-refresh requests into one timer", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		local calls = {}

		ns.RefreshCurrentCharacterKnownReputations = function(reason)
			calls[#calls + 1] = { kind = "known", reason = reason }
			return scan_result("Known", 2)
		end

		ns.RequestReputationScan(ns.SCAN_REASON.UPDATE_FACTION, false, "known")
		ns.RequestReputationScan(ns.SCAN_REASON.QUEST_TURNED_IN, false, "known")

		A.equal(#calls, 0)
		A.equal(#ctx.env.__timers, 1)

		ctx.advance(ns.SCAN_DELAY_SECONDS)
		A.equal(#calls, 1)
		A.equal(calls[1].reason, ns.SCAN_REASON.QUEST_TURNED_IN)
	end)

	runner:test("Targeted refreshes replace pending generic known refreshes", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		local known_calls = {}
		local targeted_calls = {}

		ns.RefreshCurrentCharacterKnownReputations = function(reason)
			known_calls[#known_calls + 1] = reason
			return scan_result("Known", 2)
		end

		ns.RefreshCurrentCharacterByFactionIDs = function(reason, faction_ids)
			targeted_calls[#targeted_calls + 1] = {
				reason = reason,
				factionIDs = support.copy_array(faction_ids),
			}
			return scan_result("Targeted", 2)
		end

		ns.RequestReputationScan(ns.SCAN_REASON.UPDATE_FACTION, false, "known")
		ns.RequestReputationScan(ns.SCAN_REASON.CHAT_MSG_COMBAT_FACTION_CHANGE, false, "factions", { 9, 1, 9 })
		ctx.advance(ns.SCAN_DELAY_SECONDS)

		A.equal(#known_calls, 0)
		A.equal(#targeted_calls, 1)
		A.equal(targeted_calls[1].reason, ns.SCAN_REASON.CHAT_MSG_COMBAT_FACTION_CHANGE)
		A.same(targeted_calls[1].factionIDs, { 1, 9 })
	end)

	runner:test("Combat-deferred refreshes wait for regen and then reschedule normally", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		local calls = {}

		ns.RefreshCurrentCharacterKnownReputations = function(reason)
			calls[#calls + 1] = reason
			return scan_result("CombatDeferred", 3)
		end

		ctx.set_combat(true)
		ns.RequestReputationScan(ns.SCAN_REASON.UPDATE_FACTION, false, "known")
		ctx.advance(5)
		A.equal(#calls, 0)

		ctx.set_combat(false)
		ctx.trigger_event(ns.EVENT.PLAYER_REGEN_ENABLED)
		A.equal(#calls, 0)

		ctx.advance(ns.SCAN_DELAY_SECONDS)
		A.equal(#calls, 1)
		A.equal(calls[1], ns.SCAN_REASON.UPDATE_FACTION)
	end)

	runner:test("Queued refreshes run after an async known refresh completes", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		local calls = {}
		local pending_complete = nil

		ns.StartAsyncKnownReputationRefresh = function(reason, scan_token, on_complete)
			calls[#calls + 1] = {
				kind = "async-known",
				reason = reason,
				scanToken = scan_token,
			}
			pending_complete = on_complete
			return true
		end

		ns.RefreshCurrentCharacterByFactionIDs = function(reason, faction_ids)
			calls[#calls + 1] = {
				kind = "targeted",
				reason = reason,
				factionIDs = support.copy_array(faction_ids),
			}
			return scan_result("QueuedTargeted", 1)
		end

		ns.RequestReputationScan(ns.SCAN_REASON.UPDATE_FACTION, false, "known")
		ctx.advance(ns.SCAN_DELAY_SECONDS)

		local state = ns.PlayerStateEnsure()
		A.equal(#calls, 1)
		A.equal(calls[1].kind, "async-known")
		A.truthy(state.scanInProgress)

		ns.RequestReputationScan(ns.SCAN_REASON.CHAT_MSG_COMBAT_FACTION_CHANGE, false, "factions", { 7 })
		A.equal(state.queuedRefresh.mode, "factions")
		A.same(state.queuedRefresh.factionIDs, { 7 })

		pending_complete(true, scan_result("AsyncKnown", 2))
		A.falsy(state.scanInProgress)

		ctx.advance(ns.SCAN_DELAY_SECONDS)
		A.equal(#calls, 2)
		A.equal(calls[2].kind, "targeted")
		A.equal(calls[2].reason, ns.SCAN_REASON.CHAT_MSG_COMBAT_FACTION_CHANGE)
		A.same(calls[2].factionIDs, { 7 })
	end)

	runner:test("Deferred background jobs resume after combat on the regen event", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		local resumed = 0

		ctx.set_combat(true)
		A.truthy(ns.DeferBackgroundJobUntilAfterCombat(function()
			resumed = resumed + 1
		end, "known refresh batch"))

		ctx.set_combat(false)
		ctx.trigger_event(ns.EVENT.PLAYER_REGEN_ENABLED)
		A.equal(resumed, 0)

		ctx.run_due_timers()
		A.equal(resumed, 1)
	end)
end
