RepSheet = RepSheet or {}
local ns = RepSheet

local function chooseLatestSnapshot(characters)
	local latestSnapshot = nil
	local latestKey = ""
	local latestAt = 0

	for characterKey, snapshot in pairs(characters or {}) do
		local snapshotKey = ns.SafeString(characterKey, ns.SafeString(snapshot and snapshot.characterKey))
		local scanAt = ns.SafeNumber(snapshot and snapshot.lastScanAt, 0)
		if scanAt > latestAt or (scanAt == latestAt and snapshotKey ~= "" and (latestKey == "" or snapshotKey < latestKey)) then
			latestSnapshot = snapshot
			latestKey = snapshotKey
			latestAt = scanAt
		end
	end

	return latestSnapshot, latestKey, latestAt
end

local function recomputeLastScanMetadata(db)
	local latestSnapshot, latestKey, latestAt = chooseLatestSnapshot(db and db.characters)
	if latestSnapshot and latestAt > 0 and latestKey ~= "" then
		db.lastScanAt = latestAt
		db.lastScanCharacter = latestKey
		return
	end

	db.lastScanAt = 0
	db.lastScanCharacter = ""
end

local function isCharacterDeleteBlocked()
	local state = ns.PlayerStateEnsure and ns.PlayerStateEnsure() or ns.PlayerState
	if type(state) ~= "table" then
		return false
	end

	return state.scanInProgress == true
		or state.scanScheduled == true
		or (type(state.pendingRefresh) == "table" and state.pendingRefresh.mode ~= nil)
		or (type(state.queuedRefresh) == "table" and state.queuedRefresh.mode ~= nil)
end

function ns.GetForgettableCharacters()
	local out = {}
	local currentCharacterKey = ns.GetCurrentCharacterKey and ns.GetCurrentCharacterKey() or ""
	local characters = ns.GetSortedCharacters()

	for index = 1, #characters do
		local character = characters[index]
		local characterKey = ns.SafeString(character and character.characterKey)
		if characterKey ~= "" and characterKey ~= currentCharacterKey then
			out[#out + 1] = character
		end
	end

	return out
end

function ns.DeleteCharacterSnapshot(characterKey)
	characterKey = ns.SafeString(characterKey)
	if characterKey == "" then
		return false, "notFound"
	end
	if characterKey == (ns.GetCurrentCharacterKey and ns.GetCurrentCharacterKey() or "") then
		return false, "currentCharacter"
	end
	if isCharacterDeleteBlocked() then
		return false, "scanBusy"
	end

	local db = RepSheetDB
	local characters = db and db.characters
	if type(characters) ~= "table" or type(characters[characterKey]) ~= "table" then
		return false, "notFound"
	end

	local removedCharacter = characters[characterKey]
	characters[characterKey] = nil
	recomputeLastScanMetadata(db)
	ns.MarkIndexDirty()

	ns.DebugLog(string.format(
		"Forgot stored alt snapshot: %s",
		ns.DebugValueText(removedCharacter and ns.FormatCharacterName(removedCharacter) or characterKey)
	))

	return true, removedCharacter
end
