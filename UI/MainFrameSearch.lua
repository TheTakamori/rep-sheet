RepSheet = RepSheet or {}
local ns = RepSheet
function ns.UI_RequestSearchRefresh()
	local state = ns.UI_MainFrameState
	state.searchRefreshToken = ns.SafeNumber(state.searchRefreshToken, 0) + 1
	local refreshToken = state.searchRefreshToken
	if not (C_Timer and C_Timer.After) or ns.SafeNumber(ns.UI_SEARCH_REFRESH_DELAY_SECONDS, 0) <= 0 then
		ns.RefreshMainFrame()
		return
	end
	C_Timer.After(ns.UI_SEARCH_REFRESH_DELAY_SECONDS, function()
		if state.searchRefreshToken ~= refreshToken then
			return
		end
		ns.RefreshMainFrame()
	end)
end
