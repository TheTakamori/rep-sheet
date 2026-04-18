RepSheet = RepSheet or {}
local ns = RepSheet

local ADDON_NAME = ns.ADDON_NAME
local EVENT = ns.EVENT
local REASON = ns.SCAN_REASON

local frame = CreateFrame("Frame")

frame:RegisterEvent(EVENT.ADDON_LOADED)
frame:RegisterEvent(EVENT.PLAYER_LOGIN)
frame:RegisterEvent(EVENT.PLAYER_REGEN_ENABLED)

frame:SetScript("OnEvent", function(_, event, arg1, ...)
	if event == EVENT.ADDON_LOADED and arg1 == ADDON_NAME then
		ns.InitDB()
		if ns.EnsureOptionsPanel then
			ns.EnsureOptionsPanel()
		end
		if ns.InitializeLiveUpdateController then
			ns.InitializeLiveUpdateController(frame)
		end
		if ns.EnsureMinimapButton then
			ns.EnsureMinimapButton()
		end
		ns.DebugLog(string.format(ns.LOG.ADDON_LOADED, ns.GetPrimarySlashCommand()))
	elseif event == EVENT.PLAYER_LOGIN then
		if ns.EnsureMinimapButton then
			ns.EnsureMinimapButton()
		end
		ns.StartInitialScan(REASON.PLAYER_LOGIN)
	elseif event == EVENT.PLAYER_REGEN_ENABLED then
		ns.HandleCombatEnded()
	elseif ns.HandleLiveUpdateEvent then
		ns.HandleLiveUpdateEvent(event, arg1, ...)
	end
end)
