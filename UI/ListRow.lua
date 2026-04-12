RepSheet = RepSheet or {}
local ns = RepSheet
local colors = ns.UI_COLORS
local layout = ns.UI_FACTION_ROW_LAYOUT
local ui = ns.UIHelpers
local widgets = ns.UIWidgets
local FAVORITE_ICON_TEXTURE = "Interface\\Common\\FavoritesIcon"
local FAVORITE_ICON_COORDS = { 0.125, 0.71875, 0.09375, 0.6875 }
local FAVORITE_ICON_ATLAS = "PetJournal-FavoritesIcon"

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

local function hideFavoriteTooltip(frame)
	if not GameTooltip or GameTooltip:GetOwner() ~= frame then
		return
	end
	GameTooltip:Hide()
end

local function setFavoriteIconTexture(texture)
	if not texture then
		return
	end

	local usedAtlas = false
	if texture.SetAtlas then
		usedAtlas = texture:SetAtlas(FAVORITE_ICON_ATLAS)
	end

	if usedAtlas then
		texture:SetTexCoord(0, 1, 0, 1)
		return
	end

	texture:SetTexture(FAVORITE_ICON_TEXTURE)
	texture:SetTexCoord(
		FAVORITE_ICON_COORDS[1],
		FAVORITE_ICON_COORDS[2],
		FAVORITE_ICON_COORDS[3],
		FAVORITE_ICON_COORDS[4]
	)
end

local function applyFavoriteButtonState(button, isFavorite, isHovered)
	if not button or not button.icon then
		return
	end

	isFavorite = isFavorite == true
	button.isFavorite = isFavorite

	local color = isFavorite and (colors.FAVORITE_HEART_ACTIVE or colors.TEXT_ACCENT)
		or (colors.FAVORITE_HEART_INACTIVE or colors.TEXT_MUTED)
	local alpha = isHovered and 1 or (isFavorite and 1 or 0.92)
	button.icon:SetVertexColor(color[1], color[2], color[3], alpha)
	if button.icon.SetDesaturated then
		button.icon:SetDesaturated(not isFavorite)
	end
end

local function showFavoriteTooltip(button)
	if not button or not GameTooltip then
		return
	end

	GameTooltip:SetOwner(button, "ANCHOR_LEFT")
	local tooltipColor = ns.UI_FAVORITE_TOOLTIP_COLOR or ns.FALLBACK_CLASS_COLOR
	GameTooltip:SetText(
		button.isFavorite and ns.TEXT.UNFAVORITE or ns.TEXT.FAVORITE,
		tooltipColor[1],
		tooltipColor[2],
		tooltipColor[3]
	)
	GameTooltip:Show()
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
	widgets.ApplyHitRectInsets(expandBtn, ns.UI_FACTION_TOGGLE_HIT_INSETS)
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

	local progressBar = widgets.CreateProgressBar(row, {
		leftX = layout.PROGRESS_LEFT,
		leftY = layout.PROGRESS_BOTTOM,
		rightX = layout.PROGRESS_RIGHT,
		rightY = layout.PROGRESS_BOTTOM,
		height = layout.PROGRESS_HEIGHT,
		backgroundColor = colors.STATUS_BAR_BG,
		horizTile = false,
	})
	row.progressBar = progressBar

	local progressText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	progressText:SetPoint("LEFT", progressBar, "RIGHT", layout.PROGRESS_TEXT_GAP, 0)
	progressText:SetPoint("RIGHT", row, "RIGHT", layout.PROGRESS_TEXT_RIGHT, 0)
	progressText:SetJustifyH("RIGHT")
	ui.ApplyTextColor(progressText, colors.TEXT_SUBTITLE)
	ui.SetSingleLine(progressText)
	row.progressText = progressText

	local favoriteBtn = CreateFrame("Button", nil, row)
	favoriteBtn:SetSize(layout.FAVORITE_WIDTH, layout.FAVORITE_HEIGHT)
	favoriteBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", layout.FAVORITE_RIGHT, layout.FAVORITE_TOP)
	favoriteBtn:RegisterForClicks("LeftButtonUp")
	widgets.ApplyHitRectInsets(favoriteBtn, ns.UI_FAVORITE_BUTTON_HIT_INSETS)
	favoriteBtn.highlight = favoriteBtn:CreateTexture(nil, "HIGHLIGHT")
	favoriteBtn.highlight:SetAllPoints()
	favoriteBtn.highlight:SetColorTexture(1, 1, 1, 0.06)
	favoriteBtn.icon = favoriteBtn:CreateTexture(nil, "OVERLAY")
	favoriteBtn.icon:SetSize(layout.FAVORITE_WIDTH, layout.FAVORITE_HEIGHT)
	favoriteBtn.icon:SetPoint("CENTER", favoriteBtn, "CENTER", 0, 0)
	setFavoriteIconTexture(favoriteBtn.icon)
	applyFavoriteButtonState(favoriteBtn, false, false)
	row.favoriteBtn = favoriteBtn

	favoriteBtn:SetScript("OnClick", function()
		if cfg.onFavoriteToggle and row.factionKey then
			cfg.onFavoriteToggle(row.factionKey)
		end
	end)
	favoriteBtn:SetScript("OnEnter", function(self)
		applyFavoriteButtonState(self, self.isFavorite, true)
		showFavoriteTooltip(self)
	end)
	favoriteBtn:SetScript("OnLeave", function(self)
		applyFavoriteButtonState(self, self.isFavorite, false)
		hideFavoriteTooltip(self)
	end)
	favoriteBtn:SetScript("OnHide", hideFavoriteTooltip)

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

	if bucket.isAccountWide then
		row.coverage:SetText(ns.TEXT.WARBAND)
	else
		local characterCount = math.max(0, ns.SafeNumber(bucket.displayCount, 0))
		row.coverage:SetText(string.format(
			ns.FORMAT.CHARACTER_COUNT,
			characterCount,
			characterCount == 1 and "" or "s"
		))
	end

	if bucket.isAccountWide then
		row.best:SetText("")
		row.best:Hide()
	else
		row.best:SetText(string.format(ns.FORMAT.BEST_CHARACTER, bucket.bestCharacterName or ns.TEXT.UNKNOWN))
		row.best:Show()
	end
	ui.UpdateProgressBar(row.progressBar, bucket.bestEntry, bucket.bestOverallFraction)
	if bucket.isAccountWide then
		row.progressText:SetText(ns.FormatPercent(bucket.bestOverallFraction or 0))
	else
		row.progressText:SetText(string.format(ns.FORMAT.PROGRESS_SUMMARY, ns.FormatPercent(bucket.bestOverallFraction or 0), bucket.maxedCount or 0))
	end
	applyFavoriteButtonState(row.favoriteBtn, ns.IsFavoriteFaction(bucket.factionKey), row.favoriteBtn:IsMouseOver())

	setBackdrop(row, selected)
end
