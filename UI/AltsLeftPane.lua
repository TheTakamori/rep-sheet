RepSheet = RepSheet or {}
local ns = RepSheet
local colors = ns.UI_COLORS
local layout = ns.UI_ALTS_LEFT_LAYOUT
local ui = ns.UIHelpers
local widgets = ns.UIWidgets

local function applyDropdownPosition(dropdown, anchor)
	dropdown:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", layout.DROPDOWN_LEFT_OFFSET, layout.DROPDOWN_TOP_OFFSET)
end

function ns.UI_CreateAltsLeftPane(parent)
	local pane = ns.UIWidgets.CreateBackdropPane(parent, ns.UI_BACKDROPS.PANE, colors.PANE_BG, colors.PANE_BORDER)

	local searchLabel = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	searchLabel:SetPoint("TOPLEFT", pane, "TOPLEFT", layout.SEARCH_LABEL_LEFT, layout.SEARCH_LABEL_TOP)
	searchLabel:SetText(ns.TEXT.ALTS_SEARCH)
	ui.ApplyTextColor(searchLabel, colors.TEXT_LABEL)

	local searchBox = CreateFrame("EditBox", "RepSheetAltsSearchBox", pane, "InputBoxTemplate")
	searchBox:SetSize(layout.SEARCH_BOX_WIDTH, layout.SEARCH_BOX_HEIGHT)
	searchBox:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 0, layout.SEARCH_BOX_GAP)
	searchBox:SetAutoFocus(false)
	searchBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		if pane.OnEscape then
			pane.OnEscape()
		end
	end)
	searchBox:SetScript("OnTextChanged", function(self)
		if pane.ignoreSearchEvents then
			return
		end
		ns.SetAltFilterValue("searchText", self:GetText() or "")
		if ns.UI_RequestSearchRefresh then
			ns.UI_RequestSearchRefresh()
		end
	end)
	pane.searchBox = searchBox

	local sortLabel = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	sortLabel:SetPoint("TOPLEFT", pane, "TOPLEFT", layout.SORT_LABEL_LEFT, layout.SORT_LABEL_TOP)
	sortLabel:SetText(ns.TEXT.ALTS_SORT)
	ui.ApplyTextColor(sortLabel, colors.TEXT_LABEL)

	local sortDrop = CreateFrame("Frame", "RepSheetAltsSortDropdown", pane, "UIDropDownMenuTemplate")
	sortDrop:SetPoint("TOPLEFT", sortLabel, "BOTTOMLEFT", layout.SORT_DROPDOWN_LEFT_OFFSET, layout.SORT_DROPDOWN_TOP_OFFSET)
	pane.sortDrop = sortDrop
	widgets.ConfigureDropdown(sortDrop, layout.SORT_DROPDOWN_WIDTH)

	widgets.InitializeChoiceDropdown(
		sortDrop,
		function()
			return ns.ALT_SORT_OPTIONS
		end,
		function()
			return ns.GetAltFilterValue("sortKey") or ns.ALT_SORT_KEY.NAME
		end,
		function(option)
			ns.SetAltFilterValue("sortKey", option.key)
			if ns.RefreshMainFrame then
				ns.RefreshMainFrame()
			end
		end
	)

	local factionLabel = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	factionLabel:SetPoint("TOPLEFT", pane, "TOPLEFT", layout.COL_ONE_LEFT, layout.ROW_ONE_TOP)
	factionLabel:SetText(ns.TEXT.ALTS_FACTION_FILTER)
	ui.ApplyTextColor(factionLabel, colors.TEXT_LABEL)

	local factionDrop = CreateFrame("Frame", "RepSheetAltsFactionDropdown", pane, "UIDropDownMenuTemplate")
	applyDropdownPosition(factionDrop, factionLabel)
	pane.factionDrop = factionDrop
	widgets.ConfigureDropdown(factionDrop, layout.FACTION_DROPDOWN_WIDTH)

	widgets.InitializeChoiceDropdown(
		factionDrop,
		function()
			return ns.ALT_FACTION_OPTIONS
		end,
		function()
			return ns.GetAltFilterValue("factionGroup") or ns.ALT_FACTION_FILTER.ALL
		end,
		function(option)
			ns.SetAltFilterValue("factionGroup", option.key)
			if ns.RefreshMainFrame then
				ns.RefreshMainFrame()
			end
		end
	)

	local classLabel = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	classLabel:SetPoint("TOPLEFT", pane, "TOPLEFT", layout.COL_TWO_LEFT, layout.ROW_ONE_TOP)
	classLabel:SetText(ns.TEXT.ALTS_CLASS_FILTER)
	ui.ApplyTextColor(classLabel, colors.TEXT_LABEL)

	local classDrop = CreateFrame("Frame", "RepSheetAltsClassDropdown", pane, "UIDropDownMenuTemplate")
	applyDropdownPosition(classDrop, classLabel)
	pane.classDrop = classDrop
	widgets.ConfigureDropdown(classDrop, layout.CLASS_DROPDOWN_WIDTH)

	widgets.InitializeChoiceDropdown(
		classDrop,
		function()
			return ns.GetAltFilterOptions().classes
		end,
		function()
			return ns.GetAltFilterValue("classFile") or ns.ALL_ALT_FILTER_KEY
		end,
		function(option)
			ns.SetAltFilterValue("classFile", option.key)
			if ns.RefreshMainFrame then
				ns.RefreshMainFrame()
			end
		end
	)

	local raceLabel = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	raceLabel:SetPoint("TOPLEFT", pane, "TOPLEFT", layout.COL_ONE_LEFT, layout.ROW_TWO_TOP)
	raceLabel:SetText(ns.TEXT.ALTS_RACE_FILTER)
	ui.ApplyTextColor(raceLabel, colors.TEXT_LABEL)

	local raceDrop = CreateFrame("Frame", "RepSheetAltsRaceDropdown", pane, "UIDropDownMenuTemplate")
	applyDropdownPosition(raceDrop, raceLabel)
	pane.raceDrop = raceDrop
	widgets.ConfigureDropdown(raceDrop, layout.RACE_DROPDOWN_WIDTH)

	widgets.InitializeChoiceDropdown(
		raceDrop,
		function()
			return ns.GetAltFilterOptions().races
		end,
		function()
			return ns.GetAltFilterValue("raceFile") or ns.ALL_ALT_FILTER_KEY
		end,
		function(option)
			ns.SetAltFilterValue("raceFile", option.key)
			if ns.RefreshMainFrame then
				ns.RefreshMainFrame()
			end
		end
	)

	local professionLabel = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	professionLabel:SetPoint("TOPLEFT", pane, "TOPLEFT", layout.COL_TWO_LEFT, layout.ROW_TWO_TOP)
	professionLabel:SetText(ns.TEXT.ALTS_PROFESSION_FILTER)
	ui.ApplyTextColor(professionLabel, colors.TEXT_LABEL)

	local professionDrop = CreateFrame("Frame", "RepSheetAltsProfessionDropdown", pane, "UIDropDownMenuTemplate")
	applyDropdownPosition(professionDrop, professionLabel)
	pane.professionDrop = professionDrop
	widgets.ConfigureDropdown(professionDrop, layout.PROFESSION_DROPDOWN_WIDTH)

	widgets.InitializeChoiceDropdown(
		professionDrop,
		function()
			return ns.GetAltFilterOptions().professions
		end,
		function()
			return ns.GetAltFilterValue("professionName") or ns.ALL_ALT_FILTER_KEY
		end,
		function(option)
			ns.SetAltFilterValue("professionName", option.key)
			if ns.RefreshMainFrame then
				ns.RefreshMainFrame()
			end
		end
	)

	local countLabel = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	countLabel:SetPoint("TOPLEFT", pane, "TOPLEFT", layout.COUNT_LEFT, layout.COUNT_TOP)
	countLabel:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -layout.COUNT_LEFT, layout.COUNT_TOP)
	countLabel:SetJustifyH("LEFT")
	pane.countLabel = countLabel

	local listScroll = CreateFrame("ScrollFrame", "RepSheetAltsListScroll", pane, "UIPanelScrollFrameTemplate")
	listScroll:SetPoint("TOPLEFT", pane, "TOPLEFT", layout.LIST_SCROLL_LEFT, layout.LIST_SCROLL_TOP)
	listScroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", layout.LIST_SCROLL_RIGHT, layout.LIST_SCROLL_BOTTOM)
	listScroll:EnableMouseWheel(true)
	listScroll:SetScript("OnMouseWheel", function(_, delta)
		local step = ns.UI_ALTS_LIST_ROW_HEIGHT * ns.UI_LIST_WHEEL_STEP_ROWS
		local current = listScroll:GetVerticalScroll() or 0
		local range = listScroll:GetVerticalScrollRange() or 0
		listScroll:SetVerticalScroll(ns.Clamp(current - delta * step, 0, range))
	end)
	pane.listScroll = listScroll

	local listScrollChild = widgets.CreateScrollChild(
		listScroll,
		ns.UI_PANE_WIDTH - layout.LIST_SCROLL_LEFT + layout.LIST_SCROLL_RIGHT,
		ns.UI_LIST_SCROLL_CHILD_MIN_HEIGHT,
		function(_, delta)
			local step = ns.UI_ALTS_LIST_ROW_HEIGHT * ns.UI_LIST_WHEEL_STEP_ROWS
			local current = listScroll:GetVerticalScroll() or 0
			local range = listScroll:GetVerticalScrollRange() or 0
			listScroll:SetVerticalScroll(ns.Clamp(current - delta * step, 0, range))
		end
	)
	pane.listScrollChild = listScrollChild

	pane.rowFrames = {}

	function pane:SyncSearchBox(text)
		if not self.searchBox then
			return
		end
		text = text or ""
		local current = self.searchBox:GetText() or ""
		if current == text then
			return
		end
		self.ignoreSearchEvents = true
		self.searchBox:SetText(text)
		self.ignoreSearchEvents = false
	end

	return pane
end
