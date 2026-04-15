RepSheet = RepSheet or {}
local ns = RepSheet

local EVENT = ns.EVENT
local REASON = ns.SCAN_REASON
local REFRESH_MODE = ns.REFRESH_MODE
local MANAGED_EVENTS = {
	EVENT.CHAT_MSG_COMBAT_FACTION_CHANGE,
	EVENT.MAJOR_FACTION_RENOWN_LEVEL_CHANGED,
}

local controller = {
	frame = nil,
	periodicRevision = 0,
	registeredListener = false,
}

local function isInCombat()
	return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function copyArray(values)
	local out = {}
	for index = 1, #(values or {}) do
		out[index] = values[index]
	end
	return out
end

local function resolveFactionNameByID(factionID)
	local helpers = ns.ScannerStandardHelpers
	if helpers and helpers.getFactionDataByFactionID then
		local row = helpers.getFactionDataByFactionID(factionID)
		local name = ns.NormalizeText(row and row.name)
		if name ~= "" then
			return name
		end
	end
	return ""
end

local function registerManagedEvent(frame, eventName)
	if frame and frame.RegisterEvent then
		frame:RegisterEvent(eventName)
	end
end

local function unregisterManagedEvent(frame, eventName)
	if frame and frame.UnregisterEvent then
		frame:UnregisterEvent(eventName)
	end
end

local function shouldListenForReputationEvents(options)
	return options.noLiveUpdates ~= true
		and (options.updateAfterCombat == true or options.updateOutOfCombat == true)
end

local function shouldRunPeriodicTimer(options)
	return options.noLiveUpdates ~= true and options.updatePeriodic == true
end

local function getPeriodicDelaySeconds(options)
	return math.max(
		ns.LIVE_UPDATE_PERIODIC_MINUTES_MIN,
		ns.SafeNumber(options and options.periodicMinutes, ns.LIVE_UPDATE_PERIODIC_MINUTES_DEFAULT)
	) * 60
end

local function requestPeriodicRefresh()
	if ns.RequestReputationScan then
		ns.RequestReputationScan(REASON.DELAYED, false, REFRESH_MODE.FULL, nil, "periodic")
	end
end

local function schedulePeriodicRefresh(revision, delaySeconds)
	if not (C_Timer and C_Timer.After) then
		return
	end

	C_Timer.After(delaySeconds, function()
		if controller.periodicRevision ~= revision then
			return
		end

		requestPeriodicRefresh()
		schedulePeriodicRefresh(revision, getPeriodicDelaySeconds(ns.GetLiveUpdateOptions()))
	end)
end

local function resolveRefreshRequest(event, ...)
	if event == EVENT.CHAT_MSG_COMBAT_FACTION_CHANGE then
		local factionIDs = ns.ResolveFactionIDsFromCombatMessage and ns.ResolveFactionIDsFromCombatMessage(...)
		if type(factionIDs) == "table" and #factionIDs > 0 then
			local normalizedFactionIDs = ns.NoteTargetedFactionRefresh and ns.NoteTargetedFactionRefresh(factionIDs) or factionIDs
			return REASON.CHAT_MSG_COMBAT_FACTION_CHANGE, REFRESH_MODE.FACTIONS, copyArray(normalizedFactionIDs)
		end
		return REASON.CHAT_MSG_COMBAT_FACTION_CHANGE, REFRESH_MODE.KNOWN, nil
	end

	if event == EVENT.MAJOR_FACTION_RENOWN_LEVEL_CHANGED then
		local factionID = ns.SafeNumber((...), 0)
		if factionID > 0 then
			local factionIDs = ns.NoteTargetedFactionRefresh and ns.NoteTargetedFactionRefresh({ factionID }) or { factionID }
			return REASON.MAJOR_FACTION_RENOWN_LEVEL_CHANGED, REFRESH_MODE.FACTIONS, copyArray(factionIDs)
		end
		return REASON.MAJOR_FACTION_RENOWN_LEVEL_CHANGED, REFRESH_MODE.KNOWN, nil
	end

	return nil, nil, nil
end

local function shouldProcessEvent(options, inCombat)
	if inCombat then
		return options.updateAfterCombat == true
	end
	return options.updateOutOfCombat == true
end

function ns.ConfigureLiveUpdates()
	local options = ns.GetLiveUpdateOptions and ns.GetLiveUpdateOptions() or {}
	local frame = controller.frame

	if frame then
		for index = 1, #MANAGED_EVENTS do
			unregisterManagedEvent(frame, MANAGED_EVENTS[index])
		end

		if shouldListenForReputationEvents(options) then
			for index = 1, #MANAGED_EVENTS do
				registerManagedEvent(frame, MANAGED_EVENTS[index])
			end
		end
	end

	controller.periodicRevision = controller.periodicRevision + 1
	if shouldRunPeriodicTimer(options) then
		schedulePeriodicRefresh(controller.periodicRevision, getPeriodicDelaySeconds(options))
	end
end

function ns.InitializeLiveUpdateController(frame)
	controller.frame = frame
	if ns.RegisterOptionsListener and not controller.registeredListener then
		ns.RegisterOptionsListener("liveUpdateController", function(sectionKey)
			if sectionKey == "liveUpdates" then
				ns.ConfigureLiveUpdates()
			end
		end)
		controller.registeredListener = true
	end
	ns.ConfigureLiveUpdates()
end

function ns.HandleLiveUpdateEvent(event, ...)
	local options = ns.GetLiveUpdateOptions and ns.GetLiveUpdateOptions() or {}
	local inCombat = isInCombat()

	if not shouldProcessEvent(options, inCombat) then
		return false
	end

	local triggerLabel = ""
	local reason, mode, factionIDs = resolveRefreshRequest(event, ...)
	if event == EVENT.CHAT_MSG_COMBAT_FACTION_CHANGE then
		local factionName = ""
		if ns.ResolveFactionIDsFromCombatMessage then
			local _, resolvedFactionName = ns.ResolveFactionIDsFromCombatMessage(...)
			factionName = ns.SafeString(resolvedFactionName)
		end
		if factionName ~= "" then
			triggerLabel = "reputation-change: " .. factionName
		end
	elseif event == EVENT.MAJOR_FACTION_RENOWN_LEVEL_CHANGED then
		local factionName = resolveFactionNameByID(ns.SafeNumber((...), 0))
		if factionName ~= "" then
			triggerLabel = "reputation-change: " .. factionName
		end
	end
	if not (reason and mode and ns.RequestReputationScan) then
		return false
	end

	ns.RequestReputationScan(reason, false, mode, factionIDs, triggerLabel)
	return true
end
