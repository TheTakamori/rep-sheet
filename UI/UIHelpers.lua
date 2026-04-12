RepSheet = RepSheet or {}
local ns = RepSheet
local helpers = ns.UIHelpers or {}
ns.UIHelpers = helpers

local colors = ns.UI_COLORS

local function createStatusBarOverlay(statusBar, frameLevelOffset)
	if not statusBar then
		return nil
	end

	local overlay = CreateFrame("StatusBar", nil, statusBar)
	overlay:SetPoint("TOPLEFT", statusBar, "TOPLEFT", 1, -1)
	overlay:SetPoint("BOTTOMRIGHT", statusBar, "BOTTOMRIGHT", -1, 1)
	overlay:SetStatusBarTexture(ns.UI_TEXTURES.STATUS_BAR)
	overlay:SetMinMaxValues(0, 1)
	overlay:SetFrameLevel(statusBar:GetFrameLevel() + ns.SafeNumber(frameLevelOffset, 1))

	local texture = overlay:GetStatusBarTexture()
	if texture and texture.SetHorizTile then
		texture:SetHorizTile(false)
	end

	overlay:Hide()
	return overlay
end

local function clampFraction(value)
	return ns.Clamp(ns.SafeNumber(value, 0), 0, 1)
end

local function getOverallFraction(source, fallbackFraction)
	if type(source) == "table" and source.overallFraction ~= nil then
		return clampFraction(source.overallFraction)
	end
	return clampFraction(fallbackFraction)
end

local function sourceUsesBandLayer(source)
	if type(source) ~= "table" or source.isMaxed == true then
		return false
	end

	local maxValue = ns.SafeNumber(source.maxValue, 0)
	if maxValue <= 0 then
		return false
	end

	if source.repType == ns.REP_TYPE.MAJOR then
		return ns.SafeNumber(source.renownMaxLevel, 0) > 0
	end
	if source.repType == ns.REP_TYPE.FRIENDSHIP then
		return ns.SafeNumber(source.friendMaxRank, 0) > 0
	end

	return ns.SafeNumber(source.standingId, 0) > 0
end

local function getCompletedLayerFraction(source, fallbackFraction)
	if not sourceUsesBandLayer(source) then
		return 0
	end

	local overall = getOverallFraction(source, fallbackFraction)
	local completed = 0

	if source.repType == ns.REP_TYPE.MAJOR then
		local currentLevel = ns.SafeNumber(source.renownLevel, 0)
		local maxLevel = ns.SafeNumber(source.renownMaxLevel, 0)
		if maxLevel > 0 and currentLevel > 1 then
			completed = (currentLevel - 1) / maxLevel
		end
	elseif source.repType == ns.REP_TYPE.FRIENDSHIP then
		local currentRank = ns.SafeNumber(source.friendCurrentRank, 0)
		local maxRank = ns.SafeNumber(source.friendMaxRank, 0)
		if maxRank > 0 and currentRank > 1 then
			completed = (currentRank - 1) / maxRank
		end
	else
		local standingId = ns.SafeNumber(source.standingId, 0)
		if standingId > 1 then
			completed = (standingId - 1) / ns.MAX_STANDARD_STANDING_ID
		end
	end

	return math.min(overall, clampFraction(completed))
end

local function getOverallLayerEnd(source, fallbackFraction)
	if type(source) == "table" and source.isMaxed == true then
		return 0
	end

	local overall = getOverallFraction(source, fallbackFraction)
	if sourceUsesBandLayer(source) then
		return getCompletedLayerFraction(source, overall)
	end
	return overall
end

local function getBandLayerRange(source, fallbackFraction)
	if not sourceUsesBandLayer(source) then
		return 0, 0
	end

	local overall = getOverallFraction(source, fallbackFraction)
	if overall <= 0 then
		return 0, 0
	end

	local startFraction = getCompletedLayerFraction(source, overall)
	return startFraction, math.max(startFraction, overall)
end

local function getParagonLayerRange(source)
	if type(source) ~= "table" or source.isMaxed ~= true or source.hasParagon ~= true then
		return 0, 0
	end
	if ns.SafeNumber(source.paragonThreshold, 0) <= 0 then
		return 0, 0
	end

	return 0, clampFraction(ns.GetParagonOverlayFraction(source))
end

local function applyOverlayRange(statusBar, overlay, startFraction, endFraction, color)
	if not statusBar or not overlay then
		return
	end

	local startValue = clampFraction(startFraction)
	local endValue = clampFraction(endFraction)
	local innerWidth = math.max(0, statusBar:GetWidth() - 2)
	if endValue <= startValue or innerWidth <= 0 then
		overlay:Hide()
		return
	end

	overlay:ClearAllPoints()
	overlay:SetPoint("TOPLEFT", statusBar, "TOPLEFT", 1 + (innerWidth * startValue), -1)
	overlay:SetPoint("BOTTOMLEFT", statusBar, "BOTTOMLEFT", 1 + (innerWidth * startValue), 1)
	overlay:SetWidth(innerWidth * (endValue - startValue))
	overlay:SetValue(1)
	helpers.ApplyStatusBarColor(overlay, color)
	overlay:Show()
end

local function hideOwnedTooltip(frame)
	if not GameTooltip or GameTooltip:GetOwner() ~= frame then
		return
	end
	GameTooltip:Hide()
end

local function addProgressTooltipLine(text, color)
	if not GameTooltip or type(text) ~= "string" or text == "" or not color then
		return
	end
	GameTooltip:AddLine(text, color[1], color[2], color[3], true)
end

local function setTooltipStyle(tooltip)
	if not tooltip then
		return
	end

	local backgroundColor = colors.TOOLTIP_BG or colors.PANE_BG
	if backgroundColor and tooltip.SetBackdropColor then
		tooltip:SetBackdropColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4])
	end

	local borderColor = colors.TOOLTIP_BORDER or colors.PANE_BORDER
	if borderColor and tooltip.SetBackdropBorderColor then
		tooltip:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
	end
end

local function shouldShowOverallLegend(source, baseFraction, isBaseMaxed)
	if isBaseMaxed then
		return false
	end

	if sourceUsesBandLayer(source) then
		return getCompletedLayerFraction(source, baseFraction) > 0
	end

	return true
end

local function shouldShowBandLegend(source, _, isBaseMaxed)
	if isBaseMaxed or type(source) ~= "table" then
		return false
	end

	return sourceUsesBandLayer(source)
end

local function shouldShowParagonLegend(source, isBaseMaxed)
	if not isBaseMaxed or type(source) ~= "table" or source.hasParagon ~= true then
		return false
	end

	return ns.SafeNumber(source.paragonThreshold, 0) > 0
end

function helpers.ApplyTextColor(fontString, color)
	if fontString and color then
		fontString:SetTextColor(color[1], color[2], color[3])
	end
end

function helpers.ApplyBackdropColors(frame, backgroundColor, borderColor)
	if not frame then
		return
	end
	if backgroundColor then
		frame:SetBackdropColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4])
	end
	if borderColor then
		frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
	end
end

function helpers.ApplyStatusBarColor(statusBar, color)
	if statusBar and color then
		statusBar:SetStatusBarColor(color[1], color[2], color[3])
	end
end

function helpers.SetSingleLine(fontString)
	if not fontString then
		return
	end
	if fontString.SetWordWrap then
		fontString:SetWordWrap(false)
	end
	if fontString.SetNonSpaceWrap then
		fontString:SetNonSpaceWrap(false)
	end
	if fontString.SetMaxLines then
		fontString:SetMaxLines(1)
	end
end

function helpers.RegisterSpecialFrame(frame)
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

function helpers.SetDropdownEnabled(dropdown, enabled)
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
	dropdown:SetAlpha(enabled and 1 or ns.UI_DROPDOWN_DISABLED_ALPHA)
end

function helpers.SetProgressBarTooltipData(statusBar, source, baseFraction)
	if not statusBar then
		return
	end

	statusBar.tooltipSource = source
	statusBar.tooltipBaseFraction = ns.SafeNumber(baseFraction, 0)
end

function helpers.AttachProgressBarTooltip(statusBar)
	if not statusBar then
		return
	end

	statusBar:EnableMouse(true)
	if statusBar.SetPropagateMouseClicks then
		statusBar:SetPropagateMouseClicks(true)
	end
	statusBar:SetScript("OnEnter", function(self)
		if not GameTooltip then
			return
		end

		local baseFraction = ns.SafeNumber(self.tooltipBaseFraction, 0)
		local source = self.tooltipSource
		local overallFraction = getOverallFraction(source, baseFraction)
		local isBaseMaxed = (type(source) == "table" and source.isMaxed == true) or ns.IsVisuallyMaxed(overallFraction)

		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
		GameTooltip:ClearLines()
		setTooltipStyle(GameTooltip)
		GameTooltip:AddLine(
			ns.TEXT.PROGRESS_BAR_TOOLTIP_TITLE,
			colors.TEXT_TITLE[1],
			colors.TEXT_TITLE[2],
			colors.TEXT_TITLE[3]
		)
		if isBaseMaxed then
			addProgressTooltipLine(ns.TEXT.PROGRESS_BAR_TOOLTIP_MAXED, colors.STATUS_BAR_MAXED)
		elseif shouldShowOverallLegend(source, overallFraction, isBaseMaxed) then
			addProgressTooltipLine(ns.TEXT.PROGRESS_BAR_TOOLTIP_OVERALL, colors.STATUS_BAR_DEFAULT)
		end
		if shouldShowBandLegend(source, overallFraction, isBaseMaxed) then
			addProgressTooltipLine(ns.TEXT.PROGRESS_BAR_TOOLTIP_BAND, colors.STATUS_BAR_BAND)
		end
		if shouldShowParagonLegend(source, isBaseMaxed) then
			addProgressTooltipLine(ns.TEXT.PROGRESS_BAR_TOOLTIP_PARAGON, colors.STATUS_BAR_PARAGON)
		end
		GameTooltip:Show()
	end)
	statusBar:SetScript("OnLeave", hideOwnedTooltip)
	statusBar:SetScript("OnHide", hideOwnedTooltip)
end

function helpers.CreateBandOverlay(statusBar)
	local overlay = createStatusBarOverlay(statusBar, 1)
	if not overlay then
		return nil
	end

	statusBar.bandOverlay = overlay
	return overlay
end

function helpers.CreateParagonOverlay(statusBar)
	local overlay = createStatusBarOverlay(statusBar, 2)
	if not overlay then
		return nil
	end

	statusBar.paragonOverlay = overlay
	return overlay
end

function helpers.CreateOverallOverlay(statusBar)
	local overlay = createStatusBarOverlay(statusBar, 3)
	if not overlay then
		return nil
	end

	statusBar.overallOverlay = overlay
	return overlay
end

function helpers.UpdateBandOverlay(statusBar, source, baseFraction)
	local overlay = statusBar and statusBar.bandOverlay
	if not overlay then
		return
	end

	local startFraction, endFraction = getBandLayerRange(source, baseFraction)
	applyOverlayRange(statusBar, overlay, startFraction, endFraction, colors.STATUS_BAR_BAND or colors.STATUS_BAR_DEFAULT)
end

function helpers.UpdateParagonOverlay(statusBar, source)
	local overlay = statusBar and statusBar.paragonOverlay
	if not overlay then
		return
	end

	local startFraction, endFraction = getParagonLayerRange(source)
	applyOverlayRange(statusBar, overlay, startFraction, endFraction, colors.STATUS_BAR_PARAGON or colors.STATUS_BAR_DEFAULT)
end

function helpers.UpdateOverallOverlay(statusBar, source, baseFraction)
	local overlay = statusBar and statusBar.overallOverlay
	if not overlay then
		return
	end

	applyOverlayRange(statusBar, overlay, 0, getOverallLayerEnd(source, baseFraction), colors.STATUS_BAR_DEFAULT)
end

function helpers.UpdateProgressBar(statusBar, source, baseFraction)
	if not statusBar then
		return
	end

	local overallFraction = getOverallFraction(source, baseFraction)
	local isBaseMaxed = (type(source) == "table" and source.isMaxed == true) or ns.IsVisuallyMaxed(overallFraction)

	if isBaseMaxed then
		statusBar:SetValue(1)
		helpers.ApplyStatusBarColor(statusBar, colors.STATUS_BAR_MAXED or colors.STATUS_BAR_DEFAULT)
	else
		statusBar:SetValue(0)
		helpers.ApplyStatusBarColor(statusBar, colors.STATUS_BAR_MAXED or colors.STATUS_BAR_DEFAULT)
	end

	helpers.SetProgressBarTooltipData(statusBar, source, overallFraction)
	helpers.UpdateBandOverlay(statusBar, source, overallFraction)
	helpers.UpdateParagonOverlay(statusBar, source)
	helpers.UpdateOverallOverlay(statusBar, source, overallFraction)
end
