RepSheet = RepSheet or {}
local ns = RepSheet
local state = ns.UI_MainFrameState
local colors = ns.UI_COLORS
local layout = ns.UI_MAIN_LAYOUT
local debugLayout = ns.UI_DEBUG_PANE_LAYOUT
local forgetLayout = ns.UI_FORGET_ALT_DIALOG_LAYOUT
local ui = ns.UIHelpers

local function registerSpecialFrame(frame)
	if not frame or not frame.GetName then
		return
	end

	local frameName = frame:GetName()
	if not frameName or frameName == "" then
		return
	end

	UISpecialFrames = type(UISpecialFrames) == "table" and UISpecialFrames or {}
	for index = 1, #UISpecialFrames do
		if UISpecialFrames[index] == frameName then
			return
		end
	end

	UISpecialFrames[#UISpecialFrames + 1] = frameName
end

local function setDropdownEnabled(dropdown, enabled)
	if not dropdown then
		return
	end

	enabled = enabled == true
	if enabled then
		if UIDropDownMenu_EnableDropDown then
			UIDropDownMenu_EnableDropDown(dropdown)
		end
	else
		if UIDropDownMenu_DisableDropDown then
			UIDropDownMenu_DisableDropDown(dropdown)
		end
	end

	if dropdown.Button and dropdown.Button.SetEnabled then
		dropdown.Button:SetEnabled(enabled)
	end
	dropdown:SetAlpha(enabled and 1 or 0.55)
end

local function forgetAltErrorText(reason)
	if reason == "scanBusy" then
		return ns.TEXT.FORGET_ALT_SCAN_BUSY
	end
	if reason == "currentCharacter" then
		return ns.TEXT.FORGET_ALT_CURRENT
	end
	if reason == "notFound" then
		return ns.TEXT.FORGET_ALT_NOT_FOUND
	end
	return ns.TEXT.FORGET_ALT_FAILED
end

local function createForgetAltDialog(parent)
	local dialog = CreateFrame("Frame", "RepSheetForgetAltDialog", parent, "BackdropTemplate")
	dialog:SetSize(forgetLayout.WIDTH, forgetLayout.HEIGHT)
	dialog:SetPoint("CENTER", parent, "CENTER", 0, 0)
	dialog:SetFrameStrata("DIALOG")
	dialog:SetToplevel(true)
	dialog:EnableMouse(true)
	dialog:SetBackdrop(ns.UI_BACKDROPS.PANE)
	ui.ApplyBackdropColors(dialog, colors.PANE_BG, colors.PANE_BORDER)
	dialog:Hide()
	registerSpecialFrame(dialog)

	local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", ns.UI_CLOSE_BUTTON_RIGHT, ns.UI_CLOSE_BUTTON_TOP)

	dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	dialog.title:SetPoint("TOPLEFT", dialog, "TOPLEFT", forgetLayout.TITLE_LEFT, forgetLayout.TITLE_TOP)
	dialog.title:SetText(ns.TEXT.FORGET_ALT_TITLE)
	ui.ApplyTextColor(dialog.title, colors.TEXT_TITLE_MUTED)

	dialog.info = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	dialog.info:SetPoint("TOPLEFT", dialog, "TOPLEFT", forgetLayout.INFO_LEFT, forgetLayout.INFO_TOP)
	dialog.info:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", forgetLayout.INFO_RIGHT, forgetLayout.INFO_TOP)
	dialog.info:SetJustifyH("LEFT")
	dialog.info:SetText(ns.TEXT.FORGET_ALT_INFO)
	ui.ApplyTextColor(dialog.info, colors.TEXT_INFO)

	dialog.dropdown = CreateFrame("Frame", "RepSheetForgetAltDropdown", dialog, "UIDropDownMenuTemplate")
	dialog.dropdown:SetPoint("TOPLEFT", dialog, "TOPLEFT", forgetLayout.DROPDOWN_LEFT - 14, forgetLayout.DROPDOWN_TOP)
	if UIDropDownMenu_SetWidth then
		UIDropDownMenu_SetWidth(dialog.dropdown, forgetLayout.DROPDOWN_WIDTH)
		UIDropDownMenu_JustifyText(dialog.dropdown, "LEFT")
	end

	dialog.status = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	dialog.status:SetPoint("TOPLEFT", dialog, "TOPLEFT", forgetLayout.STATUS_LEFT, forgetLayout.STATUS_TOP)
	dialog.status:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", forgetLayout.STATUS_RIGHT, forgetLayout.STATUS_TOP)
	dialog.status:SetJustifyH("LEFT")
	ui.ApplyTextColor(dialog.status, colors.TEXT_STATUS)

	dialog.forgetBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	dialog.forgetBtn:SetSize(forgetLayout.FORGET_WIDTH, forgetLayout.FORGET_HEIGHT)
	dialog.forgetBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", forgetLayout.FORGET_RIGHT, forgetLayout.BUTTON_BOTTOM)
	dialog.forgetBtn:SetText(ns.TEXT.FORGET)
	dialog.forgetBtn:SetEnabled(false)

	dialog.cancelBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	dialog.cancelBtn:SetSize(forgetLayout.CANCEL_WIDTH, forgetLayout.CANCEL_HEIGHT)
	dialog.cancelBtn:SetPoint("RIGHT", dialog.forgetBtn, "LEFT", forgetLayout.CANCEL_GAP, 0)
	dialog.cancelBtn:SetText(ns.TEXT.CANCEL)

	function dialog:SetSelectedCharacter(character)
		self.selectedCharacter = character
		self.selectedCharacterKey = ns.SafeString(character and character.characterKey)
		if UIDropDownMenu_SetText then
			UIDropDownMenu_SetText(
				self.dropdown,
				character and ns.FormatCharacterName(character) or ns.TEXT.FORGET_ALT_SELECT
			)
		end
		self.forgetBtn:SetEnabled(self.selectedCharacterKey ~= "")
	end

	function dialog:RefreshCharacters(preserveSelection)
		local preservedKey = preserveSelection and ns.SafeString(self.selectedCharacterKey) or ""
		self.characters = ns.GetForgettableCharacters and ns.GetForgettableCharacters() or {}

		local selectedCharacter = nil
		for index = 1, #self.characters do
			local character = self.characters[index]
			if ns.SafeString(character and character.characterKey) == preservedKey then
				selectedCharacter = character
				break
			end
		end

		setDropdownEnabled(self.dropdown, #self.characters > 0)
		self.status:SetText("")
		self:SetSelectedCharacter(selectedCharacter)
	end

	function dialog:Open()
		self:RefreshCharacters(false)
		if #(self.characters or {}) <= 0 then
			return
		end
		self:Show()
	end

	if UIDropDownMenu_Initialize then
		UIDropDownMenu_Initialize(dialog.dropdown, function()
			for index = 1, #(dialog.characters or {}) do
				local character = dialog.characters[index]
				local info = UIDropDownMenu_CreateInfo()
				info.text = ns.FormatCharacterName(character)
				info.checked = ns.SafeString(character and character.characterKey) == ns.SafeString(dialog.selectedCharacterKey)
				info.func = function()
					dialog.status:SetText("")
					dialog:SetSelectedCharacter(character)
				end
				UIDropDownMenu_AddButton(info)
			end
		end)
	end

	dialog.forgetBtn:SetScript("OnClick", function()
		local ok, reason = ns.DeleteCharacterSnapshot and ns.DeleteCharacterSnapshot(dialog.selectedCharacterKey)
		if ok then
			dialog:Hide()
			if ns.RefreshMainFrame then
				ns.RefreshMainFrame()
			end
			return
		end

		dialog:RefreshCharacters(true)
		dialog.status:SetText(forgetAltErrorText(reason))
	end)

	dialog.cancelBtn:SetScript("OnClick", function()
		dialog:Hide()
	end)

	dialog:SetScript("OnHide", function(self)
		self.status:SetText("")
		self:SetSelectedCharacter(nil)
	end)

	return dialog
end

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
	registerSpecialFrame(frame)

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

	local forgetAltBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	forgetAltBtn:SetSize(ns.UI_FORGET_ALT_BUTTON_WIDTH, ns.UI_DEBUG_BUTTON_HEIGHT)
	forgetAltBtn:SetPoint("RIGHT", close, "LEFT", ns.UI_DEBUG_BUTTON_GAP, 0)
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

	local expansionDrop = CreateFrame("Frame", "RepSheetExpansionDropdown", leftPane, "UIDropDownMenuTemplate")
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

	local sortDrop = CreateFrame("Frame", "RepSheetSortDropdown", leftPane, "UIDropDownMenuTemplate")
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

	local statusDrop = CreateFrame("Frame", "RepSheetStatusDropdown", leftPane, "UIDropDownMenuTemplate")
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

	local listScroll = CreateFrame("ScrollFrame", "RepSheetFactionScroll", leftPane, "UIPanelScrollFrameTemplate")
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

	local debugPane = debugEnabled and ns.UI_CreateDebugPane(frame) or nil
	frame.debugPane = debugPane
	local forgetAltDialog = createForgetAltDialog(frame)
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
