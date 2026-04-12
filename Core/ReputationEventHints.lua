RepSheet = RepSheet or {}
local ns = RepSheet
local standardHelpers = ns.ScannerStandardHelpers

local TARGETED_REFRESH_GRACE_SECONDS = 2
local genericKnownRefreshReasons = {
	[ns.SCAN_REASON.UPDATE_FACTION] = true,
	[ns.SCAN_REASON.QUEST_TURNED_IN] = true,
}
local targetedRefreshReasons = {
	[ns.SCAN_REASON.CHAT_MSG_COMBAT_FACTION_CHANGE] = true,
	[ns.SCAN_REASON.MAJOR_FACTION_RENOWN_LEVEL_CHANGED] = true,
}
local combatFactionTemplateKeys = {
	"FACTION_STANDING_INCREASED",
	"FACTION_STANDING_INCREASED_ACH_BONUS",
	"FACTION_STANDING_INCREASED_BONUS",
	"FACTION_STANDING_INCREASED_DOUBLE_BONUS",
	"FACTION_STANDING_DECREASED",
}
local compiledCombatFactionPatterns = {}

local function currentRealtime()
	if type(GetTimePreciseSec) == "function" then
		return GetTimePreciseSec()
	end
	if type(GetTime) == "function" then
		return GetTime()
	end
	return ns.SafeTime()
end

local function escapeLuaPattern(text)
	return (tostring(text or ""):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

local function compileCombatFactionTemplate(template)
	if type(template) ~= "string" or template == "" then
		return nil
	end

	local patternParts = { "^" }
	local captureKinds = {}
	local cursor = 1

	while cursor <= #template do
		local startAt, endAt, _, specifier = string.find(template, "%%([%d%$%+%-%#%.]*)([cdeEfgGiouqsxX])", cursor)
		if startAt then
			local literal = template:sub(cursor, startAt - 1)
			if literal ~= "" then
				patternParts[#patternParts + 1] = escapeLuaPattern(literal)
			end

			if specifier == "s" or specifier == "q" or specifier == "c" then
				captureKinds[#captureKinds + 1] = "string"
				patternParts[#patternParts + 1] = "(.+)"
			elseif specifier == "d" or specifier == "i" or specifier == "u" or specifier == "o" or specifier == "x" or specifier == "X" then
				captureKinds[#captureKinds + 1] = "number"
				patternParts[#patternParts + 1] = "([%+%-]?[%d%.,]+)"
			else
				captureKinds[#captureKinds + 1] = "number"
				patternParts[#patternParts + 1] = "([%+%-]?[%d%.,]+)"
			end

			cursor = endAt + 1
		else
			local nextPercent = string.find(template, "%%", cursor, true)
			if not nextPercent then
				patternParts[#patternParts + 1] = escapeLuaPattern(template:sub(cursor))
				break
			end

			if nextPercent > cursor then
				patternParts[#patternParts + 1] = escapeLuaPattern(template:sub(cursor, nextPercent - 1))
				cursor = nextPercent
			else
				local nextChar = template:sub(cursor + 1, cursor + 1)
				if nextChar == "%" then
					patternParts[#patternParts + 1] = "%%"
					cursor = cursor + 2
				else
					patternParts[#patternParts + 1] = "%%"
					cursor = cursor + 1
				end
			end
		end
	end

	patternParts[#patternParts + 1] = "$"
	return {
		pattern = table.concat(patternParts),
		captureKinds = captureKinds,
	}
end

local function getCompiledCombatFactionPattern(templateKey)
	if compiledCombatFactionPatterns[templateKey] ~= nil then
		local compiled = compiledCombatFactionPatterns[templateKey]
		return compiled ~= false and compiled or nil
	end

	local compiled = compileCombatFactionTemplate(_G[templateKey])
	compiledCombatFactionPatterns[templateKey] = compiled or false
	return compiled
end

function ns.IsGenericKnownReputationReason(reason)
	return genericKnownRefreshReasons[ns.SafeString(reason)] == true
end

function ns.IsTargetedReputationReason(reason)
	return targetedRefreshReasons[ns.SafeString(reason)] == true
end

function ns.ShouldReplaceGenericRefreshWithTargeted(existingReason, incomingReason, incomingMode)
	return incomingMode == "factions"
		and ns.IsGenericKnownReputationReason(existingReason)
		and ns.IsTargetedReputationReason(incomingReason)
end

function ns.ExtractFactionNameFromCombatMessage(message)
	message = ns.SafeString(message)
	if message == "" then
		return ""
	end

	for index = 1, #combatFactionTemplateKeys do
		local compiled = getCompiledCombatFactionPattern(combatFactionTemplateKeys[index])
		if compiled then
			local captures = { string.match(message, compiled.pattern) }
			if #captures > 0 then
				for captureIndex = 1, #compiled.captureKinds do
					if compiled.captureKinds[captureIndex] == "string" then
						local factionName = ns.NormalizeText(captures[captureIndex])
						if factionName ~= "" then
							return factionName
						end
					end
				end
			end
		end
	end

	return ""
end

function ns.ResolveFactionIDsFromCombatMessage(message)
	local factionName = ns.ExtractFactionNameFromCombatMessage(message)
	if factionName == "" then
		return {}, ""
	end

	local currentCharacterKey = ns.GetCurrentCharacterKey and ns.GetCurrentCharacterKey() or ""
	local factionIDs, metaByFactionID = {}, {}
	if standardHelpers.getCharacterFactionMetadata then
		factionIDs, metaByFactionID = standardHelpers.getCharacterFactionMetadata(currentCharacterKey)
	end
	local normalizedFactionName = ns.NormalizeSearchText(factionName)
	local matches = {}

	for index = 1, #factionIDs do
		local factionID = factionIDs[index]
		local meta = metaByFactionID[factionID]
		if ns.NormalizeSearchText(meta and meta.name) == normalizedFactionName then
			matches[#matches + 1] = factionID
		end
	end

	return matches, factionName
end

function ns.NoteTargetedFactionRefresh(factionIDs)
	local normalizedFactionIDs = ns.NormalizeFactionIDList(factionIDs)
	if #normalizedFactionIDs == 0 then
		return normalizedFactionIDs
	end

	local state = ns.PlayerStateEnsure and ns.PlayerStateEnsure() or nil
	if type(state) == "table" then
		state.targetedRefreshBurstUntil = currentRealtime() + TARGETED_REFRESH_GRACE_SECONDS
	end

	return normalizedFactionIDs
end

function ns.ShouldSuppressGenericFactionRefresh(reason)
	if not ns.IsGenericKnownReputationReason(reason) then
		return false
	end

	local state = ns.PlayerStateEnsure and ns.PlayerStateEnsure() or nil
	if type(state) ~= "table" then
		return false
	end

	local suppressUntil = ns.SafeNumber(state.targetedRefreshBurstUntil, 0)
	if suppressUntil <= currentRealtime() then
		state.targetedRefreshBurstUntil = 0
		return false
	end

	return true
end
