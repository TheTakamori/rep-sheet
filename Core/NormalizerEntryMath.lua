AltRepTracker = AltRepTracker or {}
local ns = AltRepTracker
local helpers = ns.NormalizerHelpers

function helpers.isEntryActuallyMaxed(entry)
	local repType = entry and entry.repType
	local currentValue = ns.SafeNumber(entry and entry.currentValue, 0)
	local maxValue = ns.SafeNumber(entry and entry.maxValue, 0)

	if repType == ns.REP_TYPE.MAJOR then
		local renownLevel = ns.SafeNumber(entry and entry.renownLevel, 0)
		local renownMaxLevel = ns.SafeNumber(entry and entry.renownMaxLevel, 0)
		if renownMaxLevel <= 0 or renownLevel < renownMaxLevel then
			return false
		end
		return true
	end

	if repType == ns.REP_TYPE.FRIENDSHIP then
		local currentRank = ns.SafeNumber(entry and entry.friendCurrentRank, 0)
		local maxRank = ns.SafeNumber(entry and entry.friendMaxRank, 0)
		return maxRank > 0 and currentRank >= maxRank and (maxValue <= 0 or currentValue >= maxValue)
	end

	if repType == ns.REP_TYPE.STANDARD or repType == ns.REP_TYPE.OTHER or repType == ns.REP_TYPE.NEIGHBORHOOD then
		local standingId = ns.SafeNumber(entry and entry.standingId, 0)
		return standingId >= ns.MAX_STANDARD_STANDING_ID and (maxValue <= 0 or currentValue >= maxValue)
	end

	if entry and entry.hasParagon then
		return maxValue <= 0 or currentValue >= maxValue
	end

	return entry and entry.isMaxed == true
end

function helpers.deriveEntryOverallFraction(entry)
	local repType = entry and entry.repType
	local currentValue = ns.SafeNumber(entry and entry.currentValue, 0)
	local maxValue = ns.SafeNumber(entry and entry.maxValue, 0)
	local tierFraction = ns.ProgressFraction(currentValue, maxValue)
	local isMaxed = helpers.isEntryActuallyMaxed(entry)

	if repType == ns.REP_TYPE.MAJOR then
		local currentLevel = ns.SafeNumber(entry and entry.renownLevel, 0)
		local maxLevel = ns.SafeNumber(entry and entry.renownMaxLevel, 0)
		if maxLevel > 0 and currentLevel >= 0 then
			if isMaxed then
				return 1
			end
			return ns.Clamp((math.max(currentLevel - 1, 0) + tierFraction) / maxLevel, 0, 1)
		end
		return tierFraction
	end

	if repType == ns.REP_TYPE.FRIENDSHIP then
		local currentRank = ns.SafeNumber(entry and entry.friendCurrentRank, 0)
		local maxRank = ns.SafeNumber(entry and entry.friendMaxRank, 0)
		if maxRank > 0 and currentRank > 0 then
			if isMaxed then
				return 1
			end
			return ns.Clamp(((currentRank - 1) + tierFraction) / maxRank, 0, 1)
		end
		return tierFraction
	end

	local standingId = ns.SafeNumber(entry and entry.standingId, 0)
	if standingId > 0 then
		if isMaxed and standingId >= ns.MAX_STANDARD_STANDING_ID then
			return 1
		end
		return ns.Clamp(((standingId - 1) + tierFraction) / ns.MAX_STANDARD_STANDING_ID, 0, 1)
	end

	return ns.SafeNumber(entry and entry.overallFraction, tierFraction)
end

function helpers.deriveEntryRemainingFraction(entry)
	if helpers.isEntryActuallyMaxed(entry) then
		return 0
	end

	local currentValue = ns.SafeNumber(entry and entry.currentValue, 0)
	local maxValue = ns.SafeNumber(entry and entry.maxValue, 0)
	if maxValue > 0 then
		return ns.Clamp((maxValue - currentValue) / maxValue, 0, 1)
	end
	return 1 - helpers.deriveEntryOverallFraction(entry)
end
