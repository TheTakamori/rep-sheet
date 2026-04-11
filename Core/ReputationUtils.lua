AltRepTracker = AltRepTracker or {}
local ns = AltRepTracker

function ns.FormatLastSeen(timestamp)
	timestamp = ns.SafeNumber(timestamp, 0)
	if timestamp <= 0 or not date then
		return ns.TEXT.NEVER
	end
	return date("%Y-%m-%d %H:%M", timestamp)
end

function ns.ProgressFraction(currentValue, maxValue)
	currentValue = ns.SafeNumber(currentValue, 0)
	maxValue = ns.SafeNumber(maxValue, 0)
	if maxValue <= 0 then
		if currentValue > 0 then
			return 1
		end
		return 0
	end
	return ns.Clamp(currentValue / maxValue, 0, 1)
end

function ns.NormalizeFactionIDList(factionIDs)
	local ids = {}
	local added = {}
	for index = 1, #(type(factionIDs) == "table" and factionIDs or {}) do
		local factionID = ns.SafeNumber(factionIDs[index], 0)
		if factionID > 0 and not added[factionID] then
			added[factionID] = true
			ids[#ids + 1] = factionID
		end
	end
	table.sort(ids)
	return ids
end

function ns.FormatPercent(fraction)
	fraction = ns.SafeNumber(fraction, 0)
	return string.format("%d%%", ns.Round(ns.Clamp(fraction, 0, 1) * 100))
end

function ns.FormatProgressValues(currentValue, maxValue)
	currentValue = ns.Round(ns.SafeNumber(currentValue, 0))
	maxValue = ns.Round(ns.SafeNumber(maxValue, 0))
	if maxValue <= 0 then
		return tostring(currentValue)
	end
	return string.format("%d / %d", currentValue, maxValue)
end

function ns.NormalizeParagonValue(currentValue, threshold, rewardPending)
	currentValue = ns.SafeNumber(currentValue, 0)
	threshold = ns.SafeNumber(threshold, 0)
	if threshold <= 0 then
		return currentValue
	end

	local normalized = math.fmod(currentValue, threshold)
	if normalized < 0 then
		normalized = normalized + threshold
	end

	if rewardPending then
		return normalized + threshold
	end
	if currentValue > 0 and normalized == 0 then
		return threshold
	end
	return normalized
end

function ns.IsVisuallyMaxed(fraction)
	return ns.SafeNumber(fraction, 0) >= 0.999
end

function ns.GetParagonOverlayFraction(source)
	if type(source) ~= "table" then
		return 0
	end
	if not source.hasParagon or not source.isMaxed then
		return 0
	end

	local threshold = ns.SafeNumber(source.paragonThreshold, 0)
	if threshold <= 0 then
		return 0
	end

	return ns.ProgressFraction(source.paragonValue, threshold)
end

function ns.StandingLabel(standingId)
	return ns.STANDING_LABELS[standingId] or ns.TEXT.UNKNOWN
end

function ns.RepTypeLabel(repType, hasParagon)
	local label = ns.TEXT.REPUTATION
	if repType == ns.REP_TYPE.MAJOR then
		label = ns.TEXT.RENOWN
	elseif repType == ns.REP_TYPE.FRIENDSHIP then
		label = ns.TEXT.FRIENDSHIP
	elseif repType == ns.REP_TYPE.NEIGHBORHOOD then
		label = ns.TEXT.NEIGHBORHOOD
	end
	if hasParagon then
		label = label .. ns.TEXT.PARAGON_SUFFIX
	end
	return label
end

function ns.IconForRepType(repType)
	if repType == ns.REP_TYPE.MAJOR then
		return ns.FACTION_ICON_MAJOR
	end
	if repType == ns.REP_TYPE.FRIENDSHIP then
		return ns.FACTION_ICON_FRIENDSHIP
	end
	if repType == ns.REP_TYPE.NEIGHBORHOOD then
		return ns.FACTION_ICON_NEIGHBORHOOD
	end
	return ns.FACTION_ICON
end

function ns.FormatCharacterName(character)
	if type(character) ~= "table" then
		return ns.TEXT.UNKNOWN
	end
	local name = ns.SafeString(character.name ~= nil and character.name or character.characterName, ns.TEXT.UNKNOWN)
	local realm = ns.SafeString(character.realm)
	if realm ~= "" then
		return string.format("%s-%s", name, realm)
	end
	return name
end

function ns.GetClassColor(character)
	local classFile = type(character) == "table" and character.classFile or nil
	local colors = RAID_CLASS_COLORS
	local color = colors and classFile and colors[classFile]
	if color then
		return color.r, color.g, color.b
	end
	return ns.FALLBACK_CLASS_COLOR[1], ns.FALLBACK_CLASS_COLOR[2], ns.FALLBACK_CLASS_COLOR[3]
end
