AltRepTracker = AltRepTracker or {}
local ns = AltRepTracker
local helpers = ns.ScannerStandardHelpers

local function buildStandardScanRow(row, headerPath, expansionKey)
	return {
		factionKey = row.factionID and tostring(row.factionID) or ns.NormalizeSearchText(row.name),
		factionID = row.factionID,
		name = ns.NormalizeText(row.name),
		description = ns.NormalizeText(row.description),
		standingId = row.standingId,
		standingText = ns.StandingLabel(row.standingId),
		currentValue = select(1, helpers.deriveProgress(row.currentStanding, row.currentReactionThreshold, row.nextReactionThreshold)),
		maxValue = select(2, helpers.deriveProgress(row.currentStanding, row.currentReactionThreshold, row.nextReactionThreshold)),
		currentStanding = ns.SafeNumber(row.currentStanding, 0),
		bottomValue = ns.SafeNumber(row.currentReactionThreshold, 0),
		topValue = ns.SafeNumber(row.nextReactionThreshold, 0),
		isAccountWide = row.isAccountWide == true,
		isWatched = row.isWatched == true,
		atWar = row.atWar == true,
		canToggleAtWar = row.canToggleAtWar == true,
		isChild = row.isChild == true,
		headerPath = headerPath,
		expansionKey = expansionKey,
		expansionID = row.expansionID,
		repType = ns.REP_TYPE.STANDARD,
		majorFactionID = row.majorFactionID or row.renownFactionID,
		icon = ns.IconForRepType(ns.REP_TYPE.STANDARD),
	}
end

local function traceStandardScanRow(prefix, scanRow)
	if not ns.ShouldTraceReputationRow(scanRow) then
		return
	end
	ns.DebugLog(string.format(
		'%s name="%s" faction=%s major=%s accountWide=%s standing=%s values=%s/%s current=%s thresholds=%s..%s headers=%s',
		prefix,
		scanRow.name or ns.TEXT.UNKNOWN,
		ns.DebugValueText(scanRow.factionID),
		ns.DebugValueText(scanRow.majorFactionID),
		ns.DebugValueText(scanRow.isAccountWide),
		ns.DebugValueText(scanRow.standingText),
		ns.DebugValueText(scanRow.currentValue),
		ns.DebugValueText(scanRow.maxValue),
		ns.DebugValueText(scanRow.currentStanding),
		ns.DebugValueText(scanRow.bottomValue),
		ns.DebugValueText(scanRow.topValue),
		type(scanRow.headerPath) == "table" and table.concat(scanRow.headerPath, " > ") or "-"
	))
end

function ns.GetStandardScanRowByFactionID(factionID, knownMeta)
	local row = helpers.getFactionDataByFactionID(factionID)
	local rowName = ns.NormalizeText(row and row.name)
	if not row or row.isHeader or rowName == "" or row.hasRep == false then
		return nil
	end

	local headerPath = type(knownMeta and knownMeta.headerPath) == "table" and ns.CopyArray(knownMeta.headerPath) or {}
	local expansionKey = ns.ResolveFactionExpansionOverride(factionID, rowName)
		or ns.ExpansionKeyFromGameExp(row.expansionID)
		or ns.ResolveExpansionKeyFromHeaders(headerPath)
	if not expansionKey or expansionKey == "" then
		expansionKey = ns.SafeString(knownMeta and knownMeta.expansionKey, ns.ALL_EXPANSIONS_KEY)
	end

	return buildStandardScanRow(row, headerPath, expansionKey)
end

local function appendFallbackStandardRows(rows)
	local currentCharacterKey = ns.GetCurrentCharacterKey and ns.GetCurrentCharacterKey() or ""
	local knownFactionIDs, knownMetaByFactionID, sourceCounts = helpers.getKnownStandardFactionMetadata(currentCharacterKey)
	if #knownFactionIDs == 0 then
		return
	end

	local existingByFactionID = {}
	for index = 1, #rows do
		local row = rows[index]
		local factionID = ns.SafeNumber(row and row.factionID, 0)
		if factionID > 0 then
			existingByFactionID[factionID] = true
		end
	end

	local addedCount = 0
	local unresolvedNames = {}
	for index = 1, #knownFactionIDs do
		local factionID = knownFactionIDs[index]
		if not existingByFactionID[factionID] then
			local row = helpers.getFactionDataByFactionID(factionID)
			local rowName = ns.NormalizeText(row and row.name)
			if row and not row.isHeader and rowName ~= "" and row.hasRep ~= false then
				local knownMeta = knownMetaByFactionID[factionID]
				local headerPath = type(knownMeta and knownMeta.headerPath) == "table" and ns.CopyArray(knownMeta.headerPath) or {}
				local expansionKey = ns.ResolveFactionExpansionOverride(factionID, rowName)
					or ns.ExpansionKeyFromGameExp(row.expansionID)
					or ns.ResolveExpansionKeyFromHeaders(headerPath)
				if not expansionKey or expansionKey == "" then
					expansionKey = ns.SafeString(knownMeta and knownMeta.expansionKey, ns.ALL_EXPANSIONS_KEY)
				end

				local scanRow = buildStandardScanRow(row, headerPath, expansionKey)
				rows[#rows + 1] = scanRow
				existingByFactionID[factionID] = true
				addedCount = addedCount + 1
				traceStandardScanRow("STD fallback row", scanRow)
			else
				local knownMeta = knownMetaByFactionID[factionID]
				if knownMeta and knownMeta.name ~= "" then
					unresolvedNames[#unresolvedNames + 1] = knownMeta.name
				end
			end
		end
	end

	table.sort(unresolvedNames)
	local unresolvedLabel = "-"
	if #unresolvedNames > 0 then
		local limit = 8
		local display = {}
		for index = 1, math.min(#unresolvedNames, limit) do
			display[#display + 1] = unresolvedNames[index]
		end
		if #unresolvedNames > limit then
			display[#display + 1] = string.format("+%d more", #unresolvedNames - limit)
		end
		unresolvedLabel = table.concat(display, ", ")
	end

	ns.DebugLog(string.format(
		"Standard ID fallback considered=%d currentHistory=%d sharedHistory=%d added=%d unresolved=%d names=%s",
		#knownFactionIDs,
		ns.SafeNumber(sourceCounts and sourceCounts.currentCharacter, 0),
		ns.SafeNumber(sourceCounts and sourceCounts.accountWideOther, 0),
		addedCount,
		#unresolvedNames,
		unresolvedLabel
	))
end

function ns.ScanStandardReputations()
	local collapsedHeaders = helpers.expandAllHeaders()
	local rows = {}
	local headerAncestorsByName = {}

	local currentExpansionHeader = nil
	local currentSectionHeader = nil
	local currentChildHeader = nil
	local count = helpers.getNumFactions()

	for index = 1, count do
		local row = helpers.getFactionDataByIndex(index)
		if row then
			local rowName = ns.NormalizeText(row.name)
			if row.isHeader then
				local mappedExpansion = ns.ResolveExpansionKeyFromHeader(rowName)
				if mappedExpansion and mappedExpansion ~= ns.ALL_EXPANSIONS_KEY then
					currentExpansionHeader = rowName
					currentSectionHeader = nil
					currentChildHeader = nil
				else
					local ancestorPath
					if row.isChild then
						-- Child headers are nested under the current section, but they are
						-- siblings of other child headers. Do not inherit the previous child
						-- header here or siblings get chained together incorrectly.
						ancestorPath = helpers.currentHeaderPath(currentExpansionHeader, currentSectionHeader, nil)
					else
						-- A non-child header starts a new top-level section under the
						-- current expansion, so its ancestry should not inherit the prior
						-- section or child header.
						ancestorPath = helpers.currentHeaderPath(currentExpansionHeader, nil, nil)
					end
					headerAncestorsByName[ns.NormalizeSearchText(rowName)] = ns.CopyArray(ancestorPath)

					if row.isChild then
						currentChildHeader = rowName
					else
						currentSectionHeader = rowName
						currentChildHeader = nil
					end
				end
			elseif rowName ~= "" and row.hasRep ~= false then
				local headerPath = helpers.currentHeaderPath(currentExpansionHeader, currentSectionHeader, currentChildHeader)

				local expansionKey = ns.ResolveFactionExpansionOverride(row.factionID, rowName)
					or ns.ExpansionKeyFromGameExp(row.expansionID)
					or ns.ResolveExpansionKeyFromHeaders(headerPath)

				local scanRow = buildStandardScanRow(row, headerPath, expansionKey)
				rows[#rows + 1] = scanRow
				traceStandardScanRow("STD row", scanRow)
			end
		end
	end

	appendFallbackStandardRows(rows)
	helpers.restoreCollapsedHeaders(collapsedHeaders)

	local state = ns.PlayerStateEnsure()
	state.lastStandardScanCount = #rows
	ns.DebugLog(string.format(ns.FORMAT.STANDARD_SCAN_CAPTURED, #rows))
	return rows, {
		headerAncestorsByName = headerAncestorsByName,
	}
end
