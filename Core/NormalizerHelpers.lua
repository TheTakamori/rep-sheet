AltRepTracker = AltRepTracker or {}
local ns = AltRepTracker
local helpers = ns.NormalizerHelpers

local function buildFactionKey(row)
	if row.factionID and row.factionID > 0 then
		return tostring(row.factionID)
	end
	return ns.NormalizeSearchText(row.name)
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
	local currentValue = ns.SafeNumber(row.currentValue, 0)
	local maxValue = ns.SafeNumber(row.maxValue, 0)

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

function helpers.ApplyRuntimeReputationFields(entry)
	if type(entry) ~= "table" then
		return
	end

	local expansionKey = ns.SafeString(entry.expansionKey, ns.ALL_EXPANSIONS_KEY)
	local row = {
		factionKey = entry.factionKey,
		factionID = entry.factionID,
		name = entry.name,
		standingId = ns.SafeNumber(entry.standingId, 0),
		standingText = resolveStandingText(entry),
		currentValue = entry.currentValue,
		maxValue = entry.maxValue,
		currentStanding = entry.currentStanding,
		bottomValue = entry.bottomValue,
		topValue = entry.topValue,
		isAccountWide = entry.isAccountWide == true,
		isWatched = entry.isWatched == true,
		isChild = entry.isChild == true,
		headerPath = type(entry.headerPath) == "table" and ns.CopyArray(entry.headerPath) or {},
		expansionKey = expansionKey,
		repType = entry.repType,
		majorFactionID = entry.majorFactionID,
	}
	local special = {
		repType = entry.repType,
		majorFactionID = ns.SafeNumber(entry.majorFactionID, 0),
		isAccountWide = entry.isAccountWide == true,
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
		friendTextLevel = ns.SafeString(entry.friendTextLevel),
	}
	local repType, currentValue, maxValue, isMaxed = chooseNormalizedValues(row, special)
	local showParagonLabel = shouldShowParagonProgress(repType, special, isMaxed)
	local overallFraction = deriveOverallFraction(repType, row, special, currentValue, maxValue, isMaxed)

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
	entry.headerLabel = type(row.headerPath) == "table" and table.concat(row.headerPath, " / ") or ""
	entry.icon = ns.IconForRepType(repType)
end

function helpers.normalizeFactionRow(row, special)
	special = type(special) == "table" and special or {}
	local factionKey = buildFactionKey(row)
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
		name = row.name,
		description = row.description,
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
		isAccountWide = special.isAccountWide == true or row.isAccountWide == true,
		isChild = row.isChild == true,
		isWatched = row.isWatched == true,
		headerPath = row.headerPath,
		headerLabel = type(row.headerPath) == "table" and table.concat(row.headerPath, " / ") or "",
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
		friendTextLevel = ns.SafeString(special.friendTextLevel),
		searchText = ns.NormalizeSearchText(string.format(
			"%s %s %s %s",
			row.name or "",
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
