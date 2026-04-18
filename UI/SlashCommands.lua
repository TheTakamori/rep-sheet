RepSheet = RepSheet or {}
local ns = RepSheet

SLASH_REPSHEET1 = ns.SLASH_COMMANDS[1]
if ns.SLASH_COMMANDS[2] then
	SLASH_REPSHEET2 = ns.SLASH_COMMANDS[2]
end

SlashCmdList.REPSHEET = function(message)
	local token = ns.NormalizeSearchText((message or ""):match("^%s*(.-)%s*$"))
	if token == ns.SLASH_SUBCOMMAND.SCAN then
		ns.RequestReputationScan(ns.SCAN_REASON.SLASH_COMMAND, true)
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
