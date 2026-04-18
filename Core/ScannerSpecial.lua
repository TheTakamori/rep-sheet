RepSheet = RepSheet or {}
local ns = RepSheet
local pick = ns.PickTableField

local function safeTableCall(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, data = pcall(fn, ...)
	if ok and type(data) == "table" then
		return data
	end
	return nil
end

local function extractMajorFaction(row)
	if not C_MajorFactions or type(C_MajorFactions.GetMajorFactionData) ~= "function" then
		return nil
	end

	local candidates = {}
	if row.majorFactionID and row.majorFactionID > 0 then
		candidates[#candidates + 1] = row.majorFactionID
	end
	if row.factionID and row.factionID > 0 and row.factionID ~= row.majorFactionID then
		candidates[#candidates + 1] = row.factionID
	end

	for i = 1, #candidates do
		local candidate = candidates[i]
		local data = row.rawMajorData
		if type(data) ~= "table" or next(data) == nil then
			data = safeTableCall(C_MajorFactions.GetMajorFactionData, candidate)
		end
		if data then
			local renownLevel = ns.SafeNumber(pick(data, "renownLevel", "level", "currentLevel"), nil)
			local function pickRenownEarnedAndThreshold(tbl)
				if type(tbl) ~= "table" then
					return nil, nil
				end
				local e = pick(
					tbl,
					"renownReputationEarned",
					"renownLevelEarned",
					"factionRenownReputationEarned",
					"renownReputation",
					"renownExperience",
					"renownXPEarned",
					"reputationEarned",
					"earnedReputation"
				)
				local t = pick(
					tbl,
					"renownLevelThreshold",
					"renownNextLevelThreshold",
					"factionRenownLevelThreshold",
					"nextRenownLevelThreshold",
					"nextLevelReputationThreshold"
				)
				return e, t
			end

			local rawEarned, rawThreshold = pickRenownEarnedAndThreshold(data)
			if rawEarned == nil and rawThreshold == nil then
				for _, subKey in ipairs({ "renown", "majorFactionRenown", "warbandRenown", "factionRenown" }) do
					local sub = data[subKey]
					if type(sub) == "table" then
						rawEarned, rawThreshold = pickRenownEarnedAndThreshold(sub)
						if rawEarned ~= nil or rawThreshold ~= nil then
							break
						end
					end
				end
			end
			local currentValue = rawEarned ~= nil and ns.SafeNumber(rawEarned, 0) or nil
			local maxValue = rawThreshold ~= nil and ns.SafeNumber(rawThreshold, 0) or nil
			local maxLevel = ns.SafeNumber(pick(data, "maxRenownLevel", "maximumRenownLevel", "renownMaxLevel"), 0)

			if maxLevel <= 0 and type(C_MajorFactions.GetRenownLevels) == "function" then
				local ok, firstValue, secondValue = pcall(C_MajorFactions.GetRenownLevels, candidate)
				if ok then
					if type(firstValue) == "table" then
						maxLevel = #firstValue
					elseif type(secondValue) == "number" then
						maxLevel = secondValue
					elseif type(firstValue) == "number" then
						maxLevel = firstValue
					end
				end
			end

			if renownLevel or next(data) then
				return {
					repType = ns.REP_TYPE.MAJOR,
					majorFactionID = candidate,
					renownLevel = renownLevel,
					renownMaxLevel = maxLevel,
					currentValue = currentValue,
					maxValue = maxValue,
					isAccountWide = pick(data, "isAccountWide", "isWarband") == true or row.isAccountWide == true,
					rawMajorData = data,
				}
			end
		end
	end

	return nil
end

local function extractFriendshipFaction(row)
	if not row.factionID or type(GetFriendshipReputation) ~= "function" then
		return nil
	end

	local ok, friendID, friendRep, friendMaxRep, friendName, friendText, friendTexture, friendTextLevel, friendThreshold, nextFriendThreshold =
		pcall(GetFriendshipReputation, row.factionID)
	if not ok or not friendID or friendID <= 0 then
		return nil
	end

	local currentRank, maxRank = nil, nil
	if type(GetFriendshipReputationRanks) == "function" then
		local rankOk
		rankOk, currentRank, maxRank = pcall(GetFriendshipReputationRanks, row.factionID)
		if not rankOk then
			currentRank, maxRank = nil, nil
		end
	end

	local bottomValue = ns.SafeNumber(friendThreshold, 0)
	local topValue = ns.SafeNumber(nextFriendThreshold, ns.SafeNumber(friendMaxRep, 0))
	local maxValue = math.max(0, topValue - bottomValue)
	local currentValue = ns.SafeNumber(friendRep, 0)
	if currentValue >= bottomValue and currentValue <= topValue then
		currentValue = currentValue - bottomValue
	end

	return {
		repType = ns.REP_TYPE.FRIENDSHIP,
		friendID = friendID,
		friendName = friendName,
		friendText = friendText,
		friendTexture = friendTexture,
		friendTextLevel = friendTextLevel,
		friendCurrentRank = currentRank,
		friendMaxRank = maxRank,
		currentValue = ns.Clamp(currentValue, 0, maxValue > 0 and maxValue or currentValue),
		maxValue = maxValue,
		isAccountWide = row.isAccountWide == true,
	}
end

local function extractParagon(row)
	if not row.factionID or not C_Reputation or type(C_Reputation.GetFactionParagonInfo) ~= "function" then
		return nil
	end

	local ok, currentValue, threshold, rewardQuestID, hasRewardPending, tooLowLevel = pcall(C_Reputation.GetFactionParagonInfo, row.factionID)
	if not ok or not threshold or threshold <= 0 then
		return nil
	end

	local rawValue = ns.SafeNumber(currentValue, 0)
	local normalizedValue = ns.NormalizeParagonValue(rawValue, threshold, hasRewardPending == true)

	return {
		hasParagon = true,
		paragonValue = normalizedValue,
		paragonValueRaw = rawValue,
		paragonThreshold = ns.SafeNumber(threshold, 0),
		paragonRewardQuestID = rewardQuestID,
		paragonRewardPending = hasRewardPending == true,
		tooLowLevelForParagon = tooLowLevel == true,
	}
end

local function extractNeighborhood(row)
	local normalizedName = ns.NormalizeSearchText(row.name)
	if normalizedName == ns.NormalizeSearchText(ns.NEIGHBORHOOD_INITIATIVE_NAME) then
		return {
			repType = ns.REP_TYPE.NEIGHBORHOOD,
			isAccountWide = true,
		}
	end
	return nil
end

local function ensureSpecialScanSummary(summary)
	summary = type(summary) == "table" and summary or {}
	return {
		major = ns.SafeNumber(summary.major, 0),
		friendship = ns.SafeNumber(summary.friendship, 0),
		paragon = ns.SafeNumber(summary.paragon, 0),
		neighborhood = ns.SafeNumber(summary.neighborhood, 0),
	}
end

function ns.LogSpecialReputationSummary(summary)
	local totals = ensureSpecialScanSummary(summary)
	local state = ns.PlayerStateEnsure()
	state.lastSpecialScanSummary = totals
	ns.DebugLog(string.format(
		"Special scan enriched %d major, %d friendship, %d paragon, %d neighborhood factions.",
		totals.major,
		totals.friendship,
		totals.paragon,
		totals.neighborhood
	))
end

function ns.AppendSpecialReputationData(scanRows, out, summary)
	out = type(out) == "table" and out or {}
	summary = ensureSpecialScanSummary(summary)

	for index = 1, #(scanRows or {}) do
		local row = scanRows[index]
		if row and row.factionKey then
			local merged = {}

			local neighborhood = extractNeighborhood(row)
			if neighborhood then
				for key, value in pairs(neighborhood) do
					merged[key] = value
				end
				summary.neighborhood = summary.neighborhood + 1
			end

			local friendship = extractFriendshipFaction(row)
			if friendship then
				for key, value in pairs(friendship) do
					merged[key] = value
				end
				summary.friendship = summary.friendship + 1
			end

			local paragon = extractParagon(row)
			if paragon then
				for key, value in pairs(paragon) do
					merged[key] = value
				end
				summary.paragon = summary.paragon + 1
			end

			-- Major last so repType / renown fields win over friendship for renown factions (warband rows often match both APIs).
			local major = extractMajorFaction(row)
			if major then
				for key, value in pairs(major) do
					merged[key] = value
				end
				summary.major = summary.major + 1
			end

			if ns.ShouldTraceReputationRow(row, merged) then
				ns.DebugLog(string.format(
					'SPEC row name="%s" faction=%s majorID=%s accountWide=%s major=%s friendship=%s paragon=%s mergedType=%s renown=%s/%s xp=%s/%s paragonValue=%s/%s rawParagon=%s majorKeys=%s',
					row.name or ns.TEXT.UNKNOWN,
					ns.DebugValueText(row.factionID),
					ns.DebugValueText(row.majorFactionID),
					ns.DebugValueText(row.isAccountWide),
					ns.DebugValueText(major ~= nil),
					ns.DebugValueText(friendship ~= nil),
					ns.DebugValueText(paragon ~= nil),
					ns.DebugValueText(merged.repType),
					ns.DebugValueText(merged.renownLevel),
					ns.DebugValueText(merged.renownMaxLevel),
					ns.DebugValueText(merged.currentValue),
					ns.DebugValueText(merged.maxValue),
					ns.DebugValueText(merged.paragonValue),
					ns.DebugValueText(merged.paragonThreshold),
					ns.DebugValueText(merged.paragonValueRaw),
					ns.DebugTableKeys(major and major.rawMajorData, 18)
				))
			end

			if next(merged) then
				out[row.factionKey] = merged
			end
		end
	end

	return out, summary
end

function ns.ScanSpecialReputationData(scanRows)
	local out, summary = ns.AppendSpecialReputationData(scanRows, {}, nil)
	ns.LogSpecialReputationSummary(summary)
	return out
end
