RepSheet = RepSheet or {}
local ns = RepSheet

local ADDON_NAME = ns.ADDON_NAME
local EVENT = ns.EVENT
local REASON = ns.SCAN_REASON
local REFRESH_MODE = {
	FULL = "full",
	KNOWN = "known",
	FACTIONS = "factions",
}

local frame = CreateFrame("Frame")

local function isInCombat()
	return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function refreshUI()
	if RepSheetMainFrame and RepSheetMainFrame:IsShown() and ns.RefreshMainFrame then
		ns.RefreshMainFrame()
	end
end

local function mergeFactionIDs(existingFactionIDs, incomingFactionIDs)
	return ns.MergeFactionIDLists(existingFactionIDs, incomingFactionIDs)
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
	local existingReason = slot.reason
	local existingMode = slot.mode

	if existingMode == REFRESH_MODE.FULL or incomingMode == REFRESH_MODE.FULL then
		slot.reason = reason or existingReason or REASON.UNKNOWN
		slot.mode = REFRESH_MODE.FULL
		slot.factionIDs = nil
	elseif existingMode == REFRESH_MODE.FACTIONS
		and incomingMode == REFRESH_MODE.KNOWN
		and ns.ShouldSuppressGenericFactionRefresh
		and ns.ShouldSuppressGenericFactionRefresh(reason)
	then
		slot.reason = existingReason or reason or REASON.UNKNOWN
		slot.mode = REFRESH_MODE.FACTIONS
		slot.factionIDs = mergeFactionIDs(slot.factionIDs, factionIDs)
	elseif existingMode == REFRESH_MODE.KNOWN
		and ns.ShouldReplaceGenericRefreshWithTargeted
		and ns.ShouldReplaceGenericRefreshWithTargeted(existingReason, reason, incomingMode)
	then
		slot.reason = reason or existingReason or REASON.UNKNOWN
		slot.mode = REFRESH_MODE.FACTIONS
		slot.factionIDs = mergeFactionIDs(slot.factionIDs, factionIDs)
	elseif existingMode == REFRESH_MODE.KNOWN or incomingMode == REFRESH_MODE.KNOWN then
		slot.reason = reason or existingReason or REASON.UNKNOWN
		slot.mode = REFRESH_MODE.KNOWN
		slot.factionIDs = nil
	else
		slot.reason = reason or existingReason or REASON.UNKNOWN
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

local function cancelScheduledScan(state)
	if not state.scanScheduled then
		return
	end
	state.scanScheduled = false
	state.scanScheduleToken = ns.SafeNumber(state.scanScheduleToken, 0) + 1
end

local function flushCombatDeferredRescan()
	local state = ns.PlayerStateEnsure()
	if isInCombat() or state.scanInProgress or state.scanScheduled then
		return false
	end

	local combatReason, combatMode, combatFactionIDs = takeRefreshRequest(state, "combatDeferredRefresh")
	if not combatReason then
		return false
	end

	ns.DebugLog(string.format(
		"Running combat-deferred refresh: reason=%s mode=%s",
		ns.DebugValueText(combatReason),
		ns.DebugValueText(describeRefreshRequest(combatMode, combatFactionIDs))
	))
	ns.RequestReputationScan(combatReason, false, combatMode, combatFactionIDs)
	return true
end

local function movePendingRefreshToCombatDeferred(state)
	local pendingReason, pendingMode, pendingFactionIDs = takeRefreshRequest(state, "pendingRefresh")
	if not pendingReason then
		return nil
	end

	cancelScheduledScan(state)
	return mergeRefreshRequest(state, "combatDeferredRefresh", pendingReason, pendingMode, pendingFactionIDs)
end

local function deferRefreshUntilAfterCombat(state, reason, mode, factionIDs)
	local movedPending = movePendingRefreshToCombatDeferred(state)
	local deferred = mergeRefreshRequest(state, "combatDeferredRefresh", reason, mode, factionIDs)
	ns.DebugLog(string.format(
		"Refresh deferred until after combat: reason=%s mode=%s movedPending=%s",
		ns.DebugValueText(reason),
		ns.DebugValueText(describeRefreshRequest(deferred.mode, deferred.factionIDs)),
		ns.DebugValueText(movedPending ~= nil)
	))
	return deferred
end

function ns.DeferBackgroundJobUntilAfterCombat(callback, label)
	if type(callback) ~= "function" or not isInCombat() then
		return false
	end

	local state = ns.PlayerStateEnsure()
	state.combatDeferredBackgroundCallback = callback
	state.combatDeferredBackgroundLabel = ns.SafeString(label, "background job")
	ns.DebugLog(string.format(
		"Deferred %s until after combat.",
		ns.DebugValueText(state.combatDeferredBackgroundLabel)
	))
	return true
end

local function resumeDeferredBackgroundJob()
	local state = ns.PlayerStateEnsure()
	if isInCombat() then
		return false
	end

	local callback = state.combatDeferredBackgroundCallback
	if type(callback) ~= "function" then
		return false
	end

	local label = ns.SafeString(state.combatDeferredBackgroundLabel, "background job")
	state.combatDeferredBackgroundCallback = nil
	state.combatDeferredBackgroundLabel = nil
	ns.DebugLog(string.format("Resuming deferred %s after combat.", ns.DebugValueText(label)))
	if C_Timer and C_Timer.After then
		C_Timer.After(0, callback)
	else
		callback()
	end
	return true
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

local function completeScan(scanToken, reason, refreshMode, factionIDs, ok, result)
	local state = ns.PlayerStateEnsure()
	if state.activeScanToken ~= scanToken then
		return result
	end

	state.activeScanToken = nil
	state.scanInProgress = false
	if not ok then
		ns.DebugLog(string.format(ns.LOG.SCAN_FAILED, tostring(result)))
		flushQueuedRescan()
		flushCombatDeferredRescan()
		return
	end
	ns.DebugLog(string.format(
		"Scan complete: reason=%s mode=%s character=%s reputations=%s",
		ns.DebugValueText(reason),
		ns.DebugValueText(describeRefreshRequest(refreshMode, factionIDs)),
		ns.FormatCharacterName(result),
		ns.DebugValueText(result and result.reputationCount)
	))
	noteScanResult(result, reason)
	refreshUI()
	flushQueuedRescan()
	flushCombatDeferredRescan()
	return result
end

local function performScan(reason, mode, factionIDs, allowAsync)
	local state = ns.PlayerStateEnsure()
	local refreshMode = mode or REFRESH_MODE.FULL
	state.scanInProgress = true
	state.scanTokenCounter = ns.SafeNumber(state.scanTokenCounter, 0) + 1
	local scanToken = state.scanTokenCounter
	state.activeScanToken = scanToken
	ns.DebugLog(string.format(
		"Scan start: reason=%s mode=%s character=%s",
		ns.DebugValueText(reason),
		ns.DebugValueText(describeRefreshRequest(refreshMode, factionIDs)),
		ns.FormatCharacterName(ns.BuildCurrentCharacterMeta())
	))
	if allowAsync and refreshMode == REFRESH_MODE.KNOWN and ns.StartAsyncKnownReputationRefresh then
		local started = ns.StartAsyncKnownReputationRefresh(reason, scanToken, function(ok, result)
			completeScan(scanToken, reason, refreshMode, factionIDs, ok, result)
		end)
		if started then
			return
		end
	end

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
	return completeScan(scanToken, reason, refreshMode, factionIDs, ok, snapshot)
end

function ns.RequestReputationScan(reason, immediate, mode, factionIDs)
	local state = ns.PlayerStateEnsure()
	local refreshMode = mode or REFRESH_MODE.FULL
	local normalizedFactionIDs = refreshMode == REFRESH_MODE.FACTIONS and ns.NormalizeFactionIDList(factionIDs) or nil

	if not immediate and isInCombat() then
		deferRefreshUntilAfterCombat(state, reason, refreshMode, normalizedFactionIDs)
		return
	end

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
		return performScan(
			pendingReason or reason or REASON.UNKNOWN,
			pendingMode or pending.mode,
			pendingFactionIDs or pending.factionIDs,
			false
		)
	end

	if state.scanScheduled then
		return
	end

	state.scanScheduled = true
	state.scanScheduleToken = ns.SafeNumber(state.scanScheduleToken, 0) + 1
	local scheduleToken = state.scanScheduleToken
	C_Timer.After(ns.SCAN_DELAY_SECONDS, function()
		if state.scanScheduleToken ~= scheduleToken then
			return
		end
		state.scanScheduled = false
		local pendingReason, pendingMode, pendingFactionIDs = takeRefreshRequest(state, "pendingRefresh")
		if pendingReason then
			if isInCombat() then
				deferRefreshUntilAfterCombat(state, pendingReason, pendingMode, pendingFactionIDs)
				return
			end
			if state.scanInProgress then
				mergeRefreshRequest(state, "queuedRefresh", pendingReason, pendingMode, pendingFactionIDs)
				return
			end
			performScan(pendingReason, pendingMode, pendingFactionIDs, true)
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
frame:RegisterEvent(EVENT.PLAYER_REGEN_ENABLED)
frame:RegisterEvent(EVENT.UPDATE_FACTION)
frame:RegisterEvent(EVENT.CHAT_MSG_COMBAT_FACTION_CHANGE)
frame:RegisterEvent(EVENT.MAJOR_FACTION_RENOWN_LEVEL_CHANGED)
frame:RegisterEvent(EVENT.QUEST_TURNED_IN)

frame:SetScript("OnEvent", function(_, event, arg1)
	if event == EVENT.ADDON_LOADED and arg1 == ADDON_NAME then
		ns.InitDB()
		if ns.EnsureMinimapButton then
			ns.EnsureMinimapButton()
		end
		ns.DebugLog(string.format(ns.LOG.ADDON_LOADED, ns.GetPrimarySlashCommand()))
	elseif event == EVENT.PLAYER_LOGIN then
		if ns.EnsureMinimapButton then
			ns.EnsureMinimapButton()
		end
		startInitialScan(REASON.PLAYER_LOGIN)
	elseif event == EVENT.PLAYER_ENTERING_WORLD then
		ns.RequestReputationScan(REASON.PLAYER_ENTERING_WORLD, false, REFRESH_MODE.KNOWN)
	elseif event == EVENT.PLAYER_REGEN_ENABLED then
		resumeDeferredBackgroundJob()
		flushCombatDeferredRescan()
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
		if ns.ShouldSuppressGenericFactionRefresh and ns.ShouldSuppressGenericFactionRefresh(REASON.UPDATE_FACTION) then
			ns.DebugLog("UPDATE_FACTION ignored: targeted refresh burst active.")
			return
		end
		ns.RequestReputationScan(REASON.UPDATE_FACTION, false, REFRESH_MODE.KNOWN)
	elseif event == EVENT.CHAT_MSG_COMBAT_FACTION_CHANGE then
		local targetedFactionIDs, factionName = {}, ""
		if ns.ResolveFactionIDsFromCombatMessage then
			targetedFactionIDs, factionName = ns.ResolveFactionIDsFromCombatMessage(arg1)
		end
		if type(targetedFactionIDs) == "table" and #targetedFactionIDs > 0 then
			if ns.NoteTargetedFactionRefresh then
				targetedFactionIDs = ns.NoteTargetedFactionRefresh(targetedFactionIDs)
			end
			ns.DebugLog(string.format(
				"Combat faction change targeted refresh: faction=%s ids=%s",
				ns.DebugValueText(factionName),
				ns.DebugValueText(#targetedFactionIDs)
			))
			ns.RequestReputationScan(REASON.CHAT_MSG_COMBAT_FACTION_CHANGE, false, REFRESH_MODE.FACTIONS, targetedFactionIDs)
		else
			ns.DebugLog(string.format(
				"Combat faction change unresolved; falling back to full scan: faction=%s",
				ns.DebugValueText(factionName)
			))
			ns.RequestReputationScan(REASON.CHAT_MSG_COMBAT_FACTION_CHANGE, false, REFRESH_MODE.FULL)
		end
	elseif event == EVENT.MAJOR_FACTION_RENOWN_LEVEL_CHANGED then
		local targetedFactionIDs = { arg1 }
		if ns.NoteTargetedFactionRefresh then
			targetedFactionIDs = ns.NoteTargetedFactionRefresh(targetedFactionIDs)
		end
		ns.RequestReputationScan(REASON.MAJOR_FACTION_RENOWN_LEVEL_CHANGED, false, REFRESH_MODE.FACTIONS, targetedFactionIDs)
	elseif event == EVENT.QUEST_TURNED_IN then
		if ns.ShouldSuppressGenericFactionRefresh and ns.ShouldSuppressGenericFactionRefresh(REASON.QUEST_TURNED_IN) then
			ns.DebugLog("QUEST_TURNED_IN ignored: targeted refresh burst active.")
			return
		end
		ns.RequestReputationScan(REASON.QUEST_TURNED_IN, false, REFRESH_MODE.KNOWN)
	end
end)

SLASH_REPSHEET1 = ns.SLASH_COMMANDS[1]
if ns.SLASH_COMMANDS[2] then
	SLASH_REPSHEET2 = ns.SLASH_COMMANDS[2]
end
SlashCmdList.REPSHEET = function(message)
	local token = ns.NormalizeSearchText((message or ""):match("^%s*(.-)%s*$"))
	if token == ns.SLASH_SUBCOMMAND.SCAN then
		ns.RequestReputationScan(REASON.SLASH_COMMAND, true)
		return
	end
	if token == ns.SLASH_SUBCOMMAND.DEBUG and ns.IsLocalDebugEnabled and ns.IsLocalDebugEnabled() then
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
