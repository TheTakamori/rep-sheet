RepSheet = RepSheet or {}
local ns = RepSheet
local standardHelpers = ns.ScannerStandardHelpers

local function saveCurrentCharacterSnapshot(reason, scanRows)
	local specialMap = ns.ScanSpecialReputationData(scanRows)
	local snapshot = ns.NormalizeCurrentCharacterSnapshot(reason, scanRows, specialMap)
	ns.SaveCharacterSnapshot(snapshot)
	ns.DebugLog(string.format(ns.FORMAT.SAVED_REPUTATIONS, snapshot.reputationCount or 0, ns.FormatCharacterName(snapshot)))
	return snapshot
end

local function buildUnresolvedFactionLabel(names)
	if #names == 0 then
		return "-"
	end
	if #names > 12 then
		local display = {}
		for index = 1, 12 do
			display[index] = names[index]
		end
		return table.concat(display, ", ") .. ", ..."
	end
	return table.concat(names, ", ")
end

local function buildKnownMajorScanRow(factionID, knownMeta)
	if not ns.GetMajorFactionScanRowByFactionID then
		return nil
	end

	local majorFactionID = ns.SafeNumber(knownMeta and knownMeta.majorFactionID, 0)
	if majorFactionID <= 0 then
		return nil
	end

	local majorMeta = {
		factionKey = tostring(factionID),
		factionID = factionID,
		name = ns.NormalizeText(knownMeta and knownMeta.name),
		standingId = ns.SafeNumber(knownMeta and knownMeta.standingId, 0),
		standingText = ns.SafeString(knownMeta and knownMeta.standingText),
		currentValue = ns.SafeNumber(knownMeta and knownMeta.currentValue, 0),
		maxValue = ns.SafeNumber(knownMeta and knownMeta.maxValue, 0),
		currentStanding = ns.SafeNumber(knownMeta and knownMeta.currentStanding, 0),
		bottomValue = ns.SafeNumber(knownMeta and knownMeta.bottomValue, 0),
		topValue = ns.SafeNumber(knownMeta and knownMeta.topValue, 0),
		isAccountWide = knownMeta and knownMeta.isAccountWide == true,
		isWatched = knownMeta and knownMeta.isWatched == true,
		atWar = knownMeta and knownMeta.atWar == true,
		canToggleAtWar = knownMeta and knownMeta.canToggleAtWar == true,
		isChild = knownMeta and knownMeta.isChild == true,
		headerPath = type(knownMeta and knownMeta.headerPath) == "table" and ns.CopyArray(knownMeta.headerPath) or {},
		expansionKey = ns.SafeString(knownMeta and knownMeta.expansionKey, ns.ALL_EXPANSIONS_KEY),
		majorFactionID = majorFactionID,
	}
	return ns.GetMajorFactionScanRowByFactionID(majorFactionID, majorMeta)
end

local function buildTargetedScanRows(factionIDs, metaByFactionID)
	local rows = {}
	local addedByFactionKey = {}
	local standardCount = 0
	local majorCount = 0
	local unresolvedNames = {}

	for index = 1, #factionIDs do
		local factionID = factionIDs[index]
		local knownMeta = type(metaByFactionID) == "table" and metaByFactionID[factionID] or nil
		local scanRow = ns.GetStandardScanRowByFactionID and ns.GetStandardScanRowByFactionID(factionID, knownMeta) or nil
		if scanRow then
			standardCount = standardCount + 1
		else
			scanRow = buildKnownMajorScanRow(factionID, knownMeta)
			if scanRow then
				majorCount = majorCount + 1
			end
		end

		if scanRow and scanRow.factionKey and not addedByFactionKey[scanRow.factionKey] then
			addedByFactionKey[scanRow.factionKey] = true
			rows[#rows + 1] = scanRow
		elseif not scanRow then
			local unresolvedName = ns.NormalizeText(knownMeta and knownMeta.name)
			unresolvedNames[#unresolvedNames + 1] = unresolvedName ~= "" and unresolvedName or tostring(factionID)
		end
	end

	ns.DebugLog(string.format(
		"Targeted refresh resolved=%d requested=%d standard=%d major=%d unresolved=%d names=%s",
		#rows,
		#factionIDs,
		standardCount,
		majorCount,
		#unresolvedNames,
		buildUnresolvedFactionLabel(unresolvedNames)
	))
	return rows
end

function ns.ScanCurrentCharacter(reason)
	local standardRows, scanContext = ns.ScanStandardReputations()
	local majorRows = ns.ScanMajorReputations(standardRows, scanContext)
	local scanRows = ns.MergeScannedReputationRows(standardRows, majorRows)
	return saveCurrentCharacterSnapshot(reason, scanRows)
end

function ns.RefreshCurrentCharacterKnownReputations(reason)
	local currentCharacterKey = ns.GetCurrentCharacterKey and ns.GetCurrentCharacterKey() or ""
	local factionIDs, metaByFactionID = standardHelpers.getCharacterFactionMetadata(currentCharacterKey)
	if #factionIDs == 0 then
		ns.DebugLog("Known-ID refresh found no stored faction IDs; falling back to a full scan.")
		return ns.ScanCurrentCharacter(reason)
	end

	local scanRows = buildTargetedScanRows(factionIDs, metaByFactionID)
	if #scanRows == 0 then
		ns.DebugLog("Known-ID refresh resolved no rows; falling back to a full scan.")
		return ns.ScanCurrentCharacter(reason)
	end

	return saveCurrentCharacterSnapshot(reason, scanRows)
end

function ns.RefreshCurrentCharacterByFactionIDs(reason, factionIDs)
	local targetFactionIDs = ns.NormalizeFactionIDList(factionIDs)
	if #targetFactionIDs == 0 then
		return ns.RefreshCurrentCharacterKnownReputations(reason)
	end

	local currentCharacterKey = ns.GetCurrentCharacterKey and ns.GetCurrentCharacterKey() or ""
	local _, metaByFactionID = standardHelpers.getCharacterFactionMetadata(currentCharacterKey)
	local scanRows = buildTargetedScanRows(targetFactionIDs, metaByFactionID)
	if #scanRows == 0 then
		ns.DebugLog(string.format(
			"Targeted faction refresh resolved no rows for %d faction IDs; falling back to a full scan.",
			#targetFactionIDs
		))
		return ns.ScanCurrentCharacter(reason)
	end

	return saveCurrentCharacterSnapshot(reason, scanRows)
end
