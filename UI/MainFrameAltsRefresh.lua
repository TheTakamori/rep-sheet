RepSheet = RepSheet or {}
local ns = RepSheet
local listLayout = ns.UI_ALTS_LEFT_LAYOUT
local rowLayout = ns.UI_ALTS_LIST_ROW_LAYOUT

local widgets = ns.UIWidgets

local function syncDropdownText(dropdown, options, selectedKey, fallbackLabel)
	widgets.SetDropdownText(dropdown, ns.GetOptionLabel(options, selectedKey, fallbackLabel))
end

local function clampAltsScroll(altsLeftPane, resetToTop)
	local scroll = altsLeftPane and altsLeftPane.listScroll
	if not scroll then
		return
	end
	local range = scroll:GetVerticalScrollRange() or 0
	local current = scroll:GetVerticalScroll() or 0
	if resetToTop then
		current = 0
	end
	scroll:SetVerticalScroll(ns.Clamp(current, 0, range))
end

local function ensureAltsRows(altsLeftPane, count)
	local rowFrames = altsLeftPane.rowFrames
	for index = #rowFrames + 1, count do
		rowFrames[index] = ns.UI_CreateAltsListRow(altsLeftPane.listScrollChild, index, {
			onClick = function(characterKey)
				ns.SelectCharacter(characterKey)
				ns.RefreshMainFrame()
			end,
		})
	end
end

local function relayoutAltsRows(altsLeftPane, totalRows)
	local scroll = altsLeftPane.listScroll
	local scrollChild = altsLeftPane.listScrollChild
	if not scroll or not scrollChild then
		return
	end

	local scrollWidth = scroll:GetWidth()
	if not scrollWidth or scrollWidth <= 0 then
		scrollWidth = ns.UI_PANE_WIDTH - listLayout.LIST_SCROLL_LEFT + listLayout.LIST_SCROLL_RIGHT
	end
	local childWidth = math.max(ns.UI_LIST_MIN_WIDTH, scrollWidth)
	scrollChild:SetWidth(childWidth)

	local scrollHeight = scroll:GetHeight()
	if not scrollHeight or scrollHeight <= 0 then
		scrollHeight = ns.UI_LIST_SCROLL_FALLBACK_HEIGHT
	end
	local childHeight = math.max(scrollHeight, totalRows * ns.UI_ALTS_LIST_ROW_HEIGHT + ns.UI_LIST_SCROLL_CHILD_EXTRA_HEIGHT)
	scrollChild:SetHeight(childHeight)

	for index = 1, #altsLeftPane.rowFrames do
		local row = altsLeftPane.rowFrames[index]
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", ns.UI_LIST_CHILD_X, ns.UI_LIST_CHILD_Y - (index - 1) * ns.UI_ALTS_LIST_ROW_HEIGHT)
		row:SetWidth(math.max(ns.UI_LIST_MIN_WIDTH, childWidth - rowLayout.OUTER_WIDTH_TRIM))
	end
end

function ns.UI_RefreshAltsLeftPane(altsLeftPane, opts)
	if not altsLeftPane then
		return
	end

	local altFilters = ns.GetAltFilters()
	local options = ns.GetAltFilterOptions()

	if altsLeftPane.SyncSearchBox then
		altsLeftPane:SyncSearchBox(altFilters.searchText or "")
	end

	syncDropdownText(altsLeftPane.sortDrop, ns.ALT_SORT_OPTIONS, altFilters.sortKey)
	syncDropdownText(altsLeftPane.factionDrop, ns.ALT_FACTION_OPTIONS, altFilters.factionGroup)
	syncDropdownText(altsLeftPane.classDrop, options.classes, altFilters.classFile, ns.TEXT.ALTS_FILTER_ALL_CLASSES)
	syncDropdownText(altsLeftPane.raceDrop, options.races, altFilters.raceFile, ns.TEXT.ALTS_FILTER_ALL_RACES)
	syncDropdownText(altsLeftPane.professionDrop, options.professions, altFilters.professionName, ns.TEXT.ALTS_FILTER_ALL_PROFESSIONS)

	local results, total = ns.GetFilteredAltResults()
	local visibleCount = #results

	ensureAltsRows(altsLeftPane, visibleCount)
	relayoutAltsRows(altsLeftPane, visibleCount)

	local selectedKey = ns.GetSelectedCharacterKey()
	for index = 1, #altsLeftPane.rowFrames do
		local row = altsLeftPane.rowFrames[index]
		local record = results[index]
		ns.UI_ApplyAltsListRow(row, record, record and record.characterKey == selectedKey or false)
	end

	if altsLeftPane.countLabel then
		if visibleCount <= 0 then
			altsLeftPane.countLabel:SetText(string.format(ns.FORMAT.ALTS_COUNT_EMPTY, total or 0))
		else
			altsLeftPane.countLabel:SetText(string.format(ns.FORMAT.ALTS_COUNT_RESULTS, visibleCount, total or 0))
		end
	end

	clampAltsScroll(altsLeftPane, opts and opts.resetScroll == true)
end

local function syncAltRepExpansionDropdown(dropdown, selectedKey)
	widgets.SetDropdownText(dropdown, ns.ExpansionLabelForKey(selectedKey or ns.ALL_EXPANSIONS_KEY))
end

local function syncAltRepSortDropdown(dropdown, selectedKey)
	widgets.SetDropdownText(dropdown, ns.GetOptionLabel(ns.ALT_REP_SORT_OPTIONS, selectedKey))
end

function ns.UI_RefreshAltsPane(altsPane)
	if not altsPane or not altsPane.SetAlt then
		return
	end
	local altRepFilters = ns.GetAltRepFilters()
	syncAltRepExpansionDropdown(altsPane.expansionDrop, altRepFilters.expansionKey)
	syncAltRepSortDropdown(altsPane.sortDrop, altRepFilters.sortKey)

	local key = ns.GetSelectedCharacterKey()
	local record = key and ns.GetAltRecordByKey(key) or nil
	altsPane:SetAlt(record)
end
