RepSheet = RepSheet or {}
local ns = RepSheet

RepSheetDB = RepSheetDB or {}

local function ensureTable(tbl, key)
	if type(tbl[key]) ~= "table" then
		tbl[key] = {}
	end
	return tbl[key]
end

local function resetStoredReputationSnapshots(db)
	db.characters = {}
	db.lastScanAt = 0
	db.lastScanCharacter = ""
end

local function sanitizeStatusKey(statusKey)
	statusKey = ns.SafeString(statusKey, ns.FILTER_STATUS.ALL)
	if statusKey ~= ns.FILTER_STATUS.ALL
		and statusKey ~= ns.FILTER_STATUS.FAVORITES
		and statusKey ~= ns.FILTER_STATUS.MAXED then
		return ns.FILTER_STATUS.ALL
	end
	return statusKey
end

local function sanitizeViewMode(viewMode)
	viewMode = ns.SafeString(viewMode, ns.VIEW_MODE.FACTIONS)
	if viewMode ~= ns.VIEW_MODE.FACTIONS and viewMode ~= ns.VIEW_MODE.ALTS then
		return ns.VIEW_MODE.FACTIONS
	end
	return viewMode
end

local function sanitizeAltFactionFilter(value)
	value = ns.SafeString(value, ns.ALT_FACTION_FILTER.ALL)
	if value ~= ns.ALT_FACTION_FILTER.ALL
		and value ~= ns.ALT_FACTION_FILTER.ALLIANCE
		and value ~= ns.ALT_FACTION_FILTER.HORDE
		and value ~= ns.ALT_FACTION_FILTER.NEUTRAL then
		return ns.ALT_FACTION_FILTER.ALL
	end
	return value
end

local function sanitizeAltSortKey(value)
	value = ns.SafeString(value, ns.ALT_SORT_KEY.NAME)
	if value ~= ns.ALT_SORT_KEY.NAME
		and value ~= ns.ALT_SORT_KEY.LEVEL_DESC
		and value ~= ns.ALT_SORT_KEY.CLASS
		and value ~= ns.ALT_SORT_KEY.LAST_SCAN_DESC then
		return ns.ALT_SORT_KEY.NAME
	end
	return value
end

local function sanitizeAltFilters(filters)
	filters = type(filters) == "table" and filters or {}
	return {
		searchText = ns.SafeString(filters.searchText),
		factionGroup = sanitizeAltFactionFilter(filters.factionGroup),
		classFile = ns.SafeString(filters.classFile, ns.ALL_ALT_FILTER_KEY),
		raceFile = ns.SafeString(filters.raceFile, ns.ALL_ALT_FILTER_KEY),
		professionName = ns.SafeString(filters.professionName, ns.ALL_ALT_FILTER_KEY),
		sortKey = sanitizeAltSortKey(filters.sortKey),
	}
end

local function sanitizeAltRepSortKey(value)
	value = ns.SafeString(value, ns.ALT_REP_SORT_KEY.NAME)
	if value ~= ns.ALT_REP_SORT_KEY.NAME and value ~= ns.ALT_REP_SORT_KEY.LEVEL_DESC then
		return ns.ALT_REP_SORT_KEY.NAME
	end
	return value
end

local function sanitizeAltRepFilters(filters)
	filters = type(filters) == "table" and filters or {}
	return {
		expansionKey = ns.SafeString(filters.expansionKey, ns.ALL_EXPANSIONS_KEY),
		sortKey = sanitizeAltRepSortKey(filters.sortKey),
	}
end

local function sanitizeLiveUpdateOptions(options)
	options = type(options) == "table" and options or {}

	local periodicMinutes = math.floor(ns.SafeNumber(
		options.periodicMinutes,
		ns.LIVE_UPDATE_PERIODIC_MINUTES_DEFAULT
	))
	periodicMinutes = math.max(ns.LIVE_UPDATE_PERIODIC_MINUTES_MIN, periodicMinutes)
	periodicMinutes = math.min(ns.LIVE_UPDATE_PERIODIC_MINUTES_MAX, periodicMinutes)

	local sanitized = {
		noLiveUpdates = options.noLiveUpdates ~= false,
		updateAfterCombat = options.updateAfterCombat == true,
		updateOutOfCombat = options.updateOutOfCombat == true,
		updatePeriodic = options.updatePeriodic == true,
		periodicMinutes = periodicMinutes,
	}

	if sanitized.noLiveUpdates then
		sanitized.updateAfterCombat = false
		sanitized.updateOutOfCombat = false
		sanitized.updatePeriodic = false
	elseif sanitized.updateAfterCombat ~= true
		and sanitized.updateOutOfCombat ~= true
		and sanitized.updatePeriodic ~= true
	then
		sanitized.noLiveUpdates = true
	end

	return sanitized
end

local function copyTable(source)
	local out = {}
	for key, value in pairs(source or {}) do
		out[key] = value
	end
	return out
end

local function sameFlatTable(left, right)
	for key, value in pairs(left or {}) do
		if right[key] ~= value then
			return false
		end
	end
	for key, value in pairs(right or {}) do
		if left[key] ~= value then
			return false
		end
	end
	return true
end

local function sortedKeys(tbl)
	local keys = {}
	for key in pairs(tbl or {}) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(left, right)
		return tostring(left) < tostring(right)
	end)
	return keys
end

local function notifyOptionsListeners(sectionKey, value)
	local runtime = ns.RuntimeEnsure()
	local listeners = runtime.optionsListeners or {}
	for _, listenerKey in ipairs(sortedKeys(listeners)) do
		local callback = listeners[listenerKey]
		if type(callback) == "function" then
			callback(sectionKey, value)
		end
	end
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
	runtime.optionsListeners = type(runtime.optionsListeners) == "table" and runtime.optionsListeners or {}
	if runtime.visibleRowsDirty == nil then
		runtime.visibleRowsDirty = true
	end
	return runtime
end

function ns.GetDB()
	return RepSheetDB
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

function ns.InvalidateAltResults()
	local runtime = ns.RuntimeEnsure()
	runtime.altResultsSignature = nil
	runtime.altResults = nil
	runtime.altResultsTotal = nil
end

function ns.InvalidateAltRepResults()
	local runtime = ns.RuntimeEnsure()
	runtime.altRepResultsSignature = nil
	runtime.altRepResults = nil
	runtime.altRepResultsTotal = nil
end

function ns.MarkIndexDirty()
	local runtime = ns.RuntimeEnsure()
	runtime.indexDirty = true
	runtime.index = nil
	runtime.altsIndex = nil
	runtime.altsIndexDirty = true
	ns.InvalidateFilteredResults()
	ns.InvalidateAltResults()
	ns.InvalidateAltRepResults()
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
	local db = RepSheetDB
	local storedVersion = ns.SafeNumber(db.version, 0)
	if storedVersion ~= ns.DB_SCHEMA_VERSION then
		resetStoredReputationSnapshots(db)
	end
	db.version = ns.DB_SCHEMA_VERSION
	ensureTable(db, "characters")
	ensureTable(db, "favorites")
	local ui = ensureTable(db, "ui")
	local filters = ensureTable(db, "filters")
	local options = ensureTable(db, "options")
	local defaultFramePosition = ns.DEFAULT_MAIN_FRAME_POSITION

	ui.selectedFactionKey = ui.selectedFactionKey or nil
	ui.selectedCharacterKey = ui.selectedCharacterKey or nil
	ui.rightViewMode = sanitizeViewMode(ui.rightViewMode)
	ui.mainFrame = ui.mainFrame or {
		point = defaultFramePosition.point,
		relativePoint = defaultFramePosition.relativePoint,
		x = defaultFramePosition.x,
		y = defaultFramePosition.y,
	}
	ui.minimapButton = type(ui.minimapButton) == "table" and ui.minimapButton or {}
	ui.minimapButton.angle = ns.SafeNumber(ui.minimapButton.angle, ns.DEFAULT_MINIMAP_BUTTON_ANGLE)

	filters.searchText = ns.SafeString(filters.searchText)
	filters.expansionKey = ns.SafeString(filters.expansionKey, ns.ALL_EXPANSIONS_KEY)
	filters.sortKey = ns.SafeString(filters.sortKey, ns.SORT_KEY.BEST_PROGRESS)
	filters.statusKey = sanitizeStatusKey(filters.statusKey)
	filters.leftViewMode = sanitizeViewMode(filters.leftViewMode)
	filters.alts = sanitizeAltFilters(filters.alts)
	filters.altRep = sanitizeAltRepFilters(filters.altRep)
	options.liveUpdates = sanitizeLiveUpdateOptions(options.liveUpdates)

	db.lastScanAt = ns.SafeNumber(db.lastScanAt, 0)
	db.lastScanCharacter = ns.SafeString(db.lastScanCharacter)

	ns.RuntimeEnsure()
	ns.MarkIndexDirty()
end

function ns.ClearStoredReputationData()
	local db = RepSheetDB
	local clearedCharacters = ns.CountTable(db and db.characters)
	local ui = ensureTable(db, "ui")

	db.characters = {}
	db.lastScanAt = 0
	db.lastScanCharacter = ""
	ui.selectedFactionKey = nil
	ui.selectedCharacterKey = nil
	ui.rightViewMode = ns.VIEW_MODE.FACTIONS

	local runtime = ns.RuntimeEnsure()
	runtime.collapsedFactionKeys = {}
	runtime.currentPage = 0
	runtime.resetListScroll = true

	ns.PlayerState = {}

	ns.MarkIndexDirty()
	return clearedCharacters
end

function ns.GetFilters()
	return RepSheetDB.filters
end

function ns.GetFilterValue(key)
	local filters = ns.GetFilters()
	return filters and filters[key]
end

function ns.SetFilterValue(key, value)
	local filters = ns.GetFilters()
	if key == "statusKey" then
		value = sanitizeStatusKey(value)
	end
	if not filters or filters[key] == value then
		return
	end
	filters[key] = value
	ns.ResetMainPage()
	ns.RuntimeEnsure().resetListScroll = true
	ns.InvalidateFilteredResults()
end

function ns.GetSelectedFactionKey()
	local ui = RepSheetDB.ui
	return ui and ui.selectedFactionKey or nil
end

function ns.SetSelectedFactionKey(factionKey)
	RepSheetDB.ui.selectedFactionKey = factionKey
end

function ns.GetSelectedCharacterKey()
	local ui = RepSheetDB.ui
	return ui and ui.selectedCharacterKey or nil
end

function ns.SetSelectedCharacterKey(characterKey)
	RepSheetDB.ui.selectedCharacterKey = characterKey
end

function ns.GetLeftViewMode()
	local filters = RepSheetDB.filters
	return sanitizeViewMode(filters and filters.leftViewMode)
end

function ns.SetLeftViewMode(viewMode)
	local filters = ensureTable(RepSheetDB, "filters")
	local sanitized = sanitizeViewMode(viewMode)
	if filters.leftViewMode == sanitized then
		return false
	end
	filters.leftViewMode = sanitized
	ns.RuntimeEnsure().resetListScroll = true
	return true
end

function ns.GetRightViewMode()
	local ui = RepSheetDB.ui
	return sanitizeViewMode(ui and ui.rightViewMode)
end

function ns.SelectFaction(factionKey)
	local ui = ensureTable(RepSheetDB, "ui")
	ui.selectedFactionKey = factionKey
	ui.rightViewMode = ns.VIEW_MODE.FACTIONS
end

function ns.SelectCharacter(characterKey)
	local ui = ensureTable(RepSheetDB, "ui")
	ui.selectedCharacterKey = characterKey
	ui.rightViewMode = ns.VIEW_MODE.ALTS
end

function ns.GetAltFilters()
	local filters = ensureTable(RepSheetDB, "filters")
	filters.alts = sanitizeAltFilters(filters.alts)
	return filters.alts
end

function ns.GetAltFilterValue(key)
	local altFilters = ns.GetAltFilters()
	return altFilters and altFilters[key]
end

function ns.SetAltFilterValue(key, value)
	local altFilters = ns.GetAltFilters()
	if not altFilters then
		return
	end

	if key == "factionGroup" then
		value = sanitizeAltFactionFilter(value)
	elseif key == "sortKey" then
		value = sanitizeAltSortKey(value)
	elseif key == "searchText" then
		value = ns.SafeString(value)
	elseif key == "classFile" or key == "raceFile" or key == "professionName" then
		value = ns.SafeString(value, ns.ALL_ALT_FILTER_KEY)
	end

	if altFilters[key] == value then
		return
	end
	altFilters[key] = value
	ns.RuntimeEnsure().resetListScroll = true
	ns.InvalidateAltResults()
end

function ns.GetAltRepFilters()
	local filters = ensureTable(RepSheetDB, "filters")
	filters.altRep = sanitizeAltRepFilters(filters.altRep)
	return filters.altRep
end

function ns.GetAltRepFilterValue(key)
	local altRepFilters = ns.GetAltRepFilters()
	return altRepFilters and altRepFilters[key]
end

function ns.SetAltRepFilterValue(key, value)
	local altRepFilters = ns.GetAltRepFilters()
	if not altRepFilters then
		return
	end

	if key == "sortKey" then
		value = sanitizeAltRepSortKey(value)
	elseif key == "expansionKey" then
		value = ns.SafeString(value, ns.ALL_EXPANSIONS_KEY)
	end

	if altRepFilters[key] == value then
		return
	end
	altRepFilters[key] = value
	ns.InvalidateAltRepResults()
end

function ns.GetMinimapButtonAngle()
	local ui = RepSheetDB.ui
	local minimapButton = ui and ui.minimapButton
	return ns.SafeNumber(minimapButton and minimapButton.angle, ns.DEFAULT_MINIMAP_BUTTON_ANGLE)
end

function ns.GetOptions()
	local db = ns.GetDB()
	return db and db.options or nil
end

function ns.GetLiveUpdateOptions()
	local options = ns.GetOptions()
	return copyTable(sanitizeLiveUpdateOptions(options and options.liveUpdates))
end

function ns.SetLiveUpdateOptions(nextOptions)
	local options = ensureTable(RepSheetDB, "options")
	local current = sanitizeLiveUpdateOptions(options.liveUpdates)
	local merged = copyTable(current)

	for key, value in pairs(type(nextOptions) == "table" and nextOptions or {}) do
		merged[key] = value
	end

	local sanitized = sanitizeLiveUpdateOptions(merged)
	if sameFlatTable(current, sanitized) then
		return false
	end

	options.liveUpdates = sanitized
	notifyOptionsListeners("liveUpdates", copyTable(sanitized))
	return true
end

function ns.RegisterOptionsListener(listenerKey, callback)
	listenerKey = ns.SafeString(listenerKey)
	if listenerKey == "" or type(callback) ~= "function" then
		return false
	end
	ns.RuntimeEnsure().optionsListeners[listenerKey] = callback
	return true
end

function ns.UnregisterOptionsListener(listenerKey)
	listenerKey = ns.SafeString(listenerKey)
	if listenerKey == "" then
		return false
	end
	local listeners = ns.RuntimeEnsure().optionsListeners
	if listeners[listenerKey] == nil then
		return false
	end
	listeners[listenerKey] = nil
	return true
end

function ns.SetMinimapButtonAngle(angle)
	local ui = ensureTable(RepSheetDB, "ui")
	local minimapButton = ensureTable(ui, "minimapButton")
	minimapButton.angle = ns.SafeNumber(angle, ns.DEFAULT_MINIMAP_BUTTON_ANGLE)
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
	return RepSheetDB.favorites[tostring(factionKey)] == true
end

function ns.ToggleFavoriteFaction(factionKey)
	local key = tostring(factionKey or "")
	if key == "" then
		return false
	end
	local favorites = RepSheetDB.favorites
	if favorites[key] then
		favorites[key] = nil
		ns.InvalidateFilteredResults()
		return false
	end
	favorites[key] = true
	ns.InvalidateFilteredResults()
	return true
end
