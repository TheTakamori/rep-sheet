AltRepTracker = AltRepTracker or {}
local ns = AltRepTracker
local helpers = ns.NormalizerHelpers
local standardHelpers = ns.ScannerStandardHelpers

local function saveCurrentCharacterSnapshot(reason, scanRows)
	local specialMap = ns.ScanSpecialReputationData(scanRows)
	local snapshot = ns.NormalizeCurrentCharacterSnapshot(reason, scanRows, specialMap)
	ns.SaveCharacterSnapshot(snapshot)
	ns.DebugLog(string.format(ns.FORMAT.SAVED_REPUTATIONS, snapshot.reputationCount or 0, ns.FormatCharacterName(snapshot)))
	return snapshot
end

local function normalizeFactionIDs(factionIDs)
	local ids = {}
	local added = {}

	for index = 1, #(type(factionIDs) == "table" and factionIDs or {}) do
		local factionID = ns.SafeNumber(factionIDs[index], 0)
		if factionID > 0 and not added[factionID] then
			added[factionID] = true
			ids[#ids + 1] = factionID
		end
	end

	table.sort(ids)
	return ids
end

local function buildStoredStandardRow(meta)
	local factionID = ns.SafeNumber(meta and meta.factionID, 0)
	if factionID <= 0 then
		return nil
	end

	return {
		factionKey = tostring(factionID),
		factionID = factionID,
		name = ns.NormalizeText(meta and meta.name),
		standingId = ns.SafeNumber(meta and meta.standingId, 0),
		standingText = ns.SafeString(meta and meta.standingText),
		currentValue = ns.SafeNumber(meta and meta.currentValue, 0),
		maxValue = ns.SafeNumber(meta and meta.maxValue, 0),
		currentStanding = ns.SafeNumber(meta and meta.currentStanding, 0),
		bottomValue = ns.SafeNumber(meta and meta.bottomValue, 0),
		topValue = ns.SafeNumber(meta and meta.topValue, 0),
		isAccountWide = meta and meta.isAccountWide == true or false,
		isWatched = meta and meta.isWatched == true or false,
		atWar = meta and meta.atWar == true or false,
		canToggleAtWar = meta and meta.canToggleAtWar == true or false,
		isChild = meta and meta.isChild == true or false,
		headerPath = type(meta and meta.headerPath) == "table" and ns.CopyArray(meta.headerPath) or {},
		expansionKey = ns.SafeString(meta and meta.expansionKey, ns.ALL_EXPANSIONS_KEY),
		repType = ns.REP_TYPE.STANDARD,
	}
end

local function buildUnresolvedFactionLabel(names)
	if #names == 0 then
		return "-"
	end
	if #names > 12 then
		return table.concat(names, ", ", 1, 12) .. ", ..."
	end
	return table.concat(names, ", ")
end

local function buildTargetedScanRows(factionIDs, metaByFactionID)
	local rows = {}
	local addedByFactionKey = {}
	local standardCount = 0
	local majorFallbackCount = 0
	local unresolvedNames = {}

	for index = 1, #factionIDs do
		local factionID = factionIDs[index]
		local knownMeta = type(metaByFactionID) == "table" and metaByFactionID[factionID] or nil
		local scanRow = ns.GetStandardScanRowByFactionID and ns.GetStandardScanRowByFactionID(factionID, knownMeta) or nil
		if scanRow then
			standardCount = standardCount + 1
		else
			local storedRow = buildStoredStandardRow(knownMeta)
			scanRow = ns.GetMajorFactionScanRowByFactionID and ns.GetMajorFactionScanRowByFactionID(factionID, storedRow) or nil
			if scanRow then
				majorFallbackCount = majorFallbackCount + 1
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
		"Targeted refresh resolved=%d requested=%d standard=%d majorFallback=%d unresolved=%d names=%s",
		#rows,
		#factionIDs,
		standardCount,
		majorFallbackCount,
		#unresolvedNames,
		buildUnresolvedFactionLabel(unresolvedNames)
	))
	return rows
end

function ns.NormalizeCurrentCharacterSnapshot(reason, scanRows, specialMap)
	local snapshot = ns.BuildCurrentCharacterSnapshotBase(reason)
	specialMap = specialMap or {}

	for index = 1, #(scanRows or {}) do
		local rawRow = scanRows[index]
		local normalized = helpers.normalizeFactionRow(rawRow, specialMap[rawRow.factionKey])
		if normalized then
			normalized.characterKey = snapshot.characterKey
			normalized.characterName = snapshot.name
			local existing = snapshot.reputations[normalized.factionKey]
			if existing and (ns.ShouldTraceReputationRow(rawRow, specialMap[rawRow.factionKey]) or ns.ShouldTraceReputationRow(existing)) then
				ns.DebugLog(string.format(
					'SAVE collision key=%s keep? incoming=%s[%s | %s] existing=%s[%s | %s]',
					ns.DebugValueText(normalized.factionKey),
					ns.DebugValueText(normalized.name),
					ns.DebugValueText(normalized.rankText),
					ns.DebugValueText(normalized.progressText),
					ns.DebugValueText(existing.name),
					ns.DebugValueText(existing.rankText),
					ns.DebugValueText(existing.progressText)
				))
			end
			if not existing or helpers.scoreNormalizedRow(normalized) >= helpers.scoreNormalizedRow(existing) then
				snapshot.reputations[normalized.factionKey] = normalized
			end
		end
	end

	snapshot.reputationCount = ns.CountTable(snapshot.reputations)
	return snapshot
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
	local targetFactionIDs = normalizeFactionIDs(factionIDs)
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
