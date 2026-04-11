RepSheet = RepSheet or {}
local ns = RepSheet
local colors = ns.UI_COLORS
local layout = ns.UI_DEBUG_PANE_LAYOUT
local ui = ns.UIHelpers
local CLEAR_ALL_DATA_DIALOG_KEY = "REPSHEET_CLEAR_ALL_DATA_CONFIRM"

local function paneWidth()
	return ns.UI_FRAME_WIDTH - (ns.UI_FRAME_SIDE_INSET * 2)
end

local function scrollChildWidth()
	return paneWidth() - layout.SCROLL_LEFT + layout.SCROLL_RIGHT
end

local function textBoxWidth(totalWidth)
	return math.max(1, totalWidth - layout.TEXT_LEFT + layout.TEXT_RIGHT)
end

local function scrollToBottom(scroll)
	if not scroll then
		return
	end
	scroll:SetVerticalScroll(scroll:GetVerticalScrollRange() or 0)
end

local function measureTextHeight(measurer, text, width, minHeight, padding)
	if not measurer then
		return minHeight
	end

	measurer:SetWidth(math.max(1, width))
	measurer:SetText(text or "")
	return math.max(minHeight, measurer:GetStringHeight() + padding)
end

local function restoreLogText(editBox)
	if not editBox then
		return
	end
	editBox._restoring = true
	editBox:SetText(editBox._displayText or "")
	editBox._restoring = false
end

local function showClearAllDataConfirm(pane)
	if not pane or not pane.ClearAllData then
		return
	end

	if not (StaticPopupDialogs and StaticPopup_Show) then
		pane:ClearAllData()
		return
	end

	StaticPopupDialogs[CLEAR_ALL_DATA_DIALOG_KEY] = StaticPopupDialogs[CLEAR_ALL_DATA_DIALOG_KEY] or {
		text = ns.TEXT.CLEAR_ALL_DATA_CONFIRM,
		button1 = YES,
		button2 = CANCEL,
		OnAccept = function(self, data)
			local target = data or (self and self.data)
			if target and target.ClearAllData then
				target:ClearAllData()
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}

	StaticPopup_Show(CLEAR_ALL_DATA_DIALOG_KEY, nil, nil, pane)
end

function ns.UI_CreateDebugPane(parent)
	local pane = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	pane:SetPoint("TOPLEFT", parent, "TOPLEFT", ns.UI_FRAME_SIDE_INSET, ns.UI_FRAME_TOP_OFFSET)
	pane:SetSize(paneWidth(), ns.UI_FRAME_HEIGHT - ns.UI_PANE_HEIGHT_TRIM)
	pane:SetBackdrop(ns.UI_BACKDROPS.PANE)
	ui.ApplyBackdropColors(pane, colors.PANE_BG, colors.PANE_BORDER)

	pane.title = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	pane.title:SetPoint("TOPLEFT", pane, "TOPLEFT", layout.TITLE_LEFT, layout.TITLE_TOP)
	pane.title:SetText(ns.TEXT.DEBUG_TITLE)
	ui.ApplyTextColor(pane.title, colors.TEXT_TITLE_MUTED)

	pane.info = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	pane.info:SetPoint("TOPLEFT", pane, "TOPLEFT", layout.INFO_LEFT, layout.INFO_TOP)
	pane.info:SetPoint("TOPRIGHT", pane, "TOPRIGHT", layout.INFO_RIGHT, layout.INFO_TOP)
	pane.info:SetJustifyH("LEFT")
	pane.info:SetText(ns.TEXT.DEBUG_INFO)
	ui.ApplyTextColor(pane.info, colors.TEXT_INFO)

	pane.clearBtn = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
	pane.clearBtn:SetSize(layout.CLEAR_WIDTH, layout.CLEAR_HEIGHT)
	pane.clearBtn:SetPoint("TOPRIGHT", pane, "TOPRIGHT", layout.CLEAR_RIGHT, layout.CLEAR_TOP)
	pane.clearBtn:SetText(ns.TEXT.CLEAR_LOG)

	pane.scanBtn = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
	pane.scanBtn:SetSize(layout.SCAN_WIDTH, layout.SCAN_HEIGHT)
	pane.scanBtn:SetPoint("RIGHT", pane.clearBtn, "LEFT", layout.SCAN_GAP, 0)
	pane.scanBtn:SetText(ns.TEXT.SCAN_AND_LOG)

	pane.wipeBtn = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
	pane.wipeBtn:SetSize(layout.WIPE_WIDTH, layout.WIPE_HEIGHT)
	pane.wipeBtn:SetPoint("RIGHT", pane.scanBtn, "LEFT", layout.WIPE_GAP, 0)
	pane.wipeBtn:SetText(ns.TEXT.CLEAR_ALL_DATA)

	pane.scroll = CreateFrame("ScrollFrame", "RepSheetDebugPaneScroll", pane, "UIPanelScrollFrameTemplate")
	pane.scroll:SetPoint("TOPLEFT", pane, "TOPLEFT", layout.SCROLL_LEFT, layout.SCROLL_TOP)
	pane.scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", layout.SCROLL_RIGHT, layout.SCROLL_BOTTOM)
	pane.scroll:EnableMouseWheel(true)
	pane.scroll:SetScript("OnMouseWheel", function(self, delta)
		local current = self:GetVerticalScroll() or 0
		local range = self:GetVerticalScrollRange() or 0
		self:SetVerticalScroll(ns.Clamp(current - delta * 32, 0, range))
	end)

	pane.scrollChild = CreateFrame("Frame", nil, pane.scroll)
	pane.scrollChild:SetSize(scrollChildWidth(), layout.SCROLL_CHILD_MIN_HEIGHT)
	pane.scroll:SetScrollChild(pane.scrollChild)

	pane.measureText = pane:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
	pane.measureText:SetPoint("TOPLEFT", pane, "BOTTOMLEFT", 0, -1024)
	pane.measureText:SetJustifyH("LEFT")
	pane.measureText:SetJustifyV("TOP")
	pane.measureText:SetAlpha(0)

	pane.logBox = CreateFrame("EditBox", nil, pane.scrollChild)
	pane.logBox:SetMultiLine(true)
	pane.logBox:SetAutoFocus(false)
	pane.logBox:SetFontObject(ChatFontNormal)
	pane.logBox:SetPoint("TOPLEFT", pane.scrollChild, "TOPLEFT", layout.TEXT_LEFT, layout.TEXT_TOP)
	pane.logBox:SetJustifyH("LEFT")
	pane.logBox:SetJustifyV("TOP")
	pane.logBox:SetTextColor(colors.TEXT_INFO[1], colors.TEXT_INFO[2], colors.TEXT_INFO[3])
	pane.logBox:EnableMouse(true)
	pane.logBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		local owner = pane and pane:GetParent()
		if owner and owner.Hide then
			owner:Hide()
		end
	end)
	pane.logBox:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)
	pane.logBox:SetScript("OnMouseUp", function(self)
		self:SetFocus()
		self:HighlightText()
	end)
	pane.logBox:SetScript("OnTextChanged", function(self, userInput)
		if self._restoring then
			return
		end
		if userInput then
			restoreLogText(self)
			self:SetFocus()
			self:HighlightText()
		end
	end)

	function pane:ClearLog()
		ns.ClearDebugLog()
	end

	function pane:RunDebugScan()
		ns.ClearDebugLog()
		ns.DebugLog("Debug scan requested from debug page.")
		if ns.RequestReputationScan then
			ns.RequestReputationScan(ns.SCAN_REASON.MANUAL_REFRESH, true)
		else
			ns.ScanCurrentCharacter(ns.SCAN_REASON.MANUAL_REFRESH)
		end
	end

	function pane:ClearAllData()
		ns.ClearDebugLog()
		local clearedCharacters = 0
		if ns.ClearStoredReputationData then
			clearedCharacters = ns.ClearStoredReputationData()
		end
		ns.DebugLog(string.format(
			"Cleared all stored character reputation data. Characters removed=%s",
			ns.DebugValueText(clearedCharacters)
		))
		if ns.RefreshMainFrame then
			ns.RefreshMainFrame()
		end
	end

	function pane:Refresh()
		local text = ns.GetDebugLogText()
		if text == "" then
			text = ns.TEXT.DEBUG_EMPTY_HINT
		end

		local childWidth = scrollChildWidth()
		local width = textBoxWidth(childWidth)
		local height = measureTextHeight(self.measureText, text, width, layout.SCROLL_CHILD_MIN_HEIGHT, layout.SCROLL_CHILD_PADDING)

		self.scrollChild:SetSize(childWidth, height)
		self.logBox:SetSize(width, height)
		self.logBox._displayText = text
		restoreLogText(self.logBox)

		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				if pane and pane.scroll and pane:IsShown() then
					scrollToBottom(pane.scroll)
				end
			end)
		else
			scrollToBottom(self.scroll)
		end
	end

	pane.clearBtn:SetScript("OnClick", function()
		pane:ClearLog()
	end)

	pane.scanBtn:SetScript("OnClick", function()
		pane:RunDebugScan()
	end)

	pane.wipeBtn:SetScript("OnClick", function()
		showClearAllDataConfirm(pane)
	end)

	local listenerKey = {}
	ns.RegisterDebugListener(listenerKey, function()
		if pane.Refresh then
			pane:Refresh()
		end
	end)

	pane:SetScript("OnShow", function()
		pane:Refresh()
	end)

	pane:Hide()
	return pane
end
