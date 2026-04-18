RepSheet = RepSheet or {}
local ns = RepSheet
local colors = ns.UI_COLORS
local paneLayout = ns.UI_CHARACTER_PANE_LAYOUT
local ui = ns.UIHelpers
local widgets = ns.UIWidgets

local function scrollChildWidth()
	return ns.UI_PANE_WIDTH - paneLayout.SCROLL_LEFT + paneLayout.SCROLL_RIGHT
end

local function navigateToCharacter(entry)
	if not entry or entry.isAccountWide then
		return
	end
	local characterKey = ns.SafeString(entry.characterKey)
	if characterKey == "" or not ns.SelectCharacter then
		return
	end
	ns.SelectCharacter(characterKey)
	if ns.RefreshMainFrame then
		ns.RefreshMainFrame()
	end
end

local detailRowConfig = {
	onNameClick = navigateToCharacter,
}

local function createDetailRow(parent, index)
	return ns.UI_CreateDetailRow(parent, index, detailRowConfig)
end

local function applyDetailRow(row, entry)
	ns.UI_ApplyDetailRow(row, entry)
end

function ns.UI_CreateCharacterPane(parent)
	local pane = ns.UIWidgets.CreateBackdropPane(parent, ns.UI_BACKDROPS.PANE, colors.PANE_BG, colors.PANE_BORDER)

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
