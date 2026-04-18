RepSheet = RepSheet or {}
local ns = RepSheet
local colors = ns.UI_COLORS
local paneLayout = ns.UI_CHARACTER_PANE_LAYOUT
local rowLayout = ns.UI_DETAIL_ROW_LAYOUT
local ui = ns.UIHelpers
local widgets = ns.UIWidgets

local function scrollChildWidth()
	return ns.UI_PANE_WIDTH - paneLayout.SCROLL_LEFT + paneLayout.SCROLL_RIGHT
end

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

local function createDetailRow(parent, index)
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
	row.nameHover:RegisterForClicks()
	if row.nameHover.SetPropagateMouseClicks then
		row.nameHover:SetPropagateMouseClicks(true)
	end
	row.nameHover:SetScript("OnEnter", showCharacterTooltip)
	row.nameHover:SetScript("OnLeave", hideCharacterTooltip)
	row.nameHover:SetScript("OnHide", hideCharacterTooltip)

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

	return row
end

local function applyDetailRow(row, entry)
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

	if entry.isAccountWide then
		row.name:SetText(ns.TEXT.WARBAND)
		ui.ApplyTextColor(row.name, colors.TEXT_TITLE)
	else
		local r, g, b = ns.GetClassColor({ classFile = entry.classFile })
		row.name:SetText(ns.FormatCharacterName(entry))
		row.name:SetTextColor(r, g, b)
	end

	if row.nameHover then
		row.nameHover.currentEntry = entry
		if entry.isAccountWide then
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

function ns.UI_CreateCharacterPane(parent)
	local pane = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	pane:SetBackdrop(ns.UI_BACKDROPS.PANE)
	ui.ApplyBackdropColors(pane, colors.PANE_BG, colors.PANE_BORDER)

	pane.path = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	pane.path:SetPoint("TOPLEFT", pane, "TOPLEFT", paneLayout.PATH_LEFT, paneLayout.PATH_TOP)
	pane.path:SetPoint("TOPRIGHT", pane, "TOPRIGHT", paneLayout.PATH_RIGHT, paneLayout.PATH_RIGHT_TOP)
	pane.path:SetJustifyH("LEFT")
	if pane.path.SetWordWrap then
		pane.path:SetWordWrap(false)
	end
	if pane.path.SetMaxLines then
		pane.path:SetMaxLines(1)
	end
	ui.ApplyTextColor(pane.path, colors.TEXT_STATUS)

	pane.title = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	pane.title:SetPoint("TOPLEFT", pane.path, "BOTTOMLEFT", 0, paneLayout.TITLE_GAP)
	pane.title:SetPoint("TOPRIGHT", pane.path, "BOTTOMRIGHT", 0, paneLayout.TITLE_GAP)
	pane.title:SetJustifyH("LEFT")
	ui.ApplyTextColor(pane.title, colors.TEXT_TITLE_MUTED)

	pane.subtitle = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	pane.subtitle:SetPoint("TOPLEFT", pane.title, "BOTTOMLEFT", 0, paneLayout.SUBTITLE_GAP)
	ui.ApplyTextColor(pane.subtitle, colors.TEXT_SUBTITLE)

	pane.summary = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	pane.summary:SetPoint("TOPLEFT", pane, "TOPLEFT", paneLayout.SUMMARY_LEFT, paneLayout.SUMMARY_TOP)
	pane.summary:SetPoint("TOPRIGHT", pane, "TOPRIGHT", paneLayout.SUMMARY_RIGHT, paneLayout.SUMMARY_TOP)
	pane.summary:SetJustifyH("LEFT")
	ui.ApplyTextColor(pane.summary, colors.TEXT_INFO)

	pane.favoriteBtn = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
	pane.favoriteBtn:SetSize(paneLayout.FAVORITE_WIDTH, paneLayout.FAVORITE_HEIGHT)
	pane.favoriteBtn:SetPoint("TOPRIGHT", pane, "TOPRIGHT", paneLayout.FAVORITE_RIGHT, paneLayout.FAVORITE_TOP)

	pane.detailsBtn = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
	pane.detailsBtn:SetSize(paneLayout.DETAILS_WIDTH, paneLayout.DETAILS_HEIGHT)
	pane.detailsBtn:SetPoint("TOPRIGHT", pane.favoriteBtn, "BOTTOMRIGHT", 0, paneLayout.DETAILS_TOP_GAP)
	pane.detailsBtn:SetText(ns.TEXT.DETAILS)
	pane.detailsBtn:SetEnabled(false)
	pane.detailsBtn:SetScript("OnClick", function()
		if not pane.currentFactionKey then
			return
		end
		ns.OpenFactionInGameUI(ns.GetFactionBucketByKey(pane.currentFactionKey))
	end)

	pane.note = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	pane.note:SetPoint("TOPLEFT", pane.summary, "BOTTOMLEFT", 0, paneLayout.NOTE_GAP)
	pane.note:SetPoint("TOPRIGHT", pane, "TOPRIGHT", paneLayout.SUMMARY_RIGHT, paneLayout.NOTE_GAP)
	pane.note:SetJustifyH("LEFT")
	ui.ApplyTextColor(pane.note, colors.TEXT_STATUS)
	pane.note:SetText(ns.TEXT.KNOWN_CHARACTER_NOTE)

	pane.scroll = CreateFrame("ScrollFrame", "RepSheetCharacterPaneScroll", pane, "UIPanelScrollFrameTemplate")
	pane.scroll:SetPoint("TOPLEFT", pane, "TOPLEFT", paneLayout.SCROLL_LEFT, paneLayout.SCROLL_TOP)
	pane.scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", paneLayout.SCROLL_RIGHT, paneLayout.SCROLL_BOTTOM)

	pane.scrollChild = widgets.CreateScrollChild(
		pane.scroll,
		scrollChildWidth(),
		paneLayout.SCROLL_CHILD_MIN_HEIGHT
	)

	pane.emptyText = pane.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	pane.emptyText:SetPoint("TOPLEFT", pane.scrollChild, "TOPLEFT", paneLayout.EMPTY_LEFT, paneLayout.EMPTY_TOP)
	pane.emptyText:SetPoint("TOPRIGHT", pane.scrollChild, "TOPRIGHT", paneLayout.EMPTY_RIGHT, paneLayout.EMPTY_TOP)
	pane.emptyText:SetJustifyH("LEFT")
	ui.ApplyTextColor(pane.emptyText, colors.TEXT_EMPTY)
	pane.emptyText:SetText(ns.TEXT.DETAIL_EMPTY_HINT)

	pane.rows = {}

	function pane:SetFaction(bucket)
		self.currentFactionKey = bucket and bucket.factionKey or nil

		if not bucket then
			self.path:SetText("")
			self.title:SetText(ns.TEXT.NO_FACTION_SELECTED)
			self.subtitle:SetText(ns.TEXT.CHOOSE_FACTION_HINT)
			self.summary:SetText("")
			self.favoriteBtn:SetText(ns.TEXT.FAVORITE)
			self.detailsBtn:SetEnabled(false)
			self.note:SetText(ns.TEXT.KNOWN_CHARACTER_NOTE)
			self.emptyText:Show()
			for index = 1, #self.rows do
				self.rows[index]:Hide()
			end
			return
		end

		local parentChain = ns.GetFactionParentChain(bucket.factionKey)
		if #parentChain > 0 then
			local parentNames = {}
			for index = 1, #parentChain do
				parentNames[#parentNames + 1] = parentChain[index].name or ns.TEXT.UNKNOWN
			end
			self.path:SetText(table.concat(parentNames, "  >  "))
		else
			self.path:SetText("")
		end

		self.title:SetText(bucket.name or ns.TEXT.UNKNOWN_FACTION)

		local subtitle = string.format(ns.FORMAT.DETAIL_SUBTITLE, bucket.expansionName or ns.TEXT.UNKNOWN, bucket.repTypeLabel or ns.TEXT.REPUTATION)
		if bucket.isAccountWide then
			subtitle = subtitle .. "  " .. ns.TEXT.WARBAND
		end
		self.subtitle:SetText(subtitle)

		local summary
		if bucket.isAccountWide then
			summary = string.format(ns.FORMAT.DETAIL_SUMMARY_WARBAND, bucket.bestCharacterName or ns.TEXT.UNKNOWN)
		else
			summary = string.format(ns.FORMAT.DETAIL_SUMMARY, bucket.bestCharacterName or ns.TEXT.UNKNOWN, bucket.maxedCount or 0, bucket.totalCharacters or 0)
		end
		self.summary:SetText(summary)
		self.favoriteBtn:SetText(ns.IsFavoriteFaction(bucket.factionKey) and ns.TEXT.UNFAVORITE or ns.TEXT.FAVORITE)
		self.detailsBtn:SetEnabled(true)

		if bucket.isAccountWide then
			self.note:SetText("")
		else
			self.note:SetText(ns.TEXT.KNOWN_CHARACTER_NOTE)
		end

		local entries = ns.GetFactionDetailEntries(bucket.factionKey)
		self.emptyText:SetShown(#entries == 0)
		for index = 1, #entries do
			if not self.rows[index] then
				self.rows[index] = createDetailRow(self.scrollChild, index)
			end
			applyDetailRow(self.rows[index], entries[index])
		end
		for index = #entries + 1, #self.rows do
			self.rows[index]:Hide()
		end

		local height = math.max(paneLayout.SCROLL_CHILD_EMPTY_HEIGHT, #entries * ns.UI_DETAIL_ROW_HEIGHT + paneLayout.SCROLL_CHILD_PADDING)
		self.scrollChild:SetHeight(height)
	end

	pane.favoriteBtn:SetScript("OnClick", function()
		if not pane.currentFactionKey then
			return
		end
		ns.ToggleFavoriteFaction(pane.currentFactionKey)
		pane:SetFaction(ns.GetFactionBucketByKey(pane.currentFactionKey))
		if pane.onFavoriteChanged then
			pane.onFavoriteChanged()
		end
	end)

	return pane
end
