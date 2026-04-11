AltRepTracker = AltRepTracker or {}
local ns = AltRepTracker

local ADDON_NAME = "AltRepTracker"
local EVENT = ns.EVENT
local REASON = ns.SCAN_REASON
local REFRESH_MODE = {
	FULL = "full",
	KNOWN = "known",
	FACTIONS = "factions",
}

local frame = CreateFrame("Frame")

local function refreshUI()
	if AltRepTrackerMainFrame and AltRepTrackerMainFrame:IsShown() and ns.RefreshMainFrame then
		ns.RefreshMainFrame()
	end
end

local function normalizeFactionIDs(factionIDs)
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

local function mergeFactionIDs(existingFactionIDs, incomingFactionIDs)
	local merged = {}
	local added = {}

	local function append(ids)
		for index = 1, #(type(ids) == "table" and ids or {}) do
			local factionID = ns.SafeNumber(ids[index], 0)
			if factionID > 0 and not added[factionID] then
				added[factionID] = true
				merged[#merged + 1] = factionID
			end
		end
	end

	append(existingFactionIDs)
	append(incomingFactionIDs)
	table.sort(merged)
	return merged
end

local function describeRefreshRequest(mode, factionIDs)
	if mode == REFRESH_MODE.FACTIONS then
		return string.format("%s[%d]", mode, #(type(factionIDs) == "table" and factionIDs or {}))
	end
	return ns.SafeString(mode, REFRESH_MODE.FULL)
end

local function mergeRefreshRequest(state, slotKey, reason, mode, factionIDs)
	local slot = type(state[slotKey]) == "table" and state[slotKey] or {}
	local incomingMode = mode or REFRESH_MODE.FULL
	slot.reason = reason or slot.reason or REASON.UNKNOWN

	if slot.mode == REFRESH_MODE.FULL or incomingMode == REFRESH_MODE.FULL then
		slot.mode = REFRESH_MODE.FULL
		slot.factionIDs = nil
	elseif slot.mode == REFRESH_MODE.KNOWN or incomingMode == REFRESH_MODE.KNOWN then
		slot.mode = REFRESH_MODE.KNOWN
		slot.factionIDs = nil
	else
		slot.mode = REFRESH_MODE.FACTIONS
		slot.factionIDs = mergeFactionIDs(slot.factionIDs, factionIDs)
	end

	state[slotKey] = slot
	return slot
end

local function takeRefreshRequest(state, slotKey)
	local slot = state[slotKey]
	if type(slot) ~= "table" or not slot.mode then
		return nil, nil, nil
	end

	state[slotKey] = nil
	return slot.reason or REASON.UNKNOWN, slot.mode, slot.factionIDs
end

local function flushQueuedRescan()
	local state = ns.PlayerStateEnsure()
	if state.scanInProgress or type(state.queuedRefresh) ~= "table" or not state.queuedRefresh.mode then
		return
	end

	local queuedReason, queuedMode, queuedFactionIDs = takeRefreshRequest(state, "queuedRefresh")
	ns.DebugLog(string.format(
		"Running queued follow-up refresh: reason=%s mode=%s",
		ns.DebugValueText(queuedReason),
		ns.DebugValueText(describeRefreshRequest(queuedMode, queuedFactionIDs))
	))
	ns.RequestReputationScan(queuedReason, false, queuedMode, queuedFactionIDs)
end

local function noteScanResult(snapshot, reason)
	local state = ns.PlayerStateEnsure()
	local count = snapshot and ns.SafeNumber(snapshot.reputationCount, 0) or 0
	local pendingRefresh = state.pendingRefresh
	local queuedRefresh = state.queuedRefresh

	state.lastObservedReputationCount = count
	state.lastSuccessfulScanReason = reason

	if count > ns.SafeNumber(state.bestObservedReputationCount, 0) then
		state.bestObservedReputationCount = count
	end

	ns.DebugLog(string.format(
		"Scan evaluation: reason=%s count=%s best=%s queued=%s pending=%s",
		ns.DebugValueText(reason),
		ns.DebugValueText(count),
		ns.DebugValueText(state.bestObservedReputationCount),
		ns.DebugValueText(queuedRefresh and describeRefreshRequest(queuedRefresh.mode, queuedRefresh.factionIDs) or nil),
		ns.DebugValueText(pendingRefresh and describeRefreshRequest(pendingRefresh.mode, pendingRefresh.factionIDs) or nil)
	))
end

local function performScan(reason, mode, factionIDs)
	local state = ns.PlayerStateEnsure()
	local refreshMode = mode or REFRESH_MODE.FULL
	state.scanInProgress = true
	ns.DebugLog(string.format(
		"Scan start: reason=%s mode=%s character=%s",
		ns.DebugValueText(reason),
		ns.DebugValueText(describeRefreshRequest(refreshMode, factionIDs)),
		ns.FormatCharacterName(ns.BuildCurrentCharacterMeta())
	))
	local scanFunction = ns.ScanCurrentCharacter
	if refreshMode == REFRESH_MODE.KNOWN then
		scanFunction = ns.RefreshCurrentCharacterKnownReputations
	elseif refreshMode == REFRESH_MODE.FACTIONS then
		scanFunction = ns.RefreshCurrentCharacterByFactionIDs
	end

	local ok, snapshot
	if refreshMode == REFRESH_MODE.FACTIONS then
		ok, snapshot = pcall(scanFunction, reason, factionIDs)
	else
		ok, snapshot = pcall(scanFunction, reason)
	end
	state.scanInProgress = false
	if not ok then
		ns.DebugLog(string.format(ns.LOG.SCAN_FAILED, tostring(snapshot)))
		flushQueuedRescan()
		return
	end
	ns.DebugLog(string.format(
		"Scan complete: reason=%s mode=%s character=%s reputations=%s",
		ns.DebugValueText(reason),
		ns.DebugValueText(describeRefreshRequest(refreshMode, factionIDs)),
		ns.FormatCharacterName(snapshot),
		ns.DebugValueText(snapshot and snapshot.reputationCount)
	))
	noteScanResult(snapshot, reason)
	refreshUI()
	flushQueuedRescan()
	return snapshot
end

function ns.RequestReputationScan(reason, immediate, mode, factionIDs)
	local state = ns.PlayerStateEnsure()
	local refreshMode = mode or REFRESH_MODE.FULL
	local normalizedFactionIDs = refreshMode == REFRESH_MODE.FACTIONS and normalizeFactionIDs(factionIDs) or nil

	if state.scanInProgress then
		local queued = mergeRefreshRequest(state, "queuedRefresh", reason, refreshMode, normalizedFactionIDs)
		ns.DebugLog(string.format(
			"Refresh queued during active scan: reason=%s mode=%s",
			ns.DebugValueText(reason),
			ns.DebugValueText(describeRefreshRequest(queued.mode, queued.factionIDs))
		))
		return
	end

	local pending = mergeRefreshRequest(state, "pendingRefresh", reason, refreshMode, normalizedFactionIDs)

	if immediate or not (C_Timer and C_Timer.After) then
		local pendingReason, pendingMode, pendingFactionIDs = takeRefreshRequest(state, "pendingRefresh")
		return performScan(pendingReason or reason or REASON.UNKNOWN, pendingMode or pending.mode, pendingFactionIDs or pending.factionIDs)
	end

	if state.scanScheduled then
		return
	end

	state.scanScheduled = true
	C_Timer.After(ns.SCAN_DELAY_SECONDS, function()
		state.scanScheduled = false
		local pendingReason, pendingMode, pendingFactionIDs = takeRefreshRequest(state, "pendingRefresh")
		if pendingReason then
			if state.scanInProgress then
				mergeRefreshRequest(state, "queuedRefresh", pendingReason, pendingMode, pendingFactionIDs)
				return
			end
			performScan(pendingReason, pendingMode, pendingFactionIDs)
		end
	end)
end

local function startInitialScan(reason)
	local state = ns.PlayerStateEnsure()
	state.bestObservedReputationCount = 0
	state.lastObservedReputationCount = 0
	ns.DebugLog(string.format(
		"Initial scan requested: character=%s reason=%s",
		ns.FormatCharacterName(ns.BuildCurrentCharacterMeta()),
		ns.DebugValueText(reason)
	))
	state.pendingRefresh = nil
	state.queuedRefresh = nil
	ns.RequestReputationScan(reason, false, REFRESH_MODE.FULL)
end

frame:RegisterEvent(EVENT.ADDON_LOADED)
frame:RegisterEvent(EVENT.PLAYER_LOGIN)
frame:RegisterEvent(EVENT.PLAYER_ENTERING_WORLD)
frame:RegisterEvent(EVENT.UPDATE_FACTION)
frame:RegisterEvent(EVENT.CHAT_MSG_COMBAT_FACTION_CHANGE)
frame:RegisterEvent(EVENT.MAJOR_FACTION_RENOWN_LEVEL_CHANGED)
frame:RegisterEvent(EVENT.QUEST_TURNED_IN)

frame:SetScript("OnEvent", function(_, event, arg1)
	if event == EVENT.ADDON_LOADED and arg1 == ADDON_NAME then
		ns.InitDB()
		ns.DebugLog(string.format(ns.LOG.ADDON_LOADED, ns.GetPrimarySlashCommand()))
	elseif event == EVENT.PLAYER_LOGIN then
		startInitialScan(REASON.PLAYER_LOGIN)
	elseif event == EVENT.PLAYER_ENTERING_WORLD then
		ns.RequestReputationScan(REASON.PLAYER_ENTERING_WORLD, false, REFRESH_MODE.KNOWN)
	elseif event == EVENT.UPDATE_FACTION then
		local state = ns.PlayerStateEnsure()
		local suppressedCount = ns.SafeNumber(state.suppressedUpdateFactionEvents, 0)
		local suppressUntil = ns.SafeNumber(state.suppressedUpdateFactionUntil, 0)
		local now = ns.SafeTime()
		if suppressedCount > 0 and now <= suppressUntil then
			state.suppressedUpdateFactionEvents = suppressedCount - 1
			ns.DebugLog(string.format(
				"UPDATE_FACTION ignored: header mutation pending=%s",
				ns.DebugValueText(state.suppressedUpdateFactionEvents)
			))
			return
		end
		if suppressedCount > 0 and now > suppressUntil then
			state.suppressedUpdateFactionEvents = 0
			state.suppressedUpdateFactionUntil = 0
		end
		ns.RequestReputationScan(REASON.UPDATE_FACTION, false, REFRESH_MODE.KNOWN)
	elseif event == EVENT.CHAT_MSG_COMBAT_FACTION_CHANGE then
		ns.RequestReputationScan(REASON.CHAT_MSG_COMBAT_FACTION_CHANGE, false, REFRESH_MODE.KNOWN)
	elseif event == EVENT.MAJOR_FACTION_RENOWN_LEVEL_CHANGED then
		ns.RequestReputationScan(REASON.MAJOR_FACTION_RENOWN_LEVEL_CHANGED, false, REFRESH_MODE.FACTIONS, { arg1 })
	elseif event == EVENT.QUEST_TURNED_IN then
		ns.RequestReputationScan(REASON.QUEST_TURNED_IN, false, REFRESH_MODE.KNOWN)
	end
end)

SLASH_ALTREPTRACKER1 = ns.SLASH_COMMANDS[1]
SLASH_ALTREPTRACKER2 = ns.SLASH_COMMANDS[2]
SlashCmdList.ALTREPTRACKER = function(message)
	local token = ns.NormalizeSearchText((message or ""):match("^%s*(.-)%s*$"))
	if token == ns.SLASH_SUBCOMMAND.SCAN then
		ns.RequestReputationScan(REASON.SLASH_COMMAND, true)
		return
	end
	if token == ns.SLASH_SUBCOMMAND.DEBUG then
		local ui = ns.CreateMainFrame()
		ui:Show()
		if ui.SetDebugPageShown then
			ui:SetDebugPageShown(true)
		end
		ns.RefreshMainFrame()
		return
	end
	local ui = ns.CreateMainFrame()
	ui:SetShown(not ui:IsShown())
	if ui:IsShown() then
		ns.RefreshMainFrame()
	end
end
