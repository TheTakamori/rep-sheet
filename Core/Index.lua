RepSheet = RepSheet or {}
local ns = RepSheet
local tree = ns.FactionTree

local function buildDetailEntry(character, rep)
	local entry = {
		characterKey = character.characterKey,
		characterName = character.name,
		characterSortName = ns.NormalizeSearchText(ns.FormatCharacterName(character)),
		realm = character.realm,
		classFile = character.classFile,
		className = character.className,
		lastScanAt = character.lastScanAt,
		factionKey = rep.factionKey,
		factionID = rep.factionID,
		name = rep.name,
		description = rep.description,
		expansionKey = rep.expansionKey,
		expansionName = rep.expansionName,
		repType = rep.repType,
		repTypeLabel = rep.repTypeLabel,
		standingId = rep.standingId,
		standingText = rep.standingText,
		rankText = rep.rankText,
		progressText = rep.progressText,
		currentValue = rep.currentValue,
		maxValue = rep.maxValue,
		currentStanding = rep.currentStanding,
		bottomValue = rep.bottomValue,
		topValue = rep.topValue,
		overallFraction = rep.overallFraction,
		remainingFraction = rep.remainingFraction,
		isMaxed = rep.isMaxed,
		isAccountWide = rep.isAccountWide,
		isWatched = rep.isWatched,
		atWar = rep.atWar,
		canToggleAtWar = rep.canToggleAtWar,
		isChild = rep.isChild,
		headerPath = rep.headerPath,
		headerLabel = rep.headerLabel,
		sortName = rep.sortName,
		searchText = rep.searchText,
		icon = rep.icon,
		hasParagon = rep.hasParagon,
		renownLevel = rep.renownLevel,
		renownMaxLevel = rep.renownMaxLevel,
		friendCurrentRank = rep.friendCurrentRank,
		friendMaxRank = rep.friendMaxRank,
		friendTextLevel = rep.friendTextLevel,
		paragonValue = rep.paragonValue,
		paragonThreshold = rep.paragonThreshold,
		paragonRewardPending = rep.paragonRewardPending,
		majorFactionID = rep.majorFactionID,
	}
	return entry
end

local function scoreEntry(entry)
	local score = ns.SafeNumber(entry.overallFraction, 0)
	if entry.isMaxed then
		score = score + ns.SORT_WEIGHTS.MAXED
	end
	if entry.hasParagon then
		score = score + ns.SORT_WEIGHTS.ENTRY_PARAGON
	end
	return score
end

local function chooseRepresentativeEntry(bucket)
	local representative = nil

	for index = 1, #bucket.entries do
		local entry = bucket.entries[index]
		if not representative then
			representative = entry
		elseif bucket.isAccountWide then
			local recentA = ns.SafeNumber(entry.lastScanAt, 0)
			local recentB = ns.SafeNumber(representative.lastScanAt, 0)
			if recentA ~= recentB then
				if recentA > recentB then
					representative = entry
				end
			elseif scoreEntry(entry) > scoreEntry(representative) then
				representative = entry
			end
		elseif scoreEntry(entry) > scoreEntry(representative) then
			representative = entry
		end
	end

	return representative
end

local function sortDetailEntriesByProgressDesc(entries)
	table.sort(entries, function(a, b)
		local scoreA = scoreEntry(a)
		local scoreB = scoreEntry(b)
		if scoreA ~= scoreB then
			return scoreA > scoreB
		end

		local nameA = ns.SafeString(a.characterSortName)
		if nameA == "" then
			nameA = ns.NormalizeSearchText(ns.FormatCharacterName(a))
		end
		local nameB = ns.SafeString(b.characterSortName)
		if nameB == "" then
			nameB = ns.NormalizeSearchText(ns.FormatCharacterName(b))
		end
		return nameA < nameB
	end)
end

local function finalizeBucket(bucket, characters)
	local bestEntry = chooseRepresentativeEntry(bucket)

	if bucket.isAccountWide then
		if bestEntry then
			bucket.entries = { bestEntry }
			bucket.byCharacterKey = { [bestEntry.characterKey] = bestEntry }
		else
			bucket.entries = {}
			bucket.byCharacterKey = {}
		end
	end

	sortDetailEntriesByProgressDesc(bucket.entries)

	local maxedCount = 0
	local closestRemaining = 1
	for index = 1, #bucket.entries do
		local entry = bucket.entries[index]
		if entry.isMaxed then
			maxedCount = maxedCount + 1
		end
		closestRemaining = math.min(closestRemaining, ns.SafeNumber(entry.remainingFraction, 1))
	end

	bucket.totalCharacters = #characters
	bucket.displayCount = #bucket.entries
	bucket.maxedCount = maxedCount
	bucket.bestEntry = bestEntry or bucket.entries[1]
	bucket.bestCharacterName = bucket.bestEntry and bucket.bestEntry.characterName or ns.TEXT.UNKNOWN
	bucket.bestOverallFraction = bucket.bestEntry and ns.SafeNumber(bucket.bestEntry.overallFraction, 0) or 0
	bucket.closestRemaining = closestRemaining
	tree.RebuildBucketSearchText(bucket)
end

function ns.BuildFactionIndex()
	local runtime = ns.RuntimeEnsure()
	if not runtime.indexDirty and runtime.index then
		return runtime.index
	end

	local characters = ns.GetSortedCharacters()
	local byFactionKey = {}
	local all = {}

	for charIndex = 1, #characters do
		local character = characters[charIndex]
		local reputations = character.reputations or {}
		for factionKey, rep in pairs(reputations) do
			local entry = buildDetailEntry(character, rep)
			local bucket = byFactionKey[factionKey]
			if not bucket then
				bucket = {
					factionKey = factionKey,
					factionID = entry.factionID,
					majorFactionID = ns.SafeNumber(entry.majorFactionID, 0),
					name = entry.name,
					expansionKey = entry.expansionKey,
					expansionName = entry.expansionName,
					repType = entry.repType,
					repTypeLabel = entry.repTypeLabel,
					sortName = entry.sortName,
					headerPath = ns.CopyArray(entry.headerPath),
					headerLabel = entry.headerLabel,
					icon = entry.icon,
					isAccountWide = entry.isAccountWide == true,
					hasParagon = entry.hasParagon == true,
					entries = {},
					byCharacterKey = {},
					headerPathUpdatedAt = ns.SafeNumber(character.lastScanAt, 0),
				}
				if entry.isChild ~= nil then
					bucket.isChild = entry.isChild == true
				end
				byFactionKey[factionKey] = bucket
				all[#all + 1] = bucket
			end

			bucket.entries[#bucket.entries + 1] = entry
			bucket.byCharacterKey[character.characterKey] = entry
			bucket.isAccountWide = bucket.isAccountWide or entry.isAccountWide == true
			bucket.hasParagon = bucket.hasParagon or entry.hasParagon == true
			if entry.isChild ~= nil then
				if bucket.isChild == nil then
					bucket.isChild = entry.isChild == true
				elseif entry.isChild == true then
					bucket.isChild = true
				end
			end
			if entry.majorFactionID and entry.majorFactionID > 0 then
				bucket.majorFactionID = entry.majorFactionID
			end
			local pathUpdatedAt = ns.SafeNumber(character.lastScanAt, 0)
			local currentHeaderPath = bucket.headerPath or {}
			if type(entry.headerPath) == "table" and (
				pathUpdatedAt > ns.SafeNumber(bucket.headerPathUpdatedAt, 0)
				or (pathUpdatedAt == ns.SafeNumber(bucket.headerPathUpdatedAt, 0) and #entry.headerPath > #currentHeaderPath)
			) then
				bucket.headerPath = ns.CopyArray(entry.headerPath)
				bucket.headerLabel = entry.headerLabel
				bucket.expansionKey = entry.expansionKey
				bucket.expansionName = entry.expansionName
				bucket.repType = entry.repType
				bucket.repTypeLabel = entry.repTypeLabel
				bucket.sortName = entry.sortName
				bucket.icon = entry.icon
				bucket.headerPathUpdatedAt = pathUpdatedAt
			end
		end
	end

	for index = 1, #all do
		finalizeBucket(all[index], characters)
	end

	tree.LinkBucketRelationships(all, byFactionKey)

	table.sort(all, function(a, b)
		local nameA = ns.SafeString(a.sortName)
		if nameA == "" then
			nameA = ns.NormalizeSearchText(a.name)
		end
		local nameB = ns.SafeString(b.sortName)
		if nameB == "" then
			nameB = ns.NormalizeSearchText(b.name)
		end
		return nameA < nameB
	end)

	runtime.indexDirty = false
	runtime.index = {
		all = all,
		byKey = byFactionKey,
		totalCharacters = #characters,
		characters = characters,
	}
	ns.InvalidateFilteredResults()
	return runtime.index
end

function ns.GetFactionBucketByKey(factionKey)
	local index = ns.BuildFactionIndex()
	return index.byKey[factionKey]
end

function ns.GetFactionDetailEntries(factionKey)
	local bucket = ns.GetFactionBucketByKey(factionKey)
	if not bucket then
		return {}
	end
	return bucket.entries
end
