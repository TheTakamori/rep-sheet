RepSheet = RepSheet or {}
local ns = RepSheet

local REASON = ns.SCAN_REASON
local REFRESH_MODE = ns.REFRESH_MODE

local function isInCombat()
	return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function refreshUIIfShown()
	if RepSheetMainFrame and RepSheetMainFrame:IsShown() and ns.RefreshMainFrame then
		ns.RefreshMainFrame()
	end
end

local function describeRefreshRequest(mode, factionIDs)
	if mode == REFRESH_MODE.FACTIONS then
		return string.format("%s[%d]", mode, #(type(factionIDs) == "table" and factionIDs or {}))
	end
	return ns.SafeString(mode, REFRESH_MODE.FULL)
end

local function mergeTriggerLabel(existingLabel, incomingLabel)
	existingLabel = ns.SafeString(existingLabel)
	incomingLabel = ns.SafeString(incomingLabel)
	if existingLabel == "" then
		return incomingLabel
	end
	if incomingLabel == "" or incomingLabel == existingLabel then
		return existingLabel
	end
	return existingLabel .. ", " .. incomingLabel
end

local function notifyScanActivity(phase, reason, mode, factionIDs, snapshot, triggerLabel)
	if not ns.DebugNotify then
		return
	end

	local message = string.format(
		"Rep update %s: reason=%s mode=%s",
		ns.SafeString(phase, "started"),
		ns.DebugValueText(reason),
		ns.DebugValueText(describeRefreshRequest(mode, factionIDs))
	)
	if ns.SafeString(triggerLabel) ~= "" then
		message = string.format("%s trigger=%s", message, triggerLabel)
	end

	if snapshot then
		message = string.format(
			"%s character=%s reputations=%s",
			message,
			ns.FormatCharacterName(snapshot),
			ns.DebugValueText(snapshot and snapshot.reputationCount)
		)
	end

	ns.DebugNotify(message)
end

local function mergeRefreshRequest(state, slotKey, reason, mode, factionIDs, triggerLabel)
	local slot = type(state[slotKey]) == "table" and state[slotKey] or {}
	local incomingMode = mode or REFRESH_MODE.FULL
	local existingReason = slot.reason
	local existingMode = slot.mode
	local existingTriggerLabel = ns.SafeString(slot.triggerLabel)

	if existingMode == REFRESH_MODE.FULL or incomingMode == REFRESH_MODE.FULL then
		slot.reason = reason or existingReason or REASON.UNKNOWN
		slot.mode = REFRESH_MODE.FULL
		slot.factionIDs = nil
		slot.triggerLabel = mergeTriggerLabel(existingTriggerLabel, triggerLabel)
	elseif existingMode == REFRESH_MODE.FACTIONS
		and incomingMode == REFRESH_MODE.KNOWN
		and ns.ShouldSuppressGenericFactionRefresh
		and ns.ShouldSuppressGenericFactionRefresh(reason)
	then
		slot.reason = existingReason or reason or REASON.UNKNOWN
		slot.mode = REFRESH_MODE.FACTIONS
		slot.factionIDs = ns.MergeFactionIDLists(slot.factionIDs, factionIDs)
		slot.triggerLabel = mergeTriggerLabel(existingTriggerLabel, triggerLabel)
	elseif existingMode == REFRESH_MODE.KNOWN
		and ns.ShouldReplaceGenericRefreshWithTargeted
		and ns.ShouldReplaceGenericRefreshWithTargeted(existingReason, reason, incomingMode)
	then
		slot.reason = reason or existingReason or REASON.UNKNOWN
		slot.mode = REFRESH_MODE.FACTIONS
		slot.factionIDs = ns.MergeFactionIDLists(slot.factionIDs, factionIDs)
		slot.triggerLabel = mergeTriggerLabel(existingTriggerLabel, triggerLabel)
	elseif existingMode == REFRESH_MODE.KNOWN or incomingMode == REFRESH_MODE.KNOWN then
		slot.reason = reason or existingReason or REASON.UNKNOWN
		slot.mode = REFRESH_MODE.KNOWN
		slot.factionIDs = nil
		slot.triggerLabel = mergeTriggerLabel(existingTriggerLabel, triggerLabel)
	else
		slot.reason = reason or existingReason or REASON.UNKNOWN
		slot.mode = REFRESH_MODE.FACTIONS
		slot.factionIDs = ns.MergeFactionIDLists(slot.factionIDs, factionIDs)
		slot.triggerLabel = mergeTriggerLabel(existingTriggerLabel, triggerLabel)
	end

	state[slotKey] = slot
	return slot
end

local function takeRefreshRequest(state, slotKey)
	local slot = state[slotKey]
	if type(slot) ~= "table" or not slot.mode then
		return nil, nil, nil, nil
	end

	state[slotKey] = nil
	return slot.reason or REASON.UNKNOWN, slot.mode, slot.factionIDs, slot.triggerLabel
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

	local combatReason, combatMode, combatFactionIDs, combatTriggerLabel = takeRefreshRequest(state, "combatDeferredRefresh")
	if not combatReason then
		return false
	end

	ns.DebugLog(string.format(
		"Running combat-deferred refresh: reason=%s mode=%s",
		ns.DebugValueText(combatReason),
		ns.DebugValueText(describeRefreshRequest(combatMode, combatFactionIDs))
	))
	ns.RequestReputationScan(combatReason, false, combatMode, combatFactionIDs, combatTriggerLabel)
	return true
end

local function movePendingRefreshToCombatDeferred(state)
	local pendingReason, pendingMode, pendingFactionIDs, pendingTriggerLabel = takeRefreshRequest(state, "pendingRefresh")
	if not pendingReason then
		return nil
	end

	cancelScheduledScan(state)
	return mergeRefreshRequest(state, "combatDeferredRefresh", pendingReason, pendingMode, pendingFactionIDs, pendingTriggerLabel)
end

local function deferRefreshUntilAfterCombat(state, reason, mode, factionIDs, triggerLabel)
	local movedPending = movePendingRefreshToCombatDeferred(state)
	local deferred = mergeRefreshRequest(state, "combatDeferredRefresh", reason, mode, factionIDs, triggerLabel)
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

	local queuedReason, queuedMode, queuedFactionIDs, queuedTriggerLabel = takeRefreshRequest(state, "queuedRefresh")
	ns.DebugLog(string.format(
		"Running queued follow-up refresh: reason=%s mode=%s",
		ns.DebugValueText(queuedReason),
		ns.DebugValueText(describeRefreshRequest(queuedMode, queuedFactionIDs))
	))
	ns.RequestReputationScan(queuedReason, false, queuedMode, queuedFactionIDs, queuedTriggerLabel)
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

local function completeScan(scanToken, reason, refreshMode, factionIDs, triggerLabel, ok, result)
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
	notifyScanActivity("completed", reason, refreshMode, factionIDs, result, triggerLabel)
	noteScanResult(result, reason)
	refreshUIIfShown()
	flushQueuedRescan()
	flushCombatDeferredRescan()
	return result
end

local function performScan(reason, mode, factionIDs, allowAsync, triggerLabel)
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
	notifyScanActivity("started", reason, refreshMode, factionIDs, nil, triggerLabel)
	if allowAsync and refreshMode == REFRESH_MODE.KNOWN and ns.StartAsyncKnownReputationRefresh then
		local started = ns.StartAsyncKnownReputationRefresh(reason, scanToken, function(ok, result)
			completeScan(scanToken, reason, refreshMode, factionIDs, triggerLabel, ok, result)
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
	return completeScan(scanToken, reason, refreshMode, factionIDs, triggerLabel, ok, snapshot)
end

function ns.RequestReputationScan(reason, immediate, mode, factionIDs, triggerLabel)
	local state = ns.PlayerStateEnsure()
	local refreshMode = mode or REFRESH_MODE.FULL
	local normalizedFactionIDs = refreshMode == REFRESH_MODE.FACTIONS and ns.NormalizeFactionIDList(factionIDs) or nil

	if not immediate and isInCombat() then
		deferRefreshUntilAfterCombat(state, reason, refreshMode, normalizedFactionIDs, triggerLabel)
		return
	end

	if state.scanInProgress then
		local queued = mergeRefreshRequest(state, "queuedRefresh", reason, refreshMode, normalizedFactionIDs, triggerLabel)
		ns.DebugLog(string.format(
			"Refresh queued during active scan: reason=%s mode=%s",
			ns.DebugValueText(reason),
			ns.DebugValueText(describeRefreshRequest(queued.mode, queued.factionIDs))
		))
		return
	end

	local pending = mergeRefreshRequest(state, "pendingRefresh", reason, refreshMode, normalizedFactionIDs, triggerLabel)

	if immediate or not (C_Timer and C_Timer.After) then
		local pendingReason, pendingMode, pendingFactionIDs, pendingTriggerLabel = takeRefreshRequest(state, "pendingRefresh")
		return performScan(
			pendingReason or reason or REASON.UNKNOWN,
			pendingMode or pending.mode,
			pendingFactionIDs or pending.factionIDs,
			false,
			pendingTriggerLabel or pending.triggerLabel
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
		local pendingReason, pendingMode, pendingFactionIDs, pendingTriggerLabel = takeRefreshRequest(state, "pendingRefresh")
		if pendingReason then
			if isInCombat() then
				deferRefreshUntilAfterCombat(state, pendingReason, pendingMode, pendingFactionIDs, pendingTriggerLabel)
				return
			end
			if state.scanInProgress then
				mergeRefreshRequest(state, "queuedRefresh", pendingReason, pendingMode, pendingFactionIDs, pendingTriggerLabel)
				return
			end
			performScan(pendingReason, pendingMode, pendingFactionIDs, true, pendingTriggerLabel)
		end
	end)
end

function ns.StartInitialScan(reason)
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
	ns.RequestReputationScan(reason, true, REFRESH_MODE.FULL)
end

function ns.HandleCombatEnded()
	resumeDeferredBackgroundJob()
	flushCombatDeferredRescan()
end
