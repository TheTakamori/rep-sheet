RepSheet = RepSheet or {}
local ns = RepSheet
local helpers = ns.UIHelpers or {}
ns.UIHelpers = helpers

local colors = ns.UI_COLORS
local progressLayout = ns.UI_PROGRESS_BAR_LAYOUT or {}

local function normalizeOverlayVerticalInset(value)
	return math.max(0, ns.SafeNumber(value, progressLayout.VERTICAL_INSET or 1))
end

local function resolveOverlayInsets(overlay, verticalInset)
	local baseInset = normalizeOverlayVerticalInset(progressLayout.VERTICAL_INSET)
	local resolvedVerticalInset = normalizeOverlayVerticalInset(verticalInset)
	local topInset = resolvedVerticalInset
	local bottomInset = resolvedVerticalInset

	if overlay and overlay.alignToBottom == true and resolvedVerticalInset > baseInset then
		-- Keep the shorter stacked layer flush with the lower edge instead of centering it.
		topInset = baseInset + ((resolvedVerticalInset - baseInset) * 2)
		bottomInset = baseInset
	end

	return resolvedVerticalInset, topInset, bottomInset
end

local function createStatusBarOverlay(statusBar, frameLevelOffset, verticalInset, alignToBottom)
	if not statusBar then
		return nil
	end

	local overlay = CreateFrame("StatusBar", nil, statusBar)
	overlay.alignToBottom = alignToBottom == true
	overlay.verticalInset, overlay.topInset, overlay.bottomInset = resolveOverlayInsets(overlay, verticalInset)
	overlay:SetPoint(
		"TOPLEFT",
		statusBar,
		"TOPLEFT",
		ns.SafeNumber(progressLayout.HORIZONTAL_INSET, 1),
		-overlay.topInset
	)
	overlay:SetPoint(
		"BOTTOMRIGHT",
		statusBar,
		"BOTTOMRIGHT",
		-ns.SafeNumber(progressLayout.HORIZONTAL_INSET, 1),
		overlay.bottomInset
	)
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

local function getOverallLayerEnd(source, fallbackFraction)
	if type(source) == "table" and source.isMaxed == true then
		return 0
	end

	return getOverallFraction(source, fallbackFraction)
end

local function getBandLayerRange(source)
	if not sourceUsesBandLayer(source) then
		return 0, 0
	end

	local bandFraction = clampFraction(ns.GetBandOverlayFraction(source))
	if bandFraction <= 0 then
		return 0, 0
	end

	return 0, bandFraction
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

local function applyOverlayRange(statusBar, overlay, startFraction, endFraction, color, verticalInset)
	if not statusBar or not overlay then
		return
	end

	local startValue = clampFraction(startFraction)
	local endValue = clampFraction(endFraction)
	overlay.verticalInset, overlay.topInset, overlay.bottomInset = resolveOverlayInsets(
		overlay,
		verticalInset ~= nil and verticalInset or overlay.verticalInset
	)
	local horizontalInset = ns.SafeNumber(progressLayout.HORIZONTAL_INSET, 1)
	local innerWidth = math.max(0, statusBar:GetWidth() - (horizontalInset * 2))
	if endValue <= startValue or innerWidth <= 0 then
		overlay:Hide()
		return
	end

	overlay:ClearAllPoints()
	overlay:SetPoint(
		"TOPLEFT",
		statusBar,
		"TOPLEFT",
		horizontalInset + (innerWidth * startValue),
		-overlay.topInset
	)
	overlay:SetPoint(
		"BOTTOMLEFT",
		statusBar,
		"BOTTOMLEFT",
		horizontalInset + (innerWidth * startValue),
		overlay.bottomInset
	)
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

	return getOverallFraction(source, baseFraction) > 0
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
	local overlay = createStatusBarOverlay(statusBar, 2, progressLayout.STACKED_VERTICAL_INSET, true)
	if not overlay then
		return nil
	end

	statusBar.bandOverlay = overlay
	return overlay
end

function helpers.CreateParagonOverlay(statusBar)
	local overlay = createStatusBarOverlay(statusBar, 3, progressLayout.STACKED_VERTICAL_INSET, true)
	if not overlay then
		return nil
	end

	statusBar.paragonOverlay = overlay
	return overlay
end

function helpers.CreateOverallOverlay(statusBar)
	local overlay = createStatusBarOverlay(statusBar, 1, progressLayout.VERTICAL_INSET)
	if not overlay then
		return nil
	end

	statusBar.overallOverlay = overlay
	return overlay
end

function helpers.UpdateBandOverlay(statusBar, source)
	local overlay = statusBar and statusBar.bandOverlay
	if not overlay then
		return
	end

	local startFraction, endFraction = getBandLayerRange(source)
	applyOverlayRange(
		statusBar,
		overlay,
		startFraction,
		endFraction,
		colors.STATUS_BAR_BAND or colors.STATUS_BAR_DEFAULT,
		progressLayout.STACKED_VERTICAL_INSET
	)
end

function helpers.UpdateParagonOverlay(statusBar, source)
	local overlay = statusBar and statusBar.paragonOverlay
	if not overlay then
		return
	end

	local startFraction, endFraction = getParagonLayerRange(source)
	applyOverlayRange(
		statusBar,
		overlay,
		startFraction,
		endFraction,
		colors.STATUS_BAR_PARAGON or colors.STATUS_BAR_DEFAULT,
		progressLayout.STACKED_VERTICAL_INSET
	)
end

function helpers.UpdateOverallOverlay(statusBar, source, baseFraction)
	local overlay = statusBar and statusBar.overallOverlay
	if not overlay then
		return
	end

	applyOverlayRange(
		statusBar,
		overlay,
		0,
		getOverallLayerEnd(source, baseFraction),
		colors.STATUS_BAR_DEFAULT,
		progressLayout.VERTICAL_INSET
	)
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
	helpers.UpdateBandOverlay(statusBar, source)
	helpers.UpdateParagonOverlay(statusBar, source)
	helpers.UpdateOverallOverlay(statusBar, source, overallFraction)
end
