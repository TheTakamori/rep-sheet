RepSheet = RepSheet or {}
local ns = RepSheet

local function playerNameAndRealm()
	local name, realm = nil, nil
	if UnitFullName then
		name, realm = UnitFullName("player")
	end
	if not name or name == "" then
		name = UnitName and UnitName("player") or ns.TEXT.UNKNOWN
	end
	if not realm or realm == "" then
		realm = GetRealmName and GetRealmName() or ""
	end
	return ns.NormalizeText(name), ns.NormalizeText(realm)
end

function ns.MakeCharacterKey(name, realm)
	return string.format("%s::%s", ns.NormalizeText(realm), ns.NormalizeText(name))
end

local function buildProfessionEntry(index)
	if type(index) ~= "number" or type(GetProfessionInfo) ~= "function" then
		return nil
	end
	local name, _, skillLevel, maxSkillLevel = GetProfessionInfo(index)
	name = ns.NormalizeText(name)
	if name == "" then
		return nil
	end
	return {
		name = name,
		skillLevel = ns.SafeNumber(skillLevel, 0),
		maxSkillLevel = ns.SafeNumber(maxSkillLevel, 0),
	}
end

local function readPlayerProfessions()
	if type(GetProfessions) ~= "function" then
		return nil
	end
	local prof1, prof2 = GetProfessions()
	local primary1 = buildProfessionEntry(prof1)
	local primary2 = buildProfessionEntry(prof2)
	if not primary1 and not primary2 then
		return { primary1 = nil, primary2 = nil }
	end
	return { primary1 = primary1, primary2 = primary2 }
end

function ns.BuildCurrentPlayerProfessions()
	local ok, professions = pcall(readPlayerProfessions)
	if not ok then
		return nil
	end
	return professions
end

function ns.GetCurrentCharacterKey()
	local name, realm = playerNameAndRealm()
	return ns.MakeCharacterKey(name, realm)
end

function ns.BuildCurrentCharacterMeta()
	local name, realm = playerNameAndRealm()
	local localizedClass, classFile, classID = nil, nil, nil
	if UnitClass then
		localizedClass, classFile, classID = UnitClass("player")
	end
	local raceName, raceFile, raceID = nil, nil, nil
	if UnitRace then
		raceName, raceFile, raceID = UnitRace("player")
	end
	local factionName = nil
	if UnitFactionGroup then
		factionName = select(1, UnitFactionGroup("player"))
	end
	return {
		characterKey = ns.MakeCharacterKey(name, realm),
		name = name,
		realm = realm,
		className = localizedClass,
		classFile = classFile,
		classID = classID,
		raceName = raceName,
		raceFile = raceFile,
		raceID = raceID,
		factionName = factionName,
		level = UnitLevel and UnitLevel("player") or 0,
		guid = UnitGUID and UnitGUID("player") or nil,
		lastKnownZone = GetRealZoneText and GetRealZoneText() or "",
		professions = ns.BuildCurrentPlayerProfessions(),
	}
end

function ns.BuildCurrentCharacterSnapshotBase(reason)
	local snapshot = ns.BuildCurrentCharacterMeta()
	snapshot.lastScanAt = ns.SafeTime()
	snapshot.lastScanReason = ns.SafeString(reason)
	snapshot.reputations = {}
	snapshot.scanNotes = {}
	return snapshot
end

local function countSnapshotReputations(snapshot)
	if type(snapshot) ~= "table" or type(snapshot.reputations) ~= "table" then
		return 0
	end
	return ns.CountTable(snapshot.reputations)
end

local function shouldPreserveMissingReputation(reputation)
	if type(reputation) ~= "table" then
		return false
	end
	if ns.SafeString(reputation.repType) == ns.REP_TYPE.MAJOR then
		return false
	end
	return ns.SafeNumber(reputation.majorFactionID, 0) <= 0
end

local function buildStoredReputation(reputation)
	if type(reputation) ~= "table" then
		return nil
	end

	local factionID = ns.SafeNumber(reputation.factionID, 0)
	local factionKey = ns.SafeString(reputation.factionKey)
	if factionKey == "" and factionID > 0 then
		factionKey = tostring(factionID)
	end
	if factionKey == "" then
		return nil
	end

	return {
		factionKey = factionKey,
		factionID = factionID,
		name = ns.NormalizeText(reputation.name),
		description = ns.NormalizeText(reputation.description),
		expansionKey = ns.SafeString(reputation.expansionKey, ns.ALL_EXPANSIONS_KEY),
		expansionName = ns.SafeString(reputation.expansionName),
		repType = ns.SafeString(reputation.repType, ns.REP_TYPE.STANDARD),
		repTypeLabel = ns.SafeString(reputation.repTypeLabel),
		standingId = ns.SafeNumber(reputation.standingId, 0),
		standingText = ns.SafeString(reputation.standingText),
		rankText = ns.SafeString(reputation.rankText),
		progressText = ns.SafeString(reputation.progressText),
		currentValue = ns.SafeNumber(reputation.currentValue, 0),
		maxValue = ns.SafeNumber(reputation.maxValue, 0),
		currentStanding = ns.SafeNumber(reputation.currentStanding, 0),
		bottomValue = ns.SafeNumber(reputation.bottomValue, 0),
		topValue = ns.SafeNumber(reputation.topValue, 0),
		overallFraction = ns.SafeNumber(reputation.overallFraction, 0),
		remainingFraction = ns.SafeNumber(reputation.remainingFraction, 1),
		isMaxed = reputation.isMaxed == true,
		isAccountWide = reputation.isAccountWide == true,
		isWatched = reputation.isWatched == true,
		atWar = reputation.atWar == true,
		canToggleAtWar = reputation.canToggleAtWar == true,
		isChild = reputation.isChild == true,
		headerPath = type(reputation.headerPath) == "table" and ns.CopyArray(reputation.headerPath) or {},
		headerLabel = ns.SafeString(reputation.headerLabel),
		sortName = ns.SafeString(reputation.sortName, ns.NormalizeSearchText(reputation.name)),
		searchText = ns.SafeString(reputation.searchText),
		icon = ns.SafeString(reputation.icon),
		hasParagon = reputation.hasParagon == true,
		paragonValue = ns.SafeNumber(reputation.paragonValue, 0),
		paragonThreshold = ns.SafeNumber(reputation.paragonThreshold, 0),
		paragonRewardPending = reputation.paragonRewardPending == true,
		majorFactionID = ns.SafeNumber(reputation.majorFactionID, 0),
		renownLevel = ns.SafeNumber(reputation.renownLevel, 0),
		renownMaxLevel = ns.SafeNumber(reputation.renownMaxLevel, 0),
		friendCurrentRank = ns.SafeNumber(reputation.friendCurrentRank, 0),
		friendMaxRank = ns.SafeNumber(reputation.friendMaxRank, 0),
	}
end

local function buildStoredSnapshot(snapshot)
	local stored = {}
	for key, value in pairs(snapshot or {}) do
		if key == "reputations" then
			stored.reputations = {}
			for factionKey, reputation in pairs(value or {}) do
				local storedReputation = buildStoredReputation(reputation)
				if storedReputation then
					stored.reputations[factionKey] = storedReputation
				end
			end
		elseif key == "scanNotes" and type(value) == "table" then
			stored.scanNotes = {}
			for noteKey, noteValue in pairs(value) do
				stored.scanNotes[noteKey] = noteValue
			end
		else
			stored[key] = value
		end
	end
	stored.reputations = stored.reputations or {}
	stored.scanNotes = stored.scanNotes or {}
	return stored
end

local function preserveMissingReputations(snapshot, previous, previousBestCount)
	if type(snapshot) ~= "table" or type(previous) ~= "table" then
		return
	end

	local currentReputations = type(snapshot.reputations) == "table" and snapshot.reputations or {}
	local previousReputations = type(previous.reputations) == "table" and previous.reputations or nil
	local currentCount = ns.CountTable(currentReputations)
	local previousStoredCount = countSnapshotReputations(previous)

	if type(previousReputations) ~= "table" or currentCount >= previousBestCount or previousStoredCount <= 0 then
		snapshot.reputationCount = currentCount
		return
	end

	local mergedReputations = {}
	for factionKey, reputation in pairs(currentReputations) do
		mergedReputations[factionKey] = reputation
	end

	local preservedCount = 0
	for factionKey, reputation in pairs(previousReputations) do
		if not mergedReputations[factionKey] and shouldPreserveMissingReputation(reputation) then
			mergedReputations[factionKey] = reputation
			preservedCount = preservedCount + 1
		end
	end

	if preservedCount <= 0 then
		snapshot.reputationCount = currentCount
		return
	end

	snapshot.reputations = mergedReputations
	snapshot.reputationCount = ns.CountTable(mergedReputations)
	snapshot.scanNotes = type(snapshot.scanNotes) == "table" and snapshot.scanNotes or {}
	snapshot.scanNotes.partialMerge = string.format(
		"Preserved %d missing reputations from prior snapshot.",
		preservedCount
	)

	ns.DebugLog(string.format(
		"Preserved missing reputations: reason=%s current=%s previousStored=%s previousBest=%s kept=%s merged=%s",
		ns.DebugValueText(snapshot.lastScanReason),
		ns.DebugValueText(currentCount),
		ns.DebugValueText(previousStoredCount),
		ns.DebugValueText(previousBestCount),
		ns.DebugValueText(preservedCount),
		ns.DebugValueText(snapshot.reputationCount)
	))
end

function ns.SaveCharacterSnapshot(snapshot)
	if type(snapshot) ~= "table" or not snapshot.characterKey or snapshot.characterKey == "" then
		return
	end

	local db = RepSheetDB
	local storedSnapshot = buildStoredSnapshot(snapshot)
	local previous = db.characters[storedSnapshot.characterKey]
	local previousBestCount = 0
	if type(previous) == "table" then
		previousBestCount = math.max(
			ns.SafeNumber(previous.bestKnownReputationCount, 0),
			ns.SafeNumber(previous.reputationCount, 0)
		)
	end

	storedSnapshot.lastScanAt = ns.SafeNumber(storedSnapshot.lastScanAt, ns.SafeTime())
	preserveMissingReputations(storedSnapshot, previous, previousBestCount)
	local currentCount = ns.SafeNumber(storedSnapshot.reputationCount, 0)
	if currentCount >= previousBestCount then
		storedSnapshot.bestKnownReputationCount = currentCount
		storedSnapshot.bestKnownReputationAt = storedSnapshot.lastScanAt
		storedSnapshot.bestKnownReputationReason = storedSnapshot.lastScanReason
	else
		storedSnapshot.bestKnownReputationCount = previousBestCount
		storedSnapshot.bestKnownReputationAt = ns.SafeNumber(previous and previous.bestKnownReputationAt, ns.SafeNumber(previous and previous.lastScanAt, 0))
		storedSnapshot.bestKnownReputationReason = ns.SafeString(
			previous and previous.bestKnownReputationReason,
			ns.SafeString(previous and previous.lastScanReason)
		)
	end

	db.characters[storedSnapshot.characterKey] = storedSnapshot
	db.lastScanAt = storedSnapshot.lastScanAt
	db.lastScanCharacter = storedSnapshot.characterKey
	ns.MarkIndexDirty()
end

function ns.GetCharacters()
	return RepSheetDB.characters
end

function ns.GetCharacterByKey(characterKey)
	return RepSheetDB.characters and RepSheetDB.characters[characterKey] or nil
end

function ns.GetSortedCharacters()
	local out = {}
	local characters = ns.GetCharacters()
	for _, character in pairs(characters) do
		if ns.BackfillStoredCharacterReputations then
			ns.BackfillStoredCharacterReputations(character)
		end
		out[#out + 1] = character
	end
	table.sort(out, function(a, b)
		local realmA = ns.NormalizeSearchText(a.realm)
		local realmB = ns.NormalizeSearchText(b.realm)
		if realmA ~= realmB then
			return realmA < realmB
		end
		return ns.NormalizeSearchText(a.name) < ns.NormalizeSearchText(b.name)
	end)
	return out
end
