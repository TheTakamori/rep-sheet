RepSheet = RepSheet or {}
local ns = RepSheet
local colors = ns.UI_COLORS
local paneLayout = ns.UI_ALTS_PANE_LAYOUT
local ui = ns.UIHelpers
local widgets = ns.UIWidgets

local function scrollChildWidth()
	return ns.UI_PANE_WIDTH - paneLayout.SCROLL_LEFT + paneLayout.SCROLL_RIGHT
end

local function navigateToFaction(entry)
	if not entry then
		return
	end
	local factionKey = ns.SafeString(entry.factionKey)
	if factionKey == "" or not ns.SelectFaction then
		return
	end
	ns.SelectFaction(factionKey)
	if ns.RefreshMainFrame then
		ns.RefreshMainFrame()
	end
end

local detailRowConfig = {
	onRowClick = navigateToFaction,
	formatName = function(entry)
		return {
			text = ns.SafeString(entry.name, ns.TEXT.UNKNOWN_FACTION),
			color = colors.TEXT_TITLE,
		}
	end,
	shouldHideHover = function()
		return true
	end,
}

local function createDetailRow(parent, index)
	return ns.UI_CreateDetailRow(parent, index, detailRowConfig)
end

function ns.UI_CreateAltsPane(parent)
	local pane = ns.UIWidgets.CreateBackdropPane(parent, ns.UI_BACKDROPS.PANE, colors.PANE_BG, colors.PANE_BORDER)

	pane.title = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	pane.title:SetPoint("TOPLEFT", pane, "TOPLEFT", paneLayout.HEADER_LEFT, paneLayout.NAME_TOP)
	pane.title:SetPoint("TOPRIGHT", pane, "TOPRIGHT", paneLayout.HEADER_RIGHT, paneLayout.NAME_TOP)
	pane.title:SetJustifyH("LEFT")
	ui.SetSingleLine(pane.title)

	pane.meta = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	pane.meta:SetPoint("TOPLEFT", pane.title, "BOTTOMLEFT", 0, paneLayout.META_GAP)
	pane.meta:SetPoint("TOPRIGHT", pane.title, "BOTTOMRIGHT", 0, paneLayout.META_GAP)
	pane.meta:SetJustifyH("LEFT")
	ui.ApplyTextColor(pane.meta, colors.TEXT_SUBTITLE)

	pane.professions = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	pane.professions:SetPoint("TOPLEFT", pane.meta, "BOTTOMLEFT", 0, paneLayout.PROFESSIONS_GAP)
	pane.professions:SetPoint("TOPRIGHT", pane.meta, "BOTTOMRIGHT", 0, paneLayout.PROFESSIONS_GAP)
	pane.professions:SetJustifyH("LEFT")
	ui.ApplyTextColor(pane.professions, colors.TEXT_ACCENT)

	pane.summary = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	pane.summary:SetPoint("TOPLEFT", pane.professions, "BOTTOMLEFT", 0, paneLayout.PROFESSIONS_GAP)
	pane.summary:SetPoint("TOPRIGHT", pane.professions, "BOTTOMRIGHT", 0, paneLayout.PROFESSIONS_GAP)
	pane.summary:SetJustifyH("LEFT")
	ui.ApplyTextColor(pane.summary, colors.TEXT_INFO)

	pane.filterLabel = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	pane.filterLabel:SetPoint("TOPLEFT", pane, "TOPLEFT", paneLayout.FILTER_LABEL_LEFT, paneLayout.FILTER_LABEL_TOP)
	pane.filterLabel:SetText(ns.TEXT.ALT_REP_FILTER_LABEL)
	ui.ApplyTextColor(pane.filterLabel, colors.TEXT_LABEL)

	pane.expansionDrop = CreateFrame("Frame", "RepSheetAltRepExpansionDropdown", pane, "UIDropDownMenuTemplate")
	pane.expansionDrop:SetPoint("TOPLEFT", pane.filterLabel, "BOTTOMLEFT", paneLayout.FILTER_DROPDOWN_LEFT_OFFSET, paneLayout.FILTER_DROPDOWN_TOP_OFFSET)
	widgets.ConfigureDropdown(pane.expansionDrop, paneLayout.FILTER_DROPDOWN_WIDTH)

	pane.sortLabel = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	pane.sortLabel:SetPoint("TOPLEFT", pane, "TOPLEFT", paneLayout.FILTER_COL_TWO_LEFT, paneLayout.FILTER_LABEL_TOP)
	pane.sortLabel:SetText(ns.TEXT.ALT_REP_SORT_LABEL)
	ui.ApplyTextColor(pane.sortLabel, colors.TEXT_LABEL)

	pane.sortDrop = CreateFrame("Frame", "RepSheetAltRepSortDropdown", pane, "UIDropDownMenuTemplate")
	pane.sortDrop:SetPoint("TOPLEFT", pane.sortLabel, "BOTTOMLEFT", paneLayout.FILTER_DROPDOWN_LEFT_OFFSET, paneLayout.FILTER_DROPDOWN_TOP_OFFSET)
	widgets.ConfigureDropdown(pane.sortDrop, paneLayout.SORT_DROPDOWN_WIDTH)

	widgets.InitializeChoiceDropdown(
		pane.expansionDrop,
		function()
			return ns.Expansions
		end,
		function()
			return ns.GetAltRepFilterValue("expansionKey") or ns.ALL_EXPANSIONS_KEY
		end,
		function(option)
			ns.SetAltRepFilterValue("expansionKey", option.key)
			ns.RefreshMainFrame()
		end
	)

	widgets.InitializeChoiceDropdown(
		pane.sortDrop,
		function()
			return ns.ALT_REP_SORT_OPTIONS
		end,
		function()
			return ns.GetAltRepFilterValue("sortKey") or ns.ALT_REP_SORT_KEY.NAME
		end,
		function(option)
			ns.SetAltRepFilterValue("sortKey", option.key)
			ns.RefreshMainFrame()
		end
	)

	pane.repHeader = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	pane.repHeader:SetPoint("TOPLEFT", pane, "TOPLEFT", paneLayout.REP_HEADER_LEFT, paneLayout.REP_HEADER_TOP)
	pane.repHeader:SetPoint("TOPRIGHT", pane, "TOPRIGHT", paneLayout.REP_HEADER_RIGHT, paneLayout.REP_HEADER_TOP)
	pane.repHeader:SetJustifyH("LEFT")
	ui.ApplyTextColor(pane.repHeader, colors.TEXT_LABEL)
	pane.repHeader:SetText(ns.TEXT.ALT_REPUTATIONS_HEADER)

	pane.scroll = CreateFrame("ScrollFrame", "RepSheetAltsPaneScroll", pane, "UIPanelScrollFrameTemplate")
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
	pane.emptyText:SetText(ns.TEXT.ALT_DETAIL_EMPTY_HINT)

	pane.rows = {}

	local function setControlsShown(shown)
		pane.filterLabel:SetShown(shown)
		pane.expansionDrop:SetShown(shown)
		pane.sortLabel:SetShown(shown)
		pane.sortDrop:SetShown(shown)
	end

	local function clearHeader()
		pane.title:SetText(ns.TEXT.NO_ALT_SELECTED)
		ui.ApplyTextColor(pane.title, colors.TEXT_TITLE_MUTED)
		pane.meta:SetText(ns.TEXT.CHOOSE_ALT_HINT)
		pane.professions:SetText("")
		pane.summary:SetText("")
		pane.repHeader:Hide()
		setControlsShown(false)
		pane.emptyText:Show()
		pane.emptyText:SetText(ns.TEXT.ALT_DETAIL_EMPTY_HINT)
		for index = 1, #pane.rows do
			pane.rows[index]:Hide()
		end
		pane.scrollChild:SetHeight(paneLayout.SCROLL_CHILD_EMPTY_HEIGHT)
	end

	function pane:SetAlt(record)
		self.currentCharacterKey = record and record.characterKey or nil

		if not record then
			clearHeader()
			return
		end

		local r, g, b = ns.GetClassColor({ classFile = record.classFile })
		self.title:SetText(ns.FormatCharacterName(record))
		self.title:SetTextColor(r, g, b)

		local level = ns.SafeNumber(record.level, 0)
		local metaParts = {}
		if level > 0 then
			metaParts[#metaParts + 1] = string.format(
				ns.FORMAT.ALT_DETAIL_LEVEL_RACE_CLASS,
				level,
				ns.SafeString(record.raceName, ""),
				ns.SafeString(record.className, "")
			)
		end
		local factionName = ns.SafeString(record.factionName)
		if factionName ~= "" then
			metaParts[#metaParts + 1] = string.format(ns.FORMAT.ALT_FACTION_GROUP, factionName)
		end
		self.meta:SetText(table.concat(metaParts, "  "))

		local profList = record.professionList or {}
		if #profList > 0 then
			self.professions:SetText(table.concat(profList, ", "))
		else
			self.professions:SetText(ns.TEXT.NO_PROFESSIONS)
		end

		setControlsShown(true)
		self.repHeader:Show()

		local entries, totalEntries = ns.GetFilteredAltReputationEntries(record.characterKey)
		totalEntries = totalEntries or #entries
		local visibleCount = #entries

		local lastScanLabel = record.lastScanAt and record.lastScanAt > 0
			and ns.FormatLastSeen(record.lastScanAt)
			or ns.TEXT.NEVER
		local repCountText
		if visibleCount ~= totalEntries then
			repCountText = string.format(ns.FORMAT.ALT_REPUTATION_COUNT_FILTERED, visibleCount, totalEntries)
		else
			repCountText = string.format(ns.FORMAT.ALT_REPUTATION_COUNT, totalEntries)
		end
		local summaryParts = {
			repCountText,
			string.format(ns.FORMAT.ALT_LAST_SCAN, lastScanLabel),
		}
		self.summary:SetText(table.concat(summaryParts, "  "))

		if visibleCount == 0 then
			self.emptyText:Show()
			if totalEntries == 0 then
				self.emptyText:SetText(ns.TEXT.ALT_NO_REPUTATIONS)
			else
				self.emptyText:SetText(ns.TEXT.ALT_REP_FILTER_EMPTY)
			end
		else
			self.emptyText:Hide()
		end

		for index = 1, visibleCount do
			if not self.rows[index] then
				self.rows[index] = createDetailRow(self.scrollChild, index)
			end
			ns.UI_ApplyDetailRow(self.rows[index], entries[index])
		end
		for index = visibleCount + 1, #self.rows do
			self.rows[index]:Hide()
		end

		local height = math.max(paneLayout.SCROLL_CHILD_EMPTY_HEIGHT, visibleCount * ns.UI_DETAIL_ROW_HEIGHT + paneLayout.SCROLL_CHILD_PADDING)
		self.scrollChild:SetHeight(height)
	end

	clearHeader()

	return pane
end
