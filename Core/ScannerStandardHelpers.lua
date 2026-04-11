AltRepTracker = AltRepTracker or {}
local ns = AltRepTracker
local helpers = ns.ScannerStandardHelpers or {}
ns.ScannerStandardHelpers = helpers

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

local function appendUniqueHeaderPath(path, value)
	value = ns.NormalizeText(value)
	if value == "" then
		return
	end
	if path[#path] ~= value then
		path[#path + 1] = value
	end
end

local function buildFactionDataFromTable(data, index)
	if type(data) ~= "table" or not next(data) then
		return nil
	end
	return {
		index = index,
		factionID = pick(data, "factionID", "id"),
		name = pick(data, "name"),
		description = pick(data, "description"),
		standingId = pick(data, "reaction", "standingID", "standingId"),
		currentStanding = pick(data, "currentStanding", "barValue", "earnedValue"),
		currentReactionThreshold = pick(data, "currentReactionThreshold", "bottomValue", "barMin"),
		nextReactionThreshold = pick(data, "nextReactionThreshold", "topValue", "barMax"),
		isHeader = pick(data, "isHeader"),
		isCollapsed = pick(data, "isCollapsed"),
		hasRep = pick(data, "hasRep"),
		isChild = pick(data, "isChild"),
		isWatched = pick(data, "isWatched"),
		atWar = pick(data, "atWar", "atWarWith"),
		canToggleAtWar = pick(data, "canToggleAtWar"),
		isAccountWide = pick(data, "isAccountWide", "isWarband"),
		expansionID = pick(data, "expansionID", "expansion", "gameExpansion"),
		majorFactionID = pick(data, "majorFactionID"),
		renownFactionID = pick(data, "renownFactionID"),
	}
end

function helpers.getNumFactions()
	if C_Reputation and C_Reputation.GetNumFactions then
		local ok, count = pcall(C_Reputation.GetNumFactions)
		if ok and type(count) == "number" then
			return count
		end
	end
	if GetNumFactions then
		return GetNumFactions() or 0
	end
	return 0
end

function helpers.getFactionDataByIndex(index)
	if C_Reputation and C_Reputation.GetFactionDataByIndex then
		local ok, data = pcall(C_Reputation.GetFactionDataByIndex, index)
		if ok then
			return buildFactionDataFromTable(data, index)
		end
	end

	if GetFactionInfo then
		local name, description, standingId, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID =
			GetFactionInfo(index)
		if name then
			return {
				index = index,
				factionID = factionID,
				name = name,
				description = description,
				standingId = standingId,
				currentStanding = barValue,
				currentReactionThreshold = barMin,
				nextReactionThreshold = barMax,
				isHeader = isHeader,
				isCollapsed = isCollapsed,
				hasRep = hasRep,
				isChild = isChild,
				isWatched = isWatched,
				atWar = atWarWith,
				canToggleAtWar = canToggleAtWar,
				isAccountWide = false,
				expansionID = nil,
				majorFactionID = nil,
				renownFactionID = nil,
			}
		end
	end

	return nil
end

function helpers.getFactionDataByFactionID(factionID)
	factionID = ns.SafeNumber(factionID, 0)
	if factionID <= 0 or not (C_Reputation and C_Reputation.GetFactionDataByID) then
		return nil
	end

	local ok, data = pcall(C_Reputation.GetFactionDataByID, factionID)
	if not ok then
		return nil
	end
	return buildFactionDataFromTable(data, nil)
end

function helpers.deriveProgress(currentStanding, bottomValue, topValue)
	currentStanding = ns.SafeNumber(currentStanding, 0)
	bottomValue = ns.SafeNumber(bottomValue, 0)
	topValue = ns.SafeNumber(topValue, 0)

	local maxValue = topValue - bottomValue
	if maxValue <= 0 then
		return math.max(0, currentStanding), 0
	end

	local currentValue
	if currentStanding >= bottomValue and currentStanding <= topValue then
		currentValue = currentStanding - bottomValue
	elseif currentStanding >= 0 and currentStanding <= maxValue then
		currentValue = currentStanding
	else
		currentValue = currentStanding - bottomValue
	end

	return ns.Clamp(currentValue, 0, maxValue), maxValue
end

function helpers.currentHeaderPath(expansionHeader, sectionHeader, childHeader)
	local path = {}
	appendUniqueHeaderPath(path, expansionHeader)
	appendUniqueHeaderPath(path, sectionHeader)
	appendUniqueHeaderPath(path, childHeader)
	return path
end

local function getExpandHeaderAPI()
	if C_Reputation and type(C_Reputation.ExpandFactionHeader) == "function" then
		return C_Reputation.ExpandFactionHeader
	end
	if type(ExpandFactionHeader) == "function" then
		return ExpandFactionHeader
	end
	return nil
end

local function getCollapseHeaderAPI()
	if C_Reputation and type(C_Reputation.CollapseFactionHeader) == "function" then
		return C_Reputation.CollapseFactionHeader
	end
	if type(CollapseFactionHeader) == "function" then
		return CollapseFactionHeader
	end
	return nil
end

local function noteFactionHeaderMutation()
	local state = ns.PlayerStateEnsure and ns.PlayerStateEnsure() or nil
	if not state then
		return
	end
	state.suppressedUpdateFactionEvents = ns.SafeNumber(state.suppressedUpdateFactionEvents, 0) + 1
	state.suppressedUpdateFactionUntil = ns.SafeTime() + 2
end

function helpers.expandAllHeaders()
	local expandHeader = getExpandHeaderAPI()
	if not expandHeader then
		ns.DebugLog("Header expansion unavailable: no faction header API.")
		return {}
	end

	local collapsedHeaders = {}
	local safety = 0
	local changed = true
	while changed and safety < ns.FACTION_HEADER_EXPAND_LIMIT do
		changed = false
		safety = safety + 1
		local count = helpers.getNumFactions()
		for index = 1, count do
			local row = helpers.getFactionDataByIndex(index)
			if row and row.isHeader and row.isCollapsed then
				collapsedHeaders[#collapsedHeaders + 1] = ns.NormalizeText(row.name)
				local ok = pcall(expandHeader, index)
				if ok then
					noteFactionHeaderMutation()
					changed = true
					break
				end
			end
		end
	end
	return collapsedHeaders
end

function helpers.restoreCollapsedHeaders(collapsedHeaders)
	local collapseHeader = getCollapseHeaderAPI()
	if not collapseHeader then
		return
	end
	for collapsedIndex = #collapsedHeaders, 1, -1 do
		local targetName = collapsedHeaders[collapsedIndex]
		local count = helpers.getNumFactions()
		for index = 1, count do
			local row = helpers.getFactionDataByIndex(index)
			if row and row.isHeader and not row.isCollapsed and ns.NormalizeText(row.name) == targetName then
				local ok = pcall(collapseHeader, index)
				if ok then
					noteFactionHeaderMutation()
				end
				break
			end
		end
	end
end

function helpers.getCharacterFactionMetadata(characterKey)
	local ids = {}
	local metaByFactionID = {}
	local character = ns.GetCharacterByKey and ns.GetCharacterByKey(characterKey) or nil

	if type(character) ~= "table" then
		return ids, metaByFactionID
	end

	for _, rep in pairs(character.reputations or {}) do
		local factionID = ns.SafeNumber(rep and rep.factionID, 0)
		if factionID > 0 and not metaByFactionID[factionID] then
			metaByFactionID[factionID] = {
				factionID = factionID,
				name = ns.NormalizeText(rep.name),
				expansionKey = ns.SafeString(rep.expansionKey),
				headerPath = type(rep.headerPath) == "table" and ns.CopyArray(rep.headerPath) or nil,
				majorFactionID = ns.SafeNumber(rep.majorFactionID, 0),
				isAccountWide = rep.isAccountWide == true,
				standingId = ns.SafeNumber(rep.standingId, 0),
				standingText = ns.SafeString(rep.standingText),
				currentValue = ns.SafeNumber(rep.currentValue, 0),
				maxValue = ns.SafeNumber(rep.maxValue, 0),
				currentStanding = ns.SafeNumber(rep.currentStanding, 0),
				bottomValue = ns.SafeNumber(rep.bottomValue, 0),
				topValue = ns.SafeNumber(rep.topValue, 0),
				isWatched = rep.isWatched == true,
				atWar = rep.atWar == true,
				canToggleAtWar = rep.canToggleAtWar == true,
				isChild = rep.isChild == true,
			}
			ids[#ids + 1] = factionID
		end
	end

	table.sort(ids)
	return ids, metaByFactionID
end

local function chooseKnownStandardSource(currentCharacterKey, sourceCharacterKey, rep)
	if currentCharacterKey ~= "" and sourceCharacterKey == currentCharacterKey then
		return 2, "currentCharacter"
	end
	if rep and rep.isAccountWide == true then
		return 1, "accountWideOther"
	end
	return 0, nil
end

local function upsertKnownStandardMeta(ids, metaByFactionID, rep, scanAt, sourceCharacterKey, sourcePriority, sourceKind)
	local factionID = ns.SafeNumber(rep and rep.factionID, 0)
	local majorFactionID = ns.SafeNumber(rep and rep.majorFactionID, 0)
	if factionID <= 0 or majorFactionID > 0 or sourcePriority <= 0 then
		return
	end

	local existing = metaByFactionID[factionID]
	local shouldReplace = not existing
	if not shouldReplace then
		local existingPriority = ns.SafeNumber(existing.sourcePriority, 0)
		local existingSeenAt = ns.SafeNumber(existing.lastSeenAt, 0)
		shouldReplace = sourcePriority > existingPriority
			or (sourcePriority == existingPriority and scanAt >= existingSeenAt)
	end

	if not shouldReplace then
		return
	end

	metaByFactionID[factionID] = {
		factionID = factionID,
		name = ns.NormalizeText(rep.name),
		expansionKey = ns.SafeString(rep.expansionKey),
		headerPath = type(rep.headerPath) == "table" and ns.CopyArray(rep.headerPath) or nil,
		lastSeenAt = scanAt,
		sourceCharacterKey = ns.SafeString(sourceCharacterKey),
		sourcePriority = sourcePriority,
		sourceKind = sourceKind,
		isAccountWide = rep.isAccountWide == true,
	}

	if not existing then
		ids[#ids + 1] = factionID
	end
end

function helpers.getKnownStandardFactionMetadata(currentCharacterKey)
	local ids = {}
	local metaByFactionID = {}
	local sourceCounts = {
		currentCharacter = 0,
		accountWideOther = 0,
	}
	local characters = ns.GetCharacters and ns.GetCharacters() or nil
	currentCharacterKey = ns.SafeString(currentCharacterKey)

	if type(characters) ~= "table" then
		return ids, metaByFactionID, sourceCounts
	end

	for characterKey, character in pairs(characters) do
		local scanAt = ns.SafeNumber(character and character.lastScanAt, 0)
		for _, rep in pairs(character and character.reputations or {}) do
			local sourcePriority, sourceKind = chooseKnownStandardSource(currentCharacterKey, characterKey, rep)
			upsertKnownStandardMeta(ids, metaByFactionID, rep, scanAt, characterKey, sourcePriority, sourceKind)
		end
	end

	table.sort(ids)
	for index = 1, #ids do
		local meta = metaByFactionID[ids[index]]
		if meta and meta.sourceKind == "currentCharacter" then
			sourceCounts.currentCharacter = sourceCounts.currentCharacter + 1
		elseif meta and meta.sourceKind == "accountWideOther" then
			sourceCounts.accountWideOther = sourceCounts.accountWideOther + 1
		end
	end
	return ids, metaByFactionID, sourceCounts
end
