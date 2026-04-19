RepSheet = RepSheet or {}
local ns = RepSheet

-- Build the per-guild storage key used to bucket guild reputations. Every guild
-- shares ns.GUILD_FACTION_ID (1168) in the API, so we key stored guild rows by
-- "<prefix><normalized guild name>" instead of the colliding faction ID.
function ns.MakeGuildFactionKey(name)
	local normalized = ns.NormalizeSearchText(name)
	if normalized == "" then
		return ""
	end
	return ns.GUILD_FACTION_KEY_PREFIX .. normalized
end

function ns.IsGuildFactionKey(factionKey)
	if type(factionKey) ~= "string" or factionKey == "" then
		return false
	end
	if factionKey == tostring(ns.GUILD_FACTION_ID) then
		return true
	end
	local prefix = ns.GUILD_FACTION_KEY_PREFIX
	return string.sub(factionKey, 1, #prefix) == prefix
end

function ns.HeaderPathContainsGuildHeader(headerPath)
	if type(headerPath) ~= "table" then
		return false
	end
	for index = 1, #headerPath do
		if ns.NormalizeText(headerPath[index]) == ns.GUILD_HEADER_NAME then
			return true
		end
	end
	return false
end

-- Guild detection for raw scan rows where the header path is still passed
-- alongside the row instead of stored on it. Scanner modules use this before
-- the row has been normalized.
function ns.IsGuildScanRow(row, headerPath)
	if row and ns.SafeNumber(row.factionID, 0) == ns.GUILD_FACTION_ID then
		return true
	end
	return ns.HeaderPathContainsGuildHeader(headerPath)
end

-- Guild detection for normalized or stored reputation entries. Used by the
-- normalizer and character store to recognize new entries, legacy entries
-- under the shared "1168" key, and entries that already carry the guild flag.
function ns.IsGuildReputation(entry, factionKey)
	if type(entry) ~= "table" then
		return false
	end
	if entry.isGuildReputation == true then
		return true
	end
	if ns.SafeNumber(entry.factionID, 0) == ns.GUILD_FACTION_ID then
		return true
	end
	if ns.HeaderPathContainsGuildHeader(entry.headerPath) then
		return true
	end
	if ns.IsGuildFactionKey(factionKey or entry.factionKey) then
		return true
	end
	return false
end

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

function ns.MergeFactionIDLists(...)
	local merged = {}
	for index = 1, select("#", ...) do
		local ids = select(index, ...)
		for listIndex = 1, #(type(ids) == "table" and ids or {}) do
			merged[#merged + 1] = ids[listIndex]
		end
	end
	return ns.NormalizeFactionIDList(merged)
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
	return string.format("%d/%d", currentValue, maxValue)
end

function ns.FormatStatusWithProgress(statusText, progressText)
	statusText = ns.SafeString(statusText)
	progressText = ns.SafeString(progressText)
	if progressText == "" then
		return statusText
	end
	if string.find(statusText, ns.SEPARATOR.STATUS_PROGRESS_PUNCT, 1, true) then
		return statusText .. ns.SEPARATOR.META_PARTS .. progressText
	end
	return string.format(ns.FORMAT.DETAIL_STATUS_PROGRESS, statusText, progressText)
end

function ns.DeriveProgressValues(currentStanding, bottomValue, topValue)
	currentStanding = ns.SafeNumber(currentStanding, 0)
	bottomValue = ns.SafeNumber(bottomValue, 0)
	topValue = ns.SafeNumber(topValue, 0)

	local maxValue = topValue - bottomValue
	if maxValue <= 0 then
		return math.max(0, currentStanding), 0
	end

	local currentValue
	if currentStanding >= bottomValue and currentStanding <= topValue then
		currentValue = currentStanding - bottomValue
	elseif currentStanding >= 0 and currentStanding <= maxValue then
		currentValue = currentStanding
	else
		currentValue = currentStanding - bottomValue
	end

	return ns.Clamp(currentValue, 0, maxValue), maxValue
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

function ns.GetBandOverlayFraction(source)
	if type(source) ~= "table" or source.isMaxed then
		return 0
	end

	local maxValue = ns.SafeNumber(source.maxValue, 0)
	if maxValue <= 0 then
		return 0
	end

	return ns.ProgressFraction(source.currentValue, maxValue)
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

function ns.HasValidMajorRenown(source)
	return type(source) == "table" and ns.SafeNumber(source.renownMaxLevel, 0) > 0
end

function ns.RepTypeLabel(repType, hasParagon, source)
	local label = ns.TEXT.REPUTATION
	if repType == ns.REP_TYPE.MAJOR and ns.HasValidMajorRenown(source) then
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
	local name = ns.SafeString(character.characterName)
	if name == "" then
		name = ns.SafeString(character.name, ns.TEXT.UNKNOWN)
	end
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

local PROFESSION_LINE_COLOR = { 1, 0.82, 0 }
local NAME_REALM_LINE_COLOR = { 1, 1, 1 }
local NEEDS_CAPTURE_LINE_COLOR = { 1, 0.55, 0.18 }

local function appendNameRealmLine(lines, entry)
	local name = ns.SafeString(entry.characterName, ns.SafeString(entry.name, ns.TEXT.UNKNOWN))
	local realm = ns.SafeString(entry.realm)
	local text
	if realm == "" then
		text = name
	else
		text = string.format(ns.FORMAT.HOVER_NAME_REALM, name, realm)
	end
	lines[#lines + 1] = {
		text = text,
		r = NAME_REALM_LINE_COLOR[1],
		g = NAME_REALM_LINE_COLOR[2],
		b = NAME_REALM_LINE_COLOR[3],
	}
end

local function appendProfessionLine(lines, profession)
	if type(profession) ~= "table" then
		return
	end
	local name = ns.SafeString(profession.name)
	if name == "" then
		return
	end
	lines[#lines + 1] = {
		text = name,
		r = PROFESSION_LINE_COLOR[1],
		g = PROFESSION_LINE_COLOR[2],
		b = PROFESSION_LINE_COLOR[3],
	}
end

function ns.BuildCharacterHoverTooltipLines(entry)
	if type(entry) ~= "table" or entry.isAccountWide == true then
		return nil
	end

	local lines = {}
	appendNameRealmLine(lines, entry)

	if entry.professions == nil then
		lines[#lines + 1] = {
			text = ns.TEXT.HOVER_NEEDS_CAPTURE,
			r = NEEDS_CAPTURE_LINE_COLOR[1],
			g = NEEDS_CAPTURE_LINE_COLOR[2],
			b = NEEDS_CAPTURE_LINE_COLOR[3],
			wrap = true,
		}
		return lines
	end

	local level = ns.SafeNumber(entry.level, 0)
	local className = ns.SafeString(entry.className)
	local classR, classG, classB = ns.GetClassColor(entry)
	lines[#lines + 1] = {
		text = string.format(ns.FORMAT.HOVER_LEVEL_CLASS, level, className),
		r = classR,
		g = classG,
		b = classB,
	}

	appendProfessionLine(lines, entry.professions.primary1)
	appendProfessionLine(lines, entry.professions.primary2)

	return lines
end
