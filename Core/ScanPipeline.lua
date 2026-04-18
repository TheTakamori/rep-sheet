RepSheet = RepSheet or {}
local ns = RepSheet
local standardHelpers = ns.ScannerStandardHelpers

local function saveCurrentCharacterSnapshot(reason, scanRows, specialMap)
	if specialMap == nil then
		specialMap = ns.ScanSpecialReputationData(scanRows)
	end
	local snapshot = ns.NormalizeCurrentCharacterSnapshot(reason, scanRows, specialMap)
	ns.SaveCharacterSnapshot(snapshot)
	ns.DebugLog(string.format(ns.FORMAT.SAVED_REPUTATIONS, snapshot.reputationCount or 0, ns.FormatCharacterName(snapshot)))
	return snapshot
end

local function createTargetedRefreshStats(requestedCount)
	return {
		requestedCount = ns.SafeNumber(requestedCount, 0),
		standardCount = 0,
		majorCount = 0,
		unresolvedNames = {},
	}
end

local function logTargetedRefreshSummary(rows, stats)
	local safeStats = type(stats) == "table" and stats or createTargetedRefreshStats()
	ns.DebugLog(string.format(
		ns.LOG.TARGETED_REFRESH_SUMMARY,
		#(type(rows) == "table" and rows or {}),
		ns.SafeNumber(safeStats.requestedCount, 0),
		ns.SafeNumber(safeStats.standardCount, 0),
		ns.SafeNumber(safeStats.majorCount, 0),
		#(safeStats.unresolvedNames or {}),
		ns.FormatDebugNameList(safeStats.unresolvedNames or {})
	))
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
		name = knownMeta and knownMeta.name,
		standingId = ns.SafeNumber(knownMeta and knownMeta.standingId, 0),
		currentStanding = ns.SafeNumber(knownMeta and knownMeta.currentStanding, 0),
		bottomValue = ns.SafeNumber(knownMeta and knownMeta.bottomValue, 0),
		topValue = ns.SafeNumber(knownMeta and knownMeta.topValue, 0),
		isAccountWide = knownMeta and knownMeta.isAccountWide == true,
		isWatched = knownMeta and knownMeta.isWatched == true,
		atWar = knownMeta and knownMeta.atWar == true,
		canToggleAtWar = knownMeta and knownMeta.canToggleAtWar == true,
		isChild = knownMeta and knownMeta.isChild == true,
		headerPath = type(knownMeta and knownMeta.headerPath) == "table" and ns.CopyArray(knownMeta.headerPath) or {},
		majorFactionID = majorFactionID,
	}
	local expansionHint = ns.SafeString(knownMeta and knownMeta.expansionKey)
	if expansionHint ~= "" then
		majorMeta.expansionKey = expansionHint
	end
	return ns.GetMajorFactionScanRowByFactionID(majorFactionID, majorMeta)
end

local function buildTargetedScanRow(factionID, metaByFactionID)
	local knownMeta = type(metaByFactionID) == "table" and metaByFactionID[factionID] or nil
	local scanRow = ns.GetStandardScanRowByFactionID and ns.GetStandardScanRowByFactionID(factionID, knownMeta) or nil
	local resolvedKind = nil
	if scanRow then
		resolvedKind = "standard"
	else
		scanRow = buildKnownMajorScanRow(factionID, knownMeta)
		if scanRow then
			resolvedKind = "major"
		end
	end

	local unresolvedName = nil
	if not scanRow then
		unresolvedName = ns.SafeString(knownMeta and knownMeta.name)
		if unresolvedName == "" then
			unresolvedName = tostring(factionID)
		end
	end

	return scanRow, resolvedKind, unresolvedName
end

local function appendTargetedScanRow(rows, addedByFactionKey, factionID, metaByFactionID, stats)
	local scanRow, resolvedKind, unresolvedName = buildTargetedScanRow(factionID, metaByFactionID)
	if resolvedKind == "standard" then
		stats.standardCount = ns.SafeNumber(stats.standardCount, 0) + 1
	elseif resolvedKind == "major" then
		stats.majorCount = ns.SafeNumber(stats.majorCount, 0) + 1
	end

	if scanRow and scanRow.factionKey and not addedByFactionKey[scanRow.factionKey] then
		addedByFactionKey[scanRow.factionKey] = true
		rows[#rows + 1] = scanRow
	elseif not scanRow then
		local unresolvedNames = stats.unresolvedNames or {}
		unresolvedNames[#unresolvedNames + 1] = unresolvedName
		stats.unresolvedNames = unresolvedNames
	end
end

local function buildTargetedScanRows(factionIDs, metaByFactionID)
	local rows = {}
	local addedByFactionKey = {}
	local stats = createTargetedRefreshStats(#factionIDs)

	for index = 1, #factionIDs do
		appendTargetedScanRow(rows, addedByFactionKey, factionIDs[index], metaByFactionID, stats)
	end

	logTargetedRefreshSummary(rows, stats)
	return rows
end

local function buildRowBatch(rows, firstIndex, lastIndex)
	local batch = {}
	for index = firstIndex, lastIndex do
		batch[#batch + 1] = rows[index]
	end
	return batch
end

local function scheduleKnownRefreshBatch(callback)
	if C_Timer and C_Timer.After then
		C_Timer.After(ns.KNOWN_REFRESH_BATCH_DELAY_SECONDS, callback)
		return
	end
	callback()
end

local function isKnownRefreshScanActive(scanToken)
	local state = ns.PlayerStateEnsure and ns.PlayerStateEnsure() or nil
	return type(state) == "table" and state.activeScanToken == scanToken
end

function ns.StartAsyncKnownReputationRefresh(reason, scanToken, onComplete)
	if type(onComplete) ~= "function" or not (C_Timer and C_Timer.After) then
		return false
	end

	local currentCharacterKey = ns.GetCurrentCharacterKey and ns.GetCurrentCharacterKey() or ""
	local factionIDs, metaByFactionID = standardHelpers.getCharacterFactionMetadata(currentCharacterKey)
	if #factionIDs == 0 then
		ns.DebugLog("Known-ID refresh found no stored faction IDs; falling back to a full scan.")
		local ok, snapshot = pcall(ns.ScanCurrentCharacter, reason)
		onComplete(ok, snapshot)
		return true
	end

	local job = {
		reason = reason,
		scanToken = scanToken,
		factionIDs = factionIDs,
		metaByFactionID = metaByFactionID,
		rows = {},
		addedByFactionKey = {},
		stats = createTargetedRefreshStats(#factionIDs),
		resolveIndex = 1,
		specialIndex = 1,
		specialMap = {},
		specialSummary = nil,
	}

	local function complete(ok, payload)
		if isKnownRefreshScanActive(scanToken) then
			onComplete(ok, payload)
		end
	end

	local function processSpecialBatch()
		if not isKnownRefreshScanActive(scanToken) then
			return
		end

		if ns.DeferBackgroundJobUntilAfterCombat
			and ns.DeferBackgroundJobUntilAfterCombat(processSpecialBatch, "known refresh batch")
		then
			return
		end

		local batchSize = math.max(1, ns.SafeNumber(ns.KNOWN_REFRESH_SPECIAL_BATCH_SIZE, 20))
		local lastIndex = math.min(#job.rows, job.specialIndex + batchSize - 1)
		local batchRows = buildRowBatch(job.rows, job.specialIndex, lastIndex)
		local ok, specialMap, specialSummary = pcall(
			ns.AppendSpecialReputationData,
			batchRows,
			job.specialMap,
			job.specialSummary
		)
		if not ok then
			complete(false, specialMap)
			return
		end

		job.specialMap = specialMap or job.specialMap
		job.specialSummary = specialSummary or job.specialSummary
		job.specialIndex = lastIndex + 1
		if job.specialIndex <= #job.rows then
			scheduleKnownRefreshBatch(processSpecialBatch)
			return
		end

		if ns.LogSpecialReputationSummary then
			ns.LogSpecialReputationSummary(job.specialSummary)
		end

		local savedOk, snapshot = pcall(saveCurrentCharacterSnapshot, reason, job.rows, job.specialMap)
		complete(savedOk, snapshot)
	end

	local function processResolveBatch()
		if not isKnownRefreshScanActive(scanToken) then
			return
		end

		if ns.DeferBackgroundJobUntilAfterCombat
			and ns.DeferBackgroundJobUntilAfterCombat(processResolveBatch, "known refresh batch")
		then
			return
		end

		local batchSize = math.max(1, ns.SafeNumber(ns.KNOWN_REFRESH_RESOLVE_BATCH_SIZE, 25))
		local processed = 0
		while job.resolveIndex <= #job.factionIDs and processed < batchSize do
			appendTargetedScanRow(
				job.rows,
				job.addedByFactionKey,
				job.factionIDs[job.resolveIndex],
				job.metaByFactionID,
				job.stats
			)
			job.resolveIndex = job.resolveIndex + 1
			processed = processed + 1
		end

		if job.resolveIndex <= #job.factionIDs then
			scheduleKnownRefreshBatch(processResolveBatch)
			return
		end

		logTargetedRefreshSummary(job.rows, job.stats)
		if #job.rows == 0 then
			ns.DebugLog("Known-ID refresh resolved no rows; falling back to a full scan.")
			local ok, snapshot = pcall(ns.ScanCurrentCharacter, reason)
			complete(ok, snapshot)
			return
		end

		scheduleKnownRefreshBatch(processSpecialBatch)
	end

	scheduleKnownRefreshBatch(processResolveBatch)
	return true
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
