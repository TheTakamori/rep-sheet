local support = require("support")
local A = support.assert

local DELETE_AND_UI_FILES = support.with_files({
	"Core/CharacterDelete.lua",
	"Core/OpenFactionUI.lua",
})

return function(runner, root)
	runner:test("InitDB resets stale snapshot storage and applies defaults", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns

		ctx.env.RepSheetDB = {
			version = 1,
			characters = {
				["OldRealm::Oldie"] = { characterKey = "OldRealm::Oldie" },
			},
			lastScanAt = 1234,
			lastScanCharacter = "OldRealm::Oldie",
			ui = {
				minimapButton = {
					angle = "bad",
				},
			},
			filters = {
				searchText = 42,
				expansionKey = "",
				sortKey = "",
				statusKey = "bogus",
			},
			options = {
				liveUpdates = {
					noLiveUpdates = false,
					updateOutOfCombat = true,
					updatePeriodic = true,
					periodicMinutes = "30",
				},
			},
		}

		ns.InitDB()

		local db = ns.GetDB()
		A.equal(db.version, ns.DB_SCHEMA_VERSION)
		A.same(db.characters, {})
		A.equal(db.lastScanAt, 0)
		A.equal(db.lastScanCharacter, "")
		A.equal(db.filters.searchText, "")
		A.equal(db.filters.expansionKey, ns.ALL_EXPANSIONS_KEY)
		A.equal(db.filters.sortKey, ns.SORT_KEY.BEST_PROGRESS)
		A.equal(db.filters.statusKey, ns.FILTER_STATUS.ALL)
		A.equal(db.options.liveUpdates.noLiveUpdates, false)
		A.truthy(db.options.liveUpdates.updateOutOfCombat)
		A.truthy(db.options.liveUpdates.updatePeriodic)
		A.equal(db.options.liveUpdates.periodicMinutes, 30)
		A.equal(ns.GetMinimapButtonAngle(), ns.DEFAULT_MINIMAP_BUTTON_ANGLE)
		A.truthy(ns.RuntimeEnsure().indexDirty)
	end)

	runner:test("InitDB backfills live update defaults without wiping current snapshots", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns

		ctx.env.RepSheetDB = {
			version = ns.DB_SCHEMA_VERSION,
			characters = {
				["Kept::Snapshot"] = { characterKey = "Kept::Snapshot" },
			},
			options = {},
		}

		ns.InitDB()

		local options = ns.GetLiveUpdateOptions()
		A.same(ctx.env.RepSheetDB.characters, {
			["Kept::Snapshot"] = { characterKey = "Kept::Snapshot" },
		})
		A.truthy(options.noLiveUpdates)
		A.falsy(options.updateAfterCombat)
		A.falsy(options.updateOutOfCombat)
		A.falsy(options.updatePeriodic)
		A.equal(options.periodicMinutes, ns.LIVE_UPDATE_PERIODIC_MINUTES_DEFAULT)
	end)

	runner:test("DB_SCHEMA_VERSION must remain at 2 to avoid wiping stored character data", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		A.equal(ns.DB_SCHEMA_VERSION, 2)
	end)

	runner:test("BuildCurrentPlayerProfessions returns both primary slots when populated", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		ctx.env.__player.professions = {
			prof1Index = 1,
			prof2Index = 2,
			byIndex = {
				[1] = { name = "Mining", skillLevel = 90, maxSkillLevel = 100 },
				[2] = { name = "Blacksmithing", skillLevel = 75, maxSkillLevel = 100 },
			},
		}

		local professions = ns.BuildCurrentPlayerProfessions()
		A.equal(professions.primary1.name, "Mining")
		A.equal(professions.primary1.skillLevel, 90)
		A.equal(professions.primary1.maxSkillLevel, 100)
		A.equal(professions.primary2.name, "Blacksmithing")
		A.equal(professions.primary2.skillLevel, 75)
	end)

	runner:test("BuildCurrentPlayerProfessions skips empty slots and survives a missing API", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		ctx.env.__player.professions = {
			prof1Index = 3,
			prof2Index = nil,
			byIndex = {
				[3] = { name = "Tailoring", skillLevel = 1, maxSkillLevel = 100 },
			},
		}

		local professions = ns.BuildCurrentPlayerProfessions()
		A.equal(professions.primary1.name, "Tailoring")
		A.equal(professions.primary2, nil)

		ctx.env.__player.professions = nil
		professions = ns.BuildCurrentPlayerProfessions()
		A.equal(professions.primary1, nil)
		A.equal(professions.primary2, nil)

		local previousGetProfessions = ctx.env.GetProfessions
		ctx.env.GetProfessions = nil
		A.equal(ns.BuildCurrentPlayerProfessions(), nil)

		ctx.env.GetProfessions = function()
			error("api blew up")
		end
		A.equal(ns.BuildCurrentPlayerProfessions(), nil)
		ctx.env.GetProfessions = previousGetProfessions
	end)

	runner:test("BuildCurrentCharacterMeta and SaveCharacterSnapshot persist captured professions", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		ns.InitDB()
		ctx.env.__player.professions = {
			prof1Index = 1,
			prof2Index = 2,
			byIndex = {
				[1] = { name = "Engineering", skillLevel = 50, maxSkillLevel = 100 },
				[2] = { name = "Mining", skillLevel = 60, maxSkillLevel = 100 },
			},
		}

		local meta = ns.BuildCurrentCharacterMeta()
		A.equal(meta.professions.primary1.name, "Engineering")
		A.equal(meta.professions.primary2.name, "Mining")

		local snapshot = ns.BuildCurrentCharacterSnapshotBase("test")
		ns.SaveCharacterSnapshot(snapshot)
		local stored = ns.GetCharacterByKey(snapshot.characterKey)
		A.equal(stored.professions.primary1.name, "Engineering")
		A.equal(stored.professions.primary2.name, "Mining")
	end)

	runner:test("SaveCharacterSnapshot leaves legacy snapshots without professions untouched", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		ctx.env.RepSheetDB = {
			version = ns.DB_SCHEMA_VERSION,
			characters = {
				["LegacyRealm::Legacy"] = {
					characterKey = "LegacyRealm::Legacy",
					name = "Legacy",
					realm = "LegacyRealm",
					level = 60,
					className = "Warrior",
					classFile = "WARRIOR",
					reputations = {
						["100"] = {
							factionKey = "100",
							factionID = 100,
							name = "Booty Bay",
							expansionKey = "classic",
							standingId = 6,
							currentValue = 3000,
							maxValue = 6000,
						},
					},
				},
			},
		}
		ns.InitDB()

		ctx.env.__player.professions = {
			prof1Index = 1,
			byIndex = {
				[1] = { name = "Mining", skillLevel = 80, maxSkillLevel = 100 },
			},
		}
		ns.SaveCharacterSnapshot(ns.BuildCurrentCharacterSnapshotBase("test"))

		local legacy = ns.GetCharacterByKey("LegacyRealm::Legacy")
		A.truthy(legacy)
		A.equal(legacy.name, "Legacy")
		A.equal(legacy.level, 60)
		A.equal(legacy.professions, nil)
		A.truthy(legacy.reputations["100"])
		A.equal(legacy.reputations["100"].name, "Booty Bay")
	end)

	runner:test("BuildCharacterHoverTooltipLines covers full data, partial, missing, and warband cases", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns

		local fullLines = ns.BuildCharacterHoverTooltipLines({
			characterName = "Takamori",
			realm = "Area 52",
			level = 90,
			className = "Paladin",
			classFile = "PALADIN",
			professions = {
				primary1 = { name = "Mining" },
				primary2 = { name = "Blacksmithing" },
			},
		})
		A.equal(#fullLines, 4)
		A.equal(fullLines[1].text, "Takamori - Area 52")
		A.equal(fullLines[2].text, "Level 90 Paladin")
		A.equal(fullLines[3].text, "Mining")
		A.equal(fullLines[4].text, "Blacksmithing")

		local oneProfession = ns.BuildCharacterHoverTooltipLines({
			characterName = "Solo",
			realm = "Area 52",
			level = 80,
			className = "Mage",
			classFile = "MAGE",
			professions = {
				primary1 = { name = "Tailoring" },
			},
		})
		A.equal(#oneProfession, 3)
		A.equal(oneProfession[3].text, "Tailoring")

		local emptyProfessions = ns.BuildCharacterHoverTooltipLines({
			characterName = "NoTrade",
			realm = "Area 52",
			level = 50,
			className = "Rogue",
			classFile = "ROGUE",
			professions = {},
		})
		A.equal(#emptyProfessions, 2)
		A.equal(emptyProfessions[2].text, "Level 50 Rogue")

		local needsCapture = ns.BuildCharacterHoverTooltipLines({
			characterName = "Legacy",
			realm = "Old",
			level = 60,
			className = "Warrior",
			classFile = "WARRIOR",
		})
		A.equal(#needsCapture, 2)
		A.equal(needsCapture[1].text, "Legacy - Old")
		A.equal(needsCapture[2].text, ns.TEXT.HOVER_NEEDS_CAPTURE)

		A.equal(ns.BuildCharacterHoverTooltipLines({ isAccountWide = true }), nil)
		A.equal(ns.BuildCharacterHoverTooltipLines(nil), nil)
	end)

	runner:test("SetFilterValue sanitizes status keys and invalidates cached views", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		ns.InitDB()

		local runtime = ns.RuntimeEnsure()
		runtime.currentPage = 4
		runtime.filteredSignature = "cached"
		runtime.filteredResults = { "cached" }
		runtime.visibleRows = { "cached" }
		runtime.visibleRowsDirty = false
		ns.SetFilterValue("statusKey", ns.FILTER_STATUS.FAVORITES)
		A.equal(ns.GetFilterValue("statusKey"), ns.FILTER_STATUS.FAVORITES)

		ns.SetFilterValue("statusKey", "invalid")
		A.equal(ns.GetFilterValue("statusKey"), ns.FILTER_STATUS.ALL)
		A.equal(ns.GetCurrentPage(), 0)
		A.truthy(runtime.resetListScroll)
		A.equal(runtime.filteredSignature, nil)
		A.equal(runtime.filteredResults, nil)
		A.equal(runtime.visibleRows, nil)
		A.truthy(runtime.visibleRowsDirty)
	end)

	runner:test("SetLiveUpdateOptions sanitizes values and notifies listeners on change", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		ns.InitDB()

		local notifications = {}
		ns.RegisterOptionsListener("state-test", function(sectionKey, value)
			notifications[#notifications + 1] = {
				sectionKey = sectionKey,
				value = value,
			}
		end)

		local changed = ns.SetLiveUpdateOptions({
			noLiveUpdates = false,
			updateAfterCombat = true,
			updatePeriodic = true,
			periodicMinutes = 0.4,
		})
		local options = ns.GetLiveUpdateOptions()
		A.truthy(changed)
		A.falsy(options.noLiveUpdates)
		A.truthy(options.updateAfterCombat)
		A.falsy(options.updateOutOfCombat)
		A.truthy(options.updatePeriodic)
		A.equal(options.periodicMinutes, ns.LIVE_UPDATE_PERIODIC_MINUTES_MIN)
		A.equal(#notifications, 1)
		A.equal(notifications[1].sectionKey, "liveUpdates")
		A.equal(notifications[1].value.periodicMinutes, ns.LIVE_UPDATE_PERIODIC_MINUTES_MIN)

		changed = ns.SetLiveUpdateOptions({
			noLiveUpdates = true,
			updateAfterCombat = true,
			updateOutOfCombat = true,
			updatePeriodic = true,
			periodicMinutes = 9999,
		})
		options = ns.GetLiveUpdateOptions()
		A.truthy(changed)
		A.truthy(options.noLiveUpdates)
		A.falsy(options.updateAfterCombat)
		A.falsy(options.updateOutOfCombat)
		A.falsy(options.updatePeriodic)
		A.equal(options.periodicMinutes, ns.LIVE_UPDATE_PERIODIC_MINUTES_MAX)

		changed = ns.SetLiveUpdateOptions({ noLiveUpdates = true })
		A.falsy(changed)
		A.equal(#notifications, 2)
	end)

	runner:test("ClearStoredReputationData wipes snapshots and resets runtime state", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		ns.InitDB()

		ctx.env.RepSheetDB.characters = {
			["A::One"] = { characterKey = "A::One" },
			["B::Two"] = { characterKey = "B::Two" },
		}
		ctx.env.RepSheetDB.ui.selectedFactionKey = "200"
		ns.PlayerState = {
			scanInProgress = true,
			pendingRefresh = { mode = "known" },
		}
		local runtime = ns.RuntimeEnsure()
		runtime.collapsedFactionKeys = { ["200"] = true }
		runtime.currentPage = 5

		local removed = ns.ClearStoredReputationData()

		A.equal(removed, 2)
		A.same(ctx.env.RepSheetDB.characters, {})
		A.equal(ctx.env.RepSheetDB.lastScanAt, 0)
		A.equal(ctx.env.RepSheetDB.lastScanCharacter, "")
		A.equal(ctx.env.RepSheetDB.ui.selectedFactionKey, nil)
		A.same(ns.PlayerState, {})
		A.same(runtime.collapsedFactionKeys, {})
		A.equal(runtime.currentPage, 0)
		A.truthy(runtime.resetListScroll)
		A.truthy(runtime.indexDirty)
	end)

	runner:test("GetSortedCharacters orders snapshots and backfills runtime reputation fields", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		ns.InitDB()

		ctx.env.RepSheetDB.characters = {
			["Beta::Zed"] = {
				characterKey = "Beta::Zed",
				name = "Zed",
				realm = "Beta",
				reputations = {
					["100"] = {
						factionKey = "100",
						factionID = 100,
						name = "Booty Bay",
						expansionKey = "classic",
						standingId = 5,
						currentValue = 1200,
						maxValue = 3000,
					},
				},
			},
			["Alpha::Aly"] = {
				characterKey = "Alpha::Aly",
				name = "Aly",
				realm = "Alpha",
				reputations = {},
			},
		}

		local characters = ns.GetSortedCharacters()
		A.equal(characters[1].characterKey, "Alpha::Aly")
		A.equal(characters[2].characterKey, "Beta::Zed")

		local rep = characters[2].reputations["100"]
		A.equal(rep.expansionName, "Classic / Vanilla")
		A.equal(rep.repTypeLabel, ns.TEXT.REPUTATION)
		A.equal(rep.icon, ns.FACTION_ICON)
		A.contains(rep.searchText, "booty bay")
	end)

	runner:test("Utility helpers format labels, colors, and expansion lookups correctly", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns

		A.equal(ns.GetAddonVersion(), "test-version")
		A.equal(ns.GetOptionLabel({ { key = "a", label = "A" } }, "missing", "Fallback"), "A")
		A.equal(ns.FormatLastSeen(0), ns.TEXT.NEVER)
		A.equal(ns.FormatPercent(0.556), "56%")
		A.equal(ns.FormatProgressValues(1234.4, 5678.8), "1234/5679")
		A.equal(ns.FormatStatusWithProgress("Honored", "1500/6000"), "Honored: 1500/6000")
		A.equal(ns.FormatStatusWithProgress("Renown: 5/10", "1500/2500"), "Renown: 5/10  1500/2500")
		A.equal(ns.PickTableField({ a = false, b = 2 }, "missing", "a", "b"), false)
		A.equal(ns.PickTableField(nil, "a"), nil)
		A.equal(ns.FormatDebugNameList({ "Zulu", "Alpha" }), "Alpha, Zulu")
		local previousNameLimit = ns.DEBUG_LOG_NAME_LIMIT
		ns.DEBUG_LOG_NAME_LIMIT = 2
		local truncatedNameList = ns.FormatDebugNameList({ "Zulu", "Alpha", "Beta" })
		ns.DEBUG_LOG_NAME_LIMIT = previousNameLimit
		A.equal(truncatedNameList, "Alpha, Beta, +1 more")
		A.equal(ns.TEXT.PROGRESS_BAR_TOOLTIP_OVERALL, "Orange: Overall progress toward finishing the reputation.")
		A.equal(ns.TEXT.PROGRESS_BAR_TOOLTIP_BAND, "Blue: Progress within the current rank or renown level.")
		A.equal(ns.StandingLabel(8), "Exalted")
		A.equal(ns.RepTypeLabel(ns.REP_TYPE.FRIENDSHIP, false, {}), ns.TEXT.FRIENDSHIP)
		A.equal(ns.RepTypeLabel(ns.REP_TYPE.MAJOR, true, { renownMaxLevel = 10 }), ns.TEXT.RENOWN .. ns.TEXT.PARAGON_SUFFIX)
		A.same({ ns.GetClassColor({ classFile = "MAGE" }) }, { 0.25, 0.78, 0.92 })
		A.same({ ns.GetClassColor({ classFile = "UNKNOWN" }) }, ns.FALLBACK_CLASS_COLOR)
		A.equal(ns.ResolveExpansionKeyFromHeader("The War Within"), "tww")
		A.equal(ns.ResolveExpansionKeyFromHeaders({ "Classic / Vanilla", "The War Within" }), "tww")
		A.equal(ns.ExpansionKeyFromGameExp(ctx.env.LE_EXPANSION_DRAGONFLIGHT), "df")
		A.truthy(ns.IsVisuallyMaxed(0.999))
	end)

	runner:test("Overlay and stored-entry math helpers reflect maxed and paragon state", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		local helpers = ns.NormalizerHelpers

		A.near(ns.GetBandOverlayFraction({ currentValue = 1200, maxValue = 3000 }), 0.4, 1e-6)
		A.equal(ns.GetBandOverlayFraction({ currentValue = 3000, maxValue = 3000, isMaxed = true }), 0)
		A.near(ns.GetParagonOverlayFraction({
			hasParagon = true,
			isMaxed = true,
			paragonValue = 500,
			paragonThreshold = 1000,
		}), 0.5, 1e-6)
		A.truthy(helpers.isEntryActuallyMaxed({
			repType = ns.REP_TYPE.MAJOR,
			renownLevel = 10,
			renownMaxLevel = 10,
		}))
		A.near(helpers.deriveEntryOverallFraction({
			repType = ns.REP_TYPE.FRIENDSHIP,
			friendCurrentRank = 3,
			friendMaxRank = 5,
			currentValue = 250,
			maxValue = 500,
		}), 0.5, 1e-6)
		A.near(helpers.deriveEntryRemainingFraction({
			repType = ns.REP_TYPE.STANDARD,
			standingId = 5,
			currentValue = 1500,
			maxValue = 3000,
		}), 0.5, 1e-6)
	end)

	runner:test("Debug log buffers lines, notifies listeners, and can be cleared", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		ns.LOCAL_DEV.ENABLE_DEBUG = true
		ns.DEBUG_LOG_MAX_LINES = 3

		local notified = {}
		ns.RegisterDebugListener("test", function(line, buffer)
			notified[#notified + 1] = {
				line = line,
				size = #buffer,
			}
		end)

		ns.DebugLog("one")
		ns.DebugLog("two")
		ns.DebugLog("three")
		ns.DebugLog("four")

		local lines = ns.GetDebugLogLines()
		A.equal(#lines, 3)
		A.contains(lines[1], "two")
		A.contains(ns.GetDebugLogText(), "four")
		A.contains(ns.GetLastDebugLine(), "four")
		A.equal(#notified, 4)

		ns.ClearDebugLog()
		A.equal(#ns.GetDebugLogLines(), 0)

		ns.UnregisterDebugListener("test")
		ns.DebugLog("five")
		A.equal(#notified, 5)
	end)

	runner:test("DebugNotify mirrors local developer messages to chat and the debug log", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		ns.LOCAL_DEV.ENABLE_DEBUG = true

		ns.DebugNotify("Rep update started: reason=Manual refresh mode=full")

		A.equal(#ctx.env.__chat_messages, 1)
		A.contains(ctx.env.__chat_messages[1], "Rep Sheet [DEV]")
		A.truthy(string.match(ctx.env.__chat_messages[1], "%d%d:%d%d:%d%d"))
		A.contains(ctx.env.__chat_messages[1], "Rep update started")
		A.contains(ns.GetLastDebugLine(), "Rep update started")
	end)

	runner:test("GetForgettableCharacters excludes the current character and stays sorted", function()
		local ctx = support.new_context(root, { files = DELETE_AND_UI_FILES })
		local ns = ctx.ns
		ns.InitDB()

		ctx.env.RepSheetDB.characters = {
			["TestRealm::Tester"] = support.make_snapshot(ns, {
				characterKey = "TestRealm::Tester",
				name = "Tester",
				realm = "TestRealm",
			}),
			["Alpha::Aly"] = support.make_snapshot(ns, {
				characterKey = "Alpha::Aly",
				name = "Aly",
				realm = "Alpha",
			}),
			["Beta::Zed"] = support.make_snapshot(ns, {
				characterKey = "Beta::Zed",
				name = "Zed",
				realm = "Beta",
			}),
		}

		local characters = ns.GetForgettableCharacters()
		A.equal(#characters, 2)
		A.equal(characters[1].characterKey, "Alpha::Aly")
		A.equal(characters[2].characterKey, "Beta::Zed")
	end)

	runner:test("DeleteCharacterSnapshot blocks unsafe deletions and recomputes last-scan metadata", function()
		local ctx = support.new_context(root, { files = DELETE_AND_UI_FILES })
		local ns = ctx.ns
		ns.InitDB()
		ns.LOCAL_DEV.ENABLE_DEBUG = true

		ctx.env.RepSheetDB.characters = {
			["TestRealm::Tester"] = support.make_snapshot(ns, {
				characterKey = "TestRealm::Tester",
				name = "Tester",
				realm = "TestRealm",
				lastScanAt = 100,
			}),
			["Alpha::Aly"] = support.make_snapshot(ns, {
				characterKey = "Alpha::Aly",
				name = "Aly",
				realm = "Alpha",
				lastScanAt = 200,
			}),
			["Beta::Zed"] = support.make_snapshot(ns, {
				characterKey = "Beta::Zed",
				name = "Zed",
				realm = "Beta",
				lastScanAt = 300,
			}),
		}

		local ok, reason = ns.DeleteCharacterSnapshot("")
		A.falsy(ok)
		A.equal(reason, "notFound")

		ok, reason = ns.DeleteCharacterSnapshot("TestRealm::Tester")
		A.falsy(ok)
		A.equal(reason, "currentCharacter")

		ns.PlayerState = { scanInProgress = true }
		ok, reason = ns.DeleteCharacterSnapshot("Alpha::Aly")
		A.falsy(ok)
		A.equal(reason, "scanBusy")

		ns.PlayerState = {}
		ok, reason = ns.DeleteCharacterSnapshot("Alpha::Aly")
		A.truthy(ok)
		A.equal(reason.characterKey, "Alpha::Aly")
		A.equal(ctx.env.RepSheetDB.lastScanAt, 300)
		A.equal(ctx.env.RepSheetDB.lastScanCharacter, "Beta::Zed")
		A.truthy(ns.RuntimeEnsure().indexDirty)
		A.contains(ns.GetLastDebugLine(), "Aly-Alpha")
	end)

	runner:test("OpenFactionInGameUI prefers renown APIs and falls back through reputation views", function()
		local ctx = support.new_context(root, { files = DELETE_AND_UI_FILES })
		local ns = ctx.ns
		local calls = {}

		ctx.env.C_MajorFactions.OpenRenown = function(faction_id)
			calls[#calls + 1] = "OpenRenown:" .. tostring(faction_id)
		end
		ns.OpenFactionInGameUI({
			repType = ns.REP_TYPE.MAJOR,
			majorFactionID = 2590,
			factionID = 2590,
		})
		A.same(calls, { "OpenRenown:2590" })

		calls = {}
		ctx.env.C_MajorFactions.OpenRenown = function()
			error("fail")
		end
		ctx.env.C_MajorFactions.OpenMajorFactionRenown = function(faction_id)
			calls[#calls + 1] = "OpenMajorFactionRenown:" .. tostring(faction_id)
		end
		ns.OpenFactionInGameUI({
			repType = ns.REP_TYPE.MAJOR,
			majorFactionID = 2600,
			factionID = 2600,
		})
		A.same(calls, { "OpenMajorFactionRenown:2600" })

		calls = {}
		ctx.env.C_MajorFactions.OpenMajorFactionRenown = function()
			error("fail")
		end
		ctx.env.C_Reputation.ToggleReputationUI = function()
			error("fail")
		end
		ctx.env.ToggleCharacter = function(view)
			calls[#calls + 1] = tostring(view)
			if view == "ReputationFrame" then
				error("fail")
			end
		end
		ns.OpenFactionInGameUI({
			repType = ns.REP_TYPE.STANDARD,
			factionID = 72,
		})
		A.same(calls, { "ReputationFrame", "4" })
	end)
end
