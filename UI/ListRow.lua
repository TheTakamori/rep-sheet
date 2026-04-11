AltRepTracker = AltRepTracker or {}
local ns = AltRepTracker
local colors = ns.UI_COLORS
local layout = ns.UI_FACTION_ROW_LAYOUT
local ui = ns.UIHelpers

local function layoutHierarchy(row, depth)
	depth = math.max(0, ns.SafeNumber(depth, 0))
	local indent = depth * layout.TREE_INDENT
	local toggleLeft = layout.CONTENT_LEFT + indent
	local titleLeft = toggleLeft + layout.TOGGLE_RESERVED_WIDTH

	row.expandBtn:ClearAllPoints()
	row.expandBtn:SetPoint("TOPLEFT", row, "TOPLEFT", toggleLeft, layout.TOGGLE_TOP)

	row.title:ClearAllPoints()
	row.title:SetPoint("TOPLEFT", row, "TOPLEFT", titleLeft, layout.TITLE_TOP)
	row.title:SetPoint("TOPRIGHT", row, "TOPRIGHT", layout.TITLE_RIGHT, layout.TITLE_RIGHT_TOP)

	row.meta:ClearAllPoints()
	row.meta:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, layout.META_TOP_GAP)
	row.meta:SetPoint("TOPRIGHT", row, "TOPRIGHT", layout.TITLE_RIGHT, layout.META_TOP_GAP)

	row.best:ClearAllPoints()
	row.best:SetPoint("TOPLEFT", row.meta, "BOTTOMLEFT", 0, layout.BEST_TOP_GAP)
	row.best:SetPoint("TOPRIGHT", row, "TOPRIGHT", layout.BEST_RIGHT, layout.BEST_TOP_GAP)
end

local function setBackdrop(row, selected)
	row:SetBackdrop(ns.UI_BACKDROPS.ROW)

	if selected then
		ui.ApplyBackdropColors(row, colors.ROW_SELECTED_BG, colors.ROW_SELECTED_BORDER)
	else
		ui.ApplyBackdropColors(row, colors.ROW_BG, colors.ROW_BORDER)
	end
end

local function setExpandButtonState(button, collapsed)
	if not button then
		return
	end

	local texturePrefix
	if collapsed then
		texturePrefix = "Interface\\Buttons\\UI-PlusButton-"
	else
		texturePrefix = "Interface\\Buttons\\UI-MinusButton-"
	end

	button:SetNormalTexture(texturePrefix .. "UP")
	button:SetPushedTexture(texturePrefix .. "DOWN")
	button:SetHighlightTexture(texturePrefix .. "Hilight", "ADD")
	button:SetDisabledTexture(texturePrefix .. "Disabled")
end

function ns.UI_CreateFactionRow(parent, index, cfg)
	local rowHeight = cfg.rowHeight or ns.UI_LIST_ROW_HEIGHT
	local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
	row:SetSize(math.max(ns.UI_LIST_MIN_WIDTH, parent:GetWidth() - layout.OUTER_WIDTH_TRIM), rowHeight - layout.OUTER_HEIGHT_TRIM)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", ns.UI_LIST_CHILD_X, ns.UI_LIST_CHILD_Y - (index - 1) * rowHeight)
	row:RegisterForClicks("LeftButtonUp")
	row:SetClipsChildren(true)
	setBackdrop(row, false)

	local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", row, "TOPLEFT", layout.CONTENT_LEFT, layout.TITLE_TOP)
	title:SetPoint("TOPRIGHT", row, "TOPRIGHT", layout.TITLE_RIGHT, layout.TITLE_RIGHT_TOP)
	title:SetJustifyH("LEFT")
	ui.ApplyTextColor(title, colors.TEXT_TITLE)
	ui.SetSingleLine(title)
	row.title = title

	local expandBtn = CreateFrame("Button", nil, row)
	expandBtn:SetSize(layout.TOGGLE_SIZE, layout.TOGGLE_SIZE)
	expandBtn:RegisterForClicks("LeftButtonUp")
	if expandBtn.SetHitRectInsets then
		expandBtn:SetHitRectInsets(-6, -6, -5, -5)
	end
	setExpandButtonState(expandBtn, false)
	expandBtn:SetScript("OnClick", function()
		if cfg.onToggleCollapse and row.factionKey and row.treeHasChildren then
			cfg.onToggleCollapse(row.factionKey)
		end
	end)
	row.expandBtn = expandBtn

	local meta = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	meta:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, layout.META_TOP_GAP)
	meta:SetPoint("TOPRIGHT", row, "TOPRIGHT", layout.TITLE_RIGHT, layout.META_TOP_GAP)
	meta:SetJustifyH("LEFT")
	ui.ApplyTextColor(meta, colors.TEXT_MUTED)
	ui.SetSingleLine(meta)
	row.meta = meta

	local best = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	best:SetPoint("TOPLEFT", meta, "BOTTOMLEFT", 0, layout.BEST_TOP_GAP)
	best:SetPoint("TOPRIGHT", row, "TOPRIGHT", layout.BEST_RIGHT, layout.BEST_TOP_GAP)
	best:SetJustifyH("LEFT")
	ui.ApplyTextColor(best, colors.TEXT_ACCENT)
	ui.SetSingleLine(best)
	row.best = best

	local coverage = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	coverage:SetPoint("TOPRIGHT", row, "TOPRIGHT", layout.COVERAGE_RIGHT, layout.COVERAGE_TOP)
	coverage:SetWidth(layout.COVERAGE_WIDTH)
	coverage:SetJustifyH("RIGHT")
	ui.ApplyTextColor(coverage, colors.TEXT_STATUS)
	ui.SetSingleLine(coverage)
	row.coverage = coverage

	local progressBar = CreateFrame("StatusBar", nil, row)
	progressBar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", layout.PROGRESS_LEFT, layout.PROGRESS_BOTTOM)
	progressBar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", layout.PROGRESS_RIGHT, layout.PROGRESS_BOTTOM)
	progressBar:SetHeight(layout.PROGRESS_HEIGHT)
	progressBar:SetStatusBarTexture(ns.UI_TEXTURES.STATUS_BAR)
	progressBar:GetStatusBarTexture():SetHorizTile(false)
	progressBar:SetMinMaxValues(0, 1)
	progressBar.bg = progressBar:CreateTexture(nil, "BACKGROUND")
	progressBar.bg:SetAllPoints()
	progressBar.bg:SetColorTexture(
		colors.STATUS_BAR_BG[1],
		colors.STATUS_BAR_BG[2],
		colors.STATUS_BAR_BG[3],
		colors.STATUS_BAR_BG[4]
	)
	ui.CreateParagonOverlay(progressBar)
	progressBar.paragonOverlay:GetStatusBarTexture():SetHorizTile(false)
	row.progressBar = progressBar

	local progressText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	progressText:SetPoint("LEFT", progressBar, "RIGHT", layout.PROGRESS_TEXT_GAP, 0)
	progressText:SetPoint("RIGHT", row, "RIGHT", layout.PROGRESS_TEXT_RIGHT, 0)
	progressText:SetJustifyH("RIGHT")
	ui.ApplyTextColor(progressText, colors.TEXT_SUBTITLE)
	ui.SetSingleLine(progressText)
	row.progressText = progressText

	local favoriteBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	favoriteBtn:SetSize(layout.FAVORITE_WIDTH, layout.FAVORITE_HEIGHT)
	favoriteBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", layout.FAVORITE_RIGHT, layout.FAVORITE_TOP)
	row.favoriteBtn = favoriteBtn

	favoriteBtn:SetScript("OnClick", function()
		if cfg.onFavoriteToggle and row.factionKey then
			cfg.onFavoriteToggle(row.factionKey)
		end
	end)

	row:SetScript("OnClick", function()
		if cfg.onClick and row.factionKey then
			cfg.onClick(row.factionKey)
		end
	end)

	return row
end

function ns.UI_ApplyFactionRow(row, bucket, selected)
	if not bucket then
		row:Hide()
		return
	end

	row:Show()
	row.factionKey = bucket.factionKey
	row.treeHasChildren = bucket.treeHasChildren == true
	layoutHierarchy(row, bucket.treeDepth)

	if row.treeHasChildren then
		setExpandButtonState(row.expandBtn, bucket.treeCollapsed)
		row.expandBtn:Show()
	else
		row.expandBtn:Hide()
	end

	row.title:SetText(bucket.name or ns.TEXT.UNKNOWN_FACTION)
	row.meta:SetText(string.format(ns.FORMAT.DETAIL_SUBTITLE, bucket.expansionName or ns.TEXT.UNKNOWN, bucket.repTypeLabel or ns.TEXT.REPUTATION))

	local trackedText
	if bucket.isAccountWide then
		trackedText = ns.TEXT.WARBAND
	elseif bucket.anyMissing then
		trackedText = string.format(ns.FORMAT.ALTS_TRACKED, bucket.capturedCount or 0, bucket.totalCharacters or 0)
			.. "  "
			.. ns.TEXT.MISSING
	else
		trackedText = string.format(ns.FORMAT.ALTS_TRACKED, bucket.capturedCount or 0, bucket.totalCharacters or 0)
	end
	row.coverage:SetText(trackedText)

	row.best:SetText(string.format(ns.FORMAT.BEST_CHARACTER, bucket.bestCharacterName or ns.TEXT.UNKNOWN))
	row.progressBar:SetValue(ns.SafeNumber(bucket.bestOverallFraction, 0))
	if bucket.isAccountWide then
		row.progressText:SetText(ns.FormatPercent(bucket.bestOverallFraction or 0))
	else
		row.progressText:SetText(string.format(ns.FORMAT.PROGRESS_SUMMARY, ns.FormatPercent(bucket.bestOverallFraction or 0), bucket.maxedCount or 0))
	end
	row.favoriteBtn:SetText(ns.IsFavoriteFaction(bucket.factionKey) and ns.TEXT.FAVORITE_SHORT or ns.TEXT.FAVORITE_SHORT_ADD)

	if ns.IsVisuallyMaxed(bucket.bestOverallFraction) then
		ui.ApplyStatusBarColor(row.progressBar, colors.STATUS_BAR_MAXED)
	else
		ui.ApplyStatusBarColor(row.progressBar, colors.STATUS_BAR_DEFAULT)
	end
	ui.UpdateParagonOverlay(row.progressBar, bucket.bestEntry)

	setBackdrop(row, selected)
end
