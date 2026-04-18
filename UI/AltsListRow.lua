RepSheet = RepSheet or {}
local ns = RepSheet
local colors = ns.UI_COLORS
local layout = ns.UI_ALTS_LIST_ROW_LAYOUT
local ui = ns.UIHelpers

function ns.UI_CreateAltsListRow(parent, index, cfg)
	cfg = type(cfg) == "table" and cfg or {}
	local rowHeight = ns.UI_ALTS_LIST_ROW_HEIGHT
	local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
	row:SetSize(math.max(ns.UI_LIST_MIN_WIDTH, parent:GetWidth() - layout.OUTER_WIDTH_TRIM), rowHeight - layout.OUTER_HEIGHT_TRIM)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", ns.UI_LIST_CHILD_X, ns.UI_LIST_CHILD_Y - (index - 1) * rowHeight)
	row:RegisterForClicks("LeftButtonUp")
	row:SetClipsChildren(true)
	ui.ApplyRowBackdrop(row, false)

	local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	name:SetPoint("TOPLEFT", row, "TOPLEFT", layout.NAME_LEFT, layout.NAME_TOP)
	name:SetPoint("TOPRIGHT", row, "TOPRIGHT", layout.NAME_RIGHT, layout.NAME_TOP)
	name:SetJustifyH("LEFT")
	ui.ApplyTextColor(name, colors.TEXT_TITLE)
	ui.SetSingleLine(name)
	row.name = name

	local meta = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	meta:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, layout.META_TOP_GAP)
	meta:SetPoint("TOPRIGHT", row, "TOPRIGHT", layout.META_RIGHT, layout.META_TOP_GAP)
	meta:SetJustifyH("LEFT")
	ui.ApplyTextColor(meta, colors.TEXT_INFO)
	ui.SetSingleLine(meta)
	row.meta = meta

	local professions = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	professions:SetPoint("TOPLEFT", meta, "BOTTOMLEFT", 0, layout.PROFESSIONS_TOP_GAP)
	professions:SetPoint("TOPRIGHT", row, "TOPRIGHT", layout.PROFESSIONS_RIGHT, layout.PROFESSIONS_TOP_GAP)
	professions:SetJustifyH("LEFT")
	ui.ApplyTextColor(professions, colors.TEXT_ACCENT)
	ui.SetSingleLine(professions)
	row.professions = professions

	row:SetScript("OnClick", function()
		if cfg.onClick and row.characterKey then
			cfg.onClick(row.characterKey)
		end
	end)

	return row
end

function ns.UI_ApplyAltsListRow(row, record, selected)
	if not record then
		row:Hide()
		return
	end

	row:Show()
	row.characterKey = record.characterKey

	local r, g, b = ns.GetClassColor({ classFile = record.classFile })
	row.name:SetText(ns.FormatCharacterName(record))
	row.name:SetTextColor(r, g, b)

	row.meta:SetText(record.metaText or "")
	row.professions:SetText(record.professionText or ns.TEXT.NO_PROFESSIONS)

	ui.ApplyRowBackdrop(row, selected)
end
