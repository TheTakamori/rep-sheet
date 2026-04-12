RepSheet = RepSheet or {}
local ns = RepSheet
local helpers = ns.ScannerStandardHelpers

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
