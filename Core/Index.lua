AltRepTracker = AltRepTracker or {}
local ns = AltRepTracker
local tree = ns.FactionTree
local helpers = ns.NormalizerHelpers

local function buildDetailEntry(character, rep)
	local entry = {
		characterKey = character.characterKey,
		characterName = character.name,
		realm = character.realm,
		classFile = character.classFile,
		className = character.className,
		lastScanAt = character.lastScanAt,
		factionKey = rep.factionKey,
		name = rep.name,
		expansionKey = rep.expansionKey,
		expansionName = rep.expansionName,
		repType = rep.repType,
		repTypeLabel = rep.repTypeLabel,
		standingId = rep.standingId,
		rankText = rep.rankText,
		progressText = rep.progressText,
		currentValue = rep.currentValue,
		maxValue = rep.maxValue,
		overallFraction = rep.overallFraction,
		remainingFraction = rep.remainingFraction,
		isMaxed = rep.isMaxed,
		isAccountWide = rep.isAccountWide,
		hasParagon = rep.hasParagon,
		renownLevel = rep.renownLevel,
		renownMaxLevel = rep.renownMaxLevel,
		friendCurrentRank = rep.friendCurrentRank,
		friendMaxRank = rep.friendMaxRank,
		paragonValue = rep.paragonValue,
		paragonThreshold = rep.paragonThreshold,
		paragonRewardPending = rep.paragonRewardPending,
		icon = rep.icon,
	}
	entry.isMaxed = helpers.isEntryActuallyMaxed(entry)
	entry.overallFraction = helpers.deriveEntryOverallFraction(entry)
	entry.remainingFraction = helpers.deriveEntryRemainingFraction(entry)
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

		local nameA = ns.NormalizeSearchText(ns.FormatCharacterName(a))
		local nameB = ns.NormalizeSearchText(ns.FormatCharacterName(b))
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
	bucket.anyMissing = not bucket.isAccountWide and bucket.capturedCount < #characters
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
			local bucket = byFactionKey[factionKey]
			if not bucket then
				bucket = {
					factionKey = factionKey,
					factionID = rep.factionID,
					majorFactionID = ns.SafeNumber(rep.majorFactionID, 0),
					name = rep.name,
					expansionKey = rep.expansionKey,
					expansionName = rep.expansionName,
					repType = rep.repType,
					repTypeLabel = rep.repTypeLabel,
					headerPath = ns.CopyArray(rep.headerPath),
					headerLabel = rep.headerLabel,
					icon = rep.icon,
					isAccountWide = rep.isAccountWide == true,
					hasParagon = rep.hasParagon == true,
					entries = {},
					byCharacterKey = {},
					capturedCount = 0,
					headerPathUpdatedAt = ns.SafeNumber(character.lastScanAt, 0),
				}
				byFactionKey[factionKey] = bucket
				all[#all + 1] = bucket
			end

			local entry = buildDetailEntry(character, rep)
			bucket.entries[#bucket.entries + 1] = entry
			bucket.byCharacterKey[character.characterKey] = entry
			bucket.capturedCount = bucket.capturedCount + 1
			bucket.isAccountWide = bucket.isAccountWide or rep.isAccountWide == true
			bucket.hasParagon = bucket.hasParagon or rep.hasParagon == true
			if rep.majorFactionID and rep.majorFactionID > 0 then
				bucket.majorFactionID = rep.majorFactionID
			end
			local pathUpdatedAt = ns.SafeNumber(character.lastScanAt, 0)
			local currentHeaderPath = bucket.headerPath or {}
			if type(rep.headerPath) == "table" and (
				pathUpdatedAt > ns.SafeNumber(bucket.headerPathUpdatedAt, 0)
				or (pathUpdatedAt == ns.SafeNumber(bucket.headerPathUpdatedAt, 0) and #rep.headerPath > #currentHeaderPath)
			) then
				bucket.headerPath = ns.CopyArray(rep.headerPath)
				bucket.headerPathUpdatedAt = pathUpdatedAt
			end
		end
	end

	for index = 1, #all do
		finalizeBucket(all[index], characters)
	end

	tree.LinkBucketRelationships(all, byFactionKey)

	table.sort(all, function(a, b)
		return ns.NormalizeSearchText(a.name) < ns.NormalizeSearchText(b.name)
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
