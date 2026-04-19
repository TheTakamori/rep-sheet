RepSheet = RepSheet or {}
local ns = RepSheet
local colors = ns.UI_COLORS
local layout = ns.UI_FORGET_ALT_DIALOG_LAYOUT
local ui = ns.UIHelpers
local widgets = ns.UIWidgets

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

function ns.UI_CreateForgetAltDialog(parent)
	local dialog = CreateFrame("Frame", "RepSheetForgetAltDialog", parent, "BackdropTemplate")
	dialog:SetSize(layout.WIDTH, layout.HEIGHT)
	dialog:SetPoint("CENTER", parent, "CENTER", 0, 0)
	dialog:SetFrameStrata("DIALOG")
	dialog:SetToplevel(true)
	dialog:EnableMouse(true)
	dialog:SetBackdrop(ns.UI_BACKDROPS.PANE)
	ui.ApplyBackdropColors(dialog, colors.PANE_BG, colors.PANE_BORDER)
	dialog:Hide()
	ui.RegisterSpecialFrame(dialog)

	local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", ns.UI_CLOSE_BUTTON_RIGHT, ns.UI_CLOSE_BUTTON_TOP)

	dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	dialog.title:SetPoint("TOPLEFT", dialog, "TOPLEFT", layout.TITLE_LEFT, layout.TITLE_TOP)
	dialog.title:SetText(ns.TEXT.FORGET_ALT_TITLE)
	ui.ApplyTextColor(dialog.title, colors.TEXT_TITLE_MUTED)

	dialog.info = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	dialog.info:SetPoint("TOPLEFT", dialog, "TOPLEFT", layout.INFO_LEFT, layout.INFO_TOP)
	dialog.info:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", layout.INFO_RIGHT, layout.INFO_TOP)
	dialog.info:SetJustifyH("LEFT")
	dialog.info:SetText(ns.TEXT.FORGET_ALT_INFO)
	ui.ApplyTextColor(dialog.info, colors.TEXT_INFO)

	dialog.dropdown = CreateFrame("Frame", "RepSheetForgetAltDropdown", dialog, "UIDropDownMenuTemplate")
	dialog.dropdown:SetPoint("TOPLEFT", dialog, "TOPLEFT", layout.DROPDOWN_LEFT - 14, layout.DROPDOWN_TOP)
	widgets.ConfigureDropdown(dialog.dropdown, layout.DROPDOWN_WIDTH)

	dialog.status = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	dialog.status:SetPoint("TOPLEFT", dialog, "TOPLEFT", layout.STATUS_LEFT, layout.STATUS_TOP)
	dialog.status:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", layout.STATUS_RIGHT, layout.STATUS_TOP)
	dialog.status:SetJustifyH("LEFT")
	ui.ApplyTextColor(dialog.status, colors.TEXT_STATUS)

	dialog.forgetBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	dialog.forgetBtn:SetSize(layout.FORGET_WIDTH, layout.FORGET_HEIGHT)
	dialog.forgetBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", layout.FORGET_RIGHT, layout.BUTTON_BOTTOM)
	dialog.forgetBtn:SetText(ns.TEXT.FORGET)
	dialog.forgetBtn:SetEnabled(false)

	dialog.cancelBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	dialog.cancelBtn:SetSize(layout.CANCEL_WIDTH, layout.CANCEL_HEIGHT)
	dialog.cancelBtn:SetPoint("RIGHT", dialog.forgetBtn, "LEFT", layout.CANCEL_GAP, 0)
	dialog.cancelBtn:SetText(ns.TEXT.CANCEL)

	function dialog:SetSelectedCharacter(character)
		self.selectedCharacter = character
		self.selectedCharacterKey = ns.SafeString(character and character.characterKey)
		ns.UIWidgets.SetDropdownText(
			self.dropdown,
			character and ns.FormatCharacterName(character) or ns.TEXT.FORGET_ALT_SELECT
		)
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

		ui.SetDropdownEnabled(self.dropdown, #self.characters > 0)
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

	widgets.InitializeChoiceDropdown(
		dialog.dropdown,
		function()
			return dialog.characters or {}
		end,
		function()
			return ns.SafeString(dialog.selectedCharacterKey)
		end,
		function(character)
			dialog.status:SetText("")
			dialog:SetSelectedCharacter(character)
		end,
		function(character)
			return ns.FormatCharacterName(character)
		end,
		function(character)
			return ns.SafeString(character and character.characterKey)
		end
	)

	dialog.forgetBtn:SetScript("OnClick", function()
		local ok, reason
		if ns.DeleteCharacterSnapshot then
			ok, reason = ns.DeleteCharacterSnapshot(dialog.selectedCharacterKey)
		end
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
