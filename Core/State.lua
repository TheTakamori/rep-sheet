AltRepTracker = AltRepTracker or {}
local ns = AltRepTracker

AltRepTrackerDB = AltRepTrackerDB or {}

local function ensureTable(tbl, key)
	if type(tbl[key]) ~= "table" then
		tbl[key] = {}
	end
	return tbl[key]
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
	if runtime.visibleRowsDirty == nil then
		runtime.visibleRowsDirty = true
	end
	return runtime
end

function ns.GetDB()
	return AltRepTrackerDB
end

function ns.InvalidateVisibleRows()
	local runtime = ns.RuntimeEnsure()
	runtime.visibleRows = nil
	runtime.visibleRowsDirty = true
end

function ns.InvalidateFilteredResults()
	local runtime = ns.RuntimeEnsure()
	runtime.filteredSignature = nil
	runtime.filteredResults = nil
	runtime.filteredTotalCharacters = nil
	ns.InvalidateVisibleRows()
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

	ns.RuntimeEnsure()
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

function ns.GetSelectedFactionKey()
	local ui = AltRepTrackerDB.ui
	return ui and ui.selectedFactionKey or nil
end

function ns.SetSelectedFactionKey(factionKey)
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
	ns.InvalidateVisibleRows()
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
