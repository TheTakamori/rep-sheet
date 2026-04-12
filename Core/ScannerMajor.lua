RepSheet = RepSheet or {}
local ns = RepSheet

local function pick(data, ...)
	if type(data) ~= "table" then
		return nil
	end
	for index = 1, select("#", ...) do
		local key = select(index, ...)
		if data[key] ~= nil then
			return data[key]
		end
	end
	return nil
end

local function copyRow(row)
	local out = {}
	for key, value in pairs(row or {}) do
		if key == "headerPath" and type(value) == "table" then
			out[key] = ns.CopyArray(value)
		else
			out[key] = value
		end
	end
	return out
end

local function collectMajorFactionIDs()
	local ids = {}
	local added = {}

	local function addID(value)
		value = ns.SafeNumber(value, 0)
		if value <= 0 or added[value] then
			return
		end
		added[value] = true
		ids[#ids + 1] = value
	end

	if C_MajorFactions and type(C_MajorFactions.GetMajorFactionIDs) == "function" then
		local ok, result = pcall(C_MajorFactions.GetMajorFactionIDs)
		if ok and type(result) == "table" then
			for key, value in pairs(result) do
				if type(key) == "number" then
					addID(value)
				else
					addID(key)
					addID(value)
				end
			end
		end
	end

	for index = 1, #(ns.EXTRA_MAJOR_FACTION_IDS or {}) do
		addID(ns.EXTRA_MAJOR_FACTION_IDS[index])
	end

	table.sort(ids)
	return ids
end

local function buildMajorFactionIDSet(ids)
	local lookup = {}
	for index = 1, #(ids or {}) do
		lookup[ids[index]] = true
	end
	return lookup
end

local function resolveHeaderPathForMajorRow(standardRow, headerAncestorsByName, rowName)
	if standardRow and type(standardRow.headerPath) == "table" and #standardRow.headerPath > 0 then
		return ns.CopyArray(standardRow.headerPath)
	end

	local byName = headerAncestorsByName and headerAncestorsByName[ns.NormalizeSearchText(rowName)] or nil
	if type(byName) == "table" and #byName > 0 then
		return ns.CopyArray(byName)
	end

	return {}
end

local function buildMajorScanRow(factionID, data, standardRow, headerAncestorsByName)
	if type(data) ~= "table" or next(data) == nil then
		return nil
	end

	local rowName = ns.SafeString(pick(data, "name"))
	if rowName == "" then
		return nil
	end

	local expansionID = pick(data, "expansionID", "expansion", "gameExpansion")
	local headerPath = resolveHeaderPathForMajorRow(standardRow, headerAncestorsByName, rowName)

	local visibleFactionKey = tostring(standardRow and standardRow.factionKey or factionID)
	local visibleFactionID = ns.SafeNumber(standardRow and standardRow.factionID, factionID)
	local visibleName = ns.SafeString(standardRow and standardRow.name, rowName)

	local scanRow = {
		factionKey = visibleFactionKey,
		factionID = visibleFactionID,
		name = visibleName ~= "" and visibleName or rowName,
		description = pick(data, "description"),
		standingId = standardRow and standardRow.standingId or 0,
		currentStanding = standardRow and standardRow.currentStanding or 0,
		bottomValue = standardRow and standardRow.bottomValue or 0,
		topValue = standardRow and standardRow.topValue or 0,
		isAccountWide = pick(data, "isAccountWide", "isWarband") ~= false or (standardRow and standardRow.isAccountWide == true),
		isWatched = standardRow and standardRow.isWatched == true or false,
		atWar = standardRow and standardRow.atWar == true or false,
		canToggleAtWar = standardRow and standardRow.canToggleAtWar == true or false,
		isChild = standardRow and standardRow.isChild == true or false,
		headerPath = headerPath,
		expansionID = expansionID or (standardRow and standardRow.expansionID),
		majorFactionID = factionID,
		rawMajorData = data,
	}
	local expansionHint = ns.SafeString(standardRow and standardRow.expansionKey)
	if expansionHint ~= "" then
		scanRow.expansionKey = expansionHint
	end
	return scanRow
end

local function mergeMajorRowIntoStandardRow(merged, majorRow)
	if not merged or not majorRow then
		return merged
	end

	merged.majorFactionID = ns.SafeNumber(majorRow.majorFactionID, ns.SafeNumber(merged.majorFactionID, 0))
	merged.isAccountWide = merged.isAccountWide == true or majorRow.isAccountWide == true
	merged.rawMajorData = majorRow.rawMajorData or merged.rawMajorData
	merged.description = ns.SafeString(merged.description) ~= "" and merged.description or majorRow.description
	merged.expansionID = merged.expansionID or majorRow.expansionID

	if type(majorRow.headerPath) == "table" and #majorRow.headerPath > 0 then
		merged.headerPath = ns.CopyArray(majorRow.headerPath)
	end

	return merged
end

function ns.GetMajorFactionScanRowByFactionID(factionID, standardRow, scanContext)
	if not C_MajorFactions or type(C_MajorFactions.GetMajorFactionData) ~= "function" then
		return nil
	end

	local headerAncestorsByName = type(scanContext) == "table" and scanContext.headerAncestorsByName or nil
	local ok, data = pcall(C_MajorFactions.GetMajorFactionData, factionID)
	if not ok then
		return nil
	end

	return buildMajorScanRow(factionID, data, standardRow, headerAncestorsByName)
end

function ns.ScanMajorReputations(standardRows, scanContext)
	local rows = {}
	if not C_MajorFactions or type(C_MajorFactions.GetMajorFactionData) ~= "function" then
		return rows
	end

	local majorFactionIDs = collectMajorFactionIDs()
	local knownMajorFactionIDs = buildMajorFactionIDSet(majorFactionIDs)
	local seenFactionKeys = {}
	local scannedMajorFactionIDs = {}
	local candidateCount = 0
	local standaloneCount = 0

	for index = 1, #(standardRows or {}) do
		local standardRow = standardRows[index]
		local visibleFactionKey = tostring(standardRow and standardRow.factionKey or "")
		local visibleFactionID = ns.SafeNumber(standardRow and standardRow.factionID, 0)
		local majorFactionID = ns.SafeNumber(standardRow and standardRow.majorFactionID, 0)
		if majorFactionID <= 0 and visibleFactionID > 0 and knownMajorFactionIDs[visibleFactionID] then
			majorFactionID = visibleFactionID
		end
		if visibleFactionKey ~= ""
			and majorFactionID > 0
			and not seenFactionKeys[visibleFactionKey]
			and not scannedMajorFactionIDs[majorFactionID]
		then
			seenFactionKeys[visibleFactionKey] = true
			scannedMajorFactionIDs[majorFactionID] = true
			candidateCount = candidateCount + 1
			local scanRow = ns.GetMajorFactionScanRowByFactionID(majorFactionID, standardRow, scanContext)
			if scanRow then
				rows[#rows + 1] = scanRow
				ns.DebugLog(string.format(
					'MAJOR row name="%s" faction=%s major=%s accountWide=%s expansionID=%s headers=%s',
					scanRow.name or ns.TEXT.UNKNOWN,
					ns.DebugValueText(scanRow.factionID),
					ns.DebugValueText(scanRow.majorFactionID),
					ns.DebugValueText(scanRow.isAccountWide),
					ns.DebugValueText(scanRow.expansionID),
					type(scanRow.headerPath) == "table" and table.concat(scanRow.headerPath, " > ") or "-"
				))
			end
		end
	end

	for index = 1, #majorFactionIDs do
		local majorFactionID = majorFactionIDs[index]
		if not scannedMajorFactionIDs[majorFactionID] then
			scannedMajorFactionIDs[majorFactionID] = true
			local scanRow = ns.GetMajorFactionScanRowByFactionID(majorFactionID, nil, scanContext)
			if scanRow then
				rows[#rows + 1] = scanRow
				standaloneCount = standaloneCount + 1
				ns.DebugLog(string.format(
					'MAJOR standalone row name="%s" faction=%s major=%s accountWide=%s expansionID=%s headers=%s',
					scanRow.name or ns.TEXT.UNKNOWN,
					ns.DebugValueText(scanRow.factionID),
					ns.DebugValueText(scanRow.majorFactionID),
					ns.DebugValueText(scanRow.isAccountWide),
					ns.DebugValueText(scanRow.expansionID),
					type(scanRow.headerPath) == "table" and table.concat(scanRow.headerPath, " > ") or "-"
				))
			end
		end
	end

	local state = ns.PlayerStateEnsure()
	state.lastMajorScanCount = #rows
	ns.DebugLog(string.format(
		"Major scan enriched %d visible faction rows and %d standalone major factions from %d standard candidates.",
		#rows - standaloneCount,
		standaloneCount,
		candidateCount
	))
	return rows
end

function ns.MergeScannedReputationRows(standardRows, majorRows)
	local mergedByFactionKey = {}
	local orderedKeys = {}
	local standaloneMajorRows = 0

	for index = 1, #(standardRows or {}) do
		local row = standardRows[index]
		if row and row.factionKey then
			local key = tostring(row.factionKey)
			mergedByFactionKey[key] = copyRow(row)
			orderedKeys[#orderedKeys + 1] = key
		end
	end

	for index = 1, #(majorRows or {}) do
		local row = majorRows[index]
		if row and row.factionKey then
			local key = tostring(row.factionKey)
			local merged = mergedByFactionKey[key]
			if merged then
				mergeMajorRowIntoStandardRow(merged, row)
			else
				mergedByFactionKey[key] = copyRow(row)
				orderedKeys[#orderedKeys + 1] = key
				standaloneMajorRows = standaloneMajorRows + 1
			end
		end
	end

	local rows = {}
	for index = 1, #orderedKeys do
		rows[index] = mergedByFactionKey[orderedKeys[index]]
	end

	ns.DebugLog(string.format(
		"Merged %d standard rows and %d major rows into %d raw rows. Added %d standalone major rows.",
		#(standardRows or {}),
		#(majorRows or {}),
		#rows,
		standaloneMajorRows
	))
	return rows
end
