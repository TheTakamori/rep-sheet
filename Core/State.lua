AltRepTracker = AltRepTracker or {}
local ns = AltRepTracker

AltRepTrackerDB = AltRepTrackerDB or {}

local function ensureTable(tbl, key)
	if type(tbl[key]) ~= "table" then
		tbl[key] = {}
	end
	return tbl[key]
end

local function playerNameAndRealm()
	local name, realm = nil, nil
	if UnitFullName then
		name, realm = UnitFullName("player")
	end
	if not name or name == "" then
		name = UnitName and UnitName("player") or ns.TEXT.UNKNOWN
	end
	if not realm or realm == "" then
		realm = GetRealmName and GetRealmName() or ""
	end
	return ns.NormalizeText(name), ns.NormalizeText(realm)
end

function ns.PlayerStateEnsure()
	local state = ns.PlayerState or {}
	ns.PlayerState = state
	return state
end

function ns.RuntimeEnsure()
	local runtime = ns.Runtime or {}
	ns.Runtime = runtime
	if runtime.indexDirty == nil then
		runtime.indexDirty = true
	end
	if runtime.resetListScroll == nil then
		runtime.resetListScroll = false
	end
	runtime.collapsedFactionKeys = runtime.collapsedFactionKeys or {}
	runtime.currentPage = runtime.currentPage or 0
	runtime.selectedFactionKey = runtime.selectedFactionKey or nil
	return runtime
end

function ns.GetDB()
	return AltRepTrackerDB
end

function ns.InvalidateFilteredResults()
	local runtime = ns.RuntimeEnsure()
	runtime.filteredSignature = nil
	runtime.filteredResults = nil
end

function ns.MarkIndexDirty()
	local runtime = ns.RuntimeEnsure()
	runtime.indexDirty = true
	runtime.index = nil
	ns.InvalidateFilteredResults()
end

function ns.ResetMainPage()
	ns.RuntimeEnsure().currentPage = 0
end

function ns.GetCurrentPage()
	return ns.RuntimeEnsure().currentPage or 0
end

function ns.SetCurrentPage(page)
	ns.RuntimeEnsure().currentPage = math.max(0, ns.SafeNumber(page, 0))
end

function ns.InitDB()
	local db = AltRepTrackerDB
	db.version = ns.DB_SCHEMA_VERSION
	ensureTable(db, "characters")
	ensureTable(db, "favorites")
	local ui = ensureTable(db, "ui")
	local filters = ensureTable(db, "filters")
	local defaultFramePosition = ns.DEFAULT_MAIN_FRAME_POSITION

	ui.selectedFactionKey = ui.selectedFactionKey or nil
	ui.mainFrame = ui.mainFrame or {
		point = defaultFramePosition.point,
		relativePoint = defaultFramePosition.relativePoint,
		x = defaultFramePosition.x,
		y = defaultFramePosition.y,
	}

	filters.searchText = ns.SafeString(filters.searchText)
	filters.expansionKey = ns.SafeString(filters.expansionKey, ns.ALL_EXPANSIONS_KEY)
	filters.sortKey = ns.SafeString(filters.sortKey, ns.SORT_KEY.BEST_PROGRESS)
	filters.statusKey = ns.SafeString(filters.statusKey, ns.FILTER_STATUS.ALL)

	db.lastScanAt = ns.SafeNumber(db.lastScanAt, 0)
	db.lastScanCharacter = ns.SafeString(db.lastScanCharacter)

	local runtime = ns.RuntimeEnsure()
	runtime.selectedFactionKey = runtime.selectedFactionKey or ui.selectedFactionKey
	ns.MarkIndexDirty()
end

function ns.ClearStoredReputationData()
	local db = AltRepTrackerDB
	local clearedCharacters = ns.CountTable(db and db.characters)
	local ui = ensureTable(db, "ui")

	db.characters = {}
	db.lastScanAt = 0
	db.lastScanCharacter = ""
	ui.selectedFactionKey = nil

	local runtime = ns.RuntimeEnsure()
	runtime.selectedFactionKey = nil
	runtime.collapsedFactionKeys = {}
	runtime.currentPage = 0
	runtime.resetListScroll = true

	ns.PlayerState = {}

	ns.MarkIndexDirty()
	return clearedCharacters
end

function ns.GetFilters()
	return AltRepTrackerDB.filters
end

function ns.GetFilterValue(key)
	local filters = ns.GetFilters()
	return filters and filters[key]
end

function ns.SetFilterValue(key, value)
	local filters = ns.GetFilters()
	if not filters or filters[key] == value then
		return
	end
	filters[key] = value
	ns.ResetMainPage()
	ns.RuntimeEnsure().resetListScroll = true
	ns.InvalidateFilteredResults()
end

function ns.MakeCharacterKey(name, realm)
	return string.format("%s::%s", ns.NormalizeText(realm), ns.NormalizeText(name))
end

function ns.GetCurrentCharacterKey()
	local name, realm = playerNameAndRealm()
	return ns.MakeCharacterKey(name, realm)
end

function ns.BuildCurrentCharacterMeta()
	local name, realm = playerNameAndRealm()
	local localizedClass, classFile, classID = nil, nil, nil
	if UnitClass then
		localizedClass, classFile, classID = UnitClass("player")
	end
	local raceName, raceFile, raceID = nil, nil, nil
	if UnitRace then
		raceName, raceFile, raceID = UnitRace("player")
	end
	local factionName = nil
	if UnitFactionGroup then
		factionName = select(1, UnitFactionGroup("player"))
	end
	return {
		characterKey = ns.MakeCharacterKey(name, realm),
		name = name,
		realm = realm,
		className = localizedClass,
		classFile = classFile,
		classID = classID,
		raceName = raceName,
		raceFile = raceFile,
		raceID = raceID,
		factionName = factionName,
		level = UnitLevel and UnitLevel("player") or 0,
		guid = UnitGUID and UnitGUID("player") or nil,
		lastKnownZone = GetRealZoneText and GetRealZoneText() or "",
	}
end

function ns.BuildCurrentCharacterSnapshotBase(reason)
	local snapshot = ns.BuildCurrentCharacterMeta()
	snapshot.lastScanAt = ns.SafeTime()
	snapshot.lastScanReason = ns.SafeString(reason)
	snapshot.reputations = {}
	snapshot.scanNotes = {}
	return snapshot
end

local function countSnapshotReputations(snapshot)
	if type(snapshot) ~= "table" or type(snapshot.reputations) ~= "table" then
		return 0
	end
	return ns.CountTable(snapshot.reputations)
end

local function preserveMissingReputations(snapshot, previous, previousBestCount)
	if type(snapshot) ~= "table" or type(previous) ~= "table" then
		return
	end

	local currentReputations = type(snapshot.reputations) == "table" and snapshot.reputations or {}
	local previousReputations = type(previous.reputations) == "table" and previous.reputations or nil
	local currentCount = ns.CountTable(currentReputations)
	local previousStoredCount = countSnapshotReputations(previous)

	if type(previousReputations) ~= "table" or currentCount >= previousBestCount or previousStoredCount <= 0 then
		snapshot.reputationCount = currentCount
		return
	end

	local mergedReputations = {}
	for factionKey, reputation in pairs(currentReputations) do
		mergedReputations[factionKey] = reputation
	end

	local preservedCount = 0
	for factionKey, reputation in pairs(previousReputations) do
		if not mergedReputations[factionKey] then
			mergedReputations[factionKey] = reputation
			preservedCount = preservedCount + 1
		end
	end

	if preservedCount <= 0 then
		snapshot.reputationCount = currentCount
		return
	end

	snapshot.reputations = mergedReputations
	snapshot.reputationCount = ns.CountTable(mergedReputations)
	snapshot.scanNotes = type(snapshot.scanNotes) == "table" and snapshot.scanNotes or {}
	snapshot.scanNotes.partialMerge = string.format(
		"Preserved %d missing reputations from prior snapshot.",
		preservedCount
	)

	ns.DebugLog(string.format(
		"Preserved missing reputations: reason=%s current=%s previousStored=%s previousBest=%s kept=%s merged=%s",
		ns.DebugValueText(snapshot.lastScanReason),
		ns.DebugValueText(currentCount),
		ns.DebugValueText(previousStoredCount),
		ns.DebugValueText(previousBestCount),
		ns.DebugValueText(preservedCount),
		ns.DebugValueText(snapshot.reputationCount)
	))
end

function ns.SaveCharacterSnapshot(snapshot)
	if type(snapshot) ~= "table" or not snapshot.characterKey or snapshot.characterKey == "" then
		return
	end
	local db = AltRepTrackerDB
	local previous = db.characters[snapshot.characterKey]
	local previousBestCount = 0
	if type(previous) == "table" then
		previousBestCount = math.max(
			ns.SafeNumber(previous.bestKnownReputationCount, 0),
			ns.SafeNumber(previous.reputationCount, 0)
		)
	end

	snapshot.lastScanAt = ns.SafeNumber(snapshot.lastScanAt, ns.SafeTime())
	preserveMissingReputations(snapshot, previous, previousBestCount)
	local currentCount = ns.SafeNumber(snapshot.reputationCount, 0)
	if currentCount >= previousBestCount then
		snapshot.bestKnownReputationCount = currentCount
		snapshot.bestKnownReputationAt = snapshot.lastScanAt
		snapshot.bestKnownReputationReason = snapshot.lastScanReason
	else
		snapshot.bestKnownReputationCount = previousBestCount
		snapshot.bestKnownReputationAt = ns.SafeNumber(previous and previous.bestKnownReputationAt, ns.SafeNumber(previous and previous.lastScanAt, 0))
		snapshot.bestKnownReputationReason = ns.SafeString(
			previous and previous.bestKnownReputationReason,
			ns.SafeString(previous and previous.lastScanReason)
		)
	end

	db.characters[snapshot.characterKey] = snapshot
	db.lastScanAt = snapshot.lastScanAt
	db.lastScanCharacter = snapshot.characterKey
	ns.MarkIndexDirty()
end

function ns.GetCharacters()
	return AltRepTrackerDB.characters
end

function ns.GetCharacterByKey(characterKey)
	return AltRepTrackerDB.characters and AltRepTrackerDB.characters[characterKey] or nil
end

function ns.GetSortedCharacters()
	local out = {}
	local characters = ns.GetCharacters()
	for _, character in pairs(characters) do
		out[#out + 1] = character
	end
	table.sort(out, function(a, b)
		local realmA = ns.NormalizeSearchText(a.realm)
		local realmB = ns.NormalizeSearchText(b.realm)
		if realmA ~= realmB then
			return realmA < realmB
		end
		return ns.NormalizeSearchText(a.name) < ns.NormalizeSearchText(b.name)
	end)
	return out
end

function ns.GetSelectedFactionKey()
	local runtime = ns.RuntimeEnsure()
	if runtime.selectedFactionKey and runtime.selectedFactionKey ~= "" then
		return runtime.selectedFactionKey
	end
	local ui = AltRepTrackerDB.ui
	return ui and ui.selectedFactionKey or nil
end

function ns.SetSelectedFactionKey(factionKey)
	local runtime = ns.RuntimeEnsure()
	runtime.selectedFactionKey = factionKey
	AltRepTrackerDB.ui.selectedFactionKey = factionKey
end

function ns.IsFactionCollapsed(factionKey)
	factionKey = tostring(factionKey or "")
	if factionKey == "" then
		return false
	end
	return ns.RuntimeEnsure().collapsedFactionKeys[factionKey] == true
end

function ns.SetFactionCollapsed(factionKey, collapsed)
	factionKey = tostring(factionKey or "")
	if factionKey == "" then
		return
	end
	local collapsedFactionKeys = ns.RuntimeEnsure().collapsedFactionKeys
	if collapsed then
		collapsedFactionKeys[factionKey] = true
	else
		collapsedFactionKeys[factionKey] = nil
	end
end

function ns.ToggleFactionCollapsed(factionKey)
	local collapsed = ns.IsFactionCollapsed(factionKey)
	ns.SetFactionCollapsed(factionKey, not collapsed)
	return not collapsed
end

function ns.IsFavoriteFaction(factionKey)
	return AltRepTrackerDB.favorites[tostring(factionKey)] == true
end

function ns.ToggleFavoriteFaction(factionKey)
	local key = tostring(factionKey or "")
	if key == "" then
		return false
	end
	local favorites = AltRepTrackerDB.favorites
	if favorites[key] then
		favorites[key] = nil
		ns.InvalidateFilteredResults()
		return false
	end
	favorites[key] = true
	ns.InvalidateFilteredResults()
	return true
end
