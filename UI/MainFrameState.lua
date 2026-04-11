AltRepTracker = AltRepTracker or {}
local ns = AltRepTracker

ns.UI_MainFrameState = ns.UI_MainFrameState or {}

local state = ns.UI_MainFrameState
state.main = state.main or nil
state.rowFrames = type(state.rowFrames) == "table" and state.rowFrames or {}
state.ignoreSearchEvents = state.ignoreSearchEvents == true
state.searchRefreshToken = ns.SafeNumber(state.searchRefreshToken, 0)
