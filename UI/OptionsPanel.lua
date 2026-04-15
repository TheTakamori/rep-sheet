RepSheet = RepSheet or {}
local ns = RepSheet

local colors = ns.UI_COLORS
local layout = ns.UI_OPTIONS_LAYOUT
local ui = ns.UIHelpers

local panelState = {
	frame = nil,
	category = nil,
}

local function applyEnabledState(widget, enabled)
	if not widget then
		return
	end

	enabled = enabled == true
	if widget.SetEnabled then
		widget:SetEnabled(enabled)
	elseif enabled and widget.Enable then
		widget:Enable()
	elseif not enabled and widget.Disable then
		widget:Disable()
	end

	if widget.SetAlpha then
		widget:SetAlpha(enabled and 1 or ns.UI_DROPDOWN_DISABLED_ALPHA)
	end

	if widget.Text and widget.Text.SetTextColor then
		local color = enabled and colors.TEXT_LABEL or colors.TEXT_MUTED
		widget.Text:SetTextColor(color[1], color[2], color[3])
	end
end

local function buildUpdatedOptions(current, changes)
	local nextOptions = {}
	for key, value in pairs(current or {}) do
		nextOptions[key] = value
	end
	for key, value in pairs(changes or {}) do
		nextOptions[key] = value
	end
	if nextOptions.noLiveUpdates == true then
		nextOptions.updateAfterCombat = false
		nextOptions.updateOutOfCombat = false
		nextOptions.updatePeriodic = false
	elseif nextOptions.updateAfterCombat ~= true
		and nextOptions.updateOutOfCombat ~= true
		and nextOptions.updatePeriodic ~= true
	then
		nextOptions.noLiveUpdates = true
	end
	return nextOptions
end

local function saveOptions(changes)
	local current = ns.GetLiveUpdateOptions and ns.GetLiveUpdateOptions() or {}
	if ns.SetLiveUpdateOptions then
		ns.SetLiveUpdateOptions(buildUpdatedOptions(current, changes))
	end
end

local function createCheckWithLabel(parent, template, text, anchorTo, relativePoint, offsetX, offsetY)
	local button = CreateFrame("CheckButton", nil, parent, template)
	button:SetPoint("TOPLEFT", anchorTo, relativePoint, offsetX, offsetY)
	button.Text = button.Text or button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	button.Text:SetPoint("LEFT", button, "RIGHT", 2, 0)
	button.Text:SetText(text)
	return button
end

local function applyPeriodicMinutes(editBox)
	if not editBox then
		return
	end

	local current = ns.GetLiveUpdateOptions and ns.GetLiveUpdateOptions() or {}
	local enteredValue = tonumber(editBox:GetText() or "")
	if enteredValue == nil then
		editBox:SetText(tostring(current.periodicMinutes or ns.LIVE_UPDATE_PERIODIC_MINUTES_DEFAULT))
		return
	end

	saveOptions({
		noLiveUpdates = false,
		updatePeriodic = true,
		periodicMinutes = enteredValue,
	})
end

local function createOptionsPanel()
	local frame = CreateFrame("Frame", "RepSheetOptionsPanel", UIParent)
	frame.name = ns.TEXT.OPTIONS_TITLE

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", layout.TITLE_LEFT, layout.TITLE_TOP)
	title:SetText(ns.TEXT.OPTIONS_TITLE)
	ui.ApplyTextColor(title, colors.TEXT_TITLE)

	local sectionTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	sectionTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", layout.SECTION_LEFT, layout.SECTION_TOP)
	sectionTitle:SetText(ns.TEXT.LIVE_UPDATES_TITLE)
	ui.ApplyTextColor(sectionTitle, colors.TEXT_TITLE_MUTED)

	local warning = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	warning:SetPoint("TOPLEFT", frame, "TOPLEFT", layout.WARNING_LEFT, layout.WARNING_TOP)
	warning:SetPoint("TOPRIGHT", frame, "TOPRIGHT", layout.WARNING_RIGHT, layout.WARNING_TOP)
	warning:SetJustifyH("LEFT")
	warning:SetText(ns.TEXT.LIVE_UPDATES_WARNING)
	ui.ApplyTextColor(warning, colors.TEXT_STATUS)

	local noLiveUpdates = createCheckWithLabel(
		frame,
		"UICheckButtonTemplate",
		ns.TEXT.LIVE_UPDATES_NONE,
		frame,
		"TOPLEFT",
		layout.RADIO_LEFT,
		layout.RADIO_TOP
	)

	local afterCombat = createCheckWithLabel(
		frame,
		"UICheckButtonTemplate",
		ns.TEXT.LIVE_UPDATES_AFTER_COMBAT,
		noLiveUpdates,
		"BOTTOMLEFT",
		0,
		layout.CHECKBOX_GAP
	)

	local outOfCombat = createCheckWithLabel(
		frame,
		"UICheckButtonTemplate",
		ns.TEXT.LIVE_UPDATES_OUT_OF_COMBAT,
		afterCombat,
		"BOTTOMLEFT",
		0,
		layout.CHECKBOX_GAP
	)

	local periodic = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	periodic:SetPoint("TOPLEFT", outOfCombat, "BOTTOMLEFT", 0, layout.CHECKBOX_GAP)
	periodic.Text = periodic.Text or periodic:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	periodic.Text:SetPoint("LEFT", periodic, "RIGHT", 0, 0)
	periodic.Text:SetText(ns.TEXT.LIVE_UPDATES_EVERY)

	local periodicInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	periodicInput:SetSize(layout.PERIODIC_INPUT_WIDTH, layout.PERIODIC_INPUT_HEIGHT)
	periodicInput:SetPoint("LEFT", periodic.Text, "RIGHT", layout.PERIODIC_INPUT_GAP, 0)
	periodicInput:SetAutoFocus(false)
	if periodicInput.SetNumeric then
		periodicInput:SetNumeric(true)
	end

	local periodicSuffix = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	periodicSuffix:SetPoint("LEFT", periodicInput, "RIGHT", layout.PERIODIC_SUFFIX_GAP, 0)
	periodicSuffix:SetText(ns.TEXT.LIVE_UPDATES_MINUTES)
	ui.ApplyTextColor(periodicSuffix, colors.TEXT_LABEL)

	frame.noLiveUpdates = noLiveUpdates
	frame.afterCombat = afterCombat
	frame.outOfCombat = outOfCombat
	frame.periodic = periodic
	frame.periodicInput = periodicInput
	frame.periodicSuffix = periodicSuffix

	function frame:RefreshFromDB()
		local options = ns.GetLiveUpdateOptions and ns.GetLiveUpdateOptions() or {}
		self.ignoreCallbacks = true
		noLiveUpdates:SetChecked(options.noLiveUpdates == true)
		afterCombat:SetChecked(options.updateAfterCombat == true)
		outOfCombat:SetChecked(options.updateOutOfCombat == true)
		periodic:SetChecked(options.updatePeriodic == true)
		periodicInput:SetText(tostring(options.periodicMinutes or ns.LIVE_UPDATE_PERIODIC_MINUTES_DEFAULT))

		applyEnabledState(afterCombat, true)
		applyEnabledState(outOfCombat, true)
		applyEnabledState(periodic, true)
		applyEnabledState(periodicInput, options.updatePeriodic == true)
		if periodicSuffix and periodicSuffix.SetTextColor then
			local suffixColor = options.updatePeriodic == true
				and colors.TEXT_LABEL
				or colors.TEXT_MUTED
			periodicSuffix:SetTextColor(suffixColor[1], suffixColor[2], suffixColor[3])
		end
		self.ignoreCallbacks = false
	end

	noLiveUpdates:SetScript("OnClick", function(self)
		if frame.ignoreCallbacks then
			return
		end
		saveOptions({
			noLiveUpdates = self:GetChecked() == true,
		})
		frame:RefreshFromDB()
	end)

	afterCombat:SetScript("OnClick", function(self)
		if frame.ignoreCallbacks then
			return
		end
		saveOptions({
			noLiveUpdates = false,
			updateAfterCombat = self:GetChecked() == true,
		})
		frame:RefreshFromDB()
	end)

	outOfCombat:SetScript("OnClick", function(self)
		if frame.ignoreCallbacks then
			return
		end
		saveOptions({
			noLiveUpdates = false,
			updateOutOfCombat = self:GetChecked() == true,
		})
		frame:RefreshFromDB()
	end)

	periodic:SetScript("OnClick", function(self)
		if frame.ignoreCallbacks then
			return
		end
		saveOptions({
			noLiveUpdates = false,
			updatePeriodic = self:GetChecked() == true,
		})
		frame:RefreshFromDB()
	end)

	periodicInput:SetScript("OnEnterPressed", function(self)
		applyPeriodicMinutes(self)
		self:ClearFocus()
		frame:RefreshFromDB()
	end)
	periodicInput:SetScript("OnEditFocusLost", function(self)
		applyPeriodicMinutes(self)
		frame:RefreshFromDB()
	end)

	frame:SetScript("OnShow", function(self)
		self:RefreshFromDB()
	end)

	return frame
end

local function getOpenCategoryTarget(category)
	if type(category) == "table" and type(category.GetID) == "function" then
		return category:GetID()
	end
	return category
end

function ns.EnsureOptionsPanel()
	if not panelState.frame then
		panelState.frame = createOptionsPanel()
	end

	if panelState.category then
		return panelState.frame, panelState.category
	end

	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		panelState.category = Settings.RegisterCanvasLayoutCategory(panelState.frame, ns.TEXT.OPTIONS_TITLE)
		if panelState.category then
			Settings.RegisterAddOnCategory(panelState.category)
		end
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panelState.frame)
		panelState.category = panelState.frame
	end

	return panelState.frame, panelState.category
end

function ns.OpenOptionsPanel()
	local _, category = ns.EnsureOptionsPanel()
	if not category then
		return false
	end

	if Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(getOpenCategoryTarget(category))
		return true
	end

	if InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(category)
		return true
	end

	return false
end
