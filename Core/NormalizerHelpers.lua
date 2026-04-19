RepSheet = RepSheet or {}
local ns = RepSheet
local helpers = ns.NormalizerHelpers

local function buildFactionKey(factionID, name)
	factionID = ns.SafeNumber(factionID, 0)
	if factionID > 0 then
		return tostring(factionID)
	end
	return ns.NormalizeSearchText(name)
end

local function chooseStoredFactionKey(factionID, name, isGuild, fallbackKey)
	if isGuild then
		local guildKey = ns.MakeGuildFactionKey(name)
		if guildKey ~= "" then
			return guildKey
		end
	end
	-- Always prefer a key derived from factionID + name so that ApplyRuntime
	-- and Backfill paths stay deterministic. Only fall back to a stored key
	-- when there is genuinely no factionID and no usable name.
	local derived = buildFactionKey(factionID, name)
	if derived ~= "" then
		return derived
	end
	return ns.SafeString(fallbackKey)
end

local function normalizeHeaderPath(headerPath)
	if type(headerPath) ~= "table" then
		return {}
	end

	local normalized = {}
	for index = 1, #headerPath do
		local headerName = ns.NormalizeText(headerPath[index])
		if headerName ~= "" then
			normalized[#normalized + 1] = headerName
		end
	end
	return normalized
end

local function resolveStandingText(row)
	local standingText = ns.SafeString(row and row.standingText)
	if standingText ~= "" then
		return standingText
	end

	local standingId = ns.SafeNumber(row and row.standingId, 0)
	if standingId > 0 then
		return ns.StandingLabel(standingId)
	end

	return ""
end

local function buildRankText(repType, row, special)
	if repType == ns.REP_TYPE.MAJOR then
		local renownLevel = ns.SafeNumber(special.renownLevel, 0)
		local renownMax = ns.SafeNumber(special.renownMaxLevel, 0)
		if ns.HasValidMajorRenown(special) then
			return string.format("%s: %s", ns.TEXT.RENOWN, ns.FormatProgressValues(renownLevel, renownMax))
		end
		return row.standingText or ns.TEXT.REPUTATION
	end

	if repType == ns.REP_TYPE.FRIENDSHIP then
		local levelText = ns.SafeString(special.friendTextLevel)
		if levelText ~= "" then
			return levelText
		end
		local currentRank = ns.SafeNumber(special.friendCurrentRank, 0)
		local maxRank = ns.SafeNumber(special.friendMaxRank, 0)
		if currentRank > 0 and maxRank > 0 then
			return string.format("Rank: %s", ns.FormatProgressValues(currentRank, maxRank))
		end
		return ns.TEXT.FRIENDSHIP
	end

	if repType == ns.REP_TYPE.NEIGHBORHOOD then
		local standingText = resolveStandingText(row)
		if standingText ~= "" then
			return standingText
		end
		return ns.TEXT.NEIGHBORHOOD
	end

	local standingText = resolveStandingText(row)
	if standingText ~= "" then
		return standingText
	end
	return ns.TEXT.REPUTATION
end

local function isCappedMajorRenown(special)
	if not ns.HasValidMajorRenown(special) then
		return false
	end
	return ns.SafeNumber(special.renownLevel, 0) >= ns.SafeNumber(special.renownMaxLevel, 0)
end

local function traceContradictoryMajorRenown(row, special, currentValue, maxValue)
	if not isCappedMajorRenown(special) or ns.SafeNumber(maxValue, 0) <= 0 or ns.SafeNumber(currentValue, 0) >= ns.SafeNumber(maxValue, 0) then
		return
	end

	local state = ns.PlayerStateEnsure()
	state.majorRenownContradictions = type(state.majorRenownContradictions) == "table" and state.majorRenownContradictions or {}
	local factionKey = tostring(row and row.factionKey or row and row.factionID or special and special.majorFactionID or "")
	if factionKey == "" or state.majorRenownContradictions[factionKey] then
		return
	end

	state.majorRenownContradictions[factionKey] = true
	ns.DebugLog(string.format(
		'MAJOR contradiction name="%s" faction=%s major=%s renown=%s/%s xp=%s/%s paragon=%s',
		row and row.name or ns.TEXT.UNKNOWN,
		ns.DebugValueText(row and row.factionID),
		ns.DebugValueText(special and special.majorFactionID),
		ns.DebugValueText(special and special.renownLevel),
		ns.DebugValueText(special and special.renownMaxLevel),
		ns.DebugValueText(currentValue),
		ns.DebugValueText(maxValue),
		ns.DebugValueText(special and special.hasParagon)
	))
end

local function deriveOverallFraction(repType, row, special, currentValue, maxValue, isMaxed)
	local tierFraction = ns.ProgressFraction(currentValue, maxValue)

	if repType == ns.REP_TYPE.MAJOR then
		local currentLevel = ns.SafeNumber(special.renownLevel, 0)
		local maxLevel = ns.SafeNumber(special.renownMaxLevel, 0)
		if maxLevel > 0 and currentLevel >= 0 then
			if isMaxed then
				return 1
			end
			return ns.Clamp((math.max(currentLevel - 1, 0) + tierFraction) / maxLevel, 0, 1)
		end
		return tierFraction
	end

	if repType == ns.REP_TYPE.FRIENDSHIP then
		local currentRank = ns.SafeNumber(special.friendCurrentRank, 0)
		local maxRank = ns.SafeNumber(special.friendMaxRank, 0)
		if maxRank > 0 and currentRank > 0 then
			if isMaxed then
				return 1
			end
			return ns.Clamp(((currentRank - 1) + tierFraction) / maxRank, 0, 1)
		end
		return tierFraction
	end

	local standingId = ns.SafeNumber(row.standingId, 0)
	if standingId > 0 then
		if isMaxed and standingId >= ns.MAX_STANDARD_STANDING_ID then
			return 1
		end
		return ns.Clamp(((standingId - 1) + tierFraction) / ns.MAX_STANDARD_STANDING_ID, 0, 1)
	end

	return tierFraction
end

local function shouldShowParagonProgress(repType, special, isMaxed)
	if not special.hasParagon or ns.SafeNumber(special.paragonThreshold, 0) <= 0 then
		return false
	end

	if repType == ns.REP_TYPE.MAJOR then
		return isCappedMajorRenown(special)
	end

	return isMaxed == true
end

local function shouldShowMeaningfulMajorProgress(special, maxValue, isMaxed)
	return ns.HasValidMajorRenown(special)
		and not isMaxed
		and ns.SafeNumber(maxValue, 0) > 0
end

local function isAtMaximumStandardStanding(row, currentValue, maxValue)
	local standingId = ns.SafeNumber(row and row.standingId, 0)
	if standingId < ns.MAX_STANDARD_STANDING_ID then
		return false
	end
	return maxValue <= 0 or currentValue >= maxValue
end

local function chooseNormalizedValues(row, special)
	local repType = special.repType or row.repType or ns.REP_TYPE.STANDARD
	local currentValue = row.currentValue
	local maxValue = row.maxValue
	if currentValue == nil or maxValue == nil then
		currentValue, maxValue = ns.DeriveProgressValues(row.currentStanding, row.bottomValue, row.topValue)
	else
		currentValue = ns.SafeNumber(currentValue, 0)
		maxValue = ns.SafeNumber(maxValue, 0)
	end

	if repType == ns.REP_TYPE.MAJOR then
		local renownMax = ns.SafeNumber(special.renownMaxLevel, 0)
		if renownMax > 0 then
			if special.currentValue ~= nil then
				currentValue = ns.SafeNumber(special.currentValue, 0)
			else
				currentValue = 0
			end
			if special.maxValue ~= nil then
				maxValue = ns.SafeNumber(special.maxValue, 0)
			else
				maxValue = 0
			end
		else
			currentValue = ns.SafeNumber(special.currentValue, currentValue)
			maxValue = ns.SafeNumber(special.maxValue, maxValue)
		end
	elseif repType == ns.REP_TYPE.FRIENDSHIP then
		currentValue = ns.SafeNumber(special.currentValue, currentValue)
		maxValue = ns.SafeNumber(special.maxValue, maxValue)
	end

	local isMaxed = false
	if repType == ns.REP_TYPE.MAJOR then
		if isCappedMajorRenown(special) then
			isMaxed = true
		elseif special.hasParagon and (maxValue <= 0 or currentValue >= maxValue) then
			isMaxed = true
		end
	elseif repType == ns.REP_TYPE.FRIENDSHIP then
		local currentRank = ns.SafeNumber(special.friendCurrentRank, 0)
		local maxRank = ns.SafeNumber(special.friendMaxRank, 0)
		if maxRank > 0 and currentRank >= maxRank and (maxValue <= 0 or currentValue >= maxValue) then
			isMaxed = true
		end
	elseif repType == ns.REP_TYPE.STANDARD or repType == ns.REP_TYPE.OTHER or repType == ns.REP_TYPE.NEIGHBORHOOD then
		if isAtMaximumStandardStanding(row, currentValue, maxValue) then
			isMaxed = true
		end
	elseif special.hasParagon then
		if maxValue <= 0 or currentValue >= maxValue then
			isMaxed = true
		end
	end

	if isMaxed and maxValue > 0 and repType ~= ns.REP_TYPE.MAJOR then
		currentValue = maxValue
	end

	if repType == ns.REP_TYPE.MAJOR then
		traceContradictoryMajorRenown(row, special, currentValue, maxValue)
	end

	return repType, currentValue, maxValue, isMaxed
end

local function buildProgressText(currentValue, maxValue, special, repType, isMaxed)
	local showParagon = shouldShowParagonProgress(repType, special, isMaxed)
	if repType == ns.REP_TYPE.MAJOR then
		local parts = {}
		if ns.HasValidMajorRenown(special) then
			if shouldShowMeaningfulMajorProgress(special, maxValue, isMaxed) then
				parts[#parts + 1] = string.format(
					"%s: %s",
					ns.TEXT.RENOWN_XP,
					ns.FormatProgressValues(currentValue, maxValue)
				)
			end
			if showParagon then
				parts[#parts + 1] = string.format(
					"%s: %s%s",
					ns.TEXT.PARAGON,
					ns.FormatProgressValues(special.paragonValue, special.paragonThreshold),
					special.paragonRewardPending and " ready" or ""
				)
			end
			return table.concat(parts, "  ")
		end
		if currentValue > 0 or maxValue > 0 then
			parts[#parts + 1] = string.format(
				"%s",
				ns.FormatProgressValues(currentValue, maxValue)
			)
		end
		if showParagon then
			parts[#parts + 1] = string.format(
				"%s: %s%s",
				ns.TEXT.PARAGON,
				ns.FormatProgressValues(special.paragonValue, special.paragonThreshold),
				special.paragonRewardPending and " ready" or ""
			)
		end
		return table.concat(parts, "  ")
	end

	local progressText = ns.FormatProgressValues(currentValue, maxValue)
	if showParagon then
		progressText = string.format(
			"%s  %s: %s%s",
			progressText,
			ns.TEXT.PARAGON,
			ns.FormatProgressValues(special.paragonValue, special.paragonThreshold),
			special.paragonRewardPending and " ready" or ""
		)
	end
	return progressText
end

local function runtimeFieldsMissing(entry)
	if ns.SafeString(entry.expansionName) == "" then
		return true
	end
	if ns.SafeString(entry.repTypeLabel) == "" then
		return true
	end
	if ns.SafeString(entry.rankText) == "" and ns.SafeString(entry.progressText) == "" then
		return true
	end
	if entry.overallFraction == nil or entry.remainingFraction == nil or entry.isMaxed == nil then
		return true
	end
	if ns.SafeString(entry.sortName) == "" then
		return true
	end
	if ns.SafeString(entry.icon) == "" then
		return true
	end
	if ns.SafeString(entry.searchText) == "" then
		return true
	end
	return false
end

function helpers.ApplyRuntimeReputationFields(entry)
	if type(entry) ~= "table" then
		return
	end

	local normalizedName = ns.NormalizeText(entry.name)
	local normalizedDescription = ns.NormalizeText(entry.description)
	local normalizedHeaderPath = normalizeHeaderPath(entry.headerPath)
	local expansionKey = ns.SafeString(entry.expansionKey, ns.ALL_EXPANSIONS_KEY)
	local entryIsGuild = ns.IsGuildReputation(entry, entry.factionKey)
	local row = {
		factionKey = chooseStoredFactionKey(entry.factionID, normalizedName, entryIsGuild, entry.factionKey),
		factionID = entry.factionID,
		name = normalizedName,
		description = normalizedDescription,
		standingId = ns.SafeNumber(entry.standingId, 0),
		standingText = resolveStandingText(entry),
		currentValue = entry.currentValue,
		maxValue = entry.maxValue,
		currentStanding = entry.currentStanding,
		bottomValue = entry.bottomValue,
		topValue = entry.topValue,
		isAccountWide = entry.isAccountWide == true and not entryIsGuild,
		isWatched = entry.isWatched == true,
		isChild = entry.isChild == true,
		headerPath = normalizedHeaderPath,
		expansionKey = expansionKey,
		repType = entry.repType,
		majorFactionID = entry.majorFactionID,
	}
	local special = {
		repType = entry.repType,
		majorFactionID = ns.SafeNumber(entry.majorFactionID, 0),
		isAccountWide = entry.isAccountWide == true and not entryIsGuild,
		hasParagon = entry.hasParagon == true,
		paragonValue = ns.SafeNumber(entry.paragonValue, 0),
		paragonThreshold = ns.SafeNumber(entry.paragonThreshold, 0),
		paragonRewardPending = entry.paragonRewardPending == true,
		currentValue = entry.currentValue,
		maxValue = entry.maxValue,
		renownLevel = ns.SafeNumber(entry.renownLevel, 0),
		renownMaxLevel = ns.SafeNumber(entry.renownMaxLevel, 0),
		friendCurrentRank = ns.SafeNumber(entry.friendCurrentRank, 0),
		friendMaxRank = ns.SafeNumber(entry.friendMaxRank, 0),
		friendTextLevel = ns.NormalizeText(entry.friendTextLevel),
	}
	local repType, currentValue, maxValue, isMaxed = chooseNormalizedValues(row, special)
	local showParagonLabel = shouldShowParagonProgress(repType, special, isMaxed)
	local overallFraction = deriveOverallFraction(repType, row, special, currentValue, maxValue, isMaxed)

	entry.factionKey = row.factionKey
	entry.name = normalizedName
	entry.description = normalizedDescription
	entry.isGuildReputation = entryIsGuild
	if entryIsGuild then
		entry.isAccountWide = false
	end
	entry.repType = repType
	entry.expansionKey = expansionKey
	entry.expansionName = ns.ExpansionLabelForKey(expansionKey)
	entry.standingText = row.standingText
	entry.repTypeLabel = ns.RepTypeLabel(repType, showParagonLabel, special)
	entry.rankText = buildRankText(repType, row, special)
	entry.progressText = buildProgressText(currentValue, maxValue, special, repType, isMaxed)
	entry.currentValue = currentValue
	entry.maxValue = maxValue
	entry.isMaxed = isMaxed
	entry.overallFraction = overallFraction
	entry.remainingFraction = isMaxed and 0 or (maxValue > 0 and ns.Clamp((maxValue - currentValue) / maxValue, 0, 1) or (1 - overallFraction))
	entry.headerPath = row.headerPath
	entry.headerLabel = type(row.headerPath) == "table" and table.concat(row.headerPath, " / ") or ""
	entry.icon = ns.IconForRepType(repType)
	entry.friendTextLevel = special.friendTextLevel
	entry.sortName = ns.NormalizeSearchText(normalizedName)
	entry.searchText = ns.NormalizeSearchText(string.format(
		"%s %s %s %s",
		entry.name or "",
		entry.expansionName or "",
		entry.repTypeLabel or "",
		entry.rankText or ""
	))
end

local function rekeyLegacyGuildReputations(character)
	if type(character) ~= "table" or type(character.reputations) ~= "table" then
		return
	end

	local reputations = character.reputations
	local migrated = {}
	for factionKey, reputation in pairs(reputations) do
		if type(reputation) == "table" and ns.IsGuildReputation(reputation, factionKey) then
			local normalizedName = ns.NormalizeText(reputation.name)
			local newKey = ns.MakeGuildFactionKey(normalizedName)
			if newKey ~= "" and newKey ~= factionKey then
				migrated[#migrated + 1] = { oldKey = factionKey, newKey = newKey, reputation = reputation }
			elseif newKey == "" then
				-- Cannot derive a guild key without a name, drop the legacy
				-- entry to avoid the cross-character collision under "1168".
				migrated[#migrated + 1] = { oldKey = factionKey, newKey = nil, reputation = reputation }
			else
				reputation.factionKey = newKey
				reputation.isGuildReputation = true
				reputation.isAccountWide = false
			end
		end
	end

	for index = 1, #migrated do
		local move = migrated[index]
		reputations[move.oldKey] = nil
		if move.newKey then
			move.reputation.factionKey = move.newKey
			move.reputation.isGuildReputation = true
			move.reputation.isAccountWide = false
			reputations[move.newKey] = move.reputation
		end
	end
end

function ns.BackfillStoredCharacterReputations(character)
	if type(character) ~= "table" or type(character.reputations) ~= "table" then
		return
	end
	rekeyLegacyGuildReputations(character)
	for factionKey, reputation in pairs(character.reputations) do
		if type(reputation) == "table" then
			if ns.SafeString(reputation.factionKey) == "" then
				reputation.factionKey = factionKey
			end
			if runtimeFieldsMissing(reputation) then
				helpers.ApplyRuntimeReputationFields(reputation)
			end
		end
	end
end

function helpers.normalizeFactionRow(row, special)
	special = type(special) == "table" and special or {}
	local normalizedName = ns.NormalizeText(row.name)
	if normalizedName == "" then
		return nil
	end

	local normalizedDescription = ns.NormalizeText(row.description)
	local normalizedHeaderPath = normalizeHeaderPath(row.headerPath)
	local isGuild = ns.IsGuildReputation(row, row.factionKey)
	local factionKey = chooseStoredFactionKey(row.factionID, normalizedName, isGuild, row.factionKey)
	if factionKey == "" then
		return nil
	end

	local repType, currentValue, maxValue, isMaxed = chooseNormalizedValues(row, special)
	local showParagonLabel = shouldShowParagonProgress(repType, special, isMaxed)
	local overallFraction = deriveOverallFraction(repType, row, special, currentValue, maxValue, isMaxed)
	local remainingFraction = isMaxed and 0 or (maxValue > 0 and ns.Clamp((maxValue - currentValue) / maxValue, 0, 1) or (1 - overallFraction))
	local rankText = buildRankText(repType, row, special)
	local expansionKey = row.expansionKey
		or ns.ResolveFactionExpansionOverride(row.factionID, row.name)
		or ns.ExpansionKeyFromGameExp(row.expansionID)
		or ns.ResolveExpansionKeyFromHeaders(row.headerPath)
		or ns.ALL_EXPANSIONS_KEY

	local normalized = {
		factionKey = factionKey,
		factionID = row.factionID,
		name = normalizedName,
		description = normalizedDescription,
		expansionKey = expansionKey,
		expansionName = ns.ExpansionLabelForKey(expansionKey),
		repType = repType,
		repTypeLabel = ns.RepTypeLabel(repType, showParagonLabel, special),
		standingId = row.standingId,
		standingText = resolveStandingText(row),
		rankText = rankText,
		progressText = buildProgressText(currentValue, maxValue, special, repType, isMaxed),
		currentValue = currentValue,
		maxValue = maxValue,
		overallFraction = overallFraction,
		remainingFraction = remainingFraction,
		isMaxed = isMaxed,
		-- Guild reputation is intrinsically per-character (each character can
		-- only belong to one guild), so never honor the API's account-wide /
		-- warband flag for guild rows. Otherwise the index would collapse
		-- multiple alts into a single representative entry.
		isAccountWide = (special.isAccountWide == true or row.isAccountWide == true) and not isGuild,
		isChild = row.isChild == true,
		isWatched = row.isWatched == true,
		headerPath = normalizedHeaderPath,
		headerLabel = type(normalizedHeaderPath) == "table" and table.concat(normalizedHeaderPath, " / ") or "",
		icon = row.icon or ns.IconForRepType(repType),
		hasParagon = special.hasParagon == true,
		paragonValue = ns.SafeNumber(special.paragonValue, 0),
		paragonThreshold = ns.SafeNumber(special.paragonThreshold, 0),
		paragonRewardPending = special.paragonRewardPending == true,
		majorFactionID = ns.SafeNumber(special.majorFactionID, ns.SafeNumber(row.majorFactionID, 0)),
		parentFactionID = 0,
		parentFactionKey = nil,
		renownLevel = ns.SafeNumber(special.renownLevel, 0),
		renownMaxLevel = ns.SafeNumber(special.renownMaxLevel, 0),
		friendCurrentRank = ns.SafeNumber(special.friendCurrentRank, 0),
		friendMaxRank = ns.SafeNumber(special.friendMaxRank, 0),
		friendTextLevel = ns.NormalizeText(special.friendTextLevel),
		isGuildReputation = isGuild,
		sortName = ns.NormalizeSearchText(normalizedName),
		searchText = ns.NormalizeSearchText(string.format(
			"%s %s %s %s",
			normalizedName,
			ns.ExpansionLabelForKey(expansionKey),
			ns.RepTypeLabel(repType, showParagonLabel, special),
			rankText
		)),
	}

	if ns.ShouldTraceReputationRow(row, special) then
		ns.DebugLog(string.format(
			'NORM row name="%s" faction=%s repType=%s rank=%s progress="%s" values=%s/%s overall=%s maxed=%s accountWide=%s paragon=%s majorID=%s',
			normalized.name or ns.TEXT.UNKNOWN,
			ns.DebugValueText(normalized.factionID),
			ns.DebugValueText(normalized.repType),
			ns.DebugValueText(normalized.rankText),
			ns.DebugValueText(normalized.progressText),
			ns.DebugValueText(normalized.currentValue),
			ns.DebugValueText(normalized.maxValue),
			ns.DebugValueText(normalized.overallFraction),
			ns.DebugValueText(normalized.isMaxed),
			ns.DebugValueText(normalized.isAccountWide),
			ns.DebugValueText(normalized.hasParagon),
			ns.DebugValueText(normalized.majorFactionID)
		))
	end

	return normalized
end

function helpers.scoreNormalizedRow(row)
	local score = ns.SafeNumber(row.overallFraction, 0)
	if row.isMaxed then
		score = score + ns.SORT_WEIGHTS.MAXED
	end
	if row.repType == ns.REP_TYPE.MAJOR then
		score = score + ns.SORT_WEIGHTS.NORMALIZED_MAJOR
	elseif row.repType == ns.REP_TYPE.FRIENDSHIP then
		score = score + ns.SORT_WEIGHTS.NORMALIZED_FRIENDSHIP
	end
	if row.hasParagon then
		score = score + ns.SORT_WEIGHTS.NORMALIZED_PARAGON
	end
	return score
end
