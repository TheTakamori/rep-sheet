AltRepTracker = AltRepTracker or {}
local ns = AltRepTracker
local state = ns.UI_MainFrameState
local layout = ns.UI_MAIN_LAYOUT
local rowLayout = ns.UI_FACTION_ROW_LAYOUT

local function syncDropdownText(dropdown, options, selectedKey, fallbackLabel)
	if not UIDropDownMenu_SetText then
		return
	end
	UIDropDownMenu_SetText(dropdown, ns.GetOptionLabel(options, selectedKey, fallbackLabel))
end

local function syncExpansionDropdown(dropdown, selectedKey)
	if not UIDropDownMenu_SetText then
		return
	end
	UIDropDownMenu_SetText(dropdown, ns.ExpansionLabelForKey(selectedKey or ns.ALL_EXPANSIONS_KEY))
end

local function filteredContainsFaction(results, factionKey)
	if not factionKey or factionKey == "" then
		return false
	end
	for index = 1, #results do
		if results[index].factionKey == factionKey then
			return true
		end
	end
	return false
end

local function clampFactionScroll(resetToTop)
	local main = state.main
	if not main or not main.listScroll then
		return
	end
	local scroll = main.listScroll
	local range = scroll:GetVerticalScrollRange() or 0
	local current = scroll:GetVerticalScroll() or 0
	if resetToTop then
		current = 0
	end
	scroll:SetVerticalScroll(ns.Clamp(current, 0, range))
end

function ns.UI_MainFrameFactionListMouseWheel(_, delta)
	local main = state.main
	if not main or not main.listScroll then
		return
	end
	local scroll = main.listScroll
	local step = ns.UI_LIST_ROW_HEIGHT * ns.UI_LIST_WHEEL_STEP_ROWS
	local current = scroll:GetVerticalScroll() or 0
	local range = scroll:GetVerticalScrollRange() or 0
	scroll:SetVerticalScroll(ns.Clamp(current - delta * step, 0, range))
end

local function ensureFactionRows(count)
	local main = state.main
	if not main or not main.listScrollChild then
		return
	end

	local rowFrames = state.rowFrames
	for index = #rowFrames + 1, count do
		rowFrames[index] = ns.UI_CreateFactionRow(main.listScrollChild, index, {
			rowHeight = ns.UI_LIST_ROW_HEIGHT,
			onClick = function(factionKey)
				local bucket = ns.GetFactionBucketByKey(factionKey)
				if bucket and bucket.childFactionKeys and #bucket.childFactionKeys > 0 and ns.GetSelectedFactionKey() == factionKey then
					ns.ToggleFactionCollapsed(factionKey)
					ns.RefreshMainFrame()
					return
				end
				ns.SetSelectedFactionKey(factionKey)
				ns.RefreshMainFrame()
			end,
			onToggleCollapse = function(factionKey)
				local collapsed = ns.ToggleFactionCollapsed(factionKey)
				local selectedKey = ns.GetSelectedFactionKey()
				if collapsed and selectedKey and ns.IsFactionDescendantOf(selectedKey, factionKey) then
					ns.SetSelectedFactionKey(factionKey)
				end
				ns.RefreshMainFrame()
			end,
			onFavoriteToggle = function(factionKey)
				ns.ToggleFavoriteFaction(factionKey)
				ns.RefreshMainFrame()
			end,
		})
	end
end

local function relayoutFactionRows(totalRows)
	local main = state.main
	if not main or not main.listScroll or not main.listScrollChild then
		return
	end

	local scrollWidth = main.listScroll:GetWidth()
	if not scrollWidth or scrollWidth <= 0 then
		scrollWidth = ns.UI_PANE_WIDTH - layout.LIST_SCROLL_LEFT + layout.LIST_SCROLL_RIGHT
	end
	local childWidth = math.max(ns.UI_LIST_MIN_WIDTH, scrollWidth)
	main.listScrollChild:SetWidth(childWidth)

	local scrollHeight = main.listScroll:GetHeight()
	if not scrollHeight or scrollHeight <= 0 then
		scrollHeight = ns.UI_LIST_SCROLL_FALLBACK_HEIGHT
	end
	local childHeight = math.max(scrollHeight, totalRows * ns.UI_LIST_ROW_HEIGHT + ns.UI_LIST_SCROLL_CHILD_EXTRA_HEIGHT)
	main.listScrollChild:SetHeight(childHeight)

	for index = 1, #state.rowFrames do
		local row = state.rowFrames[index]
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", main.listScrollChild, "TOPLEFT", ns.UI_LIST_CHILD_X, ns.UI_LIST_CHILD_Y - (index - 1) * ns.UI_LIST_ROW_HEIGHT)
		row:SetWidth(math.max(ns.UI_LIST_MIN_WIDTH, childWidth - rowLayout.OUTER_WIDTH_TRIM))
	end
end

function ns.RefreshMainFrame()
	local main = state.main
	if not main then
		return
	end

	local runtime = ns.RuntimeEnsure()
	local filters = ns.GetFilters()
	local filtered, totalCharacters = ns.GetFilteredFactionResults()
	local visibleRows = ns.GetVisibleFactionRows()
	local total = #filtered

	local selectedKey = ns.GetSelectedFactionKey()
	if not filteredContainsFaction(visibleRows, selectedKey) then
		selectedKey = visibleRows[1] and visibleRows[1].factionKey or nil
		ns.SetSelectedFactionKey(selectedKey)
	end

	if main.expansionDrop then
		syncExpansionDropdown(main.expansionDrop, filters.expansionKey or ns.ALL_EXPANSIONS_KEY)
	end
	if main.sortDrop then
		syncDropdownText(main.sortDrop, ns.SORT_OPTIONS, filters.sortKey)
	end
	if main.statusDrop then
		syncDropdownText(main.statusDrop, ns.FILTER_STATUS_OPTIONS, filters.statusKey)
	end
	if main.searchBox and not state.ignoreSearchEvents then
		local uiText = main.searchBox:GetText() or ""
		if uiText ~= (filters.searchText or "") then
			state.ignoreSearchEvents = true
			main.searchBox:SetText(filters.searchText or "")
			state.ignoreSearchEvents = false
		end
	end

	ensureFactionRows(#visibleRows)
	relayoutFactionRows(#visibleRows)

	for index = 1, #state.rowFrames do
		local row = state.rowFrames[index]
		local bucket = visibleRows[index]
		ns.UI_ApplyFactionRow(row, bucket, bucket and bucket.factionKey == selectedKey)
	end

	if total <= 0 then
		main.countLabel:SetText(string.format(ns.FORMAT.COUNT_EMPTY, totalCharacters or 0))
	else
		main.countLabel:SetText(string.format(ns.FORMAT.COUNT_RESULTS, total, totalCharacters or 0))
	end

	local selectedBucket = selectedKey and ns.GetFactionBucketByKey(selectedKey) or nil
	main.characterPane:SetFaction(selectedBucket)

	local db = ns.GetDB()
	local lastScanLabel = db.lastScanAt and db.lastScanAt > 0 and ns.FormatLastSeen(db.lastScanAt) or ns.TEXT.NEVER
	local scanSource = db.lastScanCharacter ~= "" and (ns.GetCharacterByKey(db.lastScanCharacter) and ns.FormatCharacterName(ns.GetCharacterByKey(db.lastScanCharacter)) or db.lastScanCharacter)
		or ns.TEXT.UNKNOWN
	main.statusLabel:SetText(string.format(ns.FORMAT.STATUS_FOOTER, lastScanLabel, scanSource))

	if main.debugPane and main.debugPane:IsShown() and main.debugPane.Refresh then
		main.debugPane:Refresh()
	end

	clampFactionScroll(runtime.resetListScroll == true)
	runtime.resetListScroll = false
end
