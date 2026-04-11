RepSheet = RepSheet or {}
local ns = RepSheet
local helpers = ns.ScannerStandardHelpers

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
