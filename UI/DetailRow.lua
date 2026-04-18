RepSheet = RepSheet or {}
local ns = RepSheet
local colors = ns.UI_COLORS
local rowLayout = ns.UI_DETAIL_ROW_LAYOUT
local ui = ns.UIHelpers
local widgets = ns.UIWidgets

local function hideCharacterTooltip(frame)
	if not GameTooltip or GameTooltip:GetOwner() ~= frame then
		return
	end
	GameTooltip:Hide()
end

local function showCharacterTooltip(frame)
	if not frame or not GameTooltip then
		return
	end
	local lines = ns.BuildCharacterHoverTooltipLines(frame.currentEntry)
	if type(lines) ~= "table" or #lines == 0 then
		return
	end

	GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	for index = 1, #lines do
		local line = lines[index]
		GameTooltip:AddLine(line.text, line.r, line.g, line.b, line.wrap == true)
	end
	GameTooltip:Show()
end

function ns.UI_CreateDetailRow(parent, index, cfg)
	cfg = type(cfg) == "table" and cfg or {}

	local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	row:SetSize(parent:GetWidth() - ns.UI_DETAIL_ROW_WIDTH_TRIM, ns.UI_DETAIL_ROW_HEIGHT)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", ns.UI_DETAIL_ROW_INSET_X, ns.UI_DETAIL_ROW_INSET_Y - (index - 1) * ns.UI_DETAIL_ROW_HEIGHT)
	row:SetBackdrop(ns.UI_BACKDROPS.ROW)
	row:SetBackdropColor(colors.DETAIL_ROW_BG[1], colors.DETAIL_ROW_BG[2], colors.DETAIL_ROW_BG[3], colors.DETAIL_ROW_BG[4])
	row:SetBackdropBorderColor(
		colors.DETAIL_ROW_BORDER[1],
		colors.DETAIL_ROW_BORDER[2],
		colors.DETAIL_ROW_BORDER[3],
		colors.DETAIL_ROW_BORDER[4]
	)

	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.name:SetPoint("TOPLEFT", row, "TOPLEFT", rowLayout.NAME_LEFT, rowLayout.NAME_TOP)
	row.name:SetJustifyH("LEFT")

	row.nameHover = CreateFrame("Button", nil, row)
	row.nameHover:SetAllPoints(row.name)
	row.nameHover:RegisterForClicks("LeftButtonUp")
	if not cfg.onNameClick and row.nameHover.SetPropagateMouseClicks then
		row.nameHover:SetPropagateMouseClicks(true)
	end
	row.nameHover:SetScript("OnEnter", showCharacterTooltip)
	row.nameHover:SetScript("OnLeave", hideCharacterTooltip)
	row.nameHover:SetScript("OnHide", hideCharacterTooltip)
	if cfg.onNameClick then
		row.nameHover:SetScript("OnClick", function(button)
			local entry = button.currentEntry
			if entry then
				cfg.onNameClick(entry)
			end
		end)
	end

	row.status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.status:SetPoint("TOPRIGHT", row, "TOPRIGHT", rowLayout.STATUS_RIGHT, rowLayout.STATUS_TOP)
	row.status:SetJustifyH("RIGHT")

	row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	row.meta:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, rowLayout.META_GAP)
	row.meta:SetPoint("TOPRIGHT", row, "TOPRIGHT", rowLayout.META_RIGHT, rowLayout.META_TOP)
	row.meta:SetJustifyH("LEFT")
	ui.ApplyTextColor(row.meta, colors.TEXT_INFO)

	row.progressBar = widgets.CreateProgressBar(row, {
		leftX = rowLayout.PROGRESS_LEFT,
		leftY = rowLayout.PROGRESS_BOTTOM,
		rightX = rowLayout.PROGRESS_RIGHT,
		rightY = rowLayout.PROGRESS_BOTTOM,
		height = rowLayout.PROGRESS_HEIGHT,
		backgroundColor = colors.STATUS_BAR_BG_SOLID,
	})

	if cfg.onRowClick then
		row:EnableMouse(true)
		row:SetScript("OnMouseUp", function(self, button)
			if button ~= "LeftButton" then
				return
			end
			if self.currentEntry then
				cfg.onRowClick(self.currentEntry)
			end
		end)
	end

	row.config = cfg
	return row
end

function ns.UI_ApplyDetailRow(row, entry)
	row.currentEntry = entry

	if not entry then
		if row.nameHover then
			row.nameHover.currentEntry = nil
			hideCharacterTooltip(row.nameHover)
		end
		row:Hide()
		return
	end

	row:Show()
	local statusText = entry.rankText or ns.TEXT.NO_DATA
	local progressText = ns.SafeString(entry.progressText)
	local barValue = ns.SafeNumber(entry.overallFraction, 0)

	local cfg = row.config or {}
	local nameLabelOverride = cfg.formatName and cfg.formatName(entry) or nil

	if nameLabelOverride then
		row.name:SetText(nameLabelOverride.text or "")
		if nameLabelOverride.color then
			ui.ApplyTextColor(row.name, nameLabelOverride.color)
		else
			ui.ApplyTextColor(row.name, colors.TEXT_TITLE)
		end
	elseif entry.isAccountWide then
		row.name:SetText(ns.TEXT.WARBAND)
		ui.ApplyTextColor(row.name, colors.TEXT_TITLE)
	else
		local r, g, b = ns.GetClassColor({ classFile = entry.classFile })
		row.name:SetText(ns.FormatCharacterName(entry))
		row.name:SetTextColor(r, g, b)
	end

	if row.nameHover then
		row.nameHover.currentEntry = entry
		local hoverHidden = entry.isAccountWide
		if cfg.shouldHideHover then
			hoverHidden = cfg.shouldHideHover(entry)
		end
		if hoverHidden then
			row.nameHover:Hide()
		else
			row.nameHover:Show()
		end
	end

	if progressText ~= "" then
		row.status:SetText(ns.FormatStatusWithProgress(statusText, progressText))
	else
		row.status:SetText(statusText)
	end
	row.meta:SetText(entry.paragonRewardPending and ns.TEXT.PARAGON_REWARD_READY or "")
	row.progressBar:Show()
	ui.UpdateProgressBar(row.progressBar, entry, barValue)
end
