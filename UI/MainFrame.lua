AltRepTracker = AltRepTracker or {}
local ns = AltRepTracker
local state = ns.UI_MainFrameState
local colors = ns.UI_COLORS
local layout = ns.UI_MAIN_LAYOUT
local debugLayout = ns.UI_DEBUG_PANE_LAYOUT
local ui = ns.UIHelpers

function ns.CreateMainFrame()
	if state.main then
		return state.main
	end

	local frame = CreateFrame("Frame", "AltRepTrackerMainFrame", UIParent, "BackdropTemplate")
	frame:SetSize(ns.UI_FRAME_WIDTH, ns.UI_FRAME_HEIGHT)
	frame:SetFrameStrata("HIGH")
	frame:SetBackdrop(ns.UI_BACKDROPS.FRAME)
	ui.ApplyBackdropColors(frame, colors.FRAME_BG)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		ns.SaveMainFramePosition(self)
	end)
	frame:Hide()
	ns.RestoreMainFramePosition(frame)

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", ns.UI_MAIN_TITLE_LEFT, ns.UI_MAIN_TITLE_TOP)
	title:SetText(ns.TEXT.MAIN_TITLE)
	ui.ApplyTextColor(title, colors.TEXT_TITLE)

	local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, ns.UI_MAIN_SUBTITLE_GAP)
	subtitle:SetText(ns.TEXT.MAIN_SUBTITLE)
	ui.ApplyTextColor(subtitle, colors.TEXT_SUBTITLE)

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", ns.UI_CLOSE_BUTTON_RIGHT, ns.UI_CLOSE_BUTTON_TOP)

	local debugBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	debugBtn:SetSize(ns.UI_DEBUG_BUTTON_WIDTH, ns.UI_DEBUG_BUTTON_HEIGHT)
	debugBtn:SetPoint("RIGHT", close, "LEFT", ns.UI_DEBUG_BUTTON_GAP, 0)
	debugBtn:SetText(ns.TEXT.DEBUG)
	frame.debugBtn = debugBtn

	local debugScanBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	debugScanBtn:SetSize(debugLayout.SCAN_WIDTH, ns.UI_DEBUG_BUTTON_HEIGHT)
	debugScanBtn:SetPoint("RIGHT", debugBtn, "LEFT", ns.UI_DEBUG_BUTTON_GAP, 0)
	debugScanBtn:SetText(ns.TEXT.SCAN_AND_LOG)
	debugScanBtn:Hide()
	frame.debugScanBtn = debugScanBtn

	local debugClearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	debugClearBtn:SetSize(debugLayout.CLEAR_WIDTH, ns.UI_DEBUG_BUTTON_HEIGHT)
	debugClearBtn:SetPoint("RIGHT", debugScanBtn, "LEFT", ns.UI_DEBUG_BUTTON_GAP, 0)
	debugClearBtn:SetText(ns.TEXT.CLEAR_LOG)
	debugClearBtn:Hide()
	frame.debugClearBtn = debugClearBtn

	local info = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	info:SetPoint("TOPLEFT", frame, "TOPLEFT", ns.UI_MAIN_INFO_LEFT, ns.UI_MAIN_INFO_TOP)
	info:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -ns.UI_MAIN_INFO_LEFT, ns.UI_MAIN_INFO_TOP)
	info:SetJustifyH("LEFT")
	info:SetText(ns.TEXT.MAIN_INFO)
	ui.ApplyTextColor(info, colors.TEXT_INFO)

	local leftPane = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	leftPane:SetPoint("TOPLEFT", frame, "TOPLEFT", ns.UI_FRAME_SIDE_INSET, ns.UI_FRAME_TOP_OFFSET)
	leftPane:SetSize(ns.UI_PANE_WIDTH, ns.UI_FRAME_HEIGHT - ns.UI_PANE_HEIGHT_TRIM)
	leftPane:SetBackdrop(ns.UI_BACKDROPS.PANE)
	ui.ApplyBackdropColors(leftPane, colors.PANE_BG, colors.PANE_BORDER)
	frame.leftPane = leftPane

	local searchLabel = leftPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	searchLabel:SetPoint("TOPLEFT", leftPane, "TOPLEFT", layout.SEARCH_LABEL_LEFT, layout.SEARCH_LABEL_TOP)
	searchLabel:SetText(ns.TEXT.SEARCH)
	ui.ApplyTextColor(searchLabel, colors.TEXT_LABEL)

	local searchBox = CreateFrame("EditBox", "AltRepTrackerSearchBox", leftPane, "InputBoxTemplate")
	searchBox:SetSize(layout.SEARCH_BOX_WIDTH, layout.SEARCH_BOX_HEIGHT)
	searchBox:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 0, layout.SEARCH_BOX_GAP)
	searchBox:SetAutoFocus(false)
	searchBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	searchBox:SetScript("OnTextChanged", function(self)
		if state.ignoreSearchEvents then
			return
		end
		ns.SetFilterValue("searchText", self:GetText() or "")
		ns.UI_RequestSearchRefresh()
	end)
	frame.searchBox = searchBox

	local scanBtn = CreateFrame("Button", nil, leftPane, "UIPanelButtonTemplate")
	scanBtn:SetSize(layout.SCAN_BUTTON_WIDTH, layout.SCAN_BUTTON_HEIGHT)
	scanBtn:SetPoint("TOPRIGHT", leftPane, "TOPRIGHT", layout.SCAN_BUTTON_RIGHT, layout.SCAN_BUTTON_TOP)
	scanBtn:SetText(ns.TEXT.SCAN_THIS_ALT)
	scanBtn:SetScript("OnClick", function()
		if ns.RequestReputationScan then
			ns.RequestReputationScan(ns.SCAN_REASON.MANUAL_REFRESH, true)
		else
			ns.ScanCurrentCharacter(ns.SCAN_REASON.MANUAL_REFRESH)
			ns.RefreshMainFrame()
		end
	end)

	local controlsTop = layout.CONTROL_ROW_ONE_TOP

	local expansionLabel = leftPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	expansionLabel:SetPoint("TOPLEFT", leftPane, "TOPLEFT", layout.CONTROL_COL_ONE_LEFT, controlsTop)
	expansionLabel:SetText(ns.TEXT.EXPANSION)
	ui.ApplyTextColor(expansionLabel, colors.TEXT_LABEL)

	local expansionDrop = CreateFrame("Frame", "AltRepTrackerExpansionDropdown", leftPane, "UIDropDownMenuTemplate")
	expansionDrop:SetPoint("TOPLEFT", expansionLabel, "BOTTOMLEFT", layout.DROPDOWN_LEFT_OFFSET, layout.DROPDOWN_TOP_OFFSET)
	frame.expansionDrop = expansionDrop
	if UIDropDownMenu_SetWidth then
		UIDropDownMenu_SetWidth(expansionDrop, layout.EXPANSION_DROPDOWN_WIDTH)
		UIDropDownMenu_JustifyText(expansionDrop, "LEFT")
	end

	local sortLabel = leftPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	sortLabel:SetPoint("TOPLEFT", leftPane, "TOPLEFT", layout.CONTROL_COL_TWO_LEFT, controlsTop)
	sortLabel:SetText(ns.TEXT.SORT)
	ui.ApplyTextColor(sortLabel, colors.TEXT_LABEL)

	local sortDrop = CreateFrame("Frame", "AltRepTrackerSortDropdown", leftPane, "UIDropDownMenuTemplate")
	sortDrop:SetPoint("TOPLEFT", sortLabel, "BOTTOMLEFT", layout.DROPDOWN_LEFT_OFFSET, layout.DROPDOWN_TOP_OFFSET)
	frame.sortDrop = sortDrop
	if UIDropDownMenu_SetWidth then
		UIDropDownMenu_SetWidth(sortDrop, layout.SORT_DROPDOWN_WIDTH)
		UIDropDownMenu_JustifyText(sortDrop, "LEFT")
	end

	local statusLabel = leftPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	statusLabel:SetPoint("TOPLEFT", leftPane, "TOPLEFT", layout.CONTROL_COL_ONE_LEFT, layout.CONTROL_ROW_TWO_TOP)
	statusLabel:SetText(ns.TEXT.FILTER)
	ui.ApplyTextColor(statusLabel, colors.TEXT_LABEL)

	local statusDrop = CreateFrame("Frame", "AltRepTrackerStatusDropdown", leftPane, "UIDropDownMenuTemplate")
	statusDrop:SetPoint("TOPLEFT", statusLabel, "BOTTOMLEFT", layout.DROPDOWN_LEFT_OFFSET, layout.DROPDOWN_TOP_OFFSET)
	frame.statusDrop = statusDrop
	if UIDropDownMenu_SetWidth then
		UIDropDownMenu_SetWidth(statusDrop, layout.STATUS_DROPDOWN_WIDTH)
		UIDropDownMenu_JustifyText(statusDrop, "LEFT")
	end

	if UIDropDownMenu_Initialize then
		UIDropDownMenu_Initialize(expansionDrop, function()
			local selected = ns.GetFilterValue("expansionKey") or ns.ALL_EXPANSIONS_KEY
			for index = 1, #ns.Expansions do
				local expansion = ns.Expansions[index]
				local info = UIDropDownMenu_CreateInfo()
				info.text = expansion.name
				info.checked = selected == expansion.key
				info.func = function()
					ns.SetFilterValue("expansionKey", expansion.key)
					ns.RefreshMainFrame()
				end
				UIDropDownMenu_AddButton(info)
			end
		end)

		UIDropDownMenu_Initialize(sortDrop, function()
			local selected = ns.GetFilterValue("sortKey") or ns.SORT_KEY.BEST_PROGRESS
			for index = 1, #ns.SORT_OPTIONS do
				local option = ns.SORT_OPTIONS[index]
				local info = UIDropDownMenu_CreateInfo()
				info.text = option.label
				info.checked = selected == option.key
				info.func = function()
					ns.SetFilterValue("sortKey", option.key)
					ns.RefreshMainFrame()
				end
				UIDropDownMenu_AddButton(info)
			end
		end)

		UIDropDownMenu_Initialize(statusDrop, function()
			local selected = ns.GetFilterValue("statusKey") or ns.FILTER_STATUS.ALL
			for index = 1, #ns.FILTER_STATUS_OPTIONS do
				local option = ns.FILTER_STATUS_OPTIONS[index]
				local info = UIDropDownMenu_CreateInfo()
				info.text = option.label
				info.checked = selected == option.key
				info.func = function()
					ns.SetFilterValue("statusKey", option.key)
					ns.RefreshMainFrame()
				end
				UIDropDownMenu_AddButton(info)
			end
		end)
	end

	local countLabel = leftPane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	countLabel:SetPoint("TOPLEFT", leftPane, "TOPLEFT", layout.COUNT_LEFT, layout.COUNT_TOP)
	countLabel:SetPoint("TOPRIGHT", leftPane, "TOPRIGHT", -layout.COUNT_LEFT, layout.COUNT_TOP)
	countLabel:SetJustifyH("LEFT")
	frame.countLabel = countLabel

	local listScroll = CreateFrame("ScrollFrame", "AltRepTrackerFactionScroll", leftPane, "UIPanelScrollFrameTemplate")
	listScroll:SetPoint("TOPLEFT", leftPane, "TOPLEFT", layout.LIST_SCROLL_LEFT, layout.LIST_SCROLL_TOP)
	listScroll:SetPoint("BOTTOMRIGHT", leftPane, "BOTTOMRIGHT", layout.LIST_SCROLL_RIGHT, layout.LIST_SCROLL_BOTTOM)
	listScroll:EnableMouseWheel(true)
	listScroll:SetScript("OnMouseWheel", ns.UI_MainFrameFactionListMouseWheel)
	frame.listScroll = listScroll

	local listScrollChild = CreateFrame("Frame", nil, listScroll)
	listScrollChild:SetSize(ns.UI_PANE_WIDTH - layout.LIST_SCROLL_LEFT + layout.LIST_SCROLL_RIGHT, ns.UI_LIST_SCROLL_CHILD_MIN_HEIGHT)
	listScrollChild:EnableMouseWheel(true)
	listScrollChild:SetScript("OnMouseWheel", ns.UI_MainFrameFactionListMouseWheel)
	listScroll:SetScrollChild(listScrollChild)
	frame.listScrollChild = listScrollChild

	local characterPane = ns.UI_CreateCharacterPane(frame)
	characterPane:SetPoint("TOPLEFT", leftPane, "TOPRIGHT", ns.UI_PANE_GAP, 0)
	characterPane:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -ns.UI_FRAME_SIDE_INSET, ns.UI_FRAME_TOP_OFFSET)
	characterPane:SetPoint("BOTTOMLEFT", leftPane, "BOTTOMRIGHT", ns.UI_PANE_GAP, 0)
	characterPane.onFavoriteChanged = function()
		ns.RefreshMainFrame()
	end
	frame.characterPane = characterPane

	local debugPane = ns.UI_CreateDebugPane(frame)
	frame.debugPane = debugPane

	function frame:SetDebugPageShown(shown)
		shown = shown == true
		leftPane:SetShown(not shown)
		characterPane:SetShown(not shown)
		debugPane:SetShown(shown)
		debugBtn:SetText(shown and ns.TEXT.BACK or ns.TEXT.DEBUG)
		debugScanBtn:SetShown(shown)
		debugClearBtn:SetShown(shown)
		if shown and debugPane.Refresh then
			debugPane:Refresh()
		end
	end

	debugBtn:SetScript("OnClick", function()
		frame:SetDebugPageShown(not debugPane:IsShown())
	end)

	debugScanBtn:SetScript("OnClick", function()
		if debugPane.RunDebugScan then
			debugPane:RunDebugScan()
		end
	end)

	debugClearBtn:SetScript("OnClick", function()
		if debugPane.ClearLog then
			debugPane:ClearLog()
		end
	end)

	local statusFooter = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	statusFooter:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", ns.UI_FRAME_FOOTER_SIDE_INSET, ns.UI_FRAME_FOOTER_BOTTOM_INSET)
	statusFooter:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -ns.UI_FRAME_FOOTER_SIDE_INSET, ns.UI_FRAME_FOOTER_BOTTOM_INSET)
	statusFooter:SetJustifyH("LEFT")
	ui.ApplyTextColor(statusFooter, colors.TEXT_FOOTER)
	frame.statusLabel = statusFooter

	frame:SetScript("OnShow", function()
		ns.RuntimeEnsure().resetListScroll = true
		state.ignoreSearchEvents = true
		searchBox:SetText(ns.GetFilterValue("searchText") or "")
		state.ignoreSearchEvents = false
		debugBtn:SetText(debugPane:IsShown() and ns.TEXT.BACK or ns.TEXT.DEBUG)
		debugScanBtn:SetShown(debugPane:IsShown())
		debugClearBtn:SetShown(debugPane:IsShown())
		ns.RefreshMainFrame()
	end)

	state.main = frame
	ns.DebugLog(string.format(ns.LOG.MAIN_FRAME_CREATED, ns.GetPrimarySlashCommand()))
	return state.main
end
