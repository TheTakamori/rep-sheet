RepSheet = RepSheet or {}
local ns = RepSheet
local state = ns.UI_MainFrameState
local colors = ns.UI_COLORS
local layout = ns.UI_MAIN_LAYOUT
local debugLayout = ns.UI_DEBUG_PANE_LAYOUT
local ui = ns.UIHelpers
local widgets = ns.UIWidgets

function ns.CreateMainFrame()
	if state.main then
		return state.main
	end

	local debugEnabled = ns.IsLocalDebugEnabled and ns.IsLocalDebugEnabled()
	local frame = CreateFrame("Frame", "RepSheetMainFrame", UIParent, "BackdropTemplate")
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
	ui.RegisterSpecialFrame(frame)

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

	local optionsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	optionsBtn:SetSize(ns.UI_OPTIONS_BUTTON_WIDTH, ns.UI_DEBUG_BUTTON_HEIGHT)
	optionsBtn:SetPoint("RIGHT", close, "LEFT", ns.UI_DEBUG_BUTTON_GAP, 0)
	optionsBtn:SetText(ns.TEXT.OPTIONS)
	frame.optionsBtn = optionsBtn

	local forgetAltBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	forgetAltBtn:SetSize(ns.UI_FORGET_ALT_BUTTON_WIDTH, ns.UI_DEBUG_BUTTON_HEIGHT)
	forgetAltBtn:SetPoint("RIGHT", optionsBtn, "LEFT", ns.UI_DEBUG_BUTTON_GAP, 0)
	forgetAltBtn:SetText(ns.TEXT.FORGET_ALT)
	frame.forgetAltBtn = forgetAltBtn

	local debugBtn = nil
	local debugScanBtn = nil
	local debugClearBtn = nil
	if debugEnabled then
		debugBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		debugBtn:SetSize(ns.UI_DEBUG_BUTTON_WIDTH, ns.UI_DEBUG_BUTTON_HEIGHT)
		debugBtn:SetPoint("RIGHT", forgetAltBtn, "LEFT", ns.UI_DEBUG_BUTTON_GAP, 0)
		debugBtn:SetText(ns.TEXT.DEBUG)
		frame.debugBtn = debugBtn

		debugScanBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		debugScanBtn:SetSize(debugLayout.SCAN_WIDTH, ns.UI_DEBUG_BUTTON_HEIGHT)
		debugScanBtn:SetPoint("RIGHT", debugBtn, "LEFT", ns.UI_DEBUG_BUTTON_GAP, 0)
		debugScanBtn:SetText(ns.TEXT.SCAN_AND_LOG)
		debugScanBtn:Hide()
		frame.debugScanBtn = debugScanBtn

		debugClearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		debugClearBtn:SetSize(debugLayout.CLEAR_WIDTH, ns.UI_DEBUG_BUTTON_HEIGHT)
		debugClearBtn:SetPoint("RIGHT", debugScanBtn, "LEFT", ns.UI_DEBUG_BUTTON_GAP, 0)
		debugClearBtn:SetText(ns.TEXT.CLEAR_LOG)
		debugClearBtn:Hide()
		frame.debugClearBtn = debugClearBtn
	end

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

	local searchBox = CreateFrame("EditBox", "RepSheetSearchBox", leftPane, "InputBoxTemplate")
	searchBox:SetSize(layout.SEARCH_BOX_WIDTH, layout.SEARCH_BOX_HEIGHT)
	searchBox:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 0, layout.SEARCH_BOX_GAP)
	searchBox:SetAutoFocus(false)
	searchBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		frame:Hide()
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
		widgets.RequestManualReputationScan()
	end)

	local controlsTop = layout.CONTROL_ROW_ONE_TOP

	local expansionLabel = leftPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	expansionLabel:SetPoint("TOPLEFT", leftPane, "TOPLEFT", layout.CONTROL_COL_ONE_LEFT, controlsTop)
	expansionLabel:SetText(ns.TEXT.EXPANSION)
	ui.ApplyTextColor(expansionLabel, colors.TEXT_LABEL)

	local expansionDrop = CreateFrame("Frame", "RepSheetExpansionDropdown", leftPane, "UIDropDownMenuTemplate")
	expansionDrop:SetPoint("TOPLEFT", expansionLabel, "BOTTOMLEFT", layout.DROPDOWN_LEFT_OFFSET, layout.DROPDOWN_TOP_OFFSET)
	frame.expansionDrop = expansionDrop
	widgets.ConfigureDropdown(expansionDrop, layout.EXPANSION_DROPDOWN_WIDTH)

	local sortLabel = leftPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	sortLabel:SetPoint("TOPLEFT", leftPane, "TOPLEFT", layout.CONTROL_COL_TWO_LEFT, controlsTop)
	sortLabel:SetText(ns.TEXT.SORT)
	ui.ApplyTextColor(sortLabel, colors.TEXT_LABEL)

	local sortDrop = CreateFrame("Frame", "RepSheetSortDropdown", leftPane, "UIDropDownMenuTemplate")
	sortDrop:SetPoint("TOPLEFT", sortLabel, "BOTTOMLEFT", layout.DROPDOWN_LEFT_OFFSET, layout.DROPDOWN_TOP_OFFSET)
	frame.sortDrop = sortDrop
	widgets.ConfigureDropdown(sortDrop, layout.SORT_DROPDOWN_WIDTH)

	local statusLabel = leftPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	statusLabel:SetPoint("TOPLEFT", leftPane, "TOPLEFT", layout.CONTROL_COL_ONE_LEFT, layout.CONTROL_ROW_TWO_TOP)
	statusLabel:SetText(ns.TEXT.FILTER)
	ui.ApplyTextColor(statusLabel, colors.TEXT_LABEL)

	local statusDrop = CreateFrame("Frame", "RepSheetStatusDropdown", leftPane, "UIDropDownMenuTemplate")
	statusDrop:SetPoint("TOPLEFT", statusLabel, "BOTTOMLEFT", layout.DROPDOWN_LEFT_OFFSET, layout.DROPDOWN_TOP_OFFSET)
	frame.statusDrop = statusDrop
	widgets.ConfigureDropdown(statusDrop, layout.STATUS_DROPDOWN_WIDTH)

	widgets.InitializeChoiceDropdown(
		expansionDrop,
		function()
			return ns.Expansions
		end,
		function()
			return ns.GetFilterValue("expansionKey") or ns.ALL_EXPANSIONS_KEY
		end,
		function(option)
			ns.SetFilterValue("expansionKey", option.key)
			ns.RefreshMainFrame()
		end
	)

	widgets.InitializeChoiceDropdown(
		sortDrop,
		function()
			return ns.SORT_OPTIONS
		end,
		function()
			return ns.GetFilterValue("sortKey") or ns.SORT_KEY.BEST_PROGRESS
		end,
		function(option)
			ns.SetFilterValue("sortKey", option.key)
			ns.RefreshMainFrame()
		end
	)

	widgets.InitializeChoiceDropdown(
		statusDrop,
		function()
			return ns.FILTER_STATUS_OPTIONS
		end,
		function()
			return ns.GetFilterValue("statusKey") or ns.FILTER_STATUS.ALL
		end,
		function(option)
			ns.SetFilterValue("statusKey", option.key)
			ns.RefreshMainFrame()
		end
	)

	local countLabel = leftPane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	countLabel:SetPoint("TOPLEFT", leftPane, "TOPLEFT", layout.COUNT_LEFT, layout.COUNT_TOP)
	countLabel:SetPoint("TOPRIGHT", leftPane, "TOPRIGHT", -layout.COUNT_LEFT, layout.COUNT_TOP)
	countLabel:SetJustifyH("LEFT")
	frame.countLabel = countLabel

	local listScroll = CreateFrame("ScrollFrame", "RepSheetFactionScroll", leftPane, "UIPanelScrollFrameTemplate")
	listScroll:SetPoint("TOPLEFT", leftPane, "TOPLEFT", layout.LIST_SCROLL_LEFT, layout.LIST_SCROLL_TOP)
	listScroll:SetPoint("BOTTOMRIGHT", leftPane, "BOTTOMRIGHT", layout.LIST_SCROLL_RIGHT, layout.LIST_SCROLL_BOTTOM)
	listScroll:EnableMouseWheel(true)
	listScroll:SetScript("OnMouseWheel", ns.UI_MainFrameFactionListMouseWheel)
	frame.listScroll = listScroll

	local listScrollChild = widgets.CreateScrollChild(
		listScroll,
		ns.UI_PANE_WIDTH - layout.LIST_SCROLL_LEFT + layout.LIST_SCROLL_RIGHT,
		ns.UI_LIST_SCROLL_CHILD_MIN_HEIGHT,
		ns.UI_MainFrameFactionListMouseWheel
	)
	frame.listScrollChild = listScrollChild

	local characterPane = ns.UI_CreateCharacterPane(frame)
	characterPane:SetPoint("TOPLEFT", leftPane, "TOPRIGHT", ns.UI_PANE_GAP, 0)
	characterPane:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -ns.UI_FRAME_SIDE_INSET, ns.UI_FRAME_TOP_OFFSET)
	characterPane:SetPoint("BOTTOMLEFT", leftPane, "BOTTOMRIGHT", ns.UI_PANE_GAP, 0)
	characterPane.onFavoriteChanged = function()
		ns.RefreshMainFrame()
	end
	frame.characterPane = characterPane

	local debugPane = debugEnabled and ns.UI_CreateDebugPane(frame) or nil
	frame.debugPane = debugPane
	local forgetAltDialog = ns.UI_CreateForgetAltDialog(frame)
	frame.forgetAltDialog = forgetAltDialog

	function frame:UpdateForgetAltButtonState()
		local forgettableCharacters = ns.GetForgettableCharacters and ns.GetForgettableCharacters() or {}
		local hasForgettableCharacters = #forgettableCharacters > 0
		forgetAltBtn:SetEnabled(hasForgettableCharacters)

		if forgetAltDialog:IsShown() then
			forgetAltDialog:RefreshCharacters(true)
			if #(forgetAltDialog.characters or {}) <= 0 then
				forgetAltDialog:Hide()
			end
		end
	end

	function frame:SetDebugPageShown(shown)
		if not debugEnabled or not debugPane or not debugBtn or not debugScanBtn or not debugClearBtn then
			leftPane:Show()
			characterPane:Show()
			if debugPane then
				debugPane:Hide()
			end
			return
		end
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

	if debugBtn then
		debugBtn:SetScript("OnClick", function()
			frame:SetDebugPageShown(not debugPane:IsShown())
		end)
	end

	optionsBtn:SetScript("OnClick", function()
		if ns.OpenOptionsPanel then
			ns.OpenOptionsPanel()
		end
	end)

	forgetAltBtn:SetScript("OnClick", function()
		if forgetAltDialog.Open then
			forgetAltDialog:Open()
		end
	end)

	if debugScanBtn then
		debugScanBtn:SetScript("OnClick", function()
			if debugPane.RunDebugScan then
				debugPane:RunDebugScan()
			end
		end)
	end

	if debugClearBtn then
		debugClearBtn:SetScript("OnClick", function()
			if debugPane.ClearLog then
				debugPane:ClearLog()
			end
		end)
	end

	local statusFooter = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	statusFooter:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", ns.UI_FRAME_FOOTER_SIDE_INSET, ns.UI_FRAME_FOOTER_BOTTOM_INSET)
	statusFooter:SetJustifyH("LEFT")
	ui.ApplyTextColor(statusFooter, colors.TEXT_FOOTER)
	ui.SetSingleLine(statusFooter)
	frame.statusLabel = statusFooter

	local versionFooter = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	versionFooter:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -ns.UI_FRAME_FOOTER_SIDE_INSET, ns.UI_FRAME_FOOTER_BOTTOM_INSET)
	versionFooter:SetJustifyH("RIGHT")
	ui.ApplyTextColor(versionFooter, colors.TEXT_FOOTER)
	ui.SetSingleLine(versionFooter)
	frame.versionLabel = versionFooter

	statusFooter:SetPoint("BOTTOMRIGHT", versionFooter, "BOTTOMLEFT", ns.UI_FRAME_FOOTER_GAP, 0)

	frame:SetScript("OnShow", function()
		ns.RuntimeEnsure().resetListScroll = true
		state.ignoreSearchEvents = true
		searchBox:SetText(ns.GetFilterValue("searchText") or "")
		state.ignoreSearchEvents = false
		frame:UpdateForgetAltButtonState()
		if debugBtn and debugPane and debugScanBtn and debugClearBtn then
			debugBtn:SetText(debugPane:IsShown() and ns.TEXT.BACK or ns.TEXT.DEBUG)
			debugScanBtn:SetShown(debugPane:IsShown())
			debugClearBtn:SetShown(debugPane:IsShown())
		end
		ns.RefreshMainFrame()
	end)
	frame:SetScript("OnHide", function()
		if forgetAltDialog and forgetAltDialog:IsShown() then
			forgetAltDialog:Hide()
		end
	end)

	state.main = frame
	ns.DebugLog(string.format(ns.LOG.MAIN_FRAME_CREATED, ns.GetPrimarySlashCommand()))
	return state.main
end
